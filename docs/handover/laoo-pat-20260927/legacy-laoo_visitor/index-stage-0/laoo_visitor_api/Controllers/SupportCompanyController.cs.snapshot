using System.Data;
using System.Security.Claims;
using LaooMeetingApi.Models.Partner;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController]
[Route("api/support/companies")]
[Authorize]
public sealed class SupportCompanyController : ControllerBase
{
    private const string ScreenCode = "06001";
    private readonly IConfiguration _configuration;
    public SupportCompanyController(IConfiguration configuration) => _configuration = configuration;

    [HttpGet]
    public async Task<ActionResult<List<PartnerCompanyResponse>>> GetAll(
        [FromQuery] string? search, [FromQuery] long? partnerId,
        [FromQuery] bool? isActive, CancellationToken cancellationToken)
    {
        if (!IsSupport()) return Forbid();

        await using var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken);
        if (!await AllowedAsync(connection, "VIEW", cancellationToken)) return Forbid();
        const string sql = """
SELECT C.CompanyID, C.PartnerID, C.CompanyCode, C.CustomerNameTH, C.CustomerNameEN, C.TaxID,
       C.EmailAdmin, C.Telephone, C.AddressText, C.IsActive, C.CreateDate, C.CreateBy, C.UpdateDate,
       C.UpdateBy, CAST(NULL AS nvarchar(100)), P.PartnerNameTH
FROM dbo.TDSTCompanySetUp AS C
INNER JOIN dbo.TDADPartner AS P ON P.PartnerID = C.PartnerID
WHERE (@PartnerID IS NULL OR C.PartnerID = @PartnerID)
  AND C.CompanyID IS NOT NULL
  AND C.CompanyCode IS NOT NULL
  AND C.CustomerNameTH IS NOT NULL
  AND (@Search IS NULL OR C.CompanyCode LIKE N'%' + @Search + N'%' OR C.CustomerNameTH LIKE N'%' + @Search + N'%' OR ISNULL(C.CustomerNameEN,N'') LIKE N'%' + @Search + N'%')
  AND (@IsActive IS NULL OR C.IsActive = @IsActive)
ORDER BY C.CompanyCode;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId ?? (object)DBNull.Value;
        command.Parameters.Add("@Search", SqlDbType.NVarChar, 200).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        command.Parameters.Add("@IsActive", SqlDbType.Bit).Value = isActive ?? (object)DBNull.Value;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<PartnerCompanyResponse>();
        while (await reader.ReadAsync(cancellationToken)) result.Add(Read(reader));
        return Ok(result);
    }

    [HttpGet("actions")]
    public async Task<ActionResult<object>> Actions(CancellationToken cancellationToken)
    {
        if (!IsSupport()) return Forbid();
        await using var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken);
        return Ok(new
        {
            view = await AllowedAsync(connection, "VIEW", cancellationToken),
            create = await AllowedAsync(connection, "CREATE", cancellationToken),
            edit = await AllowedAsync(connection, "EDIT", cancellationToken),
            delete = await AllowedAsync(connection, "DELETE", cancellationToken),
        });
    }

    [HttpPut("{companyId:long}")]
    public async Task<IActionResult> Update(long companyId, PartnerCompanyUpsertRequest request, CancellationToken cancellationToken)
    {
        if (!IsSupport()) return Forbid();
        if (string.IsNullOrWhiteSpace(request.CompanyNameTh))
            return BadRequest(new { message = "กรุณาระบุชื่อผู้ใช้บริการ" });

        await using var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken);
        if (!await AllowedAsync(connection, "EDIT", cancellationToken)) return Forbid();
        const string sql = """
UPDATE dbo.TDSTCompanySetUp SET CustomerNameTH=@CustomerNameTH, CustomerNameEN=@CustomerNameEN, TaxID=@TaxID, IsActive=@IsActive,
EmailAdmin=@Email, Telephone=@Telephone, AddressText=@AddressText,
UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@CompanyID;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        Add(command, "@CustomerNameTH", SqlDbType.NVarChar, request.CompanyNameTh.Trim(), 200);
        Add(command, "@CustomerNameEN", SqlDbType.NVarChar, Null(request.CompanyNameEn), 200);
        Add(command, "@TaxID", SqlDbType.NVarChar, Null(request.TaxId), 20);
        Add(command, "@Email", SqlDbType.NVarChar, Null(request.Email), 320);
        Add(command, "@Telephone", SqlDbType.NVarChar, Null(request.Telephone), 50);
        Add(command, "@AddressText", SqlDbType.NVarChar, Null(request.AddressText), 1000);
        command.Parameters.Add("@IsActive", SqlDbType.Bit).Value = request.IsActive;
        return await command.ExecuteNonQueryAsync(cancellationToken) == 0 ? NotFound() : NoContent();
    }

    [HttpDelete("{companyId:long}")]
    public async Task<IActionResult> Delete(long companyId, CancellationToken cancellationToken)
    {
        if (!IsSupport()) return Forbid();
        await using var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken);
        if (!await AllowedAsync(connection, "DELETE", cancellationToken)) return Forbid();
        const string dependencySql = "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADBranch WHERE CompanyID=@CompanyID) OR EXISTS (SELECT 1 FROM dbo.TDADUser WHERE CompanyID=@CompanyID) THEN CAST(1 AS BIGINT) ELSE CAST(0 AS BIGINT) END;";
        await using var dependency = new SqlCommand(dependencySql, connection);
        dependency.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        if (Convert.ToInt64(await dependency.ExecuteScalarAsync(cancellationToken)) > 0)
            return Conflict(new { code = "COMPANY_IN_USE", message = "ไม่สามารถลบผู้ใช้บริการที่มีสาขาหรือผู้ใช้งานอยู่ได้" });
        await using var command = new SqlCommand("DELETE FROM dbo.TDSTCompanySetUp WHERE CompanyID=@CompanyID", connection);
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        return await command.ExecuteNonQueryAsync(cancellationToken) == 0 ? NotFound() : NoContent();
    }

    private bool IsSupport() => string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase);

    private async Task<bool> AllowedAsync(SqlConnection connection, string action, CancellationToken token)
    {
        if (!long.TryParse(User.FindFirstValue("laoo_user_id"), out var userId) ||
            !long.TryParse(User.FindFirstValue("project_id"), out var projectId))
            return false;

        const string sql = """
SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM dbo.TDADLaooUserPermission AS UP
    INNER JOIN dbo.TDADPermission AS P
        ON P.PermissionID = UP.PermissionID
       AND P.ProjectID = UP.ProjectID
    INNER JOIN dbo.TDADLaooUser AS U
        ON U.LaooUserID = UP.LaooUserID
       AND U.IsActive = 1
    WHERE UP.LaooUserID = @UserID
      AND UP.ProjectID = @ProjectID
      AND UP.IsAllowed = 1
      AND UP.IsActive = 1
      AND P.IsActive = 1
      AND P.ScreenCode IN (@ScreenCode, @LegacyScreenCode)
      AND P.ActionCode = @Action
) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@UserID", SqlDbType.BigInt).Value = userId;
        command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
        command.Parameters.Add("@ScreenCode", SqlDbType.NVarChar, 20).Value = ScreenCode;
        command.Parameters.Add("@LegacyScreenCode", SqlDbType.NVarChar, 100).Value = "COMPANY";
        command.Parameters.Add("@Action", SqlDbType.NVarChar, 50).Value = action;
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private static string? Null(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static void Add(SqlCommand c, string name, SqlDbType type, string? value, int size) => c.Parameters.Add(name, type, size).Value = (object?)value ?? DBNull.Value;

    private static PartnerCompanyResponse Read(SqlDataReader r) => new()
    {
        CompanyId = r.GetInt64(0),
        PartnerId = r.GetInt64(1),
        CompanyCode = r.GetString(2),
        CompanyNameTh = r.GetString(3),
        CompanyNameEn = N(r, 4),
        TaxId = N(r, 5),
        Email = N(r, 6),
        Telephone = N(r, 7),
        AddressText = N(r, 8),
        IsActive = r.GetBoolean(9),
        CreateDate = r.GetDateTime(10),
        CreateBy = L(r, 11),
        UpdateDate = D(r, 12),
        UpdateBy = L(r, 13),
        ThemeName = N(r, 14),
        PartnerNameTh = r.GetString(15)
    };
    private static string? N(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static long? L(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static DateTime? D(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetDateTime(i);
}
