using Laoo.Pet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.Pet.Controllers;
[ApiController,Authorize,Route("api/company/pet/profiles")]
public sealed class PetProfilesController(IConfiguration config) : PetControllerBase(config)
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct,int page=1,int pageSize=20,string? search=null)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("เลือกหน้าตั้งแต่ 1 และจำนวนไม่เกิน 100 รายการ");
        await using var db=await Open(ct);
        if(await Guard(db,"62004","VIEW",ct) is { } no)return no;
        var term=(search??"").Trim();
        var args=new (string,object?)[]{("@c",Company),("@term",term),("@offset",(page-1)*pageSize),("@size",pageSize)};
        var where="CompanyID=@c AND (@term=N'' OR PetName LIKE N'%'+@term+N'%' OR PetCode LIKE N'%'+@term+N'%')";
        var total=await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDPTPet WHERE "+where,ct,args);
        var rows=await PetDb.Rows(db,null,"SELECT PetID id,PetCode code,OwnerCustomerID ownerCustomerId,MemberID memberId,PetName name,Species species,Breed breed,SizeCode sizeCode,BirthDate birthDate,CautionText caution,EmergencyName emergencyName,EmergencyPhone emergencyPhone,IsActive active FROM dbo.TDPTPet WHERE "+where+" ORDER BY PetID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,args);
        return Ok(new {items=rows,total,page,pageSize});
    }
    [HttpPost]
    public async Task<IActionResult> Create(PetProfileRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("ระบุรหัส ชื่อ ชนิด และเจ้าของจากทะเบียนลูกค้า");
        await using var db=await Open(ct);
        if(await Guard(db,"62004","CREATE",ct) is { } no)return no;
        if(!await References(db,input,ct))return Invalid("ไม่พบลูกค้าหรือสมาชิกในบริษัทเดียวกัน");
        try
        {
            var id=await PetDb.Id(db,null,"INSERT dbo.TDPTPet(CompanyID,PetCode,OwnerCustomerID,MemberID,PetName,Species,Breed,SizeCode,BirthDate,CautionText,EmergencyName,EmergencyPhone) VALUES(@c,@code,@owner,@member,@name,@species,@breed,@size,@birth,@caution,@emergency,@phone);SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,Args(input));
            return Created($"/api/company/pet/profiles/{id}",new{id});
        }
        catch(SqlException e) when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสสัตว์เลี้ยงซ้ำ",description="เปลี่ยนรหัสสัตว์เลี้ยงแล้วบันทึกอีกครั้ง"});}
    }
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id,PetProfileRequest input,CancellationToken ct)
    {
        if(id<1||!Valid(input))return Invalid("ระบุรหัส ชื่อ ชนิด และเจ้าของจากทะเบียนลูกค้า");
        await using var db=await Open(ct);
        if(await Guard(db,"62004","EDIT",ct) is { } no)return no;
        if(!await References(db,input,ct))return Invalid("ไม่พบลูกค้าหรือสมาชิกในบริษัทเดียวกัน");
        try
        {
            var args=Args(input).Append(("@id",(object?)id)).ToArray();
            var changed=await PetDb.Exec(db,null,"UPDATE dbo.TDPTPet SET PetCode=@code,OwnerCustomerID=@owner,MemberID=@member,PetName=@name,Species=@species,Breed=@breed,SizeCode=@size,BirthDate=@birth,CautionText=@caution,EmergencyName=@emergency,EmergencyPhone=@phone WHERE CompanyID=@c AND PetID=@id AND IsActive=1",ct,args);
            return changed==0?Missing():NoContent();
        }
        catch(SqlException e) when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสสัตว์เลี้ยงซ้ำ",description="เปลี่ยนรหัสสัตว์เลี้ยงแล้วบันทึกอีกครั้ง"});}
    }
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Deactivate(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"62004","DELETE",ct) is { } no)return no;
        var changed=await PetDb.Exec(db,null,"UPDATE dbo.TDPTPet SET IsActive=0 WHERE CompanyID=@c AND PetID=@id AND IsActive=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDPTStay WHERE CompanyID=@c AND PetID=@id AND StatusCode IN(N'BOOKED',N'CHECKED_IN'))",ct,("@c",Company),("@id",id));
        return changed==0?Conflict(new{message="ปิดโปรไฟล์ไม่ได้",description="ตรวจสอบรายการเข้าพักที่ยังไม่สิ้นสุดหรือสถานะโปรไฟล์"}):NoContent();
    }
    bool Valid(PetProfileRequest x)=>x.OwnerCustomerId>0&&!string.IsNullOrWhiteSpace(x.Code)&&x.Code.Length<=30&&!string.IsNullOrWhiteSpace(x.Name)&&x.Name.Length<=150&&!string.IsNullOrWhiteSpace(x.Species)&&x.Species.Length<=80;
    async Task<bool> References(Microsoft.Data.SqlClient.SqlConnection db,PetProfileRequest x,CancellationToken ct)
    {
        var owner=await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDARCustomer WHERE CompanyID=@c AND CustomerID=@id AND IsActive=1",ct,("@c",Company),("@id",x.OwnerCustomerId));
        if(owner==0)return false;
        return x.MemberId is null || await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDBKMember WHERE CompanyID=@c AND MemberID=@id AND IsActive=1",ct,("@c",Company),("@id",x.MemberId))>0;
    }
    (string,object?)[] Args(PetProfileRequest x)=>[("@c",Company),("@code",x.Code.Trim()),("@owner",x.OwnerCustomerId),("@member",x.MemberId),("@name",x.Name.Trim()),("@species",x.Species.Trim()),("@breed",x.Breed),("@size",x.SizeCode),("@birth",x.BirthDate),("@caution",x.Caution),("@emergency",x.EmergencyName),("@phone",x.EmergencyPhone)];
}
public sealed record PetProfileRequest(string Code,long OwnerCustomerId,long? MemberId,string Name,string Species,string? Breed,string? SizeCode,DateOnly? BirthDate,string? Caution,string? EmergencyName,string? EmergencyPhone);
