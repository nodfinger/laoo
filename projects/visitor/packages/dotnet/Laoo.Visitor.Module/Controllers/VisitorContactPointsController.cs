using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooVisitorModule.Controllers;

[ApiController]
[Authorize]
[Route("api/visitor/contact-points")]
public sealed class VisitorContactPointsController(IConfiguration configuration) : ControllerBase
{
    private const string MenuCode = "33001";
    public sealed record SaveRequest(string? ContactPointCode, string? ContactPointName,
        long? BranchId, bool IsActive, IReadOnlyList<long>? EmployeeIds);

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
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "VIEW", token)) return Forbid();
        page = Math.Max(page, 1); pageSize = Math.Clamp(pageSize, 1, 100);
        var q = Clean(search) ?? string.Empty;
        await using var cmd = new SqlCommand("""
SELECT COUNT_BIG(1) OVER(),P.VisitorContactPointID,P.ContactPointCode,P.ContactPointName,P.BranchID,
       B.BranchCode,B.BranchNameTH,P.IsActive,ISNULL(A.EmployeeCount,0) EmployeeCount,A.EmployeeNames
FROM dbo.TDTMVisitorContactPoint P
JOIN dbo.TDADBranch B ON B.CompanyID=P.CompanyID AND B.BranchID=P.BranchID
OUTER APPLY (
    SELECT COUNT(*) EmployeeCount,
           STRING_AGG(CAST(CONCAT(E.EmployeeCode,N' — ',E.FullName) AS nvarchar(max)),N' | ') EmployeeNames
    FROM dbo.TDTMVisitorContactPointEmployee X
    JOIN dbo.TDADEmployee E ON E.CompanyID=X.CompanyID AND E.EmployeeID=X.EmployeeID AND E.IsActive=1
    WHERE X.CompanyID=P.CompanyID AND X.VisitorContactPointID=P.VisitorContactPointID AND X.IsActive=1
) A
WHERE P.CompanyID=@CompanyID AND (@Search=N'' OR P.ContactPointCode LIKE @Like OR P.ContactPointName LIKE @Like)
ORDER BY P.ContactPointCode,P.VisitorContactPointID OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
""", c);
        Add(cmd, "@CompanyID", SqlDbType.BigInt, companyId); Add(cmd, "@Search", SqlDbType.NVarChar, q, 200);
        Add(cmd, "@Like", SqlDbType.NVarChar, $"%{q}%", 210); Add(cmd, "@Offset", SqlDbType.Int, (page - 1) * pageSize); Add(cmd, "@PageSize", SqlDbType.Int, pageSize);
        var items = new List<object>(); long total = 0;
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) { total = r.GetInt64(0); items.Add(new { id=r.GetInt64(1), code=r.GetString(2), name=r.GetString(3), branchId=r.GetInt64(4), branchCode=r.GetString(5), branchName=r.GetString(6), isActive=r.GetBoolean(7), employeeCount=r.GetInt32(8), employeeNames=r.IsDBNull(9) ? null : r.GetString(9) }); }
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("lookups")]
    public async Task<IActionResult> Lookups([FromQuery] string? employeeSearch, [FromQuery] long? contactPointId, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "VIEW", token)) return Forbid();
        var branches = new List<object>();
        await using (var b = new SqlCommand("SELECT BranchID,BranchCode,BranchNameTH FROM dbo.TDADBranch WHERE CompanyID=@CompanyID AND IsActive=1 ORDER BY BranchCode", c))
        { Add(b,"@CompanyID",SqlDbType.BigInt,companyId); await using var r=await b.ExecuteReaderAsync(token); while(await r.ReadAsync(token)) branches.Add(new {id=r.GetInt64(0),code=r.GetString(1),name=r.GetString(2)}); }
        var q=Clean(employeeSearch) ?? string.Empty; var employees=new List<object>();
        await using (var e = new SqlCommand("""
SELECT TOP(100) E.EmployeeID,E.EmployeeCode,E.FullName,
 CASE WHEN A.VisitorContactPointID IS NULL OR A.VisitorContactPointID=@PointID THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END Available
FROM dbo.TDADEmployee E
LEFT JOIN dbo.TDTMVisitorContactPointEmployee A ON A.CompanyID=E.CompanyID AND A.EmployeeID=E.EmployeeID AND A.IsActive=1
WHERE E.CompanyID=@CompanyID AND E.IsActive=1 AND (@Search=N'' OR E.EmployeeCode LIKE @Like OR E.FullName LIKE @Like)
ORDER BY E.EmployeeCode,E.EmployeeID;
""", c))
        { Add(e,"@CompanyID",SqlDbType.BigInt,companyId); Add(e,"@PointID",SqlDbType.BigInt,contactPointId); Add(e,"@Search",SqlDbType.NVarChar,q,200); Add(e,"@Like",SqlDbType.NVarChar,$"%{q}%",210); await using var r=await e.ExecuteReaderAsync(token); while(await r.ReadAsync(token)) employees.Add(new {id=r.GetInt64(0),code=r.GetString(1),name=r.GetString(2),available=r.GetBoolean(3)}); }
        return Ok(new { branches, employees });
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token)
    {
        if (!Scope(out var companyId,out _)) return Forbid(); await using var c=await Open(token); if(!await Can(c,"VIEW",token)) return Forbid();
        await using var cmd=new SqlCommand("SELECT VisitorContactPointID,ContactPointCode,ContactPointName,BranchID,IsActive FROM dbo.TDTMVisitorContactPoint WHERE CompanyID=@CompanyID AND VisitorContactPointID=@ID",c); Add(cmd,"@CompanyID",SqlDbType.BigInt,companyId);Add(cmd,"@ID",SqlDbType.BigInt,id); long pointId; string code; string name; long branchId; bool isActive;
        await using (var r=await cmd.ExecuteReaderAsync(token)){if(!await r.ReadAsync(token)) return NotFound(new{message="ไม่พบจุดติดต่อ"}); pointId=r.GetInt64(0);code=r.GetString(1);name=r.GetString(2);branchId=r.GetInt64(3);isActive=r.GetBoolean(4);}
        var employees=await EmployeeIds(c,companyId,id,token); return Ok(new{id=pointId,code,name,branchId,isActive,employeeIds=employees});
    }

    [HttpPost]
    public Task<IActionResult> Create(SaveRequest request,CancellationToken token) => Save(null,request,"CREATE",token);
    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id,SaveRequest request,CancellationToken token) => Save(id,request,"EDIT",token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,CancellationToken token)
    {
        if(!Scope(out var companyId,out var userId)) return Forbid(); await using var c=await Open(token); if(!await Can(c,"DELETE",token)) return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try { await using var used=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMVisitorVisit WHERE CompanyID=@CompanyID AND VisitorContactPointID=@ID",c,tx);Add(used,"@CompanyID",SqlDbType.BigInt,companyId);Add(used,"@ID",SqlDbType.BigInt,id);if(Convert.ToInt64(await used.ExecuteScalarAsync(token))>0)return Conflict(new{message="จุดติดต่อมีประวัติ Check-in แล้ว จึงลบไม่ได้ กรุณาปิดการใช้งานแทน"}); await using var links=new SqlCommand("DELETE FROM dbo.TDTMVisitorContactPointEmployee WHERE CompanyID=@CompanyID AND VisitorContactPointID=@ID; DELETE FROM dbo.TDTMVisitorContactPoint WHERE CompanyID=@CompanyID AND VisitorContactPointID=@ID;",c,tx);Add(links,"@CompanyID",SqlDbType.BigInt,companyId);Add(links,"@ID",SqlDbType.BigInt,id);if(await links.ExecuteNonQueryAsync(token)==0)return NotFound(new{message="ไม่พบจุดติดต่อ"});await tx.CommitAsync(token);return NoContent(); } catch {await tx.RollbackAsync(token);throw;}
    }

    private async Task<IActionResult> Save(long? id,SaveRequest request,string action,CancellationToken token)
    {
        if(!Scope(out var companyId,out var userId))return Forbid();var code=Clean(request.ContactPointCode)?.ToUpperInvariant();var name=Clean(request.ContactPointName);var employees=(request.EmployeeIds??[]).Distinct().ToArray();if(code is null||name is null||request.BranchId is null)return BadRequest(new{message="กรุณาระบุรหัส ชื่อจุดติดต่อ และสาขา"});
        await using var c=await Open(token);if(!await Can(c,action,token))return Forbid();await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try { if(!await Branch(c,tx,companyId,request.BranchId.Value,token))return BadRequest(new{message="สาขาไม่ถูกต้องหรือไม่ Active"}); if(!await ValidEmployees(c,tx,companyId,employees,token))return BadRequest(new{message="พบพนักงานที่ไม่ Active หรืออยู่นอก Company"}); long pointId;
            if(id is null){await using var ins=new SqlCommand("INSERT dbo.TDTMVisitorContactPoint(CompanyID,BranchID,ContactPointCode,ContactPointName,IsActive,CreateBy) VALUES(@CompanyID,@BranchID,@Code,@Name,@Active,@UserID); SELECT CONVERT(bigint,SCOPE_IDENTITY());",c,tx);BindPoint(ins,companyId,request.BranchId.Value,code,name,request.IsActive,userId);pointId=Convert.ToInt64(await ins.ExecuteScalarAsync(token));}
            else {pointId=id.Value;await using var upd=new SqlCommand("UPDATE dbo.TDTMVisitorContactPoint SET BranchID=@BranchID,ContactPointCode=@Code,ContactPointName=@Name,IsActive=@Active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND VisitorContactPointID=@ID;",c,tx);BindPoint(upd,companyId,request.BranchId.Value,code,name,request.IsActive,userId);Add(upd,"@ID",SqlDbType.BigInt,pointId);if(await upd.ExecuteNonQueryAsync(token)!=1)return NotFound(new{message="ไม่พบจุดติดต่อ"});await using var off=new SqlCommand("UPDATE dbo.TDTMVisitorContactPointEmployee SET IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND VisitorContactPointID=@ID AND IsActive=1;",c,tx);Add(off,"@CompanyID",SqlDbType.BigInt,companyId);Add(off,"@ID",SqlDbType.BigInt,pointId);Add(off,"@UserID",SqlDbType.BigInt,userId);await off.ExecuteNonQueryAsync(token);}
            foreach(var employeeId in employees){await using var add=new SqlCommand("INSERT dbo.TDTMVisitorContactPointEmployee(CompanyID,VisitorContactPointID,EmployeeID,IsActive,CreateBy) VALUES(@CompanyID,@PointID,@EmployeeID,1,@UserID);",c,tx);Add(add,"@CompanyID",SqlDbType.BigInt,companyId);Add(add,"@PointID",SqlDbType.BigInt,pointId);Add(add,"@EmployeeID",SqlDbType.BigInt,employeeId);Add(add,"@UserID",SqlDbType.BigInt,userId);await add.ExecuteNonQueryAsync(token);}await tx.CommitAsync(token);return Ok(new{id=pointId});
        } catch(SqlException e) when(e.Number is 2601 or 2627){await tx.RollbackAsync(token);return Conflict(new{message="พนักงานหนึ่งคนประจำได้เพียงหนึ่งจุดติดต่อ"});}catch{await tx.RollbackAsync(token);throw;}
    }

    private async Task<List<long>> EmployeeIds(SqlConnection c,long company,long point,CancellationToken t){var result=new List<long>();await using var q=new SqlCommand("SELECT EmployeeID FROM dbo.TDTMVisitorContactPointEmployee WHERE CompanyID=@CompanyID AND VisitorContactPointID=@PointID AND IsActive=1",c);Add(q,"@CompanyID",SqlDbType.BigInt,company);Add(q,"@PointID",SqlDbType.BigInt,point);await using var r=await q.ExecuteReaderAsync(t);while(await r.ReadAsync(t))result.Add(r.GetInt64(0));return result;}
    private static async Task<bool> Branch(SqlConnection c,SqlTransaction tx,long company,long branch,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDADBranch WHERE CompanyID=@CompanyID AND BranchID=@BranchID AND IsActive=1",c,tx);Add(q,"@CompanyID",SqlDbType.BigInt,company);Add(q,"@BranchID",SqlDbType.BigInt,branch);return Convert.ToInt64(await q.ExecuteScalarAsync(t))==1;}
    private static async Task<bool> ValidEmployees(SqlConnection c,SqlTransaction tx,long company,long[] ids,CancellationToken t){if(ids.Length==0)return true;await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDADEmployee WHERE CompanyID=@CompanyID AND IsActive=1 AND EmployeeID IN ("+string.Join(',',ids.Select((_,i)=>"@E"+i))+")",c,tx);Add(q,"@CompanyID",SqlDbType.BigInt,company);for(var i=0;i<ids.Length;i++)Add(q,"@E"+i,SqlDbType.BigInt,ids[i]);return Convert.ToInt64(await q.ExecuteScalarAsync(t))==ids.Length;}
    private static void BindPoint(SqlCommand q,long company,long branch,string code,string name,bool active,long user){Add(q,"@CompanyID",SqlDbType.BigInt,company);Add(q,"@BranchID",SqlDbType.BigInt,branch);Add(q,"@Code",SqlDbType.VarChar,code,30);Add(q,"@Name",SqlDbType.NVarChar,name,200);Add(q,"@Active",SqlDbType.Bit,active);Add(q,"@UserID",SqlDbType.BigInt,user);}
    private async Task<bool> Can(SqlConnection c,string action,CancellationToken t)=>await CompanyMenuAccess.IsAllowedAsync(c,User,MenuCode,action,t);
    private async Task<string> Caption(SqlConnection c,CancellationToken t){await using var q=new SqlCommand("SELECT MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@Menu",c);Add(q,"@Menu",SqlDbType.Char,MenuCode,5);return Convert.ToString(await q.ExecuteScalarAsync(t))??MenuCode;}
    private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private bool Scope(out long company,out long user){company=user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}
    private static string? Clean(string? v)=>string.IsNullOrWhiteSpace(v)?null:v.Trim();
    private static void Add(SqlCommand q,string n,SqlDbType t,object? v,int s=0){var p=s==0?q.Parameters.Add(n,t):q.Parameters.Add(n,t,s);p.Value=v??DBNull.Value;}
}
