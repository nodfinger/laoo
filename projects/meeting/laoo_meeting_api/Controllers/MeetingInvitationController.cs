using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Route("api/company/my-meeting-invitations"), Authorize]
public sealed class MeetingInvitationController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "21003";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var connection = await Open(token);
        return Ok(new { view = await Allowed(connection, "VIEW", token), edit = await Allowed(connection, "EDIT", token) });
    }

    [HttpGet]
    public async Task<IActionResult> List(string? search = null, string? status = null, int page = 1, int pageSize = 20, CancellationToken token = default)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        var employee = await EmployeeId(connection, company, user, token);
        if (employee is null) return BadRequest(Error("ไม่พบข้อมูลพนักงานของผู้ใช้งาน", "กรุณาผูก User Login กับพนักงานก่อนเปิดคำเชิญของฉัน"));
        const string filter = @"
FROM dbo.TDADMeetingRoomBookingParticipant P
INNER JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
INNER JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADUserEmployee RUE ON RUE.UserID=B.RequesterUserID AND RUE.CompanyID=B.CompanyID AND RUE.IsActive=1
LEFT JOIN dbo.TDADEmployee RE ON RE.EmployeeID=COALESCE(B.RequesterEmployeeID,RUE.EmployeeID) AND RE.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADMeetingBookingFoodPlan FP ON FP.BookingID=B.BookingID AND FP.CompanyID=B.CompanyID AND FP.IsActive=1
WHERE P.CompanyID=@company AND P.EmployeeID=@employee AND B.BookingStatus='APPROVED'
  AND S.EndDateTime>=GETDATE()
  AND (@status IS NULL OR @status='' OR P.InvitationStatus=@status)
  AND (@search IS NULL OR B.BookingNo LIKE N'%'+@search+N'%' OR B.Subject LIKE N'%'+@search+N'%' OR R.RoomCode LIKE N'%'+@search+N'%' OR R.RoomNameTH LIKE N'%'+@search+N'%')";
        var countSql = $"SELECT COUNT_BIG(DISTINCT P.BookingParticipantID) {filter};";
        await using var count = new SqlCommand(countSql, connection); Bind(count, company, employee.Value, search, status);
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        var sql = $@"
SELECT P.BookingParticipantID,P.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,
       MIN(S.StartDateTime),MAX(S.EndDateTime),P.InvitationStatus,P.ResponseDate,P.Remark,
       RE.EmployeeCode,RE.FullName,FP.OrderCutoffDateTime,
       (SELECT COUNT_BIG(1) FROM dbo.TDADMeetingBookingFoodOption FO WHERE FO.BookingID=B.BookingID AND FO.CompanyID=B.CompanyID)
{filter}
GROUP BY P.BookingParticipantID,P.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,
         P.InvitationStatus,P.ResponseDate,P.Remark,RE.EmployeeCode,RE.FullName,FP.OrderCutoffDateTime,B.CreateDate
