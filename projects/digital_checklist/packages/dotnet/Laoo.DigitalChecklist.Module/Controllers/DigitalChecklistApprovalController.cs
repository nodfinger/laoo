using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
namespace Laoo.DigitalChecklist.Controllers;

public sealed partial class DigitalChecklistController
{
    [HttpPost("approvals/{id:long}/approve")]
    public async Task<IActionResult> ApproveCurrent(long id, DecisionInput input, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "58007", "APPROVE", ct) is { } denied) return denied;
        const string sql = """
            BEGIN TRY
              BEGIN TRAN;
              DECLARE @inspection bigint,@version int,@next int,@nextUser bigint;
              SELECT @inspection=A.InspectionID,@version=A.VersionNo FROM dbo.TDCLApproval A WITH(UPDLOCK,HOLDLOCK)
              JOIN dbo.TDCLInspection I ON I.CompanyID=A.CompanyID AND I.InspectionID=A.InspectionID AND I.VersionNo=A.VersionNo
              WHERE A.CompanyID=@co AND A.ApprovalID=@id AND A.ApproverUserID=@actor AND A.StatusCode='PENDING' AND I.CreatedBy<>@actor;
              IF @inspection IS NULL THROW 58011,'Approval unavailable or self-approval is prohibited',1;
              IF EXISTS(SELECT 1 FROM dbo.TDCLInspectionItem X WHERE X.CompanyID=@co AND X.InspectionID=@inspection AND X.VersionNo=@version AND X.ResultCode='FAIL'
                AND NOT EXISTS(SELECT 1 FROM dbo.TDCLAttachment E WHERE E.CompanyID=X.CompanyID AND E.InspectionID=X.InspectionID AND E.InspectionItemID=X.InspectionItemID))
                THROW 58022,'Failed checklist items require photo evidence',1;
              UPDATE dbo.TDCLApproval SET StatusCode='APPROVED',DecisionNote=@note,DecidedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND ApprovalID=@id AND VersionNo=@version AND StatusCode='PENDING';
              SELECT @next=MIN(StepNo) FROM dbo.TDCLApproval WHERE CompanyID=@co AND InspectionID=@inspection AND VersionNo=@version AND StatusCode='WAITING';
              IF @next IS NOT NULL
              BEGIN
                UPDATE dbo.TDCLApproval SET StatusCode='PENDING' WHERE CompanyID=@co AND InspectionID=@inspection AND VersionNo=@version AND StepNo=@next;
                SELECT @nextUser=ApproverUserID FROM dbo.TDCLApproval WHERE CompanyID=@co AND InspectionID=@inspection AND VersionNo=@version AND StepNo=@next;
                INSERT dbo.TDCLNotification(CompanyID,UserID,InspectionID,NoticeCode,NoticeKey,Message) SELECT @co,@nextUser,@inspection,'APPROVAL_REQUIRED',CONCAT(N'APPROVAL:',@inspection,N':',@version),CONCAT(N'มีรายการตรวจรออนุมัติ ',InspectionCode) FROM dbo.TDCLInspection WHERE CompanyID=@co AND InspectionID=@inspection;
              END
              ELSE
              BEGIN
                UPDATE dbo.TDCLInspection SET StatusCode='APPROVED' WHERE CompanyID=@co AND InspectionID=@inspection AND VersionNo=@version;
                INSERT dbo.TDCLCorrectiveTask(CompanyID,InspectionID,InspectionItemID,TaskCode,Subject,Detail,StatusCode)
                SELECT @co,@inspection,X.InspectionItemID,CONCAT('DCL-',@inspection,'-',X.InspectionItemID),T.TypeName,X.Detail,'OPEN'
                FROM dbo.TDCLInspectionItem X JOIN dbo.TDCLInspection I ON I.CompanyID=X.CompanyID AND I.InspectionID=X.InspectionID AND I.VersionNo=X.VersionNo
                JOIN dbo.TDCLType T ON T.CompanyID=I.CompanyID AND T.TypeID=I.TypeID
                WHERE X.CompanyID=@co AND X.InspectionID=@inspection AND X.VersionNo=@version AND X.ResultCode='FAIL';
              END;
              INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail) VALUES(@co,@actor,'APPROVE','INSPECTION',@inspection,CONCAT('Version:',@version));
              COMMIT;
            END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH
            """;
        await using var command = new SqlCommand(sql, db);
        command.Parameters.AddWithValue("@co", Company);
        command.Parameters.AddWithValue("@id", id);
        command.Parameters.AddWithValue("@actor", Actor);
        command.Parameters.AddWithValue("@note", input.Note ?? (object)DBNull.Value);
        try { await command.ExecuteNonQueryAsync(ct); }
        catch (SqlException error) when (error.Number is 58011 or 58022)
        {
            return Conflict(new { message = error.Number == 58022
                ? "ข้อที่ไม่ผ่านต้องแนบรูปหลักฐานก่อนอนุมัติ กรุณาส่งกลับให้ผู้ตรวจแนบรูป"
                : "รายการอนุมัตินี้ถูกดำเนินการแล้ว หรือไม่ใช่งานของคุณ" });
        }
        return Ok(new { approved = true });
    }

    [HttpPost("approvals/{id:long}/return")]
    public async Task<IActionResult> ReturnCurrent(long id, DecisionInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Note)) return BadRequest(new { message = "กรุณาระบุเหตุผลที่ส่งกลับ" });
        await using var db = await Open(ct);
        if (await Guard(db, "58007", "RETURN", ct) is { } denied) return denied;
        const string sql = """
            BEGIN TRY
              BEGIN TRAN;
              DECLARE @inspection bigint,@version int;
              SELECT @inspection=A.InspectionID,@version=A.VersionNo FROM dbo.TDCLApproval A WITH(UPDLOCK,HOLDLOCK)
              JOIN dbo.TDCLInspection I ON I.CompanyID=A.CompanyID AND I.InspectionID=A.InspectionID AND I.VersionNo=A.VersionNo
              WHERE A.CompanyID=@co AND A.ApprovalID=@id AND A.ApproverUserID=@actor AND A.StatusCode='PENDING' AND I.CreatedBy<>@actor;
              IF @inspection IS NULL THROW 58015,'Approval unavailable or self-return is prohibited',1;
              UPDATE dbo.TDCLApproval SET StatusCode='RETURNED',DecisionNote=@note,DecidedAt=SYSUTCDATETIME()
                WHERE CompanyID=@co AND InspectionID=@inspection AND VersionNo=@version AND StatusCode IN('PENDING','WAITING');
              UPDATE dbo.TDCLInspection SET StatusCode='RETURNED' WHERE CompanyID=@co AND InspectionID=@inspection AND VersionNo=@version;
              INSERT dbo.TDCLNotification(CompanyID,UserID,InspectionID,NoticeCode,NoticeKey,Message) SELECT @co,CreatedBy,@inspection,'INSPECTION_RETURNED',CONCAT(N'RETURN:',@inspection,N':',@version),CONCAT(N'รายการตรวจถูกส่งกลับแก้ไข ',InspectionCode) FROM dbo.TDCLInspection WHERE CompanyID=@co AND InspectionID=@inspection;
              INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail) VALUES(@co,@actor,'RETURN','INSPECTION',@inspection,@note);
              COMMIT;
            END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH
            """;
        await using var command = new SqlCommand(sql, db);
        command.Parameters.AddWithValue("@co", Company);
        command.Parameters.AddWithValue("@id", id);
        command.Parameters.AddWithValue("@actor", Actor);
        command.Parameters.AddWithValue("@note", input.Note.Trim());
        try { await command.ExecuteNonQueryAsync(ct); }
        catch (SqlException error) when (error.Number == 58015)
        {
            return Conflict(new { message = "รายการส่งกลับนี้ถูกดำเนินการแล้ว หรือไม่ใช่งานของคุณ" });
        }
        return Ok(new { returned = true });
    }
}
