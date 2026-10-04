using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpPost("bookings/{id:long}/pay")]
    public async Task<IActionResult> PayBooking(long id, SportCounterPaymentInput input, CancellationToken ct)
    {
        if (input.IdempotencyKey == Guid.Empty || input.PaymentCode is not ("CASH" or "TRANSFER")
            || (input.PaymentCode == "TRANSFER" && string.IsNullOrWhiteSpace(input.PaymentReference)))
            return Invalid("ระบุวิธีรับเงินและเลขอ้างอิงสำหรับการโอน");
        await using var db = await Open(ct);
        if (await Guard(db, "54007", "RECORD_PAYMENT", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            var repeated = await SportDb.Id(db, tx,
                "SELECT COALESCE(MAX(PaymentID),0) FROM dbo.TDSPPayment WHERE CompanyID=@co AND IdempotencyKey=@key",
                ct, ("@co", Company), ("@key", input.IdempotencyKey));
            if (repeated > 0) { await tx.CommitAsync(ct); return Ok(new { id = repeated, repeated = true }); }
            var booking = await SportDb.Rows(db, tx, """
SELECT B.PriceSnapshot,B.StatusCode,B.PaymentDueAt
FROM dbo.TDSPBooking B WITH(UPDLOCK,HOLDLOCK)
WHERE B.CompanyID=@co AND B.BookingID=@booking
 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor AND UB.BranchID=B.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@booking", id), ("@actor", Actor));
            if (booking.Count != 1 || Convert.ToString(booking[0]["StatusCode"]) != "PENDING_PAYMENT"
                || booking[0]["PaymentDueAt"] is not DateTime due || due < DateTime.UtcNow)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "รับเงินไม่ได้", description = "รายการจองไม่อยู่ระหว่างรอชำระหรือหมดเวลาแล้ว" });
            }
            var amount = Convert.ToDecimal(booking[0]["PriceSnapshot"]);
            if (amount <= 0) { await tx.RollbackAsync(ct); return Invalid("ยอดรับต้องมากกว่า 0"); }
            var payment = await SportDb.Id(db, tx, """
INSERT dbo.TDSPPayment(CompanyID,BookingID,Amount,PaymentCode,PaymentReference,StatusCode,IdempotencyKey,CreatedBy)
OUTPUT INSERTED.PaymentID VALUES(@co,@booking,@amount,@code,@reference,N'RECORDED',@key,@actor)
""", ct, ("@co", Company), ("@booking", id), ("@amount", amount),
                ("@code", input.PaymentCode), ("@reference", input.PaymentReference?.Trim()),
                ("@key", input.IdempotencyKey), ("@actor", Actor));
            await SportDb.Execute(db, tx,
                "UPDATE dbo.TDSPBooking SET StatusCode=N'CONFIRMED',PaymentDueAt=NULL WHERE CompanyID=@co AND BookingID=@booking",
                ct, ("@co", Company), ("@booking", id));
            await tx.CommitAsync(ct);
            return Ok(new { id = payment, amount, status = "CONFIRMED" });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627 or 1205)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new { message = "รับเงินซ้ำหรือข้อมูลเปลี่ยน", description = "ตรวจรายการล่าสุดก่อนลองใหม่" });
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }
    [HttpPost("bookings/{id:long}/check-in")]
    public async Task<IActionResult> CheckIn(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54009", "CHECK_IN", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            var rows = await SportDb.Rows(db, tx, """
SELECT B.StartsAt,B.StatusCode,COALESCE(S.CheckInGraceMinutes,15) GraceMinutes
FROM dbo.TDSPBooking B WITH(UPDLOCK,HOLDLOCK)
LEFT JOIN dbo.TDSPSetting S ON S.CompanyID=B.CompanyID
WHERE B.CompanyID=@co AND B.BookingID=@booking
 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor AND UB.BranchID=B.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@booking", id), ("@actor", Actor));
            if (rows.Count != 1 || Convert.ToString(rows[0]["StatusCode"]) != "CONFIRMED")
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "เช็กอินไม่ได้", description = "รายการจองต้องยืนยันก่อนและยังไม่เคยเช็กอิน" });
            }
            var start = (DateTime)rows[0]["StartsAt"]!;
            var grace = Convert.ToInt32(rows[0]["GraceMinutes"]);
            if (DateTime.UtcNow < start.AddMinutes(-15) || DateTime.UtcNow > start.AddMinutes(grace))
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "อยู่นอกเวลาเช็กอิน", description = "ตรวจเวลาเริ่มและเวลาผ่อนผันของสนาม" });
            }
            await SportDb.Execute(db, tx, """
UPDATE dbo.TDSPBooking SET StatusCode=N'CHECKED_IN',CheckedInAt=SYSUTCDATETIME(),CheckedInBy=@actor
WHERE CompanyID=@co AND BookingID=@booking;
UPDATE dbo.TDSPMembershipUse SET StatusCode=N'CONSUMED',FinalizedAt=SYSUTCDATETIME()
WHERE CompanyID=@co AND BookingID=@booking AND StatusCode=N'RESERVED';
""", ct, ("@co", Company), ("@booking", id), ("@actor", Actor));
            await tx.CommitAsync(ct);
            return Ok(new { checkedIn = true, bookingId = id });
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }
    [HttpPost("bookings/{id:long}/cancel")]
    public async Task<IActionResult> CancelBooking(long id, SportCancelInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Reason)) return Invalid("ระบุเหตุผลยกเลิก");
        await using var db = await Open(ct);
        if (await Guard(db, "54008", "CANCEL", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            var rows = await SportDb.Rows(db, tx, """
SELECT B.StartsAt,B.StatusCode,B.MembershipID,COALESCE(S.CancelBeforeMinutes,120) CancelBeforeMinutes
FROM dbo.TDSPBooking B WITH(UPDLOCK,HOLDLOCK)
LEFT JOIN dbo.TDSPSetting S ON S.CompanyID=B.CompanyID
WHERE B.CompanyID=@co AND B.BookingID=@booking
 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor AND UB.BranchID=B.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@booking", id), ("@actor", Actor));
            if (rows.Count != 1 || Convert.ToString(rows[0]["StatusCode"]) is not ("PENDING_PAYMENT" or "CONFIRMED"))
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "ยกเลิกไม่ได้", description = "รายการจองไม่อยู่ในสถานะที่ยกเลิกได้" });
            }
            if ((DateTime)rows[0]["StartsAt"]! < DateTime.UtcNow.AddMinutes(Convert.ToInt32(rows[0]["CancelBeforeMinutes"])))
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "พ้นเวลายกเลิก", description = "ต้องยกเลิกก่อนเวลาเริ่มตามค่าที่บริษัทกำหนด" });
            }
            // Paid drop-in bookings require a separate refund workflow; never silently discard payment.
            if (rows[0]["MembershipID"] is null && Convert.ToString(rows[0]["StatusCode"]) == "CONFIRMED")
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "รายการนี้รับเงินแล้ว", description = "ให้พนักงานทำคืนเงินก่อนยกเลิก" });
            }
            await SportDb.Execute(db, tx, """
UPDATE dbo.TDSPBooking SET StatusCode=N'CANCELLED',CancelledAt=SYSUTCDATETIME(),CancelReason=@reason
WHERE CompanyID=@co AND BookingID=@booking;
UPDATE dbo.TDSPMembershipUse SET StatusCode=N'RELEASED',FinalizedAt=SYSUTCDATETIME()
WHERE CompanyID=@co AND BookingID=@booking AND StatusCode=N'RESERVED';
""", ct, ("@co", Company), ("@booking", id), ("@reason", input.Reason.Trim()));
            await tx.CommitAsync(ct);
            return Ok(new { cancelled = true, bookingId = id });
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }

    [HttpPost("bookings/{id:long}/no-show")]
    public async Task<IActionResult> MarkNoShow(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54009", "MARK_NO_SHOW", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            var rows = await SportDb.Rows(db, tx, """
SELECT B.StartsAt,B.StatusCode,COALESCE(S.CheckInGraceMinutes,15) GraceMinutes
FROM dbo.TDSPBooking B WITH(UPDLOCK,HOLDLOCK)
LEFT JOIN dbo.TDSPSetting S ON S.CompanyID=B.CompanyID
WHERE B.CompanyID=@co AND B.BookingID=@booking
 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor
 AND UB.BranchID=B.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@booking", id), ("@actor", Actor));
            if (rows.Count != 1 || Convert.ToString(rows[0]["StatusCode"]) != "CONFIRMED"
                || DateTime.UtcNow <= ((DateTime)rows[0]["StartsAt"]!).AddMinutes(Convert.ToInt32(rows[0]["GraceMinutes"])))
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "ยังบันทึกไม่มาไม่ได้",
                    description = "ตรวจสถานะการจองและรอให้พ้นเวลาผ่อนผันก่อน" });
            }
            await SportDb.Execute(db, tx, """
UPDATE dbo.TDSPBooking SET StatusCode=N'NO_SHOW' WHERE CompanyID=@co AND BookingID=@booking;
UPDATE dbo.TDSPMembershipUse SET StatusCode=N'CONSUMED',FinalizedAt=SYSUTCDATETIME()
WHERE CompanyID=@co AND BookingID=@booking AND StatusCode=N'RESERVED';
""", ct, ("@co", Company), ("@booking", id));
            await tx.CommitAsync(ct);
            return Ok(new { bookingId = id, status = "NO_SHOW" });
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }
}

public sealed record SportCounterPaymentInput(Guid IdempotencyKey,string PaymentCode,string? PaymentReference);
public sealed record SportCancelInput(string Reason);
