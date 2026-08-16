using System.Data;
using System.Security.Claims;
using LaooApi.Models.Partner;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/partner/companies")]
[Authorize]
public sealed class PartnerCompanyController : ControllerBase
{
    private const string ScreenCode = "06001";
    private readonly IConfiguration _configuration;
    private readonly PasswordService _passwordService;

    public PartnerCompanyController(IConfiguration configuration, PasswordService passwordService)
    {
        _configuration = configuration;
        _passwordService = passwordService;
    }

    [HttpGet]
    public async Task<ActionResult<List<PartnerCompanyResponse>>> GetAll(
        [FromQuery] string? search, [FromQuery] bool? isActive, CancellationToken cancellationToken)
    {
        var partnerId = PartnerId();
        if (partnerId is null) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        if (!await AllowedAsync(connection, "VIEW", cancellationToken)) return Forbid();
        const string sql = """
SELECT C.CompanyID, C.PartnerID, C.CompanyCode, C.CompanyNameTH, C.CompanyNameEN, C.TaxID,
       C.Email, C.Telephone, C.AddressText, C.IsActive, C.CreateDate, C.CreateBy,
       C.UpdateDate, C.UpdateBy, C.ThemeName, P.PartnerNameTH,
       (SELECT TOP 1 U.Username FROM dbo.TDADUser U WHERE U.CompanyID = C.CompanyID AND U.IsCompanyAdmin = 1 AND U.IsActive = 1 ORDER BY U.UserID) AS AdminUsername
FROM dbo.TDADCompany C
INNER JOIN dbo.TDADPartner P ON P.PartnerID = C.PartnerID
WHERE C.PartnerID = @PartnerID
  AND (@Search IS NULL OR C.CompanyNameTH LIKE N'%' + @Search + N'%' OR ISNULL(C.Telephone, N'') LIKE N'%' + @Search + N'%')
  AND (@IsActive IS NULL OR C.IsActive = @IsActive)
ORDER BY CompanyCode;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
        command.Parameters.Add("@Search", SqlDbType.NVarChar, 200).Value =
            string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        command.Parameters.Add("@IsActive", SqlDbType.Bit).Value = isActive.HasValue ? isActive.Value : DBNull.Value;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<PartnerCompanyResponse>();
        while (await reader.ReadAsync(cancellationToken)) result.Add(Read(reader));
        return Ok(result);
    }

    [HttpGet("actions")]
    public async Task<ActionResult<object>> Actions(CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        return Ok(new
        {
            view = await AllowedAsync(connection, "VIEW", cancellationToken),
            create = await AllowedAsync(connection, "CREATE", cancellationToken),
            edit = await AllowedAsync(connection, "EDIT", cancellationToken),
            delete = await AllowedAsync(connection, "DELETE", cancellationToken),
        });
    }

    [HttpPost]
    public async Task<ActionResult<PartnerCompanyResponse>> Create(
        PartnerCompanyUpsertRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.CompanyNameTh))
            return BadRequest(new { message = "กรุณาระบุชื่อ Customer/Company" });
        if (string.IsNullOrWhiteSpace(request.AdminUsername) || string.IsNullOrWhiteSpace(request.AdminPassword))
            return BadRequest(new { message = "กรุณาระบุ Username และ Password ผู้ดูแลระบบ" });
        if (request.AdminUsername.Trim().Length > 100 || request.AdminPassword.Trim().Length < 1)
            return BadRequest(new { message = "Username หรือ Password ผู้ดูแลระบบไม่ถูกต้อง" });
        if (!PasswordService.MeetsPolicy(request.AdminUsername.Trim(), request.AdminPassword))
            return BadRequest(new { message = PasswordService.PolicyMessage });
        var partnerId = PartnerId();
        if (partnerId is null || !string.Equals(User.FindFirstValue("user_type"), "PARTNER_USER", StringComparison.OrdinalIgnoreCase))
            return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        if (!await AllowedAsync(connection, "CREATE", cancellationToken)) return Forbid();
        if (!await IsPartnerAdminAsync(connection, cancellationToken)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        try
        {
            const string codeSql = """
SELECT N'C' + RIGHT(N'000000' + CAST(ISNULL(MAX(TRY_CONVERT(INT, SUBSTRING(CompanyCode, 2, 20))), 0) + 1 AS NVARCHAR(20)), 6)
FROM dbo.TDADCompany WITH (UPDLOCK, HOLDLOCK) WHERE CompanyCode LIKE N'C%';
""";
            await using var codeCommand = new SqlCommand(codeSql, connection, transaction);
            codeCommand.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
            var code = Convert.ToString(await codeCommand.ExecuteScalarAsync(cancellationToken)) ?? "C000001";
            const string insertSql = """
INSERT INTO dbo.TDADCompany (PartnerID, CompanyCode, CompanyNameTH, CompanyNameEN, TaxID, Email, Telephone, AddressText, IsActive, CreateDate, CreateBy, ThemeName)
VALUES (@PartnerID, @CompanyCode, @CompanyNameTH, @CompanyNameEN, @TaxID, @Email, @Telephone, @AddressText, 1, SYSUTCDATETIME(), NULL, @ThemeName);
SELECT CAST(SCOPE_IDENTITY() AS BIGINT);
""";
            await using var insert = new SqlCommand(insertSql, connection, transaction);
            insert.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
            Add(insert, "@CompanyCode", SqlDbType.NVarChar, code, 30);
            Add(insert, "@CompanyNameTH", SqlDbType.NVarChar, request.CompanyNameTh.Trim(), 200);
            Add(insert, "@CompanyNameEN", SqlDbType.NVarChar, Null(request.CompanyNameEn), 200);
            Add(insert, "@TaxID", SqlDbType.NVarChar, Null(request.TaxId), 20);
            Add(insert, "@Email", SqlDbType.NVarChar, Null(request.Email), 320);
            Add(insert, "@Telephone", SqlDbType.NVarChar, Null(request.Telephone), 50);
            Add(insert, "@AddressText", SqlDbType.NVarChar, Null(request.AddressText), 1000);
            Add(insert, "@ThemeName", SqlDbType.NVarChar, Null(request.ThemeName), 100);
            var companyId = Convert.ToInt64(await insert.ExecuteScalarAsync(cancellationToken));
            const string userSql = """
IF EXISTS (SELECT 1 FROM dbo.TDADUser WHERE NormalizedUsername=@NormalizedUsername)
    THROW 50010, 'DUPLICATE_ADMIN_USERNAME', 1;
INSERT INTO dbo.TDADUser
    (CompanyID, Username, NormalizedUsername, PasswordHash, DisplayName, IsCompanyAdmin, IsActive, FailedLoginCount, LastPasswordChangeDate, CreateDate)
VALUES
    (@CompanyID, @Username, @NormalizedUsername, @PasswordHash, @DisplayName, 1, 1, 0, SYSUTCDATETIME(), SYSUTCDATETIME());
""";
            await using var user = new SqlCommand(userSql, connection, transaction);
            var adminUsername = request.AdminUsername.Trim();
            user.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
            Add(user, "@Username", SqlDbType.NVarChar, adminUsername, 100);
            Add(user, "@NormalizedUsername", SqlDbType.NVarChar, adminUsername.ToUpperInvariant(), 100);
            Add(user, "@PasswordHash", SqlDbType.NVarChar, _passwordService.HashPassword(adminUsername, request.AdminPassword), 500);
            Add(user, "@DisplayName", SqlDbType.NVarChar, $"{request.CompanyNameTh.Trim()} Admin", 200);
            await user.ExecuteNonQueryAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return Created($"/api/partner/companies/{companyId}", new PartnerCompanyResponse { CompanyId = companyId, PartnerId = partnerId.Value, CompanyCode = code, CompanyNameTh = request.CompanyNameTh.Trim(), CompanyNameEn = Null(request.CompanyNameEn), TaxId = Null(request.TaxId), Email = Null(request.Email), Telephone = Null(request.Telephone), AddressText = Null(request.AddressText), IsActive = true, CreateDate = DateTime.UtcNow, ThemeName = Null(request.ThemeName) });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627)
        {
            await transaction.RollbackAsync(cancellationToken);
            return Conflict(new { message = "รหัสลูกค้าซ้ำ กรุณากดบันทึกอีกครั้ง" });
        }
        catch (SqlException ex) when (ex.Number == 50010)
        {
            await transaction.RollbackAsync(cancellationToken);
            return Conflict(new { message = "Username ผู้ดูแลระบบซ้ำ กรุณาใช้ Username อื่น" });
        }
        catch { await transaction.RollbackAsync(cancellationToken); throw; }
    }

    [HttpPut("{companyId:long}")]
    public async Task<IActionResult> Update(long companyId, PartnerCompanyUpsertRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.CompanyNameTh)) return BadRequest(new { message = "กรุณาระบุชื่อผู้ใช้บริการ" });
        var partnerId = PartnerId();
        if (partnerId is null) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        if (!await AllowedAsync(connection, "EDIT", cancellationToken)) return Forbid();
        if (!await IsPartnerAdminAsync(connection, cancellationToken)) return Forbid();
        const string sql = """
UPDATE dbo.TDADCompany SET CompanyNameTH=@CompanyNameTH, CompanyNameEN=@CompanyNameEN, TaxID=@TaxID, IsActive=@IsActive,
Email=@Email, Telephone=@Telephone, AddressText=@AddressText, ThemeName=@ThemeName,
UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@CompanyID AND PartnerID=@PartnerID;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
        Add(command, "@CompanyNameTH", SqlDbType.NVarChar, request.CompanyNameTh.Trim(), 200);
        Add(command, "@CompanyNameEN", SqlDbType.NVarChar, Null(request.CompanyNameEn), 200);
        Add(command, "@TaxID", SqlDbType.NVarChar, Null(request.TaxId), 20);
        Add(command, "@Email", SqlDbType.NVarChar, Null(request.Email), 320);
        Add(command, "@Telephone", SqlDbType.NVarChar, Null(request.Telephone), 50);
        Add(command, "@AddressText", SqlDbType.NVarChar, Null(request.AddressText), 1000);
        command.Parameters.Add("@IsActive", SqlDbType.Bit).Value = request.IsActive;
        Add(command, "@ThemeName", SqlDbType.NVarChar, Null(request.ThemeName), 100);
        return await command.ExecuteNonQueryAsync(cancellationToken) == 0 ? NotFound() : NoContent();
    }

