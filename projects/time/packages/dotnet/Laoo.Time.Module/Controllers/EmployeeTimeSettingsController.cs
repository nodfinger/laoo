using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Authorize]
[Route("api/time/employee-settings")]
public sealed class EmployeeTimeSettingsController(IConfiguration configuration)
    : ControllerBase
{
    private const string MenuCode = "28001";

    public sealed record UpdateRequest(
        bool RequiresAttendance,
        string? DeviceCode,
        DateOnly EffectiveFrom,
        string Reason,
        string? RequirementRowVersion,
        string? DeviceCodeRowVersion);

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        if (!TryScope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        return Ok(new
        {
            menuCode = MenuCode,
            caption = await Caption(connection, token),
            screenType = 2,
            view = await CompanyMenuAccess.IsAllowedAsync(
                connection, User, MenuCode, "VIEW", token),
            edit = await CompanyMenuAccess.IsAllowedAsync(
                connection, User, MenuCode, "EDIT", token),
            create = false,
            delete = false,
        });
    }

    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] string? search,
        [FromQuery] bool? isActive,
        [FromQuery] string? requirementCode,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30,
        CancellationToken token = default)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        if (page < 1 || pageSize is < 1 or > 100)
            return BadRequest(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง" });

        requirementCode = Clean(requirementCode)?.ToUpperInvariant();
        if (requirementCode is not null and not "REQUIRED" and not "EXEMPT")
            return BadRequest(new { message = "สถานะการลงเวลาทำงานไม่ถูกต้อง" });

        await using var connection = await Open(token);
        if (!await CompanyMenuAccess.IsAllowedAsync(
                connection, User, MenuCode, "VIEW", token))
            return Forbid();

        search = Clean(search);
        const string fromSql = """
FROM dbo.TDADEmployee E
OUTER APPLY
(
    SELECT TOP (1) R.AttendanceRequirementID,R.RequirementCode,
           R.EffectiveFrom,R.EffectiveTo,R.Reason,
           CONVERT(varchar(32),R.RowVersion,2) RowVersion
    FROM dbo.TDTMAttendanceRequirement R
    WHERE R.CompanyID=E.CompanyID AND R.EmployeeID=E.EmployeeID
      AND R.EffectiveFrom<=CONVERT(date,GETDATE())
      AND (R.EffectiveTo IS NULL OR R.EffectiveTo>=CONVERT(date,GETDATE()))
    ORDER BY R.EffectiveFrom DESC,R.AttendanceRequirementID DESC
) AR
OUTER APPLY
(
    SELECT TOP (1) D.DeviceCodeAssignmentID,D.DeviceCode,
           D.EffectiveFromDateTime,D.EffectiveToDateTime,
           CONVERT(varchar(32),D.RowVersion,2) RowVersion
    FROM dbo.TDTMAttendanceDeviceCodeAssignment D
    WHERE D.CompanyID=E.CompanyID AND D.EmployeeID=E.EmployeeID
      AND D.EffectiveFromDateTime<=GETDATE()
      AND (D.EffectiveToDateTime IS NULL OR D.EffectiveToDateTime>GETDATE())
    ORDER BY D.EffectiveFromDateTime DESC,D.DeviceCodeAssignmentID DESC
) DC
WHERE E.CompanyID=@CompanyID
  AND (@IsActive IS NULL OR E.IsActive=@IsActive)
  AND (@RequirementCode IS NULL OR ISNULL(AR.RequirementCode,'REQUIRED')=@RequirementCode)
  AND (@Search IS NULL OR E.EmployeeCode LIKE N'%'+@Search+N'%'
       OR E.FullName LIKE N'%'+@Search+N'%'
       OR E.NickName LIKE N'%'+@Search+N'%'
       OR DC.DeviceCode LIKE N'%'+@Search+N'%')
  AND
  (
      EXISTS
      (
          SELECT 1 FROM dbo.TDADUser U
          WHERE U.CompanyID=@CompanyID AND U.UserID=@UserID
            AND U.IsActive=1 AND U.IsCompanyAdmin=1
      )
      OR EXISTS
      (
          SELECT 1
          FROM dbo.TDTMEmployeeDataScopeGrant G
          WHERE G.CompanyID=@CompanyID AND G.IsActive=1
            AND G.EffectiveFrom<=GETDATE()
            AND (G.EffectiveTo IS NULL OR G.EffectiveTo>GETDATE())
            AND
            (
                G.UserID=@UserID
                OR G.RoleGroupID IN
                (
                    SELECT ERG.RoleGroupID
                    FROM dbo.TDADUserEmployee UE
                    JOIN dbo.TDADEmployeeRoleGroup ERG
                      ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
                     AND ERG.EffectiveFrom<=CONVERT(date,GETDATE())
                     AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,GETDATE()))
                    WHERE UE.CompanyID=@CompanyID AND UE.UserID=@UserID
                      AND UE.IsActive=1
                )
            )
            AND
            (
                G.ScopeTypeCode='ALL'
                OR
                (
                    G.ScopeTypeCode='SELF' AND EXISTS
                    (
                        SELECT 1 FROM dbo.TDADUserEmployee UE
                        WHERE UE.CompanyID=@CompanyID AND UE.UserID=@UserID
                          AND UE.EmployeeID=E.EmployeeID AND UE.IsActive=1
                    )
                )
            )
      )
  )
""";

        await using var count = new SqlCommand(
            $"SELECT COUNT_BIG(1) {fromSql}", connection);
        BindFilters(count, companyId, userId, search, isActive, requirementCode);
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));

        await using var command = new SqlCommand($"""
SELECT E.EmployeeID,E.EmployeeCode,E.FullName,E.NickName,E.IsActive,
       ISNULL(AR.RequirementCode,'REQUIRED') RequirementCode,
       AR.EffectiveFrom,AR.EffectiveTo,AR.Reason,AR.RowVersion RequirementRowVersion,
       DC.DeviceCode,DC.EffectiveFromDateTime,DC.RowVersion DeviceCodeRowVersion,
       CASE WHEN EXISTS
       (
           SELECT 1 FROM dbo.TDADUserEmployee UE
           JOIN dbo.TDADUser U ON U.UserID=UE.UserID AND U.CompanyID=UE.CompanyID
           WHERE UE.CompanyID=E.CompanyID AND UE.EmployeeID=E.EmployeeID
             AND UE.IsActive=1 AND U.IsActive=1
       ) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END HasActiveLogin
{fromSql}
ORDER BY E.EmployeeCode,E.EmployeeID
OFFSET @Offset ROWS FETCH NEXT @Take ROWS ONLY;
""", connection);
        BindFilters(command, companyId, userId, search, isActive, requirementCode);
        command.Parameters.Add("@Offset", SqlDbType.Int).Value = (page - 1) * pageSize;
        command.Parameters.Add("@Take", SqlDbType.Int).Value = pageSize;

        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token))
        {
            items.Add(new
            {
                employeeId = reader.GetInt64(0),
                employeeCode = reader.GetString(1),
                fullName = reader.GetString(2),
                nickName = Text(reader, 3),
                isActive = reader.GetBoolean(4),
                requiresAttendance = reader.GetString(5) == "REQUIRED",
                requirementCode = reader.GetString(5),
                requirementEffectiveFrom = Date(reader, 6),
                requirementEffectiveTo = Date(reader, 7),
                requirementReason = Text(reader, 8),
                requirementRowVersion = Text(reader, 9),
                deviceCode = Text(reader, 10),
                deviceCodeEffectiveFrom = DateTimeValue(reader, 11),
                deviceCodeRowVersion = Text(reader, 12),
                hasActiveLogin = reader.GetBoolean(13),
            });
        }

        return Ok(new { total, page, pageSize, items });
    }

    [HttpPut("{employeeId:long}")]
    public async Task<IActionResult> Update(
        long employeeId,
        UpdateRequest request,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        if (employeeId <= 0) return BadRequest(new { message = "รหัสพนักงานไม่ถูกต้อง" });
        var reason = Clean(request.Reason);
        var deviceCode = Clean(request.DeviceCode);
        if (reason is null)
            return BadRequest(new { message = "กรุณาระบุเหตุผลในการแก้ไข" });
        if (reason.Length > 1000 || deviceCode?.Length > 100)
            return BadRequest(new { message = "ข้อมูลยาวเกินกำหนด" });
        if (request.EffectiveFrom < DateOnly.FromDateTime(DateTime.Today))
            return BadRequest(new { message = "วันที่เริ่มใช้ต้องไม่ย้อนหลัง" });

        await using var connection = await Open(token);
        if (!await CompanyMenuAccess.IsAllowedAsync(
                connection, User, MenuCode, "EDIT", token))
            return Forbid();
        if (!await EmployeeInScope(connection, companyId, userId, employeeId, token))
            return Forbid();

        await using var transaction =
            (SqlTransaction)await connection.BeginTransactionAsync(
                IsolationLevel.Serializable, token);
        try
        {
            var current = await LoadCurrent(
                connection, transaction, companyId, employeeId, token);
            if (current is null) return NotFound();
            if (!Matches(request.RequirementRowVersion, current.RequirementRowVersion) ||
                !Matches(request.DeviceCodeRowVersion, current.DeviceCodeRowVersion))
            {
                await transaction.RollbackAsync(token);
                return Conflict(new { message = "ข้อมูลถูกแก้ไขโดยผู้ใช้อื่น กรุณาโหลดใหม่" });
            }

            var requirementCode = request.RequiresAttendance ? "REQUIRED" : "EXEMPT";
            var effectiveAt = request.EffectiveFrom.ToDateTime(TimeOnly.MinValue);
            await SaveRequirement(connection, transaction, companyId, employeeId,
                requirementCode, request.EffectiveFrom, reason, userId, current, token);
            await SaveDeviceCode(connection, transaction, companyId, employeeId,
                deviceCode, effectiveAt, userId, current, token);

            var before = JsonSerializer.Serialize(new
            {
                requiresAttendance = current.RequirementCode != "EXEMPT",
                current.DeviceCode,
            });
            var after = JsonSerializer.Serialize(new
            {
                request.RequiresAttendance,
                deviceCode,
                effectiveFrom = request.EffectiveFrom,
            });
            await using var audit = new SqlCommand("""
INSERT dbo.TDTMEmployeeTimeSettingAudit
    (CompanyID,EmployeeID,SettingTypeCode,BeforeJson,AfterJson,Reason,ActorUserID)
VALUES
    (@CompanyID,@EmployeeID,'EMPLOYEE_TIME_SETTINGS',@BeforeJson,@AfterJson,@Reason,@UserID);
""", connection, transaction);
            Add(audit, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(audit, "@EmployeeID", SqlDbType.BigInt, employeeId);
            Add(audit, "@BeforeJson", SqlDbType.NVarChar, before, -1);
            Add(audit, "@AfterJson", SqlDbType.NVarChar, after, -1);
            Add(audit, "@Reason", SqlDbType.NVarChar, reason, 1000);
            Add(audit, "@UserID", SqlDbType.BigInt, userId);
            await audit.ExecuteNonQueryAsync(token);

            await transaction.CommitAsync(token);
            return NoContent();
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627 or 52405 or 52406)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new
            {
                message = "รหัสที่เครื่องหรือช่วงวันที่ซ้ำกับข้อมูลที่มีอยู่",
            });
        }
    }

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(
            configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private bool TryScope(out long companyId, out long userId)
    {
        companyId = 0;
        userId = 0;
        return string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER",
                   StringComparison.OrdinalIgnoreCase) &&
               long.TryParse(User.FindFirstValue("company_id"), out companyId) &&
               long.TryParse(User.FindFirstValue("user_id"), out userId) &&
               companyId > 0 && userId > 0;
    }

    private static async Task<string> Caption(
        SqlConnection connection,
        CancellationToken token)
    {
        await using var command = new SqlCommand(
            "SELECT TOP (1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@MenuCode",
            connection);
        Add(command, "@MenuCode", SqlDbType.Char, MenuCode, 5);
        return Convert.ToString(await command.ExecuteScalarAsync(token)) ??
               "พนักงาน–ลงเวลาทำงาน";
    }

    private static async Task<bool> EmployeeInScope(
        SqlConnection connection,
        long companyId,
        long userId,
        long employeeId,
        CancellationToken token)
    {
        await using var command = new SqlCommand("""
SELECT CASE WHEN EXISTS
(
    SELECT 1 FROM dbo.TDADEmployee E
    WHERE E.CompanyID=@CompanyID AND E.EmployeeID=@EmployeeID
      AND
      (
          EXISTS
          (
              SELECT 1 FROM dbo.TDADUser U
              WHERE U.CompanyID=@CompanyID AND U.UserID=@UserID
                AND U.IsActive=1 AND U.IsCompanyAdmin=1
          )
          OR EXISTS
          (
              SELECT 1 FROM dbo.TDTMEmployeeDataScopeGrant G
              WHERE G.CompanyID=@CompanyID AND G.IsActive=1
                AND G.EffectiveFrom<=GETDATE()
                AND (G.EffectiveTo IS NULL OR G.EffectiveTo>GETDATE())
                AND
                (
                    G.UserID=@UserID
                    OR G.RoleGroupID IN
                    (
                        SELECT ERG.RoleGroupID
                        FROM dbo.TDADUserEmployee UE
                        JOIN dbo.TDADEmployeeRoleGroup ERG
                          ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
                         AND ERG.EffectiveFrom<=CONVERT(date,GETDATE())
                         AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,GETDATE()))
                        WHERE UE.CompanyID=@CompanyID AND UE.UserID=@UserID AND UE.IsActive=1
                    )
                )
                AND
                (
                    G.ScopeTypeCode='ALL'
                    OR
                    (
                        G.ScopeTypeCode='SELF' AND EXISTS
                        (
                            SELECT 1 FROM dbo.TDADUserEmployee UE
                            WHERE UE.CompanyID=@CompanyID AND UE.UserID=@UserID
                              AND UE.EmployeeID=E.EmployeeID AND UE.IsActive=1
                        )
                    )
                )
          )
      )
) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        Add(command, "@EmployeeID", SqlDbType.BigInt, employeeId);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private sealed record CurrentSettings(
        long? RequirementId,
        string? RequirementCode,
        DateOnly? RequirementEffectiveFrom,
        string? RequirementRowVersion,
        long? DeviceCodeId,
        string? DeviceCode,
        DateTime? DeviceCodeEffectiveFrom,
        string? DeviceCodeRowVersion);

    private static async Task<CurrentSettings?> LoadCurrent(
        SqlConnection connection,
        SqlTransaction transaction,
        long companyId,
        long employeeId,
        CancellationToken token)
    {
        await using var command = new SqlCommand("""
SELECT E.EmployeeID,
       AR.AttendanceRequirementID,AR.RequirementCode,AR.EffectiveFrom,
       CONVERT(varchar(32),AR.RowVersion,2),
       DC.DeviceCodeAssignmentID,DC.DeviceCode,DC.EffectiveFromDateTime,
       CONVERT(varchar(32),DC.RowVersion,2)
FROM dbo.TDADEmployee E
OUTER APPLY
(
    SELECT TOP (1) R.* FROM dbo.TDTMAttendanceRequirement R WITH (UPDLOCK,HOLDLOCK)
    WHERE R.CompanyID=E.CompanyID AND R.EmployeeID=E.EmployeeID AND R.EffectiveTo IS NULL
    ORDER BY R.EffectiveFrom DESC,R.AttendanceRequirementID DESC
) AR
OUTER APPLY
(
    SELECT TOP (1) D.* FROM dbo.TDTMAttendanceDeviceCodeAssignment D WITH (UPDLOCK,HOLDLOCK)
    WHERE D.CompanyID=E.CompanyID AND D.EmployeeID=E.EmployeeID AND D.EffectiveToDateTime IS NULL
    ORDER BY D.EffectiveFromDateTime DESC,D.DeviceCodeAssignmentID DESC
) DC
WHERE E.CompanyID=@CompanyID AND E.EmployeeID=@EmployeeID;
""", connection, transaction);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@EmployeeID", SqlDbType.BigInt, employeeId);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return null;
        return new CurrentSettings(
            Long(reader, 1), Text(reader, 2), Date(reader, 3), Text(reader, 4),
            Long(reader, 5), Text(reader, 6), DateTimeValue(reader, 7), Text(reader, 8));
    }

    private static async Task SaveRequirement(
        SqlConnection connection,
        SqlTransaction transaction,
        long companyId,
        long employeeId,
        string requirementCode,
        DateOnly effectiveFrom,
        string reason,
        long userId,
        CurrentSettings current,
        CancellationToken token)
    {
        if (current.RequirementId.HasValue &&
            current.RequirementEffectiveFrom == effectiveFrom)
        {
            await using var update = new SqlCommand("""
UPDATE dbo.TDTMAttendanceRequirement
SET RequirementCode=@RequirementCode,Reason=@Reason,
    UpdateDate=SYSDATETIME(),UpdateBy=@UserID
WHERE AttendanceRequirementID=@ID AND CompanyID=@CompanyID;
""", connection, transaction);
            Add(update, "@RequirementCode", SqlDbType.VarChar, requirementCode, 20);
            Add(update, "@Reason", SqlDbType.NVarChar, reason, 500);
            Add(update, "@UserID", SqlDbType.BigInt, userId);
            Add(update, "@ID", SqlDbType.BigInt, current.RequirementId.Value);
            Add(update, "@CompanyID", SqlDbType.BigInt, companyId);
            await update.ExecuteNonQueryAsync(token);
            return;
        }

        if (current.RequirementId.HasValue)
        {
            if (current.RequirementEffectiveFrom > effectiveFrom)
                throw new InvalidOperationException("Effective date precedes the current version.");
            await using var close = new SqlCommand("""
UPDATE dbo.TDTMAttendanceRequirement
SET EffectiveTo=DATEADD(day,-1,@EffectiveFrom),UpdateDate=SYSDATETIME(),UpdateBy=@UserID
WHERE AttendanceRequirementID=@ID AND CompanyID=@CompanyID;
""", connection, transaction);
            Add(close, "@EffectiveFrom", SqlDbType.Date, effectiveFrom.ToDateTime(TimeOnly.MinValue));
            Add(close, "@UserID", SqlDbType.BigInt, userId);
            Add(close, "@ID", SqlDbType.BigInt, current.RequirementId.Value);
            Add(close, "@CompanyID", SqlDbType.BigInt, companyId);
            await close.ExecuteNonQueryAsync(token);
        }

        await using var insert = new SqlCommand("""
INSERT dbo.TDTMAttendanceRequirement
    (CompanyID,EmployeeID,RequirementCode,EffectiveFrom,Reason,CreateBy)
VALUES
    (@CompanyID,@EmployeeID,@RequirementCode,@EffectiveFrom,@Reason,@UserID);
""", connection, transaction);
        Add(insert, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(insert, "@EmployeeID", SqlDbType.BigInt, employeeId);
        Add(insert, "@RequirementCode", SqlDbType.VarChar, requirementCode, 20);
        Add(insert, "@EffectiveFrom", SqlDbType.Date, effectiveFrom.ToDateTime(TimeOnly.MinValue));
        Add(insert, "@Reason", SqlDbType.NVarChar, reason, 500);
        Add(insert, "@UserID", SqlDbType.BigInt, userId);
        await insert.ExecuteNonQueryAsync(token);
    }

    private static async Task SaveDeviceCode(
        SqlConnection connection,
        SqlTransaction transaction,
        long companyId,
        long employeeId,
        string? deviceCode,
        DateTime effectiveAt,
        long userId,
        CurrentSettings current,
        CancellationToken token)
    {
        if (string.Equals(deviceCode, current.DeviceCode, StringComparison.OrdinalIgnoreCase))
            return;

        if (current.DeviceCodeId.HasValue)
        {
            if (current.DeviceCodeEffectiveFrom >= effectiveAt)
                throw new InvalidOperationException("Effective date precedes the current device-code version.");
            await using var close = new SqlCommand("""
UPDATE dbo.TDTMAttendanceDeviceCodeAssignment
SET EffectiveToDateTime=@EffectiveAt,UpdateDate=SYSDATETIME(),UpdateBy=@UserID
WHERE DeviceCodeAssignmentID=@ID AND CompanyID=@CompanyID;
""", connection, transaction);
            Add(close, "@EffectiveAt", SqlDbType.DateTime2, effectiveAt);
            Add(close, "@UserID", SqlDbType.BigInt, userId);
            Add(close, "@ID", SqlDbType.BigInt, current.DeviceCodeId.Value);
            Add(close, "@CompanyID", SqlDbType.BigInt, companyId);
            await close.ExecuteNonQueryAsync(token);
        }

        if (deviceCode is null) return;
        await using var insert = new SqlCommand("""
INSERT dbo.TDTMAttendanceDeviceCodeAssignment
    (CompanyID,EmployeeID,DeviceCode,EffectiveFromDateTime,CreateBy)
VALUES
    (@CompanyID,@EmployeeID,@DeviceCode,@EffectiveAt,@UserID);
""", connection, transaction);
        Add(insert, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(insert, "@EmployeeID", SqlDbType.BigInt, employeeId);
        Add(insert, "@DeviceCode", SqlDbType.NVarChar, deviceCode, 100);
        Add(insert, "@EffectiveAt", SqlDbType.DateTime2, effectiveAt);
        Add(insert, "@UserID", SqlDbType.BigInt, userId);
        await insert.ExecuteNonQueryAsync(token);
    }

    private static bool Matches(string? supplied, string? current) =>
        supplied is null || string.Equals(supplied, current, StringComparison.OrdinalIgnoreCase);

    private static void BindFilters(
        SqlCommand command,
        long companyId,
        long userId,
        string? search,
        bool? isActive,
        string? requirementCode)
    {
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        Add(command, "@Search", SqlDbType.NVarChar, search, 200);
        Add(command, "@IsActive", SqlDbType.Bit, isActive);
        Add(command, "@RequirementCode", SqlDbType.VarChar, requirementCode, 20);
    }

    private static string? Clean(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static string? Text(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);

    private static long? Long(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : reader.GetInt64(ordinal);

    private static DateOnly? Date(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : DateOnly.FromDateTime(reader.GetDateTime(ordinal));

    private static DateTime? DateTimeValue(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);

    private static void Add(
        SqlCommand command,
        string name,
        SqlDbType type,
        object? value,
        int size = 0)
    {
        var parameter = size != 0
            ? command.Parameters.Add(name, type, size)
            : command.Parameters.Add(name, type);
        parameter.Value = value ?? DBNull.Value;
    }
}
