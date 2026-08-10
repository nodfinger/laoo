using System.Data;
using System.Security.Claims;
using LaooApi.Models.Partner;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/partner/companies")]
[Authorize]
public sealed class PartnerCompanyController : ControllerBase
{
    private readonly IConfiguration _configuration;

    public PartnerCompanyController(IConfiguration configuration) => _configuration = configuration;

    [HttpGet]
    public async Task<ActionResult<List<PartnerCompanyResponse>>> GetAll(
        [FromQuery] string? search, [FromQuery] bool? isActive, CancellationToken cancellationToken)
    {
        var partnerId = PartnerId();
        if (partnerId is null) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        const string sql = """
SELECT CompanyID, PartnerID, CompanyCode, CompanyNameTH, CompanyNameEN, TaxID,
       Email, Telephone, AddressText, IsActive, CreateDate, CreateBy,
       UpdateDate, UpdateBy, ThemeName
FROM dbo.TDADCompany
WHERE PartnerID = @PartnerID
  AND (@Search IS NULL OR CompanyCode LIKE N'%' + @Search + N'%' OR CompanyNameTH LIKE N'%' + @Search + N'%')
  AND (@IsActive IS NULL OR IsActive = @IsActive)
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

    [HttpPost]
    public async Task<ActionResult<PartnerCompanyResponse>> Create(
        PartnerCompanyUpsertRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.CompanyNameTh))
            return BadRequest(new { message = "กรุณาระบุชื่อ Customer/Company" });
        var partnerId = PartnerId();
        if (partnerId is null || !string.Equals(User.FindFirstValue("user_type"), "PARTNER_USER", StringComparison.OrdinalIgnoreCase))
            return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        if (!await IsPartnerAdminAsync(connection, cancellationToken)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        try
        {
            const string codeSql = """
SELECT N'C' + RIGHT(N'000000' + CAST(ISNULL(MAX(TRY_CONVERT(INT, SUBSTRING(CompanyCode, 2, 20))), 0) + 1 AS NVARCHAR(20)), 6)
FROM dbo.TDADCompany WITH (UPDLOCK, HOLDLOCK) WHERE PartnerID = @PartnerID AND CompanyCode LIKE N'C%';
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
            await transaction.CommitAsync(cancellationToken);
            return Created($"/api/partner/companies/{companyId}", new PartnerCompanyResponse { CompanyId = companyId, PartnerId = partnerId.Value, CompanyCode = code, CompanyNameTh = request.CompanyNameTh.Trim(), CompanyNameEn = Null(request.CompanyNameEn), TaxId = Null(request.TaxId), Email = Null(request.Email), Telephone = Null(request.Telephone), AddressText = Null(request.AddressText), IsActive = true, CreateDate = DateTime.UtcNow, ThemeName = Null(request.ThemeName) });
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
        if (!await IsPartnerAdminAsync(connection, cancellationToken)) return Forbid();
        const string sql = """
UPDATE dbo.TDADCompany SET CompanyNameTH=@CompanyNameTH, CompanyNameEN=@CompanyNameEN, TaxID=@TaxID,
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
        Add(command, "@ThemeName", SqlDbType.NVarChar, Null(request.ThemeName), 100);
        return await command.ExecuteNonQueryAsync(cancellationToken) == 0 ? NotFound() : NoContent();
    }

    [HttpDelete("{companyId:long}")]
    public async Task<IActionResult> Delete(long companyId, CancellationToken cancellationToken)
    {
        var partnerId = PartnerId();
        if (partnerId is null) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
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
        await using var command = new SqlCommand("SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADPartnerUser WHERE PartnerID = @PartnerID AND IsPartnerAdmin = 1 AND IsActive = 1) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END", connection);
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
        return Convert.ToBoolean(await command.ExecuteScalarAsync(cancellationToken));
    }

    private long? PartnerId() => long.TryParse(User.FindFirstValue("partner_id"), out var id) ? id : null;
    private async Task<SqlConnection> OpenConnectionAsync(CancellationToken token) { var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private static string? Null(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static void Add(SqlCommand c, string name, SqlDbType type, string? value, int size) => c.Parameters.Add(name, type, size).Value = (object?)value ?? DBNull.Value;
    private static PartnerCompanyResponse Read(SqlDataReader r) => new() { CompanyId = r.GetInt64(0), PartnerId = r.GetInt64(1), CompanyCode = r.GetString(2), CompanyNameTh = r.GetString(3), CompanyNameEn = N(r, 4), TaxId = N(r, 5), Email = N(r, 6), Telephone = N(r, 7), AddressText = N(r, 8), IsActive = r.GetBoolean(9), CreateDate = r.GetDateTime(10), CreateBy = L(r, 11), UpdateDate = D(r, 12), UpdateBy = L(r, 13), ThemeName = N(r, 14) };
    private static string? N(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static long? L(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static DateTime? D(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetDateTime(i);
}
