using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Market.Controllers;

public sealed partial class MarketController
{
    [HttpPost("bookings")]
    public async Task<IActionResult> Reserve(ReserveStallInput input, CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7));
        if (input.StallID <= 0 || input.TraderID <= 0 || input.IdempotencyKey == Guid.Empty
            || input.StartsOn < today || input.EndsOn < input.StartsOn
            || input.EndsOn.DayNumber - input.StartsOn.DayNumber > 365)
            return Invalid("ตรวจสอบล็อก ผู้ค้า และช่วงวันที่ต้องการจอง");
        await using var db = await Open(ct);
        if (await Guard(db, "59003", "RESERVE", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var previous = await MarketDb.Rows(db, tx, """
SELECT BookingID id,StallID stallId,TraderID traderId,StartsOn startsOn,EndsOn endsOn,StatusCode status
FROM dbo.TDMKBooking WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND IdempotencyKey=@key
""", ct, ("@co", Company), ("@key", input.IdempotencyKey));
        if (previous.Count > 0)
        {
            await tx.CommitAsync(ct);
            var row = previous[0];
            if (Convert.ToInt64(row["stallId"]) != input.StallID
                || Convert.ToInt64(row["traderId"]) != input.TraderID
                || DateOnly.FromDateTime((DateTime)row["startsOn"]!) != input.StartsOn
                || DateOnly.FromDateTime((DateTime)row["endsOn"]!) != input.EndsOn)
                return Conflict(new { message = "รหัสคำขอจองถูกใช้แล้ว",
                    description = "เริ่มคำขอใหม่เพื่อจองช่วงเวลาหรือผู้ค้าอื่น" });
            return Ok(new { id = row["id"], status = row["status"], repeated = true });
        }
        var stall = await MarketDb.Rows(db, tx, """
SELECT S.StallID id,M.BranchID branchId FROM dbo.TDMKStall S WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDMKZone Z ON Z.CompanyID=S.CompanyID AND Z.ZoneID=S.ZoneID AND Z.IsActive=1
JOIN dbo.TDMKMarket M ON M.CompanyID=S.CompanyID AND M.MarketID=S.MarketID AND M.IsActive=1
WHERE S.CompanyID=@co AND S.StallID=@stall AND S.IsActive=1
AND (M.BranchID IS NULL OR EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co
 AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=M.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@stall", input.StallID), ("@actor", Actor));
        if (stall.Count != 1)
        {
            await tx.RollbackAsync(ct);
            return NotFound(new { message = "ไม่พบล็อกที่จองได้", description = "ตรวจสอบตลาด สาขา และสถานะล็อก" });
        }
        var trader = await MarketDb.Id(db, tx,
            "SELECT COUNT(*) FROM dbo.TDMKTrader WHERE CompanyID=@co AND TraderID=@trader AND IsActive=1",
            ct, ("@co", Company), ("@trader", input.TraderID));
        if (trader == 0)
        {
            await tx.RollbackAsync(ct);
            return Invalid("เลือกผู้ค้าที่เปิดใช้งานในบริษัทนี้");
        }
        var limit = await MarketDb.Id(db, tx,
            "SELECT COALESCE(MAX(AdvanceBookingDays),90) FROM dbo.TDMKSetting WHERE CompanyID=@co",
            ct, ("@co", Company));
        if (input.StartsOn.DayNumber - today.DayNumber > limit)
        {
            await tx.RollbackAsync(ct);
            return Invalid($"จองล่วงหน้าได้ไม่เกิน {limit} วัน");
        }
        if (input.StartsOn > today)
        {
            var history = await MarketDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDMKContract WHERE CompanyID=@co AND TraderID=@trader
AND StatusCode IN(N'ACTIVE',N'ENDED')
""", ct, ("@co", Company), ("@trader", input.TraderID));
            if (history == 0)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "จองล่วงหน้าไม่ได้",
                    description = "ผู้ค้าที่ไม่มีประวัติให้บันทึกความสนใจก่อน หรือเลือกจองวันที่ปัจจุบัน" });
            }
        }
        await MarketDb.Execute(db, tx, """
UPDATE dbo.TDMKBooking SET StatusCode=N'EXPIRED' WHERE CompanyID=@co AND StallID=@stall
AND StatusCode=N'RESERVED' AND ExpiresAt<=SYSUTCDATETIME()
""", ct, ("@co", Company), ("@stall", input.StallID));
        var overlaps = await MarketDb.Id(db, tx, """
SELECT
 (SELECT COUNT(*) FROM dbo.TDMKStallStatusPeriod WITH(UPDLOCK,HOLDLOCK)
  WHERE CompanyID=@co AND StallID=@stall AND IsActive=1
  AND StartsOn<=@end AND (EndsOn IS NULL OR EndsOn>=@start))
 +(SELECT COUNT(*) FROM dbo.TDMKContract WITH(UPDLOCK,HOLDLOCK)
  WHERE CompanyID=@co AND StallID=@stall AND StatusCode=N'ACTIVE'
  AND StartsOn<=@end AND EndsOn>=@start)
 +(SELECT COUNT(*) FROM dbo.TDMKBooking WITH(UPDLOCK,HOLDLOCK)
  WHERE CompanyID=@co AND StallID=@stall AND StatusCode=N'RESERVED'
  AND ExpiresAt>SYSUTCDATETIME() AND StartsOn<=@end AND EndsOn>=@start)
""", ct, ("@co", Company), ("@stall", input.StallID),
            ("@start", input.StartsOn.ToDateTime(TimeOnly.MinValue)),
            ("@end", input.EndsOn.ToDateTime(TimeOnly.MinValue)));
        if (overlaps > 0)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new { message = "ล็อกไม่ว่างในช่วงวันที่เลือก",
                description = "ตรวจสอบผังตามวันที่ หรือเลือกล็อกและช่วงอื่น" });
        }
        var id = await MarketDb.Id(db, tx, """
INSERT dbo.TDMKBooking(CompanyID,StallID,TraderID,StartsOn,EndsOn,ExpiresAt,
 StatusCode,IdempotencyKey,CreatedBy)
OUTPUT INSERTED.BookingID
VALUES(@co,@stall,@trader,@start,@end,DATEADD(hour,24,SYSUTCDATETIME()),
 N'RESERVED',@key,@actor)
""", ct, ("@co", Company), ("@stall", input.StallID), ("@trader", input.TraderID),
            ("@start", input.StartsOn.ToDateTime(TimeOnly.MinValue)),
            ("@end", input.EndsOn.ToDateTime(TimeOnly.MinValue)),
            ("@key", input.IdempotencyKey), ("@actor", Actor));
        await MarketDb.Execute(db, tx, """
INSERT dbo.TDMKAudit(CompanyID,ActorUserID,ActionCode,EntityType,EntityID)
VALUES(@co,@actor,N'RESERVE',N'BOOKING',@id)
""", ct, ("@co", Company), ("@actor", Actor), ("@id", id));
        await tx.CommitAsync(ct);
        return Ok(new { id, status = "RESERVED" });
    }

    [HttpPost("bookings/{id:long}/cancel")]
    public async Task<IActionResult> Cancel(long id, CancelStallInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Reason) || input.Reason.Length > 500)
            return Invalid("ระบุเหตุผลยกเลิกไม่เกิน 500 ตัวอักษร");
        await using var db = await Open(ct);
        if (await Guard(db, "59003", "CANCEL", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var changed = await MarketDb.Execute(db, tx, """
UPDATE B SET StatusCode=N'CANCELLED' FROM dbo.TDMKBooking B
JOIN dbo.TDMKStall S ON S.CompanyID=B.CompanyID AND S.StallID=B.StallID
JOIN dbo.TDMKMarket M ON M.CompanyID=S.CompanyID AND M.MarketID=S.MarketID
WHERE B.CompanyID=@co AND B.BookingID=@id AND B.StatusCode=N'RESERVED'
AND (M.BranchID IS NULL OR EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co
 AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=M.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@id", id), ("@actor", Actor));
        if (changed != 1)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new { message = "ยกเลิกการจองไม่ได้",
                description = "รายการอาจถูกยกเลิก หมดอายุ หรืออยู่นอกสาขาที่มีสิทธิ์" });
        }
        await MarketDb.Execute(db, tx, """
INSERT dbo.TDMKAudit(CompanyID,ActorUserID,ActionCode,EntityType,EntityID,Remark)
VALUES(@co,@actor,N'CANCEL',N'BOOKING',@id,@reason)
""", ct, ("@co", Company), ("@actor", Actor), ("@id", id), ("@reason", input.Reason.Trim()));
        await tx.CommitAsync(ct);
        return Ok(new { id, status = "CANCELLED" });
    }
}

public sealed record ReserveStallInput(long StallID, long TraderID, DateOnly StartsOn,
    DateOnly EndsOn, Guid IdempotencyKey);
public sealed record CancelStallInput(string Reason);
