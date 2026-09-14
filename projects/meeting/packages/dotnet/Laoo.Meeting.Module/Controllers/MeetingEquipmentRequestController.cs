using System.Data;
using System.Security.Claims;
using LaooMeetingApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Authorize, Route("api/company/meeting-equipment-requests")]
[RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingEquipmentRequestController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "22005";
    private const long MeetingProjectId = 2;

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var db = await Open(token);
        return Ok(new { view = await Allowed(db, "VIEW", token), edit = await Allowed(db, "EDIT", token) });
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await CompanyAdmin(db, company, user, token)) return Forbid();
        return Ok(new { requireEquipmentRequestReview = await RequiresReview(db, company, token) });
    }

    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(EquipmentRequestSettings request, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await CompanyAdmin(db, company, user, token)) return Forbid();
        const string sql = """
IF EXISTS(SELECT 1 FROM dbo.TDSTCompanySetupSystemMeeting WHERE CompanyID=@company AND ProjectID=@project)
 UPDATE dbo.TDSTCompanySetupSystemMeeting SET RequireEquipmentRequestReview=@review,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ProjectID=@project;
ELSE
 INSERT dbo.TDSTCompanySetupSystemMeeting(CompanyID,ProjectID,RequireEquipmentRequestReview,CreateBy) VALUES(@company,@project,@review,@user);
""";
        await using var cmd = new SqlCommand(sql, db);
        Add(cmd, "@company", company); Add(cmd, "@project", MeetingProjectId); Add(cmd, "@review", request.RequireEquipmentRequestReview); Add(cmd, "@user", user);
        await cmd.ExecuteNonQueryAsync(token);
        return NoContent();
    }

    [HttpGet]
    public async Task<IActionResult> List(string? status, DateTime? dateFrom, DateTime? dateTo, long? roomId, long? departmentId, long? requesterUserId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await Allowed(db, "VIEW", token)) return Forbid();
        var admin = await CompanyAdmin(db, company, user, token);
        var sql = $"""
SELECT D.EquipmentRequestDetailID,H.EquipmentRequestID,H.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,
 MIN(S.StartDateTime),MAX(S.EndDateTime),I.ItemID,I.ItemName,I.UnitCode,D.Quantity,D.Remark,D.StatusCode,D.ResultRemark,
 D.ResponsibleDepartmentOrgUnitID,DEP.NameTH,H.RequestedByUserID,H.RequestedByName,H.RequestedByRoleCode,H.CreateDate,H.RequiresReview,CASE WHEN H.RequestedByUserID=@user THEN 1 ELSE 0 END,
 CASE WHEN @admin=1 OR B.RequesterUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql} THEN 1 ELSE 0 END,
 CASE WHEN @admin=1 OR B.RequesterUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql} OR (@edit=1 AND EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1 WHERE UE.CompanyID=@company AND UE.UserID=@user AND UE.IsActive=1 AND E.DepartmentOrgUnitID=D.ResponsibleDepartmentOrgUnitID)) THEN 1 ELSE 0 END,
 D.ReviewedByUserID,D.ReviewedByName,D.ReviewedDateTime,D.ReviewRemark,D.ProcessedByUserID,D.ProcessedDateTime,
 CASE WHEN D.StatusCode IN('WAITING_REVIEW','PENDING') AND MIN(S.StartDateTime)>GETDATE()
 AND EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingEquipmentPlan EP JOIN dbo.TDADMeetingRoomBooking EB ON EB.BookingID=EP.BookingID AND EB.CompanyID=EP.CompanyID
 WHERE EP.BookingID=H.BookingID AND EP.CompanyID=B.CompanyID AND EP.IsActive=1 AND EP.RequestCutoffDateTime>GETDATE() AND EB.BookingStatus='APPROVED')
 AND (@admin=1 OR B.RequesterUserID=@user OR H.RequestedByUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql}) THEN 1 ELSE 0 END
FROM dbo.TDADMeetingBookingEquipmentRequestDetail D
JOIN dbo.TDADMeetingBookingEquipmentRequest H ON H.EquipmentRequestID=D.EquipmentRequestID AND H.CompanyID=D.CompanyID
JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=H.BookingID AND B.CompanyID=H.CompanyID
JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
JOIN dbo.TDIVItem I ON I.ItemID=D.ItemID AND I.CompanyID=D.CompanyID
LEFT JOIN dbo.TDADOrganizationUnit DEP ON DEP.OrgUnitID=D.ResponsibleDepartmentOrgUnitID AND DEP.CompanyID=D.CompanyID
WHERE D.CompanyID=@company AND (@status IS NULL OR D.StatusCode=@status) AND (@room IS NULL OR B.RoomID=@room)
 AND (@department IS NULL OR D.ResponsibleDepartmentOrgUnitID=@department) AND (@requester IS NULL OR H.RequestedByUserID=@requester)
 AND (@from IS NULL OR S.StartDateTime>=@from) AND (@to IS NULL OR S.StartDateTime<DATEADD(day,1,@to))
 AND (@admin=1 OR H.RequestedByUserID=@user
   OR B.RequesterUserID=@user OR {MeetingRoomAdminAccess.BookingRoomSql}
   OR (D.StatusCode IN('PENDING','IN_PROGRESS','COMPLETED','DEPARTMENT_REJECTED') AND EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1 WHERE UE.CompanyID=@company AND UE.UserID=@user AND UE.IsActive=1 AND E.DepartmentOrgUnitID=D.ResponsibleDepartmentOrgUnitID)))
GROUP BY D.EquipmentRequestDetailID,H.EquipmentRequestID,H.BookingID,B.BookingNo,B.Subject,B.RequesterUserID,B.RoomID,B.CompanyID,R.RoomCode,R.RoomNameTH,I.ItemID,I.ItemName,I.UnitCode,D.Quantity,D.Remark,D.StatusCode,D.ResultRemark,D.ResponsibleDepartmentOrgUnitID,DEP.NameTH,H.RequestedByUserID,H.RequestedByName,H.RequestedByRoleCode,H.CreateDate,H.RequiresReview,CASE WHEN H.RequestedByUserID=@user THEN 1 ELSE 0 END,D.ReviewedByUserID,D.ReviewedByName,D.ReviewedDateTime,D.ReviewRemark,D.ProcessedByUserID,D.ProcessedDateTime
ORDER BY MIN(S.StartDateTime),H.CreateDate DESC,D.EquipmentRequestDetailID DESC;
""";
        await using var cmd = new SqlCommand(sql, db);
        Add(cmd, "@company", company); Add(cmd, "@user", user); Add(cmd, "@admin", admin); Add(cmd, "@edit", await Allowed(db, "EDIT", token)); Add(cmd, "@status", Clean(status)?.ToUpperInvariant()); Add(cmd, "@from", dateFrom); Add(cmd, "@to", dateTo); Add(cmd, "@room", roomId); Add(cmd, "@department", departmentId); Add(cmd, "@requester", requesterUserId);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new {
            detailId=reader.GetInt64(0), requestId=reader.GetInt64(1), bookingId=reader.GetInt64(2), bookingNo=reader.GetString(3), subject=reader.GetString(4), roomCode=reader.GetString(5), roomName=reader.GetString(6), startDateTime=reader.GetDateTime(7), endDateTime=reader.GetDateTime(8), itemId=reader.GetInt64(9), itemName=reader.GetString(10), unitCode=Text(reader,11), quantity=reader.GetDecimal(12), remark=Text(reader,13), statusCode=reader.GetString(14), resultRemark=Text(reader,15), departmentId=reader.GetInt64(16), departmentName=Text(reader,17), requestedByUserId=reader.GetInt64(18), requesterName=Text(reader,19), requesterRoleCode=Text(reader,20), requestedDate=reader.GetDateTime(21), requiresReview=reader.GetBoolean(22), isOwnRequest=reader.GetInt32(23)==1, canManageBooking=reader.GetInt32(24)==1, canManageStatus=reader.GetInt32(25)==1, reviewedByUserId=Long(reader,26), reviewedByName=Text(reader,27), reviewedDateTime=Date(reader,28), reviewRemark=Text(reader,29), processedByUserId=Long(reader,30), processedDateTime=Date(reader,31),canCancel=reader.GetInt32(32)==1
        });
        return Ok(new { items });
    }

    [HttpGet("booking/{bookingId:long}")]
    public async Task<IActionResult> Booking(long bookingId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        var access = await GetAccess(db, company, user, bookingId, token);
        if (access is null || !access.InScope) return NotFound();
        var state = RequestState(access);
        var items = await EligibleItems(db, company, token);
        var details = await BookingDetails(db, company, user, bookingId, access.CanReview, state=="OPEN", token);
        return Ok(new { requesterName=access.UserName, access.BookingId,access.BookingNo,access.Subject,access.RoomCode,access.RoomName,access.Start,access.End,access.Cutoff,access.Active,canConfigurePlan=access.CanReview && access.Status=="APPROVED" && access.Start>DateTime.Now,canReview=access.CanReview,canRequest=state=="OPEN",requestState=state,items,requests=details });
    }

    [HttpPut("booking/{bookingId:long}/plan")]
    public async Task<IActionResult> SavePlan(long bookingId, EquipmentPlanRequest request, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        var access = await GetAccess(db, company, user, bookingId, token);
        if (access is null || !access.CanReview) return Forbid();
        if (access.Status != "APPROVED" || access.Start <= DateTime.Now || request.RequestCutoffDateTime <= DateTime.Now || request.RequestCutoffDateTime >= access.Start) return BadRequest(Error("กำหนดเวลาปิดรับไม่ถูกต้อง", "เวลาปิดรับต้องอยู่หลังเวลาปัจจุบันและก่อนเริ่มประชุม"));
        const string sql = """IF EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingEquipmentPlan WHERE BookingID=@booking AND CompanyID=@company) UPDATE dbo.TDADMeetingBookingEquipmentPlan SET RequestCutoffDateTime=@cutoff,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE BookingID=@booking AND CompanyID=@company; ELSE INSERT dbo.TDADMeetingBookingEquipmentPlan(BookingID,CompanyID,RequestCutoffDateTime,IsActive,CreateBy) VALUES(@booking,@company,@cutoff,@active,@user);""";
        await using var cmd = new SqlCommand(sql, db); Add(cmd,"@booking",bookingId); Add(cmd,"@company",company); Add(cmd,"@cutoff",request.RequestCutoffDateTime); Add(cmd,"@active",request.IsActive); Add(cmd,"@user",user); await cmd.ExecuteNonQueryAsync(token); return NoContent();
    }

    [HttpPost("booking/{bookingId:long}")]
    [HttpPut("booking/{bookingId:long}")]
    public async Task<IActionResult> Create(long bookingId, EquipmentRequestCreate request, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        var access = await GetAccess(db, company, user, bookingId, token, tx);
        if (request.Items is null || request.Items.Count == 0 || request.Items.Any(x => x.ItemId <= 0 || x.Quantity <= 0 || x.Remark?.Length > 500) || request.Items.Select(x => x.ItemId).Distinct().Count() != request.Items.Count) return BadRequest(Error("รายการอุปกรณ์ไม่ถูกต้อง", "เลือกอุปกรณ์ไม่ซ้ำ ระบุจำนวนมากกว่า 0 และหมายเหตุไม่เกิน 500 ตัวอักษร"));
        var lines = (request.Items ?? []).Where(x => x.ItemId > 0 && x.Quantity > 0).GroupBy(x => x.ItemId).Select(x => x.Last()).ToList();
        if (access is null || !access.InScope) return Forbid();
        if (RequestState(access) != "OPEN") return BadRequest(Error("ไม่สามารถส่งคำขอได้", "เกินเวลาปิดรับหรือยังไม่ได้เปิดรับคำขออุปกรณ์"));
        if (lines.Count == 0) return BadRequest(Error("ยังไม่ได้เลือกอุปกรณ์", "กรุณาเลือกอุปกรณ์อย่างน้อย 1 รายการและระบุจำนวนมากกว่า 0"));
        var requiresReview = await RequiresReview(db, company, token, tx);
        try
        {
            foreach (var line in lines)
            {
                await using var duplicate = new SqlCommand("""
SELECT COUNT_BIG(*) FROM dbo.TDADMeetingBookingEquipmentRequest H
JOIN dbo.TDADMeetingBookingEquipmentRequestDetail D ON D.EquipmentRequestID=H.EquipmentRequestID AND D.CompanyID=H.CompanyID
WHERE H.CompanyID=@company AND H.BookingID=@booking AND H.RequestedByUserID=@user
 AND D.ItemID=@item AND D.StatusCode IN ('WAITING_REVIEW','PENDING','IN_PROGRESS')
""", db, tx);
                Add(duplicate,"@company",company); Add(duplicate,"@booking",bookingId);
                Add(duplicate,"@user",user); Add(duplicate,"@item",line.ItemId);
                if (Convert.ToInt64(await duplicate.ExecuteScalarAsync(token)) > 0)
                    return Conflict(Error("มีคำขออุปกรณ์นี้อยู่แล้ว", "หากต้องการเปลี่ยนจำนวนหรือหมายเหตุ ให้ยกเลิกรายการเดิมที่ยังยกเลิกได้แล้วส่งคำขอใหม่"));
            }
            var requestId = await InsertHeader(db, tx, company, bookingId, user, access.UserName, access.RoleCode, requiresReview, token);
            foreach (var line in lines)
            {
                var department = await ItemDepartment(db, tx, company, line.ItemId, token);
                if (department is null) return BadRequest(Error("อุปกรณ์ไม่พร้อมรับคำขอ", "พบอุปกรณ์ที่ไม่ได้เปิดใช้กับ Meeting หรือไม่มีแผนกรับผิดชอบ"));
                var status = requiresReview ? "WAITING_REVIEW" : "PENDING";
                var detailId = await InsertDetail(db, tx, requestId, company, line.ItemId, department.Value, line.Quantity, Clean(line.Remark), status, token);
                await Timeline(db, tx, company, requestId, detailId, requiresReview ? "SUBMITTED_FOR_REVIEW" : "SENT_TO_DEPARTMENT", null, user, access.UserName, token);
            }
            await Timeline(db, tx, company, requestId, null, "REQUEST_CREATED", null, user, access.UserName, token);
            await tx.CommitAsync(token);
            return Ok(new { requestId, requiresReview, statusCode = requiresReview ? "WAITING_REVIEW" : "PENDING" });
        }
        catch { await tx.RollbackAsync(token); throw; }
    }

    [HttpPut("requests/{requestId:long}/review")]
    public async Task<IActionResult> Review(long requestId, EquipmentRequestReview request, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        var action = Clean(request.ActionCode)?.ToUpperInvariant();
        if (action is not ("APPROVE" or "REJECT")) return BadRequest(Error("คำสั่งตรวจสอบไม่ถูกต้อง", "ระบุ APPROVE หรือ REJECT"));
        if (action == "REJECT" && string.IsNullOrWhiteSpace(request.Remark)) return BadRequest(Error("กรุณาระบุเหตุผล", "การปฏิเสธคำขอต้องระบุเหตุผล"));
        await using var db = await Open(token);
        var bookingId = await RequestBooking(db, company, requestId, token); if (bookingId is null) return NotFound();
        var access = await GetAccess(db, company, user, bookingId.Value, token); if (access is null || !access.CanReview) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        var ids = request.DetailIds?.Where(x=>x>0).Distinct().ToList() ?? [];
        var filter = ids.Count == 0 ? "" : " AND D.EquipmentRequestDetailID IN (" + string.Join(',', ids.Select((_, i) => "@id"+i)) + ")";
        var next = action == "APPROVE" ? "PENDING" : "REVIEW_REJECTED";
        var sql = $"""UPDATE D SET StatusCode=@next,ReviewedByUserID=@user,ReviewedByName=@name,ReviewedDateTime=SYSUTCDATETIME(),ReviewRemark=@remark,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMeetingBookingEquipmentRequestDetail D WHERE D.CompanyID=@company AND D.EquipmentRequestID=@request AND D.StatusCode='WAITING_REVIEW'{filter};""";
        await using var cmd = new SqlCommand(sql, db, tx); Add(cmd,"@next",next); Add(cmd,"@user",user); Add(cmd,"@name",access.UserName); Add(cmd,"@remark",Clean(request.Remark)); Add(cmd,"@company",company); Add(cmd,"@request",requestId); for(var i=0;i<ids.Count;i++) Add(cmd,"@id"+i,ids[i]); var affected=await cmd.ExecuteNonQueryAsync(token); if(affected==0) return BadRequest(Error("ไม่มีรายการรอตรวจสอบ", "รายการที่เลือกอาจถูกตรวจสอบไปแล้ว"));
        await Timeline(db, tx, company, requestId, null, action == "APPROVE" ? "REVIEW_APPROVED" : "REVIEW_REJECTED", Clean(request.Remark), user, access.UserName, token);
        await tx.CommitAsync(token);
        return NoContent();
    }

    [HttpPut("details/{detailId:long}/cancel")]
    public async Task<IActionResult> Cancel(long detailId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        var booking = await DetailBooking(db, company, detailId, token);
        if (booking is null) return NotFound();
        var access = await GetAccess(db, company, user, booking.Value, token);
        if (access is null || !access.InScope) return Forbid();
        if (RequestState(access) != "OPEN") return BadRequest(Error("ยกเลิกรายการไม่ได้", "ปิดรับคำขอหรือรายการประชุมไม่พร้อมดำเนินการแล้ว"));
        var manager = access.CanReview;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        const string sql = """UPDATE D SET StatusCode='CANCELLED',UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.EquipmentRequestID FROM dbo.TDADMeetingBookingEquipmentRequestDetail D JOIN dbo.TDADMeetingBookingEquipmentRequest H ON H.EquipmentRequestID=D.EquipmentRequestID JOIN dbo.TDADMeetingBookingEquipmentPlan P ON P.BookingID=H.BookingID AND P.CompanyID=H.CompanyID WHERE D.CompanyID=@company AND D.EquipmentRequestDetailID=@detail AND (@manager=1 OR H.RequestedByUserID=@user) AND D.StatusCode IN('WAITING_REVIEW','PENDING') AND P.IsActive=1 AND P.RequestCutoffDateTime>SYSDATETIME() AND EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBooking B WHERE B.BookingID=H.BookingID AND B.CompanyID=H.CompanyID AND B.BookingStatus='APPROVED' AND (SELECT MIN(S.StartDateTime) FROM dbo.TDADMeetingRoomBookingSlot S WHERE S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID)>SYSDATETIME());""";
        await using var cmd = new SqlCommand(sql, db, tx);
        Add(cmd, "@user", user); Add(cmd, "@company", company); Add(cmd, "@detail", detailId); Add(cmd, "@manager", manager);
        var requestId = await cmd.ExecuteScalarAsync(token);
        if (requestId is null) return BadRequest(Error("ยกเลิกรายการไม่ได้", "ยกเลิกได้เฉพาะผู้ขอหรือผู้ดูแลการประชุม สำหรับรายการที่ยังรอตรวจสอบหรือรอดำเนินการภายในเวลาปิดรับ"));
        await Timeline(db, tx, company, Convert.ToInt64(requestId), detailId, "CANCELLED", null, user, access.UserName, token);
        await tx.CommitAsync(token);
        return NoContent();
    }
    [HttpPut("details/{detailId:long}/status")]
    public async Task<IActionResult> Status(long detailId, EquipmentRequestStatus request, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        var status=Clean(request.StatusCode)?.ToUpperInvariant(); if(status is not("IN_PROGRESS" or "COMPLETED" or "DEPARTMENT_REJECTED")) return BadRequest(Error("สถานะไม่ถูกต้อง","แผนกเปลี่ยนได้เป็น IN_PROGRESS, COMPLETED หรือ DEPARTMENT_REJECTED"));
        if(status=="DEPARTMENT_REJECTED"&&string.IsNullOrWhiteSpace(request.ResultRemark)) return BadRequest(Error("กรุณาระบุเหตุผล","การปฏิเสธโดยแผนกต้องระบุเหตุผล"));
        await using var db=await Open(token); var booking=await DetailBooking(db,company,detailId,token); if(booking is null)return NotFound(); var access=await GetAccess(db,company,user,booking.Value,token); var manager=access?.CanReview==true; var edit=await Allowed(db,"EDIT",token); if(!manager&&!edit)return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        const string sql="""UPDATE D SET StatusCode=@status,ResultRemark=@remark,ProcessedByUserID=@user,ProcessedDateTime=SYSUTCDATETIME(),UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.EquipmentRequestID FROM dbo.TDADMeetingBookingEquipmentRequestDetail D WHERE D.CompanyID=@company AND D.EquipmentRequestDetailID=@detail AND D.StatusCode IN('PENDING','IN_PROGRESS') AND (@manager=1 OR (@edit=1 AND EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1 WHERE UE.CompanyID=@company AND UE.UserID=@user AND UE.IsActive=1 AND E.DepartmentOrgUnitID=D.ResponsibleDepartmentOrgUnitID)));""";
        await using var cmd=new SqlCommand(sql,db,tx);Add(cmd,"@status",status);Add(cmd,"@remark",Clean(request.ResultRemark));Add(cmd,"@user",user);Add(cmd,"@company",company);Add(cmd,"@detail",detailId);Add(cmd,"@manager",manager);Add(cmd,"@edit",edit);var requestId=await cmd.ExecuteScalarAsync(token);if(requestId is null)return Forbid();
        await Timeline(db,tx,company,Convert.ToInt64(requestId),detailId,status,Clean(request.ResultRemark),user,access?.UserName,token);
        await tx.CommitAsync(token); return NoContent();
    }

    [HttpGet("requests/{requestId:long}/timeline")]
    public async Task<IActionResult> Timeline(long requestId, CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid(); await using var db=await Open(token); var booking=await RequestBooking(db,company,requestId,token);if(booking is null)return NotFound();var access=await GetAccess(db,company,user,booking.Value,token);if(access is null||!access.InScope)return Forbid();
        const string sql="SELECT EquipmentRequestDetailID,EventCode,EventRemark,ActorName,CreateDate FROM dbo.TDADMeetingBookingEquipmentRequestTimeline WHERE CompanyID=@company AND EquipmentRequestID=@request AND (@manager=1 OR EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingEquipmentRequest H WHERE H.EquipmentRequestID=@request AND H.CompanyID=@company AND H.RequestedByUserID=@user)) ORDER BY CreateDate,EquipmentRequestTimelineID;";await using var cmd=new SqlCommand(sql,db);Add(cmd,"@company",company);Add(cmd,"@request",requestId);Add(cmd,"@manager",access.CanReview);Add(cmd,"@user",user);await using var r=await cmd.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new{detailId=Long(r,0),eventCode=r.GetString(1),remark=Text(r,2),actorName=Text(r,3),createDate=r.GetDateTime(4)});return Ok(new{items});
    }

    private async Task<bool> RequiresReview(SqlConnection db,long company,CancellationToken token,SqlTransaction? tx=null){await using var cmd=new SqlCommand("SELECT TOP(1) RequireEquipmentRequestReview FROM dbo.TDSTCompanySetupSystemMeeting WHERE CompanyID=@company AND ProjectID=@project",db,tx);Add(cmd,"@company",company);Add(cmd,"@project",MeetingProjectId);var value=await cmd.ExecuteScalarAsync(token);return value is not null&&value!=DBNull.Value&&Convert.ToBoolean(value);}
    private async Task<long> InsertHeader(SqlConnection db,SqlTransaction tx,long company,long booking,long user,string name,string role,bool review,CancellationToken token){const string sql="INSERT dbo.TDADMeetingBookingEquipmentRequest(CompanyID,BookingID,RequestedByUserID,RequestedByName,RequestedByRoleCode,RequiresReview) OUTPUT INSERTED.EquipmentRequestID VALUES(@company,@booking,@user,@name,@role,@review)";await using var cmd=new SqlCommand(sql,db,tx);Add(cmd,"@company",company);Add(cmd,"@booking",booking);Add(cmd,"@user",user);Add(cmd,"@name",name);Add(cmd,"@role",role);Add(cmd,"@review",review);return Convert.ToInt64(await cmd.ExecuteScalarAsync(token));}
    private async Task<long> InsertDetail(SqlConnection db,SqlTransaction tx,long request,long company,long item,long department,decimal quantity,string? remark,string status,CancellationToken token){const string sql="INSERT dbo.TDADMeetingBookingEquipmentRequestDetail(EquipmentRequestID,CompanyID,ItemID,ResponsibleDepartmentOrgUnitID,Quantity,Remark,StatusCode) OUTPUT INSERTED.EquipmentRequestDetailID VALUES(@request,@company,@item,@department,@quantity,@remark,@status)";await using var cmd=new SqlCommand(sql,db,tx);Add(cmd,"@request",request);Add(cmd,"@company",company);Add(cmd,"@item",item);Add(cmd,"@department",department);Add(cmd,"@quantity",quantity);Add(cmd,"@remark",remark);Add(cmd,"@status",status);Add(cmd,"@user",UserId());return Convert.ToInt64(await cmd.ExecuteScalarAsync(token));}
    private async Task Timeline(SqlConnection db,SqlTransaction? tx,long company,long request,long? detail,string code,string? remark,long actor,string? name,CancellationToken token){const string sql="INSERT dbo.TDADMeetingBookingEquipmentRequestTimeline(CompanyID,EquipmentRequestID,EquipmentRequestDetailID,EventCode,EventRemark,ActorUserID,ActorName) VALUES(@company,@request,@detail,@code,@remark,@actor,@name)";await using var cmd=new SqlCommand(sql,db,tx);Add(cmd,"@company",company);Add(cmd,"@request",request);Add(cmd,"@detail",detail);Add(cmd,"@code",code);Add(cmd,"@remark",remark);Add(cmd,"@actor",actor);Add(cmd,"@name",name);await cmd.ExecuteNonQueryAsync(token);}
    private async Task<long?> ItemDepartment(SqlConnection db,SqlTransaction tx,long company,long item,CancellationToken token){const string sql="SELECT I.ResponsibleDepartmentOrgUnitID FROM dbo.TDIVItem I JOIN dbo.TDIVItemUsage U ON U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode=N'EQUIPMENT' WHERE I.CompanyID=@company AND I.ItemID=@item AND I.IsActive=1 AND I.ResponsibleDepartmentOrgUnitID IS NOT NULL AND (NOT EXISTS(SELECT 1 FROM dbo.TDIVItemProjectPolicy P WHERE P.CompanyID=I.CompanyID AND P.ItemID=I.ItemID AND P.AccessModeCode=N'SELECTED') OR EXISTS(SELECT 1 FROM dbo.TDIVItemProject X JOIN dbo.TDADProject MP ON MP.ProjectID=X.ProjectID AND MP.ProjectCode=N'LAOO_MEETING' AND MP.IsActive=1 WHERE X.CompanyID=I.CompanyID AND X.ItemID=I.ItemID))";await using var cmd=new SqlCommand(sql,db,tx);Add(cmd,"@company",company);Add(cmd,"@item",item);var value=await cmd.ExecuteScalarAsync(token);return value is null||value==DBNull.Value?null:Convert.ToInt64(value);}
    private async Task<List<object>> EligibleItems(SqlConnection db,long company,CancellationToken token){const string sql="SELECT I.ItemID,I.ItemName,COALESCE(U.Name,N'') AS UnitName,D.NameTH FROM dbo.TDIVItem I JOIN dbo.TDIVItemUsage IU ON IU.CompanyID=I.CompanyID AND IU.ItemID=I.ItemID AND IU.UsageCode=N'EQUIPMENT' LEFT JOIN dbo.TDSTMaster U ON U.MasterGroupCode=N'002' AND U.MasterCode=I.UnitCode AND U.OwnerType=N'C' AND U.OwnerCompanyID=I.CompanyID AND U.IsActive=1 JOIN dbo.TDADOrganizationUnit D ON D.OrgUnitID=I.ResponsibleDepartmentOrgUnitID AND D.CompanyID=I.CompanyID WHERE I.CompanyID=@company AND I.IsActive=1 ORDER BY I.ItemName";await using var cmd=new SqlCommand(sql,db);Add(cmd,"@company",company);await using var r=await cmd.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new{itemId=r.GetInt64(0),name=r.GetString(1),unitName=Text(r,2),departmentName=Text(r,3)});return items;}
    private async Task<List<object>> BookingDetails(SqlConnection db,long company,long user,long booking,bool canReview,bool canRequest,CancellationToken token){const string sql="SELECT D.EquipmentRequestDetailID,H.EquipmentRequestID,D.ItemID,I.ItemName,D.Quantity,D.Remark,D.StatusCode,D.ResultRemark,H.RequestedByUserID,H.RequestedByName,H.RequestedByRoleCode,D.ReviewedByName,D.ReviewedDateTime,D.ReviewRemark FROM dbo.TDADMeetingBookingEquipmentRequestDetail D JOIN dbo.TDADMeetingBookingEquipmentRequest H ON H.EquipmentRequestID=D.EquipmentRequestID JOIN dbo.TDIVItem I ON I.ItemID=D.ItemID AND I.CompanyID=D.CompanyID WHERE H.CompanyID=@company AND H.BookingID=@booking AND (@review=1 OR H.RequestedByUserID=@user) ORDER BY H.CreateDate DESC,D.EquipmentRequestDetailID DESC";await using var cmd=new SqlCommand(sql,db);Add(cmd,"@company",company);Add(cmd,"@booking",booking);Add(cmd,"@user",user);Add(cmd,"@review",canReview);await using var r=await cmd.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new{detailId=r.GetInt64(0),requestId=r.GetInt64(1),itemId=r.GetInt64(2),itemName=r.GetString(3),quantity=r.GetDecimal(4),remark=Text(r,5),statusCode=r.GetString(6),resultRemark=Text(r,7),requestedByUserId=r.GetInt64(8),requesterName=Text(r,9),requesterRoleCode=Text(r,10),reviewedByName=Text(r,11),reviewedDateTime=Date(r,12),reviewRemark=Text(r,13),canCancel=canRequest && (canReview || r.GetInt64(8)==user) && (r.GetString(6) is "WAITING_REVIEW" or "PENDING"),isOwnRequest=r.GetInt64(8)==user});return items;}
    private async Task<long?> DetailBooking(SqlConnection db,long company,long detail,CancellationToken token){await using var cmd=new SqlCommand("SELECT H.BookingID FROM dbo.TDADMeetingBookingEquipmentRequestDetail D JOIN dbo.TDADMeetingBookingEquipmentRequest H ON H.EquipmentRequestID=D.EquipmentRequestID AND H.CompanyID=D.CompanyID WHERE D.CompanyID=@company AND D.EquipmentRequestDetailID=@detail",db);Add(cmd,"@company",company);Add(cmd,"@detail",detail);var value=await cmd.ExecuteScalarAsync(token);return value is null||value==DBNull.Value?null:Convert.ToInt64(value);}
    private async Task<long?> RequestBooking(SqlConnection db,long company,long request,CancellationToken token){await using var cmd=new SqlCommand("SELECT BookingID FROM dbo.TDADMeetingBookingEquipmentRequest WHERE CompanyID=@company AND EquipmentRequestID=@request",db);Add(cmd,"@company",company);Add(cmd,"@request",request);var value=await cmd.ExecuteScalarAsync(token);return value is null||value==DBNull.Value?null:Convert.ToInt64(value);}    private async Task<Access?> GetAccess(SqlConnection db,long company,long user,long booking,CancellationToken token,SqlTransaction? tx=null){var sql=$"""SELECT B.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,MIN(S.StartDateTime),MAX(S.EndDateTime),P.RequestCutoffDateTime,P.IsActive,B.BookingStatus,COALESCE((SELECT TOP(1) NULLIF(E.FullName,N'') FROM dbo.TDADUserEmployee NU JOIN dbo.TDADEmployee E ON E.EmployeeID=NU.EmployeeID AND E.CompanyID=NU.CompanyID AND E.IsActive=1 WHERE NU.CompanyID=@company AND NU.UserID=@user AND NU.IsActive=1 ORDER BY E.EmployeeID),U.Username),CASE WHEN U.IsCompanyAdmin=1 THEN 1 ELSE 0 END,CASE WHEN {MeetingRoomAdminAccess.BookingRoomSql} THEN 1 ELSE 0 END,CASE WHEN B.RequesterUserID=@user THEN 1 ELSE 0 END,CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBookingParticipant BP JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=BP.CompanyID AND UE.EmployeeID=BP.EmployeeID AND UE.UserID=@user AND UE.IsActive=1 WHERE BP.CompanyID=B.CompanyID AND BP.BookingID=B.BookingID AND BP.InvitationStatus='ACCEPTED' AND EXISTS(SELECT 1 FROM dbo.TDADEmployee IE WHERE IE.EmployeeID=BP.EmployeeID AND IE.CompanyID=BP.CompanyID AND IE.IsActive=1)) THEN 1 ELSE 0 END FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID JOIN dbo.TDADUser U ON U.CompanyID=B.CompanyID AND U.UserID=@user AND U.IsActive=1 LEFT JOIN dbo.TDADMeetingBookingEquipmentPlan P ON P.BookingID=B.BookingID AND P.CompanyID=B.CompanyID WHERE B.CompanyID=@company AND B.BookingID=@booking GROUP BY B.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,P.RequestCutoffDateTime,P.IsActive,B.BookingStatus,U.Username,U.IsCompanyAdmin,B.RequesterUserID,B.RoomID,B.CompanyID""";await using var cmd=new SqlCommand(sql,db,tx);Add(cmd,"@company",company);Add(cmd,"@user",user);Add(cmd,"@booking",booking);await using var r=await cmd.ExecuteReaderAsync(token);if(!await r.ReadAsync(token))return null;var admin=r.GetInt32(11)==1;var room=r.GetInt32(12)==1;var owner=r.GetInt32(13)==1;var invited=r.GetInt32(14)==1;var role=admin?"COMPANY_ADMIN":room?"ROOM_ADMIN":owner?"MEETING_OWNER":invited?"INVITEE":"";return new(r.GetInt64(0),r.GetString(1),r.GetString(2),r.GetString(3),r.GetString(4),r.GetDateTime(5),r.GetDateTime(6),Date(r,7),!r.IsDBNull(8)&&r.GetBoolean(8),r.GetString(9),Text(r,10)??"-",role,admin||room||owner,admin||room||owner||invited);}
    private static string RequestState(Access x)=>!x.InScope?"NO_PERMISSION":x.Status!="APPROVED"?"BOOKING_NOT_APPROVED":x.Start<=DateTime.Now?"MEETING_STARTED":x.Cutoff is null?"CUTOFF_NOT_CONFIGURED":!x.Active?"CUTOFF_DISABLED":x.Cutoff<=DateTime.Now?"CUTOFF_EXPIRED":"OPEN";
    private async Task<bool> CompanyAdmin(SqlConnection db,long company,long user,CancellationToken token){await using var cmd=new SqlCommand("SELECT IsCompanyAdmin FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@user AND IsActive=1",db);Add(cmd,"@company",company);Add(cmd,"@user",user);var value=await cmd.ExecuteScalarAsync(token);return value is not null&&value!=DBNull.Value&&Convert.ToBoolean(value);}
    private Task<bool> Allowed(SqlConnection db,string action,CancellationToken token)=>MeetingFoodPlanAccess.Allowed(db,User,action,token,ScreenCode);
    private bool Scope(out long company,out long user){company=0;user=0;return string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&long.TryParse(User.FindFirstValue("company_id"),out company)&&company>0&&long.TryParse(User.FindFirstValue("user_id"),out user)&&user>0;}
    private long UserId()=>long.TryParse(User.FindFirstValue("user_id"),out var value)?value:0;
    private async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    private static object Error(string message,string description)=>new{message,description}; private static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim(); private static string? Text(SqlDataReader r,int index)=>r.IsDBNull(index)?null:r.GetValue(index)?.ToString(); private static long? Long(SqlDataReader r,int index)=>r.IsDBNull(index)?null:Convert.ToInt64(r.GetValue(index)); private static DateTime? Date(SqlDataReader r,int index)=>r.IsDBNull(index)?null:r.GetDateTime(index); private static void Add(SqlCommand cmd,string name,object? value)=>cmd.Parameters.AddWithValue(name,value??DBNull.Value);
    private sealed record Access(long BookingId,string BookingNo,string Subject,string RoomCode,string RoomName,DateTime Start,DateTime End,DateTime? Cutoff,bool Active,string Status,string UserName,string RoleCode,bool CanReview,bool InScope);
}

public sealed record EquipmentRequestSettings(bool RequireEquipmentRequestReview);
public sealed record EquipmentPlanRequest(DateTime RequestCutoffDateTime,bool IsActive=true);
public sealed record EquipmentRequestLine(long ItemId,decimal Quantity,string? Remark);
public sealed record EquipmentRequestCreate(List<EquipmentRequestLine>? Items);
public sealed record EquipmentRequestReview(string ActionCode,string? Remark,List<long>? DetailIds);
public sealed record EquipmentRequestStatus(string StatusCode,string? ResultRemark);
