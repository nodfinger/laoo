using System.Data;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    public sealed record SettlementInput(decimal ApprovedDeduction, string Reason);
    public sealed record RefundInput(string Method, string? ReferenceNo, string IdempotencyKey);

    [HttpGet("bookings/{bookingId:long}/settlement")]
    public async Task<IActionResult> Settlement(long bookingId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "60008", "VIEW", ct) is { } denied) return denied;
        var scope = await BookingScope(db, null, bookingId, ct);
        if (scope is null) return NotFound();
        if (await BranchGuard(db, scope.Value.Branch, ct) is { } blocked) return blocked;
        var rows = await RentalDb.Rows(db, null,
            "SELECT * FROM dbo.TDRNSettlement WHERE CompanyID=@co AND BookingID=@id",
            ct, ("@co", Company), ("@id", bookingId));
        if (rows.Count > 0) return Ok(rows[0]);
        var proposal = await RentalDb.Rows(db, null, """
SELECT COALESCE(SUM(L.DamageAmount),0) damage,
COALESCE(SUM(L.LateFee),0) late FROM dbo.TDRNReturnLine L
JOIN dbo.TDRNReturn R ON R.CompanyID=L.CompanyID AND R.ReturnID=L.ReturnID
WHERE R.CompanyID=@co AND R.BookingID=@id
""", ct, ("@co", Company), ("@id", bookingId));
        return Ok(new { proposedDamage = proposal[0]["damage"], proposedLate = proposal[0]["late"] });
    }

    [HttpPost("bookings/{bookingId:long}/settlement/approve")]
    public async Task<IActionResult> ApproveSettlement(long bookingId,
        [FromBody] SettlementInput input, CancellationToken ct)
    {
        if (input.ApprovedDeduction < 0 || input.ApprovedDeduction > 1_000_000_000
            || string.IsNullOrWhiteSpace(input.Reason) || input.Reason.Length > 1000)
            return Invalid("Approved deduction requires an amount and reason");
        await using var db = await Open(ct);
        if (await Guard(db, "60008", "APPROVE", ct) is { } denied) return denied;
        var scope = await BookingScope(db, null, bookingId, ct);
        if (scope is null) return NotFound();
        if (await BranchGuard(db, scope.Value.Branch, ct) is { } blocked) return blocked;
        await using var tx = (Microsoft.Data.SqlClient.SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var bookings = await RentalDb.Rows(db, tx, """
SELECT StatusCode,TotalDeposit FROM dbo.TDRNBooking WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND BookingID=@id
""", ct, ("@co", Company), ("@id", bookingId));
        if (bookings.Count == 0) return NotFound();
        if (Convert.ToString(bookings[0]["StatusCode"]) != "RETURNED")
            return Conflict(new { message = "All items must be returned before settlement" });
        var proposal = await RentalDb.Rows(db, tx, """
SELECT COALESCE(SUM(L.DamageAmount),0) damage,
COALESCE(SUM(L.LateFee),0) late FROM dbo.TDRNReturnLine L
JOIN dbo.TDRNReturn R ON R.CompanyID=L.CompanyID AND R.ReturnID=L.ReturnID
WHERE R.CompanyID=@co AND R.BookingID=@id
""", ct, ("@co", Company), ("@id", bookingId));
        var deposit = Convert.ToDecimal(bookings[0]["TotalDeposit"]);
        var refund = Math.Max(0, deposit - input.ApprovedDeduction);
        var additional = Math.Max(0, input.ApprovedDeduction - deposit);
        await RentalDb.Execute(db, tx, """
INSERT dbo.TDRNSettlement(CompanyID,BookingID,ProposedDamage,ProposedLate,
ApprovedDeduction,RefundDue,AdditionalDue,Reason,StatusCode,ApprovedBy)
VALUES(@co,@id,@damage,@late,@approved,@refund,@additional,@reason,N'APPROVED',@actor)
""", ct, ("@co", Company), ("@id", bookingId),
            ("@damage", proposal[0]["damage"]), ("@late", proposal[0]["late"]),
            ("@approved", input.ApprovedDeduction), ("@refund", refund),
            ("@additional", additional), ("@reason", input.Reason.Trim()),
            ("@actor", Actor));
        await RentalDb.Execute(db, tx,
            "UPDATE dbo.TDRNBooking SET StatusCode=N'SETTLEMENT',UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND BookingID=@id",
            ct, ("@co", Company), ("@id", bookingId));
        await RentalDb.Audit(db, tx, Company, Actor, "DEDUCTION_APPROVED", bookingId, null,
            $"Approved={input.ApprovedDeduction};Reason={input.Reason.Trim()}", ct);
        await tx.CommitAsync(ct);
        return Ok(new { bookingId, approvedDeduction = input.ApprovedDeduction, refund, additional });
    }

    [HttpPost("bookings/{bookingId:long}/settlement/refund")]
    public async Task<IActionResult> RefundDeposit(long bookingId,
        [FromBody] RefundInput input, CancellationToken ct)
    {
        if (input.Method is not ("CASH" or "TRANSFER")
            || (input.Method == "TRANSFER" && string.IsNullOrWhiteSpace(input.ReferenceNo))
            || string.IsNullOrWhiteSpace(input.IdempotencyKey) || input.IdempotencyKey.Length > 100
            || input.ReferenceNo?.Length > 100)
            return Invalid("Invalid deposit refund");
        await using var db = await Open(ct);
        if (await Guard(db, "60008", "REFUND", ct) is { } denied) return denied;
        var scope = await BookingScope(db, null, bookingId, ct);
        if (scope is null) return NotFound();
        if (await BranchGuard(db, scope.Value.Branch, ct) is { } blocked) return blocked;
        var key = input.IdempotencyKey.Trim();
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            $"{bookingId}|REFUND|{input.Method}|{input.ReferenceNo?.Trim()}")));
        await using var tx = (Microsoft.Data.SqlClient.SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var booking = await RentalDb.Rows(db, tx,
            "SELECT StatusCode FROM dbo.TDRNBooking WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND BookingID=@id",
            ct, ("@co", Company), ("@id", bookingId));
        if (booking.Count == 0) return NotFound();
        var settlement = await RentalDb.Rows(db, tx, """
SELECT RefundDue,AdditionalDue,StatusCode FROM dbo.TDRNSettlement WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND BookingID=@id
""", ct, ("@co", Company), ("@id", bookingId));
        if (settlement.Count == 0) return Conflict(new { message = "Settlement is not approved" });
        if (Convert.ToString(booking[0]["StatusCode"]) == "CLOSED")
            return Ok(new { bookingId, status = "CLOSED", alreadyClosed = true });
        if (Convert.ToString(booking[0]["StatusCode"]) != "SETTLEMENT")
            return Conflict(new { message = "Booking is not ready for refund" });
        var due = Convert.ToDecimal(settlement[0]["AdditionalDue"]);
        var paid = await RentalDb.Money(db, tx, """
SELECT COALESCE(SUM(Amount),0) FROM dbo.TDRNPaymentLedger
WHERE CompanyID=@co AND BookingID=@id AND Kind=N'ADDITIONAL'
""", ct, ("@co", Company), ("@id", bookingId));
        if (paid < due) return Conflict(new { message = "Additional damage charge is unpaid" });
        var refund = Convert.ToDecimal(settlement[0]["RefundDue"]);
        long? paymentId = null;
        if (refund > 0)
            paymentId = await RentalDb.Number(db, tx, """
INSERT dbo.TDRNPaymentLedger(CompanyID,BookingID,Kind,Amount,Method,
ReferenceNo,IdempotencyKey,RequestHash,CreatedBy)
OUTPUT INSERTED.PaymentID
VALUES(@co,@id,N'DEPOSIT_REFUND',@amount,@method,@reference,@key,@hash,@actor)
""", ct, ("@co", Company), ("@id", bookingId), ("@amount", refund),
                ("@method", input.Method), ("@reference", input.ReferenceNo?.Trim()),
                ("@key", key), ("@hash", hash), ("@actor", Actor));
        await RentalDb.Execute(db, tx,
            "UPDATE dbo.TDRNSettlement SET StatusCode=N'REFUNDED',RefundedAt=SYSUTCDATETIME(),RefundedBy=@actor WHERE CompanyID=@co AND BookingID=@id",
            ct, ("@co", Company), ("@id", bookingId), ("@actor", Actor));
        await RentalDb.Execute(db, tx,
            "UPDATE dbo.TDRNBooking SET StatusCode=N'CLOSED',UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND BookingID=@id",
            ct, ("@co", Company), ("@id", bookingId));
        await RentalDb.Audit(db, tx, Company, Actor, "DEPOSIT_REFUNDED", bookingId, null,
            $"Refunded={refund};Additional={due}", ct);
        await tx.CommitAsync(ct);
        return Ok(new { bookingId, refunded = refund, paymentId, status = "CLOSED" });
    }
}
