using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;
namespace Laoo.Site;
internal static class SiteAccess
{
    static readonly Dictionary<string, int> Screens = new()
    {
        ["63001"]=2, ["63002"]=1, ["63003"]=4, ["63004"]=3,
        ["63005"]=1, ["63006"]=4, ["63007"]=3, ["63008"]=3
    };
    public static bool Scope(ClaimsPrincipal user, out long company, out long actor)
    {
        company=actor=0;
        return user.FindFirstValue("user_type")=="COMPANY_USER"
            && long.TryParse(user.FindFirstValue("company_id"),out company) && company>0
            && long.TryParse(user.FindFirstValue("user_id"),out actor) && actor>0;
    }
    public static async Task<bool> Can(SqlConnection db, ClaimsPrincipal user, string menu, string action, CancellationToken ct)
    {
        if (!Scope(user,out _,out _) || !Screens.TryGetValue(menu,out var screen)) return false;
        var mapped=await SiteDb.Scalar(db,null,@"SELECT COUNT(*) FROM dbo.TDADMainMenu M
JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.IsActive=1
JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.ProjectCode=N'LAOO_SITE' AND P.IsActive=1
WHERE M.MenuCode=@menu AND M.IsActive=1 AND M.ScreenType=@screen",ct,("@menu",menu),("@screen",screen));
        return mapped>0 && await CompanyMenuAccess.IsAllowedAsync(db,user,menu,action,ct);
    }
}
