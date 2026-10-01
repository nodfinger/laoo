using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooSurveyModule.Controllers;

public sealed partial class SurveyController
{
    [HttpGet("approvals")]
    public async Task<IActionResult> Approvals(CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "40003", "VIEW", token)) return Forbid();
        var employee = await CurrentEmployee(c, company, user, token); var self = await Can(c, "40003", "SELF_APPROVE", token);
        await using var q = new SqlCommand("""
SELECT s.SurveyID id,s.SurveyCode code,s.SurveyName name,s.OpenAt,s.CloseAt,s.IsAnonymous anonymous,
 s.StatusCode status,e.FullName approver,
 (SELECT COUNT(*) FROM dbo.TDSVSurveyQuestion q WHERE q.SurveyID=s.SurveyID AND q.IsActive=1) questionCount
FROM dbo.TDSVSurvey s LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=s.CompanyID AND e.EmployeeID=s.ApproverEmployeeID
WHERE s.CompanyID=@co AND s.StatusCode=N'PENDING_APPROVAL' AND (@self=1 OR s.ApproverEmployeeID=@employee)
ORDER BY s.SubmittedAt
""", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@employee", SqlDbType.BigInt, employee); P(q, "@self", SqlDbType.Bit, self);
        return Ok(await ReadRows(q, token));
    }

    [HttpPost("approvals/{id:long}")]
    public async Task<IActionResult> Decide(long id, SurveyDecisionInput input, CancellationToken token)
    {
        var action = input.Action.Trim().ToUpperInvariant();
        if (action is not ("APPROVE" or "RETURN") || action == "RETURN" && string.IsNullOrWhiteSpace(input.Reason))
            return Bad("ข้อมูลอนุมัติไม่ครบ", "ระบุ APPROVE หรือ RETURN และใส่เหตุผลเมื่อส่งกลับ");
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "40003", "APPROVE", token)) return Forbid();
        var employee = await CurrentEmployee(c, company, user, token); var self = await Can(c, "40003", "SELF_APPROVE", token);
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        await using var q = new SqlCommand("""
UPDATE dbo.TDSVSurvey SET StatusCode=@status,
 ApprovedAt=CASE WHEN @status=N'APPROVED' THEN SYSUTCDATETIME() ELSE NULL END,
 ReturnReason=@reason,UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@co AND SurveyID=@id AND StatusCode=N'PENDING_APPROVAL'
 AND (@self=1 OR ApproverEmployeeID=@employee);SELECT @@ROWCOUNT
""", c, tx);
        P(q, "@status", SqlDbType.NVarChar, action == "APPROVE" ? "APPROVED" : "RETURNED", 30);
        P(q, "@reason", SqlDbType.NVarChar, Clean(input.Reason), 1000); P(q, "@user", SqlDbType.BigInt, user);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id);
        P(q, "@self", SqlDbType.Bit, self); P(q, "@employee", SqlDbType.BigInt, employee);
        if (Convert.ToInt32(await q.ExecuteScalarAsync(token)) == 0) { await tx.RollbackAsync(token); return Forbid(); }
        await Execute(c, tx, "INSERT dbo.TDSVSurveyApprovalHistory(CompanyID,SurveyID,ActionCode,ActionByEmployeeID,ReasonText,CreateBy) VALUES(@co,@id,@action,@employee,@reason,@user)", token,
            ("@co", company), ("@id", id), ("@action", action), ("@employee", employee), ("@reason", Clean(input.Reason)), ("@user", user));
        await tx.CommitAsync(token); return NoContent();
    }

    [HttpGet("deliveries")]
    public Task<IActionResult> Deliveries(CancellationToken token) => Read("40004", """
SELECT s.SurveyID id,s.SurveyCode code,s.SurveyName name,s.OpenAt,s.CloseAt,s.StatusCode status,
 (SELECT COUNT(*) FROM dbo.TDSVSurveyAssignment a WHERE a.SurveyID=s.SurveyID AND a.IsActive=1) audienceCount,
 (SELECT COUNT(*) FROM dbo.TDSVSurveyAssignment a WHERE a.SurveyID=s.SurveyID AND a.RespondedAt IS NOT NULL) respondedCount
FROM dbo.TDSVSurvey s WHERE s.CompanyID=@co AND s.StatusCode IN(N'APPROVED',N'PUBLISHED',N'CLOSED')
ORDER BY s.OpenAt DESC
""", token);

    [HttpPut("{id:long}/targets")]
    public async Task<IActionResult> SaveTargets(long id, SurveyTargetInput input, CancellationToken token)
    {
        var mode = input.Mode.Trim().ToUpperInvariant();
        if (mode is not ("ALL" or "CUSTOM") || mode == "CUSTOM" && input.DepartmentIDs.Count + input.EmployeeIDs.Count == 0)
            return Bad("กลุ่มผู้ตอบไม่ถูกต้อง", "เลือกพนักงานทั้งหมด หรือเลือกแผนก/พนักงานอย่างน้อย 1 รายการ");
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "40004", "EDIT", token)) return Forbid();
        if (!await TargetsValid(c, company, input, token)) return Bad("กลุ่มผู้ตอบไม่ถูกต้อง", "ทุกแผนกและพนักงานต้องเปิดใช้งานในบริษัทเดียวกัน");
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        var state = Convert.ToString(await Scalar(c, tx, "SELECT StatusCode FROM dbo.TDSVSurvey WHERE CompanyID=@co AND SurveyID=@id", token, ("@co", company), ("@id", id)));
        if (state != "APPROVED") { await tx.RollbackAsync(token); return Conflict(new { message = "แก้กลุ่มผู้ตอบไม่ได้", description = "กำหนดผู้ตอบได้เฉพาะแบบสอบถามที่อนุมัติแล้วและยังไม่เผยแพร่" }); }
        await Execute(c, tx, "DELETE dbo.TDSVSurveyTargetDepartment WHERE SurveyID=@id;DELETE dbo.TDSVSurveyTargetEmployee WHERE SurveyID=@id", token, ("@id", id));
        if (mode == "CUSTOM")
        {
            foreach (var department in input.DepartmentIDs.Distinct())
                await Execute(c, tx, "INSERT dbo.TDSVSurveyTargetDepartment(CompanyID,SurveyID,DepartmentOrgUnitID,CreateBy) VALUES(@co,@id,@target,@user)", token, ("@co", company), ("@id", id), ("@target", department), ("@user", user));
            foreach (var employee in input.EmployeeIDs.Distinct())
                await Execute(c, tx, "INSERT dbo.TDSVSurveyTargetEmployee(CompanyID,SurveyID,EmployeeID,CreateBy) VALUES(@co,@id,@target,@user)", token, ("@co", company), ("@id", id), ("@target", employee), ("@user", user));
        }
        await Execute(c, tx, "UPDATE dbo.TDSVSurvey SET UpdateBy=@user,UpdateDate=SYSUTCDATETIME(),TargetMode=@mode WHERE CompanyID=@co AND SurveyID=@id", token, ("@user", user), ("@mode", mode), ("@co", company), ("@id", id));
        await tx.CommitAsync(token); return NoContent();
    }

    [HttpPost("{id:long}/publish")]
    public async Task<IActionResult> Publish(long id, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "40004", "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        var mode = Convert.ToString(await Scalar(c, tx, "SELECT TargetMode FROM dbo.TDSVSurvey WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND SurveyID=@id AND StatusCode=N'APPROVED'", token, ("@co", company), ("@id", id)));
        if (string.IsNullOrWhiteSpace(mode)) { await tx.RollbackAsync(token); return Conflict(new { message = "ยังไม่กำหนดกลุ่มผู้ตอบ", description = "เลือกพนักงานทั้งหมดหรือกำหนดแผนก/พนักงานก่อนเผยแพร่" }); }
        var insert = mode == "ALL" ? """
INSERT dbo.TDSVSurveyAssignment(CompanyID,SurveyID,EmployeeID,CreateBy)
SELECT @co,@id,e.EmployeeID,@user FROM dbo.TDADEmployee e WHERE e.CompanyID=@co AND e.IsActive=1
""" : """
INSERT dbo.TDSVSurveyAssignment(CompanyID,SurveyID,EmployeeID,CreateBy)
SELECT @co,@id,x.EmployeeID,@user FROM(
 SELECT EmployeeID FROM dbo.TDSVSurveyTargetEmployee WHERE CompanyID=@co AND SurveyID=@id
 UNION SELECT e.EmployeeID FROM dbo.TDADEmployee e WHERE e.CompanyID=@co AND e.IsActive=1 AND e.DepartmentOrgUnitID IN(SELECT DepartmentOrgUnitID FROM dbo.TDSVSurveyTargetDepartment WHERE CompanyID=@co AND SurveyID=@id)
 UNION SELECT a.EmployeeID FROM dbo.TDADEmployeeOrganizationAssignment a WHERE a.CompanyID=@co AND a.IsActive=1 AND a.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND(a.EffectiveTo IS NULL OR a.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())) AND a.DepartmentOrgUnitID IN(SELECT DepartmentOrgUnitID FROM dbo.TDSVSurveyTargetDepartment WHERE CompanyID=@co AND SurveyID=@id)
)x JOIN dbo.TDADEmployee e ON e.CompanyID=@co AND e.EmployeeID=x.EmployeeID AND e.IsActive=1
""";
        var count = await Execute(c, tx, insert, token, ("@co", company), ("@id", id), ("@user", user));
        if (count == 0) { await tx.RollbackAsync(token); return Bad("ไม่พบผู้ตอบแบบสอบถาม", "กลุ่มที่เลือกไม่มีพนักงาน Active"); }
        await Execute(c, tx, "UPDATE dbo.TDSVSurvey SET StatusCode=N'PUBLISHED',PublishedAt=SYSUTCDATETIME(),UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND SurveyID=@id;INSERT dbo.TDSVSurveyDeliveryHistory(CompanyID,SurveyID,ActionCode,RecipientCount,CreateBy) VALUES(@co,@id,N'PUBLISH',@count,@user)", token,
            ("@co", company), ("@id", id), ("@count", count), ("@user", user));
        await tx.CommitAsync(token); return Ok(new { audienceCount = count });
    }

    [HttpPost("{id:long}/resend")]
    public async Task<IActionResult> Resend(long id, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "40004", "RESEND", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        var count = await Execute(c, tx, "UPDATE a SET ReminderCount=ReminderCount+1,LastReminderAt=SYSUTCDATETIME() FROM dbo.TDSVSurveyAssignment a JOIN dbo.TDSVSurvey s ON s.SurveyID=a.SurveyID WHERE a.CompanyID=@co AND a.SurveyID=@id AND a.RespondedAt IS NULL AND a.IsActive=1 AND s.StatusCode=N'PUBLISHED'", token, ("@co", company), ("@id", id));
        if (count == 0) { await tx.RollbackAsync(token); return Conflict(new { message = "ไม่มีผู้รับที่ต้องแจ้งเตือน", description = "แบบสอบถามไม่อยู่ระหว่างเผยแพร่หรือทุกคนตอบแล้ว" }); }
        await Execute(c, tx, "INSERT dbo.TDSVSurveyDeliveryHistory(CompanyID,SurveyID,ActionCode,RecipientCount,CreateBy) VALUES(@co,@id,N'RESEND',@count,@user)", token, ("@co", company), ("@id", id), ("@count", count), ("@user", user));
        await tx.CommitAsync(token); return Ok(new { recipientCount = count });
    }

    [HttpPost("{id:long}/close")]
    public Task<IActionResult> Close(long id, CancellationToken token) => StatusAction(id, "40004", "EDIT",
        "UPDATE dbo.TDSVSurvey SET StatusCode=N'CLOSED',ClosedAt=SYSUTCDATETIME(),UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND SurveyID=@id AND StatusCode=N'PUBLISHED'", token);
}
