using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Patrol.Controllers;

public sealed partial class PatrolController
{
    [HttpGet("runs")]
    public async Task<IActionResult> Runs(CancellationToken ct) => await List("56008", "SELECT R.RunID id,R.RouteNameSnapshot name,R.StartsAt,R.EndsAt,R.StatusCode status,E.FullName employee,R.AssignedTeamCode team,(SELECT COUNT(*) FROM dbo.TDPCRunCheckpoint P WHERE P.CompanyID=R.CompanyID AND P.RunID=R.RunID) totalPoints,(SELECT COUNT(*) FROM dbo.TDPCRunCheckpoint P WHERE P.CompanyID=R.CompanyID AND P.RunID=R.RunID AND P.StatusCode IN(N'EARLY',N'ON_TIME',N'LATE',N'COMPLETED')) completedPoints FROM dbo.TDPCRun R LEFT JOIN dbo.TDADEmployee E ON E.CompanyID=R.CompanyID AND E.EmployeeID=R.AssignedEmployeeID WHERE R.CompanyID=@co ORDER BY R.StartsAt DESC", ct);

    [HttpGet("runs/{id:long}")]
    public async Task<IActionResult> Run(long id, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56008", "VIEW", ct) is { } denied) return denied;
        var head = await PatrolDb.Rows(db, null, "SELECT RunID id,RouteNameSnapshot name,StartsAt,EndsAt,StatusCode status,AssignedEmployeeID employeeId,AssignedTeamCode team FROM dbo.TDPCRun WHERE CompanyID=@co AND RunID=@id", ct, ("@co", Company), ("@id", id));
        if (head.Count == 0) return NotFound(new { message = "Invalid patrol request", description = "Invalid patrol request" });
        var points = await PatrolDb.Rows(db, null, "SELECT RunCheckpointID id,SequenceNo sequence,CheckpointCodeSnapshot code,CheckpointNameSnapshot name,TimeMode timeMode,ScheduledFrom,ScheduledTo,StatusCode status,CheckedAt,MinutesVariance,RequireGps,RequirePhoto,RequireChecklist FROM dbo.TDPCRunCheckpoint WHERE CompanyID=@co AND RunID=@id ORDER BY SequenceNo", ct, ("@co", Company), ("@id", id));
        return Ok(new { run = head[0], points });
    }

    [HttpPost("runs/{id:long}/start")]
    public async Task<IActionResult> Start(long id, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56008", "START", ct) is { } denied) return denied;
        var changed = await PatrolDb.Execute(db, null, "UPDATE dbo.TDPCRun SET StatusCode=N'IN_PROGRESS',StartedAt=COALESCE(StartedAt,SYSUTCDATETIME()) WHERE CompanyID=@co AND RunID=@id AND StatusCode=N'OPEN'", ct, ("@co", Company), ("@id", id));
        if (changed == 0) return Conflict(new { message = "Invalid patrol request", description = "Invalid patrol request" });
        await Audit(db, null, "START", "RUN", id, null, ct); return Ok(new { started = true });
    }

