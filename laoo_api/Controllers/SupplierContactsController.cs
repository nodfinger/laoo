using System.Data;
using System.Text.Json;
using Laoo.Shared.Contracts;
using LaooApi.Ocr;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController,Authorize,Route("api/company/supplier-contacts")]
public sealed class SupplierContactsController(IConfiguration configuration) : ControllerBase
{
    private long Company=>long.TryParse(User.FindFirst("company_id")?.Value,out var id)?id:0;
    private long Actor=>long.TryParse(User.FindFirst("user_id")?.Value,out var id)?id:0;
    private long Partner=>long.TryParse(User.FindFirst("partner_id")?.Value,out var id)?id:0;
    private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private async Task<bool> Allowed(SqlConnection c,string menu,string action,CancellationToken t){
        if(!await CompanyMenuAccess.IsAllowedAsync(c,User,menu,action,t))return false;
        using var q=new SqlCommand("SELECT ScreenType FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1",c);q.Parameters.AddWithValue("@menu",menu);
        return Convert.ToInt32(await q.ExecuteScalarAsync(t))==1;
    }
    private async Task<bool> Allowed(SqlConnection c,string action,CancellationToken t)=>await Allowed(c,"55003",action,t);
    private static void P(SqlCommand q,string name,SqlDbType type,object? value,int size=0){var p=size>0?q.Parameters.Add(name,type,size):q.Parameters.Add(name,type);p.Value=value??DBNull.Value;}
    private static string S(SqlDataReader r,int n)=>r.IsDBNull(n)?"":r.GetString(n);
    private const string Reviewer="""
EXISTS (SELECT 1 FROM dbo.TDSTBusinessCardReviewSetting s
 JOIN dbo.TDADUserEmployee me ON me.CompanyID=q.CompanyID AND me.UserID=@actor AND me.IsActive=1
 JOIN dbo.TDADEmployee reviewer ON reviewer.CompanyID=me.CompanyID AND reviewer.EmployeeID=me.EmployeeID AND reviewer.IsActive=1
 WHERE s.CompanyID=q.CompanyID AND s.TargetType=N'SUPPLIER' AND (
  (s.ReviewMode=N'EMPLOYEE' AND EXISTS (SELECT 1 FROM dbo.TDSTBusinessCardReviewer r WHERE r.CompanyID=q.CompanyID AND r.TargetType=N'SUPPLIER' AND r.EmployeeID=reviewer.EmployeeID))
  OR (s.ReviewMode=N'ORG' AND EXISTS (SELECT 1 FROM dbo.TDADUserEmployee su JOIN dbo.TDADEmployee sender ON sender.CompanyID=su.CompanyID AND sender.EmployeeID=su.EmployeeID AND sender.IsActive=1
   WHERE su.CompanyID=q.CompanyID AND su.UserID=q.SubmittedBy AND su.IsActive=1 AND
    ((s.OrgLevel=N'DEP' AND reviewer.DepartmentOrgUnitID IS NOT NULL AND reviewer.DepartmentOrgUnitID=sender.DepartmentOrgUnitID)
     OR (s.OrgLevel=N'DIV' AND reviewer.DivisionOrgUnitID IS NOT NULL AND reviewer.DivisionOrgUnitID=sender.DivisionOrgUnitID))))))
""";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken t){using var c=await Open(t);if(!await Allowed(c,"VIEW",t))return Forbid();return Ok(new{view=true,create=await Allowed(c,"CREATE",t),edit=await Allowed(c,"EDIT",t),delete=await Allowed(c,"DELETE",t)});}

    [HttpGet("lookups")]
    public async Task<IActionResult> Lookups(string? search,long? customerId,CancellationToken t){
        using var c=await Open(t);if(!await Allowed(c,"VIEW",t))return Forbid();
        var canView=await Allowed(c,"08007","VIEW",t);var canCreate=await Allowed(c,"08007","CREATE",t);var vendors=new List<object>();
        if(canView){using var q=new SqlCommand("SELECT TOP(200) VendorID,VendorName FROM dbo.TDAPVendor WHERE CompanyID=@company AND IsActive=1 AND (VendorID=@id OR @search=N'' OR VendorName LIKE @like OR VendorCode LIKE @like) ORDER BY CASE WHEN VendorID=@id THEN 0 ELSE 1 END,VendorName",c);
            P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,customerId);P(q,"@search",SqlDbType.NVarChar,search?.Trim()??"",250);P(q,"@like",SqlDbType.NVarChar,"%"+(search?.Trim()??"")+"%",252);
            using var r=await q.ExecuteReaderAsync(t);while(await r.ReadAsync(t))vendors.Add(new{id=r.GetInt64(0),name=S(r,1)});}
        return Ok(new{customers=vendors,canCreateCustomer=canView&&canCreate});
    }

    [HttpGet("ocr-review-queue")]
    public async Task<IActionResult> ReviewQueue(string? search,CancellationToken t){
        using var c=await Open(t);if(!await Allowed(c,"VIEW",t))return Forbid();
        var edit=await Allowed(c,"EDIT",t);var delete=await Allowed(c,"DELETE",t);var create=await Allowed(c,"CREATE",t);
        var canViewVendors=await Allowed(c,"08007","VIEW",t);var canCreateVendors=await Allowed(c,"08007","CREATE",t);
        using var q=new SqlCommand($"""
SELECT q.DraftID,JSON_VALUE(q.Payload,'$.company'),JSON_VALUE(q.Payload,'$.name'),JSON_VALUE(q.Payload,'$.phone'),JSON_VALUE(q.Payload,'$.email'),q.Status,
CASE WHEN q.Status='PENDING' AND {Reviewer} THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END,
CASE WHEN q.Status='DRAFT' AND q.SubmittedBy=@actor THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END,
CASE WHEN JSON_VALUE(q.Payload,'$.createCustomer')='true' THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END
FROM dbo.TDSTSupplierBusinessCardDraft q
WHERE q.CompanyID=@company AND q.Status IN ('DRAFT','PENDING') AND (q.SubmittedBy=@actor OR (q.Status='PENDING' AND {Reviewer}))
AND (@search=N'' OR JSON_VALUE(q.Payload,'$.company') LIKE @like OR JSON_VALUE(q.Payload,'$.name') LIKE @like OR JSON_VALUE(q.Payload,'$.phone') LIKE @like OR JSON_VALUE(q.Payload,'$.email') LIKE @like)
ORDER BY q.DraftID DESC
""",c);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@search",SqlDbType.NVarChar,search?.Trim()??"",250);P(q,"@like",SqlDbType.NVarChar,"%"+(search?.Trim()??"")+"%",252);
        var rows=new List<object>();using var r=await q.ExecuteReaderAsync(t);while(await r.ReadAsync(t))rows.Add(new{reviewId=r.GetInt64(0),company=S(r,1),name=S(r,2),phone=S(r,3),email=S(r,4),status=S(r,5),canReview=edit&&create&&canViewVendors&&(!r.GetBoolean(8)||canCreateVendors)&&r.GetBoolean(6),canSend=create&&r.GetBoolean(7),canDelete=delete&&r.GetBoolean(7)});return Ok(new{items=rows});
    }

    [HttpPost("ocr-drafts"),RequestSizeLimit(32*1024*1024)]
    public async Task<IActionResult> CreateDraft([FromBody] BusinessCardDraftRequest input,CancellationToken t){
        using var c=await Open(t);if(!await Allowed(c,"CREATE",t))return Forbid();var x=input.Contact;
        if(x is null||string.IsNullOrWhiteSpace(x.Name)||x.Name.Length>200||(x.Phone?.Length??0)>50||(x.Email?.Length??0)>320||(x.Company?.Length??0)>200||(x.Position?.Length??0)>200||(x.Address?.Length??0)>1000||(x.Website?.Length??0)>320||(x.Line?.Length??0)>100||(!x.CreateCustomer&&!x.CustomerId.HasValue)||(x.CreateCustomer&&(x.CustomerId.HasValue||string.IsNullOrWhiteSpace(x.Company)))||(input.Images?.Count??0)>2)return BadRequest(new{message="ข้อมูลแบบร่างไม่ถูกต้อง"});
        if(!string.IsNullOrWhiteSpace(x.Website)&&(!Uri.TryCreate(x.Website,UriKind.Absolute,out var url)||url.Scheme is not ("http" or "https")))return BadRequest(new{message="เว็บไซต์ไม่ถูกต้อง"});
        if(!await Allowed(c,"08007","VIEW",t)||(x.CreateCustomer&&!await Allowed(c,"08007","CREATE",t)))return Forbid();
        using var sizeQuery=new SqlCommand("SELECT COALESCE((SELECT MaxImageSizeMB FROM dbo.TDSTBusinessCardOcrSetting WHERE CompanyID=@company),10)",c);P(sizeQuery,"@company",SqlDbType.BigInt,Company);var max=Convert.ToInt32(await sizeQuery.ExecuteScalarAsync(t));
        var images=new List<(string Name,byte[] Bytes)>();foreach(var image in input.Images??[]){
            if(string.IsNullOrWhiteSpace(image.Name)||string.IsNullOrEmpty(image.Data))return BadRequest(new{message="รูปนามบัตรไม่ถูกต้อง"});byte[] raw;try{raw=Convert.FromBase64String(image.Data);}catch(FormatException){return BadRequest(new{message="รูปนามบัตรไม่ถูกต้อง"});}
            if(raw.Length==0||raw.Length>max*1024L*1024)return BadRequest(new{message="ขนาดรูปนามบัตรไม่ถูกต้อง"});try{images.Add((Path.GetFileName(image.Name),BusinessCardImage.Normalize(raw)));}catch(OcrFailure e){return BadRequest(new{message=e.Message,description=e.Description});}}
        using var tx=c.BeginTransaction(IsolationLevel.Serializable);
        if(x.CustomerId.HasValue){using var check=new SqlCommand("SELECT COUNT(1) FROM dbo.TDAPVendor WHERE CompanyID=@company AND VendorID=@id AND IsActive=1",c,tx);P(check,"@company",SqlDbType.BigInt,Company);P(check,"@id",SqlDbType.BigInt,x.CustomerId);if(Convert.ToInt32(await check.ExecuteScalarAsync(t))!=1)return Forbid();}
        using var q=new SqlCommand("INSERT dbo.TDSTSupplierBusinessCardDraft(CompanyID,SubmittedBy,Payload) OUTPUT INSERTED.DraftID VALUES(@company,@actor,@payload)",c,tx);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@payload",SqlDbType.NVarChar,JsonSerializer.Serialize(x with {FromOcr=true},new JsonSerializerOptions{PropertyNamingPolicy=JsonNamingPolicy.CamelCase}));var id=Convert.ToInt64(await q.ExecuteScalarAsync(t));
        foreach(var image in images){using var iq=new SqlCommand("INSERT dbo.TDSTSupplierBusinessCardDraftImage(CompanyID,DraftID,OriginalName,ImageData) VALUES(@company,@id,@name,@data)",c,tx);P(iq,"@company",SqlDbType.BigInt,Company);P(iq,"@id",SqlDbType.BigInt,id);P(iq,"@name",SqlDbType.NVarChar,image.Name,255);P(iq,"@data",SqlDbType.VarBinary,image.Bytes);await iq.ExecuteNonQueryAsync(t);}await tx.CommitAsync(t);return Ok(new{draftId=id});
    }

    [HttpGet("ocr-drafts/{id:long}")]
    public async Task<IActionResult> Details(long id,CancellationToken t){using var c=await Open(t);if(!await Allowed(c,"VIEW",t))return Forbid();using var q=new SqlCommand($"SELECT q.Payload FROM dbo.TDSTSupplierBusinessCardDraft q WHERE q.CompanyID=@company AND q.DraftID=@id AND (q.SubmittedBy=@actor OR (q.Status='PENDING' AND {Reviewer})) AND q.Status IN ('DRAFT','PENDING')",c);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@actor",SqlDbType.BigInt,Actor);var payload=await q.ExecuteScalarAsync(t) as string;if(payload is null)return NotFound();using var iq=new SqlCommand("SELECT OriginalName,ImageData FROM dbo.TDSTSupplierBusinessCardDraftImage WHERE CompanyID=@company AND DraftID=@id ORDER BY DraftImageID",c);P(iq,"@company",SqlDbType.BigInt,Company);P(iq,"@id",SqlDbType.BigInt,id);using var r=await iq.ExecuteReaderAsync(t);var images=new List<object>();while(await r.ReadAsync(t))images.Add(new{name=S(r,0),data=Convert.ToBase64String((byte[])r[1])});return Ok(new{contact=JsonSerializer.Deserialize<JsonElement>(payload),images});}
    [HttpGet("{contactId:long}/images/{imageId:long}")]
    public async Task<IActionResult> Image(long contactId,long imageId,CancellationToken t){using var c=await Open(t);if(!await Allowed(c,"VIEW",t))return Forbid();using var q=new SqlCommand("SELECT i.ImageData FROM dbo.TDSTSupplierBusinessCardDraftImage i JOIN dbo.TDSTSupplierBusinessCardDraft d ON d.CompanyID=i.CompanyID AND d.DraftID=i.DraftID WHERE d.CompanyID=@company AND d.VendorContactID=@contact AND d.Status='APPROVED' AND i.DraftImageID=@image",c);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@contact",SqlDbType.BigInt,contactId);P(q,"@image",SqlDbType.BigInt,imageId);var bytes=await q.ExecuteScalarAsync(t) as byte[];return bytes is null?NotFound():File(bytes,"image/png");}
    [HttpPost("ocr-drafts/{id:long}/send")]
    public async Task<IActionResult> Send(long id,CancellationToken t)=>await Transition(id,"CREATE","PENDING",t);
    [HttpDelete("ocr-drafts/{id:long}")]
    public async Task<IActionResult> Delete(long id,CancellationToken t)=>await Transition(id,"DELETE","DELETED",t);
    [HttpPost("ocr-review-queue/{id:long}/complete")]
    public async Task<IActionResult> Complete(long id,CancellationToken t){
        using var c=await Open(t);if(!await Allowed(c,"EDIT",t)||!await Allowed(c,"CREATE",t)||!await Allowed(c,"08007","VIEW",t))return Forbid();
        var canCreateVendor=await Allowed(c,"08007","CREATE",t);
        using var tx=c.BeginTransaction(IsolationLevel.Serializable);
        using var locked=new SqlCommand($"SELECT q.Payload FROM dbo.TDSTSupplierBusinessCardDraft q WITH(UPDLOCK,HOLDLOCK) WHERE q.CompanyID=@company AND q.DraftID=@id AND q.Status='PENDING' AND {Reviewer}",c,tx);
        P(locked,"@company",SqlDbType.BigInt,Company);P(locked,"@actor",SqlDbType.BigInt,Actor);P(locked,"@id",SqlDbType.BigInt,id);
        var payload=await locked.ExecuteScalarAsync(t) as string;if(payload is null)return NotFound();
        var x=JsonSerializer.Deserialize<ContactSave>(payload,new JsonSerializerOptions{PropertyNameCaseInsensitive=true});if(x is null||string.IsNullOrWhiteSpace(x.Name))return BadRequest(new{message="ข้อมูลแบบร่างไม่ถูกต้อง"});
        long? vendor=x.CustomerId;
        if(x.CreateCustomer){
            if(!canCreateVendor)return Forbid();
            using var create=new SqlCommand("""
DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource=N'LAOO_OCR_VENDOR_CODE',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
IF @lock<0 THROW 51000,N'ไม่สามารถออกรหัสผู้ขายได้',1;
DECLARE @number bigint; SELECT @number=ISNULL(MAX(TRY_CONVERT(bigint,SUBSTRING(VendorCode,4,7))),0)+1 FROM dbo.TDAPVendor WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND LEN(VendorCode)=10 AND VendorCode LIKE N'OCR[0-9][0-9][0-9][0-9][0-9][0-9][0-9]';
IF @number>9999999 THROW 51001,N'รหัสผู้ขายถึงจำนวนสูงสุด',1;
INSERT dbo.TDAPVendor(CompanyID,CompanySetupID,VendorCode,VendorName,EntityTypeCode,Address,Telephone,Email,ContactName,ContactTelephone,ContactEmail,CreditDays,IsActive,CreatedBy,DataSource)
OUTPUT INSERTED.VendorID SELECT TOP(1) @company,PKValue,N'OCR'+RIGHT(N'0000000'+CONVERT(nvarchar(7),@number),7),@companyName,'ORGANIZATION',@address,@phone,@email,@name,@phone,@email,0,1,@actor,1 FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND PartnerID=@partner AND IsActive=1 ORDER BY PKValue;
""",c,tx);
            P(create,"@company",SqlDbType.BigInt,Company);P(create,"@partner",SqlDbType.BigInt,Partner);P(create,"@actor",SqlDbType.BigInt,Actor);P(create,"@companyName",SqlDbType.NVarChar,x.Company?.Trim(),200);P(create,"@address",SqlDbType.NVarChar,x.Address?.Trim(),1000);P(create,"@phone",SqlDbType.NVarChar,x.Phone?.Trim(),50);P(create,"@email",SqlDbType.NVarChar,x.Email?.Trim(),320);P(create,"@name",SqlDbType.NVarChar,x.Name.Trim(),200);
            var created=await create.ExecuteScalarAsync(t);if(created is null)return Forbid();vendor=Convert.ToInt64(created);
        }
        using(var check=new SqlCommand("SELECT COUNT(1) FROM dbo.TDAPVendor WHERE CompanyID=@company AND VendorID=@vendor AND IsActive=1",c,tx)){P(check,"@company",SqlDbType.BigInt,Company);P(check,"@vendor",SqlDbType.BigInt,vendor);if(Convert.ToInt32(await check.ExecuteScalarAsync(t))!=1)return Forbid();}
        using var contact=new SqlCommand("INSERT dbo.TDAPVendorContact(CompanyID,VendorID,FullName,PositionName,Phone,Email,Address,Website,LineID,CreatedBy) OUTPUT INSERTED.VendorContactID VALUES(@company,@vendor,@name,@position,@phone,@email,@address,@website,@line,@actor)",c,tx);
        P(contact,"@company",SqlDbType.BigInt,Company);P(contact,"@vendor",SqlDbType.BigInt,vendor);P(contact,"@name",SqlDbType.NVarChar,x.Name.Trim(),200);P(contact,"@position",SqlDbType.NVarChar,x.Position?.Trim(),200);P(contact,"@phone",SqlDbType.NVarChar,x.Phone?.Trim(),50);P(contact,"@email",SqlDbType.NVarChar,x.Email?.Trim(),320);P(contact,"@address",SqlDbType.NVarChar,x.Address?.Trim(),1000);P(contact,"@website",SqlDbType.NVarChar,x.Website?.Trim(),320);P(contact,"@line",SqlDbType.NVarChar,x.Line?.Trim(),100);P(contact,"@actor",SqlDbType.BigInt,Actor);
        var contactId=Convert.ToInt64(await contact.ExecuteScalarAsync(t));
        using var update=new SqlCommand("UPDATE dbo.TDSTSupplierBusinessCardDraft SET Status='APPROVED',ReviewedAt=SYSUTCDATETIME(),ReviewedBy=@actor,VendorID=@vendor,VendorContactID=@contact WHERE CompanyID=@company AND DraftID=@id AND Status='PENDING'",c,tx);
        P(update,"@company",SqlDbType.BigInt,Company);P(update,"@id",SqlDbType.BigInt,id);P(update,"@actor",SqlDbType.BigInt,Actor);P(update,"@vendor",SqlDbType.BigInt,vendor);P(update,"@contact",SqlDbType.BigInt,contactId);await update.ExecuteNonQueryAsync(t);await tx.CommitAsync(t);return Ok(new{vendorId=vendor,vendorContactId=contactId});
    }
    private async Task<IActionResult> Transition(long id,string action,string state,CancellationToken t){using var c=await Open(t);if(!await Allowed(c,action,t))return Forbid();using var q=new SqlCommand("UPDATE dbo.TDSTSupplierBusinessCardDraft SET Status=@state,SentAt=CASE WHEN @state='PENDING' THEN SYSUTCDATETIME() ELSE SentAt END WHERE CompanyID=@company AND DraftID=@id AND SubmittedBy=@actor AND Status='DRAFT'",c);P(q,"@state",SqlDbType.VarChar,state,12);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@actor",SqlDbType.BigInt,Actor);return await q.ExecuteNonQueryAsync(t)==1?NoContent():Conflict(new{message="แบบร่างถูกเปลี่ยนสถานะหรือไม่มีสิทธิ์"});}
}
