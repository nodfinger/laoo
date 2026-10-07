using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Patrol.Controllers;

public sealed partial class PatrolController
{
    [HttpGet("routes")]
    public async Task<IActionResult> Routes(CancellationToken ct) => await List("56006", "SELECT R.RouteID id,R.BranchID branchId,R.RouteCode code,R.RouteName name,B.BranchNameTH branch,R.WorkType workType,R.SequenceMode sequenceMode,(SELECT COUNT(*) FROM dbo.TDPCRouteCheckpoint X WHERE X.CompanyID=R.CompanyID AND X.RouteID=R.RouteID) checkpointCount,(SELECT STRING_AGG(CONVERT(nvarchar(20),X.CheckpointID),',') FROM dbo.TDPCRouteCheckpoint X WHERE X.CompanyID=R.CompanyID AND X.RouteID=R.RouteID) checkpointIds, (SELECT X.CheckpointID checkpointId,X.TimeMode timeMode,CONVERT(varchar(5),X.WindowStart,108) windowStart,CONVERT(varchar(5),X.WindowEnd,108) windowEnd,X.GraceBeforeMinutes graceBefore,X.GraceAfterMinutes graceAfter,X.ChecklistTemplateID checklistTemplateId FROM dbo.TDPCRouteCheckpoint X WHERE X.CompanyID=R.CompanyID AND X.RouteID=R.RouteID ORDER BY X.SequenceNo FOR JSON PATH) pointsJson,R.IsActive isActive FROM dbo.TDPCRoute R JOIN dbo.TDADBranch B ON B.CompanyID=R.CompanyID AND B.BranchID=R.BranchID WHERE R.CompanyID=@co ORDER BY R.RouteID DESC", ct);

