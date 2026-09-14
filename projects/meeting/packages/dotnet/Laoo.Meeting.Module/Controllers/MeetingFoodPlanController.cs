using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using LaooMeetingApi.Models;
using LaooMeetingApi.Security;

namespace LaooMeetingApi.Controllers;

[ApiController, Route("api/company/meeting-food-plans"), Authorize]
[LaooMeetingApi.Security.RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingFoodPlanController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "21005";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var connection = await Open(token);
        return Ok(new
        {
            view = await Allowed(connection, "VIEW", token),
            create = await Allowed(connection, "CREATE", token),
            edit = await Allowed(connection, "EDIT", token),
            delete = await Allowed(connection, "DELETE", token),
        });
    }

    [HttpGet]
    public async Task<IActionResult> List(string? search = null, int page = 1, int pageSize = 20, CancellationToken token = default)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        var filter = $@"
FROM dbo.TDADMeetingRoomBooking B
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
INNER JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADMeetingBookingFoodPlan P ON P.BookingID=B.BookingID AND P.CompanyID=B.CompanyID
WHERE B.CompanyID=@company AND B.BookingStatus='APPROVED'
  AND S.EndDateTime>=GETDATE()
  AND {MeetingFoodPlanAccess.OwnershipSql}
  AND (@search IS NULL OR B.BookingNo LIKE N'%'+@search+N'%' OR B.Subject LIKE N'%'+@search+N'%' OR R.RoomCode LIKE N'%'+@search+N'%' OR R.RoomNameTH LIKE N'%'+@search+N'%')";
        var countSql = $"SELECT COUNT_BIG(DISTINCT B.BookingID) {filter};";
        await using var countCommand = new SqlCommand(countSql, connection);
        Bind(countCommand, company, user, search);
        var total = Convert.ToInt64(await countCommand.ExecuteScalarAsync(token));
        var sql = $@"
