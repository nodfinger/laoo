using System.Data;
using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    [HttpGet("items/{rentalItemId:long}/serial-lookup")]
    public async Task<IActionResult> TransferSerialLookup(long rentalItemId, long otherWarehouseId,
        string direction, string serialNo, CancellationToken ct)
    {
        if (rentalItemId <= 0 || otherWarehouseId <= 0 || string.IsNullOrWhiteSpace(serialNo)
            || serialNo.Length > 200 || direction is not ("TO_RENTAL" or "FROM_RENTAL"))
            return Invalid("กรุณาตรวจสอบทิศทางคลังและ Serial Number");
        await using var db = await Open(ct);
        if (await Guard(db, "60002", "EDIT", ct) is { } denied) return denied;
        var rental = await RentalDb.Rows(db, null, """
SELECT R.BranchID,R.ItemID,R.WarehouseID FROM dbo.TDRNItem R
WHERE R.CompanyID=@co AND R.RentalItemID=@rental AND R.IsActive=1
""", ct, ("@co", Company), ("@rental", rentalItemId));
        if (rental.Count == 0) return NotFound();
        if (await BranchGuard(db, Convert.ToInt64(rental[0]["BranchID"]), ct) is { } blocked) return blocked;
        var other = await RentalDb.Rows(db, null, """
SELECT BranchID FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND WarehouseID=@warehouse
AND IsActive=1 AND WarehouseCode NOT LIKE N'RENTAL-%'
""", ct, ("@co", Company), ("@warehouse", otherWarehouseId));
        if (other.Count == 0) return NotFound();
        if (await BranchGuard(db, Convert.ToInt64(other[0]["BranchID"]), ct) is { } otherBlocked)
            return otherBlocked;
        var source = direction == "TO_RENTAL" ? otherWarehouseId : Convert.ToInt64(rental[0]["WarehouseID"]);
        var instance = await RentalDb.Rows(db, null, """
SELECT I.ItemInstanceID id,I.SerialNo serialNo FROM dbo.TDIVItemInstance I
WHERE I.CompanyID=@co AND I.ItemID=@item AND I.WarehouseID=@warehouse
AND I.SerialNo=@serial AND I.StatusCode=N'IN_STOCK'
""", ct, ("@co", Company), ("@item", rental[0]["ItemID"]),
            ("@warehouse", source), ("@serial", serialNo.Trim()));
        return instance.Count == 0 ? NotFound() : Ok(instance[0]);
    }

    public sealed record SerialSelection(long BookingLineId, List<long> InstanceIds);
    public sealed record HandoverInput(long StaffSignAttachmentId,
        long CustomerSignAttachmentId, List<SerialSelection> Serials);

    [HttpGet("bookings/{bookingId:long}/serial-lookup")]
    public async Task<IActionResult> SerialLookup(long bookingId, string serialNo,
        string stage, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(serialNo) || serialNo.Length > 200
            || stage is not ("HANDOVER" or "RETURN"))
            return Invalid("Invalid serial lookup");
        await using var db = await Open(ct);
        if (await Guard(db, stage == "HANDOVER" ? "60006" : "60007", "CREATE", ct) is { } denied)
            return denied;
        var scope = await BookingScope(db, null, bookingId, ct);
        if (scope is null) return NotFound();
        if (await BranchGuard(db, scope.Value.Branch, ct) is { } blocked) return blocked;
        if ((stage == "HANDOVER" && scope.Value.Status is not ("RESERVED" or "PAID"))
            || (stage == "RETURN" && scope.Value.Status is not ("OUT" or "PARTIAL_RETURN")))
            return Conflict(new { message = "Serial lookup is unavailable in this booking state" });
        var rows = await RentalDb.Rows(db, null, """
SELECT I.ItemInstanceID id,I.SerialNo serialNo,L.BookingLineID bookingLineId,
L.ItemID itemId,I.StatusCode status
FROM dbo.TDRNBookingLine L
JOIN dbo.TDIVItemInstance I ON I.CompanyID=L.CompanyID AND I.ItemID=L.ItemID
WHERE L.CompanyID=@co AND L.BookingID=@booking AND I.SerialNo=@serial
AND ((@stage=N'HANDOVER' AND I.WarehouseID=L.WarehouseID AND I.StatusCode=N'IN_STOCK')
 OR (@stage=N'RETURN' AND I.StatusCode=N'ISSUED'
 AND EXISTS(SELECT 1 FROM dbo.TDRNSerialAssignment S
 WHERE S.CompanyID=L.CompanyID AND S.BookingLineID=L.BookingLineID
 AND S.ItemInstanceID=I.ItemInstanceID AND S.ReturnID IS NULL)))
""", ct, ("@co", Company), ("@booking", bookingId),
            ("@serial", serialNo.Trim()), ("@stage", stage));
        return rows.Count == 0 ? NotFound() : Ok(rows[0]);
    }

    [HttpPost("bookings/{bookingId:long}/handover")]
    public async Task<IActionResult> Handover(long bookingId, [FromBody] HandoverInput input,
        CancellationToken ct)
    {
        if (input.StaffSignAttachmentId <= 0 || input.CustomerSignAttachmentId <= 0
            || input.StaffSignAttachmentId == input.CustomerSignAttachmentId
            || input.Serials is null || input.Serials.GroupBy(x => x.BookingLineId).Any(x => x.Count() != 1)
            || input.Serials.SelectMany(x => x.InstanceIds ?? []).Distinct().Count()
                != input.Serials.Sum(x => x.InstanceIds?.Count ?? 0))
            return Invalid("Invalid handover signatures or serials");
        await using var db = await Open(ct);
        if (await Guard(db, "60006", "CREATE", ct) is { } denied) return denied;
        var scope = await BookingScope(db, null, bookingId, ct);
        if (scope is null) return NotFound();
        if (await BranchGuard(db, scope.Value.Branch, ct) is { } blocked) return blocked;
        await using var tx = (Microsoft.Data.SqlClient.SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var status = await RentalDb.Rows(db, tx, """
SELECT StatusCode,TotalRent,TotalDeposit,ExpiresAt FROM dbo.TDRNBooking WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND BookingID=@booking
""", ct, ("@co", Company), ("@booking", bookingId));
        if (status.Count == 0) return NotFound();
        var zeroPrice = Convert.ToDecimal(status[0]["TotalRent"]) == 0
            && Convert.ToDecimal(status[0]["TotalDeposit"]) == 0;
        if (Convert.ToString(status[0]["StatusCode"]) != "PAID"
            && !(zeroPrice && Convert.ToString(status[0]["StatusCode"]) == "RESERVED"
            && Convert.ToDateTime(status[0]["ExpiresAt"]) > DateTime.UtcNow))
            return Conflict(new { message = "Rent and deposit must be paid before handover" });
        var signs = await RentalDb.Number(db, tx, """
SELECT COUNT(*) FROM dbo.TDRNAttachment
WHERE CompanyID=@co AND BookingID=@booking
AND ((AttachmentID=@staff AND Kind=N'HANDOVER_STAFF_SIGN')
 OR (AttachmentID=@customer AND Kind=N'HANDOVER_CUSTOMER_SIGN'))
""", ct, ("@co", Company), ("@booking", bookingId),
            ("@staff", input.StaffSignAttachmentId), ("@customer", input.CustomerSignAttachmentId));
        if (signs != 2) return Invalid("Handover signatures are missing");
        var lines = await RentalDb.Rows(db, tx, """
SELECT BookingLineID,ItemID,WarehouseID,Quantity,RequireSerialSnapshot
FROM dbo.TDRNBookingLine WHERE CompanyID=@co AND BookingID=@booking ORDER BY BookingLineID
""", ct, ("@co", Company), ("@booking", bookingId));
        foreach (var line in lines)
        {
            var lineId = Convert.ToInt64(line["BookingLineID"]);
            if (await RentalDb.Number(db, tx, """
SELECT COUNT(*) FROM dbo.TDRNAttachment
WHERE CompanyID=@co AND BookingID=@booking AND BookingLineID=@line AND Kind=N'HANDOVER_PHOTO'
""", ct, ("@co", Company), ("@booking", bookingId), ("@line", lineId)) == 0)
                return Invalid($"Handover photo is missing for line {lineId}");
            var serials = input.Serials.SingleOrDefault(x => x.BookingLineId == lineId)?.InstanceIds ?? [];
            var requires = Convert.ToBoolean(line["RequireSerialSnapshot"]);
            if (requires && serials.Count != Convert.ToInt32(line["Quantity"]))
                return Invalid($"Serial count does not match line {lineId}");
            if (!requires && serials.Count > Convert.ToInt32(line["Quantity"]))
                return Invalid($"Too many serials for line {lineId}");
        }
        var handoverId = await RentalDb.Number(db, tx, """
INSERT dbo.TDRNHandover(CompanyID,BookingID,StaffSignAttachmentID,
CustomerSignAttachmentID,CreatedBy)
OUTPUT INSERTED.HandoverID VALUES(@co,@booking,@staff,@customer,@actor)
""", ct, ("@co", Company), ("@booking", bookingId),
            ("@staff", input.StaffSignAttachmentId),
            ("@customer", input.CustomerSignAttachmentId), ("@actor", Actor));
        foreach (var line in lines)
        {
            var lineId = Convert.ToInt64(line["BookingLineID"]);
            var item = Convert.ToInt64(line["ItemID"]);
            var warehouse = Convert.ToInt64(line["WarehouseID"]);
            var quantity = Convert.ToInt32(line["Quantity"]);
            var changed = await RentalDb.Execute(db, tx, """
UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK)
SET Quantity=Quantity-@qty,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@co AND WarehouseID=@warehouse AND ItemID=@item AND Quantity>=@qty
""", ct, ("@co", Company), ("@warehouse", warehouse), ("@item", item), ("@qty", quantity));
            if (changed != 1) return Conflict(new { message = "Rental stock changed before handover", lineId });
            await RentalDb.Execute(db, tx, """
INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,
DocumentDetailID,MovementType,Quantity,Remark,CreatedBy)
VALUES(@co,@warehouse,@item,N'RENTAL',@booking,@line,N'ISSUE',-@qty,N'Rental handover',@actor)
""", ct, ("@co", Company), ("@warehouse", warehouse), ("@item", item),
                ("@booking", bookingId), ("@line", lineId), ("@qty", quantity), ("@actor", Actor));
            var selected = input.Serials.SingleOrDefault(x => x.BookingLineId == lineId)?.InstanceIds ?? [];
            foreach (var instance in selected)
            {
                var updated = await RentalDb.Execute(db, tx, """
UPDATE dbo.TDIVItemInstance WITH(UPDLOCK,HOLDLOCK)
SET StatusCode=N'ISSUED',UpdateDate=SYSUTCDATETIME(),UpdatedBy=@actor
WHERE CompanyID=@co AND ItemInstanceID=@instance AND ItemID=@item
AND WarehouseID=@warehouse AND StatusCode=N'IN_STOCK'
""", ct, ("@co", Company), ("@instance", instance), ("@item", item),
                    ("@warehouse", warehouse), ("@actor", Actor));
                if (updated != 1) return Conflict(new { message = "Serial is not available", instance });
                await RentalDb.Execute(db, tx, """
INSERT dbo.TDRNSerialAssignment(CompanyID,BookingID,BookingLineID,ItemInstanceID)
VALUES(@co,@booking,@line,@instance)
""", ct, ("@co", Company), ("@booking", bookingId),
                    ("@line", lineId), ("@instance", instance));
                await RentalDb.Execute(db, tx, """
INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,
WarehouseID,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy)
VALUES(@co,@instance,N'IN_STOCK',N'ISSUED',@warehouse,N'RENTAL',@booking,@line,N'Rental handover',@actor)
""", ct, ("@co", Company), ("@instance", instance), ("@warehouse", warehouse),
                    ("@booking", bookingId), ("@line", lineId), ("@actor", Actor));
            }
        }
        await RentalDb.Execute(db, tx,
            "UPDATE dbo.TDRNBooking SET StatusCode=N'OUT',UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND BookingID=@booking",
            ct, ("@co", Company), ("@booking", bookingId));
        await RentalDb.Audit(db, tx, Company, Actor, "HANDED_OVER", bookingId, null,
            $"HandoverID={handoverId}", ct);
        await tx.CommitAsync(ct);
        return Ok(new { handoverId, bookingId, status = "OUT" });
    }
}
