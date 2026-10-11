using Laoo.Site;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.Site.Controllers;

[ApiController,Authorize,Route("api/company/site/reports")]
public sealed class SiteDailyController(IConfiguration config) : SiteControllerBase(config)
{
    const string BranchScope=@"(EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=P.BranchID AND X.IsActive=1))";

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct,long? projectId=null,int page=1,int pageSize=20)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("หน้าและจำนวนรายการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63003","VIEW",ct) is { } no)return no;
        var args=new (string,object?)[]{("@c",Company),("@actor",Actor),("@project",projectId),("@offset",(page-1)*pageSize),("@size",pageSize)};
        var where="R.CompanyID=@c AND (@project IS NULL OR R.SiteProjectID=@project) AND "+BranchScope;
        var total=await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDSIDailyReport R JOIN dbo.TDSIProject P ON P.CompanyID=R.CompanyID AND P.SiteProjectID=R.SiteProjectID WHERE "+where,ct,args);
        var rows=await SiteDb.Rows(db,null,@"SELECT R.ReportID id,R.SiteProjectID projectId,P.ProjectName projectName,R.WorkDate workDate,
R.Summary summary,R.StatusCode status,R.VersionNo version,R.CreatedAt createdAt,R.SubmittedAt submittedAt
FROM dbo.TDSIDailyReport R JOIN dbo.TDSIProject P ON P.CompanyID=R.CompanyID AND P.SiteProjectID=R.SiteProjectID
WHERE "+where+" ORDER BY R.WorkDate DESC,R.ReportID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,args);
        return Ok(new{items=rows,total,page,pageSize});
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Detail(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"63003","VIEW",ct) is { } no)return no;
        var report=await SiteDb.Rows(db,null,@"SELECT R.ReportID id,R.SiteProjectID projectId,R.WorkDate workDate,R.Summary summary,
R.ProblemSummary problemSummary,R.StatusCode status,R.VersionNo version,R.ReviewReason reviewReason
FROM dbo.TDSIDailyReport R JOIN dbo.TDSIProject P ON P.CompanyID=R.CompanyID AND P.SiteProjectID=R.SiteProjectID
WHERE R.CompanyID=@c AND R.ReportID=@id AND "+BranchScope,ct,("@c",Company),("@actor",Actor),("@id",id));
        if(report.Count==0)return Missing();
        var lines=await SiteDb.Rows(db,null,"SELECT LineID id,LineType type,EmployeeID employeeId,ItemID itemId,Description description,Quantity quantity,Amount amount,SortOrder sortOrder FROM dbo.TDSIDailyLine WHERE CompanyID=@c AND ReportID=@id ORDER BY SortOrder,LineID",ct,("@c",Company),("@id",id));
        var photos=await SiteDb.Rows(db,null,"SELECT AttachmentID id,FileName fileName,MimeType mimeType,FileBytes fileBytes FROM dbo.TDSIAttachment WHERE CompanyID=@c AND ReportID=@id ORDER BY AttachmentID",ct,("@c",Company),("@id",id));
        return Ok(new{report=report[0],lines,photos});
    }

    [HttpPost]
    public async Task<IActionResult> Create(SiteReportRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("วันทำงาน สรุปงาน และรายการประกอบไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63003","CREATE",ct) is { } no)return no;
        if(!await ProjectAllowed(db,input.ProjectId,ct))return Missing();
        if(!await References(db,input.Lines,ct))return Invalid("พนักงานหรือวัสดุไม่อยู่ในบริษัทนี้");
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var id=await SiteDb.Scalar(db,tx,@"INSERT dbo.TDSIDailyReport(CompanyID,SiteProjectID,WorkDate,Summary,ProblemSummary,CreatedBy)
VALUES(@c,@project,@day,@summary,@problem,@actor);SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,
                ("@c",Company),("@project",input.ProjectId),("@day",input.WorkDate),("@summary",input.Summary.Trim()),
                ("@problem",input.ProblemSummary?.Trim()),("@actor",Actor));
            await InsertLines(db,tx,id,input.Lines,ct);
            await SiteDb.Exec(db,tx,"INSERT dbo.TDSIAudit(CompanyID,SiteProjectID,EntityType,EntityID,ActionCode,ActorType,ActorID) VALUES(@c,@project,N'REPORT',@id,N'CREATE',N'COMPANY_USER',@actor)",ct,
                ("@c",Company),("@project",input.ProjectId),("@id",id),("@actor",Actor));
            await tx.CommitAsync(ct);
            return Created($"/api/company/site/reports/{id}",new{id});
        }
        catch {await tx.RollbackAsync(ct);throw;}
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id,SiteReportRequest input,CancellationToken ct)
    {
        if(id<1||!Valid(input))return Invalid("ข้อมูลบันทึกไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63003","EDIT",ct) is { } no)return no;
        if(!await ProjectAllowed(db,input.ProjectId,ct))return Missing();
        if(!await References(db,input.Lines,ct))return Invalid("พนักงานหรือวัสดุไม่อยู่ในบริษัทนี้");
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var changed=await SiteDb.Exec(db,tx,@"UPDATE dbo.TDSIDailyReport SET WorkDate=@day,Summary=@summary,ProblemSummary=@problem,
StatusCode=N'DRAFT',ReviewReason=NULL,VersionNo=VersionNo+1,UpdatedAt=SYSUTCDATETIME()
WHERE CompanyID=@c AND ReportID=@id AND SiteProjectID=@project AND StatusCode IN(N'DRAFT',N'RETURNED')",ct,
                ("@c",Company),("@id",id),("@project",input.ProjectId),("@day",input.WorkDate),("@summary",input.Summary.Trim()),("@problem",input.ProblemSummary?.Trim()));
            if(changed==0){await tx.RollbackAsync(ct);return Conflict(new{message="แก้ไขไม่ได้",description="บันทึกถูกส่งตรวจแล้วหรือไม่พบรายการ"});}
            await SiteDb.Exec(db,tx,"DELETE FROM dbo.TDSIDailyLine WHERE CompanyID=@c AND ReportID=@id",ct,("@c",Company),("@id",id));
            await InsertLines(db,tx,id,input.Lines,ct);
            await SiteDb.Exec(db,tx,"INSERT dbo.TDSIAudit(CompanyID,SiteProjectID,EntityType,EntityID,ActionCode,ActorType,ActorID) VALUES(@c,@project,N'REPORT',@id,N'EDIT',N'COMPANY_USER',@actor)",ct,
                ("@c",Company),("@project",input.ProjectId),("@id",id),("@actor",Actor));
            await tx.CommitAsync(ct);
            return NoContent();
        }
        catch {await tx.RollbackAsync(ct);throw;}
    }

    [HttpPost("{id:long}/submit")]
    public async Task<IActionResult> Submit(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"63003","SUBMIT",ct) is { } no)return no;
        var changed=await SiteDb.Exec(db,null,@"UPDATE R SET StatusCode=N'SUBMITTED',SubmittedAt=SYSUTCDATETIME(),UpdatedAt=SYSUTCDATETIME()
FROM dbo.TDSIDailyReport R JOIN dbo.TDSIProject P ON P.CompanyID=R.CompanyID AND P.SiteProjectID=R.SiteProjectID
WHERE R.CompanyID=@c AND R.ReportID=@id AND R.StatusCode=N'DRAFT' AND P.StatusCode=N'ACTIVE' AND "+BranchScope,ct,
            ("@c",Company),("@actor",Actor),("@id",id));
        return changed==0?Conflict(new{message="ส่งตรวจไม่ได้",description="ไม่พบร่างที่พร้อมส่งหรือไม่มีสิทธิ์สาขานี้"}):NoContent();
    }

    async Task<bool> ProjectAllowed(SqlConnection db,long id,CancellationToken ct)=>
        await SiteDb.Scalar(db,null,@"SELECT COUNT(*) FROM dbo.TDSIProject P WHERE P.CompanyID=@c AND P.SiteProjectID=@id
AND P.StatusCode=N'ACTIVE' AND "+BranchScope,ct,("@c",Company),("@id",id),("@actor",Actor))>0;
    static bool Valid(SiteReportRequest x)=>x.ProjectId>0&&!string.IsNullOrWhiteSpace(x.Summary)&&x.Summary.Length<=4000
        &&(x.ProblemSummary?.Length??0)<=4000&&x.Lines is {Count:<=200}
        &&x.Lines.All(l=>l.Type is "WORKER" or "MATERIAL" or "EXPENSE"&&!string.IsNullOrWhiteSpace(l.Description)
            &&l.Description.Length<=1000&&(l.Quantity is null or >0)&&(l.Amount is null or >=0));
    async Task<bool> References(SqlConnection db,IReadOnlyList<SiteReportLine> lines,CancellationToken ct)
    {
        foreach(var line in lines)
        {
            if(line.EmployeeId is >0 && await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDADEmployee WHERE CompanyID=@c AND EmployeeID=@id AND IsActive=1",ct,("@c",Company),("@id",line.EmployeeId))==0)return false;
            if(line.ItemId is >0 && await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDIVItem WHERE CompanyID=@c AND ItemID=@id AND IsActive=1",ct,("@c",Company),("@id",line.ItemId))==0)return false;
        }
        return true;
    }
    async Task InsertLines(SqlConnection db,SqlTransaction tx,long id,IReadOnlyList<SiteReportLine> lines,CancellationToken ct)
    {
        for(var i=0;i<lines.Count;i++)
        {
            var l=lines[i];
            await SiteDb.Exec(db,tx,@"INSERT dbo.TDSIDailyLine(CompanyID,ReportID,LineType,EmployeeID,ItemID,Description,Quantity,Amount,SortOrder)
VALUES(@c,@report,@type,@employee,@item,@description,@quantity,@amount,@sort)",ct,
                ("@c",Company),("@report",id),("@type",l.Type),("@employee",l.EmployeeId),("@item",l.ItemId),
                ("@description",l.Description.Trim()),("@quantity",l.Quantity),("@amount",l.Amount),("@sort",i));
        }
    }
}
public sealed record SiteReportRequest(long ProjectId,DateOnly WorkDate,string Summary,string? ProblemSummary,List<SiteReportLine> Lines);
public sealed record SiteReportLine(string Type,string Description,long? EmployeeId,long? ItemId,decimal? Quantity,decimal? Amount);
