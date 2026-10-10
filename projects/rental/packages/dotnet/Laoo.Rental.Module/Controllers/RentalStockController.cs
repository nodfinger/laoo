using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    public sealed record StockTransferInput(long RentalItemId, long OtherWarehouseId,
        string Direction, int Quantity, List<long> InstanceIds, string IdempotencyKey);

    [HttpPost("stock-transfers")]
    public async Task<IActionResult> TransferStock([FromBody] StockTransferInput input,
        CancellationToken ct)
    {
        if (input.RentalItemId <= 0 || input.OtherWarehouseId <= 0
            || input.Direction is not ("TO_RENTAL" or "FROM_RENTAL")
            || input.Quantity is < 1 or > 10000
            || input.InstanceIds is null || input.InstanceIds.Count > input.Quantity
            || input.InstanceIds.Distinct().Count() != input.InstanceIds.Count
            || string.IsNullOrWhiteSpace(input.IdempotencyKey) || input.IdempotencyKey.Length > 100)
            return Invalid("Invalid rental stock transfer");
        await using var db = await Open(ct);
        if (await Guard(db, "60002", "EDIT", ct) is { } denied) return denied;
        var rental = await RentalDb.Rows(db, null, """
SELECT BranchID,ItemID,WarehouseID,RequireSerial FROM dbo.TDRNItem
WHERE CompanyID=@co AND RentalItemID=@id AND IsActive=1
""", ct, ("@co", Company), ("@id", input.RentalItemId));
        if (rental.Count == 0) return NotFound();
        var row = rental[0];
        if (await BranchGuard(db, Convert.ToInt64(row["BranchID"]), ct) is { } blocked) return blocked;
        var other = await RentalDb.Rows(db, null, """
SELECT BranchID FROM dbo.TDIVWarehouse
WHERE CompanyID=@co AND WarehouseID=@warehouse AND IsActive=1
AND WarehouseCode NOT LIKE N'RENTAL-%'
""", ct, ("@co", Company), ("@warehouse", input.OtherWarehouseId));
        if (other.Count == 0) return Invalid("Other warehouse must be an active central warehouse");
        if (await BranchGuard(db, Convert.ToInt64(other[0]["BranchID"]), ct) is { } otherBlocked)
            return otherBlocked;
        if (Convert.ToBoolean(row["RequireSerial"]) && input.InstanceIds.Count != input.Quantity)
            return Invalid("All serials are required for this rental item");
        var rentalWarehouse = Convert.ToInt64(row["WarehouseID"]);
        var source = input.Direction == "TO_RENTAL" ? input.OtherWarehouseId : rentalWarehouse;
        var target = input.Direction == "TO_RENTAL" ? rentalWarehouse : input.OtherWarehouseId;
        var item = Convert.ToInt64(row["ItemID"]);
        var key = input.IdempotencyKey.Trim();
        var canonical = JsonSerializer.Serialize(new
        {
            input.RentalItemId, input.OtherWarehouseId, input.Direction, input.Quantity,
            Serials = input.InstanceIds.Order().ToArray()
        });
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));
        await using var tx = (Microsoft.Data.SqlClient.SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var prior = await RentalDb.Rows(db, tx, """
SELECT TransferID id,RequestHash hash FROM dbo.TDRNStockTransfer WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND IdempotencyKey=@key
""", ct, ("@co", Company), ("@key", key));
        if (prior.Count != 0)
        {
            await tx.CommitAsync(ct);
            if (!string.Equals(Convert.ToString(prior[0]["hash"]), hash, StringComparison.Ordinal))
                return Conflict(new { message = "Idempotency key was used for another transfer" });
            return Ok(new { id = prior[0]["id"], duplicate = true });
        }
        if (input.Direction == "FROM_RENTAL" && await RentalDb.Number(db, tx, """
SELECT COUNT(*) FROM dbo.TDRNBookingLine L
JOIN dbo.TDRNBooking B ON B.CompanyID=L.CompanyID AND B.BookingID=L.BookingID
WHERE L.CompanyID=@co AND L.RentalItemID=@rental
AND ((B.StatusCode=N'RESERVED' AND B.ExpiresAt>SYSUTCDATETIME())
 OR B.StatusCode=N'PAID')
""", ct, ("@co", Company), ("@rental", input.RentalItemId)) > 0)
            return Conflict(new { message = "Active bookings reserve this rental item" });
        var reduced = await RentalDb.Execute(db, tx, """
UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK)
SET Quantity=Quantity-@qty,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@co AND WarehouseID=@source AND ItemID=@item AND Quantity>=@qty
""", ct, ("@co", Company), ("@source", source),
            ("@item", item), ("@qty", input.Quantity));
        if (reduced != 1) return Conflict(new { message = "Source warehouse stock is insufficient" });
        await RentalDb.Execute(db, tx, """
UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK)
SET Quantity=Quantity+@qty,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@co AND WarehouseID=@target AND ItemID=@item;
IF @@ROWCOUNT=0 INSERT dbo.TDIVStockBalance(CompanyID,WarehouseID,ItemID,Quantity)
VALUES(@co,@target,@item,@qty);
""", ct, ("@co", Company), ("@target", target),
            ("@item", item), ("@qty", input.Quantity));
        var transferId = await RentalDb.Number(db, tx, """
INSERT dbo.TDRNStockTransfer(CompanyID,RentalItemID,SourceWarehouseID,
TargetWarehouseID,DirectionCode,Quantity,IdempotencyKey,RequestHash,CreatedBy)
OUTPUT INSERTED.TransferID
VALUES(@co,@rental,@source,@target,@direction,@qty,@key,@hash,@actor)
""", ct, ("@co", Company), ("@rental", input.RentalItemId),
            ("@source", source), ("@target", target),
            ("@direction", input.Direction), ("@qty", input.Quantity),
            ("@key", key), ("@hash", hash), ("@actor", Actor));
        await RentalDb.Execute(db, tx, """
INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ToWarehouseID,ItemID,
DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy)
VALUES(@co,@source,@target,@item,N'RENTAL_TRANSFER',@id,@id,N'TRANSFER_OUT',-@qty,N'Rental stock transfer',@actor),
(@co,@target,@source,@item,N'RENTAL_TRANSFER',@id,@id,N'TRANSFER_IN',@qty,N'Rental stock transfer',@actor)
""", ct, ("@co", Company), ("@source", source), ("@target", target),
            ("@item", item), ("@id", transferId), ("@qty", input.Quantity), ("@actor", Actor));
        foreach (var instance in input.InstanceIds)
        {
            var moved = await RentalDb.Execute(db, tx, """
UPDATE dbo.TDIVItemInstance WITH(UPDLOCK,HOLDLOCK)
SET WarehouseID=@target,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@actor
WHERE CompanyID=@co AND ItemInstanceID=@instance AND ItemID=@item
AND WarehouseID=@source AND StatusCode=N'IN_STOCK'
""", ct, ("@co", Company), ("@instance", instance), ("@item", item),
                ("@source", source), ("@target", target), ("@actor", Actor));
            if (moved != 1) return Conflict(new { message = "Serial is unavailable in source warehouse", instance });
            await RentalDb.Execute(db, tx, """
INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,
WarehouseID,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy)
VALUES(@co,@instance,N'IN_STOCK',N'IN_STOCK',@target,N'RENTAL_TRANSFER',@id,0,N'Rental stock transfer',@actor)
""", ct, ("@co", Company), ("@instance", instance), ("@target", target),
                ("@id", transferId), ("@actor", Actor));
        }
        await RentalDb.Audit(db, tx, Company, Actor, "STOCK_TRANSFERRED", null,
            input.RentalItemId, $"TransferID={transferId};{input.Direction};Quantity={input.Quantity}", ct);
        await tx.CommitAsync(ct);
        return Ok(new { transferId, source, target, input.Quantity });
    }
}
