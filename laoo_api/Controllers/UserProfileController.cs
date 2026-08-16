using System.Data;
using System.Security.Claims;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/user-profile")]
public sealed class UserProfileController(IConfiguration configuration, PasswordService passwordService) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        var owner = ResolveOwner();
        if (owner is null) return Forbid();
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        await using var command = new SqlCommand($"""
SELECT U.Username,U.DisplayName,P.ThemeCode,P.Introduction,P.AvatarContentType,P.AvatarFileName,P.AvatarData
FROM dbo.{owner.Value.Table} U
LEFT JOIN dbo.TDADUserProfile P ON P.{owner.Value.ProfileKey}=@id
WHERE U.{owner.Value.UserKey}=@id AND U.IsActive=1;
""", connection);
        command.Parameters.Add("@id", SqlDbType.BigInt).Value = owner.Value.Id;
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound(new { message = "ไม่พบข้อมูลผู้ใช้งาน" });
        return Ok(new
        {
            username = reader.GetString(0), displayName = reader.GetString(1),
            themeCode = reader.IsDBNull(2) ? null : reader.GetString(2),
            introduction = reader.IsDBNull(3) ? null : reader.GetString(3),
            avatarContentType = reader.IsDBNull(4) ? null : reader.GetString(4),
            avatarFileName = reader.IsDBNull(5) ? null : reader.GetString(5),
            avatarDataBase64 = reader.IsDBNull(6) ? null : Convert.ToBase64String((byte[])reader[6])
        });
    }

    [HttpPut]
    public async Task<IActionResult> Update([FromBody] UserProfileUpdate request, CancellationToken token)
    {
        var owner = ResolveOwner();
        if (owner is null) return Forbid();
        var username = request.Username?.Trim() ?? string.Empty;
        if (username.Length is < 1 or > 100) return BadRequest(new { message = "กรุณาระบุ Username ให้ถูกต้อง" });
        if (!string.IsNullOrWhiteSpace(request.NewPassword) &&
            !PasswordService.MeetsPolicy(username, request.NewPassword))
            return BadRequest(new { message = PasswordService.PolicyMessage });
        if (request.Introduction?.Length > 1000) return BadRequest(new { message = "ข้อความแนะนำยาวเกิน 1,000 ตัวอักษร" });
        byte[]? avatar = null;
        if (!request.RemoveAvatar && !string.IsNullOrWhiteSpace(request.AvatarDataBase64))
        {
            try { avatar = Convert.FromBase64String(request.AvatarDataBase64); }
            catch (FormatException) { return BadRequest(new { message = "รูปโปรไฟล์ไม่ถูกต้อง" }); }
            if (avatar.Length > 2 * 1024 * 1024) return BadRequest(new { message = "รูปโปรไฟล์ต้องมีขนาดไม่เกิน 2 MB" });
        }

        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(token);
        try
        {
            var current = await ReadCurrentAsync(connection, transaction, owner.Value, token);
            if (current is null) return NotFound(new { message = "ไม่พบข้อมูลผู้ใช้งาน" });
            var loginChanged = !string.Equals(current.Value.Username, username, StringComparison.OrdinalIgnoreCase) || !string.IsNullOrWhiteSpace(request.NewPassword);
            if (loginChanged && string.IsNullOrWhiteSpace(request.CurrentPassword)) return BadRequest(new { message = "กรุณาระบุ Password เดิมก่อนแก้ไขข้อมูล Login" });
            if (loginChanged && !passwordService.VerifyPassword(current.Value.Username, current.Value.PasswordHash, request.CurrentPassword!)) return BadRequest(new { message = "Password เดิมไม่ถูกต้อง" });
            var normalized = username.ToUpperInvariant();
            if (!string.Equals(current.Value.Username, username, StringComparison.OrdinalIgnoreCase))
            {
                await using var duplicate = new SqlCommand($"SELECT COUNT(1) FROM dbo.{owner.Value.Table} WHERE NormalizedUsername=@name AND {owner.Value.UserKey}<>@id", connection, transaction);
                duplicate.Parameters.Add("@name", SqlDbType.NVarChar, 100).Value = normalized;
                duplicate.Parameters.Add("@id", SqlDbType.BigInt).Value = owner.Value.Id;
                if ((int)await duplicate.ExecuteScalarAsync(token)! > 0) return Conflict(new { message = "Username นี้ถูกใช้งานแล้ว" });
            }

            var passwordHash = string.IsNullOrWhiteSpace(request.NewPassword) ? current.Value.PasswordHash : passwordService.HashPassword(username, request.NewPassword!);
            await using var update = new SqlCommand($"UPDATE dbo.{owner.Value.Table} SET Username=@name,NormalizedUsername=@normalized,PasswordHash=@hash WHERE {owner.Value.UserKey}=@id;", connection, transaction);
            Add(update, "@name", SqlDbType.NVarChar, username, 100); Add(update, "@normalized", SqlDbType.NVarChar, normalized, 100); Add(update, "@hash", SqlDbType.NVarChar, passwordHash, 500); update.Parameters.Add("@id", SqlDbType.BigInt).Value = owner.Value.Id;
            await update.ExecuteNonQueryAsync(token);

            await using var profile = new SqlCommand($"""
UPDATE dbo.TDADUserProfile SET AvatarData=CASE WHEN @remove=1 THEN NULL ELSE COALESCE(@avatar,AvatarData) END,AvatarContentType=CASE WHEN @remove=1 THEN NULL ELSE COALESCE(@type,AvatarContentType) END,AvatarFileName=CASE WHEN @remove=1 THEN NULL ELSE COALESCE(@file,AvatarFileName) END,ThemeCode=@theme,Introduction=@intro,UpdateDate=SYSUTCDATETIME()
WHERE {owner.Value.ProfileKey}=@id;
IF @@ROWCOUNT=0 INSERT dbo.TDADUserProfile(UserType,{owner.Value.ProfileKey},AvatarData,AvatarContentType,AvatarFileName,ThemeCode,Introduction) VALUES(@userType,@id,@avatar,@type,@file,@theme,@intro);
""", connection, transaction);
            profile.Parameters.Add("@userType", SqlDbType.Char, 1).Value = owner.Value.Type; profile.Parameters.Add("@id", SqlDbType.BigInt).Value = owner.Value.Id; profile.Parameters.Add("@remove", SqlDbType.Bit).Value = request.RemoveAvatar;
            profile.Parameters.Add("@avatar", SqlDbType.VarBinary, -1).Value = (object?)avatar ?? DBNull.Value; Add(profile, "@type", SqlDbType.NVarChar, request.AvatarContentType, 100); Add(profile, "@file", SqlDbType.NVarChar, request.AvatarFileName, 250); Add(profile, "@theme", SqlDbType.NVarChar, request.ThemeCode, 30); Add(profile, "@intro", SqlDbType.NVarChar, request.Introduction, 1000);
            await profile.ExecuteNonQueryAsync(token);
            await transaction.CommitAsync(token);
            return Ok(new { username, displayName = current.Value.DisplayName });
        }
        catch { await transaction.RollbackAsync(token); throw; }
    }

    [HttpPut("theme")]
    public async Task<IActionResult> UpdateTheme([FromBody] UserProfileThemeUpdate request, CancellationToken token)
    {
        var owner = ResolveOwner();
        if (owner is null) return Forbid();
        if (string.IsNullOrWhiteSpace(request.ThemeCode)) return BadRequest(new { message = "กรุณาเลือก Style" });
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        await using var command = new SqlCommand($"""
UPDATE dbo.TDADUserProfile SET ThemeCode=@theme,UpdateDate=SYSUTCDATETIME()
WHERE {owner.Value.ProfileKey}=@id;
IF @@ROWCOUNT=0 INSERT dbo.TDADUserProfile(UserType,{owner.Value.ProfileKey},ThemeCode) VALUES(@userType,@id,@theme);
""", connection);
        command.Parameters.Add("@userType", SqlDbType.Char, 1).Value = owner.Value.Type;
        command.Parameters.Add("@id", SqlDbType.BigInt).Value = owner.Value.Id;
        command.Parameters.Add("@theme", SqlDbType.NVarChar, 30).Value = request.ThemeCode.Trim();
        await command.ExecuteNonQueryAsync(token);
        return Ok(new { themeCode = request.ThemeCode.Trim() });
    }

    private async Task<(string Username, string DisplayName, string PasswordHash)?> ReadCurrentAsync(SqlConnection c, SqlTransaction tx, Owner owner, CancellationToken token)
    {
        await using var cmd = new SqlCommand($"SELECT Username,DisplayName,PasswordHash FROM dbo.{owner.Table} WHERE {owner.UserKey}=@id AND IsActive=1", c, tx);
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = owner.Id;
        await using var r = await cmd.ExecuteReaderAsync(token);
        return await r.ReadAsync(token) ? (r.GetString(0), r.GetString(1), r.GetString(2)) : null;
    }

    private Owner? ResolveOwner()
    {
        var type = User.FindFirstValue("user_type");
        if (type == "LAOO_SUPPORT" && long.TryParse(User.FindFirstValue("laoo_user_id"), out var laoo)) return new Owner('L', "TDADLaooUser", "LaooUserID", "LaooUserID", laoo);
        if (type == "PARTNER_USER" && TryPartnerUserId(out var partner)) return new Owner('P', "TDADPartnerUser", "PartnerUserID", "PartnerUserID", partner);
        if (type == "COMPANY_USER" && long.TryParse(User.FindFirstValue("user_id"), out var company)) return new Owner('C', "TDADUser", "UserID", "UserID", company);
        return null;
    }

    private bool TryPartnerUserId(out long id)
    {
        if (long.TryParse(User.FindFirstValue("user_id"), out id)) return true;
        var subject = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? string.Empty;
        return subject.StartsWith("partner:", StringComparison.OrdinalIgnoreCase)
            && long.TryParse(subject[8..], out id);
    }

    private static void Add(SqlCommand c, string name, SqlDbType type, object? value, int size) => c.Parameters.Add(name, type, size).Value = value ?? DBNull.Value;
    private readonly record struct Owner(char Type, string Table, string UserKey, string ProfileKey, long Id);
}

public sealed record UserProfileUpdate(string? Username, string? CurrentPassword, string? NewPassword, string? ThemeCode, string? Introduction, string? AvatarDataBase64, string? AvatarContentType, string? AvatarFileName, bool RemoveAvatar = false);
public sealed record UserProfileThemeUpdate(string? ThemeCode);
