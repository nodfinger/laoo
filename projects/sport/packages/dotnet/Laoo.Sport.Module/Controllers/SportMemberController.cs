using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpPost("members")]
    public async Task<IActionResult> AddMember(SportMemberInput input, CancellationToken ct)
    {
        if (!ValidMember(input)) return Invalid("รหัสสมาชิก ระดับสมาชิก เพศ หรือวันเกิดไม่ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "54006", "CREATE", ct) is { } denied) return denied;
        var valid = await SportDb.Id(db, null, """
SELECT COUNT(*) FROM dbo.TDADPerson P
JOIN dbo.TDSPMemberLevel L ON L.CompanyID=P.CompanyID AND L.LevelID=@level AND L.IsActive=1
WHERE P.CompanyID=@co AND P.PersonID=@person AND P.IsActive=1
""", ct, ("@co", Company), ("@person", input.PersonID), ("@level", input.LevelID));
        if (valid != 1) return Conflict(new { message = "เพิ่มสมาชิกไม่ได้",
            description = "เลือกบุคคลและระดับสมาชิกที่ใช้งานในบริษัทเดียวกัน" });
        try
        {
            var id = await SportDb.Id(db, null, """
INSERT dbo.TDSPMember(CompanyID,PersonID,MemberCode,LevelID,BirthDate,GenderCode,IsActive)
OUTPUT INSERTED.MemberID VALUES(@co,@person,@code,@level,@birth,@gender,1)
""", ct, ("@co", Company), ("@person", input.PersonID),
                ("@code", input.Code.Trim().ToUpperInvariant()), ("@level", input.LevelID),
                ("@birth", input.BirthDate?.ToDateTime(TimeOnly.MinValue)), ("@gender", input.GenderCode));
            return Ok(new { id });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627)
        { return Conflict(new { message = "สมาชิกซ้ำ", description = "บุคคลหรือรหัสนี้เป็นสมาชิกอยู่แล้ว" }); }
    }

    [HttpPut("members/{id:long}")]
    public async Task<IActionResult> EditMember(long id, SportMemberInput input, CancellationToken ct)
    {
        if (!ValidMember(input)) return Invalid("รหัสสมาชิก ระดับสมาชิก เพศ หรือวันเกิดไม่ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "54006", "EDIT", ct) is { } denied) return denied;
        try
        {
            var affected = await SportDb.Execute(db, null, """
UPDATE M SET MemberCode=@code,LevelID=@level,BirthDate=@birth,
 GenderCode=@gender,IsActive=@active
FROM dbo.TDSPMember M
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID AND P.IsActive=1
JOIN dbo.TDSPMemberLevel L ON L.CompanyID=M.CompanyID AND L.LevelID=@level AND L.IsActive=1
WHERE M.CompanyID=@co AND M.MemberID=@id AND M.PersonID=@person
""", ct, ("@co", Company), ("@id", id), ("@person", input.PersonID),
                ("@code", input.Code.Trim().ToUpperInvariant()), ("@level", input.LevelID),
                ("@birth", input.BirthDate?.ToDateTime(TimeOnly.MinValue)), ("@gender", input.GenderCode),
                ("@active", input.Active));
            return affected == 1 ? Ok(new { saved = true }) : Conflict(
                new { message = "แก้สมาชิกไม่ได้", description = "ตรวจบุคคล ระดับ และบริษัทของสมาชิก" });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627)
        { return Conflict(new { message = "รหัสสมาชิกซ้ำ", description = "เปลี่ยนรหัสแล้วบันทึกใหม่" }); }
    }

    private static bool ValidMember(SportMemberInput v) =>
        v.PersonID > 0 && v.LevelID > 0 && !string.IsNullOrWhiteSpace(v.Code)
        && v.Code.Length <= 30
        && (v.GenderCode is null or "MALE" or "FEMALE" or "OTHER" or "UNSPECIFIED")
        && (v.BirthDate is null || v.BirthDate.Value <= DateOnly.FromDateTime(DateTime.UtcNow));
}

public sealed record SportMemberInput(long PersonID,string Code,long LevelID,
    DateOnly? BirthDate,string? GenderCode,bool Active = true);
