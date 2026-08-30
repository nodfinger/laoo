using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/partner/company-features")]
[Authorize]
public sealed class PartnerFeatureController : ControllerBase
{
    private readonly IConfiguration _configuration;

    public PartnerFeatureController(IConfiguration configuration) => _configuration = configuration;

    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] long? companyId, CancellationToken token)
    {
        if (!IsPartnerUser()) return Forbid();
        var partnerId = PartnerId();
        if (partnerId is null) return Forbid();
        await using var connection = await OpenConnectionAsync(token);
        if (!await IsPartnerAdminAsync(connection, partnerId.Value, token)) return Forbid();

        const string sql = """
SELECT F.FeatureCode, F.FeatureName, F.FeatureDescription,
       C.CompanyFeatureID, C.CompanyID, C.IsEnabled, C.IsTrial,
       C.StartDate, C.ExpireDate
FROM dbo.TDADFeature F
LEFT JOIN dbo.TDADCompanyFeature C
  ON C.FeatureCode = F.FeatureCode
 AND C.PartnerID = @PartnerID
 AND (@CompanyID IS NULL OR C.CompanyID = @CompanyID)
WHERE F.IsActive = 1
ORDER BY F.SortOrder, F.FeatureCode;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId.HasValue ? companyId.Value : DBNull.Value;
        await using var reader = await command.ExecuteReaderAsync(token);
        var rows = new List<object>();
        while (await reader.ReadAsync(token))
        {
            rows.Add(new
            {
                featureCode = reader.GetString(0),
                featureName = reader.GetString(1),
                featureDescription = reader.IsDBNull(2) ? null : reader.GetString(2),
                companyFeatureId = reader.IsDBNull(3) ? (long?)null : reader.GetInt64(3),
                companyId = reader.IsDBNull(4) ? (long?)null : reader.GetInt64(4),
                isEnabled = !reader.IsDBNull(5) && reader.GetBoolean(5),
                isTrial = !reader.IsDBNull(6) && reader.GetBoolean(6),
                startDate = reader.IsDBNull(7) ? (DateTime?)null : reader.GetDateTime(7),
                expireDate = reader.IsDBNull(8) ? (DateTime?)null : reader.GetDateTime(8),
            });
        }
        return Ok(rows);
    }

    [HttpPut("{companyId:long}/sales-management")]
    public async Task<IActionResult> SetSalesManagement(long companyId, SalesManagementFeatureRequest request, CancellationToken token)
    {
        if (!IsPartnerUser()) return Forbid();
        var partnerId = PartnerId();
        if (partnerId is null) return Forbid();
        if (request.ExpireDate.HasValue && request.StartDate.HasValue && request.ExpireDate < request.StartDate)
            return BadRequest(new { message = "วันหมดอายุต้องไม่น้อยกว่าวันเริ่มต้น" });

        await using var connection = await OpenConnectionAsync(token);
        if (!await IsPartnerAdminAsync(connection, partnerId.Value, token)) return Forbid();
        if (!await OwnsCompanyAsync(connection, partnerId.Value, companyId, token)) return NotFound(new { message = "ไม่พบ Customer ภายใต้ Partner นี้" });
        var projectId = await ProjectIdAsync(connection, token);
        if (projectId is null) return BadRequest(new { message = "ไม่พบ Project LAOO ที่ใช้งาน" });

        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(token);
        try
        {
            const string sql = """
DECLARE @OldIsEnabled bit, @OldIsTrial bit, @OldStartDate date, @OldExpireDate date, @CompanyFeatureID bigint;
SELECT @CompanyFeatureID=CompanyFeatureID, @OldIsEnabled=IsEnabled, @OldIsTrial=IsTrial,
       @OldStartDate=StartDate, @OldExpireDate=ExpireDate
FROM dbo.TDADCompanyFeature WITH (UPDLOCK, HOLDLOCK)
WHERE ProjectID=@ProjectID AND CompanyID=@CompanyID AND FeatureCode=N'SALES_MANAGEMENT';

IF @CompanyFeatureID IS NULL
BEGIN
    INSERT dbo.TDADCompanyFeature
        (ProjectID,PartnerID,CompanyID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
    VALUES
        (@ProjectID,@PartnerID,@CompanyID,N'SALES_MANAGEMENT',@IsEnabled,@IsTrial,@StartDate,@ExpireDate,@UserID);
    SET @CompanyFeatureID=SCOPE_IDENTITY();
END
ELSE
BEGIN
    UPDATE dbo.TDADCompanyFeature
    SET PartnerID=@PartnerID, IsEnabled=@IsEnabled, IsTrial=@IsTrial,
        StartDate=@StartDate, ExpireDate=@ExpireDate,
        UpdateDate=SYSUTCDATETIME(), UpdatedBy=@UserID
    WHERE CompanyFeatureID=@CompanyFeatureID;
END;

INSERT dbo.TDADCompanyFeatureHistory
    (CompanyFeatureID,OldIsEnabled,NewIsEnabled,OldIsTrial,NewIsTrial,
     OldStartDate,NewStartDate,OldExpireDate,NewExpireDate,ChangeReason,ChangedBy)
VALUES
    (@CompanyFeatureID,@OldIsEnabled,@IsEnabled,@OldIsTrial,@IsTrial,
     @OldStartDate,@StartDate,@OldExpireDate,@ExpireDate,@ChangeReason,@UserID);

SELECT @CompanyFeatureID;
""";
            await using var command = new SqlCommand(sql, connection, transaction);
            command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId.Value;
            command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId.Value;
            command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
            command.Parameters.Add("@IsEnabled", SqlDbType.Bit).Value = request.IsEnabled;
            command.Parameters.Add("@IsTrial", SqlDbType.Bit).Value = request.IsTrial;
            command.Parameters.Add("@StartDate", SqlDbType.Date).Value = request.StartDate.HasValue ? request.StartDate.Value.Date : DBNull.Value;
            command.Parameters.Add("@ExpireDate", SqlDbType.Date).Value = request.ExpireDate.HasValue ? request.ExpireDate.Value.Date : DBNull.Value;
            command.Parameters.Add("@UserID", SqlDbType.BigInt).Value =
                PartnerUserId() is long partnerUserId ? partnerUserId : DBNull.Value;
            command.Parameters.Add("@ChangeReason", SqlDbType.NVarChar, 500).Value = string.IsNullOrWhiteSpace(request.ChangeReason) ? DBNull.Value : request.ChangeReason.Trim();
            var companyFeatureId = Convert.ToInt64(await command.ExecuteScalarAsync(token));
            await transaction.CommitAsync(token);
            return Ok(new { companyFeatureId, companyId, featureCode = "SALES_MANAGEMENT", isEnabled = request.IsEnabled, isTrial = request.IsTrial, request.StartDate, request.ExpireDate });
        }
        catch
        {
            await transaction.RollbackAsync(token);
            throw;
        }
    }

    private bool IsPartnerUser() => string.Equals(User.FindFirstValue("user_type"), "PARTNER_USER", StringComparison.OrdinalIgnoreCase);
    private long? PartnerId() => long.TryParse(User.FindFirstValue("partner_id"), out var value) ? value : null;
    private long? PartnerUserId()
    {
        var subject = User.FindFirstValue("sub") ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        return subject?.StartsWith("partner:", StringComparison.OrdinalIgnoreCase) == true &&
               long.TryParse(subject[8..], out var value)
            ? value
            : null;
    }

    private async Task<bool> IsPartnerAdminAsync(SqlConnection connection, long partnerId, CancellationToken token)
    {
        const string sql = "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADPartnerUser WHERE PartnerID=@PartnerID AND NormalizedUsername=@Username AND IsPartnerAdmin=1 AND IsActive=1) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId;
        command.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = (User.Identity?.Name ?? User.FindFirstValue("unique_name") ?? string.Empty).Trim().ToUpperInvariant();
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private async Task<bool> OwnsCompanyAsync(SqlConnection connection, long partnerId, long companyId, CancellationToken token)
    {
        const string sql = "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDSTCompanySetUp WHERE CompanyID=@CompanyID AND PartnerID=@PartnerID AND IsActive=1) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId;
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private async Task<long?> ProjectIdAsync(SqlConnection connection, CancellationToken token)
    {
        const string sql = "SELECT TOP 1 ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1 ORDER BY ProjectID";
        await using var command = new SqlCommand(sql, connection);
        var value = await command.ExecuteScalarAsync(token);
        return value is null || value == DBNull.Value ? null : Convert.ToInt64(value);
    }

    private async Task<SqlConnection> OpenConnectionAsync(CancellationToken token)
    {
        var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }
}

public sealed record SalesManagementFeatureRequest(
    bool IsEnabled,
    bool IsTrial,
    DateTime? StartDate,
    DateTime? ExpireDate,
    string? ChangeReason);
