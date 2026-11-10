using System.Security.Claims;
using System.Reflection;
using Laoo.Shared.Contracts;
using LaooApi.Controllers;
using LaooApi.Models.Navigation;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;

// Read-only regression against an employee with group permissions but no user/project link.
var root = Path.GetFullPath(args[0]);
var config = new ConfigurationBuilder().AddJsonFile(Path.Combine(root, "laoo_api/appsettings.json"))
    .AddJsonFile(Path.Combine(root, "laoo_api/local.json")).Build();
await using var db = new SqlConnection(config.GetConnectionString("LaooDatabase"));
await db.OpenAsync();
await using var fixture = new SqlCommand("""
SELECT U.UserID,U.CompanyID,C.PartnerID,P.ProjectID
FROM dbo.TDADUser U JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.IsActive=1
CROSS JOIN dbo.TDADProject P
WHERE U.NormalizedUsername=@name AND U.IsActive=1 AND P.ProjectCode=N'LAOO' AND P.IsActive=1
""", db);
fixture.Parameters.AddWithValue("@name", (args.ElementAtOrDefault(1) ?? "m").ToUpperInvariant());
long user, company, partner, core;
await using (var reader = await fixture.ExecuteReaderAsync())
{
    if (!await reader.ReadAsync()) throw new Exception("Employee fixture missing.");
    (user, company, partner, core) = (reader.GetInt64(0),reader.GetInt64(1),reader.GetInt64(2),reader.GetInt64(3));
}
ClaimsPrincipal Principal(long companyId) => new(new ClaimsIdentity(new[] {
    new Claim("user_type", "COMPANY_USER"),new Claim("user_id",user.ToString()),
    new Claim("company_id",companyId.ToString()),new Claim("partner_id",partner.ToString()),
    new Claim("project_code","LAOO"),
    new Claim("project_id",core.ToString()) }, "test"));
var principal = Principal(company);
var controller = new NavigationController(config) { ControllerContext = new ControllerContext {
    HttpContext = new DefaultHttpContext { User = principal } } };
var result = await controller.GetProjects(default);
var projects = (List<NavigationProjectResponse>)((OkObjectResult)result.Result!).Value!;
var menus = projects.SelectMany(p=>p.MenuGroups).SelectMany(g=>g.Items).Select(m=>m.MenuCode).ToHashSet();
foreach(var project in projects)
foreach(var menu in project.MenuGroups.SelectMany(g=>g.Items))
    if (!await CompanyMenuAccess.IsAllowedForProjectAsync(db,principal,project.ProjectCode,menu.MenuCode,"VIEW",default))
        throw new Exception($"Navigation exposed a menu outside its Project permission: {project.ProjectCode}/{menu.MenuCode}.");
await using var grants = new SqlCommand("""
SELECT DISTINCT RP.MenuCode,RP.ActionCode,P.ProjectCode
FROM dbo.TDADUserEmployee UE
JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1
JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=E.EmployeeID AND ERG.IsActive=1
JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.CompanyID=UE.CompanyID AND RG.ScopeType='C' AND RG.IsActive=1
JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.IsAllowed=1
JOIN dbo.TDADProject P ON P.ProjectID=RP.ProjectID AND P.ProjectCode=N'LAOO_SERVICE' AND P.IsActive=1
JOIN dbo.TDADCompanyProjectSubscription S ON S.CompanyID=UE.CompanyID AND S.ProjectID=P.ProjectID AND S.IsCurrent=1
 AND S.StatusCode IN(N'ACTIVE',N'TRIAL') AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
 AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
WHERE UE.UserID=@user AND UE.CompanyID=@company AND UE.IsActive=1
 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
""", db);
grants.Parameters.AddWithValue("@user",user);grants.Parameters.AddWithValue("@company",company);
var expected = new List<(string Menu,string Action,string Project)>();
await using(var reader=await grants.ExecuteReaderAsync()) while(await reader.ReadAsync())
    expected.Add((reader.GetString(0),reader.GetString(1),reader.GetString(2)));
if (expected.Count==0) throw new Exception("Active service role grants missing.");
foreach(var grant in expected)
{
    if (grant.Action=="VIEW" && !menus.Contains(grant.Menu)) throw new Exception($"Group VIEW menu {grant.Menu} missing from navigation.");
    if (!await CompanyMenuAccess.IsAllowedForProjectAsync(db,principal,grant.Project,grant.Menu,grant.Action,default))
        throw new Exception($"Group {grant.Action} denied for {grant.Menu}.");
    if (await CompanyMenuAccess.IsAllowedForProjectAsync(db,Principal(-1),grant.Project,grant.Menu,grant.Action,default))
        throw new Exception("Cross-company access granted.");
}
Console.WriteLine($"PASS: {expected.Count} group grants work without a manual Project assignment; cross-company access denied.");

