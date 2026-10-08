using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;

namespace Laoo.Patrol;

internal static class PatrolAccess
{
    private static readonly IReadOnlyDictionary<string, (int Screen, string Actions)> Menus =
        new Dictionary<string, (int, string)>
        {
            ["56001"] = (2, "VIEW EDIT"),
            ["56002"] = (1, "VIEW CREATE EDIT DELETE"),
            ["56003"] = (1, "VIEW CREATE EDIT DELETE MANAGE_DEVICE"),
            ["56004"] = (1, "VIEW CREATE EDIT DELETE ENROLL_CREDENTIAL"),
            ["56005"] = (1, "VIEW CREATE EDIT DELETE"),
            ["56006"] = (1, "VIEW CREATE EDIT DELETE"),
            ["56007"] = (4, "VIEW CREATE EDIT ASSIGN CANCEL"),
            ["56008"] = (4, "VIEW START CHECKPOINT SKIP COMPLETE CANCEL REPORT_INCIDENT"),
            ["56009"] = (3, "VIEW ACKNOWLEDGE"),
            ["56010"] = (3, "VIEW ACKNOWLEDGE ESCALATE CREATE_SERVICE"),
            ["56011"] = (3, "VIEW EXPORT"),
            ["56012"] = (3, "VIEW EXPORT")
        };

    public static bool Scope(ClaimsPrincipal user, out long company, out long actor)
    {
        company = actor = 0;
        return user.FindFirstValue("user_type") == "COMPANY_USER"
            && long.TryParse(user.FindFirstValue("company_id"), out company) && company > 0
            && long.TryParse(user.FindFirstValue("user_id"), out actor) && actor > 0;
    }

    public static async Task<bool> Can(SqlConnection db, ClaimsPrincipal user, string menu,
        string action, CancellationToken ct)
    {
        if (!Scope(user, out var company, out _) || !Menus.TryGetValue(menu, out var contract)
           || !contract.Actions.Split(' ').Contains(action)) return false;
        var screen = await PatrolDb.Id(db, null,
            "SELECT COALESCE(MAX(ScreenType),0) FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1",
            ct, ("@menu", menu));
        if (screen != contract.Screen) return false;
        var write = action is not ("VIEW" or "EXPORT");
        var entitlement = await PatrolDb.Id(db, null, """
SELECT COUNT(*)
FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_PATROL' AND P.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE S.CompanyID=@co AND S.IsCurrent=1 AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND ((S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
 OR (@write=0 AND (S.StatusCode=N'EXPIRED' OR S.ExpireDate<CONVERT(date,SYSUTCDATETIME()))))
AND EXISTS(
 SELECT 1 FROM dbo.TDADCompanyProjectSubscription TS
 JOIN dbo.TDADProject TP ON TP.ProjectID=TS.ProjectID AND TP.ProjectCode=N'LAOO_TIME' AND TP.IsActive=1
 WHERE TS.CompanyID=S.CompanyID AND TS.IsCurrent=1 AND TS.StatusCode IN(N'ACTIVE',N'TRIAL')
 AND (TS.ExpireDate IS NULL OR TS.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
""", ct, ("@co", company), ("@write", write));
        return entitlement > 0 && await CompanyMenuAccess.IsAllowedAsync(db, user, menu, action, ct);
    }
}
