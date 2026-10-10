using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

namespace Laoo.Booking.Controllers;

public sealed record BookingSaleLinkRequest(long SaleId);

[ApiController, Authorize, Route("api/company/booking")]
public sealed class BookingUsageController(IConfiguration config) : ControllerBase
{
    long Company => long.Parse(User.FindFirst("company_id")!.Value);
    long Actor => long.Parse(User.FindFirst("user_id")!.Value);
    async Task<SqlConnection> Open(CancellationToken ct) { var d = new SqlConnection(config.GetConnectionString("LaooDatabase")); await d.OpenAsync(ct); return d; }
    async Task<IActionResult?> Guard(SqlConnection db, string action, CancellationToken ct)
    {
        if (!BookingAccess.Scope(User, out _, out _)) return StatusCode(403, new { message = "ไม่สามารถเข้าถึงบริษัท", description = "กรุณาเข้าสู่ระบบด้วยบัญชีบริษัท" });
        return await BookingAccess.Can(db, User, "61008", action, ct) ? null : StatusCode(403, new { message = "ไม่มีสิทธิ์บันทึกการใช้บริการ", description = "ตรวจสอบแพ็กเกจและสิทธิ์เมนูของผู้ใช้" });
    }
    [HttpPost("bookings/{id:long}/use")]
    public Task<IActionResult> UseAll(long id, CancellationToken ct) => RecordUsage(id, null, ct);

    [HttpPost("bookings/{id:long}/lines/{lineId:long}/use")]
    public Task<IActionResult> UseLine(long id, long lineId, CancellationToken ct) => RecordUsage(id, lineId, ct);

