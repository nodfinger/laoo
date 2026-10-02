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
        var code=Clean(request.Code)?.ToUpperInvariant(); var name=Clean(request.Name); var kind=Clean(request.DocumentClass)?.ToUpperInvariant();
        if(code is null||name is null||kind is not ("CONTROLLED" or "GENERAL")||request.DefaultAudienceMode is not ("ALL" or "RESTRICTED")) return Bad("ข้อมูลประเภทเอกสารไม่ครบ","ระบุรหัส ชื่อ กลุ่มเอกสาร และผู้มีสิทธิ์เริ่มต้น");
        if(!Scope(out var company,out var user)) return Forbid();
        await using var db=await Open(token); if(!await Can(db,"48002",action,token)) return Forbid();
        try {
            var sql=id is null
                ?"INSERT dbo.TDDCDocumentType(CompanyID,TypeCode,TypeName,DocumentClass,RequireAcknowledgement,DefaultReviewerUserID,DefaultApproverUserID,DefaultAudienceMode,IsActive,CreateBy) OUTPUT INSERTED.DocumentTypeID VALUES(@company,@code,@name,@kind,@ack,@reviewer,@approver,@audience,@active,@user)"
                :"UPDATE dbo.TDDCDocumentType SET TypeCode=@code,TypeName=@name,DocumentClass=@kind,RequireAcknowledgement=@ack,DefaultReviewerUserID=@reviewer,DefaultApproverUserID=@approver,DefaultAudienceMode=@audience,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.DocumentTypeID WHERE CompanyID=@company AND DocumentTypeID=@id";
            var saved=await Scalar<long>(db,sql,token,("@company",company),("@id",id),("@code",code),("@name",name),("@kind",kind),("@ack",request.RequireAcknowledgement),("@reviewer",request.DefaultReviewerUserId),("@approver",request.DefaultApproverUserId),("@audience",request.DefaultAudienceMode),("@active",request.Active),("@user",user));
            return saved>0?Ok(new{id=saved}):NotFound();
        } catch(SqlException e) when(e.Number is 2601 or 2627) { return Conflict(new{message="รหัสประเภทเอกสารซ้ำ",description="ใช้รหัสอื่นภายในบริษัทเดียวกัน"}); }
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
        if(!Scope(out var company,out _)) return Forbid(); await using var db=await Open(token); if(!await Can(db,menu,"VIEW",token)) return Forbid();
        await ActivateDue(db,company,token); page=Math.Max(page,1);pageSize=Math.Clamp(pageSize,1,100);
        const string where=" FROM dbo.TDDCDocument d JOIN dbo.TDDCDocumentType t ON t.DocumentTypeID=d.DocumentTypeID AND t.CompanyID=d.CompanyID LEFT JOIN dbo.TDDCRevision r ON r.RevisionID=d.CurrentRevisionID WHERE d.CompanyID=@company AND d.DocumentClass=@kind AND d.IsActive=1 AND (@search IS NULL OR d.DocumentNo LIKE N'%'+@search+N'%' OR d.DocumentTitle LIKE N'%'+@search+N'%') AND (@status IS NULL OR d.StatusCode=@status)";
        var args=new(string,object?)[]{("@company",company),("@kind",documentClass.ToUpperInvariant()),("@search",Clean(search)),("@status",Clean(status)?.ToUpperInvariant())};
        var total=await Scalar<int>(db,"SELECT COUNT(*)"+where,token,args);
        var items=await Query(db,"SELECT d.DocumentID id,d.DocumentNo documentNo,d.DocumentTitle title,t.TypeName typeName,d.StatusCode status,r.RevisionNo revisionNo,r.EffectiveDate,d.PublishDate,d.ExpireDate,d.RequireAcknowledgement requireAcknowledgement"+where+" ORDER BY d.CreateDate DESC OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY",token,[..args,("@skip",(page-1)*pageSize),("@take",pageSize)]);
        return Ok(new{items,total,page,pageSize});
    }

    [HttpGet("documents/{id:long}")]
    public async Task<IActionResult> Document(long id,CancellationToken token)
    {
        if(!Scope(out var company,out _)) return Forbid(); await using var db=await Open(token); if(!await AnyDocumentView(db,token)) return Forbid();
        var rows=await Query(db,"SELECT d.DocumentID id,d.DocumentNo documentNo,d.DocumentTitle title,d.DocumentClass documentClass,d.DocumentTypeID documentTypeId,d.OwnerDepartmentID ownerDepartmentId,d.OwnerUserID ownerUserId,d.StatusCode status,d.AudienceMode audienceMode,d.RequireAcknowledgement requireAcknowledgement,d.PublishDate,d.ExpireDate,r.RevisionID revisionId,r.RevisionNo revisionNo,r.ChangeSummary changeSummary,r.EffectiveDate,r.ReviewerUserID reviewerUserId,r.ApproverUserID approverUserId FROM dbo.TDDCDocument d LEFT JOIN dbo.TDDCRevision r ON r.RevisionID=d.CurrentRevisionID WHERE d.CompanyID=@company AND d.DocumentID=@id",token,("@company",company),("@id",id));
        if(rows.Count==0)return NotFound();
        var access=await Query(db,"SELECT SubjectType subjectType,SubjectID subjectId,CanView canView,CanPreview canPreview,CanDownload canDownload FROM dbo.TDDCAccessRule WHERE CompanyID=@company AND DocumentID=@id ORDER BY SubjectType,SubjectID",token,("@company",company),("@id",id));
        var files=await Query(db,"SELECT DocumentFileID id,FileRole fileRole,OriginalFileName fileName,ContentType contentType,FileSizeBytes sizeBytes,CreateDate FROM dbo.TDDCFile WHERE CompanyID=@company AND DocumentID=@id ORDER BY FileRole DESC,CreateDate",token,("@company",company),("@id",id));
        var revisions=await Query(db,"SELECT RevisionID id,RevisionNo revisionNo,StatusCode status,EffectiveDate,ChangeSummary changeSummary,ReviewedDate,ApprovedDate,CreateDate FROM dbo.TDDCRevision WHERE CompanyID=@company AND DocumentID=@id ORDER BY RevisionID DESC",token,("@company",company),("@id",id));
        return Ok(new{header=rows[0],access,files,revisions});
    }

    [HttpPost("documents")]
    public Task<IActionResult> Document(DocumentRequest request,CancellationToken token)=>SaveDocument(null,request,token);
    [HttpPut("documents/{id:long}")]
    public Task<IActionResult> Document(long id,DocumentRequest request,CancellationToken token)=>SaveDocument(id,request,token);

    async Task<IActionResult> SaveDocument(long? id,DocumentRequest request,CancellationToken token)
    {
        var kind=Clean(request.DocumentClass)?.ToUpperInvariant(); var menu=kind=="GENERAL"?"48005":"48003"; var action=id is null?"CREATE":"EDIT";
        if(kind is not ("CONTROLLED" or "GENERAL")||Clean(request.DocumentNo) is null||Clean(request.Title) is null||Clean(request.RevisionNo) is null||request.DocumentTypeId<=0||request.AudienceMode is not ("ALL" or "RESTRICTED")) return Bad("ข้อมูลเอกสารไม่ครบ","ระบุเลขที่ ชื่อ ประเภท Revision และสิทธิ์ผู้ใช้งาน");
        if(!Scope(out var company,out var user)) return Forbid(); await using var db=await Open(token); if(!await Can(db,menu,action,token)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        try {
            var type=await Query(db,tx,"SELECT DocumentClass kind FROM dbo.TDDCDocumentType WHERE CompanyID=@company AND DocumentTypeID=@type AND IsActive=1",token,("@company",company),("@type",request.DocumentTypeId));
            if(type.Count==0||Convert.ToString(type[0]["kind"])!=kind){await tx.RollbackAsync(token);return Bad("ประเภทเอกสารไม่ตรง","เลือกประเภทให้ตรงกับกลุ่มเอกสาร");}
            long documentId; long revisionId;
            if(id is null){
                documentId=await Scalar<long>(db,tx,"INSERT dbo.TDDCDocument(CompanyID,DocumentTypeID,DocumentNo,DocumentTitle,DocumentClass,OwnerDepartmentID,OwnerUserID,StatusCode,AudienceMode,RequireAcknowledgement,PublishDate,ExpireDate,CreateBy) OUTPUT INSERTED.DocumentID VALUES(@company,@type,@no,@title,@kind,@department,@user,@status,@audience,@ack,@publish,@expire,@user)",token,("@company",company),("@type",request.DocumentTypeId),("@no",request.DocumentNo.Trim().ToUpperInvariant()),("@title",request.Title.Trim()),("@kind",kind),("@department",request.OwnerDepartmentId),("@user",user),("@status",kind=="GENERAL"?"PUBLISHED":"DRAFT"),("@audience",request.AudienceMode),("@ack",request.RequireAcknowledgement),("@publish",kind=="GENERAL"?request.PublishDate??DateTime.UtcNow:null),("@expire",request.ExpireDate));
                revisionId=await Scalar<long>(db,tx,"INSERT dbo.TDDCRevision(CompanyID,DocumentID,RevisionNo,ChangeSummary,EffectiveDate,StatusCode,ReviewerUserID,ApproverUserID,CreateBy) OUTPUT INSERTED.RevisionID VALUES(@company,@document,@revision,@summary,@effective,@status,@reviewer,@approver,@user)",token,("@company",company),("@document",documentId),("@revision",request.RevisionNo.Trim().ToUpperInvariant()),("@summary",Clean(request.ChangeSummary)),("@effective",request.EffectiveDate?.Date),("@status",kind=="GENERAL"?"EFFECTIVE":"DRAFT"),("@reviewer",request.ReviewerUserId),("@approver",request.ApproverUserId),("@user",user));
                await Execute(db,tx,"UPDATE dbo.TDDCDocument SET CurrentRevisionID=@revision WHERE CompanyID=@company AND DocumentID=@document",token,("@revision",revisionId),("@company",company),("@document",documentId));
            } else {
                documentId=id.Value;
                var current=await Query(db,tx,"SELECT CurrentRevisionID revisionId,StatusCode status,OwnerUserID owner FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@document AND DocumentClass=@kind",token,("@company",company),("@document",documentId),("@kind",kind));
                if(current.Count==0){await tx.RollbackAsync(token);return NotFound();}
                if(kind=="CONTROLLED" && Convert.ToString(current[0]["status"]) is not ("DRAFT" or "RETURNED")){await tx.RollbackAsync(token);return Conflict(new{message="แก้ไขเอกสารไม่ได้",description="แก้ไขได้เฉพาะสถานะร่างหรือส่งกลับ"});}
                revisionId=Convert.ToInt64(current[0]["revisionId"]);
                await Execute(db,tx,"UPDATE dbo.TDDCDocument SET DocumentTypeID=@type,DocumentNo=@no,DocumentTitle=@title,OwnerDepartmentID=@department,AudienceMode=@audience,RequireAcknowledgement=@ack,PublishDate=@publish,ExpireDate=@expire,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@document",token,("@type",request.DocumentTypeId),("@no",request.DocumentNo.Trim().ToUpperInvariant()),("@title",request.Title.Trim()),("@department",request.OwnerDepartmentId),("@audience",request.AudienceMode),("@ack",request.RequireAcknowledgement),("@publish",request.PublishDate),("@expire",request.ExpireDate),("@user",user),("@company",company),("@document",documentId));
                await Execute(db,tx,"UPDATE dbo.TDDCRevision SET RevisionNo=@revision,ChangeSummary=@summary,EffectiveDate=@effective,ReviewerUserID=@reviewer,ApproverUserID=@approver,StatusCode=CASE WHEN StatusCode=N'RETURNED' THEN N'DRAFT' ELSE StatusCode END,ReturnedReason=NULL,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND RevisionID=@revisionId",token,("@revision",request.RevisionNo.Trim().ToUpperInvariant()),("@summary",Clean(request.ChangeSummary)),("@effective",request.EffectiveDate?.Date),("@reviewer",request.ReviewerUserId),("@approver",request.ApproverUserId),("@user",user),("@company",company),("@revisionId",revisionId));
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
        if(!Scope(out var company,out _)) return Forbid(); await using var db=await Open(token);
        var item=(await Query(db,"SELECT DocumentClass kind,StatusCode status FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@id",token,("@company",company),("@id",id))).FirstOrDefault();
        if(item is null)return NotFound(); var menu=Convert.ToString(item["kind"])=="GENERAL"?"48005":"48003"; if(!await Can(db,menu,"DELETE",token))return Forbid();
        if(Convert.ToString(item["kind"])=="CONTROLLED"&&Convert.ToString(item["status"])!="DRAFT")return Conflict(new{message="ลบเอกสารควบคุมไม่ได้",description="เอกสารที่เข้าสู่ Workflow แล้วต้องเก็บประวัติและเปลี่ยนเป็น Obsolete เท่านั้น"});
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        var paths=await Query(db,tx,"SELECT RelativePath path FROM dbo.TDDCFile WHERE CompanyID=@company AND DocumentID=@id",token,("@company",company),("@id",id));
        foreach(var table in new[]{"TDDCAcknowledgement","TDDCFile","TDDCAccessRule","TDDCRevision","TDDCAudit"}) await Execute(db,tx,$"DELETE dbo.{table} WHERE CompanyID=@company AND DocumentID=@id",token,("@company",company),("@id",id));
        await Execute(db,tx,"DELETE dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@id",token,("@company",company),("@id",id)); await tx.CommitAsync(token);
        foreach(var path in paths.Select(x=>Convert.ToString(x["path"])).Where(x=>!string.IsNullOrWhiteSpace(x))) { var full=SafePhysical(path!); if(System.IO.File.Exists(full))System.IO.File.Delete(full); }
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
        var doc=(await Query(db,"SELECT d.CurrentRevisionID revisionId,d.DocumentClass kind,d.StatusCode status FROM dbo.TDDCDocument d WHERE d.CompanyID=@company AND d.DocumentID=@id",token,("@company",company),("@id",id))).FirstOrDefault();
        if(doc is null)return NotFound(); var menu=Convert.ToString(doc["kind"])=="GENERAL"?"48005":"48003"; if(!await Can(db,menu,"EDIT",token))return Forbid();
        if(Convert.ToString(doc["kind"])=="CONTROLLED"&&Convert.ToString(doc["status"]) is not ("DRAFT" or "RETURNED"))return Conflict(new{message="แนบไฟล์ไม่ได้",description="เอกสารอยู่ระหว่าง Workflow หรือมีผลบังคับใช้แล้ว"});
        await EnsureSettings(db,company,token); var setting=(await Query(db,"SELECT MaxPrimaryFileMB primaryMb,MaxAttachmentFileMB attachmentMb,AllowedAttachmentExtensions extensions FROM dbo.TDDCSystemSetting WHERE CompanyID=@company",token,("@company",company))).Single();
        var extension=Path.GetExtension(file.FileName).TrimStart('.').ToLowerInvariant(); var max=Convert.ToInt32(setting[fileRole=="PRIMARY"?"primaryMb":"attachmentMb"]);
        if(fileRole=="PRIMARY"&&extension!="pdf")return Bad("ไฟล์หลักต้องเป็น PDF","ไฟล์ Office สามารถแนบเป็นเอกสารประกอบได้");
        var allowed=Convert.ToString(setting["extensions"])!.Split(',',StringSplitOptions.RemoveEmptyEntries|StringSplitOptions.TrimEntries);
        if(fileRole=="ATTACHMENT"&&!allowed.Contains(extension,StringComparer.OrdinalIgnoreCase))return Bad("ชนิดไฟล์ไม่ได้รับอนุญาต","ตรวจชนิดไฟล์ที่ตั้งค่าระบบ");
        if(file.Length>max*1024L*1024L)return Bad("ไฟล์มีขนาดใหญ่เกินกำหนด",$"ไฟล์ต้องไม่เกิน {max} MB");
        var revision=Convert.ToInt64(doc["revisionId"]); var folder=Path.Combine(environment.WebRootPath??Path.Combine(environment.ContentRootPath,"wwwroot"),"uploads","document-control",company.ToString(),id.ToString(),revision.ToString());
        Directory.CreateDirectory(folder); var stored=$"{Guid.NewGuid():N}.{extension}"; var full=Path.Combine(folder,stored);
        await using(var output=System.IO.File.Create(full))await file.CopyToAsync(output,token);
        await using var input=System.IO.File.OpenRead(full); var hash=Convert.ToHexString(await SHA256.HashDataAsync(input,token)); var relative=$"uploads/document-control/{company}/{id}/{revision}/{stored}";
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        if(fileRole=="PRIMARY")await Execute(db,tx,"DELETE dbo.TDDCFile WHERE CompanyID=@company AND DocumentID=@id AND RevisionID=@revision AND FileRole=N'PRIMARY'",token,("@company",company),("@id",id),("@revision",revision));
        var fileId=await Scalar<long>(db,tx,"INSERT dbo.TDDCFile(CompanyID,DocumentID,RevisionID,FileRole,OriginalFileName,StoredFileName,RelativePath,ContentType,FileSizeBytes,Sha256,CreateBy) OUTPUT INSERTED.DocumentFileID VALUES(@company,@id,@revision,@role,@original,@stored,@path,@content,@size,@hash,@user)",token,("@company",company),("@id",id),("@revision",revision),("@role",fileRole),("@original",Path.GetFileName(file.FileName)),("@stored",stored),("@path",relative),("@content",file.ContentType??"application/octet-stream"),("@size",file.Length),("@hash",hash),("@user",user));
        await Audit(db,tx,company,id,revision,"UPLOAD",$"{fileRole}:{file.FileName}",user,token); await tx.CommitAsync(token); return Ok(new{id=fileId,fileName=file.FileName,sizeBytes=file.Length});
    }

    [HttpPost("documents/{id:long}/submit")]
    public async Task<IActionResult> Submit(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid(); await using var db=await Open(token); if(!await Can(db,"48003","SUBMIT",token))return Forbid();
        var invalid=await Scalar<int>(db,"SELECT COUNT(*) FROM dbo.TDDCDocument d JOIN dbo.TDDCRevision r ON r.RevisionID=d.CurrentRevisionID WHERE d.CompanyID=@company AND d.DocumentID=@id AND (d.StatusCode NOT IN(N'DRAFT',N'RETURNED') OR r.ReviewerUserID IS NULL OR r.ApproverUserID IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.TDDCFile f WHERE f.CompanyID=d.CompanyID AND f.DocumentID=d.DocumentID AND f.RevisionID=r.RevisionID AND f.FileRole=N'PRIMARY'))",token,("@company",company),("@id",id));
        if(invalid>0)return Conflict(new{message="ส่งตรวจทานไม่ได้",description="ต้องมีผู้ตรวจทาน ผู้อนุมัติ และไฟล์หลัก PDF"});
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token); var revision=await Scalar<long>(db,tx,"SELECT CurrentRevisionID FROM dbo.TDDCDocument WHERE CompanyID=@company AND DocumentID=@id",token,("@company",company),("@id",id));
        var changed=await Execute(db,tx,"UPDATE dbo.TDDCDocument SET StatusCode=N'IN_REVIEW',UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND DocumentID=@id AND StatusCode IN(N'DRAFT',N'RETURNED'); UPDATE dbo.TDDCRevision SET StatusCode=N'IN_REVIEW',UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND RevisionID=@revision AND StatusCode IN(N'DRAFT',N'RETURNED')",token,("@company",company),("@id",id),("@revision",revision),("@user",user));
        await Audit(db,tx,company,id,revision,"SUBMIT",null,user,token); await tx.CommitAsync(token); return changed>0?NoContent():Conflict();
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
        var file=(await Query(db,"SELECT f.DocumentID documentId,f.RelativePath path,f.OriginalFileName fileName,f.ContentType contentType,d.StatusCode status FROM dbo.TDDCFile f JOIN dbo.TDDCDocument d ON d.CompanyID=f.CompanyID AND d.DocumentID=f.DocumentID WHERE f.CompanyID=@company AND f.DocumentFileID=@file",token,("@company",company),("@file",fileId))).FirstOrDefault();if(file is null)return NotFound();
        var document=Convert.ToInt64(file["documentId"]); var published=Convert.ToString(file["status"]) is "EFFECTIVE" or "PUBLISHED"; var allowed=published&&await Can(db,"48006",mode,token)&&await HasAudience(db,company,document,user,mode,token)||await Can(db,"48003",mode,token)||await Can(db,"48005",mode,token);if(!allowed)return Forbid();
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
public sealed record TypeRequest(string Code,string Name,string DocumentClass,bool RequireAcknowledgement,long? DefaultReviewerUserId,long? DefaultApproverUserId,string DefaultAudienceMode,bool Active=true);
public sealed record DocumentRequest(long DocumentTypeId,string DocumentNo,string Title,string DocumentClass,long? OwnerDepartmentId,string RevisionNo,string? ChangeSummary,DateTime? EffectiveDate,long? ReviewerUserId,long? ApproverUserId,string AudienceMode,List<long> DepartmentIds,List<long> UserIds,bool AllowDownload,bool RequireAcknowledgement,DateTime? PublishDate,DateTime? ExpireDate);
public sealed record WorkflowRequest(string? Note);
public sealed class FileUploadRequest
{
    public required IFormFile File { get; init; }
    public string FileRole { get; init; } = "ATTACHMENT";
}
