using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;

namespace Laoo.SchoolFood;

public static class SchoolFoodAccess
{
    // Both subscriptions are required. An expired subscription permits historical reads only.
    public static async Task<bool> HasSubscriptions(SqlConnection db, long company,
        bool write, CancellationToken ct) =>
        await FoodDb.Id(db, null, """
SELECT COUNT(DISTINCT P.ProjectCode)
FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.IsActive=1
JOIN dbo.TDADProjectPackage PK ON PK.PackageID=S.PackageID AND PK.ProjectID=P.ProjectID AND PK.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE S.CompanyID=@co AND S.IsCurrent=1 AND P.ProjectCode IN(N'LAOO_SCHOOL',N'LAOO_SCHOOL_FOOD')
AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND ((S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
OR (@write=0 AND S.StatusCode IN(N'ACTIVE',N'TRIAL',N'EXPIRED') AND
 (S.StatusCode=N'EXPIRED' OR S.ExpireDate<CONVERT(date,SYSUTCDATETIME()))))
""",ct,("@co",company),("@write",write)) == 2;

    public static bool Scope(ClaimsPrincipal user, out long company, out long actor)
    {
        company=actor=0;
        return user.FindFirstValue("user_type")=="COMPANY_USER"
            && long.TryParse(user.FindFirstValue("company_id"),out company)
            && long.TryParse(user.FindFirstValue("user_id"),out actor) && company>0 && actor>0;
    }

    public static async Task<bool> Can(SqlConnection db, ClaimsPrincipal user,
        string menu, string action, CancellationToken ct)
    {
        if (!Scope(user,out var company,out _)) return false;
        var contract=SchoolFoodContract.Menus.SingleOrDefault(m=>m.Code==menu);
        if(contract is null || !contract.Actions.Contains(action)) return false;
        var screenType=await FoodDb.Id(db,null,"SELECT COALESCE(MAX(ScreenType),0) FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1",ct,("@menu",menu));
        if(screenType!=contract.ScreenType)return false;
        return await HasSubscriptions(db,company,action is not ("VIEW" or "EXPORT"),ct)
            && await CompanyMenuAccess.IsAllowedAsync(db,user,menu,action,ct);
    }

    // A present but disabled assignment must never promote a shop user to school-wide scope.
    public static async Task<long?> ShopScope(SqlConnection db,long company,long actor,CancellationToken ct)
    {
        var rows=await FoodDb.Rows(db,null,"SELECT ShopID,IsActive FROM dbo.TDSFShopUser WHERE CompanyID=@co AND UserID=@user",
            ct,("@co",company),("@user",actor));
        return rows.Count==0 ? null : rows[0].Bool("IsActive") ? rows[0].Long("ShopID") : -1;
    }
}
