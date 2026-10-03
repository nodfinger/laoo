using System.Security.Claims;
using System.Text.Json;
using Laoo.Shared.Contracts;
using LaooApi.Controllers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

var root = Path.GetFullPath(args.FirstOrDefault() ?? ".");
var config = new ConfigurationBuilder().AddJsonFile(Path.Combine(root, "laoo_api/local.json")).Build();
await using var connection = new SqlConnection(config.GetConnectionString("LaooDatabase"));
await connection.OpenAsync();

async Task<int> Scalar(string sql)
{
    await using var command = new SqlCommand(sql, connection);
    return Convert.ToInt32(await command.ExecuteScalarAsync());
}

if (await Scalar("SELECT COUNT(1) FROM sys.tables WHERE name IN(N'TDADProjectPackage',N'TDADProjectPackageFeature',N'TDADProjectPackageQuota',N'TDADCompanyProjectSubscription',N'TDADCompanyProjectSubscriptionAudit')") != 5)
    throw new Exception("Package schema is incomplete.");
if (await Scalar("SELECT COUNT(1) FROM dbo.TDADProjectPackage PK JOIN dbo.TDADProject P ON P.ProjectID=PK.ProjectID WHERE P.ProjectType=N'CORE'") != 0)
    throw new Exception("CORE project must not have a package.");
if (await Scalar("SELECT COUNT(1) FROM dbo.TDADCompanyProject CP JOIN dbo.TDADProject P ON P.ProjectID=CP.ProjectID AND P.ProjectType<>N'CORE' WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription S WHERE S.CompanyID=CP.CompanyID AND S.ProjectID=CP.ProjectID AND S.IsCurrent=1)") != 0)
    throw new Exception("Business project backfill is incomplete.");
if (await Scalar("SELECT COUNT(1) FROM dbo.TDADCompanyProjectSubscription S JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_PROVIDER' JOIN dbo.TDADProjectPackage PK ON PK.PackageID=S.PackageID AND PK.PackageCode=N'FREE' WHERE S.IsCurrent=1 AND S.ReasonText=N'Migrated from TDADCompanyProject'") != 0)
    throw new Exception("Provider backfill lost existing feature access.");
if (await Scalar("SELECT COUNT(1) FROM (SELECT CompanyID,ProjectID FROM dbo.TDADCompanyProjectSubscription WHERE IsCurrent=1 GROUP BY CompanyID,ProjectID HAVING COUNT(1)>1) X") != 0)
    throw new Exception("Duplicate current subscriptions found.");
if (await Scalar("SELECT COUNT(1) FROM dbo.TDADCompanyProjectSubscription S JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID WHERE S.PartnerID<>C.PartnerID") != 0)
    throw new Exception("Subscription Partner scope mismatch.");

const string fixtureSql = """
SELECT TOP(1) PU.PartnerUserID,C.PartnerID,C.CompanyID,
 (SELECT TOP(1) ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1)
FROM dbo.TDADPartnerUser PU JOIN dbo.TDSTCompanySetUp C ON C.PartnerID=PU.PartnerID AND C.IsActive=1
WHERE PU.IsActive=1 AND PU.IsPartnerAdmin=1 AND C.CompanyID IS NOT NULL AND C.CompanyCode=N'DEMO'
ORDER BY PU.PartnerUserID;
""";
await using var fixtureCommand = new SqlCommand(fixtureSql, connection);
await using var reader = await fixtureCommand.ExecuteReaderAsync();
if (!await reader.ReadAsync()) throw new Exception("No Partner Admin fixture.");
var partnerUser = reader.GetInt64(0);
var partner = reader.GetInt64(1);
var company = reader.GetInt64(2);
var coreProject = reader.GetInt64(3);
await reader.CloseAsync();

var partnerController = new PartnerProjectSubscriptionController(config)
{
    ControllerContext = Context(
        ("user_type", "PARTNER_USER"), ("partner_user_id", $"{partnerUser}"),
        ("partner_id", $"{partner}"), ("project_id", $"{coreProject}"))
};
if (await partnerController.Get(company, default) is not ContentResult { StatusCode: 200 })
    throw new Exception("Partner cannot read own Company subscriptions.");

await using (var crossCommand = new SqlCommand(
    "SELECT TOP(1) CompanyID FROM dbo.TDSTCompanySetUp WHERE IsActive=1 AND PartnerID<>@Partner AND CompanyID IS NOT NULL", connection))
{
    crossCommand.Parameters.AddWithValue("@Partner", partner);
    var crossCompany = await crossCommand.ExecuteScalarAsync();
    if (crossCompany is not null &&
        await partnerController.Get(Convert.ToInt64(crossCompany), default) is not NotFoundObjectResult)
        throw new Exception("Partner can read a Company owned by another Partner.");
}

