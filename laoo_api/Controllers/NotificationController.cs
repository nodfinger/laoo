using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts.Notifications;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/notifications")]
public sealed class NotificationController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => Claim("company_id");
    private long PartnerId => Claim("partner_id");
    private long UserId => Claim("user_id");
    private long Claim(string name) => long.TryParse(User.FindFirstValue(name), out var value) ? value : 0;

    [HttpGet("recipient-preference")]
    public async Task<IActionResult> Preference([FromQuery] long personId, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Scope(c, token) || !await Allowed(c, "VIEW", token)) return Forbid();
        const string sql = "SELECT P.CompanyID,P.PersonID,U.UserID,COALESCE(NP.NotifyInSystem,E.NotifyInSystem,CONVERT(bit,1)),CONVERT(bit,CASE WHEN U.UserID IS NOT NULL AND U.IsActive=1 AND COALESCE(NP.NotifyInSystem,E.NotifyInSystem,CONVERT(bit,1))=1 THEN 1 ELSE 0 END) FROM dbo.TDADPerson P OUTER APPLY(SELECT TOP(1) U.UserID,U.IsActive FROM dbo.TDADUser U WHERE U.CompanyID=P.CompanyID AND U.PersonID=P.PersonID ORDER BY U.IsActive DESC,U.UserID) U LEFT JOIN dbo.TDADPersonNotificationPreference NP ON NP.CompanyID=P.CompanyID AND NP.PersonID=P.PersonID LEFT JOIN dbo.TDADEmployee E ON E.CompanyID=P.CompanyID AND E.PersonID=P.PersonID WHERE P.CompanyID=@company AND P.PersonID=@person";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@person", SqlDbType.BigInt, personId);
        await using var r = await q.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound();
        return Ok(new NotificationPreferenceResponse(r.GetInt64(0), r.GetInt64(1), r.IsDBNull(2) ? null : r.GetInt64(2), r.GetBoolean(3), r.GetBoolean(4)));
    }

    [HttpPut("recipient-preference")]
    public async Task<IActionResult> UpdatePreference(NotificationPreferenceUpdateRequest request, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Scope(c, token) || !await Allowed(c, "EDIT", token)) return Forbid();
        const string sql = "MERGE dbo.TDADPersonNotificationPreference WITH(HOLDLOCK) AS T USING(SELECT @company CompanyID,@person PersonID) AS S ON T.CompanyID=S.CompanyID AND T.PersonID=S.PersonID WHEN MATCHED THEN UPDATE SET NotifyInSystem=@notify,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHEN NOT MATCHED THEN INSERT(CompanyID,PersonID,NotifyInSystem,CreateBy) VALUES(@company,@person,@notify,@user);";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@person", SqlDbType.BigInt, request.PersonId); Add(q, "@notify", SqlDbType.Bit, request.NotifyInSystem); Add(q, "@user", SqlDbType.BigInt, UserId);
        if (!await PersonBelongs(c, request.PersonId, token)) return NotFound();
        await q.ExecuteNonQueryAsync(token);
        return Ok(new { personId = request.PersonId, notifyInSystem = request.NotifyInSystem });
    }

    [HttpPost]
    public async Task<IActionResult> Create(NotificationCreateRequest request, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Scope(c, token)) return Forbid();
        if (request.CompanyId != CompanyId || string.IsNullOrWhiteSpace(request.SourceProject) || string.IsNullOrWhiteSpace(request.SourceType) || string.IsNullOrWhiteSpace(request.Title) || string.IsNullOrWhiteSpace(request.Message) || string.IsNullOrWhiteSpace(request.IdempotencyKey)) return BadRequest(new { message = "ข้อมูล Notification ไม่ครบ" });
        if (!await SourceAllowed(c, request.SourceProject.Trim(), token)) return Forbid();
        const string existingSql = "SELECT TOP(1) NotificationID,StatusCode FROM dbo.TDADNotification WHERE CompanyID=@company AND SourceProject=@project AND IdempotencyKey=@key";
        await using (var existing = new SqlCommand(existingSql, c)) { Add(existing, "@company", SqlDbType.BigInt, CompanyId); Add(existing, "@project", SqlDbType.NVarChar, request.SourceProject.Trim(), 50); Add(existing, "@key", SqlDbType.NVarChar, request.IdempotencyKey.Trim(), 200); await using var r = await existing.ExecuteReaderAsync(token); if (await r.ReadAsync(token)) return Ok(new { notificationId = r.GetInt64(0), status = r.GetString(1), duplicate = true }); }
        if (request.RecipientUserId.HasValue && await UserBelongsToAnotherCompany(c, request.RecipientUserId.Value, token)) return Forbid();
        var recipient = await Recipient(c, request.RecipientUserId, token);
        var status = recipient is { NotifyInSystem: true } ? "SENT" : "NO_CHANNEL";
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            const string insert = "INSERT dbo.TDADNotification(CompanyID,RecipientUserID,RecipientPersonID,SourceProject,SourceType,SourceID,Title,Message,PayloadJson,IdempotencyKey,StatusCode,SentDate,CreateBy) OUTPUT INSERTED.NotificationID VALUES(@company,@user,@person,@project,@type,@sourceId,@title,@message,@payload,@key,@status,CASE WHEN @status=N'SENT' THEN SYSUTCDATETIME() END,@createBy)";
            await using var cmd = new SqlCommand(insert, c, tx); Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@user", SqlDbType.BigInt, recipient?.UserId); Add(cmd, "@person", SqlDbType.BigInt, recipient?.PersonId); Add(cmd, "@project", SqlDbType.NVarChar, request.SourceProject.Trim(), 50); Add(cmd, "@type", SqlDbType.NVarChar, request.SourceType.Trim(), 80); Add(cmd, "@sourceId", SqlDbType.BigInt, request.SourceId); Add(cmd, "@title", SqlDbType.NVarChar, request.Title.Trim(), 200); Add(cmd, "@message", SqlDbType.NVarChar, request.Message.Trim(), 2000); Add(cmd, "@payload", SqlDbType.NVarChar, request.PayloadJson); Add(cmd, "@key", SqlDbType.NVarChar, request.IdempotencyKey.Trim(), 200); Add(cmd, "@status", SqlDbType.NVarChar, status, 20); Add(cmd, "@createBy", SqlDbType.BigInt, UserId);
            var id = Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
            await Audit(c, tx, id, status, status == "NO_CHANNEL" ? "ไม่มี User หรือปิดรับแจ้งเตือนในระบบ" : "บันทึก Notification ในระบบ", token);
            await tx.CommitAsync(token);
            return Ok(new { notificationId = id, status, duplicate = false });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627) { await tx.RollbackAsync(token); return Ok(new { status = "SENT", duplicate = true }); }
    }

    [HttpGet]
    public async Task<IActionResult> Inbox([FromQuery] bool unreadOnly = false, [FromQuery] int page = 1, [FromQuery] int pageSize = 50, CancellationToken token = default)
    {
        await using var c = await Open(token); if (!await Scope(c, token)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        const string sql = "SELECT N.NotificationID,N.SourceProject,N.SourceType,N.SourceID,N.Title,N.Message,N.PayloadJson,N.StatusCode,N.CreateDate,R.ReadDate FROM dbo.TDADNotification N LEFT JOIN dbo.TDADNotificationRead R ON R.CompanyID=N.CompanyID AND R.NotificationID=N.NotificationID AND R.UserID=@user WHERE N.CompanyID=@company AND N.RecipientUserID=@user AND (@unread=0 OR R.ReadDate IS NULL) ORDER BY N.CreateDate DESC OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@user", SqlDbType.BigInt, UserId); Add(q, "@unread", SqlDbType.Bit, unreadOnly); Add(q, "@offset", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@take", SqlDbType.Int, pageSize); var rows = new List<object>(); await using var r = await q.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) rows.Add(new { notificationId = r.GetInt64(0), sourceProject = r.GetString(1), sourceType = r.GetString(2), sourceId = r.IsDBNull(3) ? (long?)null : r.GetInt64(3), title = r.GetString(4), message = r.GetString(5), payloadJson = Text(r, 6), status = r.GetString(7), createDate = r.GetDateTime(8), readDate = r.IsDBNull(9) ? (DateTime?)null : r.GetDateTime(9) });
        return Ok(new { items = rows, page, pageSize });
    }

    [HttpPost("{id:long}/read")]
    public async Task<IActionResult> Read(long id, CancellationToken token)
    {
        await using var c = await Open(token); if (!await Scope(c, token)) return Forbid();
        const string sql = "IF NOT EXISTS(SELECT 1 FROM dbo.TDADNotification WHERE NotificationID=@id AND CompanyID=@company AND RecipientUserID=@user) THROW 53101,'NOTIFICATION_NOT_FOUND',1; INSERT dbo.TDADNotificationRead(CompanyID,NotificationID,UserID) SELECT @company,@id,@user WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADNotificationRead WHERE CompanyID=@company AND NotificationID=@id AND UserID=@user); INSERT dbo.TDADNotificationAudit(CompanyID,NotificationID,StatusCode,Detail,CreateBy) VALUES(@company,@id,N'READ',N'ผู้รับเปิดอ่าน Notification',@user);";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id); Add(q, "@user", SqlDbType.BigInt, UserId);
        try { await q.ExecuteNonQueryAsync(token); return Ok(new { notificationId = id, read = true }); } catch (SqlException e) when (e.Number == 53101) { return NotFound(); }
    }

    private async Task<(long UserId, long? PersonId, bool NotifyInSystem)?> Recipient(SqlConnection c, long? userId, CancellationToken token)
    {
        if (!userId.HasValue) return null;
        const string sql = "SELECT U.UserID,U.PersonID,COALESCE(NP.NotifyInSystem,E.NotifyInSystem,CONVERT(bit,1)) FROM dbo.TDADUser U LEFT JOIN dbo.TDADPersonNotificationPreference NP ON NP.CompanyID=U.CompanyID AND NP.PersonID=U.PersonID LEFT JOIN dbo.TDADEmployee E ON E.CompanyID=U.CompanyID AND E.PersonID=U.PersonID WHERE U.CompanyID=@company AND U.UserID=@user AND U.IsActive=1";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@user", SqlDbType.BigInt, userId); await using var r = await q.ExecuteReaderAsync(token); return await r.ReadAsync(token) ? (r.GetInt64(0), r.IsDBNull(1) ? (long?)null : r.GetInt64(1), r.GetBoolean(2)) : null;
    }
    private async Task<bool> SourceAllowed(SqlConnection c, string projectCode, CancellationToken token) { const string sql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADProject P JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=P.ProjectID AND CP.CompanyID=@company AND CP.PartnerID=@partner AND CP.IsEnabled=1 WHERE P.ProjectCode=@project AND P.IsActive=1) AND EXISTS(SELECT 1 FROM dbo.TDADUserProject UP JOIN dbo.TDADProject P ON P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.CompanyID=@company AND UP.IsActive=1 AND P.ProjectCode=@project) THEN 1 ELSE 0 END"; await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@partner", SqlDbType.BigInt, PartnerId); Add(q, "@user", SqlDbType.BigInt, UserId); Add(q, "@project", SqlDbType.NVarChar, projectCode, 50); return Convert.ToBoolean(await q.ExecuteScalarAsync(token)); }
    private async Task<bool> UserBelongsToAnotherCompany(SqlConnection c, long userId, CancellationToken token) { await using var q = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID<>@company) THEN 1 ELSE 0 END", c); Add(q, "@user", SqlDbType.BigInt, userId); Add(q, "@company", SqlDbType.BigInt, CompanyId); return Convert.ToBoolean(await q.ExecuteScalarAsync(token)); }
    private async Task<bool> PersonBelongs(SqlConnection c, long personId, CancellationToken token) { await using var q = new SqlCommand("SELECT COUNT(1) FROM dbo.TDADPerson WHERE CompanyID=@company AND PersonID=@person", c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@person", SqlDbType.BigInt, personId); return Convert.ToInt32(await q.ExecuteScalarAsync(token)) == 1; }
    private async Task Audit(SqlConnection c, SqlTransaction tx, long id, string status, string detail, CancellationToken token) { await using var q = new SqlCommand("INSERT dbo.TDADNotificationAudit(CompanyID,NotificationID,StatusCode,Detail,CreateBy) VALUES(@company,@id,@status,@detail,@user)", c, tx); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id); Add(q, "@status", SqlDbType.NVarChar, status, 20); Add(q, "@detail", SqlDbType.NVarChar, detail, 1000); Add(q, "@user", SqlDbType.BigInt, UserId); await q.ExecuteNonQueryAsync(token); }
    private async Task<bool> Scope(SqlConnection c, CancellationToken token) { return CompanyId > 0 && UserId > 0 && await PersonScope(c, token); }
    private async Task<bool> PersonScope(SqlConnection c, CancellationToken token) { await using var q = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1) THEN 1 ELSE 0 END", c); Add(q, "@user", SqlDbType.BigInt, UserId); Add(q, "@company", SqlDbType.BigInt, CompanyId); return Convert.ToBoolean(await q.ExecuteScalarAsync(token)); }
    private async Task<bool> Allowed(SqlConnection c, string action, CancellationToken token) => await CompanyProjectPermission.IsAllowedAsync(c, User, "13002", action, token) || await IsCompanyAdmin(c, token);
    private async Task<bool> IsCompanyAdmin(SqlConnection c, CancellationToken token) { await using var q = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsCompanyAdmin=1 AND IsActive=1) THEN 1 ELSE 0 END", c); Add(q, "@user", SqlDbType.BigInt, UserId); Add(q, "@company", SqlDbType.BigInt, CompanyId); return Convert.ToBoolean(await q.ExecuteScalarAsync(token)); }
    private Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); return OpenAsync(c, token); }
    private static async Task<SqlConnection> OpenAsync(SqlConnection c, CancellationToken token) { await c.OpenAsync(token); return c; }
    private static string? Text(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static void Add(SqlCommand c, string name, SqlDbType type, object? value, int size = 0) { var p = size > 0 ? c.Parameters.Add(name, type, size) : c.Parameters.Add(name, type); p.Value = value ?? DBNull.Value; }
}
