using System.Data;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    public sealed record CancelInput(string Reason, string RefundMethod, string? ReferenceNo);

    [HttpPost("bookings/{bookingId:long}/cancel")]
    public async Task<IActionResult> CancelBooking(long bookingId, [FromBody] CancelInput input,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Reason) || input.Reason.Length > 1000
            || input.RefundMethod is not ("CASH" or "TRANSFER")
            || (input.RefundMethod == "TRANSFER" && string.IsNullOrWhiteSpace(input.ReferenceNo))
            || input.ReferenceNo?.Length > 100)
            return Invalid("Cancellation reason and refund method are required");
        await using var db = await Open(ct);
        if (await Guard(db, "60004", "CANCEL", ct) is { } denied) return denied;
        var scope = await BookingScope(db, null, bookingId, ct);
        if (scope is null) return NotFound();
        if (await BranchGuard(db, scope.Value.Branch, ct) is { } blocked) return blocked;
        await using var tx = (Microsoft.Data.SqlClient.SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var status = await RentalDb.Rows(db, tx, """
SELECT StatusCode,StartAt FROM dbo.TDRNBooking WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND BookingID=@booking
""", ct, ("@co", Company), ("@booking", bookingId));
        if (status.Count == 0) return NotFound();
        if (Convert.ToString(status[0]["StatusCode"]) == "CANCELLED")
            return Ok(new { bookingId, duplicate = true });
        if (Convert.ToString(status[0]["StatusCode"]) is not ("RESERVED" or "PAID"))
            return Conflict(new { message = "Only bookings before handover can be cancelled" });
        var cancelBeforeHours = await RentalDb.Number(db, tx,
            "SELECT COALESCE((SELECT CancelBeforeHours FROM dbo.TDRNSetting WHERE CompanyID=@co),2)",
            ct, ("@co", Company));
        if (Convert.ToDateTime(status[0]["StartAt"]) <= DateTime.UtcNow.AddHours(cancelBeforeHours))
            return Conflict(new { message = "Cancellation window has closed" });
        var paid = await RentalDb.Rows(db, tx, """
SELECT Kind,SUM(Amount) Amount FROM dbo.TDRNPaymentLedger
WHERE CompanyID=@co AND BookingID=@booking AND Kind IN(N'RENT',N'DEPOSIT')
GROUP BY Kind
""", ct, ("@co", Company), ("@booking", bookingId));
        foreach (var row in paid)
        {
            var kind = Convert.ToString(row["Kind"])!;
            var amount = Convert.ToDecimal(row["Amount"]);
            if (amount <= 0) continue;
            var refundKind = kind + "_REFUND";
            var key = $"RN:CANCEL:{bookingId}:{kind}";
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
                $"{bookingId}|{refundKind}|{amount}|{input.RefundMethod}|{input.ReferenceNo?.Trim()}")));
            await RentalDb.Execute(db, tx, """
INSERT dbo.TDRNPaymentLedger(CompanyID,BookingID,Kind,Amount,Method,
ReferenceNo,IdempotencyKey,RequestHash,CreatedBy)
VALUES(@co,@booking,@kind,@amount,@method,@reference,@key,@hash,@actor)
""", ct, ("@co", Company), ("@booking", bookingId), ("@kind", refundKind),
                ("@amount", amount), ("@method", input.RefundMethod),
                ("@reference", input.ReferenceNo?.Trim()), ("@key", key),
                ("@hash", hash), ("@actor", Actor));
        }
        await RentalDb.Execute(db, tx, """
UPDATE dbo.TDRNBooking SET StatusCode=N'CANCELLED',CancelReason=@reason,
CancelledAt=SYSUTCDATETIME(),CancelledBy=@actor,UpdatedAt=SYSUTCDATETIME()
WHERE CompanyID=@co AND BookingID=@booking
""", ct, ("@co", Company), ("@booking", bookingId),
            ("@reason", input.Reason.Trim()), ("@actor", Actor));
        await RentalDb.Audit(db, tx, Company, Actor, "BOOKING_CANCELLED", bookingId, null,
            input.Reason.Trim(), ct);
        await tx.CommitAsync(ct);
        return Ok(new { bookingId, status = "CANCELLED", refunded = paid });
    }
}