const string mismatchSql = """
SELECT TOP(1) S.ProjectID,PK2.PackageID
FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProjectPackage PK2 ON PK2.ProjectID<>S.ProjectID AND PK2.IsActive=1
WHERE S.CompanyID=@Company AND S.IsCurrent=1;
""";
await using (var mismatchCommand = new SqlCommand(mismatchSql, connection))
{
    mismatchCommand.Parameters.AddWithValue("@Company", company);
    await using var mismatch = await mismatchCommand.ExecuteReaderAsync();
    if (await mismatch.ReadAsync())
    {
        var project = mismatch.GetInt64(0);
        var wrongPackage = mismatch.GetInt64(1);
        await mismatch.CloseAsync();
        var auditBefore = await AuditCount(connection, company, project);
        var result = await partnerController.Save(company, project,
            new(wrongPackage, "ACTIVE", DateOnly.FromDateTime(DateTime.Today), null, "PACKAGE-TEST-ROLLBACK"), default);
        if (result is not BadRequestObjectResult) throw new Exception("Package from another Project was accepted.");
        if (await AuditCount(connection, company, project) != auditBefore)
            throw new Exception("Rejected package request wrote an audit row; rollback failed.");
    }
}

const string flowFixtureSql = """
SELECT TOP(1) S.ProjectID,S.PackageID,S.StatusCode,S.StartDate,S.ExpireDate,
 (SELECT TOP(1) PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=S.ProjectID AND IsActive=1 ORDER BY SortOrder),
 (SELECT TOP(1) PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=S.ProjectID AND IsActive=1 ORDER BY SortOrder DESC)
FROM dbo.TDADCompanyProjectSubscription S
WHERE S.CompanyID=@Company AND S.IsCurrent=1
 AND (SELECT COUNT(1) FROM dbo.TDADProjectPackage WHERE ProjectID=S.ProjectID AND IsActive=1)>=2
ORDER BY S.ProjectID;
""";
await using (var flowCommand = new SqlCommand(flowFixtureSql, connection))
{
    flowCommand.Parameters.AddWithValue("@Company", company);
    await using var flow = await flowCommand.ExecuteReaderAsync();
    if (!await flow.ReadAsync()) throw new Exception("DEMO has no business subscription flow fixture.");
    var project = flow.GetInt64(0);
    var originalPackage = flow.GetInt64(1);
    var originalStatus = flow.GetString(2);
    var originalStart = DateOnly.FromDateTime(flow.GetDateTime(3));
    DateOnly? originalExpire = flow.IsDBNull(4) ? null : DateOnly.FromDateTime(flow.GetDateTime(4));
    var lowPackage = flow.GetInt64(5);
    var highPackage = flow.GetInt64(6);
    await flow.CloseAsync();
    var runId = $"PACKAGE-FLOW-{DateTime.UtcNow:yyyyMMddHHmmss}";
    var today = DateOnly.FromDateTime(DateTime.Today);
    var future = today.AddDays(30);
    try
    {
        await ExpectSaved(partnerController, company, project, lowPackage, "TRIAL", today, future, runId);
        await ExpectSaved(partnerController, company, project, highPackage, "ACTIVE", today, future, runId);
        await ExpectSaved(partnerController, company, project, lowPackage, "ACTIVE", today, future, runId);
        await ExpectSaved(partnerController, company, project, lowPackage, "EXPIRED", today, today, runId);
        await ExpectSaved(partnerController, company, project, lowPackage, "SUSPENDED", today, future, runId);
        await ExpectSaved(partnerController, company, project, lowPackage, "CANCELLED", today, future, runId);
    }
    finally
    {
        await ExpectSaved(partnerController, company, project, originalPackage, originalStatus,
            originalStart, originalExpire, $"{runId}-RESTORE");
    }
    await using var audit = new SqlCommand(
        "SELECT COUNT(DISTINCT ActionCode) FROM dbo.TDADCompanyProjectSubscriptionAudit WHERE CompanyID=@Company AND ProjectID=@Project AND ReasonText LIKE @Run + N'%' AND ActionCode IN(N'RENEW',N'UPGRADE',N'DOWNGRADE',N'EXPIRE',N'SUSPEND',N'CANCEL')", connection);
    audit.Parameters.AddWithValue("@Company", company);
    audit.Parameters.AddWithValue("@Project", project);
    audit.Parameters.AddWithValue("@Run", runId);
    if (Convert.ToInt32(await audit.ExecuteScalarAsync()) < 5)
        throw new Exception("Subscription status/upgrade/downgrade audit flow is incomplete.");
}

