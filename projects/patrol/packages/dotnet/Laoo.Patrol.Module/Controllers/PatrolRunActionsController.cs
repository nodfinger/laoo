using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Patrol.Controllers;

public sealed partial class PatrolController
{
    [HttpPost("runs/{run:long}/checkpoints/{point:long}/skip")]
    public async Task<IActionResult> SkipCheckpoint(long run, long point, PatrolReasonInput input, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(input.Reason)) return Invalid("A reason is required when skipping a checkpoint");
        await using var database = await Open(cancellationToken);
        if (await Guard(database, "56008", "SKIP", cancellationToken) is { } denied) return denied;
        await using var transaction = (SqlTransaction)await database.BeginTransactionAsync(cancellationToken);
        try
        {
            var changed = await PatrolDb.Execute(database, transaction, """
UPDATE P SET StatusCode=N'SKIPPED'
FROM dbo.TDPCRunCheckpoint P
JOIN dbo.TDPCRun R ON R.CompanyID=P.CompanyID AND R.RunID=P.RunID
WHERE P.CompanyID=@co AND P.RunID=@run AND P.RunCheckpointID=@point
  AND P.StatusCode=N'PENDING' AND R.StatusCode IN(N'OPEN',N'IN_PROGRESS');
""", cancellationToken, ("@co", Company), ("@run", run), ("@point", point));
            if (changed == 0) return Conflict(new { message = "Checkpoint cannot be skipped", description = "The checkpoint is already processed or the patrol run is closed" });
            await Audit(database, transaction, "SKIP", "RUN_CHECKPOINT", point, input.Reason.Trim(), cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return Ok(new { skipped = true });
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    [HttpPost("runs/{id:long}/cancel")]
    public async Task<IActionResult> CancelRun(long id, PatrolReasonInput input, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(input.Reason)) return Invalid("A cancellation reason is required");
        await using var database = await Open(cancellationToken);
        if (await Guard(database, "56008", "CANCEL", cancellationToken) is { } denied) return denied;
        await using var transaction = (SqlTransaction)await database.BeginTransactionAsync(cancellationToken);
        try
        {
            var changed = await PatrolDb.Execute(database, transaction, """
UPDATE dbo.TDPCRun SET StatusCode=N'CANCELLED',CompletedAt=SYSUTCDATETIME()
WHERE CompanyID=@co AND RunID=@id AND StatusCode IN(N'OPEN',N'IN_PROGRESS');
""", cancellationToken, ("@co", Company), ("@id", id));
            if (changed == 0)
            {
                await transaction.RollbackAsync(cancellationToken);
                return Conflict(new { message = "Patrol run cannot be cancelled", description = "The patrol run is already closed or was not found" });
            }
            await PatrolDb.Execute(database, transaction, """
UPDATE dbo.TDPCRunCheckpoint SET StatusCode=N'SKIPPED'
WHERE CompanyID=@co AND RunID=@id AND StatusCode=N'PENDING';
UPDATE S SET StatusCode=N'CANCELLED'
FROM dbo.TDPCSchedule S JOIN dbo.TDPCRun R ON R.CompanyID=S.CompanyID AND R.ScheduleID=S.ScheduleID
WHERE S.CompanyID=@co AND R.RunID=@id AND S.StatusCode=N'OPEN';
""", cancellationToken, ("@co", Company), ("@id", id));
            await Audit(database, transaction, "CANCEL", "RUN", id, input.Reason.Trim(), cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return Ok(new { cancelled = true });
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    [HttpPost("schedules/{id:long}/cancel")]
    public async Task<IActionResult> CancelSchedule(long id, PatrolReasonInput input, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(input.Reason)) return Invalid("A cancellation reason is required");
        await using var database = await Open(cancellationToken);
        if (await Guard(database, "56007", "CANCEL", cancellationToken) is { } denied) return denied;
        var changed = await PatrolDb.Execute(database, null,
            "UPDATE dbo.TDPCSchedule SET StatusCode=N'CANCELLED' WHERE CompanyID=@co AND ScheduleID=@id AND StatusCode=N'PLANNED'",
            cancellationToken, ("@co", Company), ("@id", id));
        if (changed == 0) return Conflict(new { message = "Schedule cannot be cancelled", description = "Only a planned schedule without an opened run can be cancelled" });
        await Audit(database, null, "CANCEL", "SCHEDULE", id, input.Reason.Trim(), cancellationToken);
        return Ok(new { cancelled = true });
    }
}
