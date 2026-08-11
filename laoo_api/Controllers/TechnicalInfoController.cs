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
        var menusByCode = result.Menus.ToDictionary(menu => menu.MenuCode, StringComparer.OrdinalIgnoreCase);
        const string dartFileSql = """
SELECT MenuCode, FileName, RelativePath, FullPath
FROM dbo.TDSTScreenDartFile
WHERE CompanyCode='TD'
ORDER BY MenuCode;
""";
        await using (var command = new SqlCommand(dartFileSql, connection))
        {
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                var menuCode = reader.GetString(0).Trim();
                if (menusByCode.TryGetValue(menuCode, out var menu))
                    result.DartFiles.Add(new TechnicalDartFile(
                        menuCode, menu.MenuName, reader.GetString(1),
                        reader.GetString(2), reader.GetString(3)));
            }
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
                var md = new TechnicalMd(
                    reader.GetString(0), reader.GetString(1), reader.GetString(2),
                    reader.GetString(3), N(reader, 4),
                    ResolveFilePath(reader.GetString(2), reader.GetString(3)));
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

    [HttpGet("file-content")]
    public IActionResult FileContent([FromQuery] string path)
    {
        var fullPath = Path.GetFullPath(path);
        var projectRoot = Path.GetFullPath(Directory.GetParent(environment.ContentRootPath)?.FullName ?? environment.ContentRootPath);
        var rootPrefix = projectRoot.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
        var allowedExtensions = new[] { ".md", ".dart", ".cs", ".sql", ".json", ".yaml", ".yml", ".txt", ".xml", ".html", ".css", ".js", ".ts", ".csproj", ".sln" };
        if (!fullPath.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase) || !allowedExtensions.Contains(Path.GetExtension(fullPath), StringComparer.OrdinalIgnoreCase))
            return BadRequest("ไฟล์นี้ไม่อยู่ในโครงการหรือไม่ใช่ไฟล์ข้อความที่รองรับ");
        if (!System.IO.File.Exists(fullPath)) return NotFound("ไม่พบไฟล์");
        return Ok(new { path = fullPath, content = System.IO.File.ReadAllText(fullPath) });
    }

    private IEnumerable<TechnicalMdPart> ReadMatches(TechnicalMd md, string term)
    {
        var path = md.MDFullPath;
        if (!System.IO.File.Exists(path)) yield break;
        var lines = System.IO.File.ReadAllLines(path);
        for (var i = 0; i < lines.Length; i++)
            if (lines[i].Contains(term, StringComparison.OrdinalIgnoreCase))
                yield return new TechnicalMdPart(i + 1, lines[i].Trim());
    }

    private static string? N(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);

    private string ResolveFilePath(string relativeDirectory, string fileName)
    {
        var root = Directory.GetParent(environment.ContentRootPath)?.FullName ?? environment.ContentRootPath;
        var path = Path.Combine(root, relativeDirectory.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar), fileName);
        if (System.IO.File.Exists(path)) return path;
        return Path.Combine(environment.ContentRootPath, relativeDirectory, fileName);
    }

}

public sealed class TechnicalInfoResponse
{
    public List<TechnicalMenu> Menus { get; } = [];
    public List<TechnicalDartFile> DartFiles { get; } = [];
    public List<TechnicalMd> Mds { get; } = [];
    public List<TechnicalTable> Tables { get; } = [];
}

public sealed record TechnicalMenu(string MenuCode, string MenuName, string? RouteName, string? RoutePath, string? FeatureCode);
public sealed record TechnicalDartFile(string MenuCode, string MenuName, string FileName, string RelativePath, string FullPath);
public sealed class TechnicalMd(string mdCode, string mdName, string mdPath, string mdFileName, string? menuCodes, string mdFullPath)
{
    public string MDCode { get; } = mdCode;
    public string MDName { get; } = mdName;
    public string MDPath { get; } = mdPath;
    public string MDFileName { get; } = mdFileName;
    public string? MenuCodes { get; } = menuCodes;
    public string MDFullPath { get; } = mdFullPath;
    public List<TechnicalMdPart> Parts { get; } = [];
}
public sealed record TechnicalMdPart(int Line, string Text);
public sealed record TechnicalTable(string TableName, string TableMeaning);
