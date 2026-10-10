using System.Security.Claims;
using Microsoft.Data.SqlClient;
using Laoo.Shared.Contracts;
namespace Laoo.Booking;
public static class BookingAccess
{
    static readonly Dictionary<string, int> Screens = new()
    { ["61001"] = 2, ["61002"] = 1, ["61003"] = 1, ["61004"] = 1, ["61005"] = 1, ["61006"] = 1, ["61007"] = 4, ["61008"] = 4, ["61009"] = 3, ["61010"] = 3 };
    public static bool Scope(ClaimsPrincipal u, out long co, out long actor) { co = actor = 0; return u.FindFirstValue("user_type") == "COMPANY_USER" && long.TryParse(u.FindFirstValue("company_id"), out co) && co > 0 && long.TryParse(u.FindFirstValue("user_id"), out actor) && actor > 0; }
    public static async Task<bool> Can(SqlConnection db, ClaimsPrincipal u, string m, string a, CancellationToken ct)
    {
        if (!Scope(u, out _, out _) || !Screens.TryGetValue(m, out var s)) return false;
        if (await BookingDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.IsActive=1 JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.ProjectCode=N'LAOO_BOOKING' AND P.IsActive=1 WHERE M.MenuCode=@m AND M.IsActive=1 AND M.ScreenType=@s", ct, ("@m", m), ("@s", s)) == 0) return false;
        // The central entitlement rule permits read-only actions after expiry,
        // while still rejecting writes, suspension, and unrelated companies.
        return await CompanyMenuAccess.IsAllowedAsync(db, u, m, a, ct);
    }
}
