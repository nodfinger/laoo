using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooKnowledgeModule.Controllers;

[ApiController, Authorize, Route("api/company/knowledge")]
public sealed class KnowledgeController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    static readonly string[] Menus = ["49001","49002","49003","49004","49005","49006","49007","49008"];

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu,CancellationToken token)
    {
        if(!Menus.Contains(menu)||!Scope(out _,out _))return Forbid();
        await using var db=await Open(token);if(!await Can(db,menu,"VIEW",token))return Forbid();
        var names=new[]{"CREATE","EDIT","DELETE","SUBMIT","ARCHIVE","UPLOAD","REVIEW","RETURN","PUBLISH","PREVIEW","DOWNLOAD","FEEDBACK","COMMENT","FOLLOW","ANSWER","ACCEPT","CONVERT","EXPORT"};
        var result=new Dictionary<string,bool>();foreach(var name in names)result[name.ToLowerInvariant()]=await Can(db,menu,name,token);return Ok(result);
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();
        await using var db=await Open(token);if(!await Can(db,"49001","VIEW",token))return Forbid();
        await EnsureSettings(db,company,user,token);
        return Ok((await Query(db,"SELECT MaxVideoMB maxVideoMb,MaxAttachmentMB maxAttachmentMb,DefaultReviewMonths defaultReviewMonths,AllowedVideoExtensions allowedVideoExtensions,AllowedAttachmentExtensions allowedAttachmentExtensions FROM dbo.TDKNSystemSetting WHERE CompanyID=@company",token,("@company",company))).Single());
    }

    [HttpPut("settings")]
    public async Task<IActionResult> Settings(SettingsRequest request,CancellationToken token)
    {
        if(request.MaxVideoMb is <1 or >2048||request.MaxAttachmentMb is <1 or >200||request.DefaultReviewMonths is <1 or >60)return Bad("ข้อมูลตั้งค่าไม่ถูกต้อง","คลิปต้องไม่เกิน 2,048 MB ไฟล์แนบไม่เกิน 200 MB และรอบทบทวน 1-60 เดือน");
        if(!Scope(out var company,out var user))return Forbid();
        await using var db=await Open(token);if(!await Can(db,"49001","EDIT",token))return Forbid();
        await EnsureSettings(db,company,user,token);
        await Execute(db,"UPDATE dbo.TDKNSystemSetting SET MaxVideoMB=@video,MaxAttachmentMB=@file,DefaultReviewMonths=@review,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company",token,("@video",request.MaxVideoMb),("@file",request.MaxAttachmentMb),("@review",request.DefaultReviewMonths),("@user",user),("@company",company));
        return NoContent();
    }

    [HttpGet("taxonomy")]
    public async Task<IActionResult> Taxonomy(CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"49002","VIEW",token))return Forbid();
        return Ok(await Query(db,"SELECT c.CategoryID id,c.CategoryCode code,c.CategoryName name,c.OwnerUserID ownerUserId,COALESCE(e.FullName,u.Username) ownerName,c.SortOrder sortOrder,c.IsActive active FROM dbo.TDKNCategory c LEFT JOIN dbo.TDADUser u ON u.CompanyID=c.CompanyID AND u.UserID=c.OwnerUserID LEFT JOIN dbo.TDADUserEmployee ue ON ue.CompanyID=u.CompanyID AND ue.UserID=u.UserID AND ue.IsActive=1 LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE c.CompanyID=@company ORDER BY c.SortOrder,c.CategoryName",token,("@company",company)));
    }

    [HttpPost("taxonomy")]
    public Task<IActionResult> Taxonomy(CategoryRequest request,CancellationToken token)=>SaveCategory(null,request,"CREATE",token);
    [HttpPut("taxonomy/{id:long}")]
    public Task<IActionResult> Taxonomy(long id,CategoryRequest request,CancellationToken token)=>SaveCategory(id,request,"EDIT",token);
    async Task<IActionResult> SaveCategory(long? id,CategoryRequest request,string action,CancellationToken token)
    {
        var code=Clean(request.Code)?.ToUpperInvariant();var name=Clean(request.Name);if(code is null||name is null)return Bad("ข้อมูลหมวดความรู้ไม่ครบ","ระบุรหัสและชื่อหมวดความรู้");
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49002",action,token))return Forbid();
        try{var sql=id is null?"INSERT dbo.TDKNCategory(CompanyID,CategoryCode,CategoryName,OwnerUserID,SortOrder,IsActive,CreateBy) OUTPUT INSERTED.CategoryID VALUES(@company,@code,@name,@owner,@sort,@active,@user)":"UPDATE dbo.TDKNCategory SET CategoryCode=@code,CategoryName=@name,OwnerUserID=@owner,SortOrder=@sort,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.CategoryID WHERE CompanyID=@company AND CategoryID=@id";var saved=await Scalar<long>(db,sql,token,("@company",company),("@id",id),("@code",code),("@name",name),("@owner",request.OwnerUserId),("@sort",request.SortOrder),("@active",request.Active),("@user",user));return saved>0?Ok(new{id=saved}):NotFound();}
        catch(SqlException e) when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสหมวดซ้ำ",description="ใช้รหัสอื่นภายในบริษัทเดียวกัน"});}
    }

    [HttpDelete("taxonomy/{id:long}")]
    public async Task<IActionResult> DeleteCategory(long id,CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"49002","DELETE",token))return Forbid();
        var used=await Scalar<int>(db,"SELECT (SELECT COUNT(*) FROM dbo.TDKNArticle WHERE CompanyID=@company AND CategoryID=@id)+(SELECT COUNT(*) FROM dbo.TDKNQuestion WHERE CompanyID=@company AND CategoryID=@id)",token,("@company",company),("@id",id));
        if(used>0)return Conflict(new{message="ลบหมวดไม่ได้",description="หมวดนี้ถูกใช้งานแล้ว ให้ปิดใช้งานแทน"});
        return await Execute(db,"DELETE dbo.TDKNCategory WHERE CompanyID=@company AND CategoryID=@id",token,("@company",company),("@id",id))==1?NoContent():NotFound();
    }

    [HttpGet("options")]
    public async Task<IActionResult> Options(CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await AnyView(db,token))return Forbid();
        var categories=await Query(db,"SELECT CategoryID id,CategoryCode code,CategoryName name FROM dbo.TDKNCategory WHERE CompanyID=@company AND IsActive=1 ORDER BY SortOrder,CategoryName",token,("@company",company));
        var users=await Query(db,"SELECT u.UserID id,u.Username code,COALESCE(e.FullName,u.Username) name FROM dbo.TDADUser u LEFT JOIN dbo.TDADUserEmployee ue ON ue.CompanyID=u.CompanyID AND ue.UserID=u.UserID AND ue.IsActive=1 LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE u.CompanyID=@company AND u.IsActive=1 ORDER BY COALESCE(e.FullName,u.Username)",token,("@company",company));
        var departments=await Query(db,"SELECT OrgUnitID id,UnitCode code,NameTH name FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND UnitType IN(N'DEPARTMENT',N'DEP') AND IsActive=1 ORDER BY NameTH",token,("@company",company));
        return Ok(new{categories,users,departments});
    }

    [HttpGet("articles")]
    public async Task<IActionResult> Articles(string? search=null,string? status=null,int page=1,int pageSize=20,CancellationToken token=default)
    {
        if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"49003","VIEW",token))return Forbid();await MarkReviewDue(db,company,token);page=Math.Max(1,page);pageSize=Math.Clamp(pageSize,1,100);
        const string tail=" FROM dbo.TDKNArticle a JOIN dbo.TDKNCategory c ON c.CompanyID=a.CompanyID AND c.CategoryID=a.CategoryID LEFT JOIN dbo.TDKNArticleRevision r ON r.RevisionID=a.CurrentRevisionID WHERE a.CompanyID=@company AND a.IsActive=1 AND (@search IS NULL OR a.ArticleCode LIKE N'%'+@search+N'%' OR a.Title LIKE N'%'+@search+N'%' OR a.SummaryText LIKE N'%'+@search+N'%') AND (@status IS NULL OR a.StatusCode=@status)";
        var args=new(string,object?)[]{("@company",company),("@search",Clean(search)),("@status",Clean(status)?.ToUpperInvariant())};
        var total=await Scalar<int>(db,"SELECT COUNT(*)"+tail,token,args);var items=await Query(db,"SELECT a.ArticleID id,a.ArticleCode code,a.Title title,a.SummaryText summary,a.ContentType contentType,a.SourceUrl sourceUrl,c.CategoryName categoryName,a.StatusCode status,a.PublishedRevisionID publishedRevisionId,r.RevisionNo revisionNo,a.PublishedAt,a.NextReviewDate"+tail+" ORDER BY a.CreateDate DESC OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY",token,[..args,("@skip",(page-1)*pageSize),("@take",pageSize)]);
        return Ok(new{items,total,page,pageSize});
    }

    [HttpGet("articles/{id:long}")]
    public async Task<IActionResult> Article(long id,CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"49003","VIEW",token)&&!await Can(db,"49005","VIEW",token))return Forbid();
        var rows=await Query(db,"SELECT a.ArticleID id,a.ArticleCode code,a.CategoryID categoryId,a.Title title,a.SummaryText summary,a.ContentType contentType,a.SourceSystem sourceSystem,a.SourceID sourceId,a.SourceUrl sourceUrl,a.StatusCode status,a.AudienceMode audienceMode,a.OwnerUserID ownerUserId,r.RevisionID revisionId,r.RevisionNo revisionNo,r.BodyText bodyText,r.ReviewerUserID reviewerUserId,a.PublishedAt,a.NextReviewDate FROM dbo.TDKNArticle a LEFT JOIN dbo.TDKNArticleRevision r ON r.RevisionID=a.CurrentRevisionID WHERE a.CompanyID=@company AND a.ArticleID=@id",token,("@company",company),("@id",id));if(rows.Count==0)return NotFound();var audience=await Query(db,"SELECT SubjectType subjectType,SubjectID subjectId FROM dbo.TDKNArticleAudience WHERE CompanyID=@company AND ArticleID=@id",token,("@company",company),("@id",id));rows[0]["departmentIds"]=audience.Where(x=>Convert.ToString(x["subjectType"])=="DEPARTMENT").Select(x=>Convert.ToInt64(x["subjectId"])).ToList();rows[0]["userIds"]=audience.Where(x=>Convert.ToString(x["subjectType"])=="USER").Select(x=>Convert.ToInt64(x["subjectId"])).ToList();return Ok(rows[0]);
    }

    [HttpPost("articles")]
    public Task<IActionResult> Article(ArticleRequest request,CancellationToken token)=>SaveArticle(null,request,token);
    [HttpPut("articles/{id:long}")]
    public Task<IActionResult> Article(long id,ArticleRequest request,CancellationToken token)=>SaveArticle(id,request,token);
    async Task<IActionResult> SaveArticle(long? id,ArticleRequest request,CancellationToken token)
    {
        var title=Clean(request.Title);var type=Clean(request.ContentType)?.ToUpperInvariant();var allowed=new[]{"ARTICLE","VIDEO_FILE","VIDEO_URL","DOCUMENT_CONTROL","TRAINING","INTRANET","EXTERNAL_URL"};
        if(title is null||request.CategoryId<=0||type is null||!allowed.Contains(type)||request.AudienceMode is not ("ALL" or "RESTRICTED")||(request.AudienceMode=="RESTRICTED"&&!(request.DepartmentIds?.Any(x=>x>0)==true||request.UserIds?.Any(x=>x>0)==true)))return Bad("ข้อมูลความรู้ไม่ครบ","ระบุชื่อ หมวด ประเภทเนื้อหา และสิทธิ์การเข้าถึง โดยโหมดจำกัดสิทธิ์ต้องเลือกแผนกหรือบุคคลอย่างน้อยหนึ่งรายการ");
        if(type is "VIDEO_URL" or "EXTERNAL_URL" && !Uri.TryCreate(request.SourceUrl,UriKind.Absolute,out _))return Bad("URL ไม่ถูกต้อง","ระบุ URL แบบเต็ม เช่น https://example.com");
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);var action=id is null?"CREATE":"EDIT";if(!await Can(db,"49003",action,token))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);try{
            if(await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDKNCategory WHERE CompanyID=@company AND CategoryID=@category AND IsActive=1",token,("@company",company),("@category",request.CategoryId))==0){await tx.RollbackAsync(token);return Bad("ไม่พบหมวดความรู้","เลือกหมวดความรู้ที่ยังใช้งานอยู่");}
            long articleId;long revisionId;
            if(id is null){var code=Clean(request.Code)?.ToUpperInvariant()??$"KN-{DateTime.UtcNow:yyyyMMddHHmmss}-{user}";articleId=await Scalar<long>(db,tx,"INSERT dbo.TDKNArticle(CompanyID,ArticleCode,CategoryID,Title,SummaryText,ContentType,SourceSystem,SourceType,SourceID,SourceRevision,SourceUrl,OwnerUserID,StatusCode,AudienceMode,NextReviewDate,CreateBy) OUTPUT INSERTED.ArticleID VALUES(@company,@code,@category,@title,@summary,@type,@sourceSystem,@sourceType,@sourceId,@sourceRevision,@sourceUrl,@user,N'DRAFT',@audience,@reviewDate,@user)",token,("@company",company),("@code",code),("@category",request.CategoryId),("@title",title),("@summary",Clean(request.Summary)),("@type",type),("@sourceSystem",Clean(request.SourceSystem)),("@sourceType",Clean(request.SourceType)),("@sourceId",Clean(request.SourceId)),("@sourceRevision",Clean(request.SourceRevision)),("@sourceUrl",Clean(request.SourceUrl)),("@user",user),("@audience",request.AudienceMode),("@reviewDate",request.NextReviewDate));revisionId=await Scalar<long>(db,tx,"INSERT dbo.TDKNArticleRevision(CompanyID,ArticleID,RevisionNo,BodyText,StatusCode,ReviewerUserID,CreateBy) OUTPUT INSERTED.RevisionID VALUES(@company,@article,1,@body,N'DRAFT',@reviewer,@user)",token,("@company",company),("@article",articleId),("@body",Clean(request.Body)),("@reviewer",request.ReviewerUserId),("@user",user));await Execute(db,tx,"UPDATE dbo.TDKNArticle SET CurrentRevisionID=@revision WHERE CompanyID=@company AND ArticleID=@article",token,("@revision",revisionId),("@company",company),("@article",articleId));}
            else{articleId=id.Value;var current=await Query(db,tx,"SELECT CurrentRevisionID revisionId,StatusCode status,OwnerUserID owner FROM dbo.TDKNArticle WHERE CompanyID=@company AND ArticleID=@article AND IsActive=1",token,("@company",company),("@article",articleId));if(current.Count==0){await tx.RollbackAsync(token);return NotFound();}var state=Convert.ToString(current[0]["status"]);if(state is not ("DRAFT" or "RETURNED")){await tx.RollbackAsync(token);return Conflict(new{message="แก้ไขรายการนี้ไม่ได้",description="แก้ไขได้เฉพาะสถานะร่างหรือส่งกลับ หากเผยแพร่แล้วต้องสร้าง Revision ใหม่"});}revisionId=Convert.ToInt64(current[0]["revisionId"]);await Execute(db,tx,"UPDATE dbo.TDKNArticle SET CategoryID=@category,Title=@title,SummaryText=@summary,ContentType=@type,SourceSystem=@sourceSystem,SourceType=@sourceType,SourceID=@sourceId,SourceRevision=@sourceRevision,SourceUrl=@sourceUrl,AudienceMode=@audience,NextReviewDate=@reviewDate,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ArticleID=@article;UPDATE dbo.TDKNArticleRevision SET BodyText=@body,ReviewerUserID=@reviewer,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND RevisionID=@revision",token,("@category",request.CategoryId),("@title",title),("@summary",Clean(request.Summary)),("@type",type),("@sourceSystem",Clean(request.SourceSystem)),("@sourceType",Clean(request.SourceType)),("@sourceId",Clean(request.SourceId)),("@sourceRevision",Clean(request.SourceRevision)),("@sourceUrl",Clean(request.SourceUrl)),("@audience",request.AudienceMode),("@reviewDate",request.NextReviewDate),("@body",Clean(request.Body)),("@reviewer",request.ReviewerUserId),("@user",user),("@company",company),("@article",articleId),("@revision",revisionId));}
            await ReplaceAudience(db,tx,company,articleId,request.DepartmentIds,request.UserIds,user,token);await Audit(db,tx,company,"ARTICLE",articleId,id is null?"CREATE":"EDIT",null,user,token);await tx.CommitAsync(token);return Ok(new{id=articleId,revisionId});
        }catch(SqlException e) when(e.Number is 2601 or 2627){await tx.RollbackAsync(token);return Conflict(new{message="รหัสความรู้ซ้ำ",description="ระบบพบรหัสนี้ในบริษัทแล้ว กรุณาใช้รหัสอื่น"});}
    }
    // Draft deletion is a permanent operation.
    [HttpDelete("articles/{id:long}")]
    public async Task<IActionResult> DeleteArticle(long id,CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"49003","DELETE",token))return Forbid();
        var article=await Query(db,"SELECT StatusCode status,PublishedRevisionID publishedRevisionId FROM dbo.TDKNArticle WHERE CompanyID=@company AND ArticleID=@id",token,("@company",company),("@id",id));if(article.Count==0)return NotFound();if(Convert.ToString(article[0]["status"])!="DRAFT"||article[0]["publishedRevisionId"] is not null)return Conflict(new{message="ลบความรู้นี้ไม่ได้",description="ลบได้เฉพาะร่างใหม่ที่ไม่เคยเผยแพร่ ส่วน Revision ต้องส่งกลับหรือเผยแพร่ตาม Workflow"});
        var files=await Query(db,"SELECT RelativePath relativePath,StoredFileName storedFileName FROM dbo.TDKNFile WHERE CompanyID=@company AND ArticleID=@id",token,("@company",company),("@id",id));
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        await Execute(db,tx,"DELETE dbo.TDKNFeedback WHERE CompanyID=@company AND ArticleID=@id;DELETE dbo.TDKNFile WHERE CompanyID=@company AND ArticleID=@id;DELETE dbo.TDKNArticleTag WHERE CompanyID=@company AND ArticleID=@id;DELETE dbo.TDKNArticleAudience WHERE CompanyID=@company AND ArticleID=@id;DELETE dbo.TDKNFollow WHERE CompanyID=@company AND ArticleID=@id;DELETE dbo.TDKNArticleRevision WHERE CompanyID=@company AND ArticleID=@id;DELETE dbo.TDKNArticle WHERE CompanyID=@company AND ArticleID=@id",token,("@company",company),("@id",id));
        await tx.CommitAsync(token);
        var webRoot=environment.WebRootPath??Path.Combine(environment.ContentRootPath,"wwwroot");var uploadRoot=Path.GetFullPath(Path.Combine(webRoot,"uploads","knowledge"));
        foreach(var file in files){var full=Path.GetFullPath(Path.Combine(webRoot,Convert.ToString(file["relativePath"])??string.Empty,Convert.ToString(file["storedFileName"])??string.Empty));if(full.StartsWith(uploadRoot,StringComparison.OrdinalIgnoreCase)&&System.IO.File.Exists(full))System.IO.File.Delete(full);}
        return NoContent();
    }

    [HttpPost("articles/{id:long}/submit")]
    public async Task<IActionResult> Submit(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49003","SUBMIT",token))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        var changed=await Execute(db,tx,"UPDATE r SET StatusCode=N'IN_REVIEW',SubmittedAt=SYSUTCDATETIME(),UpdateBy=@user,UpdateDate=SYSUTCDATETIME() FROM dbo.TDKNArticleRevision r JOIN dbo.TDKNArticle a ON a.ArticleID=r.ArticleID AND a.CurrentRevisionID=r.RevisionID WHERE a.CompanyID=@company AND a.ArticleID=@id AND a.StatusCode IN(N'DRAFT',N'RETURNED');UPDATE dbo.TDKNArticle SET StatusCode=N'IN_REVIEW',UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ArticleID=@id AND StatusCode IN(N'DRAFT',N'RETURNED')",token,("@company",company),("@id",id),("@user",user));
        if(changed==0){await tx.RollbackAsync(token);return Conflict(new{message="ส่งตรวจทานไม่ได้",description="รายการต้องอยู่ในสถานะร่างหรือส่งกลับ"});}await Audit(db,tx,company,"ARTICLE",id,"SUBMIT",null,user,token);await tx.CommitAsync(token);return NoContent();
    }

    [HttpPost("articles/{id:long}/revisions")]
    public async Task<IActionResult> CreateRevision(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49003","EDIT",token))return Forbid();await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        var source=await Query(db,tx,"SELECT a.PublishedRevisionID publishedRevisionId,r.BodyText body,r.ReviewerUserID reviewer FROM dbo.TDKNArticle a JOIN dbo.TDKNArticleRevision r ON r.RevisionID=a.PublishedRevisionID WHERE a.CompanyID=@company AND a.ArticleID=@id AND a.IsActive=1 AND a.StatusCode IN(N'PUBLISHED',N'REVIEW_DUE')",token,("@company",company),("@id",id));if(source.Count==0){await tx.RollbackAsync(token);return Conflict(new{message="สร้าง Revision ไม่ได้",description="รายการต้องมีฉบับเผยแพร่และยังไม่มี Revision ที่กำลังแก้ไข"});}
        var revision=await Scalar<long>(db,tx,"INSERT dbo.TDKNArticleRevision(CompanyID,ArticleID,RevisionNo,BodyText,StatusCode,ReviewerUserID,CreateBy) OUTPUT INSERTED.RevisionID VALUES(@company,@article,(SELECT ISNULL(MAX(RevisionNo),0)+1 FROM dbo.TDKNArticleRevision WHERE CompanyID=@company AND ArticleID=@article),@body,N'DRAFT',@reviewer,@user)",token,("@company",company),("@article",id),("@body",source[0]["body"]),("@reviewer",source[0]["reviewer"]),("@user",user));
        await Execute(db,tx,"UPDATE dbo.TDKNArticle SET CurrentRevisionID=@revision,StatusCode=N'DRAFT',UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ArticleID=@id",token,("@revision",revision),("@user",user),("@company",company),("@id",id));await Audit(db,tx,company,"ARTICLE",id,"CREATE_REVISION",null,user,token);await tx.CommitAsync(token);return Ok(new{id,revisionId=revision});
    }

    [HttpGet("reviews")]
    public async Task<IActionResult> Reviews(CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49004","VIEW",token))return Forbid();
        return Ok(await Query(db,"SELECT a.ArticleID id,a.ArticleCode code,a.Title title,c.CategoryName categoryName,a.ContentType contentType,a.StatusCode status,r.RevisionNo revisionNo,r.SubmittedAt,COALESCE(e.FullName,u.Username) ownerName FROM dbo.TDKNArticle a JOIN dbo.TDKNCategory c ON c.CategoryID=a.CategoryID AND c.CompanyID=a.CompanyID JOIN dbo.TDKNArticleRevision r ON r.RevisionID=a.CurrentRevisionID LEFT JOIN dbo.TDADUser u ON u.CompanyID=a.CompanyID AND u.UserID=a.OwnerUserID LEFT JOIN dbo.TDADUserEmployee ue ON ue.CompanyID=u.CompanyID AND ue.UserID=u.UserID AND ue.IsActive=1 LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE a.CompanyID=@company AND a.StatusCode=N'IN_REVIEW' AND (r.ReviewerUserID IS NULL OR r.ReviewerUserID=@user) ORDER BY r.SubmittedAt",token,("@company",company),("@user",user)));
    }

    [HttpPost("reviews/{id:long}/publish")]
    public Task<IActionResult> Publish(long id,WorkflowRequest request,CancellationToken token)=>Review(id,"PUBLISH",request,token);
    [HttpPost("reviews/{id:long}/return")]
    public Task<IActionResult> Return(long id,WorkflowRequest request,CancellationToken token)=>Review(id,"RETURN",request,token);
    async Task<IActionResult> Review(long id,string action,WorkflowRequest request,CancellationToken token)
    {
        action=action.ToUpperInvariant();if(action is not ("PUBLISH" or "RETURN"))return NotFound();if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49004",action,token))return Forbid();if(action=="RETURN"&&Clean(request.Note) is null)return Bad("กรุณาระบุเหตุผล","การส่งกลับต้องมีเหตุผลเพื่อให้เจ้าของแก้ไขได้ถูกต้อง");
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);var months=await Scalar<int>(db,tx,"SELECT COALESCE((SELECT DefaultReviewMonths FROM dbo.TDKNSystemSetting WHERE CompanyID=@company),12)",token,("@company",company));var state=action=="PUBLISH"?"PUBLISHED":"RETURNED";var changed=await Execute(db,tx,"UPDATE r SET StatusCode=@state,ReviewedBy=@user,ReviewedAt=SYSUTCDATETIME(),ReturnReason=@note,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() FROM dbo.TDKNArticleRevision r JOIN dbo.TDKNArticle a ON a.ArticleID=r.ArticleID AND a.CurrentRevisionID=r.RevisionID WHERE a.CompanyID=@company AND a.ArticleID=@id AND a.StatusCode=N'IN_REVIEW';UPDATE dbo.TDKNArticle SET StatusCode=@state,PublishedRevisionID=CASE WHEN @state=N'PUBLISHED' THEN CurrentRevisionID ELSE PublishedRevisionID END,PublishedAt=CASE WHEN @state=N'PUBLISHED' THEN SYSUTCDATETIME() ELSE PublishedAt END,NextReviewDate=CASE WHEN @state=N'PUBLISHED' THEN DATEADD(month,@months,CAST(SYSUTCDATETIME() AS date)) ELSE NextReviewDate END,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ArticleID=@id AND StatusCode=N'IN_REVIEW'",token,("@state",state),("@note",Clean(request.Note)),("@user",user),("@company",company),("@id",id),("@months",months));if(changed==0){await tx.RollbackAsync(token);return Conflict(new{message="ดำเนินการไม่ได้",description="รายการไม่ได้อยู่ระหว่างตรวจทานหรือมีผู้ดำเนินการไปแล้ว"});}await Audit(db,tx,company,"ARTICLE",id,action,Clean(request.Note),user,token);await tx.CommitAsync(token);return NoContent();
    }
    [HttpGet("library")]
    public async Task<IActionResult> Library(string? search=null,int page=1,int pageSize=20,CancellationToken token=default)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49005","VIEW",token))return Forbid();await MarkReviewDue(db,company,token);page=Math.Max(1,page);pageSize=Math.Clamp(pageSize,1,100);
        var sql=AudienceSql("SELECT a.ArticleID id,a.ArticleCode code,a.Title title,a.SummaryText summary,a.ContentType contentType,a.SourceUrl sourceUrl,c.CategoryName categoryName,N'PUBLISHED' status,r.RevisionNo revisionNo,a.PublishedAt,a.NextReviewDate,CAST(CASE WHEN f.UserID IS NULL THEN 0 ELSE 1 END AS bit) followed FROM dbo.TDKNArticle a JOIN dbo.TDKNCategory c ON c.CompanyID=a.CompanyID AND c.CategoryID=a.CategoryID JOIN dbo.TDKNArticleRevision r ON r.RevisionID=a.PublishedRevisionID LEFT JOIN dbo.TDKNFollow f ON f.CompanyID=a.CompanyID AND f.ArticleID=a.ArticleID AND f.UserID=@user")+" ORDER BY a.PublishedAt DESC OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY";
        var countSql=AudienceSql("SELECT COUNT(*) FROM dbo.TDKNArticle a");var args=new(string,object?)[]{("@company",company),("@user",user),("@search",Clean(search))};var total=await Scalar<int>(db,countSql,token,args);var items=await Query(db,sql,token,[..args,("@skip",(page-1)*pageSize),("@take",pageSize)]);return Ok(new{items,total,page,pageSize});
    }

    [HttpPut("articles/{id:long}/feedback")]
    public async Task<IActionResult> Feedback(long id,FeedbackRequest request,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49005","FEEDBACK",token)||!await HasAudience(db,company,id,user,token))return Forbid();
        await Execute(db,"MERGE dbo.TDKNFeedback AS t USING(SELECT @company CompanyID,@id ArticleID,@user UserID) s ON t.CompanyID=s.CompanyID AND t.ArticleID=s.ArticleID AND t.UserID=s.UserID WHEN MATCHED THEN UPDATE SET IsHelpful=@helpful,CommentText=@comment,UpdateDate=SYSUTCDATETIME() WHEN NOT MATCHED THEN INSERT(CompanyID,ArticleID,RevisionID,UserID,IsHelpful,CommentText) VALUES(@company,@id,(SELECT PublishedRevisionID FROM dbo.TDKNArticle WHERE CompanyID=@company AND ArticleID=@id),@user,@helpful,@comment);",token,("@company",company),("@id",id),("@user",user),("@helpful",request.IsHelpful),("@comment",Clean(request.Comment)));return NoContent();
    }

    [HttpPut("articles/{id:long}/follow")]
    public async Task<IActionResult> Follow(long id,FollowRequest request,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49005","FOLLOW",token)&&!await Can(db,"49007","FOLLOW",token))return Forbid();if(!await HasAudience(db,company,id,user,token))return Forbid();
        if(request.Follow)await Execute(db,"IF NOT EXISTS(SELECT 1 FROM dbo.TDKNFollow WHERE CompanyID=@company AND ArticleID=@id AND UserID=@user) INSERT dbo.TDKNFollow(CompanyID,ArticleID,UserID) VALUES(@company,@id,@user)",token,("@company",company),("@id",id),("@user",user));else await Execute(db,"DELETE dbo.TDKNFollow WHERE CompanyID=@company AND ArticleID=@id AND UserID=@user",token,("@company",company),("@id",id),("@user",user));return NoContent();
    }

    [HttpGet("mine")]
    public async Task<IActionResult> Mine(CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49007","VIEW",token))return Forbid();
        var authored=await Query(db,"SELECT TOP(50) ArticleID id,ArticleCode code,Title title,StatusCode status,ContentType contentType,CreateDate FROM dbo.TDKNArticle WHERE CompanyID=@company AND OwnerUserID=@user AND IsActive=1 ORDER BY CreateDate DESC",token,("@company",company),("@user",user));
        var followed=await Query(db,"SELECT TOP(50) a.ArticleID id,a.ArticleCode code,a.Title title,a.StatusCode status,a.ContentType contentType,f.CreateDate followedAt FROM dbo.TDKNFollow f JOIN dbo.TDKNArticle a ON a.CompanyID=f.CompanyID AND a.ArticleID=f.ArticleID WHERE f.CompanyID=@company AND f.UserID=@user AND a.StatusCode IN(N'PUBLISHED',N'REVIEW_DUE') ORDER BY f.CreateDate DESC",token,("@company",company),("@user",user));return Ok(new{authored,followed});
    }
    [HttpGet("questions")]
    public async Task<IActionResult> Questions(string? status=null,CancellationToken token=default)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49006","VIEW",token))return Forbid();
        return Ok(await Query(db,"SELECT q.QuestionID id,q.QuestionTitle title,q.QuestionText question,c.CategoryName categoryName,q.StatusCode status,q.AskedBy askedBy,q.CreateDate,COUNT(a.AnswerID) answerCount,MAX(CASE WHEN a.IsAccepted=1 THEN a.AnswerID END) acceptedAnswerId,q.ConvertedArticleID convertedArticleId,CAST(CASE WHEN q.AskedBy=@user AND q.StatusCode=N'OPEN' AND COUNT(a.AnswerID)=0 THEN 1 ELSE 0 END AS bit) canEdit,CAST(CASE WHEN q.AskedBy=@user AND q.ConvertedArticleID IS NULL THEN 1 ELSE 0 END AS bit) canDelete FROM dbo.TDKNQuestion q JOIN dbo.TDKNCategory c ON c.CompanyID=q.CompanyID AND c.CategoryID=q.CategoryID LEFT JOIN dbo.TDKNAnswer a ON a.CompanyID=q.CompanyID AND a.QuestionID=q.QuestionID WHERE q.CompanyID=@company AND (@status IS NULL OR q.StatusCode=@status) GROUP BY q.QuestionID,q.QuestionTitle,q.QuestionText,c.CategoryName,q.StatusCode,q.AskedBy,q.CreateDate,q.ConvertedArticleID ORDER BY q.CreateDate DESC",token,("@company",company),("@user",user),("@status",Clean(status)?.ToUpperInvariant())));
    }

    [HttpGet("questions/{id:long}")]
    public async Task<IActionResult> Question(long id,CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"49006","VIEW",token))return Forbid();
        var rows=await Query(db,"SELECT q.QuestionID id,q.CategoryID categoryId,q.QuestionTitle title,q.QuestionText question,q.AskedBy askedBy,q.StatusCode status,q.ConvertedArticleID convertedArticleId,q.CreateDate,c.CategoryName categoryName FROM dbo.TDKNQuestion q JOIN dbo.TDKNCategory c ON c.CompanyID=q.CompanyID AND c.CategoryID=q.CategoryID WHERE q.CompanyID=@company AND q.QuestionID=@id",token,("@company",company),("@id",id));if(rows.Count==0)return NotFound();
        var answers=await Query(db,"SELECT a.AnswerID id,a.AnswerText answer,a.AnsweredBy answeredBy,a.IsAccepted accepted,a.CreateDate,COALESCE(e.FullName,u.Username) answeredByName FROM dbo.TDKNAnswer a LEFT JOIN dbo.TDADUser u ON u.CompanyID=a.CompanyID AND u.UserID=a.AnsweredBy LEFT JOIN dbo.TDADUserEmployee ue ON ue.CompanyID=u.CompanyID AND ue.UserID=u.UserID AND ue.IsActive=1 LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE a.CompanyID=@company AND a.QuestionID=@id ORDER BY a.CreateDate",token,("@company",company),("@id",id));return Ok(new{question=rows[0],answers});
    }
    [HttpPost("questions")]
    public async Task<IActionResult> Question(QuestionRequest request,CancellationToken token)
    {
        if(Clean(request.Title) is null||Clean(request.Question) is null||request.CategoryId<=0)return Bad("ข้อมูลคำถามไม่ครบ","ระบุหัวข้อ รายละเอียด และหมวดความรู้");if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49006","CREATE",token))return Forbid();
        var id=await Scalar<long>(db,"INSERT dbo.TDKNQuestion(CompanyID,CategoryID,QuestionTitle,QuestionText,AskedBy,StatusCode,AudienceMode) OUTPUT INSERTED.QuestionID VALUES(@company,@category,@title,@question,@user,N'OPEN',N'ALL')",token,("@company",company),("@category",request.CategoryId),("@title",request.Title.Trim()),("@question",request.Question.Trim()),("@user",user));return Ok(new{id});
    }

    [HttpPost("questions/{id:long}/answers")]
    public async Task<IActionResult> Answer(long id,AnswerRequest request,CancellationToken token)
    {
        if(Clean(request.Answer) is null)return Bad("ยังไม่มีคำตอบ","ระบุคำตอบก่อนบันทึก");if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49006","ANSWER",token))return Forbid();
        var answer=await Scalar<long>(db,"INSERT dbo.TDKNAnswer(CompanyID,QuestionID,AnswerText,AnsweredBy) OUTPUT INSERTED.AnswerID SELECT @company,@id,@answer,@user WHERE EXISTS(SELECT 1 FROM dbo.TDKNQuestion WHERE CompanyID=@company AND QuestionID=@id AND StatusCode<>N'RESOLVED');UPDATE dbo.TDKNQuestion SET StatusCode=N'ANSWERED',UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND QuestionID=@id AND StatusCode=N'OPEN'",token,("@company",company),("@id",id),("@answer",request.Answer.Trim()),("@user",user));return answer>0?Ok(new{id=answer}):NotFound();
    }

    [HttpPut("questions/{id:long}")]
    public async Task<IActionResult> UpdateQuestion(long id,QuestionRequest request,CancellationToken token)
    {
        if(Clean(request.Title) is null||Clean(request.Question) is null||request.CategoryId<=0)return Bad("ข้อมูลคำถามไม่ครบ","ระบุหัวข้อ รายละเอียด และหมวดความรู้");if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49006","EDIT",token))return Forbid();
        var changed=await Execute(db,"UPDATE dbo.TDKNQuestion SET CategoryID=@category,QuestionTitle=@title,QuestionText=@question,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND QuestionID=@id AND AskedBy=@user AND StatusCode=N'OPEN' AND NOT EXISTS(SELECT 1 FROM dbo.TDKNAnswer WHERE CompanyID=@company AND QuestionID=@id)",token,("@company",company),("@id",id),("@category",request.CategoryId),("@title",request.Title.Trim()),("@question",request.Question.Trim()),("@user",user));return changed==1?NoContent():Conflict(new{message="แก้ไขคำถามไม่ได้",description="แก้ไขได้เฉพาะคำถามของตนที่ยังไม่มีคำตอบ"});
    }

    [HttpDelete("questions/{id:long}")]
    public async Task<IActionResult> DeleteQuestion(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49006","DELETE",token))return Forbid();
        var changed=await Execute(db,"DELETE dbo.TDKNQuestion WHERE CompanyID=@company AND QuestionID=@id AND AskedBy=@user AND ConvertedArticleID IS NULL",token,("@company",company),("@id",id),("@user",user));return changed==1?NoContent():Conflict(new{message="ลบคำถามไม่ได้",description="ลบได้เฉพาะคำถามของตนที่ยังไม่ถูกแปลงเป็นองค์ความรู้"});
    }

    [HttpPost("questions/{id:long}/accept/{answerId:long}")]
    public async Task<IActionResult> Accept(long id,long answerId,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49006","ACCEPT",token))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);var owned=await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDKNQuestion q JOIN dbo.TDKNAnswer a ON a.CompanyID=q.CompanyID AND a.QuestionID=q.QuestionID WHERE q.CompanyID=@company AND q.QuestionID=@id AND q.AskedBy=@user AND q.StatusCode<>N'RESOLVED' AND a.AnswerID=@answer",token,("@company",company),("@id",id),("@answer",answerId),("@user",user));if(owned==0){await tx.RollbackAsync(token);return Forbid();}await Execute(db,tx,"UPDATE dbo.TDKNAnswer SET IsAccepted=CASE WHEN AnswerID=@answer THEN 1 ELSE 0 END WHERE CompanyID=@company AND QuestionID=@id;UPDATE dbo.TDKNQuestion SET StatusCode=N'RESOLVED',UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND QuestionID=@id",token,("@company",company),("@id",id),("@answer",answerId));await tx.CommitAsync(token);return NoContent();
    }
    [HttpPost("questions/{id:long}/convert")]
    public async Task<IActionResult> ConvertQuestion(long id,ConvertQuestionRequest request,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49006","CONVERT",token)||!await Can(db,"49003","CREATE",token))return Forbid();await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        var q=await Query(db,tx,"SELECT q.CategoryID categoryId,q.QuestionTitle title,q.QuestionText question,a.AnswerText answer FROM dbo.TDKNQuestion q JOIN dbo.TDKNAnswer a ON a.CompanyID=q.CompanyID AND a.QuestionID=q.QuestionID AND a.IsAccepted=1 WHERE q.CompanyID=@company AND q.QuestionID=@id AND q.StatusCode=N'RESOLVED' AND q.ConvertedArticleID IS NULL",token,("@company",company),("@id",id));if(q.Count==0){await tx.RollbackAsync(token);return Conflict(new{message="สร้างบทความไม่ได้",description="คำถามต้องปิดด้วยคำตอบที่ยอมรับ และยังไม่เคยสร้างบทความ"});}
        var article=await Scalar<long>(db,tx,"INSERT dbo.TDKNArticle(CompanyID,ArticleCode,CategoryID,Title,SummaryText,ContentType,OwnerUserID,StatusCode,AudienceMode,CreateBy) OUTPUT INSERTED.ArticleID VALUES(@company,@code,@category,@title,@summary,N'ARTICLE',@user,N'DRAFT',N'ALL',@user)",token,("@company",company),("@code",$"KN-QA-{id}-{DateTime.UtcNow:yyyyMMddHHmmss}"),("@category",Convert.ToInt64(q[0]["categoryId"])),("@title",Clean(request.Title)??Convert.ToString(q[0]["title"])),("@summary",Convert.ToString(q[0]["question"])),("@user",user));
        var revision=await Scalar<long>(db,tx,"INSERT dbo.TDKNArticleRevision(CompanyID,ArticleID,RevisionNo,BodyText,StatusCode,CreateBy) OUTPUT INSERTED.RevisionID VALUES(@company,@article,1,@body,N'DRAFT',@user)",token,("@company",company),("@article",article),("@body",Convert.ToString(q[0]["answer"])),("@user",user));await Execute(db,tx,"UPDATE dbo.TDKNArticle SET CurrentRevisionID=@revision WHERE CompanyID=@company AND ArticleID=@article;UPDATE dbo.TDKNQuestion SET ConvertedArticleID=@article,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND QuestionID=@id",token,("@revision",revision),("@company",company),("@article",article),("@id",id));await tx.CommitAsync(token);return Ok(new{id=article});
    }

    [HttpGet("reports")]
    public async Task<IActionResult> Reports(CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"49008","VIEW",token))return Forbid();await MarkReviewDue(db,company,token);
        var totals=(await Query(db,"SELECT COUNT(*) total,SUM(CASE WHEN StatusCode=N'PUBLISHED' THEN 1 ELSE 0 END) published,SUM(CASE WHEN StatusCode=N'IN_REVIEW' THEN 1 ELSE 0 END) inReview,SUM(CASE WHEN StatusCode=N'REVIEW_DUE' THEN 1 ELSE 0 END) reviewDue FROM dbo.TDKNArticle WHERE CompanyID=@company AND IsActive=1",token,("@company",company))).Single();
        var byCategory=await Query(db,"SELECT c.CategoryName name,COUNT(a.ArticleID) value FROM dbo.TDKNCategory c LEFT JOIN dbo.TDKNArticle a ON a.CompanyID=c.CompanyID AND a.CategoryID=c.CategoryID AND a.IsActive=1 WHERE c.CompanyID=@company GROUP BY c.CategoryID,c.CategoryName ORDER BY value DESC",token,("@company",company));
        var feedback=await Query(db,"SELECT SUM(CASE WHEN IsHelpful=1 THEN 1 ELSE 0 END) helpful,SUM(CASE WHEN IsHelpful=0 THEN 1 ELSE 0 END) unhelpful FROM dbo.TDKNFeedback WHERE CompanyID=@company",token,("@company",company));return Ok(new{totals,byCategory,feedback=feedback.SingleOrDefault()});
    }
    [HttpGet("articles/{id:long}/source")]
    public async Task<IActionResult> Source(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49005","VIEW",token)||!await HasAudience(db,company,id,user,token))return Forbid();
        var rows=await Query(db,"SELECT SourceSystem sourceSystem,SourceType sourceType,SourceID sourceId,SourceRevision sourceRevision,SourceUrl sourceUrl FROM dbo.TDKNArticle WHERE CompanyID=@company AND ArticleID=@id AND PublishedRevisionID IS NOT NULL",token,("@company",company),("@id",id));if(rows.Count==0)return NotFound();var source=Convert.ToString(rows[0]["sourceSystem"])?.ToUpperInvariant();
        var sourceMenu=source switch{"DOCUMENT_CONTROL"=>"48006","TRAINING"=>"37006","INTRANET"=>"43001",_=>null};if(sourceMenu is not null&&!await Can(db,sourceMenu,"VIEW",token))return Forbid();return Ok(rows[0]);
    }
    [HttpPost("articles/{id:long}/files")]
    [RequestSizeLimit(2_200_000_000)]
    public async Task<IActionResult> Upload(long id,[FromForm] IFormFile file,[FromForm] string kind="ATTACHMENT",CancellationToken token=default)
    {
        kind=kind.ToUpperInvariant();if(kind is not ("COVER" or "VIDEO" or "ATTACHMENT")||file.Length<=0)return Bad("ไฟล์ไม่ถูกต้อง","เลือกไฟล์และประเภทไฟล์ที่รองรับ");if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49003","UPLOAD",token))return Forbid();await EnsureSettings(db,company,user,token);
        var setting=(await Query(db,"SELECT MaxVideoMB,MaxAttachmentMB,AllowedVideoExtensions,AllowedAttachmentExtensions FROM dbo.TDKNSystemSetting WHERE CompanyID=@company",token,("@company",company))).Single();var extensions=Convert.ToString(setting[kind=="VIDEO"?"AllowedVideoExtensions":"AllowedAttachmentExtensions"])!.Split(',',StringSplitOptions.RemoveEmptyEntries|StringSplitOptions.TrimEntries);var ext=Path.GetExtension(file.FileName).TrimStart('.').ToLowerInvariant();var max=Convert.ToInt64(setting[kind=="VIDEO"?"MaxVideoMB":"MaxAttachmentMB"])*1024*1024;if(!extensions.Contains(ext,StringComparer.OrdinalIgnoreCase))return Bad("ชนิดไฟล์ไม่รองรับ",$"อนุญาตเฉพาะ {string.Join(", ",extensions)}");if(file.Length>max)return Bad("ไฟล์มีขนาดเกินกำหนด",$"ไฟล์ต้องไม่เกิน {max/1024/1024} MB");
        var revision=await Scalar<long>(db,"SELECT CurrentRevisionID FROM dbo.TDKNArticle WHERE CompanyID=@company AND ArticleID=@id AND StatusCode IN(N'DRAFT',N'RETURNED')",token,("@company",company),("@id",id));if(revision<=0)return Conflict(new{message="แนบไฟล์ไม่ได้",description="แนบไฟล์ได้เฉพาะสถานะร่างหรือส่งกลับ"});
        var root=environment.WebRootPath??Path.Combine(environment.ContentRootPath,"wwwroot");var relative=Path.Combine("uploads","knowledge",company.ToString(),id.ToString(),revision.ToString());var folder=Path.Combine(root,relative);Directory.CreateDirectory(folder);var stored=$"{Guid.NewGuid():N}.{ext}";var full=Path.Combine(folder,stored);await using(var output=System.IO.File.Create(full))await file.CopyToAsync(output,token);await using var input=System.IO.File.OpenRead(full);var hash=Convert.ToHexString(await SHA256.HashDataAsync(input,token));
        var fileId=await Scalar<long>(db,"INSERT dbo.TDKNFile(CompanyID,ArticleID,RevisionID,FileKind,OriginalFileName,StoredFileName,RelativePath,ContentType,FileSizeBytes,Sha256,CreateBy) OUTPUT INSERTED.FileID VALUES(@company,@article,@revision,@kind,@original,@stored,@path,@content,@size,@hash,@user)",token,("@company",company),("@article",id),("@revision",revision),("@kind",kind),("@original",Path.GetFileName(file.FileName)),("@stored",stored),("@path",relative.Replace('\\','/')),("@content",file.ContentType),("@size",file.Length),("@hash",hash),("@user",user));return Ok(new{id=fileId,fileName=file.FileName,sizeBytes=file.Length});
    }

    [HttpGet("files/{id:long}")]
    public async Task<IActionResult> File(long id,bool download=false,CancellationToken token=default)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Can(db,"49005",download?"DOWNLOAD":"PREVIEW",token)&&!await Can(db,"49003",download?"DOWNLOAD":"PREVIEW",token))return Forbid();var rows=await Query(db,"SELECT f.ArticleID articleId,f.RelativePath relativePath,f.StoredFileName storedFileName,f.OriginalFileName originalFileName,f.ContentType contentType FROM dbo.TDKNFile f WHERE f.CompanyID=@company AND f.FileID=@id",token,("@company",company),("@id",id));if(rows.Count==0)return NotFound();var article=Convert.ToInt64(rows[0]["articleId"]);if(!await HasAudience(db,company,article,user,token)&&!await Can(db,"49003","VIEW",token))return Forbid();var root=environment.WebRootPath??Path.Combine(environment.ContentRootPath,"wwwroot");var full=Path.GetFullPath(Path.Combine(root,Convert.ToString(rows[0]["relativePath"])!,Convert.ToString(rows[0]["storedFileName"])!));if(!System.IO.File.Exists(full))return NotFound();return PhysicalFile(full,Convert.ToString(rows[0]["contentType"])??"application/octet-stream",download?Convert.ToString(rows[0]["originalFileName"]):null,enableRangeProcessing:true);
    }
    async Task EnsureSettings(SqlConnection db,long company,long user,CancellationToken token)=>await Execute(db,"IF NOT EXISTS(SELECT 1 FROM dbo.TDKNSystemSetting WHERE CompanyID=@company) INSERT dbo.TDKNSystemSetting(CompanyID,CreateBy) VALUES(@company,@user)",token,("@company",company),("@user",user));
    async Task MarkReviewDue(SqlConnection db,long company,CancellationToken token)=>await Execute(db,"UPDATE dbo.TDKNArticle SET StatusCode=N'REVIEW_DUE',UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND StatusCode=N'PUBLISHED' AND NextReviewDate<CAST(SYSUTCDATETIME() AS date)",token,("@company",company));
    async Task ReplaceAudience(SqlConnection db,SqlTransaction tx,long company,long article,IEnumerable<long>? departments,IEnumerable<long>? users,long actor,CancellationToken token)
    {
        await Execute(db,tx,"DELETE dbo.TDKNArticleAudience WHERE CompanyID=@company AND ArticleID=@article",token,("@company",company),("@article",article));
        foreach(var id in (departments??[]).Distinct().Where(x=>x>0))await Execute(db,tx,"INSERT dbo.TDKNArticleAudience(CompanyID,ArticleID,SubjectType,SubjectID,CreateBy) VALUES(@company,@article,N'DEPARTMENT',@id,@user)",token,("@company",company),("@article",article),("@id",id),("@user",actor));
        foreach(var id in (users??[]).Distinct().Where(x=>x>0))await Execute(db,tx,"INSERT dbo.TDKNArticleAudience(CompanyID,ArticleID,SubjectType,SubjectID,CreateBy) VALUES(@company,@article,N'USER',@id,@user)",token,("@company",company),("@article",article),("@id",id),("@user",actor));
    }
    string AudienceSql(string select)=>select+" WHERE a.CompanyID=@company AND a.PublishedRevisionID IS NOT NULL AND a.IsActive=1 AND (@search IS NULL OR a.ArticleCode LIKE N'%'+@search+N'%' OR a.Title LIKE N'%'+@search+N'%' OR a.SummaryText LIKE N'%'+@search+N'%') AND (a.AudienceMode=N'ALL' OR a.OwnerUserID=@user OR EXISTS(SELECT 1 FROM dbo.TDKNArticleAudience aa WHERE aa.CompanyID=a.CompanyID AND aa.ArticleID=a.ArticleID AND (aa.SubjectType=N'USER' AND aa.SubjectID=@user OR aa.SubjectType=N'DEPARTMENT' AND aa.SubjectID IN(SELECT e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1 AND e.IsActive=1))))";
    async Task<bool> HasAudience(SqlConnection db,long company,long article,long user,CancellationToken token)=>await Scalar<int>(db,"SELECT COUNT(*) FROM dbo.TDKNArticle a WHERE a.CompanyID=@company AND a.ArticleID=@article AND a.PublishedRevisionID IS NOT NULL AND (a.AudienceMode=N'ALL' OR a.OwnerUserID=@user OR EXISTS(SELECT 1 FROM dbo.TDKNArticleAudience aa WHERE aa.CompanyID=a.CompanyID AND aa.ArticleID=a.ArticleID AND ((aa.SubjectType=N'USER' AND aa.SubjectID=@user) OR (aa.SubjectType=N'DEPARTMENT' AND aa.SubjectID IN(SELECT e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1 AND e.IsActive=1)))))",token,("@company",company),("@article",article),("@user",user))>0;
    async Task Audit(SqlConnection db,SqlTransaction tx,long company,string entity,long id,string action,string? detail,long user,CancellationToken token)=>await Execute(db,tx,"INSERT dbo.TDKNAudit(CompanyID,EntityType,EntityID,ActionCode,DetailText,UserID,IpAddress) VALUES(@company,@entity,@id,@action,@detail,@user,@ip)",token,("@company",company),("@entity",entity),("@id",id),("@action",action),("@detail",detail),("@user",user),("@ip",HttpContext.Connection.RemoteIpAddress?.ToString()));
    Task<bool> Can(SqlConnection db,string menu,string action,CancellationToken token)=>CompanyMenuAccess.IsAllowedAsync(db,User,menu,action,token);
    async Task<bool> AnyView(SqlConnection db,CancellationToken token){foreach(var menu in Menus)if(await Can(db,menu,"VIEW",token))return true;return false;}
    bool Scope(out long company,out long user){company=0;user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}
    async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
    ObjectResult Bad(string message,string description)=>BadRequest(new{message,description});
    static void Params(SqlCommand command,IEnumerable<(string Name,object? Value)> values){foreach(var (name,value) in values)command.Parameters.AddWithValue(name,value??DBNull.Value);}
    static async Task<List<Dictionary<string,object?>>> Query(SqlConnection db,string sql,CancellationToken token,params (string,object?)[] values)=>await Query(db,null,sql,token,values);
    static async Task<List<Dictionary<string,object?>>> Query(SqlConnection db,SqlTransaction? tx,string sql,CancellationToken token,params (string,object?)[] values)
    {
        await using var command=new SqlCommand(sql,db,tx);Params(command,values);await using var reader=await command.ExecuteReaderAsync(token);var result=new List<Dictionary<string,object?>>();while(await reader.ReadAsync(token)){var row=new Dictionary<string,object?>(StringComparer.OrdinalIgnoreCase);for(var i=0;i<reader.FieldCount;i++)row[reader.GetName(i)]=await reader.IsDBNullAsync(i,token)?null:reader.GetValue(i);result.Add(row);}return result;
    }
    static async Task<int> Execute(SqlConnection db,string sql,CancellationToken token,params (string,object?)[] values)=>await Execute(db,null,sql,token,values);
    static async Task<int> Execute(SqlConnection db,SqlTransaction? tx,string sql,CancellationToken token,params (string,object?)[] values){await using var command=new SqlCommand(sql,db,tx);Params(command,values);return await command.ExecuteNonQueryAsync(token);}
    static async Task<T> Scalar<T>(SqlConnection db,string sql,CancellationToken token,params (string,object?)[] values)=>await Scalar<T>(db,null,sql,token,values);
    static async Task<T> Scalar<T>(SqlConnection db,SqlTransaction? tx,string sql,CancellationToken token,params (string,object?)[] values){await using var command=new SqlCommand(sql,db,tx);Params(command,values);var value=await command.ExecuteScalarAsync(token);if(value is null||value==DBNull.Value)return default!;return (T)Convert.ChangeType(value,Nullable.GetUnderlyingType(typeof(T))??typeof(T));}
}

public sealed record SettingsRequest(int MaxVideoMb,int MaxAttachmentMb,int DefaultReviewMonths);
public sealed record CategoryRequest(string Code,string Name,long? OwnerUserId,int SortOrder=0,bool Active=true);
public sealed record ArticleRequest(long CategoryId,string? Code,string Title,string? Summary,string ContentType,string? Body,string? SourceSystem,string? SourceType,string? SourceId,string? SourceRevision,string? SourceUrl,long? ReviewerUserId,string AudienceMode,List<long>? DepartmentIds,List<long>? UserIds,DateTime? NextReviewDate);
public sealed record WorkflowRequest(string? Note);
public sealed record FeedbackRequest(bool IsHelpful,string? Comment);
public sealed record FollowRequest(bool Follow);
public sealed record QuestionRequest(long CategoryId,string Title,string Question);
public sealed record AnswerRequest(string Answer);
public sealed record ConvertQuestionRequest(string? Title);