var companyController = new CompanyProjectSubscriptionController(config)
{
    ControllerContext = Context(("user_type", "COMPANY_USER"), ("company_id", $"{company}"))
};
if (await companyController.Get(default) is not ContentResult { StatusCode: 200 })
    throw new Exception("Company cannot read its subscriptions.");

if (!CompanyMenuAccess.Sql.Contains("TDADCompanyProjectSubscription", StringComparison.Ordinal)
    || !CompanyMenuAccess.Sql.Contains("N'EXPIRED'", StringComparison.Ordinal)
    || !CompanyMenuAccess.Sql.Contains("N'DOWNLOAD'", StringComparison.Ordinal))
    throw new Exception("Shared authorization contract lost package or expired read-only guards.");

const string supportSql = """
SELECT TOP(1) U.LaooUserID,P.ProjectID
FROM dbo.TDADLaooUser U
JOIN dbo.TDADLaooUserPermission UP ON UP.LaooUserID=U.LaooUserID AND UP.IsAllowed=1 AND UP.IsActive=1
JOIN dbo.TDADPermission PERM ON PERM.PermissionID=UP.PermissionID AND PERM.ProjectID=UP.ProjectID
JOIN dbo.TDADProject P ON P.ProjectID=UP.ProjectID AND P.ProjectCode=N'LAOO' AND P.IsActive=1
WHERE U.IsActive=1 AND U.IsSupportUser=1 AND PERM.ScreenCode=N'*' AND PERM.ActionCode=N'ADMIN';
""";
await using (var supportCommand = new SqlCommand(supportSql, connection))
await using (var supportReader = await supportCommand.ExecuteReaderAsync())
{
    if (!await supportReader.ReadAsync()) throw new Exception("No LAOO Support admin fixture.");
    var supportUser = supportReader.GetInt64(0);
    var supportProject = supportReader.GetInt64(1);
    await supportReader.CloseAsync();
    var support = new SupportProjectPackageController(config)
    {
        ControllerContext = Context(("user_type", "LAOO_SUPPORT"),
            ("laoo_user_id", $"{supportUser}"), ("project_id", $"{supportProject}"))
    };
    var list = await support.Get(null, default) as ContentResult
        ?? throw new Exception("Support package list failed.");
    using var document = JsonDocument.Parse(list.Content ?? "[]");
    var package = document.RootElement.EnumerateArray()
        .FirstOrDefault(x => x.TryGetProperty("packageId", out var id) && id.ValueKind == JsonValueKind.Number);
    if (package.ValueKind == JsonValueKind.Undefined) throw new Exception("No Package Master fixture.");
    var packageId = package.GetProperty("packageId").GetInt64();
    var projectId = package.GetProperty("projectId").GetInt64();
    if (await support.GetDetail(packageId, default) is not ContentResult { StatusCode: 200 })
        throw new Exception("Support package detail failed.");
    if (await support.GetOptions(projectId, default) is not ContentResult { StatusCode: 200 })
        throw new Exception("Support package feature options failed.");
}

Console.WriteLine("PASS: Package schema, backfill, Partner scope, Company summary and shared guard contracts.");

static ControllerContext Context(params (string Name, string Value)[] claims) => new()
{
    HttpContext = new DefaultHttpContext
    {
        User = new ClaimsPrincipal(new ClaimsIdentity(
            claims.Select(x => new Claim(x.Name, x.Value)), "Test"))
    }
};

static async Task<int> AuditCount(SqlConnection connection, long company, long project)
{
    await using var command = new SqlCommand(
        "SELECT COUNT(1) FROM dbo.TDADCompanyProjectSubscriptionAudit WHERE CompanyID=@Company AND ProjectID=@Project", connection);
    command.Parameters.AddWithValue("@Company", company);
    command.Parameters.AddWithValue("@Project", project);
    return Convert.ToInt32(await command.ExecuteScalarAsync());
}

static async Task ExpectSaved(PartnerProjectSubscriptionController controller, long company,
    long project, long package, string status, DateOnly start, DateOnly? expire, string reason)
{
    var result = await controller.Save(company, project,
        new(package, status, start, expire, reason), default);
    if (result is not OkObjectResult)
        throw new Exception($"Subscription flow failed at {status}: {result.GetType().Name}");
}
