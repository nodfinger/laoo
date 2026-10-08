using Microsoft.AspNetCore.Mvc;

namespace Laoo.Market.Controllers;

public sealed partial class MarketController
{
    [HttpGet("traders")]
    public async Task<IActionResult> Traders(CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "59003", "VIEW", ct) is { } denied) return denied;
        return Ok(await MarketDb.Rows(db, null, """
SELECT T.TraderID id,T.TraderName name,T.Phone phone,
 CASE WHEN EXISTS(SELECT 1 FROM dbo.TDMKContract C WHERE C.CompanyID=T.CompanyID
 AND C.TraderID=T.TraderID AND C.StatusCode IN(N'ACTIVE',N'ENDED')) THEN CAST(1 AS bit)
 ELSE CAST(0 AS bit) END hasHistory
FROM dbo.TDMKTrader T WHERE T.CompanyID=@co AND T.IsActive=1
ORDER BY T.TraderName
""", ct, ("@co", Company)));
    }

    [HttpPost("traders")]
    public async Task<IActionResult> CreateTrader(TraderInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 200
            || string.IsNullOrWhiteSpace(input.Phone) || input.Phone.Length > 50)
            return Invalid("ระบุชื่อผู้ค้าและเบอร์โทรที่ติดต่อได้");
        await using var db = await Open(ct);
        if (await Guard(db, "59004", "CREATE", ct) is { } denied) return denied;
        if (input.CustomerID is > 0 && await MarketDb.Id(db, null,
            "SELECT COUNT(*) FROM dbo.TDARCustomer WHERE CompanyID=@co AND CustomerID=@customer",
            ct, ("@co", Company), ("@customer", input.CustomerID)) == 0)
            return Invalid("ไม่พบลูกค้าในบริษัทนี้");
        var id = await MarketDb.Id(db, null, """
INSERT dbo.TDMKTrader(CompanyID,CustomerID,TraderName,Phone)
OUTPUT INSERTED.TraderID VALUES(@co,@customer,@name,@phone)
""", ct, ("@co", Company), ("@customer", input.CustomerID),
            ("@name", input.Name.Trim()), ("@phone", input.Phone.Trim()));
        return Ok(new { id });
    }

    [HttpPost("inquiries")]
    public async Task<IActionResult> CreateInquiry(InquiryInput input, CancellationToken ct)
    {
        if (input.MarketID <= 0 || string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 200
            || string.IsNullOrWhiteSpace(input.Phone) || input.Phone.Length > 50
            || input.Requirement?.Length > 2000)
            return Invalid("ระบุตลาด ชื่อ เบอร์โทร และรายละเอียดความต้องการให้ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "59004", "CREATE", ct) is { } denied) return denied;
        var allowed = await MarketDb.Id(db, null, """
SELECT COUNT(*) FROM dbo.TDMKMarket M WHERE M.CompanyID=@co AND M.MarketID=@market AND M.IsActive=1
AND (M.BranchID IS NULL OR EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co
 AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=M.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@market", input.MarketID), ("@actor", Actor));
        if (allowed == 0) return NotFound(new { message = "ไม่พบตลาด",
            description = "เลือกตลาดภายในสาขาที่มีสิทธิ์" });
        var id = await MarketDb.Id(db, null, """
INSERT dbo.TDMKInquiry(CompanyID,MarketID,ContactName,Phone,Requirement)
OUTPUT INSERTED.InquiryID VALUES(@co,@market,@name,@phone,@requirement)
""", ct, ("@co", Company), ("@market", input.MarketID),
            ("@name", input.Name.Trim()), ("@phone", input.Phone.Trim()),
            ("@requirement", input.Requirement?.Trim()));
        return Ok(new { id });
    }

    [HttpGet("markets/{marketId:long}/bookings")]
    public async Task<IActionResult> Bookings(long marketId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "59003", "VIEW", ct) is { } denied) return denied;
        return Ok(await MarketDb.Rows(db, null, """
SELECT TOP(100) B.BookingID id,S.StallCode stall,T.TraderName trader,
 B.StartsOn startsOn,B.EndsOn endsOn,B.ExpiresAt expiresAt,
 CASE WHEN B.StatusCode=N'RESERVED' AND B.ExpiresAt<=SYSUTCDATETIME()
 THEN N'EXPIRED' ELSE B.StatusCode END status
FROM dbo.TDMKBooking B
JOIN dbo.TDMKStall S ON S.CompanyID=B.CompanyID AND S.StallID=B.StallID
JOIN dbo.TDMKMarket M ON M.CompanyID=S.CompanyID AND M.MarketID=S.MarketID
JOIN dbo.TDMKTrader T ON T.CompanyID=B.CompanyID AND T.TraderID=B.TraderID
WHERE B.CompanyID=@co AND S.MarketID=@market
AND (M.BranchID IS NULL OR EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co
 AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=M.BranchID AND UB.IsActive=1))
ORDER BY B.BookingID DESC
""", ct, ("@co", Company), ("@market", marketId), ("@actor", Actor)));
    }
}

public sealed record TraderInput(string Name, string Phone, long? CustomerID);
public sealed record InquiryInput(long MarketID, string Name, string Phone, string? Requirement);