SELECT B.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,
       MIN(S.StartDateTime),MAX(S.EndDateTime),P.OrderCutoffDateTime,P.IsActive,
       (SELECT COUNT_BIG(1) FROM dbo.TDADMeetingBookingFoodOption O WHERE O.BookingID=B.BookingID AND O.CompanyID=B.CompanyID)
{filter}
GROUP BY B.BookingID,B.CompanyID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,P.OrderCutoffDateTime,P.IsActive,B.CreateDate
ORDER BY MIN(S.StartDateTime),B.CreateDate
OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;";
        await using var command = new SqlCommand(sql, connection);
        Bind(command, company, user, search);
        Add(command, "@skip", (page - 1) * pageSize);
        Add(command, "@take", pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new
        {
            bookingId = reader.GetInt64(0), bookingNo = Text(reader, 1), subject = reader.GetString(2),
            roomCode = reader.GetString(3), roomName = reader.GetString(4), startDateTime = reader.GetDateTime(5),
            endDateTime = reader.GetDateTime(6), orderCutoffDateTime = Date(reader, 7),
            isActive = Bool(reader, 8), foodCount = Convert.ToInt32(reader.GetInt64(9)),
        });
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("{bookingId:long}")]
    public async Task<IActionResult> Get(long bookingId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var connection = await Open(token);
        var header = await BookingHeader(connection, bookingId, company, user, token);
        if (header is null) return NotFound(Error("ไม่พบรายการประชุม", $"BookingID {bookingId} ไม่อยู่ในขอบเขตของผู้ใช้งาน"));
        const string sql = @"
SELECT F.FoodID,F.FoodCode,F.FoodNameTH,F.FoodTypeCode,T.Name,F.FoodImageUrl,
       CASE WHEN O.BookingFoodOptionID IS NULL THEN 0 ELSE 1 END
FROM dbo.TDADMeetingFood F
OUTER APPLY
(
    SELECT TOP (1) M.Name,M.Seq
    FROM dbo.TDSTMaster M
    WHERE M.MasterGroupCode=@foodTypeGroup
      AND M.MasterCode=F.FoodTypeCode
      AND M.IsActive=1
      AND M.OwnerType='C'
      AND M.OwnerCompanyID=@company
) T
LEFT JOIN dbo.TDADMeetingBookingFoodOption O ON O.FoodID=F.FoodID AND O.BookingID=@booking AND O.CompanyID=F.CompanyID
WHERE F.CompanyID=@company
ORDER BY ISNULL(T.Seq,0),F.FoodCode;";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@booking", bookingId); Add(command, "@company", company);
        Add(command, "@foodTypeGroup", MasterGroupCodes.FoodType);
        var foods = new List<object>();
        await using (var reader = await command.ExecuteReaderAsync(token))
        {
            while (await reader.ReadAsync(token)) foods.Add(new
            {
                foodId = reader.GetInt64(0), code = reader.GetString(1), nameTh = reader.GetString(2),
                foodTypeCode = reader.GetString(3), foodTypeName = Text(reader, 4), imageUrl = Text(reader, 5),
                selected = reader.GetInt32(6) == 1,
            });
        }
        var groups = new List<object>();
        const string groupSql = "SELECT FoodTypeCode,MaxQuantity,IsRequired FROM dbo.TDADMeetingBookingFoodGroup WHERE BookingID=@booking AND CompanyID=@company AND IsActive=1 ORDER BY BookingFoodGroupID";
        await using (var groupCommand = new SqlCommand(groupSql, connection))
        {
            Add(groupCommand, "@booking", bookingId); Add(groupCommand, "@company", company);
            await using var groupReader = await groupCommand.ExecuteReaderAsync(token);
            while (await groupReader.ReadAsync(token)) groups.Add(new
            {
                foodTypeCode = groupReader.GetString(0),
                maxQuantity = groupReader.GetInt32(1),
                isRequired = groupReader.GetBoolean(2),
            });
        }
        var questionDefinitions = new List<(long Id, string Text, string Type, bool Required, int Sort)>();
        const string questionSql = """
SELECT RequirementQuestionID,QuestionText,AnswerType,IsRequired,SortOrder
FROM dbo.TDADMeetingBookingRequirementQuestion
WHERE BookingID=@booking AND CompanyID=@company AND IsActive=1
ORDER BY SortOrder,RequirementQuestionID;
""";
        await using (var questionCommand = new SqlCommand(questionSql, connection))
        {
            Add(questionCommand, "@booking", bookingId); Add(questionCommand, "@company", company);
            await using var questionReader = await questionCommand.ExecuteReaderAsync(token);
            while (await questionReader.ReadAsync(token)) questionDefinitions.Add((questionReader.GetInt64(0), questionReader.GetString(1), questionReader.GetString(2), questionReader.GetBoolean(3), questionReader.GetInt32(4)));
        }
        var questions = new List<object>();
        foreach (var question in questionDefinitions)
        {
            var options = new List<object>();
            await using var optionCommand = new SqlCommand("SELECT RequirementOptionID,OptionText,SortOrder FROM dbo.TDADMeetingBookingRequirementOption WHERE RequirementQuestionID=@question AND IsActive=1 ORDER BY SortOrder,RequirementOptionID", connection);
            Add(optionCommand, "@question", question.Id);
            await using var optionReader = await optionCommand.ExecuteReaderAsync(token);
            while (await optionReader.ReadAsync(token)) options.Add(new { optionId = optionReader.GetInt64(0), optionText = optionReader.GetString(1), sortOrder = optionReader.GetInt32(2) });
            questions.Add(new { questionId = question.Id, questionText = question.Text, answerType = question.Type, isRequired = question.Required, sortOrder = question.Sort, options });
        }
        var canManageFoodPlan = header.Status == "APPROVED" &&
                                header.StartDateTime > DateTime.Now;
        return Ok(new { header.BookingId, header.BookingNo, header.Subject, header.RoomCode, header.RoomName, header.StartDateTime, header.EndDateTime, header.OrderCutoffDateTime, header.IsActive, canManageFoodPlan, foods, groups, questions });
    }

    [HttpPut("{bookingId:long}")]
    public async Task<IActionResult> Save(long bookingId, FoodPlanRequest request, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        var foodIds = (request.FoodIds ?? []).Where(id => id > 0).Distinct().ToList();
        var groups = (request.Groups ?? []).Where(group => !string.IsNullOrWhiteSpace(group.FoodTypeCode)).ToList();
        var questions = (request.Questions ?? []).Where(question => !string.IsNullOrWhiteSpace(question.QuestionText)).ToList();
        if ((request.Questions ?? []).Any(question => string.IsNullOrWhiteSpace(question.QuestionText) || question.QuestionText.Trim().Length > 300 || question.SortOrder < 1 || question.AnswerType is not ("TEXT" or "BOOLEAN" or "SINGLE" or "MULTIPLE" or "NUMBER")))
            return BadRequest(Error("คำถามเพิ่มเติมไม่ถูกต้อง", "กรุณาระบุคำถาม ประเภทคำตอบ และลำดับให้ถูกต้อง"));
        if (questions.Any(question => question.AnswerType is "SINGLE" or "MULTIPLE" && !(question.Options ?? []).Any(option => !string.IsNullOrWhiteSpace(option))))
            return BadRequest(Error("ตัวเลือกคำถามไม่ถูกต้อง", "คำถามแบบเลือกต้องมีตัวเลือกอย่างน้อย 1 รายการ"));
        if (groups.Any(group => group.MaxQuantity < 1 || group.MaxQuantity > 99)) return BadRequest(Error("จำนวนรวมต่อกลุ่มไม่ถูกต้อง", "จำนวนต้องอยู่ระหว่าง 1 ถึง 99"));
        if (request.IsActive && foodIds.Count == 0) return BadRequest(Error("ยังไม่ได้เลือกอาหาร", "กรุณาเลือกอย่างน้อย 1 รายการ"));
        await using var connection = await Open(token);
        var header = await BookingHeader(connection, bookingId, company, user, token);
        if (header is null) return NotFound(Error("ไม่พบรายการประชุม", $"BookingID {bookingId} ไม่อยู่ในขอบเขตของผู้ใช้งาน"));
        if (header.Status != "APPROVED" || header.StartDateTime <= DateTime.Now)
            return BadRequest(Error("กำหนดเมนูอาหารไม่ได้", "รายการประชุมต้องอนุมัติแล้วและยังไม่เริ่ม"));
        if (request.OrderCutoffDateTime <= DateTime.Now || request.OrderCutoffDateTime >= header.StartDateTime)
            return BadRequest(Error("เวลาปิดรับไม่ถูกต้อง", "เวลาปิดรับต้องมากกว่าเวลาปัจจุบันและก่อนเวลาเริ่มประชุม"));

        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            foreach (var foodId in foodIds)
            {
                await using var validate = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMeetingFood WHERE FoodID=@food AND CompanyID=@company) THEN 1 ELSE 0 END", connection, transaction);
                Add(validate, "@food", foodId); Add(validate, "@company", company);
                if (!Convert.ToBoolean(await validate.ExecuteScalarAsync(token)))
                    return BadRequest(Error("รายการอาหารไม่ถูกต้อง", $"FoodID {foodId} ไม่อยู่ในบริษัทของผู้ใช้งาน"));
            }
            const string upsert = @"
