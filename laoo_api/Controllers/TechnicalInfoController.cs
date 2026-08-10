using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/technical-info")]
[Authorize]
public sealed class TechnicalInfoController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string? q, CancellationToken cancellationToken)
    {
        var term = (q ?? string.Empty).Trim();
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken);

        var result = new TechnicalInfoResponse();
        const string menuSql = """
SELECT TOP (50) MenuCode, MenuName, RouteName, RoutePath, FeatureCode
FROM dbo.TDADMainMenu
WHERE IsActive=1 AND IsVisible=1 AND (@q='' OR MenuCode LIKE @like OR MenuName LIKE @like OR RouteName LIKE @like)
ORDER BY SortOrder, MenuCode;
""";
        await using (var command = new SqlCommand(menuSql, connection))
        {
            command.Parameters.AddWithValue("@q", term);
            command.Parameters.AddWithValue("@like", $"%{term}%");
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                result.Menus.Add(new TechnicalMenu(reader.GetString(0).Trim(), reader.GetString(1), N(reader, 2), N(reader, 3), N(reader, 4)));
        }

        const string mdSql = """
WITH M AS (
    SELECT CompanyCode, MIN(MDCode) AS MDCode, MAX(MDName) AS MDName, MDPath, MDFileName
    FROM dbo.TDSTMDName
    WHERE CompanyCode='TD'
    GROUP BY CompanyCode, MDPath, MDFileName
)
SELECT TOP (100) M.MDCode, M.MDName, M.MDPath, M.MDFileName,
       (SELECT STRING_AGG(X.MenuCode, ',') FROM (SELECT DISTINCT S.MenuCode FROM dbo.TDSTMDSystem S WHERE S.CompanyCode=M.CompanyCode AND S.MDCode=M.MDCode) X) AS MenuCodes
FROM M
ORDER BY M.MDCode;
""";
        await using (var command = new SqlCommand(mdSql, connection))
        {
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                var md = new TechnicalMd(reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), N(reader, 4));
                if (!string.IsNullOrWhiteSpace(term))
                    md.Parts.AddRange(ReadMatches(md, term));
                if (string.IsNullOrWhiteSpace(term) || md.Parts.Count > 0 || md.MDCode.Contains(term, StringComparison.OrdinalIgnoreCase) || md.MDName.Contains(term, StringComparison.OrdinalIgnoreCase) || md.MDFileName.Contains(term, StringComparison.OrdinalIgnoreCase))
                    result.Mds.Add(md);
            }
        }

        const string tableSql = """
SELECT TableName, MAX(Name) AS TableMeaning
FROM dbo.TDSTTableName
WHERE CompanyCode='TD' AND (@q='' OR TableName LIKE @like OR Name LIKE @like)
GROUP BY TableName
ORDER BY TableName;
""";
        await using (var command = new SqlCommand(tableSql, connection))
        {
            command.Parameters.AddWithValue("@q", term);
            command.Parameters.AddWithValue("@like", $"%{term}%");
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                result.Tables.Add(new TechnicalTable(reader.GetString(0), reader.IsDBNull(1) ? string.Empty : reader.GetString(1)));
        }

        return Ok(result);
    }

    private IEnumerable<TechnicalMdPart> ReadMatches(TechnicalMd md, string term)
    {
        var root = Directory.GetParent(environment.ContentRootPath)?.FullName ?? environment.ContentRootPath;
        var path = Path.Combine(root, md.MDPath.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar), md.MDFileName);
        if (!System.IO.File.Exists(path)) path = Path.Combine(environment.ContentRootPath, md.MDPath, md.MDFileName);
        if (!System.IO.File.Exists(path)) yield break;
        var lines = System.IO.File.ReadAllLines(path);
        for (var i = 0; i < lines.Length; i++)
            if (lines[i].Contains(term, StringComparison.OrdinalIgnoreCase))
                yield return new TechnicalMdPart(i + 1, lines[i].Trim());
    }

    private static string? N(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
}

public sealed class TechnicalInfoResponse
{
    public List<TechnicalMenu> Menus { get; } = [];
    public List<TechnicalMd> Mds { get; } = [];
    public List<TechnicalTable> Tables { get; } = [];
}

public sealed record TechnicalMenu(string MenuCode, string MenuName, string? RouteName, string? RoutePath, string? FeatureCode);
public sealed class TechnicalMd(string mdCode, string mdName, string mdPath, string mdFileName, string? menuCodes)
{
    public string MDCode { get; } = mdCode;
    public string MDName { get; } = mdName;
    public string MDPath { get; } = mdPath;
    public string MDFileName { get; } = mdFileName;
    public string? MenuCodes { get; } = menuCodes;
    public List<TechnicalMdPart> Parts { get; } = [];
}
public sealed record TechnicalMdPart(int Line, string Text);
public sealed record TechnicalTable(string TableName, string TableMeaning);
