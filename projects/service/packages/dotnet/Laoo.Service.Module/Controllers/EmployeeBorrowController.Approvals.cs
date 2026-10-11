using System.Data;
using LaooServiceModule.Infrastructure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;

public sealed partial class EmployeeBorrowController
{
    [HttpPost("requests/{id:long}/approve")]
    public Task<IActionResult> Approve(long id, CancellationToken token) => Decision(id, true, null, token);

    [HttpPost("requests/{id:long}/reject")]
    public Task<IActionResult> Reject(long id, [FromBody] BorrowRejectInput input, CancellationToken token) => Decision(id, false, input.Reason, token);

    private async Task<IActionResult> Decision(long id, bool approve, string? reason, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "08009", approve ? "APPROVE" : "REJECT", token)) return Denied();
        if (!approve && string.IsNullOrWhiteSpace(reason)) return Invalid("ต้องระบุเหตุผล", "กรุณาระบุเหตุผลที่ไม่อนุมัติคำขอ");
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var row = await LockedRequest(c, tx, id, token);
            if (row is null) { await tx.RollbackAsync(token); return NotFound(); }
            if (row.Value.Status != "WAIT_APPROVAL") throw new InvalidOperationException("คำขอนี้ไม่ได้รออนุมัติแล้ว");
            if (!await WarehouseAccessService.CanAccessAsync(c, tx, Company, UserId, row.Value.WarehouseID, token)) throw new InvalidOperationException("คำขออยู่นอกคลังที่มีสิทธิ์");
            await using var step = new SqlCommand("SELECT TOP(1) BorrowApprovalID,ApproverUserID FROM dbo.TDIVBorrowApproval WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND BorrowRequestID=@request AND StatusCode=N'PENDING' ORDER BY StepNo", c, tx);
            P(step, "@company", SqlDbType.BigInt, Company); P(step, "@request", SqlDbType.BigInt, id);
            long stepID = 0, assigned = 0;
            await using (var r = await step.ExecuteReaderAsync(token)) if (await r.ReadAsync(token)) { stepID = r.GetInt64(0); assigned = r.GetInt64(1); }
            if (stepID == 0 || assigned != UserId) throw new InvalidOperationException("ขั้นอนุมัติปัจจุบันไม่ได้มอบหมายให้ผู้ใช้คนนี้");
            await using var update = new SqlCommand("UPDATE dbo.TDIVBorrowApproval SET StatusCode=@status,DecisionDate=SYSUTCDATETIME(),Reason=@reason WHERE BorrowApprovalID=@step AND CompanyID=@company AND StatusCode=N'PENDING'", c, tx);
            P(update, "@status", SqlDbType.NVarChar, approve ? "APPROVED" : "REJECTED", 15);
            P(update, "@reason", SqlDbType.NVarChar, approve ? null : reason?.Trim(), 1000);
            P(update, "@step", SqlDbType.BigInt, stepID); P(update, "@company", SqlDbType.BigInt, Company);
            if (await update.ExecuteNonQueryAsync(token) != 1) throw new InvalidOperationException("ขั้นอนุมัติถูกเปลี่ยนไปแล้ว");
            var next = "WAIT_APPROVAL";
            if (!approve) next = "REJECTED";
            else
            {
                await using var remaining = new SqlCommand("SELECT COUNT(*) FROM dbo.TDIVBorrowApproval WHERE CompanyID=@company AND BorrowRequestID=@request AND StatusCode=N'PENDING'", c, tx);
                P(remaining, "@company", SqlDbType.BigInt, Company); P(remaining, "@request", SqlDbType.BigInt, id);
                if (Convert.ToInt32(await remaining.ExecuteScalarAsync(token)) == 0) next = "READY";
            }
            if (!approve) await ReleaseSerials(c, tx, id, row.Value.WarehouseID, token);
            await using var header = new SqlCommand("UPDATE dbo.TDIVBorrowRequest SET StatusCode=@status,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE BorrowRequestID=@request AND CompanyID=@company", c, tx);
            P(header, "@status", SqlDbType.NVarChar, next, 25); P(header, "@user", SqlDbType.BigInt, UserId); P(header, "@request", SqlDbType.BigInt, id); P(header, "@company", SqlDbType.BigInt, Company);
            await header.ExecuteNonQueryAsync(token);
            await Audit(c, tx, id, approve ? "APPROVE" : "REJECT", reason?.Trim(), token);
            await tx.CommitAsync(token);
            return Ok(new { statusCode = next });
        }
        catch (Exception ex) when (ex is InvalidOperationException or SqlException)
        {
            await tx.RollbackAsync(token);
            return Invalid(approve ? "อนุมัติไม่สำเร็จ" : "ปฏิเสธไม่สำเร็จ", ex is InvalidOperationException ? ex.Message : "โปรดตรวจสอบสถานะและลองใหม่");
        }
    }
}

public sealed record BorrowRejectInput(string Reason);