var loginProject = typeof(LaooApi.Services.AuthenticationService).GetMethod("FindLoginProjectAsync",BindingFlags.Static|BindingFlags.NonPublic)!;
var loginResult = (Task<(long Id,string Code)?>)loginProject.Invoke(null,new object?[]{db,(args.ElementAtOrDefault(1)??"m").ToUpperInvariant(),"LAOO_SERVICE",CancellationToken.None})!;
if (await loginResult is null) throw new Exception("Login cannot resolve permitted business Project.");
var postLogin = new Laoo.Service.Api.Controllers.AuthContextController(config,NullLogger<Laoo.Service.Api.Controllers.AuthContextController>.Instance)
{ControllerContext=new ControllerContext{HttpContext=new DefaultHttpContext{User=principal}}};
var postResult = await postLogin.GetPostLoginContext(default);
var post = ((OkObjectResult)postResult.Result!).Value as Laoo.Service.Api.Models.Auth.PostLoginContextResponse;
if (post is null || !post.Projects.Any(p=>p.ProjectCode=="LAOO_SERVICE")) throw new Exception("Post-login context missing permitted business Project.");
var filter = new LaooServiceModule.Security.RequireCompanyProjectFilter(config,"LAOO_SERVICE");
var filterContext = new AuthorizationFilterContext(new ActionContext(new DefaultHttpContext{User=principal},new RouteData(),new ActionDescriptor()),new List<IFilterMetadata>());
await filter.OnAuthorizationAsync(filterContext);
if (filterContext.Result is not null) throw new Exception("Service Project guard denied group member.");
var absent = new AuthorizationFilterContext(new ActionContext(new DefaultHttpContext{User=Principal(-1)},new RouteData(),new ActionDescriptor()),new List<IFilterMetadata>());
await filter.OnAuthorizationAsync(absent);
if (absent.Result is not ObjectResult {StatusCode:403}) throw new Exception("Project guard failed Company isolation.");
foreach (var action in new[]{"EDIT","DELETE"})
    if (!expected.Any(g=>g.Menu=="20001"&&g.Action==action)
        && await CompanyMenuAccess.IsAllowedForProjectAsync(db,principal,"LAOO_SERVICE","20001",action,default))
        throw new Exception($"Unassigned {action} permission granted.");
if(await CompanyMenuAccess.IsAllowedForProjectAsync(db,principal,"MISSING_PROJECT","20001","VIEW",default))
    throw new Exception("Unavailable Project granted.");
Console.WriteLine("PASS: login Project, post-login context and Service API guard agree; unassigned actions and unavailable Project denied.");

await using var adminQuery=new SqlCommand("SELECT TOP 1 UserID FROM dbo.TDADUser WHERE CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1 ORDER BY UserID",db);
adminQuery.Parameters.AddWithValue("@company",company);
var adminId=await adminQuery.ExecuteScalarAsync() ?? throw new Exception("Company admin fixture missing.");
var adminIdentity=new ClaimsIdentity(principal.Claims.Where(c=>c.Type!="user_id"),"test");
adminIdentity.AddClaim(new Claim("user_id",adminId.ToString()!));
var adminPrincipal=new ClaimsPrincipal(adminIdentity);
foreach(var action in new[]{"VIEW","CREATE","EDIT","DELETE"})
    if(!await CompanyMenuAccess.IsAllowedForProjectAsync(db,adminPrincipal,"LAOO_SERVICE","20001",action,default))
        throw new Exception($"Company admin denied {action} within enabled package.");
await using var disabledQuery=new SqlCommand("""
SELECT TOP 1 P.ProjectCode,PM.MenuCode FROM dbo.TDADProject P
JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=P.ProjectID AND PM.IsActive=1
JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode AND M.IsActive=1
WHERE P.IsActive=1 AND P.ProjectType<>N'CORE' AND NOT EXISTS
 (SELECT 1 FROM dbo.TDADCompanyProjectSubscription S
  JOIN dbo.TDADProjectPackage PK ON PK.PackageID=S.PackageID AND PK.ProjectID=S.ProjectID AND PK.IsActive=1
  WHERE S.CompanyID=@company AND S.ProjectID=P.ProjectID AND S.IsCurrent=1 AND S.StatusCode IN(N'ACTIVE',N'TRIAL')
   AND S.StartDate<=CONVERT(date,SYSUTCDATETIME()) AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
ORDER BY P.ProjectID,PM.MenuCode
""",db);
disabledQuery.Parameters.AddWithValue("@company",company);
string disabledProject,disabledMenu;
await using(var reader=await disabledQuery.ExecuteReaderAsync())
{
    if(!await reader.ReadAsync()) throw new Exception("Disabled package fixture missing.");
    disabledProject=reader.GetString(0);disabledMenu=reader.GetString(1);
}
if(await CompanyMenuAccess.IsAllowedForProjectAsync(db,adminPrincipal,disabledProject,disabledMenu,"VIEW",default))
    throw new Exception("Company admin bypassed disabled package.");
Console.WriteLine("PASS: Company admin has all CRUD actions in enabled service; disabled business package remains denied.");
