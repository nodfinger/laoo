using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
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
        if (!Scope(out var company, out var user)) return Forbid();
        var roleAccess = await RoleManage(connection, null, company, user, token);
        return Ok(new
        {
            view = roleAccess || await Allowed(connection, "VIEW", token),
            create = roleAccess || await Allowed(connection, "CREATE", token),
            edit = roleAccess || await Allowed(connection, "EDIT", token),
            delete = roleAccess || await Allowed(connection, "DELETE", token),
        });
    }

    [HttpGet]
    public async Task<IActionResult> List(string? search = null, int page = 1, int pageSize = 20, CancellationToken token = default)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        await using var connection = await Open(token);
        var roleAccess = await RoleManage(connection, null, company, user, token);
        if (!roleAccess && !await Allowed(connection, "VIEW", token)) return Forbid();
        var canCreate = await Allowed(connection, "CREATE", token);
        var canEdit = await Allowed(connection, "EDIT", token);
        var canDelete = await Allowed(connection, "DELETE", token);
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
            canManageFoodPlan = MeetingFoodPlanAccess.CanManage("APPROVED", reader.GetDateTime(6), true, roleAccess || (reader.IsDBNull(7) ? canCreate : canEdit)),
            canDeleteFoodPlan = !reader.IsDBNull(7) && MeetingFoodPlanAccess.CanManage("APPROVED", reader.GetDateTime(6), true, roleAccess || canDelete),
        });
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("{bookingId:long}")]
    public async Task<IActionResult> Get(long bookingId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var connection = await Open(token);
        var roleAccess = await RoleManage(connection, bookingId, company, user, token);
        if (!roleAccess && !await Allowed(connection, "VIEW", token)) return Forbid();
        var header = await BookingHeader(connection, bookingId, company, user, token);
        if (header is null) return Forbid();
        var exists = await PlanExists(connection, bookingId, company, token);
        var canManageFoodPlan = MeetingFoodPlanAccess.CanManage(header.Status, header.EndDateTime, true,
            roleAccess || await Allowed(connection, exists ? "EDIT" : "CREATE", token));
        const string sql = @"
SELECT F.FoodID,F.FoodCode,F.FoodNameTH,F.FoodTypeCode,T.Name,F.FoodImageUrl,
       CASE WHEN O.BookingFoodOptionID IS NULL THEN 0 ELSE 1 END,ISNULL(O.Quantity,1)
FROM dbo.TDADMeetingFood F
OUTER APPLY
(
    SELECT TOP (1) M.Name,M.Seq
    FROM dbo.TDSTMaster M
    WHERE M.MasterGroupCode='011'
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
        await using var reader = await command.ExecuteReaderAsync(token);
        var foods = new List<object>();
        while (await reader.ReadAsync(token)) foods.Add(new
        {
            foodId = reader.GetInt64(0), code = reader.GetString(1), nameTh = reader.GetString(2),
            foodTypeCode = reader.GetString(3), foodTypeName = Text(reader, 4), imageUrl = Text(reader, 5),
            selected = reader.GetInt32(6) == 1,
            quantity = reader.GetInt32(7),
        });
        await reader.CloseAsync();
        var groups = new List<object>();
        await using (var group = new SqlCommand("""
SELECT G.FoodTypeCode,ISNULL(M.Name,G.FoodTypeCode),G.MaxQuantity,G.IsRequired,G.IsActive
FROM dbo.TDADMeetingBookingFoodGroup G
OUTER APPLY(SELECT TOP(1) X.Name FROM dbo.TDSTMaster X WHERE X.MasterGroupCode='011'
 AND X.MasterCode=G.FoodTypeCode AND X.OwnerType='C' AND X.OwnerCompanyID=@company AND X.IsActive=1) M
WHERE G.BookingID=@booking AND G.CompanyID=@company ORDER BY G.BookingFoodGroupID;
""", connection))
        {
            Add(group, "@booking", bookingId); Add(group, "@company", company);
            await using var groupReader = await group.ExecuteReaderAsync(token);
            while (await groupReader.ReadAsync(token)) groups.Add(new
            {
                foodTypeCode = groupReader.GetString(0), foodTypeName = groupReader.GetString(1),
                maxQuantity = groupReader.GetInt32(2), isRequired = groupReader.GetBoolean(3),
                isActive = groupReader.GetBoolean(4),
            });
        }
        var questionRows = new List<FoodPlanQuestionRow>();
        await using (var question = new SqlCommand("""
SELECT Q.RequirementQuestionID,Q.QuestionText,Q.AnswerType,Q.IsRequired,Q.SortOrder,
 O.RequirementOptionID,O.OptionText,O.SortOrder
FROM dbo.TDADMeetingBookingRequirementQuestion Q
LEFT JOIN dbo.TDADMeetingBookingRequirementOption O ON O.RequirementQuestionID=Q.RequirementQuestionID AND O.IsActive=1
WHERE Q.BookingID=@booking AND Q.CompanyID=@company AND Q.IsActive=1
ORDER BY Q.SortOrder,Q.RequirementQuestionID,O.SortOrder,O.RequirementOptionID;
""", connection))
        {
            Add(question, "@booking", bookingId); Add(question, "@company", company);
            await using var questionReader = await question.ExecuteReaderAsync(token);
            while (await questionReader.ReadAsync(token)) questionRows.Add(new(
                questionReader.GetInt64(0), questionReader.GetString(1), questionReader.GetString(2),
                questionReader.GetBoolean(3), questionReader.GetInt32(4),
                questionReader.IsDBNull(5) ? null : questionReader.GetInt64(5),
                Text(questionReader, 6), questionReader.IsDBNull(7) ? null : questionReader.GetInt32(7)));
        }
        var questions = questionRows.GroupBy(x => new { x.Id, x.Text, x.Type, x.Required, x.Sort })
            .Select(g => new
            {
                questionId = g.Key.Id, questionText = g.Key.Text, answerType = g.Key.Type,
                isRequired = g.Key.Required, sortOrder = g.Key.Sort,
                options = g.Where(x => x.OptionId is not null)
                    .Select(x => new { optionId = x.OptionId, optionText = x.OptionText, sortOrder = x.OptionSort }),
            }).ToList();
        return Ok(new { header.BookingId, header.BookingNo, header.Subject, header.RoomCode, header.RoomName, header.StartDateTime, header.EndDateTime, header.OrderCutoffDateTime, header.IsActive, canManageFoodPlan, foods, groups, questions });
    }

    [HttpPut("{bookingId:long}")]
    public async Task<IActionResult> Save(long bookingId, FoodPlanRequest request, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        if (request.Groups is null)
            return BadRequest(Error("ต้องกำหนดอาหารเป็นกลุ่ม", "กรุณาโหลดหน้ากำหนดเมนูใหม่ แล้วกำหนดจำนวนรวมและรายการของแต่ละกลุ่ม"));
        var groups = request.Groups;
        var foodIds = groups.SelectMany(x => x.FoodIds ?? []).Where(id => id > 0).Distinct().ToList();
        if (groups.GroupBy(x => x.FoodTypeCode?.Trim(), StringComparer.OrdinalIgnoreCase).Any(x => string.IsNullOrWhiteSpace(x.Key) || x.Key!.Length > 50 || x.Count() > 1)
            || groups.Any(x => x.MaxQuantity is < 1 or > 99 || (x.FoodIds?.Count ?? 0) == 0)
            || groups.SelectMany(x => x.FoodIds ?? []).GroupBy(x => x).Any(x => x.Count() > 1))
            return BadRequest(Error("กติกากลุ่มอาหารไม่ถูกต้อง", "แต่ละกลุ่มต้องไม่ซ้ำ มีรายการอาหาร และกำหนดจำนวนระหว่าง 1 ถึง 99"));
        var questions = request.Questions ?? [];
        if (questions.Any(x => string.IsNullOrWhiteSpace(x.QuestionText) || x.QuestionText.Trim().Length > 300 || x.SortOrder < 1
            || x.AnswerType is not ("TEXT" or "BOOLEAN" or "SINGLE" or "MULTIPLE" or "NUMBER")
            || (x.Options ?? []).Any(option => string.IsNullOrWhiteSpace(option) || option!.Trim().Length > 200)
            || (x.AnswerType is "SINGLE" or "MULTIPLE" && (x.Options ?? []).Select(option => option!.Trim()).Distinct().Count() < 2)))
            return BadRequest(Error("คำถามความต้องการไม่ถูกต้อง", "กรุณาระบุคำถาม ประเภทคำตอบ และอย่างน้อย 2 ตัวเลือกสำหรับคำถามแบบเลือก"));
        if (request.FoodQuantities is not null &&
            (request.FoodQuantities.Any(entry => entry.Value <= 0 || !foodIds.Contains(entry.Key)) ||
             foodIds.Any(id => !request.FoodQuantities.ContainsKey(id))))
            return BadRequest(Error("จำนวนอาหารไม่ถูกต้อง", "กรุณาระบุจำนวนเต็มมากกว่า 0 ให้ครบทุกอาหารที่เลือก"));
        if (request.IsActive && foodIds.Count == 0) return BadRequest(Error("ยังไม่ได้เลือกอาหาร", "กรุณาเลือกอย่างน้อย 1 รายการ"));
        await using var connection = await Open(token);
        var exists = await PlanExists(connection, bookingId, company, token);
        var roleAccess = await RoleManage(connection, bookingId, company, user, token);
        if (!roleAccess && (!await Allowed(connection, "VIEW", token) || !await Allowed(connection, exists ? "EDIT" : "CREATE", token))) return Forbid();
        var header = await BookingHeader(connection, bookingId, company, user, token);
        if (header is null) return Forbid();
        if (!MeetingFoodPlanAccess.CanManage(header.Status, header.EndDateTime, true, true))
            return BadRequest(Error("กำหนดเมนูอาหารไม่ได้", "รายการประชุมต้องอนุมัติแล้วและยังไม่สิ้นสุด"));
        if (request.OrderCutoffDateTime <= DateTime.Now || request.OrderCutoffDateTime >= header.StartDateTime)
            return BadRequest(Error("เวลาปิดรับไม่ถูกต้อง", "เวลาปิดรับต้องมากกว่าเวลาปัจจุบันและก่อนเวลาเริ่มประชุม"));

        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            // Recheck the booking inside the write transaction so a concurrent
            // cancellation or room reassignment cannot leave a stale permission.
            header = await BookingHeader(connection, bookingId, company, user, token, transaction);
            if (header is null) return Forbid();
            if (!MeetingFoodPlanAccess.CanManage(header.Status, header.EndDateTime, true, true))
                return BadRequest(Error("กำหนดเมนูอาหารไม่ได้", "รายการประชุมต้องอนุมัติแล้วและยังไม่สิ้นสุด"));
            if (request.OrderCutoffDateTime <= DateTime.Now || request.OrderCutoffDateTime >= header.StartDateTime)
                return BadRequest(Error("เวลาปิดรับไม่ถูกต้อง", "เวลาปิดรับต้องมากกว่าเวลาปัจจุบันและก่อนเวลาเริ่มประชุม"));
            if (exists != await PlanExists(connection, bookingId, company, token, transaction))
                return Conflict(Error("ชุดอาหารถูกเปลี่ยนแปลงแล้ว", "กรุณาเปิดรายการใหม่ก่อนบันทึก"));
            if (request.Groups is not null)
            {
                await using var responses = new SqlCommand("""
SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingFoodOrder WHERE CompanyID=@company AND BookingID=@booking)
 OR EXISTS(SELECT 1 FROM dbo.TDADMeetingParticipantRequirementAnswer A
  JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.BookingParticipantID=A.BookingParticipantID AND P.CompanyID=A.CompanyID
  WHERE A.CompanyID=@company AND P.BookingID=@booking) THEN 1 ELSE 0 END;
""", connection, transaction);
                Add(responses, "@company", company); Add(responses, "@booking", bookingId);
                if (Convert.ToBoolean(await responses.ExecuteScalarAsync(token)))
                    return Conflict(Error("แก้ชุดคำตอบไม่ได้", "มีผู้เข้าร่วมส่งคำตอบแล้ว จึงล็อกรายการอาหารและคำถามเพื่อรักษายอดสรุป"));
            }
            var groupByFood = groups.SelectMany(group => (group.FoodIds ?? [])
                .Select(foodId => new { FoodId = foodId, Group = group })).ToDictionary(x => x.FoodId, x => x.Group);
            foreach (var foodId in foodIds)
            {
                await using var validate = new SqlCommand("SELECT FoodTypeCode FROM dbo.TDADMeetingFood WHERE FoodID=@food AND CompanyID=@company", connection, transaction);
                Add(validate, "@food", foodId); Add(validate, "@company", company);
                var foodType = Convert.ToString(await validate.ExecuteScalarAsync(token));
                if (string.IsNullOrWhiteSpace(foodType))
                    return BadRequest(Error("รายการอาหารไม่ถูกต้อง", $"FoodID {foodId} ไม่อยู่ในบริษัทของผู้ใช้งาน"));
                if (groups.Count > 0 && (!groupByFood.TryGetValue(foodId, out var requestedGroup)
                    || !string.Equals(foodType, requestedGroup.FoodTypeCode?.Trim(), StringComparison.OrdinalIgnoreCase)))
                    return BadRequest(Error("กลุ่มอาหารไม่ตรงกับรายการ", $"FoodID {foodId} ไม่ได้อยู่ในประเภทอาหารที่กำหนด"));
            }
            const string upsert = @"
IF EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingFoodPlan WHERE BookingID=@booking AND CompanyID=@company)
 UPDATE dbo.TDADMeetingBookingFoodPlan SET OrderCutoffDateTime=@cutoff,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE BookingID=@booking AND CompanyID=@company;
ELSE
 INSERT dbo.TDADMeetingBookingFoodPlan(BookingID,CompanyID,OrderCutoffDateTime,IsActive,CreateBy) VALUES(@booking,@company,@cutoff,@active,@user);
DELETE FROM dbo.TDADMeetingBookingFoodOption WHERE BookingID=@booking AND CompanyID=@company;
DELETE FROM dbo.TDADMeetingBookingFoodGroup WHERE BookingID=@booking AND CompanyID=@company;
DELETE O FROM dbo.TDADMeetingBookingRequirementOption O
 JOIN dbo.TDADMeetingBookingRequirementQuestion Q ON Q.RequirementQuestionID=O.RequirementQuestionID
 WHERE Q.BookingID=@booking AND Q.CompanyID=@company;
DELETE FROM dbo.TDADMeetingBookingRequirementQuestion WHERE BookingID=@booking AND CompanyID=@company;";
            await using var save = new SqlCommand(upsert, connection, transaction);
            Add(save, "@booking", bookingId); Add(save, "@company", company); Add(save, "@cutoff", request.OrderCutoffDateTime); Add(save, "@active", request.IsActive); Add(save, "@user", user);
            await save.ExecuteNonQueryAsync(token);
            foreach (var group in groups)
            {
                await using (var saveGroup = new SqlCommand("INSERT dbo.TDADMeetingBookingFoodGroup(BookingID,CompanyID,FoodTypeCode,MaxQuantity,IsRequired,IsActive,CreateBy) VALUES(@booking,@company,@type,@max,@required,1,@user)", connection, transaction))
                {
                    Add(saveGroup, "@booking", bookingId); Add(saveGroup, "@company", company); Add(saveGroup, "@type", group.FoodTypeCode!.Trim());
                    Add(saveGroup, "@max", group.MaxQuantity); Add(saveGroup, "@required", group.IsRequired); Add(saveGroup, "@user", user);
                    await saveGroup.ExecuteNonQueryAsync(token);
                }
                foreach (var foodId in group.FoodIds!.Distinct())
                {
                    await using var option = new SqlCommand("INSERT dbo.TDADMeetingBookingFoodOption(BookingID,CompanyID,FoodID,CreateBy,Quantity) VALUES(@booking,@company,@food,@user,@quantity)", connection, transaction);
                    Add(option, "@booking", bookingId); Add(option, "@company", company); Add(option, "@food", foodId);
                    Add(option, "@user", user); Add(option, "@quantity", group.MaxQuantity); await option.ExecuteNonQueryAsync(token);
                }
            }
            foreach (var question in questions.OrderBy(x => x.SortOrder))
            {
                await using var insertQuestion = new SqlCommand("""
INSERT dbo.TDADMeetingBookingRequirementQuestion(BookingID,CompanyID,QuestionText,AnswerType,IsRequired,SortOrder,IsActive,CreateBy)
VALUES(@booking,@company,@text,@type,@required,@sort,1,@user);SELECT CONVERT(bigint,SCOPE_IDENTITY());
""", connection, transaction);
                Add(insertQuestion, "@booking", bookingId); Add(insertQuestion, "@company", company); Add(insertQuestion, "@text", question.QuestionText!.Trim());
                Add(insertQuestion, "@type", question.AnswerType); Add(insertQuestion, "@required", question.IsRequired);
                Add(insertQuestion, "@sort", question.SortOrder); Add(insertQuestion, "@user", user);
                var questionId = Convert.ToInt64(await insertQuestion.ExecuteScalarAsync(token));
                var optionSort = 1;
                foreach (var optionText in (question.Options ?? []).Select(x => x?.Trim()).Where(x => !string.IsNullOrWhiteSpace(x)).Distinct())
                {
                    await using var insertOption = new SqlCommand("INSERT dbo.TDADMeetingBookingRequirementOption(RequirementQuestionID,OptionText,SortOrder,CreateBy) VALUES(@question,@text,@sort,@user)", connection, transaction);
                    Add(insertOption, "@question", questionId); Add(insertOption, "@text", optionText); Add(insertOption, "@sort", optionSort++); Add(insertOption, "@user", user);
                    await insertOption.ExecuteNonQueryAsync(token);
                }
            }
            await transaction.CommitAsync(token);
            return Ok(new { bookingId, foodCount = foodIds.Count });
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
        var roleAccess = await RoleManage(connection, bookingId, company, user, token);
        if (!roleAccess && (!await Allowed(connection, "VIEW", token) || !await Allowed(connection, "DELETE", token))) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        var header = await BookingHeader(connection, bookingId, company, user, token, transaction);
        if (header is null) return Forbid();
        if (!MeetingFoodPlanAccess.CanManage(header.Status, header.EndDateTime, true, true))
            return BadRequest(Error("ลบเมนูอาหารไม่ได้", "รายการประชุมต้องอนุมัติแล้วและยังไม่สิ้นสุด"));
        await using (var responses = new SqlCommand("""
SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingFoodOrder WHERE CompanyID=@company AND BookingID=@booking)
 OR EXISTS(SELECT 1 FROM dbo.TDADMeetingParticipantRequirementAnswer A
 JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.BookingParticipantID=A.BookingParticipantID AND P.CompanyID=A.CompanyID
 WHERE A.CompanyID=@company AND P.BookingID=@booking) THEN 1 ELSE 0 END;
""", connection, transaction))
        {
            Add(responses, "@company", company); Add(responses, "@booking", bookingId);
            if (Convert.ToBoolean(await responses.ExecuteScalarAsync(token)))
                return Conflict(Error("ลบชุดคำตอบไม่ได้", "มีผู้เข้าร่วมส่งคำตอบแล้ว ให้ปิดการใช้งานแทนเพื่อเก็บประวัติ"));
        }
        await using var command = new SqlCommand("""
DELETE FROM dbo.TDADMeetingBookingFoodOption WHERE BookingID=@booking AND CompanyID=@company;
DELETE FROM dbo.TDADMeetingBookingFoodGroup WHERE BookingID=@booking AND CompanyID=@company;
DELETE O FROM dbo.TDADMeetingBookingRequirementOption O
 JOIN dbo.TDADMeetingBookingRequirementQuestion Q ON Q.RequirementQuestionID=O.RequirementQuestionID
 WHERE Q.BookingID=@booking AND Q.CompanyID=@company;
DELETE FROM dbo.TDADMeetingBookingRequirementQuestion WHERE BookingID=@booking AND CompanyID=@company;
DELETE FROM dbo.TDADMeetingBookingFoodPlan WHERE BookingID=@booking AND CompanyID=@company;
SELECT @@ROWCOUNT;
""", connection, transaction);
        Add(command, "@booking", bookingId); Add(command, "@company", company);
        var affected = Convert.ToInt32(await command.ExecuteScalarAsync(token));
        await transaction.CommitAsync(token);
        return affected == 0 ? NotFound() : NoContent();
    }

    private async Task<FoodPlanHeader?> BookingHeader(SqlConnection connection, long bookingId, long company, long user, CancellationToken token, SqlTransaction? transaction = null)
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
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@booking", bookingId); Add(command, "@company", company); Add(command, "@user", user);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return null;
        return new(reader.GetInt64(0), Text(reader, 1), reader.GetString(2), reader.GetString(3), reader.GetString(4), reader.GetString(5), reader.GetDateTime(6), reader.GetDateTime(7), Date(reader, 8), Bool(reader, 9));
    }

    private async Task<bool> PlanExists(SqlConnection connection, long bookingId, long company, CancellationToken token, SqlTransaction? transaction = null)
    {
        await using var command = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMeetingBookingFoodPlan WHERE BookingID=@booking AND CompanyID=@company) THEN 1 ELSE 0 END", connection, transaction);
        Add(command, "@booking", bookingId); Add(command, "@company", company);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private static async Task<bool> RoleManage(SqlConnection connection, long? bookingId, long company, long user, CancellationToken token)
    {
        var sql = $"""
SELECT CASE WHEN EXISTS
(
 SELECT 1 FROM dbo.TDADMeetingRoomBooking B
 WHERE B.CompanyID=@company AND (@booking IS NULL OR B.BookingID=@booking)
   AND {MeetingFoodPlanAccess.OwnershipSql}
) THEN 1 ELSE 0 END;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@booking", bookingId); Add(command, "@company", company); Add(command, "@user", user);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private void Bind(SqlCommand command, long company, long user, string? search)
    { Add(command, "@company", company); Add(command, "@user", user); Add(command, "@search", string.IsNullOrWhiteSpace(search) ? null : search.Trim()); }
    private Task<bool> Allowed(SqlConnection connection, string action, CancellationToken token) =>
        MeetingFoodPlanAccess.Allowed(connection, User, action, token);
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

public sealed record FoodPlanRequest(DateTime OrderCutoffDateTime, List<long>? FoodIds, bool IsActive = true,
    Dictionary<long, int>? FoodQuantities = null, List<FoodGroupRequest>? Groups = null,
    List<RequirementQuestionRequest>? Questions = null);
public sealed record FoodGroupRequest(string? FoodTypeCode, int MaxQuantity, bool IsRequired, List<long>? FoodIds);
public sealed record RequirementQuestionRequest(string? QuestionText, string AnswerType, bool IsRequired, int SortOrder, List<string?>? Options);
public sealed record FoodPlanHeader(long BookingId, string? BookingNo, string Subject, string Status, string RoomCode, string RoomName, DateTime StartDateTime, DateTime EndDateTime, DateTime? OrderCutoffDateTime, bool IsActive);
internal sealed record FoodPlanQuestionRow(long Id, string Text, string Type, bool Required, int Sort, long? OptionId, string? OptionText, int? OptionSort);