IF EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingFoodPlan WHERE BookingID=@booking AND CompanyID=@company)
 UPDATE dbo.TDADMeetingBookingFoodPlan SET OrderCutoffDateTime=@cutoff,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE BookingID=@booking AND CompanyID=@company;
ELSE
 INSERT dbo.TDADMeetingBookingFoodPlan(BookingID,CompanyID,OrderCutoffDateTime,IsActive,CreateBy) VALUES(@booking,@company,@cutoff,@active,@user);
DELETE FROM dbo.TDADMeetingBookingFoodOption WHERE BookingID=@booking AND CompanyID=@company;";
            await using var save = new SqlCommand(upsert, connection, transaction);
            Add(save, "@booking", bookingId); Add(save, "@company", company); Add(save, "@cutoff", request.OrderCutoffDateTime); Add(save, "@active", request.IsActive); Add(save, "@user", user);
            await save.ExecuteNonQueryAsync(token);
            foreach (var foodId in foodIds)
            {
                await using var option = new SqlCommand("INSERT dbo.TDADMeetingBookingFoodOption(BookingID,CompanyID,FoodID,CreateBy) VALUES(@booking,@company,@food,@user)", connection, transaction);
                Add(option, "@booking", bookingId); Add(option, "@company", company); Add(option, "@food", foodId); Add(option, "@user", user);
                await option.ExecuteNonQueryAsync(token);
            }
            await using (var clearGroups = new SqlCommand("UPDATE dbo.TDADMeetingBookingFoodGroup SET IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE BookingID=@booking AND CompanyID=@company", connection, transaction))
            {
                Add(clearGroups, "@booking", bookingId); Add(clearGroups, "@company", company); Add(clearGroups, "@user", user);
                await clearGroups.ExecuteNonQueryAsync(token);
            }
            foreach (var group in request.Groups ?? [])
            {
                await using var groupCommand = new SqlCommand("""
IF EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingFoodGroup WHERE BookingID=@booking AND CompanyID=@company AND FoodTypeCode=@type)
 UPDATE dbo.TDADMeetingBookingFoodGroup SET MaxQuantity=@max,IsRequired=@required,IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE BookingID=@booking AND CompanyID=@company AND FoodTypeCode=@type;
ELSE
 INSERT dbo.TDADMeetingBookingFoodGroup(BookingID,CompanyID,FoodTypeCode,MaxQuantity,IsRequired,IsActive,CreateBy) VALUES(@booking,@company,@type,@max,@required,1,@user);
""", connection, transaction);
                Add(groupCommand, "@booking", bookingId); Add(groupCommand, "@company", company); Add(groupCommand, "@type", group.FoodTypeCode.Trim()); Add(groupCommand, "@max", group.MaxQuantity); Add(groupCommand, "@required", group.IsRequired); Add(groupCommand, "@user", user);
                await groupCommand.ExecuteNonQueryAsync(token);
            }
            await using (var deactivateQuestions = new SqlCommand("UPDATE O SET IsActive=0 FROM dbo.TDADMeetingBookingRequirementOption O JOIN dbo.TDADMeetingBookingRequirementQuestion Q ON Q.RequirementQuestionID=O.RequirementQuestionID WHERE Q.BookingID=@booking AND Q.CompanyID=@company; UPDATE dbo.TDADMeetingBookingRequirementQuestion SET IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE BookingID=@booking AND CompanyID=@company", connection, transaction))
            {
                Add(deactivateQuestions, "@booking", bookingId); Add(deactivateQuestions, "@company", company); Add(deactivateQuestions, "@user", user);
                await deactivateQuestions.ExecuteNonQueryAsync(token);
            }
            foreach (var question in questions.OrderBy(question => question.SortOrder))
            {
                await using var insertQuestion = new SqlCommand("INSERT dbo.TDADMeetingBookingRequirementQuestion(BookingID,CompanyID,QuestionText,AnswerType,IsRequired,SortOrder,IsActive,CreateBy) VALUES(@booking,@company,@text,@type,@required,@sort,1,@user); SELECT CONVERT(bigint,SCOPE_IDENTITY());", connection, transaction);
                Add(insertQuestion, "@booking", bookingId); Add(insertQuestion, "@company", company); Add(insertQuestion, "@text", question.QuestionText.Trim()); Add(insertQuestion, "@type", question.AnswerType); Add(insertQuestion, "@required", question.IsRequired); Add(insertQuestion, "@sort", question.SortOrder); Add(insertQuestion, "@user", user);
                var questionId = Convert.ToInt64(await insertQuestion.ExecuteScalarAsync(token));
                foreach (var option in (question.Options ?? []).Select(option => option.Trim()).Where(option => option.Length > 0).Distinct().Take(50).Select((option, index) => (option, index)))
                {
                    await using var insertOption = new SqlCommand("INSERT dbo.TDADMeetingBookingRequirementOption(RequirementQuestionID,OptionText,SortOrder,IsActive,CreateBy) VALUES(@question,@text,@sort,1,@user)", connection, transaction);
                    Add(insertOption, "@question", questionId); Add(insertOption, "@text", option.option); Add(insertOption, "@sort", option.index + 1); Add(insertOption, "@user", user);
                    await insertOption.ExecuteNonQueryAsync(token);
                }
            }
            await transaction.CommitAsync(token);
            return Ok(new { bookingId, foodCount = foodIds.Count, questionCount = questions.Count });
        }
        catch
        {
            await transaction.RollbackAsync(token);
            throw;
        }
    }

    [HttpDelete("{bookingId:long}")]
    public async Task<IActionResult> Delete(long bookingId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var connection = await Open(token);
        var header = await BookingHeader(connection, bookingId, company, user, token);
        if (header is null) return Forbid();
        if (header.Status != "APPROVED" || header.StartDateTime <= DateTime.Now) return BadRequest(Error("แก้ชุดอาหารไม่ได้", "การจองต้องอนุมัติแล้วและยังไม่เริ่มประชุม"));
        await using var command = new SqlCommand("DELETE FROM dbo.TDADMeetingBookingFoodOption WHERE BookingID=@booking AND CompanyID=@company; DELETE FROM dbo.TDADMeetingBookingFoodPlan WHERE BookingID=@booking AND CompanyID=@company; SELECT @@ROWCOUNT;", connection);
        Add(command, "@booking", bookingId); Add(command, "@company", company);
        return Convert.ToInt32(await command.ExecuteScalarAsync(token)) == 0 ? NotFound() : NoContent();
    }

    private async Task<FoodPlanHeader?> BookingHeader(SqlConnection connection, long bookingId, long company, long user, CancellationToken token)
    {
        var sql = $@"
SELECT B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH,
       MIN(S.StartDateTime),MAX(S.EndDateTime),P.OrderCutoffDateTime,P.IsActive
FROM dbo.TDADMeetingRoomBooking B
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
INNER JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADMeetingBookingFoodPlan P ON P.BookingID=B.BookingID AND P.CompanyID=B.CompanyID
WHERE B.BookingID=@booking AND B.CompanyID=@company
  AND {MeetingFoodPlanAccess.OwnershipSql}
GROUP BY B.BookingID,B.BookingNo,B.Subject,B.BookingStatus,R.RoomCode,R.RoomNameTH,P.OrderCutoffDateTime,P.IsActive;";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@booking", bookingId); Add(command, "@company", company);
Add(command, "@user", user);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return null;
        return new(reader.GetInt64(0), Text(reader, 1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetString(5), reader.GetDateTime(6), reader.GetDateTime(7), Date(reader, 8), Bool(reader, 9));
    }

    private async Task<bool> PlanExists(SqlConnection connection, long bookingId, long company, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingFoodPlan WHERE BookingID=@booking AND CompanyID=@company) THEN 1 ELSE 0 END", connection);
        Add(command, "@booking", bookingId); Add(command, "@company", company);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private void Bind(SqlCommand command, long company, long user, string? search)
    { Add(command, "@company", company); Add(command, "@user", user); Add(command, "@search", string.IsNullOrWhiteSpace(search) ? null : search.Trim()); }
    private async Task<bool> Allowed(SqlConnection connection, string action, CancellationToken token)
    {
        if (!Scope(out var company, out var user) || !long.TryParse(User.FindFirstValue("project_id"), out var project)) return false;
        const string sql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action) THEN 1 ELSE 0 END";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@user", user); Add(command, "@company", company); Add(command, "@project", project); Add(command, "@screen", ScreenCode); Add(command, "@action", action);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
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
    private static bool Bool(SqlDataReader reader, int index) => !reader.IsDBNull(index) && reader.GetBoolean(index);
    private static void Add(SqlCommand command, string name, object? value) => command.Parameters.AddWithValue(name, value ?? DBNull.Value);
}


public sealed record FoodPlanRequest(DateTime OrderCutoffDateTime, List<long>? FoodIds, List<FoodGroupRequest>? Groups = null, List<FoodRequirementQuestion>? Questions = null, bool IsActive = true);
public sealed record FoodGroupRequest(string FoodTypeCode, int MaxQuantity, bool IsRequired = false, List<long>? FoodIds = null);
public sealed record FoodPlanHeader(long BookingId, string? BookingNo, string Subject, string Status, string RoomCode, string RoomName, DateTime StartDateTime, DateTime EndDateTime, DateTime? OrderCutoffDateTime, bool IsActive);

public sealed record FoodRequirementQuestion(string QuestionText, string AnswerType, bool IsRequired, int SortOrder, List<string>? Options = null);
