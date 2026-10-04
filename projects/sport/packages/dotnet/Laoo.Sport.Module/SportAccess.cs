using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;

namespace Laoo.Sport;

public static class SportAccess
{
    private static readonly IReadOnlyDictionary<string, (int ScreenType, string Actions)> Menus =
        new Dictionary<string, (int, string)>
        {
            ["54001"] = (2, "VIEW EDIT"),
            ["54002"] = (1, "VIEW CREATE EDIT DELETE"),
            ["54003"] = (1, "VIEW CREATE EDIT DELETE"),
            ["54004"] = (1, "VIEW CREATE EDIT DELETE"),
            ["54005"] = (1, "VIEW CREATE EDIT DELETE"),
            ["54006"] = (1, "VIEW CREATE EDIT DELETE MANAGE_CREDENTIAL"),
            ["54007"] = (4, "VIEW CREATE EDIT RENEW RECORD_PAYMENT"),
            ["54008"] = (1, "VIEW CREATE EDIT DELETE CANCEL"),
            ["54009"] = (3, "VIEW CHECK_IN MARK_NO_SHOW"),
            ["54010"] = (2, "VIEW EDIT"),
            ["54011"] = (3, "VIEW EXPORT")
        };

    public static bool Scope(ClaimsPrincipal user, out long company, out long actor)
    {
        company = actor = 0;
        return user.FindFirstValue("user_type") == "COMPANY_USER"
            && long.TryParse(user.FindFirstValue("company_id"), out company) && company > 0
            && long.TryParse(user.FindFirstValue("user_id"), out actor) && actor > 0;
    }

    public static async Task<bool> Can(SqlConnection db, ClaimsPrincipal user,
        string menu, string action, CancellationToken ct)
    {
        if (!Scope(user, out var company, out _) || !Menus.TryGetValue(menu, out var contract)
            || !contract.Actions.Split(' ').Contains(action)) return false;
        var screen = await SportDb.Id(db, null,
            "SELECT COALESCE(MAX(ScreenType),0) FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1",
            ct, ("@menu", menu));
        if (screen != contract.ScreenType) return false;
        var write = action is not ("VIEW" or "EXPORT");
        var subscription = await SportDb.Id(db, null, """
SELECT COUNT(*)
FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_SPORT' AND P.IsActive=1
JOIN dbo.TDADProjectPackage PK ON PK.PackageID=S.PackageID AND PK.ProjectID=P.ProjectID AND PK.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE S.CompanyID=@co AND S.IsCurrent=1 AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND ((S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
  OR (@write=0 AND S.StatusCode IN(N'ACTIVE',N'TRIAL',N'EXPIRED')
    AND (S.StatusCode=N'EXPIRED' OR S.ExpireDate<CONVERT(date,SYSUTCDATETIME()))))
""", ct, ("@co", company), ("@write", write));
        return subscription > 0 && await CompanyMenuAccess.IsAllowedAsync(db, user, menu, action, ct);
    }
}
