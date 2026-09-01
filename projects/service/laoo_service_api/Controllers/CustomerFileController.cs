using System.Data;
using System.Security.Claims;
using LaooServiceApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceApi.Controllers;

[ApiController, Authorize]
[Route("api/company/customers/{customerId:long}/files")]
public sealed class CustomerFileController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private readonly IConfiguration _configuration = configuration;
    private const long MaxFileSize = 10 * 1024 * 1024;
    private static readonly HashSet<string> ImageExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".jpg", ".jpeg", ".png", ".webp" };
    private static readonly HashSet<string> DocumentExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".doc", ".docx", ".xls", ".xlsx", ".pdf", ".txt", ".csv" };

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<CustomerFileRow>>> List(long customerId, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "VIEW", token) || !await OwnsCustomerAsync(c, customerId, token)) return Forbid();
        const string sql = """
SELECT CustomerFileID,CustomerID,FileType,OriginalFileName,Extension,ContentType,FileSize,CreateDate,Description
FROM dbo.TDARCustomerFile
WHERE CompanyID=@company AND CustomerID=@customer AND IsActive=1
ORDER BY FileType,CreateDate DESC,CustomerFileID DESC
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@customer", SqlDbType.BigInt, customerId);
        var result = new List<CustomerFileRow>();
        await using var reader = await cmd.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
            result.Add(new(reader.GetInt64(0), reader.GetInt64(1), reader.GetString(2), reader.GetString(3), reader.GetString(4), Text(reader, 5), reader.GetInt64(6), reader.GetDateTime(7), Text(reader, 8)));
        return Ok(result);
    }

    [HttpPost]
    [RequestSizeLimit(MaxFileSize)]
    public async Task<IActionResult> Upload(long customerId, IFormFile? file, [FromForm] string? fileType, [FromForm] string? description, CancellationToken token)
    {
        if (file is null || file.Length == 0) return BadRequest(new { message = "กรุณาเลือกไฟล์" });
        if (file.Length > MaxFileSize) return BadRequest(new { message = "ไฟล์ต้องมีขนาดไม่เกิน 10 MB" });
        var type = fileType?.Trim().ToUpperInvariant() ?? "";
        if (type is not ("BUSINESS_CARD" or "CUSTOMER_DOCUMENT")) return BadRequest(new { message = "ประเภทไฟล์ไม่ถูกต้อง" });
        var extension = Path.GetExtension(file.FileName);
        var allowed = type == "BUSINESS_CARD" ? ImageExtensions : DocumentExtensions;
        if (!allowed.Contains(extension)) return BadRequest(new { message = "ชนิดไฟล์นี้ไม่รองรับ" });

        await using var c = await OpenAsync(token);
        var permissionPointCode = type == "BUSINESS_CARD" ? "001" : "002";
        if (!await CanAsync(c, "EDIT", token, permissionPointCode) || !await OwnsCustomerAsync(c, customerId, token)) return Forbid();
        var company = CompanyID().ToString();
        var relativeDirectory = Path.Combine("uploads", "customers", company, customerId.ToString(), type.ToLowerInvariant());
        var root = Path.GetFullPath(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"));
        var directory = Path.GetFullPath(Path.Combine(root, relativeDirectory));
        Directory.CreateDirectory(directory);
        var storedName = $"{Guid.NewGuid():N}{extension.ToLowerInvariant()}";
        var fullPath = Path.Combine(directory, storedName);
        var relativePath = Path.Combine(relativeDirectory, storedName).Replace('\\', '/');
        try
        {
            await using (var output = System.IO.File.Create(fullPath)) await file.CopyToAsync(output, token);
            const string sql = """
