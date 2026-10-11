using Laoo.Site;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.Site.Controllers;

[ApiController,Authorize,Route("api/company/site/handovers")]
public sealed class SiteHandoversController(IConfiguration config) : SiteControllerBase(config)
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct,long? projectId=null,int page=1,int pageSize=20)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("หน้าและจำนวนรายการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63006","VIEW",ct) is { } no)return no;
        var args=new (string,object?)[]{("@c",Company),("@actor",Actor),("@project",projectId),("@offset",(page-1)*pageSize),("@size",pageSize)};
        var where=@"H.CompanyID=@c AND (@project IS NULL OR H.SiteProjectID=@project)
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=P.BranchID AND X.IsActive=1))";
        var total=await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDSIHandover H JOIN dbo.TDSIProject P ON P.CompanyID=H.CompanyID AND P.SiteProjectID=H.SiteProjectID WHERE "+where,ct,args);
        var rows=await SiteDb.Rows(db,null,@"SELECT H.HandoverID id,H.SiteProjectID projectId,P.ProjectName projectName,H.HandoverNo number,
H.StageName stageName,H.HandoverType type,H.Detail detail,H.StatusCode status,H.SubmittedAt submittedAt,
H.AcceptedAt acceptedAt,H.ReturnReason returnReason
FROM dbo.TDSIHandover H JOIN dbo.TDSIProject P ON P.CompanyID=H.CompanyID AND P.SiteProjectID=H.SiteProjectID
WHERE "+where+" ORDER BY H.HandoverID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,args);
        return Ok(new{items=rows,total,page,pageSize});
    }
    [HttpPost]
    public async Task<IActionResult> Create(SiteHandoverRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("ชื่อช่วงงาน ประเภท และรายละเอียดไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63006","CREATE",ct) is { } no)return no;
        if(!await ProjectInScope(db,input.ProjectId,ct))return Missing();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var temporary="TMP-"+Guid.NewGuid().ToString("N");
            var id=await SiteDb.Scalar(db,tx,@"INSERT dbo.TDSIHandover(CompanyID,SiteProjectID,HandoverNo,StageName,HandoverType,Detail,CreatedBy)
VALUES(@c,@project,@number,@stage,@type,@detail,@actor);SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,
                ("@c",Company),("@project",input.ProjectId),("@number",temporary),("@stage",input.StageName.Trim()),
                ("@type",input.Type),("@detail",input.Detail.Trim()),("@actor",Actor));
            var number=$"SI-{DateTime.UtcNow:yyyy}-{id:000000}";
            await SiteDb.Exec(db,tx,"UPDATE dbo.TDSIHandover SET HandoverNo=@number WHERE CompanyID=@c AND HandoverID=@id",ct,
                ("@number",number),("@c",Company),("@id",id));
            await tx.CommitAsync(ct);
            return Created($"/api/company/site/handovers/{id}",new{id,number});
        }
        catch {await tx.RollbackAsync(ct);throw;}
    }
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id,SiteHandoverRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("ข้อมูลส่งมอบไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63006","EDIT",ct) is { } no)return no;
        if(!await ProjectInScope(db,input.ProjectId,ct))return Missing();
        var changed=await SiteDb.Exec(db,null,@"UPDATE dbo.TDSIHandover SET StageName=@stage,HandoverType=@type,Detail=@detail,
StatusCode=N'DRAFT',ReturnReason=NULL,UpdatedAt=SYSUTCDATETIME()
WHERE CompanyID=@c AND HandoverID=@id AND SiteProjectID=@project AND StatusCode IN(N'DRAFT',N'RETURNED')",ct,
            ("@c",Company),("@id",id),("@project",input.ProjectId),("@stage",input.StageName.Trim()),
            ("@type",input.Type),("@detail",input.Detail.Trim()));
        return changed==0?Conflict(new{message="แก้ไขไม่ได้",description="เอกสารถูกส่งหรือรับมอบแล้ว"}):NoContent();
    }
    [HttpPost("{id:long}/submit")]
    public async Task<IActionResult> Submit(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"63006","SUBMIT",ct) is { } no)return no;
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var rows=await SiteDb.Rows(db,tx,@"SELECT H.SiteProjectID projectId FROM dbo.TDSIHandover H WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDSIProject P ON P.CompanyID=H.CompanyID AND P.SiteProjectID=H.SiteProjectID
WHERE H.CompanyID=@c AND H.HandoverID=@id AND H.StatusCode=N'DRAFT' AND P.StatusCode=N'ACTIVE'
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=P.BranchID AND X.IsActive=1))",ct,
                ("@c",Company),("@id",id),("@actor",Actor));
            if(rows.Count==0){await tx.RollbackAsync(ct);return Conflict(new{message="ส่งมอบไม่ได้",description="ไม่พบร่างที่พร้อมส่งหรือไม่มีสิทธิ์สาขานี้"});}
            var project=Convert.ToInt64(rows[0]["projectId"]);
            await SiteDb.Exec(db,tx,@"UPDATE dbo.TDSIHandover SET StatusCode=N'SUBMITTED',SubmittedBy=@actor,
SubmittedAt=SYSUTCDATETIME(),UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@c AND HandoverID=@id",ct,
                ("@actor",Actor),("@c",Company),("@id",id));
            await SiteDb.Exec(db,tx,@"INSERT dbo.TDSINotification(CompanyID,SiteProjectID,AccessID,NotificationType,ReferenceID,Title)
SELECT @c,@project,AccessID,N'HANDOVER',@id,N'มีงานรอยืนยันรับมอบ' FROM dbo.TDSICustomerAccess
WHERE CompanyID=@c AND SiteProjectID=@project AND IsActive=1",ct,("@c",Company),("@project",project),("@id",id));
            await tx.CommitAsync(ct);
            return NoContent();
        }
        catch {await tx.RollbackAsync(ct);throw;}
    }
    static bool Valid(SiteHandoverRequest x)=>x.ProjectId>0&&!string.IsNullOrWhiteSpace(x.StageName)&&x.StageName.Length<=200
        &&x.Type is "STAGE" or "FINAL"&&!string.IsNullOrWhiteSpace(x.Detail)&&x.Detail.Length<=4000;
}
public sealed record SiteHandoverRequest(long ProjectId,string StageName,string Type,string Detail);
