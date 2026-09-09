using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.Json;
using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using LaooMeetingApi.Security;

namespace LaooMeetingApi.Controllers;

[ApiController, Authorize, Route("api/company/meeting-attendance")]
[RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingAttendanceController(IConfiguration configuration, IDataProtectionProvider protectionProvider) : ControllerBase
{
    private const string ManagerScreenCode = "22004";
    private readonly IDataProtector qrProtector = protectionProvider.CreateProtector("LAOO_MEETING.AttendanceQr.v1");

    public sealed record IssueQrRequest([Required] string Kind, long? ParticipantId);
    public sealed record ConsumeQrRequest([Required, StringLength(8192)] string Token);
    public sealed record ReceiptItem(long FoodOrderDetailId, int ReceivedQuantity);
    public sealed record ReceiptRequest([Required] List<ReceiptItem>? Items);
    private sealed record QrPayload(long CompanyId, long BookingId, long SlotId, long RoomId,
        long? ParticipantId, long? EmployeeId, string Kind, DateTimeOffset ExpiresAtUtc);

    private const string SelfSql = """
EXISTS (SELECT 1 FROM dbo.TDADUserEmployee UE
 JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1
 WHERE UE.CompanyID=@company AND UE.UserID=@user AND UE.EmployeeID=P.EmployeeID AND UE.IsActive=1)
""";
    private const string ManagerSql = """
(B.RequesterUserID=@user OR EXISTS (SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@company AND U.UserID=@user AND U.IsCompanyAdmin=1 AND U.IsActive=1)
 OR EXISTS (SELECT 1 FROM dbo.TDADMeetingRoomContact C
 JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=C.EmployeeID AND UE.CompanyID=@company AND UE.UserID=@user AND UE.IsActive=1
 JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=@company AND E.IsActive=1
 WHERE C.RoomID=B.RoomID AND C.IsActive=1))
""";
    private const string SourceSql = """
FROM dbo.TDADMeetingRoomBookingParticipant P
JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
JOIN dbo.TDADEmployee E ON E.EmployeeID=P.EmployeeID AND E.CompanyID=P.CompanyID AND E.IsActive=1
""";
    private bool Scope(out long company,out long user)
    {
        company=0; user=0;
        return User.FindFirstValue("user_type")=="COMPANY_USER"
          && long.TryParse(User.FindFirstValue("company_id"),out company) && company>0
          && long.TryParse(User.FindFirstValue("user_id"),out user) && user>0;
    }
    private static void Bind(SqlCommand cmd,long company,long user,long booking)
    { cmd.Parameters.AddWithValue("@company",company);cmd.Parameters.AddWithValue("@user",user);cmd.Parameters.AddWithValue("@booking",booking); }
    private ObjectResult Denied()=>StatusCode(403,new {message="ไม่มีสิทธิ์เช็กอินรายการนี้",description="กรุณาใช้บัญชีผู้ได้รับคำเชิญหรือผู้ดูแลการประชุมในบริษัทเดียวกัน"});
    private ObjectResult Unavailable()=>StatusCode(503,new {message="ระบบเช็กอินยังไม่พร้อม",description="ยังไม่ได้ติดตั้งโครงสร้างเช็กอิน กรุณาติดต่อผู้ดูแลระบบ"});
    private async Task<bool> Allowed(SqlConnection db,long company,long user,string action,CancellationToken token,string screen="21003")
    {
        if(!long.TryParse(User.FindFirstValue("project_id"),out var project) || project<=0) return false;
        await using var cmd=new SqlCommand("""
SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=@screen AND IsActive=1
 AND (@action='VIEW' OR ScreenType IN (1,2,4)))
AND EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectID=@project AND ProjectCode='LAOO_MEETING' AND IsActive=1)
AND (
 EXISTS(SELECT 1 FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@user AND IsCompanyAdmin=1 AND IsActive=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
 WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE
 JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=@company AND E.IsActive=1
 JOIN dbo.TDADEmployeeRoleGroup ER ON ER.EmployeeID=UE.EmployeeID AND ER.IsActive=1
 JOIN dbo.TDADRoleGroup R ON R.RoleGroupID=ER.RoleGroupID AND R.ScopeType='C' AND R.CompanyID=@company AND R.ProjectID=@project AND R.IsActive=1
 JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=R.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1
 WHERE UE.CompanyID=@company AND UE.UserID=@user AND UE.IsActive=1 AND ER.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
 AND (ER.EffectiveTo IS NULL OR ER.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))
) THEN 1 ELSE 0 END
""",db);
        Bind(cmd,company,user,0);cmd.Parameters.AddWithValue("@project",project);cmd.Parameters.AddWithValue("@action",action);cmd.Parameters.AddWithValue("@screen",screen);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(token))==1;
    }
    private static async Task<bool> Ready(SqlConnection db,CancellationToken token)
    {
        await using var cmd=new SqlCommand("SELECT CASE WHEN OBJECT_ID(N'dbo.TDADMeetingParticipantCheckIn',N'U') IS NULL THEN 0 ELSE 1 END",db);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(token))==1;
    }
    private static async Task<bool> ActiveUser(SqlConnection db,long company,long user,CancellationToken token)
    {
        await using var cmd=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@user AND IsActive=1",db);
        Bind(cmd,company,user,0);
        return Convert.ToInt64(await cmd.ExecuteScalarAsync(token))==1;
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search,[FromQuery] DateOnly? dateFrom,[FromQuery] DateOnly? dateTo,
        [FromQuery] int page=1,[FromQuery] int pageSize=20,CancellationToken token=default)
    {
        if(!Scope(out var company,out var user)) return Denied();
        if(page<1 || pageSize is <1 or >100) return BadRequest(new {message="ตัวกรองไม่ถูกต้อง",description="หน้าต้องเริ่มจาก 1 และจำนวนต่อหน้าต้องอยู่ระหว่าง 1 ถึง 100"});
        var from=dateFrom ?? DateOnly.FromDateTime(DateTime.Today);
        var to=dateTo ?? from;
        if(to<from || to.DayNumber-from.DayNumber>366) return BadRequest(new {message="ช่วงวันที่ไม่ถูกต้อง",description="วันที่สิ้นสุดต้องไม่น้อยกว่าวันที่เริ่ม และเลือกได้ไม่เกิน 366 วัน"});
        search=string.IsNullOrWhiteSpace(search)?null:search.Trim();
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if(!await ActiveUser(db,company,user,token) || !await Allowed(db,company,user,"VIEW",token,ManagerScreenCode)) return Denied();
        if(!await Ready(db,token)) return Ok(new {available=false,total=0,page,pageSize,items=Array.Empty<object>()});
        var where=$"""
WHERE B.CompanyID=@company
 AND S.StartDateTime<DATEADD(day,1,CAST(@to AS datetime2)) AND S.EndDateTime>=CAST(@from AS datetime2)
 AND ((B.BookingStatus='APPROVED') OR (B.BookingStatus='CANCELLED' AND EXISTS(
   SELECT 1 FROM dbo.TDADMeetingParticipantCheckIn CX WHERE CX.CompanyID=B.CompanyID AND CX.BookingSlotID=S.BookingSlotID)))
 AND {ManagerSql}
 AND (@search IS NULL OR B.BookingNo LIKE N'%'+@search+N'%' OR B.Subject LIKE N'%'+@search+N'%'
   OR R.RoomCode LIKE N'%'+@search+N'%' OR R.RoomNameTH LIKE N'%'+@search+N'%')
""";
        await using var count=new SqlCommand($"""
SELECT COUNT_BIG(1)
FROM dbo.TDADMeetingRoomBooking B
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID
JOIN dbo.TDADMeetingRoom R ON R.CompanyID=B.CompanyID AND R.RoomID=B.RoomID
{where};
""",db);
        Bind(count,company,user,0);count.Parameters.AddWithValue("@search",(object?)search??DBNull.Value);
        count.Parameters.AddWithValue("@from",from.ToDateTime(TimeOnly.MinValue));count.Parameters.AddWithValue("@to",to.ToDateTime(TimeOnly.MinValue));
        var total=Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var cmd=new SqlCommand($"""
SELECT B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH,S.BookingSlotID,S.StartDateTime,S.EndDateTime,
 COUNT(DISTINCT CASE WHEN P.InvitationStatus IN ('PENDING','ACCEPTED') THEN P.BookingParticipantID END) ParticipantCount,
 COUNT(DISTINCT CASE WHEN P.InvitationStatus IN ('PENDING','ACCEPTED') AND CI.ParticipantCheckInID IS NOT NULL THEN P.BookingParticipantID END) CheckedInCount
FROM dbo.TDADMeetingRoomBooking B
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID
JOIN dbo.TDADMeetingRoom R ON R.CompanyID=B.CompanyID AND R.RoomID=B.RoomID
LEFT JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.CompanyID=B.CompanyID AND P.BookingID=B.BookingID
LEFT JOIN dbo.TDADMeetingParticipantCheckIn CI ON CI.CompanyID=P.CompanyID AND CI.BookingParticipantID=P.BookingParticipantID AND CI.BookingSlotID=S.BookingSlotID
{where}
GROUP BY B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH,S.BookingSlotID,S.StartDateTime,S.EndDateTime
ORDER BY S.StartDateTime,B.BookingID,S.BookingSlotID OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY;
""",db);
        Bind(cmd,company,user,0);cmd.Parameters.AddWithValue("@search",(object?)search??DBNull.Value);
        cmd.Parameters.AddWithValue("@from",from.ToDateTime(TimeOnly.MinValue));cmd.Parameters.AddWithValue("@to",to.ToDateTime(TimeOnly.MinValue));
        cmd.Parameters.AddWithValue("@offset",(page-1)*pageSize);cmd.Parameters.AddWithValue("@take",pageSize);
        await using var reader=await cmd.ExecuteReaderAsync(token);var items=new List<object>();
        while(await reader.ReadAsync(token)) { var invited=reader.GetInt32(9);var checkedIn=reader.GetInt32(10);items.Add(new {
            bookingId=reader.GetInt64(0),bookingNo=reader.IsDBNull(1)?null:reader.GetString(1),subject=reader.GetString(2),status=reader.GetString(3),
            roomCode=reader.GetString(4),roomName=reader.GetString(5),slotId=reader.GetInt64(6),startDateTime=reader.GetDateTime(7),endDateTime=reader.GetDateTime(8),
            participantCount=invited,checkedInCount=checkedIn,pendingCheckInCount=Math.Max(0,invited-checkedIn)}); }
        return Ok(new {available=true,total,page,pageSize,items});
    }

    [HttpGet("{bookingId:long}")]
    public async Task<IActionResult> Get(long bookingId,[FromQuery] long? slotId,CancellationToken token)
    {
        if(!Scope(out var company,out var user)) return Denied();
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if(!await ActiveUser(db,company,user,token)) return Denied();
        if(!await Ready(db,token)) return Ok(new {available=false,items=Array.Empty<object>()});
        var selfView=await Allowed(db,company,user,"VIEW",token);
        var managerView=await Allowed(db,company,user,"VIEW",token,ManagerScreenCode);
        var selfEdit=selfView && await Allowed(db,company,user,"EDIT",token);
        var managerEdit=managerView && await Allowed(db,company,user,"EDIT",token,ManagerScreenCode);
        var qrReady=await ReceiptReady(db,token);
        var sql=$"""
SELECT P.BookingParticipantID,E.FullName,S.BookingSlotID,S.StartDateTime,S.EndDateTime,C.CheckInDate,C.CheckInByUserID,C.CheckInMethod,
 CASE WHEN B.BookingStatus='APPROVED' AND P.InvitationStatus IN ('PENDING','ACCEPTED')
 AND S.StartDateTime<=GETDATE() AND S.EndDateTime>GETDATE() AND C.ParticipantCheckInID IS NULL
 AND ((@selfEdit=1 AND {SelfSql}) OR (@managerEdit=1 AND {ManagerSql})) THEN 1 ELSE 0 END,
 CASE WHEN @qrReady=1 AND B.BookingStatus='APPROVED' AND S.EndDateTime>GETDATE()
 AND @managerEdit=1 AND {ManagerSql} THEN 1 ELSE 0 END,
 CASE WHEN @qrReady=1 AND B.BookingStatus='APPROVED' AND S.EndDateTime>GETDATE()
 AND P.InvitationStatus IN ('PENDING','ACCEPTED')
 AND ((@selfView=1 AND {SelfSql}) OR (@managerEdit=1 AND {ManagerSql})) THEN 1 ELSE 0 END,
 CASE WHEN @qrReady=1 AND B.BookingStatus='APPROVED' AND S.StartDateTime<=GETDATE() AND S.EndDateTime>GETDATE()
 AND P.InvitationStatus IN ('PENDING','ACCEPTED') AND @managerEdit=1 AND {ManagerSql} THEN 1 ELSE 0 END,
 CASE WHEN @qrReady=1 AND B.BookingStatus='APPROVED' AND S.StartDateTime<=GETDATE() AND S.EndDateTime>GETDATE()
 AND P.InvitationStatus IN ('PENDING','ACCEPTED') AND C.ParticipantCheckInID IS NULL
 AND @selfEdit=1 AND {SelfSql} THEN 1 ELSE 0 END
{SourceSql}
LEFT JOIN dbo.TDADMeetingParticipantCheckIn C ON C.CompanyID=P.CompanyID AND C.BookingParticipantID=P.BookingParticipantID AND C.BookingSlotID=S.BookingSlotID
WHERE B.CompanyID=@company AND B.BookingID=@booking AND (@slot IS NULL OR S.BookingSlotID=@slot)
 AND ((@selfView=1 AND {SelfSql}) OR (@managerView=1 AND {ManagerSql}))
ORDER BY S.StartDateTime,E.FullName,P.BookingParticipantID;
""";
        await using var cmd=new SqlCommand(sql,db);Bind(cmd,company,user,bookingId);
        cmd.Parameters.AddWithValue("@selfView",selfView);cmd.Parameters.AddWithValue("@managerView",managerView);
        cmd.Parameters.AddWithValue("@selfEdit",selfEdit);cmd.Parameters.AddWithValue("@managerEdit",managerEdit);
        cmd.Parameters.AddWithValue("@qrReady",qrReady);
        cmd.Parameters.AddWithValue("@slot",(object?)slotId??DBNull.Value);
        await using var reader=await cmd.ExecuteReaderAsync(token);
        var items=new List<object>();
        while(await reader.ReadAsync(token)) items.Add(new {
            participantId=reader.GetInt64(0),participantName=reader.GetString(1),slotId=reader.GetInt64(2),
            startDateTime=reader.GetDateTime(3),endDateTime=reader.GetDateTime(4),
            checkInDate=reader.IsDBNull(5)?(DateTime?)null:DateTime.SpecifyKind(reader.GetDateTime(5),DateTimeKind.Utc),
            checkInByUserId=reader.IsDBNull(6)?(long?)null:reader.GetInt64(6),
            method=reader.IsDBNull(7)?null:reader.GetString(7),canCheckIn=reader.GetInt32(8)==1,
            canIssueRoomQr=reader.GetInt32(9)==1,canIssuePersonalQr=reader.GetInt32(10)==1,
            canManualCheckIn=reader.GetInt32(8)==1,canScanRoomQr=reader.GetInt32(12)==1,canScanPersonalQr=reader.GetInt32(11)==1 });
        return Ok(new {available=true,items});
    }

    public sealed record FoodReceiptData(long FoodOrderDetailId,long FoodId,string FoodName,int OrderedQuantity,
        int ReceivedQuantity,long? ReceivedByUserId,DateTime? ReceivedAtUtc,long? ReceiptSlotId)
    {
        public int RemainingQuantity=>OrderedQuantity-ReceivedQuantity;
    }

    [HttpGet("{bookingId:long}/{participantId:long}/{slotId:long}/food-receipt")]
    public Task<IActionResult> GetFoodReceipt(long bookingId,long participantId,long slotId,CancellationToken token)
        => FoodReceiptCore(bookingId,participantId,slotId,null,token);

    [HttpPut("{bookingId:long}/{participantId:long}/{slotId:long}/food-receipt")]
    public Task<IActionResult> SaveFoodReceipt(long bookingId,long participantId,long slotId,ReceiptRequest request,CancellationToken token)
    {
        if(request.Items is null || request.Items.Count is <1 or >100
            || request.Items.Any(x=>x is null || x.FoodOrderDetailId<=0 || x.ReceivedQuantity is <0 or >99)
            || request.Items.Select(x=>x.FoodOrderDetailId).Distinct().Count()!=request.Items.Count)
            return Task.FromResult<IActionResult>(BadRequest(new {message="จำนวนรับอาหารไม่ถูกต้อง",description="ส่งรายการไม่ซ้ำ 1 ถึง 100 รายการ พร้อมยอดรับสะสมเป็นจำนวนเต็ม 0 ถึง 99"}));
        return FoodReceiptCore(bookingId,participantId,slotId,request,token);
    }

    private async Task<IActionResult> FoodReceiptCore(long bookingId,long participantId,long slotId,ReceiptRequest? request,CancellationToken token)
    {
        if(!Scope(out var company,out var user)) return Denied();
        if(bookingId<=0 || participantId<=0 || slotId<=0) return Ineligible();
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if(!await ActiveUser(db,company,user,token)) return Denied();
        if(!await Ready(db,token) || !await ReceiptReady(db,token)) return Unavailable();
        var selfView=await Allowed(db,company,user,"VIEW",token);
        var managerView=await Allowed(db,company,user,"VIEW",token,ManagerScreenCode);
        var selfEdit=selfView && await Allowed(db,company,user,"EDIT",token);
        var managerEdit=managerView && await Allowed(db,company,user,"EDIT",token,ManagerScreenCode);
        if(request is null ? !selfView && !managerView : !selfEdit && !managerEdit) return Denied();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        var source=request is null?SourceSql:SourceSql.Replace("BookingParticipant P","BookingParticipant P WITH (UPDLOCK,HOLDLOCK)");
        await using var access=new SqlCommand($"""
SELECT C.ParticipantCheckInID,C.CheckInDate,
 CASE WHEN B.BookingStatus='APPROVED' AND P.InvitationStatus IN ('PENDING','ACCEPTED')
 AND S.StartDateTime<=GETDATE() AND S.EndDateTime>GETDATE() AND C.ParticipantCheckInID IS NOT NULL
 AND ((@selfEdit=1 AND {SelfSql}) OR (@managerEdit=1 AND {ManagerSql})) THEN 1 ELSE 0 END,
 CASE WHEN @selfEdit=1 AND {SelfSql} THEN 'SELF' ELSE 'DELEGATE' END
{source}
LEFT JOIN dbo.TDADMeetingParticipantCheckIn C ON C.CompanyID=P.CompanyID AND C.BookingParticipantID=P.BookingParticipantID AND C.BookingSlotID=S.BookingSlotID
WHERE B.CompanyID=@company AND B.BookingID=@booking AND P.BookingParticipantID=@participant AND S.BookingSlotID=@slot
 AND ((@selfView=1 AND {SelfSql}) OR (@managerView=1 AND {ManagerSql}));
""",db,tx);
        Bind(access,company,user,bookingId);access.Parameters.AddWithValue("@participant",participantId);access.Parameters.AddWithValue("@slot",slotId);
        access.Parameters.AddWithValue("@selfView",selfView);access.Parameters.AddWithValue("@managerView",managerView);
        access.Parameters.AddWithValue("@selfEdit",selfEdit);access.Parameters.AddWithValue("@managerEdit",managerEdit);
        long? checkInId;DateTime? checkInDate;bool canReceive;string receiptMethod;
        await using(var reader=await access.ExecuteReaderAsync(token))
        {
            if(!await reader.ReadAsync(token)) return Denied();
            checkInId=reader.IsDBNull(0)?null:reader.GetInt64(0);
            checkInDate=reader.IsDBNull(1)?null:DateTime.SpecifyKind(reader.GetDateTime(1),DateTimeKind.Utc);
            canReceive=reader.GetInt32(2)==1;receiptMethod=reader.GetString(3);
        }
        if(request is not null && !canReceive) return Conflict(new {message="ยังรับอาหารรอบนี้ไม่ได้",description="ต้องเช็กอินก่อน และอยู่ในช่วงเวลาของรอบประชุมที่อนุมัติแล้ว พร้อมสิทธิ์รับอาหารของตนเองหรือรับแทน"});

        // Lock the order header before details, matching SaveFoodOrder. The quantity cap is booking-wide.
        await using var order=new SqlCommand("SELECT BookingFoodOrderID FROM dbo.TDADMeetingBookingFoodOrder WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND BookingID=@booking AND BookingParticipantID=@participant",db,tx);
        Bind(order,company,user,bookingId);order.Parameters.AddWithValue("@participant",participantId);
        var orderId=await order.ExecuteScalarAsync(token);
        var items=orderId is null?new List<FoodReceiptData>():await ReadReceipts(db,tx,company,Convert.ToInt64(orderId),token);
        if(request is not null)
        {
            var existing=items.ToDictionary(x=>x.FoodOrderDetailId);
            // Validate the whole request before the first mutation; decreasing an issued quantity is forbidden.
            foreach(var item in request.Items!)
            {
                if(!existing.TryGetValue(item.FoodOrderDetailId,out var current)
                    || item.ReceivedQuantity<current.ReceivedQuantity || item.ReceivedQuantity>current.OrderedQuantity)
                    return Conflict(new {message="บันทึกรับอาหารไม่ได้",description="รายการต้องอยู่ในคำสั่งอาหารนี้ ยอดรับต้องไม่น้อยกว่ายอดเดิมและไม่เกินยอดสั่ง กรุณาโหลดข้อมูลล่าสุด"});
            }
            foreach(var item in request.Items!.OrderBy(x=>x.FoodOrderDetailId))
            {
                var previous=existing[item.FoodOrderDetailId].ReceivedQuantity;
                if(previous==item.ReceivedQuantity) continue; // Retries preserve original actor, timestamp and history.
                await using var save=new SqlCommand("""
DECLARE @now datetime2(7)=SYSUTCDATETIME();
UPDATE dbo.TDADMeetingFoodReceipt SET ReceivedQuantity=@quantity,ReceivedByUserID=@user,
 ReceivedAtUtc=@now,ParticipantCheckInID=@checkIn,ReceiptMethod=@method
WHERE CompanyID=@company AND BookingFoodOrderDetailID=@detail;
IF @@ROWCOUNT=0
 INSERT dbo.TDADMeetingFoodReceipt(CompanyID,BookingFoodOrderDetailID,ParticipantCheckInID,ReceivedQuantity,ReceivedByUserID,ReceivedAtUtc,ReceiptMethod)
 VALUES(@company,@detail,@checkIn,@quantity,@user,@now,@method);
INSERT dbo.TDADMeetingFoodReceiptHistory(FoodReceiptID,ParticipantCheckInID,PreviousQuantity,ReceivedQuantity,ReceivedByUserID,ReceivedAtUtc,ReceiptMethod)
SELECT FoodReceiptID,@checkIn,@previous,@quantity,@user,@now,@method FROM dbo.TDADMeetingFoodReceipt
 WHERE CompanyID=@company AND BookingFoodOrderDetailID=@detail;
""",db,tx);
                Bind(save,company,user,bookingId);save.Parameters.AddWithValue("@detail",item.FoodOrderDetailId);
                save.Parameters.AddWithValue("@checkIn",checkInId!.Value);save.Parameters.AddWithValue("@quantity",item.ReceivedQuantity);
                save.Parameters.AddWithValue("@previous",previous);save.Parameters.AddWithValue("@method",receiptMethod);
                await save.ExecuteNonQueryAsync(token);
            }
            items=await ReadReceipts(db,tx,company,Convert.ToInt64(orderId),token);
        }
        await tx.CommitAsync(token);
        return Ok(new {bookingId,participantId,slotId,checkInDate,canReceive=canReceive && items.Any(x=>x.RemainingQuantity>0),items});
    }

    private static async Task<List<FoodReceiptData>> ReadReceipts(SqlConnection db,SqlTransaction tx,long company,long orderId,CancellationToken token)
    {
        await using var cmd=new SqlCommand("""
SELECT D.BookingFoodOrderDetailID,D.FoodID,F.FoodNameTH,D.Quantity,ISNULL(R.ReceivedQuantity,0),R.ReceivedByUserID,R.ReceivedAtUtc,C.BookingSlotID
FROM dbo.TDADMeetingBookingFoodOrderDetail D WITH (UPDLOCK,HOLDLOCK)
JOIN dbo.TDADMeetingBookingFoodOrder H ON H.BookingFoodOrderID=D.BookingFoodOrderID AND H.CompanyID=@company
JOIN dbo.TDADMeetingFood F ON F.FoodID=D.FoodID AND F.CompanyID=H.CompanyID
LEFT JOIN dbo.TDADMeetingFoodReceipt R WITH (UPDLOCK,HOLDLOCK) ON R.CompanyID=H.CompanyID AND R.BookingFoodOrderDetailID=D.BookingFoodOrderDetailID
LEFT JOIN dbo.TDADMeetingParticipantCheckIn C ON C.ParticipantCheckInID=R.ParticipantCheckInID AND C.CompanyID=R.CompanyID
WHERE H.BookingFoodOrderID=@order ORDER BY D.BookingFoodOrderDetailID;
""",db,tx);
        cmd.Parameters.AddWithValue("@company",company);cmd.Parameters.AddWithValue("@order",orderId);
        await using var reader=await cmd.ExecuteReaderAsync(token);
        var items=new List<FoodReceiptData>();
        while(await reader.ReadAsync(token)) items.Add(new FoodReceiptData(reader.GetInt64(0),reader.GetInt64(1),reader.GetString(2),reader.GetInt32(3),reader.GetInt32(4),
            reader.IsDBNull(5)?null:reader.GetInt64(5),reader.IsDBNull(6)?null:DateTime.SpecifyKind(reader.GetDateTime(6),DateTimeKind.Utc),reader.IsDBNull(7)?null:reader.GetInt64(7)));
        return items;
    }

    private ObjectResult Ineligible()=>Conflict(new {message="รายการนี้ยังดำเนินการไม่ได้",description="ตรวจสอบสิทธิ์ คำเชิญ สถานะอนุมัติ และช่วงเวลาประชุม แล้วลองใหม่"});
    private ObjectResult InvalidQr()=>BadRequest(new {message="QR ไม่ถูกต้องหรือหมดอายุ",description="กรุณาขอ QR ใหม่ของบริษัทและรอบประชุมนี้ แล้วสแกนอีกครั้ง"});
    private static async Task<bool> ReceiptReady(SqlConnection db,CancellationToken token)
    {
        await using var cmd=new SqlCommand("""
SELECT CASE WHEN OBJECT_ID(N'dbo.TDADMeetingFoodReceipt',N'U') IS NOT NULL
 AND OBJECT_ID(N'dbo.TDADMeetingFoodReceiptHistory',N'U') IS NOT NULL
 AND OBJECT_ID(N'dbo.TDADMeetingBookingFoodOrder',N'U') IS NOT NULL
 AND OBJECT_ID(N'dbo.TDADMeetingBookingFoodOrderDetail',N'U') IS NOT NULL
 AND COL_LENGTH(N'dbo.TDADMeetingFoodReceipt',N'ReceivedAtUtc') IS NOT NULL
 AND COL_LENGTH(N'dbo.TDADMeetingFoodReceiptHistory',N'PreviousQuantity') IS NOT NULL
 AND EXISTS(SELECT 1 FROM sys.triggers WHERE object_id=OBJECT_ID(N'dbo.TR_MeetingFoodReceipt_Validate') AND is_disabled=0)
 AND EXISTS(SELECT 1 FROM sys.triggers WHERE object_id=OBJECT_ID(N'dbo.TR_MeetingFoodOrderDetail_ProtectReceipt') AND is_disabled=0)
 AND EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDADMeetingParticipantCheckIn')
  AND name=N'CK_MeetingParticipantCheckIn_Method' AND is_disabled=0 AND is_not_trusted=0
  AND definition LIKE '%QR_SELF%' AND definition LIKE '%QR_STAFF%')
 THEN 1 ELSE 0 END;
""",db);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(token))==1;
    }

    // Tokens are opaque QR contents. Never accept a client-supplied attendance method or scope.
    [HttpPost("{bookingId:long}/{slotId:long}/qr-token")]
    [ResponseCache(NoStore=true,Location=ResponseCacheLocation.None)]
    public async Task<IActionResult> IssueQr(long bookingId,long slotId,IssueQrRequest request,CancellationToken token)
    {
        if(!Scope(out var company,out var user)) return Denied();
        var kind=request.Kind?.Trim().ToUpperInvariant();
        if(bookingId<=0 || slotId<=0 || kind is not ("ROOM" or "PERSONAL")
            || (kind=="ROOM" && request.ParticipantId is not null)
            || (kind=="PERSONAL" && request.ParticipantId is not >0)) return InvalidQr();
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if(!await ActiveUser(db,company,user,token)) return Denied();
        if(!await Ready(db,token) || !await ReceiptReady(db,token)) return Unavailable();
        var selfView=kind=="PERSONAL" && await Allowed(db,company,user,"VIEW",token);
        var managerEdit=await Allowed(db,company,user,"VIEW",token,ManagerScreenCode) && await Allowed(db,company,user,"EDIT",token,ManagerScreenCode);
        if(!selfView && !managerEdit) return Denied();
        var sql=$"""
SELECT B.RoomID,DATEDIFF(second,GETDATE(),S.EndDateTime),P.EmployeeID
FROM dbo.TDADMeetingRoomBooking B
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.CompanyID=B.CompanyID AND P.BookingID=B.BookingID AND P.BookingParticipantID=@participant
WHERE B.CompanyID=@company AND B.BookingID=@booking AND S.BookingSlotID=@slot
 AND B.BookingStatus='APPROVED' AND S.EndDateTime>GETDATE()
 AND ((@kind='ROOM' AND @managerEdit=1 AND {ManagerSql})
 OR (@kind='PERSONAL' AND P.InvitationStatus IN ('PENDING','ACCEPTED')
 AND EXISTS(SELECT 1 FROM dbo.TDADEmployee E WHERE E.CompanyID=@company AND E.EmployeeID=P.EmployeeID AND E.IsActive=1)
 AND ((@selfView=1 AND {SelfSql}) OR (@managerEdit=1 AND {ManagerSql}))));
""";
        await using var cmd=new SqlCommand(sql,db);Bind(cmd,company,user,bookingId);
        cmd.Parameters.AddWithValue("@slot",slotId);cmd.Parameters.AddWithValue("@participant",request.ParticipantId ?? 0);
        cmd.Parameters.AddWithValue("@kind",kind);cmd.Parameters.AddWithValue("@selfView",selfView);cmd.Parameters.AddWithValue("@managerEdit",managerEdit);
        // Take the UTC baseline before querying so query latency cannot extend validity past slot end.
        var issuedAt=DateTimeOffset.UtcNow;
        await using var reader=await cmd.ExecuteReaderAsync(token);
        if(!await reader.ReadAsync(token)) return Ineligible();
        var seconds=Math.Min(900,reader.GetInt32(1));
        if(seconds<=0) return Ineligible();
        var expires=issuedAt.AddSeconds(seconds);
        var payload=new QrPayload(company,bookingId,slotId,reader.GetInt64(0),request.ParticipantId,
            reader.IsDBNull(2)?null:reader.GetInt64(2),kind!,expires);
        Response.Headers.CacheControl="no-store";
        return Ok(new {token=qrProtector.Protect(JsonSerializer.Serialize(payload)),expiresAtUtc=expires,kind,bookingId,slotId,participantId=request.ParticipantId});
    }

    [HttpPost("qr-check-in")]
    public Task<IActionResult> ConsumeQr(ConsumeQrRequest request,CancellationToken token)
    {
        if(!Scope(out var company,out _)) return Task.FromResult<IActionResult>(Denied());
        QrPayload? qr;
        try
        {
            if(string.IsNullOrWhiteSpace(request.Token) || request.Token.Length>8192) return Task.FromResult<IActionResult>(InvalidQr());
            qr=JsonSerializer.Deserialize<QrPayload>(qrProtector.Unprotect(request.Token));
        }
        catch(Exception ex) when(ex is CryptographicException or JsonException or FormatException or ArgumentException)
        { return Task.FromResult<IActionResult>(InvalidQr()); }
        if(qr is null || qr.CompanyId!=company || qr.BookingId<=0 || qr.SlotId<=0 || qr.RoomId<=0
            || qr.ExpiresAtUtc<=DateTimeOffset.UtcNow || qr.Kind is not ("ROOM" or "PERSONAL")
            || (qr.Kind=="ROOM" && (qr.ParticipantId is not null || qr.EmployeeId is not null))
            || (qr.Kind=="PERSONAL" && (qr.ParticipantId is not >0 || qr.EmployeeId is not >0)))
            return Task.FromResult<IActionResult>(InvalidQr());
        return CheckInCore(qr.BookingId,qr.ParticipantId ?? 0,qr.SlotId,qr,token);
    }

    [HttpPut("{bookingId:long}/{participantId:long}/{slotId:long}")]
    public Task<IActionResult> CheckIn(long bookingId,long participantId,long slotId,CancellationToken token)
        => bookingId<=0 || participantId<=0 || slotId<=0
            ? Task.FromResult<IActionResult>(Ineligible()) : CheckInCore(bookingId, participantId, slotId, null, token);

    private async Task<IActionResult> CheckInCore(long bookingId,long participantId,long slotId,QrPayload? qr,CancellationToken token)
    {
        if(!Scope(out var company,out var user)) return Denied();
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if(!await ActiveUser(db,company,user,token)) return Denied();
        if(!await Ready(db,token)) return Unavailable();
        if(qr is not null && !await ReceiptReady(db,token)) return Unavailable();
        var selfEdit=(qr is null || qr.Kind=="ROOM") && await Allowed(db,company,user,"VIEW",token) && await Allowed(db,company,user,"EDIT",token);
        var managerEdit=qr?.Kind!="ROOM" && await Allowed(db,company,user,"VIEW",token,ManagerScreenCode) && await Allowed(db,company,user,"EDIT",token,ManagerScreenCode);
        if(!selfEdit && !managerEdit) return Denied();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        var sql=$"""
SELECT P.BookingParticipantID,CASE WHEN @selfEdit=1 AND {SelfSql} THEN 1 ELSE 0 END
{SourceSql.Replace("BookingParticipant P", "BookingParticipant P WITH (UPDLOCK,HOLDLOCK)")}
WHERE B.CompanyID=@company AND B.BookingID=@booking AND (@participant=0 OR P.BookingParticipantID=@participant) AND S.BookingSlotID=@slot
AND (@room=0 OR B.RoomID=@room) AND (@employee=0 OR P.EmployeeID=@employee)
AND ((@selfEdit=1 AND {SelfSql}) OR (@managerEdit=1 AND {ManagerSql}))
AND B.BookingStatus='APPROVED' AND P.InvitationStatus IN ('PENDING','ACCEPTED')
AND S.StartDateTime<=GETDATE() AND S.EndDateTime>GETDATE();
""";
        await using var eligible=new SqlCommand(sql,db,tx);Bind(eligible,company,user,bookingId);
        eligible.Parameters.AddWithValue("@selfEdit",selfEdit);eligible.Parameters.AddWithValue("@managerEdit",managerEdit);
        eligible.Parameters.AddWithValue("@participant",participantId);eligible.Parameters.AddWithValue("@slot",slotId);
        eligible.Parameters.AddWithValue("@room",qr?.RoomId ?? 0);
        eligible.Parameters.AddWithValue("@employee",qr?.EmployeeId ?? 0);
        bool isSelf;
        await using(var participants=await eligible.ExecuteReaderAsync(token))
        {
            if(!await participants.ReadAsync(token)) return Ineligible();
            participantId=participants.GetInt64(0);
            isSelf=participants.GetInt32(1)==1;
            if(await participants.ReadAsync(token)) return Conflict(new {message="พบผู้เข้าร่วมมากกว่าหนึ่งคนในบัญชีนี้",description="กรุณาให้ผู้ดูแลสแกน QR ส่วนตัวหรือเช็กอินแทน"});
        }
        if(qr is not null && qr.ExpiresAtUtc<=DateTimeOffset.UtcNow) return InvalidQr();
        var method=qr?.Kind switch { "ROOM" => "QR_SELF", "PERSONAL" => "QR_STAFF", _ => isSelf?"SELF":"MANUAL" };
        await using var save=new SqlCommand("""
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMeetingParticipantCheckIn WITH (UPDLOCK,HOLDLOCK)
 WHERE CompanyID=@company AND BookingParticipantID=@participant AND BookingSlotID=@slot)
 INSERT dbo.TDADMeetingParticipantCheckIn(CompanyID,BookingParticipantID,BookingSlotID,CheckInByUserID,CheckInMethod)
 VALUES(@company,@participant,@slot,@user,@method);
SELECT CheckInDate,CheckInByUserID,CheckInMethod FROM dbo.TDADMeetingParticipantCheckIn WHERE CompanyID=@company AND BookingParticipantID=@participant AND BookingSlotID=@slot;
""",db,tx);
        Bind(save,company,user,bookingId);save.Parameters.AddWithValue("@participant",participantId);save.Parameters.AddWithValue("@slot",slotId);save.Parameters.AddWithValue("@method",method);
        DateTime date; long actor; string savedMethod;
        await using(var saved=await save.ExecuteReaderAsync(token))
        {
            await saved.ReadAsync(token);
            date=saved.GetDateTime(0); actor=saved.GetInt64(1); savedMethod=saved.GetString(2);
        }
        await tx.CommitAsync(token);
        return Ok(new {bookingId,participantId,slotId,checkInDate=DateTime.SpecifyKind(date,DateTimeKind.Utc),checkInByUserId=actor,method=savedMethod});
    }
}
