using System.Data;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/approval-assignment")]
public sealed class CompanyApprovalAssignmentController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User,"company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User,"user_id");
    private Task<bool> Can(SqlConnection db,string menu,string action,CancellationToken ct) =>
        CompanyProjectPermission.IsAllowedAsync(db,User,menu,action,ct);
    public sealed record Input(string PatternCode);
    public sealed record PersonalInput(long RequesterEmployeeId, List<long> ApproverEmployeeIds);

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,ct);
        if(CompanyId<=0 || UserId<=0 || !await Can(db,"68002","VIEW",ct)) return Forbid();
        var canManage=await Can(db,"10011","VIEW",ct) && await Can(db,"10011","EDIT",ct);
        const string sql="""
SELECT DISTINCT M.MenuCode,M.MenuName,P.ProjectNameTH,A.PatternCode,C.PatternName,P.ProjectCode,
 COALESCE(E.FullName,N''),COALESCE(E.NickName,N''),COALESCE(S.EmployeeNameDisplay,'FULL'),COALESCE(U.Username,N''),Audit.UpdateDate,
 (SELECT COUNT(DISTINCT PS.RequesterEmployeeID) FROM dbo.TDSTPersonalApprovalStep PS WHERE PS.CompanyID=@company AND PS.MenuCode=M.MenuCode)
FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.IsActive=1
JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.IsActive=1
LEFT JOIN dbo.TDSTMenuApprovalAssignment A ON A.CompanyID=@company AND A.MenuCode=M.MenuCode
LEFT JOIN dbo.TDSTApprovalPatternCatalog C ON C.CompanyID=A.CompanyID AND C.PatternCode=A.PatternCode
OUTER APPLY (
 SELECT TOP(1) T.UpdateBy,T.UpdateDate FROM (
  SELECT A.UpdateBy,A.UpdateDate WHERE A.MenuCode IS NOT NULL
  UNION ALL
  SELECT PS.UpdateBy,PS.UpdateDate FROM dbo.TDSTPersonalApprovalStep PS WHERE PS.CompanyID=@company AND PS.MenuCode=M.MenuCode
 ) T ORDER BY T.UpdateDate DESC,T.UpdateBy DESC
) Audit
LEFT JOIN dbo.TDADUser U ON U.UserID=Audit.UpdateBy AND U.CompanyID=@company
OUTER APPLY (SELECT TOP(1) E.FullName,E.NickName FROM dbo.TDADUserEmployee UE
 JOIN dbo.TDADEmployee E ON E.CompanyID=UE.CompanyID AND E.EmployeeID=UE.EmployeeID
 WHERE UE.CompanyID=@company AND UE.UserID=Audit.UpdateBy ORDER BY UE.IsActive DESC,E.IsActive DESC,E.EmployeeID) E
OUTER APPLY (SELECT TOP(1) EmployeeNameDisplay FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND OwnerType='C' AND IsActive=1) S
WHERE M.IsActive=1 AND M.IsVisible=1 AND M.RequiresApproval=1 ORDER BY P.ProjectNameTH,M.MenuName;
""";
        var candidates=new List<(string Code,string Name,string Project,string? PatternCode,string? PatternName,string ProjectCode,string Editor,DateTime? UpdatedAt,int PersonalCount)>();
        await using(var q=new SqlCommand(sql,db)) {
            q.Parameters.AddWithValue("@company",CompanyId);await using var r=await q.ExecuteReaderAsync(ct);
            while(await r.ReadAsync(ct)) {
                var full=r.GetString(6).Trim();var nick=r.GetString(7).Trim();var mode=r.GetString(8);var username=r.GetString(9).Trim();
                var editor=mode=="NICK" && nick.Length>0?nick:mode=="BOTH" && full.Length>0 && nick.Length>0?$"{full} ({nick})":full.Length>0?full:nick.Length>0?nick:username.Length>0?username:"-";
                candidates.Add((r.GetString(0).Trim(),r.GetString(1),r.GetString(2),r.IsDBNull(3)?null:r.GetString(3),r.IsDBNull(4)?null:r.GetString(4),r.GetString(5),editor,r.IsDBNull(10)?null:DateTime.SpecifyKind(r.GetDateTime(10),DateTimeKind.Utc),r.GetInt32(11)));
            }
        }
        var rows=new List<object>();
        foreach(var row in candidates) if(await Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedForProjectAsync(db,User,row.ProjectCode,row.Code,"VIEW",ct))
            rows.Add(new {code=row.Code,name=row.Name,project=row.Project,patternCode=row.PatternCode,patternName=row.PatternName,updatedByName=row.Editor,updatedAt=row.UpdatedAt,personalCount=row.PersonalCount});
        var patterns=new List<object>();
        if(canManage) {
            await using var q=new SqlCommand("SELECT PatternCode,PatternName FROM dbo.TDSTApprovalPatternCatalog WHERE CompanyID=@company ORDER BY PatternName,PatternCode",db);
            q.Parameters.AddWithValue("@company",CompanyId);await using var r=await q.ExecuteReaderAsync(ct);
            while(await r.ReadAsync(ct)) patterns.Add(new {code=r.GetString(0),name=r.GetString(1)});
        }
        return Ok(new {rows,patterns,canManage});
    }

    [HttpPut("{menuCode}")]
    public async Task<IActionResult> Save(string menuCode,Input input,CancellationToken ct)
    {
        var pattern=input?.PatternCode?.Trim();
        if(string.IsNullOrEmpty(pattern) || pattern.Length>50) return BadRequest(new {message="กรุณาเลือกรูปแบบการอนุมัติ"});
        await using var db=await RegistryControllerSupport.Open(configuration,ct);
        if(CompanyId<=0 || UserId<=0 || !await Can(db,"68002","VIEW",ct) || !await Can(db,"10011","VIEW",ct) || !await Can(db,"10011","EDIT",ct) || !await Can(db,menuCode,"VIEW",ct)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        await using var q=new SqlCommand("""
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WITH(UPDLOCK,HOLDLOCK) WHERE MenuCode=@menu AND IsActive=1 AND IsVisible=1 AND RequiresApproval=1)
 THROW 54231,N'Menu does not require approval.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDSTApprovalPatternCatalog WITH(HOLDLOCK) WHERE CompanyID=@company AND PatternCode=@pattern)
 THROW 54232,N'Approval pattern is not available.',1;
UPDATE dbo.TDSTMenuApprovalAssignment WITH(UPDLOCK,HOLDLOCK) SET PatternCode=@pattern,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND MenuCode=@menu;
IF @@ROWCOUNT=0 INSERT dbo.TDSTMenuApprovalAssignment(CompanyID,MenuCode,PatternCode,UpdateBy) VALUES(@company,@menu,@pattern,@user);
""",db,tx);
        q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);q.Parameters.AddWithValue("@menu",menuCode);q.Parameters.AddWithValue("@pattern",pattern);
        try {await q.ExecuteNonQueryAsync(ct);await tx.CommitAsync(ct);return Ok(new {saved=true});}
        catch(SqlException ex) when(ex.Number is 54231 or 54232) {return BadRequest(new {message="บันทึกไม่ได้ เมนูหรือรูปแบบอนุมัติเปลี่ยนไป กรุณาโหลดข้อมูลใหม่"});}
    }

    private async Task<bool> CanManagePersonal(SqlConnection db,string menuCode,CancellationToken ct) =>
        CompanyId>0 && UserId>0 && await Can(db,"68002","VIEW",ct) && await Can(db,"10011","VIEW",ct) &&
        await Can(db,"10011","EDIT",ct) && await Can(db,menuCode,"VIEW",ct);

    [HttpGet("{menuCode}/personal")]
    public async Task<IActionResult> Personal(string menuCode,CancellationToken ct)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,ct);
        if(!await CanManagePersonal(db,menuCode,ct))return Forbid();
        await using var q=new SqlCommand("""
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1 AND IsVisible=1 AND RequiresApproval=1) THROW 54240,N'Invalid approval menu.',1;
SELECT E.EmployeeID,COALESCE(E.FullName,N''),COALESCE(E.NickName,N''),COALESCE(D.NameTH,N''),E.IsActive,COALESCE(C.EmployeeNameDisplay,'FULL')
FROM dbo.TDADEmployee E LEFT JOIN dbo.TDADOrganizationUnit D ON D.OrgUnitID=E.DepartmentOrgUnitID AND D.CompanyID=E.CompanyID
OUTER APPLY(SELECT TOP(1) EmployeeNameDisplay FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND OwnerType='C' AND IsActive=1) C
WHERE E.CompanyID=@company ORDER BY E.FullName,E.EmployeeID;
SELECT RequesterEmployeeID,ApproverEmployeeID,StepNo FROM dbo.TDSTPersonalApprovalStep WHERE CompanyID=@company AND MenuCode=@menu ORDER BY RequesterEmployeeID,StepNo;
""",db);
        q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@menu",menuCode);
        try {
            await using var r=await q.ExecuteReaderAsync(ct);var employees=new List<object>();
            while(await r.ReadAsync(ct)) {
                var full=r.GetString(1).Trim();var nick=r.GetString(2).Trim();var mode=r.GetString(5);
                var name=mode=="NICK" && nick.Length>0?nick:mode=="BOTH" && full.Length>0 && nick.Length>0?$"{full} ({nick})":full.Length>0?full:nick.Length>0?nick:"-";
                employees.Add(new {id=r.GetInt64(0),name,department=r.GetString(3),active=r.GetBoolean(4)});
            }
            await r.NextResultAsync(ct);var steps=new List<object>();while(await r.ReadAsync(ct))steps.Add(new {requesterId=r.GetInt64(0),approverId=r.GetInt64(1),order=r.GetInt32(2)});
            return Ok(new {employees,steps});
        } catch(SqlException ex) when(ex.Number==54240) {return BadRequest(new {message="เมนูนี้ไม่รองรับการอนุมัติ กรุณาโหลดข้อมูลใหม่"});}
    }

    [HttpPut("{menuCode}/personal")]
    public async Task<IActionResult> SavePersonal(string menuCode,PersonalInput input,CancellationToken ct)
    {
        if(input is null || input.RequesterEmployeeId<=0 || input.ApproverEmployeeIds is null || input.ApproverEmployeeIds.Count==0 ||
           input.ApproverEmployeeIds.Any(x=>x<=0 || x==input.RequesterEmployeeId) || input.ApproverEmployeeIds.Distinct().Count()!=input.ApproverEmployeeIds.Count)
            return BadRequest(new {message="กรุณาเลือกผู้ทำรายการและผู้อนุมัติอย่างน้อยหนึ่งคน โดยไม่เลือกตนเองหรือชื่อซ้ำ"});
        await using var db=await RegistryControllerSupport.Open(configuration,ct);
        if(!await CanManagePersonal(db,menuCode,ct))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        await using(var valid=new SqlCommand("IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WITH(HOLDLOCK) WHERE MenuCode=@menu AND IsActive=1 AND IsVisible=1 AND RequiresApproval=1) THROW 54240,N'Invalid approval menu.',1; SELECT COUNT(*) FROM dbo.TDADEmployee WITH(HOLDLOCK) WHERE CompanyID=@company AND EmployeeID=@employee AND IsActive=1",db,tx)) {
            valid.Parameters.AddWithValue("@menu",menuCode);valid.Parameters.AddWithValue("@company",CompanyId);var id=valid.Parameters.Add("@employee",SqlDbType.BigInt);
            foreach(var employee in input.ApproverEmployeeIds.Prepend(input.RequesterEmployeeId)) {id.Value=employee;try {if(Convert.ToInt32(await valid.ExecuteScalarAsync(ct))!=1)return BadRequest(new {message="ไม่พบพนักงานที่เปิดใช้งานในบริษัท กรุณาโหลดใหม่"});} catch(SqlException ex) when(ex.Number==54240) {return BadRequest(new {message="เมนูนี้ไม่รองรับการอนุมัติ"});}}
        }
        await using(var delete=new SqlCommand("DELETE dbo.TDSTPersonalApprovalStep WHERE CompanyID=@company AND MenuCode=@menu AND RequesterEmployeeID=@requester",db,tx)) {
            delete.Parameters.AddWithValue("@company",CompanyId);delete.Parameters.AddWithValue("@menu",menuCode);delete.Parameters.AddWithValue("@requester",input.RequesterEmployeeId);await delete.ExecuteNonQueryAsync(ct);
        }
        for(var i=0;i<input.ApproverEmployeeIds.Count;i++) {
            await using var insert=new SqlCommand("INSERT dbo.TDSTPersonalApprovalStep(CompanyID,MenuCode,RequesterEmployeeID,StepNo,ApproverEmployeeID,UpdateBy) VALUES(@company,@menu,@requester,@step,@approver,@user)",db,tx);
            insert.Parameters.AddWithValue("@company",CompanyId);insert.Parameters.AddWithValue("@menu",menuCode);insert.Parameters.AddWithValue("@requester",input.RequesterEmployeeId);insert.Parameters.AddWithValue("@step",i+1);insert.Parameters.AddWithValue("@approver",input.ApproverEmployeeIds[i]);insert.Parameters.AddWithValue("@user",UserId);await insert.ExecuteNonQueryAsync(ct);
        }
        await tx.CommitAsync(ct);return Ok(new {saved=true});
    }
}
