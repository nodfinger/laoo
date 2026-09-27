using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Security.Claims;

namespace LaooServiceApi.Controllers;

[ApiController]
[Route("api/system/company-setup")]
[Authorize]
public sealed class CompanySetupRuntimeController : ControllerBase
{
    private readonly IConfiguration _configuration;

    public CompanySetupRuntimeController(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    [HttpGet("runtime")]
    public async Task<IActionResult> GetRuntime(
        CancellationToken cancellationToken)
    {
        var baseConnectionString =
            _configuration.GetConnectionString("LaooDatabase");

        if (string.IsNullOrWhiteSpace(baseConnectionString))
        {
            return Problem(
                title: "LaooDatabase connection string is missing.",
                statusCode: StatusCodes.Status500InternalServerError);
        }

        await using var connection =
            new SqlConnection(baseConnectionString);

        await connection.OpenAsync(cancellationToken);

        var owner = ResolveOwner();
        if (owner is null)
        {
            return Forbid();
        }

        const string columnSql = """
            SELECT CASE
                WHEN COL_LENGTH(N'dbo.TDSTCompanySetUp', N'ThemeName') IS NULL
                THEN CAST(0 AS bit)
                ELSE CAST(1 AS bit)
            END;
            """;
        await using var columnCommand = new SqlCommand(columnSql, connection);
        var hasThemeName = Convert.ToBoolean(
            await columnCommand.ExecuteScalarAsync(cancellationToken));

        // The only interpolated fragment is selected from these two fixed projections.
        var themeProjection = hasThemeName
            ? "ThemeName"
            : "CAST(NULL AS nvarchar(200)) AS ThemeName";
        var sql = $$"""
            SELECT TOP (1)
                Name,
                TitleHeader,
                CustomerNameTh,
                AddressText,
                Telephone,
                TaxID,
                COALESCE(NULLIF(EmailCenter, N''), NULLIF(EmailAdmin, N'')) AS CustomerEmail,
                RowSTD,
                RowCardSTD,
                TimeAlert,
                OrgStructureType,
                YearFormat,
                VersionID,
                {{themeProjection}},
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(SuperUserName)), '') IS NULL
                    THEN CAST(0 AS bit)
                    ELSE CAST(1 AS bit)
                END AS HasSuperUser,
                CASE
                    WHEN PasswordDirect IS NULL
                    THEN CAST(0 AS bit)
                    ELSE CAST(1 AS bit)
                END AS HasPasswordDirect
            FROM dbo.TDSTCompanySetUp
            WHERE (
                    (@OwnerType = 'L' AND OwnerType = 'L' AND PartnerID IS NULL AND CompanyID IS NULL)
                    OR (@OwnerType = 'P' AND OwnerType = 'P' AND PartnerID = @PartnerID AND @PartnerID IS NOT NULL AND CompanyID IS NULL)
                    OR (@OwnerType = 'C' AND OwnerType = 'C' AND CompanyID = @CompanyID AND @CompanyID IS NOT NULL)
                  )
            ORDER BY PKValue;
            """;

        await using var command =
            new SqlCommand(sql, connection);
        command.Parameters.Add("@OwnerType", SqlDbType.Char, 1).Value = owner.Value.OwnerType;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value =
            (object?)owner.Value.PartnerID ?? DBNull.Value;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value =
            (object?)owner.Value.CompanyID ?? DBNull.Value;

        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return NotFound(new
            {
                message = "ไม่พบข้อมูลใน TDSTCompanySetUp"
            });
        }

        return Ok(new
        {
            name = ReadString(reader, "Name", "Laoo Solutions"),
            titleHeader = ReadString(
                reader,
                "TitleHeader",
                "Laoo Solutions"),
            companyName = ReadNullableString(reader, "CustomerNameTh"),
            addressText = ReadNullableString(reader, "AddressText"),
            telephone = ReadNullableString(reader, "Telephone"),
            taxID = ReadNullableString(reader, "TaxID"),
            email = ReadNullableString(reader, "CustomerEmail"),
            rowSTD = ReadInt(reader, "RowSTD", 50),
            rowCardSTD = ReadInt(reader, "RowCardSTD", 12),
            timeAlert = ReadInt(reader, "TimeAlert", 30),
            orgStructureType = ReadInt(reader, "OrgStructureType", 1),
            yearFormat = ReadString(reader, "YearFormat", "C"),
            versionID = ReadString(reader, "VersionID", ""),
            themeName = ReadNullableString(reader, "ThemeName"),
            hasSuperUser = reader.GetBoolean(
                reader.GetOrdinal("HasSuperUser")),
            hasPasswordDirect = reader.GetBoolean(
                reader.GetOrdinal("HasPasswordDirect"))
        });
    }

    private OwnerScope? ResolveOwner()
    {
        var companyId = GetLongClaim("company_id");
        if (companyId is not null)
        {
            return new OwnerScope("C", null, companyId);
        }

        var partnerId = GetLongClaim("partner_id");
        if (partnerId is not null)
        {
            return new OwnerScope("P", partnerId, null);
        }

        var loginMode = User.FindFirstValue("login_mode");
        return string.Equals(loginMode, "LAOO", StringComparison.OrdinalIgnoreCase)
            ? new OwnerScope("L", null, null)
            : null;
    }

    private long? GetLongClaim(string type)
    {
        var raw = User.FindFirstValue(type);
        return long.TryParse(raw, out var value) ? value : null;
    }

    private static string ReadString(
        SqlDataReader reader,
        string name,
        string fallback)
    {
        var value = ReadNullableString(reader, name);
        return string.IsNullOrWhiteSpace(value)
            ? fallback
            : value;
    }

    private static string? ReadNullableString(
        SqlDataReader reader,
        string name)
    {
        var ordinal = reader.GetOrdinal(name);

        if (reader.IsDBNull(ordinal))
        {
            return null;
        }

        return Convert.ToString(
            reader.GetValue(ordinal))?.Trim();
    }

    private static int ReadInt(
        SqlDataReader reader,
        string name,
        int fallback)
    {
        var ordinal = reader.GetOrdinal(name);

        if (reader.IsDBNull(ordinal))
        {
            return fallback;
        }

        var value = Convert.ToInt32(reader.GetValue(ordinal));
        return value > 0 ? value : fallback;
    }

    private readonly record struct OwnerScope(
        string OwnerType,
        long? PartnerID,
        long? CompanyID);
}
