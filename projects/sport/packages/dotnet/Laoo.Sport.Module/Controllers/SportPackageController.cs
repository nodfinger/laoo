using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpPost("packages")]
    public Task<IActionResult> AddPackage(SportPackageInput input, CancellationToken ct) =>
        SavePackage(null, input, ct);

    [HttpPut("packages/{id:long}")]
    public Task<IActionResult> EditPackage(long id, SportPackageInput input, CancellationToken ct) =>
        SavePackage(id, input, ct);

    private async Task<IActionResult> SavePackage(long? id, SportPackageInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Code) || input.Code.Length > 30
            || string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 150
            || input.DurationDays is < 1 or > 3650 || input.Price < 0
            || input.QuotaUnit is not ("VISIT" or "HOUR" or "UNLIMITED")
            || (input.QuotaUnit == "UNLIMITED" ? input.QuotaAmount is not null : input.QuotaAmount is null or <= 0)
            || input.SportTypeIDs is null or { Length: 0 or > 30 }
            || input.SportTypeIDs.Distinct().Count() != input.SportTypeIDs.Length)
            return Invalid("ข้อมูลแพ็กเกจ กีฬา ราคา หรือโควตาไม่ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "54005", id is null ? "CREATE" : "EDIT", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            if (input.LevelID is long levelId && await SportDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDSPMemberLevel
WHERE CompanyID=@co AND LevelID=@level AND IsActive=1
""", ct, ("@co", Company), ("@level", levelId)) != 1)
            {
                await tx.RollbackAsync(ct);
                return Invalid("ระดับสมาชิกไม่อยู่ในบริษัทนี้หรือไม่เปิดใช้งาน");
            }
            var validSports = await SportDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDSPSportType
WHERE CompanyID=@co AND IsActive=1 AND SportTypeID IN
(SELECT TRY_CONVERT(bigint,value) FROM OPENJSON(@ids))
""", ct, ("@co", Company), ("@ids", System.Text.Json.JsonSerializer.Serialize(input.SportTypeIDs)));
            if (validSports != input.SportTypeIDs.Length)
            {
                await tx.RollbackAsync(ct);
                return Invalid("ประเภทกีฬาบางรายการไม่อยู่ในบริษัทนี้หรือไม่เปิดใช้งาน");
            }
            long packageId;
            if (id is null)
                packageId = await SportDb.Id(db, tx, """
INSERT dbo.TDSPPackage(CompanyID,PackageCode,PackageName,LevelID,DurationDays,
 QuotaUnit,QuotaAmount,Price,IsActive)
OUTPUT INSERTED.PackageID
VALUES(@co,@code,@name,@level,@days,@unit,@quota,@price,@active)
""", ct, ("@co", Company), ("@code", input.Code.Trim().ToUpperInvariant()),
                    ("@name", input.Name.Trim()), ("@level", input.LevelID), ("@days", input.DurationDays),
                    ("@unit", input.QuotaUnit), ("@quota", input.QuotaAmount),
                    ("@price", input.Price), ("@active", input.Active));
            else
            {
                packageId = id.Value;
                var updated = await SportDb.Execute(db, tx, """
UPDATE dbo.TDSPPackage SET PackageCode=@code,PackageName=@name,LevelID=@level,
 DurationDays=@days,QuotaUnit=@unit,QuotaAmount=@quota,Price=@price,IsActive=@active
WHERE CompanyID=@co AND PackageID=@id
""", ct, ("@co", Company), ("@id", packageId),
                    ("@code", input.Code.Trim().ToUpperInvariant()), ("@name", input.Name.Trim()),
                    ("@level", input.LevelID), ("@days", input.DurationDays), ("@unit", input.QuotaUnit),
                    ("@quota", input.QuotaAmount), ("@price", input.Price), ("@active", input.Active));
                if (updated != 1)
                {
                    await tx.RollbackAsync(ct);
                    return NotFound(new { message = "ไม่พบแพ็กเกจ", description = "ตรวจรายการและลองใหม่" });
                }
                await SportDb.Execute(db, tx, """
DELETE FROM dbo.TDSPPackageSport WHERE CompanyID=@co AND PackageID=@id
""", ct, ("@co", Company), ("@id", packageId));
            }
            foreach (var sportId in input.SportTypeIDs)
                await SportDb.Execute(db, tx, """
INSERT dbo.TDSPPackageSport(CompanyID,PackageID,SportTypeID)
VALUES(@co,@package,@sport)
""", ct, ("@co", Company), ("@package", packageId), ("@sport", sportId));
            await tx.CommitAsync(ct);
            return Ok(new { id = packageId, saved = true });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627 or 1205)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new { message = "แพ็กเกจซ้ำหรือข้อมูลเปลี่ยน",
                description = "ตรวจรหัสแพ็กเกจแล้วลองใหม่" });
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }

    [HttpDelete("packages/{id:long}")]
    public async Task<IActionResult> DeletePackage(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54005", "DELETE", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            var referenced = await SportDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDSPMembership WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND PackageID=@id
""", ct, ("@co", Company), ("@id", id));
            if (referenced > 0)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "ลบแพ็กเกจไม่ได้",
                    description = "มีประวัติสมัครแล้ว ให้ปิดสถานะแทน" });
            }
            await SportDb.Execute(db, tx, """
DELETE FROM dbo.TDSPPackageSport WHERE CompanyID=@co AND PackageID=@id
""", ct, ("@co", Company), ("@id", id));
            var affected = await SportDb.Execute(db, tx, """
DELETE FROM dbo.TDSPPackage WHERE CompanyID=@co AND PackageID=@id
""", ct, ("@co", Company), ("@id", id));
            await tx.CommitAsync(ct);
            return affected == 1 ? Ok(new { deleted = true }) : NotFound(
                new { message = "ไม่พบแพ็กเกจ", description = "ตรวจรายการและลองใหม่" });
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }
}

public sealed record SportPackageInput(string Code,string Name,long? LevelID,int DurationDays,
    string QuotaUnit,decimal? QuotaAmount,decimal Price,long[] SportTypeIDs,bool Active = true);
