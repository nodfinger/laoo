using System.Data;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    public sealed record PaymentInput(string Kind, decimal Amount, string Method,
        string? ReferenceNo, string IdempotencyKey);

    [HttpGet("bookings/{bookingId:long}")]
    public async Task<IActionResult> Booking(long bookingId, string menu = "60009", CancellationToken ct = default)
    {
        if (menu is not ("60005" or "60006" or "60007" or "60008" or "60009")) return NotFound();
        await using var db = await Open(ct);
        if (await Guard(db, menu, "VIEW", ct) is { } denied) return denied;
        var scope = await BookingScope(db, null, bookingId, ct);
        if (scope is null) return NotFound();
        if (await BranchGuard(db, scope.Value.Branch, ct) is { } blocked) return blocked;
        var header = await RentalDb.Rows(db, null,
            "SELECT BookingID,BookingCode,BranchID,CustomerID,StartAt,EndAt,ExpiresAt,StatusCode,TotalRent,TotalDeposit,CreatedAt,CreatedBy,UpdatedAt FROM dbo.TDRNBooking WHERE CompanyID=@co AND BookingID=@id",
            ct, ("@co", Company), ("@id", bookingId));
        var lines = await RentalDb.Rows(db, null,
            "SELECT * FROM dbo.TDRNBookingLine WHERE CompanyID=@co AND BookingID=@id ORDER BY BookingLineID",
            ct, ("@co", Company), ("@id", bookingId));
        var payments = await RentalDb.Rows(db, null,
            "SELECT PaymentID,Kind,Amount,Method,ReferenceNo,CreatedAt FROM dbo.TDRNPaymentLedger WHERE CompanyID=@co AND BookingID=@id ORDER BY PaymentID",
            ct, ("@co", Company), ("@id", bookingId));
        var returns = await RentalDb.Rows(db, null,
            "SELECT ReturnID,CreatedAt,CreatedBy FROM dbo.TDRNReturn WHERE CompanyID=@co AND BookingID=@id ORDER BY ReturnID",
            ct, ("@co", Company), ("@id", bookingId));
        var returnLines = await RentalDb.Rows(db, null, """
SELECT L.ReturnLineID returnLineId,L.BookingLineID bookingLineId,L.Quantity quantity,
L.ConditionCode condition,L.DamageAmount damageAmount,L.LateFee lateFee,L.Remark remark
FROM dbo.TDRNReturnLine L JOIN dbo.TDRNReturn R
 ON R.CompanyID=L.CompanyID AND R.ReturnID=L.ReturnID
WHERE R.CompanyID=@co AND R.BookingID=@id ORDER BY L.ReturnLineID
""", ct, ("@co", Company), ("@id", bookingId));
        var attachments = await RentalDb.Rows(db, null,
            "SELECT AttachmentID,BookingLineID,ReturnID,Kind,OriginalName,MimeType,SizeBytes,CreatedAt FROM dbo.TDRNAttachment WHERE CompanyID=@co AND BookingID=@id ORDER BY AttachmentID",
            ct, ("@co", Company), ("@id", bookingId));
        var settlement = await RentalDb.Rows(db, null,
            "SELECT ProposedDamage,ProposedLate,ApprovedDeduction,RefundDue,AdditionalDue,StatusCode FROM dbo.TDRNSettlement WHERE CompanyID=@co AND BookingID=@id",
            ct, ("@co", Company), ("@id", bookingId));
        var audit = await RentalDb.Rows(db, null,
            "SELECT EventCode,Detail,CreatedAt,ActorID FROM dbo.TDRNAudit WHERE CompanyID=@co AND BookingID=@id ORDER BY AuditID",
            ct, ("@co", Company), ("@id", bookingId));
        return Ok(new { header = header.Single(), lines, payments, returns, returnLines, attachments, settlement = settlement.SingleOrDefault(), audit });
    }

    [HttpPost("bookings/{bookingId:long}/payments")]
    public async Task<IActionResult> ReceivePayment(long bookingId, [FromBody] PaymentInput input,
        CancellationToken ct)
    {
        if (input.Kind is not ("RENT" or "DEPOSIT" or "ADDITIONAL") || input.Amount <= 0
            || input.Method is not ("CASH" or "TRANSFER")
            || (input.Method == "TRANSFER" && string.IsNullOrWhiteSpace(input.ReferenceNo))
            || string.IsNullOrWhiteSpace(input.IdempotencyKey) || input.IdempotencyKey.Length > 100
            || input.ReferenceNo?.Length > 100)
            return Invalid("Invalid rental payment");
        await using var db = await Open(ct);
        if (await Guard(db, "60005", "CREATE", ct) is { } denied) return denied;
        var scope = await BookingScope(db, null, bookingId, ct);
        if (scope is null) return NotFound();
        if (await BranchGuard(db, scope.Value.Branch, ct) is { } blocked) return blocked;
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            $"{bookingId}|{input.Kind}|{input.Amount}|{input.Method}|{input.ReferenceNo?.Trim()}")));
        var key = input.IdempotencyKey.Trim();
        await using var tx = (Microsoft.Data.SqlClient.SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var prior = await RentalDb.Rows(db, tx, """
SELECT PaymentID id,RequestHash hash FROM dbo.TDRNPaymentLedger WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND IdempotencyKey=@key
""", ct, ("@co", Company), ("@key", key));
        if (prior.Count != 0)
        {
            await tx.CommitAsync(ct);
            if (!string.Equals(Convert.ToString(prior[0]["hash"]), hash, StringComparison.Ordinal))
                return Conflict(new { message = "Idempotency key was used for another payment" });
            return Ok(new { id = prior[0]["id"], duplicate = true });
        }
        var bookings = await RentalDb.Rows(db, tx, """
SELECT StatusCode,ExpiresAt,TotalRent,TotalDeposit
FROM dbo.TDRNBooking WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND BookingID=@id
""", ct, ("@co", Company), ("@id", bookingId));
        if (bookings.Count == 0) return NotFound();
        var booking = bookings[0];
        var status = Convert.ToString(booking["StatusCode"]);
        if ((input.Kind == "ADDITIONAL" && status != "SETTLEMENT")
            || (input.Kind != "ADDITIONAL" && status is not ("RESERVED" or "PAID"))
            || (status == "RESERVED" && Convert.ToDateTime(booking["ExpiresAt"]) <= DateTime.UtcNow))
            return Conflict(new { message = "Booking is not payable" });
        var expected = input.Kind == "ADDITIONAL"
            ? await RentalDb.Money(db, tx,
                "SELECT AdditionalDue FROM dbo.TDRNSettlement WHERE CompanyID=@co AND BookingID=@id",
                ct, ("@co", Company), ("@id", bookingId))
            : Convert.ToDecimal(booking[input.Kind == "RENT" ? "TotalRent" : "TotalDeposit"]);
        var paid = await RentalDb.Money(db, tx, """
SELECT COALESCE(SUM(Amount),0) FROM dbo.TDRNPaymentLedger
WHERE CompanyID=@co AND BookingID=@id AND Kind=@kind
""", ct, ("@co", Company), ("@id", bookingId), ("@kind", input.Kind));
        if (paid + input.Amount > expected)
            return Conflict(new { message = "Payment exceeds amount due" });
        var paymentId = await RentalDb.Number(db, tx, """
INSERT dbo.TDRNPaymentLedger(CompanyID,BookingID,Kind,Amount,Method,
ReferenceNo,IdempotencyKey,RequestHash,CreatedBy)
OUTPUT INSERTED.PaymentID
VALUES(@co,@id,@kind,@amount,@method,@reference,@key,@hash,@actor)
""", ct, ("@co", Company), ("@id", bookingId), ("@kind", input.Kind),
            ("@amount", input.Amount), ("@method", input.Method),
            ("@reference", input.ReferenceNo?.Trim()), ("@key", key),
            ("@hash", hash), ("@actor", Actor));
        var remaining = await RentalDb.Rows(db, tx, """
SELECT B.TotalRent-COALESCE(SUM(CASE WHEN P.Kind=N'RENT' THEN P.Amount ELSE 0 END),0) rent,
B.TotalDeposit-COALESCE(SUM(CASE WHEN P.Kind=N'DEPOSIT' THEN P.Amount ELSE 0 END),0) deposit
FROM dbo.TDRNBooking B LEFT JOIN dbo.TDRNPaymentLedger P
 ON P.CompanyID=B.CompanyID AND P.BookingID=B.BookingID
WHERE B.CompanyID=@co AND B.BookingID=@id
GROUP BY B.TotalRent,B.TotalDeposit
""", ct, ("@co", Company), ("@id", bookingId));
        if ((status is "RESERVED" or "PAID") && Convert.ToDecimal(remaining[0]["rent"]) == 0 &&
            Convert.ToDecimal(remaining[0]["deposit"]) == 0)
            await RentalDb.Execute(db, tx,
                "UPDATE dbo.TDRNBooking SET StatusCode=N'PAID',ExpiresAt=EndAt WHERE CompanyID=@co AND BookingID=@id",
                ct, ("@co", Company), ("@id", bookingId));
        await RentalDb.Audit(db, tx, Company, Actor, "PAYMENT_RECEIVED", bookingId, null,
            $"{input.Kind}:{input.Amount}", ct);
        await tx.CommitAsync(ct);
        return Created($"/api/company/rental/bookings/{bookingId}",
            new { id = paymentId, bookingId, receiptNo = $"RN-P{paymentId:D8}" });
    }
}
