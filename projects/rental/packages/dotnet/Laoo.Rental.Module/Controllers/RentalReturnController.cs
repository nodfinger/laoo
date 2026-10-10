using System.Data;
using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    public sealed record ReturnLineInput(long BookingLineId, int Quantity, string Condition,
        decimal DamageAmount, string? Remark, List<long> InstanceIds);
    public sealed record ReturnInput(long StaffSignAttachmentId,
        long CustomerSignAttachmentId, List<ReturnLineInput> Lines);

    [HttpPost("bookings/{bookingId:long}/returns")]
    public async Task<IActionResult> ReceiveReturn(long bookingId, [FromBody] ReturnInput input,
        CancellationToken ct)
    {
        if (input.StaffSignAttachmentId <= 0 || input.CustomerSignAttachmentId <= 0
            || input.StaffSignAttachmentId == input.CustomerSignAttachmentId
            || input.Lines is null || input.Lines.Count is < 1 or > 100
            || input.Lines.GroupBy(x => x.BookingLineId).Any(x => x.Count() != 1)
            || input.Lines.Any(x => x.Quantity <= 0 || x.DamageAmount < 0
                || x.Condition is not ("OK" or "DAMAGED" or "LOST") || x.Remark?.Length > 1000)
            || input.Lines.SelectMany(x => x.InstanceIds ?? []).Distinct().Count()
                != input.Lines.Sum(x => x.InstanceIds?.Count ?? 0))
            return Invalid("Invalid rental return");
        await using var db = await Open(ct);
        if (await Guard(db, "60007", "CREATE", ct) is { } denied) return denied;
        var scope = await BookingScope(db, null, bookingId, ct);
        if (scope is null) return NotFound();
        if (await BranchGuard(db, scope.Value.Branch, ct) is { } blocked) return blocked;
        await using var tx = (Microsoft.Data.SqlClient.SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var booking = await RentalDb.Rows(db, tx, """
SELECT StatusCode,EndAt FROM dbo.TDRNBooking WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND BookingID=@booking
""", ct, ("@co", Company), ("@booking", bookingId));
        if (booking.Count == 0) return NotFound();
        if (Convert.ToString(booking[0]["StatusCode"]) is not ("OUT" or "PARTIAL_RETURN"))
            return Conflict(new { message = "Booking has not been handed over" });
        var signs = await RentalDb.Number(db, tx, """
SELECT COUNT(*) FROM dbo.TDRNAttachment
WHERE CompanyID=@co AND BookingID=@booking AND ReturnID IS NULL
AND ((AttachmentID=@staff AND Kind=N'RETURN_STAFF_SIGN')
 OR (AttachmentID=@customer AND Kind=N'RETURN_CUSTOMER_SIGN'))
""", ct, ("@co", Company), ("@booking", bookingId),
            ("@staff", input.StaffSignAttachmentId), ("@customer", input.CustomerSignAttachmentId));
        if (signs != 2) return Invalid("Return signatures are missing");
        var returnId = await RentalDb.Number(db, tx, """
INSERT dbo.TDRNReturn(CompanyID,BookingID,StaffSignAttachmentID,
CustomerSignAttachmentID,CreatedBy)
OUTPUT INSERTED.ReturnID VALUES(@co,@booking,@staff,@customer,@actor)
""", ct, ("@co", Company), ("@booking", bookingId),
            ("@staff", input.StaffSignAttachmentId),
            ("@customer", input.CustomerSignAttachmentId), ("@actor", Actor));
        await RentalDb.Execute(db, tx, """
UPDATE dbo.TDRNAttachment SET ReturnID=@return
WHERE CompanyID=@co AND BookingID=@booking AND ReturnID IS NULL
AND AttachmentID IN(@staff,@customer)
""", ct, ("@co", Company), ("@booking", bookingId), ("@return", returnId),
            ("@staff", input.StaffSignAttachmentId),
            ("@customer", input.CustomerSignAttachmentId));
        var endAt = Convert.ToDateTime(booking[0]["EndAt"]);
        foreach (var line in input.Lines.OrderBy(x => x.BookingLineId))
        {
            var original = await RentalDb.Rows(db, tx, """
SELECT ItemID,WarehouseID,Quantity,RateUnitSnapshot,RateSnapshot,RequireSerialSnapshot
FROM dbo.TDRNBookingLine WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND BookingID=@booking AND BookingLineID=@line
""", ct, ("@co", Company), ("@booking", bookingId), ("@line", line.BookingLineId));
            if (original.Count == 0) return Invalid("Return line does not belong to booking");
            var already = await RentalDb.Number(db, tx, """
SELECT COALESCE(SUM(Quantity),0) FROM dbo.TDRNReturnLine
WHERE CompanyID=@co AND BookingLineID=@line
""", ct, ("@co", Company), ("@line", line.BookingLineId));
            var row = original[0];
            if (line.Quantity > Convert.ToInt32(row["Quantity"]) - already)
                return Conflict(new { message = "Return quantity exceeds outstanding", line.BookingLineId });
            if (await RentalDb.Number(db, tx, """
SELECT COUNT(*) FROM dbo.TDRNAttachment
WHERE CompanyID=@co AND BookingID=@booking AND BookingLineID=@line
AND Kind=N'RETURN_PHOTO' AND ReturnID IS NULL
""", ct, ("@co", Company), ("@booking", bookingId), ("@line", line.BookingLineId)) == 0)
                return Invalid($"Return photo is missing for line {line.BookingLineId}");
            var serials = line.InstanceIds ?? [];
            var requires = Convert.ToBoolean(row["RequireSerialSnapshot"]);
            if ((requires && serials.Count != line.Quantity) || (!requires && serials.Count > line.Quantity))
                return Invalid($"Serial count does not match line {line.BookingLineId}");
            var late = DateTime.UtcNow > endAt ? DateTime.UtcNow - endAt : TimeSpan.Zero;
            var lateUnits = Convert.ToString(row["RateUnitSnapshot"]) == "HOUR"
                ? (decimal)Math.Ceiling(late.TotalHours) : (decimal)Math.Ceiling(late.TotalDays);
            var lateFee = lateUnits * Convert.ToDecimal(row["RateSnapshot"]) * line.Quantity;
            var returnLineId = await RentalDb.Number(db, tx, """
INSERT dbo.TDRNReturnLine(CompanyID,ReturnID,BookingLineID,Quantity,
ConditionCode,DamageAmount,LateFee,Remark)
OUTPUT INSERTED.ReturnLineID
VALUES(@co,@return,@line,@qty,@condition,@damage,@late,@remark)
""", ct, ("@co", Company), ("@return", returnId), ("@line", line.BookingLineId),
                ("@qty", line.Quantity), ("@condition", line.Condition),
                ("@damage", line.DamageAmount), ("@late", lateFee),
                ("@remark", line.Remark?.Trim()));
            await RentalDb.Execute(db, tx, """
UPDATE dbo.TDRNAttachment SET ReturnID=@return
WHERE CompanyID=@co AND BookingID=@booking AND BookingLineID=@line
AND Kind=N'RETURN_PHOTO' AND ReturnID IS NULL
""", ct, ("@co", Company), ("@booking", bookingId),
                ("@line", line.BookingLineId), ("@return", returnId));
            var item = Convert.ToInt64(row["ItemID"]);
            var warehouse = Convert.ToInt64(row["WarehouseID"]);
            foreach (var instance in serials)
            {
                var updated = await RentalDb.Execute(db, tx, """
UPDATE dbo.TDRNSerialAssignment WITH(UPDLOCK,HOLDLOCK)
SET ReturnID=@return,ReturnedAt=SYSUTCDATETIME()
WHERE CompanyID=@co AND BookingID=@booking AND BookingLineID=@line
AND ItemInstanceID=@instance AND ReturnID IS NULL
""", ct, ("@co", Company), ("@booking", bookingId),
                    ("@line", line.BookingLineId), ("@instance", instance), ("@return", returnId));
                if (updated != 1) return Conflict(new { message = "Serial was not handed over or was already returned", instance });
                var newStatus = line.Condition switch
                {
                    "OK" => "IN_STOCK", "DAMAGED" => "REPAIR", _ => "RETIRED"
                };
                updated = await RentalDb.Execute(db, tx, """
UPDATE dbo.TDIVItemInstance WITH(UPDLOCK,HOLDLOCK)
SET StatusCode=@status,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@actor
WHERE CompanyID=@co AND ItemInstanceID=@instance AND ItemID=@item AND StatusCode=N'ISSUED'
""", ct, ("@co", Company), ("@instance", instance), ("@item", item),
                    ("@status", newStatus), ("@actor", Actor));
                if (updated != 1) return Conflict(new { message = "Serial state changed", instance });
                await RentalDb.Execute(db, tx, """
INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,
WarehouseID,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy)
VALUES(@co,@instance,N'ISSUED',@status,@warehouse,N'RENTAL_RETURN',@return,@line,N'Rental return',@actor)
""", ct, ("@co", Company), ("@instance", instance), ("@status", newStatus),
                    ("@warehouse", warehouse), ("@return", returnId),
                    ("@line", returnLineId), ("@actor", Actor));
            }
            if (line.Condition == "OK")
            {
                await RentalDb.Execute(db, tx, """
UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK)
SET Quantity=Quantity+@qty,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@co AND WarehouseID=@warehouse AND ItemID=@item
""", ct, ("@co", Company), ("@warehouse", warehouse),
                    ("@item", item), ("@qty", line.Quantity));
                await RentalDb.Execute(db, tx, """
INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,
DocumentDetailID,MovementType,Quantity,Remark,CreatedBy)
VALUES(@co,@warehouse,@item,N'RENTAL_RETURN',@return,@line,N'RECEIPT',@qty,N'Rental return',@actor)
""", ct, ("@co", Company), ("@warehouse", warehouse), ("@item", item),
                    ("@return", returnId), ("@line", returnLineId),
                    ("@qty", line.Quantity), ("@actor", Actor));
            }
        }
        var outstanding = await RentalDb.Number(db, tx, """
SELECT COALESCE(SUM(L.Quantity-COALESCE(R.Returned,0)),0)
FROM dbo.TDRNBookingLine L
OUTER APPLY(SELECT SUM(X.Quantity) Returned FROM dbo.TDRNReturnLine X
 WHERE X.CompanyID=L.CompanyID AND X.BookingLineID=L.BookingLineID) R
WHERE L.CompanyID=@co AND L.BookingID=@booking
""", ct, ("@co", Company), ("@booking", bookingId));
        if (outstanding == 0 && await RentalDb.Number(db, tx, """
SELECT COUNT(*) FROM dbo.TDRNSerialAssignment
WHERE CompanyID=@co AND BookingID=@booking AND ReturnID IS NULL
""", ct, ("@co", Company), ("@booking", bookingId)) > 0)
            return Conflict(new { message = "Scanned serials are still outstanding" });
        await RentalDb.Execute(db, tx,
            "UPDATE dbo.TDRNBooking SET StatusCode=@status,UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND BookingID=@booking",
            ct, ("@co", Company), ("@booking", bookingId),
            ("@status", outstanding == 0 ? "RETURNED" : "PARTIAL_RETURN"));
        await RentalDb.Audit(db, tx, Company, Actor, "RETURN_RECEIVED", bookingId, null,
            $"ReturnID={returnId};Outstanding={outstanding}", ct);
        await tx.CommitAsync(ct);
        return Ok(new { returnId, bookingId, outstanding });
    }
}
