using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Route("api/time/leave-report")]
[Authorize]
public sealed class LeaveReportController(IConfiguration configuration) : ControllerBase
{
    private const string MenuCode = "28012";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid();
        await using var c = await Open(token);
        return Ok(new { menuCode = MenuCode, caption = await Caption(c, token), screenType = 3, view = await Can(c, token) });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] DateOnly? fromDate, [FromQuery] DateOnly? toDate,
        [FromQuery] long? branchId, [FromQuery] long? divisionOrgUnitId, [FromQuery] long? departmentOrgUnitId,
        [FromQuery] long? employeeId, [FromQuery] long? leaveTypeId, [FromQuery] string? status,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, token)) return Forbid();
        if (page < 1 || pageSize is < 1 or > 100) return BadRequest(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง" });
        var from = fromDate ?? ThailandToday().AddDays(-30);
        var to = toDate ?? ThailandToday();
        if (from > to) return BadRequest(new { message = "วันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด" });
        var normalizedStatus = Clean(status)?.ToUpperInvariant();
        if (normalizedStatus is not null && normalizedStatus is not ("PENDING" or "APPROVED" or "REJECTED" or "CANCELLED")) return BadRequest(new { message = "สถานะคำขอไม่ถูกต้อง" });
        const string sql = """
SELECT E.EmployeeID,E.EmployeeCode,E.FullName,T.LeaveTypeID,T.LeaveTypeCode,T.LeaveTypeName,T.UnitCode,
       COALESCE(SUM(CASE WHEN L.EntryTypeCode='GRANT' THEN L.Quantity ELSE 0 END),0) Granted,
       COALESCE(SUM(CASE WHEN L.EntryTypeCode='USAGE' THEN -L.Quantity ELSE 0 END),0) Used,
       COALESCE(SUM(L.Quantity),0) Balance,
       OA.HomeBranchID,OA.DivisionOrgUnitID,OA.DepartmentOrgUnitID,
       COALESCE((SELECT SUM(RS.ReservedQuantity) FROM dbo.TDTMLeaveReservation RS WHERE RS.CompanyID=E.CompanyID AND RS.EmployeeID=E.EmployeeID AND RS.LeaveTypeID=T.LeaveTypeID AND RS.StatusCode='ACTIVE'),0) Pending
FROM dbo.TDADEmployee E CROSS JOIN dbo.TDTMLeaveType T
LEFT JOIN dbo.TDTMLeaveEntitlementLedger L ON L.CompanyID=E.CompanyID AND L.EmployeeID=E.EmployeeID AND L.LeaveTypeID=T.LeaveTypeID AND L.EffectiveDate<=@To
OUTER APPLY(SELECT TOP(1) A.HomeBranchID,A.DivisionOrgUnitID,A.DepartmentOrgUnitID FROM dbo.TDADEmployeeOrganizationAssignment A WHERE A.CompanyID=E.CompanyID AND A.EmployeeID=E.EmployeeID AND A.IsActive=1 AND A.EffectiveFrom<=@To AND(A.EffectiveTo IS NULL OR A.EffectiveTo>=@To) ORDER BY A.EffectiveFrom DESC,A.EmployeeOrganizationAssignmentID DESC) OA
WHERE E.CompanyID=@C AND E.IsActive=1 AND T.CompanyID=@C AND T.IsActive=1
AND(@Employee IS NULL OR E.EmployeeID=@Employee) AND(@Type IS NULL OR T.LeaveTypeID=@Type)
AND(@Branch IS NULL OR OA.HomeBranchID=@Branch) AND(@Division IS NULL OR OA.DivisionOrgUnitID=@Division) AND(@Department IS NULL OR OA.DepartmentOrgUnitID=@Department)
GROUP BY E.EmployeeID,E.EmployeeCode,E.FullName,T.LeaveTypeID,T.LeaveTypeCode,T.LeaveTypeName,T.UnitCode,OA.HomeBranchID,OA.DivisionOrgUnitID,OA.DepartmentOrgUnitID
HAVING(@Status IS NULL OR EXISTS(SELECT 1 FROM dbo.TDTMLeaveRequest LR JOIN dbo.TDTMRequest RR ON RR.RequestID=LR.RequestID WHERE LR.CompanyID=@C AND LR.SubjectEmployeeID=E.EmployeeID AND LR.LeaveTypeID=T.LeaveTypeID AND RR.StatusCode=@Status AND LR.StartWorkDate<=@To AND LR.EndWorkDate>=@From))
ORDER BY E.EmployeeCode,T.LeaveTypeCode
""";
        await using var q = new SqlCommand(sql, c);
        Add(q,"@C",SqlDbType.BigInt,companyId); Add(q,"@From",SqlDbType.Date,from.ToDateTime(TimeOnly.MinValue)); Add(q,"@To",SqlDbType.Date,to.ToDateTime(TimeOnly.MinValue)); Add(q,"@Branch",SqlDbType.BigInt,branchId); Add(q,"@Division",SqlDbType.BigInt,divisionOrgUnitId); Add(q,"@Department",SqlDbType.BigInt,departmentOrgUnitId); Add(q,"@Employee",SqlDbType.BigInt,employeeId); Add(q,"@Type",SqlDbType.BigInt,leaveTypeId); Add(q,"@Status",SqlDbType.VarChar,normalizedStatus,20);
        await using var r = await q.ExecuteReaderAsync(token);
        var candidates = new List<(long Id,string Code,string Name,long TypeId,string TypeCode,string TypeName,string Unit,decimal Granted,decimal Used,decimal Balance,decimal Pending)>();
        while(await r.ReadAsync(token)) candidates.Add((r.GetInt64(0),r.GetString(1),r.GetString(2),r.GetInt64(3),r.GetString(4),r.GetString(5),r.GetString(6),r.GetDecimal(7),r.GetDecimal(8),r.GetDecimal(9),r.GetDecimal(13)));
        await r.CloseAsync();
        var scoped = new List<object>();
        foreach(var item in candidates)
            if(await InScope(c,companyId,userId,item.Id,token)) scoped.Add(new { employeeId=item.Id,employeeCode=item.Code,fullName=item.Name,leaveTypeId=item.TypeId,leaveTypeCode=item.TypeCode,leaveTypeName=item.TypeName,unitCode=item.Unit,granted=item.Granted,used=item.Used,pending=item.Pending,balance=item.Balance });
        var total=scoped.Count;
        return Ok(new { items=scoped.Skip((page-1)*pageSize).Take(pageSize), total, page, pageSize, fromDate=from, toDate=to });
    }

    private async Task<SqlConnection> Open(CancellationToken token){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(token);return c;}
    private bool Scope(out long company,out long user){company=0;user=0;return string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}
    private Task<bool> Can(SqlConnection c,CancellationToken token)=>CompanyMenuAccess.IsAllowedAsync(c,User,MenuCode,"VIEW",token);
    private static async Task<string> Caption(SqlConnection c,CancellationToken token){await using var q=new SqlCommand("SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@M",c);Add(q,"@M",SqlDbType.Char,MenuCode,5);return Convert.ToString(await q.ExecuteScalarAsync(token))??MenuCode;}
    private static async Task<bool> InScope(SqlConnection c,long company,long user,long employee,CancellationToken token){const string sql="""
SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADEmployee E WHERE E.CompanyID=@C AND E.EmployeeID=@E AND E.IsActive=1 AND(EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@C AND U.UserID=@U AND U.IsActive=1 AND U.IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDTMEmployeeDataScopeGrant G WHERE G.CompanyID=@C AND G.IsActive=1 AND(G.UserID=@U OR G.RoleGroupID IN(SELECT ERG.RoleGroupID FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSDATETIME()) AND(ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSDATETIME())) WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.IsActive=1)) AND G.EffectiveFrom<=SYSDATETIME() AND(G.EffectiveTo IS NULL OR G.EffectiveTo>SYSDATETIME()) AND(G.ScopeTypeCode='ALL' OR(G.ScopeTypeCode='SELF' AND EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.EmployeeID=@E AND UE.IsActive=1)) OR(G.ScopeTypeCode='DIVISION' AND G.ScopeReferenceID=E.DivisionOrgUnitID) OR(G.ScopeTypeCode='DEPARTMENT' AND G.ScopeReferenceID=E.DepartmentOrgUnitID)))) THEN 1 ELSE 0 END
""";await using var q=new SqlCommand(sql,c);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@U",SqlDbType.BigInt,user);Add(q,"@E",SqlDbType.BigInt,employee);return Convert.ToInt32(await q.ExecuteScalarAsync(token))==1;}
    private static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
    private static DateOnly ThailandToday()=>DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow,TimeZoneInfo.FindSystemTimeZoneById("Asia/Bangkok")));
    private static void Add(SqlCommand q,string name,SqlDbType type,object? value,int size=0){var p=size==0?q.Parameters.Add(name,type):q.Parameters.Add(name,type,size);p.Value=value??DBNull.Value;}
}
