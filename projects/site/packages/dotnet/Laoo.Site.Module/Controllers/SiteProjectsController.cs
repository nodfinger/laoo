using Laoo.Site;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.Site.Controllers;

[ApiController,Authorize,Route("api/company/site")]
public sealed class SiteProjectsController(IConfiguration config) : SiteControllerBase(config)
{
    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,menu,"VIEW",ct) is { } no)return no;
        var meta=await SiteDb.Rows(db,null,"SELECT MenuName,ScreenType,IconName FROM dbo.TDADMainMenu WHERE MenuCode=@menu",ct,("@menu",menu));
        if(meta.Count==0)return Missing();
        var allowed=new Dictionary<string,bool>();
        foreach(var action in new[]{"VIEW","CREATE","EDIT","DELETE","SUBMIT","REVIEW","PUBLISH","RETURN","ACCEPT"})
            allowed[action.ToLowerInvariant()]=await SiteAccess.Can(db,User,menu,action,ct);
        return Ok(new { metadata=meta[0],actions=allowed });
    }

    [HttpGet("options")]
    public async Task<IActionResult> Options(CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"63002","VIEW",ct) is { } no)return no;
        var customers=await SiteDb.Rows(db,null,"SELECT TOP 200 CustomerID id,MIN(CusCode) code,MIN(CusName) name FROM dbo.TDARCustomer WHERE CompanyID=@c AND IsActive=1 GROUP BY CustomerID ORDER BY MIN(CusName)",ct,("@c",Company));
        var items=await SiteDb.Rows(db,null,"SELECT TOP 200 ItemID id,ItemCode code,ItemName name FROM dbo.TDIVItem WHERE CompanyID=@c AND IsActive=1 ORDER BY ItemName",ct,("@c",Company));
        var employees=await SiteDb.Rows(db,null,"SELECT TOP 200 EmployeeID id,EmployeeCode code,FullName name FROM dbo.TDADEmployee WHERE CompanyID=@c AND IsActive=1 ORDER BY FullName",ct,("@c",Company));
        var branches=await SiteDb.Rows(db,null,@"SELECT B.BranchID id,B.BranchNameTH name FROM dbo.TDADBranch B
WHERE B.CompanyID=@c AND B.IsActive=1 AND
(EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=B.BranchID AND X.IsActive=1))
ORDER BY B.BranchNameTH",ct,("@c",Company),("@actor",Actor));
        return Ok(new {customers,items,employees,branches});
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"63001","VIEW",ct) is { } no)return no;
        var rows=await SiteDb.Rows(db,null,"SELECT MaxPhotoMB maxPhotoMB,AllowOfflineDraft allowOfflineDraft FROM dbo.TDSISetting WHERE CompanyID=@c",ct,("@c",Company));
        return Ok(rows.Count==0 ? new { maxPhotoMB=10,allowOfflineDraft=true } : (object)rows[0]);
    }

    [HttpPut("settings")]
    public async Task<IActionResult> Settings(SiteSettingsRequest input,CancellationToken ct)
    {
        if(input.MaxPhotoMB is <1 or >20)return Invalid("รูปต้องมีขนาดสูงสุดระหว่าง 1–20 MB");
        await using var db=await Open(ct);
        if(await Guard(db,"63001","EDIT",ct) is { } no)return no;
        await SiteDb.Exec(db,null,@"UPDATE dbo.TDSISetting SET MaxPhotoMB=@max,AllowOfflineDraft=@offline,UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@c;
IF @@ROWCOUNT=0 INSERT dbo.TDSISetting(CompanyID,MaxPhotoMB,AllowOfflineDraft) VALUES(@c,@max,@offline)",ct,
            ("@c",Company),("@max",input.MaxPhotoMB),("@offline",input.AllowOfflineDraft));
        return NoContent();
    }

    [HttpGet("projects")]
    public async Task<IActionResult> Projects(CancellationToken ct,int page=1,int pageSize=20,string? search=null)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("หน้าและจำนวนรายการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63002","VIEW",ct) is { } no)return no;
        var args=new (string,object?)[]{("@c",Company),("@actor",Actor),("@term",(search??"").Trim()),("@offset",(page-1)*pageSize),("@size",pageSize)};
        const string filter=@"P.CompanyID=@c AND (@term=N'' OR P.ProjectCode LIKE N'%'+@term+N'%' OR P.ProjectName LIKE N'%'+@term+N'%')
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=P.BranchID AND X.IsActive=1))";
        var total=await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDSIProject P WHERE "+filter,ct,args);
        var rows=await SiteDb.Rows(db,null,@"SELECT P.SiteProjectID id,P.ProjectCode code,P.ProjectName name,P.BranchID branchId,P.CustomerID customerId,
C.CusName customerName,P.SiteAddress address,P.StatusCode status,P.StartDate startDate,P.DueDate dueDate,
CONVERT(varchar(24),P.RowVersion,1) rowVersion,
COALESCE((SELECT SUM(T.Weight*T.ProgressPercent)/NULLIF(SUM(T.Weight),0) FROM dbo.TDSITask T WHERE T.CompanyID=P.CompanyID AND T.SiteProjectID=P.SiteProjectID AND T.IsActive=1),0) progressPercent
FROM dbo.TDSIProject P OUTER APPLY (SELECT TOP(1) C.CusName FROM dbo.TDARCustomer C
 WHERE C.CompanyID=P.CompanyID AND C.CustomerID=P.CustomerID ORDER BY C.CustomerID) C
WHERE "+filter+" ORDER BY P.SiteProjectID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,args);
        return Ok(new {items=rows,total,page,pageSize});
    }

    [HttpPost("projects")]
    public async Task<IActionResult> CreateProject(SiteProjectRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("ระบุรหัส ชื่อโครงการ ลูกค้า สาขา และช่วงวันที่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63002","CREATE",ct) is { } no)return no;
        if(!await ValidReferences(db,input,ct))return Invalid("ไม่พบลูกค้าหรือสาขาที่มีสิทธิ์ในบริษัทนี้");
        try
        {
            var id=await SiteDb.Scalar(db,null,@"INSERT dbo.TDSIProject(CompanyID,BranchID,CustomerID,ProjectCode,ProjectName,SiteAddress,Description,StartDate,DueDate,CreatedBy)
VALUES(@c,@branch,@customer,@code,@name,@address,@description,@start,@due,@actor);
SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,Args(input));
            return Created($"/api/company/site/projects/{id}",new{id});
        }
        catch(SqlException e) when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสโครงการซ้ำ",description="ใช้รหัสโครงการอื่นในบริษัทนี้"});}
    }

    [HttpPut("projects/{id:long}")]
    public async Task<IActionResult> UpdateProject(long id,SiteProjectRequest input,CancellationToken ct)
    {
        if(id<1||!Valid(input))return Invalid("ข้อมูลโครงการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"63002","EDIT",ct) is { } no)return no;
        if(!await ValidReferences(db,input,ct))return Invalid("ไม่พบลูกค้าหรือสาขาที่มีสิทธิ์");
        var changed=await SiteDb.Exec(db,null,@"UPDATE dbo.TDSIProject SET BranchID=@branch,CustomerID=@customer,ProjectCode=@code,ProjectName=@name,
SiteAddress=@address,Description=@description,StartDate=@start,DueDate=@due,UpdatedAt=SYSUTCDATETIME()
WHERE CompanyID=@c AND SiteProjectID=@id AND StatusCode<>N'CANCELLED' AND RowVersion=@version
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=TDSIProject.BranchID AND X.IsActive=1))",ct,
            Args(input).Concat([("@id",(object?)id),("@version",ParseVersion(input.RowVersion))]).ToArray());
        return changed==0?Conflict(new{message="แก้ไขไม่สำเร็จ",description="ข้อมูลอาจถูกแก้โดยผู้อื่นหรือไม่มีสิทธิ์สาขานี้"}):NoContent();
    }

    [HttpDelete("projects/{id:long}")]
    public async Task<IActionResult> CancelProject(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"63002","DELETE",ct) is { } no)return no;
        var changed=await SiteDb.Exec(db,null,@"UPDATE P SET StatusCode=N'CANCELLED',UpdatedAt=SYSUTCDATETIME() FROM dbo.TDSIProject P
WHERE P.CompanyID=@c AND P.SiteProjectID=@id AND P.StatusCode=N'ACTIVE'
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=P.BranchID AND X.IsActive=1))
AND NOT EXISTS(SELECT 1 FROM dbo.TDSIDailyReport R WHERE R.CompanyID=@c AND R.SiteProjectID=@id)
AND NOT EXISTS(SELECT 1 FROM dbo.TDSIHandover H WHERE H.CompanyID=@c AND H.SiteProjectID=@id)",ct,("@c",Company),("@id",id),("@actor",Actor));
        return changed==0?Conflict(new{message="ยกเลิกไม่ได้",description="ไม่พบรายการ หรือมีบันทึก/ส่งมอบงานแล้ว"}):NoContent();
    }

    bool Valid(SiteProjectRequest x)=>x.CustomerId>0&&x.BranchId>0&&!string.IsNullOrWhiteSpace(x.Code)&&x.Code.Length<=40
        &&!string.IsNullOrWhiteSpace(x.Name)&&x.Name.Length<=200&&(x.Address?.Length??0)<=1000&&(x.Description?.Length??0)<=2000
        &&(x.StartDate is null||x.DueDate is null||x.DueDate>=x.StartDate);
    async Task<bool> ValidReferences(SqlConnection db,SiteProjectRequest x,CancellationToken ct)
    {
        var customer=await SiteDb.Scalar(db,null,"SELECT COUNT(*) FROM dbo.TDARCustomer WHERE CompanyID=@c AND CustomerID=@id AND IsActive=1",ct,("@c",Company),("@id",x.CustomerId));
        var branch=await SiteDb.Scalar(db,null,@"SELECT COUNT(*) FROM dbo.TDADBranch B WHERE B.CompanyID=@c AND B.BranchID=@id AND B.IsActive=1
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=B.BranchID AND X.IsActive=1))",ct,
            ("@c",Company),("@id",x.BranchId),("@actor",Actor));
        return customer>0&&branch>0;
    }
    (string,object?)[] Args(SiteProjectRequest x)=>[("@c",Company),("@branch",x.BranchId),("@customer",x.CustomerId),
        ("@code",x.Code.Trim()),("@name",x.Name.Trim()),("@address",x.Address?.Trim()),("@description",x.Description?.Trim()),
        ("@start",x.StartDate),("@due",x.DueDate),("@actor",Actor)];
    static byte[] ParseVersion(string? value)
    {
        if(string.IsNullOrWhiteSpace(value))return [];
        try{return Convert.FromHexString(value.StartsWith("0x",StringComparison.OrdinalIgnoreCase)?value[2..]:value);}
        catch(FormatException){return [];}
    }
}
public sealed record SiteSettingsRequest(int MaxPhotoMB,bool AllowOfflineDraft);
public sealed record SiteProjectRequest(string Code,string Name,long CustomerId,long BranchId,string? Address,string? Description,DateOnly? StartDate,DateOnly? DueDate,string? RowVersion);
