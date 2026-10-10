using Laoo.Pet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
namespace Laoo.Pet.Controllers;
[ApiController,Authorize,Route("api/company/pet/work")]
public sealed class PetWorkController(IConfiguration config) : PetControllerBase(config)
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct,int page=1,int pageSize=20)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("เลขหน้าไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62007","VIEW",ct) is { } no)return no;
        var total=await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDPTStay WHERE CompanyID=@c AND StatusCode IN(N'BOOKED',N'CHECKED_IN')",ct,("@c",Company));
        var rows=await PetDb.Rows(db,null,"SELECT S.StayID id,S.PetID petId,B.BookingNo bookingNo,P.PetName petName,S.StatusCode status,S.StartsAt startsAt,S.EndsAt endsAt,R.RoomCode roomCode FROM dbo.TDPTStay S JOIN dbo.TDBKBooking B ON B.CompanyID=S.CompanyID AND B.BookingID=S.BookingID JOIN dbo.TDPTPet P ON P.CompanyID=S.CompanyID AND P.PetID=S.PetID LEFT JOIN dbo.TDPTRoom R ON R.CompanyID=S.CompanyID AND R.RoomID=S.RoomID WHERE S.CompanyID=@c AND S.StatusCode IN(N'BOOKED',N'CHECKED_IN') ORDER BY S.StartsAt,S.StayID OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@c",Company),("@offset",(page-1)*pageSize),("@size",pageSize));
        return Ok(new{items=rows,total,page,pageSize});
    }
    [HttpGet("{id:long}/care")]
    public async Task<IActionResult> Care(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"62007","VIEW",ct) is { } no)return no;
        if(await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDPTStay WHERE CompanyID=@c AND StayID=@id",ct,("@c",Company),("@id",id))==0)return Missing();
        return Ok(await PetDb.Rows(db,null,"SELECT CareLogID id,EventCode eventCode,DetailText detail,LoggedAt loggedAt,LoggedBy loggedBy FROM dbo.TDPTCareLog WHERE CompanyID=@c AND StayID=@id ORDER BY LoggedAt,CareLogID",ct,("@c",Company),("@id",id)));
    }
    [HttpPost("{id:long}/checkin")]
    public Task<IActionResult> CheckIn(long id,CancellationToken ct)=>Transition(id,"BOOKED","CHECKED_IN","CHECKIN",ct);
    [HttpPost("{id:long}/complete")]
    public Task<IActionResult> Complete(long id,CancellationToken ct)=>Transition(id,"CHECKED_IN","COMPLETED","COMPLETE",ct);
    [HttpPost("{id:long}/care")]
    public async Task<IActionResult> AddCare(long id,PetCareRequest input,CancellationToken ct)
    {
        if(string.IsNullOrWhiteSpace(input.EventCode)||input.EventCode.Length>30||input.Detail?.Length>2000)return Invalid("ระบุประเภทงานและรายละเอียดไม่เกิน 2,000 อักษร");
        await using var db=await Open(ct);
        if(await Guard(db,"62007","EDIT",ct) is { } no)return no;
        var active=await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDPTStay WHERE CompanyID=@c AND StayID=@id AND StatusCode=N'CHECKED_IN'",ct,("@c",Company),("@id",id));
        if(active==0)return Conflict(new{message="ยังบันทึกงานไม่ได้",description="ต้องเช็กอินและยังไม่ปิดงานบริการ"});
        var log=await PetDb.Id(db,null,@"INSERT dbo.TDPTCareLog(CompanyID,StayID,EventCode,DetailText,LoggedBy)
SELECT @c,StayID,@event,@detail,@actor FROM dbo.TDPTStay
WHERE CompanyID=@c AND StayID=@stay AND StatusCode=N'CHECKED_IN';
SELECT CONVERT(bigint,ISNULL(SCOPE_IDENTITY(),0))",ct,("@c",Company),("@stay",id),("@event",input.EventCode.Trim()),("@detail",input.Detail?.Trim()),("@actor",Actor));
        if(log==0)return Conflict(new{message="บันทึกงานไม่ได้",description="รายการต้องเช็กอินแล้วและยังไม่ปิดงาน"});
        return Created($"/api/company/pet/work/{id}/care/{log}",new{id=log});
    }
    async Task<IActionResult> Transition(long id,string from,string to,string action,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"62007",action,ct) is { } no)return no;
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        try
        {
            var stay=await PetDb.Rows(db,tx,"SELECT BookingID FROM dbo.TDPTStay WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND StayID=@id AND StatusCode=@from",ct,("@c",Company),("@id",id),("@from",from));
            if(stay.Count==0)return Conflict(new{message="สถานะรายการเปลี่ยนแล้ว",description="โหลดข้อมูลใหม่และตรวจว่ารายการยังทำขั้นตอนนี้ได้"});
            var booking=Convert.ToInt64(stay[0]["BookingID"]);
            var bookingRows=await PetDb.Rows(db,tx,"SELECT StatusCode FROM dbo.TDBKBooking WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND BookingID=@booking",ct,("@c",Company),("@booking",booking));
            var bookingStatus=bookingRows.Count==0?null:Convert.ToString(bookingRows[0]["StatusCode"]);
            if(bookingStatus is null or "CANCELLED" or "NO_SHOW" || (to=="CHECKED_IN" && bookingStatus is not ("BOOKED" or "CONFIRMED")))
                return Conflict(new{message="สถานะการจองไม่พร้อม",description="ตรวจสอบสถานะรายการจองในระบบ Booking ก่อนดำเนินการ"});
            if(to=="COMPLETED")
            {
                await PetDb.Exec(db,tx,@"INSERT dbo.TDBKUsage(CompanyID,BookingID,LineID,UsedBy)
SELECT @c,@booking,L.LineID,@actor FROM dbo.TDBKBookingService L
WHERE L.CompanyID=@c AND L.BookingID=@booking
AND NOT EXISTS(SELECT 1 FROM dbo.TDBKUsage U WITH(UPDLOCK,HOLDLOCK)
  WHERE U.CompanyID=L.CompanyID AND U.BookingID=L.BookingID AND U.LineID=L.LineID)",ct,("@c",Company),("@booking",booking),("@actor",Actor));
                // A package covers the whole appointment, not an arbitrary subset of its services.
                var eligible=await PetDb.Rows(db,tx,@"SELECT TOP (1) E.EntitlementID
FROM dbo.TDPTEntitlement E WITH (UPDLOCK,HOLDLOCK)
JOIN dbo.TDBKBooking B ON B.CompanyID=E.CompanyID AND B.MemberID=E.MemberID
WHERE E.CompanyID=@c AND B.BookingID=@booking AND E.RemainingUnits>0
 AND CONVERT(date,B.StartsAt) BETWEEN E.StartsOn AND E.ExpiresOn
 AND NOT EXISTS (SELECT 1 FROM dbo.TDBKBookingService L
   WHERE L.CompanyID=B.CompanyID AND L.BookingID=B.BookingID
   AND NOT EXISTS (SELECT 1 FROM dbo.TDPTPackageService PS
     WHERE PS.CompanyID=E.CompanyID AND PS.PackageID=E.PackageID AND PS.ServiceID=L.ServiceID))
 AND NOT EXISTS (SELECT 1 FROM dbo.TDPTEntitlementLedger X
   WHERE X.CompanyID=E.CompanyID AND X.EntitlementID=E.EntitlementID
     AND X.BookingID=B.BookingID AND X.DeltaUnits<0)
ORDER BY E.ExpiresOn,E.EntitlementID",ct,("@c",Company),("@booking",booking));
                if(eligible.Count>0)
                {
                    var entitlement=Convert.ToInt64(eligible[0]["EntitlementID"]);
                    var changed=await PetDb.Exec(db,tx,"UPDATE dbo.TDPTEntitlement SET RemainingUnits=RemainingUnits-1 WHERE CompanyID=@c AND EntitlementID=@id AND RemainingUnits>0",ct,("@c",Company),("@id",entitlement));
                    if(changed!=1)return Conflict(new{message="Package balance changed; retry completion"});
                    await PetDb.Exec(db,tx,"INSERT dbo.TDPTEntitlementLedger(CompanyID,EntitlementID,BookingID,DeltaUnits,ReasonCode,CreatedBy) VALUES(@c,@id,@booking,-1,N'USE',@actor)",ct,("@c",Company),("@id",entitlement),("@booking",booking),("@actor",Actor));
                }
            }
            await PetDb.Exec(db,tx,"UPDATE dbo.TDPTStay SET StatusCode=@to,CheckInAt=CASE WHEN @to=N'CHECKED_IN' THEN SYSUTCDATETIME() ELSE CheckInAt END,CheckOutAt=CASE WHEN @to=N'COMPLETED' THEN SYSUTCDATETIME() ELSE CheckOutAt END WHERE CompanyID=@c AND StayID=@id",ct,("@c",Company),("@id",id),("@to",to));
            await PetDb.Exec(db,tx,"UPDATE dbo.TDBKBooking SET StatusCode=@status WHERE CompanyID=@c AND BookingID=@booking",ct,("@c",Company),("@booking",booking),("@status",to=="COMPLETED"?"COMPLETED":"IN_SERVICE"));
            await PetDb.Exec(db,tx,"INSERT dbo.TDBKBookingAudit(CompanyID,BookingID,ActionCode,ActorUserID) VALUES(@c,@booking,@action,@actor);INSERT dbo.TDPTCareLog(CompanyID,StayID,EventCode,LoggedBy) VALUES(@c,@id,@action,@actor);INSERT dbo.TDPTAudit(CompanyID,EntityCode,EntityID,ActionCode,ActorID) VALUES(@c,N'STAY',@id,@action,@actor)",ct,("@c",Company),("@booking",booking),("@id",id),("@action",action),("@actor",Actor));
            await tx.CommitAsync(ct);
            return NoContent();
        }
        catch{await tx.RollbackAsync(ct);throw;}
    }
}
public sealed record PetCareRequest(string EventCode,string? Detail);
