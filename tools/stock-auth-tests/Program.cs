using System.Reflection;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using System.Transactions;
using LaooApi.Controllers;
using LaooApi.Security;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.IdentityModel.Tokens;

var root = Path.GetFullPath(args[0]);
var outputPath = Path.GetFullPath(args[1]);
var config = new ConfigurationBuilder()
    .AddJsonFile(Path.Combine(root, "laoo_api", "appsettings.json"))
    .AddJsonFile(Path.Combine(root, "laoo_api", "local.json")).Build();
var connectionString = config.GetConnectionString("LaooDatabase") ?? throw new InvalidOperationException("Missing database configuration.");
var users = new List<(long User, long Company, long Partner, long Project)>();
await using (var db = new SqlConnection(connectionString))
{
    await db.OpenAsync();
    await using var usersCommand = new SqlCommand("""
SELECT DISTINCT U.UserID,U.CompanyID,C.PartnerID,P.ProjectID
FROM dbo.TDADUser U JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.IsActive=1
JOIN dbo.TDADUserProject UP ON UP.UserID=U.UserID AND UP.CompanyID=U.CompanyID AND UP.IsActive=1
JOIN dbo.TDADProject P ON P.ProjectID=UP.ProjectID AND P.ProjectCode=N'LAOO'
WHERE U.IsActive=1 ORDER BY U.CompanyID,U.UserID
""", db);
    await using var reader = await usersCommand.ExecuteReaderAsync();
    while (await reader.ReadAsync()) users.Add((reader.GetInt64(0), reader.GetInt64(1), reader.GetInt64(2), reader.GetInt64(3)));
}

ClaimsPrincipal Principal((long User, long Company, long Partner, long Project) user) => new(new ClaimsIdentity([
    new Claim("user_type", "COMPANY_USER"), new Claim("user_id", user.User.ToString()),
    new Claim("company_id", user.Company.ToString()), new Claim("partner_id", user.Partner.ToString()),
    new Claim("project_id", user.Project.ToString()),
], "test"));

var canVendor = typeof(VendorController).GetMethod("Can", BindingFlags.Instance | BindingFlags.NonPublic)
    ?? throw new InvalidOperationException("Vendor authorization method missing.");
var allowed = new List<string>();
await using (var db = new SqlConnection(connectionString))
{
    await db.OpenAsync();
    foreach (var user in users)
    {
        var principal = Principal(user);
        var controller = new VendorController(config, NullLogger<VendorController>.Instance)
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = principal } }
        };
        foreach (var action in new[] { "VIEW", "CREATE", "EDIT", "DELETE" })
        {
            if (await ItemCatalogAuthorization.IsAllowed(db, principal, action, CancellationToken.None))
                allowed.Add($"{user.Company}|{user.User}|08001|{action}");
            var vendorTask = (Task<bool>)canVendor.Invoke(controller, [db, action, CancellationToken.None])!;
            if (await vendorTask) allowed.Add($"{user.Company}|{user.User}|08007|{action}");
        }
    }
}
await File.WriteAllLinesAsync(outputPath, allowed.OrderBy(x => x, StringComparer.Ordinal));
Console.WriteLine($"Checked actual item/vendor authorization for {users.Count} active users: {allowed.Count} allowed actions.");

