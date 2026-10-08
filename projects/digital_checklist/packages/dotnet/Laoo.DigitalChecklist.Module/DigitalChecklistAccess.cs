using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;
namespace Laoo.DigitalChecklist;
internal static class DigitalChecklistAccess
{
    internal static bool Scope(ClaimsPrincipal u, out long company, out long actor) { company = actor = 0; return u.FindFirstValue("user_type") == "COMPANY_USER" && long.TryParse(u.FindFirstValue("company_id"), out company) && company > 0 && long.TryParse(u.FindFirstValue("user_id"), out actor) && actor > 0; }
    internal static readonly IReadOnlyDictionary<string, (int Screen, string Actions)> Menus = new Dictionary<string, (int, string)>
    {
        ["58001"] = (2, "VIEW EDIT"),
        ["58002"] = (1, "VIEW CREATE EDIT DELETE MANAGE_DEPARTMENT"),
        ["58003"] = (1, "VIEW CREATE EDIT DELETE"),
        ["58004"] = (1, "VIEW CREATE EDIT DELETE"),
        ["58005"] = (1, "VIEW CREATE EDIT DELETE"),
        ["58006"] = (4, "VIEW CREATE SUBMIT"),
        ["58007"] = (3, "VIEW APPROVE RETURN"),
        ["58008"] = (3, "VIEW EDIT HANDOFF"),
        ["58009"] = (3, "VIEW AUDIT EXPORT"),
        ["58010"] = (3, "VIEW EXPORT")
    };
    internal static async Task<bool> Can(SqlConnection db, ClaimsPrincipal u, string menu, string action, CancellationToken ct)
    {
        if (!Scope(u, out var co, out _) || !Menus.TryGetValue(menu, out var s) || !s.Actions.Split(' ').Contains(action)) return false;
        await using var m = new SqlCommand("SELECT COUNT(*) FROM dbo.TDADMainMenu WHERE MenuCode=@m AND IsActive=1 AND ScreenType=@s", db); m.Parameters.AddWithValue("@m", menu); m.Parameters.AddWithValue("@s", s.Screen); if (Convert.ToInt32(await m.ExecuteScalarAsync(ct)) == 0) return false;
        await using var e = new SqlCommand("SELECT COUNT(*) FROM dbo.TDADCompanyProjectSubscription S JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_DIGITAL_CHECKLIST' AND P.IsActive=1 JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1 WHERE S.CompanyID=@co AND S.IsCurrent=1 AND S.StartDate<=CONVERT(date,SYSUTCDATETIME()) AND S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))", db); e.Parameters.AddWithValue("@co", co);
        return Convert.ToInt32(await e.ExecuteScalarAsync(ct)) > 0 && await CompanyMenuAccess.IsAllowedAsync(db, u, menu, action, ct);
    }
}
