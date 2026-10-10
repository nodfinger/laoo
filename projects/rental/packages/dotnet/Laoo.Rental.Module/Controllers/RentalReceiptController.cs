using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    [HttpGet("payments/{paymentId:long}/receipt-data")]
    public async Task<IActionResult> ReceiptData(long paymentId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (!RentalAccess.Scope(User, out _, out _)) return Forbid();
        var rows = await RentalDb.Rows(db, null, """
SELECT P.PaymentID,P.BookingID,P.Kind,P.Amount,P.Method,P.ReferenceNo,P.CreatedAt,
B.BookingCode,B.BranchID,B.StartAt,B.EndAt,B.CustomerID,
C.CusCode,C.CusName,C.CusAddress,C.TaxID customerTaxId
FROM dbo.TDRNPaymentLedger P
JOIN dbo.TDRNBooking B ON B.CompanyID=P.CompanyID AND B.BookingID=P.BookingID
JOIN dbo.TDARCustomer C ON C.CompanyID=B.CompanyID AND C.CustomerID=B.CustomerID
WHERE P.CompanyID=@co AND P.PaymentID=@id
""", ct, ("@co", Company), ("@id", paymentId));
        if (rows.Count == 0) return NotFound();
        var isRefund = Convert.ToString(rows[0]["Kind"])!.EndsWith("_REFUND", StringComparison.Ordinal);
        if (await Guard(db, isRefund ? "60008" : "60005", "VIEW", ct) is { } denied) return denied;
        if (await BranchGuard(db, Convert.ToInt64(rows[0]["BranchID"]), ct) is { } blocked)
            return blocked;
        var company = await RentalDb.Rows(db, null, """
SELECT COALESCE(NULLIF(CustomerNameTH,N''),NULLIF(CustomerNameEN,N''),
NULLIF(Name,N''),N'-') companyName,
COALESCE(AddressText,N'') address,COALESCE(Telephone,N'') phone,
COALESCE(EmailCenter,N'') email,COALESCE(TaxID,N'') taxId
FROM dbo.TDSTCompanySetUp WHERE CompanyID=@co AND OwnerType=N'C' AND IsActive=1
""", ct, ("@co", Company));
        if (company.Count == 0) return NotFound();
        var lines = await RentalDb.Rows(db, null, """
SELECT L.BookingLineID,L.Quantity,L.RateUnitSnapshot,L.RateSnapshot,
L.RentAmount,L.DepositAmount,I.ItemCode,I.ItemName
FROM dbo.TDRNBookingLine L
JOIN dbo.TDIVItem I ON I.CompanyID=L.CompanyID AND I.ItemID=L.ItemID
WHERE L.CompanyID=@co AND L.BookingID=@booking
ORDER BY L.BookingLineID
""", ct, ("@co", Company), ("@booking", rows[0]["BookingID"]));
        return Ok(new { documentNo = $"{(isRefund ? "RN-R" : "RN-P")}{paymentId:D8}",
            company = company[0], payment = rows[0], lines });
    }
}
