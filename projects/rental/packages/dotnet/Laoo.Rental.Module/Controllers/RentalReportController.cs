using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    [HttpGet("history")]
    public async Task<IActionResult> History(string menu = "60009", long? branchId = null, string? status = null,
        int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        if (menu is not ("60004" or "60005" or "60006" or "60007" or "60008" or "60009")
            || page < 1 || pageSize is < 1 or > 100 || page > int.MaxValue / pageSize
            || (status is not null && status.Length > 30))
            return Invalid("Invalid page or status");
        await using var db = await Open(ct);
        if (await Guard(db, menu, "VIEW", ct) is { } denied) return denied;
        if (branchId is > 0 && await BranchGuard(db, branchId.Value, ct) is { } blocked) return blocked;
        const string where = """
FROM dbo.TDRNBooking B
JOIN dbo.TDADBranch BR ON BR.CompanyID=B.CompanyID AND BR.BranchID=B.BranchID
JOIN dbo.TDARCustomer C ON C.CompanyID=B.CompanyID AND C.CustomerID=B.CustomerID
WHERE B.CompanyID=@co AND (@branch IS NULL OR B.BranchID=@branch)
AND (@status IS NULL OR B.StatusCode=@status)
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=B.BranchID AND UB.IsActive=1))
""";
        var count = await RentalDb.Number(db, null, "SELECT COUNT(*)\n" + where, ct,
            ("@co", Company), ("@branch", branchId), ("@status", status), ("@actor", Actor));
        var rows = await RentalDb.Rows(db, null, """
SELECT B.BookingID id,B.BookingCode code,B.BranchID branchId,BR.BranchNameTH branchName,
B.CustomerID customerId,C.CusName customerName,
B.StartAt startAt,B.EndAt endAt,B.StatusCode status,B.TotalRent rent,
B.TotalDeposit deposit,B.CreatedAt createdAt
""" + "\n" + where + "\n" + """
ORDER BY B.BookingID DESC OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY
""", ct, ("@co", Company), ("@branch", branchId), ("@status", status),
            ("@actor", Actor), ("@skip", (page - 1) * pageSize), ("@take", pageSize));
        return Ok(new { items = rows, total = count, page, pageSize });
    }

    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard(long? branchId, DateOnly? from,
        DateOnly? to, CancellationToken ct)
    {
        if (from > to || (from is not null && from.Value.Year < 2000)
            || (to is not null && to.Value.Year > 2100))
            return Invalid("Invalid report dates");
        await using var db = await Open(ct);
        if (await Guard(db, "60010", "VIEW", ct) is { } denied) return denied;
        if (branchId is > 0 && await BranchGuard(db, branchId.Value, ct) is { } blocked) return blocked;
        var dateFrom = from?.ToDateTime(TimeOnly.MinValue);
        var dateTo = to?.AddDays(1).ToDateTime(TimeOnly.MinValue);
        var summary = await RentalDb.Rows(db, null, """
SELECT B.StatusCode status,COUNT(*) bookings,
SUM(B.TotalRent) rent,SUM(B.TotalDeposit) deposits
FROM dbo.TDRNBooking B
WHERE B.CompanyID=@co AND (@branch IS NULL OR B.BranchID=@branch)
AND (@from IS NULL OR B.CreatedAt>=@from) AND (@to IS NULL OR B.CreatedAt<@to)
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=B.BranchID AND UB.IsActive=1))
GROUP BY B.StatusCode ORDER BY B.StatusCode
""", ct, ("@co", Company), ("@branch", branchId), ("@actor", Actor),
            ("@from", dateFrom), ("@to", dateTo));
        var popular = await RentalDb.Rows(db, null, """
SELECT TOP(10) L.ItemID itemId,I.ItemCode code,I.ItemName name,
SUM(L.Quantity) bookedUnits,COUNT(*) bookingLines
FROM dbo.TDRNBookingLine L
JOIN dbo.TDRNBooking B ON B.CompanyID=L.CompanyID AND B.BookingID=L.BookingID
JOIN dbo.TDIVItem I ON I.CompanyID=L.CompanyID AND I.ItemID=L.ItemID
WHERE B.CompanyID=@co AND B.StatusCode<>N'CANCELLED'
AND (@branch IS NULL OR B.BranchID=@branch)
AND (@from IS NULL OR B.CreatedAt>=@from) AND (@to IS NULL OR B.CreatedAt<@to)
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=B.BranchID AND UB.IsActive=1))
GROUP BY L.ItemID,I.ItemCode,I.ItemName ORDER BY bookedUnits DESC,L.ItemID
""", ct, ("@co", Company), ("@branch", branchId), ("@actor", Actor),
            ("@from", dateFrom), ("@to", dateTo));
        return Ok(new { summary, popular });
    }
}
