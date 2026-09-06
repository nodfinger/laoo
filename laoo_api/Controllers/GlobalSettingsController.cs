using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/global-settings")]
public sealed class GlobalSettingsController(IConfiguration configuration) : ControllerBase
{
    private readonly IConfiguration _configuration = configuration;
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
