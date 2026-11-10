using System.Data;
using System.Security.Cryptography;
using System.Text;
using LaooApi.Services.Assistant;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/assistant/user-commands")]
public sealed class AssistantUserCommandsController(IConfiguration configuration) : ControllerBase
{
    public sealed record CommandRequest(string? Text, string? Capability);

    private async Task<(SqlConnection? Db, long Company, long User, AiChatSettings? Settings)> Context(CancellationToken token)
    {
        var company = AiChatSettingsStore.CompanyId(User);
        if (company is null || !long.TryParse(User.FindFirst("user_id")?.Value, out var user)) return (null, 0, 0, null);
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        var settings = await AiChatSettingsStore.ReadAsync(db, company.Value, user, token);
        if (settings is null || !settings.Enabled) { await db.DisposeAsync(); return (null, 0, 0, null); }
        await using var check = new SqlCommand("SELECT COUNT_BIG(*) FROM dbo.TDADUser WHERE CompanyID=@c AND UserID=@u AND IsActive=1", db);
        check.Parameters.AddWithValue("@c", company.Value); check.Parameters.AddWithValue("@u", user);
        if (Convert.ToInt64(await check.ExecuteScalarAsync(token)) != 1) { await db.DisposeAsync(); return (null, 0, 0, null); }
        return (db, company.Value, user, settings);
    }

    private static byte[] Hash(string value) => SHA256.HashData(Encoding.UTF8.GetBytes(string.Concat(value.Where(c => !char.IsWhiteSpace(c))).ToUpperInvariant()));

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        var ctx = await Context(token); if (ctx.Db is null) return Forbid();
        await using var db = ctx.Db;
        await using var cmd = new SqlCommand("SELECT CommandID,CommandText,IsFavorite,LastUsedAt FROM dbo.TDADAiUserCommand WHERE CompanyID=@c AND UserID=@u ORDER BY LastUsedAt DESC,CommandID DESC", db);
        cmd.Parameters.AddWithValue("@c", ctx.Company); cmd.Parameters.AddWithValue("@u", ctx.User);
        var favorite = new List<object>(); var recent = new List<object>();
        await using var reader = await cmd.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
        {
            var item = new { id = reader.GetInt64(0), text = reader.GetString(1) };
            if (reader.GetBoolean(2)) favorite.Add(item);
            if (!reader.IsDBNull(3) && recent.Count < ctx.Settings!.EffectiveRecentCommandLimit) recent.Add(item);
        }
        return Ok(new { favorite, recent, favoriteCount = favorite.Count, favoriteLimit = ctx.Settings!.EffectiveFrequentCommandLimit, recentLimit = ctx.Settings.EffectiveRecentCommandLimit });
    }

    [HttpPost("{kind}")]
    public async Task<IActionResult> Save(string kind, CommandRequest request, CancellationToken token)
    {
        if (kind is not ("favorite" or "recent")) return NotFound();
        var text = request.Text?.Trim();
        if (string.IsNullOrWhiteSpace(text) || text.Length > 1000) return BadRequest(new { message = "กรุณาระบุคำสั่งไม่เกิน 1,000 ตัวอักษร" });
        var ctx = await Context(token); if (ctx.Db is null) return Forbid();
        await using var db = ctx.Db;
        var allowed = request.Capability == "repair.serial_combined"
            ? await AssistantCapabilityAccess.IsAllowed(db, User, AssistantCapabilities.SerialLookup.Id, token)
              && await AssistantCapabilityAccess.IsAllowed(db, User, AssistantCapabilities.SerialRepairHistory.Id, token)
            : request.Capability is not null && await AssistantCapabilityAccess.IsAllowed(db, User, request.Capability, token);
        if (!allowed) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        await using var cmd = new SqlCommand("SELECT CommandID,IsFavorite FROM dbo.TDADAiUserCommand WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND UserID=@u AND CommandHash=@hash", db, tx);
        cmd.Parameters.AddWithValue("@c", ctx.Company); cmd.Parameters.AddWithValue("@u", ctx.User);
        cmd.Parameters.Add("@hash", SqlDbType.Binary, 32).Value = Hash(text);
        long? id = null; var existingFavorite = false;
        await using (var reader = await cmd.ExecuteReaderAsync(token)) if (await reader.ReadAsync(token)) { id = reader.GetInt64(0); existingFavorite = reader.GetBoolean(1); }
        if (kind == "favorite" && !existingFavorite)
        {
            cmd.CommandText = "SELECT COUNT(*) FROM dbo.TDADAiUserCommand WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND UserID=@u AND IsFavorite=1";
            var count = Convert.ToInt32(await cmd.ExecuteScalarAsync(token));
            if (count >= ctx.Settings!.EffectiveFrequentCommandLimit) { await tx.RollbackAsync(token); return Conflict(new { message = "จำนวนคำสั่งใช้บ่อยเต็มแล้ว" }); }
        }
        if (kind == "recent" && ctx.Settings!.EffectiveRecentCommandLimit <= 0) { await tx.RollbackAsync(token); return NoContent(); }
        cmd.Parameters.Add("@text", SqlDbType.NVarChar, 1000).Value = text;
        cmd.Parameters.AddWithValue("@favorite", kind == "favorite");
        cmd.CommandText = id is null
            ? "INSERT dbo.TDADAiUserCommand(CompanyID,UserID,CommandHash,CommandText,IsFavorite,LastUsedAt) VALUES(@c,@u,@hash,@text,@favorite,CASE WHEN @favorite=0 THEN SYSUTCDATETIME() END)"
            : "UPDATE dbo.TDADAiUserCommand SET CommandText=@text, IsFavorite=CASE WHEN @favorite=1 THEN 1 ELSE IsFavorite END, LastUsedAt=CASE WHEN @favorite=0 THEN SYSUTCDATETIME() ELSE LastUsedAt END WHERE CompanyID=@c AND UserID=@u AND CommandHash=@hash";
        await cmd.ExecuteNonQueryAsync(token);
        if (kind == "recent")
        {
            cmd.Parameters.AddWithValue("@limit", ctx.Settings!.EffectiveRecentCommandLimit);
            cmd.CommandText = "UPDATE dbo.TDADAiUserCommand SET LastUsedAt=NULL WHERE CommandID IN (SELECT CommandID FROM dbo.TDADAiUserCommand WHERE CompanyID=@c AND UserID=@u AND LastUsedAt IS NOT NULL ORDER BY LastUsedAt DESC,CommandID DESC OFFSET @limit ROWS); DELETE dbo.TDADAiUserCommand WHERE CompanyID=@c AND UserID=@u AND IsFavorite=0 AND LastUsedAt IS NULL";
            await cmd.ExecuteNonQueryAsync(token);
        }
        await tx.CommitAsync(token); return NoContent();
    }

    [HttpDelete("favorite/{id:long}")]
    public async Task<IActionResult> Remove(long id, CancellationToken token)
    {
        var ctx = await Context(token); if (ctx.Db is null) return Forbid();
        await using var db = ctx.Db;
        await using var cmd = new SqlCommand("UPDATE dbo.TDADAiUserCommand SET IsFavorite=0 WHERE CommandID=@id AND CompanyID=@c AND UserID=@u; DELETE dbo.TDADAiUserCommand WHERE CommandID=@id AND CompanyID=@c AND UserID=@u AND IsFavorite=0 AND LastUsedAt IS NULL", db);
        cmd.Parameters.AddWithValue("@id", id); cmd.Parameters.AddWithValue("@c", ctx.Company); cmd.Parameters.AddWithValue("@u", ctx.User);
        await cmd.ExecuteNonQueryAsync(token); return NoContent();
    }
}
