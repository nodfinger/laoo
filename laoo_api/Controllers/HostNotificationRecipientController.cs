using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts.Notifications;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/host-notification-recipient")]
public sealed class HostNotificationRecipientController(IConfiguration configuration) : ControllerBase
{
    private const string ActiveScopeSql = """
        SELECT COUNT(*) FROM dbo.TDADUser U
        JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID
        WHERE C.PartnerID=@partner AND C.IsActive=1
          AND U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1
        """;
    private const string EmployeeSql = """
        SELECT E.CompanyID,E.PersonID,
          CAST(CASE WHEN E.IsActive=1 THEN 1 ELSE 0 END AS bit),
          CAST(CASE WHEN P.IsActive=1 THEN 1 ELSE 0 END AS bit),
          CAST(NULL AS bigint),CAST(NULL AS bigint)
        FROM dbo.TDADEmployee E
        LEFT JOIN dbo.TDADPerson P ON P.CompanyID=E.CompanyID AND P.PersonID=E.PersonID
        WHERE E.EmployeeID=@id
        """;
    private const string ResidentSql = """
        SELECT R.CompanyID,R.PersonID,
          CAST(CASE WHEN R.IsActive=1 THEN 1 ELSE 0 END AS bit),
          CAST(CASE WHEN P.IsActive=1 THEN 1 ELSE 0 END AS bit),
          CAST(NULL AS bigint),CAST(NULL AS bigint)
        FROM dbo.TDADResident R
        LEFT JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID
        WHERE R.ResidentID=@id
        """;
    private const string ServiceCustomerSql = """
        SELECT S.CompanyID,S.PersonID,
          CAST(CASE WHEN S.IsActive=1 THEN 1 ELSE 0 END AS bit),
          CAST(CASE WHEN P.IsActive=1 THEN 1 ELSE 0 END AS bit),
          CAST(NULL AS bigint),CAST(NULL AS bigint)
        FROM dbo.TDADServiceCustomer S
        LEFT JOIN dbo.TDADPerson P ON P.CompanyID=S.CompanyID AND P.PersonID=S.PersonID
        WHERE S.ServiceCustomerID=@id
        """;
    private const string TenantContactSql = """
        SELECT C.CompanyID,C.PersonID,
          CAST(CASE WHEN C.IsActive=1 AND T.IsActive=1 THEN 1 ELSE 0 END AS bit),
          CAST(CASE WHEN P.IsActive=1 THEN 1 ELSE 0 END AS bit),
          CAST(NULL AS bigint),C.TenantID
        FROM dbo.TDADRentalOfficeTenantContact C
        LEFT JOIN dbo.TDADRentalOfficeTenant T
          ON T.CompanyID=C.CompanyID AND T.TenantID=C.TenantID
        LEFT JOIN dbo.TDADPerson P ON P.CompanyID=C.CompanyID AND P.PersonID=C.PersonID
        WHERE C.TenantContactID=@id
        """;
    [HttpGet]
    public async Task<IActionResult> Get(
        [FromQuery] string? hostType, [FromQuery] long? employeeId,
        [FromQuery] long? residentId, [FromQuery] long? serviceCustomerId,
        [FromQuery] long? tenantId, [FromQuery] long? contactId,
        CancellationToken token)
    {
        var type = NormalizeHostType(hostType);
        if (type is null || !HasRequiredIdentity(type, employeeId, residentId, serviceCustomerId, tenantId, contactId))
            return BadRequest(new { message = "HOST_IDENTITY_REQUIRED" });
        return await GetAuthorized(type, employeeId, residentId, serviceCustomerId, tenantId, contactId, token);
    }

