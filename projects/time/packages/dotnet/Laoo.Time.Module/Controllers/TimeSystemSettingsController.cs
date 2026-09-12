using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Authorize]
[Route("api/time/system-settings")]
public sealed class TimeSystemSettingsController(IConfiguration configuration)
    : ControllerBase
{
    private const string MenuCode = "28002";
    private static readonly TimeSpan ThailandOffset = TimeSpan.FromHours(7);
    private static readonly string[] ApprovalProcesses =
        ["LEAVE", "TIME", "OT", "ENTITLEMENT", "PERIOD"];
    private static readonly string[] RequestProcesses =
        ["LEAVE_REQUEST", "LEAVE_CANCELLATION", "TIME_CORRECTION", "RECONFIRMATION"];

    public sealed record UpdateRequest(
        DateOnly EffectiveFrom,
        string DefaultProfileCode,
        Dictionary<string, string> ProcessProfiles,
        Dictionary<string, string> RequestPolicies,
        string Reason,
        string StateToken);

    private sealed record State(
        string DefaultProfileCode,
        Dictionary<string, string> ProcessProfiles,
        Dictionary<string, string> RequestPolicies,
        int ActiveEmployeeCount,
        int EmployeeWithoutLoginCount);

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
            view = await Can(connection, "VIEW", token),
            edit = await Can(connection, "EDIT", token),
            manageApprovalProfile = await Can(
                connection, "MANAGE_APPROVAL_PROFILE", token),
            create = false,
            delete = false,
        });
    }

    [HttpGet]
    public async Task<IActionResult> Get(
        [FromQuery] DateOnly? effectiveDate,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();
        var date = effectiveDate ?? ThailandBusinessDate();
        var state = await LoadState(connection, null, companyId, date, token);
        return Ok(new
        {
            effectiveDate = date,
            state.DefaultProfileCode,
            state.ProcessProfiles,
            state.RequestPolicies,
            state.ActiveEmployeeCount,
            state.EmployeeWithoutLoginCount,
            selfServiceReady = state.EmployeeWithoutLoginCount == 0,
            stateToken = Token(state),
        });
    }

    [HttpPut]
    public async Task<IActionResult> Update(
        UpdateRequest request,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var reason = Clean(request.Reason);
        var defaultProfile = Normalize(request.DefaultProfileCode);
        if (request.EffectiveFrom < ThailandBusinessDate())
            return BadRequest(new { message = "วันที่เริ่มใช้ต้องไม่ย้อนหลัง" });
        if (reason is null || reason.Length > 1000)
            return BadRequest(new { message = "กรุณาระบุเหตุผลไม่เกิน 1,000 ตัวอักษร" });
        if (!IsBaseProfile(defaultProfile) ||
            !ValidMap(request.ProcessProfiles, ApprovalProcesses, IsProfile) ||
            !ValidMap(request.RequestPolicies, RequestProcesses, IsRequestPolicy))
            return BadRequest(new { message = "ค่ารูปแบบอนุมัติหรือนโยบายคำขอไม่ถูกต้อง" });

        await using var connection = await Open(token);
        if (!await Can(connection, "EDIT", token) ||
            !await Can(connection, "MANAGE_APPROVAL_PROFILE", token))
            return Forbid();

        await using var transaction =
            (SqlTransaction)await connection.BeginTransactionAsync(
                IsolationLevel.Serializable, token);
        try
        {
            var before = await LoadState(
                connection, transaction, companyId, request.EffectiveFrom, token);
            if (!string.Equals(request.StateToken, Token(before),
                    StringComparison.Ordinal))
            {
                await transaction.RollbackAsync(token);
                return Conflict(new { message = "การตั้งค่าถูกแก้ไขแล้ว กรุณาโหลดข้อมูลใหม่" });
            }
            if (request.RequestPolicies.Values.Any(
                    value => Normalize(value) == "SELF_SERVICE_ONLY") &&
                before.EmployeeWithoutLoginCount > 0)
            {
                await transaction.RollbackAsync(token);
                return Conflict(new
                {
                    message = "ยังเปิด SELF_SERVICE_ONLY ไม่ได้",
                    employeeWithoutLoginCount = before.EmployeeWithoutLoginCount,
                });
            }

            await SaveDefaultProfile(connection, transaction, companyId,
                request.EffectiveFrom, defaultProfile, userId, token);
            foreach (var process in ApprovalProcesses)
            {
                await SaveProcessProfile(connection, transaction, companyId,
                    process, request.EffectiveFrom,
                    Normalize(request.ProcessProfiles[process]), userId, token);
            }
            foreach (var process in RequestProcesses)
            {
                await SaveRequestPolicy(connection, transaction, companyId,
                    process, request.EffectiveFrom,
                    Normalize(request.RequestPolicies[process]), userId, token);
            }

            var after = new
            {
                defaultProfileCode = defaultProfile,
                processProfiles = NormalizeMap(request.ProcessProfiles),
                requestPolicies = NormalizeMap(request.RequestPolicies),
                effectiveFrom = request.EffectiveFrom,
            };
            await using var audit = new SqlCommand("""
INSERT dbo.TDTMAdministrativeOverride
    (CompanyID,OverrideTypeCode,TargetTypeCode,BeforeJson,AfterJson,Reason,
     ActorUserID,CorrelationID,OccurredDate)
VALUES
    (@CompanyID,'APPROVAL_PROFILE_CHANGE','TIME_SYSTEM_SETTINGS',
     @BeforeJson,@AfterJson,@Reason,@UserID,NEWID(),SYSUTCDATETIME());
""", connection, transaction);
            Add(audit, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(audit, "@BeforeJson", SqlDbType.NVarChar,
                JsonSerializer.Serialize(before), -1);
            Add(audit, "@AfterJson", SqlDbType.NVarChar,
                JsonSerializer.Serialize(after), -1);
            Add(audit, "@Reason", SqlDbType.NVarChar, reason, 1000);
            Add(audit, "@UserID", SqlDbType.BigInt, userId);
            await audit.ExecuteNonQueryAsync(token);

            await transaction.CommitAsync(token);
            return NoContent();
        }
        catch (InvalidOperationException exception)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = exception.Message });
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627 or 52401 or 52402 or 52403)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = "ช่วงวันที่ตั้งค่าซ้ำกับ Version ที่มีอยู่" });
        }
    }

    private async Task<bool> Can(
        SqlConnection connection,
        string action,
        CancellationToken token) =>
        await CompanyMenuAccess.IsAllowedAsync(
            connection, User, MenuCode, action, token);

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

    private static async Task<State> LoadState(
        SqlConnection connection,
        SqlTransaction? transaction,
        long companyId,
        DateOnly date,
        CancellationToken token)
    {
        var defaultProfile = "OWNER_OPERATED";
        var processProfiles = ApprovalProcesses.ToDictionary(
            key => key, _ => "DEFAULT", StringComparer.OrdinalIgnoreCase);
        var requestPolicies = RequestProcesses.ToDictionary(
            key => key, _ => "SELF_SERVICE_AND_PROXY", StringComparer.OrdinalIgnoreCase);

        await using (var command = new SqlCommand("""
SELECT TOP (1) ProfileCode
FROM dbo.TDTMApprovalProfileVersion
WHERE CompanyID=@CompanyID AND IsActive=1 AND EffectiveFrom<=@Date
  AND (EffectiveTo IS NULL OR EffectiveTo>=@Date)
ORDER BY EffectiveFrom DESC,ApprovalProfileVersionID DESC;
""", connection, transaction))
        {
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(command, "@Date", SqlDbType.Date, date.ToDateTime(TimeOnly.MinValue));
            defaultProfile = Convert.ToString(await command.ExecuteScalarAsync(token)) ??
                             defaultProfile;
        }

        await using (var command = new SqlCommand("""
SELECT ProcessCode,ProfileCode
FROM dbo.TDTMProcessApprovalPolicyVersion
WHERE CompanyID=@CompanyID AND IsActive=1 AND EffectiveFrom<=@Date
  AND (EffectiveTo IS NULL OR EffectiveTo>=@Date);
""", connection, transaction))
        {
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(command, "@Date", SqlDbType.Date, date.ToDateTime(TimeOnly.MinValue));
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token))
                processProfiles[reader.GetString(0)] = reader.GetString(1);
        }

        await using (var command = new SqlCommand("""
SELECT ProcessCode,PolicyCode
FROM dbo.TDTMEmployeeRequestPolicyVersion
WHERE CompanyID=@CompanyID AND IsActive=1 AND EffectiveFrom<=@Date
  AND (EffectiveTo IS NULL OR EffectiveTo>=@Date);
""", connection, transaction))
        {
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(command, "@Date", SqlDbType.Date, date.ToDateTime(TimeOnly.MinValue));
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token))
                requestPolicies[reader.GetString(0)] = reader.GetString(1);
        }

        var activeEmployees = 0;
        var withoutLogin = 0;
        await using (var command = new SqlCommand("""
SELECT COUNT_BIG(1),COALESCE(SUM(CASE WHEN LoginUser.EmployeeID IS NULL THEN 1 ELSE 0 END),0)
FROM dbo.TDADEmployee E
OUTER APPLY
(
    SELECT TOP (1) UE.EmployeeID
    FROM dbo.TDADUserEmployee UE
    JOIN dbo.TDADUser U ON U.UserID=UE.UserID AND U.CompanyID=UE.CompanyID AND U.IsActive=1
    WHERE UE.CompanyID=E.CompanyID AND UE.EmployeeID=E.EmployeeID AND UE.IsActive=1
) LoginUser
WHERE E.CompanyID=@CompanyID AND E.IsActive=1;
""", connection, transaction))
        {
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
            await using var reader = await command.ExecuteReaderAsync(token);
            if (await reader.ReadAsync(token))
            {
                activeEmployees = Convert.ToInt32(reader.GetInt64(0));
                withoutLogin = reader.IsDBNull(1) ? 0 : reader.GetInt32(1);
            }
        }
        return new State(defaultProfile, processProfiles, requestPolicies,
            activeEmployees, withoutLogin);
    }

    private static async Task SaveDefaultProfile(
        SqlConnection connection, SqlTransaction transaction,
        long companyId, DateOnly effectiveFrom, string value,
        long userId, CancellationToken token) =>
        await SaveVersion(connection, transaction,
            "TDTMApprovalProfileVersion", "ApprovalProfileVersionID",
            companyId, null, "ProfileCode", value, effectiveFrom, userId, token);

    private static async Task SaveProcessProfile(
        SqlConnection connection, SqlTransaction transaction,
        long companyId, string process, DateOnly effectiveFrom, string value,
        long userId, CancellationToken token)
    {
        if (value == "DEFAULT")
        {
            await CloseVersion(connection, transaction,
                "TDTMProcessApprovalPolicyVersion", "ProcessApprovalPolicyVersionID",
                companyId, process, effectiveFrom, userId, token);
            return;
        }
        await SaveVersion(connection, transaction,
            "TDTMProcessApprovalPolicyVersion", "ProcessApprovalPolicyVersionID",
            companyId, process, "ProfileCode", value, effectiveFrom, userId, token);
    }

    private static async Task SaveRequestPolicy(
        SqlConnection connection, SqlTransaction transaction,
        long companyId, string process, DateOnly effectiveFrom, string value,
        long userId, CancellationToken token) =>
        await SaveVersion(connection, transaction,
            "TDTMEmployeeRequestPolicyVersion", "RequestPolicyVersionID",
            companyId, process, "PolicyCode", value, effectiveFrom, userId, token);

    private static async Task SaveVersion(
        SqlConnection connection, SqlTransaction transaction,
        string table, string idColumn, long companyId, string? process,
        string valueColumn, string value, DateOnly effectiveFrom,
        long userId, CancellationToken token)
    {
        var current = await CurrentVersion(connection, transaction,
            table, idColumn, companyId, process, token);
        if (current is { } row && row.Start == effectiveFrom)
        {
            await using var update = new SqlCommand($"""
UPDATE dbo.{table}
SET {valueColumn}=@Value,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE {idColumn}=@ID AND CompanyID=@CompanyID;
""", connection, transaction);
            BindVersion(update, companyId, process, effectiveFrom, userId);
            Add(update, "@Value", SqlDbType.VarChar, value, 30);
            Add(update, "@ID", SqlDbType.BigInt, row.Id);
            await update.ExecuteNonQueryAsync(token);
            return;
        }
        if (current is { } existing)
        {
            if (existing.Start > effectiveFrom)
                throw new InvalidOperationException(
                    "วันที่เริ่มใช้ต้องไม่ก่อน Version ที่บันทึกไว้");
            await CloseById(connection, transaction, table, idColumn,
                companyId, existing.Id, effectiveFrom, userId, token);
        }

        var processColumns = process is null ? "" : ",ProcessCode";
        var processValues = process is null ? "" : ",@ProcessCode";
        await using var insert = new SqlCommand($"""
INSERT dbo.{table}
    (CompanyID{processColumns},{valueColumn},EffectiveFrom,IsActive,CreateBy)
VALUES
    (@CompanyID{processValues},@Value,@EffectiveFrom,1,@UserID);
""", connection, transaction);
        BindVersion(insert, companyId, process, effectiveFrom, userId);
        Add(insert, "@Value", SqlDbType.VarChar, value, 30);
        await insert.ExecuteNonQueryAsync(token);
    }

    private static async Task CloseVersion(
        SqlConnection connection, SqlTransaction transaction,
        string table, string idColumn, long companyId, string process,
        DateOnly effectiveFrom, long userId, CancellationToken token)
    {
        var current = await CurrentVersion(connection, transaction,
            table, idColumn, companyId, process, token);
        if (current is null) return;
        if (current.Value.Start > effectiveFrom)
            throw new InvalidOperationException(
                "วันที่เริ่มใช้ต้องไม่ก่อน Version ที่บันทึกไว้");
        if (current.Value.Start == effectiveFrom)
        {
            await using var deactivate = new SqlCommand($"""
UPDATE dbo.{table}
SET EffectiveTo=@EffectiveFrom,IsActive=0,
    UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE {idColumn}=@ID AND CompanyID=@CompanyID;
""", connection, transaction);
            BindVersion(deactivate, companyId, null, effectiveFrom, userId);
            Add(deactivate, "@ID", SqlDbType.BigInt, current.Value.Id);
            await deactivate.ExecuteNonQueryAsync(token);
            return;
        }
        await CloseById(connection, transaction, table, idColumn,
            companyId, current.Value.Id, effectiveFrom, userId, token);
    }

    private static async Task CloseById(
        SqlConnection connection, SqlTransaction transaction,
        string table, string idColumn, long companyId, long id,
        DateOnly effectiveFrom, long userId, CancellationToken token)
    {
        await using var command = new SqlCommand($"""
UPDATE dbo.{table}
SET EffectiveTo=DATEADD(day,-1,@EffectiveFrom),
    UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE {idColumn}=@ID AND CompanyID=@CompanyID;
""", connection, transaction);
        BindVersion(command, companyId, null, effectiveFrom, userId);
        Add(command, "@ID", SqlDbType.BigInt, id);
        await command.ExecuteNonQueryAsync(token);
    }

    private static async Task<(long Id, DateOnly Start)?> CurrentVersion(
        SqlConnection connection, SqlTransaction transaction,
        string table, string idColumn, long companyId, string? process,
        CancellationToken token)
    {
        var processWhere = process is null ? "" : " AND ProcessCode=@ProcessCode";
        await using var command = new SqlCommand($"""
SELECT TOP (1) {idColumn},EffectiveFrom
FROM dbo.{table} WITH (UPDLOCK,HOLDLOCK)
WHERE CompanyID=@CompanyID AND IsActive=1 AND EffectiveTo IS NULL{processWhere}
ORDER BY EffectiveFrom DESC,{idColumn} DESC;
""", connection, transaction);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        if (process is not null)
            Add(command, "@ProcessCode", SqlDbType.VarChar, process, 30);
        await using var reader = await command.ExecuteReaderAsync(token);
        return await reader.ReadAsync(token)
            ? (reader.GetInt64(0), DateOnly.FromDateTime(reader.GetDateTime(1)))
            : null;
    }

    private static void BindVersion(
        SqlCommand command, long companyId, string? process,
        DateOnly effectiveFrom, long userId)
    {
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        if (process is not null)
            Add(command, "@ProcessCode", SqlDbType.VarChar, process, 30);
        Add(command, "@EffectiveFrom", SqlDbType.Date,
            effectiveFrom.ToDateTime(TimeOnly.MinValue));
        Add(command, "@UserID", SqlDbType.BigInt, userId);
    }

    private static bool ValidMap(
        Dictionary<string, string>? values,
        IEnumerable<string> required,
        Func<string, bool> validator) =>
        values is not null && required.All(key =>
            values.TryGetValue(key, out var value) && validator(Normalize(value)));

    private static bool IsProfile(string value) =>
        value is "OWNER_OPERATED" or "SEGREGATED_WORKFLOW" or "DEFAULT";

    private static bool IsBaseProfile(string value) =>
        value is "OWNER_OPERATED" or "SEGREGATED_WORKFLOW";

    private static bool IsRequestPolicy(string value) =>
        value is "SELF_SERVICE_AND_PROXY" or "PROXY_ONLY" or "SELF_SERVICE_ONLY";

    private static Dictionary<string, string> NormalizeMap(
        Dictionary<string, string> values) =>
        values.OrderBy(entry => entry.Key).ToDictionary(
            entry => Normalize(entry.Key), entry => Normalize(entry.Value));

    private static string Normalize(string value) => value.Trim().ToUpperInvariant();

    private static DateOnly ThailandBusinessDate() =>
        DateOnly.FromDateTime(DateTime.UtcNow.Add(ThailandOffset));

    private static string? Clean(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static string Token(State state)
    {
        var canonical = JsonSerializer.Serialize(new
        {
            state.DefaultProfileCode,
            ProcessProfiles = state.ProcessProfiles.OrderBy(x => x.Key),
            RequestPolicies = state.RequestPolicies.OrderBy(x => x.Key),
            state.ActiveEmployeeCount,
            state.EmployeeWithoutLoginCount,
        });
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));
    }

    private static async Task<string> Caption(
        SqlConnection connection, CancellationToken token)
    {
        await using var command = new SqlCommand(
            "SELECT TOP (1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@MenuCode",
            connection);
        Add(command, "@MenuCode", SqlDbType.Char, MenuCode, 5);
        return Convert.ToString(await command.ExecuteScalarAsync(token)) ??
               "กำหนดค่าระบบเวลา";
    }

    private static void Add(
        SqlCommand command, string name, SqlDbType type,
        object? value, int size = 0)
    {
        var parameter = size != 0
            ? command.Parameters.Add(name, type, size)
            : command.Parameters.Add(name, type);
        parameter.Value = value ?? DBNull.Value;
    }
}
