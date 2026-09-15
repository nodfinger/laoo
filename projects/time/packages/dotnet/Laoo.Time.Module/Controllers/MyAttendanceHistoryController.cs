using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Authorize]
[Route("api/time/my-attendance-history")]
public sealed class MyAttendanceHistoryController(IConfiguration configuration) : ControllerBase
{
    private const string MenuCode = "30002";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await CanView(connection, token)) return Forbid();
        var employeeId = await ResolveEmployee(connection, companyId, userId, token);

        return Ok(new
        {
            menuCode = MenuCode,
            caption = await Caption(connection, token),
            screenType = 3,
            view = true,
            employeeLinked = employeeId.HasValue,
        });
    }

    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] DateOnly? fromWorkDate,
        [FromQuery] DateOnly? toWorkDate,
        [FromQuery] string? statusCode,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30,
        CancellationToken token = default)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await CanView(connection, token)) return Forbid();

        var employeeId = await ResolveEmployee(connection, companyId, userId, token);
        if (!employeeId.HasValue)
            return Conflict(new { message = "ไม่สามารถแสดงประวัติการลงเวลาของฉันได้", description = "บัญชีผู้ใช้ยังไม่ได้ผูกกับพนักงานที่ใช้งานอยู่ กรุณาติดต่อผู้ดูแลระบบ" });

        var today = ThailandToday();
        var from = fromWorkDate ?? new DateOnly(today.Year, today.Month, 1);
        var to = toWorkDate ?? today;
        if (from > to)
            return BadRequest(new { message = "ช่วงวันที่ไม่ถูกต้อง", description = "วันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด" });
        if (page < 1 || pageSize is < 1 or > 30)
            return BadRequest(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง", description = "กรุณาระบุหน้าตั้งแต่ 1 และจำนวนรายการไม่เกิน 30" });

        var status = Clean(statusCode)?.ToUpperInvariant();
        if (status is not null and not ("COMPLETE" or "UNRESOLVED" or "DAY_OFF"))
            return BadRequest(new { message = "สถานะผลลงเวลาไม่ถูกต้อง", description = "กรุณาเลือกสถานะที่ระบบรองรับ" });

        const string where = """
WHERE R.CompanyID=@CompanyID AND R.EmployeeID=@EmployeeID AND R.IsCurrent=1
  AND R.WorkDate BETWEEN @FromWorkDate AND @ToWorkDate
  AND (@StatusCode IS NULL OR R.StatusCode=@StatusCode)
""";
        await using var count = new SqlCommand($"SELECT COUNT_BIG(1) FROM dbo.TDTMAttendanceResult R {where}", connection);
        Bind(count, companyId, employeeId.Value, from, to, status, 1, pageSize);
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));

        await using var command = new SqlCommand($"""
SELECT R.AttendanceResultID,R.WorkDate,R.StatusCode,R.ScheduledWorkMinutes,
       R.ActualWorkMinutes,R.LateMinutes,R.EarlyMinutes,R.UnresolvedReason,R.ResultVersion
FROM dbo.TDTMAttendanceResult R
{where}
ORDER BY R.WorkDate DESC,R.AttendanceResultID DESC
OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
""", connection);
        Bind(command, companyId, employeeId.Value, from, to, status, page, pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token))
        {
            items.Add(new
            {
                attendanceResultId = reader.GetInt64(0),
                workDate = DateOnly.FromDateTime(reader.GetDateTime(1)),
                statusCode = reader.GetString(2),
                scheduledWorkMinutes = reader.GetInt32(3),
                actualWorkMinutes = reader.GetInt32(4),
                lateMinutes = reader.GetInt32(5),
                earlyMinutes = reader.GetInt32(6),
                unresolvedReason = reader.IsDBNull(7) ? null : reader.GetString(7),
                resultVersion = reader.GetInt32(8),
            });
        }
        return Ok(new { total, page, pageSize, items });
    }

    private static void Bind(SqlCommand command, long companyId, long employeeId,
        DateOnly from, DateOnly to, string? status, int page, int pageSize)
    {
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@EmployeeID", SqlDbType.BigInt, employeeId);
        Add(command, "@FromWorkDate", SqlDbType.Date, from.ToDateTime(TimeOnly.MinValue));
        Add(command, "@ToWorkDate", SqlDbType.Date, to.ToDateTime(TimeOnly.MinValue));
        Add(command, "@StatusCode", SqlDbType.VarChar, status, 20);
        Add(command, "@Offset", SqlDbType.Int, (page - 1) * pageSize);
        Add(command, "@PageSize", SqlDbType.Int, pageSize);
    }

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private async Task<bool> CanView(SqlConnection connection, CancellationToken token) =>
        await CompanyMenuAccess.IsAllowedAsync(connection, User, MenuCode, "VIEW", token);

    private bool TryScope(out long companyId, out long userId)
    {
        companyId = 0;
        userId = 0;
        return string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase) &&
               long.TryParse(User.FindFirstValue("company_id"), out companyId) &&
               long.TryParse(User.FindFirstValue("user_id"), out userId) &&
               companyId > 0 && userId > 0;
    }

    private static async Task<long?> ResolveEmployee(SqlConnection connection, long companyId,
        long userId, CancellationToken token)
    {
        await using var command = new SqlCommand("""
SELECT TOP(1) E.EmployeeID
FROM dbo.TDADUserEmployee UE
JOIN dbo.TDADUser U ON U.CompanyID=UE.CompanyID AND U.UserID=UE.UserID AND U.IsActive=1
JOIN dbo.TDADEmployee E ON E.CompanyID=UE.CompanyID AND E.EmployeeID=UE.EmployeeID AND E.IsActive=1
WHERE UE.CompanyID=@CompanyID AND UE.UserID=@UserID AND UE.IsActive=1
ORDER BY UE.EmployeeID;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        var value = await command.ExecuteScalarAsync(token);
        return value is null ? null : Convert.ToInt64(value);
    }

    private static async Task<string> Caption(SqlConnection connection, CancellationToken token)
    {
        await using var command = new SqlCommand(
            "SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@MenuCode", connection);
        Add(command, "@MenuCode", SqlDbType.Char, MenuCode, 5);
        return Convert.ToString(await command.ExecuteScalarAsync(token)) ?? MenuCode;
    }

    private static DateOnly ThailandToday() => DateOnly.FromDateTime(
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow,
            TimeZoneInfo.FindSystemTimeZoneById("Asia/Bangkok")));

    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0)
    {
        var parameter = size == 0 ? command.Parameters.Add(name, type) : command.Parameters.Add(name, type, size);
        parameter.Value = value ?? DBNull.Value;
    }
}
