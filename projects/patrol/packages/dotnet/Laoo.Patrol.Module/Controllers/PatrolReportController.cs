using Microsoft.AspNetCore.Mvc;

namespace Laoo.Patrol.Controllers;

public sealed partial class PatrolController
{
    [HttpGet("monitor")]
    public async Task<IActionResult> Monitor(CancellationToken ct) => await List("56009", "SELECT R.RunID id,R.RouteNameSnapshot name,R.StartsAt,R.EndsAt,R.StatusCode status,SUM(CASE WHEN P.StatusCode=N'PENDING' THEN 1 ELSE 0 END) pending,SUM(CASE WHEN P.StatusCode=N'MISSED' THEN 1 ELSE 0 END) missed,SUM(CASE WHEN P.StatusCode=N'LATE' THEN 1 ELSE 0 END) late,COUNT(P.RunCheckpointID) total FROM dbo.TDPCRun R LEFT JOIN dbo.TDPCRunCheckpoint P ON P.CompanyID=R.CompanyID AND P.RunID=R.RunID WHERE R.CompanyID=@co GROUP BY R.RunID,R.RouteNameSnapshot,R.StartsAt,R.EndsAt,R.StatusCode ORDER BY R.StartsAt DESC", ct);

    [HttpGet("incidents")]
    public async Task<IActionResult> Incidents(CancellationToken ct) => await List("56010", "SELECT IncidentID id,IncidentCode code,SeverityCode severity,Subject name,StatusCode status,ServiceRequestID serviceRequestId,ReportedAt FROM dbo.TDPCIncident WHERE CompanyID=@co ORDER BY ReportedAt DESC", ct);

    [HttpPost("incidents")]
    public async Task<IActionResult> AddIncident(IncidentInput x, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(x.Subject) || string.IsNullOrWhiteSpace(x.Detail)) return Invalid("Invalid patrol request");
        await using var db = await Open(ct); if (await Guard(db, "56008", "REPORT_INCIDENT", ct) is { } denied) return denied;
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDPCRun WHERE CompanyID=@co AND RunID=@run", ct, ("@co", Company), ("@run", x.RunId)) == 0) return Invalid("Invalid patrol request");
        var code = $"PI{DateTime.UtcNow:yyyyMMddHHmmssfff}";
        var id = await PatrolDb.Id(db, null, "INSERT dbo.TDPCIncident(CompanyID,RunID,RunCheckpointID,IncidentCode,SeverityCode,Subject,Detail,ReportedBy) OUTPUT INSERTED.IncidentID VALUES(@co,@run,@point,@code,@severity,@subject,@detail,@actor)", ct, ("@co", Company), ("@run", x.RunId), ("@point", x.RunCheckpointId), ("@code", code), ("@severity", x.Severity), ("@subject", x.Subject.Trim()), ("@detail", x.Detail.Trim()), ("@actor", Actor));
        await Audit(db, null, "CREATE", "INCIDENT", id, code, ct); return Ok(new { id, code, serviceCreated = false });
    }

    [HttpPut("incidents/{id:long}/acknowledge")]
    public async Task<IActionResult> Acknowledge(long id, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56010", "ACKNOWLEDGE", ct) is { } denied) return denied;
        var changed = await PatrolDb.Execute(db, null, "UPDATE dbo.TDPCIncident SET StatusCode=N'ACKNOWLEDGED',AcknowledgedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND IncidentID=@id AND StatusCode=N'OPEN'", ct, ("@co", Company), ("@id", id));
        if (changed == 0) return Conflict(new { message = "Invalid patrol request", description = "Invalid patrol request" });
        await Audit(db, null, "ACKNOWLEDGE", "INCIDENT", id, null, ct); return Ok(new { saved = true });
    }

    [HttpGet("audit")]
    public async Task<IActionResult> AuditList(CancellationToken ct) => await List("56011", "SELECT AuditID id,ActionCode action,EntityType entity,EntityID entityId,Detail,CreatedAt FROM dbo.TDPCAudit WHERE CompanyID=@co ORDER BY AuditID DESC", ct);

    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard(CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56012", "VIEW", ct) is { } denied) return denied;
        var summary = await PatrolDb.Rows(db, null, "SELECT COUNT(DISTINCT R.RunID) totalRuns,COUNT(DISTINCT CASE WHEN R.StatusCode=N'COMPLETED' THEN R.RunID END) completedRuns,SUM(CASE WHEN P.StatusCode=N'ON_TIME' THEN 1 ELSE 0 END) onTime,SUM(CASE WHEN P.StatusCode=N'LATE' THEN 1 ELSE 0 END) late,SUM(CASE WHEN P.StatusCode=N'EARLY' THEN 1 ELSE 0 END) early,SUM(CASE WHEN P.StatusCode=N'COMPLETED' THEN 1 ELSE 0 END) anytimeCompleted,SUM(CASE WHEN P.StatusCode=N'MISSED' THEN 1 ELSE 0 END) missed FROM dbo.TDPCRun R LEFT JOIN dbo.TDPCRunCheckpoint P ON P.CompanyID=R.CompanyID AND P.RunID=R.RunID WHERE R.CompanyID=@co", ct, ("@co", Company));
        var routes = await PatrolDb.Rows(db, null, "SELECT TOP(10) R.RouteNameSnapshot name,COUNT(*) runCount,SUM(CASE WHEN R.StatusCode=N'COMPLETED' THEN 1 ELSE 0 END) completed FROM dbo.TDPCRun R WHERE R.CompanyID=@co GROUP BY R.RouteNameSnapshot ORDER BY COUNT(*) DESC", ct, ("@co", Company));
        return Ok(new { summary = summary.Single(), routes });
    }
}
