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

    [HttpGet("results")]
    public async Task<IActionResult> Results([FromQuery] long? employeeId, [FromQuery] DateOnly? workDate, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid(); await using var c = await Open(token); if (!await Can(c, "VIEW", token)) return Forbid();
        await using var q = new SqlCommand("SELECT R.AttendanceResultID,R.EmployeeID,E.EmployeeCode,E.FullName,R.WorkDate,R.StatusCode,R.ScheduledWorkMinutes,R.ActualWorkMinutes,R.LateMinutes,R.EarlyMinutes,R.UnresolvedReason,R.ResultVersion FROM dbo.TDTMAttendanceResult R JOIN dbo.TDADEmployee E ON E.EmployeeID=R.EmployeeID AND E.CompanyID=R.CompanyID WHERE R.CompanyID=@C AND R.IsCurrent=1 AND(@E IS NULL OR R.EmployeeID=@E) AND(@D IS NULL OR R.WorkDate=@D) ORDER BY R.WorkDate DESC,E.EmployeeCode", c); Add(q,"@C",SqlDbType.BigInt,companyId);Add(q,"@E",SqlDbType.BigInt,employeeId);Add(q,"@D",SqlDbType.Date,workDate?.ToDateTime(TimeOnly.MinValue)); await using var r=await q.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new{attendanceResultId=r.GetInt64(0),employeeId=r.GetInt64(1),employeeCode=r.GetString(2),fullName=r.GetString(3),workDate=DateOnly.FromDateTime(r.GetDateTime(4)),statusCode=r.GetString(5),scheduledWorkMinutes=r.GetInt32(6),actualWorkMinutes=r.GetInt32(7),lateMinutes=r.GetInt32(8),earlyMinutes=r.GetInt32(9),unresolvedReason=r.IsDBNull(10)?null:r.GetString(10),resultVersion=r.GetInt32(11)});return Ok(new{items});
    }
    private async Task<long?> Batch(SqlConnection c,SqlTransaction tx,long company,string key,CancellationToken t){await using var q=new SqlCommand("SELECT AttendanceImportBatchID FROM dbo.TDTMAttendanceImportBatch WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND IdempotencyKey=@K",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@K",SqlDbType.NVarChar,key,100);var x=await q.ExecuteScalarAsync(t);return x is null?null:Convert.ToInt64(x);}
    private static async Task<long?> EmployeeForDevice(SqlConnection c,SqlTransaction tx,long company,string device,DateTime at,CancellationToken t){await using var q=new SqlCommand("SELECT TOP(1) EmployeeID FROM dbo.TDTMAttendanceDeviceCodeAssignment WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND DeviceCode=@D AND EffectiveFromDateTime<=@T AND(EffectiveToDateTime IS NULL OR EffectiveToDateTime>@T) ORDER BY EffectiveFromDateTime DESC",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@D",SqlDbType.NVarChar,device,100);Add(q,"@T",SqlDbType.DateTime2,at);var x=await q.ExecuteScalarAsync(t);return x is null?null:Convert.ToInt64(x);}
    private static async Task<long> InsertBatch(SqlConnection c,SqlTransaction tx,long company,ImportRequest x,long user,int accepted,int skipped,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMAttendanceImportBatch(CompanyID,SourceCode,IdempotencyKey,EventCount,AcceptedCount,SkippedCount,CreateBy) OUTPUT INSERTED.AttendanceImportBatchID VALUES(@C,@S,@K,@N,@A,@X,@U)",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@S",SqlDbType.VarChar,x.SourceCode.Trim().ToUpperInvariant(),50);Add(q,"@K",SqlDbType.NVarChar,x.IdempotencyKey.Trim(),100);Add(q,"@N",SqlDbType.Int,x.Events.Count);Add(q,"@A",SqlDbType.Int,accepted);Add(q,"@X",SqlDbType.Int,skipped);Add(q,"@U",SqlDbType.BigInt,user);return Convert.ToInt64(await q.ExecuteScalarAsync(t));}
    private static async Task UpdateBatch(SqlConnection c,SqlTransaction tx,long id,int accepted,int skipped,CancellationToken t){await using var q=new SqlCommand("UPDATE dbo.TDTMAttendanceImportBatch SET AcceptedCount=@A,SkippedCount=@S WHERE AttendanceImportBatchID=@I",c,tx);Add(q,"@A",SqlDbType.Int,accepted);Add(q,"@S",SqlDbType.Int,skipped);Add(q,"@I",SqlDbType.BigInt,id);await q.ExecuteNonQueryAsync(t);}
    private static async Task<bool> Exists(SqlConnection c,SqlTransaction tx,long company,byte[] fingerprint,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMAttendanceEvent WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND EventFingerprint=@F",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@F",SqlDbType.VarBinary,fingerprint,32);return Convert.ToInt64(await q.ExecuteScalarAsync(t))>0;}
    private static async Task InsertEvent(SqlConnection c,SqlTransaction tx,long batch,long company,long user,(EventRequest Event,string Source,string Device,byte[] Payload,byte[] Fingerprint,long Employee) x,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMAttendanceEvent(AttendanceImportBatchID,CompanyID,EmployeeID,SourceCode,SourceEventID,DeviceCode,EventDateTime,PayloadHash,EventFingerprint,CreateBy)VALUES(@B,@C,@E,@S,@I,@D,@T,@P,@F,@U)",c,tx);Add(q,"@B",SqlDbType.BigInt,batch);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,x.Employee);Add(q,"@S",SqlDbType.VarChar,x.Source,50);Add(q,"@I",SqlDbType.NVarChar,x.Event.SourceEventId.Trim(),150);Add(q,"@D",SqlDbType.NVarChar,x.Device,100);Add(q,"@T",SqlDbType.DateTime2,DateTime.SpecifyKind(x.Event.EventDateTime,DateTimeKind.Unspecified));Add(q,"@P",SqlDbType.VarBinary,x.Payload,32);Add(q,"@F",SqlDbType.VarBinary,x.Fingerprint,32);Add(q,"@U",SqlDbType.BigInt,user);await q.ExecuteNonQueryAsync(t);}
    private async Task<bool> Can(SqlConnection c,string action,CancellationToken t)=>await CompanyMenuAccess.IsAllowedAsync(c,User,MenuCode,action,t); private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}private bool Scope(out long company,out long user){company=0;user=0;return string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}private static byte[] Hash(string x)=>SHA256.HashData(Encoding.UTF8.GetBytes(x));private static void Add(SqlCommand q,string n,SqlDbType t,object? v,int s=0){var p=s==0?q.Parameters.Add(n,t):q.Parameters.Add(n,t,s);p.Value=v??DBNull.Value;}
}
