using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Laoo.Market.Controllers;

[ApiController, Authorize, Route("api/company/market")]
public sealed partial class MarketController(IConfiguration configuration) : ControllerBase
{
    private async Task<SqlConnection> Open(CancellationToken ct)
    {
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        return db;
    }

    private async Task<IActionResult?> Guard(SqlConnection db, string menu, string action, CancellationToken ct)
    {
        if (!MarketAccess.Scope(User, out _, out _)) return Forbid();
        if (!await MarketAccess.Can(db, User, menu, action, ct))
            return StatusCode(403, new { message = "ไม่มีสิทธิ์ทำรายการตลาดนัด",
                description = "ตรวจสอบแพ็กเกจระบบตลาดนัดและสิทธิ์เมนูกับผู้ดูแล" });
        return null;
    }

    private long Company => long.Parse(User.FindFirst("company_id")!.Value);
    private long Actor => long.Parse(User.FindFirst("user_id")!.Value);
    private static IActionResult Invalid(string description) =>
        new BadRequestObjectResult(new { message = "ข้อมูลไม่ถูกต้อง", description });

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken ct)
    {
        if (menu is not ("59001" or "59002" or "59003" or "59004")) return NotFound();
        await using var db = await Open(ct);
        if (await Guard(db, menu, "VIEW", ct) is { } denied) return denied;
        var permissions = await MarketDb.Rows(db, null, """
SELECT P.ActionCode FROM dbo.TDADPermission P
JOIN dbo.TDADProject J ON J.ProjectID=P.ProjectID
WHERE J.ProjectCode=N'LAOO_MARKET' AND P.ScreenCode=@menu AND P.IsActive=1
""", ct, ("@menu", menu));
        var actions = new Dictionary<string, bool>();
        foreach (var permission in permissions)
        {
            var action = Convert.ToString(permission["ActionCode"])!;
            actions[action.ToLowerInvariant()] = await MarketAccess.Can(db, User, menu, action, ct);
        }
        var meta = await MarketDb.Rows(db, null,
            "SELECT MenuName,ScreenType,IconName FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1",
            ct, ("@menu", menu));
        return Ok(new { actions, metadata = meta.Single() });
    }

    [HttpGet("markets")]
    public async Task<IActionResult> Markets(CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "59003", "VIEW", ct) is { } denied) return denied;
        return Ok(await MarketDb.Rows(db, null, """
SELECT M.MarketID id,M.MarketCode code,M.MarketName name,M.BranchID branchId
FROM dbo.TDMKMarket M WHERE M.CompanyID=@co AND M.IsActive=1
AND (M.BranchID IS NULL OR EXISTS(SELECT 1 FROM dbo.TDADUser U
 WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch B WHERE B.CompanyID=@co
 AND B.UserID=@actor AND B.BranchID=M.BranchID AND B.IsActive=1))
ORDER BY M.MarketName
""", ct, ("@co", Company), ("@actor", Actor)));
    }

    [HttpGet("markets/{marketId:long}/map")]
    public async Task<IActionResult> Map(long marketId, DateOnly on, CancellationToken ct)
    {
        if (on.Year is < 2000 or > 2100) return Invalid("เลือกวันที่ที่ต้องการดูผังล็อก");
        await using var db = await Open(ct);
        if (await Guard(db, "59003", "VIEW", ct) is { } denied) return denied;
        var rows = await MarketDb.Rows(db, null, """
SELECT S.StallID id,S.StallCode code,S.PosX x,S.PosY y,S.WidthUnits width,S.HeightUnits height,
 Z.ZoneID zoneId,Z.ZoneName zone,
 CASE WHEN P.StatusCode=N'CLOSED' THEN N'CLOSED'
      WHEN P.StatusCode=N'RENOVATION' THEN N'RENOVATION'
      WHEN C.ContractID IS NOT NULL THEN N'OCCUPIED'
      WHEN B.BookingID IS NOT NULL THEN N'RESERVED' ELSE N'VACANT' END status,
 B.BookingID bookingId,B.ExpiresAt bookingExpiresAt,T.TraderName trader
FROM dbo.TDMKStall S
JOIN dbo.TDMKZone Z ON Z.CompanyID=S.CompanyID AND Z.ZoneID=S.ZoneID AND Z.IsActive=1
JOIN dbo.TDMKMarket M ON M.CompanyID=S.CompanyID AND M.MarketID=S.MarketID AND M.IsActive=1
OUTER APPLY(SELECT TOP(1) StatusCode FROM dbo.TDMKStallStatusPeriod X
 WHERE X.CompanyID=S.CompanyID AND X.StallID=S.StallID AND X.IsActive=1
 AND X.StartsOn<=@on AND (X.EndsOn IS NULL OR X.EndsOn>=@on)
 ORDER BY CASE WHEN X.StatusCode=N'CLOSED' THEN 0 ELSE 1 END,X.PeriodID DESC) P
OUTER APPLY(SELECT TOP(1) ContractID,TraderID FROM dbo.TDMKContract X
 WHERE X.CompanyID=S.CompanyID AND X.StallID=S.StallID AND X.StatusCode=N'ACTIVE'
 AND X.StartsOn<=@on AND X.EndsOn>=@on ORDER BY X.ContractID DESC) C
OUTER APPLY(SELECT TOP(1) BookingID,TraderID,ExpiresAt FROM dbo.TDMKBooking X
 WHERE X.CompanyID=S.CompanyID AND X.StallID=S.StallID AND X.StatusCode=N'RESERVED'
 AND X.ExpiresAt>SYSUTCDATETIME() AND X.StartsOn<=@on AND X.EndsOn>=@on
 ORDER BY X.BookingID DESC) B
LEFT JOIN dbo.TDMKTrader T ON T.CompanyID=S.CompanyID AND T.TraderID=COALESCE(C.TraderID,B.TraderID)
WHERE S.CompanyID=@co AND S.MarketID=@market AND S.IsActive=1
AND (M.BranchID IS NULL OR EXISTS(SELECT 1 FROM dbo.TDADUser U
 WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=M.BranchID AND UB.IsActive=1))
ORDER BY Z.ZoneName,S.StallCode
""", ct, ("@co", Company), ("@market", marketId), ("@actor", Actor), ("@on", on.ToDateTime(TimeOnly.MinValue)));
        return Ok(rows);
    }
}