    [HttpPut("{companyId:long}/admin")]
    public async Task<IActionResult> UpdateAdmin(long companyId, PartnerCompanyAdminUpsertRequest request, CancellationToken cancellationToken)
    {
        var username = request.Username.Trim();
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(request.Password))
            return BadRequest(new { message = "กรุณาระบุ Username และ Password ผู้ดูแลระบบ" });
        if (!PasswordService.MeetsPolicy(username, request.Password))
            return BadRequest(new { message = PasswordService.PolicyMessage });
        var partnerId = PartnerId();
        if (partnerId is null) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        if (!await AllowedAsync(connection, "EDIT", cancellationToken)) return Forbid();
        if (!await IsPartnerAdminAsync(connection, cancellationToken)) return Forbid();
        const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDADCompany WHERE CompanyID=@CompanyID AND PartnerID=@PartnerID)
    THROW 50011, 'COMPANY_NOT_FOUND', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADUser WHERE NormalizedUsername=@NormalizedUsername AND CompanyID<>@CompanyID)
    THROW 50010, 'DUPLICATE_ADMIN_USERNAME', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADUser WHERE CompanyID=@CompanyID AND IsCompanyAdmin=1)
    UPDATE dbo.TDADUser SET Username=@Username, NormalizedUsername=@NormalizedUsername, PasswordHash=@PasswordHash, IsActive=1,
        LastPasswordChangeDate=SYSUTCDATETIME() WHERE CompanyID=@CompanyID AND IsCompanyAdmin=1;
