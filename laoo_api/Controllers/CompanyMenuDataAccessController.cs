using System.Data;
using Laoo.Shared.Contracts;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

/// <summary>Company-specific overrides for menus that opt in to data scoping.</summary>
[ApiController, Authorize, Route("api/company/menu-data-access")]
public sealed class CompanyMenuDataAccessController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");
    private static readonly HashSet<string> Scopes = ["SELF", "DEPARTMENT", "DIVISION", "ALL"];

    public sealed record PolicyRequest(string ViewScope, string EditScope, string DeleteScope,
        bool ViewHead, bool ViewManager, bool EditHead, bool EditManager, bool DeleteHead, bool DeleteManager,
        bool? ViewStaff = null, bool? EditStaff = null, bool? DeleteStaff = null);

    private Task<bool> Can(SqlConnection db, string menu, string action, CancellationToken token) =>
        CompanyProjectPermission.IsAllowedAsync(db, User, menu, action, token);

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || UserId <= 0 || !await Can(db, "10010", "VIEW", token)) return Forbid();
        var canManage = await Can(db, "10004", "EDIT", token);
        const string sql = """
SELECT DISTINCT CONVERT(nvarchar(20),M.MenuCode),M.MenuName,G.MenuGroupName,
 P.ProjectNameTH,CASE WHEN A.MenuCode IS NULL THEN 0 ELSE 1 END,
 A.ViewScope,A.EditScope,A.DeleteScope,A.ViewHead,A.ViewManager,A.EditHead,A.EditManager,A.DeleteHead,A.DeleteManager,A.ViewStaff,A.EditStaff,A.DeleteStaff,
 COALESCE(E.FullName,N''),COALESCE(E.NickName,N''),COALESCE(C.EmployeeNameDisplay,'FULL'),Audit.UpdateDate
FROM dbo.TDADMainMenu M
JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.IsActive=1
JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.IsActive=1
JOIN dbo.TDADMenuGroup G ON G.MenuGroupCode=PM.MenuGroupCode AND G.IsActive=1
LEFT JOIN dbo.TDSTMenuDataAccessPolicy A ON A.CompanyID=@company AND A.MenuCode=CONVERT(nvarchar(20),M.MenuCode)
LEFT JOIN dbo.TDSTMenuDataAccessAudit Audit ON Audit.CompanyID=@company AND Audit.MenuCode=CONVERT(nvarchar(20),M.MenuCode)
OUTER APPLY (SELECT TOP(1) e.FullName,e.NickName FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=@company AND ue.UserID=Audit.UpdateBy ORDER BY ue.IsActive DESC,e.IsActive DESC,e.EmployeeID) E
OUTER APPLY (SELECT TOP(1) EmployeeNameDisplay FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND OwnerType='C' AND IsActive=1) C
WHERE M.IsActive=1 AND M.IsVisible=1 AND M.AllowDataAccessSettings=1
ORDER BY P.ProjectNameTH,G.MenuGroupName,M.MenuName;
""";
        var candidates = new List<(string Code,string Name,string Group,string Project,bool Override,PolicyRequest? Policy,string Editor,DateTime? EditedAt)>();
        await using (var q = new SqlCommand(sql, db))
        {
            q.Parameters.AddWithValue("@company", CompanyId);
            await using var r = await q.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token))
            {
                var hasOverride = Convert.ToInt32(r.GetValue(4)) == 1;
                var policy = hasOverride ? new PolicyRequest(r.GetString(5),r.GetString(6),r.GetString(7),
                    r.GetBoolean(8),r.GetBoolean(9),r.GetBoolean(10),r.GetBoolean(11),r.GetBoolean(12),r.GetBoolean(13),r.GetBoolean(14),r.GetBoolean(15),r.GetBoolean(16)) : null;
                var full=r.GetString(17).Trim();var nick=r.GetString(18).Trim();var mode=r.GetString(19);
                var editor=mode=="NICK" && nick.Length>0 ? nick : mode=="BOTH" && full.Length>0 && nick.Length>0 ? $"{full} ({nick})" : full.Length>0 ? full : nick.Length>0 ? nick : "-";
                candidates.Add((r.GetString(0).Trim(),r.GetString(1),r.GetString(2),r.GetString(3),hasOverride,policy,editor,r.IsDBNull(20)?null:DateTime.SpecifyKind(r.GetDateTime(20),DateTimeKind.Utc)));
            }
        }
        var rows = new List<object>();
        foreach (var row in candidates)
            if (await Can(db, row.Code, "VIEW", token))
            {
                var view=await MenuDataAccessResolver.ReadRuleAsync(db,null,CompanyId,row.Code,"VIEW",token);
                var edit=await MenuDataAccessResolver.ReadRuleAsync(db,null,CompanyId,row.Code,"EDIT",token);
                var delete=await MenuDataAccessResolver.ReadRuleAsync(db,null,CompanyId,row.Code,"DELETE",token);
                var effective = view is null || edit is null || delete is null ? null :
                    new PolicyRequest(view.Scope,edit.Scope,delete.Scope,view.AllowDepartmentHead,view.AllowDivisionManager,
                        edit.AllowDepartmentHead,edit.AllowDivisionManager,delete.AllowDepartmentHead,delete.AllowDivisionManager,
                        view.AllowStaff,edit.AllowStaff,delete.AllowStaff);
                rows.Add(new { code=row.Code,name=row.Name,group=row.Group,project=row.Project,hasOverride=row.Override,policy=row.Policy,effective,updatedByName=row.Editor,updatedAt=row.EditedAt });
            }
        return Ok(new { rows, canManage });
    }

    [HttpPut("{menuCode}")]
    public async Task<IActionResult> Save(string menuCode, PolicyRequest request, CancellationToken token)
    {
        if (request is null || !Scopes.Contains(request.ViewScope) || !Scopes.Contains(request.EditScope) || !Scopes.Contains(request.DeleteScope))
            return BadRequest(new { message="เงื่อนไขการเข้าถึงข้อมูลไม่ถูกต้อง" });
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || UserId <= 0 || !await Can(db,"10010","VIEW",token) ||
            !await Can(db,"10004","EDIT",token) || !await Can(db,menuCode,"VIEW",token)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        await using var q = new SqlCommand("""
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WITH(UPDLOCK,HOLDLOCK) WHERE MenuCode=@menu AND IsActive=1 AND AllowDataAccessSettings=1)
 THROW 54210,N'Menu does not allow data access settings.',1;
UPDATE dbo.TDSTMenuDataAccessPolicy SET ViewScope=@view,EditScope=@edit,DeleteScope=@delete,
 ViewHead=@vh,ViewManager=@vm,EditHead=@eh,EditManager=@em,DeleteHead=@dh,DeleteManager=@dm,ViewStaff=@vs,EditStaff=@es,DeleteStaff=@ds,
 UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND MenuCode=@menu;
IF @@ROWCOUNT=0 INSERT dbo.TDSTMenuDataAccessPolicy
 (CompanyID,MenuCode,ViewScope,EditScope,DeleteScope,ViewHead,ViewManager,EditHead,EditManager,DeleteHead,DeleteManager,ViewStaff,EditStaff,DeleteStaff,UpdateBy)
 VALUES(@company,@menu,@view,@edit,@delete,@vh,@vm,@eh,@em,@dh,@dm,@vs,@es,@ds,@user);
UPDATE dbo.TDSTMenuDataAccessAudit SET UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND MenuCode=@menu;
IF @@ROWCOUNT=0 INSERT dbo.TDSTMenuDataAccessAudit(CompanyID,MenuCode,UpdateBy,UpdateDate) VALUES(@company,@menu,@user,SYSUTCDATETIME());
""",db,tx);
        q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);q.Parameters.AddWithValue("@menu",menuCode);
        q.Parameters.AddWithValue("@view",request.ViewScope);q.Parameters.AddWithValue("@edit",request.EditScope);q.Parameters.AddWithValue("@delete",request.DeleteScope);
        q.Parameters.AddWithValue("@vh",request.ViewScope!="SELF" && request.ViewHead);q.Parameters.AddWithValue("@vm",request.ViewScope is not ("SELF" or "DEPARTMENT") && request.ViewManager);
        q.Parameters.AddWithValue("@eh",request.EditScope!="SELF" && request.EditHead);q.Parameters.AddWithValue("@em",request.EditScope is not ("SELF" or "DEPARTMENT") && request.EditManager);
        q.Parameters.AddWithValue("@dh",request.DeleteScope!="SELF" && request.DeleteHead);q.Parameters.AddWithValue("@dm",request.DeleteScope is not ("SELF" or "DEPARTMENT") && request.DeleteManager);
        q.Parameters.AddWithValue("@vs",request.ViewScope!="SELF");
        q.Parameters.AddWithValue("@es",request.EditScope!="SELF");
        q.Parameters.AddWithValue("@ds",request.DeleteScope!="SELF");
        try { await q.ExecuteNonQueryAsync(token); await tx.CommitAsync(token); return Ok(new { saved=true }); }
        catch(SqlException ex) when(ex.Number==54210) { return BadRequest(new { message="เมนูนี้ไม่รองรับการกำหนดการเข้าถึงข้อมูล" }); }
    }

    [HttpDelete("{menuCode}")]
    public async Task<IActionResult> Reset(string menuCode, CancellationToken token)
    {
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || UserId <= 0 || !await Can(db,"10010","VIEW",token) ||
            !await Can(db,"10004","EDIT",token) || !await Can(db,menuCode,"VIEW",token)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        await using var q = new SqlCommand("IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WITH(UPDLOCK,HOLDLOCK) WHERE MenuCode=@menu AND IsActive=1 AND AllowDataAccessSettings=1) THROW 54210,N'Menu does not allow data access settings.',1; DELETE FROM dbo.TDSTMenuDataAccessPolicy WHERE CompanyID=@company AND MenuCode=@menu; UPDATE dbo.TDSTMenuDataAccessAudit SET UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND MenuCode=@menu; IF @@ROWCOUNT=0 INSERT dbo.TDSTMenuDataAccessAudit(CompanyID,MenuCode,UpdateBy,UpdateDate) VALUES(@company,@menu,@user,SYSUTCDATETIME());",db,tx);
        q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@menu",menuCode);
        q.Parameters.AddWithValue("@user",UserId);
        try { await q.ExecuteNonQueryAsync(token); await tx.CommitAsync(token); }
        catch(SqlException ex) when(ex.Number==54210) { return BadRequest(new { message="เมนูนี้ไม่รองรับการกำหนดการเข้าถึงข้อมูล" }); }
        return Ok(new { reset=true });
    }
}