ORDER BY MIN(S.StartDateTime),B.CreateDate
OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;";
        await using var command = new SqlCommand(sql, connection); Bind(command, company, employee.Value, search, status); Add(command, "@skip", (page - 1) * pageSize); Add(command, "@take", pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new
        {
            participantId = reader.GetInt64(0), bookingId = reader.GetInt64(1), bookingNo = Text(reader, 2), subject = reader.GetString(3),
            roomCode = reader.GetString(4), roomName = reader.GetString(5), startDateTime = reader.GetDateTime(6), endDateTime = reader.GetDateTime(7),
            invitationStatus = reader.GetString(8), responseDate = Date(reader, 9), remark = Text(reader, 10), organizerCode = Text(reader, 11),
            organizerName = Text(reader, 12), orderCutoffDateTime = Date(reader, 13), foodCount = Convert.ToInt32(reader.GetInt64(14)),
        });
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("{participantId:long}")]
    public async Task<IActionResult> Get(long participantId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        var employee = await EmployeeId(connection, company, user, token);
        if (employee is null) return Forbid();
        const string headerSql = @"
SELECT P.BookingParticipantID,P.BookingID,B.BookingNo,B.Subject,B.Description,R.RoomCode,R.RoomNameTH,
       MIN(S.StartDateTime),MAX(S.EndDateTime),P.InvitationStatus,P.Remark,RE.FullName,FP.OrderCutoffDateTime
FROM dbo.TDADMeetingRoomBookingParticipant P
INNER JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID AND B.BookingStatus='APPROVED'
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
INNER JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADUserEmployee RUE ON RUE.UserID=B.RequesterUserID AND RUE.CompanyID=B.CompanyID AND RUE.IsActive=1
LEFT JOIN dbo.TDADEmployee RE ON RE.EmployeeID=COALESCE(B.RequesterEmployeeID,RUE.EmployeeID) AND RE.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADMeetingBookingFoodPlan FP ON FP.BookingID=B.BookingID AND FP.CompanyID=B.CompanyID AND FP.IsActive=1
WHERE P.BookingParticipantID=@participant AND P.CompanyID=@company AND P.EmployeeID=@employee AND S.EndDateTime>=GETDATE()
GROUP BY P.BookingParticipantID,P.BookingID,B.BookingNo,B.Subject,B.Description,R.RoomCode,R.RoomNameTH,P.InvitationStatus,P.Remark,RE.FullName,FP.OrderCutoffDateTime;";
        await using var header = new SqlCommand(headerSql, connection); Add(header, "@participant", participantId); Add(header, "@company", company); Add(header, "@employee", employee.Value);
        await using var reader = await header.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound(Error("ไม่พบคำเชิญ", $"คำเชิญ {participantId} ไม่อยู่ในขอบเขตของผู้ใช้งาน"));
        var bookingId = reader.GetInt64(1);
        var result = new
        {
            participantId = reader.GetInt64(0), bookingId, bookingNo = Text(reader, 2), subject = reader.GetString(3), description = Text(reader, 4),
            roomCode = reader.GetString(5), roomName = reader.GetString(6), startDateTime = reader.GetDateTime(7), endDateTime = reader.GetDateTime(8),
            invitationStatus = reader.GetString(9), remark = Text(reader, 10), organizerName = Text(reader, 11), orderCutoffDateTime = Date(reader, 12),
        };
        await reader.CloseAsync();
        const string foodSql = @"
SELECT F.FoodID,F.FoodCode,F.FoodNameTH,T.Name,F.FoodImageUrl
FROM dbo.TDADMeetingBookingFoodOption O
INNER JOIN dbo.TDADMeetingFood F ON F.FoodID=O.FoodID AND F.CompanyID=O.CompanyID
LEFT JOIN dbo.TDSTMaster T ON T.MasterGroupCode='011' AND T.MasterCode=F.FoodTypeCode AND T.OwnerType='L'
WHERE O.BookingID=@booking AND O.CompanyID=@company
ORDER BY ISNULL(T.Seq,0),F.FoodCode;";
        await using var food = new SqlCommand(foodSql, connection); Add(food, "@booking", bookingId); Add(food, "@company", company);
        await using var foodReader = await food.ExecuteReaderAsync(token);
        var foods = new List<object>();
        while (await foodReader.ReadAsync(token)) foods.Add(new { foodId = foodReader.GetInt64(0), code = foodReader.GetString(1), nameTh = foodReader.GetString(2), foodTypeName = Text(foodReader, 3), imageUrl = Text(foodReader, 4) });
        return Ok(new { invitation = result, foods });
    }

    [HttpPut("{participantId:long}/response")]
    public async Task<IActionResult> Respond(long participantId, InvitationResponseRequest request, CancellationToken token)
    {
        var status = request.Status?.Trim().ToUpperInvariant();
        if (status is not ("PENDING" or "ACCEPTED" or "DECLINED")) return BadRequest(Error("สถานะตอบรับไม่ถูกต้อง", "เลือกได้เฉพาะ รอตอบรับ เข้าร่วม หรือไม่เข้าร่วม"));
        if (!Scope(out var company, out var user)) return Forbid();
        await using var connection = await Open(token);
        if (!await Allowed(connection, "EDIT", token)) return Forbid();
        var employee = await EmployeeId(connection, company, user, token);
        if (employee is null) return Forbid();
        const string sql = @"
UPDATE P SET InvitationStatus=@status,ResponseDate=CASE WHEN @status='PENDING' THEN NULL ELSE SYSUTCDATETIME() END,Remark=@remark
FROM dbo.TDADMeetingRoomBookingParticipant P
INNER JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID AND B.BookingStatus='APPROVED'
WHERE P.BookingParticipantID=@participant AND P.CompanyID=@company AND P.EmployeeID=@employee
  AND EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBookingSlot S WHERE S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID AND S.EndDateTime>=GETDATE());";
        await using var command = new SqlCommand(sql, connection); Add(command, "@status", status); Add(command, "@remark", string.IsNullOrWhiteSpace(request.Remark) ? null : request.Remark.Trim()); Add(command, "@participant", participantId); Add(command, "@company", company); Add(command, "@employee", employee.Value);
        return await command.ExecuteNonQueryAsync(token) == 0 ? NotFound(Error("ไม่พบคำเชิญที่แก้ไขได้", "คำเชิญอาจสิ้นสุดหรือไม่อยู่ในบัญชีผู้ใช้นี้")) : Ok(new { participantId, status });
    }

    private async Task<long?> EmployeeId(SqlConnection connection, long company, long user, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT TOP 1 EmployeeID FROM dbo.TDADUserEmployee WHERE UserID=@user AND CompanyID=@company AND IsActive=1 ORDER BY UserEmployeeID", connection); Add(command, "@user", user); Add(command, "@company", company);
        var value = await command.ExecuteScalarAsync(token); return value is null ? null : Convert.ToInt64(value);
    }
    private void Bind(SqlCommand command, long company, long employee, string? search, string? status) { Add(command, "@company", company); Add(command, "@employee", employee); Add(command, "@search", string.IsNullOrWhiteSpace(search) ? null : search.Trim()); Add(command, "@status", string.IsNullOrWhiteSpace(status) ? null : status.Trim().ToUpperInvariant()); }
    private async Task<bool> Allowed(SqlConnection connection, string action, CancellationToken token)
    {
        if (!Scope(out var company, out var user) || !long.TryParse(User.FindFirstValue("project_id"), out var project)) return false;
        const string sql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action) THEN 1 ELSE 0 END";
        await using var command = new SqlCommand(sql, connection); Add(command, "@user", user); Add(command, "@company", company); Add(command, "@project", project); Add(command, "@screen", ScreenCode); Add(command, "@action", action); return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }
    private bool Scope(out long company, out long user)
    {
        company = 0; user = 0;
        return long.TryParse(User.FindFirstValue("company_id"), out company) && company > 0
            && long.TryParse(User.FindFirstValue("user_id"), out user) && user > 0
            && string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase);
    }
    private async Task<SqlConnection> Open(CancellationToken token) { var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await connection.OpenAsync(token); return connection; }
    private static object Error(string message, string description) => new { message, description };
    private static string? Text(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
    private static DateTime? Date(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetDateTime(index);
    private static void Add(SqlCommand command, string name, object? value) => command.Parameters.AddWithValue(name, value ?? DBNull.Value);
}

public sealed record InvitationResponseRequest(string? Status, string? Remark);
