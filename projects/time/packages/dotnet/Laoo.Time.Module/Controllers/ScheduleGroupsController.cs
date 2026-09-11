using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Authorize]
[Route("api/time/schedule-groups")]
public sealed class ScheduleGroupsController(IConfiguration configuration) : ControllerBase
{
    private const string MenuCode = "27002";
    public sealed record SaveRequest(string GroupCode,string GroupName,string? DescriptionText,bool IsActive,string? RowVersion);

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        if(!Scope(out _,out _)) return Forbid(); await using var c=await Open(token);
        return Ok(new{menuCode=MenuCode,caption=await Caption(c,token),screenType=1,
            view=await Can(c,"VIEW",token),create=await Can(c,"CREATE",token),edit=await Can(c,"EDIT",token),delete=await Can(c,"DELETE",token)});
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery]string? search,[FromQuery]bool? isActive,[FromQuery]int page=1,[FromQuery]int pageSize=30,CancellationToken token=default)
    {
        if(!Scope(out var companyId,out _))return Forbid(); if(page<1||pageSize is<1 or>100)return BadRequest(new{message="หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง"});
        await using var c=await Open(token);if(!await Can(c,"VIEW",token))return Forbid();search=Clean(search);
        const string where="FROM dbo.TDTMWorkScheduleGroup G WHERE G.CompanyID=@CompanyID AND (@Active IS NULL OR G.IsActive=@Active) AND (@Search IS NULL OR G.GroupCode LIKE N'%'+@Search+N'%' OR G.GroupName LIKE N'%'+@Search+N'%')";
        await using var count=new SqlCommand($"SELECT COUNT_BIG(1) {where}",c);Bind(count,companyId,search,isActive);var total=Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var cmd=new SqlCommand($"SELECT G.WorkScheduleGroupID,G.GroupCode,G.GroupName,G.DescriptionText,G.IsActive,CONVERT(varchar(32),G.RowVersion,2),(SELECT COUNT(*) FROM dbo.TDTMWorkScheduleGroupAssignment A WHERE A.CompanyID=G.CompanyID AND A.WorkScheduleGroupID=G.WorkScheduleGroupID AND A.IsActive=1 AND A.EffectiveFrom<=CONVERT(date,GETDATE()) AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=CONVERT(date,GETDATE()))) MemberCount {where} ORDER BY G.GroupCode,G.WorkScheduleGroupID OFFSET @Offset ROWS FETCH NEXT @Take ROWS ONLY",c);Bind(cmd,companyId,search,isActive);Add(cmd,"@Offset",SqlDbType.Int,(page-1)*pageSize);Add(cmd,"@Take",SqlDbType.Int,pageSize);
        await using var r=await cmd.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new{workScheduleGroupId=r.GetInt64(0),groupCode=r.GetString(1),groupName=r.GetString(2),descriptionText=r.IsDBNull(3)?null:r.GetString(3),isActive=r.GetBoolean(4),rowVersion=r.GetString(5),memberCount=r.GetInt32(6)});return Ok(new{total,page,pageSize,items});
    }

    [HttpPost]
    public async Task<IActionResult> Create(SaveRequest request,CancellationToken token)
    {
        if(!Scope(out var companyId,out var userId))return Forbid();var error=Validate(request);if(error!=null)return BadRequest(new{message=error});await using var c=await Open(token);if(!await Can(c,"CREATE",token))return Forbid();
        await using var cmd=new SqlCommand("INSERT dbo.TDTMWorkScheduleGroup(CompanyID,GroupCode,GroupName,DescriptionText,IsActive,CreateBy) OUTPUT INSERTED.WorkScheduleGroupID VALUES(@CompanyID,@Code,@Name,@Description,@Active,@UserID)",c);BindSave(cmd,companyId,userId,request);
        try{var id=Convert.ToInt64(await cmd.ExecuteScalarAsync(token));return Created(string.Empty,new{workScheduleGroupId=id});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสกลุ่มซ้ำกับข้อมูลเดิม"});}
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id,SaveRequest request,CancellationToken token)
    {
        if(!Scope(out var companyId,out var userId))return Forbid();var error=Validate(request);if(error!=null)return BadRequest(new{message=error});if(string.IsNullOrWhiteSpace(request.RowVersion))return BadRequest(new{message="ไม่พบ Version ของข้อมูล"});await using var c=await Open(token);if(!await Can(c,"EDIT",token))return Forbid();
        await using var cmd=new SqlCommand("UPDATE dbo.TDTMWorkScheduleGroup SET GroupCode=@Code,GroupName=@Name,DescriptionText=@Description,IsActive=@Active,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND WorkScheduleGroupID=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2)",c);BindSave(cmd,companyId,userId,request);Add(cmd,"@ID",SqlDbType.BigInt,id);Add(cmd,"@RowVersion",SqlDbType.VarChar,request.RowVersion,32);
        try{return await cmd.ExecuteNonQueryAsync(token)==1?NoContent():Conflict(new{message="ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่"});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสกลุ่มซ้ำกับข้อมูลเดิม"});}
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,[FromQuery]string rowVersion,CancellationToken token)
    {
        if(!Scope(out var companyId,out var userId))return Forbid();await using var c=await Open(token);if(!await Can(c,"DELETE",token))return Forbid();await using var cmd=new SqlCommand("IF EXISTS(SELECT 1 FROM dbo.TDTMWorkScheduleGroupAssignment WHERE CompanyID=@CompanyID AND WorkScheduleGroupID=@ID) OR EXISTS(SELECT 1 FROM dbo.TDTMGroupShiftRotation WHERE CompanyID=@CompanyID AND WorkScheduleGroupID=@ID) THROW 52331,N'กลุ่มนี้ถูกใช้งานในตารางแล้ว ไม่สามารถลบได้',1; UPDATE dbo.TDTMWorkScheduleGroup SET IsActive=0,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND WorkScheduleGroupID=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2)",c);Add(cmd,"@CompanyID",SqlDbType.BigInt,companyId);Add(cmd,"@ID",SqlDbType.BigInt,id);Add(cmd,"@UserID",SqlDbType.BigInt,userId);Add(cmd,"@RowVersion",SqlDbType.VarChar,rowVersion,32);try{return await cmd.ExecuteNonQueryAsync(token)==1?NoContent():Conflict(new{message="ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่"});}catch(SqlException e)when(e.Number==52331){return Conflict(new{message=e.Message});}
    }

    private static string? Validate(SaveRequest r){if(Clean(r.GroupCode)is null||r.GroupCode.Trim().Length>30)return"กรุณาระบุรหัสกลุ่มไม่เกิน 30 ตัวอักษร";if(Clean(r.GroupName)is null||r.GroupName.Trim().Length>150)return"กรุณาระบุชื่อกลุ่มไม่เกิน 150 ตัวอักษร";if(Clean(r.DescriptionText)?.Length>500)return"รายละเอียดต้องไม่เกิน 500 ตัวอักษร";return null;}
    private async Task<bool> Can(SqlConnection c,string a,CancellationToken t)=>await CompanyMenuAccess.IsAllowedAsync(c,User,MenuCode,a,t);private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private bool Scope(out long companyId,out long userId){companyId=0;userId=0;return string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&long.TryParse(User.FindFirstValue("company_id"),out companyId)&&long.TryParse(User.FindFirstValue("user_id"),out userId)&&companyId>0&&userId>0;}
    private static async Task<string> Caption(SqlConnection c,CancellationToken t){await using var q=new SqlCommand("SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@Code",c);Add(q,"@Code",SqlDbType.Char,MenuCode,5);return Convert.ToString(await q.ExecuteScalarAsync(t))??"กลุ่มตารางทำงาน";}
    private static void Bind(SqlCommand c,long id,string? search,bool? active){Add(c,"@CompanyID",SqlDbType.BigInt,id);Add(c,"@Search",SqlDbType.NVarChar,search,150);Add(c,"@Active",SqlDbType.Bit,active);}
    private static void BindSave(SqlCommand c,long id,long user,SaveRequest r){Add(c,"@CompanyID",SqlDbType.BigInt,id);Add(c,"@Code",SqlDbType.NVarChar,r.GroupCode.Trim().ToUpperInvariant(),30);Add(c,"@Name",SqlDbType.NVarChar,r.GroupName.Trim(),150);Add(c,"@Description",SqlDbType.NVarChar,Clean(r.DescriptionText),500);Add(c,"@Active",SqlDbType.Bit,r.IsActive);Add(c,"@UserID",SqlDbType.BigInt,user);}
    private static string? Clean(string? x)=>string.IsNullOrWhiteSpace(x)?null:x.Trim();private static void Add(SqlCommand c,string n,SqlDbType t,object? v,int s=0){var p=s==0?c.Parameters.Add(n,t):c.Parameters.Add(n,t,s);p.Value=v??DBNull.Value;}
}
