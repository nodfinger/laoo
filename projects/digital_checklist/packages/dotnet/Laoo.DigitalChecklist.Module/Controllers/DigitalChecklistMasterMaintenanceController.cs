using Microsoft.AspNetCore.Mvc;
namespace Laoo.DigitalChecklist.Controllers;

public sealed partial class DigitalChecklistController
{
    [HttpPut("masters/{entity}/{id:long}")]
    public async Task<IActionResult> UpdateMaster(string entity, long id, MasterInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 150 || input.Code is { Length: > 30 })
            return BadRequest(new { message = "กรุณาตรวจรหัสและชื่อ" });
        await using var db = await Open(ct);
        var menu = entity.ToUpperInvariant() switch { "GROUP" or "TYPE" => "58002", "TEMPLATE" => "58003", "WORKFLOW" => "58004", "SCHEDULE" => "58005", _ => "" };
        if (menu.Length == 0) return BadRequest();
        if (await Guard(db, menu, "EDIT", ct) is { } denied) return denied;
        var department = await Department(db, ct);
        var admin = await Admin(db, ct);
        var update = entity.ToUpperInvariant() switch
        {
            "GROUP" => "UPDATE G SET GroupCode=COALESCE(@code,G.GroupCode),GroupName=@name OUTPUT INSERTED.GroupID FROM dbo.TDCLGroup G WHERE G.CompanyID=@co AND G.GroupID=@id AND G.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep)",
            "TYPE" => "UPDATE T SET TypeCode=COALESCE(@code,T.TypeCode),TypeName=@name OUTPUT INSERTED.TypeID FROM dbo.TDCLType T JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID WHERE T.CompanyID=@co AND T.TypeID=@id AND T.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep)",
            "TEMPLATE" => "UPDATE V SET TemplateCode=COALESCE(@code,V.TemplateCode),TemplateName=@name OUTPUT INSERTED.TemplateID FROM dbo.TDCLTemplate V JOIN dbo.TDCLType T ON T.CompanyID=V.CompanyID AND T.TypeID=V.TypeID JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID WHERE V.CompanyID=@co AND V.TemplateID=@id AND V.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep)",
            "WORKFLOW" => "UPDATE W SET WorkflowName=@name OUTPUT INSERTED.WorkflowID FROM dbo.TDCLWorkflow W JOIN dbo.TDCLType T ON T.CompanyID=W.CompanyID AND T.TypeID=W.TypeID JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID WHERE W.CompanyID=@co AND W.WorkflowID=@id AND W.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep)",
            "SCHEDULE" => "UPDATE S SET ScheduleName=@name,FrequencyCode=COALESCE(@freq,S.FrequencyCode),TimesJson=COALESCE(@times,S.TimesJson),WeekDaysJson=COALESCE(@days,S.WeekDaysJson) OUTPUT INSERTED.ScheduleID FROM dbo.TDCLSchedule S JOIN dbo.TDCLType T ON T.CompanyID=S.CompanyID AND T.TypeID=S.TypeID JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID WHERE S.CompanyID=@co AND S.ScheduleID=@id AND S.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep)",
            _ => throw new InvalidOperationException()
        };
        if (entity.Equals("SCHEDULE", StringComparison.OrdinalIgnoreCase))
        {
            if (input.Frequency is not null and not ("DAILY" or "WEEKLY" or "MONTHLY" or "YEARLY")) return BadRequest(new { message = "ความถี่ไม่ถูกต้อง" });
            if (input.TimesJson is not null)
            {
                try { var times = System.Text.Json.JsonSerializer.Deserialize<List<string>>(input.TimesJson) ?? []; if (times.Count is < 1 or > 12 || times.Any(x => !TimeOnly.TryParse(x, out _)) || times.Distinct().Count() != times.Count) return BadRequest(new { message = "ช่วงเวลาตรวจไม่ถูกต้อง" }); input = input with { TimesJson = System.Text.Json.JsonSerializer.Serialize(times) }; }
                catch (System.Text.Json.JsonException) { return BadRequest(new { message = "รูปแบบเวลาตรวจไม่ถูกต้อง" }); }
            }
        }
        var changed = await DigitalChecklistDb.Id(db, update, ct, ("@co", Company), ("@id", id), ("@admin", admin), ("@dep", department), ("@code", (object?)input.Code ?? DBNull.Value), ("@name", input.Name.Trim()), ("@freq", (object?)input.Frequency ?? DBNull.Value), ("@times", (object?)input.TimesJson ?? DBNull.Value), ("@days", (object?)input.WeekDaysJson ?? DBNull.Value));
        if (changed == 0) return NotFound();
        await DigitalChecklistDb.Id(db, "INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail) VALUES(@co,@actor,'EDIT',@entity,@id,@detail); SELECT @id", ct, ("@co", Company), ("@actor", Actor), ("@entity", entity.ToUpperInvariant()), ("@id", id), ("@detail", input.Name.Trim()));
        return Ok(new { id, updated = true });
    }

    [HttpDelete("masters/{entity}/{id:long}")]
    public async Task<IActionResult> DeactivateMaster(string entity, long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        var normalized = entity.ToUpperInvariant();
        var menu = normalized switch { "GROUP" or "TYPE" => "58002", "TEMPLATE" => "58003", "WORKFLOW" => "58004", "SCHEDULE" => "58005", _ => "" };
        if (menu.Length == 0) return BadRequest();
        if (await Guard(db, menu, "DELETE", ct) is { } denied) return denied;
        var department = await Department(db, ct);
        var admin = await Admin(db, ct);
        var sql = normalized switch
        {
            "GROUP" => "UPDATE G SET IsActive=0 OUTPUT INSERTED.GroupID FROM dbo.TDCLGroup G WHERE G.CompanyID=@co AND G.GroupID=@id AND G.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep)",
            "TYPE" => "UPDATE T SET IsActive=0 OUTPUT INSERTED.TypeID FROM dbo.TDCLType T JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID WHERE T.CompanyID=@co AND T.TypeID=@id AND T.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep)",
            "TEMPLATE" => "UPDATE V SET IsActive=0 OUTPUT INSERTED.TemplateID FROM dbo.TDCLTemplate V JOIN dbo.TDCLType T ON T.CompanyID=V.CompanyID AND T.TypeID=V.TypeID JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID WHERE V.CompanyID=@co AND V.TemplateID=@id AND V.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep)",
            "WORKFLOW" => "UPDATE W SET IsActive=0 OUTPUT INSERTED.WorkflowID FROM dbo.TDCLWorkflow W JOIN dbo.TDCLType T ON T.CompanyID=W.CompanyID AND T.TypeID=W.TypeID JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID WHERE W.CompanyID=@co AND W.WorkflowID=@id AND W.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep)",
            "SCHEDULE" => "UPDATE S SET IsActive=0 OUTPUT INSERTED.ScheduleID FROM dbo.TDCLSchedule S JOIN dbo.TDCLType T ON T.CompanyID=S.CompanyID AND T.TypeID=S.TypeID JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID WHERE S.CompanyID=@co AND S.ScheduleID=@id AND S.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep)",
            _ => throw new InvalidOperationException()
        };
        var changed = await DigitalChecklistDb.Id(db, sql, ct, ("@co", Company), ("@id", id), ("@admin", admin), ("@dep", department));
        if (changed == 0) return NotFound();
        await DigitalChecklistDb.Id(db, "INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail) VALUES(@co,@actor,'DEACTIVATE',@entity,@id,N'Soft delete'); SELECT @id", ct, ("@co", Company), ("@actor", Actor), ("@entity", normalized), ("@id", id));
        return Ok(new { id, deactivated = true });
    }
}
