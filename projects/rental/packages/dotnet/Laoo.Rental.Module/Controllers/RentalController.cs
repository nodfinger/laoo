using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Laoo.Rental.Controllers;

[ApiController, Authorize, Route("api/company/rental")]
public sealed partial class RentalController(IConfiguration configuration) : ControllerBase
{
    private long Company => long.Parse(User.FindFirst("company_id")!.Value);
    private long Actor => long.Parse(User.FindFirst("user_id")!.Value);

    private async Task<SqlConnection> Open(CancellationToken ct)
    {
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        return db;
    }

    private async Task<IActionResult?> Guard(SqlConnection db, string menu, string action, CancellationToken ct)
    {
        if (!RentalAccess.Scope(User, out _, out _)) return Forbid();
        if (!await RentalAccess.Can(db, User, menu, action, ct))
            return StatusCode(403, new { message = "No rental permission", menu, action });
        return null;
    }

    private async Task<IActionResult?> BranchGuard(SqlConnection db, long branch, CancellationToken ct) =>
        await RentalAccess.Branch(db, Company, Actor, branch, ct) ? null : Forbid();

    private static IActionResult Invalid(string message) =>
        new BadRequestObjectResult(new { message });

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken ct)
    {
        if (!RentalAccess.KnownMenu(menu)) return NotFound();
        await using var db = await Open(ct);
        if (await Guard(db, menu, "VIEW", ct) is { } denied) return denied;
        var rows = await RentalDb.Rows(db, null, """
SELECT P.ActionCode FROM dbo.TDADPermission P
JOIN dbo.TDADProject J ON J.ProjectID=P.ProjectID AND J.ProjectCode=N'LAOO_RENTAL'
WHERE P.ScreenCode=@menu AND P.IsActive=1
""", ct, ("@menu", menu));
        var actions = new Dictionary<string, bool>();
        foreach (var row in rows)
        {
            var action = Convert.ToString(row["ActionCode"])!;
            actions[action.ToLowerInvariant()] = await RentalAccess.Can(db, User, menu, action, ct);
        }
        var metadata = await RentalDb.Rows(db, null,
            "SELECT MenuName,ScreenType,IconName FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1",
            ct, ("@menu", menu));
        return Ok(new { actions, metadata = metadata.Single() });
    }

    private async Task<(long Branch, string Status)?> BookingScope(SqlConnection db,
        SqlTransaction? tx, long booking, CancellationToken ct)
    {
        var rows = await RentalDb.Rows(db, tx,
            "SELECT BranchID,StatusCode FROM dbo.TDRNBooking WHERE CompanyID=@co AND BookingID=@id",
            ct, ("@co", Company), ("@id", booking));
        if (rows.Count == 0) return null;
        return (Convert.ToInt64(rows[0]["BranchID"]), Convert.ToString(rows[0]["StatusCode"])!);
    }
}
