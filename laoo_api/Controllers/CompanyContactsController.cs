using System.Data;
using System.Security.Cryptography;
using Laoo.Shared.Contracts;
using LaooApi.Ocr;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController,Authorize,Route("api/company/contacts")]
public sealed class CompanyContactsController(IConfiguration configuration,IWebHostEnvironment environment) : ControllerBase
{
    private long Company=>long.TryParse(User.FindFirst("company_id")?.Value,out var id)?id:0;
    private long Actor=>long.TryParse(User.FindFirst("user_id")?.Value,out var id)?id:0;
    private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private async Task<bool> Allowed(SqlConnection c,string action,CancellationToken t)
    {
        if(!await CompanyMenuAccess.IsAllowedAsync(c,User,"55002",action,t))return false;
        using var q=new SqlCommand("SELECT ScreenType FROM dbo.TDADMainMenu WHERE MenuCode='55002' AND IsActive=1",c);
        return Convert.ToInt32(await q.ExecuteScalarAsync(t))==1;
    }
    private static void P(SqlCommand q,string name,SqlDbType type,object? value,int size=0)
    {var p=size>0?q.Parameters.Add(name,type,size):q.Parameters.Add(name,type);p.Value=value??DBNull.Value;}
    private static string S(SqlDataReader r,int n)=>r.IsDBNull(n)?"":r.GetString(n);
    private static object Issue(string message,string description)=>new{message,description};
    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken t)
    {using var c=await Open(t);if(!await Allowed(c,"VIEW",t))return Forbid();return Ok(new{view=true,create=await Allowed(c,"CREATE",t),edit=await Allowed(c,"EDIT",t),delete=await Allowed(c,"DELETE",t)});}

    [HttpGet]
    public async Task<IActionResult> List(string? search,int page=1,int pageSize=20,CancellationToken t=default)
    {
        using var c=await Open(t);if(!await Allowed(c,"VIEW",t))return Forbid();
        page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        using var q=new SqlCommand("""
SELECT COUNT_BIG(*) OVER(),C.ContactID,C.PersonID,C.CustomerID,P.FullName,P.Mobile,P.Email,
 C.CompanyName,C.PositionName,C.Address,C.Website,C.LineID,C.IsActive,C.RowVersion,P.RowVersion,C.OwnsPerson
FROM dbo.TDADContact C JOIN dbo.TDADPerson P ON P.PersonID=C.PersonID AND P.CompanyID=C.CompanyID
WHERE C.CompanyID=@company AND C.IsDeleted=0
 AND (@search=N'' OR P.FullName LIKE @like OR P.Mobile LIKE @like OR P.Email LIKE @like OR C.CompanyName LIKE @like)
ORDER BY C.ContactID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY;
""",c);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@search",SqlDbType.NVarChar,search?.Trim()??"",250);P(q,"@like",SqlDbType.NVarChar,"%"+(search?.Trim()??"")+"%",252);
        P(q,"@offset",SqlDbType.Int,(page-1)*pageSize);P(q,"@size",SqlDbType.Int,pageSize);
        long total=0;var items=new List<object>();using var r=await q.ExecuteReaderAsync(t);
        while(await r.ReadAsync(t)){total=r.GetInt64(0);items.Add(new{contactId=r.GetInt64(1),personId=r.GetInt64(2),customerId=r.IsDBNull(3)?(long?)null:r.GetInt64(3),name=S(r,4),phone=S(r,5),email=S(r,6),company=S(r,7),position=S(r,8),address=S(r,9),website=S(r,10),line=S(r,11),isActive=r.GetBoolean(12),rowVersion=Convert.ToBase64String((byte[])r[13]),personRowVersion=Convert.ToBase64String((byte[])r[14]),ownsPerson=r.GetBoolean(15)});}
        return Ok(new{items,total,page,pageSize});
    }
    [HttpGet("lookups")]
    public async Task<IActionResult> Lookups(string? search,long? personId,long? customerId,CancellationToken t)
    {
        using var c=await Open(t);if(!await Allowed(c,"VIEW",t))return Forbid();
        var persons=new List<object>();var customers=new List<object>();
        var canPerson=await CompanyMenuAccess.IsAllowedAsync(c,User,"13002","VIEW",t);
        var canCustomer=await CompanyMenuAccess.IsAllowedAsync(c,User,"09001","VIEW",t);
        if(canPerson){
            using var q=new SqlCommand("SELECT TOP(50) PersonID,FullName,Mobile,Email,RowVersion FROM dbo.TDADPerson WHERE CompanyID=@company AND IsActive=1 AND (PersonID=@person OR @search=N'' OR FullName LIKE @like OR Mobile LIKE @like OR Email LIKE @like) ORDER BY CASE WHEN PersonID=@person THEN 0 ELSE 1 END,FullName",c);
            P(q,"@company",SqlDbType.BigInt,Company);P(q,"@person",SqlDbType.BigInt,personId);P(q,"@search",SqlDbType.NVarChar,search?.Trim()??"",250);P(q,"@like",SqlDbType.NVarChar,"%"+(search?.Trim()??"")+"%",252);
            using var r=await q.ExecuteReaderAsync(t);while(await r.ReadAsync(t))persons.Add(new{id=r.GetInt64(0),name=S(r,1),phone=S(r,2),email=S(r,3),rowVersion=Convert.ToBase64String((byte[])r[4])});
        }
        if(canCustomer){using var q=new SqlCommand("SELECT TOP(200) CustomerID,CusName FROM dbo.TDARCustomer WHERE CompanyID=@company AND IsActive=1 ORDER BY CASE WHEN CustomerID=@customer THEN 0 ELSE 1 END,CusName",c);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@customer",SqlDbType.BigInt,customerId);using var r=await q.ExecuteReaderAsync(t);while(await r.ReadAsync(t))customers.Add(new{id=r.GetInt64(0),name=S(r,1)});}
        return Ok(new{persons,customers,canEditPerson=await CompanyMenuAccess.IsAllowedAsync(c,User,"13002","EDIT",t)});
    }
    [HttpPost]
    public Task<IActionResult> Create(ContactSave request,CancellationToken t)=>Save(null,request,t);
    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id,ContactSave request,CancellationToken t)=>Save(id,request,t);
    private async Task<IActionResult> Save(long? id,ContactSave x,CancellationToken t)
    {
        using var c=await Open(t);if(!await Allowed(c,id.HasValue?"EDIT":"CREATE",t))return Forbid();
        if(string.IsNullOrWhiteSpace(x.Name)||x.Name.Length>200||(x.Phone?.Length??0)>50||(x.Email?.Length??0)>320||(x.Company?.Length??0)>250||(x.Position?.Length??0)>200||(x.Address?.Length??0)>1000||(x.Website?.Length??0)>500||(x.Line?.Length??0)>100)
            return BadRequest(Issue("ข้อมูลผู้ติดต่อไม่ถูกต้อง","ระบุชื่อ และตรวจความยาวข้อมูลแต่ละช่อง"));
        if(!string.IsNullOrWhiteSpace(x.Website) && (!Uri.TryCreate(x.Website,UriKind.Absolute,out var uri)||uri.Scheme is not ("http" or "https")))
            return BadRequest(Issue("เว็บไซต์ไม่ถูกต้อง","ระบุลิงก์ที่ขึ้นต้นด้วย https:// หรือ http://"));
        var personEdit=await CompanyMenuAccess.IsAllowedAsync(c,User,"13002","EDIT",t);
        if(x.CustomerId.HasValue && !await CompanyMenuAccess.IsAllowedAsync(c,User,"09001","VIEW",t))return Forbid();
        if(!id.HasValue && x.PersonId.HasValue && !await CompanyMenuAccess.IsAllowedAsync(c,User,"13002","VIEW",t))return Forbid();
        using var tx=c.BeginTransaction(IsolationLevel.Serializable);
        var person=x.PersonId;var owns=false;
        if(id.HasValue){
            using var q=new SqlCommand("SELECT PersonID,OwnsPerson,RowVersion FROM dbo.TDADContact WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND ContactID=@id AND IsDeleted=0",c,tx);
            P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);
            using var r=await q.ExecuteReaderAsync(t);if(!await r.ReadAsync(t))return NotFound();
            person=r.GetInt64(0);owns=r.GetBoolean(1);
            if(x.RowVersion!=Convert.ToBase64String((byte[])r[2]))return Conflict(Issue("ข้อมูลถูกแก้ไขแล้ว","เปิดรายการใหม่ก่อนบันทึกอีกครั้ง"));
        }
        if(x.CustomerId.HasValue){
            using var q=new SqlCommand("SELECT COUNT(1) FROM dbo.TDARCustomer WHERE CompanyID=@company AND CustomerID=@customer AND IsActive=1",c,tx);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@customer",SqlDbType.BigInt,x.CustomerId);
            if(Convert.ToInt32(await q.ExecuteScalarAsync(t))!=1)return Forbid();
        }
        if(person.HasValue){
            using(var q=new SqlCommand("SELECT FullName,Mobile,Email,RowVersion FROM dbo.TDADPerson WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND PersonID=@person",c,tx)){
                P(q,"@company",SqlDbType.BigInt,Company);P(q,"@person",SqlDbType.BigInt,person);
                using var r=await q.ExecuteReaderAsync(t);if(!await r.ReadAsync(t))return Forbid();
                var changed=S(r,0)!=x.Name.Trim()||S(r,1)!=(x.Phone??"").Trim()||S(r,2)!=(x.Email??"").Trim();
                if(changed&&x.PersonRowVersion!=Convert.ToBase64String((byte[])r[3]))return Conflict(Issue("ข้อมูลบุคคลเปลี่ยนแปลงแล้ว","เปิดข้อมูลล่าสุดก่อนแก้ไข"));
                if(!changed)personEdit=false;else if(!personEdit&&!owns)return StatusCode(403,Issue("ไม่มีสิทธิ์แก้ข้อมูลบุคคลร่วม","เลือกใช้ข้อมูลบุคคลเดิม หรือให้ผู้มีสิทธิ์แก้ทะเบียนบุคคล"));
                else personEdit=true;
            }
            // Owning the contact alone cannot edit identities subsequently shared with other modules.
            if(personEdit&&!await SharedPersonEditable(c,tx,person.Value,t))return StatusCode(403,Issue("บุคคลนี้ใช้ร่วมกับระบบอื่น","แก้ชื่อ เบอร์ และอีเมลผ่านทะเบียนบุคคลที่มีสิทธิ์"));
            if(personEdit){using var q=new SqlCommand("UPDATE dbo.TDADPerson SET FullName=@name,Mobile=@phone,Email=@email,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE PersonID=@person AND CompanyID=@company",c,tx);Bind(q,x);P(q,"@person",SqlDbType.BigInt,person);await q.ExecuteNonQueryAsync(t);}
            if(!id.HasValue){using var q=new SqlCommand("SELECT COUNT(1) FROM dbo.TDADContact WHERE CompanyID=@company AND PersonID=@person",c,tx);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@person",SqlDbType.BigInt,person);if(Convert.ToInt32(await q.ExecuteScalarAsync(t))>0)return Conflict(Issue("บุคคลนี้มีทะเบียนผู้ติดต่อแล้ว","ค้นหารายการเดิมก่อนเพิ่ม หากถูกลบให้ผู้ดูแลตรวจสอบ"));}
        }else{
            using var q=new SqlCommand("INSERT dbo.TDADPerson(CompanyID,FullName,Mobile,Email,IsActive,CreateBy) OUTPUT INSERTED.PersonID VALUES(@company,@name,@phone,@email,1,@actor)",c,tx);Bind(q,x);person=Convert.ToInt64(await q.ExecuteScalarAsync(t));owns=true;
        }
        using(var q=new SqlCommand(id.HasValue?"""
UPDATE dbo.TDADContact SET CustomerID=@customer,CompanyName=@companyName,PositionName=@position,Address=@address,Website=@website,LineID=@line,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor
OUTPUT INSERTED.ContactID WHERE CompanyID=@company AND ContactID=@id AND IsDeleted=0
""":"""
INSERT dbo.TDADContact(CompanyID,PersonID,OwnsPerson,CustomerID,CompanyName,PositionName,Address,Website,LineID,IsActive,CreateBy)
OUTPUT INSERTED.ContactID VALUES(@company,@person,@owns,@customer,@companyName,@position,@address,@website,@line,@active,@actor)
""",c,tx)){
            Bind(q,x);P(q,"@id",SqlDbType.BigInt,id);P(q,"@person",SqlDbType.BigInt,person);P(q,"@owns",SqlDbType.Bit,owns);
            id=Convert.ToInt64(await q.ExecuteScalarAsync(t));
        }
        await tx.CommitAsync(t);return Ok(new{contactId=id,personId=person});
    }
    private async Task<bool> SharedPersonEditable(SqlConnection c,SqlTransaction tx,long person,CancellationToken t)
    {
        using var q=new SqlCommand("""
SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADEmployee WHERE PersonID=@person AND CompanyID=@company)
 OR EXISTS(SELECT 1 FROM dbo.TDADUser WHERE PersonID=@person AND CompanyID=@company)
 OR EXISTS(SELECT 1 FROM dbo.TDADResident WHERE PersonID=@person AND CompanyID=@company)
 OR EXISTS(SELECT 1 FROM dbo.TDADServiceCustomer WHERE PersonID=@person AND CompanyID=@company)
 THEN 0 ELSE 1 END AS bit)
""",c,tx);
        P(q,"@person",SqlDbType.BigInt,person);P(q,"@company",SqlDbType.BigInt,Company);return Convert.ToBoolean(await q.ExecuteScalarAsync(t));
    }
    private void Bind(SqlCommand q,ContactSave x)
    {
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@name",SqlDbType.NVarChar,x.Name.Trim(),200);
        P(q,"@phone",SqlDbType.NVarChar,x.Phone?.Trim(),50);P(q,"@email",SqlDbType.NVarChar,x.Email?.Trim(),320);
        P(q,"@customer",SqlDbType.BigInt,x.CustomerId);P(q,"@companyName",SqlDbType.NVarChar,x.Company?.Trim(),250);
        P(q,"@position",SqlDbType.NVarChar,x.Position?.Trim(),200);P(q,"@address",SqlDbType.NVarChar,x.Address?.Trim(),1000);
        P(q,"@website",SqlDbType.NVarChar,x.Website?.Trim(),500);P(q,"@line",SqlDbType.NVarChar,x.Line?.Trim(),100);P(q,"@active",SqlDbType.Bit,x.IsActive);
    }
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,[FromQuery]string rowVersion,CancellationToken t)
    {
        using var c=await Open(t);if(!await Allowed(c,"DELETE",t))return Forbid();
        byte[] version;try{version=Convert.FromBase64String(rowVersion);}catch(FormatException){return BadRequest();}
        using var q=new SqlCommand("UPDATE dbo.TDADContact SET IsDeleted=1,IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND ContactID=@id AND RowVersion=@version AND IsDeleted=0",c);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@version",SqlDbType.Timestamp,version);
        return await q.ExecuteNonQueryAsync(t)==1?NoContent():Conflict(Issue("ลบข้อมูลไม่ได้","รายการถูกเปลี่ยนหรือถูกลบแล้ว กรุณาโหลดข้อมูลใหม่"));
    }
    private string FilePath(string name)=>Path.Combine(environment.ContentRootPath,"App_Data","contact-cards",Company.ToString(),name);
    private async Task<bool> Owns(SqlConnection c,long id,CancellationToken t){using var q=new SqlCommand("SELECT COUNT(1) FROM dbo.TDADContact WHERE CompanyID=@company AND ContactID=@id AND IsDeleted=0",c);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);return Convert.ToInt32(await q.ExecuteScalarAsync(t))==1;}
    [HttpGet("{id:long}/files")]
    public async Task<IActionResult> Files(long id,CancellationToken t){
        using var c=await Open(t);if(!await Allowed(c,"VIEW",t)||!await Owns(c,id,t))return Forbid();
        using var q=new SqlCommand("SELECT ContactFileID,OriginalName,FileSize FROM dbo.TDADContactFile WHERE CompanyID=@company AND ContactID=@id ORDER BY ContactFileID",c);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);
        using var r=await q.ExecuteReaderAsync(t);var files=new List<object>();while(await r.ReadAsync(t))files.Add(new{id=r.GetInt64(0),name=S(r,1),size=r.GetInt64(2)});return Ok(files);
    }
    [HttpPost("{id:long}/files"),RequestSizeLimit(11*1024*1024)]
    public async Task<IActionResult> Upload(long id,IFormFile? file,CancellationToken t){
        using var c=await Open(t);if(!await Owns(c,id,t))return Forbid();
        var canEdit=await Allowed(c,"EDIT",t);var canCreate=await Allowed(c,"CREATE",t);
        if(!canEdit){
            if(!canCreate)return Forbid();
            using var creator=new SqlCommand("SELECT COUNT(1) FROM dbo.TDADContact WHERE CompanyID=@company AND ContactID=@id AND CreateBy=@actor AND IsDeleted=0",c);
            P(creator,"@company",SqlDbType.BigInt,Company);P(creator,"@id",SqlDbType.BigInt,id);P(creator,"@actor",SqlDbType.BigInt,Actor);
            if(Convert.ToInt32(await creator.ExecuteScalarAsync(t))!=1)return Forbid();
        }
        using var setting=new SqlCommand("SELECT COALESCE((SELECT MaxImageSizeMB FROM dbo.TDSTBusinessCardOcrSetting WHERE CompanyID=@company),10)",c);
        P(setting,"@company",SqlDbType.BigInt,Company);var max=Convert.ToInt32(await setting.ExecuteScalarAsync(t));
        if(file is null||file.Length<=0||file.Length>max*1024L*1024)return BadRequest(Issue("ภาพไม่ถูกต้อง",$"เลือกภาพไม่เกิน {max} MB"));
        using var ms=new MemoryStream();await file.CopyToAsync(ms,t);byte[] bytes;
        try{bytes=BusinessCardImage.Normalize(ms.ToArray());}catch(OcrFailure e){return BadRequest(Issue(e.Message,e.Description));}
        var name=Guid.NewGuid().ToString("N")+".png";var path=FilePath(name);Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        await System.IO.File.WriteAllBytesAsync(path,bytes,t);
        try{using var q=new SqlCommand("INSERT dbo.TDADContactFile(CompanyID,ContactID,OriginalName,StoredName,ContentType,FileSize,Sha256,CreateBy) OUTPUT INSERTED.ContactFileID VALUES(@company,@id,@original,@stored,N'image/png',@size,@sha,@actor)",c);
            P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@original",SqlDbType.NVarChar,Path.GetFileName(file.FileName),255);P(q,"@stored",SqlDbType.NVarChar,name,100);P(q,"@size",SqlDbType.BigInt,bytes.Length);P(q,"@sha",SqlDbType.Char,Convert.ToHexString(SHA256.HashData(bytes)),64);P(q,"@actor",SqlDbType.BigInt,Actor);return Ok(new{id=Convert.ToInt64(await q.ExecuteScalarAsync(t))});}
        catch{System.IO.File.Delete(path);throw;}
    }
    [HttpGet("{id:long}/files/{fileId:long}")]
    public async Task<IActionResult> Download(long id,long fileId,CancellationToken t){
        using var c=await Open(t);if(!await Allowed(c,"VIEW",t)||!await Owns(c,id,t))return Forbid();
        using var q=new SqlCommand("SELECT StoredName FROM dbo.TDADContactFile WHERE CompanyID=@company AND ContactID=@id AND ContactFileID=@file",c);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@file",SqlDbType.BigInt,fileId);
        var name=await q.ExecuteScalarAsync(t) as string;if(name is null||Path.GetFileName(name)!=name)return NotFound();
        var path=FilePath(name);return System.IO.File.Exists(path)?PhysicalFile(path,"image/png"):NotFound();
    }
}
public sealed record ContactSave(string Name,string? Phone,string? Email,string? Company,string? Position,string? Address,string? Website,string? Line,bool IsActive=true,long? PersonId=null,long? CustomerId=null,string? RowVersion=null,string? PersonRowVersion=null);
