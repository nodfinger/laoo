using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Patrol.Controllers;

public sealed partial class PatrolController
{
    [HttpPut("monitor/{runId:long}/acknowledge")]
    public async Task<IActionResult> AcknowledgeMonitor(long runId, PatrolReasonInput input, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(input.Reason)) return Invalid("An acknowledgement note is required");
        await using var database = await Open(cancellationToken);
        if (await Guard(database, "56009", "ACKNOWLEDGE", cancellationToken) is { } denied) return denied;
        if (await PatrolDb.Id(database, null, "SELECT COUNT(*) FROM dbo.TDPCRun WHERE CompanyID=@co AND RunID=@id", cancellationToken, ("@co", Company), ("@id", runId)) == 0)
            return NotFound(new { message = "Patrol run was not found", description = "The requested run does not belong to this company" });
        await Audit(database, null, "ACKNOWLEDGE", "MONITOR_RUN", runId, input.Reason.Trim(), cancellationToken);
        return Ok(new { acknowledged = true });
    }

    [HttpPut("incidents/{id:long}/escalate")]
    public async Task<IActionResult> EscalateIncident(long id, PatrolReasonInput input, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(input.Reason)) return Invalid("An escalation reason is required");
        await using var database = await Open(cancellationToken);
        if (await Guard(database, "56010", "ESCALATE", cancellationToken) is { } denied) return denied;
        var changed = await PatrolDb.Execute(database, null,
            "UPDATE dbo.TDPCIncident SET StatusCode=N'ESCALATED' WHERE CompanyID=@co AND IncidentID=@id AND StatusCode IN(N'OPEN',N'ACKNOWLEDGED')",
            cancellationToken, ("@co", Company), ("@id", id));
        if (changed == 0) return Conflict(new { message = "Incident cannot be escalated", description = "The incident was not found or is already closed" });
        await Audit(database, null, "ESCALATE", "INCIDENT", id, input.Reason.Trim(), cancellationToken);
        return Ok(new { escalated = true });
    }

    [HttpPost("incidents/{id:long}/service-request")]
    public async Task<IActionResult> CreateServiceRequest(long id, CancellationToken cancellationToken)
    {
        await using var database = await Open(cancellationToken);
        if (await Guard(database, "56010", "CREATE_SERVICE", cancellationToken) is { } denied) return denied;
        var employeeId = await Employee(database, cancellationToken);
        if (employeeId is null) return BadRequest(new { message = "Employee profile is required", description = "Link the current user to an active employee before creating a service request" });

        var available = await PatrolDb.Id(database, null, """
SELECT COUNT(*) FROM dbo.TDADCompanyProject CP
JOIN dbo.TDADProject P ON P.ProjectID=CP.ProjectID AND P.ProjectCode=N'LAOO_SERVICE' AND P.IsActive=1
LEFT JOIN dbo.TDSTCompanySetupSystemService S ON S.CompanyID=CP.CompanyID AND S.ProjectID=P.ProjectID
WHERE CP.CompanyID=@co AND CP.IsEnabled=1 AND COALESCE(S.ServiceEnabled,1)=1 AND COALESCE(S.RequireEquipment,0)=0;
""", cancellationToken, ("@co", Company));
        if (available == 0) return BadRequest(new { message = "Service request is unavailable", description = "Enable LAOO_SERVICE and allow requests without required equipment before linking a patrol incident" });

        await using var transaction = (SqlTransaction)await database.BeginTransactionAsync(cancellationToken);
        try
        {
            var incidents = await PatrolDb.Rows(database, transaction, """
SELECT I.ServiceRequestID,I.IncidentCode,I.Subject,I.Detail,P.CheckpointNameSnapshot,
       E.PersonID,COALESCE(PER.FullName,E.FullName) RequesterName,PER.Mobile,PER.Email
FROM dbo.TDPCIncident I
JOIN dbo.TDPCRun R ON R.CompanyID=I.CompanyID AND R.RunID=I.RunID
LEFT JOIN dbo.TDPCRunCheckpoint P ON P.CompanyID=I.CompanyID AND P.RunCheckpointID=I.RunCheckpointID
JOIN dbo.TDADEmployee E ON E.CompanyID=I.CompanyID AND E.EmployeeID=@employee AND E.IsActive=1
LEFT JOIN dbo.TDADPerson PER ON PER.CompanyID=E.CompanyID AND PER.PersonID=E.PersonID
WHERE I.CompanyID=@co AND I.IncidentID=@id;
""", cancellationToken, ("@co", Company), ("@id", id), ("@employee", employeeId));
            if (incidents.Count == 0) return NotFound(new { message = "Incident was not found", description = "The incident does not belong to this company" });
            var incident = incidents[0];
            if (incident["ServiceRequestID"] is not null)
            {
                await transaction.CommitAsync(cancellationToken);
                return Ok(new { requestId = incident["ServiceRequestID"], duplicate = true });
            }
            var requestNoRows = await PatrolDb.Rows(database, transaction, """
SELECT N'SR'+CONVERT(nvarchar(8),CONVERT(date,SYSUTCDATETIME()),112)
 +RIGHT(N'000000'+CONVERT(nvarchar(6),ISNULL(MAX(TRY_CONVERT(int,RIGHT(RequestNo,6))),0)+1),6) RequestNo
FROM dbo.TDADServiceRequest WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND RequestNo LIKE N'SR'+CONVERT(nvarchar(8),CONVERT(date,SYSUTCDATETIME()),112)+N'%';
""", cancellationToken, ("@co", Company));
            var requestNo = Convert.ToString(requestNoRows[0]["RequestNo"])!;
            var detail = $"Patrol incident {incident["IncidentCode"]}: {incident["Detail"]}";
            var requestId = await PatrolDb.Id(database, transaction, """
DECLARE @created TABLE(RequestID bigint);
INSERT dbo.TDADServiceRequest(CompanyID,RequestNo,RequesterType,RequesterID,RequesterNameSnapshot,RequesterPhoneSnapshot,RequesterEmailSnapshot,LocationSnapshot,Subject,Detail,CreateBy)
OUTPUT INSERTED.RequestID INTO @created VALUES(@co,@no,N'EMPLOYEE',@person,@name,@phone,@email,@location,@subject,@detail,@actor);
UPDATE dbo.TDPCIncident SET ServiceRequestID=(SELECT RequestID FROM @created) WHERE CompanyID=@co AND IncidentID=@incident;
SELECT RequestID FROM @created;
""", cancellationToken, ("@co", Company), ("@no", requestNo), ("@person", incident["PersonID"]), ("@name", incident["RequesterName"]), ("@phone", incident["Mobile"]), ("@email", incident["Email"]), ("@location", incident["CheckpointNameSnapshot"]), ("@subject", incident["Subject"]), ("@detail", detail), ("@actor", Actor), ("@incident", id));
            await Audit(database, transaction, "CREATE_SERVICE", "INCIDENT", id, requestNo, cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return Ok(new { requestId, requestNo, duplicate = false });
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }
}