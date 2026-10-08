using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace Laoo.DigitalChecklist.Controllers;

public sealed partial class DigitalChecklistController
{
    [HttpPost("schedules/{scheduleId:long}/inspections")]
    public async Task<IActionResult> SubmitScheduledInspection(long scheduleId, InspectionInput input, CancellationToken ct)
    {
        if (input.Items.Count == 0 || input.Items.Select(x => x.TemplateItemId).Distinct().Count() != input.Items.Count || input.Items.Any(x => x.ResultCode is not ("PASS" or "FAIL")))
            return BadRequest(new { message = "กรุณาบันทึกผลตรวจทุกรายการให้ถูกต้อง" });
        await using var db = await Open(ct);
        if (await Guard(db, "58006", "SUBMIT", ct) is { } denied) return denied;
        var department = await Department(db, ct);
        if (department is null) return StatusCode(403, new { message = "ไม่พบแผนกปัจจุบัน กรุณาติดต่อผู้ดูแล" });
        var items = JsonSerializer.Serialize(input.Items);
        const string sql = """
            BEGIN TRY
              BEGIN TRAN;
              DECLARE @id bigint,@version int,@type bigint,@template bigint,@workflow bigint,@group bigint;
              SELECT @id=I.InspectionID,@version=I.VersionNo,@type=S.TypeID,@template=S.TemplateID,@workflow=S.WorkflowID,@group=G.GroupID
              FROM dbo.TDCLInspection I WITH(UPDLOCK,HOLDLOCK)
              JOIN dbo.TDCLSchedule S ON S.CompanyID=I.CompanyID AND S.ScheduleID=I.ScheduleID
              JOIN dbo.TDCLType T ON T.CompanyID=S.CompanyID AND T.TypeID=S.TypeID
              JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID
              WHERE I.CompanyID=@co AND I.ScheduleID=@schedule AND I.InspectionID=@inspection
                AND I.StatusCode IN('DUE','OVERDUE','RETURNED') AND I.DepartmentOrgUnitID=@dep AND G.DepartmentOrgUnitID=@dep;
              IF @id IS NULL THROW 58017,'Scheduled inspection unavailable',1;
              IF @type<>@requestedType THROW 58018,'Inspection type does not match schedule',1;
              IF EXISTS(SELECT 1 FROM OPENJSON(@items) WITH(TemplateItemID bigint '$.TemplateItemId') J
                LEFT JOIN dbo.TDCLTemplateItem TI ON TI.CompanyID=@co AND TI.TemplateID=@template AND TI.ItemID=J.TemplateItemID
                WHERE TI.ItemID IS NULL) THROW 58019,'Inspection item does not belong to scheduled template',1;
              IF EXISTS(SELECT 1 FROM dbo.TDCLTemplateItem TI WHERE TI.CompanyID=@co AND TI.TemplateID=@template AND TI.IsRequired=1
                AND NOT EXISTS(SELECT 1 FROM OPENJSON(@items) WITH(TemplateItemID bigint '$.TemplateItemId') J WHERE J.TemplateItemID=TI.ItemID))
                THROW 58021,'Required scheduled checklist item missing',1;
              SET @version=@version+CASE WHEN EXISTS(SELECT 1 FROM dbo.TDCLInspection WHERE CompanyID=@co AND InspectionID=@id AND StatusCode='RETURNED') THEN 1 ELSE 0 END;
              UPDATE dbo.TDCLInspection SET VersionNo=@version,StatusCode='IN_APPROVAL',StartedAt=COALESCE(StartedAt,SYSUTCDATETIME()),SubmittedAt=SYSUTCDATETIME(),SnapshotJson=@snapshot,CreatedBy=@actor WHERE CompanyID=@co AND InspectionID=@id;
              INSERT dbo.TDCLInspectionVersion(CompanyID,InspectionID,VersionNo,SnapshotJson,CreatedBy) VALUES(@co,@id,@version,@snapshot,@actor);
              INSERT dbo.TDCLInspectionItem(CompanyID,InspectionID,VersionNo,TemplateItemID,ResultCode,Detail)
                SELECT @co,@id,@version,TemplateItemId,ResultCode,Detail FROM OPENJSON(@items) WITH(TemplateItemId bigint '$.TemplateItemId',ResultCode varchar(12) '$.ResultCode',Detail nvarchar(1000) '$.Detail');
              INSERT dbo.TDCLApproval(CompanyID,InspectionID,VersionNo,GroupID,StepNo,ApproverUserID,StatusCode)
                SELECT @co,@id,@version,@group,S.SequenceNo,S.ApproverUserID,CASE WHEN S.SequenceNo=1 THEN 'PENDING' ELSE 'WAITING' END FROM dbo.TDCLWorkflowStep S WHERE S.CompanyID=@co AND S.WorkflowID=@workflow;
              IF @@ROWCOUNT=0 THROW 58010,'Approval route not configured',1;
              INSERT dbo.TDCLNotification(CompanyID,UserID,InspectionID,NoticeCode,NoticeKey,Message)
                SELECT @co,A.ApproverUserID,@id,'APPROVAL_REQUIRED',CONCAT(N'APPROVAL:',@id,N':',@version),CONCAT(N'มีรายการตรวจรออนุมัติ ',I.InspectionCode)
                FROM dbo.TDCLApproval A JOIN dbo.TDCLInspection I ON I.CompanyID=A.CompanyID AND I.InspectionID=A.InspectionID
                WHERE A.CompanyID=@co AND A.InspectionID=@id AND A.VersionNo=@version AND A.StatusCode='PENDING'
                  AND (NOT EXISTS(SELECT 1 FROM dbo.TDCLSetting WHERE CompanyID=@co) OR EXISTS(SELECT 1 FROM dbo.TDCLSetting WHERE CompanyID=@co AND (NotifyInApp=1 OR NotifyEmail=1)));
              INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail) VALUES(@co,@actor,'SUBMIT','INSPECTION',@id,CONCAT('Version:',@version));
              COMMIT; SELECT @id;
            END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH
            """;
        try
        {
            var id = await DigitalChecklistDb.Id(db, sql, ct,
                ("@co", Company), ("@schedule", scheduleId), ("@inspection", input.InspectionId),
                ("@requestedType", input.TypeId), ("@dep", department), ("@items", items),
                ("@snapshot", JsonSerializer.Serialize(new { input.Note, input.Items })), ("@actor", Actor));
            return Ok(new { id, status = "IN_APPROVAL" });
        }
        catch (SqlException error) when (error.Number is 58017 or 58018 or 58019 or 58021 or 58010)
        {
            return error.Number switch
            {
                58017 => Conflict(new { message = "รอบตรวจนี้ส่งแล้วหรือไม่อยู่ในแผนกของคุณ กรุณาโหลดรายการใหม่" }),
                58018 => BadRequest(new { message = "ประเภทการตรวจไม่ตรงกับแผน" }),
                58019 => BadRequest(new { message = "มีข้อคำถามที่ไม่อยู่ในแบบตรวจของรอบนี้" }),
                58021 => BadRequest(new { message = "กรุณาตอบข้อบังคับในแบบตรวจให้ครบ" }),
                _ => Conflict(new { message = "ยังไม่ได้กำหนดสายอนุมัติสำหรับรอบตรวจนี้" })
            };
        }
    }
}
