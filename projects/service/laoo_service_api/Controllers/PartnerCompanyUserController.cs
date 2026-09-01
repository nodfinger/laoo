using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts.CompanyUsers;
using LaooServiceApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceApi.Controllers;

[ApiController]
[Route("api/partner/company-users")]
[Authorize]
public sealed class PartnerCompanyUserController(
    IConfiguration configuration,
    PasswordService passwordService) : ControllerBase
{
    private static CompanyUserScreenContract Screen => CompanyUserScreenContracts.Partner;

    [HttpGet("actions")]
    public async Task<ActionResult<object>> Actions(CancellationToken token)
    {
        if (!InPartnerScope()) return Forbid();
        await using var connection = await Open(token);
        return Ok(new
        {
            view = await Can(connection, "VIEW", token),
            create = false,
            edit = await Can(connection, "EDIT", token),
            delete = false,
        });
    }

    [HttpGet]
    public async Task<ActionResult<List<CompanyUserResponse>>> List(
        [FromQuery] string? search,
        [FromQuery] long? companyId,
        [FromQuery] bool? isActive,
        CancellationToken token)
    {
        if (!InPartnerScope()) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();
        return Ok(await QueryUsers(connection, search, companyId, isActive, token));
    }

    private async Task<List<CompanyUserResponse>> QueryUsers(
        SqlConnection connection,
        string? search,
        long? companyId,
        bool? isActive,
        CancellationToken token)
    {
        var sql = new System.Text.StringBuilder();
        sql.Append("SELECT U.UserID,U.CompanyID,C.CompanyCode,C.CustomerNameTH,");
        sql.Append("U.Username,U.DisplayName,U.Email,U.Mobile,U.IsCompanyAdmin,U.IsActive ");
        sql.Append("FROM dbo.TDADUser U INNER JOIN dbo.TDSTCompanySetUp C ");
        sql.Append("ON C.CompanyID=U.CompanyID AND C.PartnerID=@PartnerID ");
        sql.Append("WHERE (@CompanyID IS NULL OR U.CompanyID=@CompanyID) ");
        sql.Append("AND (@IsActive IS NULL OR U.IsActive=@IsActive) ");
        sql.Append("AND (@Search IS NULL OR U.Username LIKE N'%' + @Search + N'%' ");
        sql.Append("OR U.DisplayName LIKE N'%' + @Search + N'%' ");
        sql.Append("OR C.CompanyCode LIKE N'%' + @Search + N'%' ");
        sql.Append("OR C.CustomerNameTH LIKE N'%' + @Search + N'%') ");
        sql.Append("ORDER BY C.CompanyCode,U.IsCompanyAdmin DESC,U.Username;");
        await using var command = new SqlCommand(sql.ToString(), connection);
        Add(command, "@PartnerID", SqlDbType.BigInt, PartnerId());
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@IsActive", SqlDbType.Bit, isActive);
        Add(command, "@Search", SqlDbType.NVarChar, Clean(search), 200);
        return await ReadUsers(command, token);
    }

    private static async Task<List<CompanyUserResponse>> ReadUsers(
        SqlCommand command,
        CancellationToken token)
    {
        await using var reader = await command.ExecuteReaderAsync(token);
        var result = new List<CompanyUserResponse>();
        while (await reader.ReadAsync(token))
        {
            result.Add(new CompanyUserResponse
            {
                UserId = reader.GetInt64(0),
                CompanyId = reader.GetInt64(1),
                CompanyCode = reader.GetString(2),
                CompanyName = reader.GetString(3),
                Username = reader.GetString(4),
                DisplayName = reader.GetString(5),
                Email = Text(reader, 6),
                Mobile = Text(reader, 7),
                IsCompanyAdmin = reader.GetBoolean(8),
                IsActive = reader.GetBoolean(9),
            });
        }
        return result;
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(
        long id,
        CompanyUserUpdateRequest request,
        CancellationToken token)
    {
        if (!InPartnerScope()) return Forbid();
        var username = request.Username.Trim();
        var displayName = request.DisplayName.Trim();
        if (username.Length == 0 || displayName.Length == 0)
            return BadRequest(new { message = "กรุณาระบุ Username และชื่อผู้ใช้งาน" });
        if (username.Length > 100 || displayName.Length > 200)
            return BadRequest(new { message = "Username หรือชื่อผู้ใช้งานยาวเกินกำหนด" });

        await using var connection = await Open(token);
        if (!await Can(connection, "EDIT", token)) return Forbid();
        const string ownerSql =
            "SELECT U.CompanyID FROM dbo.TDADUser U " +
            "INNER JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID " +
            "AND C.PartnerID=@PartnerID WHERE U.UserID=@ID;";
        await using var owner = new SqlCommand(ownerSql, connection);
        Add(owner, "@PartnerID", SqlDbType.BigInt, PartnerId());
        Add(owner, "@ID", SqlDbType.BigInt, id);
        var companyValue = await owner.ExecuteScalarAsync(token);
        if (companyValue is null || companyValue == DBNull.Value) return NotFound();
        var companyId = Convert.ToInt64(companyValue);

        if (!string.IsNullOrWhiteSpace(request.Password))
        {
            var policy = await passwordService.GetPolicyAsync(
                connection, "C", PartnerId(), companyId, token);
            if (!PasswordService.MeetsPolicy(username, request.Password, policy))
                return BadRequest(new
                {
                    message = PasswordService.GetReadablePolicyMessage(policy),
                });
        }
        return await ExecuteUpdate(connection, id, username, displayName, request, token);
    }

    private async Task<IActionResult> ExecuteUpdate(
        SqlConnection connection,
        long id,
        string username,
        string displayName,
        CompanyUserUpdateRequest request,
        CancellationToken token)
    {
        var sql = new System.Text.StringBuilder();
        sql.Append("IF EXISTS (SELECT 1 FROM dbo.TDADUser WHERE UserID=@ID AND ISNULL(NormalizedUsername,N'')<>@NormalizedUsername) AND (");
        sql.Append("EXISTS (SELECT 1 FROM dbo.TDADLaooUser WHERE NormalizedUsername=@NormalizedUsername) ");
        sql.Append("OR EXISTS (SELECT 1 FROM dbo.TDADPartnerUser WHERE NormalizedUsername=@NormalizedUsername) ");
        sql.Append("OR EXISTS (SELECT 1 FROM dbo.TDADUser WHERE NormalizedUsername=@NormalizedUsername AND UserID<>@ID)) ");
        sql.Append("THROW 50008, 'USERNAME_EXISTS', 1; ");
        sql.Append("UPDATE U SET Username=@Username,NormalizedUsername=@NormalizedUsername,");
        sql.Append("DisplayName=@DisplayName,Email=@Email,Mobile=@Mobile,IsActive=@IsActive,");
        sql.Append("UpdateDate=SYSUTCDATETIME(),UpdateBy=@UpdateBy ");
        if (!string.IsNullOrWhiteSpace(request.Password))
            sql.Append(",PasswordHash=@PasswordHash,LastPasswordChangeDate=SYSUTCDATETIME() ");
        sql.Append("FROM dbo.TDADUser U INNER JOIN dbo.TDSTCompanySetUp C ");
        sql.Append("ON C.CompanyID=U.CompanyID AND C.PartnerID=@PartnerID WHERE U.UserID=@ID;");

        await using var command = new SqlCommand(sql.ToString(), connection);
        Add(command, "@ID", SqlDbType.BigInt, id);
        Add(command, "@PartnerID", SqlDbType.BigInt, PartnerId());
        Add(command, "@Username", SqlDbType.NVarChar, username, 100);
        Add(command, "@NormalizedUsername", SqlDbType.NVarChar, username.ToUpperInvariant(), 100);
        Add(command, "@DisplayName", SqlDbType.NVarChar, displayName, 200);
        Add(command, "@Email", SqlDbType.NVarChar, Clean(request.Email), 320);
        Add(command, "@Mobile", SqlDbType.NVarChar, Clean(request.Mobile), 50);
        Add(command, "@IsActive", SqlDbType.Bit, request.IsActive);
        Add(command, "@UpdateBy", SqlDbType.BigInt, PartnerUserId());
        if (!string.IsNullOrWhiteSpace(request.Password))
            Add(command, "@PasswordHash", SqlDbType.NVarChar,
                passwordService.HashPassword(username, request.Password), 500);
        try
        {
            return await command.ExecuteNonQueryAsync(token) == 0
                ? NotFound()
                : NoContent();
        }
        catch (SqlException exception) when (exception.Number is 50008 or 2601 or 2627)
        {
            return Conflict(new { message = "Username นี้มีผู้ใช้งานแล้ว" });
        }
    }

    private bool InPartnerScope() =>
        string.Equals(
            User.FindFirstValue("user_type"),
            Screen.RequiredUserType,
            StringComparison.OrdinalIgnoreCase) &&
        PartnerId().HasValue &&
        PartnerUserId().HasValue;

    private long? PartnerId() =>
        long.TryParse(User.FindFirstValue("partner_id"), out var id) ? id : null;

    private long? PartnerUserId() =>
        long.TryParse(User.FindFirstValue("partner_user_id"), out var id) ? id : null;

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(
            configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private static string? Clean(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static string? Text(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);

    private static void Add(
        SqlCommand command,
        string name,
        SqlDbType type,
        object? value,
        int size = 0)
    {
        var parameter = size > 0
            ? command.Parameters.Add(name, type, size)
            : command.Parameters.Add(name, type);
        parameter.Value = value ?? DBNull.Value;
    }

    private async Task<bool> Can(
        SqlConnection connection,
        string action,
        CancellationToken token)
    {
        if (!long.TryParse(User.FindFirstValue("project_id"), out var projectId))
            return false;
        await using var command = new SqlCommand(PermissionSql(), connection);
        Add(command, "@UserID", SqlDbType.BigInt, PartnerUserId());
        Add(command, "@PartnerID", SqlDbType.BigInt, PartnerId());
        Add(command, "@ProjectID", SqlDbType.BigInt, projectId);
        Add(command, "@ScreenCode", SqlDbType.NVarChar, Screen.MenuCode, 100);
        Add(command, "@Action", SqlDbType.NVarChar, action, 50);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private static string PermissionSql()
    {
        var sql = new System.Text.StringBuilder();
        sql.Append("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADPartnerUser ");
        sql.Append("WHERE PartnerUserID=@UserID AND PartnerID=@PartnerID ");
        sql.Append("AND IsPartnerAdmin=1 AND IsActive=1) OR EXISTS(");
        sql.Append("SELECT 1 FROM dbo.TDADPartnerUserPermission UP ");
        sql.Append("INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID ");
        sql.Append("AND P.ProjectID=UP.ProjectID INNER JOIN dbo.TDADPartnerUser U ");
        sql.Append("ON U.PartnerUserID=UP.PartnerUserID ");
        sql.Append("WHERE U.PartnerUserID=@UserID AND U.PartnerID=@PartnerID AND U.IsActive=1 ");
        sql.Append("AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 ");
        sql.Append("AND P.IsActive=1 AND P.ScreenCode=@ScreenCode AND P.ActionCode=@Action) ");
        sql.Append("OR EXISTS(SELECT 1 FROM dbo.TDADPartnerUser U ");
        sql.Append("INNER JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.PartnerUserID=U.PartnerUserID ");
        sql.Append("INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=PUE.EmployeeID ");
        sql.Append("INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID ");
        sql.Append("AND RG.ScopeType='P' AND RG.PartnerID=U.PartnerID AND RG.ProjectID=@ProjectID ");
        sql.Append("INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID ");
        sql.Append("AND RP.ProjectID=@ProjectID AND RP.MenuCode=@ScreenCode ");
        sql.Append("AND RP.ActionCode=@Action AND RP.IsAllowed=1 ");
        sql.Append("WHERE U.PartnerUserID=@UserID AND U.PartnerID=@PartnerID AND U.IsActive=1 ");
        sql.Append("AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) ");
        sql.Append("AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) ");
        sql.Append("THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END;");
        return sql.ToString();
    }
}