    private async Task<IActionResult> GetAuthorized(string type, long? employeeId, long? residentId,
        long? serviceCustomerId, long? tenantId, long? contactId, CancellationToken token)
    {
        var companyId = ClaimLong("company_id");
        var partnerId = ClaimLong("partner_id");
        var userId = ClaimLong("user_id");
        if (!string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase)
            || companyId <= 0 || partnerId <= 0 || userId <= 0) return Forbid();
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        if (!await HasActiveCompanyScope(connection, companyId, partnerId, userId, token)
            || !await HasVisitorPermission(connection, token)) return Forbid();
        return await ResolveAuthorized(connection, type, companyId, userId, employeeId,
            residentId, serviceCustomerId, tenantId, contactId, token);
    }

    private async Task<IActionResult> ResolveAuthorized(SqlConnection connection, string type,
        long companyId, long userId, long? employeeId, long? residentId,
        long? serviceCustomerId, long? tenantId, long? contactId, CancellationToken token)
    {
        var host = await ResolveHost(connection, type, employeeId, residentId, serviceCustomerId, contactId, token);
        if (host is null) return NotFound(new { message = "HOST_NOT_FOUND" });
        if (host.CompanyId != companyId) return Forbid();
        if (!host.IsActive || !host.IsPersonActive || host.PersonId <= 0
            || (type == "RENTAL_OFFICE" && host.TenantId != tenantId))
            return NotFound(new { message = "HOST_NOT_FOUND" });
        if (!await HasBranchScope(connection, companyId, userId, host.BranchId, token)) return Forbid();
        var recipient = await ResolveRecipient(connection, companyId, host.PersonId, token);
        return Ok(new HostNotificationRecipientResponse(
            type, host.PersonId, recipient.UserId, recipient.NotifyInSystem, recipient.CanNotify));
    }

    private long ClaimLong(string name) =>
        long.TryParse(User.FindFirstValue(name), out var value) ? value : 0;

    private async Task<bool> HasVisitorPermission(SqlConnection connection, CancellationToken token) =>
        await CompanyProjectPermission.IsAllowedAsync(connection, User, "32001", "CREATE", token)
        || await CompanyProjectPermission.IsAllowedAsync(connection, User, "32002", "VIEW", token)
        || await CompanyProjectPermission.IsAllowedAsync(connection, User, "32003", "VIEW", token);

    private async Task<bool> HasActiveCompanyScope(SqlConnection connection, long companyId,
        long partnerId, long userId, CancellationToken token)
    {
        return await QueryActiveScope(connection, companyId, partnerId, userId, token);
    }

    private static async Task<bool> QueryActiveScope(SqlConnection connection, long companyId,
        long partnerId, long userId, CancellationToken token)
    {
        await using var command = new SqlCommand(ActiveScopeSql, connection);
        return await ExecuteScope(command, companyId, partnerId, userId, token);
    }

    private static async Task<bool> ExecuteScope(SqlCommand command, long companyId,
        long partnerId, long userId, CancellationToken token)
    {
        Add(command, "@company", SqlDbType.BigInt, companyId);
        Add(command, "@partner", SqlDbType.BigInt, partnerId);
        Add(command, "@user", SqlDbType.BigInt, userId);
        return Convert.ToInt32(await command.ExecuteScalarAsync(token)) == 1;
    }

    private static async Task<HostRow?> ResolveHost(SqlConnection connection, string type,
        long? employeeId, long? residentId, long? serviceCustomerId, long? contactId,
        CancellationToken token)
    {
        var id = type switch
        {
            "EMPLOYEE" => employeeId,
            "RESIDENT" or "VILLAGE" => residentId,
            "SERVICE_CUSTOMER" => serviceCustomerId,
            _ => contactId
        };
        await using var command = new SqlCommand(HostSql(type), connection);
        Add(command, "@id", SqlDbType.BigInt, id);
        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow, token);
        if (!await reader.ReadAsync(token)) return null;
        return new HostRow(reader.GetInt64(0), reader.IsDBNull(1) ? 0 : reader.GetInt64(1),
            reader.GetBoolean(2), reader.GetBoolean(3),
            reader.IsDBNull(4) ? null : reader.GetInt64(4),
            reader.IsDBNull(5) ? null : reader.GetInt64(5));
    }

    private static string HostSql(string type) => type switch
    {
        "EMPLOYEE" => EmployeeSql,
        "RESIDENT" or "VILLAGE" => ResidentSql,
        "SERVICE_CUSTOMER" => ServiceCustomerSql,
        _ => TenantContactSql
    };

    private static async Task<bool> HasBranchScope(SqlConnection connection, long companyId,
        long userId, long? branchId, CancellationToken token)
    {
        if (branchId is null) return true;
        const string sql = """
            SELECT CAST(CASE WHEN EXISTS(
              SELECT 1 FROM dbo.TDADBranch B
              JOIN dbo.TDADUser U ON U.UserID=@user AND U.CompanyID=B.CompanyID AND U.IsActive=1
              WHERE B.CompanyID=@company AND B.BranchID=@branch AND B.IsActive=1
                AND (U.IsCompanyAdmin=1 OR EXISTS(
                  SELECT 1 FROM dbo.TDADUserBranch UB
                  WHERE UB.UserID=U.UserID AND UB.CompanyID=B.CompanyID
                    AND UB.BranchID=B.BranchID AND UB.IsActive=1)))
              THEN 1 ELSE 0 END AS bit)
            """;
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@company", SqlDbType.BigInt, companyId);
        Add(command, "@user", SqlDbType.BigInt, userId);
        Add(command, "@branch", SqlDbType.BigInt, branchId);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private static async Task<RecipientRow> ResolveRecipient(SqlConnection connection,
        long companyId, long personId, CancellationToken token)
    {
        const string sql = """
            SELECT U.UserID,COALESCE(NP.NotifyInSystem,E.NotifyInSystem,CONVERT(bit,1))
            FROM dbo.TDADPerson P
            OUTER APPLY(SELECT TOP(1) X.UserID FROM dbo.TDADUser X
              WHERE X.CompanyID=P.CompanyID AND X.PersonID=P.PersonID AND X.IsActive=1
              ORDER BY X.UserID) U
            OUTER APPLY(SELECT TOP(1) X.NotifyInSystem
              FROM dbo.TDADPersonNotificationPreference X
              WHERE X.CompanyID=P.CompanyID AND X.PersonID=P.PersonID) NP
            OUTER APPLY(SELECT TOP(1) X.NotifyInSystem FROM dbo.TDADEmployee X
              WHERE X.CompanyID=P.CompanyID AND X.PersonID=P.PersonID AND X.IsActive=1
              ORDER BY X.EmployeeID) E
            WHERE P.CompanyID=@company AND P.PersonID=@person AND P.IsActive=1
            """;
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@company", SqlDbType.BigInt, companyId);
        Add(command, "@person", SqlDbType.BigInt, personId);
        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow, token);
        if (!await reader.ReadAsync(token) || reader.IsDBNull(0)) return new(null, false, false);
        var notify = reader.GetBoolean(1);
        return new(reader.GetInt64(0), notify, notify);
    }

    private static void Add(SqlCommand command, string name, SqlDbType type, object? value) =>
        command.Parameters.Add(name, type).Value = value ?? DBNull.Value;

    private static string? NormalizeHostType(string? value) => value?.Trim().ToUpperInvariant() switch
    {
        "EMPLOYEE" => "EMPLOYEE",
        "RESIDENT" => "RESIDENT",
        "VILLAGE" => "VILLAGE",
        "SERVICE_CUSTOMER" => "SERVICE_CUSTOMER",
        "RENTAL_OFFICE" => "RENTAL_OFFICE",
        _ => null
    };

    private static bool HasRequiredIdentity(string type, long? employeeId, long? residentId,
        long? serviceCustomerId, long? tenantId, long? contactId) => type switch
        {
            "EMPLOYEE" => employeeId > 0,
            "RESIDENT" or "VILLAGE" => residentId > 0,
            "SERVICE_CUSTOMER" => serviceCustomerId > 0,
            "RENTAL_OFFICE" => tenantId > 0 && contactId > 0,
            _ => false
        };

    private sealed record HostRow(long CompanyId, long PersonId, bool IsActive,
        bool IsPersonActive, long? BranchId, long? TenantId);
    private sealed record RecipientRow(long? UserId, bool NotifyInSystem, bool CanNotify);
}
