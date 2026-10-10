using Laoo.Pet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.Pet.Controllers;
[ApiController,Authorize,Route("api/company/pet")]
public sealed class PetCatalogController(IConfiguration config) : PetControllerBase(config)
{
    [HttpGet("services")]
    public async Task<IActionResult> Services(CancellationToken ct,int page=1,int pageSize=20,string? search=null)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("เลขหน้าหรือจำนวนรายการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62002","VIEW",ct) is { } no)return no;
        var term=(search??"").Trim();
        if(term.Length>100)return Invalid("คำค้นหาต้องไม่เกิน 100 อักษร");
        const string filter=" FROM dbo.TDPTServiceMap M JOIN dbo.TDBKService S ON S.CompanyID=M.CompanyID AND S.ServiceID=M.ServiceID WHERE M.CompanyID=@c AND (@term=N'' OR S.ServiceCode LIKE N'%'+@term+N'%' OR S.ServiceName LIKE N'%'+@term+N'%')";
        var total=await PetDb.Id(db,null,"SELECT COUNT(*)"+filter,ct,("@c",Company),("@term",term));
        var items=await PetDb.Rows(db,null,"SELECT M.ServiceID id,S.ServiceCode code,S.ServiceName name,M.KindCode kind,M.UnitCode unit,S.Price price,M.IsActive active"+filter+" ORDER BY M.ServiceID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@c",Company),("@term",term),("@offset",(page-1)*pageSize),("@size",pageSize));
        return Ok(new{items,total,page,pageSize});
    }
    [HttpPost("services")]
    public async Task<IActionResult> AddService(PetServiceRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("ระบุบริการในระบบจองและประเภทงานสัตว์เลี้ยงที่รองรับ");
        await using var db=await Open(ct);
        if(await Guard(db,"62002","CREATE",ct) is { } no)return no;
        if(await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDBKService WHERE CompanyID=@c AND ServiceID=@id AND IsActive=1",ct,("@c",Company),("@id",input.ServiceId))==0)return Invalid("ไม่พบบริการ Booking ที่เปิดใช้งานในบริษัทนี้");
        try { await PetDb.Exec(db,null,"INSERT dbo.TDPTServiceMap(CompanyID,ServiceID,KindCode,UnitCode,IsActive) VALUES(@c,@id,@kind,@unit,@active)",ct,("@c",Company),("@id",input.ServiceId),("@kind",input.Kind),("@unit",input.Unit),("@active",input.Active)); return Created($"/api/company/pet/services/{input.ServiceId}",new{id=input.ServiceId}); }
        catch(SqlException e) when(e.Number is 2601 or 2627){return Conflict(new{message="บริการนี้ลงทะเบียนแล้ว",description="เลือกบริการอื่นหรือแก้ไขรายการเดิม"});}
    }
    [HttpPut("services/{id:long}")]
    public async Task<IActionResult> EditService(long id,PetServiceRequest input,CancellationToken ct)
    {
        if(id!=input.ServiceId||!Valid(input))return Invalid("รหัสบริการหรือประเภทงานไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62002","EDIT",ct) is { } no)return no;
        var changed=await PetDb.Exec(db,null,"UPDATE dbo.TDPTServiceMap SET KindCode=@kind,UnitCode=@unit,IsActive=@active WHERE CompanyID=@c AND ServiceID=@id",ct,("@c",Company),("@id",id),("@kind",input.Kind),("@unit",input.Unit),("@active",input.Active));
        return changed==0?Missing():NoContent();
    }
    [HttpDelete("services/{id:long}")]
    public async Task<IActionResult> RemoveService(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"62002","DELETE",ct) is { } no)return no;
        var changed=await PetDb.Exec(db,null,"UPDATE dbo.TDPTServiceMap SET IsActive=0 WHERE CompanyID=@c AND ServiceID=@id AND IsActive=1",ct,("@c",Company),("@id",id));
        return changed==0?Missing():NoContent();
    }
    [HttpGet("rooms")]
    public async Task<IActionResult> Rooms(CancellationToken ct,int page=1,int pageSize=20,string? search=null)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("เลขหน้าหรือจำนวนรายการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62003","VIEW",ct) is { } no)return no;
        var term=(search??"").Trim();
        if(term.Length>100)return Invalid("คำค้นหาต้องไม่เกิน 100 อักษร");
        const string filter=" FROM dbo.TDPTRoom R JOIN dbo.TDBKResource B ON B.CompanyID=R.CompanyID AND B.ResourceID=R.ResourceID WHERE R.CompanyID=@c AND (@term=N'' OR R.RoomCode LIKE N'%'+@term+N'%' OR R.RoomName LIKE N'%'+@term+N'%')";
        var total=await PetDb.Id(db,null,"SELECT COUNT(*)"+filter,ct,("@c",Company),("@term",term));
        var items=await PetDb.Rows(db,null,"SELECT R.RoomID id,R.ResourceID resourceId,R.RoomCode code,R.RoomName name,R.Capacity capacity,R.IsActive active,B.BranchID branchId"+filter+" ORDER BY R.RoomID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@c",Company),("@term",term),("@offset",(page-1)*pageSize),("@size",pageSize));
        return Ok(new{items,total,page,pageSize});
    }
    [HttpPost("rooms")]
    public async Task<IActionResult> AddRoom(PetRoomRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("ระบุรหัส ชื่อ ความจุ และทรัพยากร Booking");
        await using var db=await Open(ct);
        if(await Guard(db,"62003","CREATE",ct) is { } no)return no;
        if(await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDBKResource WHERE CompanyID=@c AND ResourceID=@id AND IsActive=1",ct,("@c",Company),("@id",input.ResourceId))==0)return Invalid("ไม่พบทรัพยากร Booking ในบริษัทนี้");
        try { var id=await PetDb.Id(db,null,"INSERT dbo.TDPTRoom(CompanyID,ResourceID,RoomCode,RoomName,Capacity,IsActive) VALUES(@c,@resource,@code,@name,@capacity,@active);SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,("@c",Company),("@resource",input.ResourceId),("@code",input.Code.Trim()),("@name",input.Name.Trim()),("@capacity",input.Capacity),("@active",input.Active)); return Created($"/api/company/pet/rooms/{id}",new{id}); }
        catch(SqlException e) when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสหรือทรัพยากรห้องซ้ำ",description="ใช้รหัสอื่นหรือเลือกทรัพยากรที่ยังไม่ผูกกับห้อง"});}
    }
    [HttpPut("rooms/{id:long}")]
    public async Task<IActionResult> EditRoom(long id,PetRoomRequest input,CancellationToken ct)
    {
        if(id<1||!Valid(input))return Invalid("ข้อมูลห้องไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62003","EDIT",ct) is { } no)return no;
        var changed=await PetDb.Exec(db,null,"UPDATE dbo.TDPTRoom SET RoomName=@name,Capacity=@capacity,IsActive=@active WHERE CompanyID=@c AND RoomID=@id AND ResourceID=@resource AND RoomCode=@code",ct,("@c",Company),("@id",id),("@resource",input.ResourceId),("@code",input.Code),("@name",input.Name.Trim()),("@capacity",input.Capacity),("@active",input.Active));
        return changed==0?Missing():NoContent();
    }
    [HttpDelete("rooms/{id:long}")]
    public async Task<IActionResult> RemoveRoom(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"62003","DELETE",ct) is { } no)return no;
        var changed=await PetDb.Exec(db,null,"UPDATE dbo.TDPTRoom SET IsActive=0 WHERE CompanyID=@c AND RoomID=@id AND IsActive=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDPTStay WHERE CompanyID=@c AND RoomID=@id AND StatusCode IN(N'BOOKED',N'CHECKED_IN'))",ct,("@c",Company),("@id",id));
        return changed==0?Conflict(new{message="ปิดห้องไม่ได้",description="ตรวจสอบการจองหรือเข้าพักที่ยังไม่สิ้นสุด"}):NoContent();
    }
    static bool Valid(PetServiceRequest x)=>x.ServiceId>0&&new[]{"HOTEL","GROOMING","DAYCARE","TRANSPORT"}.Contains(x.Kind)&&new[]{"VISIT","NIGHT","DAY"}.Contains(x.Unit);
    static bool Valid(PetRoomRequest x)=>x.ResourceId>0&&x.Capacity is >0 and <=100&&!string.IsNullOrWhiteSpace(x.Code)&&x.Code.Length<=30&&!string.IsNullOrWhiteSpace(x.Name)&&x.Name.Length<=150;
}
public sealed record PetServiceRequest(long ServiceId,string Kind,string Unit,bool Active=true);
public sealed record PetRoomRequest(long ResourceId,string Code,string Name,int Capacity,bool Active=true);
