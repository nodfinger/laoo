using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
namespace Laoo.DigitalChecklist.Controllers;

public sealed partial class DigitalChecklistController
{
    [HttpPost("inspections")]
    public async Task<IActionResult> SubmitManualInspection(InspectionInput input, CancellationToken ct)
    {
        if (input.ScheduleId is not null) return BadRequest(new { message = "งานตามแผนต้องส่งผ่านรอบตรวจที่ระบบสร้าง" });
        if (input.Items.Count == 0 || input.Items.Select(x => x.TemplateItemId).Distinct().Count() != input.Items.Count || input.Items.Any(x => x.ResultCode is not ("PASS" or "FAIL")))
            return BadRequest(new { message = "กรุณาบันทึกผลตรวจทุกรายการให้ถูกต้อง" });
        await using var db = await Open(ct);
        if (await Guard(db, "58006", "SUBMIT", ct) is { } denied) return denied;
        var department = await Department(db, ct);
        if (department is null) return StatusCode(403, new { message = "ไม่พบแผนกปัจจุบัน กรุณาติดต่อผู้ดูแล" });
        var items = JsonSerializer.Serialize(input.Items);
        var code = $"DCL-M-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid():N}"[..34];
        var snapshot = JsonSerializer.Serialize(new { input.TypeId, input.Note, input.Items, actor = Actor, submittedAt = DateTime.UtcNow });
        const string sql = """
            BEGIN TRY BEGIN TRAN;
            DECLARE @template bigint,@workflow bigint,@group bigint,@typeName nvarchar(150);
            SELECT TOP(1) @template=V.TemplateID,@workflow=W.WorkflowID,@group=G.GroupID,@typeName=T.TypeName
            FROM dbo.TDCLType T JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID
            OUTER APPLY(SELECT TOP(1) TemplateID FROM dbo.TDCLTemplate WHERE CompanyID=T.CompanyID AND TypeID=T.TypeID AND IsActive=1 ORDER BY TemplateID DESC) V
            OUTER APPLY(SELECT TOP(1) WorkflowID FROM dbo.TDCLWorkflow WHERE CompanyID=T.CompanyID AND TypeID=T.TypeID AND IsActive=1 ORDER BY WorkflowID DESC) W
            WHERE T.CompanyID=@co AND T.TypeID=@type AND T.IsActive=1 AND G.DepartmentOrgUnitID=@dep;
            IF @template IS NULL OR @workflow IS NULL THROW 58020,'Template or workflow missing',1;
            IF EXISTS(SELECT 1 FROM OPENJSON(@items) WITH(TemplateItemID bigint '$.TemplateItemId') J LEFT JOIN dbo.TDCLTemplateItem I ON I.CompanyID=@co AND I.TemplateID=@template AND I.ItemID=J.TemplateItemID WHERE I.ItemID IS NULL)
              THROW 58019,'Inspection item does not belong to current template',1;
            IF EXISTS(SELECT 1 FROM dbo.TDCLTemplateItem I WHERE I.CompanyID=@co AND I.TemplateID=@template AND I.IsRequired=1 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@items) WITH(TemplateItemID bigint '$.TemplateItemId') J WHERE J.TemplateItemID=I.ItemID))
              THROW 58021,'Required checklist item missing',1;
            INSERT dbo.TDCLInspection(CompanyID,TypeID,DepartmentOrgUnitID,InspectionCode,DueAt,StartedAt,SubmittedAt,StatusCode,VersionNo,SnapshotJson,CreatedBy)
              VALUES(@co,@type,@dep,@code,SYSUTCDATETIME(),SYSUTCDATETIME(),SYSUTCDATETIME(),'IN_APPROVAL',1,@snapshot,@actor);
            DECLARE @id bigint=SCOPE_IDENTITY();
            INSERT dbo.TDCLInspectionVersion(CompanyID,InspectionID,VersionNo,SnapshotJson,CreatedBy) VALUES(@co,@id,1,@snapshot,@actor);
            INSERT dbo.TDCLInspectionItem(CompanyID,InspectionID,VersionNo,TemplateItemID,ResultCode,Detail)
              SELECT @co,@id,1,TemplateItemId,ResultCode,Detail FROM OPENJSON(@items) WITH(TemplateItemId bigint '$.TemplateItemId',ResultCode varchar(12) '$.ResultCode',Detail nvarchar(1000) '$.Detail');
            INSERT dbo.TDCLApproval(CompanyID,InspectionID,VersionNo,GroupID,StepNo,ApproverUserID,StatusCode)
              SELECT @co,@id,1,@group,SequenceNo,ApproverUserID,CASE WHEN SequenceNo=1 THEN 'PENDING' ELSE 'WAITING' END FROM dbo.TDCLWorkflowStep WHERE CompanyID=@co AND WorkflowID=@workflow;
            IF @@ROWCOUNT=0 THROW 58010,'Approval route not configured',1;
            INSERT dbo.TDCLNotification(CompanyID,UserID,InspectionID,NoticeCode,NoticeKey,Message)
              SELECT @co,A.ApproverUserID,@id,'APPROVAL_REQUIRED',CONCAT(N'APPROVAL:',@id,N':1'),CONCAT(N'มีรายการตรวจรออนุมัติ ',@code) FROM dbo.TDCLApproval A
              WHERE A.CompanyID=@co AND A.InspectionID=@id AND A.VersionNo=1 AND A.StatusCode='PENDING'
                AND (NOT EXISTS(SELECT 1 FROM dbo.TDCLSetting WHERE CompanyID=@co) OR EXISTS(SELECT 1 FROM dbo.TDCLSetting WHERE CompanyID=@co AND (NotifyInApp=1 OR NotifyEmail=1)));
            INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail) VALUES(@co,@actor,'SUBMIT','INSPECTION',@id,CONCAT('Version:1; Type:',@typeName));
            COMMIT; SELECT @id;
            END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH
            """;
        var id = await DigitalChecklistDb.Id(db, sql, ct, ("@co", Company), ("@type", input.TypeId), ("@dep", department), ("@code", code), ("@snapshot", snapshot), ("@actor", Actor), ("@items", items));
        return Ok(new { id, status = "IN_APPROVAL" });
    }
}
