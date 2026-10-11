using System.Security.Claims;
using System.Text.Json;
using Laoo.Site;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.Site.Controllers;

[ApiController,Authorize,Route("api/site/customer/portal")]
public sealed class SiteCustomerPortalController(IConfiguration config,IWebHostEnvironment env) : ControllerBase
{
    bool Scope(out long company,out long account)
    {
        company=account=0;
        return User.FindFirstValue("user_type")=="SITE_CUSTOMER"
            &&User.FindFirstValue("login_mode")=="SITE_CUSTOMER"
            &&User.FindFirstValue("project_code")=="LAOO_SITE"
            &&User.FindFirst("user_id") is null
            &&long.TryParse(User.FindFirstValue("company_id"),out company)&&company>0
            &&long.TryParse(User.FindFirstValue("site_customer_account_id"),out account)&&account>0;
    }
    async Task<SqlConnection> Open(CancellationToken ct)
    {
        var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        return db;
    }
    async Task<bool> Allowed(SqlConnection db,long company,long account,long project,bool write,CancellationToken ct)
        => await SiteDb.Scalar(db,null,@"SELECT COUNT(*) FROM dbo.TDSICustomerAccess G
JOIN dbo.TDSICustomerAccount A ON A.CompanyID=G.CompanyID AND A.CustomerAccountID=G.CustomerAccountID AND A.CustomerID=G.CustomerID AND A.IsActive=1
JOIN dbo.TDSIProject P ON P.CompanyID=G.CompanyID AND P.SiteProjectID=G.SiteProjectID AND P.CustomerID=G.CustomerID AND P.StatusCode<>N'CANCELLED'
JOIN dbo.TDADCompanyProjectSubscription S ON S.CompanyID=G.CompanyID AND S.IsCurrent=1
JOIN dbo.TDADProject J ON J.ProjectID=S.ProjectID AND J.ProjectCode=N'LAOO_SITE' AND J.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=G.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE G.CompanyID=@c AND G.CustomerAccountID=@account AND G.SiteProjectID=@project AND G.IsActive=1
AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND ((S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
 OR (@write=0 AND (S.StatusCode=N'EXPIRED' OR (S.StatusCode IN(N'ACTIVE',N'TRIAL') AND S.ExpireDate<CONVERT(date,SYSUTCDATETIME())))))",
            ct,("@c",company),("@account",account),("@project",project),("@write",write))>0;

    [HttpGet("me")]
    public async Task<IActionResult> Me(CancellationToken ct)
    {
        if(!Scope(out var company,out var account))return Forbid();
        await using var db=await Open(ct);
        var rows=await SiteDb.Rows(db,null,@"SELECT C.Name companyName,C.TimeAlert timeAlert,A.EmailNormalized email
FROM dbo.TDSICustomerAccount A JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=A.CompanyID AND C.IsActive=1
WHERE A.CompanyID=@c AND A.CustomerAccountID=@account AND A.IsActive=1",ct,
            ("@c",company),("@account",account));
        if(rows.Count==0)return NotFound();
        return Ok(rows[0]);
    }

    [HttpGet("projects")]
    public async Task<IActionResult> Projects(CancellationToken ct)
    {
        if(!Scope(out var company,out var account))return Forbid();
        await using var db=await Open(ct);
        var ids=await SiteDb.Rows(db,null,@"SELECT G.SiteProjectID id FROM dbo.TDSICustomerAccess G
JOIN dbo.TDSICustomerAccount A ON A.CompanyID=G.CompanyID AND A.CustomerAccountID=G.CustomerAccountID AND A.IsActive=1
WHERE G.CompanyID=@c AND G.CustomerAccountID=@account AND G.IsActive=1",ct,("@c",company),("@account",account));
        var result=new List<object>();
        foreach(var item in ids)
        {
            var project=Convert.ToInt64(item["id"]);
            if(!await Allowed(db,company,account,project,false,ct))continue;
            var rows=await SiteDb.Rows(db,null,@"SELECT SiteProjectID id,ProjectName name,SiteAddress address,
StatusCode status FROM dbo.TDSIProject WHERE CompanyID=@c AND SiteProjectID=@project",ct,("@c",company),("@project",project));
            if(rows.Count>0)result.Add(rows[0]);
        }
        return Ok(result);
    }

    [HttpGet("projects/{projectId:long}/reports")]
    public async Task<IActionResult> Reports(long projectId,CancellationToken ct,int page=1,int pageSize=20)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return BadRequest();
        if(!Scope(out var company,out var account))return Forbid();
        await using var db=await Open(ct);
        if(!await Allowed(db,company,account,projectId,false,ct))return NotFound();
        var args=new (string,object?)[]{("@c",company),("@project",projectId),("@offset",(page-1)*pageSize),("@size",pageSize)};
        var total=await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDSIPublication WHERE CompanyID=@c AND SiteProjectID=@project",ct,args);
        var rows=await SiteDb.Rows(db,null,@"SELECT PublicationID id,PublishedSnapshot snapshot,PublishedAt publishedAt
FROM dbo.TDSIPublication WHERE CompanyID=@c AND SiteProjectID=@project
ORDER BY PublishedAt DESC,PublicationID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,args);
        var items=rows.Select(r=>new{ id=r["id"],publishedAt=r["publishedAt"],
            content=JsonSerializer.Deserialize<JsonElement>(Convert.ToString(r["snapshot"])!) }).ToArray();
        return Ok(new{items,total,page,pageSize});
    }

    [HttpGet("notifications")]
    public async Task<IActionResult> Notifications(CancellationToken ct)
    {
        if(!Scope(out var company,out var account))return Forbid();
        await using var db=await Open(ct);
        var rows=await SiteDb.Rows(db,null,@"SELECT TOP(50) N.NotificationID id,N.SiteProjectID projectId,
N.NotificationType type,N.Title title,N.IsRead isRead,N.CreatedAt createdAt
FROM dbo.TDSINotification N
JOIN dbo.TDSICustomerAccess G ON G.CompanyID=N.CompanyID AND G.AccessID=N.AccessID
WHERE N.CompanyID=@c AND G.CustomerAccountID=@account AND G.IsActive=1
ORDER BY N.NotificationID DESC",ct,("@c",company),("@account",account));
        var visible=new List<object>();
        foreach(var row in rows)
            if(await Allowed(db,company,account,Convert.ToInt64(row["projectId"]),false,ct))
                visible.Add(row);
        return Ok(visible);
    }

    [HttpPost("notifications/{id:long}/read")]
    public async Task<IActionResult> ReadNotification(long id,CancellationToken ct)
    {
        if(!Scope(out var company,out var account))return Forbid();
        await using var db=await Open(ct);
        var rows=await SiteDb.Rows(db,null,@"SELECT N.SiteProjectID projectId FROM dbo.TDSINotification N
JOIN dbo.TDSICustomerAccess G ON G.CompanyID=N.CompanyID AND G.AccessID=N.AccessID AND G.IsActive=1
WHERE N.CompanyID=@c AND N.NotificationID=@id AND G.CustomerAccountID=@account",ct,
            ("@c",company),("@id",id),("@account",account));
        if(rows.Count==0||!await Allowed(db,company,account,Convert.ToInt64(rows[0]["projectId"]),false,ct))
            return NotFound();
        await SiteDb.Exec(db,null,@"UPDATE dbo.TDSINotification SET IsRead=1,ReadAt=COALESCE(ReadAt,SYSUTCDATETIME())
WHERE CompanyID=@c AND NotificationID=@id AND IsRead=0",ct,("@c",company),("@id",id));
        return NoContent();
    }

    [HttpGet("projects/{projectId:long}/handovers")]
    public async Task<IActionResult> Handovers(long projectId,CancellationToken ct)
    {
        if(!Scope(out var company,out var account))return Forbid();
        await using var db=await Open(ct);
        if(!await Allowed(db,company,account,projectId,false,ct))return NotFound();
        var rows=await SiteDb.Rows(db,null,@"SELECT HandoverID id,HandoverNo number,StageName stageName,HandoverType type,
Detail detail,StatusCode status,SubmittedAt submittedAt,AcceptedAt acceptedAt,ReturnReason returnReason
FROM dbo.TDSIHandover WHERE CompanyID=@c AND SiteProjectID=@project
AND StatusCode IN(N'SUBMITTED',N'ACCEPTED',N'RETURNED')
ORDER BY HandoverID DESC",ct,("@c",company),("@project",projectId));
        return Ok(rows);
    }

    [HttpPost("projects/{projectId:long}/handovers/{id:long}/decision")]
    public async Task<IActionResult> Decide(long projectId,long id,SiteCustomerDecision input,CancellationToken ct)
    {
        if(input.Accept is false&&(string.IsNullOrWhiteSpace(input.Reason)||input.Reason.Length>1000))
            return BadRequest(new{message="ต้องระบุเหตุผลส่งกลับ"});
        if(!Scope(out var company,out var account))return Forbid();
        await using var db=await Open(ct);
        if(!await Allowed(db,company,account,projectId,true,ct))return NotFound();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var changed=await SiteDb.Exec(db,tx,@"UPDATE dbo.TDSIHandover SET StatusCode=@status,
AcceptedBy=CASE WHEN @accept=1 THEN @account ELSE NULL END,
AcceptedAt=CASE WHEN @accept=1 THEN SYSUTCDATETIME() ELSE NULL END,
ReturnReason=CASE WHEN @accept=1 THEN NULL ELSE @reason END,UpdatedAt=SYSUTCDATETIME()
WHERE CompanyID=@c AND SiteProjectID=@project AND HandoverID=@id AND StatusCode=N'SUBMITTED'",ct,
                ("@c",company),("@project",projectId),("@id",id),("@account",account),
                ("@status",input.Accept?"ACCEPTED":"RETURNED"),("@accept",input.Accept),("@reason",input.Reason?.Trim()));
            if(changed==0){await tx.RollbackAsync(ct);return Conflict(new{message="ยืนยันไม่ได้",description="รายการนี้ถูกดำเนินการแล้วหรือไม่พบ"});}
            await SiteDb.Exec(db,tx,@"INSERT dbo.TDSIAudit(CompanyID,SiteProjectID,EntityType,EntityID,ActionCode,ActorType,ActorID)
VALUES(@c,@project,N'HANDOVER',@id,@action,N'SITE_CUSTOMER',@account)",ct,
                ("@c",company),("@project",projectId),("@id",id),("@action",input.Accept?"ACCEPT":"RETURN"),("@account",account));
            await tx.CommitAsync(ct);
            return NoContent();
        }
        catch{await tx.RollbackAsync(ct);throw;}
    }

    [HttpGet("projects/{projectId:long}/files/{id:long}")]
    public async Task<IActionResult> DownloadFile(long projectId,long id,CancellationToken ct)
    {
        if(!Scope(out var company,out var account))return Forbid();
        await using var db=await Open(ct);
        if(!await Allowed(db,company,account,projectId,false,ct))return NotFound();
        var rows=await SiteDb.Rows(db,null,@"SELECT A.StoredPath path,A.MimeType mime,A.FileName fileName
FROM dbo.TDSIAttachment A WHERE A.CompanyID=@c AND A.SiteProjectID=@project AND A.AttachmentID=@id
AND ((A.ReportID IS NOT NULL AND EXISTS(
 SELECT 1 FROM dbo.TDSIPublication P CROSS APPLY OPENJSON(P.PublishedSnapshot,N'$.photos') J
 WHERE P.CompanyID=A.CompanyID AND P.SiteProjectID=A.SiteProjectID AND P.ReportID=A.ReportID
 AND TRY_CONVERT(bigint,JSON_VALUE(J.value,N'$.id'))=A.AttachmentID))
 OR (A.HandoverID IS NOT NULL AND EXISTS(
 SELECT 1 FROM dbo.TDSIHandover H WHERE H.CompanyID=A.CompanyID AND H.SiteProjectID=A.SiteProjectID
 AND H.HandoverID=A.HandoverID AND H.StatusCode IN(N'SUBMITTED',N'ACCEPTED',N'RETURNED'))))",
            ct,("@c",company),("@project",projectId),("@id",id));
        if(rows.Count==0)return NotFound();
        var relative=Convert.ToString(rows[0]["path"])!;
        var root=Path.GetFullPath(Path.Combine(env.ContentRootPath,"uploads","site"));
        var path=Path.GetFullPath(Path.Combine(env.ContentRootPath,relative.Replace('/',Path.DirectorySeparatorChar)));
        if(!path.StartsWith(root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)
            ||!System.IO.File.Exists(path))return NotFound();
        return File(await System.IO.File.ReadAllBytesAsync(path,ct),
            Convert.ToString(rows[0]["mime"])!,Convert.ToString(rows[0]["fileName"])!);
    }
}
public sealed record SiteCustomerDecision(bool Accept,string? Reason);
