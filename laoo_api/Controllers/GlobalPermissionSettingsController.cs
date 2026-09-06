using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/global-permission-settings")]
public sealed class GlobalPermissionSettingsController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "01006";
    public sealed record AddPointRequest(string MenuCode, string PermissionPointCode, string PermissionPointName, string? PermissionPointDescription);

    [HttpGet("caption")]
    public async Task<IActionResult> Caption(CancellationToken token)
    {
        if (!string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase)) return Forbid();
        await using var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(token);
        const string sql = "SELECT TOP 1 MenuName FROM dbo.TDADMainMenu WHERE CONVERT(nvarchar(20),MenuCode)=@menu AND IsActive=1";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.AddWithValue("@menu", ScreenCode);
        var caption = Convert.ToString(await cmd.ExecuteScalarAsync(token))?.Trim();
        if (string.IsNullOrWhiteSpace(caption)) return NotFound(new { message = "ไม่พบชื่อเมนู 01006 ใน TDADMainMenu" });
        return Ok(new { menuCode = ScreenCode, menuName = caption });
    }
    [HttpGet("menus")]
    public async Task<IActionResult> Menus(CancellationToken token)
    {
        if (!string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase)) return Forbid();
        await using var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(token);
        const string sql = "SELECT G.MenuGroupCode,G.MenuGroupName,M.MenuCode,M.MenuName,N.PermissionPointCode,N.PermissionPointName,N.PermissionPointDescription FROM dbo.TDADMenuGroup G INNER JOIN dbo.TDADMainMenu M ON M.MenuGroupCode=G.MenuGroupCode AND M.IsActive=1 AND M.IsVisible=1 AND M.ShowPermissionPoint=1 LEFT JOIN dbo.TDADUserPermissionPointName N ON N.MenuCode=CONVERT(NVARCHAR(20),M.MenuCode) AND N.IsActive=1 WHERE G.IsActive=1 AND G.ShowPermissionPoint=1 ORDER BY G.SortOrder,M.SortOrder,M.MenuCode,N.SortOrder,N.PermissionPointName";
        await using var cmd = new SqlCommand(sql, c);
        await using var r = await cmd.ExecuteReaderAsync(token);
        var rows = new List<object>();
        while (await r.ReadAsync(token)) rows.Add(new { menuGroupCode = r.GetValue(0)?.ToString()?.Trim(), menuGroupName = r.GetString(1), menuCode = r.GetValue(2)?.ToString()?.Trim(), menuName = r.GetString(3), permissionPointCode = r.IsDBNull(4) ? null : r.GetString(4), permissionPointName = r.IsDBNull(5) ? null : r.GetString(5), permissionPointDescription = r.IsDBNull(6) ? null : r.GetString(6) });
        return Ok(rows);
    }

    [HttpPost("points")]
    public async Task<IActionResult> AddPoint(AddPointRequest request, CancellationToken token)
    {
        if (!string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase)) return Forbid();
        if (string.IsNullOrWhiteSpace(request.MenuCode) || string.IsNullOrWhiteSpace(request.PermissionPointCode) || string.IsNullOrWhiteSpace(request.PermissionPointName)) return BadRequest(new { message = "กรุณาระบุข้อมูลสิทธิ์ย่อยให้ครบถ้วน" });
        await using var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(token);
        const string sql = "INSERT dbo.TDADUserPermissionPointName(MenuCode,PermissionPointCode,PermissionPointName,PermissionPointDescription,SortOrder,IsActive) SELECT @menu,@code,@name,@description,ISNULL(MAX(SortOrder),0)+1,1 FROM dbo.TDADUserPermissionPointName WHERE MenuCode=@menu AND NOT EXISTS (SELECT 1 FROM dbo.TDADUserPermissionPointName WHERE MenuCode=@menu AND PermissionPointCode=@code); SELECT CAST(SCOPE_IDENTITY() AS BIGINT);";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.AddWithValue("@menu", request.MenuCode.Trim()); cmd.Parameters.AddWithValue("@code", request.PermissionPointCode.Trim()); cmd.Parameters.AddWithValue("@name", request.PermissionPointName.Trim()); cmd.Parameters.AddWithValue("@description", (object?)request.PermissionPointDescription?.Trim() ?? DBNull.Value);
        var id = await cmd.ExecuteScalarAsync(token);
        if (id is null || id == DBNull.Value) return Conflict(new { message = "รหัสประเภทสิทธิ์นี้มีอยู่แล้ว" });
        return Ok(new { permissionPointNameId = Convert.ToInt64(id) });
    }

    [HttpPut("points/{menuCode}/{permissionPointCode}")]
    public async Task<IActionResult> UpdatePoint(string menuCode, string permissionPointCode, AddPointRequest request, CancellationToken token)
    {
        if (!string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase)) return Forbid();
        if (string.IsNullOrWhiteSpace(request.PermissionPointName)) return BadRequest(new { message = "กรุณาระบุประเภทสิทธิ์" });
        await using var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(token);
        const string sql = "UPDATE dbo.TDADUserPermissionPointName SET PermissionPointName=@name,PermissionPointDescription=@description,UpdatedDate=SYSUTCDATETIME() WHERE MenuCode=@menu AND PermissionPointCode=@code";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.AddWithValue("@menu", menuCode.Trim());
        cmd.Parameters.AddWithValue("@code", permissionPointCode.Trim());
        cmd.Parameters.AddWithValue("@name", request.PermissionPointName.Trim());
        cmd.Parameters.AddWithValue("@description", (object?)request.PermissionPointDescription?.Trim() ?? DBNull.Value);
        if (await cmd.ExecuteNonQueryAsync(token) == 0) return NotFound(new { message = "ไม่พบประเภทสิทธิ์ย่อยที่ต้องการแก้ไข" });
        return NoContent();
    }

    [HttpDelete("points/{menuCode}/{permissionPointCode}")]
    public async Task<IActionResult> DeletePoint(string menuCode, string permissionPointCode, CancellationToken token)
    {
        if (!string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase)) return Forbid();
        await using var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(token);
        const string sql = "DELETE FROM dbo.TDADUserPermissionPointName WHERE MenuCode=@menu AND PermissionPointCode=@code";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.AddWithValue("@menu", menuCode.Trim()); cmd.Parameters.AddWithValue("@code", permissionPointCode.Trim());
        if (await cmd.ExecuteNonQueryAsync(token) == 0) return NotFound(new { message = "ไม่พบประเภทสิทธิ์ย่อย" });
        return NoContent();
    }
}
