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
    private static readonly TimeSpan ThailandOffset = TimeSpan.FromHours(7);

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
LEFT JOIN dbo.TDADOrganizationUnit DV
  ON DV.CompanyID=E.CompanyID AND DV.OrgUnitID=E.DivisionOrgUnitID AND DV.UnitType='DIV'
LEFT JOIN dbo.TDADOrganizationUnit DP
  ON DP.CompanyID=E.CompanyID AND DP.OrgUnitID=E.DepartmentOrgUnitID AND DP.UnitType='DEP'
OUTER APPLY
(
    SELECT TOP (1) R.AttendanceRequirementID,R.RequirementCode,
           R.EffectiveFrom,R.EffectiveTo,R.Reason,
           CONVERT(varchar(32),R.RowVersion,2) RowVersion
    FROM dbo.TDTMAttendanceRequirement R
    WHERE R.CompanyID=E.CompanyID AND R.EmployeeID=E.EmployeeID
      AND R.SupersededUtc IS NULL
      AND R.EffectiveFrom<=@BusinessDate
      AND (R.EffectiveTo IS NULL OR R.EffectiveTo>=@BusinessDate)
    ORDER BY R.EffectiveFrom DESC,R.AttendanceRequirementID DESC
) AR
OUTER APPLY
(
    SELECT TOP (1) D.DeviceCodeAssignmentID,D.DeviceCode,
           D.EffectiveFromDateTime,D.EffectiveToDateTime,
           CONVERT(varchar(32),D.RowVersion,2) RowVersion
    FROM dbo.TDTMAttendanceDeviceCodeAssignment D
    WHERE D.CompanyID=E.CompanyID AND D.EmployeeID=E.EmployeeID
      AND D.SupersededUtc IS NULL
      AND D.EffectiveFromDateTime<=@BusinessNow
      AND (D.EffectiveToDateTime IS NULL OR D.EffectiveToDateTime>@BusinessNow)
    ORDER BY D.EffectiveFromDateTime DESC,D.DeviceCodeAssignmentID DESC
) DC
WHERE E.CompanyID=@CompanyID
  AND (@IsActive IS NULL OR E.IsActive=@IsActive)
  AND (@RequirementCode IS NULL OR ISNULL(AR.RequirementCode,'REQUIRED')=@RequirementCode)
  AND (@Search IS NULL OR E.EmployeeCode LIKE N'%'+@Search+N'%'
       OR E.FullName LIKE N'%'+@Search+N'%'
       OR E.NickName LIKE N'%'+@Search+N'%'
       OR CONVERT(nvarchar(30),E.PersonID) LIKE N'%'+@Search+N'%'
       OR DC.DeviceCode LIKE N'%'+@Search+N'%'
       OR DV.NameTH LIKE N'%'+@Search+N'%'
       OR DP.NameTH LIKE N'%'+@Search+N'%')
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
            AND G.EffectiveFrom<=@BusinessNow
            AND (G.EffectiveTo IS NULL OR G.EffectiveTo>@BusinessNow)
            AND
            (
                G.UserID=@UserID
                OR G.RoleGroupID IN
                (
                    SELECT ERG.RoleGroupID
                    FROM dbo.TDADUserEmployee UE
                    JOIN dbo.TDADEmployeeRoleGroup ERG
                      ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
                     AND ERG.EffectiveFrom<=@BusinessDate
                     AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=@BusinessDate)
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
SELECT E.EmployeeID,E.PersonID,E.EmployeeCode,E.FullName,E.NickName,E.IsActive,
       E.DivisionOrgUnitID,DV.NameTH DivisionName,
       E.DepartmentOrgUnitID,DP.NameTH DepartmentName,
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
                personId = Long(reader, 1),
                employeeCode = reader.GetString(2),
                fullName = reader.GetString(3),
                nickName = Text(reader, 4),
                isActive = reader.GetBoolean(5),
                divisionOrgUnitId = Long(reader, 6),
                divisionName = Text(reader, 7),
                departmentOrgUnitId = Long(reader, 8),
                departmentName = Text(reader, 9),
                requiresAttendance = reader.GetString(10) == "REQUIRED",
                requirementCode = reader.GetString(10),
                requirementEffectiveFrom = Date(reader, 11),
                requirementEffectiveTo = Date(reader, 12),
                requirementReason = Text(reader, 13),
                requirementRowVersion = Text(reader, 14),
                deviceCode = Text(reader, 15),
                deviceCodeEffectiveFrom = DateTimeValue(reader, 16),
                deviceCodeRowVersion = Text(reader, 17),
                hasActiveLogin = reader.GetBoolean(18),
            });
        }

        return Ok(new { total, page, pageSize, items });
    }

    [HttpGet("{employeeId:long}")]
    public async Task<IActionResult> Detail(long employeeId, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        if (employeeId <= 0)
            return BadRequest(new { message = "รหัสพนักงานไม่ถูกต้อง" });

        await using var connection = await Open(token);
        if (!await CompanyMenuAccess.IsAllowedAsync(
                connection, User, MenuCode, "VIEW", token))
            return Forbid();
        if (!await EmployeeInScope(connection, companyId, userId, employeeId, token))
            return Forbid();

        await using var command = new SqlCommand("""
SELECT E.EmployeeID,E.PersonID,E.EmployeeCode,E.FullName,E.NickName,E.IsActive,
       E.DivisionOrgUnitID,DV.NameTH,E.DepartmentOrgUnitID,DP.NameTH,
       AR.RequirementCode,AR.EffectiveFrom,AR.EffectiveTo,AR.Reason,
       CONVERT(varchar(32),AR.RowVersion,2),
       DC.DeviceCode,DC.EffectiveFromDateTime,DC.EffectiveToDateTime,
       CONVERT(varchar(32),DC.RowVersion,2)
FROM dbo.TDADEmployee E
LEFT JOIN dbo.TDADOrganizationUnit DV
  ON DV.CompanyID=E.CompanyID AND DV.OrgUnitID=E.DivisionOrgUnitID AND DV.UnitType='DIV'
LEFT JOIN dbo.TDADOrganizationUnit DP
  ON DP.CompanyID=E.CompanyID AND DP.OrgUnitID=E.DepartmentOrgUnitID AND DP.UnitType='DEP'
OUTER APPLY
(
    SELECT TOP (1) R.* FROM dbo.TDTMAttendanceRequirement R
    WHERE R.CompanyID=E.CompanyID AND R.EmployeeID=E.EmployeeID
      AND R.SupersededUtc IS NULL AND R.EffectiveTo IS NULL
    ORDER BY R.EffectiveFrom DESC,R.AttendanceRequirementID DESC
) AR
OUTER APPLY
(
    SELECT TOP (1) D.* FROM dbo.TDTMAttendanceDeviceCodeAssignment D
    WHERE D.CompanyID=E.CompanyID AND D.EmployeeID=E.EmployeeID
      AND D.SupersededUtc IS NULL AND D.EffectiveToDateTime IS NULL
    ORDER BY D.EffectiveFromDateTime DESC,D.DeviceCodeAssignmentID DESC
) DC
WHERE E.CompanyID=@CompanyID AND E.EmployeeID=@EmployeeID;

SELECT AttendanceRequirementID,RequirementCode,EffectiveFrom,EffectiveTo,Reason,
       CreateDate,CreateBy,UpdateDate,UpdateBy,SupersededUtc,SupersededBy,
       CONVERT(varchar(32),RowVersion,2)
FROM dbo.TDTMAttendanceRequirement
WHERE CompanyID=@CompanyID AND EmployeeID=@EmployeeID
ORDER BY EffectiveFrom DESC,AttendanceRequirementID DESC;

SELECT DeviceCodeAssignmentID,DeviceCode,EffectiveFromDateTime,EffectiveToDateTime,
       CreateDate,CreateBy,UpdateDate,UpdateBy,SupersededUtc,SupersededBy,
       CONVERT(varchar(32),RowVersion,2)
FROM dbo.TDTMAttendanceDeviceCodeAssignment
WHERE CompanyID=@CompanyID AND EmployeeID=@EmployeeID
ORDER BY EffectiveFromDateTime DESC,DeviceCodeAssignmentID DESC;

SELECT A.EmployeeTimeSettingAuditID,A.SettingTypeCode,A.BeforeJson,A.AfterJson,
       A.Reason,A.ActorUserID,U.DisplayName,A.OccurredDate,A.CorrelationID
FROM dbo.TDTMEmployeeTimeSettingAudit A
LEFT JOIN dbo.TDADUser U ON U.CompanyID=A.CompanyID AND U.UserID=A.ActorUserID
WHERE A.CompanyID=@CompanyID AND A.EmployeeID=@EmployeeID
ORDER BY A.OccurredDate DESC,A.EmployeeTimeSettingAuditID DESC;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@EmployeeID", SqlDbType.BigInt, employeeId);

        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound();
        var employee = new
        {
            employeeId = reader.GetInt64(0),
            personId = Long(reader, 1),
            employeeCode = reader.GetString(2),
            fullName = reader.GetString(3),
            nickName = Text(reader, 4),
            isActive = reader.GetBoolean(5),
            divisionOrgUnitId = Long(reader, 6),
            divisionName = Text(reader, 7),
            departmentOrgUnitId = Long(reader, 8),
            departmentName = Text(reader, 9),
            requiresAttendance = Text(reader, 10) != "EXEMPT",
            requirementEffectiveFrom = Date(reader, 11),
            requirementEffectiveTo = Date(reader, 12),
            requirementReason = Text(reader, 13),
            requirementRowVersion = Text(reader, 14),
            deviceCode = Text(reader, 15),
            deviceCodeEffectiveFrom = DateTimeValue(reader, 16),
            deviceCodeEffectiveTo = DateTimeValue(reader, 17),
            deviceCodeRowVersion = Text(reader, 18),
            businessDate = ThailandBusinessDate(),
        };

        await reader.NextResultAsync(token);
        var requirementHistory = new List<object>();
        while (await reader.ReadAsync(token))
            requirementHistory.Add(new
            {
                id = reader.GetInt64(0), requirementCode = reader.GetString(1),
                effectiveFrom = Date(reader, 2), effectiveTo = Date(reader, 3),
                reason = Text(reader, 4), createDateUtc = reader.GetDateTime(5),
                createBy = Long(reader, 6), updateDateUtc = DateTimeValue(reader, 7),
                updateBy = Long(reader, 8), supersededUtc = DateTimeValue(reader, 9),
                supersededBy = Long(reader, 10), rowVersion = reader.GetString(11),
            });

        await reader.NextResultAsync(token);
        var deviceCodeHistory = new List<object>();
        while (await reader.ReadAsync(token))
            deviceCodeHistory.Add(new
            {
                id = reader.GetInt64(0), deviceCode = reader.GetString(1),
                effectiveFrom = reader.GetDateTime(2), effectiveTo = DateTimeValue(reader, 3),
                createDateUtc = reader.GetDateTime(4), createBy = Long(reader, 5),
                updateDateUtc = DateTimeValue(reader, 6), updateBy = Long(reader, 7),
                supersededUtc = DateTimeValue(reader, 8), supersededBy = Long(reader, 9),
                rowVersion = reader.GetString(10),
            });

        await reader.NextResultAsync(token);
        var auditHistory = new List<object>();
        while (await reader.ReadAsync(token))
            auditHistory.Add(new
            {
                id = reader.GetInt64(0), settingTypeCode = reader.GetString(1),
                beforeJson = Text(reader, 2), afterJson = reader.GetString(3),
                reason = reader.GetString(4), actorUserId = reader.GetInt64(5),
                actorName = Text(reader, 6), occurredDateUtc = reader.GetDateTime(7),
                correlationId = reader.GetGuid(8),
            });

        return Ok(new { employee, requirementHistory, deviceCodeHistory, auditHistory });
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
        if (request.EffectiveFrom < ThailandBusinessDate())
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
            if (!MatchesRequired(request.RequirementRowVersion, current.RequirementRowVersion) ||
                !MatchesRequired(request.DeviceCodeRowVersion, current.DeviceCodeRowVersion))
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
    (CompanyID,EmployeeID,SettingTypeCode,BeforeJson,AfterJson,Reason,ActorUserID,OccurredDate)
VALUES
    (@CompanyID,@EmployeeID,'EMPLOYEE_TIME_SETTINGS',@BeforeJson,@AfterJson,@Reason,@UserID,SYSUTCDATETIME());
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
        catch (InvalidOperationException exception)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new
            {
                message = exception.Message.Contains("device-code", StringComparison.Ordinal)
                    ? "วันที่เริ่มใช้ต้องไม่ก่อนเวอร์ชันรหัสที่เครื่องปัจจุบัน"
                    : "วันที่เริ่มใช้ต้องไม่ก่อนเวอร์ชันการลงเวลาปัจจุบัน",
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
                AND G.EffectiveFrom<=@BusinessNow
                AND (G.EffectiveTo IS NULL OR G.EffectiveTo>@BusinessNow)
                AND
                (
                    G.UserID=@UserID
                    OR G.RoleGroupID IN
                    (
                        SELECT ERG.RoleGroupID
                        FROM dbo.TDADUserEmployee UE
                        JOIN dbo.TDADEmployeeRoleGroup ERG
                          ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
                         AND ERG.EffectiveFrom<=@BusinessDate
                         AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=@BusinessDate)
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
        AddBusinessTime(command);
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
    WHERE R.CompanyID=E.CompanyID AND R.EmployeeID=E.EmployeeID
      AND R.SupersededUtc IS NULL AND R.EffectiveTo IS NULL
    ORDER BY R.EffectiveFrom DESC,R.AttendanceRequirementID DESC
) AR
OUTER APPLY
(
    SELECT TOP (1) D.* FROM dbo.TDTMAttendanceDeviceCodeAssignment D WITH (UPDLOCK,HOLDLOCK)
    WHERE D.CompanyID=E.CompanyID AND D.EmployeeID=E.EmployeeID
      AND D.SupersededUtc IS NULL AND D.EffectiveToDateTime IS NULL
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
            await using var supersede = new SqlCommand("""
UPDATE dbo.TDTMAttendanceRequirement
SET SupersededUtc=SYSUTCDATETIME(),SupersededBy=@UserID,
    UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE AttendanceRequirementID=@ID AND CompanyID=@CompanyID;
""", connection, transaction);
            Add(supersede, "@UserID", SqlDbType.BigInt, userId);
            Add(supersede, "@ID", SqlDbType.BigInt, current.RequirementId.Value);
            Add(supersede, "@CompanyID", SqlDbType.BigInt, companyId);
            await supersede.ExecuteNonQueryAsync(token);
        }
        else if (current.RequirementId.HasValue)
        {
            if (current.RequirementEffectiveFrom > effectiveFrom)
                throw new InvalidOperationException("Effective date precedes the current version.");
            await using var close = new SqlCommand("""
UPDATE dbo.TDTMAttendanceRequirement
SET EffectiveTo=DATEADD(day,-1,@EffectiveFrom),UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
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
    (CompanyID,EmployeeID,RequirementCode,EffectiveFrom,Reason,CreateBy,CreateDate)
VALUES
    (@CompanyID,@EmployeeID,@RequirementCode,@EffectiveFrom,@Reason,@UserID,SYSUTCDATETIME());
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
            if (current.DeviceCodeEffectiveFrom > effectiveAt)
                throw new InvalidOperationException("Effective date precedes the current device-code version.");
            var sameEffectiveTime = current.DeviceCodeEffectiveFrom == effectiveAt;
            await using var close = new SqlCommand(sameEffectiveTime ? """
UPDATE dbo.TDTMAttendanceDeviceCodeAssignment
SET SupersededUtc=SYSUTCDATETIME(),SupersededBy=@UserID,
    UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE DeviceCodeAssignmentID=@ID AND CompanyID=@CompanyID;
""" : """
UPDATE dbo.TDTMAttendanceDeviceCodeAssignment
SET EffectiveToDateTime=@EffectiveAt,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE DeviceCodeAssignmentID=@ID AND CompanyID=@CompanyID;
""", connection, transaction);
            if (!sameEffectiveTime)
                Add(close, "@EffectiveAt", SqlDbType.DateTime2, effectiveAt);
            Add(close, "@UserID", SqlDbType.BigInt, userId);
            Add(close, "@ID", SqlDbType.BigInt, current.DeviceCodeId.Value);
            Add(close, "@CompanyID", SqlDbType.BigInt, companyId);
            await close.ExecuteNonQueryAsync(token);
        }

        if (deviceCode is null) return;
        await using var insert = new SqlCommand("""
INSERT dbo.TDTMAttendanceDeviceCodeAssignment
    (CompanyID,EmployeeID,DeviceCode,EffectiveFromDateTime,CreateBy,CreateDate)
VALUES
    (@CompanyID,@EmployeeID,@DeviceCode,@EffectiveAt,@UserID,SYSUTCDATETIME());
""", connection, transaction);
        Add(insert, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(insert, "@EmployeeID", SqlDbType.BigInt, employeeId);
        Add(insert, "@DeviceCode", SqlDbType.NVarChar, deviceCode, 100);
        Add(insert, "@EffectiveAt", SqlDbType.DateTime2, effectiveAt);
        Add(insert, "@UserID", SqlDbType.BigInt, userId);
        await insert.ExecuteNonQueryAsync(token);
    }

    private static bool MatchesRequired(string? supplied, string? current) =>
        current is null
            ? supplied is null
            : supplied is not null &&
              string.Equals(supplied, current, StringComparison.OrdinalIgnoreCase);

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
        AddBusinessTime(command);
    }

    private static DateTime ThailandBusinessNow() =>
        DateTime.SpecifyKind(DateTime.UtcNow.Add(ThailandOffset), DateTimeKind.Unspecified);

    private static DateOnly ThailandBusinessDate() =>
        DateOnly.FromDateTime(ThailandBusinessNow());

    private static void AddBusinessTime(SqlCommand command)
    {
        var now = ThailandBusinessNow();
        Add(command, "@BusinessNow", SqlDbType.DateTime2, now);
        Add(command, "@BusinessDate", SqlDbType.Date,
            DateOnly.FromDateTime(now).ToDateTime(TimeOnly.MinValue));
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
