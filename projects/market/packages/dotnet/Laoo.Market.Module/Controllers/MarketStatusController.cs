using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Market.Controllers;

public sealed partial class MarketController
{
    [HttpPost("stalls/{stallId:long}/periods")]
    public async Task<IActionResult> BlockStall(long stallId, StallPeriodInput input, CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7));
        if (stallId <= 0 || input.StatusCode is not ("CLOSED" or "RENOVATION")
            || input.StartsOn < today || (input.StatusCode == "RENOVATION" && input.EndsOn is null)
            || (input.EndsOn.HasValue && input.EndsOn < input.StartsOn)
            || string.IsNullOrWhiteSpace(input.Reason) || input.Reason.Length > 500)
            return Invalid("เลือกสถานะ ช่วงวันที่ และเหตุผลให้ครบ; ปรับปรุงต้องมีวันสิ้นสุด");
        await using var db = await Open(ct);
        if (await Guard(db, "59003", "BLOCK", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var allowed = await MarketDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDMKStall S WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDMKMarket M ON M.CompanyID=S.CompanyID AND M.MarketID=S.MarketID AND M.IsActive=1
WHERE S.CompanyID=@co AND S.StallID=@stall AND S.IsActive=1
AND (M.BranchID IS NULL OR EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co
 AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=M.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@stall", stallId), ("@actor", Actor));
        if (allowed == 0)
        {
            await tx.RollbackAsync(ct);
            return NotFound(new { message = "ไม่พบล็อก", description = "ตรวจสอบตลาดและสิทธิ์สาขา" });
        }
        var conflict = await MarketDb.Id(db, tx, """
SELECT
 (SELECT COUNT(*) FROM dbo.TDMKStallStatusPeriod WITH(UPDLOCK,HOLDLOCK)
  WHERE CompanyID=@co AND StallID=@stall AND IsActive=1
  AND StartsOn<=COALESCE(@end,'99991231') AND (EndsOn IS NULL OR EndsOn>=@start))
 +(SELECT COUNT(*) FROM dbo.TDMKContract WITH(UPDLOCK,HOLDLOCK)
  WHERE CompanyID=@co AND StallID=@stall AND StatusCode=N'ACTIVE'
  AND StartsOn<=COALESCE(@end,'99991231') AND EndsOn>=@start)
 +(SELECT COUNT(*) FROM dbo.TDMKBooking WITH(UPDLOCK,HOLDLOCK)
  WHERE CompanyID=@co AND StallID=@stall AND StatusCode=N'RESERVED'
  AND ExpiresAt>SYSUTCDATETIME()
  AND StartsOn<=COALESCE(@end,'99991231') AND EndsOn>=@start)
""", ct, ("@co", Company), ("@stall", stallId),
            ("@start", input.StartsOn.ToDateTime(TimeOnly.MinValue)),
            ("@end", input.EndsOn?.ToDateTime(TimeOnly.MinValue)));
        if (conflict > 0)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new { message = "กำหนดสถานะล็อกไม่ได้",
                description = "ช่วงวันที่ทับสถานะปิด สัญญาเช่า หรือการจองที่ยังมีผล" });
        }
        var id = await MarketDb.Id(db, tx, """
INSERT dbo.TDMKStallStatusPeriod(CompanyID,StallID,StatusCode,StartsOn,EndsOn,Reason)
OUTPUT INSERTED.PeriodID VALUES(@co,@stall,@status,@start,@end,@reason)
""", ct, ("@co", Company), ("@stall", stallId),
            ("@status", input.StatusCode), ("@start", input.StartsOn.ToDateTime(TimeOnly.MinValue)),
            ("@end", input.EndsOn?.ToDateTime(TimeOnly.MinValue)), ("@reason", input.Reason.Trim()));
        await MarketDb.Execute(db, tx, """
INSERT dbo.TDMKAudit(CompanyID,ActorUserID,ActionCode,EntityType,EntityID,Remark)
VALUES(@co,@actor,N'BLOCK',N'STALL_PERIOD',@id,@reason)
""", ct, ("@co", Company), ("@actor", Actor), ("@id", id), ("@reason", input.Reason.Trim()));
        await tx.CommitAsync(ct);
        return Ok(new { id, status = input.StatusCode });
    }

    [HttpPost("stalls/{stallId:long}/reopen")]
    public async Task<IActionResult> Reopen(long stallId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "59003", "BLOCK", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var periods = await MarketDb.Rows(db, tx, """
SELECT P.PeriodID id FROM dbo.TDMKStallStatusPeriod P WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDMKStall S ON S.CompanyID=P.CompanyID AND S.StallID=P.StallID
JOIN dbo.TDMKMarket M ON M.CompanyID=S.CompanyID AND M.MarketID=S.MarketID
WHERE P.CompanyID=@co AND P.StallID=@stall AND P.StatusCode=N'CLOSED'
AND P.IsActive=1 AND P.StartsOn<=CONVERT(date,DATEADD(hour,7,SYSUTCDATETIME()))
AND (P.EndsOn IS NULL OR P.EndsOn>=CONVERT(date,DATEADD(hour,7,SYSUTCDATETIME())))
AND (M.BranchID IS NULL OR EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co
 AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=M.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@stall", stallId), ("@actor", Actor));
        if (periods.Count == 0)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new { message = "เปิดล็อกไม่ได้",
                description = "ไม่พบสถานะปิดที่มีผลอยู่ หรือไม่มีสิทธิ์ในสาขานี้" });
        }
        foreach (var period in periods)
        {
            var id = Convert.ToInt64(period["id"]);
            await MarketDb.Execute(db, tx,
                "UPDATE dbo.TDMKStallStatusPeriod SET IsActive=0 WHERE CompanyID=@co AND PeriodID=@id",
                ct, ("@co", Company), ("@id", id));
            await MarketDb.Execute(db, tx, """
INSERT dbo.TDMKAudit(CompanyID,ActorUserID,ActionCode,EntityType,EntityID)
VALUES(@co,@actor,N'REOPEN',N'STALL_PERIOD',@id)
""", ct, ("@co", Company), ("@actor", Actor), ("@id", id));
        }
        await tx.CommitAsync(ct);
        return Ok(new { stallId, status = "VACANT" });
    }
}

public sealed record StallPeriodInput(string StatusCode, DateOnly StartsOn,
    DateOnly? EndsOn, string Reason);
