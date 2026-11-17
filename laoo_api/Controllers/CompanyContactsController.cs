using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.Json;
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
    private async Task<bool> CanCreateCustomer(SqlConnection c,CancellationToken t, ClaimsPrincipal? principal=null)
    {
        var actor=principal??User;
        if(!long.TryParse(actor.FindFirst("partner_id")?.Value,out var partner) ||
           !long.TryParse(actor.FindFirst("project_id")?.Value,out _) ||
           !long.TryParse(actor.FindFirst("user_id")?.Value,out var actorId) ||
           !await CompanyMenuAccess.IsSalesEnabledAsync(c,actor,t) ||
           !await CompanyMenuAccess.IsAllowedAsync(c,actor,"09001","CREATE",t) ||
           !await CompanyMenuAccess.IsAllowedAsync(c,actor,"09001","VIEW",t)) return false;
        using var q=new SqlCommand($"""
SELECT CAST(CASE WHEN EXISTS (
 SELECT 1 FROM dbo.TDSTCompanySetUp C
 JOIN dbo.TDADProject P ON P.ProjectCode=N'LAOO' AND P.IsActive=1
 JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=P.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1
  AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME())) AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
 JOIN dbo.TDADUser AccessUser ON AccessUser.UserID=@user AND AccessUser.CompanyID=C.CompanyID
 WHERE C.CompanyID=@company AND C.PartnerID=@partner AND C.IsActive=1 AND {CompanyProjectAccess.ForUser("AccessUser","P.ProjectID",allowCoreShell:true)}
) THEN 1 ELSE 0 END AS bit)
""",c);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@partner",SqlDbType.BigInt,partner);P(q,"@user",SqlDbType.BigInt,actorId);
        return Convert.ToBoolean(await q.ExecuteScalarAsync(t));
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
        if(canCustomer){using var q=new SqlCommand("SELECT TOP(200) CustomerID,CusName FROM dbo.TDARCustomer WHERE CompanyID=@company AND IsActive=1 AND (CustomerID=@customer OR @search=N'' OR CusName LIKE @like OR CusCode LIKE @like) ORDER BY CASE WHEN CustomerID=@customer THEN 0 ELSE 1 END,CusName",c);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@customer",SqlDbType.BigInt,customerId);P(q,"@search",SqlDbType.NVarChar,search?.Trim()??"",250);P(q,"@like",SqlDbType.NVarChar,"%"+(search?.Trim()??"")+"%",252);using var r=await q.ExecuteReaderAsync(t);while(await r.ReadAsync(t))customers.Add(new{id=r.GetInt64(0),name=S(r,1)});}
        return Ok(new{persons,customers,canCreateCustomer=await CanCreateCustomer(c,t),canEditPerson=await CompanyMenuAccess.IsAllowedAsync(c,User,"13002","EDIT",t)});
    }

    // A reviewer must be configured by employee or share the configured
    // organization unit with the submitting employee in the same company.
    private const string ReviewerPredicate = """
EXISTS (SELECT 1 FROM dbo.TDSTBusinessCardReviewSetting s
 JOIN dbo.TDADUserEmployee me ON me.CompanyID=q.CompanyID AND me.UserID=@actor AND me.IsActive=1
 JOIN dbo.TDADEmployee reviewer ON reviewer.CompanyID=me.CompanyID AND reviewer.EmployeeID=me.EmployeeID AND reviewer.IsActive=1
 WHERE s.CompanyID=q.CompanyID AND s.TargetType=N'CUSTOMER' AND (
  (s.ReviewMode=N'EMPLOYEE' AND EXISTS (SELECT 1 FROM dbo.TDSTBusinessCardReviewer r WHERE r.CompanyID=q.CompanyID AND r.TargetType=N'CUSTOMER' AND r.EmployeeID=reviewer.EmployeeID))
  OR (s.ReviewMode=N'ORG' AND EXISTS (SELECT 1 FROM dbo.TDADUserEmployee su JOIN dbo.TDADEmployee sender ON sender.CompanyID=su.CompanyID AND sender.EmployeeID=su.EmployeeID AND sender.IsActive=1
   WHERE su.CompanyID=q.CompanyID AND su.UserID=q.SubmittedBy AND su.IsActive=1 AND
    ((s.OrgLevel=N'DEP' AND reviewer.DepartmentOrgUnitID IS NOT NULL AND reviewer.DepartmentOrgUnitID=sender.DepartmentOrgUnitID)
     OR (s.OrgLevel=N'DIV' AND reviewer.DivisionOrgUnitID IS NOT NULL AND reviewer.DivisionOrgUnitID=sender.DivisionOrgUnitID))))))
""";

    [HttpGet("ocr-review-queue")]
    public async Task<IActionResult> ReviewQueue(string? search,CancellationToken t)
    {
        using var c=await Open(t);if(!await Allowed(c,"VIEW",t))return Forbid();
        var canEdit=await Allowed(c,"EDIT",t);var canDelete=await Allowed(c,"DELETE",t);var canCreate=await Allowed(c,"CREATE",t);
        using var q=new SqlCommand($"""
SELECT q.DraftID,JSON_VALUE(q.Payload,'$.company'),JSON_VALUE(q.Payload,'$.name'),JSON_VALUE(q.Payload,'$.phone'),JSON_VALUE(q.Payload,'$.email'),q.Status,
 CASE WHEN q.Status='PENDING' AND {ReviewerPredicate} THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END,
 CASE WHEN q.Status='DRAFT' AND q.SubmittedBy=@actor THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END
FROM dbo.TDSTBusinessCardDraft q
WHERE q.CompanyID=@company AND q.Status IN ('DRAFT','PENDING')
 AND (q.SubmittedBy=@actor OR (q.Status='PENDING' AND {ReviewerPredicate}))
 AND (@search=N'' OR JSON_VALUE(q.Payload,'$.company') LIKE @like OR JSON_VALUE(q.Payload,'$.name') LIKE @like OR JSON_VALUE(q.Payload,'$.phone') LIKE @like OR JSON_VALUE(q.Payload,'$.email') LIKE @like)
ORDER BY q.DraftID DESC
""",c);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@search",SqlDbType.NVarChar,search?.Trim()??"",250);P(q,"@like",SqlDbType.NVarChar,"%"+(search?.Trim()??"")+"%",252);
        var rows=new List<object>();using var r=await q.ExecuteReaderAsync(t);
        while(await r.ReadAsync(t))rows.Add(new{reviewId=r.GetInt64(0),company=S(r,1),name=S(r,2),phone=S(r,3),email=S(r,4),status=S(r,5),canReview=canEdit&&canCreate&&r.GetBoolean(6),canEdit=canEdit&&r.GetBoolean(7),canSend=canCreate&&r.GetBoolean(7),canDelete=canDelete&&r.GetBoolean(7)});
        return Ok(new{items=rows});
    }

    [HttpPost("ocr-review-queue/{id:long}/complete")]
    public async Task<IActionResult> CompleteReview(long id,CancellationToken t)
    {
        using var c=await Open(t);if(!await Allowed(c,"EDIT",t))return Forbid();
        using var q=new SqlCommand($"SELECT q.Payload FROM dbo.TDSTBusinessCardDraft q WHERE q.CompanyID=@company AND q.DraftID=@id AND q.Status='PENDING' AND {ReviewerPredicate}",c);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@id",SqlDbType.BigInt,id);
        var json=await q.ExecuteScalarAsync(t) as string;
        if(json is null)return NotFound();
        var data=JsonSerializer.Deserialize<ContactSave>(json,new JsonSerializerOptions{PropertyNameCaseInsensitive=true});
        if(data is null)return BadRequest(Issue("ข้อมูลแบบร่างไม่ถูกต้อง","กรุณาติดต่อผู้ดูแลระบบ"));
        return await Save(null,data,t,id);
    }

    [HttpPost("ocr-drafts"),RequestSizeLimit(32*1024*1024)]
    public async Task<IActionResult> CreateDraft([FromBody] BusinessCardDraftRequest input,CancellationToken t)
    {
        using var c=await Open(t);if(!await Allowed(c,"CREATE",t))return Forbid();
        var x=input.Contact;
        if(x is null||string.IsNullOrWhiteSpace(x.Name)||x.Name.Length>200||(x.Phone?.Length??0)>50||(x.Email?.Length??0)>320||(x.Company?.Length??0)>200||(x.Position?.Length??0)>200||(x.Address?.Length??0)>1000||(x.Website?.Length??0)>320||(x.Line?.Length??0)>100||(!x.CreateCustomer&&!x.CustomerId.HasValue)||(x.CreateCustomer&&(x.CustomerId.HasValue||string.IsNullOrWhiteSpace(x.Company)))||(input.Images?.Count??0)>2)
            return BadRequest(Issue("ข้อมูลแบบร่างไม่ถูกต้อง","ตรวจชื่อผู้ติดต่อ ลูกค้า และรูปนามบัตร"));
        if(!string.IsNullOrWhiteSpace(x.Website)&&(!Uri.TryCreate(x.Website,UriKind.Absolute,out var website)||website.Scheme is not ("http" or "https")))return BadRequest(Issue("เว็บไซต์ไม่ถูกต้อง","ระบุลิงก์ที่ขึ้นต้นด้วย https:// หรือ http://"));
        if(x.CreateCustomer&&!await CanCreateCustomer(c,t))return Forbid();
        if(x.CustomerId.HasValue&&!await CompanyMenuAccess.IsAllowedAsync(c,User,"09001","VIEW",t))return Forbid();
        using var sizeQuery=new SqlCommand("SELECT COALESCE((SELECT MaxImageSizeMB FROM dbo.TDSTBusinessCardOcrSetting WHERE CompanyID=@company),10)",c);
        P(sizeQuery,"@company",SqlDbType.BigInt,Company);var max=Convert.ToInt32(await sizeQuery.ExecuteScalarAsync(t));
        var images=new List<(string Name,byte[] Bytes)>();
        foreach(var image in input.Images??[]){
            if(string.IsNullOrWhiteSpace(image.Name)||string.IsNullOrEmpty(image.Data))return BadRequest(Issue("รูปนามบัตรไม่ถูกต้อง","กรุณาเลือกภาพใหม่"));
            byte[] raw;try{raw=Convert.FromBase64String(image.Data);}catch(FormatException){return BadRequest(Issue("รูปนามบัตรไม่ถูกต้อง","กรุณาเลือกภาพใหม่"));}
            if(raw.Length==0||raw.Length>max*1024L*1024)return BadRequest(Issue("รูปนามบัตรไม่ถูกต้อง",$"ขนาดภาพต้องไม่เกิน {max} MB"));
            try{images.Add((Path.GetFileName(image.Name),BusinessCardImage.Normalize(raw)));}catch(OcrFailure e){return BadRequest(Issue(e.Message,e.Description));}
        }
        using var tx=c.BeginTransaction(IsolationLevel.Serializable);
        if(x.CustomerId.HasValue){using var check=new SqlCommand("SELECT COUNT(1) FROM dbo.TDARCustomer WHERE CompanyID=@company AND CustomerID=@id AND IsActive=1",c,tx);P(check,"@company",SqlDbType.BigInt,Company);P(check,"@id",SqlDbType.BigInt,x.CustomerId);if(Convert.ToInt32(await check.ExecuteScalarAsync(t))!=1)return Forbid();}
        using var q=new SqlCommand("INSERT dbo.TDSTBusinessCardDraft(CompanyID,SubmittedBy,Payload) OUTPUT INSERTED.DraftID VALUES(@company,@actor,@payload)",c,tx);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@payload",SqlDbType.NVarChar,JsonSerializer.Serialize(x with {FromOcr=true},new JsonSerializerOptions{PropertyNamingPolicy=JsonNamingPolicy.CamelCase}),-1);
        var id=Convert.ToInt64(await q.ExecuteScalarAsync(t));
        foreach(var image in images){using var iq=new SqlCommand("INSERT dbo.TDSTBusinessCardDraftImage(CompanyID,DraftID,OriginalName,ImageData) VALUES(@company,@id,@name,@data)",c,tx);P(iq,"@company",SqlDbType.BigInt,Company);P(iq,"@id",SqlDbType.BigInt,id);P(iq,"@name",SqlDbType.NVarChar,image.Name,255);P(iq,"@data",SqlDbType.VarBinary,image.Bytes,-1);await iq.ExecuteNonQueryAsync(t);}
        await tx.CommitAsync(t);return Ok(new{draftId=id});
    }

    [HttpPut("ocr-drafts/{id:long}")]
    public async Task<IActionResult> UpdateDraft(long id,[FromBody] BusinessCardDraftRequest input,CancellationToken t)
    {
        using var c=await Open(t);if(!await Allowed(c,"EDIT",t))return Forbid();
        var x=input.Contact;
        if(x is null||string.IsNullOrWhiteSpace(x.Name)||x.Name.Length>200||(x.Phone?.Length??0)>50||(x.Email?.Length??0)>320||(x.Company?.Length??0)>200||(x.Position?.Length??0)>200||(x.Address?.Length??0)>1000||(x.Website?.Length??0)>320||(x.Line?.Length??0)>100||(!x.CreateCustomer&&!x.CustomerId.HasValue)||(x.CreateCustomer&&(x.CustomerId.HasValue||string.IsNullOrWhiteSpace(x.Company)))||(input.Images?.Count??0)>0)
            return BadRequest(Issue("ข้อมูลแบบร่างไม่ถูกต้อง","ตรวจชื่อผู้ติดต่อ ลูกค้า และรูปนามบัตรเดิม"));
        if(!string.IsNullOrWhiteSpace(x.Website)&&(!Uri.TryCreate(x.Website,UriKind.Absolute,out var website)||website.Scheme is not ("http" or "https")))return BadRequest(Issue("เว็บไซต์ไม่ถูกต้อง","ระบุลิงก์ที่ขึ้นต้นด้วย https:// หรือ http://"));
        if(x.CreateCustomer&&!await CanCreateCustomer(c,t))return Forbid();
        if(x.CustomerId.HasValue&&!await CompanyMenuAccess.IsAllowedAsync(c,User,"09001","VIEW",t))return Forbid();
        byte[] version;try{version=Convert.FromBase64String(x.RowVersion??"");}catch(FormatException){return BadRequest(Issue("ข้อมูลแบบร่างไม่ถูกต้อง","กรุณาเปิดแบบร่างใหม่"));}if(version.Length!=8)return BadRequest(Issue("ข้อมูลแบบร่างไม่ถูกต้อง","กรุณาเปิดแบบร่างใหม่"));
        using var tx=c.BeginTransaction(IsolationLevel.Serializable);
        if(x.CustomerId.HasValue){using var check=new SqlCommand("SELECT COUNT(1) FROM dbo.TDARCustomer WHERE CompanyID=@company AND CustomerID=@id AND IsActive=1",c,tx);P(check,"@company",SqlDbType.BigInt,Company);P(check,"@id",SqlDbType.BigInt,x.CustomerId);if(Convert.ToInt32(await check.ExecuteScalarAsync(t))!=1)return Forbid();}
        using var q=new SqlCommand("UPDATE dbo.TDSTBusinessCardDraft SET Payload=@payload WHERE CompanyID=@company AND DraftID=@id AND SubmittedBy=@actor AND Status='DRAFT' AND RowVersion=@version",c,tx);
        P(q,"@payload",SqlDbType.NVarChar,JsonSerializer.Serialize(x with {FromOcr=true,RowVersion=null},new JsonSerializerOptions{PropertyNamingPolicy=JsonNamingPolicy.CamelCase}),-1);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@version",SqlDbType.Timestamp,version);
        if(await q.ExecuteNonQueryAsync(t)!=1)return Conflict(Issue("แก้ไขแบบร่างไม่ได้","แบบร่างถูกแก้ไข ส่งตรวจ หรือไม่มีสิทธิ์ กรุณาเปิดใหม่"));
        await tx.CommitAsync(t);return NoContent();
    }

    [HttpPost("ocr-drafts/{id:long}/send")]
    public async Task<IActionResult> SendDraft(long id,CancellationToken t)
    {
        using var c=await Open(t);if(!await Allowed(c,"CREATE",t))return Forbid();
        var candidates=new List<(long UserId,bool CreateCustomer,byte[] Version,string Payload)>();
        using(var candidateQuery=new SqlCommand($"""
SELECT DISTINCT candidate.UserID,CASE WHEN JSON_VALUE(q.Payload,'$.createCustomer')='true' THEN 1 ELSE 0 END,q.RowVersion,q.Payload
FROM dbo.TDSTBusinessCardDraft q JOIN dbo.TDADUser candidate ON candidate.CompanyID=q.CompanyID AND candidate.IsActive=1
WHERE q.CompanyID=@company AND q.DraftID=@id AND q.SubmittedBy=@actor AND q.Status='DRAFT'
AND {ReviewerPredicate.Replace("@actor", "candidate.UserID")}
""",c)) {
            P(candidateQuery,"@company",SqlDbType.BigInt,Company);P(candidateQuery,"@id",SqlDbType.BigInt,id);P(candidateQuery,"@actor",SqlDbType.BigInt,Actor);
            using var reader=await candidateQuery.ExecuteReaderAsync(t);while(await reader.ReadAsync(t))candidates.Add((reader.GetInt64(0),reader.GetInt32(1)==1,(byte[])reader[2],reader.GetString(3)));
        }
        long? eligible=null;byte[]? version=null;
        foreach(var candidate in candidates){
            var principal=new ClaimsPrincipal(new ClaimsIdentity(User.Claims.Where(claim=>claim.Type!="user_id").Append(new Claim("user_id",candidate.UserId.ToString())),"reviewer-check"));
            if(!await CompanyMenuAccess.IsAllowedAsync(c,principal,"55002","VIEW",t)||!await CompanyMenuAccess.IsAllowedAsync(c,principal,"55002","EDIT",t)||!await CompanyMenuAccess.IsAllowedAsync(c,principal,"55002","CREATE",t))continue;
            if(candidate.CreateCustomer ? !await CanCreateCustomer(c,t,principal) : !await CompanyMenuAccess.IsAllowedAsync(c,principal,"09001","VIEW",t))continue;
            ContactSave? draft;try{draft=JsonSerializer.Deserialize<ContactSave>(candidate.Payload,new JsonSerializerOptions{PropertyNameCaseInsensitive=true});}catch(JsonException){continue;}
            if(draft is null || string.IsNullOrWhiteSpace(draft.Name))continue;
            if(draft.PersonId.HasValue){
                if(!await CompanyMenuAccess.IsAllowedAsync(c,principal,"13002","VIEW",t))continue;
                using var personQuery=new SqlCommand("""
SELECT p.FullName,p.Mobile,p.Email,p.RowVersion,
 CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADEmployee e WHERE e.PersonID=p.PersonID AND e.CompanyID=p.CompanyID)
   OR EXISTS(SELECT 1 FROM dbo.TDADUser u WHERE u.PersonID=p.PersonID AND u.CompanyID=p.CompanyID)
   OR EXISTS(SELECT 1 FROM dbo.TDADResident r WHERE r.PersonID=p.PersonID AND r.CompanyID=p.CompanyID)
   OR EXISTS(SELECT 1 FROM dbo.TDADServiceCustomer s WHERE s.PersonID=p.PersonID AND s.CompanyID=p.CompanyID) THEN 1 ELSE 0 END,
 CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADContact c2 WHERE c2.PersonID=p.PersonID AND c2.CompanyID=p.CompanyID) THEN 1 ELSE 0 END
FROM dbo.TDADPerson p WHERE p.CompanyID=@company AND p.PersonID=@person
""",c);
                P(personQuery,"@company",SqlDbType.BigInt,Company);P(personQuery,"@person",SqlDbType.BigInt,draft.PersonId);
                bool found,changed=false,shared=false,alreadyContact=false,versionMatches=false;
                using(var person=await personQuery.ExecuteReaderAsync(t)){
                    found=await person.ReadAsync(t);
                    if(found){changed=S(person,0)!=draft.Name.Trim()||S(person,1)!=(draft.Phone??"").Trim()||S(person,2)!=(draft.Email??"").Trim();versionMatches=draft.PersonRowVersion==Convert.ToBase64String((byte[])person[3]);shared=person.GetInt32(4)==1;alreadyContact=person.GetInt32(5)==1;}
                }
                if(!found || alreadyContact || (changed && (!versionMatches || shared || !await CompanyMenuAccess.IsAllowedAsync(c,principal,"13002","EDIT",t))))continue;
            }
            eligible=candidate.UserId;version=candidate.Version;break;
        }
        if(!eligible.HasValue)return Conflict(Issue("ส่งตรวจไม่ได้","ไม่พบผู้ตรวจสอบที่กำหนดไว้และมีสิทธิ์ตรวจสอบ กรุณาตรวจการตั้งค่าและสิทธิ์เมนู"));
        using var q=new SqlCommand($"""
UPDATE q SET Status='PENDING',SentAt=SYSUTCDATETIME()
FROM dbo.TDSTBusinessCardDraft q
WHERE q.CompanyID=@company AND q.DraftID=@id AND q.SubmittedBy=@actor AND q.Status='DRAFT' AND q.RowVersion=@version
AND EXISTS (SELECT 1 FROM dbo.TDADUser candidate
 WHERE candidate.UserID=@reviewer AND candidate.CompanyID=q.CompanyID AND candidate.IsActive=1 AND {ReviewerPredicate.Replace("@actor", "candidate.UserID")});
""",c);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@reviewer",SqlDbType.BigInt,eligible.Value);P(q,"@version",SqlDbType.Timestamp,version);
        return await q.ExecuteNonQueryAsync(t)==1?NoContent():Conflict(Issue("ส่งตรวจไม่ได้","ตรวจสอบว่ามีผู้ตรวจสอบที่เปิดใช้งานและกำหนดไว้แล้ว หรือแบบร่างอาจถูกเปลี่ยนสถานะ"));
    }

    [HttpGet("ocr-drafts/{id:long}")]
    public async Task<IActionResult> DraftDetails(long id,CancellationToken t)
    {
        using var c=await Open(t);if(!await Allowed(c,"VIEW",t))return Forbid();
        using var q=new SqlCommand($"SELECT q.Payload,q.RowVersion FROM dbo.TDSTBusinessCardDraft q WHERE q.CompanyID=@company AND q.DraftID=@id AND (q.SubmittedBy=@actor OR (q.Status='PENDING' AND {ReviewerPredicate})) AND q.Status IN ('DRAFT','PENDING')",c);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@actor",SqlDbType.BigInt,Actor);
        string payload,version;using(var draft=await q.ExecuteReaderAsync(t)){if(!await draft.ReadAsync(t))return NotFound();payload=draft.GetString(0);version=Convert.ToBase64String((byte[])draft[1]);}
        using var iq=new SqlCommand("SELECT OriginalName,ImageData FROM dbo.TDSTBusinessCardDraftImage WHERE CompanyID=@company AND DraftID=@id ORDER BY DraftImageID",c);
        P(iq,"@company",SqlDbType.BigInt,Company);P(iq,"@id",SqlDbType.BigInt,id);
        using var reader=await iq.ExecuteReaderAsync(t);var images=new List<object>();while(await reader.ReadAsync(t))images.Add(new{name=S(reader,0),data=Convert.ToBase64String((byte[])reader[1])});
        return Ok(new{contact=JsonSerializer.Deserialize<JsonElement>(payload),images,rowVersion=version});
    }

    [HttpDelete("ocr-drafts/{id:long}")]
    public async Task<IActionResult> DeleteDraft(long id,CancellationToken t)
    {
        using var c=await Open(t);if(!await Allowed(c,"DELETE",t))return Forbid();
        using var q=new SqlCommand("UPDATE dbo.TDSTBusinessCardDraft SET Status='DELETED' WHERE CompanyID=@company AND DraftID=@id AND SubmittedBy=@actor AND Status='DRAFT'",c);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@actor",SqlDbType.BigInt,Actor);
        return await q.ExecuteNonQueryAsync(t)==1?NoContent():Conflict(Issue("ลบแบบร่างไม่ได้","แบบร่างถูกส่งตรวจแล้วหรือไม่มีสิทธิ์"));
    }
    [HttpPost]
    public Task<IActionResult> Create(ContactSave request,CancellationToken t)=>Save(null,request,t);
    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id,ContactSave request,CancellationToken t)=>Save(id,request,t);
    private async Task<IActionResult> Save(long? id,ContactSave x,CancellationToken t,long? draftId=null)
    {
        using var c=await Open(t);if(!await Allowed(c,id.HasValue?"EDIT":"CREATE",t))return Forbid();
        if(string.IsNullOrWhiteSpace(x.Name)||x.Name.Length>200||(x.Phone?.Length??0)>50||(x.Email?.Length??0)>320||(x.Company?.Length??0)>250||(x.Position?.Length??0)>200||(x.Address?.Length??0)>1000||(x.Website?.Length??0)>500||(x.Line?.Length??0)>100)
            return BadRequest(Issue("ข้อมูลผู้ติดต่อไม่ถูกต้อง","ระบุชื่อ และตรวจความยาวข้อมูลแต่ละช่อง"));
        if(!string.IsNullOrWhiteSpace(x.Website) && (!Uri.TryCreate(x.Website,UriKind.Absolute,out var uri)||uri.Scheme is not ("http" or "https")))
            return BadRequest(Issue("เว็บไซต์ไม่ถูกต้อง","ระบุลิงก์ที่ขึ้นต้นด้วย https:// หรือ http://"));
        if(x.FromOcr && (id.HasValue || (!x.CreateCustomer && !x.CustomerId.HasValue)))
            return BadRequest(Issue("ข้อมูลนำเข้านามบัตรไม่ถูกต้อง","กรุณาเลือกหรือสร้างลูกค้าสำหรับรายการตรวจสอบ"));
        if(x.CreateCustomer && (id.HasValue || x.CustomerId.HasValue || string.IsNullOrWhiteSpace(x.Company) || x.Company.Trim().Length>200 || (x.Website?.Length??0)>320))
            return BadRequest(Issue("ข้อมูลลูกค้าไม่ถูกต้อง","กรุณาระบุชื่อบริษัทไม่เกิน 200 ตัวอักษร และเลือกสร้างลูกค้าใหม่"));
        if(x.CreateCustomer && !await CanCreateCustomer(c,t))
            return StatusCode(403,Issue("ไม่มีสิทธิ์สร้างลูกค้า","ตรวจสิทธิ์ข้อมูลลูกค้าและแพ็กเกจระบบขายก่อนสร้างลูกค้าใหม่"));
        var personEdit=await CompanyMenuAccess.IsAllowedAsync(c,User,"13002","EDIT",t);
        if(x.CustomerId.HasValue && !await CompanyMenuAccess.IsAllowedAsync(c,User,"09001","VIEW",t))return Forbid();
        if(!id.HasValue && x.PersonId.HasValue && !await CompanyMenuAccess.IsAllowedAsync(c,User,"13002","VIEW",t))return Forbid();
        using var tx=c.BeginTransaction(IsolationLevel.Serializable);
        if(draftId.HasValue){
            using var locked=new SqlCommand($"SELECT COUNT(1) FROM dbo.TDSTBusinessCardDraft q WITH(UPDLOCK,HOLDLOCK) WHERE q.CompanyID=@company AND q.DraftID=@id AND q.Status='PENDING' AND {ReviewerPredicate}",c,tx);
            P(locked,"@company",SqlDbType.BigInt,Company);P(locked,"@actor",SqlDbType.BigInt,Actor);P(locked,"@id",SqlDbType.BigInt,draftId);
            if(Convert.ToInt32(await locked.ExecuteScalarAsync(t))!=1)return Conflict(Issue("ตรวจสอบไม่ได้","รายการถูกเปลี่ยนสถานะหรือไม่มีสิทธิ์"));
        } else if(x.FromOcr) return BadRequest(Issue("กรุณาส่งนามบัตรตรวจสอบก่อน","ข้อมูลจาก OCR ต้องผ่านขั้นตอนตรวจสอบ"));
        if(x.CreateCustomer){
            using var q=new SqlCommand("""
DECLARE @lockResult int, @lockResource nvarchar(255)=CONCAT(N'LAOO_OCR_CUSTOMER_CODE:',@company);
EXEC @lockResult=sys.sp_getapplock @Resource=@lockResource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
IF @lockResult<0 THROW 51040,N'ไม่สามารถออกรหัสลูกค้า กรุณาลองใหม่',1;
DECLARE @sequence bigint;
SELECT @sequence=ISNULL(MAX(TRY_CONVERT(bigint,SUBSTRING(CusCode,4,7))),0)+1
FROM dbo.TDARCustomer WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@company AND LEN(CusCode)=10 AND CusCode LIKE N'OCR[0-9][0-9][0-9][0-9][0-9][0-9][0-9]';
IF @sequence>9999999 THROW 51041,N'รหัสลูกค้าถึงจำนวนสูงสุดแล้ว',1;
DECLARE @code nvarchar(10)=N'OCR'+RIGHT(N'0000000'+CONVERT(nvarchar(7),@sequence),7);
IF EXISTS(SELECT 1 FROM dbo.TDARCustomer WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND CusCode=@code)
 THROW 51042,N'รหัสลูกค้าซ้ำ กรุณาลองใหม่',1;
INSERT dbo.TDARCustomer(CompanyID,CusCode,CusName,CusAddress,Website,IsActive,DataSource)
OUTPUT INSERTED.CustomerID VALUES(@company,@code,@name,@address,@website,1,@source);
""",c,tx);
            P(q,"@company",SqlDbType.BigInt,Company);P(q,"@name",SqlDbType.NVarChar,x.Company!.Trim(),200);P(q,"@address",SqlDbType.NVarChar,x.Address?.Trim(),1000);P(q,"@website",SqlDbType.NVarChar,x.Website?.Trim(),320);
            P(q,"@source",SqlDbType.TinyInt,x.FromOcr?1:0);
            x=x with { CustomerId=Convert.ToInt64(await q.ExecuteScalarAsync(t)) };
        }
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
        if(draftId.HasValue){
            using var q=new SqlCommand("UPDATE dbo.TDSTBusinessCardDraft SET Status='APPROVED',ReviewedAt=SYSUTCDATETIME(),ReviewedBy=@actor,ContactID=@contact,CustomerID=@customer WHERE CompanyID=@company AND DraftID=@draft AND Status='PENDING'",c,tx);
            P(q,"@company",SqlDbType.BigInt,Company);P(q,"@contact",SqlDbType.BigInt,id);P(q,"@customer",SqlDbType.BigInt,x.CustomerId);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@draft",SqlDbType.BigInt,draftId);await q.ExecuteNonQueryAsync(t);
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
        using var q=new SqlCommand("UPDATE dbo.TDADContact SET IsDeleted=1,IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND ContactID=@id AND RowVersion=@version AND IsDeleted=0 AND NOT EXISTS (SELECT 1 FROM dbo.TDSTBusinessCardDraft d WHERE d.CompanyID=@company AND d.ContactID=@id AND d.Status='APPROVED')",c);
        P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@actor",SqlDbType.BigInt,Actor);P(q,"@version",SqlDbType.Timestamp,version);
        return await q.ExecuteNonQueryAsync(t)==1?NoContent():Conflict(Issue("ลบข้อมูลไม่ได้","รายการถูกเปลี่ยนหรือถูกลบแล้ว กรุณาโหลดข้อมูลใหม่"));
    }
    private string FilePath(string name)=>Path.Combine(environment.ContentRootPath,"App_Data","contact-cards",Company.ToString(),name);
    private async Task<bool> Owns(SqlConnection c,long id,CancellationToken t){using var q=new SqlCommand("SELECT COUNT(1) FROM dbo.TDADContact WHERE CompanyID=@company AND ContactID=@id AND IsDeleted=0",c);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);return Convert.ToInt32(await q.ExecuteScalarAsync(t))==1;}
    [HttpGet("{id:long}/files")]
    public async Task<IActionResult> Files(long id,CancellationToken t){
        using var c=await Open(t);if(!await Allowed(c,"VIEW",t)||!await Owns(c,id,t))return Forbid();
        using var q=new SqlCommand("SELECT ContactFileID,OriginalName,FileSize FROM dbo.TDADContactFile WHERE CompanyID=@company AND ContactID=@id UNION ALL SELECT -i.DraftImageID,i.OriginalName,CONVERT(bigint,DATALENGTH(i.ImageData)) FROM dbo.TDSTBusinessCardDraftImage i JOIN dbo.TDSTBusinessCardDraft d ON d.DraftID=i.DraftID AND d.CompanyID=i.CompanyID WHERE d.CompanyID=@company AND d.ContactID=@id AND d.Status='APPROVED' ORDER BY 1",c);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);
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
        if(fileId<0){using var image=new SqlCommand("SELECT i.ImageData FROM dbo.TDSTBusinessCardDraftImage i JOIN dbo.TDSTBusinessCardDraft d ON d.DraftID=i.DraftID AND d.CompanyID=i.CompanyID WHERE d.CompanyID=@company AND d.ContactID=@id AND d.Status='APPROVED' AND i.DraftImageID=@file",c);P(image,"@company",SqlDbType.BigInt,Company);P(image,"@id",SqlDbType.BigInt,id);P(image,"@file",SqlDbType.BigInt,-fileId);var bytes=await image.ExecuteScalarAsync(t) as byte[];return bytes is null?NotFound():File(bytes,"image/png");}
        using var q=new SqlCommand("SELECT StoredName FROM dbo.TDADContactFile WHERE CompanyID=@company AND ContactID=@id AND ContactFileID=@file",c);P(q,"@company",SqlDbType.BigInt,Company);P(q,"@id",SqlDbType.BigInt,id);P(q,"@file",SqlDbType.BigInt,fileId);
        var name=await q.ExecuteScalarAsync(t) as string;if(name is null||Path.GetFileName(name)!=name)return NotFound();
        var path=FilePath(name);return System.IO.File.Exists(path)?PhysicalFile(path,"image/png"):NotFound();
    }
}
public sealed record ContactSave(string Name,string? Phone,string? Email,string? Company,string? Position,string? Address,string? Website,string? Line,bool IsActive=true,long? PersonId=null,long? CustomerId=null,string? RowVersion=null,string? PersonRowVersion=null,bool CreateCustomer=false,bool FromOcr=false);
public sealed record BusinessCardDraftImage(string Name,string Data);
public sealed record BusinessCardDraftRequest(ContactSave? Contact,List<BusinessCardDraftImage>? Images);
