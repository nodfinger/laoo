using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooGatePassModule.Controllers;

[ApiController, Authorize, Route("api/company/gate-pass")]
public sealed class GatePassDataController(IConfiguration config) : ControllerBase
{
    [HttpGet("settings")]
    public Task<IActionResult> Settings(CancellationToken t) => Read("38001", "SELECT IsEnabled,DefaultReturnDays FROM dbo.TDGPSetting WHERE CompanyID=@company", t);

    [HttpGet("purposes")]
    public Task<IActionResult> Purposes(CancellationToken t) => Read("38002", "SELECT PurposeID Id,PurposeCode Code,PurposeName Name,IsActive FROM dbo.TDGPPurpose WHERE CompanyID=@company ORDER BY PurposeCode", t);

    [HttpGet("requests")]
    public Task<IActionResult> Requests(CancellationToken t) => Read("38003", "SELECT GatePassID Id,GatePassNo Number,StatusCode Status,CarrierName Carrier,DestinationName Destination,IsReturnRequired,HandedOverAt,ExitCheckedAt,ReturnedAt FROM dbo.TDGPGatePass WHERE CompanyID=@company ORDER BY CreateDate DESC", t);

    [HttpGet("approvals")]
    public Task<IActionResult> Approvals(CancellationToken t) => Read("38004", "SELECT GatePassID Id,GatePassNo Number,CarrierName Carrier,DestinationName Destination FROM dbo.TDGPGatePass WHERE CompanyID=@company AND StatusCode=N'PENDING_APPROVAL' ORDER BY CreateDate", t);

    [HttpGet("exit-check")]
    public Task<IActionResult> ExitCheck(CancellationToken t) => Read("38005", "SELECT GatePassID Id,GatePassNo Number,CarrierName Carrier,DestinationName Destination,ExitCheckedAt FROM dbo.TDGPGatePass WHERE CompanyID=@company AND StatusCode=N'HANDED_OVER' ORDER BY HandedOverAt", t);

    [HttpGet("returns")]
    public Task<IActionResult> Returns(CancellationToken t) => Read("38006", "SELECT GatePassID Id,GatePassNo Number,CarrierName Carrier,DestinationName Destination,ExpectedReturnDate,ReturnedAt FROM dbo.TDGPGatePass WHERE CompanyID=@company AND StatusCode=N'HANDED_OVER' AND IsReturnRequired=1 ORDER BY ExpectedReturnDate", t);

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

    [HttpPost("requests")]
    public async Task<IActionResult> CreateRequest(RequestInput input,CancellationToken t)
    {
        if(!Scope(out var company,out var user)||string.IsNullOrWhiteSpace(input.Carrier)||string.IsNullOrWhiteSpace(input.Destination)||input.Items is null||input.Items.Count==0||input.Items.Any(x=>string.IsNullOrWhiteSpace(x.Name)||x.Quantity<=0)) return BadRequest(new {message="ข้อมูลไม่ครบ",description="กรุณาระบุผู้รับมอบ ปลายทาง และทรัพย์สินอย่างน้อยหนึ่งรายการ"});
        await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38003","CREATE",t))return Forbid();await using var tx=(SqlTransaction)await db.BeginTransactionAsync(t);
        try{
          await using var header=new SqlCommand("INSERT dbo.TDGPGatePass(CompanyID,GatePassNo,RequesterUserID,CarrierName,DestinationName,IsReturnRequired,Remark,CreateBy) OUTPUT INSERTED.GatePassID VALUES(@company,N'GP'+FORMAT(SYSUTCDATETIME(),'yyyyMMddHHmmss')+RIGHT(CONVERT(nvarchar(36),NEWID()),4),@user,@carrier,@destination,@returns,@remark,@user)",db,tx);
          header.Parameters.Add("@company",SqlDbType.BigInt).Value=company;header.Parameters.Add("@user",SqlDbType.BigInt).Value=user;header.Parameters.Add("@carrier",SqlDbType.NVarChar,200).Value=input.Carrier.Trim();header.Parameters.Add("@destination",SqlDbType.NVarChar,300).Value=input.Destination.Trim();header.Parameters.Add("@returns",SqlDbType.Bit).Value=input.IsReturnRequired;header.Parameters.Add("@remark",SqlDbType.NVarChar,1000).Value=(object?)input.Remark??DBNull.Value;
          var id=Convert.ToInt64(await header.ExecuteScalarAsync(t));
          foreach(var item in input.Items){await using var detail=new SqlCommand("INSERT dbo.TDGPGatePassItem(GatePassID,CompanyID,ItemName,Quantity,UnitName,SerialNo) VALUES(@id,@company,@name,@qty,@unit,@serial)",db,tx);detail.Parameters.Add("@id",SqlDbType.BigInt).Value=id;detail.Parameters.Add("@company",SqlDbType.BigInt).Value=company;detail.Parameters.Add("@name",SqlDbType.NVarChar,300).Value=item.Name.Trim();detail.Parameters.Add("@qty",SqlDbType.Decimal).Value=item.Quantity;detail.Parameters.Add("@unit",SqlDbType.NVarChar,80).Value=(object?)item.Unit??DBNull.Value;detail.Parameters.Add("@serial",SqlDbType.NVarChar,150).Value=(object?)item.SerialNo??DBNull.Value;await detail.ExecuteNonQueryAsync(t);}
          await tx.CommitAsync(t);return Ok(new{id});
        }catch{await tx.RollbackAsync(t);throw;}
    }

