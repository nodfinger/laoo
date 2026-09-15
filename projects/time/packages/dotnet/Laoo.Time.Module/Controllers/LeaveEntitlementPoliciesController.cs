using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

public sealed record LeaveEntitlementPolicySaveRequest(
    long LeaveTypeId, string PolicyName, decimal EntitlementQuantity,
    string? EligibilityRuleJson, DateOnly EffectiveFrom, DateOnly? EffectiveTo,
    bool IsActive, string? RowVersion);

[ApiController]
[Route("api/time/leave-entitlement-policies")]
[Authorize]
public sealed class LeaveEntitlementPoliciesController(IConfiguration configuration) : ControllerBase
{
    private const string MenuCode = "28010";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid();
        await using var c = await Open(token);
        return Ok(new { menuCode = MenuCode, caption = await Caption(c, token), screenType = 1,
            view = await Can(c, "VIEW", token), create = await Can(c, "CREATE", token),
            edit = await Can(c, "EDIT", token), delete = await Can(c, "DELETE", token) });
    }

    [HttpGet("leave-types")]
    public async Task<IActionResult> LeaveTypes(CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "VIEW", token)) return Forbid();
        await using var q = new SqlCommand("SELECT LeaveTypeID,LeaveTypeCode,LeaveTypeName,UnitCode FROM dbo.TDTMLeaveType WHERE CompanyID=@C AND IsActive=1 ORDER BY LeaveTypeCode", c); Add(q, "@C", SqlDbType.BigInt, companyId);
        await using var r = await q.ExecuteReaderAsync(token); var items = new List<object>();
        while (await r.ReadAsync(token)) items.Add(new { id = r.GetInt64(0), code = r.GetString(1), name = r.GetString(2), unitCode = r.GetString(3) });
        return Ok(new { items });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] long? leaveTypeId, [FromQuery] bool? isActive,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        if (page < 1 || pageSize is < 1 or > 100) return BadRequest(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง" });
        await using var c = await Open(token); if (!await Can(c, "VIEW", token)) return Forbid();
        const string where = "FROM dbo.TDTMLeaveEntitlementPolicyVersion P JOIN dbo.TDTMLeaveType T ON T.LeaveTypeID=P.LeaveTypeID WHERE P.CompanyID=@C AND(@Type IS NULL OR P.LeaveTypeID=@Type) AND(@A IS NULL OR P.IsActive=@A)";
        await using var count = new SqlCommand("SELECT COUNT_BIG(1) " + where, c); Bind(count, companyId, leaveTypeId, isActive);
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var q = new SqlCommand("SELECT P.LeaveEntitlementPolicyVersionID,P.LeaveTypeID,T.LeaveTypeCode,T.LeaveTypeName,P.PolicyName,P.UnitCode,P.EntitlementQuantity,P.EligibilityRuleJson,P.EffectiveFrom,P.EffectiveTo,P.IsActive,CONVERT(varchar(32),P.RowVersion,2) " + where + " ORDER BY T.LeaveTypeCode,P.EffectiveFrom DESC OFFSET @O ROWS FETCH NEXT @T ROWS ONLY", c);
        Bind(q, companyId, leaveTypeId, isActive); Add(q, "@O", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@T", SqlDbType.Int, pageSize);
        await using var r = await q.ExecuteReaderAsync(token); var items = new List<object>();
        while (await r.ReadAsync(token)) items.Add(new { id = r.GetInt64(0), leaveTypeId = r.GetInt64(1), leaveTypeCode = r.GetString(2), leaveTypeName = r.GetString(3), policyName = r.GetString(4), unitCode = r.GetString(5), entitlementQuantity = r.GetDecimal(6), eligibilityRuleJson = r.IsDBNull(7) ? null : r.GetString(7), effectiveFrom = DateOnly.FromDateTime(r.GetDateTime(8)), effectiveTo = r.IsDBNull(9) ? (DateOnly?)null : DateOnly.FromDateTime(r.GetDateTime(9)), isActive = r.GetBoolean(10), rowVersion = r.GetString(11) });
        return Ok(new { total, page, pageSize, items });
    }

    [HttpPost]
    public Task<IActionResult> Create(LeaveEntitlementPolicySaveRequest request, CancellationToken token) => Save(null, request, token);
    [HttpPut("{id:long}")]
    public Task<IActionResult> Version(long id, LeaveEntitlementPolicySaveRequest request, CancellationToken token) => Save(id, request, token);

    private async Task<IActionResult> Save(long? versionId, LeaveEntitlementPolicySaveRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var name = Clean(request.PolicyName); var rules = Clean(request.EligibilityRuleJson);
        if (name is null || name.Length > 200 || request.EntitlementQuantity < 0 || request.EffectiveTo < request.EffectiveFrom || (rules is not null && !IsJson(rules))) return BadRequest(new { message = "ข้อมูลเกณฑ์สิทธิ์ลาไม่ถูกต้อง" });
        if (versionId.HasValue && !RowVersion(request.RowVersion)) return BadRequest(new { message = "ไม่พบ Version ของข้อมูล กรุณาโหลดใหม่" });
        await using var c = await Open(token); if (!await Can(c, versionId.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            var unit = await LeaveTypeUnit(c, tx, companyId, request.LeaveTypeId, token);
            if (unit is null) throw new InvalidOperationException("ไม่พบประเภทลาที่ใช้งานอยู่");
            if (versionId.HasValue)
            {
                await using var close = new SqlCommand("UPDATE dbo.TDTMLeaveEntitlementPolicyVersion SET EffectiveTo=DATEADD(day,-1,@From),UpdateDate=SYSDATETIME(),UpdateBy=@U WHERE CompanyID=@C AND LeaveEntitlementPolicyVersionID=@ID AND RowVersion=CONVERT(binary(8),@V,2) AND EffectiveFrom<@From", c, tx);
                Add(close, "@C", SqlDbType.BigInt, companyId); Add(close, "@ID", SqlDbType.BigInt, versionId.Value); Add(close, "@V", SqlDbType.VarChar, request.RowVersion, 32); Add(close, "@From", SqlDbType.Date, request.EffectiveFrom.ToDateTime(TimeOnly.MinValue)); Add(close, "@U", SqlDbType.BigInt, userId);
                if (await close.ExecuteNonQueryAsync(token) != 1) return Conflict(new { message = "วันที่เริ่มใช้ต้องใหม่กว่ารายการเดิม และข้อมูลต้องไม่ถูกแก้ไขแล้ว" });
            }
            await using var insert = new SqlCommand("INSERT dbo.TDTMLeaveEntitlementPolicyVersion(CompanyID,LeaveTypeID,PolicyName,UnitCode,EntitlementQuantity,EligibilityRuleJson,EffectiveFrom,EffectiveTo,IsActive,CreateBy)VALUES(@C,@Type,@Name,@Unit,@Qty,@Rules,@From,@To,@Active,@U)", c, tx);
            Add(insert, "@C", SqlDbType.BigInt, companyId); Add(insert, "@Type", SqlDbType.BigInt, request.LeaveTypeId); Add(insert, "@Name", SqlDbType.NVarChar, name, 200); Add(insert, "@Unit", SqlDbType.VarChar, unit, 10); Add(insert, "@Qty", SqlDbType.Decimal, request.EntitlementQuantity); insert.Parameters["@Qty"].Precision = 18; insert.Parameters["@Qty"].Scale = 4; Add(insert, "@Rules", SqlDbType.NVarChar, rules, -1); Add(insert, "@From", SqlDbType.Date, request.EffectiveFrom.ToDateTime(TimeOnly.MinValue)); Add(insert, "@To", SqlDbType.Date, request.EffectiveTo?.ToDateTime(TimeOnly.MinValue)); Add(insert, "@Active", SqlDbType.Bit, request.IsActive); Add(insert, "@U", SqlDbType.BigInt, userId);
            await insert.ExecuteNonQueryAsync(token); await tx.CommitAsync(token); return NoContent();
        }
        catch (InvalidOperationException e) { await tx.RollbackAsync(token); return BadRequest(new { message = e.Message }); }
        catch (SqlException e) when (e.Number is 2601 or 2627) { await tx.RollbackAsync(token); return Conflict(new { message = "ช่วงวันที่มีผลของเกณฑ์สิทธิ์ซ้ำกัน" }); }
    }

    private static async Task<string?> LeaveTypeUnit(SqlConnection c, SqlTransaction tx, long companyId, long id, CancellationToken token) { await using var q = new SqlCommand("SELECT UnitCode FROM dbo.TDTMLeaveType WHERE CompanyID=@C AND LeaveTypeID=@ID AND IsActive=1", c, tx); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@ID", SqlDbType.BigInt, id); return Convert.ToString(await q.ExecuteScalarAsync(token)); }
    private async Task<SqlConnection> Open(CancellationToken t) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(t); return c; }
    private bool Scope(out long c, out long u) { c=0;u=0; return string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&long.TryParse(User.FindFirstValue("company_id"),out c)&&long.TryParse(User.FindFirstValue("user_id"),out u)&&c>0&&u>0; }
    private Task<bool> Can(SqlConnection c,string a,CancellationToken t)=>CompanyMenuAccess.IsAllowedAsync(c,User,MenuCode,a,t);
    private static async Task<string> Caption(SqlConnection c,CancellationToken t){await using var q=new SqlCommand("SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode='28010'",c);return Convert.ToString(await q.ExecuteScalarAsync(t))??"เกณฑ์สิทธิ์การลา";}
    private static string? Clean(string? x)=>string.IsNullOrWhiteSpace(x)?null:x.Trim(); private static bool RowVersion(string? x)=>x is {Length:16}&&x.All(Uri.IsHexDigit); private static bool IsJson(string value){try{System.Text.Json.JsonDocument.Parse(value);return true;}catch{return false;}}
    private static void Bind(SqlCommand q,long c,long? type,bool? a){Add(q,"@C",SqlDbType.BigInt,c);Add(q,"@Type",SqlDbType.BigInt,type);Add(q,"@A",SqlDbType.Bit,a);} private static void Add(SqlCommand q,string n,SqlDbType t,object? v,int size=0){var p=size==0?q.Parameters.Add(n,t):q.Parameters.Add(n,t,size);p.Value=v??DBNull.Value;}
}
