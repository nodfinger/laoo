using System.Data;
using System.Security.Claims;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/locations")]
public sealed class CoreLocationController(IConfiguration configuration) : ControllerBase
{
    private long Company => long.TryParse(User.FindFirstValue("company_id"), out var id) ? id : 0;
    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(token);
        return c;
    }

    private async Task<bool> Allowed(SqlConnection c, string action, CancellationToken token)
    {
        if (!await CompanyProjectPermission.IsAllowedAsync(c, User, "14001", action, token)) return false;
        if (!long.TryParse(User.FindFirstValue("partner_id"),out var partner)) return false;
        using var cmd = new SqlCommand("SELECT COUNT(*) FROM dbo.TDADMainMenu M WHERE M.MenuCode=N'14001' AND M.IsActive=1 AND M.ScreenType=1 AND EXISTS(SELECT 1 FROM dbo.TDSTCompanySetUp C WHERE C.CompanyID=@company AND C.PartnerID=@partner AND C.IsActive=1);", c);
        cmd.Parameters.AddWithValue("@company",Company);
        cmd.Parameters.AddWithValue("@partner",partner);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(token)) == 1;
    }

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Allowed(c, "VIEW", token)) return StatusCode(403, new { message="ไม่สามารถดูสถานที่ได้", description="บัญชีนี้ไม่มีสิทธิ์ดูทะเบียนสถานที่ของ Company" });
        var actions = new { create=await Allowed(c,"CREATE",token), edit=await Allowed(c,"EDIT",token), delete=await Allowed(c,"DELETE",token) };
        const string sql = """
SELECT BuildingID id,BuildingCode code,BuildingNameTH name,IsActive active FROM dbo.TDADBuilding WHERE CompanyID=@company ORDER BY BuildingCode,BuildingID;
SELECT F.FloorID id,F.BuildingID parentId,F.FloorCode code,F.FloorNameTH name,F.IsActive active FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE B.CompanyID=@company ORDER BY F.FloorNumber,F.FloorCode,F.FloorID;
SELECT RoomID id,BuildingID buildingId,FloorID parentId,RoomCode code,RoomNameTH name,RoomTypeCode type,Description description,IsActive active FROM dbo.TDADRoom WHERE CompanyID=@company ORDER BY RoomCode,RoomID;
""";
        using var cmd = new SqlCommand(sql,c);
        cmd.Parameters.AddWithValue("@company",Company);
        await using var r = await cmd.ExecuteReaderAsync(token);
        var sets = new List<List<Dictionary<string,object?>>>();
        do
        {
            var rows=new List<Dictionary<string,object?>>();
            while(await r.ReadAsync(token))
            {
                var row=new Dictionary<string,object?>();
                for(var i=0;i<r.FieldCount;i++) row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);
                rows.Add(row);
            }
            sets.Add(rows);
        } while(await r.NextResultAsync(token));
        return Ok(new { buildings=sets[0], floors=sets[1], rooms=sets[2], actions });
    }

    [HttpPost("{kind}")]
    public Task<IActionResult> Create(string kind, LocationRequest request, CancellationToken token) => Save(kind,null,request,token);
    [HttpPut("{kind}/{id:long}")]
    public Task<IActionResult> Update(string kind,long id,LocationRequest request,CancellationToken token) => Save(kind,id,request,token);

    [HttpDelete("{kind}/{id:long}")]
    public async Task<IActionResult> Delete(string kind,long id,CancellationToken token)
    {
        var sql=kind switch
        {
            "buildings" => "IF EXISTS(SELECT 1 FROM dbo.TDADMeetingRoom WHERE BuildingID=@id AND CompanyID=@company) THROW 51204,'REFERENCED',1; DELETE FROM dbo.TDADBuilding WHERE BuildingID=@id AND CompanyID=@company;",
            "floors" => "IF EXISTS(SELECT 1 FROM dbo.TDADMeetingRoom WHERE FloorID=@id AND CompanyID=@company) THROW 51204,'REFERENCED',1; DELETE F FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE F.FloorID=@id AND B.CompanyID=@company;",
            "rooms" => "DELETE FROM dbo.TDADRoom WHERE RoomID=@id AND CompanyID=@company;",
            _ => null
        };
        if(sql is null) return NotFound();
        await using var c=await Open(token);
        if(!await Allowed(c,"DELETE",token)) return StatusCode(403,new { message="ลบสถานที่ไม่ได้",description="บัญชีนี้ไม่มีสิทธิ์ลบทะเบียนสถานที่" });
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        using var cmd=new SqlCommand(sql,c,tx);
        cmd.Parameters.AddWithValue("@company",Company);
        cmd.Parameters.AddWithValue("@id",id);
        try
        {
            var changed=await cmd.ExecuteNonQueryAsync(token);
            await tx.CommitAsync(token);
            return changed==0?NotFound(new {message="ไม่พบสถานที่",description="กรุณาโหลดรายการใหม่"}):NoContent();
        }
        catch(SqlException e) when(e.Number is 547 or 51204)
        {
            await tx.RollbackAsync(token);
            return Conflict(new { message="สถานที่นี้ยังลบไม่ได้",description="มีชั้น ห้อง หรือข้อมูลอื่นอ้างอิงอยู่ ให้ปิดใช้งานแทนการลบ" });
        }
    }

    private async Task<IActionResult> Save(string kind,long? id,LocationRequest x,CancellationToken token)
    {
        if(kind is not ("buildings" or "floors" or "rooms")) return NotFound();
        if(string.IsNullOrWhiteSpace(x.Code)||x.Code.Trim().Length>20||string.IsNullOrWhiteSpace(x.Name)||x.Name.Trim().Length>200||x.Description?.Length>1000)
            return BadRequest(new { message="ข้อมูลสถานที่ไม่ถูกต้อง",description="ระบุรหัสไม่เกิน 20 ตัวอักษร ชื่อไม่เกิน 200 ตัวอักษร และรายละเอียดไม่เกิน 1,000 ตัวอักษร" });
        if(kind=="rooms" && x.Type is not ("RESIDENTIAL" or "OFFICE" or "COMMON" or "OTHER"))
            return BadRequest(new { message="ประเภทห้องไม่ถูกต้อง",description="กรุณาเลือกประเภทห้องจากรายการ" });
        await using var c=await Open(token);
        if(!await Allowed(c,id.HasValue?"EDIT":"CREATE",token)) return StatusCode(403,new { message="บันทึกสถานที่ไม่ได้",description="บัญชีนี้ไม่มีสิทธิ์ดำเนินการ" });
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        var sql=kind switch
        {
            "buildings" => """
IF @id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADBuilding WHERE BuildingID=@id AND CompanyID=@company) THROW 51201,'NOT_FOUND',1;
IF EXISTS(SELECT 1 FROM dbo.TDADBuilding WHERE CompanyID=@company AND BuildingCode=@code AND (@id IS NULL OR BuildingID<>@id)) THROW 51202,'DUPLICATE_CODE',1;
IF @id IS NULL BEGIN INSERT dbo.TDADBuilding(CompanyID,BranchID,BuildingCode,BuildingNameTH,IsActive,CreateDate,CreateBy) VALUES(@company,NULL,@code,@name,@active,SYSUTCDATETIME(),@actor); SET @id=SCOPE_IDENTITY(); END
ELSE UPDATE dbo.TDADBuilding SET BuildingCode=@code,BuildingNameTH=@name,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE BuildingID=@id AND CompanyID=@company;
SELECT @id;
""",
            "floors" => """
IF NOT EXISTS(SELECT 1 FROM dbo.TDADBuilding WHERE BuildingID=@parent AND CompanyID=@company AND (IsActive=1 OR @active=0)) THROW 51203,'INVALID_PARENT',1;
IF @id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE F.FloorID=@id AND B.CompanyID=@company AND F.BuildingID=@parent) THROW 51201,'NOT_FOUND',1;
IF EXISTS(SELECT 1 FROM dbo.TDADFloor WHERE BuildingID=@parent AND FloorCode=@code AND (@id IS NULL OR FloorID<>@id)) THROW 51202,'DUPLICATE_CODE',1;
IF @id IS NULL BEGIN INSERT dbo.TDADFloor(BuildingID,FloorCode,FloorNameTH,IsActive,CreateDate,CreateBy) VALUES(@parent,@code,@name,@active,SYSUTCDATETIME(),@actor); SET @id=SCOPE_IDENTITY(); END
ELSE UPDATE dbo.TDADFloor SET FloorCode=@code,FloorNameTH=@name,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE FloorID=@id AND BuildingID=@parent;
SELECT @id;
""",
            _ => """
DECLARE @building bigint;
SELECT @building=B.BuildingID FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE F.FloorID=@parent AND B.CompanyID=@company AND (@active=0 OR (F.IsActive=1 AND B.IsActive=1));
IF @building IS NULL THROW 51203,'INVALID_PARENT',1;
IF @id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADRoom WHERE RoomID=@id AND CompanyID=@company AND FloorID=@parent) THROW 51201,'NOT_FOUND',1;
IF @id IS NULL BEGIN INSERT dbo.TDADRoom(CompanyID,BuildingID,FloorID,RoomCode,RoomNameTH,RoomTypeCode,Description,IsActive,CreateBy) VALUES(@company,@building,@parent,@code,@name,@type,@description,@active,@actor); SET @id=SCOPE_IDENTITY(); END
ELSE UPDATE dbo.TDADRoom SET RoomCode=@code,RoomNameTH=@name,RoomTypeCode=@type,Description=@description,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE RoomID=@id AND CompanyID=@company;
SELECT @id;
"""
        };
        using var cmd=new SqlCommand(sql,c,tx);
        cmd.Parameters.AddWithValue("@company",Company);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=(object?)id??DBNull.Value;
        cmd.Parameters.Add("@parent",SqlDbType.BigInt).Value=(object?)x.ParentId??DBNull.Value;
        cmd.Parameters.AddWithValue("@code",x.Code.Trim());
        cmd.Parameters.AddWithValue("@name",x.Name.Trim());
        cmd.Parameters.AddWithValue("@type",x.Type??"OTHER");
        cmd.Parameters.AddWithValue("@description",(object?)x.Description??DBNull.Value);
        cmd.Parameters.AddWithValue("@active",x.Active);
        cmd.Parameters.AddWithValue("@actor",User.FindFirstValue("user_id")??"api");
        try
        {
            var saved=Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
            await tx.CommitAsync(token);
            return Ok(new { id=saved });
        }
        catch(SqlException e) when(e.Number is 51201 or 51202 or 51203 or 2601 or 2627)
        {
            await tx.RollbackAsync(token);
            return Conflict(new { message="บันทึกสถานที่ไม่ได้",description=e.Number switch { 51201=>"ไม่พบรายการใน Company หรือสถานที่แม่เดิม กรุณาโหลดข้อมูลใหม่",51203=>"กรุณาเลือกอาคารและชั้นที่เปิดใช้งานใน Company ของตน",_=>"รหัสซ้ำในสถานที่เดียวกัน กรุณาเปลี่ยนรหัส" } });
        }
    }
}

public sealed record LocationRequest(string Code,string Name,long? ParentId,string? Type,string? Description,bool Active=true);