ELSE
    INSERT INTO dbo.TDADUser (CompanyID, Username, NormalizedUsername, PasswordHash, DisplayName, IsCompanyAdmin, IsActive, FailedLoginCount, LastPasswordChangeDate, CreateDate)
    VALUES (@CompanyID, @Username, @NormalizedUsername, @PasswordHash, N'ผู้ดูแลระบบ', 1, 1, 0, SYSUTCDATETIME(), SYSUTCDATETIME());
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
        Add(command, "@Username", SqlDbType.NVarChar, username, 100);
        Add(command, "@NormalizedUsername", SqlDbType.NVarChar, username.ToUpperInvariant(), 100);
        Add(command, "@PasswordHash", SqlDbType.NVarChar, _passwordService.HashPassword(username, request.Password), 500);
        try { await command.ExecuteNonQueryAsync(cancellationToken); return NoContent(); }
        catch (SqlException ex) when (ex.Number == 50010) { return Conflict(new { message = "Username ผู้ดูแลระบบซ้ำ กรุณาใช้ Username อื่น" }); }
        catch (SqlException ex) when (ex.Number == 50011) { return NotFound(); }
    }

    [HttpDelete("{companyId:long}")]
    public async Task<IActionResult> Delete(long companyId, CancellationToken cancellationToken)
    {
        var partnerId = PartnerId();
        if (partnerId is null) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        if (!await AllowedAsync(connection, "DELETE", cancellationToken)) return Forbid();
        if (!await IsPartnerAdminAsync(connection, cancellationToken)) return Forbid();
        const string dependencySql = "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADBranch WHERE CompanyID=@CompanyID) OR EXISTS (SELECT 1 FROM dbo.TDADUser WHERE CompanyID=@CompanyID) THEN CAST(1 AS BIGINT) ELSE CAST(0 AS BIGINT) END;";
        await using var dependency = new SqlCommand(dependencySql, connection);
        dependency.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        if (Convert.ToInt64(await dependency.ExecuteScalarAsync(cancellationToken)) > 0)
            return Conflict(new { code = "COMPANY_IN_USE", message = "ไม่สามารถลบผู้ใช้บริการที่มีสาขาหรือผู้ใช้งานอยู่ได้" });
        await using var command = new SqlCommand("DELETE FROM dbo.TDADCompany WHERE CompanyID=@CompanyID AND PartnerID=@PartnerID", connection);
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
        return await command.ExecuteNonQueryAsync(cancellationToken) == 0 ? NotFound() : NoContent();
    }

    private async Task<bool> IsPartnerAdminAsync(SqlConnection connection, CancellationToken cancellationToken)
    {
        var partnerId = PartnerId();
        if (partnerId is null) return false;
        await using var command = new SqlCommand("SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADPartnerUser WHERE PartnerID=@PartnerID AND NormalizedUsername=@Username AND IsPartnerAdmin=1 AND IsActive=1) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END", connection);
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
        command.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = (User.Identity?.Name ?? User.FindFirstValue("unique_name") ?? string.Empty).Trim().ToUpperInvariant();
        return Convert.ToBoolean(await command.ExecuteScalarAsync(cancellationToken));
    }

    private long? PartnerId() => long.TryParse(User.FindFirstValue("partner_id"), out var id) ? id : null;
    private async Task<bool> AllowedAsync(SqlConnection connection, string action, CancellationToken token)
    {
        var partnerId = PartnerId();
        var project = User.FindFirstValue("project_id");
        if (partnerId is null || !long.TryParse(project, out var projectId)) return false;
        const string sql = "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADPartnerUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID INNER JOIN dbo.TDADPartnerUser U ON U.PartnerUserID=UP.PartnerUserID WHERE U.PartnerID=@PartnerID AND U.NormalizedUsername=@Username AND U.IsActive=1 AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@ScreenCode AND P.ActionCode=@Action) OR EXISTS (SELECT 1 FROM dbo.TDADPartnerUser U INNER JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.PartnerUserID=U.PartnerUserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=PUE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='P' AND RG.PartnerID=U.PartnerID AND RG.ProjectID=@ProjectID INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@ProjectID AND RP.MenuCode=@ScreenCode AND RP.ActionCode=@Action AND RP.IsAllowed=1 WHERE U.PartnerID=@PartnerID AND U.NormalizedUsername=@Username AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
        command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
        command.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = (User.Identity?.Name ?? User.FindFirstValue("unique_name") ?? string.Empty).Trim().ToUpperInvariant();
        command.Parameters.Add("@ScreenCode", SqlDbType.NVarChar, 100).Value = ScreenCode;
        command.Parameters.Add("@Action", SqlDbType.NVarChar, 50).Value = action;
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }
    private async Task<SqlConnection> OpenConnectionAsync(CancellationToken token) { var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private static string? Null(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static void Add(SqlCommand c, string name, SqlDbType type, string? value, int size) => c.Parameters.Add(name, type, size).Value = (object?)value ?? DBNull.Value;
    private static PartnerCompanyResponse Read(SqlDataReader r) => new() { CompanyId = r.GetInt64(0), PartnerId = r.GetInt64(1), CompanyCode = r.GetString(2), CompanyNameTh = r.GetString(3), CompanyNameEn = N(r, 4), TaxId = N(r, 5), Email = N(r, 6), Telephone = N(r, 7), AddressText = N(r, 8), IsActive = r.GetBoolean(9), CreateDate = r.GetDateTime(10), CreateBy = L(r, 11), UpdateDate = D(r, 12), UpdateBy = L(r, 13), ThemeName = N(r, 14), PartnerNameTh = N(r, 15), AdminUsername = N(r, 16) };
    private static string? N(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static long? L(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static DateTime? D(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetDateTime(i);
}
