using Laoo.Site;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.Site.Controllers;

[ApiController,Authorize,Route("api/company/site/issues")]
public sealed class SiteIssuesController(IConfiguration config) : SiteControllerBase(config)
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct,long? projectId=null,int page=1,int pageSize=20)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("หน้าและจำนวนรายการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63005","VIEW",ct) is { } no)return no;
        var args=new (string,object?)[]{("@c",Company),("@actor",Actor),("@project",projectId),("@offset",(page-1)*pageSize),("@size",pageSize)};
        var where=@"I.CompanyID=@c AND (@project IS NULL OR I.SiteProjectID=@project)
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=P.BranchID AND X.IsActive=1))";
        var total=await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDSIIssue I JOIN dbo.TDSIProject P ON P.CompanyID=I.CompanyID AND P.SiteProjectID=I.SiteProjectID WHERE "+where,ct,args);
        var rows=await SiteDb.Rows(db,null,@"SELECT I.IssueID id,I.SiteProjectID projectId,P.ProjectName projectName,I.ReportID reportId,I.Title title,
I.Detail detail,I.StatusCode status,I.AssignedEmployeeID assignedEmployeeId,I.DueDate dueDate,I.Resolution resolution,I.CreatedAt createdAt
FROM dbo.TDSIIssue I JOIN dbo.TDSIProject P ON P.CompanyID=I.CompanyID AND P.SiteProjectID=I.SiteProjectID
WHERE "+where+" ORDER BY I.IssueID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,args);
        return Ok(new{items=rows,total,page,pageSize});
    }

    [HttpPost]
    public async Task<IActionResult> Create(SiteIssueRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("ชื่อปัญหาและรายละเอียดต้องไม่ว่าง");
        await using var db=await Open(ct);
        if(await Guard(db,"63005","CREATE",ct) is { } no)return no;
        if(!await References(db,input,ct))return Invalid("โครงการ รายงาน หรือผู้รับผิดชอบไม่อยู่ในขอบเขตที่มีสิทธิ์");
        var id=await SiteDb.Scalar(db,null,@"INSERT dbo.TDSIIssue(CompanyID,SiteProjectID,ReportID,Title,Detail,AssignedEmployeeID,DueDate,CreatedBy)
VALUES(@c,@project,@report,@title,@detail,@employee,@due,@actor);SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,Args(input));
        return Created($"/api/company/site/issues/{id}",new{id});
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id,SiteIssueRequest input,CancellationToken ct)
    {
        if(id<1||!Valid(input))return Invalid("ข้อมูลปัญหาไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63005","EDIT",ct) is { } no)return no;
        if(!await References(db,input,ct))return Invalid("โครงการ รายงาน หรือผู้รับผิดชอบไม่อยู่ในขอบเขตที่มีสิทธิ์");
        var changed=await SiteDb.Exec(db,null,@"UPDATE dbo.TDSIIssue SET ReportID=@report,Title=@title,Detail=@detail,
AssignedEmployeeID=@employee,DueDate=@due,StatusCode=@status,Resolution=@resolution,UpdatedAt=SYSUTCDATETIME()
WHERE CompanyID=@c AND IssueID=@id AND SiteProjectID=@project AND StatusCode<>N'CLOSED'",ct,
            Args(input).Concat([("@id",(object?)id),("@status",input.Status),("@resolution",input.Resolution?.Trim())]).ToArray());
        return changed==0?Missing():NoContent();
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Close(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"63005","DELETE",ct) is { } no)return no;
        var project=await SiteDb.Scalar(db,null,"SELECT COALESCE(MAX(SiteProjectID),0) FROM dbo.TDSIIssue WHERE CompanyID=@c AND IssueID=@id",ct,("@c",Company),("@id",id));
        if(project==0||!await ProjectInScope(db,project,ct))return Missing();
        var changed=await SiteDb.Exec(db,null,"UPDATE dbo.TDSIIssue SET StatusCode=N'CLOSED',UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@c AND IssueID=@id AND StatusCode=N'RESOLVED'",ct,("@c",Company),("@id",id));
        return changed==0?Conflict(new{message="ปิดปัญหาไม่ได้",description="ต้องแก้ไขให้เสร็จก่อนจึงปิดได้"}):NoContent();
    }

    bool Valid(SiteIssueRequest x)=>x.ProjectId>0&&!string.IsNullOrWhiteSpace(x.Title)&&x.Title.Length<=200
        &&!string.IsNullOrWhiteSpace(x.Detail)&&x.Detail.Length<=4000&&(x.Resolution?.Length??0)<=4000
        &&x.Status is "OPEN" or "IN_PROGRESS" or "RESOLVED";
    async Task<bool> References(SqlConnection db,SiteIssueRequest x,CancellationToken ct)
    {
        if(!await ProjectInScope(db,x.ProjectId,ct))return false;
        if(x.ReportId is >0 && await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDSIDailyReport WHERE CompanyID=@c AND SiteProjectID=@project AND ReportID=@report",ct,
            ("@c",Company),("@project",x.ProjectId),("@report",x.ReportId))==0)return false;
        if(x.EmployeeId is >0 && await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDADEmployee WHERE CompanyID=@c AND EmployeeID=@id AND IsActive=1",ct,
            ("@c",Company),("@id",x.EmployeeId))==0)return false;
        return true;
    }
    (string,object?)[] Args(SiteIssueRequest x)=>[("@c",Company),("@project",x.ProjectId),("@report",x.ReportId),
        ("@title",x.Title.Trim()),("@detail",x.Detail.Trim()),("@employee",x.EmployeeId),("@due",x.DueDate),("@actor",Actor)];
}
public sealed record SiteIssueRequest(long ProjectId,long? ReportId,string Title,string Detail,long? EmployeeId,DateOnly? DueDate,string Status,string? Resolution);