    [HttpPost("routes")]
    public async Task<IActionResult> AddRoute(RouteInput x, CancellationToken ct)
    {
        if (!ValidRoute(x)) return Invalid("กรุณาตรวจรหัส ชื่อ ประเภทงาน และจุดตรวจ");
        await using var db = await Open(ct); if (await Guard(db, "56006", "CREATE", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            if (!await ValidateRouteReferences(db, tx, x, ct)) { await tx.RollbackAsync(ct); return Invalid("สาขา จุดตรวจ หรือ Checklist ต้องอยู่ในบริษัทเดียวกันและเปิดใช้งาน"); }
            var id = await InsertRoute(db, tx, x, ct); await Audit(db, tx, "CREATE", "ROUTE", id, x.Code, ct); await tx.CommitAsync(ct); return Ok(new { id });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { await tx.RollbackAsync(ct); return Conflict(new { message = "รหัสเส้นทางซ้ำ", description = "เปลี่ยนรหัสเส้นทางให้ไม่ซ้ำในบริษัท" }); }
        catch { await tx.RollbackAsync(ct); throw; }
    }

    [HttpPut("routes/{id:long}")]
    public async Task<IActionResult> EditRoute(long id, RouteInput x, CancellationToken ct)
    {
        if (!ValidRoute(x)) return Invalid("กรุณาตรวจรหัส ชื่อ ประเภทงาน และจุดตรวจ");
        await using var db = await Open(ct); if (await Guard(db, "56006", "EDIT", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            if (!await ValidateRouteReferences(db, tx, x, ct)) { await tx.RollbackAsync(ct); return Invalid("สาขา จุดตรวจ หรือ Checklist ต้องอยู่ในบริษัทเดียวกันและเปิดใช้งาน"); }
            var changed = await PatrolDb.Execute(db, tx, "UPDATE dbo.TDPCRoute SET BranchID=@branch,RouteCode=@code,RouteName=@name,WorkType=@work,SequenceMode=@mode,IsActive=@active WHERE CompanyID=@co AND RouteID=@id", ct, ("@co", Company), ("@id", id), ("@branch", x.BranchId), ("@code", x.Code.Trim()), ("@name", x.Name.Trim()), ("@work", x.WorkType), ("@mode", x.SequenceMode), ("@active", x.Active));
            if (changed == 0) { await tx.RollbackAsync(ct); return NotFound(new { message = "ไม่พบเส้นทางตรวจ", description = "โหลดรายการใหม่แล้วเลือกเส้นทางที่ยังมีอยู่" }); }
            await PatrolDb.Execute(db, tx, "DELETE dbo.TDPCRouteCheckpoint WHERE CompanyID=@co AND RouteID=@id", ct, ("@co", Company), ("@id", id));
            await InsertRoutePoints(db, tx, id, x.Points, ct); await Audit(db, tx, "EDIT", "ROUTE", id, x.Code, ct); await tx.CommitAsync(ct); return Ok(new { saved = true });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { await tx.RollbackAsync(ct); return Conflict(new { message = "รหัสเส้นทางซ้ำ", description = "เปลี่ยนรหัสเส้นทางให้ไม่ซ้ำในบริษัท" }); }
        catch { await tx.RollbackAsync(ct); throw; }
    }

    [HttpDelete("routes/{id:long}")]
    public async Task<IActionResult> DeleteRoute(long id, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56006", "DELETE", ct) is { } denied) return denied;
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDPCSchedule WHERE CompanyID=@co AND RouteID=@id", ct, ("@co", Company), ("@id", id)) > 0) return Conflict(new { message = "เส้นทางมีประวัติหรือมีตารางตรวจ", description = "เก็บเส้นทางไว้เพื่อรักษาประวัติ และปิดใช้งานได้หลังยกเลิกตารางตรวจที่เกี่ยวข้อง" });
        var changed = await PatrolDb.Execute(db, null, "UPDATE dbo.TDPCRoute SET IsActive=0 WHERE CompanyID=@co AND RouteID=@id AND IsActive=1", ct, ("@co", Company), ("@id", id));
        if (changed == 0) return NotFound(new { message = "ไม่พบเส้นทางตรวจ", description = "โหลดรายการใหม่แล้วลองอีกครั้ง" });
        await Audit(db, null, "DEACTIVATE", "ROUTE", id, null, ct); return Ok(new { deactivated = true });
    }

    [HttpGet("schedules")]
    public async Task<IActionResult> Schedules(CancellationToken ct) => await List("56007", "SELECT S.ScheduleID id,S.RouteID routeId,S.ScheduleCode code,S.ScheduleName name,R.RouteName route,S.StartsAt,S.EndsAt,S.AssignedEmployeeID employeeId,E.FullName employee,S.AssignedTeamCode team,S.StatusCode status FROM dbo.TDPCSchedule S JOIN dbo.TDPCRoute R ON R.CompanyID=S.CompanyID AND R.RouteID=S.RouteID LEFT JOIN dbo.TDADEmployee E ON E.CompanyID=S.CompanyID AND E.EmployeeID=S.AssignedEmployeeID WHERE S.CompanyID=@co ORDER BY S.StartsAt DESC", ct);

    [HttpPost("schedules")]
    public async Task<IActionResult> AddSchedule(ScheduleInput x, CancellationToken ct)
    {
        if (!ValidSchedule(x)) return Invalid("กรุณาตรวจรหัส ชื่อ เวลา และผู้รับผิดชอบ");
        await using var db = await Open(ct); if (await Guard(db, "56007", "CREATE", ct) is { } denied) return denied;
        if (!await ValidateScheduleReferences(db, x, ct)) return Invalid("เส้นทางหรือพนักงานต้องอยู่ในบริษัทเดียวกันและเปิดใช้งาน");
        if (await HasScheduleOverlap(db, x, null, ct)) return Conflict(new { message = "ตารางตรวจซ้อนเวลา", description = "พนักงานหรือทีมมีรอบตรวจอื่นในช่วงเวลานี้แล้ว" });
        try
        {
            var id = await PatrolDb.Id(db, null, "INSERT dbo.TDPCSchedule(CompanyID,RouteID,ScheduleCode,ScheduleName,StartsAt,EndsAt,AssignedEmployeeID,AssignedTeamCode,CreatedBy) OUTPUT INSERTED.ScheduleID VALUES(@co,@route,@code,@name,@from,@to,@employee,@team,@actor)", ct, ("@co", Company), ("@route", x.RouteId), ("@code", x.Code.Trim()), ("@name", x.Name.Trim()), ("@from", x.StartsAt), ("@to", x.EndsAt), ("@employee", x.EmployeeId), ("@team", NormalizeTeam(x.TeamCode)), ("@actor", Actor));
            await Audit(db, null, "CREATE", "SCHEDULE", id, x.Code, ct); return Ok(new { id });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { return Conflict(new { message = "รหัสตารางตรวจซ้ำ", description = "เปลี่ยนรหัสให้ไม่ซ้ำในบริษัท" }); }
    }

    [HttpPut("schedules/{id:long}")]
    public async Task<IActionResult> EditSchedule(long id, ScheduleInput x, CancellationToken ct)
    {
        if (!ValidSchedule(x)) return Invalid("กรุณาตรวจรหัส ชื่อ เวลา และผู้รับผิดชอบ");
        await using var db = await Open(ct); if (await Guard(db, "56007", "EDIT", ct) is { } denied) return denied;
        if (!await ValidateScheduleReferences(db, x, ct)) return Invalid("เส้นทางหรือพนักงานต้องอยู่ในบริษัทเดียวกันและเปิดใช้งาน");
        if (await HasScheduleOverlap(db, x, id, ct)) return Conflict(new { message = "ตารางตรวจซ้อนเวลา", description = "พนักงานหรือทีมมีรอบตรวจอื่นในช่วงเวลานี้แล้ว" });
        try
        {
            var changed = await PatrolDb.Execute(db, null, "UPDATE dbo.TDPCSchedule SET RouteID=@route,ScheduleCode=@code,ScheduleName=@name,StartsAt=@from,EndsAt=@to,AssignedEmployeeID=@employee,AssignedTeamCode=@team WHERE CompanyID=@co AND ScheduleID=@id AND StatusCode=N'PLANNED'", ct, ("@co", Company), ("@id", id), ("@route", x.RouteId), ("@code", x.Code.Trim()), ("@name", x.Name.Trim()), ("@from", x.StartsAt), ("@to", x.EndsAt), ("@employee", x.EmployeeId), ("@team", NormalizeTeam(x.TeamCode)));
            if (changed == 0) return Conflict(new { message = "แก้ไขตารางตรวจไม่ได้", description = "แก้ไขได้เฉพาะรายการที่ยังวางแผนและยังไม่เปิดรอบ" });
            await Audit(db, null, "EDIT", "SCHEDULE", id, x.Code, ct); return Ok(new { saved = true });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { return Conflict(new { message = "รหัสตารางตรวจซ้ำ", description = "เปลี่ยนรหัสให้ไม่ซ้ำในบริษัท" }); }
    }

    [HttpPost("schedules/{id:long}/open")]
    public async Task<IActionResult> OpenRun(long id, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56007", "ASSIGN", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var rows = await PatrolDb.Rows(db, tx, "SELECT S.RouteID,S.StartsAt,S.EndsAt,S.AssignedEmployeeID,S.AssignedTeamCode,R.RouteName FROM dbo.TDPCSchedule S JOIN dbo.TDPCRoute R ON R.CompanyID=S.CompanyID AND R.RouteID=S.RouteID WHERE S.CompanyID=@co AND S.ScheduleID=@id AND S.StatusCode=N'PLANNED' AND R.IsActive=1", ct, ("@co", Company), ("@id", id));
            if (rows.Count == 0) return Conflict(new { message = "เปิดรอบตรวจไม่ได้", description = "ตรวจสอบว่าตารางยังวางแผนอยู่และเส้นทางยังเปิดใช้งาน" });
            var s = rows[0]; var run = await PatrolDb.Id(db, tx, "INSERT dbo.TDPCRun(CompanyID,ScheduleID,RouteID,RouteNameSnapshot,AssignedEmployeeID,AssignedTeamCode,StartsAt,EndsAt) OUTPUT INSERTED.RunID VALUES(@co,@schedule,@route,@name,@employee,@team,@from,@to)", ct, ("@co", Company), ("@schedule", id), ("@route", s["RouteID"]), ("@name", s["RouteName"]), ("@employee", s["AssignedEmployeeID"]), ("@team", s["AssignedTeamCode"]), ("@from", s["StartsAt"]), ("@to", s["EndsAt"]));
            await PatrolDb.Execute(db, tx, """
INSERT dbo.TDPCRunCheckpoint(CompanyID,RunID,CheckpointID,SequenceNo,CheckpointCodeSnapshot,CheckpointNameSnapshot,TimeMode,ScheduledFrom,ScheduledTo,GraceBeforeMinutes,GraceAfterMinutes,RequireGps,RequirePhoto,RequireChecklist)
SELECT RC.CompanyID,@run,C.CheckpointID,RC.SequenceNo,C.CheckpointCode,C.CheckpointName,RC.TimeMode,
CASE WHEN RC.TimeMode=N'TIME_WINDOW' THEN DATEADD(day,DATEDIFF(day,0,S.StartsAt),CONVERT(datetime2,RC.WindowStart)) END,
CASE WHEN RC.TimeMode=N'TIME_WINDOW' THEN DATEADD(day,CASE WHEN RC.WindowEnd<=RC.WindowStart THEN 1 ELSE 0 END,DATEADD(day,DATEDIFF(day,0,S.StartsAt),CONVERT(datetime2,RC.WindowEnd))) END,
RC.GraceBeforeMinutes,RC.GraceAfterMinutes,C.RequireGps,C.RequirePhoto,C.RequireChecklist
FROM dbo.TDPCSchedule S JOIN dbo.TDPCRouteCheckpoint RC ON RC.CompanyID=S.CompanyID AND RC.RouteID=S.RouteID
JOIN dbo.TDPCCheckpoint C ON C.CompanyID=RC.CompanyID AND C.CheckpointID=RC.CheckpointID WHERE S.CompanyID=@co AND S.ScheduleID=@schedule AND C.IsActive=1;
UPDATE dbo.TDPCSchedule SET StatusCode=N'OPEN' WHERE CompanyID=@co AND ScheduleID=@schedule;
""", ct, ("@run", run), ("@co", Company), ("@schedule", id));
            await Audit(db, tx, "OPEN", "RUN", run, null, ct); await tx.CommitAsync(ct); return Ok(new { runId = run });
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }

    private static bool ValidRoute(RouteInput x) => !string.IsNullOrWhiteSpace(x.Code) && x.Code.Length <= 30 && !string.IsNullOrWhiteSpace(x.Name) && x.Name.Length <= 150 && x.WorkType is "SECURITY" or "HOUSEKEEPING" && x.SequenceMode is "STRICT" or "FLEXIBLE" && x.Points is { Count: > 0 } && x.Points.All(p => p.CheckpointId > 0 && p.TimeMode is "TIME_WINDOW" or "ANYTIME_IN_RUN" && (p.TimeMode != "TIME_WINDOW" || p.WindowStart is not null && p.WindowEnd is not null) && p.GraceBefore is >= 0 and <= 1440 && p.GraceAfter is >= 0 and <= 1440);
    private static bool ValidSchedule(ScheduleInput x) => x.RouteId > 0 && !string.IsNullOrWhiteSpace(x.Code) && x.Code.Length <= 30 && !string.IsNullOrWhiteSpace(x.Name) && x.Name.Length <= 150 && x.StartsAt < x.EndsAt && (x.EmployeeId is > 0 || !string.IsNullOrWhiteSpace(x.TeamCode));
    private static string? NormalizeTeam(string? team) => string.IsNullOrWhiteSpace(team) ? null : team.Trim();
    private async Task<bool> ValidateRouteReferences(SqlConnection db, SqlTransaction tx, RouteInput x, CancellationToken ct)
    {
        if (await PatrolDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDADBranch WHERE CompanyID=@co AND BranchID=@id AND IsActive=1", ct, ("@co", Company), ("@id", x.BranchId)) == 0) return false;
        foreach (var point in x.Points)
        {
            if (await PatrolDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDPCCheckpoint WHERE CompanyID=@co AND CheckpointID=@id AND BranchID=@branch AND IsActive=1", ct, ("@co", Company), ("@id", point.CheckpointId), ("@branch", x.BranchId)) == 0) return false;
            if (point.ChecklistTemplateId is not null && await PatrolDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDPCChecklistTemplate WHERE CompanyID=@co AND TemplateID=@id AND WorkType=@work AND IsActive=1", ct, ("@co", Company), ("@id", point.ChecklistTemplateId), ("@work", x.WorkType)) == 0) return false;
        }
        return true;
    }
    private async Task<long> InsertRoute(SqlConnection db, SqlTransaction tx, RouteInput x, CancellationToken ct)
    {
        var id = await PatrolDb.Id(db, tx, "INSERT dbo.TDPCRoute(CompanyID,BranchID,RouteCode,RouteName,WorkType,SequenceMode) OUTPUT INSERTED.RouteID VALUES(@co,@branch,@code,@name,@work,@mode)", ct, ("@co", Company), ("@branch", x.BranchId), ("@code", x.Code.Trim()), ("@name", x.Name.Trim()), ("@work", x.WorkType), ("@mode", x.SequenceMode));
        await InsertRoutePoints(db, tx, id, x.Points, ct); return id;
    }
    private async Task InsertRoutePoints(SqlConnection db, SqlTransaction tx, long routeId, List<RoutePointInput> points, CancellationToken ct)
    {
        for (var i = 0; i < points.Count; i++) { var p = points[i]; await PatrolDb.Execute(db, tx, "INSERT dbo.TDPCRouteCheckpoint(CompanyID,RouteID,CheckpointID,SequenceNo,TimeMode,WindowStart,WindowEnd,GraceBeforeMinutes,GraceAfterMinutes,ChecklistTemplateID) VALUES(@co,@route,@cp,@seq,@mode,@from,@to,@gb,@ga,@list)", ct, ("@co", Company), ("@route", routeId), ("@cp", p.CheckpointId), ("@seq", i + 1), ("@mode", p.TimeMode), ("@from", p.WindowStart), ("@to", p.WindowEnd), ("@gb", p.GraceBefore), ("@ga", p.GraceAfter), ("@list", p.ChecklistTemplateId)); }
    }
    private async Task<bool> ValidateScheduleReferences(SqlConnection db, ScheduleInput x, CancellationToken ct)
    {
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDPCRoute WHERE CompanyID=@co AND RouteID=@id AND IsActive=1", ct, ("@co", Company), ("@id", x.RouteId)) == 0) return false;
        return x.EmployeeId is null || await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDADEmployee WHERE CompanyID=@co AND EmployeeID=@id AND IsActive=1", ct, ("@co", Company), ("@id", x.EmployeeId)) > 0;
    }
    private async Task<bool> HasScheduleOverlap(SqlConnection db, ScheduleInput x, long? exceptId, CancellationToken ct) => await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDPCSchedule WHERE CompanyID=@co AND StatusCode=N'PLANNED' AND (@except IS NULL OR ScheduleID<>@except) AND StartsAt<@ends AND EndsAt>@starts AND ((@employee IS NOT NULL AND AssignedEmployeeID=@employee) OR (@team IS NOT NULL AND AssignedTeamCode=@team))", ct, ("@co", Company), ("@except", exceptId), ("@starts", x.StartsAt), ("@ends", x.EndsAt), ("@employee", x.EmployeeId), ("@team", NormalizeTeam(x.TeamCode))) > 0;
}