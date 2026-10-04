using System.Data;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpGet("members/{memberId:long}/memberships")]
    public async Task<IActionResult> Memberships(long memberId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54007", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT E.MembershipID id,E.PackageID packageId,E.PackageNameSnapshot packageName,
 E.StartsOn startsOn,E.EndsOn endsOn,E.PriceSnapshot price,E.QuotaUnitSnapshot unit,
 E.QuotaAmountSnapshot quota,E.StatusCode status
FROM dbo.TDSPMembership E
JOIN dbo.TDSPMember M ON M.CompanyID=E.CompanyID AND M.MemberID=E.MemberID
WHERE E.CompanyID=@co AND E.MemberID=@member
ORDER BY E.MembershipID DESC
""", ct, ("@co", Company), ("@member", memberId)));
    }

    [HttpPost("memberships")]
    public async Task<IActionResult> Enroll(SportEnrollmentInput input, CancellationToken ct)
    {
        if (input.MemberID <= 0 || input.PackageID <= 0 || input.IdempotencyKey == Guid.Empty
            || input.PaymentCode is not ("CASH" or "TRANSFER")
            || (input.PaymentCode == "TRANSFER" && string.IsNullOrWhiteSpace(input.PaymentReference)))
            return Invalid("ระบุสมาชิก แพ็กเกจ และข้อมูลรับเงินให้ครบ");
        await using var db = await Open(ct);
        if (await Guard(db, "54007", input.Renew ? "RENEW" : "CREATE", ct) is { } denied) return denied;
        if (await Guard(db, "54007", "RECORD_PAYMENT", ct) is { } payDenied) return payDenied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            var previous = await SportDb.Rows(db, tx, """
SELECT PaymentID,MembershipID FROM dbo.TDSPPayment
WHERE CompanyID=@co AND IdempotencyKey=@key
""", ct, ("@co", Company), ("@key", input.IdempotencyKey));
            if (previous.Count == 1)
            {
                await tx.CommitAsync(ct);
                return Ok(new { id = previous[0]["MembershipID"], paymentId = previous[0]["PaymentID"], repeated = true });
            }
            var rows = await SportDb.Rows(db, tx, """
SELECT M.MemberID,M.PersonID,P.PackageName,P.DurationDays,P.QuotaUnit,P.QuotaAmount,P.Price,
 L.RequiresResident
FROM dbo.TDSPMember M WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDADPerson Person ON Person.CompanyID=M.CompanyID AND Person.PersonID=M.PersonID AND Person.IsActive=1
JOIN dbo.TDSPMemberLevel L ON L.CompanyID=M.CompanyID AND L.LevelID=M.LevelID AND L.IsActive=1
JOIN dbo.TDSPPackage P ON P.CompanyID=M.CompanyID AND P.PackageID=@package AND P.IsActive=1
 AND (P.LevelID IS NULL OR P.LevelID=M.LevelID)
WHERE M.CompanyID=@co AND M.MemberID=@member AND M.IsActive=1
""", ct, ("@co", Company), ("@member", input.MemberID), ("@package", input.PackageID));
            if (rows.Count != 1)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "สมัครไม่ได้", description = "ตรวจสมาชิก ระดับสมาชิก และแพ็กเกจที่ยังใช้งาน" });
            }
            var personId = Convert.ToInt64(rows[0]["PersonID"]);
            if (Convert.ToBoolean(rows[0]["RequiresResident"]))
            {
                var resident = await SportDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDADResident
WHERE CompanyID=@co AND PersonID=@person AND IsActive=1
 AND (StartDate IS NULL OR StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (EndDate IS NULL OR EndDate>=CONVERT(date,SYSUTCDATETIME()))
""", ct, ("@co", Company), ("@person", personId));
                if (resident == 0)
                {
                    await tx.RollbackAsync(ct);
                    return Conflict(new { message = "ใช้ราคาผู้พักอาศัยไม่ได้", description = "ไม่พบสิทธิ์พักอาศัยที่ยังใช้งาน" });
                }
            }
            var sports = await SportDb.Rows(db, tx, """
SELECT S.SportCode FROM dbo.TDSPPackageSport X
JOIN dbo.TDSPSportType S ON S.CompanyID=X.CompanyID AND S.SportTypeID=X.SportTypeID AND S.IsActive=1
WHERE X.CompanyID=@co AND X.PackageID=@package ORDER BY S.SportCode
""", ct, ("@co", Company), ("@package", input.PackageID));
            if (sports.Count == 0)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "แพ็กเกจไม่มีชนิดกีฬา", description = "กำหนดประเภทกีฬาให้แพ็กเกจก่อนสมัคร" });
            }
            var start = input.StartsOn.ToDateTime(TimeOnly.MinValue);
            if (start.Date < DateTime.UtcNow.Date || start.Date > DateTime.UtcNow.Date.AddDays(365))
            {
                await tx.RollbackAsync(ct);
                return Invalid("วันเริ่มต้องอยู่ระหว่างวันนี้กับหนึ่งปีข้างหน้า");
            }
            var current = await SportDb.Rows(db, tx, """
SELECT MAX(EndsOn) EndsOn,
 SUM(CASE WHEN EndsOn>=CONVERT(date,SYSUTCDATETIME()) AND StatusCode=N'ACTIVE' THEN 1 ELSE 0 END) CurrentCount,
 COUNT(*) Total
FROM dbo.TDSPMembership WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND MemberID=@member AND StatusCode IN(N'ACTIVE',N'EXPIRED')
""", ct, ("@co", Company), ("@member", input.MemberID));
            var hasCurrent = Convert.ToInt32(current[0]["CurrentCount"]) > 0;
            if (input.Renew && Convert.ToInt32(current[0]["Total"]) == 0)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "ต่ออายุไม่ได้", description = "ไม่พบประวัติสมาชิกเดิม ให้สมัครใหม่" });
            }
            if (!input.Renew && hasCurrent)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "สมาชิกมีแพ็กเกจอยู่แล้ว", description = "ใช้คำสั่งต่ออายุเพื่อรักษาประวัติเดิม" });
            }
            if (input.Renew)
                start = new[] { start, ((DateTime)current[0]["EndsOn"]!).AddDays(1) }.Max();
            var duration = Convert.ToInt32(rows[0]["DurationDays"]);
            if (duration > 3650)
            {
                await tx.RollbackAsync(ct);
                return Invalid("ระยะเวลาแพ็กเกจต้องไม่เกิน 10 ปี");
            }
            var end = start.AddDays(duration - 1);
            var price = Convert.ToDecimal(rows[0]["Price"]);
            if (price <= 0)
            {
                await tx.RollbackAsync(ct);
                return Invalid("แพ็กเกจนี้ไม่มียอดรับเงิน กรุณาตรวจราคา");
            }
            var sportCodes = JsonSerializer.Serialize(
                sports.Select(s => Convert.ToString(s["SportCode"])!).ToArray());
            if (sportCodes.Length > 1000)
            {
                await tx.RollbackAsync(ct);
                return Invalid("แพ็กเกจยาวเกินขอบเขตที่รองรับ กรุณาตรวจประเภทกีฬาและระยะเวลา");
            }
            var membership = await SportDb.Id(db, tx, """
INSERT dbo.TDSPMembership(CompanyID,MemberID,PackageID,StartsOn,EndsOn,
 PackageNameSnapshot,SportCodesSnapshot,PriceSnapshot,QuotaUnitSnapshot,QuotaAmountSnapshot,StatusCode)
OUTPUT INSERTED.MembershipID
VALUES(@co,@member,@package,@start,@end,@name,@sports,@price,@unit,@quota,N'ACTIVE')
""", ct, ("@co", Company), ("@member", input.MemberID), ("@package", input.PackageID),
                ("@start", start), ("@end", end), ("@name", rows[0]["PackageName"]),
                ("@sports", sportCodes), ("@price", price),
                ("@unit", rows[0]["QuotaUnit"]), ("@quota", rows[0]["QuotaAmount"]));
            var payment = await SportDb.Id(db, tx, """
INSERT dbo.TDSPPayment(CompanyID,MembershipID,Amount,PaymentCode,PaymentReference,
 StatusCode,IdempotencyKey,CreatedBy)
OUTPUT INSERTED.PaymentID
VALUES(@co,@membership,@amount,@code,@reference,N'RECORDED',@key,@actor)
""", ct, ("@co", Company), ("@membership", membership), ("@amount", price),
                ("@code", input.PaymentCode), ("@reference", input.PaymentReference?.Trim()),
                ("@key", input.IdempotencyKey), ("@actor", Actor));
            await tx.CommitAsync(ct);
            return Ok(new { id = membership, paymentId = payment, startsOn = start.Date,
                endsOn = end.Date, price, sports = sportCodes });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627 or 1205)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new { message = "รายการสมัครเปลี่ยนแปลงหรือส่งซ้ำ",
                description = "ตรวจประวัติสมาชิกก่อนลองใหม่" });
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }
}

public sealed record SportEnrollmentInput(long MemberID,long PackageID,DateOnly StartsOn,
    bool Renew,string PaymentCode,string? PaymentReference,Guid IdempotencyKey);
