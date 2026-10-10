using Laoo.Pet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
namespace Laoo.Pet.Controllers;
[ApiController,Authorize,Route("api/company/pet")]
public sealed class PetReportsController(IConfiguration config) : PetControllerBase(config)
{
    [HttpGet("history")]
    public async Task<IActionResult> History(CancellationToken ct,int page=1,int pageSize=20,long? petId=null)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("เลขหน้าไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62008","VIEW",ct) is { } no)return no;
        var total=await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDPTStay WHERE CompanyID=@c AND (@pet IS NULL OR PetID=@pet)",ct,("@c",Company),("@pet",petId));
        var rows=await PetDb.Rows(db,null,@"SELECT S.StayID id,P.PetName petName,B.BookingNo bookingNo,S.StartsAt startsAt,S.EndsAt endsAt,S.CheckInAt checkInAt,S.CheckOutAt checkOutAt,S.StatusCode status,B.TotalAmount amount FROM dbo.TDPTStay S JOIN dbo.TDPTPet P ON P.CompanyID=S.CompanyID AND P.PetID=S.PetID JOIN dbo.TDBKBooking B ON B.CompanyID=S.CompanyID AND B.BookingID=S.BookingID WHERE S.CompanyID=@c AND (@pet IS NULL OR S.PetID=@pet) ORDER BY S.StartsAt DESC,S.StayID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@c",Company),("@pet",petId),("@offset",(page-1)*pageSize),("@size",pageSize));
        return Ok(new{items=rows,total,page,pageSize});
    }
    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard(CancellationToken ct,DateTime? from=null,DateTime? to=null)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"62010","VIEW",ct) is { } no)return no;
        var start=from??DateTime.UtcNow.Date.AddDays(-30);
        var end=to??DateTime.UtcNow.Date.AddDays(1);
        if(end<=start||(end-start).TotalDays>3660)return Invalid("ช่วงวันที่รายงานไม่ถูกต้องหรือยาวเกิน 10 ปี");
        var summary=await PetDb.Rows(db,null,"SELECT COUNT(*) appointments,SUM(CASE WHEN StatusCode=N'CHECKED_IN' THEN 1 ELSE 0 END) checkedIn,SUM(CASE WHEN StatusCode=N'COMPLETED' THEN 1 ELSE 0 END) completed FROM dbo.TDPTStay WHERE CompanyID=@c AND StartsAt>=@from AND StartsAt<@to",ct,("@c",Company),("@from",start),("@to",end));
        var services=await PetDb.Rows(db,null,"SELECT TOP 10 V.ServiceName name,COUNT(*) count FROM dbo.TDPTStay S JOIN dbo.TDBKBookingService L ON L.CompanyID=S.CompanyID AND L.BookingID=S.BookingID JOIN dbo.TDBKService V ON V.CompanyID=L.CompanyID AND V.ServiceID=L.ServiceID WHERE S.CompanyID=@c AND S.StartsAt>=@from AND S.StartsAt<@to GROUP BY V.ServiceName ORDER BY COUNT(*) DESC,V.ServiceName",ct,("@c",Company),("@from",start),("@to",end));
        return Ok(new{summary=summary[0],services});
    }
}
