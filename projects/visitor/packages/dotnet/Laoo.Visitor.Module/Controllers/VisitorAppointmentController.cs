using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooVisitorModule.Controllers;

[ApiController]
[Authorize]
[Route("api/visitor/appointments")]
public sealed class VisitorAppointmentController(IConfiguration configuration) : ControllerBase
{
    private const string AppointmentMenu = "32001";
    private const string ApprovalMenu = "32002";
    private const string CheckInMenu = "31002";

    public sealed record CreateRequest(string VisitorName, string? Phone, DateTime AppointmentDate,
        string? VisitPurpose, string HostType, long? HostEmployeeId, long? HostResidentId,
        long? HostServiceCustomerId, long? HostTenantId, long? HostTenantContactId, long? ContactPointId, string? ContactPointNameSnapshot);
    public sealed record UpdateRequest(string VisitorName, string? Phone, DateTime AppointmentDate,
        string? VisitPurpose, long? ContactPointId, string? ContactPointNameSnapshot);
    public sealed record ApprovalRequest(string StatusCode, string? Note);

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid();
        await using var db = await Open(token);
        return Ok(new
        {
            view = await Can(db, AppointmentMenu, "VIEW", token),
            create = await Can(db, AppointmentMenu, "CREATE", token),
            edit = await Can(db, AppointmentMenu, "EDIT", token),
            delete = await Can(db, AppointmentMenu, "DELETE", token),
            approvalView = await Can(db, ApprovalMenu, "VIEW", token),
            approvalEdit = await Can(db, ApprovalMenu, "EDIT", token)
        });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, CancellationToken token,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, AppointmentMenu, "VIEW", token)) return Forbid();
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var cleanSearch = Clean(search) ?? string.Empty;
        await using var count = new SqlCommand("""
SELECT COUNT_BIG(1)
FROM dbo.TDTMVisitorAppointment
WHERE CompanyID=@CompanyID AND CreateBy=@UserID
  AND (@Search=N'' OR VisitorName LIKE N'%'+@Search+'%' OR Phone LIKE N'%'+@Search+'%');
""", db);
        Add(count, "@CompanyID", SqlDbType.BigInt, companyId); Add(count, "@UserID", SqlDbType.BigInt, userId);
        Add(count, "@Search", SqlDbType.NVarChar, cleanSearch, 200);
        var total = Convert.ToInt32(await count.ExecuteScalarAsync(token));
        await using var command = new SqlCommand("""
SELECT VisitorAppointmentID,VisitorName,Phone,AppointmentDate,VisitPurpose,HostNameSnapshot,
       ContactPointNameSnapshot,StatusCode,ApprovalNote,ApprovedDate
FROM dbo.TDTMVisitorAppointment
WHERE CompanyID=@CompanyID AND CreateBy=@UserID
  AND (@Search=N'' OR VisitorName LIKE N'%'+@Search+'%' OR Phone LIKE N'%'+@Search+'%')
ORDER BY AppointmentDate DESC,VisitorAppointmentID DESC
OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
""", db);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@UserID", SqlDbType.BigInt, userId);
        Add(command, "@Search", SqlDbType.NVarChar, cleanSearch, 200);
        Add(command, "@Offset", SqlDbType.Int, (page - 1) * pageSize); Add(command, "@PageSize", SqlDbType.Int, pageSize);
        return Ok(new { items = await ReadAppointments(command, token), total, page, pageSize });
    }

    [HttpGet("contact-points")]
    public async Task<IActionResult> ContactPoints(CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, AppointmentMenu, "VIEW", token)) return Forbid();
        await using var command = new SqlCommand("""
SELECT VisitorContactPointID,ContactPointCode,ContactPointName
FROM dbo.TDTMVisitorContactPoint
WHERE CompanyID=@CompanyID AND IsActive=1
ORDER BY ContactPointCode,ContactPointName,VisitorContactPointID;
""", db);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token))
            items.Add(new { contactPointId = reader.GetInt64(0), code = reader.GetString(1), name = reader.GetString(2) });
        return Ok(new { items });
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        if (!ValidVisitor(request.VisitorName, request.AppointmentDate, out var validation)) return BadRequest(new { message = validation });
        await using var db = await Open(token);
        if (!await Can(db, AppointmentMenu, "CREATE", token)) return Forbid();
        var contactPointName = await ActiveContactPointName(db, companyId, request.ContactPointId, token);
        if (contactPointName is null) return BadRequest(new { message = "กรุณาเลือกจุดติดต่อที่เปิดใช้งาน" });
        var identities = await CurrentHostIdentities(token);
        var hostType = Clean(request.HostType)?.ToUpperInvariant();
        if (!identities.Matches(hostType, request.HostEmployeeId, request.HostResidentId,
                request.HostServiceCustomerId, request.HostTenantContactId) ||
            hostType == "RENTAL_OFFICE" && !identities.MatchesTenant(request.HostTenantContactId, request.HostTenantId))
            return BadRequest(new { message = "ผู้รับรองต้องเป็นข้อมูลของผู้ Login เท่านั้น" });
        var hostName = ActorName(userId);
        await using var transaction = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            await using var command = new SqlCommand("""
INSERT dbo.TDTMVisitorAppointment
(CompanyID,VisitorName,Phone,AppointmentDate,VisitPurpose,HostType,HostEmployeeID,HostResidentID,
 HostServiceCustomerID,HostTenantID,HostTenantContactID,HostNameSnapshot,ContactPointNameSnapshot,CreateBy)
OUTPUT INSERTED.VisitorAppointmentID
VALUES(@CompanyID,@VisitorName,@Phone,@AppointmentDate,@VisitPurpose,@HostType,@EmployeeID,@ResidentID,
 @ServiceCustomerID,@TenantID,@TenantContactID,@HostName,@ContactPointName,@UserID);
""", db, transaction);
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@VisitorName", SqlDbType.NVarChar, Clean(request.VisitorName), 200);
            Add(command, "@Phone", SqlDbType.NVarChar, Clean(request.Phone), 50); Add(command, "@AppointmentDate", SqlDbType.DateTime2, request.AppointmentDate);
            Add(command, "@VisitPurpose", SqlDbType.NVarChar, Clean(request.VisitPurpose), 1000); Add(command, "@HostType", SqlDbType.VarChar, hostType, 20);
            Add(command, "@EmployeeID", SqlDbType.BigInt, request.HostEmployeeId); Add(command, "@ResidentID", SqlDbType.BigInt, request.HostResidentId);
            Add(command, "@ServiceCustomerID", SqlDbType.BigInt, request.HostServiceCustomerId); Add(command, "@TenantID", SqlDbType.BigInt, request.HostTenantId); Add(command, "@TenantContactID", SqlDbType.BigInt, request.HostTenantContactId);
            Add(command, "@HostName", SqlDbType.NVarChar, hostName, 200); Add(command, "@ContactPointName", SqlDbType.NVarChar, contactPointName, 200);
            Add(command, "@UserID", SqlDbType.BigInt, userId);
            var id = Convert.ToInt64(await command.ExecuteScalarAsync(token));
            await Audit(db, transaction, companyId, id, null, "PENDING", null, userId, hostName, token);
            await transaction.CommitAsync(token);
            return Ok(new { visitorAppointmentId = id, statusCode = "PENDING" });
        }
        catch { await transaction.RollbackAsync(token); throw; }
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, UpdateRequest request, CancellationToken token) =>
        await ChangePending(id, request, false, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Cancel(long id, CancellationToken token) =>
        await ChangePending(id, null, true, token);

    [HttpGet("pending-approval")]
    public async Task<IActionResult> PendingApproval(CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, ApprovalMenu, "VIEW", token)) return Forbid();
        var identities = await CurrentHostIdentities(token);
        await using var command = new SqlCommand("""
SELECT TOP(100) VisitorAppointmentID,VisitorName,Phone,AppointmentDate,VisitPurpose,HostType,
       HostEmployeeID,HostResidentID,HostServiceCustomerID,HostTenantID,HostTenantContactID,HostNameSnapshot,ContactPointNameSnapshot,StatusCode
FROM dbo.TDTMVisitorAppointment WHERE CompanyID=@CompanyID AND StatusCode='PENDING'
ORDER BY AppointmentDate,VisitorAppointmentID;
""", db);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        return Ok(new { items = await ReadHostAppointments(command, identities, token) });
    }

    [HttpPost("{id:long}/approval")]
    public async Task<IActionResult> Approval(long id, ApprovalRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var status = Clean(request.StatusCode)?.ToUpperInvariant();
        if (status is not ("APPROVED" or "REJECTED")) return BadRequest(new { message = "สถานะการอนุมัติไม่ถูกต้อง" });
        if (request.Note?.Length > 1000) return BadRequest(new { message = "หมายเหตุต้องไม่เกิน 1,000 ตัวอักษร" });
        await using var db = await Open(token);
        if (!await Can(db, ApprovalMenu, "EDIT", token)) return Forbid();
        var identities = await CurrentHostIdentities(token);
        await using var transaction = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var appointment = await FindForHost(db, transaction, companyId, id, identities, token);
            if (appointment is null) return NotFound(new { message = "ไม่พบรายการรออนุมัติของคุณ" });
            var actorName = ActorName(userId);
            await using var update = new SqlCommand("""
UPDATE dbo.TDTMVisitorAppointment SET StatusCode=@Status,ApprovalNote=@Note,ApprovedByUserID=@UserID,
 ApprovedByNameSnapshot=@Name,ApprovedDate=SYSUTCDATETIME(),UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE CompanyID=@CompanyID AND VisitorAppointmentID=@Id AND StatusCode='PENDING';
""", db, transaction);
            Add(update, "@Status", SqlDbType.VarChar, status, 20); Add(update, "@Note", SqlDbType.NVarChar, Clean(request.Note), 1000);
            Add(update, "@UserID", SqlDbType.BigInt, userId); Add(update, "@Name", SqlDbType.NVarChar, actorName, 200);
            Add(update, "@CompanyID", SqlDbType.BigInt, companyId); Add(update, "@Id", SqlDbType.BigInt, id);
            if (await update.ExecuteNonQueryAsync(token) != 1) return Conflict(new { message = "รายการนี้ไม่ได้อยู่ในสถานะรออนุมัติแล้ว" });
            await Audit(db, transaction, companyId, id, "PENDING", status, Clean(request.Note), userId, actorName, token);
            await transaction.CommitAsync(token);
            return Ok(new { visitorAppointmentId = id, statusCode = status });
        }
        catch { await transaction.RollbackAsync(token); throw; }
    }

    [HttpGet("approved-lookup")]
    public async Task<IActionResult> ApprovedLookup([FromQuery] string? search, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        var term = Clean(search);
        if (term is null) return BadRequest(new { message = "กรุณาระบุชื่อหรือเบอร์โทรศัพท์ผู้มาติดต่อ" });
        await using var db = await Open(token);
        if (!await Can(db, CheckInMenu, "VIEW", token)) return Forbid();
        await using var command = new SqlCommand("""
SELECT TOP(30) VisitorAppointmentID,VisitorName,Phone,AppointmentDate,VisitPurpose,HostType,HostEmployeeID,HostResidentID,
       HostServiceCustomerID,HostTenantID,HostTenantContactID,HostNameSnapshot,ContactPointNameSnapshot,StatusCode
FROM dbo.TDTMVisitorAppointment
WHERE CompanyID=@CompanyID AND StatusCode='APPROVED' AND AppointmentDate>=CONVERT(date,SYSUTCDATETIME())
  AND (VisitorName LIKE N'%'+@Search+'%' OR Phone LIKE N'%'+@Search+'%')
ORDER BY AppointmentDate,VisitorAppointmentID;
""", db);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@Search", SqlDbType.NVarChar, term, 200);
        return Ok(new { items = await ReadHostAppointments(command, null, token) });
    }

    private async Task<IActionResult> ChangePending(long id, UpdateRequest? request, bool cancel, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        if (!cancel && !ValidVisitor(request!.VisitorName, request.AppointmentDate, out var validation)) return BadRequest(new { message = validation });
        await using var db = await Open(token);
        if (!await Can(db, AppointmentMenu, cancel ? "DELETE" : "EDIT", token)) return Forbid();
        var contactPointName = cancel ? null : await ActiveContactPointName(db, companyId, request!.ContactPointId, token);
        if (!cancel && contactPointName is null) return BadRequest(new { message = "กรุณาเลือกจุดติดต่อที่เปิดใช้งาน" });
        await using var transaction = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var actorName = ActorName(userId);
            var sql = cancel ? """
UPDATE dbo.TDTMVisitorAppointment SET StatusCode='CANCELLED',CancelledDate=SYSUTCDATETIME(),UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE CompanyID=@CompanyID AND VisitorAppointmentID=@Id AND CreateBy=@UserID AND StatusCode='PENDING';
""" : """
UPDATE dbo.TDTMVisitorAppointment SET VisitorName=@VisitorName,Phone=@Phone,AppointmentDate=@AppointmentDate,
 VisitPurpose=@VisitPurpose,ContactPointNameSnapshot=@ContactPointName,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE CompanyID=@CompanyID AND VisitorAppointmentID=@Id AND CreateBy=@UserID AND StatusCode='PENDING';
""";
            await using var command = new SqlCommand(sql, db, transaction);
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@Id", SqlDbType.BigInt, id); Add(command, "@UserID", SqlDbType.BigInt, userId);
            if (!cancel)
            {
                Add(command, "@VisitorName", SqlDbType.NVarChar, Clean(request!.VisitorName), 200); Add(command, "@Phone", SqlDbType.NVarChar, Clean(request.Phone), 50);
                Add(command, "@AppointmentDate", SqlDbType.DateTime2, request.AppointmentDate); Add(command, "@VisitPurpose", SqlDbType.NVarChar, Clean(request.VisitPurpose), 1000);
                Add(command, "@ContactPointName", SqlDbType.NVarChar, contactPointName, 200);
            }
            if (await command.ExecuteNonQueryAsync(token) != 1) return Conflict(new { message = "แก้ไขหรือยกเลิกได้เฉพาะนัดหมายของตนเองที่รออนุมัติ" });
            await Audit(db, transaction, companyId, id, "PENDING", cancel ? "CANCELLED" : "PENDING", null, userId, actorName, token);
            await transaction.CommitAsync(token);
            return Ok(new { visitorAppointmentId = id, statusCode = cancel ? "CANCELLED" : "PENDING" });
        }
        catch { await transaction.RollbackAsync(token); throw; }
    }

    private async Task<AppointmentHost?> FindForHost(SqlConnection db, SqlTransaction transaction, long companyId, long id, HostIdentitySet identities, CancellationToken token)
    {
        await using var command = new SqlCommand("""
SELECT HostType,HostEmployeeID,HostResidentID,HostServiceCustomerID,HostTenantContactID
FROM dbo.TDTMVisitorAppointment WITH (UPDLOCK,HOLDLOCK)
WHERE CompanyID=@CompanyID AND VisitorAppointmentID=@Id AND StatusCode='PENDING';
""", db, transaction);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@Id", SqlDbType.BigInt, id);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return null;
        var row = new AppointmentHost(reader.GetString(0), Long(reader, 1), Long(reader, 2), Long(reader, 3), Long(reader, 4));
        return identities.Matches(row.HostType, row.EmployeeId, row.ResidentId, row.ServiceCustomerId, row.TenantContactId) ? row : null;
    }

    private async Task<HostIdentitySet> CurrentHostIdentities(CancellationToken token)
    {
        using var client = new HttpClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, $"{Request.Scheme}://{Request.Host}/api/company/current-user/host-identities");
        if (Request.Headers.TryGetValue("Authorization", out var authorization)) request.Headers.TryAddWithoutValidation("Authorization", authorization.ToString());
        using var response = await client.SendAsync(request, token);
        if (!response.IsSuccessStatusCode) throw new InvalidOperationException("ไม่สามารถตรวจสอบสิทธิ์ผู้รับรองได้ กรุณาเข้าสู่ระบบใหม่");
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync(token));
        static HashSet<long> Values(JsonElement root, string key) => root.TryGetProperty(key, out var array) && array.ValueKind == JsonValueKind.Array
            ? array.EnumerateArray().Where(x => x.TryGetInt64(out _)).Select(x => x.GetInt64()).ToHashSet() : [];
        var root = document.RootElement;
        var tenantContacts = root.TryGetProperty("tenantContacts", out var contacts) && contacts.ValueKind == JsonValueKind.Array
            ? contacts.EnumerateArray().Where(value => value.TryGetProperty("tenantContactId", out _) && value.TryGetProperty("tenantId", out _))
                .ToDictionary(value => value.GetProperty("tenantContactId").GetInt64(), value => value.GetProperty("tenantId").GetInt64())
            : new Dictionary<long, long>();
        return new HostIdentitySet(Values(root, "employeeIds"), Values(root, "residentIds"), Values(root, "serviceCustomerIds"), Values(root, "tenantContactIds"), tenantContacts);
    }

    private static async Task<List<object>> ReadAppointments(SqlCommand command, CancellationToken token)
    {
        await using var reader = await command.ExecuteReaderAsync(token); var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new { visitorAppointmentId = reader.GetInt64(0), visitorName = reader.GetString(1), phone = Text(reader, 2), appointmentDate = reader.GetDateTime(3), visitPurpose = Text(reader, 4), hostName = reader.GetString(5), contactPointName = Text(reader, 6), statusCode = reader.GetString(7), approvalNote = Text(reader, 8), approvedDate = Date(reader, 9) });
        return items;
    }

    private static async Task<List<object>> ReadHostAppointments(SqlCommand command, HostIdentitySet? filter, CancellationToken token)
    {
        await using var reader = await command.ExecuteReaderAsync(token); var items = new List<object>();
        while (await reader.ReadAsync(token))
        {
            var host = new AppointmentHost(reader.GetString(5), Long(reader, 6), Long(reader, 7), Long(reader, 8), Long(reader, 10));
            if (filter is not null && !filter.Matches(host.HostType, host.EmployeeId, host.ResidentId, host.ServiceCustomerId, host.TenantContactId)) continue;
            items.Add(new { visitorAppointmentId = reader.GetInt64(0), visitorName = reader.GetString(1), phone = Text(reader, 2), appointmentDate = reader.GetDateTime(3), visitPurpose = Text(reader, 4), hostType = host.HostType, hostEmployeeId = host.EmployeeId, hostResidentId = host.ResidentId, hostServiceCustomerId = host.ServiceCustomerId, hostTenantId = Long(reader, 9), hostTenantContactId = host.TenantContactId, hostName = reader.GetString(11), contactPointName = Text(reader, 12), statusCode = reader.GetString(13) });
        }
        return items;
    }

    private static async Task Audit(SqlConnection db, SqlTransaction transaction, long companyId, long id, string? from, string to, string? note, long userId, string actorName, CancellationToken token)
    {
        await using var command = new SqlCommand("INSERT dbo.TDTMVisitorAppointmentAudit(CompanyID,VisitorAppointmentID,FromStatusCode,ToStatusCode,NoteText,ActorUserID,ActorNameSnapshot) VALUES(@CompanyID,@Id,@From,@To,@Note,@UserID,@Name);", db, transaction);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@Id", SqlDbType.BigInt, id); Add(command, "@From", SqlDbType.VarChar, from, 20); Add(command, "@To", SqlDbType.VarChar, to, 20); Add(command, "@Note", SqlDbType.NVarChar, note, 1000); Add(command, "@UserID", SqlDbType.BigInt, userId); Add(command, "@Name", SqlDbType.NVarChar, actorName, 200); await command.ExecuteNonQueryAsync(token);
    }

    private static async Task<string?> ActiveContactPointName(SqlConnection db, long companyId, long? pointId, CancellationToken token)
    {
        if (pointId is null || pointId <= 0) return null;
        await using var command = new SqlCommand("SELECT ContactPointName FROM dbo.TDTMVisitorContactPoint WHERE CompanyID=@CompanyID AND VisitorContactPointID=@PointID AND IsActive=1;", db);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@PointID", SqlDbType.BigInt, pointId);
        return (await command.ExecuteScalarAsync(token)) as string;
    }

    private async Task<SqlConnection> Open(CancellationToken token) { var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await db.OpenAsync(token); return db; }
    private Task<bool> Can(SqlConnection db, string menu, string action, CancellationToken token) => CompanyMenuAccess.IsAllowedAsync(db, User, menu, action, token);
    private bool Scope(out long companyId, out long userId) { companyId = userId = 0; return User.FindFirstValue("user_type") == "COMPANY_USER" && long.TryParse(User.FindFirstValue("company_id"), out companyId) && long.TryParse(User.FindFirstValue("user_id"), out userId) && companyId > 0 && userId > 0; }
    private string ActorName(long userId) => User.FindFirstValue(ClaimTypes.Name) ?? User.FindFirstValue("name") ?? userId.ToString();
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static long? Long(SqlDataReader reader, int i) => reader.IsDBNull(i) ? null : reader.GetInt64(i);
    private static string? Text(SqlDataReader reader, int i) => reader.IsDBNull(i) ? null : reader.GetString(i);
    private static DateTime? Date(SqlDataReader reader, int i) => reader.IsDBNull(i) ? null : reader.GetDateTime(i);
    private static bool ValidVisitor(string? name, DateTime date, out string message) { message = string.Empty; if (Clean(name) is null) { message = "กรุณาระบุชื่อผู้มาติดต่อ"; return false; } if (date < DateTime.UtcNow.Date.AddDays(-1)) { message = "วันนัดหมายต้องไม่เป็นวันย้อนหลัง"; return false; } return true; }
    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0) { var parameter = size == 0 ? command.Parameters.Add(name, type) : command.Parameters.Add(name, type, size); parameter.Value = value ?? DBNull.Value; }

    private sealed record AppointmentHost(string HostType, long? EmployeeId, long? ResidentId, long? ServiceCustomerId, long? TenantContactId);
    private sealed record HostIdentitySet(HashSet<long> EmployeeIds, HashSet<long> ResidentIds, HashSet<long> ServiceCustomerIds, HashSet<long> TenantContactIds, Dictionary<long, long> TenantContacts)
    {
        public bool Matches(string? hostType, long? employeeId, long? residentId, long? serviceCustomerId, long? tenantContactId) => hostType switch { "EMPLOYEE" => employeeId is not null && EmployeeIds.Contains(employeeId.Value), "RESIDENT" or "VILLAGE" => residentId is not null && ResidentIds.Contains(residentId.Value), "SERVICE_CUSTOMER" => serviceCustomerId is not null && ServiceCustomerIds.Contains(serviceCustomerId.Value), "RENTAL_OFFICE" => tenantContactId is not null && TenantContactIds.Contains(tenantContactId.Value), _ => false };
        public bool MatchesTenant(long? tenantContactId, long? tenantId) => tenantContactId is not null && tenantId is not null && TenantContacts.TryGetValue(tenantContactId.Value, out var expected) && expected == tenantId.Value;
    }
}
