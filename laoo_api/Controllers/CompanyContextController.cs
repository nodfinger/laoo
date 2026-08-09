using System.Data;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/company-context")]
[Authorize]
public sealed class CompanyContextController : ControllerBase
{
    private readonly IConfiguration _configuration;
    private readonly JwtOptions _jwtOptions;

    public CompanyContextController(
        IConfiguration configuration,
        IOptions<JwtOptions> jwtOptions)
    {
        _configuration = configuration;
        _jwtOptions = jwtOptions.Value;
    }

    [HttpGet("companies")]
    public async Task<ActionResult<IReadOnlyList<CompanyContextCompany>>> GetCompaniesAsync(
        CancellationToken cancellationToken)
    {
        if (!IsLaooSupport())
        {
            return Forbid();
        }

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        const string sql = """
SELECT
    CompanyID,
    CompanyCode,
    COALESCE(NULLIF(CompanyNameTH, N''), CompanyCode) AS CompanyName
FROM dbo.TDADCompany
WHERE IsActive = 1
ORDER BY CompanyCode;
""";

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var items = new List<CompanyContextCompany>();

        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(
                new CompanyContextCompany(
                    reader.GetInt64(reader.GetOrdinal("CompanyID")),
                    reader.GetString(reader.GetOrdinal("CompanyCode")),
                    reader.GetString(reader.GetOrdinal("CompanyName"))));
        }

        return Ok(items);
    }

    [HttpPut]
    public async Task<ActionResult<CompanyContextResponse>> SelectAsync(
        [FromBody] SelectCompanyContextRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsLaooSupport())
        {
            return Forbid();
        }

        if (request.CompanyID <= 0)
        {
            return BadRequest(new { message = "CompanyID ไม่ถูกต้อง" });
        }

        var laooUserId = GetLongClaim("laoo_user_id");
        var projectId = GetLongClaim("project_id");

        if (laooUserId is null || projectId is null)
        {
            return Forbid();
        }

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        const string companySql = """
SELECT
    CompanyID,
    CompanyCode,
    COALESCE(NULLIF(CompanyNameTH, N''), CompanyCode) AS CompanyName
FROM dbo.TDADCompany
WHERE CompanyID = @CompanyID
  AND IsActive = 1;
""";

        CompanyContextCompany company;

        await using (var companyCommand = new SqlCommand(companySql, connection))
        {
            companyCommand.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value =
                request.CompanyID;

            await using var reader =
                await companyCommand.ExecuteReaderAsync(cancellationToken);

            if (!await reader.ReadAsync(cancellationToken))
            {
                return NotFound(new { message = "ไม่พบ Company ที่ใช้งานอยู่" });
            }

            company = new CompanyContextCompany(
                reader.GetInt64(reader.GetOrdinal("CompanyID")),
                reader.GetString(reader.GetOrdinal("CompanyCode")),
                reader.GetString(reader.GetOrdinal("CompanyName")));
        }

        // Update the latest active Support session if one exists.
        // JWT remains the authoritative client context after this request.
        const string sessionSql = """
;WITH CurrentSession AS
(
    SELECT TOP (1) *
    FROM dbo.TDADLoginSession
    WHERE ActualLaooUserID = @LaooUserID
      AND ProjectID = @ProjectID
      AND LoginMode = 'S'
      AND IsActive = 1
    ORDER BY LoginDate DESC
)
UPDATE CurrentSession
SET
    CompanyID = @CompanyID,
    ContextSelectedDate = SYSUTCDATETIME(),
    LastActivityDate = SYSUTCDATETIME();
""";

        await using (var sessionCommand = new SqlCommand(sessionSql, connection))
        {
            sessionCommand.Parameters.Add("@LaooUserID", SqlDbType.BigInt).Value =
                laooUserId.Value;
            sessionCommand.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value =
                projectId.Value;
            sessionCommand.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value =
                company.CompanyID;

            await sessionCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        var expiresAt =
            DateTime.UtcNow.AddMinutes(_jwtOptions.AccessTokenMinutes);

        var token = CreateContextToken(company, expiresAt);

        return Ok(
            new CompanyContextResponse(
                true,
                company.CompanyID,
                company.CompanyCode,
                company.CompanyName,
                token,
                expiresAt));
    }

    private string CreateContextToken(
        CompanyContextCompany company,
        DateTime expiresAt)
    {
        var claims = User.Claims
            .Where(c =>
                c.Type != "company_id"
                && c.Type != "company_code"
                && c.Type != JwtRegisteredClaimNames.Nbf
                && c.Type != JwtRegisteredClaimNames.Exp
                && c.Type != JwtRegisteredClaimNames.Iss
                && c.Type != JwtRegisteredClaimNames.Aud)
            .Select(c => new Claim(c.Type, c.Value))
            .ToList();

        claims.Add(new Claim("company_id", company.CompanyID.ToString()));
        claims.Add(new Claim("company_code", company.CompanyCode));

        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(_jwtOptions.SecretKey));

        var credentials =
            new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _jwtOptions.Issuer,
            audience: _jwtOptions.Audience,
            claims: claims,
            notBefore: DateTime.UtcNow,
            expires: expiresAt,
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private bool IsLaooSupport()
    {
        var loginMode = User.FindFirstValue("login_mode");
        var laooUserId = User.FindFirstValue("laoo_user_id");

        return string.Equals(loginMode, "LAOO", StringComparison.OrdinalIgnoreCase)
               && !string.IsNullOrWhiteSpace(laooUserId);
    }

    private long? GetLongClaim(string type)
    {
        var raw = User.FindFirstValue(type);
        return long.TryParse(raw, out var value) ? value : null;
    }

    private SqlConnection CreateConnection()
    {
        var connectionString =
            _configuration.GetConnectionString("LaooDatabase");

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "ไม่พบ ConnectionStrings:LaooDatabase");
        }

        return new SqlConnection(connectionString);
    }
}
