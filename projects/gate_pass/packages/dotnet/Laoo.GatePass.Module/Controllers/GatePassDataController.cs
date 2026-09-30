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
    public Task<IActionResult> Settings(CancellationToken t) => Read("38001", "SELECT s.IsEnabled,s.DefaultReturnDays,s.DefaultApproverUserID,u.DisplayName DefaultApproverName,s.MaxAttachmentSizeMB,s.MaxAttachmentsPerStage FROM dbo.TDGPSetting s LEFT JOIN dbo.TDADUser u ON u.CompanyID=s.CompanyID AND u.UserID=s.DefaultApproverUserID WHERE s.CompanyID=@company", t);

    [HttpGet("approver-options")]
    public Task<IActionResult> ApproverOptions(CancellationToken t) => Read("38001", "SELECT UserID Id,Username Code,COALESCE(NULLIF(DisplayName,N''),Username) Name FROM dbo.TDADUser WHERE CompanyID=@company AND IsActive=1 ORDER BY COALESCE(NULLIF(DisplayName,N''),Username)", t);

    [HttpPut("settings")]
    public async Task<IActionResult> UpdateSettings(SettingInput input,CancellationToken t)
    {
        if(!Scope(out var company,out var user)||input.DefaultReturnDays is < 1 or > 365||input.MaxAttachmentSizeMB is <=0 or >1||input.MaxAttachmentsPerStage is <=0 or >20)return BadRequest(new {message="ข้อมูลไม่ถูกต้อง",description="วันรับคืน 1-365 วัน, รูปหลังย่อไม่เกิน 1 MB และไม่เกิน 20 รูปต่อขั้นตอน"});
        await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38001","EDIT",t))return Forbid();
        if(input.DefaultApproverUserID is not null){await using var valid=new SqlCommand("SELECT COUNT(*) FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@approver AND IsActive=1",db);valid.Parameters.Add("@company",SqlDbType.BigInt).Value=company;valid.Parameters.Add("@approver",SqlDbType.BigInt).Value=input.DefaultApproverUserID.Value;if(Convert.ToInt32(await valid.ExecuteScalarAsync(t))!=1)return BadRequest(new{message="ผู้อนุมัติไม่ถูกต้อง",description="กรุณาเลือกผู้ใช้งานที่ Active ในบริษัทนี้"});}
        await using var cmd=new SqlCommand("UPDATE dbo.TDGPSetting SET IsEnabled=@enabled,DefaultReturnDays=@days,DefaultApproverUserID=@approver,MaxAttachmentSizeMB=COALESCE(@maxMb,MaxAttachmentSizeMB),MaxAttachmentsPerStage=COALESCE(@maxCount,MaxAttachmentsPerStage),UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company;IF @@ROWCOUNT=0 INSERT dbo.TDGPSetting(CompanyID,IsEnabled,DefaultReturnDays,DefaultApproverUserID,MaxAttachmentSizeMB,MaxAttachmentsPerStage,UpdateBy) VALUES(@company,@enabled,@days,@approver,COALESCE(@maxMb,1),COALESCE(@maxCount,5),@user);",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@enabled",SqlDbType.Bit).Value=input.IsEnabled;cmd.Parameters.Add("@days",SqlDbType.Int).Value=input.DefaultReturnDays;cmd.Parameters.Add("@approver",SqlDbType.BigInt).Value=(object?)input.DefaultApproverUserID??DBNull.Value;cmd.Parameters.Add("@maxMb",SqlDbType.Decimal).Value=(object?)input.MaxAttachmentSizeMB??DBNull.Value;cmd.Parameters.Add("@maxCount",SqlDbType.Int).Value=(object?)input.MaxAttachmentsPerStage??DBNull.Value;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        await cmd.ExecuteNonQueryAsync(t);return NoContent();
    }

    [HttpGet("purposes")]
    public Task<IActionResult> Purposes(CancellationToken t) => Read("38002", "SELECT PurposeID Id,PurposeCode Code,PurposeName Name,IsActive FROM dbo.TDGPPurpose WHERE CompanyID=@company ORDER BY PurposeCode", t);

    [HttpGet("requests")]
    public Task<IActionResult> Requests(CancellationToken t) => Read("38003", "SELECT g.GatePassID Id,g.GatePassNo Number,g.StatusCode Status,g.CarrierName Carrier,g.DestinationName Destination,p.PurposeName Purpose,g.IsReturnRequired,g.HandedOverAt,g.ExitCheckedAt,g.ReturnedAt FROM dbo.TDGPGatePass g LEFT JOIN dbo.TDGPPurpose p ON p.CompanyID=g.CompanyID AND p.PurposeID=g.PurposeID WHERE g.CompanyID=@company ORDER BY g.CreateDate DESC", t);

    [HttpGet("purpose-options")]
    public Task<IActionResult> PurposeOptions(CancellationToken t) => Read("38003", "SELECT PurposeID Id,PurposeCode Code,PurposeName Name FROM dbo.TDGPPurpose WHERE CompanyID=@company AND IsActive=1 ORDER BY PurposeCode", t);

    [HttpGet("approvals")]
    public Task<IActionResult> Approvals(CancellationToken t) => Read("38004", "SELECT GatePassID Id,GatePassNo Number,CarrierName Carrier,DestinationName Destination FROM dbo.TDGPGatePass WHERE CompanyID=@company AND StatusCode=N'PENDING_APPROVAL' ORDER BY CreateDate", t);

    [HttpGet("exit-check")]
    public Task<IActionResult> ExitCheck(CancellationToken t) => Read("38005", "SELECT GatePassID Id,GatePassNo Number,CarrierName Carrier,DestinationName Destination,ExitCheckedAt FROM dbo.TDGPGatePass WHERE CompanyID=@company AND StatusCode=N'HANDED_OVER' AND ExitCheckedAt IS NULL ORDER BY HandedOverAt", t);

    [HttpGet("returns")]
    public Task<IActionResult> Returns(CancellationToken t) => Read("38006", "SELECT GatePassID Id,GatePassNo Number,CarrierName Carrier,DestinationName Destination,ExpectedReturnDate,ReturnedAt FROM dbo.TDGPGatePass WHERE CompanyID=@company AND StatusCode=N'HANDED_OVER' AND IsReturnRequired=1 AND ExitCheckedAt IS NOT NULL AND ReturnedAt IS NULL ORDER BY ExpectedReturnDate", t);

    [HttpGet("mine")]
    public Task<IActionResult> Mine(CancellationToken t) => Read("38007", "SELECT GatePassID Id,GatePassNo Number,StatusCode Status,CarrierName Carrier,DestinationName Destination,ExitCheckedAt FROM dbo.TDGPGatePass WHERE CompanyID=@company AND RequesterUserID=@user ORDER BY CreateDate DESC", t);

    [HttpGet("dashboard")]
    public Task<IActionResult> Dashboard(CancellationToken t) => Read("38008", "SELECT COUNT(*) Total,SUM(CASE WHEN StatusCode=N'HANDED_OVER' THEN 1 ELSE 0 END) HandedOver,SUM(CASE WHEN ExitCheckedAt IS NOT NULL THEN 1 ELSE 0 END) ExitChecked,SUM(CASE WHEN StatusCode=N'RETURNED' THEN 1 ELSE 0 END) Returned FROM dbo.TDGPGatePass WHERE CompanyID=@company", t);

    [HttpPost("purposes")]
    public async Task<IActionResult> CreatePurpose(PurposeInput input,CancellationToken t)
    {
        if(!Scope(out var company,out var user)||string.IsNullOrWhiteSpace(input.Code)||string.IsNullOrWhiteSpace(input.Name)) return BadRequest(new {message="ข้อมูลไม่ครบ",description="กรุณาระบุรหัสและชื่อ"});
        await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38002","CREATE",t))return Forbid();
        await using var cmd=new SqlCommand("INSERT dbo.TDGPPurpose(CompanyID,PurposeCode,PurposeName,IsActive,CreateBy) OUTPUT INSERTED.PurposeID VALUES(@company,@code,@name,@active,@user)",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@code",SqlDbType.NVarChar,30).Value=input.Code.Trim().ToUpperInvariant();cmd.Parameters.Add("@name",SqlDbType.NVarChar,200).Value=input.Name.Trim();cmd.Parameters.Add("@active",SqlDbType.Bit).Value=input.IsActive;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        try{return Ok(new{id=Convert.ToInt64(await cmd.ExecuteScalarAsync(t))});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสซ้ำ",description="รหัสวัตถุประสงค์นี้มีอยู่แล้ว"});}
    }

    [HttpPut("purposes/{id:long}")]
    public async Task<IActionResult> UpdatePurpose(long id,PurposeInput input,CancellationToken t)
    {
        if(!Scope(out var company,out var user)||string.IsNullOrWhiteSpace(input.Code)||string.IsNullOrWhiteSpace(input.Name)) return BadRequest(new {message="ข้อมูลไม่ครบ",description="กรุณาระบุรหัสและชื่อ"});
        await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38002","EDIT",t))return Forbid();
        await using var cmd=new SqlCommand("UPDATE dbo.TDGPPurpose SET PurposeCode=@code,PurposeName=@name,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE PurposeID=@id AND CompanyID=@company",db);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@code",SqlDbType.NVarChar,30).Value=input.Code.Trim().ToUpperInvariant();cmd.Parameters.Add("@name",SqlDbType.NVarChar,200).Value=input.Name.Trim();cmd.Parameters.Add("@active",SqlDbType.Bit).Value=input.IsActive;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        try{return await cmd.ExecuteNonQueryAsync(t)==1?NoContent():NotFound(new {message="ไม่พบข้อมูล",description="ไม่พบวัตถุประสงค์ในบริษัทนี้"});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสซ้ำ",description="รหัสวัตถุประสงค์นี้มีอยู่แล้ว"});}
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
            submit=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"SUBMIT",t),
            approve=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"APPROVE",t),
            confirmExit=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"CONFIRM_EXIT",t),
            confirmReturn=await CompanyMenuAccess.IsAllowedAsync(db,User,menuCode,"CONFIRM_RETURN",t)
        });
    }

    [HttpPost("requests")]
    public async Task<IActionResult> CreateRequest(RequestInput input,CancellationToken t)
    {
        if(!Scope(out var company,out var user)||!ValidRequest(input)) return BadRequest(new {message="ข้อมูลไม่ครบ",description="กรุณาระบุวัตถุประสงค์ ผู้รับมอบ ปลายทาง และทรัพย์สินอย่างน้อยหนึ่งรายการ"});
        await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38003","CREATE",t))return Forbid();if(!await SystemEnabled(db,company,t))return Conflict(new{message="ระบบปิดใช้งาน",description="ไม่สามารถสร้างใบขอใหม่ได้ในขณะนี้"});await using var tx=(SqlTransaction)await db.BeginTransactionAsync(t);
        try{
          if(!await ValidPurpose(db,tx,company,input.PurposeId,t)){await tx.RollbackAsync(t);return BadRequest(new{message="วัตถุประสงค์ไม่ถูกต้อง",description="กรุณาเลือกวัตถุประสงค์ที่เปิดใช้งานในบริษัทนี้"});}
          await using var header=new SqlCommand("INSERT dbo.TDGPGatePass(CompanyID,GatePassNo,PurposeID,RequesterUserID,CarrierName,DestinationName,ExpectedReturnDate,IsReturnRequired,Remark,CreateBy) OUTPUT INSERTED.GatePassID VALUES(@company,N'GP'+FORMAT(SYSUTCDATETIME(),'yyyyMMddHHmmss')+RIGHT(CONVERT(nvarchar(36),NEWID()),4),@purpose,@user,@carrier,@destination,CASE WHEN @returns=1 THEN DATEADD(DAY,COALESCE((SELECT DefaultReturnDays FROM dbo.TDGPSetting WHERE CompanyID=@company),7),SYSUTCDATETIME()) END,@returns,@remark,@user)",db,tx);
          header.Parameters.Add("@company",SqlDbType.BigInt).Value=company;header.Parameters.Add("@purpose",SqlDbType.BigInt).Value=input.PurposeId!.Value;header.Parameters.Add("@user",SqlDbType.BigInt).Value=user;header.Parameters.Add("@carrier",SqlDbType.NVarChar,200).Value=input.Carrier!.Trim();header.Parameters.Add("@destination",SqlDbType.NVarChar,300).Value=input.Destination!.Trim();header.Parameters.Add("@returns",SqlDbType.Bit).Value=input.IsReturnRequired;header.Parameters.Add("@remark",SqlDbType.NVarChar,1000).Value=(object?)input.Remark??DBNull.Value;
          var id=Convert.ToInt64(await header.ExecuteScalarAsync(t));
          await AddItems(db,tx,id,company,input.Items!,t);
          await tx.CommitAsync(t);return Ok(new{id});
        }catch{await tx.RollbackAsync(t);throw;}
    }

    [HttpGet("requests/{id:long}")]
    public async Task<IActionResult> GetRequest(long id,CancellationToken t)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);if(!await HasAnyRequestView(db,t))return Forbid();
        await using var header=new SqlCommand("SELECT g.GatePassID Id,g.GatePassNo Number,g.PurposeID,g.CarrierName Carrier,g.DestinationName Destination,g.ExpectedReturnDate,g.IsReturnRequired,g.Remark,g.StatusCode Status,p.PurposeName Purpose FROM dbo.TDGPGatePass g LEFT JOIN dbo.TDGPPurpose p ON p.CompanyID=g.CompanyID AND p.PurposeID=g.PurposeID WHERE g.GatePassID=@id AND g.CompanyID=@company AND (g.RequesterUserID=@user OR g.StatusCode<>N'DRAFT')",db);
        header.Parameters.Add("@id",SqlDbType.BigInt).Value=id;header.Parameters.Add("@company",SqlDbType.BigInt).Value=company;header.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        await using var reader=await header.ExecuteReaderAsync(t);if(!await reader.ReadAsync(t))return NotFound(new{message="ไม่พบเอกสาร",description="ไม่พบใบขอนำทรัพย์สินออกในขอบเขตข้อมูลของคุณ"});
        var result=new Dictionary<string,object?>();for(var i=0;i<reader.FieldCount;i++){var key=reader.GetName(i);result[char.ToLowerInvariant(key[0])+key[1..]]=reader.IsDBNull(i)?null:reader.GetValue(i);}await reader.CloseAsync();
        await using var detail=new SqlCommand("SELECT GatePassItemID Id,ItemName Name,Quantity,UnitName Unit,SerialNo FROM dbo.TDGPGatePassItem WHERE GatePassID=@id AND CompanyID=@company ORDER BY GatePassItemID",db);detail.Parameters.Add("@id",SqlDbType.BigInt).Value=id;detail.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
        await using var details=await detail.ExecuteReaderAsync(t);var items=new List<Dictionary<string,object?>>();while(await details.ReadAsync(t)){items.Add(new(){["id"]=details.GetInt64(0),["name"]=details.GetString(1),["quantity"]=details.GetDecimal(2),["unit"]=details.IsDBNull(3)?null:details.GetString(3),["serialNo"]=details.IsDBNull(4)?null:details.GetString(4)});}result["items"]=items;return Ok(result);
    }

    [HttpPut("requests/{id:long}")]
    public async Task<IActionResult> UpdateRequest(long id,RequestInput input,CancellationToken t)
    {
        if(!ValidRequest(input))return BadRequest(new {message="ข้อมูลไม่ครบ",description="กรุณาระบุผู้รับมอบ ปลายทาง และทรัพย์สินอย่างน้อยหนึ่งรายการ"});
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38003","EDIT",t))return Forbid();await using var tx=(SqlTransaction)await db.BeginTransactionAsync(t);
        try{
          if(!await ValidPurpose(db,tx,company,input.PurposeId,t)){await tx.RollbackAsync(t);return BadRequest(new{message="วัตถุประสงค์ไม่ถูกต้อง",description="กรุณาเลือกวัตถุประสงค์ที่เปิดใช้งานในบริษัทนี้"});}
          await using var header=new SqlCommand("UPDATE dbo.TDGPGatePass SET PurposeID=@purpose,CarrierName=@carrier,DestinationName=@destination,ExpectedReturnDate=CASE WHEN @returns=1 THEN COALESCE(ExpectedReturnDate,DATEADD(DAY,COALESCE((SELECT DefaultReturnDays FROM dbo.TDGPSetting WHERE CompanyID=@company),7),SYSUTCDATETIME())) END,IsReturnRequired=@returns,Remark=@remark,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE GatePassID=@id AND CompanyID=@company AND RequesterUserID=@user AND StatusCode=N'DRAFT'",db,tx);
          AddRequestHeader(header,id,company,user,input);if(await header.ExecuteNonQueryAsync(t)!=1){await tx.RollbackAsync(t);return Conflict(new{message="แก้ไขไม่ได้",description="แก้ไขได้เฉพาะเอกสารร่างของผู้ขอ"});}
          await using(var remove=new SqlCommand("DELETE dbo.TDGPGatePassItem WHERE GatePassID=@id AND CompanyID=@company",db,tx)){remove.Parameters.Add("@id",SqlDbType.BigInt).Value=id;remove.Parameters.Add("@company",SqlDbType.BigInt).Value=company;await remove.ExecuteNonQueryAsync(t);}
          await AddItems(db,tx,id,company,input.Items!,t);await tx.CommitAsync(t);return NoContent();
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

    static bool ValidRequest(RequestInput input)=>input.PurposeId>0&&!string.IsNullOrWhiteSpace(input.Carrier)&&!string.IsNullOrWhiteSpace(input.Destination)&&input.Items is {Count:>0}&&!input.Items.Any(x=>string.IsNullOrWhiteSpace(x.Name)||x.Quantity<=0);
    static void AddRequestHeader(SqlCommand cmd,long id,long company,long user,RequestInput input){cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@purpose",SqlDbType.BigInt).Value=input.PurposeId!.Value;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;cmd.Parameters.Add("@carrier",SqlDbType.NVarChar,200).Value=input.Carrier!.Trim();cmd.Parameters.Add("@destination",SqlDbType.NVarChar,300).Value=input.Destination!.Trim();cmd.Parameters.Add("@returns",SqlDbType.Bit).Value=input.IsReturnRequired;cmd.Parameters.Add("@remark",SqlDbType.NVarChar,1000).Value=(object?)input.Remark??DBNull.Value;}
    static async Task<bool> ValidPurpose(SqlConnection db,SqlTransaction tx,long company,long? purpose,CancellationToken t){if(purpose is null or <=0)return false;await using var cmd=new SqlCommand("SELECT COUNT(*) FROM dbo.TDGPPurpose WHERE CompanyID=@company AND PurposeID=@purpose AND IsActive=1",db,tx);cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@purpose",SqlDbType.BigInt).Value=purpose.Value;return Convert.ToInt32(await cmd.ExecuteScalarAsync(t))==1;}
    static async Task AddItems(SqlConnection db,SqlTransaction tx,long id,long company,List<RequestItem> items,CancellationToken t){foreach(var item in items){await using var detail=new SqlCommand("INSERT dbo.TDGPGatePassItem(GatePassID,CompanyID,ItemName,Quantity,UnitName,SerialNo) VALUES(@id,@company,@name,@qty,@unit,@serial)",db,tx);detail.Parameters.Add("@id",SqlDbType.BigInt).Value=id;detail.Parameters.Add("@company",SqlDbType.BigInt).Value=company;detail.Parameters.Add("@name",SqlDbType.NVarChar,300).Value=item.Name.Trim();detail.Parameters.Add("@qty",SqlDbType.Decimal).Value=item.Quantity;detail.Parameters.Add("@unit",SqlDbType.NVarChar,80).Value=(object?)item.Unit??DBNull.Value;detail.Parameters.Add("@serial",SqlDbType.NVarChar,150).Value=(object?)item.SerialNo??DBNull.Value;await detail.ExecuteNonQueryAsync(t);}}

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
public sealed record SettingInput(bool IsEnabled,int DefaultReturnDays,long? DefaultApproverUserID=null,decimal? MaxAttachmentSizeMB=null,int? MaxAttachmentsPerStage=null);
public sealed record RemarkInput(string? Remark);
public sealed record HandoverInput(string? Recipient);
public sealed record PurposeInput(string? Code,string? Name,bool IsActive);
public sealed record RequestItem(string Name,decimal Quantity,string? Unit,string? SerialNo);
public sealed record RequestInput(long? PurposeId,string? Carrier,string? Destination,bool IsReturnRequired,string? Remark,List<RequestItem>? Items);
