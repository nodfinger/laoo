using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Authorize]
[Route("api/time/attendance")]
public sealed class AttendanceController(IConfiguration configuration) : ControllerBase
{
    private const string MenuCode = "27001";
    private const string RawEventsMenuCode = "25001";
    private const string DailyResultsMenuCode = "25002";
    public sealed record EventRequest(string SourceEventId, string DeviceCode, DateTime EventDateTime, string? PayloadHash);
    public sealed record ImportRequest(string IdempotencyKey, string SourceCode, IReadOnlyList<EventRequest> Events);

    [HttpPost("events/import")]
    public async Task<IActionResult> Import(ImportRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        if (string.IsNullOrWhiteSpace(request.IdempotencyKey) || request.IdempotencyKey.Trim().Length > 100 || string.IsNullOrWhiteSpace(request.SourceCode) || request.SourceCode.Trim().Length > 50 || request.Events is null || request.Events.Count is < 1 or > 1000) return BadRequest(new { message = "ข้อมูล Batch นำเข้าไม่ถูกต้อง" });
        await using var connection = await Open(token); if (!await Can(connection, "EDIT", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var previous = await Batch(connection, transaction, companyId, request.IdempotencyKey.Trim(), token);
            if (previous.HasValue) { await transaction.CommitAsync(token); return Ok(new { attendanceImportBatchId = previous.Value, replayed = true }); }
            var normalized = new List<(EventRequest Event, string Source, string Device, byte[] Payload, byte[] Fingerprint, long Employee)>();
            var seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (var item in request.Events)
            {
                if (string.IsNullOrWhiteSpace(item.SourceEventId) || item.SourceEventId.Trim().Length > 150 || string.IsNullOrWhiteSpace(item.DeviceCode) || item.DeviceCode.Trim().Length > 100) throw new InvalidOperationException("รายการเวลาใน Batch ไม่ถูกต้อง");
                var source = request.SourceCode.Trim().ToUpperInvariant(); var device = item.DeviceCode.Trim(); var occurred = DateTime.SpecifyKind(item.EventDateTime, DateTimeKind.Unspecified);
                var payload = Hash(item.PayloadHash?.Trim() ?? string.Empty); var fingerprint = Hash($"{source}|{item.SourceEventId.Trim()}|{device}|{occurred:O}|{Convert.ToHexString(payload)}");
                if (!seen.Add(Convert.ToHexString(fingerprint))) throw new InvalidOperationException("มีข้อมูลเวลาซ้ำภายใน Batch เดียวกัน");
                var employee = await EmployeeForDevice(connection, transaction, companyId, device, occurred, token) ?? throw new InvalidOperationException($"ไม่พบรหัสที่เครื่อง {device} ที่มีผลในเวลาที่นำเข้า");
                normalized.Add((item, source, device, payload, fingerprint, employee));
            }
            var batchId = await InsertBatch(connection, transaction, companyId, request, userId, 0, 0, token);
            var accepted = 0; var skipped = 0; var affected = new HashSet<(long Employee, DateOnly Date)>();
            foreach (var item in normalized)
            {
                if (await Exists(connection, transaction, companyId, item.Fingerprint, token)) { skipped++; continue; }
                await InsertEvent(connection, transaction, batchId, companyId, userId, item, token); accepted++;
                var date = DateOnly.FromDateTime(item.Event.EventDateTime); affected.Add((item.Employee, date)); affected.Add((item.Employee, date.AddDays(-1)));
            }
            await UpdateBatch(connection, transaction, batchId, accepted, skipped, token);
            foreach (var work in affected) await AttendanceCalculator.RecalculateAsync(connection, transaction, companyId, work.Employee, work.Date, userId, token);
            await transaction.CommitAsync(token); return Ok(new { attendanceImportBatchId = batchId, acceptedCount = accepted, skippedCount = skipped });
        }
        catch (InvalidOperationException exception) { await transaction.RollbackAsync(token); return Conflict(new { message = exception.Message }); }
    }

    [HttpGet("results/actions")]
    public async Task<IActionResult> ResultActions(CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, DailyResultsMenuCode, "VIEW", token)) return Forbid();
        return Ok(new
        {
            menuCode = DailyResultsMenuCode,
            caption = await Caption(connection, DailyResultsMenuCode, token),
            screenType = 3,
            view = true,
        });
    }

    [HttpGet("results")]
    public async Task<IActionResult> Results(
        [FromQuery] DateOnly? fromWorkDate,
        [FromQuery] DateOnly? toWorkDate,
        [FromQuery] long? employeeId,
        [FromQuery] DateOnly? workDate,
        [FromQuery] string? employee,
        [FromQuery] string? statusCode,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30,
        CancellationToken token = default)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, DailyResultsMenuCode, "VIEW", token)) return Forbid();

        var from = workDate ?? fromWorkDate ?? ThailandToday();
        var to = workDate ?? toWorkDate ?? ThailandToday();
        if (from > to) return BadRequest(new { message = "วันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด" });
        if (page < 1) page = 1;
        pageSize = Math.Clamp(pageSize, 1, 30);

        const string where = """
WHERE R.CompanyID=@CompanyID AND R.IsCurrent=1
  AND R.WorkDate>=@FromWorkDate AND R.WorkDate<=@ToWorkDate
  AND (@EmployeeID IS NULL OR R.EmployeeID=@EmployeeID)
  AND (@Employee IS NULL OR E.EmployeeCode LIKE N'%'+@Employee+'%' OR E.FullName LIKE N'%'+@Employee+'%')
  AND (@StatusCode IS NULL OR R.StatusCode=@StatusCode)
  AND
  (
    EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@CompanyID AND U.UserID=@UserID AND U.IsActive=1 AND U.IsCompanyAdmin=1)
    OR EXISTS
    (
      SELECT 1 FROM dbo.TDTMEmployeeDataScopeGrant G
      WHERE G.CompanyID=@CompanyID AND G.IsActive=1
        AND G.EffectiveFrom<=@BusinessNow AND (G.EffectiveTo IS NULL OR G.EffectiveTo>@BusinessNow)
        AND
        (
          G.UserID=@UserID
          OR G.RoleGroupID IN
          (
            SELECT ERG.RoleGroupID
            FROM dbo.TDADUserEmployee UE
            JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
              AND ERG.EffectiveFrom<=@BusinessDate AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=@BusinessDate)
            WHERE UE.CompanyID=@CompanyID AND UE.UserID=@UserID AND UE.IsActive=1
          )
        )
        AND
        (
          G.ScopeTypeCode='ALL'
          OR (G.ScopeTypeCode='SELF' AND EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE WHERE UE.CompanyID=@CompanyID AND UE.UserID=@UserID AND UE.EmployeeID=E.EmployeeID AND UE.IsActive=1))
          OR (G.ScopeTypeCode='DIVISION' AND G.ScopeReferenceID=E.DivisionOrgUnitID)
          OR (G.ScopeTypeCode='DEPARTMENT' AND G.ScopeReferenceID=E.DepartmentOrgUnitID)
        )
    )
  )
""";
        var total = await CountResults(connection, where, companyId, userId, from, to, employeeId, employee, statusCode, token);
        await using var command = new SqlCommand($"""
SELECT R.AttendanceResultID,R.EmployeeID,E.EmployeeCode,E.FullName,R.WorkDate,R.StatusCode,
       R.ScheduledWorkMinutes,R.ActualWorkMinutes,R.LateMinutes,R.EarlyMinutes,R.UnresolvedReason,R.ResultVersion
FROM dbo.TDTMAttendanceResult R
JOIN dbo.TDADEmployee E ON E.EmployeeID=R.EmployeeID AND E.CompanyID=R.CompanyID
{where}
ORDER BY R.WorkDate DESC,E.EmployeeCode,R.AttendanceResultID DESC
OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
""", connection);
        BindResultFilters(command, companyId, userId, from, to, employeeId, employee, statusCode, page, pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token))
        {
            items.Add(new
            {
                attendanceResultId = reader.GetInt64(0),
                employeeId = reader.GetInt64(1),
                employeeCode = reader.GetString(2),
                fullName = reader.GetString(3),
                workDate = DateOnly.FromDateTime(reader.GetDateTime(4)),
                statusCode = reader.GetString(5),
                scheduledWorkMinutes = reader.GetInt32(6),
                actualWorkMinutes = reader.GetInt32(7),
                lateMinutes = reader.GetInt32(8),
                earlyMinutes = reader.GetInt32(9),
                unresolvedReason = reader.IsDBNull(10) ? null : reader.GetString(10),
                resultVersion = reader.GetInt32(11),
            });
        }
        return Ok(new { total, page, pageSize, items });
    }

    private static async Task<long> CountResults(SqlConnection connection, string where,
        long companyId, long userId, DateOnly from, DateOnly to, long? employeeId, string? employee,
        string? statusCode, CancellationToken token)
    {
        await using var command = new SqlCommand($"""
SELECT COUNT_BIG(1)
FROM dbo.TDTMAttendanceResult R
JOIN dbo.TDADEmployee E ON E.EmployeeID=R.EmployeeID AND E.CompanyID=R.CompanyID
{where}
""", connection);
        BindResultFilters(command, companyId, userId, from, to, employeeId, employee, statusCode, 1, 30);
        return Convert.ToInt64(await command.ExecuteScalarAsync(token));
    }

    private static void BindResultFilters(SqlCommand command, long companyId, long userId,
        DateOnly from, DateOnly to, long? employeeId, string? employee, string? statusCode, int page, int pageSize)
    {
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        Add(command, "@FromWorkDate", SqlDbType.Date, from.ToDateTime(TimeOnly.MinValue));
        Add(command, "@ToWorkDate", SqlDbType.Date, to.ToDateTime(TimeOnly.MinValue));
        Add(command, "@EmployeeID", SqlDbType.BigInt, employeeId);
        Add(command, "@Employee", SqlDbType.NVarChar, Clean(employee), 150);
        Add(command, "@StatusCode", SqlDbType.VarChar, Clean(statusCode)?.ToUpperInvariant(), 20);
        Add(command, "@BusinessNow", SqlDbType.DateTime2, ThailandNow());
        Add(command, "@BusinessDate", SqlDbType.Date, ThailandToday().ToDateTime(TimeOnly.MinValue));
        Add(command, "@Offset", SqlDbType.Int, (page - 1) * pageSize);
        Add(command, "@PageSize", SqlDbType.Int, pageSize);
    }

    [HttpGet("events/actions")]
    public async Task<IActionResult> EventActions(CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        var canView = await Can(connection, RawEventsMenuCode, "VIEW", token);
        if (!canView) return Forbid();
        return Ok(new
        {
            menuCode = RawEventsMenuCode,
            caption = await Caption(connection, RawEventsMenuCode, token),
            screenType = 3,
            view = true,
        });
    }

    [HttpGet("events")]
    public async Task<IActionResult> Events(
        [FromQuery] DateTime? fromDateTime,
        [FromQuery] DateTime? toDateTime,
        [FromQuery] string? employee,
        [FromQuery] string? deviceCode,
        [FromQuery] string? sourceCode,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30,
        CancellationToken token = default)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, RawEventsMenuCode, "VIEW", token)) return Forbid();

        var businessToday = ThailandToday();
        var from = DateTime.SpecifyKind(
            fromDateTime ?? businessToday.ToDateTime(TimeOnly.MinValue),
            DateTimeKind.Unspecified);
        var to = DateTime.SpecifyKind(
            toDateTime ?? businessToday.AddDays(1).ToDateTime(TimeOnly.MinValue).AddTicks(-1),
            DateTimeKind.Unspecified);
        if (from > to) return BadRequest(new { message = "วันเวลาเริ่มต้นต้องไม่เกินวันเวลาสิ้นสุด" });
        if (page < 1) page = 1;
        pageSize = Math.Clamp(pageSize, 1, 30);

        const string where = """
WHERE A.CompanyID=@CompanyID
  AND A.EventDateTime>=@FromDateTime AND A.EventDateTime<=@ToDateTime
  AND (@Employee IS NULL OR E.EmployeeCode LIKE N'%'+@Employee+'%' OR E.FullName LIKE N'%'+@Employee+'%')
  AND (@DeviceCode IS NULL OR A.DeviceCode=@DeviceCode)
  AND (@SourceCode IS NULL OR A.SourceCode=@SourceCode)
  AND
  (
    EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@CompanyID AND U.UserID=@UserID AND U.IsActive=1 AND U.IsCompanyAdmin=1)
    OR EXISTS
    (
      SELECT 1
      FROM dbo.TDTMEmployeeDataScopeGrant G
      WHERE G.CompanyID=@CompanyID AND G.IsActive=1
        AND G.EffectiveFrom<=@BusinessNow AND (G.EffectiveTo IS NULL OR G.EffectiveTo>@BusinessNow)
        AND
        (
          G.UserID=@UserID
          OR G.RoleGroupID IN
          (
            SELECT ERG.RoleGroupID
            FROM dbo.TDADUserEmployee UE
            JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
              AND ERG.EffectiveFrom<=@BusinessDate AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=@BusinessDate)
            WHERE UE.CompanyID=@CompanyID AND UE.UserID=@UserID AND UE.IsActive=1
          )
        )
        AND
        (
          G.ScopeTypeCode='ALL'
          OR (G.ScopeTypeCode='SELF' AND EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE WHERE UE.CompanyID=@CompanyID AND UE.UserID=@UserID AND UE.EmployeeID=E.EmployeeID AND UE.IsActive=1))
          OR (G.ScopeTypeCode='DIVISION' AND G.ScopeReferenceID=E.DivisionOrgUnitID)
          OR (G.ScopeTypeCode='DEPARTMENT' AND G.ScopeReferenceID=E.DepartmentOrgUnitID)
        )
    )
  )
""";
        var total = await CountEvents(connection, where, companyId, userId, from, to, employee, deviceCode, sourceCode, token);
        await using var command = new SqlCommand($"""
SELECT A.AttendanceEventID,A.EventDateTime,A.DeviceCode,E.EmployeeCode,E.FullName,A.SourceCode,A.SourceEventID,A.CreateDate
FROM dbo.TDTMAttendanceEvent A
JOIN dbo.TDADEmployee E ON E.CompanyID=A.CompanyID AND E.EmployeeID=A.EmployeeID
{where}
ORDER BY A.EventDateTime DESC,A.AttendanceEventID DESC
OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
""", connection);
        BindEventFilters(command, companyId, userId, from, to, employee, deviceCode, sourceCode, page, pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token))
        {
            items.Add(new
            {
                attendanceEventId = reader.GetInt64(0),
                eventDateTime = reader.GetDateTime(1),
                deviceCode = reader.GetString(2),
                employeeCode = reader.GetString(3),
                fullName = reader.GetString(4),
                sourceCode = reader.GetString(5),
                sourceEventId = reader.GetString(6),
                importedDateTime = reader.GetDateTime(7),
            });
        }
        return Ok(new { total, page, pageSize, items });
    }

    private static async Task<long> CountEvents(SqlConnection connection, string where,
        long companyId, long userId, DateTime from, DateTime to, string? employee,
        string? deviceCode, string? sourceCode, CancellationToken token)
    {
        await using var command = new SqlCommand($"""
SELECT COUNT_BIG(1)
FROM dbo.TDTMAttendanceEvent A
JOIN dbo.TDADEmployee E ON E.CompanyID=A.CompanyID AND E.EmployeeID=A.EmployeeID
{where}
""", connection);
        BindEventFilters(command, companyId, userId, from, to, employee, deviceCode, sourceCode, 1, 30);
        return Convert.ToInt64(await command.ExecuteScalarAsync(token));
    }

    private static void BindEventFilters(SqlCommand command, long companyId, long userId,
        DateTime from, DateTime to, string? employee, string? deviceCode, string? sourceCode,
        int page, int pageSize)
    {
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        Add(command, "@FromDateTime", SqlDbType.DateTime2, from);
        Add(command, "@ToDateTime", SqlDbType.DateTime2, to);
        Add(command, "@Employee", SqlDbType.NVarChar, Clean(employee), 150);
        Add(command, "@DeviceCode", SqlDbType.NVarChar, Clean(deviceCode), 100);
        Add(command, "@SourceCode", SqlDbType.VarChar, Clean(sourceCode)?.ToUpperInvariant(), 50);
        Add(command, "@BusinessNow", SqlDbType.DateTime2, ThailandNow());
        Add(command, "@BusinessDate", SqlDbType.Date, ThailandToday().ToDateTime(TimeOnly.MinValue));
        Add(command, "@Offset", SqlDbType.Int, (page - 1) * pageSize);
        Add(command, "@PageSize", SqlDbType.Int, pageSize);
    }
    private async Task<long?> Batch(SqlConnection c,SqlTransaction tx,long company,string key,CancellationToken t){await using var q=new SqlCommand("SELECT AttendanceImportBatchID FROM dbo.TDTMAttendanceImportBatch WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND IdempotencyKey=@K",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@K",SqlDbType.NVarChar,key,100);var x=await q.ExecuteScalarAsync(t);return x is null?null:Convert.ToInt64(x);}
    private static async Task<long?> EmployeeForDevice(SqlConnection c,SqlTransaction tx,long company,string device,DateTime at,CancellationToken t){await using var q=new SqlCommand("SELECT TOP(1) EmployeeID FROM dbo.TDTMAttendanceDeviceCodeAssignment WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND DeviceCode=@D AND EffectiveFromDateTime<=@T AND(EffectiveToDateTime IS NULL OR EffectiveToDateTime>@T) ORDER BY EffectiveFromDateTime DESC",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@D",SqlDbType.NVarChar,device,100);Add(q,"@T",SqlDbType.DateTime2,at);var x=await q.ExecuteScalarAsync(t);return x is null?null:Convert.ToInt64(x);}
    private static async Task<long> InsertBatch(SqlConnection c,SqlTransaction tx,long company,ImportRequest x,long user,int accepted,int skipped,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMAttendanceImportBatch(CompanyID,SourceCode,IdempotencyKey,EventCount,AcceptedCount,SkippedCount,CreateBy) OUTPUT INSERTED.AttendanceImportBatchID VALUES(@C,@S,@K,@N,@A,@X,@U)",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@S",SqlDbType.VarChar,x.SourceCode.Trim().ToUpperInvariant(),50);Add(q,"@K",SqlDbType.NVarChar,x.IdempotencyKey.Trim(),100);Add(q,"@N",SqlDbType.Int,x.Events.Count);Add(q,"@A",SqlDbType.Int,accepted);Add(q,"@X",SqlDbType.Int,skipped);Add(q,"@U",SqlDbType.BigInt,user);return Convert.ToInt64(await q.ExecuteScalarAsync(t));}
    private static async Task UpdateBatch(SqlConnection c,SqlTransaction tx,long id,int accepted,int skipped,CancellationToken t){await using var q=new SqlCommand("UPDATE dbo.TDTMAttendanceImportBatch SET AcceptedCount=@A,SkippedCount=@S WHERE AttendanceImportBatchID=@I",c,tx);Add(q,"@A",SqlDbType.Int,accepted);Add(q,"@S",SqlDbType.Int,skipped);Add(q,"@I",SqlDbType.BigInt,id);await q.ExecuteNonQueryAsync(t);}
    private static async Task<bool> Exists(SqlConnection c,SqlTransaction tx,long company,byte[] fingerprint,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMAttendanceEvent WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND EventFingerprint=@F",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@F",SqlDbType.VarBinary,fingerprint,32);return Convert.ToInt64(await q.ExecuteScalarAsync(t))>0;}
    private static async Task InsertEvent(SqlConnection c,SqlTransaction tx,long batch,long company,long user,(EventRequest Event,string Source,string Device,byte[] Payload,byte[] Fingerprint,long Employee) x,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMAttendanceEvent(AttendanceImportBatchID,CompanyID,EmployeeID,SourceCode,SourceEventID,DeviceCode,EventDateTime,PayloadHash,EventFingerprint,CreateBy)VALUES(@B,@C,@E,@S,@I,@D,@T,@P,@F,@U)",c,tx);Add(q,"@B",SqlDbType.BigInt,batch);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,x.Employee);Add(q,"@S",SqlDbType.VarChar,x.Source,50);Add(q,"@I",SqlDbType.NVarChar,x.Event.SourceEventId.Trim(),150);Add(q,"@D",SqlDbType.NVarChar,x.Device,100);Add(q,"@T",SqlDbType.DateTime2,DateTime.SpecifyKind(x.Event.EventDateTime,DateTimeKind.Unspecified));Add(q,"@P",SqlDbType.VarBinary,x.Payload,32);Add(q,"@F",SqlDbType.VarBinary,x.Fingerprint,32);Add(q,"@U",SqlDbType.BigInt,user);await q.ExecuteNonQueryAsync(t);}
    private async Task<bool> Can(SqlConnection c, string action, CancellationToken t) =>
        await Can(c, MenuCode, action, t);

    private async Task<bool> Can(SqlConnection c, string menuCode, string action, CancellationToken t) =>
        await CompanyMenuAccess.IsAllowedAsync(c, User, menuCode, action, t);

    private async Task<SqlConnection> Open(CancellationToken t)
    {
        var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(t);
        return c;
    }

    private bool Scope(out long company, out long user)
    {
        company = 0;
        user = 0;
        return string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase) &&
               long.TryParse(User.FindFirstValue("company_id"), out company) &&
               long.TryParse(User.FindFirstValue("user_id"), out user) && company > 0 && user > 0;
    }

    private static async Task<string> Caption(SqlConnection connection, string menuCode, CancellationToken token)
    {
        await using var command = new SqlCommand(
            "SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@MenuCode", connection);
        Add(command, "@MenuCode", SqlDbType.Char, menuCode, 5);
        return Convert.ToString(await command.ExecuteScalarAsync(token)) ?? menuCode;
    }

    private static DateTime ThailandNow() => TimeZoneInfo.ConvertTimeFromUtc(
        DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("Asia/Bangkok"));

    private static DateOnly ThailandToday() => DateOnly.FromDateTime(ThailandNow());

    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static byte[] Hash(string x) => SHA256.HashData(Encoding.UTF8.GetBytes(x));

    private static void Add(SqlCommand q, string n, SqlDbType t, object? v, int s = 0)
    {
        var p = s == 0 ? q.Parameters.Add(n, t) : q.Parameters.Add(n, t, s);
        p.Value = v ?? DBNull.Value;
    }
}
