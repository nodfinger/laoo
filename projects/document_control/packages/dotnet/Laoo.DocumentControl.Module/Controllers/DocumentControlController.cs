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

namespace LaooDocumentControlModule.Controllers;

[ApiController, Authorize, Route("api/company/document-control")]
public sealed class DocumentControlController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    static readonly string[] Menus = ["48001","48002","48003","48004","48005","48006","48007","48008"];

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken token)
    {
        if (!Menus.Contains(menu) || !Scope(out _, out _)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, menu, "VIEW", token)) return Forbid();
        var names = new[] {"CREATE","EDIT","DELETE","SUBMIT","REVIEW","APPROVE","RETURN","PUBLISH","PREVIEW","DOWNLOAD","ACKNOWLEDGE","EXPORT"};
        var values = new Dictionary<string,bool>();
        foreach (var name in names) values[name.ToLowerInvariant()] = await Can(db, menu, name, token);
        return Ok(values);
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken token)
    {
        if (!Scope(out var company, out _)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db,"48001","VIEW",token)) return Forbid();
        await EnsureSettings(db,company,token);
        return Ok((await Query(db,"SELECT MaxPrimaryFileMB maxPrimaryFileMb,MaxAttachmentFileMB maxAttachmentFileMb,AllowedAttachmentExtensions allowedAttachmentExtensions,ReminderDays reminderDays FROM dbo.TDDCSystemSetting WHERE CompanyID=@company",token,("@company",company))).Single());
    }

    [HttpPut("settings")]
    public async Task<IActionResult> Settings(SettingsRequest request, CancellationToken token)
    {
        if (request.MaxPrimaryFileMb is <1 or >100 || request.MaxAttachmentFileMb is <1 or >100 || request.ReminderDays is <0 or >365 || string.IsNullOrWhiteSpace(request.AllowedAttachmentExtensions))
            return Bad("ข้อมูลตั้งค่าไม่ถูกต้อง","ขนาดไฟล์ต้องอยู่ระหว่าง 1-100 MB และวันเตือน 0-365 วัน");
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db,"48001","EDIT",token)) return Forbid();
        await EnsureSettings(db,company,token);
        await Execute(db,"UPDATE dbo.TDDCSystemSetting SET MaxPrimaryFileMB=@primary,MaxAttachmentFileMB=@attachment,AllowedAttachmentExtensions=@extensions,ReminderDays=@days,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company",token,
            ("@primary",request.MaxPrimaryFileMb),("@attachment",request.MaxAttachmentFileMb),("@extensions",request.AllowedAttachmentExtensions.Trim().ToLowerInvariant()),("@days",request.ReminderDays),("@user",user),("@company",company));
        return NoContent();
    }

    [HttpGet("types")]
    public async Task<IActionResult> Types(CancellationToken token)
    {
        if (!Scope(out var company,out _)) return Forbid();
        await using var db=await Open(token);
        if (!await Can(db,"48002","VIEW",token)) return Forbid();
        return Ok(await Query(db,"SELECT DocumentTypeID id,TypeCode code,TypeName name,DocumentClass documentClass,RequireAcknowledgement requireAcknowledgement,DefaultReviewerUserID defaultReviewerUserId,DefaultApproverUserID defaultApproverUserId,DefaultAudienceMode defaultAudienceMode,IsActive active FROM dbo.TDDCDocumentType WHERE CompanyID=@company ORDER BY TypeCode",token,("@company",company)));
    }

    [HttpPost("types")]
    public Task<IActionResult> Type(TypeRequest request,CancellationToken token)=>SaveType(null,request,"CREATE",token);
    [HttpPut("types/{id:long}")]
    public Task<IActionResult> Type(long id,TypeRequest request,CancellationToken token)=>SaveType(id,request,"EDIT",token);

    async Task<IActionResult> SaveType(long? id,TypeRequest request,string action,CancellationToken token)
    {
        var name=Clean(request.Name); var kind=Clean(request.DocumentClass)?.ToUpperInvariant();
        if(name is null||name.Length>200||kind is not ("CONTROLLED" or "GENERAL")||request.DefaultAudienceMode is not ("ALL" or "RESTRICTED")) return Bad("ข้อมูลประเภทเอกสารไม่ครบ","ระบุชื่อ กลุ่มเอกสาร และผู้มีสิทธิ์เริ่มต้นให้ถูกต้อง");
        if(!Scope(out var company,out var user)) return Forbid();
        await using var db=await Open(token); if(!await Can(db,"48002",action,token)) return Forbid();
        try {
            await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
            var sql=id is null ? """
DECLARE @next int;
SELECT @next=COALESCE(MAX(TRY_CONVERT(int,TypeCode)),0)+1
FROM dbo.TDDCDocumentType WITH (UPDLOCK,HOLDLOCK)
WHERE CompanyID=@company AND LEN(TypeCode) BETWEEN 1 AND 6 AND TypeCode NOT LIKE N'%[^0-9]%';
IF @next>999999 THROW 56901,N'รหัสประเภทเอกสารครบจำนวนที่กำหนด',1;
DECLARE @code nvarchar(6)=RIGHT(N'000000'+CONVERT(nvarchar(6),@next),6);
INSERT dbo.TDDCDocumentType(CompanyID,TypeCode,TypeName,DocumentClass,RequireAcknowledgement,DefaultReviewerUserID,DefaultApproverUserID,DefaultAudienceMode,IsActive,CreateBy)
OUTPUT INSERTED.DocumentTypeID VALUES(@company,@code,@name,@kind,@ack,@reviewer,@approver,@audience,@active,@user);
""" : """
UPDATE dbo.TDDCDocumentType SET TypeName=@name,DocumentClass=@kind,RequireAcknowledgement=@ack,DefaultReviewerUserID=@reviewer,DefaultApproverUserID=@approver,DefaultAudienceMode=@audience,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.DocumentTypeID WHERE CompanyID=@company AND DocumentTypeID=@id;
""";
            await using var command=new SqlCommand(sql,db,tx);
            command.Parameters.AddWithValue("@company",company);command.Parameters.AddWithValue("@id",(object?)id??DBNull.Value);
            command.Parameters.AddWithValue("@name",name);command.Parameters.AddWithValue("@kind",kind);command.Parameters.AddWithValue("@ack",request.RequireAcknowledgement);
            command.Parameters.AddWithValue("@reviewer",(object?)request.DefaultReviewerUserId??DBNull.Value);command.Parameters.AddWithValue("@approver",(object?)request.DefaultApproverUserId??DBNull.Value);
            command.Parameters.AddWithValue("@audience",request.DefaultAudienceMode);command.Parameters.AddWithValue("@active",request.Active);command.Parameters.AddWithValue("@user",user);
            var result=await command.ExecuteScalarAsync(token);var saved=result is null?0:Convert.ToInt64(result);
            await tx.CommitAsync(token);
            return saved>0?Ok(new{id=saved}):NotFound();
        } catch(SqlException e) when(e.Number is 2601 or 2627 or 56901) { return Conflict(new{message="ไม่สามารถสร้างรหัสประเภทเอกสาร",description="รหัสเต็มหรือมีการบันทึกพร้อมกัน กรุณาลองใหม่หรือติดต่อผู้ดูแลระบบ"}); }
    }

    [HttpDelete("types/{id:long}")]
    public async Task<IActionResult> DeleteType(long id,CancellationToken token)
    {
        if(!Scope(out var company,out _)) return Forbid(); await using var db=await Open(token); if(!await Can(db,"48002","DELETE",token)) return Forbid();
        if(await Scalar<int>(db,"SELECT COUNT(*) FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentTypeID=@id",token,("@company",company),("@id",id))>0) return Conflict(new{message="ลบประเภทเอกสารไม่ได้",description="มีเอกสารอ้างอิงประเภทนี้แล้ว ให้ปิดใช้งานแทน"});
        return await Execute(db,"DELETE dbo.TDDCDocumentType WHERE CompanyID=@company AND DocumentTypeID=@id",token,("@company",company),("@id",id))==1?NoContent():NotFound();
    }

    [HttpGet("options")]
    public async Task<IActionResult> Options(CancellationToken token)
    {
        if(!Scope(out var company,out _)) return Forbid(); await using var db=await Open(token);
        if(!await AnyView(db,token)) return Forbid();
        var types=await Query(db,"SELECT DocumentTypeID id,TypeCode code,TypeName name,DocumentClass documentClass,RequireAcknowledgement requireAcknowledgement,DefaultReviewerUserID reviewerUserId,DefaultApproverUserID approverUserId,DefaultAudienceMode audienceMode FROM dbo.TDDCDocumentType WHERE CompanyID=@company AND IsActive=1 ORDER BY TypeName",token,("@company",company));
        var users=await Query(db,"SELECT u.UserID id,u.Username code,COALESCE(e.FullName,u.Username) name,e.DepartmentOrgUnitID departmentId FROM dbo.TDADUser u LEFT JOIN dbo.TDADUserEmployee ue ON ue.CompanyID=u.CompanyID AND ue.UserID=u.UserID AND ue.IsActive=1 LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID AND e.IsActive=1 WHERE u.CompanyID=@company AND u.IsActive=1 ORDER BY COALESCE(e.FullName,u.Username)",token,("@company",company));
        var departments=await Query(db,"SELECT OrgUnitID id,UnitCode code,NameTH name FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND UnitType IN(N'DEPARTMENT',N'DEP') AND IsActive=1 ORDER BY NameTH",token,("@company",company));
        return Ok(new{types,users,departments});
    }

    [HttpGet("documents")]
    public async Task<IActionResult> Documents(string documentClass="CONTROLLED",string? search=null,string? status=null,int page=1,int pageSize=10,CancellationToken token=default)
    {
        var menu=documentClass.ToUpperInvariant()=="GENERAL"?"48005":"48003";
        if(!Scope(out var company,out var user)) return Forbid(); await using var db=await Open(token); if(!await Can(db,menu,"VIEW",token)) return Forbid();
        await ActivateDue(db,company,token); page=Math.Max(page,1);pageSize=Math.Clamp(pageSize,1,100);
        const string where=" FROM dbo.TDDCDocument d JOIN dbo.TDDCDocumentType t ON t.DocumentTypeID=d.DocumentTypeID AND t.CompanyID=d.CompanyID LEFT JOIN dbo.TDDCRevision r ON r.RevisionID=d.CurrentRevisionID WHERE d.CompanyID=@company AND d.DocumentClass=@kind AND d.IsActive=1 AND (d.OwnerUserID=@user OR r.ReviewerUserID=@user OR r.ApproverUserID=@user OR (d.StatusCode IN(N'EFFECTIVE',N'PUBLISHED') AND EXISTS(SELECT 1 FROM dbo.TDDCAccessRule x WHERE x.CompanyID=d.CompanyID AND x.DocumentID=d.DocumentID AND x.CanView=1 AND (x.SubjectType=N'ALL' OR x.SubjectType=N'USER' AND x.SubjectID=@user OR x.SubjectType=N'DEPARTMENT' AND x.SubjectID IN(SELECT e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1 AND e.IsActive=1))))) AND (@search IS NULL OR d.DocumentNo LIKE N'%'+@search+N'%' OR d.DocumentTitle LIKE N'%'+@search+N'%') AND (@status IS NULL OR d.StatusCode=@status)";
        var args=new(string,object?)[]{("@company",company),("@user",user),("@kind",documentClass.ToUpperInvariant()),("@search",Clean(search)),("@status",Clean(status)?.ToUpperInvariant())};
        var total=await Scalar<int>(db,"SELECT COUNT(*)"+where,token,args);
        var items=await Query(db,"SELECT d.DocumentID id,d.DocumentNo documentNo,d.DocumentTitle title,t.TypeName typeName,d.StatusCode status,r.RevisionNo revisionNo,r.EffectiveDate,d.PublishDate,d.ExpireDate,d.RequireAcknowledgement requireAcknowledgement,CAST(CASE WHEN d.OwnerUserID=@user THEN 1 ELSE 0 END AS bit) canManage"+where+" ORDER BY d.CreateDate DESC OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY",token,[..args,("@skip",(page-1)*pageSize),("@take",pageSize)]);
        return Ok(new{items,total,page,pageSize});
    }

    [HttpGet("documents/{id:long}")]
    public async Task<IActionResult> Document(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user)) return Forbid(); await using var db=await Open(token);
        var rows=await Query(db,"SELECT d.DocumentID id,d.DocumentNo documentNo,d.DocumentTitle title,d.DocumentClass documentClass,d.DocumentTypeID documentTypeId,d.OwnerDepartmentID ownerDepartmentId,d.OwnerUserID ownerUserId,d.StatusCode status,d.AudienceMode audienceMode,d.RequireAcknowledgement requireAcknowledgement,d.PublishDate,d.ExpireDate,r.RevisionID revisionId,r.RevisionNo revisionNo,r.ChangeSummary changeSummary,r.ChangeReason changeReason,r.ImpactAssessment impactAssessment,r.EffectiveDate,r.ReviewerUserID reviewerUserId,r.ApproverUserID approverUserId FROM dbo.TDDCDocument d LEFT JOIN dbo.TDDCRevision r ON r.RevisionID=d.CurrentRevisionID WHERE d.CompanyID=@company AND d.DocumentID=@id",token,("@company",company),("@id",id));
        if(rows.Count==0 || await Scalar<int>(db,"SELECT COUNT(*) FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@id AND IsActive=1",token,("@company",company),("@id",id))!=1)return NotFound();
        var item=rows[0]; var menu=Convert.ToString(item["documentClass"])=="GENERAL"?"48005":"48003";
        var owner=Convert.ToInt64(item["ownerUserId"])==user;
        var reviewer=item["reviewerUserId"] is not null && Convert.ToInt64(item["reviewerUserId"])==user;
        var approver=item["approverUserId"] is not null && Convert.ToInt64(item["approverUserId"])==user;
        var published=Convert.ToString(item["status"]) is "EFFECTIVE" or "PUBLISHED";
        var internalAllowed=owner && await Can(db,menu,"VIEW",token) || (reviewer||approver) && await Can(db,"48004","VIEW",token);
        var canRead=internalAllowed || published && await HasAudience(db,company,id,user,"VIEW",token) && (await Can(db,menu,"VIEW",token)||await Can(db,"48006","VIEW",token)||await Can(db,"48007","VIEW",token));
        if(!canRead)return Forbid();
        if(internalAllowed)item["referenceDocumentNo"]=await Scalar<string>(db,"SELECT STRING_AGG(CONVERT(nvarchar(max),d.DocumentNo),N', ') WITHIN GROUP (ORDER BY d.DocumentNo) FROM dbo.TDDCChangeRequest c JOIN dbo.TDDCChangeRequestReference x ON x.ChangeRequestID=c.ChangeRequestID JOIN dbo.TDDCDocument d ON d.CompanyID=c.CompanyID AND d.DocumentID=x.RelatedDocumentID WHERE c.CompanyID=@company AND c.DocumentID=@id AND c.RevisionID=@revision AND c.RequestType=N'NEW'",token,("@company",company),("@id",id),("@revision",item["revisionId"]));
        var access=await Query(db,"SELECT SubjectType subjectType,SubjectID subjectId,CanView canView,CanPreview canPreview,CanDownload canDownload FROM dbo.TDDCAccessRule WHERE CompanyID=@company AND DocumentID=@id ORDER BY SubjectType,SubjectID",token,("@company",company),("@id",id));
        var files=await Query(db,"SELECT DocumentFileID id,FileRole fileRole,OriginalFileName fileName,ContentType contentType,FileSizeBytes sizeBytes,CreateDate FROM dbo.TDDCFile WHERE CompanyID=@company AND DocumentID=@id AND (@internal=1 OR RevisionID=@current) ORDER BY FileRole DESC,CreateDate",token,("@company",company),("@id",id),("@internal",internalAllowed),("@current",item["revisionId"]));
        var revisions=await Query(db,"SELECT r.RevisionID id,r.RevisionNo revisionNo,r.StatusCode status,r.BasedOnRevisionID basedOnRevisionId,r.EffectiveDate,r.ChangeSummary changeSummary,r.ChangeReason changeReason,r.ImpactAssessment impactAssessment,r.ReviewedDate,r.ApprovedDate,r.CreateDate,CASE WHEN @internal=1 THEN (SELECT STRING_AGG(CONVERT(nvarchar(max),d.DocumentNo),N', ') WITHIN GROUP (ORDER BY d.DocumentNo) FROM dbo.TDDCChangeRequest c JOIN dbo.TDDCChangeRequestReference x ON x.ChangeRequestID=c.ChangeRequestID JOIN dbo.TDDCDocument d ON d.CompanyID=c.CompanyID AND d.DocumentID=x.RelatedDocumentID WHERE c.CompanyID=r.CompanyID AND c.RevisionID=r.RevisionID) ELSE NULL END referenceDocumentNo FROM dbo.TDDCRevision r WHERE r.CompanyID=@company AND r.DocumentID=@id AND (@internal=1 OR r.RevisionID=@current) ORDER BY r.RevisionID DESC",token,("@company",company),("@id",id),("@internal",internalAllowed),("@current",item["revisionId"]));
        return Ok(new{header=rows[0],access,files,revisions});
    }

    [HttpPost("documents")]
    public Task<IActionResult> Document(DocumentRequest request,CancellationToken token)=>SaveDocument(null,request,token);

    [HttpPost("documents/{id:long}/draft-revisions")]
    public async Task<IActionResult> CreateDraftRevision(long id,RevisionDraftRequest request,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();
        if(Clean(request.RevisionNo) is null || Clean(request.ChangeSummary) is null || Clean(request.ChangeReason) is null)return Bad("ข้อมูลฉบับร่างไม่ครบ","ระบุ Revision รายละเอียดและเหตุผลการเปลี่ยนแปลง");
        if(request.RevisionNo.Trim().Length>30 || request.ChangeSummary.Trim().Length>2000 || request.ChangeReason!.Trim().Length>2000 || (request.ImpactAssessment?.Trim().Length??0)>2000)return Bad("ข้อมูลยาวเกินกำหนด","Revision ไม่เกิน 30 ตัวอักษร และข้อความแต่ละช่องไม่เกิน 2,000 ตัวอักษร");
        await using var db=await Open(token);
        var kind=await Scalar<string>(db,"SELECT DocumentClass FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@id AND IsActive=1",token,("@company",company),("@id",id));
        if(kind is not ("GENERAL" or "CONTROLLED"))return NotFound();var menu=kind=="GENERAL"?"48005":"48003";if(!await Can(db,menu,"EDIT",token))return Forbid();
        var refControlled=await Can(db,"48003","VIEW",token);var refGeneral=await Can(db,"48005","VIEW",token);var refLibrary=await Can(db,"48006","VIEW",token);
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try {
            var rows=await Query(db,tx,"SELECT DocumentClass kind,OwnerUserID owner,CurrentRevisionID currentRevisionId,StatusCode status FROM dbo.TDDCDocument WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND DocumentID=@id AND IsActive=1",token,("@company",company),("@id",id));
            if(rows.Count==0){await tx.RollbackAsync(token);return NotFound();}
            var doc=rows[0];
            if(Convert.ToString(doc["kind"])!=kind || Convert.ToInt64(doc["owner"])!=user){await tx.RollbackAsync(token);return Forbid();}
            if(Convert.ToString(doc["status"]) is not ("EFFECTIVE" or "PUBLISHED") || doc["currentRevisionId"] is null){await tx.RollbackAsync(token);return Conflict(new{message="สร้างร่าง Revision ไม่ได้",description="เอกสารต้องมีฉบับที่ใช้งานอยู่"});}
            if(await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDDCRevision WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND DocumentID=@id AND StatusCode IN(N'DRAFT',N'RETURNED',N'IN_REVIEW',N'IN_APPROVAL',N'APPROVED')",token,("@company",company),("@id",id))>0){await tx.RollbackAsync(token);return Conflict(new{message="มีฉบับร่างหรือฉบับรอดำเนินการอยู่แล้ว"});}
            var basedOn=Convert.ToInt64(doc["currentRevisionId"]);
            var revision=await Scalar<long>(db,tx,"INSERT dbo.TDDCRevision(CompanyID,DocumentID,RevisionNo,ChangeSummary,StatusCode,BasedOnRevisionID,ReviewerUserID,ApproverUserID,CreateBy) OUTPUT INSERTED.RevisionID SELECT @company,@id,@no,@summary,N'DRAFT',r.RevisionID,r.ReviewerUserID,r.ApproverUserID,@user FROM dbo.TDDCRevision r WHERE r.CompanyID=@company AND r.DocumentID=@id AND r.RevisionID=@base AND r.StatusCode=N'EFFECTIVE'",token,("@company",company),("@id",id),("@no",request.RevisionNo.Trim().ToUpperInvariant()),("@summary",request.ChangeSummary.Trim()),("@user",user),("@base",basedOn));
            if(revision<=0){await tx.RollbackAsync(token);return Conflict(new{message="ไม่พบฉบับปัจจุบันที่มีผล"});}
            await Execute(db,tx,"UPDATE dbo.TDDCRevision SET ChangeReason=@reason,ImpactAssessment=@impact WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision",token,("@reason",Clean(request.ChangeReason)),("@impact",Clean(request.ImpactAssessment)),("@company",company),("@id",id),("@revision",revision));
            await Execute(db,tx,"INSERT dbo.TDDCChangeRequest(CompanyID,DocumentID,RevisionID,RequestType,StatusCode,RequesterUserID,Reason,ImpactAssessment) VALUES(@company,@id,@revision,N'CHANGE',N'DRAFT',@user,@reason,@impact)",token,("@company",company),("@id",id),("@revision",revision),("@user",user),("@reason",Clean(request.ChangeReason)),("@impact",Clean(request.ImpactAssessment)));
            if(!await SaveDraftReference(db,tx,company,id,revision,user,"CHANGE",request.ReferenceDocumentNo,refControlled,refGeneral,refLibrary,token)){await tx.RollbackAsync(token);return Bad("เอกสารอ้างอิงไม่ถูกต้อง","ไม่พบเอกสารหรือไม่มีสิทธิ์เข้าถึง");}
            await Audit(db,tx,company,id,revision,"CREATE_DRAFT_REVISION",null,user,token);await tx.CommitAsync(token);return Ok(new{id=revision,basedOnRevisionId=basedOn});
        } catch(SqlException e) when(e.Number is 2601 or 2627){await tx.RollbackAsync(token);return Conflict(new{message="Revision ซ้ำ",description="ระบุ Revision ที่ยังไม่เคยใช้กับเอกสารนี้"});}
    }

    [HttpPut("documents/{id:long}/draft-revisions/{revisionId:long}")]
    public async Task<IActionResult> UpdateDraftRevision(long id,long revisionId,RevisionDraftRequest request,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();
        if(Clean(request.RevisionNo) is null || Clean(request.ChangeSummary) is null || Clean(request.ChangeReason) is null)return Bad("ข้อมูลฉบับร่างไม่ครบ","ระบุ Revision รายละเอียดและเหตุผลการเปลี่ยนแปลง");
        if(request.RevisionNo.Trim().Length>30 || request.ChangeSummary.Trim().Length>2000 || request.ChangeReason!.Trim().Length>2000 || (request.ImpactAssessment?.Trim().Length??0)>2000)return Bad("ข้อมูลยาวเกินกำหนด","Revision ไม่เกิน 30 ตัวอักษร และข้อความแต่ละช่องไม่เกิน 2,000 ตัวอักษร");
        await using var db=await Open(token);var kind=await Scalar<string>(db,"SELECT DocumentClass FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@id AND IsActive=1",token,("@company",company),("@id",id));
        if(kind is not ("GENERAL" or "CONTROLLED"))return NotFound();var menu=kind=="GENERAL"?"48005":"48003";if(!await Can(db,menu,"EDIT",token))return Forbid();
        var refControlled=await Can(db,"48003","VIEW",token);var refGeneral=await Can(db,"48005","VIEW",token);var refLibrary=await Can(db,"48006","VIEW",token);
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        try {
            var rows=await Query(db,tx,"SELECT d.DocumentClass kind,d.OwnerUserID owner,d.CurrentRevisionID currentRevisionId,r.BasedOnRevisionID basedOn FROM dbo.TDDCDocument d WITH(UPDLOCK,HOLDLOCK) JOIN dbo.TDDCRevision r WITH(UPDLOCK,HOLDLOCK) ON r.CompanyID=d.CompanyID AND r.DocumentID=d.DocumentID WHERE d.CompanyID=@company AND d.DocumentID=@id AND d.IsActive=1 AND r.RevisionID=@revision AND r.StatusCode=N'DRAFT' AND r.BasedOnRevisionID IS NOT NULL",token,("@company",company),("@id",id),("@revision",revisionId));
            if(rows.Count==0){await tx.RollbackAsync(token);return NotFound();}var doc=rows[0];
            if(Convert.ToString(doc["kind"])!=kind || Convert.ToInt64(doc["owner"])!=user){await tx.RollbackAsync(token);return Forbid();}
            if(Convert.ToInt64(doc["currentRevisionId"])!=Convert.ToInt64(doc["basedOn"])){await tx.RollbackAsync(token);return Conflict(new{message="ฉบับปัจจุบันเปลี่ยนแล้ว",description="ต้องตรวจทานฉบับต้นทางก่อนแก้ไขร่าง"});}
            await Execute(db,tx,"UPDATE dbo.TDDCRevision SET RevisionNo=@no,ChangeSummary=@summary,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND StatusCode=N'DRAFT'",token,("@no",request.RevisionNo.Trim().ToUpperInvariant()),("@summary",request.ChangeSummary.Trim()),("@user",user),("@company",company),("@id",id),("@revision",revisionId));
            await Execute(db,tx,"UPDATE dbo.TDDCRevision SET ChangeReason=@reason,ImpactAssessment=@impact WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision",token,("@reason",Clean(request.ChangeReason)),("@impact",Clean(request.ImpactAssessment)),("@company",company),("@id",id),("@revision",revisionId));
            await Execute(db,tx,"UPDATE dbo.TDDCChangeRequest SET Reason=@reason,ImpactAssessment=@impact,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND StatusCode=N'DRAFT'",token,("@reason",Clean(request.ChangeReason)),("@impact",Clean(request.ImpactAssessment)),("@company",company),("@id",id),("@revision",revisionId));
            if(request.ReferenceDocumentNo is not null && !await SaveDraftReference(db,tx,company,id,revisionId,user,"CHANGE",request.ReferenceDocumentNo,refControlled,refGeneral,refLibrary,token)){await tx.RollbackAsync(token);return Bad("เอกสารอ้างอิงไม่ถูกต้อง","ไม่พบเอกสารหรือไม่มีสิทธิ์เข้าถึง");}
            await Audit(db,tx,company,id,revisionId,"EDIT_DRAFT_REVISION",null,user,token);await tx.CommitAsync(token);return NoContent();
        } catch(SqlException e) when(e.Number is 2601 or 2627){await tx.RollbackAsync(token);return Conflict(new{message="Revision ซ้ำ"});}
    }

    [HttpGet("documents/{id:long}/withdrawal-request")]
    public async Task<IActionResult> GetWithdrawalRequest(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);
        var rows=await Query(db,"SELECT d.DocumentClass kind,d.OwnerUserID owner,d.CurrentRevisionID revisionId FROM dbo.TDDCDocument d WHERE d.CompanyID=@company AND d.DocumentID=@id AND d.IsActive=1",token,("@company",company),("@id",id));
        if(rows.Count==0)return NotFound();var doc=rows[0];var menu=Convert.ToString(doc["kind"])=="GENERAL"?"48005":"48003";
        if(Convert.ToInt64(doc["owner"])!=user || !await Can(db,menu,"VIEW",token))return Forbid();
        var requests=await Query(db,"SELECT ChangeRequestID id,Reason reason,ImpactAssessment impactAssessment FROM dbo.TDDCChangeRequest WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND RequestType=N'WITHDRAW' AND StatusCode=N'DRAFT'",token,("@company",company),("@id",id),("@revision",doc["revisionId"]));
        return Ok(requests.FirstOrDefault() ?? new Dictionary<string,object?>());
    }

    [HttpPost("documents/{id:long}/withdrawal-request")]
    public async Task<IActionResult> SaveWithdrawalRequest(long id,WithdrawalDraftRequest request,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();
        if(Clean(request.Reason) is null || request.Reason.Trim().Length>2000 || (request.ImpactAssessment?.Trim().Length??0)>2000)return Bad("ข้อมูลคำขอไม่ถูกต้อง","ระบุเหตุผล และข้อความแต่ละช่องต้องไม่เกิน 2,000 ตัวอักษร");
        await using var db=await Open(token);var kind=await Scalar<string>(db,"SELECT DocumentClass FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@id AND IsActive=1",token,("@company",company),("@id",id));
        if(kind is not ("GENERAL" or "CONTROLLED"))return NotFound();var menu=kind=="GENERAL"?"48005":"48003";if(!await Can(db,menu,"EDIT",token))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        var rows=await Query(db,tx,"SELECT OwnerUserID owner,DocumentClass kind,StatusCode status,CurrentRevisionID revisionId FROM dbo.TDDCDocument WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND DocumentID=@id AND IsActive=1",token,("@company",company),("@id",id));
        if(rows.Count==0){await tx.RollbackAsync(token);return NotFound();}var doc=rows[0];
        if(Convert.ToString(doc["kind"])!=kind || Convert.ToInt64(doc["owner"])!=user){await tx.RollbackAsync(token);return Forbid();}
        if(Convert.ToString(doc["status"]) is not ("EFFECTIVE" or "PUBLISHED") || doc["revisionId"] is null){await tx.RollbackAsync(token);return Conflict(new{message="สร้างคำขอยกเลิกไม่ได้",description="เอกสารต้องมีฉบับที่ใช้งานอยู่"});}
        var revision=Convert.ToInt64(doc["revisionId"]);
        var requestId=await Scalar<long>(db,tx,"SELECT ChangeRequestID FROM dbo.TDDCChangeRequest WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND RequestType=N'WITHDRAW' AND StatusCode=N'DRAFT'",token,("@company",company),("@id",id),("@revision",revision));
        if(requestId==0) requestId=await Scalar<long>(db,tx,"INSERT dbo.TDDCChangeRequest(CompanyID,DocumentID,RevisionID,RequestType,StatusCode,RequesterUserID,Reason,ImpactAssessment) OUTPUT INSERTED.ChangeRequestID VALUES(@company,@id,@revision,N'WITHDRAW',N'DRAFT',@user,@reason,@impact)",token,("@company",company),("@id",id),("@revision",revision),("@user",user),("@reason",Clean(request.Reason)),("@impact",Clean(request.ImpactAssessment)));
        else await Execute(db,tx,"UPDATE dbo.TDDCChangeRequest SET Reason=@reason,ImpactAssessment=@impact,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ChangeRequestID=@request AND StatusCode=N'DRAFT'",token,("@reason",Clean(request.Reason)),("@impact",Clean(request.ImpactAssessment)),("@company",company),("@request",requestId));
        await Audit(db,tx,company,id,revision,"SAVE_WITHDRAWAL_DRAFT",null,user,token);await tx.CommitAsync(token);return Ok(new{id=requestId});
    }
    [HttpPut("documents/{id:long}")]
    public Task<IActionResult> Document(long id,DocumentRequest request,CancellationToken token)=>SaveDocument(id,request,token);

    async Task<IActionResult> SaveDocument(long? id,DocumentRequest request,CancellationToken token)
    {
        var kind=Clean(request.DocumentClass)?.ToUpperInvariant(); var menu=kind=="GENERAL"?"48005":"48003"; var action=id is null?"CREATE":"EDIT";
        if(kind is not ("CONTROLLED" or "GENERAL")||Clean(request.DocumentNo) is null||Clean(request.Title) is null||Clean(request.RevisionNo) is null||request.DocumentTypeId<=0||request.DepartmentIds is null||request.UserIds is null||request.AudienceMode is not ("ALL" or "RESTRICTED")) return Bad("ข้อมูลเอกสารไม่ครบ","ระบุเลขที่ ชื่อ ประเภท Revision และสิทธิ์ผู้ใช้งาน");
        if((request.ChangeReason?.Trim().Length??0)>2000 || (request.ImpactAssessment?.Trim().Length??0)>2000)return Bad("ข้อมูลยาวเกินกำหนด","เหตุผลและผลกระทบต้องไม่เกิน 2,000 ตัวอักษรต่อช่อง");
        if(!Scope(out var company,out var user)) return Forbid(); await using var db=await Open(token); if(!await Can(db,menu,action,token)) return Forbid();
        var refControlled=await Can(db,"48003","VIEW",token);var refGeneral=await Can(db,"48005","VIEW",token);var refLibrary=await Can(db,"48006","VIEW",token);
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        try {
            var type=await Query(db,tx,"SELECT DocumentClass kind FROM dbo.TDDCDocumentType WHERE CompanyID=@company AND DocumentTypeID=@type AND IsActive=1",token,("@company",company),("@type",request.DocumentTypeId));
            if(type.Count==0||Convert.ToString(type[0]["kind"])!=kind){await tx.RollbackAsync(token);return Bad("ประเภทเอกสารไม่ตรง","เลือกประเภทให้ตรงกับกลุ่มเอกสาร");}
            if(request.OwnerDepartmentId is long ownerDepartmentId && await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND OrgUnitID=@department AND UnitType IN(N'DEPARTMENT',N'DEP') AND IsActive=1",token,("@company",company),("@department",ownerDepartmentId))!=1){await tx.RollbackAsync(token);return Bad("แผนกไม่ถูกต้อง","เลือกแผนกที่ใช้งานในบริษัทเดียวกัน");}
            if(request.AudienceMode=="RESTRICTED" && request.DepartmentIds.Count==0 && request.UserIds.Count==0){await tx.RollbackAsync(token);return Bad("ขอบเขตไม่ถูกต้อง","เลือกแผนกหรือบุคคลอย่างน้อยหนึ่งรายการ");}
            foreach(var departmentId in request.DepartmentIds.Distinct()) if(await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND OrgUnitID=@department AND UnitType IN(N'DEPARTMENT',N'DEP') AND IsActive=1",token,("@company",company),("@department",departmentId))!=1){await tx.RollbackAsync(token);return Bad("แผนกไม่ถูกต้อง","เลือกแผนกที่ใช้งานในบริษัทเดียวกัน");}
            foreach(var targetUser in request.UserIds.Distinct()) if(await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@target AND IsActive=1",token,("@company",company),("@target",targetUser))!=1){await tx.RollbackAsync(token);return Bad("ผู้ใช้งานไม่ถูกต้อง","เลือกผู้ใช้งานในบริษัทเดียวกัน");}
            foreach(var assignee in new long?[]{request.ReviewerUserId,request.ApproverUserId}.Where(x=>x.HasValue).Select(x=>x!.Value).Distinct()) if(await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@target AND IsActive=1",token,("@company",company),("@target",assignee))!=1){await tx.RollbackAsync(token);return Bad("ผู้ตรวจทานหรือผู้อนุมัติไม่ถูกต้อง","เลือกผู้ใช้งานในบริษัทเดียวกัน");}
            long documentId; long revisionId;
            if(id is null){
                documentId=await Scalar<long>(db,tx,"INSERT dbo.TDDCDocument(CompanyID,DocumentTypeID,DocumentNo,DocumentTitle,DocumentClass,OwnerDepartmentID,OwnerUserID,StatusCode,AudienceMode,RequireAcknowledgement,PublishDate,ExpireDate,CreateBy) OUTPUT INSERTED.DocumentID VALUES(@company,@type,@no,@title,@kind,@department,@user,@status,@audience,@ack,@publish,@expire,@user)",token,("@company",company),("@type",request.DocumentTypeId),("@no",request.DocumentNo.Trim().ToUpperInvariant()),("@title",request.Title.Trim()),("@kind",kind),("@department",request.OwnerDepartmentId),("@user",user),("@status","DRAFT"),("@audience",request.AudienceMode),("@ack",request.RequireAcknowledgement),("@publish",null),("@expire",request.ExpireDate));
                revisionId=await Scalar<long>(db,tx,"INSERT dbo.TDDCRevision(CompanyID,DocumentID,RevisionNo,ChangeSummary,EffectiveDate,StatusCode,ReviewerUserID,ApproverUserID,CreateBy) OUTPUT INSERTED.RevisionID VALUES(@company,@document,@revision,@summary,@effective,@status,@reviewer,@approver,@user)",token,("@company",company),("@document",documentId),("@revision",request.RevisionNo.Trim().ToUpperInvariant()),("@summary",Clean(request.ChangeSummary)),("@effective",request.EffectiveDate?.Date),("@status","DRAFT"),("@reviewer",request.ReviewerUserId),("@approver",request.ApproverUserId),("@user",user));
                await Execute(db,tx,"UPDATE dbo.TDDCDocument SET CurrentRevisionID=@revision WHERE CompanyID=@company AND DocumentID=@document",token,("@revision",revisionId),("@company",company),("@document",documentId));
                await Execute(db,tx,"INSERT dbo.TDDCChangeRequest(CompanyID,DocumentID,RevisionID,RequestType,StatusCode,RequesterUserID,Reason,ImpactAssessment) VALUES(@company,@document,@revision,N'NEW',N'DRAFT',@user,@reason,@impact)",token,("@company",company),("@document",documentId),("@revision",revisionId),("@user",user),("@reason",Clean(request.ChangeReason)),("@impact",Clean(request.ImpactAssessment)));
            } else {
                documentId=id.Value;
                var current=await Query(db,tx,"SELECT CurrentRevisionID revisionId,StatusCode status,OwnerUserID owner FROM dbo.TDDCDocument WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND DocumentID=@document AND DocumentClass=@kind AND IsActive=1",token,("@company",company),("@document",documentId),("@kind",kind));
                if(current.Count==0){await tx.RollbackAsync(token);return NotFound();}
                if(Convert.ToInt64(current[0]["owner"])!=user){await tx.RollbackAsync(token);return Forbid();}
                if(Convert.ToString(current[0]["status"]) is not ("DRAFT" or "RETURNED")){await tx.RollbackAsync(token);return Conflict(new{message="แก้ไขเอกสารไม่ได้",description="แก้ไขได้เฉพาะสถานะร่างหรือส่งกลับ"});}
                revisionId=Convert.ToInt64(current[0]["revisionId"]);
                await Execute(db,tx,"UPDATE dbo.TDDCDocument SET DocumentTypeID=@type,DocumentNo=@no,DocumentTitle=@title,OwnerDepartmentID=@department,AudienceMode=@audience,RequireAcknowledgement=@ack,PublishDate=@publish,ExpireDate=@expire,StatusCode=CASE WHEN StatusCode=N'RETURNED' THEN N'DRAFT' ELSE StatusCode END,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@document",token,("@type",request.DocumentTypeId),("@no",request.DocumentNo.Trim().ToUpperInvariant()),("@title",request.Title.Trim()),("@department",request.OwnerDepartmentId),("@audience",request.AudienceMode),("@ack",request.RequireAcknowledgement),("@publish",request.PublishDate),("@expire",request.ExpireDate),("@user",user),("@company",company),("@document",documentId));
                await Execute(db,tx,"UPDATE dbo.TDDCRevision SET RevisionNo=@revision,ChangeSummary=@summary,EffectiveDate=@effective,ReviewerUserID=@reviewer,ApproverUserID=@approver,StatusCode=CASE WHEN StatusCode=N'RETURNED' THEN N'DRAFT' ELSE StatusCode END,ReturnedReason=NULL,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND RevisionID=@revisionId",token,("@revision",request.RevisionNo.Trim().ToUpperInvariant()),("@summary",Clean(request.ChangeSummary)),("@effective",request.EffectiveDate?.Date),("@reviewer",request.ReviewerUserId),("@approver",request.ApproverUserId),("@user",user),("@company",company),("@revisionId",revisionId));
            }
            if(request.ChangeReason is not null || request.ImpactAssessment is not null)
            {
                await Execute(db,tx,"UPDATE dbo.TDDCRevision SET ChangeReason=CASE WHEN @reasonSet=1 THEN @reason ELSE ChangeReason END,ImpactAssessment=CASE WHEN @impactSet=1 THEN @impact ELSE ImpactAssessment END WHERE CompanyID=@company AND DocumentID=@document AND RevisionID=@revision",token,("@reasonSet",request.ChangeReason is not null),("@reason",Clean(request.ChangeReason)),("@impactSet",request.ImpactAssessment is not null),("@impact",Clean(request.ImpactAssessment)),("@company",company),("@document",documentId),("@revision",revisionId));
                await Execute(db,tx,"UPDATE dbo.TDDCChangeRequest SET Reason=CASE WHEN @reasonSet=1 THEN @reason ELSE Reason END,ImpactAssessment=CASE WHEN @impactSet=1 THEN @impact ELSE ImpactAssessment END,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@document AND RevisionID=@revision AND StatusCode=N'DRAFT'",token,("@reasonSet",request.ChangeReason is not null),("@reason",Clean(request.ChangeReason)),("@impactSet",request.ImpactAssessment is not null),("@impact",Clean(request.ImpactAssessment)),("@company",company),("@document",documentId),("@revision",revisionId));
            }
            if(request.ReferenceDocumentNo is not null){
                var hasRequest=await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDDCChangeRequest WHERE CompanyID=@company AND DocumentID=@document AND RevisionID=@revision AND RequestType=N'NEW' AND StatusCode=N'DRAFT'",token,("@company",company),("@document",documentId),("@revision",revisionId));
                if(hasRequest>0 && !await SaveDraftReference(db,tx,company,documentId,revisionId,user,"NEW",request.ReferenceDocumentNo,refControlled,refGeneral,refLibrary,token)){await tx.RollbackAsync(token);return Bad("เอกสารอ้างอิงไม่ถูกต้อง","ไม่พบเอกสารหรือไม่มีสิทธิ์เข้าถึง");}
                if(hasRequest==0 && Clean(request.ReferenceDocumentNo) is not null){await tx.RollbackAsync(token);return Conflict(new{message="บันทึกเอกสารอ้างอิงไม่ได้",description="เอกสารเดิมไม่มีคำขอที่เชื่อมโยง กรุณาให้ผู้ดูแลตรวจสอบข้อมูลเดิม"});}
            }
            await Execute(db,tx,"DELETE dbo.TDDCAccessRule WHERE CompanyID=@company AND DocumentID=@document",token,("@company",company),("@document",documentId));
            if(request.AudienceMode=="ALL") await AddAccess(db,tx,company,documentId,"ALL",null,true,true,request.AllowDownload,user,token);
            else {
                foreach(var department in request.DepartmentIds.Distinct()) await AddAccess(db,tx,company,documentId,"DEPARTMENT",department,true,true,request.AllowDownload,user,token);
                foreach(var targetUser in request.UserIds.Distinct()) await AddAccess(db,tx,company,documentId,"USER",targetUser,true,true,request.AllowDownload,user,token);
            }
            await Audit(db,tx,company,documentId,revisionId,id is null?"CREATE":"EDIT",null,user,token);
            await tx.CommitAsync(token); return Ok(new{id=documentId,revisionId});
        } catch(SqlException e) when(e.Number is 2601 or 2627) { await tx.RollbackAsync(token); return Conflict(new{message="เลขที่เอกสารหรือ Revision ซ้ำ",description="เลขที่เอกสารต้องไม่ซ้ำในบริษัท และ Revision ต้องไม่ซ้ำในเอกสารเดียวกัน"}); }
    }

    [HttpDelete("documents/{id:long}")]
    public async Task<IActionResult> DeleteDocument(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user)) return Forbid(); await using var db=await Open(token);
        var item=(await Query(db,"SELECT DocumentClass kind,StatusCode status,OwnerUserID owner FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@id AND IsActive=1",token,("@company",company),("@id",id))).FirstOrDefault();
        if(item is null)return NotFound(); var menu=Convert.ToString(item["kind"])=="GENERAL"?"48005":"48003"; if(Convert.ToInt64(item["owner"])!=user || !await Can(db,menu,"DELETE",token))return Forbid();
        if(Convert.ToString(item["status"])!="DRAFT")return Conflict(new{message="ลบเอกสารไม่ได้",description="เอกสารที่เข้าสู่ Workflow หรือเผยแพร่แล้วต้องเก็บประวัติ"});
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        var changed=await Execute(db,tx,"UPDATE dbo.TDDCDocument SET IsActive=0,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id AND IsActive=1 AND StatusCode=N'DRAFT'",token,("@company",company),("@id",id),("@user",user));
        if(changed!=1){await tx.RollbackAsync(token);return Conflict(new{message="ลบเอกสารไม่ได้",description="สถานะเอกสารเปลี่ยนแล้ว กรุณาโหลดข้อมูลใหม่"});}
        await Execute(db,tx,"UPDATE dbo.TDDCChangeRequest SET StatusCode=N'CANCELLED',UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id AND StatusCode=N'DRAFT'",token,("@company",company),("@id",id));
        await Audit(db,tx,company,id,null,"DELETE",null,user,token); await tx.CommitAsync(token);
        return NoContent();
    }

    [HttpPost("documents/{id:long}/files")]
    [RequestSizeLimit(104857600)]
    public async Task<IActionResult> Upload(long id,[FromForm] FileUploadRequest request,CancellationToken token=default)
    {
        var file=request.File;
        var fileRole=request.FileRole;
        fileRole=fileRole.Trim().ToUpperInvariant(); if(file.Length<=0||fileRole is not ("PRIMARY" or "ATTACHMENT"))return Bad("ไฟล์ไม่ถูกต้อง","เลือกไฟล์และประเภทไฟล์ให้ถูกต้อง");
        if(!Scope(out var company,out var user))return Forbid(); await using var db=await Open(token);
        var doc=(await Query(db,"SELECT d.CurrentRevisionID revisionId,d.DocumentClass kind,d.StatusCode status,d.OwnerUserID owner FROM dbo.TDDCDocument d WHERE d.CompanyID=@company AND d.DocumentID=@id AND d.IsActive=1",token,("@company",company),("@id",id))).FirstOrDefault();
        if(doc is null)return NotFound(); var menu=Convert.ToString(doc["kind"])=="GENERAL"?"48005":"48003"; if(Convert.ToInt64(doc["owner"])!=user || !(await Can(db,menu,"EDIT",token) || Convert.ToString(doc["status"])=="DRAFT" && await Can(db,menu,"CREATE",token)))return Forbid();
        var revision=request.RevisionId ?? Convert.ToInt64(doc["revisionId"]);
        if(request.RevisionId is null && Convert.ToString(doc["status"]) is not ("DRAFT" or "RETURNED"))return Conflict(new{message="แนบไฟล์ไม่ได้",description="เอกสารอยู่ระหว่าง Workflow หรือมีผลบังคับใช้แล้ว"});
        if(request.RevisionId is not null && await Scalar<int>(db,"SELECT COUNT(*) FROM dbo.TDDCRevision r JOIN dbo.TDDCDocument d ON d.CompanyID=r.CompanyID AND d.DocumentID=r.DocumentID WHERE r.CompanyID=@company AND r.DocumentID=@id AND r.RevisionID=@revision AND r.StatusCode=N'DRAFT' AND r.BasedOnRevisionID=d.CurrentRevisionID AND d.IsActive=1",token,("@company",company),("@id",id),("@revision",revision))!=1)return Conflict(new{message="แนบไฟล์ไม่ได้",description="ไม่พบร่าง Revision ที่อ้างอิงฉบับปัจจุบัน"});
        await EnsureSettings(db,company,token); var setting=(await Query(db,"SELECT MaxPrimaryFileMB primaryMb,MaxAttachmentFileMB attachmentMb,AllowedAttachmentExtensions extensions FROM dbo.TDDCSystemSetting WHERE CompanyID=@company",token,("@company",company))).Single();
        var extension=Path.GetExtension(file.FileName).TrimStart('.').ToLowerInvariant(); var max=Convert.ToInt32(setting[fileRole=="PRIMARY"?"primaryMb":"attachmentMb"]);
        if(fileRole=="PRIMARY"&&extension!="pdf")return Bad("ไฟล์หลักต้องเป็น PDF","ไฟล์ Office สามารถแนบเป็นเอกสารประกอบได้");
        var allowed=Convert.ToString(setting["extensions"])!.Split(',',StringSplitOptions.RemoveEmptyEntries|StringSplitOptions.TrimEntries);
        if(fileRole=="ATTACHMENT"&&!allowed.Contains(extension,StringComparer.OrdinalIgnoreCase))return Bad("ชนิดไฟล์ไม่ได้รับอนุญาต","ตรวจชนิดไฟล์ที่ตั้งค่าระบบ");
        if(file.Length>max*1024L*1024L)return Bad("ไฟล์มีขนาดใหญ่เกินกำหนด",$"ไฟล์ต้องไม่เกิน {max} MB");
        var folder=Path.Combine(environment.WebRootPath??Path.Combine(environment.ContentRootPath,"wwwroot"),"uploads","document-control",company.ToString(),id.ToString(),revision.ToString());
        Directory.CreateDirectory(folder); var stored=$"{Guid.NewGuid():N}.{extension}"; var full=Path.Combine(folder,stored);
        try {
        await using(var output=System.IO.File.Create(full))await file.CopyToAsync(output,token);
        string hash; await using(var input=System.IO.File.OpenRead(full)) hash=Convert.ToHexString(await SHA256.HashDataAsync(input,token)); var relative=$"uploads/document-control/{company}/{id}/{revision}/{stored}";
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        var allowedDraft=await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDDCDocument d WITH(UPDLOCK,HOLDLOCK) JOIN dbo.TDDCRevision r WITH(UPDLOCK,HOLDLOCK) ON r.CompanyID=d.CompanyID AND r.DocumentID=d.DocumentID WHERE d.CompanyID=@company AND d.DocumentID=@id AND d.IsActive=1 AND r.RevisionID=@revision AND ((@separate=0 AND d.CurrentRevisionID=r.RevisionID AND d.StatusCode IN(N'DRAFT',N'RETURNED') AND r.StatusCode IN(N'DRAFT',N'RETURNED')) OR (@separate=1 AND r.StatusCode=N'DRAFT' AND r.BasedOnRevisionID=d.CurrentRevisionID))",token,("@company",company),("@id",id),("@revision",revision),("@separate",request.RevisionId is not null));
        if(allowedDraft!=1){await tx.RollbackAsync(token);System.IO.File.Delete(full);return Conflict(new{message="แนบไฟล์ไม่ได้",description="สถานะร่างหรือฉบับต้นทางเปลี่ยนแล้ว"});}
        if(fileRole=="PRIMARY")await Execute(db,tx,"DELETE dbo.TDDCFile WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND FileRole=N'PRIMARY'",token,("@company",company),("@id",id),("@revision",revision));
        var fileId=await Scalar<long>(db,tx,"INSERT dbo.TDDCFile(CompanyID,DocumentID,RevisionID,FileRole,OriginalFileName,StoredFileName,RelativePath,ContentType,FileSizeBytes,Sha256,CreateBy) OUTPUT INSERTED.DocumentFileID VALUES(@company,@id,@revision,@role,@original,@stored,@path,@content,@size,@hash,@user)",token,("@company",company),("@id",id),("@revision",revision),("@role",fileRole),("@original",Path.GetFileName(file.FileName)),("@stored",stored),("@path",relative),("@content",file.ContentType??"application/octet-stream"),("@size",file.Length),("@hash",hash),("@user",user));
        await Audit(db,tx,company,id,revision,"UPLOAD",$"{fileRole}:{file.FileName}",user,token); await tx.CommitAsync(token); return Ok(new{id=fileId,fileName=file.FileName,sizeBytes=file.Length});
        } catch { if(System.IO.File.Exists(full))System.IO.File.Delete(full); throw; }
    }

    [HttpPost("documents/{id:long}/submit")]
    public async Task<IActionResult> Submit(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid(); await using var db=await Open(token); if(!await Can(db,"48003","SUBMIT",token))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        var rows=await Query(db,tx,"SELECT d.OwnerUserID owner,d.CurrentRevisionID revisionId,d.StatusCode documentStatus,r.StatusCode revisionStatus,r.ReviewerUserID reviewer,r.ApproverUserID approver FROM dbo.TDDCDocument d WITH(UPDLOCK,HOLDLOCK) JOIN dbo.TDDCRevision r WITH(UPDLOCK,HOLDLOCK) ON r.CompanyID=d.CompanyID AND r.DocumentID=d.DocumentID AND r.RevisionID=d.CurrentRevisionID WHERE d.CompanyID=@company AND d.DocumentID=@id AND d.DocumentClass=N'CONTROLLED' AND d.IsActive=1",token,("@company",company),("@id",id));
        if(rows.Count==0){await tx.RollbackAsync(token);return NotFound();}var current=rows[0];
        if(Convert.ToInt64(current["owner"])!=user){await tx.RollbackAsync(token);return Forbid();}
        var revision=Convert.ToInt64(current["revisionId"]);
        if(Convert.ToString(current["documentStatus"]) is not ("DRAFT" or "RETURNED") || Convert.ToString(current["revisionStatus"]) is not ("DRAFT" or "RETURNED") || current["reviewer"] is null || current["approver"] is null || await Scalar<int>(db,tx,"SELECT COUNT(*) FROM dbo.TDDCFile WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND FileRole=N'PRIMARY'",token,("@company",company),("@id",id),("@revision",revision))==0){await tx.RollbackAsync(token);return Conflict(new{message="ส่งตรวจทานไม่ได้",description="ต้องมีผู้ตรวจทาน ผู้อนุมัติ และไฟล์หลัก PDF ในแบบร่าง"});}
        var changed=await Execute(db,tx,"UPDATE dbo.TDDCDocument SET StatusCode=N'IN_REVIEW',UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id AND StatusCode IN(N'DRAFT',N'RETURNED'); UPDATE dbo.TDDCRevision SET StatusCode=N'IN_REVIEW',UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND StatusCode IN(N'DRAFT',N'RETURNED')",token,("@company",company),("@id",id),("@revision",revision),("@user",user));
        if(changed!=2){await tx.RollbackAsync(token);return Conflict();}
        await Execute(db,tx,"UPDATE dbo.TDDCChangeRequest SET StatusCode=N'SUBMITTED',UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND StatusCode=N'DRAFT'",token,("@company",company),("@id",id),("@revision",revision));
        await Audit(db,tx,company,id,revision,"SUBMIT",null,user,token); await tx.CommitAsync(token); return NoContent();
    }

    [HttpGet("approval-tasks")]
    public async Task<IActionResult> ApprovalTasks(CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid(); await using var db=await Open(token); if(!await Can(db,"48004","VIEW",token))return Forbid();
        return Ok(await Query(db,"SELECT d.DocumentID id,d.DocumentNo documentNo,d.DocumentTitle title,t.TypeName typeName,r.RevisionNo revisionNo,d.StatusCode status,CASE WHEN d.StatusCode=N'IN_REVIEW' THEN N'REVIEW' ELSE N'APPROVE' END taskType,d.CreateDate FROM dbo.TDDCDocument d JOIN dbo.TDDCRevision r ON r.RevisionID=d.CurrentRevisionID JOIN dbo.TDDCDocumentType t ON t.DocumentTypeID=d.DocumentTypeID WHERE d.CompanyID=@company AND ((d.StatusCode=N'IN_REVIEW' AND r.ReviewerUserID=@user) OR (d.StatusCode=N'IN_APPROVAL' AND r.ApproverUserID=@user)) ORDER BY d.CreateDate",token,("@company",company),("@user",user)));
    }

    [HttpPost("documents/{id:long}/workflow/{workflowAction}")]
    public async Task<IActionResult> Workflow(long id,string workflowAction,[FromBody] WorkflowRequest request,CancellationToken token)
    {
        var action=workflowAction.Trim().ToUpperInvariant(); if(action is not ("REVIEW" or "APPROVE" or "RETURN"))return NotFound();
        if(!Scope(out var company,out var user))return Forbid(); await using var db=await Open(token); if(!await Can(db,"48004",action,token))return Forbid();
        var row=(await Query(db,"SELECT d.CurrentRevisionID revisionId,d.StatusCode status,r.ReviewerUserID reviewer,r.ApproverUserID approver,r.EffectiveDate FROM dbo.TDDCDocument d JOIN dbo.TDDCRevision r ON r.RevisionID=d.CurrentRevisionID WHERE d.CompanyID=@company AND d.DocumentID=@id",token,("@company",company),("@id",id))).FirstOrDefault(); if(row is null)return NotFound();
        var status=Convert.ToString(row["status"]); if(action=="REVIEW"&&(status!="IN_REVIEW"||Convert.ToInt64(row["reviewer"])!=user)||action=="APPROVE"&&(status!="IN_APPROVAL"||Convert.ToInt64(row["approver"])!=user)||action=="RETURN"&&status is not ("IN_REVIEW" or "IN_APPROVAL"))return Conflict(new{message="ดำเนินการไม่ได้",description="สถานะหรือผู้รับผิดชอบไม่ตรงกับงาน"});
        var revision=Convert.ToInt64(row["revisionId"]); await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        if(action=="REVIEW"){await Execute(db,tx,"UPDATE dbo.TDDCDocument SET StatusCode=N'IN_APPROVAL',UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id; UPDATE dbo.TDDCRevision SET StatusCode=N'IN_APPROVAL',ReviewedBy=@user,ReviewedDate=SYSUTCDATETIME(),UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND RevisionID=@revision",token,("@company",company),("@id",id),("@revision",revision),("@user",user));}
        else if(action=="APPROVE"){var effective=row["effectiveDate"] is null||Convert.ToDateTime(row["effectiveDate"]).Date<=DateTime.UtcNow.Date;var next=effective?"EFFECTIVE":"APPROVED";if(effective)await Execute(db,tx,"UPDATE r SET r.StatusCode=N'OBSOLETE',r.UpdateBy=@user,r.UpdateDate=SYSUTCDATETIME() FROM dbo.TDDCRevision r WHERE r.CompanyID=@company AND r.DocumentID=@id AND r.RevisionID<>@revision AND r.StatusCode=N'EFFECTIVE'",token,("@company",company),("@id",id),("@revision",revision),("@user",user));await Execute(db,tx,"UPDATE dbo.TDDCDocument SET StatusCode=@next,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id; UPDATE dbo.TDDCRevision SET StatusCode=@next,ApprovedBy=@user,ApprovedDate=SYSUTCDATETIME(),UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND RevisionID=@revision",token,("@next",next),("@company",company),("@id",id),("@revision",revision),("@user",user));}
        else {if(string.IsNullOrWhiteSpace(request.Note)){await tx.RollbackAsync(token);return Bad("กรุณาระบุเหตุผล","การส่งกลับต้องมีเหตุผล");}await Execute(db,tx,"UPDATE dbo.TDDCDocument SET StatusCode=N'RETURNED',UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id; UPDATE dbo.TDDCRevision SET StatusCode=N'RETURNED',ReturnedReason=@note,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND RevisionID=@revision",token,("@note",request.Note.Trim()),("@company",company),("@id",id),("@revision",revision),("@user",user));}
        if(action is "APPROVE" or "RETURN")await Execute(db,tx,"UPDATE dbo.TDDCChangeRequest SET StatusCode=@status,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND StatusCode=N'SUBMITTED'",token,("@status",action=="APPROVE"?"COMPLETED":"DRAFT"),("@company",company),("@id",id),("@revision",revision));
        await Audit(db,tx,company,id,revision,action,Clean(request.Note),user,token); await tx.CommitAsync(token); return NoContent();
    }

    [HttpGet("library")]
    public async Task<IActionResult> Library(string? search,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid(); await using var db=await Open(token); if(!await Can(db,"48006","VIEW",token))return Forbid(); await ActivateDue(db,company,token);
        return Ok(await Query(db,AudienceSql("SELECT d.DocumentID id,d.DocumentNo documentNo,d.DocumentTitle title,t.TypeName typeName,d.DocumentClass documentClass,d.StatusCode status,r.RevisionNo revisionNo,r.EffectiveDate,d.PublishDate,d.ExpireDate,d.RequireAcknowledgement requireAcknowledgement"),token,("@company",company),("@user",user),("@search",Clean(search))));
    }

    [HttpGet("acknowledgements")]
    public async Task<IActionResult> Acknowledgements(CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid(); await using var db=await Open(token); if(!await Can(db,"48007","VIEW",token))return Forbid();
        return Ok(await Query(db,AudienceSql("SELECT d.DocumentID id,d.DocumentNo documentNo,d.DocumentTitle title,r.RevisionNo revisionNo,a.AcknowledgedDate acknowledgedDate",true),token,("@company",company),("@user",user),("@search",null)));
    }

    [HttpPost("documents/{id:long}/acknowledge")]
    public async Task<IActionResult> Acknowledge(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid(); await using var db=await Open(token); if(!await Can(db,"48007","ACKNOWLEDGE",token)||!await HasAudience(db,company,id,user,"VIEW",token))return Forbid();
        var revision=await Scalar<long>(db,"SELECT CurrentRevisionID FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@id AND RequireAcknowledgement=1 AND StatusCode IN(N'EFFECTIVE',N'PUBLISHED')",token,("@company",company),("@id",id));if(revision<=0)return NotFound();
        await Execute(db,"IF NOT EXISTS(SELECT 1 FROM dbo.TDDCAcknowledgement WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND UserID=@user) INSERT dbo.TDDCAcknowledgement(CompanyID,DocumentID,RevisionID,UserID,AcknowledgedDate,IpAddress) VALUES(@company,@id,@revision,@user,SYSUTCDATETIME(),@ip) ELSE UPDATE dbo.TDDCAcknowledgement SET AcknowledgedDate=SYSUTCDATETIME(),IpAddress=@ip WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND UserID=@user",token,("@company",company),("@id",id),("@revision",revision),("@user",user),("@ip",HttpContext.Connection.RemoteIpAddress?.ToString()));return NoContent();
    }

    [HttpGet("files/{fileId:long}/{mode}")]
    public async Task<IActionResult> File(long fileId,string mode,CancellationToken token)
    {
        mode=mode.Trim().ToUpperInvariant(); if(mode is not ("PREVIEW" or "DOWNLOAD")||!Scope(out var company,out var user))return Forbid(); await using var db=await Open(token);
        var file=(await Query(db,"SELECT f.DocumentID documentId,f.RelativePath path,f.OriginalFileName fileName,f.ContentType contentType,d.DocumentClass kind,d.StatusCode status,d.OwnerUserID owner,f.RevisionID fileRevisionId,d.CurrentRevisionID currentRevisionId,r.ReviewerUserID reviewer,r.ApproverUserID approver FROM dbo.TDDCFile f JOIN dbo.TDDCDocument d ON d.CompanyID=f.CompanyID AND d.DocumentID=f.DocumentID LEFT JOIN dbo.TDDCRevision r ON r.CompanyID=d.CompanyID AND r.DocumentID=d.DocumentID AND r.RevisionID=f.RevisionID WHERE f.CompanyID=@company AND f.DocumentFileID=@file AND d.IsActive=1",token,("@company",company),("@file",fileId))).FirstOrDefault();if(file is null)return NotFound();
        var document=Convert.ToInt64(file["documentId"]); var published=Convert.ToString(file["status"]) is "EFFECTIVE" or "PUBLISHED"; var menu=Convert.ToString(file["kind"])=="GENERAL"?"48005":"48003";
        var owner=Convert.ToInt64(file["owner"])==user;
        var assigned=(file["reviewer"] is not null && Convert.ToInt64(file["reviewer"])==user)||(file["approver"] is not null && Convert.ToInt64(file["approver"])==user);
        var currentFile=file["fileRevisionId"] is not null && file["currentRevisionId"] is not null && Convert.ToInt64(file["fileRevisionId"])==Convert.ToInt64(file["currentRevisionId"]);
        var allowed=published && currentFile && await HasAudience(db,company,document,user,mode,token) && (await Can(db,"48006",mode,token)||await Can(db,menu,mode,token)) || owner && await Can(db,menu,mode,token) || assigned && await Can(db,"48004",mode,token);
        if(!allowed)return Forbid();
        var full=SafePhysical(Convert.ToString(file["path"])!);if(!System.IO.File.Exists(full))return NotFound();
        await Execute(db,"INSERT dbo.TDDCAudit(CompanyID,DocumentID,ActionCode,DetailText,UserID,IpAddress) VALUES(@company,@document,@action,@file,@user,@ip)",token,("@company",company),("@document",document),("@action",mode),("@file",file["fileName"]),("@user",user),("@ip",HttpContext.Connection.RemoteIpAddress?.ToString()));
        return PhysicalFile(full,Convert.ToString(file["contentType"])??"application/octet-stream",mode=="DOWNLOAD"?Convert.ToString(file["fileName"]):null,enableRangeProcessing:true);
    }

    [HttpGet("reports")]
    public async Task<IActionResult> Reports(CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Can(db,"48008","VIEW",token))return Forbid();
        var summary=(await Query(db,"SELECT COUNT(*) total,SUM(CASE WHEN StatusCode=N'EFFECTIVE' THEN 1 ELSE 0 END) effective,SUM(CASE WHEN StatusCode=N'PUBLISHED' THEN 1 ELSE 0 END) published,SUM(CASE WHEN StatusCode IN(N'IN_REVIEW',N'IN_APPROVAL') THEN 1 ELSE 0 END) pending,SUM(CASE WHEN ExpireDate IS NOT NULL AND ExpireDate<DATEADD(day,30,SYSUTCDATETIME()) THEN 1 ELSE 0 END) expiring FROM dbo.TDDCDocument WHERE CompanyID=@company AND IsActive=1",token,("@company",company))).Single();
        var byType=await Query(db,"SELECT t.TypeName label,COUNT(*) value FROM dbo.TDDCDocument d JOIN dbo.TDDCDocumentType t ON t.DocumentTypeID=d.DocumentTypeID WHERE d.CompanyID=@company AND d.IsActive=1 GROUP BY t.TypeName ORDER BY value DESC",token,("@company",company));
        var audit=await Query(db,"SELECT TOP(100) a.AuditID id,d.DocumentNo documentNo,a.ActionCode action,a.DetailText detail,a.UserID userId,a.ActionDate actionDate FROM dbo.TDDCAudit a LEFT JOIN dbo.TDDCDocument d ON d.CompanyID=a.CompanyID AND d.DocumentID=a.DocumentID WHERE a.CompanyID=@company ORDER BY a.ActionDate DESC",token,("@company",company)); return Ok(new{summary,byType,audit});
    }

    async Task<bool> SaveDraftReference(SqlConnection db,SqlTransaction tx,long company,long document,long revision,long user,string requestType,string? number,bool controlled,bool general,bool library,CancellationToken token)
    {
        var requestId=await Scalar<long>(db,tx,"SELECT ChangeRequestID FROM dbo.TDDCChangeRequest WHERE CompanyID=@company AND DocumentID=@document AND RevisionID=@revision AND RequestType=@type AND StatusCode=N'DRAFT'",token,("@company",company),("@document",document),("@revision",revision),("@type",requestType));
        if(requestId<=0)return number is null;
        var numbers=(number??string.Empty).Split(',',StringSplitOptions.RemoveEmptyEntries|StringSplitOptions.TrimEntries).Select(x=>x.ToUpperInvariant()).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        var relatedIds=new List<long>();
        foreach(var reference in numbers){
            var related=await Scalar<long>(db,tx,@"SELECT d.DocumentID FROM dbo.TDDCDocument d WHERE d.CompanyID=@company AND d.DocumentNo=@number AND d.IsActive=1 AND d.CurrentRevisionID IS NOT NULL AND ((d.OwnerUserID=@user AND ((d.DocumentClass=N'CONTROLLED' AND @controlled=1) OR (d.DocumentClass=N'GENERAL' AND @general=1))) OR (d.StatusCode IN(N'EFFECTIVE',N'PUBLISHED') AND (@library=1 OR (d.DocumentClass=N'CONTROLLED' AND @controlled=1) OR (d.DocumentClass=N'GENERAL' AND @general=1)) AND EXISTS(SELECT 1 FROM dbo.TDDCAccessRule x WHERE x.CompanyID=d.CompanyID AND x.DocumentID=d.DocumentID AND x.CanView=1 AND (x.SubjectType=N'ALL' OR x.SubjectType=N'USER' AND x.SubjectID=@user OR x.SubjectType=N'DEPARTMENT' AND x.SubjectID IN(SELECT e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1 AND e.IsActive=1)))))",token,("@company",company),("@number",reference),("@user",user),("@controlled",controlled),("@general",general),("@library",library));
            if(related<=0)return false;
            relatedIds.Add(related);
        }
        await Execute(db,tx,"DELETE dbo.TDDCChangeRequestReference WHERE ChangeRequestID=@request",token,("@request",requestId));
        foreach(var related in relatedIds)await Execute(db,tx,"INSERT dbo.TDDCChangeRequestReference(ChangeRequestID,RelatedDocumentID,RelatedRevisionID) SELECT @request,DocumentID,CurrentRevisionID FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@related AND IsActive=1",token,("@request",requestId),("@company",company),("@related",related));
        return true;
    }
    string AudienceSql(string select,bool acknowledgements=false)=>select+@" FROM dbo.TDDCDocument d JOIN dbo.TDDCDocumentType t ON t.DocumentTypeID=d.DocumentTypeID JOIN dbo.TDDCRevision r ON r.RevisionID=d.CurrentRevisionID LEFT JOIN dbo.TDDCAcknowledgement a ON a.CompanyID=d.CompanyID AND a.DocumentID=d.DocumentID AND a.RevisionID=d.CurrentRevisionID AND a.UserID=@user WHERE d.CompanyID=@company "+(acknowledgements?" AND d.RequireAcknowledgement=1 ":"")+@" AND d.StatusCode IN(N'EFFECTIVE',N'PUBLISHED') AND (d.ExpireDate IS NULL OR d.ExpireDate>=SYSUTCDATETIME()) AND (@search IS NULL OR d.DocumentNo LIKE N'%'+@search+N'%' OR d.DocumentTitle LIKE N'%'+@search+N'%') AND (d.AudienceMode=N'ALL' OR EXISTS(SELECT 1 FROM dbo.TDDCAccessRule x WHERE x.CompanyID=d.CompanyID AND x.DocumentID=d.DocumentID AND x.CanView=1 AND (x.SubjectType=N'ALL' OR x.SubjectType=N'USER' AND x.SubjectID=@user OR x.SubjectType=N'DEPARTMENT' AND x.SubjectID IN(SELECT e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1 AND e.IsActive=1)))) ORDER BY COALESCE(r.EffectiveDate,CONVERT(date,d.PublishDate)) DESC,d.DocumentNo";
    Task<bool> HasAudience(SqlConnection db,long company,long document,long user,string access,CancellationToken token){var column=access switch{"PREVIEW"=>"CanPreview","DOWNLOAD"=>"CanDownload",_=>"CanView"};return Scalar<bool>(db,$"SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDDCDocument d WHERE d.CompanyID=@company AND d.DocumentID=@document AND (d.OwnerUserID=@user OR EXISTS(SELECT 1 FROM dbo.TDDCAccessRule x WHERE x.CompanyID=d.CompanyID AND x.DocumentID=d.DocumentID AND x.{column}=1 AND (x.SubjectType=N'ALL' OR x.SubjectType=N'USER' AND x.SubjectID=@user OR x.SubjectType=N'DEPARTMENT' AND x.SubjectID IN(SELECT e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1 AND e.IsActive=1))))) THEN 1 ELSE 0 END",token,("@company",company),("@document",document),("@user",user));}
    async Task ActivateDue(SqlConnection db,long company,CancellationToken token)=>await Execute(db,@"UPDATE old SET old.StatusCode=N'OBSOLETE',old.UpdateDate=SYSUTCDATETIME() FROM dbo.TDDCRevision old JOIN dbo.TDDCRevision next ON next.CompanyID=old.CompanyID AND next.DocumentID=old.DocumentID AND next.StatusCode=N'APPROVED' AND next.EffectiveDate<=CONVERT(date,SYSUTCDATETIME()) WHERE old.CompanyID=@company AND old.StatusCode=N'EFFECTIVE'; UPDATE r SET r.StatusCode=N'EFFECTIVE',r.UpdateDate=SYSUTCDATETIME() FROM dbo.TDDCRevision r WHERE r.CompanyID=@company AND r.StatusCode=N'APPROVED' AND r.EffectiveDate<=CONVERT(date,SYSUTCDATETIME()); UPDATE d SET d.StatusCode=N'EFFECTIVE',d.UpdateDate=SYSUTCDATETIME() FROM dbo.TDDCDocument d JOIN dbo.TDDCRevision r ON r.RevisionID=d.CurrentRevisionID WHERE d.CompanyID=@company AND r.StatusCode=N'EFFECTIVE' AND d.StatusCode<>N'EFFECTIVE'",token,("@company",company));
    async Task AddAccess(SqlConnection db,SqlTransaction tx,long company,long document,string subject,long? id,bool view,bool preview,bool download,long user,CancellationToken token)=>await Execute(db,tx,"INSERT dbo.TDDCAccessRule(CompanyID,DocumentID,SubjectType,SubjectID,CanView,CanPreview,CanDownload,CreateBy) VALUES(@company,@document,@subject,@id,@view,@preview,@download,@user)",token,("@company",company),("@document",document),("@subject",subject),("@id",id),("@view",view),("@preview",preview),("@download",download),("@user",user));
    async Task Audit(SqlConnection db,SqlTransaction tx,long company,long document,long? revision,string action,string? detail,long user,CancellationToken token)=>await Execute(db,tx,"INSERT dbo.TDDCAudit(CompanyID,DocumentID,RevisionID,ActionCode,DetailText,UserID,IpAddress) VALUES(@company,@document,@revision,@action,@detail,@user,@ip)",token,("@company",company),("@document",document),("@revision",revision),("@action",action),("@detail",detail),("@user",user),("@ip",HttpContext.Connection.RemoteIpAddress?.ToString()));
    async Task EnsureSettings(SqlConnection db,long company,CancellationToken token)=>await Execute(db,"IF NOT EXISTS(SELECT 1 FROM dbo.TDDCSystemSetting WHERE CompanyID=@company) INSERT dbo.TDDCSystemSetting(CompanyID,CreateBy) VALUES(@company,0)",token,("@company",company));
    Task<bool> Can(SqlConnection db,string menu,string action,CancellationToken token)=>CompanyMenuAccess.IsAllowedAsync(db,User,menu,action,token);
    async Task<bool> AnyView(SqlConnection db,CancellationToken token){foreach(var menu in Menus)if(await Can(db,menu,"VIEW",token))return true;return false;}
    async Task<bool> AnyDocumentView(SqlConnection db,CancellationToken token)=>await Can(db,"48003","VIEW",token)||await Can(db,"48005","VIEW",token)||await Can(db,"48006","VIEW",token)||await Can(db,"48007","VIEW",token);
    bool Scope(out long company,out long user){company=0;user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}
    async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    string SafePhysical(string relative){var root=Path.GetFullPath(environment.WebRootPath??Path.Combine(environment.ContentRootPath,"wwwroot"));var full=Path.GetFullPath(Path.Combine(root,relative.Replace('/',Path.DirectorySeparatorChar)));if(!full.StartsWith(root,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Invalid file path.");return full;}
    static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
    BadRequestObjectResult Bad(string message,string description)=>BadRequest(new{message,description});
    static void Add(SqlCommand command,string name,object? value)=>command.Parameters.AddWithValue(name,value??DBNull.Value);
    static async Task<int> Execute(SqlConnection db,string sql,CancellationToken token,params(string,object?)[] args){await using var command=new SqlCommand(sql,db);foreach(var arg in args)Add(command,arg.Item1,arg.Item2);return await command.ExecuteNonQueryAsync(token);}
    static async Task<int> Execute(SqlConnection db,SqlTransaction tx,string sql,CancellationToken token,params(string,object?)[] args){await using var command=new SqlCommand(sql,db,tx);foreach(var arg in args)Add(command,arg.Item1,arg.Item2);return await command.ExecuteNonQueryAsync(token);}
    static async Task<T> Scalar<T>(SqlConnection db,string sql,CancellationToken token,params(string,object?)[] args){await using var command=new SqlCommand(sql,db);foreach(var arg in args)Add(command,arg.Item1,arg.Item2);var value=await command.ExecuteScalarAsync(token);return value is null||value==DBNull.Value?default!:(T)Convert.ChangeType(value,typeof(T));}
    static async Task<T> Scalar<T>(SqlConnection db,SqlTransaction tx,string sql,CancellationToken token,params(string,object?)[] args){await using var command=new SqlCommand(sql,db,tx);foreach(var arg in args)Add(command,arg.Item1,arg.Item2);var value=await command.ExecuteScalarAsync(token);return value is null||value==DBNull.Value?default!:(T)Convert.ChangeType(value,typeof(T));}
    static async Task<List<Dictionary<string,object?>>> Query(SqlConnection db,string sql,CancellationToken token,params(string,object?)[] args){await using var command=new SqlCommand(sql,db);foreach(var arg in args)Add(command,arg.Item1,arg.Item2);return await Read(command,token);}
    static async Task<List<Dictionary<string,object?>>> Query(SqlConnection db,SqlTransaction tx,string sql,CancellationToken token,params(string,object?)[] args){await using var command=new SqlCommand(sql,db,tx);foreach(var arg in args)Add(command,arg.Item1,arg.Item2);return await Read(command,token);}
    static async Task<List<Dictionary<string,object?>>> Read(SqlCommand command,CancellationToken token){await using var reader=await command.ExecuteReaderAsync(token);var rows=new List<Dictionary<string,object?>>();while(await reader.ReadAsync(token)){var row=new Dictionary<string,object?>();for(var i=0;i<reader.FieldCount;i++){var name=reader.GetName(i);row[char.ToLowerInvariant(name[0])+name[1..]]=reader.IsDBNull(i)?null:reader.GetValue(i);}rows.Add(row);}return rows;}
}

public sealed record SettingsRequest(int MaxPrimaryFileMb,int MaxAttachmentFileMb,string AllowedAttachmentExtensions,int ReminderDays);
public sealed record TypeRequest(string? Code,string Name,string DocumentClass,bool RequireAcknowledgement,long? DefaultReviewerUserId,long? DefaultApproverUserId,string DefaultAudienceMode,bool Active=true);
public sealed record DocumentRequest(long DocumentTypeId,string DocumentNo,string Title,string DocumentClass,long? OwnerDepartmentId,string RevisionNo,string? ChangeSummary,DateTime? EffectiveDate,long? ReviewerUserId,long? ApproverUserId,string AudienceMode,List<long> DepartmentIds,List<long> UserIds,bool AllowDownload,bool RequireAcknowledgement,DateTime? PublishDate,DateTime? ExpireDate,string? ChangeReason=null,string? ImpactAssessment=null,string? ReferenceDocumentNo=null);
public sealed record RevisionDraftRequest(string RevisionNo,string ChangeSummary,string? ChangeReason,string? ImpactAssessment,string? ReferenceDocumentNo=null);
public sealed record WithdrawalDraftRequest(string Reason,string? ImpactAssessment);
public sealed record WorkflowRequest(string? Note);
public sealed class FileUploadRequest
{
    public required IFormFile File { get; init; }
    public string FileRole { get; init; } = "ATTACHMENT";
    public long? RevisionId { get; init; }
}
