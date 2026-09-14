using System.Security.Claims;
using LaooApi.Controllers;
using LaooApi.Models.Navigation;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

var root = Path.GetFullPath(args.FirstOrDefault() ?? ".");
var config = new ConfigurationBuilder().AddJsonFile(Path.Combine(root, "laoo_api/local.json")).Build();
await using var connection = new SqlConnection(config.GetConnectionString("LaooDatabase"));
await connection.OpenAsync();
await using var command = new SqlCommand("SELECT U.UserID,C.CompanyID,C.PartnerID,P.ProjectID FROM dbo.TDADUser U JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.IsActive=1 JOIN dbo.TDADUserProject UP ON UP.UserID=U.UserID AND UP.CompanyID=C.CompanyID AND UP.IsActive=1 JOIN dbo.TDADProject P ON P.ProjectID=UP.ProjectID AND P.ProjectCode=N'LAOO' AND P.IsActive=1 WHERE U.IsActive=1 AND C.CompanyCode=N'DEMO' ORDER BY U.IsCompanyAdmin DESC,U.UserID", connection);
await using var reader = await command.ExecuteReaderAsync();
var fixtures = new List<(long User, long Company, long Partner, long Project)>();
while (await reader.ReadAsync()) fixtures.Add((reader.GetInt64(0), reader.GetInt64(1), reader.GetInt64(2), reader.GetInt64(3)));
if (fixtures.Count == 0) throw new Exception("No DEMO navigation fixtures.");

var foundRoleMenus = false;
foreach (var fixture in fixtures)
{
    var controller = new NavigationController(config)
    {
        ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity(new[] {
                new Claim("user_type", "COMPANY_USER"), new Claim("user_id", fixture.User.ToString()),
                new Claim("company_id", fixture.Company.ToString()), new Claim("partner_id", fixture.Partner.ToString()),
                new Claim("project_id", fixture.Project.ToString())
            }, "Test"))
        }}
    };
    var projects = (List<NavigationProjectResponse>)((OkObjectResult)(await controller.GetProjects(default)).Result!).Value!;
    var groups = (List<NavigationMenuGroupResponse>)((OkObjectResult)(await controller.GetMenus(default)).Result!).Value!;
    var expected = projects.SelectMany(project => project.MenuGroups).SelectMany(group => group.Items).Select(item => item.MenuCode).ToHashSet();
    var actual = groups.SelectMany(group => group.Items).Select(item => item.MenuCode).ToList();
    if (!expected.SetEquals(actual)) throw new Exception("Flat navigation dropped project menus.");
    if (actual.Count != actual.Distinct().Count()) throw new Exception("Duplicate menus.");
    if (groups.Count != groups.Select(group => group.MenuGroupCode).Distinct().Count()) throw new Exception("Duplicate groups.");
    foundRoleMenus |= actual.Contains("14005") && actual.Contains("14006");
}
if (!foundRoleMenus) throw new Exception("Fixture must expose both 14005 and 14006.");
Console.WriteLine("PASS: Service customer/resident menus retained for route authorization.");
