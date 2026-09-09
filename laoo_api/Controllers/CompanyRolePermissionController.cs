using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/company-role-permissions")]
public sealed class CompanyRolePermissionController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<MenuPermissionMatrixResponse>>> List([FromQuery] long roleGroupId, CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await CompanyProjectPermission.IsAllowedAsync(connection, User, "10004", "VIEW", token)) return Denied();
        if (!await OwnsRole(connection, null, roleGroupId, token)) return NotFound();
        const string sql = """
SELECT P.ProjectID,P.ProjectNameTH,M.MenuCode,M.MenuName,G.MenuGroupCode,G.MenuGroupName,M.ScreenType,
 CAST(MAX(CASE WHEN RP.ActionCode='VIEW' AND RP.IsAllowed=1 THEN 1 ELSE 0 END) AS bit),
 CAST(MAX(CASE WHEN RP.ActionCode='CREATE' AND RP.IsAllowed=1 THEN 1 ELSE 0 END) AS bit),
 CAST(MAX(CASE WHEN RP.ActionCode='EDIT' AND RP.IsAllowed=1 THEN 1 ELSE 0 END) AS bit),
 CAST(MAX(CASE WHEN RP.ActionCode='DELETE' AND RP.IsAllowed=1 THEN 1 ELSE 0 END) AS bit)
FROM dbo.TDADProject P
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=@Company AND C.PartnerID=@Partner AND C.IsActive=1
JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=P.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1
JOIN dbo.TDADUserProject UP ON UP.ProjectID=P.ProjectID AND UP.UserID=@User AND UP.CompanyID=C.CompanyID AND UP.IsActive=1
JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=P.ProjectID AND PM.IsActive=1
JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode AND M.IsActive=1 AND M.IsVisible=1
JOIN dbo.TDADMenuGroup G ON G.MenuGroupCode=PM.MenuGroupCode AND G.IsActive=1
JOIN dbo.TDADMenuGroup OG ON OG.MenuGroupCode=M.MenuGroupCode AND OG.IsActive=1
JOIN dbo.TDADProjectMenuGroup PG ON PG.ProjectID=P.ProjectID AND PG.MenuGroupCode=G.MenuGroupCode AND PG.IsActive=1
LEFT JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=@Role AND RP.ProjectID=P.ProjectID AND RP.MenuCode=M.MenuCode
WHERE P.IsActive=1 AND UPPER(LTRIM(RTRIM(G.AudienceType))) IN ('A','C') AND UPPER(LTRIM(RTRIM(OG.AudienceType))) IN ('A','C')
 AND G.MenuGroupCode<>'07' AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
GROUP BY P.ProjectID,P.ProjectNameTH,M.MenuCode,M.MenuName,G.MenuGroupCode,G.MenuGroupName,M.ScreenType,PG.SortOrder,PM.SortOrder
ORDER BY P.ProjectID,PG.SortOrder,PM.SortOrder,M.MenuCode;
""";
        await using var command = new SqlCommand(sql, connection); Bind(command, roleGroupId);
        await using var reader = await command.ExecuteReaderAsync(token); var result = new List<MenuPermissionMatrixResponse>();
        while (await reader.ReadAsync(token)) result.Add(new MenuPermissionMatrixResponse
        {
            ProjectId=reader.GetInt64(0), ProjectName=reader.GetString(1), MenuCode=reader.GetString(2), MenuName=reader.GetString(3),
            MenuGroupCode=reader.GetString(4).Trim(), MenuGroupName=reader.GetString(5), ScreenType=reader.IsDBNull(6)?1:reader.GetInt32(6),
            CanView=reader.GetBoolean(7), CanCreate=reader.GetBoolean(8), CanEdit=reader.GetBoolean(9), CanDelete=reader.GetBoolean(10)
        });
        return Ok(result);
    }

    [HttpPut]
    public async Task<IActionResult> Save([FromQuery] long roleGroupId, [FromBody] List<MenuPermissionSaveRequest> rows, CancellationToken token)
    {
        await using var connection=await Open(token);
        if (!await CompanyProjectPermission.IsAllowedAsync(connection,User,"10004","EDIT",token)) return Denied();
        if (rows.Any(x=>!x.ProjectId.HasValue) || rows.GroupBy(x=>(x.ProjectId,x.MenuCode)).Any(x=>x.Count()>1))
            return BadRequest(new { message="ข้อมูลสิทธิ์ไม่ถูกต้อง",description="พบ Project ว่างหรือเมนูซ้ำ กรุณาโหลดรายการสิทธิ์ใหม่" });
        await using var tx=(SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try
        {
            if(!await OwnsRole(connection,tx,roleGroupId,token)){await tx.RollbackAsync(token);return NotFound();}
            foreach(var row in rows) await SaveRow(connection,tx,roleGroupId,row,token);
            await SyncRoleUsersToGrantedProjects(connection,tx,roleGroupId,token);
            await tx.CommitAsync(token); return NoContent();
        }
        catch(SqlException ex) when(ex.Number==50010){await tx.RollbackAsync(token);return BadRequest(new{message="เมนูไม่อยู่ในขอบเขตบริษัท",description="Project หรือเมนูอาจถูกปิด กรุณาโหลดรายการสิทธิ์ใหม่ก่อนบันทึก"});}
        catch{await tx.RollbackAsync(token);throw;}
    }

    [HttpDelete]
    public async Task<IActionResult> Clear([FromQuery] long roleGroupId,CancellationToken token)
    {
        await using var connection=await Open(token);
        if(!await CompanyProjectPermission.IsAllowedAsync(connection,User,"10004","DELETE",token)) return Denied();
        await using var tx=(SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable,token);
        if(!await OwnsRole(connection,tx,roleGroupId,token)){await tx.RollbackAsync(token);return NotFound();}
        await using var command=new SqlCommand("DELETE FROM dbo.TDADRoleGroupPermission WHERE RoleGroupID=@Role",connection,tx); Add(command,"@Role",SqlDbType.BigInt,roleGroupId);
        await command.ExecuteNonQueryAsync(token); await tx.CommitAsync(token); return NoContent();
    }

    private async Task SaveRow(SqlConnection c,SqlTransaction tx,long role,MenuPermissionSaveRequest row,CancellationToken token)
    {
        const string sql="""
DECLARE @Type int;
SELECT @Type=M.ScreenType FROM dbo.TDADProject P
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=@Company AND C.PartnerID=@Partner AND C.IsActive=1
JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=P.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1
JOIN dbo.TDADUserProject UP ON UP.ProjectID=P.ProjectID AND UP.UserID=@User AND UP.CompanyID=C.CompanyID AND UP.IsActive=1
JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=P.ProjectID AND PM.MenuCode=@Menu AND PM.IsActive=1
JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode AND M.IsActive=1 AND M.IsVisible=1
JOIN dbo.TDADMenuGroup G ON G.MenuGroupCode=PM.MenuGroupCode AND G.IsActive=1
JOIN dbo.TDADMenuGroup OG ON OG.MenuGroupCode=M.MenuGroupCode AND OG.IsActive=1
JOIN dbo.TDADProjectMenuGroup PG ON PG.ProjectID=P.ProjectID AND PG.MenuGroupCode=G.MenuGroupCode AND PG.IsActive=1
WHERE P.ProjectID=@Project AND P.IsActive=1 AND G.MenuGroupCode<>'07'
 AND UPPER(LTRIM(RTRIM(G.AudienceType))) IN ('A','C') AND UPPER(LTRIM(RTRIM(OG.AudienceType))) IN ('A','C')
 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME())) AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()));
IF @Type IS NULL THROW 50010,'MENU_SCOPE_INVALID',1;
DELETE FROM dbo.TDADRoleGroupPermission WHERE RoleGroupID=@Role AND ProjectID=@Project AND MenuCode=@Menu;
INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
SELECT @Role,@Project,@Menu,V.ActionCode,1,N'api' FROM (VALUES(N'VIEW',@View),(N'CREATE',@Create),(N'EDIT',@Edit),(N'DELETE',@Delete))V(ActionCode,Chosen)
WHERE V.Chosen=1 AND (@View=1 OR V.ActionCode='VIEW') AND ((@Type IN(1,4)) OR (@Type=2 AND V.ActionCode IN('VIEW','EDIT')) OR (@Type=3 AND V.ActionCode='VIEW'));
""";
        await using var command=new SqlCommand(sql,c,tx); Bind(command,role); Add(command,"@Project",SqlDbType.BigInt,row.ProjectId); Add(command,"@Menu",SqlDbType.NVarChar,row.MenuCode,20);
        Add(command,"@View",SqlDbType.Bit,row.CanView);Add(command,"@Create",SqlDbType.Bit,row.CanCreate);Add(command,"@Edit",SqlDbType.Bit,row.CanEdit);Add(command,"@Delete",SqlDbType.Bit,row.CanDelete);await command.ExecuteNonQueryAsync(token);
    }

    private async Task SyncRoleUsersToGrantedProjects(
        SqlConnection connection,
        SqlTransaction transaction,
        long roleGroupId,
        CancellationToken token)
    {
        const string sql = """
DECLARE @GrantedProjects TABLE
(
    CompanyID bigint NOT NULL,
    UserID bigint NOT NULL,
    ProjectID bigint NOT NULL,
    PRIMARY KEY (CompanyID,UserID,ProjectID)
);

INSERT @GrantedProjects(CompanyID,UserID,ProjectID)
SELECT DISTINCT RG.CompanyID,U.UserID,RP.ProjectID
FROM dbo.TDADRoleGroup RG
INNER JOIN dbo.TDADEmployeeRoleGroup ERG
    ON ERG.RoleGroupID=RG.RoleGroupID
   AND ERG.IsActive=1
   AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
   AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
INNER JOIN dbo.TDADEmployee E
    ON E.EmployeeID=ERG.EmployeeID
   AND E.CompanyID=RG.CompanyID
   AND E.IsActive=1
INNER JOIN dbo.TDADUserEmployee UE
    ON UE.EmployeeID=E.EmployeeID
   AND UE.CompanyID=RG.CompanyID
   AND UE.IsActive=1
INNER JOIN dbo.TDADUser U
    ON U.UserID=UE.UserID
   AND U.CompanyID=RG.CompanyID
   AND U.IsActive=1
INNER JOIN dbo.TDADRoleGroupPermission RP
    ON RP.RoleGroupID=RG.RoleGroupID
   AND RP.ActionCode=N'VIEW'
   AND RP.IsAllowed=1
INNER JOIN dbo.TDADProject P
    ON P.ProjectID=RP.ProjectID
   AND P.IsActive=1
INNER JOIN dbo.TDADCompanyProject CP
    ON CP.CompanyID=RG.CompanyID
   AND CP.PartnerID=@Partner
   AND CP.ProjectID=RP.ProjectID
   AND CP.IsEnabled=1
   AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
   AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
WHERE RG.RoleGroupID=@Role
  AND RG.ScopeType='C'
  AND RG.CompanyID=@Company
  AND RG.IsActive=1;

UPDATE UP
SET UP.IsActive=1,
    UP.UpdateDate=SYSUTCDATETIME(),
    UP.UpdateBy=@User
FROM dbo.TDADUserProject UP
INNER JOIN @GrantedProjects GP
    ON GP.CompanyID=UP.CompanyID
   AND GP.UserID=UP.UserID
   AND GP.ProjectID=UP.ProjectID
WHERE UP.IsActive=0;

INSERT dbo.TDADUserProject
    (CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
SELECT GP.CompanyID,GP.UserID,GP.ProjectID,0,1,SYSUTCDATETIME(),@User
FROM @GrantedProjects GP
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADUserProject UP WITH (UPDLOCK,HOLDLOCK)
    WHERE UP.CompanyID=GP.CompanyID
      AND UP.UserID=GP.UserID
      AND UP.ProjectID=GP.ProjectID
);
""";
        await using var command = new SqlCommand(sql,connection,transaction);
        Bind(command,roleGroupId);
        await command.ExecuteNonQueryAsync(token);
    }

    private async Task<bool> OwnsRole(SqlConnection c,SqlTransaction? tx,long role,CancellationToken token)
    { const string sql="SELECT COUNT(1) FROM dbo.TDADRoleGroup RG JOIN dbo.TDADProject P ON P.ProjectID=RG.ProjectID AND P.ProjectCode='LAOO' AND P.IsActive=1 WHERE RG.RoleGroupID=@Role AND RG.ScopeType='C' AND RG.CompanyID=@Company AND RG.IsActive=1";await using var command=new SqlCommand(sql,c,tx);Add(command,"@Role",SqlDbType.BigInt,role);Add(command,"@Company",SqlDbType.BigInt,Claim("company_id"));return Convert.ToInt32(await command.ExecuteScalarAsync(token))==1;}
    private ObjectResult Denied()=>StatusCode(403,new{message="ไม่มีสิทธิ์ดำเนินการ",description="บัญชีนี้ไม่มีสิทธิ์จัดการกลุ่มสิทธิ์ของบริษัท"});
    private long Claim(string name)=>long.TryParse(User.FindFirstValue(name),out var value)?value:0;
    private async Task<SqlConnection> Open(CancellationToken token){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(token);return c;}
    private void Bind(SqlCommand c,long role){Add(c,"@Role",SqlDbType.BigInt,role);Add(c,"@Company",SqlDbType.BigInt,Claim("company_id"));Add(c,"@Partner",SqlDbType.BigInt,Claim("partner_id"));Add(c,"@User",SqlDbType.BigInt,Claim("user_id"));}
    private static void Add(SqlCommand c,string name,SqlDbType type,object? value,int size=0){var p=size>0?c.Parameters.Add(name,type,size):c.Parameters.Add(name,type);p.Value=value??DBNull.Value;}
}
