using Laoo.Site;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
namespace Laoo.Site.Controllers;

[ApiController,Authorize,Route("api/company/site/projects/{projectId:long}/tasks")]
public sealed class SiteTasksController(IConfiguration config) : SiteControllerBase(config)
{
    [HttpGet]
    public async Task<IActionResult> List(long projectId,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"63002","VIEW",ct) is { } no)return no;
        if(!await ProjectInScope(db,projectId,ct))return Missing();
        var rows=await SiteDb.Rows(db,null,@"SELECT SiteTaskID id,TaskName name,Weight weight,ProgressPercent progressPercent,
SortOrder sortOrder,IsActive active FROM dbo.TDSITask WHERE CompanyID=@c AND SiteProjectID=@project ORDER BY SortOrder,SiteTaskID",ct,
            ("@c",Company),("@project",projectId));
        return Ok(rows);
    }
    [HttpPost]
    public async Task<IActionResult> Create(long projectId,SiteTaskRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("ระบุชื่องาน น้ำหนัก และความคืบหน้า 0–100");
        await using var db=await Open(ct);
        if(await Guard(db,"63002","EDIT",ct) is { } no)return no;
        if(!await ProjectInScope(db,projectId,ct))return Missing();
        var id=await SiteDb.Scalar(db,null,@"INSERT dbo.TDSITask(CompanyID,SiteProjectID,TaskName,Weight,ProgressPercent,SortOrder)
VALUES(@c,@project,@name,@weight,@progress,@sort);SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,
            ("@c",Company),("@project",projectId),("@name",input.Name.Trim()),("@weight",input.Weight),
            ("@progress",input.ProgressPercent),("@sort",input.SortOrder));
        return Created($"/api/company/site/projects/{projectId}/tasks/{id}",new{id});
    }
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long projectId,long id,SiteTaskRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("ข้อมูลงานย่อยไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63002","EDIT",ct) is { } no)return no;
        if(!await ProjectInScope(db,projectId,ct))return Missing();
        var changed=await SiteDb.Exec(db,null,@"UPDATE dbo.TDSITask SET TaskName=@name,Weight=@weight,ProgressPercent=@progress,
SortOrder=@sort,IsActive=@active,UpdatedAt=SYSUTCDATETIME()
WHERE CompanyID=@c AND SiteProjectID=@project AND SiteTaskID=@id",ct,
            ("@c",Company),("@project",projectId),("@id",id),("@name",input.Name.Trim()),("@weight",input.Weight),
            ("@progress",input.ProgressPercent),("@sort",input.SortOrder),("@active",input.Active));
        return changed==0?Missing():NoContent();
    }
    static bool Valid(SiteTaskRequest x)=>!string.IsNullOrWhiteSpace(x.Name)&&x.Name.Length<=200
        &&x.Weight>0&&x.Weight<=100&&x.ProgressPercent is >=0 and <=100&&x.SortOrder>=0;
}
public sealed record SiteTaskRequest(string Name,decimal Weight,decimal ProgressPercent,int SortOrder,bool Active=true);
