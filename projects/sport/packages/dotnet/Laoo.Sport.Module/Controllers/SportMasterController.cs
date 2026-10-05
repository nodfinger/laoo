using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpPost("sport-types")]
    public async Task<IActionResult> AddSportType(SportTypeInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Code) || input.Code.Length > 30
            || string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 150)
            return Invalid("รหัสหรือชื่อประเภทกีฬาไม่ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "54002", "CREATE", ct) is { } denied) return denied;
        try
        {
            var id = await SportDb.Id(db, null, """
INSERT dbo.TDSPSportType(CompanyID,SportCode,SportName,IsActive)
OUTPUT INSERTED.SportTypeID VALUES(@co,@code,@name,1)
""", ct, ("@co", Company), ("@code", input.Code.Trim().ToUpperInvariant()),
                ("@name", input.Name.Trim()));
            return Ok(new { id });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627)
        { return Conflict(new { message = "รหัสประเภทกีฬาซ้ำ", description = "เปลี่ยนรหัสแล้วบันทึกใหม่" }); }
    }

    [HttpPut("sport-types/{id:long}")]
    public async Task<IActionResult> EditSportType(long id, SportTypeInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Code) || input.Code.Length > 30
            || string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 150)
            return Invalid("รหัสหรือชื่อประเภทกีฬาไม่ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "54002", "EDIT", ct) is { } denied) return denied;
        try
        {
            var affected = await SportDb.Execute(db, null, """
UPDATE dbo.TDSPSportType SET SportCode=@code,SportName=@name,IsActive=@active
WHERE CompanyID=@co AND SportTypeID=@id
""", ct, ("@co", Company), ("@id", id), ("@code", input.Code.Trim().ToUpperInvariant()),
                ("@name", input.Name.Trim()), ("@active", input.Active));
            return affected == 1 ? Ok(new { saved = true }) : NotFound(
                new { message = "ไม่พบประเภทกีฬา", description = "ตรวจรายการและลองใหม่" });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627)
        { return Conflict(new { message = "รหัสประเภทกีฬาซ้ำ", description = "เปลี่ยนรหัสแล้วบันทึกใหม่" }); }
    }

    [HttpDelete("sport-types/{id:long}")]
    public async Task<IActionResult> DeleteSportType(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54002", "DELETE", ct) is { } denied) return denied;
        var affected = await SportDb.Execute(db, null, """
DELETE FROM dbo.TDSPSportType
WHERE CompanyID=@co AND SportTypeID=@id
 AND NOT EXISTS(SELECT 1 FROM dbo.TDSPFacility WHERE CompanyID=@co AND SportTypeID=@id)
 AND NOT EXISTS(SELECT 1 FROM dbo.TDSPPackageSport WHERE CompanyID=@co AND SportTypeID=@id)
""", ct, ("@co", Company), ("@id", id));
        return affected == 1 ? Ok(new { deleted = true }) : Conflict(
            new { message = "ลบประเภทกีฬาไม่ได้", description = "มีสนามหรือแพ็กเกจใช้งานอยู่ ให้ปิดสถานะแทน" });
    }

    [HttpPost("levels")]
    public async Task<IActionResult> AddLevel(SportLevelInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Code) || input.Code.Length > 30
            || string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 150)
            return Invalid("รหัสหรือชื่อระดับสมาชิกไม่ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "54004", "CREATE", ct) is { } denied) return denied;
        try
        {
            var id = await SportDb.Id(db, null, """
INSERT dbo.TDSPMemberLevel(CompanyID,LevelCode,LevelName,RequiresResident,IsActive)
OUTPUT INSERTED.LevelID VALUES(@co,@code,@name,@resident,1)
""", ct, ("@co", Company), ("@code", input.Code.Trim().ToUpperInvariant()),
                ("@name", input.Name.Trim()), ("@resident", input.RequiresResident));
            return Ok(new { id });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627)
        { return Conflict(new { message = "รหัสระดับสมาชิกซ้ำ", description = "เปลี่ยนรหัสแล้วบันทึกใหม่" }); }
    }

    [HttpPut("levels/{id:long}")]
    public async Task<IActionResult> EditLevel(long id, SportLevelInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Code) || input.Code.Length > 30
            || string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 150)
            return Invalid("รหัสหรือชื่อระดับสมาชิกไม่ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "54004", "EDIT", ct) is { } denied) return denied;
        try
        {
            var affected = await SportDb.Execute(db, null, """
UPDATE dbo.TDSPMemberLevel SET LevelCode=@code,LevelName=@name,
 RequiresResident=@resident,IsActive=@active
WHERE CompanyID=@co AND LevelID=@id
""", ct, ("@co", Company), ("@id", id), ("@code", input.Code.Trim().ToUpperInvariant()),
                ("@name", input.Name.Trim()), ("@resident", input.RequiresResident),
                ("@active", input.Active));
            return affected == 1 ? Ok(new { saved = true }) : NotFound(
                new { message = "ไม่พบระดับสมาชิก", description = "ตรวจรายการและลองใหม่" });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627)
        { return Conflict(new { message = "รหัสระดับสมาชิกซ้ำ", description = "เปลี่ยนรหัสแล้วบันทึกใหม่" }); }
    }

    [HttpDelete("levels/{id:long}")]
    public async Task<IActionResult> DeleteLevel(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54004", "DELETE", ct) is { } denied) return denied;
        var affected = await SportDb.Execute(db, null, """
DELETE FROM dbo.TDSPMemberLevel WHERE CompanyID=@co AND LevelID=@id
 AND NOT EXISTS(SELECT 1 FROM dbo.TDSPMember WHERE CompanyID=@co AND LevelID=@id)
 AND NOT EXISTS(SELECT 1 FROM dbo.TDSPPackage WHERE CompanyID=@co AND LevelID=@id)
 AND NOT EXISTS(SELECT 1 FROM dbo.TDSPPosPriceRule WHERE CompanyID=@co AND LevelID=@id)
""", ct, ("@co", Company), ("@id", id));
        return affected == 1 ? Ok(new { deleted = true }) : Conflict(
            new { message = "ลบระดับสมาชิกไม่ได้", description = "มีสมาชิก แพ็กเกจ หรือกฎราคาใช้งานอยู่ ให้ปิดสถานะแทน" });
    }
}

public sealed record SportTypeInput(string Code,string Name,bool Active = true);
public sealed record SportLevelInput(string Code,string Name,bool RequiresResident,bool Active = true);
