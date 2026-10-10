using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    public sealed record ReserveLine(long RentalItemId, int Quantity);
    public sealed record ReserveInput(long BranchId, long CustomerId, DateTimeOffset StartAt,
        DateTimeOffset EndAt, string IdempotencyKey, List<ReserveLine> Lines);

    [HttpGet("availability")]
    public async Task<IActionResult> Availability(long branchId, DateTimeOffset startAt,
        DateTimeOffset endAt, CancellationToken ct)
    {
        if (branchId <= 0 || endAt <= startAt || startAt < DateTimeOffset.UtcNow
            || endAt - startAt > TimeSpan.FromDays(365))
            return Invalid("Invalid rental period");
        await using var db = await Open(ct);
        if (await Guard(db, "60003", "VIEW", ct) is { } denied) return denied;
        if (await BranchGuard(db, branchId, ct) is { } blocked) return blocked;
        return Ok(await RentalDb.Rows(db, null, """
SELECT R.RentalItemID id,I.ItemCode code,I.ItemName name,
R.RateUnit rateUnit,R.RentalRate rate,R.DepositAmount deposit,
COALESCE(B.Quantity,0) stock,
COALESCE(X.Reserved,0) reserved,
COALESCE(B.Quantity,0)-COALESCE(X.Reserved,0) available
FROM dbo.TDRNItem R
JOIN dbo.TDIVItem I ON I.CompanyID=R.CompanyID AND I.ItemID=R.ItemID
LEFT JOIN dbo.TDIVStockBalance B ON B.CompanyID=R.CompanyID
 AND B.WarehouseID=R.WarehouseID AND B.ItemID=R.ItemID
OUTER APPLY(SELECT SUM(L.Quantity) Reserved FROM dbo.TDRNBookingLine L
 JOIN dbo.TDRNBooking H ON H.CompanyID=L.CompanyID AND H.BookingID=L.BookingID
 WHERE L.CompanyID=R.CompanyID AND L.RentalItemID=R.RentalItemID
 AND H.StatusCode IN(N'RESERVED',N'PAID') AND H.ExpiresAt>SYSUTCDATETIME()
 AND H.StartAt<@endAt AND H.EndAt>@startAt) X
WHERE R.CompanyID=@co AND R.BranchID=@branch AND R.IsActive=1
ORDER BY I.ItemCode
""", ct, ("@co", Company), ("@branch", branchId),
            ("@startAt", startAt.UtcDateTime), ("@endAt", endAt.UtcDateTime)));
    }

    [HttpPost("bookings")]
    public async Task<IActionResult> Reserve([FromBody] ReserveInput input, CancellationToken ct)
    {
        if (input.BranchId <= 0 || input.CustomerId <= 0 || input.EndAt <= input.StartAt
            || input.StartAt < DateTimeOffset.UtcNow || input.EndAt - input.StartAt > TimeSpan.FromDays(365)
            || string.IsNullOrWhiteSpace(input.IdempotencyKey) || input.IdempotencyKey.Length > 100
            || input.Lines is null || input.Lines.Count is < 1 or > 100
            || input.Lines.Any(x => x.RentalItemId <= 0 || x.Quantity is <= 0 or > 10000)
            || input.Lines.Select(x => x.RentalItemId).Distinct().Count() != input.Lines.Count)
            return Invalid("Invalid reservation");
        await using var db = await Open(ct);
        if (await Guard(db, "60004", "CREATE", ct) is { } denied) return denied;
        if (await BranchGuard(db, input.BranchId, ct) is { } blocked) return blocked;
        var customer = await RentalDb.Number(db, null,
            "SELECT COUNT(*) FROM dbo.TDARCustomer WHERE CompanyID=@co AND CustomerID=@customer AND IsActive=1",
            ct, ("@co", Company), ("@customer", input.CustomerId));
        if (customer == 0) return Invalid("Customer does not belong to this company");
        var start = input.StartAt.UtcDateTime;
        var end = input.EndAt.UtcDateTime;
        var key = input.IdempotencyKey.Trim();
        var canonical = JsonSerializer.Serialize(new
        {
            input.BranchId, input.CustomerId, Start = start, End = end,
            Lines = input.Lines.OrderBy(x => x.RentalItemId).ToArray()
        });
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));
        await using var tx = (Microsoft.Data.SqlClient.SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var prior = await RentalDb.Rows(db, tx, """
SELECT BookingID id,RequestHash hash FROM dbo.TDRNBooking WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND IdempotencyKey=@key
""", ct, ("@co", Company), ("@key", key));
        if (prior.Count != 0)
        {
            await tx.CommitAsync(ct);
            if (!string.Equals(Convert.ToString(prior[0]["hash"]), hash, StringComparison.Ordinal))
                return Conflict(new { message = "Idempotency key was used for another reservation" });
            return Ok(new { id = prior[0]["id"], duplicate = true });
        }
        var holdHours = await RentalDb.Number(db, tx,
            "SELECT COALESCE((SELECT BookingHoldHours FROM dbo.TDRNSetting WHERE CompanyID=@co),24)",
            ct, ("@co", Company));
        var priceLines = new List<(ReserveLine Line, long ItemId, decimal Rent, decimal Deposit,
            string Unit, decimal Rate, long Warehouse, bool RequireSerial)>();
        foreach (var line in input.Lines.OrderBy(x => x.RentalItemId))
        {
            var rows = await RentalDb.Rows(db, tx, """
SELECT R.ItemID,R.WarehouseID,R.RateUnit,R.RentalRate,R.DepositAmount,R.RequireSerial,
COALESCE(B.Quantity,0) Stock,
COALESCE(X.Reserved,0) Reserved
FROM dbo.TDRNItem R WITH(UPDLOCK,HOLDLOCK)
LEFT JOIN dbo.TDIVStockBalance B WITH(UPDLOCK,HOLDLOCK)
 ON B.CompanyID=R.CompanyID AND B.WarehouseID=R.WarehouseID AND B.ItemID=R.ItemID
OUTER APPLY(SELECT SUM(L.Quantity) Reserved FROM dbo.TDRNBookingLine L
 JOIN dbo.TDRNBooking H ON H.CompanyID=L.CompanyID AND H.BookingID=L.BookingID
 WHERE L.CompanyID=R.CompanyID AND L.RentalItemID=R.RentalItemID
 AND H.StatusCode IN(N'RESERVED',N'PAID') AND H.ExpiresAt>SYSUTCDATETIME()
 AND H.StartAt<@endAt AND H.EndAt>@startAt) X
WHERE R.CompanyID=@co AND R.BranchID=@branch AND R.RentalItemID=@item AND R.IsActive=1
AND EXISTS(SELECT 1 FROM dbo.TDIVWarehouse W WHERE W.CompanyID=R.CompanyID
 AND W.WarehouseID=R.WarehouseID AND W.IsActive=1 AND W.IsDefault=0
 AND W.WarehouseCode LIKE N'RENTAL-%')
AND NOT EXISTS(SELECT 1 FROM dbo.TDPOOutlet O WHERE O.CompanyID=R.CompanyID
 AND O.WarehouseID=R.WarehouseID)
""", ct, ("@co", Company), ("@branch", input.BranchId),
                ("@item", line.RentalItemId), ("@startAt", start), ("@endAt", end));
            if (rows.Count == 0 || Convert.ToDecimal(rows[0]["Stock"]) -
                Convert.ToDecimal(rows[0]["Reserved"]) < line.Quantity)
                return Conflict(new { message = "Rental stock is unavailable", line.RentalItemId });
            var row = rows[0];
            var unit = Convert.ToString(row["RateUnit"])!;
            var rate = Convert.ToDecimal(row["RentalRate"]);
            var units = unit == "HOUR"
                ? (decimal)Math.Ceiling((end - start).TotalHours)
                : (decimal)Math.Ceiling((end - start).TotalDays);
            priceLines.Add((line, Convert.ToInt64(row["ItemID"]),
                units * rate * line.Quantity,
                Convert.ToDecimal(row["DepositAmount"]) * line.Quantity,
                unit, rate, Convert.ToInt64(row["WarehouseID"]),
                Convert.ToBoolean(row["RequireSerial"])));
        }
        var totalRent = priceLines.Sum(x => x.Rent);
        var totalDeposit = priceLines.Sum(x => x.Deposit);
        var id = await RentalDb.Number(db, tx, """
INSERT dbo.TDRNBooking(CompanyID,BranchID,CustomerID,StartAt,EndAt,ExpiresAt,
StatusCode,TotalRent,TotalDeposit,IdempotencyKey,RequestHash,CreatedBy)
OUTPUT INSERTED.BookingID
VALUES(@co,@branch,@customer,@startAt,@endAt,DATEADD(hour,@hold,SYSUTCDATETIME()),
N'RESERVED',@rent,@deposit,@key,@hash,@actor)
""", ct, ("@co", Company), ("@branch", input.BranchId),
            ("@customer", input.CustomerId), ("@startAt", start), ("@endAt", end),
            ("@hold", holdHours), ("@rent", totalRent), ("@deposit", totalDeposit),
            ("@key", key), ("@hash", hash), ("@actor", Actor));
        var code = $"RN-{DateTime.UtcNow.ToString("yyyyMMdd", System.Globalization.CultureInfo.InvariantCulture)}-{id:D8}";
        await RentalDb.Execute(db, tx,
            "UPDATE dbo.TDRNBooking SET BookingCode=@code WHERE CompanyID=@co AND BookingID=@id",
            ct, ("@co", Company), ("@id", id), ("@code", code));
        foreach (var p in priceLines)
            await RentalDb.Execute(db, tx, """
INSERT dbo.TDRNBookingLine(CompanyID,BookingID,RentalItemID,ItemID,WarehouseID,
Quantity,RateUnitSnapshot,RateSnapshot,RequireSerialSnapshot,RentAmount,DepositAmount)
VALUES(@co,@booking,@rentalItem,@item,@warehouse,@qty,@unit,@rate,@serial,@rent,@deposit)
""", ct, ("@co", Company), ("@booking", id),
                ("@rentalItem", p.Line.RentalItemId), ("@item", p.ItemId),
                ("@warehouse", p.Warehouse), ("@qty", p.Line.Quantity),
                ("@unit", p.Unit), ("@rate", p.Rate), ("@serial", p.RequireSerial), ("@rent", p.Rent),
                ("@deposit", p.Deposit));
        await RentalDb.Audit(db, tx, Company, Actor, "BOOKED", id, null,
            code, ct);
        await tx.CommitAsync(ct);
        return Created($"/api/company/rental/bookings/{id}",
            new { id, code, totalRent, totalDeposit, status = "RESERVED" });
    }
}