    [HttpPost("requests/{id:long}/submit")]
    public Task<IActionResult> Submit(long id,CancellationToken t)=>Change(id,"38003","SUBMIT","DRAFT","PENDING_APPROVAL","StatusCode=@next",t);
    [HttpPost("requests/{id:long}/approve")]
    public Task<IActionResult> Approve(long id,CancellationToken t)=>Change(id,"38004","APPROVE","PENDING_APPROVAL","APPROVED","StatusCode=@next,ApprovedAt=SYSUTCDATETIME(),ApprovedBy=@user",t);
    [HttpPost("requests/{id:long}/handover")]
    public Task<IActionResult> Handover(long id,CancellationToken t)=>Change(id,"38003","EDIT","APPROVED","HANDED_OVER","StatusCode=@next,HandedOverAt=SYSUTCDATETIME(),HandedOverBy=@user",t);
    [HttpPost("requests/{id:long}/confirm-exit")]
    public Task<IActionResult> ConfirmExit(long id,CancellationToken t)=>Change(id,"38005","CONFIRM_EXIT","HANDED_OVER","HANDED_OVER","ExitCheckedAt=SYSUTCDATETIME(),ExitCheckedBy=@user",t,true);
    [HttpPost("requests/{id:long}/confirm-return")]
    public Task<IActionResult> ConfirmReturn(long id,CancellationToken t)=>Change(id,"38006","CONFIRM_RETURN","HANDED_OVER","RETURNED","StatusCode=@next,ReturnedAt=SYSUTCDATETIME(),ReturnedBy=@user",t,true);

    async Task<IActionResult> Change(long id,string menu,string action,string expected,string next,string set,CancellationToken t,bool requireReturn=false)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);if(!await CompanyMenuAccess.IsAllowedAsync(db,User,menu,action,t))return Forbid();
        var own=menu=="38003"?" AND RequesterUserID=@user":"";var returning=requireReturn&&menu=="38006"?" AND IsReturnRequired=1":"";
        await using var cmd=new SqlCommand($"UPDATE dbo.TDGPGatePass SET {set},UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE GatePassID=@id AND CompanyID=@company AND StatusCode=@expected{own}{returning}",db);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;cmd.Parameters.Add("@expected",SqlDbType.NVarChar,30).Value=expected;cmd.Parameters.Add("@next",SqlDbType.NVarChar,30).Value=next;
        return await cmd.ExecuteNonQueryAsync(t)==1?NoContent():Conflict(new{message="เปลี่ยนสถานะไม่ได้",description="สถานะปัจจุบันหรือสิทธิ์ไม่ตรงตาม Flow"});
    }

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
public sealed record PurposeInput(string? Code,string? Name,bool IsActive);
public sealed record RequestItem(string Name,decimal Quantity,string? Unit,string? SerialNo);
public sealed record RequestInput(string? Carrier,string? Destination,bool IsReturnRequired,string? Remark,List<RequestItem>? Items);