if (args.Contains("--check-suspension"))
{
    var selected = users.FirstOrDefault(u => allowed.Contains($"{u.Company}|{u.User}|08001|VIEW")
        && allowed.Contains($"{u.Company}|{u.User}|08007|VIEW"));
    if (selected.User == 0) throw new InvalidOperationException("No existing item and vendor viewer to test.");
    using (var scope = new TransactionScope(TransactionScopeAsyncFlowOption.Enabled))
    {
        await using var db = new SqlConnection(connectionString);
        await db.OpenAsync();
        await using var suspend = new SqlCommand("""
UPDATE S SET StatusCode=N'SUSPENDED'
FROM dbo.TDADCompanyProjectSubscription S JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID
WHERE P.ProjectCode=N'LAOO_STOCK' AND S.CompanyID=@company AND S.IsCurrent=1
""", db);
        suspend.Parameters.AddWithValue("@company", selected.Company);
        if (await suspend.ExecuteNonQueryAsync() != 1) throw new InvalidOperationException("Expected exactly one active stock subscription.");
        var principal = Principal(selected);
        var controller = new VendorController(config, NullLogger<VendorController>.Instance)
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = principal } }
        };
        var sharedAllowed = await CompanyMenuAccess.IsAllowedAsync(db, principal, "08001", "VIEW", CancellationToken.None);
        var itemAllowed = await ItemCatalogAuthorization.IsAllowed(db, principal, "VIEW", CancellationToken.None);
        var vendorAllowed = await (Task<bool>)canVendor.Invoke(controller, [db, "VIEW", CancellationToken.None])!;
        if (sharedAllowed || itemAllowed || vendorAllowed)
            throw new InvalidOperationException("Suspended stock subscription still permits item or vendor access.");
        // No Complete(): test update is rolled back when the scope is disposed.
    }
    await using var verifyDb = new SqlConnection(connectionString);
    await verifyDb.OpenAsync();
    if (!await ItemCatalogAuthorization.IsAllowed(verifyDb, Principal(selected), "VIEW", CancellationToken.None))
        throw new InvalidOperationException("Stock access was not restored after rollback.");
    Console.WriteLine("Suspension denies item and vendor access; rollback restores the original subscription.");
}

if (args.Contains("--http-check"))
{
    var selected = users.FirstOrDefault(u => allowed.Contains($"{u.Company}|{u.User}|08001|VIEW")
        && allowed.Contains($"{u.Company}|{u.User}|08007|VIEW"));
    if (selected.User == 0) throw new InvalidOperationException("No existing viewer for read-only API checks.");
    var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:SecretKey"] ?? throw new InvalidOperationException("Missing JWT key.")));
    var token = new JwtSecurityToken(
        issuer: config["Jwt:Issuer"], audience: config["Jwt:Audience"],
        claims: Principal(selected).Claims, notBefore: DateTime.UtcNow.AddMinutes(-1), expires: DateTime.UtcNow.AddMinutes(3),
        signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));
    using var client = new HttpClient { BaseAddress = new Uri("http://127.0.0.1:5080/"), Timeout = TimeSpan.FromSeconds(20) };
    client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", new JwtSecurityTokenHandler().WriteToken(token));
    foreach (var endpoint in new[] { "api/company/items/actions", "api/company/vendors/actions" })
    {
        using var response = await client.GetAsync(endpoint);
        response.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        if (!json.RootElement.GetProperty("view").GetBoolean()) throw new InvalidOperationException($"Expected VIEW permission at {endpoint}.");
    }
    using var navigation = await client.GetAsync("api/navigation/projects");
    navigation.EnsureSuccessStatusCode();
    using var navigationJson = JsonDocument.Parse(await navigation.Content.ReadAsStringAsync());
    var projects = navigationJson.RootElement.EnumerateArray().ToArray();
    var stock = projects.SingleOrDefault(p => p.GetProperty("projectCode").GetString() == "LAOO_STOCK");
    if (stock.ValueKind == JsonValueKind.Undefined || stock.GetProperty("projectName").GetString() != "ระบบบริหารสต๊อก")
        throw new InvalidOperationException("The stock project or its name is missing from navigation.");
    var stockMenus = stock.GetProperty("menuGroups").EnumerateArray()
        .SelectMany(g => g.GetProperty("items").EnumerateArray().Select(i => i.GetProperty("menuCode").GetString()))
        .ToArray();
    if (!stockMenus.Contains("08001")) throw new InvalidOperationException("Product menu is missing from the stock project.");
    var core = projects.FirstOrDefault(p => p.GetProperty("projectCode").GetString() == "LAOO");
    if (core.ValueKind != JsonValueKind.Undefined && core.GetProperty("menuGroups").EnumerateArray()
        .SelectMany(g => g.GetProperty("items").EnumerateArray()).Any(i => i.GetProperty("menuCode").GetString() == "08001"))
        throw new InvalidOperationException("Product menu is still active under the core project.");
    Console.WriteLine("Live API returned item/vendor VIEW and the stock project menu for an existing user.");
}