    [HttpPost("runs/{run:long}/checkpoints/{point:long}/events")]
    public async Task<IActionResult> Check(long run, long point, CheckEventInput x, CancellationToken ct)
    {
        if (x.EventKey == Guid.Empty || x.Method is not ("CARD" or "QR" or "NFC" or "FINGERPRINT" or "FACE" or "SIMULATOR")) return Invalid("Invalid patrol request");
        await using var db = await Open(ct); if (await Guard(db, "56008", "CHECKPOINT", ct) is { } denied) return denied;
        long? employee = await Employee(db, ct); if (!string.IsNullOrWhiteSpace(x.CredentialReference)) { var hash = SHA256.HashData(Encoding.UTF8.GetBytes(x.CredentialReference.Trim())); var found = await PatrolDb.Rows(db, null, "SELECT TOP(1) EmployeeID FROM dbo.TDPCCredential WHERE CompanyID=@co AND CredentialType=@type AND CredentialRefHash=@hash AND IsActive=1", ct, ("@co", Company), ("@type", x.Method), ("@hash", hash)); employee = found.Count == 0 ? null : Convert.ToInt64(found[0]["EmployeeID"]); }
        if (employee is null) return StatusCode(403, new { message = "Credential not recognized", description = "No active employee credential matched this scan" });
        var setting = await PatrolDb.Rows(db, null, "SELECT OfflineMaxHours,GpsRadiusMeters FROM dbo.TDPCSetting WHERE CompanyID=@co", ct, ("@co", Company));
        var max = setting.Count == 0 ? 24 : Convert.ToInt32(setting[0]["OfflineMaxHours"]); var now = DateTime.UtcNow;
        if (x.OccurredAt > now.AddMinutes(5) || (x.Offline && x.OccurredAt < now.AddHours(-max))) return Invalid("Patrol event time is outside the allowed period");
        if (x.Offline && (x.DeviceId is null || x.DeviceSequence is null || x.DeviceSequence <= 0 || string.IsNullOrWhiteSpace(x.Signature))) return Invalid("Offline patrol evidence requires device, sequence and signature");
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var duplicate = await PatrolDb.Rows(db, tx, "SELECT CheckEventID id,ResultCode result FROM dbo.TDPCCheckEvent WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND EventKey=@key", ct, ("@co", Company), ("@key", x.EventKey));
            if (duplicate.Count > 0) { await tx.CommitAsync(ct); return Ok(new { id = duplicate[0]["id"], result = duplicate[0]["result"], duplicate = true }); }
            var rows = await PatrolDb.Rows(db, tx, "SELECT P.StatusCode PointStatus,P.TimeMode,P.ScheduledFrom,P.ScheduledTo,P.GraceBeforeMinutes,P.GraceAfterMinutes,P.RequireGps,P.RequirePhoto,P.RequireChecklist,P.SequenceNo,P.CheckpointID,C.Latitude CheckpointLatitude,C.Longitude CheckpointLongitude,C.GpsRadiusMeters,R.StatusCode,R.RouteID,R.AssignedEmployeeID,RT.SequenceMode FROM dbo.TDPCRunCheckpoint P WITH(UPDLOCK,HOLDLOCK) JOIN dbo.TDPCRun R ON R.CompanyID=P.CompanyID AND R.RunID=P.RunID JOIN dbo.TDPCRoute RT ON RT.CompanyID=R.CompanyID AND RT.RouteID=R.RouteID JOIN dbo.TDPCCheckpoint C ON C.CompanyID=P.CompanyID AND C.CheckpointID=P.CheckpointID WHERE P.CompanyID=@co AND P.RunID=@run AND P.RunCheckpointID=@point", ct, ("@co", Company), ("@run", run), ("@point", point));
            if (rows.Count == 0) return NotFound(new { message = "Invalid patrol request", description = "Invalid patrol request" });
            var p = rows[0]; if (Convert.ToString(p["PointStatus"]) != "PENDING") return Conflict(new { message = "จุดตรวจนี้ถูกบันทึกแล้ว", description = "จุดตรวจรับผลได้ครั้งเดียว หากต้องแก้ผลให้ผู้ดูแลตรวจสอบประวัติและดำเนินการตามสิทธิ์" }); if (Convert.ToString(p["StatusCode"]) is not ("OPEN" or "IN_PROGRESS")) return Conflict(new { message = "Invalid patrol request", description = "Invalid patrol request" }); if (p["AssignedEmployeeID"] is not null && Convert.ToInt64(p["AssignedEmployeeID"]) != employee.Value) return StatusCode(403, new { message = "Patrol assignment denied", description = "This run is assigned to another employee" });
            if (Convert.ToBoolean(p["RequireGps"]))
            {
                if (x.Latitude is null || x.Longitude is null || p["CheckpointLatitude"] is null || p["CheckpointLongitude"] is null) return Invalid("GPS evidence or checkpoint coordinates are missing");
                var radius = p["GpsRadiusMeters"] is null ? (setting.Count == 0 ? 100 : Convert.ToInt32(setting[0]["GpsRadiusMeters"])) : Convert.ToInt32(p["GpsRadiusMeters"]);
                var distance = PatrolEvidence.DistanceMeters(Convert.ToDouble(p["CheckpointLatitude"]), Convert.ToDouble(p["CheckpointLongitude"]), Convert.ToDouble(x.Latitude), Convert.ToDouble(x.Longitude));
                if (distance > radius) return BadRequest(new { message = "Outside checkpoint area", description = $"Current location is {Math.Round(distance)} metres from the checkpoint; allowed radius is {radius} metres" });
            }
            if (Convert.ToBoolean(p["RequirePhoto"]) && string.IsNullOrWhiteSpace(x.PhotoPath)) return Invalid("Invalid patrol request");
            if (Convert.ToBoolean(p["RequireChecklist"]) && string.IsNullOrWhiteSpace(x.ChecklistJson)) return Invalid("Invalid patrol request");
            if (x.DeviceId is not null)
            {
                var devices = await PatrolDb.Rows(db, tx, "SELECT PublicKey,LastSequence,CheckpointID FROM dbo.TDPCDevice WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND DeviceID=@device AND IsActive=1", ct, ("@co", Company), ("@device", x.DeviceId));
                if (devices.Count == 0) return Invalid("The patrol device is inactive or does not belong to this company");
                var device = devices[0];
                if (device["CheckpointID"] is not null && Convert.ToInt64(device["CheckpointID"]) != Convert.ToInt64(p["CheckpointID"])) return Invalid("The patrol device is registered to another checkpoint");
                if (x.Offline)
                {
                    if (x.DeviceSequence <= Convert.ToInt64(device["LastSequence"])) return Conflict(new { message = "Offline sequence rejected", description = "This device sequence was already used or is older than the last accepted event" });
                    var payload = PatrolEvidence.CanonicalPayload(x, run, point);
                    if (!PatrolEvidence.VerifySignature(Convert.ToString(device["PublicKey"]), x.Signature, payload)) return BadRequest(new { message = "Offline signature rejected", description = "The evidence signature does not match the registered device key" });
                }
            }
            if (Convert.ToString(p["SequenceMode"]) == "STRICT" && await PatrolDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDPCRunCheckpoint WHERE CompanyID=@co AND RunID=@run AND SequenceNo<@seq AND StatusCode=N'PENDING'", ct, ("@co", Company), ("@run", run), ("@seq", p["SequenceNo"])) > 0) return Conflict(new { message = "Invalid patrol request", description = "Invalid patrol request" });
            var result = "COMPLETED"; int? variance = null;
            if (Convert.ToString(p["TimeMode"]) == "TIME_WINDOW") { var scheduledFrom = Convert.ToDateTime(p["ScheduledFrom"]); var scheduledTo = Convert.ToDateTime(p["ScheduledTo"]); var acceptedFrom = scheduledFrom.AddMinutes(-Convert.ToInt32(p["GraceBeforeMinutes"])); var acceptedTo = scheduledTo.AddMinutes(Convert.ToInt32(p["GraceAfterMinutes"])); if (x.OccurredAt < acceptedFrom) { result = "EARLY"; variance = -(int)Math.Ceiling((scheduledFrom - x.OccurredAt).TotalMinutes); } else if (x.OccurredAt > acceptedTo) { result = "LATE"; variance = (int)Math.Ceiling((x.OccurredAt - scheduledTo).TotalMinutes); } else { result = "ON_TIME"; variance = 0; } }
            var eventId = await PatrolDb.Id(db, tx, "INSERT dbo.TDPCCheckEvent(CompanyID,RunID,RunCheckpointID,EmployeeID,EventKey,MethodCode,OccurredAt,DeviceID,DeviceSequence,Latitude,Longitude,GpsAccuracyMeters,IsOffline,PhotoPath,ChecklistJson,Note,ResultCode) OUTPUT INSERTED.CheckEventID VALUES(@co,@run,@point,@employee,@key,@method,@occurred,@device,@sequence,@lat,@lng,@accuracy,@offline,@photo,@checklist,@note,@result); UPDATE dbo.TDPCRunCheckpoint SET StatusCode=@result,CheckedAt=@occurred,CheckedByEmployeeID=@employee,MinutesVariance=@variance WHERE CompanyID=@co AND RunCheckpointID=@point; UPDATE dbo.TDPCRun SET StatusCode=N'IN_PROGRESS',StartedAt=COALESCE(StartedAt,@occurred) WHERE CompanyID=@co AND RunID=@run AND StatusCode=N'OPEN'; IF @device IS NOT NULL UPDATE dbo.TDPCDevice SET LastSequence=CASE WHEN @offline=1 THEN @sequence ELSE LastSequence END,LastSeenAt=SYSUTCDATETIME() WHERE CompanyID=@co AND DeviceID=@device;", ct, ("@co", Company), ("@run", run), ("@point", point), ("@employee", employee), ("@key", x.EventKey), ("@method", x.Method), ("@occurred", x.OccurredAt), ("@device", x.DeviceId), ("@sequence", x.DeviceSequence), ("@lat", x.Latitude), ("@lng", x.Longitude), ("@accuracy", x.GpsAccuracy), ("@offline", x.Offline), ("@photo", x.PhotoPath), ("@checklist", x.ChecklistJson), ("@note", x.Note), ("@result", result), ("@variance", variance));
            await Audit(db, tx, "CHECKPOINT", "RUN_CHECKPOINT", point, result, ct); await tx.CommitAsync(ct); return Ok(new { id = eventId, result, duplicate = false });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { await tx.RollbackAsync(ct); return Conflict(new { message = "Invalid patrol request", description = "Invalid patrol request" }); }
        catch { await tx.RollbackAsync(ct); throw; }
    }

    [HttpPost("runs/{id:long}/complete")]
    public async Task<IActionResult> Complete(long id, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56008", "COMPLETE", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var changed = await PatrolDb.Execute(db, tx,
                "UPDATE dbo.TDPCRun SET StatusCode=N'COMPLETED',CompletedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND RunID=@id AND StatusCode IN(N'OPEN',N'IN_PROGRESS')",
                ct, ("@co", Company), ("@id", id));
            if (changed == 0)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "Patrol run cannot be completed", description = "The patrol run is already closed or was not found" });
            }
            await PatrolDb.Execute(db, tx,
                "UPDATE dbo.TDPCRunCheckpoint SET StatusCode=N'MISSED' WHERE CompanyID=@co AND RunID=@id AND StatusCode=N'PENDING'; UPDATE S SET StatusCode=N'COMPLETED' FROM dbo.TDPCSchedule S JOIN dbo.TDPCRun R ON R.CompanyID=S.CompanyID AND R.ScheduleID=S.ScheduleID WHERE S.CompanyID=@co AND R.RunID=@id AND S.StatusCode=N'OPEN'",
                ct, ("@co", Company), ("@id", id));
            await Audit(db, tx, "COMPLETE", "RUN", id, null, ct);
            await tx.CommitAsync(ct);
            return Ok(new { completed = true });
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }
}
