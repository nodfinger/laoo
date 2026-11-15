using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooGatePassModule.Controllers;

[ApiController, Authorize, Route("api/company/gate-pass")]
public sealed class GatePassDataController(IConfiguration config,IWebHostEnvironment environment) : ControllerBase
{
    [HttpGet("settings")]
    public Task<IActionResult> Settings(CancellationToken t) => Read("38001", "SELECT s.IsEnabled,s.DefaultReturnDays,s.DefaultApproverUserID,u.DisplayName DefaultApproverName,s.MaxAttachmentSizeMB,s.MaxAttachmentsPerStage,s.DefaultQrExpiryDays FROM dbo.TDGPSetting s LEFT JOIN dbo.TDADUser u ON u.CompanyID=s.CompanyID AND u.UserID=s.DefaultApproverUserID WHERE s.CompanyID=@company", t);

    [HttpGet("approver-options")]
    public Task<IActionResult> ApproverOptions(CancellationToken t) => Read("38001", "SELECT UserID Id,Username Code,COALESCE(NULLIF(DisplayName,N''),Username) Name FROM dbo.TDADUser WHERE CompanyID=@company AND IsActive=1 ORDER BY COALESCE(NULLIF(DisplayName,N''),Username)", t);

    [HttpPut("settings")]
    public async Task<IActionResult> UpdateSettings(SettingInput input,CancellationToken t)
    {
        if(!Scope(out var company,out var user)||input.DefaultReturnDays is < 1 or > 365||input.MaxAttachmentSizeMB is <=0 or >1||input.MaxAttachmentsPerStage is <=0 or >20||input.DefaultQrExpiryDays is <1 or >365)return BadRequest(new {message="ข้อมูลไม่ถูกต้อง",description="วันรับคืนและอายุ QR 1-365 วัน, รูปหลังย่อไม่เกิน 1 MB และไม่เกิน 20 รูปต่อขั้นตอน"});
        await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38001","EDIT",t))return Forbid();
        if(input.DefaultApproverUserID is not null){await using var valid=new SqlCommand("SELECT COUNT(*) FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@approver AND IsActive=1",db);valid.Parameters.Add("@company",SqlDbType.BigInt).Value=company;valid.Parameters.Add("@approver",SqlDbType.BigInt).Value=input.DefaultApproverUserID.Value;if(Convert.ToInt32(await valid.ExecuteScalarAsync(t))!=1)return BadRequest(new{message="ผู้อนุมัติไม่ถูกต้อง",description="กรุณาเลือกผู้ใช้งานที่ Active ในบริษัทนี้"});}
        await using var cmd=new SqlCommand("UPDATE dbo.TDGPSetting SET IsEnabled=@enabled,DefaultReturnDays=@days,DefaultApproverUserID=@approver,MaxAttachmentSizeMB=COALESCE(@maxMb,MaxAttachmentSizeMB),MaxAttachmentsPerStage=COALESCE(@maxCount,MaxAttachmentsPerStage),DefaultQrExpiryDays=COALESCE(@qrDays,DefaultQrExpiryDays),UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company;IF @@ROWCOUNT=0 INSERT dbo.TDGPSetting(CompanyID,IsEnabled,DefaultReturnDays,DefaultApproverUserID,MaxAttachmentSizeMB,MaxAttachmentsPerStage,DefaultQrExpiryDays,UpdateBy) VALUES(@company,@enabled,@days,@approver,COALESCE(@maxMb,1),COALESCE(@maxCount,5),COALESCE(@qrDays,1),@user);",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@enabled",SqlDbType.Bit).Value=input.IsEnabled;cmd.Parameters.Add("@days",SqlDbType.Int).Value=input.DefaultReturnDays;cmd.Parameters.Add("@approver",SqlDbType.BigInt).Value=(object?)input.DefaultApproverUserID??DBNull.Value;cmd.Parameters.Add("@maxMb",SqlDbType.Decimal).Value=(object?)input.MaxAttachmentSizeMB??DBNull.Value;cmd.Parameters.Add("@maxCount",SqlDbType.Int).Value=(object?)input.MaxAttachmentsPerStage??DBNull.Value;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        cmd.Parameters.Add("@qrDays",SqlDbType.Int).Value=(object?)input.DefaultQrExpiryDays??DBNull.Value;
        await cmd.ExecuteNonQueryAsync(t);return NoContent();
    }

    [HttpGet("purposes")]
    public Task<IActionResult> Purposes(CancellationToken t) => Read("38002", "SELECT PurposeID Id,PurposeCode Code,PurposeName Name,ReturnDays,AlwaysReturnRequired,IsActive FROM dbo.TDGPPurpose WHERE CompanyID=@company ORDER BY PurposeCode", t);

    [HttpGet("purposes/default-return-days")]
    public async Task<IActionResult> PurposeDefaultReturnDays(CancellationToken t)
    {
        if (!Scope(out var company, out _)) return Forbid();
        await using var db = await Open(t);
        if (!await CompanyMenuAccess.IsAllowedAsync(db, User, "38002", "VIEW", t)) return Forbid();
        await using var cmd = new SqlCommand("SELECT COALESCE((SELECT DefaultReturnDays FROM dbo.TDGPSetting WHERE CompanyID=@company),7)", db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
        return Ok(new { defaultReturnDays=Convert.ToInt32(await cmd.ExecuteScalarAsync(t)) });
    }

    [HttpGet("requests")]
    public Task<IActionResult> Requests(CancellationToken t) => Read("38003", """
SELECT g.GatePassID Id,g.GatePassNo Number,g.StatusCode Status,g.CarrierName Carrier,g.CarrierPhone,g.DestinationName Destination,
 g.DocumentDateTime,g.PlannedExitDate,g.Remark,g.PurposeID PurposeId,p.PurposeName Purpose,g.IsReturnRequired,g.HandedOverAt,g.ExitCheckedAt,g.ReturnedAt,
 CONVERT(bit,CASE WHEN g.RequesterUserID=@user THEN 1 ELSE 0 END) IsOwner,
 emp.DepartmentOrgUnitID DepartmentId,emp.DepartmentName,
 CASE COALESCE(setup.EmployeeNameDisplay,'FULL')
   WHEN 'NICK' THEN COALESCE(NULLIF(LTRIM(RTRIM(emp.NickName)),N''),NULLIF(emp.FullName,N''),u.DisplayName,u.Username)
   WHEN 'BOTH' THEN COALESCE(NULLIF(emp.FullName,N''),u.DisplayName,u.Username,N'')+CASE WHEN NULLIF(LTRIM(RTRIM(emp.NickName)),N'') IS NULL THEN N'' ELSE N' ('+emp.NickName+N')' END
   ELSE COALESCE(NULLIF(emp.FullName,N''),u.DisplayName,u.Username) END RequesterName
FROM dbo.TDGPGatePass g
LEFT JOIN dbo.TDGPPurpose p ON p.CompanyID=g.CompanyID AND p.PurposeID=g.PurposeID
LEFT JOIN dbo.TDADUser u ON u.CompanyID=g.CompanyID AND u.UserID=g.RequesterUserID
OUTER APPLY (SELECT TOP(1) e.FullName,e.NickName,e.DepartmentOrgUnitID,d.NameTH DepartmentName FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID LEFT JOIN dbo.TDADOrganizationUnit d ON d.CompanyID=e.CompanyID AND d.OrgUnitID=e.DepartmentOrgUnitID WHERE ue.CompanyID=g.CompanyID AND ue.UserID=g.RequesterUserID ORDER BY ue.IsActive DESC,e.IsActive DESC,e.EmployeeID) emp
OUTER APPLY (SELECT TOP(1) EmployeeNameDisplay FROM dbo.TDSTCompanySetUp WHERE CompanyID=g.CompanyID AND OwnerType='C' AND IsActive=1) setup
WHERE g.CompanyID=@company AND (g.RequesterUserID=@user OR g.StatusCode<>N'DRAFT') AND dbo.LaooMenuDataAccessAllowed(@company,@user,g.RequesterUserID,N'38003','VIEW')=1
ORDER BY g.CreateDate DESC
""", t);

    [HttpGet("request-departments")]
    public Task<IActionResult> RequestDepartments(CancellationToken t) => Read("38003", """
SELECT o.OrgUnitID Id,o.NameTH Name FROM dbo.TDADOrganizationUnit o
WHERE o.CompanyID=@company AND o.OwnerType='C' AND o.UnitType='DEP' AND o.IsActive=1
AND (dbo.LaooMenuDataAccessAllowed(@company,@user,0,N'38003','VIEW')=1 OR EXISTS(
 SELECT 1 FROM dbo.TDGPGatePass g JOIN dbo.TDADUserEmployee ue ON ue.CompanyID=g.CompanyID AND ue.UserID=g.RequesterUserID AND ue.IsActive=1
 JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID AND e.IsActive=1
 WHERE g.CompanyID=@company AND (g.RequesterUserID=@user OR g.StatusCode<>N'DRAFT') AND e.DepartmentOrgUnitID=o.OrgUnitID AND dbo.LaooMenuDataAccessAllowed(@company,@user,g.RequesterUserID,N'38003','VIEW')=1))
ORDER BY o.NameTH
""", t);

    [HttpGet("purpose-options")]
    public Task<IActionResult> PurposeOptions(CancellationToken t) => Read("38003", "SELECT p.PurposeID Id,p.PurposeCode Code,p.PurposeName Name,COALESCE(p.ReturnDays,s.DefaultReturnDays,7) ReturnDays,p.AlwaysReturnRequired FROM dbo.TDGPPurpose p LEFT JOIN dbo.TDGPSetting s ON s.CompanyID=p.CompanyID WHERE p.CompanyID=@company AND p.IsActive=1 ORDER BY p.PurposeCode", t);

    [HttpGet("approvals")]
    public Task<IActionResult> Approvals(CancellationToken t) => Read("38004", "SELECT GatePassID Id,GatePassNo Number,CarrierName Carrier,DestinationName Destination FROM dbo.TDGPGatePass WHERE CompanyID=@company AND StatusCode=N'PENDING_APPROVAL' ORDER BY CreateDate", t);

    [HttpGet("exit-check")]
    public Task<IActionResult> ExitCheck(CancellationToken t) => Read("38005", "SELECT GatePassID Id,GatePassNo Number,CarrierName Carrier,DestinationName Destination,ExitCheckedAt FROM dbo.TDGPGatePass WHERE CompanyID=@company AND StatusCode=N'HANDED_OVER' AND ExitCheckedAt IS NULL ORDER BY HandedOverAt", t);

    [HttpGet("returns")]
    public Task<IActionResult> Returns(CancellationToken t) => Read("38006", """
SELECT g.GatePassID Id,g.GatePassNo Number,g.CarrierName Carrier,g.CarrierPhone,g.DestinationName Destination,
 g.ExpectedReturnDate,g.ReturnedAt,g.DocumentDateTime,g.PlannedExitDate,g.Remark,g.PurposeID PurposeId,p.PurposeName Purpose,
 emp.DepartmentOrgUnitID DepartmentId,emp.DepartmentName
FROM dbo.TDGPGatePass g
LEFT JOIN dbo.TDGPPurpose p ON p.CompanyID=g.CompanyID AND p.PurposeID=g.PurposeID
OUTER APPLY (SELECT TOP(1) e.DepartmentOrgUnitID,d.NameTH DepartmentName FROM dbo.TDADUserEmployee ue
 JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID
 LEFT JOIN dbo.TDADOrganizationUnit d ON d.CompanyID=e.CompanyID AND d.OrgUnitID=e.DepartmentOrgUnitID
 WHERE ue.CompanyID=g.CompanyID AND ue.UserID=g.RequesterUserID
 ORDER BY ue.IsActive DESC,e.IsActive DESC,e.EmployeeID) emp
WHERE g.CompanyID=@company AND g.StatusCode=N'HANDED_OVER' AND g.IsReturnRequired=1 AND g.ExitCheckedAt IS NOT NULL AND g.ReturnedAt IS NULL
 AND dbo.LaooMenuDataAccessAllowed(@company,@user,g.RequesterUserID,N'38006','VIEW')=1
ORDER BY g.ExpectedReturnDate
""", t);

    [HttpGet("mine")]
    public Task<IActionResult> Mine(CancellationToken t) => Read("38007", "SELECT GatePassID Id,GatePassNo Number,StatusCode Status,CarrierName Carrier,DestinationName Destination,ExitCheckedAt FROM dbo.TDGPGatePass WHERE CompanyID=@company AND RequesterUserID=@user ORDER BY CreateDate DESC", t);

    [HttpGet("dashboard")]
    public Task<IActionResult> Dashboard(CancellationToken t) => Read("38008", "SELECT COUNT(*) Total,SUM(CASE WHEN StatusCode=N'HANDED_OVER' THEN 1 ELSE 0 END) HandedOver,SUM(CASE WHEN ExitCheckedAt IS NOT NULL THEN 1 ELSE 0 END) ExitChecked,SUM(CASE WHEN StatusCode=N'RETURNED' THEN 1 ELSE 0 END) Returned FROM dbo.TDGPGatePass WHERE CompanyID=@company", t);

    [HttpPost("purposes")]
    public async Task<IActionResult> CreatePurpose(PurposeInput input,CancellationToken t)
    {
        if(!Scope(out var company,out var user)||string.IsNullOrWhiteSpace(input.Name)||input.ReturnDays is < 1 or > 365||(input.AlwaysReturnRequired==true && input.ClearReturnDays==true)) return BadRequest(new {message="ข้อมูลไม่ถูกต้อง",description="เมื่อบังคับนำกลับ กรุณาระบุจำนวนวันรับคืน 1 ถึง 365 วัน"});
        await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38002","CREATE",t))return Forbid();
        await using var cmd=new SqlCommand("""
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @lockResult int, @lockResource nvarchar(255)=N'GatePass:PurposeCode:'+CONVERT(nvarchar(30),@company);
EXEC @lockResult=sys.sp_getapplock @Resource=@lockResource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
IF @lockResult<0 THROW 50001,'PURPOSE_CODE_LOCK_FAILED',1;
DECLARE @generated nvarchar(30)=@code;
IF @generated IS NULL SELECT @generated=CONVERT(nvarchar(30),COALESCE(MAX(TRY_CONVERT(bigint,PurposeCode)),0)+1) FROM dbo.TDGPPurpose WHERE CompanyID=@company;
INSERT dbo.TDGPPurpose(CompanyID,PurposeCode,PurposeName,ReturnDays,AlwaysReturnRequired,IsActive,CreateBy) OUTPUT INSERTED.PurposeID VALUES(@company,@generated,@name,CASE WHEN @clear=1 THEN NULL ELSE COALESCE(@days,(SELECT DefaultReturnDays FROM dbo.TDGPSetting WHERE CompanyID=@company),7) END,COALESCE(@always,0),@active,@user);
COMMIT TRANSACTION;
""",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@code",SqlDbType.NVarChar,30).Value=string.IsNullOrWhiteSpace(input.Code) ? DBNull.Value : input.Code.Trim().ToUpperInvariant();cmd.Parameters.Add("@name",SqlDbType.NVarChar,200).Value=input.Name.Trim();cmd.Parameters.Add("@active",SqlDbType.Bit).Value=input.IsActive;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        cmd.Parameters.Add("@days",SqlDbType.Int).Value=(object?)input.ReturnDays??DBNull.Value;
        cmd.Parameters.Add("@always",SqlDbType.Bit).Value=(object?)input.AlwaysReturnRequired??DBNull.Value;
        cmd.Parameters.Add("@clear",SqlDbType.Bit).Value=input.ClearReturnDays==true;
        try{return Ok(new{id=Convert.ToInt64(await cmd.ExecuteScalarAsync(t))});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสซ้ำ",description="รหัสวัตถุประสงค์นี้มีอยู่แล้ว"});}
    }

    [HttpPut("purposes/{id:long}")]
    public async Task<IActionResult> UpdatePurpose(long id,PurposeInput input,CancellationToken t)
    {
        if(!Scope(out var company,out var user)||string.IsNullOrWhiteSpace(input.Name)||input.ReturnDays is < 1 or > 365||(input.AlwaysReturnRequired==true && input.ClearReturnDays==true)) return BadRequest(new {message="ข้อมูลไม่ถูกต้อง",description="เมื่อบังคับนำกลับ กรุณาระบุจำนวนวันรับคืน 1 ถึง 365 วัน"});
        await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38002","EDIT",t))return Forbid();
        await using var cmd=new SqlCommand("UPDATE dbo.TDGPPurpose SET PurposeCode=COALESCE(@code,PurposeCode),PurposeName=@name,ReturnDays=CASE WHEN @clear=1 THEN NULL ELSE COALESCE(@days,ReturnDays) END,AlwaysReturnRequired=COALESCE(@always,AlwaysReturnRequired),IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE PurposeID=@id AND CompanyID=@company AND NOT(COALESCE(@always,AlwaysReturnRequired)=1 AND (CASE WHEN @clear=1 THEN NULL ELSE COALESCE(@days,ReturnDays) END) IS NULL)",db);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@code",SqlDbType.NVarChar,30).Value=string.IsNullOrWhiteSpace(input.Code) ? DBNull.Value : input.Code.Trim().ToUpperInvariant();cmd.Parameters.Add("@name",SqlDbType.NVarChar,200).Value=input.Name.Trim();cmd.Parameters.Add("@active",SqlDbType.Bit).Value=input.IsActive;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        cmd.Parameters.Add("@days",SqlDbType.Int).Value=(object?)input.ReturnDays??DBNull.Value;
        cmd.Parameters.Add("@always",SqlDbType.Bit).Value=(object?)input.AlwaysReturnRequired??DBNull.Value;
        cmd.Parameters.Add("@clear",SqlDbType.Bit).Value=input.ClearReturnDays==true;
        try{
            if(await cmd.ExecuteNonQueryAsync(t)==1)return NoContent();
            await using var exists=new SqlCommand("SELECT COUNT(*) FROM dbo.TDGPPurpose WHERE PurposeID=@id AND CompanyID=@company",db);
            exists.Parameters.Add("@id",SqlDbType.BigInt).Value=id;exists.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
            return Convert.ToInt32(await exists.ExecuteScalarAsync(t))>0
                ? BadRequest(new {message="ข้อมูลไม่ถูกต้อง",description="เมื่อบังคับนำกลับ กรุณาระบุจำนวนวันรับคืน 1 ถึง 365 วัน"})
                : NotFound(new {message="ไม่พบข้อมูล",description="ไม่พบวัตถุประสงค์ในบริษัทนี้"});
        }catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสซ้ำ",description="รหัสวัตถุประสงค์นี้มีอยู่แล้ว"});}
    }

    [HttpDelete("purposes/{id:long}")]
    public async Task<IActionResult> DeletePurpose(long id,CancellationToken t)
    {
        if(!Scope(out var company,out _))return Forbid();await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38002","DELETE",t))return Forbid();
        await using var cmd=new SqlCommand("DELETE dbo.TDGPPurpose WHERE PurposeID=@id AND CompanyID=@company",db);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
        try{return await cmd.ExecuteNonQueryAsync(t)==1?NoContent():NotFound(new {message="ไม่พบข้อมูล",description="ไม่พบวัตถุประสงค์ในบริษัทนี้"});}catch(SqlException e)when(e.Number==547){return Conflict(new{message="ลบไม่ได้",description="วัตถุประสงค์นี้ถูกใช้อ้างอิงในใบขอนำทรัพย์สินออกแล้ว"});}
    }

    [HttpGet("actions/{menuCode}")]
    public async Task<IActionResult> Actions(string menuCode,CancellationToken t)
    {
        var known=new[]{"38001","38002","38003","38004","38005","38006","38007","38008"};
        if(!known.Contains(menuCode,StringComparer.Ordinal))return NotFound();
        if(!Scope(out _,out _))return Forbid();await using var db=await Open(t);
        if(!await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"VIEW",t))return Forbid();
        return Ok(new {
            create=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"CREATE",t),
            edit=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"EDIT",t),
            delete=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"DELETE",t),
            print=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"PRINT",t) && await PrintEnabled(db,menuCode,t),
            submit=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"SUBMIT",t),
            approve=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"APPROVE",t),
            confirmExit=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"CONFIRM_EXIT",t),
            confirmReturn=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"CONFIRM_RETURN",t)
        });
    }

    private static async Task<bool> PrintEnabled(SqlConnection db,string menu,CancellationToken t)
    {
        await using var cmd=new SqlCommand("SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1 AND AllowPrint=1) THEN 1 ELSE 0 END AS bit)",db);
        cmd.Parameters.Add("@menu",SqlDbType.NVarChar,20).Value=menu;
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(t));
    }

    [HttpGet("requests/{id:long}/print")]
    public async Task<IActionResult> PrintRequest(long id,CancellationToken t)
    {
        if(!Scope(out var company,out _))return Forbid();
        await using var db=await Open(t);
        if(!await PrintEnabled(db,"38003",t)||!await CompanyMenuAccess.IsAllowedAsync(db,User,"38003","PRINT",t))return Forbid();
        var detail=await GetRequest(id,"38003",t);
        if(detail is not OkObjectResult { Value: Dictionary<string,object?> result })return detail;
        await using(var companyName=new SqlCommand("SELECT TOP(1) COALESCE(NULLIF(CustomerNameTH,N''),CompanyCode) FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND OwnerType='C' AND IsActive=1",db)){
            companyName.Parameters.Add("@company",SqlDbType.BigInt).Value=company;result["companyName"]=await companyName.ExecuteScalarAsync(t);
        }
        await using(var logo=new SqlCommand("SELECT ImageData FROM dbo.TDSTCompanyLogo WHERE CompanyID=@company",db)){
            logo.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
            if(await logo.ExecuteScalarAsync(t) is byte[] logoBytes){using var image=SkiaSharp.SKBitmap.Decode(logoBytes);if(image is not null){using var encoded=image.Encode(SkiaSharp.SKEncodedImageFormat.Png,100);result["companyLogo"]=Convert.ToBase64String(encoded.ToArray());}}
        }
        await using var cmd=new SqlCommand("SELECT GatePassItemID,FileName,ContentType,FileData FROM dbo.TDGPGatePassRequestFile WHERE CompanyID=@company AND GatePassID=@id ORDER BY RequestFileID",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;
        await using var reader=await cmd.ExecuteReaderAsync(t);var files=new List<object>();
        while(await reader.ReadAsync(t)){
            var type=reader.GetString(2);var bytes=(byte[])reader[3];string? image=null;
            if(type.StartsWith("image/",StringComparison.OrdinalIgnoreCase)){
                using var data=SkiaSharp.SKData.CreateCopy(bytes);using var bitmap=SkiaSharp.SKBitmap.Decode(data);
                if(bitmap is not null){using var encoded=bitmap.Encode(SkiaSharp.SKEncodedImageFormat.Png,100);image=Convert.ToBase64String(encoded.ToArray());}
            }
            files.Add(new{itemId=reader.IsDBNull(0)?null:(long?)reader.GetInt64(0),fileName=reader.GetString(1),image});
        }
        await reader.CloseAsync();
        await using(var purposes=new SqlCommand("SELECT i.GatePassItemID,p.PurposeName FROM dbo.TDGPGatePassItem i LEFT JOIN dbo.TDGPPurpose p ON p.CompanyID=i.CompanyID AND p.PurposeID=i.PurposeID WHERE i.CompanyID=@company AND i.GatePassID=@id",db)){
            purposes.Parameters.Add("@company",SqlDbType.BigInt).Value=company;purposes.Parameters.Add("@id",SqlDbType.BigInt).Value=id;
            await using var purposeReader=await purposes.ExecuteReaderAsync(t);
            var itemRows=(List<Dictionary<string,object?>>)result["items"]!;
            while(await purposeReader.ReadAsync(t)){var item=itemRows.FirstOrDefault(x=>Convert.ToInt64(x["id"])==purposeReader.GetInt64(0));if(item is not null)item["purposeName"]=purposeReader.IsDBNull(1)?null:purposeReader.GetString(1);}
        }
        result["files"]=files;return Ok(result);
    }

    [HttpPost("requests")]
    public async Task<IActionResult> CreateRequest(RequestInput input,CancellationToken t)
    {
        if(!Scope(out var company,out var user)||!ValidRequest(input)) return BadRequest(new {message="ข้อมูลไม่ครบ",description="กรุณาระบุวัตถุประสงค์ ผู้รับมอบ เบอร์โทร ปลายทาง และทรัพย์สินอย่างน้อยหนึ่งรายการ"});
        await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38003","CREATE",t))return Forbid();if(!await SystemEnabled(db,company,t))return Conflict(new{message="ระบบปิดใช้งาน",description="ไม่สามารถสร้างใบขอใหม่ได้ในขณะนี้"});await using var tx=(SqlTransaction)await db.BeginTransactionAsync(t);
        try{
          if(!await ValidPurpose(db,tx,company,input.PurposeId,t)||!await ValidItemPurposes(db,tx,company,input.Items!,t)){await tx.RollbackAsync(t);return BadRequest(new{message="วัตถุประสงค์ไม่ถูกต้อง",description="กรุณาเลือกวัตถุประสงค์ที่เปิดใช้งานในบริษัทนี้"});}
          input=await ApplyRequiredReturns(db,tx,company,input,t);
          await using var header=new SqlCommand("INSERT dbo.TDGPGatePass(CompanyID,GatePassNo,PurposeID,RequesterUserID,CarrierName,CarrierPhone,DestinationName,DocumentDateTime,PlannedExitDate,ExpectedReturnDate,IsReturnRequired,Remark,CreateBy) OUTPUT INSERTED.GatePassID VALUES(@company,N'GP'+FORMAT(SYSUTCDATETIME(),'yyyyMMddHHmmss')+RIGHT(CONVERT(nvarchar(36),NEWID()),4),@purpose,@user,@carrier,@phone,@destination,COALESCE(@docDate,SYSUTCDATETIME()),COALESCE(@exitDate,CONVERT(date,COALESCE(@docDate,SYSUTCDATETIME()))),CASE WHEN @returns=1 THEN DATEADD(DAY,COALESCE((SELECT DefaultReturnDays FROM dbo.TDGPSetting WHERE CompanyID=@company),7),SYSUTCDATETIME()) END,@returns,@remark,@user)",db,tx);
          header.Parameters.Add("@company",SqlDbType.BigInt).Value=company;header.Parameters.Add("@purpose",SqlDbType.BigInt).Value=input.PurposeId!.Value;header.Parameters.Add("@user",SqlDbType.BigInt).Value=user;header.Parameters.Add("@carrier",SqlDbType.NVarChar,200).Value=input.Carrier!.Trim();header.Parameters.Add("@destination",SqlDbType.NVarChar,300).Value=input.Destination!.Trim();header.Parameters.Add("@returns",SqlDbType.Bit).Value=input.IsReturnRequired;header.Parameters.Add("@remark",SqlDbType.NVarChar,1000).Value=(object?)input.Remark??DBNull.Value;
          header.Parameters["@returns"].Value=RequiresReturn(input);AddDocumentFields(header,input);
          var id=Convert.ToInt64(await header.ExecuteScalarAsync(t));
          var itemIds=await SaveItems(db,tx,id,company,input.Items!,input.IsReturnRequired,t);
          await UpdateReturnSummary(db,tx,id,company,t);
          await tx.CommitAsync(t);return Ok(new{id,itemIds});
        }catch{await tx.RollbackAsync(t);throw;}
    }

    [HttpGet("requests/{id:long}")]
    public async Task<IActionResult> GetRequest(long id,[FromQuery] string? menu,CancellationToken t)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);
        var viewMenus=new[]{"38003","38004","38005","38006","38007","38008"};var allowedMenus=new List<string>();
        if(!string.IsNullOrEmpty(menu)){if(!viewMenus.Contains(menu,StringComparer.Ordinal))return Forbid();viewMenus=[menu];}
        foreach(var viewMenu in viewMenus)if(await CompanyMenuAccess.IsAllowedAsync(db,User,viewMenu,"VIEW",t))allowedMenus.Add(viewMenu);
        if(allowedMenus.Count==0)return Forbid();
        var checks=string.Join(" OR ",allowedMenus.Select((viewMenu,i)=>viewMenu=="38007" ? $"(g.RequesterUserID=@user AND dbo.LaooMenuDataAccessAllowed(@company,@user,g.RequesterUserID,@viewMenu{i},'VIEW')=1)" : $"dbo.LaooMenuDataAccessAllowed(@company,@user,g.RequesterUserID,@viewMenu{i},'VIEW')=1"));
        await using var header=new SqlCommand($"SELECT g.GatePassID Id,g.GatePassNo Number,g.PurposeID,g.CarrierName Carrier,g.CarrierPhone,g.DestinationName Destination,g.DocumentDateTime,g.PlannedExitDate,g.ExpectedReturnDate,g.IsReturnRequired,g.Remark,g.StatusCode Status,p.PurposeName Purpose FROM dbo.TDGPGatePass g LEFT JOIN dbo.TDGPPurpose p ON p.CompanyID=g.CompanyID AND p.PurposeID=g.PurposeID WHERE g.GatePassID=@id AND g.CompanyID=@company AND (g.RequesterUserID=@user OR g.StatusCode<>N'DRAFT') AND ({checks})",db);
        for(var i=0;i<allowedMenus.Count;i++)header.Parameters.Add($"@viewMenu{i}",SqlDbType.NVarChar,20).Value=allowedMenus[i];
        header.Parameters.Add("@id",SqlDbType.BigInt).Value=id;header.Parameters.Add("@company",SqlDbType.BigInt).Value=company;header.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        await using var reader=await header.ExecuteReaderAsync(t);if(!await reader.ReadAsync(t))return NotFound(new{message="ไม่พบเอกสาร",description="ไม่พบใบขอนำทรัพย์สินออกในขอบเขตข้อมูลของคุณ"});
        var result=new Dictionary<string,object?>();for(var i=0;i<reader.FieldCount;i++){var key=reader.GetName(i);result[char.ToLowerInvariant(key[0])+key[1..]]=reader.IsDBNull(i)?null:reader.GetValue(i);}await reader.CloseAsync();
        await using var detail=new SqlCommand("SELECT GatePassItemID Id,ItemName Name,Quantity,UnitName Unit,SerialNo,IsReturnRequired,PurposeID,Remark,ExpectedReturnDate FROM dbo.TDGPGatePassItem WHERE GatePassID=@id AND CompanyID=@company ORDER BY GatePassItemID",db);detail.Parameters.Add("@id",SqlDbType.BigInt).Value=id;detail.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
        await using var details=await detail.ExecuteReaderAsync(t);var items=new List<Dictionary<string,object?>>();while(await details.ReadAsync(t)){items.Add(new(){["id"]=details.GetInt64(0),["name"]=details.GetString(1),["quantity"]=details.GetDecimal(2),["unit"]=details.IsDBNull(3)?null:details.GetString(3),["serialNo"]=details.IsDBNull(4)?null:details.GetString(4),["isReturnRequired"]=details.GetBoolean(5),["purposeId"]=details.IsDBNull(6)?null:details.GetInt64(6),["remark"]=details.IsDBNull(7)?null:details.GetString(7),["expectedReturnDate"]=details.IsDBNull(8)?null:details.GetDateTime(8)});}result["items"]=items;return Ok(result);
    }

    [HttpPut("requests/{id:long}")]
    public async Task<IActionResult> UpdateRequest(long id,RequestInput input,CancellationToken t)
    {
        if(!ValidRequest(input))return BadRequest(new {message="ข้อมูลไม่ครบ",description="กรุณาระบุผู้รับมอบ เบอร์โทร ปลายทาง และทรัพย์สินอย่างน้อยหนึ่งรายการ"});
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38003","EDIT",t))return Forbid();await using var tx=(SqlTransaction)await db.BeginTransactionAsync(t);
        try{
          if(!await ValidPurpose(db,tx,company,input.PurposeId,t)||!await ValidItemPurposes(db,tx,company,input.Items!,t)){await tx.RollbackAsync(t);return BadRequest(new{message="วัตถุประสงค์ไม่ถูกต้อง",description="กรุณาเลือกวัตถุประสงค์ที่เปิดใช้งานในบริษัทนี้"});}
          input=await ApplyRequiredReturns(db,tx,company,input,t);
          await using var header=new SqlCommand("UPDATE dbo.TDGPGatePass SET PurposeID=@purpose,CarrierName=@carrier,CarrierPhone=@phone,DestinationName=@destination,DocumentDateTime=COALESCE(@docDate,DocumentDateTime),PlannedExitDate=COALESCE(@exitDate,PlannedExitDate,CONVERT(date,COALESCE(@docDate,DocumentDateTime,CreateDate))),ExpectedReturnDate=CASE WHEN @returns=1 THEN COALESCE(ExpectedReturnDate,DATEADD(DAY,COALESCE((SELECT DefaultReturnDays FROM dbo.TDGPSetting WHERE CompanyID=@company),7),SYSUTCDATETIME())) END,IsReturnRequired=@returns,Remark=@remark,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE GatePassID=@id AND CompanyID=@company AND RequesterUserID=@user AND StatusCode=N'DRAFT'",db,tx);
          AddRequestHeader(header,id,company,user,input);header.Parameters["@returns"].Value=RequiresReturn(input);AddDocumentFields(header,input);if(await header.ExecuteNonQueryAsync(t)!=1){await tx.RollbackAsync(t);return Conflict(new{message="แก้ไขไม่ได้",description="แก้ไขได้เฉพาะเอกสารร่างของผู้ขอ"});}
          var itemIds=await SaveItems(db,tx,id,company,input.Items!,input.IsReturnRequired,t);await UpdateReturnSummary(db,tx,id,company,t);await tx.CommitAsync(t);return Ok(new{id,itemIds});
        }catch{await tx.RollbackAsync(t);throw;}
    }

    [HttpDelete("requests/{id:long}")]
    public async Task<IActionResult> DeleteRequest(long id,CancellationToken t)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38003","DELETE",t))return Forbid();
        await using var cmd=new SqlCommand("DELETE dbo.TDGPGatePass WHERE GatePassID=@id AND CompanyID=@company AND RequesterUserID=@user AND StatusCode=N'DRAFT'",db);cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        if(await cmd.ExecuteNonQueryAsync(t)!=1)return Conflict(new{message="ลบไม่ได้",description="ลบได้เฉพาะเอกสารร่างของผู้ขอ"});
        RemoveAttachmentDirectory(company,id);
        return NoContent();
    }

    [HttpPost("requests/{id:long}/submit")]
    public Task<IActionResult> Submit(long id,CancellationToken t)=>Change(id,"38003","SUBMIT","DRAFT","PENDING_APPROVAL","StatusCode=@next",t);
    [HttpPost("requests/{id:long}/approve")]
    public Task<IActionResult> Approve(long id,CancellationToken t)=>Change(id,"38004","APPROVE","PENDING_APPROVAL","APPROVED","StatusCode=@next,ApprovedAt=SYSUTCDATETIME(),ApprovedBy=@user",t);
    [HttpPost("requests/{id:long}/reject")]
    public Task<IActionResult> Reject(long id,RemarkInput input,CancellationToken t)
    {
        if(string.IsNullOrWhiteSpace(input.Remark))return Task.FromResult<IActionResult>(BadRequest(new{message="ข้อมูลไม่ครบ",description="กรุณาระบุเหตุผลส่งกลับแก้ไข"}));
        return Change(id,"38004","APPROVE","PENDING_APPROVAL","DRAFT","StatusCode=@next,ApprovalRemark=@remark",t,input.Remark,historyAction:"REJECT");
    }
    [HttpPost("requests/{id:long}/handover")]
    public Task<IActionResult> Handover(long id,HandoverInput input,CancellationToken t)
    {
        if(string.IsNullOrWhiteSpace(input.Recipient))return Task.FromResult<IActionResult>(BadRequest(new{message="ข้อมูลไม่ครบ",description="กรุณาระบุผู้รับมอบทรัพย์สิน"}));
        return Change(id,"38003","EDIT","APPROVED","HANDED_OVER","StatusCode=@next,HandedOverAt=SYSUTCDATETIME(),HandedOverBy=@user,HandoverRecipient=@remark",t,input.Recipient,historyAction:"HANDOVER");
    }
    [HttpPost("requests/{id:long}/confirm-exit")]
    public Task<IActionResult> ConfirmExit(long id,CancellationToken t)=>Change(id,"38005","CONFIRM_EXIT","HANDED_OVER","HANDED_OVER","ExitCheckedAt=SYSUTCDATETIME(),ExitCheckedBy=@user",t,extraWhere:" AND ExitCheckedAt IS NULL");
    [HttpPost("requests/{id:long}/confirm-return")]
    public Task<IActionResult> ConfirmReturn(long id,CancellationToken t)=>Change(id,"38006","CONFIRM_RETURN","HANDED_OVER","RETURNED","StatusCode=@next,ReturnedAt=SYSUTCDATETIME(),ReturnedBy=@user",t,requireReturn:true,extraWhere:" AND ExitCheckedAt IS NOT NULL AND ReturnedAt IS NULL");

    async Task<IActionResult> Change(long id,string menu,string action,string expected,string next,string set,CancellationToken t,string? remark=null,bool requireReturn=false,string extraWhere="",string? historyAction=null)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,menu,action,t))return Forbid();
        if(!await SystemEnabled(db,company,t))return Conflict(new{message="ระบบปิดใช้งาน",description="ไม่สามารถดำเนินการเอกสารได้ในขณะนี้"});
        if(action=="APPROVE")
        {
            await using var owner=new SqlCommand("SELECT RequesterUserID FROM dbo.TDGPGatePass WHERE GatePassID=@id AND CompanyID=@company",db);
            owner.Parameters.Add("@id",SqlDbType.BigInt).Value=id;owner.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
            var requester=await owner.ExecuteScalarAsync(t);
            if(requester is not null&&requester!=DBNull.Value&&Convert.ToInt64(requester)==user&&!await CompanyMenuAccess.IsAllowedAsync(db,User,"38004","SELF_APPROVE",t))return Forbid();
        }
        var own=menu=="38003"?" AND RequesterUserID=@user":"";var returning=requireReturn&&menu=="38006"?" AND IsReturnRequired=1":"";
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(t);
        await using var cmd=new SqlCommand($"UPDATE dbo.TDGPGatePass SET {set},UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE GatePassID=@id AND CompanyID=@company AND StatusCode=@expected{own}{returning}{extraWhere}",db,tx);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;cmd.Parameters.Add("@expected",SqlDbType.NVarChar,30).Value=expected;cmd.Parameters.Add("@next",SqlDbType.NVarChar,30).Value=next;
        cmd.Parameters.Add("@remark",SqlDbType.NVarChar,1000).Value=(object?)remark??DBNull.Value;
        if(await cmd.ExecuteNonQueryAsync(t)!=1){await tx.RollbackAsync(t);return Conflict(new{message="เปลี่ยนสถานะไม่ได้",description="สถานะปัจจุบันหรือสิทธิ์ไม่ตรงตาม Flow"});}
        await using var history=new SqlCommand("INSERT dbo.TDGPApprovalHistory(CompanyID,GatePassID,ActionCode,Remark,ActionBy) VALUES(@company,@id,@action,@remark,@user)",db,tx);
        history.Parameters.Add("@company",SqlDbType.BigInt).Value=company;history.Parameters.Add("@id",SqlDbType.BigInt).Value=id;history.Parameters.Add("@action",SqlDbType.NVarChar,30).Value=historyAction??action;history.Parameters.Add("@remark",SqlDbType.NVarChar,1000).Value=(object?)remark??DBNull.Value;history.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        await history.ExecuteNonQueryAsync(t);await tx.CommitAsync(t);return NoContent();
    }

    void RemoveAttachmentDirectory(long company,long id)
    {
        var root=environment.WebRootPath;
        if(string.IsNullOrWhiteSpace(root))root=Path.Combine(environment.ContentRootPath,"wwwroot");
        var uploadRoot=Path.GetFullPath(Path.Combine(root,"uploads","gate-pass"))+Path.DirectorySeparatorChar;
        var target=Path.GetFullPath(Path.Combine(uploadRoot,company.ToString(),id.ToString()));
        if(target.StartsWith(uploadRoot,StringComparison.OrdinalIgnoreCase)&&Directory.Exists(target))Directory.Delete(target,true);
    }

    static bool ValidRequest(RequestInput input)=>input.PurposeId>0&&!string.IsNullOrWhiteSpace(input.Carrier)&&!string.IsNullOrWhiteSpace(input.CarrierPhone)&&input.CarrierPhone.Length<=40&&!string.IsNullOrWhiteSpace(input.Destination)&&input.Items is {Count:>0}&&!input.Items.Any(x=>string.IsNullOrWhiteSpace(x.Name)||x.Quantity<=0||x.Remark?.Length>1000);
    static bool RequiresReturn(RequestInput input)=>input.Items?.Any(x=>x.IsReturnRequired??input.IsReturnRequired)??input.IsReturnRequired;
    static void AddDocumentFields(SqlCommand cmd,RequestInput input){cmd.Parameters.Add("@phone",SqlDbType.NVarChar,40).Value=(object?)input.CarrierPhone??DBNull.Value;cmd.Parameters.Add("@docDate",SqlDbType.DateTime2).Value=(object?)input.DocumentDateTime??DBNull.Value;cmd.Parameters.Add("@exitDate",SqlDbType.Date).Value=(object?)input.PlannedExitDate?.Date??DBNull.Value;}
    static void AddRequestHeader(SqlCommand cmd,long id,long company,long user,RequestInput input){cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@purpose",SqlDbType.BigInt).Value=input.PurposeId!.Value;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;cmd.Parameters.Add("@carrier",SqlDbType.NVarChar,200).Value=input.Carrier!.Trim();cmd.Parameters.Add("@destination",SqlDbType.NVarChar,300).Value=input.Destination!.Trim();cmd.Parameters.Add("@returns",SqlDbType.Bit).Value=input.IsReturnRequired;cmd.Parameters.Add("@remark",SqlDbType.NVarChar,1000).Value=(object?)input.Remark??DBNull.Value;}
    static async Task<bool> ValidPurpose(SqlConnection db,SqlTransaction tx,long company,long? purpose,CancellationToken t){if(purpose is null or <=0)return false;await using var cmd=new SqlCommand("SELECT COUNT(*) FROM dbo.TDGPPurpose WHERE CompanyID=@company AND PurposeID=@purpose AND IsActive=1",db,tx);cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@purpose",SqlDbType.BigInt).Value=purpose.Value;return Convert.ToInt32(await cmd.ExecuteScalarAsync(t))==1;}
    static async Task<bool> ValidItemPurposes(SqlConnection db,SqlTransaction tx,long company,List<RequestItem> items,CancellationToken t){foreach(var purpose in items.Where(i=>i.PurposeId.HasValue).Select(i=>i.PurposeId).Distinct())if(!await ValidPurpose(db,tx,company,purpose,t))return false;return true;}
    static async Task<RequestInput> ApplyRequiredReturns(SqlConnection db,SqlTransaction tx,long company,RequestInput input,CancellationToken t)
    {
        var flags=new Dictionary<long,bool>();
        foreach(var purpose in input.Items!.Select(i=>i.PurposeId??input.PurposeId!.Value).Distinct().OrderBy(id=>id))
        {
            await using var cmd=new SqlCommand("SELECT AlwaysReturnRequired FROM dbo.TDGPPurpose WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND PurposeID=@purpose",db,tx);
            cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@purpose",SqlDbType.BigInt).Value=purpose;
            flags[purpose]=Convert.ToBoolean(await cmd.ExecuteScalarAsync(t));
        }
        return input with { Items=input.Items!.Select(i=>flags[i.PurposeId??input.PurposeId!.Value] ? i with { IsReturnRequired=true } : i).ToList() };
    }
    static async Task UpdateReturnSummary(SqlConnection db,SqlTransaction tx,long id,long company,CancellationToken t){await using var cmd=new SqlCommand("UPDATE dbo.TDGPGatePass SET ExpectedReturnDate=(SELECT MIN(ExpectedReturnDate) FROM dbo.TDGPGatePassItem WHERE CompanyID=@company AND GatePassID=@id AND IsReturnRequired=1) WHERE CompanyID=@company AND GatePassID=@id",db,tx);cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;await cmd.ExecuteNonQueryAsync(t);}
    static async Task AddItems(SqlConnection db,SqlTransaction tx,long id,long company,List<RequestItem> items,CancellationToken t){foreach(var item in items){await using var detail=new SqlCommand("INSERT dbo.TDGPGatePassItem(GatePassID,CompanyID,ItemName,Quantity,UnitName,SerialNo) VALUES(@id,@company,@name,@qty,@unit,@serial)",db,tx);detail.Parameters.Add("@id",SqlDbType.BigInt).Value=id;detail.Parameters.Add("@company",SqlDbType.BigInt).Value=company;detail.Parameters.Add("@name",SqlDbType.NVarChar,300).Value=item.Name.Trim();detail.Parameters.Add("@qty",SqlDbType.Decimal).Value=item.Quantity;detail.Parameters.Add("@unit",SqlDbType.NVarChar,80).Value=(object?)item.Unit??DBNull.Value;detail.Parameters.Add("@serial",SqlDbType.NVarChar,150).Value=(object?)item.SerialNo??DBNull.Value;await detail.ExecuteNonQueryAsync(t);}}
    static async Task<List<long>> SaveItems(SqlConnection db,SqlTransaction tx,long id,long company,List<RequestItem> items,bool legacyReturn,CancellationToken t)
    {
        var retained=new HashSet<long>();var result=new List<long>();
        foreach(var item in items)
        {
            if(item.Id is > 0 && !retained.Add(item.Id.Value)) throw new InvalidOperationException("Duplicate item");
            var due="CASE WHEN @returns=1 THEN COALESCE(@due,DATEADD(day,COALESCE((SELECT ReturnDays FROM dbo.TDGPPurpose WHERE CompanyID=@company AND PurposeID=COALESCE(@purpose,(SELECT PurposeID FROM dbo.TDGPGatePass WHERE CompanyID=@company AND GatePassID=@id))),(SELECT DefaultReturnDays FROM dbo.TDGPSetting WHERE CompanyID=@company),7),(SELECT COALESCE(PlannedExitDate,CONVERT(date,DocumentDateTime),CONVERT(date,CreateDate)) FROM dbo.TDGPGatePass WHERE CompanyID=@company AND GatePassID=@id))) END";
            var sql=item.Id is > 0 ? $"UPDATE dbo.TDGPGatePassItem SET ItemName=@name,Quantity=@qty,UnitName=@unit,SerialNo=@serial,IsReturnRequired=@returns,PurposeID=@purpose,Remark=@remark,ExpectedReturnDate={due} OUTPUT INSERTED.GatePassItemID WHERE GatePassID=@id AND CompanyID=@company AND GatePassItemID=@item" : $"INSERT dbo.TDGPGatePassItem(GatePassID,CompanyID,ItemName,Quantity,UnitName,SerialNo,IsReturnRequired,PurposeID,Remark,ExpectedReturnDate) OUTPUT INSERTED.GatePassItemID VALUES(@id,@company,@name,@qty,@unit,@serial,@returns,@purpose,@remark,{due})";
            await using var cmd=new SqlCommand(sql,db,tx);cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@item",SqlDbType.BigInt).Value=(object?)item.Id??DBNull.Value;cmd.Parameters.Add("@name",SqlDbType.NVarChar,300).Value=item.Name.Trim();cmd.Parameters.Add("@qty",SqlDbType.Decimal).Value=item.Quantity;cmd.Parameters.Add("@unit",SqlDbType.NVarChar,80).Value=(object?)item.Unit??DBNull.Value;cmd.Parameters.Add("@serial",SqlDbType.NVarChar,150).Value=(object?)item.SerialNo??DBNull.Value;cmd.Parameters.Add("@returns",SqlDbType.Bit).Value=item.IsReturnRequired??legacyReturn;
            cmd.Parameters.Add("@purpose",SqlDbType.BigInt).Value=(object?)item.PurposeId??DBNull.Value;cmd.Parameters.Add("@remark",SqlDbType.NVarChar,1000).Value=(object?)item.Remark??DBNull.Value;cmd.Parameters.Add("@due",SqlDbType.Date).Value=(object?)item.ExpectedReturnDate?.Date??DBNull.Value;
            var value=await cmd.ExecuteScalarAsync(t);if(value is null)throw new InvalidOperationException("Invalid item");var itemId=Convert.ToInt64(value);retained.Add(itemId);result.Add(itemId);
        }
        await using var list=new SqlCommand("SELECT GatePassItemID FROM dbo.TDGPGatePassItem WHERE GatePassID=@id AND CompanyID=@company",db,tx);list.Parameters.Add("@id",SqlDbType.BigInt).Value=id;list.Parameters.Add("@company",SqlDbType.BigInt).Value=company;var removed=new List<long>();await using(var reader=await list.ExecuteReaderAsync(t)){while(await reader.ReadAsync(t)){var itemId=reader.GetInt64(0);if(!retained.Contains(itemId))removed.Add(itemId);}}
        foreach(var itemId in removed){await using var delete=new SqlCommand("DELETE dbo.TDGPGatePassRequestFile WHERE CompanyID=@company AND GatePassID=@id AND GatePassItemID=@item; DELETE dbo.TDGPGatePassItem WHERE CompanyID=@company AND GatePassID=@id AND GatePassItemID=@item",db,tx);delete.Parameters.Add("@company",SqlDbType.BigInt).Value=company;delete.Parameters.Add("@id",SqlDbType.BigInt).Value=id;delete.Parameters.Add("@item",SqlDbType.BigInt).Value=itemId;await delete.ExecuteNonQueryAsync(t);}
        return result;
    }

    async Task<bool> HasAnyRequestView(SqlConnection db,CancellationToken t)
    {
        foreach(var menu in new[]{"38003","38004","38005","38006","38007","38008"})
            if(await CompanyMenuAccess.IsAllowedAsync(db,User,menu,"VIEW",t))return true;
        return false;
    }
    static async Task<bool> SystemEnabled(SqlConnection db,long company,CancellationToken t){await using var cmd=new SqlCommand("SELECT COALESCE((SELECT IsEnabled FROM dbo.TDGPSetting WHERE CompanyID=@company),CONVERT(bit,1))",db);cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;return Convert.ToBoolean(await cmd.ExecuteScalarAsync(t));}

    async Task<IActionResult> Read(string menu,string sql,CancellationToken t)
    {
        if(!Scope(out var company,out var user)) return Forbid();
        await using var db=await Open(t);
        if(!await CompanyMenuAccess.IsAllowedAsync(db,User,menu,"VIEW",t)) return Forbid();
        await using var command=new SqlCommand(sql,db);
        command.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
        command.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        await using var reader=await command.ExecuteReaderAsync(t);
        var items=new List<Dictionary<string,object?>>();
        while(await reader.ReadAsync(t))
        {
            var row=new Dictionary<string,object?>();
            for(var i=0;i<reader.FieldCount;i++)
            {
                var key=reader.GetName(i);
                row[char.ToLowerInvariant(key[0])+key[1..]]=reader.IsDBNull(i)?null:reader.GetValue(i);
            }
            items.Add(row);
        }
        return Ok(new { items });
    }

    bool Scope(out long company,out long user)
    {
        company=0; user=0;
        return long.TryParse(User.FindFirstValue("company_id"),out company) &&
            long.TryParse(User.FindFirstValue("user_id"),out user) &&
            User.FindFirstValue("user_type")=="COMPANY_USER";
    }
    async Task<SqlConnection> Open(CancellationToken t){var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));await db.OpenAsync(t);return db;}
}
public sealed record SettingInput(bool IsEnabled,int DefaultReturnDays,long? DefaultApproverUserID=null,decimal? MaxAttachmentSizeMB=null,int? MaxAttachmentsPerStage=null,int? DefaultQrExpiryDays=null);
public sealed record RemarkInput(string? Remark);
public sealed record HandoverInput(string? Recipient);
public sealed record PurposeInput(string? Code,string? Name,bool IsActive,int? ReturnDays=null,bool? AlwaysReturnRequired=null,bool? ClearReturnDays=null);
public sealed record RequestItem(string Name,decimal Quantity,string? Unit,string? SerialNo,long? Id=null,bool? IsReturnRequired=null,long? PurposeId=null,string? Remark=null,DateTime? ExpectedReturnDate=null);
public sealed record RequestInput(long? PurposeId,string? Carrier,string? Destination,bool IsReturnRequired,string? Remark,List<RequestItem>? Items,DateTime? DocumentDateTime=null,DateTime? PlannedExitDate=null,string? CarrierPhone=null);
