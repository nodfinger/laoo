using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

public sealed record LeaveTypeSaveRequest(
    string LeaveTypeCode, string LeaveTypeName, string UnitCode, bool IsPaid,
    bool RequireRemark, bool RequireEvidence, bool IsActive, string? RowVersion);

[ApiController]
[Route("api/time/leave-types")]
[Authorize]
public sealed class LeaveTypesController(IConfiguration configuration) : ControllerBase
{
    private const string MenuCode = "28009";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid();
        await using var c = await Open(token);
        return Ok(new { menuCode = MenuCode, caption = await Caption(c, token), screenType = 1,
            view = await Can(c, "VIEW", token), create = await Can(c, "CREATE", token),
            edit = await Can(c, "EDIT", token), delete = await Can(c, "DELETE", token) });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] bool? isActive,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        if (page < 1 || pageSize is < 1 or > 100) return BadRequest(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง" });
        await using var c = await Open(token); if (!await Can(c, "VIEW", token)) return Forbid();
        var term = Clean(search);
        const string where = "FROM dbo.TDTMLeaveType WHERE CompanyID=@C AND(@A IS NULL OR IsActive=@A) AND(@S IS NULL OR LeaveTypeCode LIKE N'%'+@S+N'%' OR LeaveTypeName LIKE N'%'+@S+N'%')";
        await using var count = new SqlCommand("SELECT COUNT_BIG(1) " + where, c); Bind(count, companyId, term, isActive);
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var q = new SqlCommand("SELECT LeaveTypeID,LeaveTypeCode,LeaveTypeName,UnitCode,IsPaid,RequireRemark,RequireEvidence,IsActive,CONVERT(varchar(32),RowVersion,2) " + where + " ORDER BY LeaveTypeCode OFFSET @O ROWS FETCH NEXT @T ROWS ONLY", c);
        Bind(q, companyId, term, isActive); Add(q, "@O", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@T", SqlDbType.Int, pageSize);
        await using var r = await q.ExecuteReaderAsync(token); var items = new List<object>();
        while (await r.ReadAsync(token)) items.Add(new { id = r.GetInt64(0), leaveTypeCode = r.GetString(1), leaveTypeName = r.GetString(2), unitCode = r.GetString(3), isPaid = r.GetBoolean(4), requireRemark = r.GetBoolean(5), requireEvidence = r.GetBoolean(6), isActive = r.GetBoolean(7), rowVersion = r.GetString(8) });
        return Ok(new { total, page, pageSize, items });
    }

    [HttpPost]
    public Task<IActionResult> Create(LeaveTypeSaveRequest request, CancellationToken token) => Save(null, request, token);
    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, LeaveTypeSaveRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, [FromQuery] string rowVersion, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        if (!RowVersion(rowVersion)) return BadRequest(new { message = "ไม่พบ Version ของข้อมูล กรุณาโหลดใหม่" });
        await using var c = await Open(token); if (!await Can(c, "DELETE", token)) return Forbid();
        await using var q = new SqlCommand("IF EXISTS(SELECT 1 FROM dbo.TDTMLeaveRequest WHERE CompanyID=@C AND LeaveTypeID=@ID) THROW 52620,N'ประเภทลานี้ถูกใช้งานแล้ว ไม่สามารถลบได้',1; UPDATE dbo.TDTMLeaveType SET IsActive=0,UpdateDate=SYSDATETIME(),UpdateBy=@U WHERE CompanyID=@C AND LeaveTypeID=@ID AND RowVersion=CONVERT(binary(8),@V,2)", c);
        Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@U", SqlDbType.BigInt, userId); Add(q, "@ID", SqlDbType.BigInt, id); Add(q, "@V", SqlDbType.VarChar, rowVersion, 32);
        try { return await q.ExecuteNonQueryAsync(token) == 1 ? NoContent() : Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" }); }
        catch (SqlException e) when (e.Number == 52620) { return Conflict(new { message = e.Message }); }
    }

    private async Task<IActionResult> Save(long? id, LeaveTypeSaveRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var code = Clean(request.LeaveTypeCode)?.ToUpperInvariant(); var name = Clean(request.LeaveTypeName); var unit = Clean(request.UnitCode)?.ToUpperInvariant();
        if (code is null || code.Length > 50 || name is null || name.Length > 200 || unit is not ("DAY" or "MINUTE")) return BadRequest(new { message = "กรุณาระบุรหัส ชื่อ และหน่วยสิทธิ์ลาให้ถูกต้อง" });
        if (id.HasValue && !RowVersion(request.RowVersion)) return BadRequest(new { message = "ไม่พบ Version ของข้อมูล กรุณาโหลดใหม่" });
        await using var c = await Open(token); if (!await Can(c, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        try
        {
            var sql = id.HasValue
                ? "UPDATE dbo.TDTMLeaveType SET LeaveTypeCode=@Code,LeaveTypeName=@Name,UnitCode=@Unit,IsPaid=@Paid,RequireRemark=@Remark,RequireEvidence=@Evidence,IsActive=@Active,UpdateDate=SYSDATETIME(),UpdateBy=@U WHERE CompanyID=@C AND LeaveTypeID=@ID AND RowVersion=CONVERT(binary(8),@V,2)"
                : "INSERT dbo.TDTMLeaveType(CompanyID,LeaveTypeCode,LeaveTypeName,UnitCode,IsPaid,RequireRemark,RequireEvidence,IsActive,CreateBy)VALUES(@C,@Code,@Name,@Unit,@Paid,@Remark,@Evidence,@Active,@U)";
            await using var q = new SqlCommand(sql, c); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@Code", SqlDbType.VarChar, code, 50); Add(q, "@Name", SqlDbType.NVarChar, name, 200); Add(q, "@Unit", SqlDbType.VarChar, unit, 10); Add(q, "@Paid", SqlDbType.Bit, request.IsPaid); Add(q, "@Remark", SqlDbType.Bit, request.RequireRemark); Add(q, "@Evidence", SqlDbType.Bit, request.RequireEvidence); Add(q, "@Active", SqlDbType.Bit, request.IsActive); Add(q, "@U", SqlDbType.BigInt, userId);
            if (id.HasValue) { Add(q, "@ID", SqlDbType.BigInt, id.Value); Add(q, "@V", SqlDbType.VarChar, request.RowVersion, 32); }
            return await q.ExecuteNonQueryAsync(token) == 1 ? NoContent() : Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627) { return Conflict(new { message = "รหัสประเภทลาซ้ำในบริษัท" }); }
    }

    private async Task<SqlConnection> Open(CancellationToken t) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(t); return c; }
    private bool Scope(out long c, out long u) { c = 0; u = 0; return string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase) && long.TryParse(User.FindFirstValue("company_id"), out c) && long.TryParse(User.FindFirstValue("user_id"), out u) && c > 0 && u > 0; }
    private Task<bool> Can(SqlConnection c, string action, CancellationToken t) => CompanyMenuAccess.IsAllowedAsync(c, User, MenuCode, action, t);
    private static async Task<string> Caption(SqlConnection c, CancellationToken t) { await using var q = new SqlCommand("SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode='28009'", c); return Convert.ToString(await q.ExecuteScalarAsync(t)) ?? "ประเภทการลา"; }
    private static string? Clean(string? x) => string.IsNullOrWhiteSpace(x) ? null : x.Trim();
    private static bool RowVersion(string? x) => x is { Length: 16 } && x.All(Uri.IsHexDigit);
    private static void Bind(SqlCommand q, long c, string? s, bool? a) { Add(q, "@C", SqlDbType.BigInt, c); Add(q, "@S", SqlDbType.NVarChar, s, 200); Add(q, "@A", SqlDbType.Bit, a); }
    private static void Add(SqlCommand q, string n, SqlDbType t, object? v, int size = 0) { var p = size == 0 ? q.Parameters.Add(n, t) : q.Parameters.Add(n, t, size); p.Value = v ?? DBNull.Value; }
}