INSERT dbo.TDARCustomerFile(CompanyID,CustomerID,FileType,OriginalFileName,StoredFileName,RelativePath,Extension,ContentType,FileSize,Description,CreateBy)
OUTPUT INSERTED.CustomerFileID
VALUES(@company,@customer,@type,@original,@stored,@path,@extension,@content,@size,@description,@user)
""";
            await using var cmd = new SqlCommand(sql, c);
            Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@customer", SqlDbType.BigInt, customerId); Add(cmd, "@type", SqlDbType.NVarChar, type, 30);
            Add(cmd, "@original", SqlDbType.NVarChar, Path.GetFileName(file.FileName), 255); Add(cmd, "@stored", SqlDbType.NVarChar, storedName, 255); Add(cmd, "@path", SqlDbType.NVarChar, relativePath, 500);
            Add(cmd, "@extension", SqlDbType.NVarChar, extension.ToLowerInvariant(), 20); Add(cmd, "@content", SqlDbType.NVarChar, (object?)file.ContentType ?? DBNull.Value, 100); Add(cmd, "@size", SqlDbType.BigInt, file.Length); Add(cmd, "@description", SqlDbType.NVarChar, (object?)description?.Trim() ?? DBNull.Value, 1000); Add(cmd, "@user", SqlDbType.BigInt, UserID());
            var id = Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
            return Ok(new { customerFileId = id });
        }
        catch
        {
            if (System.IO.File.Exists(fullPath)) System.IO.File.Delete(fullPath);
            throw;
        }
    }

    [HttpGet("{fileId:long}/download")]
    public async Task<IActionResult> Download(long customerId, long fileId, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "VIEW", token)) return Forbid();
        const string sql = "SELECT RelativePath,OriginalFileName,ContentType FROM dbo.TDARCustomerFile WHERE CustomerFileID=@id AND CompanyID=@company AND CustomerID=@customer AND IsActive=1";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@id", SqlDbType.BigInt, fileId); Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@customer", SqlDbType.BigInt, customerId);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound();
        var relative = reader.GetString(0); var original = reader.GetString(1); var contentType = Text(reader, 2) ?? "application/octet-stream";
        var root = Path.GetFullPath(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"));
        var fullPath = Path.GetFullPath(Path.Combine(root, relative.Replace('/', Path.DirectorySeparatorChar)));
        if (!fullPath.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || !System.IO.File.Exists(fullPath)) return NotFound();
        return PhysicalFile(fullPath, contentType, original, enableRangeProcessing: true);
    }

    [HttpPut("{fileId:long}")]
    public async Task<IActionResult> Update(long customerId, long fileId, [FromBody] CustomerFileUpdateRequest request, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "EDIT", token)) return Forbid();
        const string sql = "UPDATE dbo.TDARCustomerFile SET Description=@description,UpdateDate=SYSUTCDATETIME() WHERE CustomerFileID=@id AND CompanyID=@company AND CustomerID=@customer AND IsActive=1";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@description", SqlDbType.NVarChar, (object?)request.Description?.Trim() ?? DBNull.Value, 1000);
        Add(cmd, "@id", SqlDbType.BigInt, fileId); Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@customer", SqlDbType.BigInt, customerId);
        if (await cmd.ExecuteNonQueryAsync(token) == 0) return NotFound();
        return NoContent();
    }

    [HttpDelete("{fileId:long}")]
    public async Task<IActionResult> Delete(long customerId, long fileId, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "DELETE", token)) return Forbid();
        const string sql = "SELECT RelativePath FROM dbo.TDARCustomerFile WHERE CustomerFileID=@id AND CompanyID=@company AND CustomerID=@customer AND IsActive=1";
        await using var find = new SqlCommand(sql, c); Add(find, "@id", SqlDbType.BigInt, fileId); Add(find, "@company", SqlDbType.BigInt, CompanyID()); Add(find, "@customer", SqlDbType.BigInt, customerId);
        var relative = await find.ExecuteScalarAsync(token) as string;
        if (string.IsNullOrWhiteSpace(relative)) return NotFound();
        await using var remove = new SqlCommand("DELETE FROM dbo.TDARCustomerFile WHERE CustomerFileID=@id AND CompanyID=@company AND CustomerID=@customer", c);
        Add(remove, "@id", SqlDbType.BigInt, fileId); Add(remove, "@company", SqlDbType.BigInt, CompanyID()); Add(remove, "@customer", SqlDbType.BigInt, customerId); await remove.ExecuteNonQueryAsync(token);
        var root = Path.GetFullPath(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot")); var fullPath = Path.GetFullPath(Path.Combine(root, relative.Replace('/', Path.DirectorySeparatorChar)));
        if (fullPath.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) && System.IO.File.Exists(fullPath)) System.IO.File.Delete(fullPath);
        return NoContent();
    }

    private async Task<bool> OwnsCustomerAsync(SqlConnection c, long customerId, CancellationToken token)
    { await using var cmd = new SqlCommand("SELECT COUNT(1) FROM dbo.TDARCustomer WHERE CustomerID=@customer AND CompanyID=@company", c); Add(cmd, "@customer", SqlDbType.BigInt, customerId); Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); return Convert.ToInt32(await cmd.ExecuteScalarAsync(token)) > 0; }
    private async Task<bool> CanAsync(SqlConnection c, string action, CancellationToken token, string? permissionPointCode = null)
    { const string sql = """
SELECT CASE WHEN
    EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode=@action AND P.ScreenCode='09001')
 OR (@point IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.TDADUser U INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID INNER JOIN dbo.TDADUserPermissionPoint PP ON PP.EmployeeID=UE.EmployeeID AND PP.ProjectID=@project AND PP.CompanyID=@company AND PP.MenuCode='09001' AND PP.PermissionPointCode=@point AND PP.IsActive=1 AND PP.IsAllowed=1 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1))
 OR EXISTS(SELECT 1 FROM dbo.TDADUser U INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode='09001' AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))
 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END
"""; await using var cmd = new SqlCommand(sql, c); Add(cmd, "@user", SqlDbType.BigInt, UserID()); Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@project", SqlDbType.BigInt, ProjectID()); Add(cmd, "@action", SqlDbType.NVarChar, action, 20); Add(cmd, "@point", SqlDbType.NVarChar, (object?)permissionPointCode ?? DBNull.Value, 80); return (bool)(await cmd.ExecuteScalarAsync(token) ?? false); }
    private async Task<SqlConnection> OpenAsync(CancellationToken token) { var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private long UserID() => long.TryParse(User.FindFirstValue("user_id"), out var value) ? value : 0;
    private long CompanyID() => long.TryParse(User.FindFirstValue("company_id"), out var value) ? value : 0;
    private long ProjectID() => long.TryParse(User.FindFirstValue("project_id"), out var value) ? value : 0;
    private static string? Text(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetValue(index)?.ToString();
    private static void Add(SqlCommand command, string name, SqlDbType type, object value, int size = 0) { var parameter = command.Parameters.Add(name, type); if (size > 0) parameter.Size = size; parameter.Value = value ?? DBNull.Value; }
}
