using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    public sealed record SettingInput(int BookingHoldHours, int CancelBeforeHours);
    public sealed record RentalItemInput(long BranchId, long ItemId, long WarehouseId,
        string RateUnit, decimal RentalRate, decimal DepositAmount, bool RequireSerial);
    public sealed record RentalItemUpdate(string RateUnit, decimal RentalRate,
        decimal DepositAmount, bool IsActive);

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "60001", "VIEW", ct) is { } denied) return denied;
        var rows = await RentalDb.Rows(db, null, """
SELECT CompanyID companyId,BookingHoldHours bookingHoldHours,
CancelBeforeHours cancelBeforeHours FROM dbo.TDRNSetting WHERE CompanyID=@co
""", ct, ("@co", Company));
        return Ok(rows.SingleOrDefault() ?? new Dictionary<string, object?>
        {
            ["bookingHoldHours"] = 24, ["cancelBeforeHours"] = 2
        });
    }

    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings([FromBody] SettingInput input, CancellationToken ct)
    {
        if (input.BookingHoldHours is < 1 or > 168 || input.CancelBeforeHours is < 0 or > 168)
            return Invalid("Invalid booking or cancellation hours");
        await using var db = await Open(ct);
        if (await Guard(db, "60001", "EDIT", ct) is { } denied) return denied;
        await RentalDb.Execute(db, null, """
UPDATE dbo.TDRNSetting SET BookingHoldHours=@hold,CancelBeforeHours=@cancel,
UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@actor WHERE CompanyID=@co;
IF @@ROWCOUNT=0 INSERT dbo.TDRNSetting
(CompanyID,BookingHoldHours,CancelBeforeHours,UpdatedBy)
VALUES(@co,@hold,@cancel,@actor);
""", ct, ("@co", Company), ("@hold", input.BookingHoldHours),
            ("@cancel", input.CancelBeforeHours), ("@actor", Actor));
        return Ok(new { saved = true });
    }

    [HttpGet("items")]
    public async Task<IActionResult> Items([FromQuery] long? branchId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "60002", "VIEW", ct) is { } denied) return denied;
        if (branchId is > 0 && await BranchGuard(db, branchId.Value, ct) is { } blocked) return blocked;
        return Ok(await RentalDb.Rows(db, null, """
SELECT R.RentalItemID id,R.BranchID branchId,R.ItemID itemId,I.ItemCode code,I.ItemName name,
R.WarehouseID warehouseId,R.RateUnit rateUnit,R.RentalRate rentalRate,
R.DepositAmount depositAmount,R.RequireSerial requireSerial,R.IsActive isActive,
COALESCE(B.Quantity,0) rentalStock
FROM dbo.TDRNItem R
JOIN dbo.TDIVItem I ON I.CompanyID=R.CompanyID AND I.ItemID=R.ItemID
LEFT JOIN dbo.TDIVStockBalance B ON B.CompanyID=R.CompanyID
 AND B.WarehouseID=R.WarehouseID AND B.ItemID=R.ItemID
WHERE R.CompanyID=@co AND (@branch IS NULL OR R.BranchID=@branch)
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=R.BranchID AND UB.IsActive=1))
ORDER BY R.BranchID,I.ItemCode
""", ct, ("@co", Company), ("@branch", branchId), ("@actor", Actor)));
    }

    [HttpPost("items")]
    public async Task<IActionResult> AddItem([FromBody] RentalItemInput input, CancellationToken ct)
    {
        if (input.BranchId <= 0 || input.ItemId <= 0 || input.WarehouseId <= 0
            || input.RentalRate is < 0 or > 1_000_000_000
            || input.DepositAmount is < 0 or > 1_000_000_000
            || input.RateUnit is not ("HOUR" or "DAY"))
            return Invalid("Invalid rental item or price");
        await using var db = await Open(ct);
        if (await Guard(db, "60002", "CREATE", ct) is { } denied) return denied;
        if (await BranchGuard(db, input.BranchId, ct) is { } blocked) return blocked;
        var valid = await RentalDb.Number(db, null, """
SELECT COUNT(*) FROM dbo.TDIVWarehouse W
JOIN dbo.TDIVItem I ON I.CompanyID=W.CompanyID AND I.ItemID=@item
        WHERE W.CompanyID=@co AND W.WarehouseID=@warehouse AND W.BranchID=@branch
AND W.IsActive=1 AND W.IsDefault=0 AND W.WarehouseCode LIKE N'RENTAL-%'
AND I.IsActive=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDPOOutlet O WHERE O.CompanyID=@co AND O.WarehouseID=W.WarehouseID)
""", ct, ("@co", Company), ("@item", input.ItemId),
            ("@warehouse", input.WarehouseId), ("@branch", input.BranchId));
        if (valid == 0) return Invalid("Use an active rental-only warehouse and a company item");
        var id = await RentalDb.Number(db, null, """
INSERT dbo.TDRNItem(CompanyID,BranchID,ItemID,WarehouseID,RateUnit,
RentalRate,DepositAmount,RequireSerial,CreatedBy)
OUTPUT INSERTED.RentalItemID
VALUES(@co,@branch,@item,@warehouse,@unit,@rate,@deposit,@serial,@actor)
""", ct, ("@co", Company), ("@branch", input.BranchId), ("@item", input.ItemId),
            ("@warehouse", input.WarehouseId), ("@unit", input.RateUnit),
            ("@rate", input.RentalRate), ("@deposit", input.DepositAmount),
            ("@serial", input.RequireSerial), ("@actor", Actor));
        return Created($"/api/company/rental/items/{id}", new { id });
    }

    [HttpGet("items/{id:long}")]
    public async Task<IActionResult> Item(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "60002", "VIEW", ct) is { } denied) return denied;
        var rows = await RentalDb.Rows(db, null,
            "SELECT * FROM dbo.TDRNItem WHERE CompanyID=@co AND RentalItemID=@id",
            ct, ("@co", Company), ("@id", id));
        if (rows.Count == 0) return NotFound();
        if (await BranchGuard(db, Convert.ToInt64(rows[0]["BranchID"]), ct) is { } blocked) return blocked;
        return Ok(rows[0]);
    }

    [HttpPut("items/{id:long}")]
    public async Task<IActionResult> EditItem(long id, [FromBody] RentalItemUpdate input, CancellationToken ct)
    {
        if (input.RateUnit is not ("HOUR" or "DAY")
            || input.RentalRate is < 0 or > 1_000_000_000
            || input.DepositAmount is < 0 or > 1_000_000_000)
            return Invalid("Invalid rental price");
        await using var db = await Open(ct);
        if (await Guard(db, "60002", "EDIT", ct) is { } denied) return denied;
        var rows = await RentalDb.Rows(db, null,
            "SELECT BranchID FROM dbo.TDRNItem WHERE CompanyID=@co AND RentalItemID=@id",
            ct, ("@co", Company), ("@id", id));
        if (rows.Count == 0) return NotFound();
        if (await BranchGuard(db, Convert.ToInt64(rows[0]["BranchID"]), ct) is { } blocked) return blocked;
        if (!input.IsActive && await RentalDb.Number(db, null, """
SELECT COUNT(*) FROM dbo.TDRNBookingLine L JOIN dbo.TDRNBooking B
 ON B.CompanyID=L.CompanyID AND B.BookingID=L.BookingID
WHERE L.CompanyID=@co AND L.RentalItemID=@id AND B.StatusCode IN(N'RESERVED',N'PAID',N'OUT',N'PARTIAL_RETURN')
""", ct, ("@co", Company), ("@id", id)) > 0)
            return Conflict(new { message = "Active rentals use this item" });
        await RentalDb.Execute(db, null, """
UPDATE dbo.TDRNItem SET RateUnit=@unit,RentalRate=@rate,DepositAmount=@deposit,
IsActive=@active,UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@actor
WHERE CompanyID=@co AND RentalItemID=@id
""", ct, ("@co", Company), ("@id", id), ("@unit", input.RateUnit),
            ("@rate", input.RentalRate), ("@deposit", input.DepositAmount),
            ("@active", input.IsActive), ("@actor", Actor));
        return Ok(new { saved = true });
    }

    [HttpDelete("items/{id:long}")]
    public async Task<IActionResult> DeleteItem(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "60002", "DELETE", ct) is { } denied) return denied;
        var rows = await RentalDb.Rows(db, null,
            "SELECT BranchID FROM dbo.TDRNItem WHERE CompanyID=@co AND RentalItemID=@id",
            ct, ("@co", Company), ("@id", id));
        if (rows.Count == 0) return NotFound();
        if (await BranchGuard(db, Convert.ToInt64(rows[0]["BranchID"]), ct) is { } blocked) return blocked;
        if (await RentalDb.Number(db, null,
            "SELECT COUNT(*) FROM dbo.TDRNBookingLine WHERE CompanyID=@co AND RentalItemID=@id",
            ct, ("@co", Company), ("@id", id)) > 0)
            return Conflict(new { message = "Rental history uses this item; deactivate it instead" });
        await RentalDb.Execute(db, null,
            "DELETE dbo.TDRNItem WHERE CompanyID=@co AND RentalItemID=@id",
            ct, ("@co", Company), ("@id", id));
        return NoContent();
    }
}
