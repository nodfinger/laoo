using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

/// <summary>Personal display preferences; never used to authorize data access.</summary>
[ApiController, Authorize, Route("api/user-list-display")]
public sealed class UserListDisplayController(IConfiguration configuration) : ControllerBase
{
    // Only fields explicitly exposed by a screen can be configured. Never expose
    // database metadata, internal columns or permission-dependent fields here.
    private static readonly IReadOnlyDictionary<string, string[]> Fields = new Dictionary<string, string[]>
    {
        ["10003"] = ["name", "status"],
        ["05002"] = ["name", "sequence", "shortCode"],
        ["66001"] = ["number", "date", "department", "claimant", "purpose", "workPlace", "origin", "destination", "total"],
        ["10008"] = ["system", "menu", "name", "description", "approvedBy", "approvedAt", "status"],
        ["43002"] = ["code", "title", "type", "status", "publishAt", "updatedByName", "updatedAt"]
    };

    private async Task<(SqlConnection? Db, long UserId)> OpenAuthorizedAsync(string menu, CancellationToken token)
    {
        if (!Fields.ContainsKey(menu) || User.FindFirstValue("user_type") != "COMPANY_USER" ||
            !long.TryParse(User.FindFirstValue("user_id"), out var userId)) return (null, 0);
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        try
        {
            await db.OpenAsync(token);
            await using (var setting = new SqlCommand(
                "SELECT AllowListDisplaySettings FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1", db))
            {
                setting.Parameters.Add("@menu", SqlDbType.NVarChar, 20).Value = menu;
                var enabled = await setting.ExecuteScalarAsync(token);
                if (enabled is not bool allowed || !allowed)
                {
                    await db.DisposeAsync();
                    return (null, 0);
                }
            }
            if (!await CompanyMenuAccess.IsAllowedAsync(db, User, menu, "VIEW", token))
            {
                await db.DisposeAsync();
                return (null, 0);
            }
            return (db, userId);
        }
        catch { await db.DisposeAsync(); throw; }
    }

    [HttpGet("available-menus")]
    public async Task<IActionResult> AvailableMenus(CancellationToken token)
    {
        if (User.FindFirstValue("user_type") != "COMPANY_USER" ||
            !long.TryParse(User.FindFirstValue("user_id"), out _)) return Forbid();
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        await using var cmd = new SqlCommand(
            "SELECT MenuCode FROM dbo.TDADMainMenu WHERE IsActive=1 AND AllowListDisplaySettings=1", db);
        var codes = new List<string>();
        await using var reader = await cmd.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token)) codes.Add(reader.GetString(0));
        return Ok(codes);
    }

    [HttpGet("{menu}")]
    public async Task<IActionResult> Get(string menu, CancellationToken token)
    {
        var (db, id) = await OpenAuthorizedAsync(menu, token);
        if (db is null) return Forbid();
        await using (db)
        await using (var cmd = new SqlCommand("SELECT PreferencesJson FROM dbo.TDADUserListDisplayPreference WHERE UserType='C' AND UserID=@user AND MenuCode=@menu", db))
        {
            cmd.Parameters.Add("@user", SqlDbType.BigInt).Value = id;
            cmd.Parameters.Add("@menu", SqlDbType.NVarChar, 20).Value = menu;
            var json = await cmd.ExecuteScalarAsync(token) as string;
            return Content(json ?? "{}", "application/json");
        }
    }

    public sealed record Preferences(string[]? Order, string[]? Hidden, bool ActionOnRight);

    [HttpPut("{menu}")]
    public async Task<IActionResult> Put(string menu, Preferences input, CancellationToken token)
    {
        var (db, id) = await OpenAuthorizedAsync(menu, token);
        if (db is null) return Forbid();
        await using (db)
        {
            var valid = Fields[menu].ToHashSet(StringComparer.Ordinal);
            var order = input.Order ?? [];
            var hidden = input.Hidden ?? [];
            if ((hidden.Contains("name", StringComparer.Ordinal) || menu == "66001" && hidden.Contains("number", StringComparer.Ordinal) || menu == "43002" && hidden.Contains("title", StringComparer.Ordinal)) || order.Length > valid.Count || hidden.Length > valid.Count ||
                order.Distinct(StringComparer.Ordinal).Count() != order.Length ||
                hidden.Distinct(StringComparer.Ordinal).Count() != hidden.Length ||
                order.Any(key => !valid.Contains(key)) || hidden.Any(key => !valid.Contains(key)))
                return BadRequest(new { message = "ไม่สามารถบันทึกการแสดงข้อมูลได้", description = "กรุณาตรวจสอบรายการคอลัมน์แล้วลองใหม่" });
            var json = JsonSerializer.Serialize(new { order, hidden, actionOnRight = input.ActionOnRight });
            await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
            await using var cmd = new SqlCommand("""
UPDATE dbo.TDADUserListDisplayPreference SET PreferencesJson=@json,UpdateDate=SYSUTCDATETIME() WHERE UserType='C' AND UserID=@user AND MenuCode=@menu;
IF @@ROWCOUNT=0 INSERT dbo.TDADUserListDisplayPreference(UserType,UserID,MenuCode,PreferencesJson) VALUES('C',@user,@menu,@json);
""", db, tx);
            cmd.Parameters.Add("@user", SqlDbType.BigInt).Value = id;
            cmd.Parameters.Add("@menu", SqlDbType.NVarChar, 20).Value = menu;
            cmd.Parameters.Add("@json", SqlDbType.NVarChar, -1).Value = json;
            await cmd.ExecuteNonQueryAsync(token);
            await tx.CommitAsync(token);
            return NoContent();
        }
    }

    [HttpDelete("{menu}")]
    public async Task<IActionResult> Reset(string menu, CancellationToken token)
    {
        var (db, id) = await OpenAuthorizedAsync(menu, token);
        if (db is null) return Forbid();
        await using (db)
        await using (var cmd = new SqlCommand("DELETE FROM dbo.TDADUserListDisplayPreference WHERE UserType='C' AND UserID=@user AND MenuCode=@menu", db))
        {
            cmd.Parameters.Add("@user", SqlDbType.BigInt).Value = id;
            cmd.Parameters.Add("@menu", SqlDbType.NVarChar, 20).Value = menu;
            await cmd.ExecuteNonQueryAsync(token);
            return NoContent();
        }
    }

    [HttpDelete]
    public async Task<IActionResult> ResetAll(CancellationToken token)
    {
        if (User.FindFirstValue("user_type") != "COMPANY_USER" ||
            !long.TryParse(User.FindFirstValue("user_id"), out var id)) return Forbid();
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        await using var cmd = new SqlCommand("DELETE FROM dbo.TDADUserListDisplayPreference WHERE UserType='C' AND UserID=@user", db);
        cmd.Parameters.Add("@user", SqlDbType.BigInt).Value = id;
        await cmd.ExecuteNonQueryAsync(token);
        return NoContent();
    }
}
