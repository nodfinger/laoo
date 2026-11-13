using System.Data;
using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/global-settings")]
public sealed class GlobalSettingsController(
    IConfiguration configuration,
    IWebHostEnvironment environment) : ControllerBase
{
    private readonly IConfiguration _configuration = configuration;
    private readonly IWebHostEnvironment _environment = environment;
    private static readonly SemaphoreSlim AppSettingsWriteLock = new(1, 1);

    [HttpGet("home-page")]
    public async Task<IActionResult> GetHomePage(CancellationToken token)
    {
        if (!IsLaoo()) return Forbid();
        try
        {
            var root = await ReadAppSettings(token);
            var home = root["HomePage"] as JsonObject;
            var mode = int.TryParse(home?["DefaultMode"]?.ToString(), out var parsedMode)
                ? parsedMode
                : 3;
            if (mode is < 1 or > 4) mode = 3;
            var url = home?["Options"]?["2"]?["Url"]?.ToString() ?? string.Empty;
            return Ok(new { defaultMode = mode, externalUrl = url });
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException)
        {
            return StatusCode(500, new
            {
                message = "อ่านรูปแบบหน้าจอเริ่มต้นจาก appsettings.json ไม่สำเร็จ",
                description = "ตรวจสอบว่าไฟล์ appsettings.json มีรูปแบบ JSON ถูกต้องและมีสิทธิ์อ่านได้"
            });
        }
    }

    [HttpPut("home-page")]
    public async Task<IActionResult> SaveHomePage(
        HomePageSettingsRequest request,
        CancellationToken token)
    {
        if (!IsLaoo()) return Forbid();
        if (request.DefaultMode is < 1 or > 4)
            return BadRequest(new { message = "กรุณาเลือกรูปแบบการเริ่มต้นหน้าจอ 1 ถึง 4" });

        var url = request.ExternalUrl?.Trim() ?? string.Empty;
        if (url.Length > 2048 || request.DefaultMode == 2 && !TryNormalizeUrl(url, out _))
            return BadRequest(new
            {
                message = "URL หน้าเริ่มต้นไม่ถูกต้อง",
                description = "รูปแบบ URL ภายนอกต้องเป็นที่อยู่ HTTP หรือ HTTPS ที่ใช้งานได้"
            });
        if (url.Length > 0 && !TryNormalizeUrl(url, out url))
            return BadRequest(new { message = "URL หน้าเริ่มต้นไม่ถูกต้อง", description = "ใช้ได้เฉพาะ URL แบบ HTTP หรือ HTTPS" });

        await AppSettingsWriteLock.WaitAsync(token);
        var path = Path.Combine(_environment.ContentRootPath, "appsettings.json");
        var temporaryPath = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            var root = await ReadAppSettings(token);
            if (root["HomePage"] is not JsonObject home)
            {
                home = new JsonObject();
                root["HomePage"] = home;
            }
            home["DefaultMode"] = request.DefaultMode;
            if (home["Options"] is not JsonObject options)
            {
                options = new JsonObject();
                home["Options"] = options;
            }
            if (options["2"] is not JsonObject external)
            {
                external = new JsonObject();
                options["2"] = external;
            }
            external["Url"] = url;

            var json = root.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
            await System.IO.File.WriteAllTextAsync(temporaryPath, json, new System.Text.UTF8Encoding(false), token);
            System.IO.File.Move(temporaryPath, path, true);
            return NoContent();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException)
        {
            return StatusCode(500, new
            {
                message = "บันทึกรูปแบบหน้าจอเริ่มต้นลง appsettings.json ไม่สำเร็จ",
                description = "ตรวจสอบสิทธิ์เขียนไฟล์ของ API Server แล้วลองใหม่"
            });
        }
        finally
        {
            try
            {
                if (System.IO.File.Exists(temporaryPath)) System.IO.File.Delete(temporaryPath);
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
            finally { AppSettingsWriteLock.Release(); }
        }
    }

    private async Task<JsonObject> ReadAppSettings(CancellationToken token)
    {
        var json = await System.IO.File.ReadAllTextAsync(
            Path.Combine(_environment.ContentRootPath, "appsettings.json"), token);
        return JsonNode.Parse(json) as JsonObject
            ?? throw new JsonException("Invalid appsettings root");
    }

    private static bool TryNormalizeUrl(string value, out string normalized)
    {
        var candidate = value.Trim();
        if (!System.Text.RegularExpressions.Regex.IsMatch(candidate, @"^[a-zA-Z][a-zA-Z0-9+.-]*://"))
            candidate = "https://" + candidate;
        if (Uri.TryCreate(candidate, UriKind.Absolute, out var uri) &&
            uri.Scheme is "http" or "https" && uri.Host.Length > 0 &&
            uri.UserInfo.Length == 0 && !candidate.Any(char.IsWhiteSpace))
        {
            normalized = uri.ToString();
            return true;
        }
        normalized = string.Empty;
        return false;
    }
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        if (!IsLaoo()) return Forbid();
        await using var c = await OpenAsync(token);
        const string sql = "SELECT ProjectID,MaxItemImageSizeMB,MaxBusinessCardImageSizeMB,DescriptionItemImage,DescriptionBusinessCardImage FROM dbo.TDSTProjectSetupSystem WHERE ProjectID=@project AND IsActive=1";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@project", SqlDbType.BigInt, ProjectID());
        await using var r = await cmd.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound(new { message = "ยังไม่พบค่ากำหนดส่วนกลางของ Project" });
        return Ok(new { projectId = r.GetInt64(0), maxItemImageSizeMB = r.GetDecimal(1), maxBusinessCardImageSizeMB = r.GetDecimal(2), descriptionItemImage = r.IsDBNull(3) ? null : r.GetString(3), descriptionBusinessCardImage = r.IsDBNull(4) ? null : r.GetString(4) });
    }
    [HttpPut]
    public async Task<IActionResult> Save(GlobalSettingsRequest request, CancellationToken token)
    {
        if (!IsLaoo()) return Forbid();
        if (request.MaxItemImageSizeMB <= 0 || request.MaxBusinessCardImageSizeMB <= 0) return BadRequest(new { message = "ขนาดไฟล์ต้องมากกว่า 0 MB" });
        await using var c = await OpenAsync(token);
        const string sql = """
IF EXISTS (SELECT 1 FROM dbo.TDSTProjectSetupSystem WHERE ProjectID=@project)
    UPDATE dbo.TDSTProjectSetupSystem SET MaxItemImageSizeMB=@item, MaxBusinessCardImageSizeMB=@card, DescriptionItemImage=@itemDescription, DescriptionBusinessCardImage=@cardDescription, UpdateBy=@user, UpdateDate=SYSUTCDATETIME(), IsActive=1 WHERE ProjectID=@project;
ELSE
    INSERT dbo.TDSTProjectSetupSystem(ProjectID,MaxItemImageSizeMB,MaxBusinessCardImageSizeMB,DescriptionItemImage,DescriptionBusinessCardImage,CreateBy) VALUES(@project,@item,@card,@itemDescription,@cardDescription,@user);
""";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@project", SqlDbType.BigInt, ProjectID()); Add(cmd, "@item", SqlDbType.Decimal, request.MaxItemImageSizeMB); Add(cmd, "@card", SqlDbType.Decimal, request.MaxBusinessCardImageSizeMB); Add(cmd, "@itemDescription", SqlDbType.NVarChar, (object?)request.DescriptionItemImage?.Trim() ?? DBNull.Value, 1000); Add(cmd, "@cardDescription", SqlDbType.NVarChar, (object?)request.DescriptionBusinessCardImage?.Trim() ?? DBNull.Value, 1000); Add(cmd, "@user", SqlDbType.BigInt, UserID()); await cmd.ExecuteNonQueryAsync(token);
        return NoContent();
    }
    private bool IsLaoo() => string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase);
    private long ProjectID() => long.TryParse(User.FindFirstValue("project_id"), out var value) ? value : 0;
    private long UserID() => long.TryParse(User.FindFirstValue("laoo_user_id")?.Replace("laoo:", ""), out var value) ? value : 0;
    private async Task<SqlConnection> OpenAsync(CancellationToken token) { var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private static void Add(SqlCommand c, string name, SqlDbType type, object value) { var p = c.Parameters.Add(name, type); p.Value = value; if (type == SqlDbType.Decimal) { p.Precision = 10; p.Scale = 2; } }
    private static void Add(SqlCommand c, string name, SqlDbType type, object value, int size) { var p = c.Parameters.Add(name, type, size); p.Value = value; }
}
public sealed record GlobalSettingsRequest(decimal MaxItemImageSizeMB, decimal MaxBusinessCardImageSizeMB, string? DescriptionItemImage, string? DescriptionBusinessCardImage);
public sealed record HomePageSettingsRequest(int DefaultMode, string? ExternalUrl);
