using System.Data;
using System.Security.Claims;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/current-user/host-identities")]
public sealed class CurrentUserHostIdentityController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        var companyId = ClaimLong("company_id");
        var partnerId = ClaimLong("partner_id");
        var userId = ClaimLong("user_id");
        if (!string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase)
            || companyId <= 0 || partnerId <= 0 || userId <= 0) return Ok(EmptyResult());
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        if (!await HasActiveCompanyScope(connection, companyId, partnerId, userId, token)) return Forbid();
        if (!await CompanyProjectPermission.IsAllowedAsync(connection, User, "32003", "VIEW", token))
            return Ok(EmptyResult());
        const string sql = """
WITH IdentityPersons AS
(
    SELECT U.PersonID FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.PersonID IS NOT NULL
    UNION
    SELECT E.PersonID FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1 WHERE UE.UserID=@user AND UE.CompanyID=@company AND UE.IsActive=1 AND E.PersonID IS NOT NULL
)
SELECT N'EMPLOYEE' IdentityType,E.EmployeeID IdentityId FROM dbo.TDADEmployee E WHERE E.CompanyID=@company AND E.IsActive=1 AND (E.PersonID IN (SELECT PersonID FROM IdentityPersons) OR EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE WHERE UE.UserID=@user AND UE.CompanyID=@company AND UE.EmployeeID=E.EmployeeID AND UE.IsActive=1))
UNION ALL SELECT N'RESIDENT',R.ResidentID FROM dbo.TDADResident R WHERE R.CompanyID=@company AND R.IsActive=1 AND R.PersonID IN (SELECT PersonID FROM IdentityPersons)
UNION ALL SELECT N'SERVICE_CUSTOMER',S.ServiceCustomerID FROM dbo.TDADServiceCustomer S WHERE S.CompanyID=@company AND S.IsActive=1 AND S.PersonID IN (SELECT PersonID FROM IdentityPersons)
UNION ALL SELECT N'TENANT_CONTACT',TC.TenantContactID FROM dbo.TDADRentalOfficeTenantContact TC WHERE TC.CompanyID=@company AND TC.IsActive=1 AND TC.PersonID IN (SELECT PersonID FROM IdentityPersons);
""";
        var employeeIds = new List<long>(); var residentIds = new List<long>(); var serviceCustomerIds = new List<long>(); var tenantContactIds = new List<long>();
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@user", SqlDbType.BigInt).Value = userId;
        await using var reader = await command.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
        {
            var id = reader.GetInt64(1);
            switch (reader.GetString(0)) { case "EMPLOYEE": employeeIds.Add(id); break; case "RESIDENT": residentIds.Add(id); break; case "SERVICE_CUSTOMER": serviceCustomerIds.Add(id); break; case "TENANT_CONTACT": tenantContactIds.Add(id); break; }
        }
        return Ok(new { employeeIds, residentIds, serviceCustomerIds, tenantContactIds });
    }
    private async Task<bool> HasActiveCompanyScope(SqlConnection connection,long companyId,long partnerId,long userId,CancellationToken token)
    {
        const string sql = "SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser U JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.PartnerID=@partner AND C.IsActive=1 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1) THEN 1 ELSE 0 END AS bit);";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@company", SqlDbType.BigInt).Value=companyId; command.Parameters.Add("@partner", SqlDbType.BigInt).Value=partnerId; command.Parameters.Add("@user", SqlDbType.BigInt).Value=userId;
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }
    private long ClaimLong(string name) => long.TryParse(User.FindFirstValue(name),out var value) ? value : 0;
    private static object EmptyResult() => new { employeeIds=Array.Empty<long>(),residentIds=Array.Empty<long>(),serviceCustomerIds=Array.Empty<long>(),tenantContactIds=Array.Empty<long>() };
}
