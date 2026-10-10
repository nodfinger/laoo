using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;

namespace Laoo.Rental;

public static class RentalAccess
{
    private static readonly IReadOnlyDictionary<string, (int ScreenType, string Actions)> Menus =
        new Dictionary<string, (int, string)>
        {
            ["60001"] = (2, "VIEW EDIT"),
            ["60002"] = (1, "VIEW CREATE EDIT DELETE"),
            ["60003"] = (3, "VIEW"),
            ["60004"] = (4, "VIEW CREATE CANCEL"),
            ["60005"] = (4, "VIEW CREATE"),
            ["60006"] = (4, "VIEW CREATE"),
            ["60007"] = (4, "VIEW CREATE"),
            ["60008"] = (4, "VIEW APPROVE REFUND"),
            ["60009"] = (3, "VIEW"),
            ["60010"] = (3, "VIEW")
        };

    public static bool Scope(ClaimsPrincipal user, out long company, out long actor)
    {
        company = actor = 0;
        return user.FindFirstValue("user_type") == "COMPANY_USER"
            && long.TryParse(user.FindFirstValue("company_id"), out company) && company > 0
            && long.TryParse(user.FindFirstValue("user_id"), out actor) && actor > 0;
    }

    public static bool KnownMenu(string menu) => Menus.ContainsKey(menu);

    public static async Task<bool> Can(SqlConnection db, ClaimsPrincipal user,
        string menu, string action, CancellationToken ct)
    {
        if (!Scope(user, out var company, out _) || !Menus.TryGetValue(menu, out var contract)
            || !contract.Actions.Split(' ').Contains(action)) return false;
        var screen = await RentalDb.Number(db, null,
            "SELECT COALESCE(MAX(ScreenType),0) FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1",
            ct, ("@menu", menu));
        if (screen != contract.ScreenType) return false;
        var subscription = await RentalDb.Number(db, null, """
SELECT COUNT(*) FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_RENTAL' AND P.IsActive=1
JOIN dbo.TDADProjectPackage PK ON PK.PackageID=S.PackageID AND PK.ProjectID=P.ProjectID AND PK.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE S.CompanyID=@co AND S.IsCurrent=1 AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND ((S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
 OR (@readOnly=1 AND S.StatusCode IN(N'ACTIVE',N'TRIAL',N'EXPIRED')
 AND (S.StatusCode=N'EXPIRED' OR S.ExpireDate<CONVERT(date,SYSUTCDATETIME()))))
""", ct, ("@co", company), ("@readOnly", action is "VIEW" or "PREVIEW" or "DOWNLOAD" or "PRINT" or "EXPORT"));
        return subscription > 0 && await CompanyMenuAccess.IsAllowedAsync(db, user, menu, action, ct);
    }

    public static async Task<bool> Branch(SqlConnection db, long company, long actor,
        long branch, CancellationToken ct)
    {
        return await RentalDb.Number(db, null, """
SELECT COUNT(*) FROM dbo.TDADBranch B
WHERE B.CompanyID=@co AND B.BranchID=@branch
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor AND UB.BranchID=@branch AND UB.IsActive=1))
""", ct, ("@co", company), ("@actor", actor), ("@branch", branch)) > 0;
    }
}
