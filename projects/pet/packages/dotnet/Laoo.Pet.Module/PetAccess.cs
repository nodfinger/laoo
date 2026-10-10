using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;
namespace Laoo.Pet;
internal static class PetAccess
{
    static readonly Dictionary<string, int> Screens = new()
    { ["62001"]=2,["62002"]=1,["62003"]=1,["62004"]=1,["62005"]=1,["62006"]=4,["62007"]=4,["62008"]=3,["62009"]=3,["62010"]=3 };
    public static bool Scope(ClaimsPrincipal user, out long company, out long actor)
    {
        company=actor=0;
        return user.FindFirstValue("user_type")=="COMPANY_USER"
            && long.TryParse(user.FindFirstValue("company_id"), out company) && company>0
            && long.TryParse(user.FindFirstValue("user_id"), out actor) && actor>0;
    }
    public static async Task<bool> Can(SqlConnection db, ClaimsPrincipal user, string menu, string action, CancellationToken ct)
    {
        if (!Scope(user,out _,out _) || !Screens.TryGetValue(menu,out var screen)) return false;
        var mapped=await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.IsActive=1 JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.ProjectCode=N'LAOO_PET' AND P.IsActive=1 WHERE M.MenuCode=@m AND M.IsActive=1 AND M.ScreenType=@s",ct,("@m",menu),("@s",screen));
        if(mapped==0 || !await CompanyMenuAccess.IsAllowedAsync(db,user,menu,action,ct)) return false;
        var readOnly=action is "VIEW" or "PREVIEW" or "DOWNLOAD" or "PRINT" or "EXPORT";
        var company=long.Parse(user.FindFirstValue("company_id")!);
        var petSubscription=await PetDb.Id(db,null,@"SELECT COUNT(*) FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_PET' AND P.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE S.CompanyID=@c AND S.IsCurrent=1 AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND ((S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
 OR (@read=1 AND (S.StatusCode=N'EXPIRED' OR (S.StatusCode IN(N'ACTIVE',N'TRIAL') AND S.ExpireDate<CONVERT(date,SYSUTCDATETIME())))))",ct,("@c",company),("@read",readOnly));
        if(petSubscription==0)return false;
        var booking=await PetDb.Id(db,null,@"SELECT COUNT(*) FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_BOOKING' AND P.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE S.CompanyID=@c AND S.IsCurrent=1 AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND ((S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
 OR (@read=1 AND (S.StatusCode=N'EXPIRED' OR (S.StatusCode IN(N'ACTIVE',N'TRIAL') AND S.ExpireDate<CONVERT(date,SYSUTCDATETIME())))))",ct,("@c",company),("@read",readOnly));
        return booking>0;
    }
}
