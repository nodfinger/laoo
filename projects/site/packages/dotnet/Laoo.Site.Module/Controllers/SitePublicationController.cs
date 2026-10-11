using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Laoo.Site;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.Site.Controllers;

[ApiController,Authorize,Route("api/company/site/publications")]
public sealed class SitePublicationController(IConfiguration config) : SiteControllerBase(config)
{
    const string Visible=@"EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=P.BranchID AND X.IsActive=1)";

    [HttpGet]
    public async Task<IActionResult> Queue(CancellationToken ct,int page=1,int pageSize=20)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("หน้าและจำนวนรายการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63004","VIEW",ct) is { } no)return no;
        var args=new (string,object?)[]{("@c",Company),("@actor",Actor),("@offset",(page-1)*pageSize),("@size",pageSize)};
        var where="R.CompanyID=@c AND R.StatusCode IN(N'SUBMITTED',N'REVIEWED',N'PUBLISHED',N'RETURNED') AND ("+Visible+")";
        var total=await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDSIDailyReport R JOIN dbo.TDSIProject P ON P.CompanyID=R.CompanyID AND P.SiteProjectID=R.SiteProjectID WHERE "+where,ct,args);
        var rows=await SiteDb.Rows(db,null,@"SELECT R.ReportID id,R.SiteProjectID projectId,P.ProjectName projectName,R.WorkDate workDate,
R.Summary summary,R.StatusCode status,R.VersionNo version,R.SubmittedAt submittedAt,R.ReviewedAt reviewedAt
FROM dbo.TDSIDailyReport R JOIN dbo.TDSIProject P ON P.CompanyID=R.CompanyID AND P.SiteProjectID=R.SiteProjectID
WHERE "+where+" ORDER BY R.ReportID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,args);
        return Ok(new {items=rows,total,page,pageSize});
    }

    [HttpPost("{id:long}/review")]
    public async Task<IActionResult> Review(long id,SiteReviewRequest input,CancellationToken ct)
    {
        if(input.Return && (string.IsNullOrWhiteSpace(input.Reason)||input.Reason.Length>1000))
            return Invalid("ส่งกลับต้องระบุเหตุผลไม่เกิน 1,000 อักษร");
        await using var db=await Open(ct);
        if(await Guard(db,"63004",input.Return?"RETURN":"REVIEW",ct) is { } no)return no;
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var rows=await SiteDb.Rows(db,tx,@"SELECT R.SiteProjectID projectId FROM dbo.TDSIDailyReport R WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDSIProject P ON P.CompanyID=R.CompanyID AND P.SiteProjectID=R.SiteProjectID
WHERE R.CompanyID=@c AND R.ReportID=@id AND R.StatusCode=N'SUBMITTED' AND ("+Visible+")",ct,("@c",Company),("@id",id),("@actor",Actor));
            if(rows.Count==0){await tx.RollbackAsync(ct);return Conflict(new{message="ตรวจไม่ได้",description="รายการไม่อยู่ในสถานะรอตรวจหรือไม่มีสิทธิ์สาขานี้"});}
            var project=Convert.ToInt64(rows[0]["projectId"]);
            await SiteDb.Exec(db,tx,@"UPDATE dbo.TDSIDailyReport SET StatusCode=@status,ReviewedBy=@actor,
ReviewedAt=SYSUTCDATETIME(),ReviewReason=@reason,UpdatedAt=SYSUTCDATETIME()
WHERE CompanyID=@c AND ReportID=@id",ct,("@status",input.Return?"RETURNED":"REVIEWED"),("@actor",Actor),
                ("@reason",input.Return?input.Reason?.Trim():null),("@c",Company),("@id",id));
            await SiteDb.Exec(db,tx,"INSERT dbo.TDSIAudit(CompanyID,SiteProjectID,EntityType,EntityID,ActionCode,ActorType,ActorID) VALUES(@c,@project,N'REPORT',@id,@action,N'COMPANY_USER',@actor)",ct,
                ("@c",Company),("@project",project),("@id",id),("@action",input.Return?"RETURN":"REVIEW"),("@actor",Actor));
            await tx.CommitAsync(ct);
            return NoContent();
        }
        catch {await tx.RollbackAsync(ct);throw;}
    }

    [HttpPost("{id:long}/publish")]
    public async Task<IActionResult> Publish(long id,SitePublishRequest input,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"63004","PUBLISH",ct) is { } no)return no;
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var rows=await SiteDb.Rows(db,tx,@"SELECT R.SiteProjectID projectId,R.WorkDate workDate,R.Summary summary,
R.ProblemSummary problem,R.VersionNo version,P.ProjectName projectName FROM dbo.TDSIDailyReport R WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDSIProject P ON P.CompanyID=R.CompanyID AND P.SiteProjectID=R.SiteProjectID
WHERE R.CompanyID=@c AND R.ReportID=@id AND R.StatusCode=N'REVIEWED' AND ("+Visible+")",ct,
                ("@c",Company),("@id",id),("@actor",Actor));
            if(rows.Count==0){await tx.RollbackAsync(ct);return Conflict(new{message="เผยแพร่ไม่ได้",description="รายงานต้องผ่านการตรวจและยังไม่เคยเผยแพร่"});}
            var row=rows[0]; var project=Convert.ToInt64(row["projectId"]); var version=Convert.ToInt32(row["version"]);
            var lines=await SiteDb.Rows(db,tx,@"SELECT LineType type,Description description,Quantity quantity
FROM dbo.TDSIDailyLine WHERE CompanyID=@c AND ReportID=@id AND LineType IN(N'WORKER',N'MATERIAL') ORDER BY SortOrder,LineID",ct,
                ("@c",Company),("@id",id));
            var photos=input.IncludePhotos
                ? await SiteDb.Rows(db,tx,"SELECT AttachmentID id,FileName fileName,MimeType mimeType FROM dbo.TDSIAttachment WHERE CompanyID=@c AND ReportID=@id ORDER BY AttachmentID",ct,("@c",Company),("@id",id))
                : [];
            var snapshot=JsonSerializer.Serialize(new{
                projectId=project,reportId=id,version,projectName=row["projectName"],workDate=row["workDate"],
                summary=row["summary"],problem=input.IncludeProblems?row["problem"]:null,
                workers=input.IncludeWorkers?lines.Where(x=>Convert.ToString(x["type"])=="WORKER").ToArray():[],
                materials=input.IncludeMaterials?lines.Where(x=>Convert.ToString(x["type"])=="MATERIAL").ToArray():[],
                photos,publishedAt=DateTime.UtcNow});
            var sha=Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(snapshot)));
            await SiteDb.Exec(db,tx,@"INSERT dbo.TDSIPublication(CompanyID,SiteProjectID,ReportID,ReportVersionNo,PublishedSnapshot,SnapshotSha256,PublishedBy)
VALUES(@c,@project,@id,@version,@snapshot,@sha,@actor)",ct,
                ("@c",Company),("@project",project),("@id",id),("@version",version),("@snapshot",snapshot),("@sha",sha),("@actor",Actor));
            await SiteDb.Exec(db,tx,"UPDATE dbo.TDSIDailyReport SET StatusCode=N'PUBLISHED',UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@c AND ReportID=@id",ct,("@c",Company),("@id",id));
            await SiteDb.Exec(db,tx,@"INSERT dbo.TDSINotification(CompanyID,SiteProjectID,AccessID,NotificationType,ReferenceID,Title)
SELECT @c,@project,AccessID,N'DAILY_REPORT',@id,N'รายงานไซต์งานใหม่' FROM dbo.TDSICustomerAccess
WHERE CompanyID=@c AND SiteProjectID=@project AND IsActive=1",ct,("@c",Company),("@project",project),("@id",id));
            await SiteDb.Exec(db,tx,"INSERT dbo.TDSIAudit(CompanyID,SiteProjectID,EntityType,EntityID,ActionCode,ActorType,ActorID) VALUES(@c,@project,N'REPORT',@id,N'PUBLISH',N'COMPANY_USER',@actor)",ct,
                ("@c",Company),("@project",project),("@id",id),("@actor",Actor));
            await tx.CommitAsync(ct);
            return Ok(new{reportId=id,version,sha256=sha});
        }
        catch {await tx.RollbackAsync(ct);throw;}
    }
}
public sealed record SiteReviewRequest(bool Return,string? Reason);
public sealed record SitePublishRequest(bool IncludeWorkers,bool IncludeMaterials,bool IncludeProblems,bool IncludePhotos);
