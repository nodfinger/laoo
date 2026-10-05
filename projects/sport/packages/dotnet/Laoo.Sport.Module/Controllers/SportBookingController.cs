using System.Data;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpGet("bookings")]
    public async Task<IActionResult> Bookings(DateTimeOffset from, DateTimeOffset to,
        long? facilityId, CancellationToken ct)
    {
        if (from == default || to <= from || (to - from).TotalDays > 31)
            return Invalid("เลือกช่วงเวลาไม่เกิน 31 วัน");
        await using var db = await Open(ct);
        if (await Guard(db, "54008", "VIEW", ct) is { } denied) return denied;
        var rows = await SportDb.Rows(db, null, """
SELECT B.BookingID id,B.FacilityID facilityId,F.FacilityName facility,
 B.MemberID memberId,P.FullName memberName,B.StartsAt startsAt,B.EndsAt endsAt,
 B.StatusCode status,B.PaymentDueAt paymentDueAt,B.PriceSnapshot price
FROM dbo.TDSPBooking B
JOIN dbo.TDSPFacility F ON F.CompanyID=B.CompanyID AND F.FacilityID=B.FacilityID
JOIN dbo.TDSPMember M ON M.CompanyID=B.CompanyID AND M.MemberID=B.MemberID
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID
WHERE B.CompanyID=@co AND B.StartsAt>=@from AND B.StartsAt<@to
 AND (@facility IS NULL OR B.FacilityID=@facility)
 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor AND UB.BranchID=B.BranchID AND UB.IsActive=1))
ORDER BY B.StartsAt,B.FacilityID
""", ct, ("@co", Company), ("@actor", Actor), ("@from", from.UtcDateTime),
            ("@to", to.UtcDateTime), ("@facility", facilityId));
        return Ok(rows);
    }

    [HttpPost("bookings")]
    public async Task<IActionResult> CreateBooking(SportBookingInput input, CancellationToken ct)
    {
        if (input.IdempotencyKey == Guid.Empty || input.StartsAt.Offset != TimeSpan.FromHours(7)
            || input.EndsAt.Offset != TimeSpan.FromHours(7)
            || input.StartsAt < DateTimeOffset.UtcNow || input.EndsAt <= input.StartsAt
            || (input.EndsAt - input.StartsAt).TotalHours > 8
            || input.StartsAt.Date != input.EndsAt.Date)
            return Invalid("ระบุวันเวลา +07:00 ในอนาคต ความยาวไม่เกิน 8 ชั่วโมงและอยู่ในวันเดียวกัน");
        await using var db = await Open(ct);
        if (await Guard(db, "54008", "CREATE", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            var existing = await SportDb.Id(db, tx,
                "SELECT COALESCE(MAX(BookingID),0) FROM dbo.TDSPBooking WHERE CompanyID=@co AND IdempotencyKey=@key",
                ct, ("@co", Company), ("@key", input.IdempotencyKey));
            if (existing > 0) { await tx.CommitAsync(ct); return Ok(new { id = existing, repeated = true }); }
            var now = DateTime.UtcNow;
            var settings = await SportDb.Rows(db, tx,
                "SELECT PaymentHoldMinutes FROM dbo.TDSPSetting WHERE CompanyID=@co",
                ct, ("@co", Company));
            var hold = settings.Count == 0 ? 30 : Convert.ToInt32(settings[0]["PaymentHoldMinutes"]);
            // The lock is per facility/day, so two overlapping requests cannot pass the availability check.
            var resource = "SPORT:" + Company + ":" + input.FacilityID + ":" + input.StartsAt.ToString("yyyyMMdd");
            var lockResult = await SportDb.Id(db, tx, """
DECLARE @result int;
EXEC @result=sp_getapplock @Resource=@resource,@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=5000;
SELECT @result;
""", ct, ("@resource", resource));
            if (lockResult < 0) { await tx.RollbackAsync(ct); return Conflict(new { message = "สนามกำลังถูกจอง", description = "ลองใหม่อีกครั้ง" }); }
            var facility = await SportDb.Rows(db, tx, """
SELECT F.BranchID,F.SportTypeID,S.SportCode
FROM dbo.TDSPFacility F
JOIN dbo.TDSPSportType S ON S.CompanyID=F.CompanyID AND S.SportTypeID=F.SportTypeID AND S.IsActive=1
WHERE F.CompanyID=@co AND F.FacilityID=@facility AND F.IsActive=1
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor AND UB.BranchID=F.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@facility", input.FacilityID), ("@actor", Actor));
            var member = await SportDb.Rows(db, tx, """
SELECT M.LevelID FROM dbo.TDSPMember M
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID AND P.IsActive=1
WHERE M.CompanyID=@co AND M.MemberID=@member AND M.IsActive=1
""", ct, ("@co", Company), ("@member", input.MemberID));
            if (facility.Count != 1 || member.Count != 1)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "จองไม่ได้", description = "สนามหรือสมาชิกไม่อยู่ในสาขา/บริษัทที่มีสิทธิ์" });
            }
            var sport = Convert.ToString(facility[0]["SportCode"])!;
            var hours = await SportDb.Rows(db, tx, """
SELECT OpensAt,ClosesAt FROM dbo.TDSPFacilityHours
WHERE CompanyID=@co AND FacilityID=@facility AND DayOfWeek=@day AND IsActive=1
""", ct, ("@co", Company), ("@facility", input.FacilityID), ("@day", (int)input.StartsAt.DayOfWeek));
            if (!hours.Any(h => (TimeSpan)h["OpensAt"]! <= input.StartsAt.TimeOfDay
                && (TimeSpan)h["ClosesAt"]! >= input.EndsAt.TimeOfDay))
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "สนามไม่เปิดในช่วงนี้", description = "เลือกเวลาภายในตารางเปิดสนาม" });
            }
            var blocked = await SportDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDSPFacilityBlock
WHERE CompanyID=@co AND FacilityID=@facility AND StartsAt<@end AND EndsAt>@start
""", ct, ("@co", Company), ("@facility", input.FacilityID),
                ("@start", input.StartsAt.UtcDateTime), ("@end", input.EndsAt.UtcDateTime));
            await SportDb.Execute(db, tx, """
UPDATE dbo.TDSPBooking SET StatusCode=N'EXPIRED'
WHERE CompanyID=@co AND FacilityID=@facility AND StatusCode=N'PENDING_PAYMENT'
 AND PaymentDueAt<SYSUTCDATETIME()
""", ct, ("@co", Company), ("@facility", input.FacilityID));
            await SportDb.Execute(db, tx, """
UPDATE U SET StatusCode=N'RELEASED',FinalizedAt=SYSUTCDATETIME()
FROM dbo.TDSPMembershipUse U
JOIN dbo.TDSPBooking B ON B.CompanyID=U.CompanyID AND B.BookingID=U.BookingID
WHERE U.CompanyID=@co AND B.FacilityID=@facility
 AND B.StatusCode=N'EXPIRED' AND U.StatusCode=N'RESERVED'
""", ct, ("@co", Company), ("@facility", input.FacilityID));
            var overlap = await SportDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDSPBooking WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND FacilityID=@facility
AND StatusCode IN(N'PENDING_PAYMENT',N'CONFIRMED',N'CHECKED_IN')
AND StartsAt<@end AND EndsAt>@start
""", ct, ("@co", Company), ("@facility", input.FacilityID),
                ("@start", input.StartsAt.UtcDateTime), ("@end", input.EndsAt.UtcDateTime));
            if (blocked > 0 || overlap > 0)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "ช่วงเวลานี้ไม่ว่าง", description = "เลือกสนามหรือเวลาอื่น" });
            }
            decimal price;
            decimal? reservedUnits = null;
            var status = "PENDING_PAYMENT";
            if (input.MembershipID is long membershipId)
            {
                var active = await SportDb.Rows(db, tx, """
SELECT QuotaUnitSnapshot,QuotaAmountSnapshot,SportCodesSnapshot
FROM dbo.TDSPMembership WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND MembershipID=@membership AND MemberID=@member
 AND StatusCode=N'ACTIVE' AND StartsOn<=@date AND EndsOn>=@date
""", ct, ("@co", Company), ("@membership", membershipId),
                    ("@member", input.MemberID), ("@date", input.StartsAt.Date));
                if (active.Count != 1)
                {
                    await tx.RollbackAsync(ct);
                    return Conflict(new { message = "แพ็กเกจใช้ไม่ได้", description = "ตรวจวันหมดอายุและสมาชิกของแพ็กเกจ" });
                }
                string[] sports;
                try { sports = JsonSerializer.Deserialize<string[]>(Convert.ToString(active[0]["SportCodesSnapshot"])!) ?? []; }
                catch (JsonException) { sports = []; }
                if (!sports.Contains(sport, StringComparer.OrdinalIgnoreCase))
                {
                    await tx.RollbackAsync(ct);
                    return Conflict(new { message = "แพ็กเกจไม่ครอบคลุมกีฬา", description = "เลือกแพ็กเกจหรือกีฬาอื่น" });
                }
                var unit = Convert.ToString(active[0]["QuotaUnitSnapshot"]);
                reservedUnits = unit == "HOUR"
                    ? Math.Ceiling((decimal)(input.EndsAt - input.StartsAt).TotalMinutes / 60m * 100m) / 100m
                    : 1m;
                if (unit != "UNLIMITED")
                {
                    var used = await SportDb.Rows(db, tx, """
SELECT COALESCE(SUM(Units),0) used FROM dbo.TDSPMembershipUse WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND MembershipID=@membership AND StatusCode IN(N'RESERVED',N'CONSUMED')
""", ct, ("@co", Company), ("@membership", membershipId));
                    var quota = Convert.ToDecimal(active[0]["QuotaAmountSnapshot"]);
                    if (Convert.ToDecimal(used[0]["used"]) + reservedUnits > quota)
                    {
                        await tx.RollbackAsync(ct);
                        return Conflict(new { message = "สิทธิ์คงเหลือไม่พอ", description = "เลือกแพ็กเกจอื่นหรือซื้อสิทธิ์เพิ่ม" });
                    }
                }
                price = 0m;
                status = "CONFIRMED";
            }
            else
            {
                if (input.DropInPackageID is null)
                {
                    await tx.RollbackAsync(ct);
                    return Invalid("ผู้เล่นรายครั้งต้องเลือกแพ็กเกจราคาต่อครั้ง");
                }
                var dropIn = await SportDb.Rows(db, tx, """
SELECT P.Price FROM dbo.TDSPPackage P
JOIN dbo.TDSPPackageSport X ON X.CompanyID=P.CompanyID AND X.PackageID=P.PackageID
WHERE P.CompanyID=@co AND P.PackageID=@package AND X.SportTypeID=@sport
AND P.IsActive=1 AND P.QuotaUnit=N'VISIT' AND P.QuotaAmount=1
AND (P.LevelID IS NULL OR P.LevelID=@level)
""", ct, ("@co", Company), ("@package", input.DropInPackageID),
                    ("@sport", facility[0]["SportTypeID"]), ("@level", member[0]["LevelID"]));
                if (dropIn.Count != 1)
                {
                    await tx.RollbackAsync(ct);
                    return Conflict(new { message = "ราคาต่อครั้งไม่พร้อม", description = "เลือกแพ็กเกจที่ใช้กับกีฬาและระดับสมาชิกนี้" });
                }
                price = Convert.ToDecimal(dropIn[0]["Price"]);
            }
            var due = status == "PENDING_PAYMENT" ? now.AddMinutes(hold) : (DateTime?)null;
            var bookingId = await SportDb.Id(db, tx, """
INSERT dbo.TDSPBooking(CompanyID,BranchID,FacilityID,MemberID,MembershipID,StartsAt,EndsAt,
 StatusCode,PaymentDueAt,PriceSnapshot,IdempotencyKey)
OUTPUT INSERTED.BookingID
VALUES(@co,@branch,@facility,@member,@membership,@start,@end,@status,@due,@price,@key)
""", ct, ("@co", Company), ("@branch", facility[0]["BranchID"]),
                ("@facility", input.FacilityID), ("@member", input.MemberID),
                ("@membership", input.MembershipID), ("@start", input.StartsAt.UtcDateTime),
                ("@end", input.EndsAt.UtcDateTime), ("@status", status), ("@due", due),
                ("@price", price), ("@key", input.IdempotencyKey));
            if (reservedUnits is decimal units)
                await SportDb.Execute(db, tx, """
INSERT dbo.TDSPMembershipUse(CompanyID,MembershipID,BookingID,Units,StatusCode)
VALUES(@co,@membership,@booking,@units,N'RESERVED')
""", ct, ("@co", Company), ("@membership", input.MembershipID),
                    ("@booking", bookingId), ("@units", units));
            await tx.CommitAsync(ct);
            return Ok(new { id = bookingId, status, paymentDueAt = due, price });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627 or 1205)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new { message = "รายการเปลี่ยนแปลงหรือส่งซ้ำ", description = "ตรวจรายการล่าสุดก่อนจองอีกครั้ง" });
        }
        catch
        {
            await tx.RollbackAsync(ct);
            throw;
        }
    }
}

public sealed record SportBookingInput(long FacilityID,long MemberID,long? MembershipID,
    long? DropInPackageID,DateTimeOffset StartsAt,DateTimeOffset EndsAt,Guid IdempotencyKey);
