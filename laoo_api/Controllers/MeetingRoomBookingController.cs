using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/company/meeting-room-bookings")]
[Authorize]
public sealed class MeetingRoomBookingController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "21001";
    private const string CalendarScreenCode = "21002";
    private const string ApprovalScreenCode = "21004";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var connection = await Open(token);
        var isAdmin = TryCompany(out var companyId) && TryUser(out var userId) &&
                      await IsCompanyAdmin(connection, companyId, userId, token);
        return Ok(new
        {
            view = await Allowed(connection, "VIEW", token),
            create = await Allowed(connection, "CREATE", token),
            edit = await Allowed(connection, "EDIT", token),
            delete = await Allowed(connection, "DELETE", token),
            calendarView = await Allowed(connection, "VIEW", token, CalendarScreenCode),
            approvalView = await Allowed(connection, "VIEW", token, ApprovalScreenCode),
            approvalEdit = await Allowed(connection, "EDIT", token, ApprovalScreenCode),
            admin = isAdmin,
        });
    }

    [HttpGet("approval-requests")]
    public async Task<IActionResult> ApprovalRequests(
        int page = 1,
        int pageSize = 30,
        string? status = null,
        string? search = null,
        DateTime? dateFrom = null,
        DateTime? dateTo = null,
        CancellationToken token = default)
    {
        if (!TryCompany(out var companyId) || !TryUser(out var userId)) return Forbid();
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token, ApprovalScreenCode)) return Forbid();
        const string sql = """
WITH RankedApprovals AS (
SELECT A.BookingApprovalID,A.BookingID,A.ApprovalOrder,
       B.BookingNo,B.Subject,B.AttendeeCount,B.BookingStatus,
       R.RoomCode,R.RoomNameTH,
       BR.BranchNameTH,BD.BuildingNameTH,F.FloorNameTH,
       RE.EmployeeCode,NULLIF(RE.FullName,'') AS RequesterName,
        MIN(S.StartDateTime) AS StartDateTime,MAX(S.EndDateTime) AS EndDateTime,B.CreateDate AS CreateDate,
        COALESCE(B.StatusRemark,A.Remark,B.Remark) AS StatusRemark,A.ApprovalStatus,
       ROW_NUMBER() OVER (PARTITION BY A.BookingID ORDER BY
           CASE WHEN A.ApprovalStatus='PENDING' THEN 0 ELSE 1 END,
           A.ApprovalOrder,A.BookingApprovalID) AS RowNo
FROM dbo.TDADMeetingRoomBookingApproval A
INNER JOIN dbo.TDADMeetingRoomBooking B
    ON B.BookingID=A.BookingID AND B.CompanyID=@company
INNER JOIN dbo.TDADMeetingRoom R
    ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADUserEmployee UE
    ON UE.CompanyID=B.CompanyID AND UE.EmployeeID=A.EmployeeID
LEFT JOIN dbo.TDADUserEmployee RequesterUE
    ON RequesterUE.CompanyID=B.CompanyID AND RequesterUE.UserID=B.RequesterUserID
LEFT JOIN dbo.TDADEmployee RE
    ON RE.EmployeeID=COALESCE(B.RequesterEmployeeID,RequesterUE.EmployeeID)
   AND RE.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADBuilding BD
    ON BD.BuildingID=R.BuildingID AND BD.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADBranch BR
    ON BR.BranchID=BD.BranchID AND BR.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADFloor F
    ON F.FloorID=R.FloorID
INNER JOIN dbo.TDADMeetingRoomBookingSlot S
    ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
WHERE (A.ApprovalStatus='PENDING' AND (UE.UserID=@user OR EXISTS
       (SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1))
       OR A.ApprovalStatus<>'PENDING' AND (B.RequesterUserID=@user OR EXISTS
       (SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1)))
  AND S.EndDateTime >= GETDATE()
   AND (@status IS NULL OR @status='' OR B.BookingStatus=@status)
   AND (@dateFrom IS NULL OR S.StartDateTime >= @dateFrom)
   AND (@dateTo IS NULL OR S.StartDateTime < DATEADD(day,1,@dateTo))
   AND B.BookingID=(
       SELECT TOP 1 B2.BookingID
       FROM dbo.TDADMeetingRoomBooking B2
       WHERE B2.CompanyID=B.CompanyID AND B2.RoomID=B.RoomID
         AND EXISTS
         (
             SELECT 1
             FROM dbo.TDADMeetingRoomBookingSlot S2
             WHERE S2.BookingID=B2.BookingID AND S2.CompanyID=B2.CompanyID
               AND S2.StartDateTime=S.StartDateTime AND S2.EndDateTime=S.EndDateTime
         )
       ORDER BY B2.CreateDate DESC,B2.BookingID DESC
   )
   AND (@search IS NULL OR @search='' OR B.BookingNo LIKE '%'+@search+'%' OR B.Subject LIKE '%'+@search+'%' OR R.RoomCode LIKE '%'+@search+'%' OR R.RoomNameTH LIKE '%'+@search+'%' OR RE.EmployeeCode LIKE '%'+@search+'%' OR RE.FullName LIKE '%'+@search+'%')
GROUP BY A.BookingApprovalID,A.BookingID,A.ApprovalOrder,
         B.BookingNo,B.Subject,B.AttendeeCount,B.BookingStatus,
         R.RoomCode,R.RoomNameTH,BR.BranchNameTH,BD.BuildingNameTH,F.FloorNameTH,
          RE.EmployeeCode,RE.FullName,B.CreateDate,B.StatusRemark,B.Remark,A.Remark,A.ApprovalStatus
)
SELECT * FROM RankedApprovals WHERE RowNo=1
ORDER BY startDateTime,CreateDate,ApprovalOrder
OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@user", userId);
        Add(command, "@company", companyId);
        Add(command, "@skip", (page - 1) * pageSize);
        Add(command, "@take", pageSize);
        Add(command, "@status", Clean(status));
        Add(command, "@search", Clean(search));
        Add(command, "@dateFrom", dateFrom?.Date);
        Add(command, "@dateTo", dateTo?.Date);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new
        {
            approvalId = reader.GetInt64(0),
            bookingId = reader.GetInt64(1),
            approvalOrder = reader.GetInt32(2),
            bookingNo = Text(reader, 3),
            subject = reader.GetString(4),
            attendeeCount = reader.GetInt32(5),
            status = reader.GetString(6),
            roomCode = reader.GetString(7),
            roomName = reader.GetString(8),
            branchName = Text(reader, 9),
            buildingName = Text(reader, 10),
            floorName = Text(reader, 11),
            requesterCode = Text(reader, 12),
            requesterName = Text(reader, 13),
            startDateTime = reader.GetDateTime(14),
            endDateTime = reader.GetDateTime(15),
             remark = Text(reader, 17),
             approvalStatus = Text(reader, 18),
        });
        return Ok(new { items, page, pageSize });
    }

    [HttpGet("approval-requests/{bookingId:long}/history")]
    public async Task<IActionResult> ApprovalHistory(long bookingId, CancellationToken token)
    {
        if (!TryCompany(out var companyId) || !TryUser(out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token, ApprovalScreenCode)) return Forbid();
        const string sql = """
SELECT H.BookingStatusHistoryID,H.FromStatus,H.ToStatus,H.ChangedDate,H.Remark,H.ChangeSource,
       E.EmployeeCode,E.FullName,B.BookingNo
FROM dbo.TDADMeetingRoomBookingStatusHistory H
INNER JOIN dbo.TDADMeetingRoomBooking B
    ON B.BookingID=H.BookingID AND B.CompanyID=@company
OUTER APPLY
(
    SELECT TOP 1 UE.EmployeeID
    FROM dbo.TDADUserEmployee UE
    WHERE UE.UserID=H.ChangedByUserID AND UE.CompanyID=H.CompanyID
    ORDER BY UE.EmployeeID
) ActorUE
LEFT JOIN dbo.TDADEmployee E
    ON E.EmployeeID=ActorUE.EmployeeID AND E.CompanyID=H.CompanyID
