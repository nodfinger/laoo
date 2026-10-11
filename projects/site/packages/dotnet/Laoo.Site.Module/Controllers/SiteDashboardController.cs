using Laoo.Site;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
namespace Laoo.Site.Controllers;

[ApiController,Authorize,Route("api/company/site/dashboard")]
public sealed class SiteDashboardController(IConfiguration config) : SiteControllerBase(config)
{
    [HttpGet]
    public async Task<IActionResult> Summary(CancellationToken ct,DateOnly? from=null,DateOnly? to=null,long? projectId=null)
    {
        if(from.HasValue&&to.HasValue&&from>to)return Invalid("วันที่เริ่มต้องไม่เกินวันที่สิ้นสุด");
        await using var db=await Open(ct);
        if(await Guard(db,"63008","VIEW",ct) is { } no)return no;
        var args=new (string,object?)[]{("@c",Company),("@actor",Actor),("@from",from),("@to",to),("@project",projectId)};
        var scope=@"P.CompanyID=@c AND (@project IS NULL OR P.SiteProjectID=@project)
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=P.BranchID AND X.IsActive=1))";
        var projects=await SiteDb.Rows(db,null,@"SELECT P.SiteProjectID id,P.ProjectName name,P.StatusCode status,
COALESCE((SELECT SUM(T.Weight*T.ProgressPercent)/NULLIF(SUM(T.Weight),0)
FROM dbo.TDSITask T WHERE T.CompanyID=P.CompanyID AND T.SiteProjectID=P.SiteProjectID AND T.IsActive=1),0) progressPercent,
(SELECT COUNT(*) FROM dbo.TDSIDailyReport R WHERE R.CompanyID=P.CompanyID AND R.SiteProjectID=P.SiteProjectID
AND (@from IS NULL OR R.WorkDate>=@from) AND (@to IS NULL OR R.WorkDate<=@to)) reportCount,
(SELECT COUNT(*) FROM dbo.TDSIIssue I WHERE I.CompanyID=P.CompanyID AND I.SiteProjectID=P.SiteProjectID AND I.StatusCode IN(N'OPEN',N'IN_PROGRESS')) openIssueCount,
(SELECT COALESCE(SUM(L.Amount),0) FROM dbo.TDSIDailyLine L JOIN dbo.TDSIDailyReport R ON R.CompanyID=L.CompanyID AND R.ReportID=L.ReportID
WHERE R.CompanyID=P.CompanyID AND R.SiteProjectID=P.SiteProjectID AND L.LineType=N'EXPENSE'
AND (@from IS NULL OR R.WorkDate>=@from) AND (@to IS NULL OR R.WorkDate<=@to)) internalExpense
FROM dbo.TDSIProject P WHERE "+scope+" ORDER BY P.SiteProjectID DESC",ct,args);
        return Ok(new {items=projects,total=projects.Count,from,to});
    }
}
