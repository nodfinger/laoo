using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

public sealed record GenerateLeaveBalancesRequest(DateOnly? AsOfDate);

[ApiController]
[Route("api/time/leave-balances")]
[Authorize]
public sealed class LeaveBalancesController(IConfiguration configuration) : ControllerBase
{
    [HttpGet("actions")]
    public async Task<IActionResult> Actions([FromQuery] bool mine, CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid();
        var menu = mine ? "30004" : "28011";
        await using var c = await Open(token);
        return Ok(new { menuCode = menu, caption = await Caption(c, menu, token), screenType = 3, view = await Can(c, menu, token), generate = !mine && await CanGenerate(c, token) });
    }

    [HttpGet("lookups")]
    public async Task<IActionResult> Lookups([FromQuery] bool mine, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var menu = mine ? "30004" : "28011";
        await using var c = await Open(token);
        if (!await Can(c, menu, token)) return Forbid();
        var self = await EmployeeForUser(c, companyId, userId, token);
        var employeeCandidates = new List<(long Id, string Code, string Name)>();
        await using (var q = new SqlCommand("SELECT EmployeeID,EmployeeCode,FullName FROM dbo.TDADEmployee WHERE CompanyID=@C AND IsActive=1 AND(@E IS NULL OR EmployeeID=@E) ORDER BY EmployeeCode", c))
        {
            Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@E", SqlDbType.BigInt, mine ? self : null);
            await using var r = await q.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) employeeCandidates.Add((r.GetInt64(0), r.GetString(1), r.GetString(2)));
        }
        var employees = new List<object>();
        foreach (var employee in employeeCandidates)
            if (mine || await InScope(c, companyId, userId, employee.Id, token))
                employees.Add(new { id = employee.Id, code = employee.Code, name = employee.Name });
        var branches = new List<object>();
        await using (var q = new SqlCommand("SELECT BranchID,BranchCode,BranchNameTH FROM dbo.TDADBranch WHERE CompanyID=@C AND IsActive=1 ORDER BY BranchCode", c))
        { Add(q, "@C", SqlDbType.BigInt, companyId); await using var r = await q.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) branches.Add(new { id = r.GetInt64(0), code = r.GetString(1), name = r.GetString(2) }); }
        var units = new List<object>();
        await using (var q = new SqlCommand("SELECT OrgUnitID,UnitType,UnitCode,NameTH FROM dbo.TDADOrganizationUnit WHERE CompanyID=@C AND IsActive=1 AND UnitType IN('DIV','DEP') ORDER BY UnitType,UnitCode,OrgUnitID", c))
        { Add(q, "@C", SqlDbType.BigInt, companyId); await using var r = await q.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) units.Add(new { id = r.GetInt64(0), type = r.GetString(1), code = r.GetString(2), name = r.GetString(3) }); }
        var leaveTypes = new List<object>();
        await using (var q = new SqlCommand("SELECT LeaveTypeID,LeaveTypeCode,LeaveTypeName FROM dbo.TDTMLeaveType WHERE CompanyID=@C AND IsActive=1 ORDER BY LeaveTypeCode", c))
        { Add(q, "@C", SqlDbType.BigInt, companyId); await using var r = await q.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) leaveTypes.Add(new { id = r.GetInt64(0), code = r.GetString(1), name = r.GetString(2) }); }
        return Ok(new { employees, branches, units, leaveTypes });
    }

    [HttpPost("generate")]
    public async Task<IActionResult> Generate(GenerateLeaveBalancesRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var c = await Open(token);
        if (!await CanGenerate(c, token)) return Forbid();
        var asOf = request.AsOfDate ?? ThailandToday();
        return Ok(new { asOfDate = asOf, generatedCount = await GenerateInternal(c, companyId, userId, asOf, token) });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] bool mine, [FromQuery] string? search,
        [FromQuery] long? branchId, [FromQuery] long? divisionOrgUnitId, [FromQuery] long? departmentOrgUnitId,
        [FromQuery] long? employeeId, [FromQuery] long? leaveTypeId, [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var menu = mine ? "30004" : "28011";
        await using var c = await Open(token);
        if (!await Can(c, menu, token)) return Forbid();
        var self = await EmployeeForUser(c, companyId, userId, token);
        if (mine && !self.HasValue) return Conflict(new { message = "บัญชีผู้ใช้ยังไม่ได้ผูกกับพนักงานที่ใช้งานอยู่" });
        if (page < 1 || pageSize is < 1 or > 100) return BadRequest(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง" });
        if (await CanGenerate(c, token)) await GenerateInternal(c, companyId, userId, ThailandToday(), token);

        const string sql = """
SELECT E.EmployeeID,E.EmployeeCode,E.FullName,T.LeaveTypeID,T.LeaveTypeCode,T.LeaveTypeName,T.UnitCode,COALESCE(SUM(L.Quantity),0) Balance
FROM dbo.TDADEmployee E CROSS JOIN dbo.TDTMLeaveType T
LEFT JOIN dbo.TDTMLeaveEntitlementLedger L ON L.CompanyID=E.CompanyID AND L.EmployeeID=E.EmployeeID AND L.LeaveTypeID=T.LeaveTypeID
OUTER APPLY(SELECT TOP(1) A.HomeBranchID,A.DivisionOrgUnitID,A.DepartmentOrgUnitID FROM dbo.TDADEmployeeOrganizationAssignment A WHERE A.CompanyID=E.CompanyID AND A.EmployeeID=E.EmployeeID AND A.IsActive=1 AND A.EffectiveFrom<=CONVERT(date,SYSDATETIME()) AND(A.EffectiveTo IS NULL OR A.EffectiveTo>=CONVERT(date,SYSDATETIME())) ORDER BY A.EffectiveFrom DESC,A.EmployeeOrganizationAssignmentID DESC) OA
WHERE E.CompanyID=@C AND E.IsActive=1 AND T.CompanyID=@C AND T.IsActive=1
AND(@Self IS NULL OR E.EmployeeID=@Self) AND(@Employee IS NULL OR E.EmployeeID=@Employee) AND(@Type IS NULL OR T.LeaveTypeID=@Type)
AND(@Branch IS NULL OR OA.HomeBranchID=@Branch) AND(@Division IS NULL OR OA.DivisionOrgUnitID=@Division) AND(@Department IS NULL OR OA.DepartmentOrgUnitID=@Department)
AND(@S IS NULL OR E.EmployeeCode LIKE N'%'+@S+N'%' OR E.FullName LIKE N'%'+@S+N'%' OR T.LeaveTypeName LIKE N'%'+@S+N'%')
GROUP BY E.EmployeeID,E.EmployeeCode,E.FullName,T.LeaveTypeID,T.LeaveTypeCode,T.LeaveTypeName,T.UnitCode
ORDER BY E.EmployeeCode,T.LeaveTypeCode
""";
        await using var q = new SqlCommand(sql, c);
        Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@Self", SqlDbType.BigInt, mine ? self : null); Add(q, "@Employee", SqlDbType.BigInt, mine ? null : employeeId); Add(q, "@Type", SqlDbType.BigInt, leaveTypeId); Add(q, "@Branch", SqlDbType.BigInt, branchId); Add(q, "@Division", SqlDbType.BigInt, divisionOrgUnitId); Add(q, "@Department", SqlDbType.BigInt, departmentOrgUnitId); Add(q, "@S", SqlDbType.NVarChar, Clean(search), 200);
        await using var r = await q.ExecuteReaderAsync(token);
        var candidates = new List<(long EmployeeId, string EmployeeCode, string FullName, long LeaveTypeId, string LeaveTypeCode, string LeaveTypeName, string UnitCode, decimal Balance)>();
        while (await r.ReadAsync(token))
            candidates.Add((r.GetInt64(0), r.GetString(1), r.GetString(2), r.GetInt64(3), r.GetString(4), r.GetString(5), r.GetString(6), r.GetDecimal(7)));
        await r.CloseAsync();
        var scoped = new List<object>();
        foreach (var item in candidates)
            if (mine || await InScope(c, companyId, userId, item.EmployeeId, token))
                scoped.Add(new { employeeId = item.EmployeeId, employeeCode = item.EmployeeCode, fullName = item.FullName, leaveTypeId = item.LeaveTypeId, leaveTypeCode = item.LeaveTypeCode, leaveTypeName = item.LeaveTypeName, unitCode = item.UnitCode, balance = item.Balance });
        var total = scoped.Count;
        return Ok(new { items = scoped.Skip((page - 1) * pageSize).Take(pageSize), total, page, pageSize });
    }

    private static async Task<int> GenerateInternal(SqlConnection c, long companyId, long userId, DateOnly asOf, CancellationToken token)
    {
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var policies = new List<(long Id, long TypeId, string Unit, decimal Quantity, int MinimumServiceDays)>();
            await using (var q = new SqlCommand("SELECT LeaveEntitlementPolicyVersionID,LeaveTypeID,UnitCode,EntitlementQuantity,EligibilityRuleJson FROM dbo.TDTMLeaveEntitlementPolicyVersion WHERE CompanyID=@C AND IsActive=1 AND EffectiveFrom<=@D AND(EffectiveTo IS NULL OR EffectiveTo>=@D)", c, tx))
            { Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@D", SqlDbType.Date, asOf.ToDateTime(TimeOnly.MinValue)); await using var r = await q.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) policies.Add((r.GetInt64(0), r.GetInt64(1), r.GetString(2), r.GetDecimal(3), MinimumServiceDays(r.IsDBNull(4) ? null : r.GetString(4)))); }
            var inserted = 0;
            await using var e = new SqlCommand("SELECT EmployeeID,StartWorkDate FROM dbo.TDADEmployee WHERE CompanyID=@C AND IsActive=1 AND StartWorkDate IS NOT NULL", c, tx);
            Add(e, "@C", SqlDbType.BigInt, companyId);
            await using var er = await e.ExecuteReaderAsync(token);
            var employees = new List<(long Id, DateOnly Start)>();
            while (await er.ReadAsync(token)) employees.Add((er.GetInt64(0), DateOnly.FromDateTime(er.GetDateTime(1))));
            await er.CloseAsync();
            foreach (var employee in employees)
                foreach (var policy in policies)
                {
                    if (employee.Start.AddDays(policy.MinimumServiceDays) > asOf || !await InScope(c, companyId, userId, employee.Id, token, tx)) continue;
                    await using var grant = new SqlCommand("INSERT dbo.TDTMLeaveEntitlementLedger(CompanyID,EmployeeID,LeaveTypeID,UnitCode,EntryTypeCode,Quantity,EffectiveDate,SourcePolicyVersionID,Reason,CreateBy) SELECT @C,@E,@T,@U,'GRANT',@Q,@D,@P,N'GENERATED_FROM_ENTITLEMENT_POLICY',@By WHERE NOT EXISTS(SELECT 1 FROM dbo.TDTMLeaveEntitlementLedger WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND EmployeeID=@E AND SourcePolicyVersionID=@P)", c, tx);
                    Add(grant, "@C", SqlDbType.BigInt, companyId); Add(grant, "@E", SqlDbType.BigInt, employee.Id); Add(grant, "@T", SqlDbType.BigInt, policy.TypeId); Add(grant, "@U", SqlDbType.VarChar, policy.Unit, 10); Add(grant, "@Q", SqlDbType.Decimal, policy.Quantity); grant.Parameters["@Q"].Precision = 18; grant.Parameters["@Q"].Scale = 4; Add(grant, "@D", SqlDbType.Date, asOf.ToDateTime(TimeOnly.MinValue)); Add(grant, "@P", SqlDbType.BigInt, policy.Id); Add(grant, "@By", SqlDbType.BigInt, userId); inserted += await grant.ExecuteNonQueryAsync(token);
                }
            await tx.CommitAsync(token); return inserted;
        }
        catch { await tx.RollbackAsync(token); throw; }
    }

    private async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private bool Scope(out long company, out long user) { company = 0; user = 0; return long.TryParse(User.FindFirstValue("company_id"), out company) && long.TryParse(User.FindFirstValue("user_id"), out user) && company > 0 && user > 0 && string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase); }
    private Task<bool> Can(SqlConnection c, string menu, CancellationToken token) => CompanyMenuAccess.IsAllowedAsync(c, User, menu, "VIEW", token);
    private Task<bool> CanGenerate(SqlConnection c, CancellationToken token) => CompanyMenuAccess.IsAllowedAsync(c, User, "28011", "GENERATE", token);
    private static async Task<string> Caption(SqlConnection c, string menu, CancellationToken token) { await using var q = new SqlCommand("SELECT MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@M", c); Add(q, "@M", SqlDbType.VarChar, menu, 10); return Convert.ToString(await q.ExecuteScalarAsync(token)) ?? menu; }
    private static async Task<long?> EmployeeForUser(SqlConnection c, long company, long user, CancellationToken token) { await using var q = new SqlCommand("SELECT TOP(1) EmployeeID FROM dbo.TDADUserEmployee WHERE CompanyID=@C AND UserID=@U AND IsActive=1", c); Add(q, "@C", SqlDbType.BigInt, company); Add(q, "@U", SqlDbType.BigInt, user); var result = await q.ExecuteScalarAsync(token); return result is null ? null : Convert.ToInt64(result); }
    private static async Task<bool> InScope(SqlConnection c, long company, long user, long employee, CancellationToken token, SqlTransaction? transaction = null)
    {
        const string sql = """
SELECT CAST(CASE WHEN EXISTS
(
    SELECT 1 FROM dbo.TDADEmployee E
    WHERE E.CompanyID=@C AND E.EmployeeID=@E AND E.IsActive=1
      AND (
        EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@C AND U.UserID=@U AND U.IsActive=1 AND U.IsCompanyAdmin=1)
        OR EXISTS
        (
            SELECT 1 FROM dbo.TDTMEmployeeDataScopeGrant G
            WHERE G.CompanyID=@C AND G.IsActive=1
              AND (G.UserID=@U OR G.RoleGroupID IN
              (
                  SELECT ERG.RoleGroupID FROM dbo.TDADUserEmployee UE
                  JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
                    AND ERG.EffectiveFrom<=CONVERT(date,SYSDATETIME())
                    AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSDATETIME()))
                  WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.IsActive=1
              ))
              AND G.EffectiveFrom<=SYSDATETIME() AND (G.EffectiveTo IS NULL OR G.EffectiveTo>SYSDATETIME())
              AND (G.ScopeTypeCode='ALL'
                OR (G.ScopeTypeCode='SELF' AND EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.EmployeeID=@E AND UE.IsActive=1))
                OR (G.ScopeTypeCode='DIVISION' AND G.ScopeReferenceID=E.DivisionOrgUnitID)
                OR (G.ScopeTypeCode='DEPARTMENT' AND G.ScopeReferenceID=E.DepartmentOrgUnitID))
        )
      )
) THEN 1 ELSE 0 END AS bit)
""";
        await using var q = transaction is null ? new SqlCommand(sql, c) : new SqlCommand(sql, c, transaction);
        Add(q, "@C", SqlDbType.BigInt, company); Add(q, "@U", SqlDbType.BigInt, user); Add(q, "@E", SqlDbType.BigInt, employee);
        return Convert.ToBoolean(await q.ExecuteScalarAsync(token));
    }
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static int MinimumServiceDays(string? json) { if (string.IsNullOrWhiteSpace(json)) return 0; try { using var doc = JsonDocument.Parse(json); return doc.RootElement.TryGetProperty("minimumServiceDays", out var value) && value.TryGetInt32(out var days) && days >= 0 ? days : 0; } catch (JsonException) { return 0; } }
    private static DateOnly ThailandToday() => DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("Asia/Bangkok")));
    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0) { var p = size == 0 ? command.Parameters.Add(name, type) : command.Parameters.Add(name, type, size); p.Value = value ?? DBNull.Value; }
}