WHERE H.BookingID=@booking AND H.CompanyID=@company
ORDER BY H.ChangedDate DESC,H.BookingStatusHistoryID DESC;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@booking", bookingId); Add(command, "@company", companyId);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new
        {
            historyId = reader.GetInt64(0), fromStatus = Text(reader, 1), toStatus = reader.GetString(2),
            changedDate = reader.GetDateTime(3), remark = Text(reader, 4), source = Text(reader, 5),
            actorCode = Text(reader, 6), actorName = Text(reader, 7), bookingNo = Text(reader, 8),
        });
        return Ok(new { bookingId, items });
    }

    [HttpPost("approval-requests/{approvalId:long}/decision")]
    public async Task<IActionResult> DecideApproval(
        long approvalId,
        ApprovalDecisionRequest request,
        CancellationToken token)
    {
        var decision = Clean(request.Decision)?.ToUpperInvariant();
        if (decision is not ("APPROVED" or "REJECTED"))
            return BadRequest(Error("ผลการอนุมัติไม่ถูกต้อง", "ใช้ APPROVED หรือ REJECTED เท่านั้น"));
        if (!TryCompany(out var companyId) || !TryUser(out var userId)) return Forbid();

        await using var connection = await Open(token);
        if (!await Allowed(connection, "EDIT", token, ApprovalScreenCode)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            const string findSql = """
SELECT A.BookingID,B.BookingStatus,B.RequireAllApprovers
FROM dbo.TDADMeetingRoomBookingApproval A
INNER JOIN dbo.TDADMeetingRoomBooking B
    ON B.BookingID=A.BookingID AND B.CompanyID=@company AND B.BookingStatus='PENDING'
LEFT JOIN dbo.TDADUserEmployee UE
    ON UE.CompanyID=B.CompanyID AND UE.EmployeeID=A.EmployeeID
WHERE A.BookingApprovalID=@approval AND A.ApprovalStatus='PENDING'
  AND (UE.UserID=@user OR EXISTS
       (SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1));
""";
            await using var find = new SqlCommand(findSql, connection, transaction);
            Add(find, "@approval", approvalId);
            Add(find, "@company", companyId);
            Add(find, "@user", userId);
            await using var reader = await find.ExecuteReaderAsync(token);
            if (!await reader.ReadAsync(token)) return Forbid();
            var bookingId = reader.GetInt64(0);
            var previousStatus = reader.GetString(1);
            var requireAll = reader.GetBoolean(2);
            await reader.CloseAsync();

            const string updateApproval = """
UPDATE dbo.TDADMeetingRoomBookingApproval
SET ApprovalStatus=@decision,ActionDate=SYSUTCDATETIME(),ActionByUserID=@user,Remark=@remark
WHERE BookingApprovalID=@approval AND ApprovalStatus='PENDING';
""";
            await using var update = new SqlCommand(updateApproval, connection, transaction);
            Add(update, "@decision", decision);
            Add(update, "@user", userId);
            Add(update, "@remark", Clean(request.Remark));
            Add(update, "@approval", approvalId);
            if (await update.ExecuteNonQueryAsync(token) == 0) return Conflict(Error("รายการอนุมัติถูกดำเนินการแล้ว", "กรุณาโหลดรายการใหม่ก่อนดำเนินการอีกครั้ง"));

            var bookingStatus = decision == "REJECTED" ? "REJECTED" : null;
            if (bookingStatus is null)
            {
                const string pendingSql = "SELECT COUNT_BIG(1) FROM dbo.TDADMeetingRoomBookingApproval WHERE BookingID=@booking AND ApprovalStatus='PENDING';";
                await using var pending = new SqlCommand(pendingSql, connection, transaction);
                Add(pending, "@booking", bookingId);
                var pendingCount = Convert.ToInt64(await pending.ExecuteScalarAsync(token));
                if (!requireAll || pendingCount == 0) bookingStatus = "APPROVED";
            }
            if (bookingStatus is not null)
            {
                const string updateBooking = """
UPDATE dbo.TDADMeetingRoomBooking
SET BookingStatus=@status,StatusRemark=@remark,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user
WHERE BookingID=@booking AND CompanyID=@company AND BookingStatus='PENDING';
""";
                await using var updateBookingCommand = new SqlCommand(updateBooking, connection, transaction);
                Add(updateBookingCommand, "@status", bookingStatus);
                Add(updateBookingCommand, "@remark", Clean(request.Remark));
                Add(updateBookingCommand, "@user", userId);
                Add(updateBookingCommand, "@booking", bookingId);
                Add(updateBookingCommand, "@company", companyId);
                await updateBookingCommand.ExecuteNonQueryAsync(token);
                await AddStatusHistory(connection, transaction, companyId, bookingId, previousStatus, bookingStatus, userId, "APPROVAL", request.Remark, token);
            }
            await transaction.CommitAsync(token);
            return Ok(new { approvalId, bookingId, status = bookingStatus ?? "PENDING" });
        }
        catch
        {
            await transaction.RollbackAsync(token);
            throw;
        }
    }

    [HttpPost("{bookingId:long}/rollback")]
    public async Task<IActionResult> Rollback(long bookingId, RollbackBookingRequest? request, CancellationToken token)
    {
        if (!TryCompany(out var companyId) || !TryUser(out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Allowed(connection, "EDIT", token, ApprovalScreenCode)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            const string findSql = """
SELECT B.BookingStatus,B.RequesterUserID,B.RequesterEmployeeID,R.RoomID,MAX(S.EndDateTime)
FROM dbo.TDADMeetingRoomBooking B
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
INNER JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
WHERE B.BookingID=@booking AND B.CompanyID=@company
GROUP BY B.BookingStatus,B.RequesterUserID,B.RequesterEmployeeID,R.RoomID;
""";
            await using var find = new SqlCommand(findSql, connection, transaction);
            Add(find, "@booking", bookingId); Add(find, "@company", companyId);
            await using var reader = await find.ExecuteReaderAsync(token);
            if (!await reader.ReadAsync(token)) return NotFound(Error("ไม่พบรายการจอง", "รายการอาจถูกลบหรือไม่อยู่ในบริษัทของผู้ใช้งาน"));
            var status = reader.GetString(0);
            _ = reader.GetInt64(1);
            var requesterEmployeeId = reader.IsDBNull(2) ? (long?)null : reader.GetInt64(2);
            var roomId = reader.GetInt64(3);
            var bookingEnd = reader.GetDateTime(4);
            await reader.CloseAsync();

            if (status is not ("APPROVED" or "REJECTED"))
                return BadRequest(Error("ถอยสถานะไม่ได้", "รายการต้องอยู่ในสถานะอนุมัติแล้วหรือไม่อนุมัติเท่านั้น"));
            if (bookingEnd <= DateTime.Now)
                return BadRequest(Error("ถอยสถานะไม่ได้", "รายการที่เลยวันและเวลาจองแล้วไม่สามารถถอยสถานะได้"));

            const string updateSql = """
DECLARE @changed INT;
UPDATE dbo.TDADMeetingRoomBooking
SET BookingStatus='PENDING',StatusRemark=@remark,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user
WHERE BookingID=@booking AND CompanyID=@company AND BookingStatus IN ('APPROVED','REJECTED');
SET @changed=@@ROWCOUNT;
DELETE FROM dbo.TDADMeetingRoomBookingApproval WHERE BookingID=@booking;
SELECT @changed;
""";
            await using var update = new SqlCommand(updateSql, connection, transaction);
            Add(update, "@booking", bookingId); Add(update, "@company", companyId); Add(update, "@user", userId);
            Add(update, "@remark", Clean(request?.Remark));
            if (Convert.ToInt32(await update.ExecuteScalarAsync(token)) < 1) return Conflict(Error("ถอยสถานะไม่ได้", "รายการถูกเปลี่ยนแปลงแล้ว กรุณาโหลดข้อมูลใหม่"));

            await AddStatusHistory(connection, transaction, companyId, bookingId, status, "PENDING", userId, "ROLLBACK", request?.Remark, token);

            var approval = await ResolveApprovers(connection, transaction, companyId, roomId, requesterEmployeeId, token);
            for (var index = 0; index < approval.EmployeeIds.Count; index++)
            {
                const string insertApproval = """
INSERT dbo.TDADMeetingRoomBookingApproval(BookingID,EmployeeID,ApprovalOrder)
VALUES(@booking,@employee,@order);
""";
                await using var insert = new SqlCommand(insertApproval, connection, transaction);
                Add(insert, "@booking", bookingId); Add(insert, "@employee", approval.EmployeeIds[index]); Add(insert, "@order", index + 1);
                await insert.ExecuteNonQueryAsync(token);
            }
            await transaction.CommitAsync(token);
            return Ok(new { bookingId, status = "PENDING" });
        }
        catch (BookingValidationException error)
        {
            await transaction.RollbackAsync(token);
            return BadRequest(Error(error.Message, error.Description));
        }
        catch
        {
            await transaction.RollbackAsync(token);
            throw;
        }
    }

    [HttpGet("options")]
    public async Task<IActionResult> Options(CancellationToken token)
    {
        if (!TryCompany(out var companyId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token) &&
            !await Allowed(connection, "VIEW", token, CalendarScreenCode)) return Forbid();
        const string sql = """
SELECT B.BranchID,B.BranchCode,B.BranchNameTH
FROM dbo.TDADBranch B
WHERE B.CompanyID=@company AND B.IsActive=1
ORDER BY B.BranchCode;

SELECT B.BuildingID,B.BranchID,B.BuildingCode,B.BuildingNameTH
FROM dbo.TDADBuilding B
WHERE B.CompanyID=@company AND B.IsActive=1
ORDER BY B.BuildingCode;

SELECT F.FloorID,F.BuildingID,F.FloorCode,F.FloorNameTH,F.FloorNumber
FROM dbo.TDADFloor F
INNER JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID AND B.CompanyID=@company
WHERE F.IsActive=1
ORDER BY F.FloorNumber,F.FloorCode;

SELECT R.RoomID,R.BuildingID,R.FloorID,R.RoomCode,R.RoomNameTH,R.Capacity,
       R.Description,R.RoomImageUrl,R.LocationImageUrl,
       B.BranchID,BR.BranchCode,BR.BranchNameTH,B.BuildingCode,B.BuildingNameTH,
       F.FloorCode,F.FloorNameTH,
       STUFF((SELECT N', ' + MF.FacilityNameTH
              FROM dbo.TDADMeetingRoomFacility RF
              INNER JOIN dbo.TDADMeetingFacility MF ON MF.FacilityID=RF.FacilityID AND MF.CompanyID=R.CompanyID
              WHERE RF.RoomID=R.RoomID AND RF.IsActive=1
              ORDER BY MF.FacilityCode FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,N'') AS Facilities
FROM dbo.TDADMeetingRoom R
LEFT JOIN dbo.TDADBuilding B ON B.BuildingID=R.BuildingID AND B.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADBranch BR ON BR.BranchID=B.BranchID AND BR.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADFloor F ON F.FloorID=R.FloorID AND F.BuildingID=B.BuildingID
WHERE R.CompanyID=@company AND R.IsActive=1
ORDER BY R.RoomCode;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@company", companyId);
        await using var reader = await command.ExecuteReaderAsync(token);

        var branches = new List<object>();
        while (await reader.ReadAsync(token)) branches.Add(new
        {
            branchId = reader.GetInt64(0),
            code = reader.GetString(1),
            nameTh = reader.GetString(2),
        });

        await reader.NextResultAsync(token);
        var buildings = new List<object>();
        while (await reader.ReadAsync(token)) buildings.Add(new
        {
            buildingId = reader.GetInt64(0),
            branchId = reader.GetInt64(1),
            code = reader.GetString(2),
            nameTh = reader.GetString(3),
        });

        await reader.NextResultAsync(token);
        var floors = new List<object>();
        while (await reader.ReadAsync(token)) floors.Add(new
        {
            floorId = reader.GetInt64(0),
            buildingId = reader.GetInt64(1),
            code = reader.GetString(2),
            nameTh = reader.GetString(3),
            number = reader.IsDBNull(4) ? (int?)null : reader.GetInt32(4),
        });

        await reader.NextResultAsync(token);
        var rooms = new List<object>();
        while (await reader.ReadAsync(token)) rooms.Add(ReadRoom(reader));
        return Ok(new { branches, buildings, floors, rooms });
    }

    [HttpGet("calendar")]
    public async Task<IActionResult> Calendar(
        DateTime? from,
        DateTime? to,
        long? branchId,
        long? buildingId,
        long? floorId,
        long? roomId,
        string? status,
        CancellationToken token = default)
    {
        if (!TryCompany(out var companyId)) return Forbid();
        var start = (from ?? DateTime.Today).Date;
        var finish = (to ?? start.AddDays(7)).Date.AddDays(1);
        if (finish <= start || (finish - start).TotalDays > 62)
            return BadRequest(Error("ช่วงวันที่ไม่ถูกต้อง", "ปฏิทินเรียกดูข้อมูลได้ครั้งละไม่เกิน 62 วัน"));

        var normalizedStatus = Clean(status)?.ToUpperInvariant();
        var allowedStatuses = new[] { "PENDING", "APPROVED", "REJECTED", "CANCELLED" };
        if (normalizedStatus is not null && !allowedStatuses.Contains(normalizedStatus))
            return BadRequest(Error("สถานะไม่ถูกต้อง", "กรุณาเลือกสถานะจากรายการที่ระบบกำหนด"));

        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token, CalendarScreenCode)) return Forbid();
        const string sql = """
SELECT S.BookingSlotID,B.BookingID,B.BookingNo,B.Subject,B.Description,B.AttendeeCount,
       B.BookingStatus,B.ApprovalMode,S.BookingDate,S.StartDateTime,S.EndDateTime,
       R.RoomID,R.RoomCode,R.RoomNameTH,R.Capacity,
       BR.BranchID,BR.BranchNameTH,BD.BuildingID,BD.BuildingNameTH,F.FloorID,F.FloorNameTH,
       E.EmployeeCode,NULLIF(E.FullName,'')
FROM dbo.TDADMeetingRoomBookingSlot S
INNER JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=S.BookingID AND B.CompanyID=S.CompanyID
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=S.RoomID AND R.CompanyID=S.CompanyID
LEFT JOIN dbo.TDADBuilding BD ON BD.BuildingID=R.BuildingID AND BD.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADBranch BR ON BR.BranchID=BD.BranchID AND BR.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADFloor F ON F.FloorID=R.FloorID AND F.BuildingID=BD.BuildingID
LEFT JOIN dbo.TDADUserEmployee RequesterUE
    ON RequesterUE.CompanyID=B.CompanyID AND RequesterUE.UserID=B.RequesterUserID
LEFT JOIN dbo.TDADEmployee E
    ON E.EmployeeID=COALESCE(B.RequesterEmployeeID,RequesterUE.EmployeeID)
   AND E.CompanyID=B.CompanyID
WHERE S.CompanyID=@company
  AND S.StartDateTime<@finish AND S.EndDateTime>@start
  AND (@branch IS NULL OR BR.BranchID=@branch)
  AND (@building IS NULL OR BD.BuildingID=@building)
  AND (@floor IS NULL OR F.FloorID=@floor)
  AND (@room IS NULL OR R.RoomID=@room)
  AND (@status IS NULL OR B.BookingStatus=@status)
ORDER BY S.StartDateTime,R.RoomCode,B.BookingID;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@company", companyId);
        Add(command, "@start", start);
        Add(command, "@finish", finish);
        Add(command, "@branch", branchId);
        Add(command, "@building", buildingId);
        Add(command, "@floor", floorId);
        Add(command, "@room", roomId);
        Add(command, "@status", normalizedStatus);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new
        {
            bookingSlotId = reader.GetInt64(0), bookingId = reader.GetInt64(1), bookingNo = Text(reader, 2),
            subject = reader.GetString(3), description = Text(reader, 4), attendeeCount = reader.GetInt32(5),
            status = reader.GetString(6), approvalMode = reader.GetString(7), bookingDate = reader.GetDateTime(8),
            startDateTime = reader.GetDateTime(9), endDateTime = reader.GetDateTime(10),
            roomId = reader.GetInt64(11), roomCode = reader.GetString(12), roomNameTh = reader.GetString(13), capacity = Int(reader, 14),
            branchId = Long(reader, 15), branchName = Text(reader, 16), buildingId = Long(reader, 17), buildingName = Text(reader, 18),
            floorId = Long(reader, 19), floorName = Text(reader, 20), requesterCode = Text(reader, 21), requesterName = Text(reader, 22),
        });
        return Ok(new { items, from = start, to = finish.AddDays(-1) });
    }

    [HttpGet]
    public async Task<IActionResult> List(
        DateTime? dateFrom,
        DateTime? dateTo,
        long? roomId,
        bool mine = false,
        int page = 1,
        int pageSize = 30,
        CancellationToken token = default)
    {
        if (!TryCompany(out var companyId) || !TryUser(out var userId) || !await Permission("VIEW", token)) return Forbid();
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var from = (dateFrom ?? DateTime.Today).Date;
        if (from < DateTime.Today) from = DateTime.Today;
        var to = (dateTo ?? DateTime.Today.AddDays(90)).Date.AddDays(1);
        if (to <= from || (to - from).TotalDays > 366)
            return BadRequest(Error("ช่วงวันที่ไม่ถูกต้อง", "ช่วงค้นหาต้องไม่เกิน 366 วัน"));

        await using var connection = await Open(token);
        const string where = """
WHERE B.CompanyID=@company
  AND (@mine=0 OR (B.RequesterUserID=@user AND B.BookingStatus<>'CANCELLED'))
  AND (@room IS NULL OR B.RoomID=@room)
  AND EXISTS
  (
      SELECT 1 FROM dbo.TDADMeetingRoomBookingSlot S
      WHERE S.BookingID=B.BookingID AND S.StartDateTime<@to AND S.EndDateTime>@from
  )
""";
        var countSql = $"SELECT COUNT_BIG(1) FROM dbo.TDADMeetingRoomBooking B {where};";
        await using var countCommand = new SqlCommand(countSql, connection);
        BindList(countCommand, companyId, roomId, from, to);
        Add(countCommand, "@mine", mine); Add(countCommand, "@user", userId);
        var total = Convert.ToInt64(await countCommand.ExecuteScalarAsync(token));

        var sql = $"""
SELECT B.BookingID,B.BookingNo,B.RoomID,R.RoomCode,R.RoomNameTH,B.Subject,B.Description,
       B.AttendeeCount,B.BookingStatus,B.ApprovalMode,B.Remark,B.RequesterUserID,
       E.EmployeeCode,NULLIF(E.FullName,''),
       MIN(S.StartDateTime) AS StartDateTime,MAX(S.EndDateTime) AS EndDateTime,COUNT_BIG(S.BookingSlotID) AS SlotCount,
       BR.BranchNameTH,BD.BuildingNameTH,F.FloorNameTH
FROM dbo.TDADMeetingRoomBooking B
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
INNER JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID
LEFT JOIN dbo.TDADUserEmployee RequesterUE ON RequesterUE.CompanyID=B.CompanyID AND RequesterUE.UserID=B.RequesterUserID
LEFT JOIN dbo.TDADEmployee E
    ON E.EmployeeID=COALESCE(B.RequesterEmployeeID,RequesterUE.EmployeeID)
   AND E.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADBuilding BD ON BD.BuildingID=R.BuildingID AND BD.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADBranch BR ON BR.BranchID=BD.BranchID AND BR.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADFloor F ON F.FloorID=R.FloorID
{where}
GROUP BY B.BookingID,B.BookingNo,B.RoomID,R.RoomCode,R.RoomNameTH,B.Subject,B.Description,
         B.AttendeeCount,B.BookingStatus,B.ApprovalMode,B.Remark,B.RequesterUserID,
         E.EmployeeCode,E.FullName,BR.BranchNameTH,BD.BuildingNameTH,F.FloorNameTH,B.CreateDate
ORDER BY MIN(S.StartDateTime),B.CreateDate
OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;
""";
        await using var command = new SqlCommand(sql, connection);
        BindList(command, companyId, roomId, from, to);
        Add(command, "@mine", mine); Add(command, "@user", userId);
        Add(command, "@skip", (page - 1) * pageSize);
        Add(command, "@take", pageSize);
        var canManageAllParticipants = await IsCompanyAdmin(connection, companyId, userId, token);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new
        {
            bookingId = reader.GetInt64(0),
            bookingNo = Text(reader, 1),
            roomId = reader.GetInt64(2),
            roomCode = reader.GetString(3),
            roomNameTh = reader.GetString(4),
            subject = reader.GetString(5),
            description = Text(reader, 6),
            attendeeCount = reader.GetInt32(7),
            status = reader.GetString(8),
            approvalMode = reader.GetString(9),
            remark = Text(reader, 10),
            requesterUserId = reader.GetInt64(11),
            requesterCode = Text(reader, 12),
            requesterName = Text(reader, 13),
            startDateTime = reader.GetDateTime(14),
            endDateTime = reader.GetDateTime(15),
            slotCount = reader.GetInt64(16),
            branchName = Text(reader, 17),
            buildingName = Text(reader, 18),
            floorName = Text(reader, 19),
            canManageParticipants = reader.GetString(8) is "PENDING" or "APPROVED" &&
                                    (reader.GetInt64(11) == userId || canManageAllParticipants),
        });
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("{bookingId:long}/participants")]
    public async Task<IActionResult> Participants(long bookingId, CancellationToken token)
    {
        if (!TryCompany(out var companyId) || !TryUser(out var userId)) return Forbid();
        await using var connection = await Open(token);
        var isAdmin = await IsCompanyAdmin(connection, companyId, userId, token);
        const string headerSql = """
SELECT B.BookingNo,B.BookingStatus,B.RequesterUserID,R.RoomCode,R.RoomNameTH,
       MIN(S.StartDateTime),MAX(S.EndDateTime),B.RequesterEmployeeID
FROM dbo.TDADMeetingRoomBooking B
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
INNER JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
WHERE B.BookingID=@booking AND B.CompanyID=@company
GROUP BY B.BookingNo,B.BookingStatus,B.RequesterUserID,R.RoomCode,R.RoomNameTH,B.RequesterEmployeeID;
""";
        await using var headerCommand = new SqlCommand(headerSql, connection);
        Add(headerCommand, "@booking", bookingId); Add(headerCommand, "@company", companyId);
        await using var headerReader = await headerCommand.ExecuteReaderAsync(token);
        if (!await headerReader.ReadAsync(token)) return NotFound(Error("ไม่พบรายการจอง", $"BookingID {bookingId} ไม่อยู่ในบริษัทของผู้ใช้งาน"));
        var bookingNo = Text(headerReader, 0);
        var status = headerReader.GetString(1);
        var requesterUserId = headerReader.GetInt64(2);
        var roomCode = headerReader.GetString(3);
        var roomName = headerReader.GetString(4);
        var startDateTime = headerReader.GetDateTime(5);
        var endDateTime = headerReader.GetDateTime(6);
        var requesterEmployeeId = Long(headerReader, 7);
        await headerReader.CloseAsync();
        if (requesterUserId != userId && !isAdmin) return Forbid();
        if (status is not ("PENDING" or "APPROVED")) return BadRequest(Error("ยังเชิญผู้เข้าร่วมไม่ได้", "รายการจองต้องอยู่ในสถานะรออนุมัติหรืออนุมัติแล้ว"));

        const string employeeSql = """
SELECT E.EmployeeID,E.EmployeeCode,E.FullName,E.NickName,
       CASE WHEN P.BookingParticipantID IS NULL THEN 0 ELSE 1 END AS IsSelected,
       P.InvitationStatus,E.DepartmentOrgUnitID,D.NameTH
FROM dbo.TDADEmployee E
LEFT JOIN dbo.TDADMeetingRoomBookingParticipant P
    ON P.EmployeeID=E.EmployeeID AND P.CompanyID=E.CompanyID AND P.BookingID=@booking
LEFT JOIN dbo.TDADOrganizationUnit D
    ON D.OrgUnitID=E.DepartmentOrgUnitID AND D.CompanyID=E.CompanyID AND D.UnitType='DEP'
WHERE E.CompanyID=@company AND E.IsActive=1
  AND (@requesterEmployee IS NULL OR E.EmployeeID<>@requesterEmployee)
ORDER BY E.EmployeeCode,E.FullName;
""";
        await using var employeeCommand = new SqlCommand(employeeSql, connection);
        Add(employeeCommand, "@booking", bookingId); Add(employeeCommand, "@company", companyId);
        Add(employeeCommand, "@requesterEmployee", requesterEmployeeId);
        await using var reader = await employeeCommand.ExecuteReaderAsync(token);
        var employees = new List<object>();
        while (await reader.ReadAsync(token)) employees.Add(new
        {
            employeeId = reader.GetInt64(0), employeeCode = reader.GetString(1), employeeName = reader.GetString(2),
            nickName = Text(reader, 3), selected = reader.GetInt32(4) == 1, invitationStatus = Text(reader, 5),
            departmentOrgUnitId = Long(reader, 6), departmentName = Text(reader, 7),
        });
        return Ok(new { bookingId, bookingNo, status, roomCode, roomName, startDateTime, endDateTime, employees });
    }

    [HttpPut("{bookingId:long}/participants")]
    public async Task<IActionResult> SaveParticipants(long bookingId, ParticipantSaveRequest request, CancellationToken token)
    {
        if (!TryCompany(out var companyId) || !TryUser(out var userId)) return Forbid();
        var employeeIds = (request.EmployeeIds ?? []).Where(id => id > 0).Distinct().ToList();
        if (employeeIds.Count > 200) return BadRequest(Error("จำนวนผู้เข้าร่วมมากเกินไป", "เลือกผู้เข้าร่วมได้ไม่เกิน 200 คนต่อรายการ"));
        await using var connection = await Open(token);
        var isAdmin = await IsCompanyAdmin(connection, companyId, userId, token);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            const string bookingSql = "SELECT BookingStatus,RequesterUserID FROM dbo.TDADMeetingRoomBooking WITH (UPDLOCK,HOLDLOCK) WHERE BookingID=@booking AND CompanyID=@company";
            await using var bookingCommand = new SqlCommand(bookingSql, connection, transaction);
            Add(bookingCommand, "@booking", bookingId); Add(bookingCommand, "@company", companyId);
            await using var bookingReader = await bookingCommand.ExecuteReaderAsync(token);
            if (!await bookingReader.ReadAsync(token)) return NotFound(Error("ไม่พบรายการจอง", $"BookingID {bookingId} ไม่อยู่ในบริษัทของผู้ใช้งาน"));
            var status = bookingReader.GetString(0); var requesterUserId = bookingReader.GetInt64(1);
            await bookingReader.CloseAsync();
            if (requesterUserId != userId && !isAdmin) return Forbid();
            if (status is not ("PENDING" or "APPROVED")) return BadRequest(Error("บันทึกผู้เข้าร่วมไม่ได้", "รายการจองต้องอยู่ในสถานะรออนุมัติหรืออนุมัติแล้ว"));

            foreach (var employeeId in employeeIds)
            {
                const string validateSql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADEmployee WHERE EmployeeID=@employee AND CompanyID=@company AND IsActive=1) THEN 1 ELSE 0 END";
                await using var validate = new SqlCommand(validateSql, connection, transaction);
                Add(validate, "@employee", employeeId); Add(validate, "@company", companyId);
                if (!Convert.ToBoolean(await validate.ExecuteScalarAsync(token)))
                    return BadRequest(Error("ข้อมูลผู้เข้าร่วมไม่ถูกต้อง", $"ไม่พบพนักงาน ID {employeeId} ที่ยังใช้งานอยู่ในบริษัท"));
            }

            await Execute(connection, transaction, "DELETE FROM dbo.TDADMeetingRoomBookingParticipant WHERE BookingID=@booking AND CompanyID=@company;", token, ("@booking", bookingId), ("@company", companyId));
            foreach (var employeeId in employeeIds)
            {
                const string insertSql = "INSERT dbo.TDADMeetingRoomBookingParticipant(BookingID,CompanyID,EmployeeID,InvitedByUserID) VALUES(@booking,@company,@employee,@user)";
                await using var insert = new SqlCommand(insertSql, connection, transaction);
                Add(insert, "@booking", bookingId); Add(insert, "@company", companyId); Add(insert, "@employee", employeeId); Add(insert, "@user", userId);
                await insert.ExecuteNonQueryAsync(token);
            }
            await transaction.CommitAsync(token);
            return Ok(new { bookingId, participantCount = employeeIds.Count });
        }
        catch
        {
            await transaction.RollbackAsync(token);
            throw;
        }
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token)
    {
        if (!TryCompany(out var companyId) || !await Permission("VIEW", token)) return Forbid();
        await using var connection = await Open(token);
        const string sql = """
SELECT B.BookingID,B.BookingNo,B.RoomID,B.Subject,B.Description,B.AttendeeCount,
       B.BookingStatus,B.ApprovalMode,B.RequireAllApprovers,B.Remark,B.RequesterUserID
FROM dbo.TDADMeetingRoomBooking B
WHERE B.BookingID=@id AND B.CompanyID=@company;

SELECT S.BookingSlotID,S.BookingDate,S.StartDateTime,S.EndDateTime
FROM dbo.TDADMeetingRoomBookingSlot S
WHERE S.BookingID=@id AND S.CompanyID=@company
ORDER BY S.StartDateTime;

SELECT A.BookingApprovalID,A.EmployeeID,A.ApprovalOrder,A.ApprovalStatus,
       A.ActionDate,A.Remark,E.EmployeeCode,E.FullName,E.NickName
FROM dbo.TDADMeetingRoomBookingApproval A
INNER JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=A.BookingID AND B.CompanyID=@company
INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=A.EmployeeID AND E.CompanyID=B.CompanyID
WHERE A.BookingID=@id
ORDER BY A.ApprovalOrder,E.EmployeeCode;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@id", id);
        Add(command, "@company", companyId);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound(Error("ไม่พบรายการจอง", $"BookingID {id} ไม่อยู่ในบริษัทของผู้ใช้งาน"));
        var header = new
        {
            bookingId = reader.GetInt64(0), bookingNo = Text(reader, 1), roomId = reader.GetInt64(2),
            subject = reader.GetString(3), description = Text(reader, 4), attendeeCount = reader.GetInt32(5),
            status = reader.GetString(6), approvalMode = reader.GetString(7), requireAllApprovers = reader.GetBoolean(8),
            remark = Text(reader, 9), requesterUserId = reader.GetInt64(10),
        };
        await reader.NextResultAsync(token);
        var slots = new List<object>();
        while (await reader.ReadAsync(token)) slots.Add(new
        {
            bookingSlotId = reader.GetInt64(0), bookingDate = reader.GetDateTime(1),
            startDateTime = reader.GetDateTime(2), endDateTime = reader.GetDateTime(3),
        });
        await reader.NextResultAsync(token);
        var approvals = new List<object>();
        while (await reader.ReadAsync(token)) approvals.Add(new
        {
            bookingApprovalId = reader.GetInt64(0), employeeId = reader.GetInt64(1), approvalOrder = reader.GetInt32(2),
            status = reader.GetString(3), actionDate = reader.IsDBNull(4) ? (DateTime?)null : reader.GetDateTime(4),
            remark = Text(reader, 5), employeeCode = reader.GetString(6), employeeName = reader.GetString(7), nickName = Text(reader, 8),
        });
        return Ok(new { booking = header, slots, approvals });
    }

    [HttpPost("availability")]
    public async Task<IActionResult> Availability(AvailabilityRequest request, CancellationToken token)
    {
        if (!TryCompany(out var companyId) || !await Permission("VIEW", token)) return Forbid();
        var validation = ValidateSlots(request.Slots);
        if (validation is not null) return BadRequest(validation);
        await using var connection = await Open(token);
        var rooms = await LoadRooms(connection, companyId, request, token);
        if (rooms.Count == 0) return Ok(Array.Empty<object>());
        var conflicts = await LoadConflicts(connection, companyId, request.Slots!, request.ExcludeBookingId, token);
        var result = rooms.Select(room =>
        {
            var reason = AvailabilityReason(room, request.Slots!, request.AttendeeCount, conflicts);
            var roomConflicts = conflicts.GetValueOrDefault(room.RoomId) ?? [];
            var matchingConflicts = roomConflicts
                .Where(conflict => request.Slots!.Any(slot =>
                {
                    var start = Local(slot.StartDateTime);
                    var end = Local(slot.EndDateTime);
                    return start < conflict.End && end > conflict.Start;
                }))
                .OrderBy(conflict => conflict.Start)
                .Select(conflict => new
                {
                    conflict.BookingId,
                    conflict.BookingNo,
                    conflict.Subject,
                    conflict.RequesterName,
                    startDateTime = conflict.Start,
                    endDateTime = conflict.End,
                })
                .ToList();
            return new
            {
                room.RoomId, room.RoomCode, room.RoomNameTh, room.Capacity, room.Description,
                room.RoomImageUrl, room.LocationImageUrl, room.BranchId, room.BranchName,
                room.BuildingId, room.BuildingName, room.FloorId, room.FloorName, room.Facilities,
                isAvailable = reason is null,
                unavailableReason = reason,
                conflictingBookings = matchingConflicts,
            };
        });
        return Ok(result);
    }

    [HttpPost]
    public Task<IActionResult> Create(BookingSaveRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, BookingSaveRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Cancel(long id, CancellationToken token)
    {
        if (!TryCompany(out var companyId) || !TryUser(out var userId) || !await Permission("DELETE", token)) return Forbid();
        await using var connection = await Open(token);
        const string sql = """
UPDATE dbo.TDADMeetingRoomBooking
SET BookingStatus='CANCELLED',CancelDate=SYSUTCDATETIME(),UpdateDate=SYSUTCDATETIME(),UpdateBy=@user
WHERE BookingID=@id AND CompanyID=@company AND BookingStatus<>'CANCELLED';
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@id", id); Add(command, "@company", companyId); Add(command, "@user", userId);
        return await command.ExecuteNonQueryAsync(token) == 0
            ? NotFound(Error("ไม่พบรายการจองที่ยกเลิกได้", $"BookingID {id} อาจถูกยกเลิกแล้วหรือไม่อยู่ในบริษัทของผู้ใช้งาน"))
            : Ok(new { bookingId = id, status = "CANCELLED" });
    }

    private async Task<IActionResult> Save(long? id, BookingSaveRequest request, CancellationToken token)
    {
        var action = id is null ? "CREATE" : "EDIT";
        if (!TryCompany(out var companyId) || !TryUser(out var userId) || !await Permission(action, token)) return Forbid();
        if (string.IsNullOrWhiteSpace(request.Subject)) return BadRequest(Error("กรุณาระบุหัวข้อประชุม", "หัวข้อประชุมเป็นข้อมูลบังคับ"));
        if (request.AttendeeCount <= 0) return BadRequest(Error("จำนวนผู้เข้าร่วมไม่ถูกต้อง", "จำนวนผู้เข้าร่วมต้องมากกว่า 0"));
        var slotValidation = ValidateSlots(request.Slots);
        if (slotValidation is not null) return BadRequest(slotValidation);

        await using var connection = await Open(token);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var room = await LoadRoomForSave(connection, transaction, companyId, request.RoomId, token);
            if (room is null) return BadRequest(Error("ไม่พบห้องประชุม", "ห้องประชุมอาจถูกปิดใช้งานหรือไม่อยู่ในบริษัทของผู้ใช้งาน"));
            var conflicts = await LoadConflicts(connection, companyId, request.Slots!, id, token, transaction, true);
            var reason = AvailabilityReason(room, request.Slots!, request.AttendeeCount, conflicts);
            if (reason is not null) return Conflict(Error("ไม่สามารถจองห้องประชุมได้", reason));

            var requesterEmployeeId = await RequesterEmployee(connection, transaction, companyId, userId, token);
            var approval = await ResolveApprovers(connection, transaction, companyId, request.RoomId, requesterEmployeeId, token);
            var status = approval.EmployeeIds.Count == 0 ? "APPROVED" : "PENDING";
            string? previousStatus = null;
            if (id is long existingBookingId)
            {
                await using var previous = new SqlCommand(
                    "SELECT BookingStatus FROM dbo.TDADMeetingRoomBooking WHERE BookingID=@id AND CompanyID=@company",
                    connection, transaction);
                Add(previous, "@id", existingBookingId); Add(previous, "@company", companyId);
                previousStatus = Convert.ToString(await previous.ExecuteScalarAsync(token));
            }
            long bookingId;
            if (id is null)
            {
                const string insert = """
INSERT dbo.TDADMeetingRoomBooking
    (CompanyID,RoomID,RequesterUserID,RequesterEmployeeID,Subject,Description,AttendeeCount,
     BookingStatus,ApprovalMode,RequireAllApprovers,Remark,CreateBy)
VALUES
    (@company,@room,@user,@employee,@subject,@description,@attendee,@status,@mode,@requireAll,@remark,@user);
DECLARE @id BIGINT=CONVERT(BIGINT,SCOPE_IDENTITY());
UPDATE dbo.TDADMeetingRoomBooking
SET BookingNo=CONCAT('BK',CONVERT(char(8),GETDATE(),112),RIGHT(CONCAT('000000',@id),6))
WHERE BookingID=@id;
SELECT @id;
""";
                await using var insertCommand = new SqlCommand(insert, connection, transaction);
                BindHeader(insertCommand, companyId, userId, requesterEmployeeId, request, approval, status);
                bookingId = Convert.ToInt64(await insertCommand.ExecuteScalarAsync(token));
            }
            else
            {
                const string update = """
UPDATE dbo.TDADMeetingRoomBooking
SET RoomID=@room,RequesterEmployeeID=@employee,Subject=@subject,Description=@description,
    AttendeeCount=@attendee,BookingStatus=@status,ApprovalMode=@mode,
    RequireAllApprovers=@requireAll,Remark=@remark,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user,CancelDate=NULL
WHERE BookingID=@id AND CompanyID=@company AND BookingStatus NOT IN ('REJECTED','CANCELLED');
SELECT @@ROWCOUNT;
""";
                await using var updateCommand = new SqlCommand(update, connection, transaction);
                BindHeader(updateCommand, companyId, userId, requesterEmployeeId, request, approval, status);
                Add(updateCommand, "@id", id.Value);
                if (Convert.ToInt32(await updateCommand.ExecuteScalarAsync(token)) == 0)
                    return BadRequest(Error("แก้ไขรายการจองไม่ได้", "ไม่พบรายการ หรือรายการถูกปฏิเสธ/ยกเลิกแล้ว"));
                bookingId = id.Value;
                await Execute(connection, transaction, "DELETE FROM dbo.TDADMeetingRoomBookingSlot WHERE BookingID=@id; DELETE FROM dbo.TDADMeetingRoomBookingApproval WHERE BookingID=@id;", token, ("@id", bookingId));
            }

            await AddStatusHistory(connection, transaction, companyId, bookingId, previousStatus, status, userId, "BOOKING", request.Remark, token);

            foreach (var slot in request.Slots!)
            {
                const string insertSlot = """
INSERT dbo.TDADMeetingRoomBookingSlot(BookingID,CompanyID,RoomID,BookingDate,StartDateTime,EndDateTime)
VALUES(@booking,@company,@room,@date,@start,@end);
""";
                await using var slotCommand = new SqlCommand(insertSlot, connection, transaction);
                Add(slotCommand, "@booking", bookingId); Add(slotCommand, "@company", companyId); Add(slotCommand, "@room", request.RoomId);
                Add(slotCommand, "@date", slot.StartDateTime.Date); Add(slotCommand, "@start", Local(slot.StartDateTime)); Add(slotCommand, "@end", Local(slot.EndDateTime));
                await slotCommand.ExecuteNonQueryAsync(token);
            }
            for (var index = 0; index < approval.EmployeeIds.Count; index++)
            {
                const string insertApproval = """
INSERT dbo.TDADMeetingRoomBookingApproval(BookingID,EmployeeID,ApprovalOrder)
VALUES(@booking,@employee,@order);
""";
                await using var approvalCommand = new SqlCommand(insertApproval, connection, transaction);
                Add(approvalCommand, "@booking", bookingId); Add(approvalCommand, "@employee", approval.EmployeeIds[index]); Add(approvalCommand, "@order", index + 1);
                await approvalCommand.ExecuteNonQueryAsync(token);
            }
            await transaction.CommitAsync(token);
            return Ok(new { bookingId, status, approvalMode = approval.Mode });
        }
        catch (BookingValidationException error)
        {
            await transaction.RollbackAsync(token);
            return BadRequest(Error(error.Message, error.Description));
        }
        catch
        {
            await transaction.RollbackAsync(token);
            throw;
        }
    }

    private static object? ValidateSlots(List<BookingSlotRequest>? slots)
    {
        if (slots is null || slots.Count == 0) return Error("กรุณาเลือกวันและเวลา", "ต้องมีช่วงเวลาจองอย่างน้อย 1 รายการ");
        if (slots.Count > 31) return Error("จำนวนวันที่มากเกินไป", "การจองหนึ่งรายการเลือกได้ไม่เกิน 31 วัน");
        if (slots.Any(slot => slot.EndDateTime <= slot.StartDateTime)) return Error("ช่วงเวลาไม่ถูกต้อง", "เวลาสิ้นสุดต้องมากกว่าเวลาเริ่ม");
        if (slots.Any(slot => slot.StartDateTime.Date != slot.EndDateTime.Date)) return Error("ช่วงเวลาข้ามวันไม่ได้", "กรุณาแยกช่วงเวลาเป็นรายการของแต่ละวัน");
        if (slots.Select(slot => Local(slot.StartDateTime)).Distinct().Count() != slots.Count) return Error("มีวันและเวลาซ้ำ", "กรุณาตรวจสอบช่วงเวลาที่เลือก");
        return null;
    }

    private async Task<List<RoomAvailability>> LoadRooms(SqlConnection connection, long companyId, AvailabilityRequest request, CancellationToken token)
    {
        const string sql = """
SELECT R.RoomID,R.RoomCode,R.RoomNameTH,R.Capacity,R.Description,R.RoomImageUrl,R.LocationImageUrl,
       B.BranchID,BR.BranchNameTH,B.BuildingID,B.BuildingNameTH,F.FloorID,F.FloorNameTH,
       STUFF((SELECT N', ' + MF.FacilityNameTH FROM dbo.TDADMeetingRoomFacility RF
              INNER JOIN dbo.TDADMeetingFacility MF ON MF.FacilityID=RF.FacilityID AND MF.CompanyID=R.CompanyID
              WHERE RF.RoomID=R.RoomID AND RF.IsActive=1 ORDER BY MF.FacilityCode FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,N''),
       BookingRule.MaxAdvanceDays,BookingRule.MaxDurationMinutes
FROM dbo.TDADMeetingRoom R
LEFT JOIN dbo.TDADBuilding B ON B.BuildingID=R.BuildingID AND B.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADBranch BR ON BR.BranchID=B.BranchID AND BR.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADFloor F ON F.FloorID=R.FloorID
LEFT JOIN dbo.TDADMeetingRoomBookingRule BookingRule ON BookingRule.RoomID=R.RoomID AND BookingRule.CompanyID=R.CompanyID AND BookingRule.IsActive=1
WHERE R.CompanyID=@company AND R.IsActive=1
  AND (@room IS NULL OR R.RoomID=@room)
  AND (@branch IS NULL OR B.BranchID=@branch)
  AND (@building IS NULL OR B.BuildingID=@building)
  AND (@floor IS NULL OR F.FloorID=@floor)
ORDER BY R.RoomCode;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@company", companyId); Add(command, "@room", request.RoomId); Add(command, "@branch", request.BranchId); Add(command, "@building", request.BuildingId); Add(command, "@floor", request.FloorId);
        await using var reader = await command.ExecuteReaderAsync(token);
        var result = new List<RoomAvailability>();
        while (await reader.ReadAsync(token)) result.Add(ReadRoomAvailability(reader));
        return result;
    }

    private async Task<RoomAvailability?> LoadRoomForSave(SqlConnection connection, SqlTransaction transaction, long companyId, long roomId, CancellationToken token)
    {
        const string sql = """
SELECT R.RoomID,R.RoomCode,R.RoomNameTH,R.Capacity,R.Description,R.RoomImageUrl,R.LocationImageUrl,
       B.BranchID,BR.BranchNameTH,B.BuildingID,B.BuildingNameTH,F.FloorID,F.FloorNameTH,
       CAST(NULL AS nvarchar(max)),BookingRule.MaxAdvanceDays,BookingRule.MaxDurationMinutes
FROM dbo.TDADMeetingRoom R
LEFT JOIN dbo.TDADBuilding B ON B.BuildingID=R.BuildingID AND B.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADBranch BR ON BR.BranchID=B.BranchID AND BR.CompanyID=R.CompanyID
LEFT JOIN dbo.TDADFloor F ON F.FloorID=R.FloorID
LEFT JOIN dbo.TDADMeetingRoomBookingRule BookingRule ON BookingRule.RoomID=R.RoomID AND BookingRule.CompanyID=R.CompanyID AND BookingRule.IsActive=1
WHERE R.CompanyID=@company AND R.RoomID=@room AND R.IsActive=1;
""";
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@company", companyId); Add(command, "@room", roomId);
        await using var reader = await command.ExecuteReaderAsync(token);
        return await reader.ReadAsync(token) ? ReadRoomAvailability(reader) : null;
    }

    private static string? AvailabilityReason(RoomAvailability room, List<BookingSlotRequest> slots, int? attendeeCount, Dictionary<long, List<BookingConflict>> conflicts)
    {
        if (attendeeCount is > 0 && room.Capacity is > 0 && attendeeCount > room.Capacity) return $"ห้องรองรับสูงสุด {room.Capacity} คน";
        var now = DateTime.Now;
        foreach (var slot in slots)
        {
            var start = Local(slot.StartDateTime); var end = Local(slot.EndDateTime);
            if (start < now) return "ไม่สามารถจองช่วงเวลาที่ผ่านมาแล้ว";
            if (room.MaxAdvanceDays is int advance && start.Date > now.Date.AddDays(advance)) return $"ห้องกำหนดให้จองล่วงหน้าได้ไม่เกิน {advance} วัน";
            if (room.MaxDurationMinutes is int duration && (end - start).TotalMinutes > duration) return $"ห้องกำหนดระยะเวลาสูงสุด {duration} นาที";
            if (conflicts.TryGetValue(room.RoomId, out var occupied) && occupied.Any(item => start < item.End && end > item.Start)) return "ช่วงเวลานี้มีผู้จองแล้ว";
        }
        return null;
    }

    private async Task<Dictionary<long, List<BookingConflict>>> LoadConflicts(SqlConnection connection, long companyId, List<BookingSlotRequest> slots, long? excludeBookingId, CancellationToken token, SqlTransaction? transaction = null, bool lockRows = false)
    {
        var min = slots.Min(slot => Local(slot.StartDateTime));
        var max = slots.Max(slot => Local(slot.EndDateTime));
        var hint = lockRows ? "WITH (UPDLOCK,HOLDLOCK)" : string.Empty;
        var sql = $"""
SELECT S.RoomID,S.StartDateTime,S.EndDateTime,B.BookingID,B.BookingNo,B.Subject,
       NULLIF(E.FullName,'')
FROM dbo.TDADMeetingRoomBookingSlot S {hint}
INNER JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=S.BookingID AND B.CompanyID=S.CompanyID
LEFT JOIN dbo.TDADUserEmployee RequesterUE ON RequesterUE.CompanyID=B.CompanyID AND RequesterUE.UserID=B.RequesterUserID
LEFT JOIN dbo.TDADEmployee E ON E.EmployeeID=COALESCE(B.RequesterEmployeeID,RequesterUE.EmployeeID) AND E.CompanyID=B.CompanyID
WHERE S.CompanyID=@company AND S.StartDateTime<@max AND S.EndDateTime>@min
  AND B.BookingStatus IN ('PENDING','APPROVED')
  AND (@exclude IS NULL OR B.BookingID<>@exclude);
""";
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@company", companyId); Add(command, "@min", min); Add(command, "@max", max); Add(command, "@exclude", excludeBookingId);
        await using var reader = await command.ExecuteReaderAsync(token);
        var result = new Dictionary<long, List<BookingConflict>>();
        while (await reader.ReadAsync(token))
        {
            var room = reader.GetInt64(0);
            if (!result.TryGetValue(room, out var list)) result[room] = list = [];
            list.Add(new BookingConflict(
                reader.GetInt64(3),
                Text(reader, 4),
                reader.GetString(5),
                Text(reader, 6),
                reader.GetDateTime(1),
                reader.GetDateTime(2)));
        }
        return result;
    }

    private async Task<ApprovalResolution> ResolveApprovers(SqlConnection connection, SqlTransaction transaction, long companyId, long roomId, long? requesterEmployeeId, CancellationToken token)
    {
        const string ruleSql = """
SELECT ApprovalMode,RequireAllApprovers
FROM dbo.TDADMeetingRoomBookingRule
WHERE CompanyID=@company AND RoomID=@room AND IsActive=1;
""";
        await using var ruleCommand = new SqlCommand(ruleSql, connection, transaction);
        Add(ruleCommand, "@company", companyId); Add(ruleCommand, "@room", roomId);
        await using var reader = await ruleCommand.ExecuteReaderAsync(token);
        var mode = "NONE"; var requireAll = true;
        if (await reader.ReadAsync(token)) { mode = reader.GetString(0); requireAll = reader.GetBoolean(1); }
        await reader.CloseAsync();
        if (mode == "NONE") return new(mode, requireAll, []);

        var employees = new List<long>();
        if (mode == "SELECTED")
        {
            const string sql = """
SELECT A.EmployeeID
FROM dbo.TDADMeetingRoomBookingRuleApprover A
INNER JOIN dbo.TDADMeetingRoomBookingRule R ON R.RuleID=A.RuleID AND R.CompanyID=@company AND R.RoomID=@room AND R.IsActive=1
INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=A.EmployeeID AND E.CompanyID=@company AND E.IsActive=1
ORDER BY A.ApprovalOrder,A.EmployeeID;
""";
            await using var command = new SqlCommand(sql, connection, transaction);
            Add(command, "@company", companyId); Add(command, "@room", roomId);
            await using var approverReader = await command.ExecuteReaderAsync(token);
            while (await approverReader.ReadAsync(token)) employees.Add(approverReader.GetInt64(0));
        }
        else if (mode == "LINE_MANAGER")
        {
            if (requesterEmployeeId is null) throw new BookingValidationException("ไม่พบข้อมูลพนักงานของผู้จอง", "กรุณาผูก User Login กับพนักงานก่อนใช้กฎอนุมัติโดยหัวหน้าแผนก");
            const string sql = """
SELECT TOP 1 S.EmployeeID
FROM dbo.TDADEmployee E
INNER JOIN dbo.TDADOrganizationSupervisor S
    ON S.CompanyID=E.CompanyID AND S.OrgUnitID=E.DepartmentOrgUnitID
   AND S.SupervisorType=N'DEPARTMENT_HEAD' AND S.IsActive=1
INNER JOIN dbo.TDADEmployee H ON H.EmployeeID=S.EmployeeID AND H.CompanyID=E.CompanyID AND H.IsActive=1
WHERE E.EmployeeID=@employee AND E.CompanyID=@company AND E.IsActive=1;
""";
            await using var command = new SqlCommand(sql, connection, transaction);
            Add(command, "@employee", requesterEmployeeId); Add(command, "@company", companyId);
            var value = await command.ExecuteScalarAsync(token);
            if (value is not null && value != DBNull.Value) employees.Add(Convert.ToInt64(value));
        }
        if (employees.Count == 0) throw new BookingValidationException("ยังไม่ได้กำหนดผู้อนุมัติ", mode == "LINE_MANAGER" ? "กรุณากำหนดหัวหน้าแผนกของผู้จองก่อน" : "กรุณากำหนดผู้อนุมัติในกฎของห้องประชุมก่อน");
        return new(mode, requireAll, employees.Distinct().ToList());
    }

    private static async Task<long?> RequesterEmployee(SqlConnection connection, SqlTransaction transaction, long companyId, long userId, CancellationToken token)
    {
        const string sql = """
SELECT TOP 1 UE.EmployeeID
FROM dbo.TDADUserEmployee UE
INNER JOIN dbo.TDADEmployee E
    ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1
WHERE UE.UserID=@user AND UE.CompanyID=@company
ORDER BY UE.EmployeeID;
""";
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@user", userId); Add(command, "@company", companyId);
        var value = await command.ExecuteScalarAsync(token);
        return value is null || value == DBNull.Value ? null : Convert.ToInt64(value);
    }

    private async Task<bool> Permission(string action, CancellationToken token)
    {
        await using var connection = await Open(token);
        return await Allowed(connection, action, token);
    }

    private static async Task<bool> IsCompanyAdmin(SqlConnection connection, long companyId, long userId, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1) THEN 1 ELSE 0 END", connection);
        Add(command, "@user", userId); Add(command, "@company", companyId);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private async Task<bool> Allowed(
        SqlConnection connection,
        string action,
        CancellationToken token,
        string screenCode = ScreenCode)
    {
        if (!TryCompany(out var companyId) || !TryUser(out var userId) || !long.TryParse(User.FindFirstValue("project_id"), out var projectId)) return false;
        const string sql = """
SELECT CASE WHEN
    EXISTS (SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS
    (SELECT 1 FROM dbo.TDADUserPermission UP
     INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
     WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1
       AND P.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action)
 OR EXISTS
    (SELECT 1 FROM dbo.TDADUser U
     INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID AND UE.CompanyID=U.CompanyID
     INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
     INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C'
        AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project AND RG.IsActive=1
     INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project
        AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1
     WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1
       AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
       AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))
THEN 1 ELSE 0 END;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@user", userId); Add(command, "@company", companyId); Add(command, "@project", projectId); Add(command, "@screen", screenCode); Add(command, "@action", action);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private bool TryCompany(out long companyId) =>
        long.TryParse(User.FindFirstValue("company_id"), out companyId) &&
        companyId > 0 &&
        string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase);

    private bool TryUser(out long userId) => long.TryParse(User.FindFirstValue("user_id"), out userId) && userId > 0;

    private static object ReadRoom(SqlDataReader reader) => new
    {
        roomId = reader.GetInt64(0), buildingId = Long(reader, 1), floorId = Long(reader, 2),
        code = reader.GetString(3), nameTh = reader.GetString(4), capacity = Int(reader, 5),
        description = Text(reader, 6), roomImageUrl = Text(reader, 7), locationImageUrl = Text(reader, 8),
        branchId = Long(reader, 9), branchCode = Text(reader, 10), branchName = Text(reader, 11),
        buildingCode = Text(reader, 12), buildingName = Text(reader, 13), floorCode = Text(reader, 14), floorName = Text(reader, 15), facilities = Text(reader, 16),
    };

    private static RoomAvailability ReadRoomAvailability(SqlDataReader reader) => new(
        reader.GetInt64(0), reader.GetString(1), reader.GetString(2), Int(reader, 3), Text(reader, 4), Text(reader, 5), Text(reader, 6),
        Long(reader, 7), Text(reader, 8), Long(reader, 9), Text(reader, 10), Long(reader, 11), Text(reader, 12), Text(reader, 13), Int(reader, 14), Int(reader, 15));

    private static void BindList(SqlCommand command, long companyId, long? roomId, DateTime from, DateTime to)
    {
        Add(command, "@company", companyId); Add(command, "@room", roomId); Add(command, "@from", from); Add(command, "@to", to);
    }

    private static async Task AddStatusHistory(
        SqlConnection connection, SqlTransaction transaction, long companyId, long bookingId,
        string? fromStatus, string toStatus, long userId, string source, string? remark,
        CancellationToken token)
    {
        if (string.Equals(fromStatus, toStatus, StringComparison.OrdinalIgnoreCase)) return;
        const string sql = """
INSERT dbo.TDADMeetingRoomBookingStatusHistory
    (BookingID,CompanyID,FromStatus,ToStatus,ChangedByUserID,Remark,ChangeSource)
VALUES(@booking,@company,@from,@to,@user,@remark,@source);
""";
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@booking", bookingId); Add(command, "@company", companyId);
        Add(command, "@from", fromStatus); Add(command, "@to", toStatus); Add(command, "@user", userId);
        Add(command, "@remark", Clean(remark)); Add(command, "@source", source);
        await command.ExecuteNonQueryAsync(token);
    }

    private static void BindHeader(SqlCommand command, long companyId, long userId, long? employeeId, BookingSaveRequest request, ApprovalResolution approval, string status)
    {
        Add(command, "@company", companyId); Add(command, "@room", request.RoomId); Add(command, "@user", userId); Add(command, "@employee", employeeId);
        Add(command, "@subject", request.Subject.Trim()); Add(command, "@description", Clean(request.Description)); Add(command, "@attendee", request.AttendeeCount);
        Add(command, "@status", status); Add(command, "@mode", approval.Mode); Add(command, "@requireAll", approval.RequireAll); Add(command, "@remark", Clean(request.Remark));
    }

    private static async Task Execute(SqlConnection connection, SqlTransaction transaction, string sql, CancellationToken token, params (string Name, object? Value)[] parameters)
    {
        await using var command = new SqlCommand(sql, connection, transaction);
        foreach (var parameter in parameters) Add(command, parameter.Name, parameter.Value);
        await command.ExecuteNonQueryAsync(token);
    }

    private static object Error(string message, string description) => new { message, description };
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static DateTime Local(DateTime value) => DateTime.SpecifyKind(value, DateTimeKind.Unspecified);
    private static string? Text(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
    private static long? Long(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : Convert.ToInt64(reader.GetValue(index));
    private static int? Int(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : Convert.ToInt32(reader.GetValue(index));
    private static void Add(SqlCommand command, string name, object? value) => command.Parameters.AddWithValue(name, value ?? DBNull.Value);
}

public sealed record BookingSlotRequest(DateTime StartDateTime, DateTime EndDateTime);
public sealed record BookingSaveRequest(long RoomId, string Subject, string? Description, int AttendeeCount, List<BookingSlotRequest>? Slots, string? Remark);
public sealed record ApprovalDecisionRequest(string Decision, string? Remark);
public sealed record RollbackBookingRequest(string? Remark);
public sealed record ParticipantSaveRequest(List<long>? EmployeeIds);
public sealed record AvailabilityRequest(List<BookingSlotRequest>? Slots, long? RoomId, long? BranchId, long? BuildingId, long? FloorId, int? AttendeeCount, long? ExcludeBookingId);

internal sealed record ApprovalResolution(string Mode, bool RequireAll, List<long> EmployeeIds);
internal sealed record BookingConflict(
    long BookingId, string? BookingNo, string Subject, string? RequesterName,
    DateTime Start, DateTime End);
internal sealed record RoomAvailability(
    long RoomId, string RoomCode, string RoomNameTh, int? Capacity, string? Description,
    string? RoomImageUrl, string? LocationImageUrl, long? BranchId, string? BranchName,
    long? BuildingId, string? BuildingName, long? FloorId, string? FloorName,
    string? Facilities, int? MaxAdvanceDays, int? MaxDurationMinutes);

internal sealed class BookingValidationException(string message, string description) : Exception(message)
{
    public string Description { get; } = description;
}
