using Laoo.Pet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
namespace Laoo.Pet.Controllers;
[ApiController,Authorize,Route("api/company/pet/appointments")]
public sealed class PetAppointmentsController(IConfiguration config) : PetControllerBase(config)
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct,int page=1,int pageSize=20)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("เลขหน้าหรือจำนวนรายการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62006","VIEW",ct) is { } no)return no;
        var total=await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDPTStay WHERE CompanyID=@c",ct,("@c",Company));
        var rows=await PetDb.Rows(db,null,@"SELECT S.StayID id,S.BookingID bookingId,B.BookingNo bookingNo,P.PetName petName,R.RoomCode roomCode,S.StartsAt startsAt,S.EndsAt endsAt,S.StatusCode status,B.TotalAmount amount FROM dbo.TDPTStay S JOIN dbo.TDBKBooking B ON B.CompanyID=S.CompanyID AND B.BookingID=S.BookingID JOIN dbo.TDPTPet P ON P.CompanyID=S.CompanyID AND P.PetID=S.PetID LEFT JOIN dbo.TDPTRoom R ON R.CompanyID=S.CompanyID AND R.RoomID=S.RoomID WHERE S.CompanyID=@c ORDER BY S.StartsAt DESC,S.StayID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@c",Company),("@offset",(page-1)*pageSize),("@size",pageSize));
        return Ok(new{items=rows,total,page,pageSize});
    }
    [HttpGet("{id:long}")]
    public async Task<IActionResult> Detail(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"62006","VIEW",ct) is { } no)return no;
        var head=await PetDb.Rows(db,null,"SELECT S.StayID id,S.BookingID bookingId,S.PetID petId,S.RoomID roomId,S.StartsAt startsAt,S.EndsAt endsAt,S.StatusCode status,S.CheckInAt checkInAt,S.CheckOutAt checkOutAt,B.BookingNo bookingNo,B.TotalAmount amount FROM dbo.TDPTStay S JOIN dbo.TDBKBooking B ON B.CompanyID=S.CompanyID AND B.BookingID=S.BookingID WHERE S.CompanyID=@c AND S.StayID=@id",ct,("@c",Company),("@id",id));
        if(head.Count==0)return Missing();
        var lines=await PetDb.Rows(db,null,"SELECT L.LineID id,L.ServiceID serviceId,V.ServiceName name,L.ProviderID providerId,L.ResourceID resourceId,L.NetAmount amount FROM dbo.TDBKBookingService L JOIN dbo.TDBKService V ON V.CompanyID=L.CompanyID AND V.ServiceID=L.ServiceID WHERE L.CompanyID=@c AND L.BookingID=@b ORDER BY L.LineID",ct,("@c",Company),("@b",head[0]["bookingId"]));
        return Ok(new{header=head[0],details=lines});
    }
    async Task<long> ReserveRoom(SqlConnection db,SqlTransaction tx,PetAppointmentRequest input,CancellationToken ct)
    {
        if(input.RoomId is null)return -1;
        var room=await PetDb.Rows(db,tx,"SELECT R.ResourceID,R.Capacity FROM dbo.TDPTRoom R WITH(UPDLOCK,HOLDLOCK) JOIN dbo.TDBKResource B ON B.CompanyID=R.CompanyID AND B.ResourceID=R.ResourceID AND B.IsActive=1 WHERE R.CompanyID=@c AND R.RoomID=@id AND R.IsActive=1 AND (B.BranchID IS NULL OR B.BranchID=@branch)",ct,("@c",Company),("@id",input.RoomId),("@branch",input.BranchId));
        if(room.Count==0)return 0;
        var resource=Convert.ToInt64(room[0]["ResourceID"]);
        var used=await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDPTStay WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND RoomID=@room AND StatusCode IN(N'BOOKED',N'CHECKED_IN') AND StartsAt<@to AND EndsAt>@from",ct,("@c",Company),("@room",input.RoomId),("@from",input.StartsAt.UtcDateTime),("@to",input.EndsAt.UtcDateTime));
        var outside=await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDBKBookingService L JOIN dbo.TDBKBooking B ON B.CompanyID=L.CompanyID AND B.BookingID=L.BookingID WHERE L.CompanyID=@c AND L.ResourceID=@resource AND B.StatusCode IN(N'BOOKED',N'CONFIRMED',N'IN_SERVICE') AND B.StartsAt<@to AND B.EndsAt>@from AND NOT EXISTS(SELECT 1 FROM dbo.TDPTStay S WHERE S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID)",ct,("@c",Company),("@resource",resource),("@from",input.StartsAt.UtcDateTime),("@to",input.EndsAt.UtcDateTime));
        return used+outside>=Convert.ToInt64(room[0]["Capacity"])?0:resource;
    }
    [HttpPatch("{id:long}/cancel")]
    [HttpPost("{id:long}/cancel")]
    public async Task<IActionResult> Cancel(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"62006","CANCEL",ct) is { } no)return no;
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        try
        {
            var hours=await PetDb.Id(db,tx,"SELECT COALESCE((SELECT CancelBeforeHours FROM dbo.TDBKSetting WHERE CompanyID=@c),2)",ct,("@c",Company));
            var rows=await PetDb.Rows(db,tx,"SELECT BookingID FROM dbo.TDPTStay WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND StayID=@id AND StatusCode=N'BOOKED' AND StartsAt>=DATEADD(hour,@hours,SYSUTCDATETIME())",ct,("@c",Company),("@id",id),("@hours",hours));
            if(rows.Count==0)return Conflict(new{message="ยกเลิกไม่ได้",description="รายการอาจเริ่มแล้วหรือเลยเวลายกเลิกที่บริษัทกำหนด"});
            var booking=Convert.ToInt64(rows[0]["BookingID"]);
            var changed=await PetDb.Exec(db,tx,"UPDATE dbo.TDBKBooking SET StatusCode=N'CANCELLED' WHERE CompanyID=@c AND BookingID=@b AND StatusCode IN(N'BOOKED',N'CONFIRMED') AND NOT EXISTS(SELECT 1 FROM dbo.TDBKUsage WHERE CompanyID=@c AND BookingID=@b)",ct,("@c",Company),("@b",booking));
            if(changed==0)return Conflict(new{message="ยกเลิกไม่ได้",description="รายการ Booking ถูกใช้บริการหรือเปลี่ยนสถานะแล้ว"});
            await PetDb.Exec(db,tx,"UPDATE dbo.TDPTStay SET StatusCode=N'CANCELLED' WHERE CompanyID=@c AND StayID=@id;INSERT dbo.TDBKBookingAudit(CompanyID,BookingID,ActionCode,ActorUserID) VALUES(@c,@b,N'CANCEL',@actor);INSERT dbo.TDPTAudit(CompanyID,EntityCode,EntityID,ActionCode,ActorID) VALUES(@c,N'STAY',@id,N'CANCEL',@actor)",ct,("@c",Company),("@b",booking),("@id",id),("@actor",Actor));
            await tx.CommitAsync(ct);
            return NoContent();
        }
        catch{await tx.RollbackAsync(ct);throw;}
    }
    [HttpPost]
    public async Task<IActionResult> Create(PetAppointmentRequest input,CancellationToken ct)
    {
        if(input.PetId<1||input.EndsAt<=input.StartsAt||input.StartsAt<DateTimeOffset.UtcNow.AddMinutes(-5)||input.Services is null||input.Services.Count is <1 or >20||input.Services.Select(x=>x.ServiceId).Distinct().Count()!=input.Services.Count)
            return Invalid("เลือกสัตว์ บริการไม่ซ้ำ และช่วงเวลาเริ่ม–สิ้นสุดให้ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62006","CREATE",ct) is { } no)return no;
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        try
        {
            var pet=await PetDb.Rows(db,tx,"SELECT P.MemberID,C.CusName,C.Phone FROM dbo.TDPTPet P JOIN dbo.TDARCustomer C ON C.CompanyID=P.CompanyID AND C.CustomerID=P.OwnerCustomerID AND C.IsActive=1 WHERE P.CompanyID=@c AND P.PetID=@id AND P.IsActive=1",ct,("@c",Company),("@id",input.PetId));
            if(pet.Count==0)return Invalid("ไม่พบสัตว์เลี้ยงหรือเจ้าของในบริษัทนี้");
            var petBusy=await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDPTStay WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND PetID=@pet AND StatusCode IN(N'BOOKED',N'CHECKED_IN') AND StartsAt<@to AND EndsAt>@from",ct,("@c",Company),("@pet",input.PetId),("@from",input.StartsAt.UtcDateTime),("@to",input.EndsAt.UtcDateTime));
            if(petBusy>0)return Conflict(new{message="สัตว์เลี้ยงมีนัดหมายช่วงนี้แล้ว",description="ตรวจรายการเดิมหรือเลือกช่วงเวลาอื่นก่อนบันทึก"});
            if(input.BranchId is { } branch && await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDADBranch B WHERE B.CompanyID=@c AND B.BranchID=@b AND B.IsActive=1 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@u AND U.IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@u AND X.BranchID=@b AND X.IsActive=1))",ct,("@c",Company),("@b",branch),("@u",Actor))==0)return StatusCode(403,new{message="ไม่มีสิทธิ์สาขา",description="เลือกสาขาที่อยู่ในสิทธิ์ของผู้ใช้"});
            var resource=await ReserveRoom(db,tx,input,ct);
            if(resource==0)return Conflict(new{message="ห้องไม่ว่าง",description="ตรวจสอบสาขา ความจุ และช่วงเวลา แล้วเลือกใหม่"});
            decimal total=0;
            var services=new List<(PetAppointmentService Item,decimal Price)>();
            foreach(var item in input.Services)
            {
                var found=await PetDb.Rows(db,tx,"SELECT B.Price,B.RequiresProvider,B.RequiresResource,M.KindCode FROM dbo.TDPTServiceMap M JOIN dbo.TDBKService B ON B.CompanyID=M.CompanyID AND B.ServiceID=M.ServiceID AND B.IsActive=1 WHERE M.CompanyID=@c AND M.ServiceID=@id AND M.IsActive=1",ct,("@c",Company),("@id",item.ServiceId));
                if(found.Count==0)return Invalid("ไม่พบบริการสัตว์เลี้ยงที่เปิดใช้งาน");
                if((Convert.ToString(found[0]["KindCode"]) is "HOTEL" or "DAYCARE" || Convert.ToBoolean(found[0]["RequiresResource"]))&&resource<1)return Invalid("บริการนี้ต้องเลือกห้องหรือกรง");
                if(Convert.ToBoolean(found[0]["RequiresProvider"])&&item.ProviderId is null)return Invalid("บริการนี้ต้องเลือกผู้ให้บริการ");
                if(item.ProviderId is { } provider)
                {
                    if(await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDBKProvider V JOIN dbo.TDADPerson P ON P.CompanyID=V.CompanyID AND P.PersonID=V.PersonID AND P.IsActive=1 WHERE V.CompanyID=@c AND V.ProviderID=@p AND V.IsActive=1",ct,("@c",Company),("@p",provider))==0)return Invalid("ไม่พบผู้ให้บริการที่ใช้งานในบริษัทนี้");
                    var serviceCount=await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDBKProviderService WHERE CompanyID=@c AND ProviderID=@p",ct,("@c",Company),("@p",provider));
                    if(serviceCount>0 && await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDBKProviderService WHERE CompanyID=@c AND ProviderID=@p AND ServiceID=@s",ct,("@c",Company),("@p",provider),("@s",item.ServiceId))==0)return Invalid("ผู้ให้บริการไม่ได้รับบริการนี้");
                    var scheduleCount=await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDBKProviderSchedule WHERE CompanyID=@c AND ProviderID=@p",ct,("@c",Company),("@p",provider));
                    if(scheduleCount>0)
                    {
                        var zone=TimeZoneInfo.FindSystemTimeZoneById("Asia/Bangkok");
                        var start=TimeZoneInfo.ConvertTime(input.StartsAt,zone);
                        var end=TimeZoneInfo.ConvertTime(input.EndsAt,zone);
                        var day=((int)start.DayOfWeek+6)%7+1;
                        if(start.Date!=end.Date || await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDBKProviderSchedule WHERE CompanyID=@c AND ProviderID=@p AND WeekdayNumber=@day AND StartsAt<=@start AND EndsAt>=@end",ct,("@c",Company),("@p",provider),("@day",day),("@start",start.TimeOfDay),("@end",end.TimeOfDay))==0)return Invalid("เลือกเวลาที่อยู่ในตารางงานของผู้ให้บริการ");
                    }
                    var busy=await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDBKBookingService L JOIN dbo.TDBKBooking B ON B.CompanyID=L.CompanyID AND B.BookingID=L.BookingID WHERE L.CompanyID=@c AND L.ProviderID=@p AND B.StatusCode IN(N'BOOKED',N'CONFIRMED',N'IN_SERVICE') AND B.StartsAt<@to AND B.EndsAt>@from",ct,("@c",Company),("@p",provider),("@from",input.StartsAt.UtcDateTime),("@to",input.EndsAt.UtcDateTime));
                    if(busy>0)return Conflict(new{message="ผู้ให้บริการไม่ว่าง",description="เลือกผู้ให้บริการหรือช่วงเวลาอื่น"});
                }
                if(resource>0)
                {
                    var restricted=await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDBKResourceService WHERE CompanyID=@c AND ResourceID=@r",ct,("@c",Company),("@r",resource));
                    if(restricted>0 && await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDBKResourceService WHERE CompanyID=@c AND ResourceID=@r AND ServiceID=@s",ct,("@c",Company),("@r",resource),("@s",item.ServiceId))==0)return Invalid("ห้องหรือกรงไม่รองรับบริการนี้");
                }
                var price=Convert.ToDecimal(found[0]["Price"]);
                total+=price;
                services.Add((item,price));
            }
            var seq=await PetDb.Id(db,tx,"SELECT NEXT VALUE FOR dbo.TDBKBookingNoSeq",ct);
            var number=$"BK{DateTime.UtcNow:yyyyMMdd}-{seq:000000}";
            var booking=await PetDb.Id(db,tx,"INSERT dbo.TDBKBooking(CompanyID,BookingNo,MemberID,GuestName,GuestPhone,BranchID,StartsAt,EndsAt,StatusCode,TotalAmount,CreatedBy,Note) VALUES(@c,@number,@member,@guest,@phone,@branch,@from,@to,N'BOOKED',@total,@actor,@note);SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,("@c",Company),("@number",number),("@member",pet[0]["MemberID"]),("@guest",pet[0]["CusName"]),("@phone",pet[0]["Phone"]),("@branch",input.BranchId),("@from",input.StartsAt.UtcDateTime),("@to",input.EndsAt.UtcDateTime),("@total",total),("@actor",Actor),("@note",input.Note));
            foreach(var entry in services)
                await PetDb.Exec(db,tx,"INSERT dbo.TDBKBookingService(CompanyID,BookingID,ServiceID,ProviderID,ResourceID,PriceSnapshot,DiscountSnapshot,NetAmount) VALUES(@c,@booking,@service,@provider,@resource,@price,0,@price)",ct,("@c",Company),("@booking",booking),("@service",entry.Item.ServiceId),("@provider",entry.Item.ProviderId),("@resource",resource>0?resource:null),("@price",entry.Price));
            var stay=await PetDb.Id(db,tx,"INSERT dbo.TDPTStay(CompanyID,BookingID,PetID,RoomID,StartsAt,EndsAt) VALUES(@c,@booking,@pet,@room,@from,@to);SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,("@c",Company),("@booking",booking),("@pet",input.PetId),("@room",input.RoomId),("@from",input.StartsAt.UtcDateTime),("@to",input.EndsAt.UtcDateTime));
            await PetDb.Exec(db,tx,"INSERT dbo.TDBKBookingAudit(CompanyID,BookingID,ActionCode,ActorUserID) VALUES(@c,@booking,N'CREATE',@actor); INSERT dbo.TDPTAudit(CompanyID,EntityCode,EntityID,ActionCode,ActorID) VALUES(@c,N'STAY',@stay,N'CREATE',@actor)",ct,("@c",Company),("@booking",booking),("@stay",stay),("@actor",Actor));
            await tx.CommitAsync(ct);
            return Created($"/api/company/pet/appointments/{stay}",new{id=stay,bookingId=booking,number,totalAmount=total});
        }
        catch(SqlException){await tx.RollbackAsync(ct);return Conflict(new{message="บันทึกนัดหมายไม่สำเร็จ",description="ข้อมูลเวลาหรือทรัพยากรเปลี่ยนแล้ว กรุณาลองอีกครั้ง"});}
        catch{await tx.RollbackAsync(ct);throw;}
    }
}
public sealed record PetAppointmentRequest(long PetId,long? RoomId,long? BranchId,DateTimeOffset StartsAt,DateTimeOffset EndsAt,IReadOnlyList<PetAppointmentService> Services,string? Note);
public sealed record PetAppointmentService(long ServiceId,long? ProviderId);
