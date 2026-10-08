using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
namespace Laoo.DigitalChecklist.Controllers;

public sealed partial class DigitalChecklistController
{
    [HttpPost("schedules")]
    public async Task<IActionResult> CreateScheduleConfigured(MasterInput input, CancellationToken ct)
    {
        if (input.ParentId is null || string.IsNullOrWhiteSpace(input.Name) || input.Frequency is not ("DAILY" or "WEEKLY" or "MONTHLY" or "YEARLY"))
            return BadRequest(new { message = "เลือกประเภท ชื่อแผน และความถี่ตรวจให้ครบ" });
        List<string> times;
        List<int> weekdays;
        try
        {
            times = JsonSerializer.Deserialize<List<string>>(input.TimesJson ?? "[]") ?? [];
            weekdays = JsonSerializer.Deserialize<List<int>>(input.WeekDaysJson ?? "[1]") ?? [1];
        }
        catch (JsonException) { return BadRequest(new { message = "รูปแบบเวลา/วันตรวจไม่ถูกต้อง" }); }
        if (times.Count is < 1 or > 12 || times.Any(x => !TimeOnly.TryParse(x, out _)) || times.Distinct().Count() != times.Count)
            return BadRequest(new { message = "กำหนดเวลาตรวจที่ไม่ซ้ำกัน 1–12 เวลา" });
        if (weekdays.Count == 0 || weekdays.Any(x => x is < 1 or > 7) || weekdays.Distinct().Count() != weekdays.Count)
            return BadRequest(new { message = "วันในสัปดาห์ใช้เลข 1–7 และห้ามซ้ำ" });
        await using var db = await Open(ct);
        if (await Guard(db, "58005", "CREATE", ct) is { } denied) return denied;
        var department = await Department(db, ct);
        var admin = await Admin(db, ct);
        const string sql = """
            BEGIN TRY BEGIN TRAN;
            DECLARE @type bigint=@requestedType,@template bigint,@workflow bigint,@employee bigint,@targetDep bigint;
            SELECT @targetDep=G.DepartmentOrgUnitID FROM dbo.TDCLType T JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID
              WHERE T.CompanyID=@co AND T.TypeID=@type AND T.IsActive=1 AND G.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep);
            IF @targetDep IS NULL THROW 58014,'Type unavailable for department',1;
            SELECT TOP(1) @template=TemplateID FROM dbo.TDCLTemplate WHERE CompanyID=@co AND TypeID=@type AND IsActive=1 ORDER BY TemplateID DESC;
            SELECT TOP(1) @workflow=WorkflowID FROM dbo.TDCLWorkflow WHERE CompanyID=@co AND TypeID=@type AND IsActive=1 ORDER BY WorkflowID DESC;
            SELECT TOP(1) @employee=E.EmployeeID FROM dbo.TDADEmployee E
              JOIN dbo.TDADEmployeeOrganizationAssignment A ON A.CompanyID=E.CompanyID AND A.EmployeeID=E.EmployeeID AND A.DepartmentOrgUnitID=@targetDep AND A.IsActive=1
                AND A.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time')
                AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=CONVERT(date,SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time'))
              JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=E.CompanyID AND UE.EmployeeID=E.EmployeeID AND UE.IsActive=1
              JOIN dbo.TDADUser U ON U.CompanyID=UE.CompanyID AND U.UserID=UE.UserID AND U.IsActive=1
              WHERE E.CompanyID=@co AND E.IsActive=1 AND E.EmployeeID=COALESCE(@requestedEmployee,
                (SELECT TOP(1) EmployeeID FROM dbo.TDADUserEmployee WHERE CompanyID=@co AND UserID=@actor AND IsActive=1));
            IF @template IS NULL OR @workflow IS NULL OR @employee IS NULL THROW 58020,'Template, approval workflow, or eligible responsible employee missing',1;
            INSERT dbo.TDCLSchedule(CompanyID,TypeID,TemplateID,WorkflowID,ScheduleName,FrequencyCode,TimesJson,WeekDaysJson,MonthDay,YearMonth,ResponsibleEmployeeID,StartsOn)
            VALUES(@co,@type,@template,@workflow,@name,@frequency,@times,@weekdays,DAY(CONVERT(date,SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time')),MONTH(CONVERT(date,SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time')),@employee,CONVERT(date,SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time'));
            DECLARE @id bigint=SCOPE_IDENTITY();
            INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail) VALUES(@co,@actor,'CREATE','SCHEDULE',@id,@name);
            COMMIT; SELECT @id; END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH
            """;
        var id = await DigitalChecklistDb.Id(db, sql, ct, ("@co", Company), ("@requestedType", input.ParentId), ("@requestedEmployee", input.ResponsibleEmployeeId), ("@admin", admin), ("@dep", department), ("@actor", Actor), ("@name", input.Name.Trim()), ("@frequency", input.Frequency), ("@times", JsonSerializer.Serialize(times)), ("@weekdays", JsonSerializer.Serialize(weekdays)));
        return Ok(new { id });
    }
}
