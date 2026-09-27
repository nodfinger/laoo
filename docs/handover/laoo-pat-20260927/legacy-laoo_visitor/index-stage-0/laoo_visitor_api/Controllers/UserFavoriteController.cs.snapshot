using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Authorize]
[Route("api/user-favorites")]
public sealed class UserFavoriteController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        var owner = ResolveOwner();
        if (owner is null) return Forbid();
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        await using var command = new SqlCommand($"""
SELECT F.MenuCode, M.MenuName, M.RouteName, M.RoutePath, M.IconName, F.SortOrder
FROM dbo.TDADUserFavorite F
INNER JOIN dbo.TDADMainMenu M ON M.MenuCode=F.MenuCode AND M.IsActive=1 AND M.IsVisible=1
WHERE {owner.Value.Where}
ORDER BY F.SortOrder, M.SortOrder, M.MenuCode;
""", connection);
        command.Parameters.Add("@id", SqlDbType.BigInt).Value = owner.Value.Id;
        return Ok(await ReadRows(command, token));
    }

    [HttpPost]
    public async Task<IActionResult> Add([FromBody] UserFavoriteRequest request, CancellationToken token)
    {
        var owner = ResolveOwner();
        if (owner is null) return Forbid();
        var menuCode = request.MenuCode?.Trim() ?? string.Empty;
        if (menuCode.Length == 0) return BadRequest(new { message = "กรุณาระบุ MenuCode" });
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        await using var command = new SqlCommand($"""
IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1 AND IsVisible=1)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.TDADUserFavorite WHERE {owner.Value.Where} AND MenuCode=@menu)
        INSERT dbo.TDADUserFavorite(UserType,{owner.Value.Column},MenuCode,SortOrder)
        VALUES(@type,@id,@menu,@sort)
END
""", connection);
        command.Parameters.Add("@type", SqlDbType.Char, 1).Value = owner.Value.Type;
        command.Parameters.Add("@id", SqlDbType.BigInt).Value = owner.Value.Id;
        command.Parameters.Add("@menu", SqlDbType.NVarChar, 20).Value = menuCode;
        command.Parameters.Add("@sort", SqlDbType.Int).Value = request.SortOrder;
        await command.ExecuteNonQueryAsync(token);
        return Ok(new { menuCode });
    }

    [HttpDelete("{menuCode}")]
    public async Task<IActionResult> Remove(string menuCode, CancellationToken token)
    {
        var owner = ResolveOwner();
        if (owner is null) return Forbid();
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        await using var command = new SqlCommand($"DELETE FROM dbo.TDADUserFavorite WHERE {owner.Value.Where} AND MenuCode=@menu;", connection);
        command.Parameters.Add("@id", SqlDbType.BigInt).Value = owner.Value.Id;
        command.Parameters.Add("@menu", SqlDbType.NVarChar, 20).Value = menuCode.Trim();
        await command.ExecuteNonQueryAsync(token);
        return NoContent();
    }

    private Owner? ResolveOwner()
    {
        var type = User.FindFirstValue("user_type");
        if (type == "LAOO_SUPPORT" && long.TryParse(User.FindFirstValue("laoo_user_id"), out var laoo)) return new Owner('L', "LaooUserID", "LaooUserID", laoo);
        if (type == "PARTNER_USER" && TryPartnerUserId(out var partner)) return new Owner('P', "PartnerUserID", "PartnerUserID", partner);
        if (type == "COMPANY_USER" && long.TryParse(User.FindFirstValue("user_id"), out var company)) return new Owner('C', "UserID", "UserID", company);
        return null;
    }

    private bool TryPartnerUserId(out long id)
    {
        if (long.TryParse(User.FindFirstValue("user_id"), out id)) return true;
        var subject = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? string.Empty;
        return subject.StartsWith("partner:", StringComparison.OrdinalIgnoreCase) && long.TryParse(subject[8..], out id);
    }

    private static async Task<List<UserFavoriteResponse>> ReadRows(SqlCommand command, CancellationToken token)
    {
        await using var reader = await command.ExecuteReaderAsync(token);
        var rows = new List<UserFavoriteResponse>();
        while (await reader.ReadAsync(token))
            rows.Add(new(reader.GetString(0), reader.GetString(1), N(reader, 2), N(reader, 3), N(reader, 4), reader.GetInt32(5)));
        return rows;
    }

    private static string? N(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
    private readonly record struct Owner(char Type, string Column, string WhereColumn, long Id)
    {
        public string Where => $"{Column}=@id";
    }
}

public sealed record UserFavoriteRequest(string? MenuCode, int SortOrder = 0);
public sealed record UserFavoriteResponse(string MenuCode, string MenuName, string? RouteName, string? RoutePath, string? IconName, int SortOrder);
