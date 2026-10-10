using System.Data;
using System.Security.Claims;
using Laoo.Booking;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

public sealed record BookingMemberLogin(string CompanyCode, string MemberCode, string Password);
public sealed record BookingMemberPassword(string CurrentPassword, string NewPassword);
public sealed record BookingMemberCredential(string NewPassword, bool IsActive = true);

[ApiController, Route("api/booking/member")]
public sealed class BookingMemberAuthController(
    IConfiguration config, PasswordService passwords, JwtTokenService tokens) : ControllerBase
{
    private async Task<SqlConnection> Open(CancellationToken ct)
    {
        var db = new SqlConnection(config.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        return db;
    }
    private static SqlCommand Cmd(SqlConnection db, SqlTransaction? tx, string sql,
        params (string, object?)[] values)
    {
        var command = new SqlCommand(sql, db, tx);
        foreach (var (name, value) in values) command.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return command;
    }
    private static bool ValidPassword(string? value) =>
        value is { Length: >= 12 and <= 256 } && value.Any(char.IsUpper)
        && value.Any(char.IsLower) && value.Any(char.IsDigit)
        && value.Any(c => !char.IsLetterOrDigit(c));
    private bool Verify(string code, string hash, string password)
    {
        try { return passwords.VerifyPassword(code, hash, password); }
        catch (FormatException) { return false; }
    }
    private IActionResult Failed() => Unauthorized(new { message = "เข้าสู่ระบบสมาชิกไม่สำเร็จ",
        description = "ตรวจสอบรหัสบริษัท รหัสสมาชิก และรหัสผ่าน" });
    private bool Scope(out long company, out long member, out int version)
    {
        company = member = 0; version = 0;
        return User.FindFirstValue("user_type") == "BOOKING_MEMBER"
            && User.FindFirstValue("login_mode") == "BOOKING_MEMBER"
            && User.FindFirstValue("project_code") == "LAOO_BOOKING"
            && long.TryParse(User.FindFirstValue("company_id"), out company) && company > 0
            && long.TryParse(User.FindFirstValue("member_id"), out member) && member > 0
            && int.TryParse(User.FindFirstValue("credential_version"), out version) && version > 0
            && User.FindFirst("user_id") is null;
    }
    private static async Task<bool> Subscription(SqlConnection db, long company, CancellationToken ct)
    {
        await using var command = Cmd(db, null, """
SELECT COUNT(*) FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_BOOKING' AND P.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE S.CompanyID=@company AND S.IsCurrent=1
AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND (
    (S.StatusCode IN(N'ACTIVE',N'TRIAL')
     AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
    OR (S.StatusCode=N'EXPIRED'
        OR (S.StatusCode IN(N'ACTIVE',N'TRIAL')
            AND S.ExpireDate<CONVERT(date,SYSUTCDATETIME())))
)
""", ("@company", company));
        return Convert.ToInt32(await command.ExecuteScalarAsync(ct)) > 0;
    }
    private async Task<bool> Current(SqlConnection db, long company, long member, int version, CancellationToken ct,
        bool requireChangedPassword = false)
    {
        if (!await Subscription(db, company, ct)) return false;
        await using var command = Cmd(db, null, """
SELECT COUNT(*) FROM dbo.TDBKMemberCredential K
JOIN dbo.TDBKMember M ON M.CompanyID=K.CompanyID AND M.MemberID=K.MemberID AND M.IsActive=1
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID AND P.IsActive=1
WHERE K.CompanyID=@company AND K.MemberID=@member AND K.TokenVersion=@version AND K.IsActive=1
AND (@requireChanged=0 OR K.MustChangePassword=0)
""", ("@company", company), ("@member", member), ("@version", version),
            ("@requireChanged", requireChangedPassword));
        return Convert.ToInt32(await command.ExecuteScalarAsync(ct)) > 0;
    }

    [AllowAnonymous, EnableRateLimiting("authentication"), HttpPost("login")]
    public async Task<IActionResult> Login(BookingMemberLogin input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.CompanyCode) || input.CompanyCode.Length > 50
            || string.IsNullOrWhiteSpace(input.MemberCode) || input.MemberCode.Length > 30
            || string.IsNullOrEmpty(input.Password) || input.Password.Length > 256) return Failed();
        await using var db = await Open(ct);
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await using var command = Cmd(db, tx, """
SELECT M.MemberID,M.CompanyID,M.MemberCode,P.FullName,M.PersonID,
K.PasswordHash,K.FailedLoginCount,K.LockedUntil,K.TokenVersion,K.MustChangePassword,J.ProjectID
FROM dbo.TDBKMemberCredential K WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDBKMember M ON M.CompanyID=K.CompanyID AND M.MemberID=K.MemberID AND M.IsActive=1
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID AND P.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=M.CompanyID AND C.CompanyCode=@companyCode AND C.IsActive=1
JOIN dbo.TDADProject J ON J.ProjectCode=N'LAOO_BOOKING' AND J.IsActive=1
WHERE M.MemberCode=@memberCode AND K.IsActive=1
""", ("@companyCode", input.CompanyCode.Trim()), ("@memberCode", input.MemberCode.Trim()));
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) { await reader.DisposeAsync(); await tx.RollbackAsync(ct); return Failed(); }
        var id = reader.GetInt64(0); var company = reader.GetInt64(1);
        var code = reader.GetString(2); var name = reader.GetString(3); var person = reader.GetInt64(4);
        var hash = reader.GetString(5); var failed = reader.GetInt32(6);
        var locked = reader.IsDBNull(7) ? (DateTime?)null : reader.GetDateTime(7);
        var version = reader.GetInt32(8); var mustChange = reader.GetBoolean(9); var project = reader.GetInt64(10);
        await reader.DisposeAsync();
        if (locked > DateTime.UtcNow) { await tx.RollbackAsync(ct); return Failed(); }
        if (!Verify(code, hash, input.Password))
        {
            await using var fail = Cmd(db, tx, """
UPDATE dbo.TDBKMemberCredential SET FailedLoginCount=FailedLoginCount+1,
LockedUntil=CASE WHEN FailedLoginCount+1>=5 THEN DATEADD(minute,15,SYSUTCDATETIME()) ELSE NULL END
WHERE CompanyID=@company AND MemberID=@member
""", ("@company", company), ("@member", id));
            await fail.ExecuteNonQueryAsync(ct); await tx.CommitAsync(ct); return Failed();
        }
        await using (var success = Cmd(db, tx, """
UPDATE dbo.TDBKMemberCredential SET FailedLoginCount=0,LockedUntil=NULL
WHERE CompanyID=@company AND MemberID=@member
""", ("@company", company), ("@member", id)))
            await success.ExecuteNonQueryAsync(ct);
        await tx.CommitAsync(ct);
        if (!await Subscription(db, company, ct)) return Failed();
        var token = tokens.CreateToken(new AuthenticatedUser(
            $"booking-member:{company}:{id}", "BOOKING_MEMBER", "BOOKING_MEMBER",
            null, null, null, null, company, null, project, "LAOO_BOOKING",
            code, name, false, PersonId: person, CredentialVersion: version, MemberId: id));
        return Ok(new { accessToken = token.AccessToken, expiresAt = token.ExpiresAt,
            mustChangePassword = mustChange, member = new { id, code, name } });
    }

    [Authorize, HttpGet("me")]
    public async Task<IActionResult> Me(CancellationToken ct)
    {
        if (!Scope(out var company, out var member, out var version)) return Forbid();
        await using var db = await Open(ct);
        if (!await Current(db, company, member, version, ct)) return Forbid();
        await using var command = Cmd(db, null, """
SELECT M.MemberID id,M.MemberCode code,P.FullName name,M.TierCode tierCode,
M.StartsOn startsOn,M.ExpiresOn expiresOn,K.MustChangePassword mustChangePassword,C.TimeAlert timeAlert
FROM dbo.TDBKMember M JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID
JOIN dbo.TDBKMemberCredential K ON K.CompanyID=M.CompanyID AND K.MemberID=M.MemberID
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=M.CompanyID AND C.IsActive=1
WHERE M.CompanyID=@company AND M.MemberID=@member
""", ("@company", company), ("@member", member));
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) return Forbid();
        return Ok(new { id = reader.GetInt64(0), code = reader.GetString(1), name = reader.GetString(2),
            tierCode = reader.GetString(3), startsOn = reader.GetDateTime(4),
            expiresOn = reader.IsDBNull(5) ? (DateTime?)null : reader.GetDateTime(5),
            mustChangePassword = reader.GetBoolean(6), timeAlert = reader.GetInt32(7) });
    }

    [Authorize, HttpGet("history")]
    public async Task<IActionResult> History([FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default)
    {
        if (!Scope(out var company, out var member, out var version)) return Forbid();
        if (page < 1 || pageSize is < 1 or > 50 || page > int.MaxValue / pageSize) return BadRequest();
        await using var db = await Open(ct);
        if (!await Current(db, company, member, version, ct, requireChangedPassword: true)) return Forbid();
        await using var count = Cmd(db, null, """
SELECT COUNT(*) FROM dbo.TDBKBooking WHERE CompanyID=@company AND MemberID=@member
""", ("@company", company), ("@member", member));
        var total = Convert.ToInt32(await count.ExecuteScalarAsync(ct));
        await using var command = Cmd(db, null, """
SELECT B.BookingID id,B.BookingNo number,B.StartsAt startsAt,B.EndsAt endsAt,
B.StatusCode status,B.TotalAmount amount,
STRING_AGG(CONVERT(nvarchar(max),S.ServiceName),N', ') services,
MAX(U.UsedAt) usedAt
FROM dbo.TDBKBooking B
LEFT JOIN dbo.TDBKBookingService L ON L.CompanyID=B.CompanyID AND L.BookingID=B.BookingID
LEFT JOIN dbo.TDBKService S ON S.CompanyID=L.CompanyID AND S.ServiceID=L.ServiceID
LEFT JOIN dbo.TDBKUsage U ON U.CompanyID=L.CompanyID AND U.BookingID=L.BookingID AND U.LineID=L.LineID
WHERE B.CompanyID=@company AND B.MemberID=@member
GROUP BY B.BookingID,B.BookingNo,B.StartsAt,B.EndsAt,B.StatusCode,B.TotalAmount
ORDER BY B.StartsAt DESC,B.BookingID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY
""", ("@company", company), ("@member", member), ("@offset", (page - 1) * pageSize), ("@size", pageSize));
        var items = new List<object>();
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            items.Add(new { id = reader.GetInt64(0), number = reader.GetString(1),
                startsAt = reader.GetDateTime(2), endsAt = reader.GetDateTime(3),
                status = reader.GetString(4), amount = reader.GetDecimal(5),
                services = reader.IsDBNull(6) ? "" : reader.GetString(6),
                usedAt = reader.IsDBNull(7) ? (DateTime?)null : reader.GetDateTime(7) });
        return Ok(new { items, total, page, pageSize });
    }

    [Authorize, EnableRateLimiting("authentication"), HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(BookingMemberPassword input, CancellationToken ct)
    {
        if (!Scope(out var company, out var member, out var version)) return Forbid();
        if (string.IsNullOrEmpty(input.CurrentPassword) || input.CurrentPassword.Length > 256
            || !ValidPassword(input.NewPassword)) return BadRequest(new { message = "รหัสผ่านใหม่ไม่ถูกต้อง" });
        await using var db = await Open(ct);
        if (!await Current(db, company, member, version, ct)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await using var command = Cmd(db, tx, """
SELECT M.MemberCode,K.PasswordHash FROM dbo.TDBKMemberCredential K WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDBKMember M ON M.CompanyID=K.CompanyID AND M.MemberID=K.MemberID
WHERE K.CompanyID=@company AND K.MemberID=@member AND K.TokenVersion=@version AND K.IsActive=1
""", ("@company", company), ("@member", member), ("@version", version));
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) { await reader.DisposeAsync(); return Forbid(); }
        var code = reader.GetString(0); var hash = reader.GetString(1); await reader.DisposeAsync();
        if (!Verify(code, hash, input.CurrentPassword)) { await tx.RollbackAsync(ct); return Failed(); }
        if (Verify(code, hash, input.NewPassword)) { await tx.RollbackAsync(ct); return BadRequest(new { message = "รหัสผ่านใหม่ต้องต่างจากเดิม" }); }
        await using var save = Cmd(db, tx, """
UPDATE dbo.TDBKMemberCredential SET PasswordHash=@hash,TokenVersion=TokenVersion+1,
MustChangePassword=0,FailedLoginCount=0,LockedUntil=NULL,UpdatedAt=SYSUTCDATETIME()
WHERE CompanyID=@company AND MemberID=@member AND TokenVersion=@version
""", ("@hash", passwords.HashPassword(code, input.NewPassword)),
            ("@company", company), ("@member", member), ("@version", version));
        await save.ExecuteNonQueryAsync(ct); await tx.CommitAsync(ct);
        return Ok(new { saved = true, reauthenticate = true });
    }

    [Authorize, HttpPut("/api/company/booking/members/{member:long}/credential")]
    public async Task<IActionResult> SetCredential(long member, BookingMemberCredential input, CancellationToken ct)
    {
        if (!BookingAccess.Scope(User, out var company, out var actor)) return Forbid();
        if (!ValidPassword(input.NewPassword)) return BadRequest(new { message = "รหัสผ่านต้องยาว 12–256 ตัว มีพิมพ์ใหญ่ พิมพ์เล็ก ตัวเลข และอักขระพิเศษ" });
        await using var db = await Open(ct);
        if (!await BookingAccess.Can(db, User, "61005", "EDIT", ct)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await using var find = Cmd(db, tx, """
SELECT MemberCode FROM dbo.TDBKMember WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@company AND MemberID=@member AND IsActive=1
""", ("@company", company), ("@member", member));
        var code = await find.ExecuteScalarAsync(ct) as string;
        if (code is null) { await tx.RollbackAsync(ct); return NotFound(); }
        await using var save = Cmd(db, tx, """
MERGE dbo.TDBKMemberCredential WITH(HOLDLOCK) AS T
USING (SELECT @company CompanyID,@member MemberID) AS S
ON T.CompanyID=S.CompanyID AND T.MemberID=S.MemberID
WHEN MATCHED THEN UPDATE SET PasswordHash=@hash,IsActive=@active,
MustChangePassword=1,FailedLoginCount=0,LockedUntil=NULL,
TokenVersion=T.TokenVersion+1,UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@actor
WHEN NOT MATCHED THEN INSERT(CompanyID,MemberID,PasswordHash,IsActive,UpdatedBy)
VALUES(@company,@member,@hash,@active,@actor);
""", ("@company", company), ("@member", member),
            ("@hash", passwords.HashPassword(code, input.NewPassword)),
            ("@active", input.IsActive), ("@actor", actor));
        await save.ExecuteNonQueryAsync(ct); await tx.CommitAsync(ct);
        return Ok(new { saved = true, mustChangePassword = true });
    }
}
