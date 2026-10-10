using Laoo.Pet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Security.Claims;
namespace Laoo.Pet.Controllers;
[ApiController,Authorize,Route("api/pet/owner")]
public sealed class PetOwnerController(IConfiguration config) : ControllerBase
{
    bool Scope(out long company,out long member,out int version)
    {
        company=member=0;version=0;
        return User.FindFirstValue("user_type")=="BOOKING_MEMBER" && User.FindFirstValue("login_mode")=="BOOKING_MEMBER"
            && User.FindFirstValue("project_code")=="LAOO_BOOKING" && User.FindFirst("user_id") is null
            && long.TryParse(User.FindFirstValue("company_id"),out company)&&company>0
            && long.TryParse(User.FindFirstValue("member_id"),out member)&&member>0
            && int.TryParse(User.FindFirstValue("credential_version"),out version)&&version>0;
    }
    async Task<bool> Allowed(SqlConnection db,long company,long member,int version,CancellationToken ct)
    {
        var current=await PetDb.Id(db,null,@"SELECT COUNT(*) FROM dbo.TDBKMemberCredential K
JOIN dbo.TDBKMember M ON M.CompanyID=K.CompanyID AND M.MemberID=K.MemberID AND M.IsActive=1
JOIN dbo.TDADPerson X ON X.CompanyID=M.CompanyID AND X.PersonID=M.PersonID AND X.IsActive=1
WHERE K.CompanyID=@c AND K.MemberID=@m AND K.TokenVersion=@v AND K.IsActive=1 AND K.MustChangePassword=0",ct,("@c",company),("@m",member),("@v",version));
        if(current==0)return false;
        var subscribed=await PetDb.Id(db,null,@"SELECT COUNT(*) FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_PET' AND P.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE S.CompanyID=@c AND S.IsCurrent=1 AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND (S.StatusCode=N'EXPIRED' OR S.StatusCode IN(N'ACTIVE',N'TRIAL'))",ct,("@c",company));
        if(subscribed==0)return false;
        var booking=await PetDb.Id(db,null,@"SELECT COUNT(*) FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_BOOKING' AND P.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE S.CompanyID=@c AND S.IsCurrent=1 AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND S.StatusCode IN(N'ACTIVE',N'TRIAL',N'EXPIRED')",ct,("@c",company));
        return booking>0;
    }
    [HttpGet("pets")]
    public async Task<IActionResult> Pets(CancellationToken ct)
    {
        if(!Scope(out var company,out var member,out var version))return Forbid();
        await using var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));await db.OpenAsync(ct);
        if(!await Allowed(db,company,member,version,ct))return Forbid();
        return Ok(await PetDb.Rows(db,null,"SELECT PetID id,PetCode code,PetName name,Species species,Breed breed,SizeCode sizeCode,BirthDate birthDate FROM dbo.TDPTPet WHERE CompanyID=@c AND MemberID=@m AND IsActive=1 ORDER BY PetName,PetID",ct,("@c",company),("@m",member)));
    }
    [HttpGet("history")]
    public async Task<IActionResult> History(CancellationToken ct,int page=1,int pageSize=20)
    {
        if(!Scope(out var company,out var member,out var version))return Forbid();
        if(page<1||pageSize is <1 or >50||page>int.MaxValue/pageSize)return BadRequest(new{message="เลขหน้าไม่ถูกต้อง",description="เลือกหน้าตั้งแต่ 1 และไม่เกิน 50 รายการต่อหน้า"});
        await using var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));await db.OpenAsync(ct);
        if(!await Allowed(db,company,member,version,ct))return Forbid();
        var total=await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDPTStay S JOIN dbo.TDPTPet P ON P.CompanyID=S.CompanyID AND P.PetID=S.PetID WHERE S.CompanyID=@c AND P.MemberID=@m",ct,("@c",company),("@m",member));
        var rows=await PetDb.Rows(db,null,"SELECT S.StayID id,P.PetName petName,B.BookingNo bookingNo,S.StartsAt startsAt,S.EndsAt endsAt,S.StatusCode status,S.CheckInAt checkInAt,S.CheckOutAt checkOutAt FROM dbo.TDPTStay S JOIN dbo.TDPTPet P ON P.CompanyID=S.CompanyID AND P.PetID=S.PetID JOIN dbo.TDBKBooking B ON B.CompanyID=S.CompanyID AND B.BookingID=S.BookingID WHERE S.CompanyID=@c AND P.MemberID=@m ORDER BY S.StartsAt DESC,S.StayID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@c",company),("@m",member),("@offset",(page-1)*pageSize),("@size",pageSize));
        return Ok(new{items=rows,total,page,pageSize});
    }
}
