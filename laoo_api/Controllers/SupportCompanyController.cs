using System.Data;
using System.Security.Claims;
using LaooApi.Models.Partner;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/support/companies")]
[Authorize]
public sealed class SupportCompanyController : ControllerBase
{
    private readonly IConfiguration _configuration;
    public SupportCompanyController(IConfiguration configuration) => _configuration = configuration;

    [HttpGet]
    public async Task<ActionResult<List<PartnerCompanyResponse>>> GetAll(
        [FromQuery] string? search, [FromQuery] long? partnerId,
        [FromQuery] bool? isActive, CancellationToken cancellationToken)
    {
        if (!string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase))
            return Forbid();

        await using var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken);
        const string sql = """
SELECT CompanyID, PartnerID, CompanyCode, CompanyNameTH, CompanyNameEN, TaxID,
       Email, Telephone, AddressText, IsActive, CreateDate, CreateBy, UpdateDate,
       UpdateBy, ThemeName
FROM dbo.TDADCompany
WHERE (@PartnerID IS NULL OR PartnerID = @PartnerID)
  AND (@Search IS NULL OR CompanyCode LIKE N'%' + @Search + N'%' OR CompanyNameTH LIKE N'%' + @Search + N'%' OR ISNULL(CompanyNameEN,N'') LIKE N'%' + @Search + N'%')
  AND (@IsActive IS NULL OR IsActive = @IsActive)
ORDER BY CompanyCode;
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

    private static PartnerCompanyResponse Read(SqlDataReader r) => new()
    {
        CompanyId = r.GetInt64(0), PartnerId = r.GetInt64(1), CompanyCode = r.GetString(2), CompanyNameTh = r.GetString(3),
        CompanyNameEn = N(r, 4), TaxId = N(r, 5), Email = N(r, 6), Telephone = N(r, 7), AddressText = N(r, 8),
        IsActive = r.GetBoolean(9), CreateDate = r.GetDateTime(10), CreateBy = L(r, 11), UpdateDate = D(r, 12), UpdateBy = L(r, 13), ThemeName = N(r, 14)
    };
    private static string? N(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static long? L(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static DateTime? D(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetDateTime(i);
}
