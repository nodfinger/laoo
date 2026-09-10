using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/vendors")]
public sealed class VendorController(IConfiguration configuration, ILogger<VendorController> logger) : ControllerBase
{
    public const string AccessSql = """
WITH Eligible AS (
 SELECT P.ProjectID,M.ScreenType FROM dbo.TDADProject P
 JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=P.ProjectID AND PM.MenuCode='08007' AND PM.IsActive=1
 JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode AND M.IsActive=1
 JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=@company AND C.PartnerID=@partner AND C.IsActive=1
 JOIN dbo.TDADPartner B ON B.PartnerID=C.PartnerID AND B.IsActive=1
 JOIN dbo.TDADCompanyProject CP ON CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.ProjectID=P.ProjectID AND CP.IsEnabled=1
 WHERE P.ProjectCode='LAOO' AND P.IsActive=1
 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
 AND (@action='VIEW' OR (M.ScreenType IN(1,4) AND @action IN('CREATE','EDIT','DELETE')) OR (M.ScreenType=2 AND @action='EDIT'))
)
SELECT CAST(CASE WHEN EXISTS(
 SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1
 AND EXISTS(SELECT 1 FROM Eligible)
 AND (U.IsCompanyAdmin=1 OR EXISTS(
 SELECT 1 FROM Eligible E JOIN dbo.TDADUserProject UP ON UP.ProjectID=E.ProjectID AND UP.CompanyID=U.CompanyID AND UP.UserID=U.UserID AND UP.IsActive=1
 WHERE EXISTS(SELECT 1 FROM dbo.TDADUserPermission DP JOIN dbo.TDADPermission P ON P.PermissionID=DP.PermissionID AND P.ProjectID=DP.ProjectID
 WHERE DP.UserID=U.UserID AND DP.ProjectID=E.ProjectID AND DP.IsActive=1 AND DP.IsAllowed=1 AND P.IsActive=1 AND P.ScreenCode='08007' AND P.ActionCode=@action)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE
 JOIN dbo.TDADEmployee EMP ON EMP.EmployeeID=UE.EmployeeID AND EMP.CompanyID=U.CompanyID AND EMP.IsActive=1
 JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=EMP.EmployeeID AND ERG.IsActive=1
 JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.CompanyID=U.CompanyID AND RG.ScopeType='C' AND RG.IsActive=1 AND RG.ProjectID=E.ProjectID
 JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=E.ProjectID AND RP.IsAllowed=1
 WHERE UE.UserID=U.UserID AND UE.CompanyID=U.CompanyID AND UE.IsActive=1 AND RP.MenuCode='08007' AND RP.ActionCode=@action
 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))
 ))) THEN 1 ELSE 0 END AS bit);
""";
    private const string Columns = "VendorID,VendorCode,VendorName,EntityTypeCode,TaxID,Address,Telephone,Email,ContactName,ContactTelephone,ContactEmail,CreditDays,Remark,IsActive,RowVersion";
    private long Company => Claim("company_id");
    private long Claim(string name) => long.TryParse(User.FindFirstValue(name), out var n) ? n : 0;
    private async Task<SqlConnection> Open(CancellationToken t) {
        var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(t); return c;
    }
    private async Task<bool> Can(SqlConnection c,string action,CancellationToken t) {
        if(User.FindFirstValue("user_type")!="COMPANY_USER" || Company<=0 || Claim("user_id")<=0 || Claim("partner_id")<=0) return false;
        await using var cmd=new SqlCommand(AccessSql,c);
        cmd.Parameters.AddWithValue("@company",Company); cmd.Parameters.AddWithValue("@partner",Claim("partner_id"));
        cmd.Parameters.AddWithValue("@user",Claim("user_id")); cmd.Parameters.AddWithValue("@action",action);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(t));
    }
    private ObjectResult Denied() => StatusCode(403,new{message="ไม่มีสิทธิ์จัดการผู้ขาย",description="กรุณาตรวจสิทธิ์เมนูผู้ขาย (08007) และขอบเขตบริษัทกับผู้ดูแลระบบ"});
    private ObjectResult Missing() => StatusCode(404,new{message="ไม่พบผู้ขาย",description="รายการนี้อาจถูกลบหรือไม่อยู่ในบริษัทที่กำลังใช้งาน กรุณาโหลดรายการใหม่"});
    private ObjectResult StaleVersion() => StatusCode(409,new{message="ข้อมูลผู้ขายมีการเปลี่ยนแปลง",description="กรุณาปิดหน้าต่างแล้วเปิดรายการใหม่ก่อนบันทึกหรือลบ"});
    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken t) {
        await using var c=await Open(t); var actions=new Dictionary<string,bool>();
        foreach(var a in new[]{"VIEW","CREATE","EDIT","DELETE"}) actions[a.ToLowerInvariant()]=await Can(c,a,t);
        return Ok(actions);
    }
    [HttpGet]
    public async Task<IActionResult> List([FromQuery]string? search,[FromQuery]bool? isActive,[FromQuery]string? entityTypeCode,
        [FromQuery]int page=1,[FromQuery]int pageSize=20,CancellationToken t=default) {
        await using var c=await Open(t); if(!await Can(c,"VIEW",t)) return Denied();
        if(page<1 || pageSize<1 || pageSize>200 || (entityTypeCode is not null and not ("PERSON" or "ORGANIZATION")))
            return BadRequest(new{message="ตัวกรองผู้ขายไม่ถูกต้อง",description="กรุณาตรวจประเภทผู้ขายและจำนวนรายการต่อหน้า (1–200)"});
        const string filter="CompanyID=@company AND (@active IS NULL OR IsActive=@active) AND (@type IS NULL OR EntityTypeCode=@type) AND (@search=N'' OR VendorCode LIKE @like ESCAPE '~' OR VendorName LIKE @like ESCAPE '~' OR TaxID LIKE @like ESCAPE '~' OR Telephone LIKE @like ESCAPE '~')";
        await using var cmd=new SqlCommand($"SELECT COUNT(*) FROM dbo.TDAPVendor WHERE {filter}; SELECT {Columns} FROM dbo.TDAPVendor WHERE {filter} ORDER BY VendorCode,VendorID OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;",c);
        cmd.Parameters.AddWithValue("@company",Company);
        Add(cmd,"@active",SqlDbType.Bit,isActive); Add(cmd,"@type",SqlDbType.VarChar,entityTypeCode,20);
        var q=search?.Trim()??""; if(q.Length>200) return BadRequest(new{message="คำค้นหายาวเกินไป",description="ระบุคำค้นหาไม่เกิน 200 ตัวอักษร"});
        Add(cmd,"@search",SqlDbType.NVarChar,q,200);
        Add(cmd,"@like",SqlDbType.NVarChar,"%"+q.Replace("~","~~").Replace("%","~%").Replace("_","~_").Replace("[","~[")+"%",402);
        cmd.Parameters.AddWithValue("@skip",((long)page-1)*pageSize); cmd.Parameters.AddWithValue("@take",pageSize);
        await using var r=await cmd.ExecuteReaderAsync(t); await r.ReadAsync(t); var total=r.GetInt32(0);
        await r.NextResultAsync(t); var items=new List<VendorResponse>(); while(await r.ReadAsync(t)) items.Add(Read(r));
        return Ok(new{items,total,page,pageSize});
    }
    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id,CancellationToken t) {
        await using var c=await Open(t); if(!await Can(c,"VIEW",t)) return Denied();
        var row=await Find(c,id,t); return row is null?Missing():Ok(row);
    }
    [HttpPost]
    public Task<IActionResult> Create(VendorRequest body,CancellationToken t)=>Save(null,body,t);
    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id,VendorRequest body,CancellationToken t)=>Save(id,body,t);
    private async Task<IActionResult> Save(long? id,VendorRequest b,CancellationToken t) {
        await using var c=await Open(t); if(!await Can(c,id.HasValue?"EDIT":"CREATE",t)) return Denied();
        if(string.IsNullOrWhiteSpace(b.VendorCode)||string.IsNullOrWhiteSpace(b.VendorName))
            return BadRequest(new{message="ข้อมูลผู้ขายไม่ครบ",description="กรุณาระบุรหัสและชื่อผู้ขาย"});
        byte[]? version=null;
        if(id.HasValue && !TryVersion(b.RowVersion,out version)) return StaleVersion();
        var sql=id.HasValue?"""
UPDATE dbo.TDAPVendor SET VendorCode=@code,VendorName=@name,EntityTypeCode=@type,TaxID=@tax,Address=@address,Telephone=@tel,Email=@email,
ContactName=@contact,ContactTelephone=@contactTel,ContactEmail=@contactEmail,CreditDays=@credit,Remark=@remark,IsActive=@active,UpdatedBy=@user,UpdateDate=SYSUTCDATETIME()
OUTPUT INSERTED.VendorID WHERE VendorID=@id AND CompanyID=@company AND RowVersion=@version
""":"""
INSERT dbo.TDAPVendor(CompanyID,CompanySetupID,VendorCode,VendorName,EntityTypeCode,TaxID,Address,Telephone,Email,ContactName,ContactTelephone,ContactEmail,CreditDays,Remark,IsActive,CreatedBy)
OUTPUT INSERTED.VendorID SELECT TOP(1) @company,PKValue,@code,@name,@type,@tax,@address,@tel,@email,@contact,@contactTel,@contactEmail,@credit,@remark,@active,@user
FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND PartnerID=@partner AND IsActive=1 ORDER BY PKValue
""";
        try {
            // Return this write's values/version atomically, not a later reread
            // that could belong to a concurrent editor.
            sql=sql.Replace("OUTPUT INSERTED.VendorID",
                "OUTPUT "+string.Join(",",Columns.Split(',').Select(x=>"INSERTED."+x)));
            await using var cmd=new SqlCommand(sql,c);
            cmd.Parameters.AddWithValue("@company",Company); cmd.Parameters.AddWithValue("@user",Claim("user_id")); cmd.Parameters.AddWithValue("@partner",Claim("partner_id"));
            Add(cmd,"@id",SqlDbType.BigInt,id); Add(cmd,"@version",SqlDbType.Timestamp,version);
            Add(cmd,"@code",SqlDbType.NVarChar,b.VendorCode.Trim(),50); Add(cmd,"@name",SqlDbType.NVarChar,b.VendorName.Trim(),200);
            Add(cmd,"@type",SqlDbType.VarChar,b.EntityTypeCode,20); Add(cmd,"@tax",SqlDbType.NVarChar,Clean(b.TaxID),50);
            Add(cmd,"@address",SqlDbType.NVarChar,Clean(b.Address),1000); Add(cmd,"@tel",SqlDbType.NVarChar,Clean(b.Telephone),50);
            Add(cmd,"@email",SqlDbType.NVarChar,Clean(b.Email),320); Add(cmd,"@contact",SqlDbType.NVarChar,Clean(b.ContactName),200);
            Add(cmd,"@contactTel",SqlDbType.NVarChar,Clean(b.ContactTelephone),50); Add(cmd,"@contactEmail",SqlDbType.NVarChar,Clean(b.ContactEmail),320);
            Add(cmd,"@credit",SqlDbType.Int,b.CreditDays); Add(cmd,"@remark",SqlDbType.NVarChar,Clean(b.Remark),1000); Add(cmd,"@active",SqlDbType.Bit,b.IsActive);
            VendorResponse? saved;
            await using(var reader=await cmd.ExecuteReaderAsync(t)) saved=await reader.ReadAsync(t)?Read(reader):null;
            if(saved is null) return id is null?Denied():await Find(c,id.Value,t) is null?Missing():StaleVersion();
            return Ok(saved);
        } catch(SqlException ex) when(ex.Number is 2601 or 2627) {
            return StatusCode(409,new{message="รหัสผู้ขายซ้ำ",description="รหัสนี้มีอยู่แล้วในบริษัท กรุณาระบุรหัสอื่น"});
        } catch(SqlException ex) {
            logger.LogError(ex,"Vendor save failed for company {Company}",Company);
            return StatusCode(500,new{message="บันทึกผู้ขายไม่สำเร็จ",description="กรุณาลองใหม่ หากยังพบปัญหาให้ติดต่อผู้ดูแลระบบ"});
        }
    }
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,[FromQuery]string rowVersion,CancellationToken t) {
        await using var c=await Open(t); if(!await Can(c,"DELETE",t)) return Denied();
        if(!TryVersion(rowVersion,out var version)) return StaleVersion();
        try {
            await using var cmd=new SqlCommand("DELETE dbo.TDAPVendor WHERE CompanyID=@company AND VendorID=@id AND RowVersion=@version",c);
            cmd.Parameters.AddWithValue("@company",Company); cmd.Parameters.AddWithValue("@id",id); Add(cmd,"@version",SqlDbType.Timestamp,version);
            if(await cmd.ExecuteNonQueryAsync(t)==0) return await Find(c,id,t) is null?Missing():StaleVersion();
            return Ok(new{message="ลบผู้ขายแล้ว"});
        } catch(SqlException ex) when(ex.Number==547) {
            return StatusCode(409,new{message="ลบผู้ขายไม่ได้",description="ผู้ขายถูกอ้างอิงในระบบแล้ว ให้ปิดสถานะใช้งานแทน"});
        }
    }
    private async Task<VendorResponse?> Find(SqlConnection c,long id,CancellationToken t) {
        await using var cmd=new SqlCommand($"SELECT {Columns} FROM dbo.TDAPVendor WHERE CompanyID=@company AND VendorID=@id",c);
        cmd.Parameters.AddWithValue("@company",Company); cmd.Parameters.AddWithValue("@id",id);
        await using var r=await cmd.ExecuteReaderAsync(t); return await r.ReadAsync(t)?Read(r):null;
    }
    private static VendorResponse Read(SqlDataReader r)=>new(r.GetInt64(0),r.GetString(1),r.GetString(2),r.GetString(3),
        Text(r,4),Text(r,5),Text(r,6),Text(r,7),Text(r,8),Text(r,9),Text(r,10),r.GetInt32(11),Text(r,12),r.GetBoolean(13),Convert.ToBase64String((byte[])r[14]));
    private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i);
    private static string? Clean(string? v)=>string.IsNullOrWhiteSpace(v)?null:v.Trim();
    private static bool TryVersion(string? value,out byte[]? bytes) {
        bytes=null; try { if(value is null)return false; bytes=Convert.FromBase64String(value); return bytes.Length==8; }catch(FormatException){return false;}
    }
    private static void Add(SqlCommand c,string name,SqlDbType type,object? value,int size=0) {
        var p=c.Parameters.Add(name,type); if(size>0)p.Size=size; p.Value=value??DBNull.Value;
    }
}
