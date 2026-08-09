using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

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

        // Company Setup belongs to DBTDLaoo.
        // Keep server/authentication options from local.json, but force
        // only the InitialCatalog for this project database.
        var builder = new SqlConnectionStringBuilder(
            baseConnectionString)
        {
            InitialCatalog = "DBTDLaoo"
        };

        await using var connection =
            new SqlConnection(builder.ConnectionString);

        await connection.OpenAsync(cancellationToken);

        const string sql = """
            SELECT TOP (1)
                Name,
                TitleHeader,
                RowSTD,
                RowCardSTD,
                TimeAlert,
                YearFormat,
                VersionID,
                ThemeName,
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
            ORDER BY PKValue;
            """;

        await using var command =
            new SqlCommand(sql, connection);

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
            rowSTD = ReadInt(reader, "RowSTD", 50),
            rowCardSTD = ReadInt(reader, "RowCardSTD", 12),
            timeAlert = ReadInt(reader, "TimeAlert", 30),
            yearFormat = ReadString(reader, "YearFormat", "C"),
            versionID = ReadString(reader, "VersionID", ""),
            themeName = ReadNullableString(reader, "ThemeName"),
            hasSuperUser = reader.GetBoolean(
                reader.GetOrdinal("HasSuperUser")),
            hasPasswordDirect = reader.GetBoolean(
                reader.GetOrdinal("HasPasswordDirect"))
        });
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
}