    async Task<IActionResult> RecordUsage(long id, long? lineId, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "USE", ct) is { } no) return no;
        await using var tx = (SqlTransaction)await d.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var booking = await BookingDb.Rows(d, tx, "SELECT StatusCode FROM dbo.TDBKBooking WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND BookingID=@id", ct, ("@c", Company), ("@id", id));
        if (booking.Count == 0) return NotFound(new { message = "ไม่พบการจอง", description = "เปิดรายการจองของบริษัทนี้อีกครั้ง" });
        var status = Convert.ToString(booking[0]["StatusCode"]);
        if (status is not ("BOOKED" or "CONFIRMED" or "IN_SERVICE" or "COMPLETED")) return Conflict(new { message = "บันทึกใช้บริการไม่ได้", description = "รายการถูกยกเลิกหรือถูกระบุว่าไม่มาแล้ว" });
        var lines = await BookingDb.Rows(d, tx, "SELECT LineID FROM dbo.TDBKBookingService WHERE CompanyID=@c AND BookingID=@id AND (@line IS NULL OR LineID=@line)", ct, ("@c", Company), ("@id", id), ("@line", lineId));
        if (lines.Count == 0) return NotFound(new { message = "ไม่พบบริการในใบจอง", description = "เลือกรายการบริการที่อยู่ในใบจองนี้" });
        var inserted = 0;
        foreach (var line in lines)
            inserted += await BookingDb.Exec(d, tx, "INSERT dbo.TDBKUsage(CompanyID,BookingID,LineID,UsedBy) SELECT @c,@b,@line,@u WHERE NOT EXISTS(SELECT 1 FROM dbo.TDBKUsage WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND BookingID=@b AND LineID=@line)", ct, ("@c", Company), ("@b", id), ("@line", line["LineID"]), ("@u", Actor));
        if (inserted > 0)
        {
            var remaining = await BookingDb.Id(d, tx, "SELECT COUNT(*) FROM dbo.TDBKBookingService L WHERE L.CompanyID=@c AND L.BookingID=@b AND NOT EXISTS(SELECT 1 FROM dbo.TDBKUsage U WHERE U.CompanyID=L.CompanyID AND U.BookingID=L.BookingID AND U.LineID=L.LineID)", ct, ("@c", Company), ("@b", id));
            await BookingDb.Exec(d, tx, "UPDATE dbo.TDBKBooking SET StatusCode=@status WHERE CompanyID=@c AND BookingID=@b", ct, ("@status", remaining == 0 ? "COMPLETED" : "IN_SERVICE"), ("@c", Company), ("@b", id));
            await BookingDb.Exec(d, tx, "INSERT dbo.TDBKBookingAudit(CompanyID,BookingID,ActionCode,ActorUserID,Reason) VALUES(@c,@b,N'USE',@u,@reason)", ct, ("@c", Company), ("@b", id), ("@u", Actor), ("@reason", lineId?.ToString()));
        }
        await tx.CommitAsync(ct);
        return NoContent();
    }
    [HttpPost("bookings/{id:long}/no-show")]
    public async Task<IActionResult> MarkNoShow(long id, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "NOSHOW", ct) is { } no) return no;
        await using var tx = (SqlTransaction)await d.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var grace = await BookingDb.Id(d, tx, "SELECT COALESCE((SELECT NoShowGraceMinutes FROM dbo.TDBKSetting WHERE CompanyID=@c),15)", ct, ("@c", Company));
        var n = await BookingDb.Exec(d, tx, "UPDATE dbo.TDBKBooking SET StatusCode=N'NO_SHOW' WHERE CompanyID=@c AND BookingID=@b AND StatusCode IN(N'BOOKED',N'CONFIRMED') AND EndsAt<=DATEADD(minute,-@grace,SYSUTCDATETIME()) AND NOT EXISTS(SELECT 1 FROM dbo.TDBKUsage WHERE CompanyID=@c AND BookingID=@b)", ct, ("@c", Company), ("@b", id), ("@grace", grace));
        if (n == 0) return Conflict(new { message = "ระบุว่าไม่มาไม่ได้", description = "ต้องผ่านเวลาสิ้นสุดและช่วงรอที่ตั้งค่าไว้ และต้องไม่มีการใช้บริการ" });
        await BookingDb.Exec(d, tx, "INSERT dbo.TDBKBookingAudit(CompanyID,BookingID,ActionCode,ActorUserID) VALUES(@c,@b,N'NO_SHOW',@u)", ct, ("@c", Company), ("@b", id), ("@u", Actor));
        await tx.CommitAsync(ct);
        return NoContent();
    }
    [HttpPost("bookings/{id:long}/sales")]
    public async Task<IActionResult> LinkSale(long id, BookingSaleLinkRequest x, CancellationToken ct)
    {
        if (x.SaleId <= 0) return BadRequest(new { message = "เลขใบขายไม่ถูกต้อง", description = "เลือกใบขาย POS ที่ออกแล้ว" });
        await using var d = await Open(ct);
        if (await Guard(d, "SALE", ct) is { } no) return no;
        if (!await CompanyMenuAccess.IsAllowedAsync(d, User, "46004", "VIEW", ct)) return StatusCode(403, new { message = "ไม่มีสิทธิ์ดูใบขาย POS", description = "ให้ผู้ดูแลเปิดสิทธิ์เมนูขายหน้าร้านก่อนเชื่อมใบขาย" });
        await using var tx = (SqlTransaction)await d.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var booking = await BookingDb.Rows(d, tx, "SELECT BranchID,StatusCode FROM dbo.TDBKBooking WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND BookingID=@b", ct, ("@c", Company), ("@b", id));
        if (booking.Count == 0) return NotFound(new { message = "ไม่พบการจอง", description = "เปิดรายการจองของบริษัทนี้อีกครั้ง" });
        if (Convert.ToString(booking[0]["StatusCode"]) is "CANCELLED" or "NO_SHOW") return Conflict(new { message = "รายการจองปิดแล้ว", description = "เลือกรายการที่ยังใช้งานหรือใช้บริการแล้ว" });
        var sale = await BookingDb.Rows(d, tx, "SELECT BranchID,StatusCode FROM dbo.TDPOSale WITH(HOLDLOCK) WHERE CompanyID=@c AND SaleID=@sale", ct, ("@c", Company), ("@sale", x.SaleId));
        if (sale.Count == 0 || Convert.ToString(sale[0]["StatusCode"]) != "COMPLETED") return BadRequest(new { message = "ไม่พบใบขายที่ใช้ได้", description = "เลือกใบขาย POS ของบริษัทนี้ที่ชำระเสร็จแล้ว" });
        if (booking[0]["BranchID"] is not null && Convert.ToInt64(booking[0]["BranchID"]) != Convert.ToInt64(sale[0]["BranchID"])) return BadRequest(new { message = "สาขาใบขายไม่ตรง", description = "เลือกใบขายจากสาขาเดียวกับรายการจอง" });
        try
        {
            await BookingDb.Exec(d, tx, "INSERT dbo.TDBKSaleLink(CompanyID,BookingID,SaleID,LinkedBy) VALUES(@c,@b,@sale,@u)", ct, ("@c", Company), ("@b", id), ("@sale", x.SaleId), ("@u", Actor));
            await BookingDb.Exec(d, tx, "INSERT dbo.TDBKBookingAudit(CompanyID,BookingID,ActionCode,ActorUserID,Reason) VALUES(@c,@b,N'LINK_SALE',@u,@reason)", ct, ("@c", Company), ("@b", id), ("@u", Actor), ("@reason", x.SaleId.ToString()));
            await tx.CommitAsync(ct);
            return NoContent();
        }
        catch (SqlException e) when (e.Number is 2601 or 2627) { return Conflict(new { message = "ใบขายถูกเชื่อมแล้ว", description = "ใบขายหนึ่งใบเชื่อมได้กับรายการจองเดียว" }); }
    }
}
