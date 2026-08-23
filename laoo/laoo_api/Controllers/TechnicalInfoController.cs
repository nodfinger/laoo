using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/technical-info")]
[Authorize]
public sealed class TechnicalInfoController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private static readonly HashSet<string> AllowedFileExtensions =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ".dart", ".md", ".sql", ".txt"
        };

    private static readonly HashSet<string> BlockedFileNames =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ".env", "local.json", "appsettings.Local.json", "secrets.json"
        };

    private static readonly HashSet<string> BlockedDirectoryNames =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ".git", ".codex", ".vs", "bin", "obj", "publish"
        };

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string? q, CancellationToken cancellationToken)
    {
        if (!environment.IsDevelopment()) return NotFound();

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
                {
                    var fullPath = reader.GetString(3);
                    if (!TryResolveAllowedExistingFile(fullPath, out fullPath)) continue;
                    result.DartFiles.Add(new TechnicalDartFile(
                        menuCode, menu.MenuName, reader.GetString(1),
                        reader.GetString(2), fullPath));
                }
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
                var fullPath = ResolveFilePath(reader.GetString(2), reader.GetString(3));
                if (fullPath is null) continue;

                var md = new TechnicalMd(
                    reader.GetString(0), reader.GetString(1), reader.GetString(2),
                    reader.GetString(3), N(reader, 4),
                    fullPath);
                if (!string.IsNullOrWhiteSpace(term))
                    md.Parts.AddRange(ReadMatches(md, term));
                if (string.IsNullOrWhiteSpace(term) || md.Parts.Count > 0 || md.MDCode.Contains(term, StringComparison.OrdinalIgnoreCase) || md.MDName.Contains(term, StringComparison.OrdinalIgnoreCase) || md.MDFileName.Contains(term, StringComparison.OrdinalIgnoreCase))
                    result.Mds.Add(md);
            }
        }

        const string tableSql = """
SELECT TableName, MAX(Name) AS TableMeaning, ColName, DataType, Remark
FROM dbo.TDSTTableName
WHERE CompanyCode='TD' AND (@q='' OR TableName LIKE @like OR Name LIKE @like)
GROUP BY TableName, ColName, DataType, Remark
ORDER BY TableName, ColName;
""";
        await using (var command = new SqlCommand(tableSql, connection))
        {
            command.Parameters.AddWithValue("@q", term);
            command.Parameters.AddWithValue("@like", $"%{term}%");
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            var tables = new Dictionary<string, TechnicalTable>(StringComparer.OrdinalIgnoreCase);
            while (await reader.ReadAsync(cancellationToken))
            {
                var tableName = reader.GetString(0);
                if (!tables.TryGetValue(tableName, out var table))
                {
                    table = new TechnicalTable(tableName, reader.IsDBNull(1) ? string.Empty : reader.GetString(1));
                    tables[tableName] = table;
                    result.Tables.Add(table);
                }
                table.Fields.Add(new TechnicalTableField(reader.GetString(2), reader.GetString(3), reader.IsDBNull(4) ? string.Empty : reader.GetString(4)));
            }
        }

        return Ok(result);
    }

    [HttpGet("file-content")]
    public async Task<IActionResult> FileContent(
        [FromQuery] string path,
        CancellationToken cancellationToken)
    {
        if (!environment.IsDevelopment()) return NotFound();
        if (!TryResolveAllowedExistingFile(path, out var fullPath))
            return BadRequest("ไฟล์นี้ไม่อยู่ในโครงการหรือไม่ใช่ไฟล์ข้อความที่รองรับ");
        if (!System.IO.File.Exists(fullPath)) return NotFound("ไม่พบไฟล์");
        return Ok(new
        {
            path = fullPath,
            content = await System.IO.File.ReadAllTextAsync(
                fullPath,
                cancellationToken)
        });
    }

    private IEnumerable<TechnicalMdPart> ReadMatches(TechnicalMd md, string term)
    {
        if (!TryResolveAllowedExistingFile(md.MDFullPath, out var path)) yield break;
        var lines = System.IO.File.ReadAllLines(path);
        for (var i = 0; i < lines.Length; i++)
            if (lines[i].Contains(term, StringComparison.OrdinalIgnoreCase))
                yield return new TechnicalMdPart(i + 1, lines[i].Trim());
    }

    private static string? N(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);

    private string? ResolveFilePath(string relativeDirectory, string fileName)
    {
        var root = Directory.GetParent(environment.ContentRootPath)?.FullName ?? environment.ContentRootPath;
        var candidates = new[]
        {
            Path.Combine(
                root,
                relativeDirectory
                    .Replace('/', Path.DirectorySeparatorChar)
                    .Replace('\\', Path.DirectorySeparatorChar),
                fileName),
            Path.Combine(environment.ContentRootPath, relativeDirectory, fileName)
        };

        foreach (var candidate in candidates)
        {
            if (TryResolveAllowedExistingFile(candidate, out var fullPath))
                return fullPath;
        }

        return null;
    }

    private bool TryResolveAllowedExistingFile(
        string requestedPath,
        out string fullPath)
    {
        fullPath = string.Empty;
        if (string.IsNullOrWhiteSpace(requestedPath)) return false;

        string resolvedPath;
        try
        {
            var candidate = Path.IsPathFullyQualified(requestedPath)
                ? requestedPath
                : Path.Combine(environment.ContentRootPath, requestedPath);
            resolvedPath = Path.GetFullPath(candidate);
        }
        catch (Exception exception) when (
            exception is ArgumentException or NotSupportedException or PathTooLongException)
        {
            return false;
        }

        var fileName = Path.GetFileName(resolvedPath);
        if (!AllowedFileExtensions.Contains(Path.GetExtension(resolvedPath)) ||
            BlockedFileNames.Contains(fileName) ||
            fileName.StartsWith("appsettings.", StringComparison.OrdinalIgnoreCase) ||
            fileName.StartsWith(".env.", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var allowedRoot = AllowedRoots()
            .FirstOrDefault(root => IsWithinRoot(resolvedPath, root));
        if (allowedRoot is null || !System.IO.File.Exists(resolvedPath)) return false;

        if (ContainsReparsePoint(allowedRoot, resolvedPath)) return false;

        fullPath = resolvedPath;
        return true;
    }

    private IEnumerable<string> AllowedRoots()
    {
        var workspaceRoot =
            Directory.GetParent(environment.ContentRootPath)?.FullName
            ?? environment.ContentRootPath;

        return new[]
            {
                Path.Combine(environment.ContentRootPath, "docs"),
                Path.Combine(workspaceRoot, "docs"),
                Path.Combine(workspaceRoot, "scripts"),
                Path.Combine(workspaceRoot, "laoo", "lib")
            }
            .Select(Path.GetFullPath)
            .Where(Directory.Exists)
            .Distinct(StringComparer.OrdinalIgnoreCase);
    }

    private static bool IsWithinRoot(string fullPath, string root)
    {
        var relative = Path.GetRelativePath(root, fullPath);
        return !Path.IsPathRooted(relative) &&
               relative != ".." &&
               !relative.StartsWith(
                   $"..{Path.DirectorySeparatorChar}",
                   StringComparison.Ordinal) &&
               !relative.StartsWith(
                   $"..{Path.AltDirectorySeparatorChar}",
                   StringComparison.Ordinal) &&
               relative.Split(
                       [Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar],
                       StringSplitOptions.RemoveEmptyEntries)
                   .All(segment => !BlockedDirectoryNames.Contains(segment));
    }

    private static bool ContainsReparsePoint(string root, string fullPath)
    {
        var current = root;
        if ((System.IO.File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
            return true;

        foreach (var segment in Path.GetRelativePath(root, fullPath).Split(
                     [Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar],
                     StringSplitOptions.RemoveEmptyEntries))
        {
            current = Path.Combine(current, segment);
            if ((System.IO.File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                return true;
        }

        return false;
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
public sealed class TechnicalTable(string tableName, string tableMeaning)
{
    public string TableName { get; } = tableName;
    public string TableMeaning { get; } = tableMeaning;
    public List<TechnicalTableField> Fields { get; } = [];
}
public sealed record TechnicalTableField(string ColName, string DataType, string Remark);
