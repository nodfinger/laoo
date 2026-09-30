using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooSurveyModule.Controllers;

public sealed partial class SurveyController
{
    [HttpGet("mine")]
    public async Task<IActionResult> Mine(CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "40007", "VIEW", token)) return Forbid();
        await using var q = new SqlCommand("""
SELECT s.SurveyID id,s.SurveyCode code,s.SurveyName name,s.DescriptionText description,s.OpenAt,s.CloseAt,
 s.IsAnonymous anonymous,a.RespondedAt,CASE WHEN a.RespondedAt IS NULL THEN N'WAITING' ELSE N'COMPLETED' END status
FROM dbo.TDSVSurveyAssignment a JOIN dbo.TDSVSurvey s ON s.SurveyID=a.SurveyID
JOIN dbo.TDADUserEmployee ue ON ue.CompanyID=a.CompanyID AND ue.EmployeeID=a.EmployeeID AND ue.UserID=@user AND ue.IsActive=1
WHERE a.CompanyID=@co AND a.IsActive=1 AND s.StatusCode=N'PUBLISHED' AND SYSUTCDATETIME() BETWEEN s.OpenAt AND s.CloseAt
ORDER BY a.RespondedAt,s.CloseAt
""", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@user", SqlDbType.BigInt, user);
        return Ok(await ReadRows(q, token));
    }

    [HttpGet("mine/{id:long}")]
    public async Task<IActionResult> MineDetail(long id, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "40007", "VIEW", token)) return Forbid();
        const string sql = """
SELECT s.SurveyID id,s.SurveyCode code,s.SurveyName name,s.DescriptionText description,s.OpenAt,s.CloseAt,
 s.IsAnonymous anonymous,a.AssignmentID,a.RespondedAt
FROM dbo.TDSVSurveyAssignment a JOIN dbo.TDSVSurvey s ON s.SurveyID=a.SurveyID
JOIN dbo.TDADUserEmployee ue ON ue.CompanyID=a.CompanyID AND ue.EmployeeID=a.EmployeeID AND ue.UserID=@user AND ue.IsActive=1
WHERE a.CompanyID=@co AND a.SurveyID=@id AND a.IsActive=1 AND s.StatusCode=N'PUBLISHED'
 AND SYSUTCDATETIME() BETWEEN s.OpenAt AND s.CloseAt;
SELECT q.QuestionID id,q.QuestionNo number,q.QuestionText text,q.QuestionType type,q.IsRequired required,q.MinValue,q.MaxValue
FROM dbo.TDSVSurveyQuestion q WHERE q.CompanyID=@co AND q.SurveyID=@id AND q.IsActive=1 ORDER BY q.QuestionNo;
SELECT o.OptionID id,o.QuestionID questionID,o.OptionNo number,o.OptionText text
FROM dbo.TDSVSurveyQuestionOption o JOIN dbo.TDSVSurveyQuestion q ON q.QuestionID=o.QuestionID
WHERE q.CompanyID=@co AND q.SurveyID=@id AND o.IsActive=1 ORDER BY o.QuestionID,o.OptionNo;
""";
        await using var q = new SqlCommand(sql, c); P(q, "@co", SqlDbType.BigInt, company); P(q, "@user", SqlDbType.BigInt, user); P(q, "@id", SqlDbType.BigInt, id);
        var data = await Multi(q, token, ["header", "questions", "options"]);
        if (((List<Dictionary<string, object?>>)data["header"]).Count == 0) return Forbid();
        return Ok(data);
    }

    [HttpPost("mine/{id:long}/responses")]
    public async Task<IActionResult> Respond(long id, SurveyResponseInput input, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "40007", "VIEW", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        var assignmentValue = await Scalar(c, tx, """
SELECT a.AssignmentID FROM dbo.TDSVSurveyAssignment a JOIN dbo.TDSVSurvey s ON s.SurveyID=a.SurveyID
JOIN dbo.TDADUserEmployee ue ON ue.CompanyID=a.CompanyID AND ue.EmployeeID=a.EmployeeID AND ue.UserID=@user AND ue.IsActive=1
WHERE a.CompanyID=@co AND a.SurveyID=@id AND a.IsActive=1 AND a.RespondedAt IS NULL
 AND s.StatusCode=N'PUBLISHED' AND SYSUTCDATETIME() BETWEEN s.OpenAt AND s.CloseAt
""", token, ("@co", company), ("@id", id), ("@user", user));
        var assignment = assignmentValue is null ? 0 : Convert.ToInt64(assignmentValue);
        if (assignment == 0) { await tx.RollbackAsync(token); return Conflict(new { message = "ส่งคำตอบไม่ได้", description = "ไม่มีสิทธิ์ แบบสอบถามปิดแล้ว หรือเคยส่งคำตอบแล้ว" }); }
        var questions = await Query(c, tx, "SELECT QuestionID,QuestionType,IsRequired,MinValue,MaxValue FROM dbo.TDSVSurveyQuestion WHERE CompanyID=@co AND SurveyID=@id AND IsActive=1", token, ("@co", company), ("@id", id));
        foreach (var question in questions)
        {
            var questionId = Convert.ToInt64(question["QuestionID"]);
            var answer = input.Answers.FirstOrDefault(a => a.QuestionID == questionId);
            if (Convert.ToBoolean(question["IsRequired"]) && (answer is null || !answer.OptionIDs.Any() && string.IsNullOrWhiteSpace(answer.TextValue) && answer.NumberValue is null))
            { await tx.RollbackAsync(token); return Bad("กรุณาตอบคำถามให้ครบ", $"คำถามรหัส {questionId} เป็นคำถามบังคับ"); }
        }
        var response = Convert.ToInt64(await Scalar(c, tx, "INSERT dbo.TDSVSurveyResponse(CompanyID,SurveyID,AssignmentID,SubmittedAt,CreateBy) OUTPUT INSERTED.ResponseID VALUES(@co,@id,@assignment,SYSUTCDATETIME(),@user)", token,
            ("@co", company), ("@id", id), ("@assignment", assignment), ("@user", user)));
        foreach (var answer in input.Answers)
        {
            var question = questions.FirstOrDefault(q => Convert.ToInt64(q["QuestionID"]) == answer.QuestionID);
            if (question is null) { await tx.RollbackAsync(token); return Bad("คำตอบไม่ถูกต้อง", "พบคำตอบที่ไม่ใช่คำถามของแบบสอบถามนี้"); }
            var type = Convert.ToString(question["QuestionType"]);
            if (type == "SCALE" && (answer.NumberValue is null || answer.NumberValue < Convert.ToDecimal(question["MinValue"]) || answer.NumberValue > Convert.ToDecimal(question["MaxValue"])))
            { await tx.RollbackAsync(token); return Bad("คะแนนไม่ถูกต้อง", "คะแนนต้องอยู่ในช่วงที่คำถามกำหนด"); }
            if (type == "SINGLE" && answer.OptionIDs.Distinct().Count() != 1)
            { await tx.RollbackAsync(token); return Bad("คำตอบไม่ถูกต้อง", "คำถามแบบเลือกข้อเดียวต้องเลือก 1 ตัวเลือก"); }
            var answerId = Convert.ToInt64(await Scalar(c, tx, "INSERT dbo.TDSVSurveyAnswer(CompanyID,ResponseID,QuestionID,TextValue,NumberValue) OUTPUT INSERTED.AnswerID VALUES(@co,@response,@question,@text,@number)", token,
                ("@co", company), ("@response", response), ("@question", answer.QuestionID), ("@text", Clean(answer.TextValue)), ("@number", answer.NumberValue)));
            foreach (var option in answer.OptionIDs.Distinct())
            {
                var valid = Convert.ToInt32(await Scalar(c, tx, "SELECT COUNT(*) FROM dbo.TDSVSurveyQuestionOption WHERE CompanyID=@co AND QuestionID=@question AND OptionID=@option AND IsActive=1", token,
                    ("@co", company), ("@question", answer.QuestionID), ("@option", option)));
                if (valid == 0) { await tx.RollbackAsync(token); return Bad("ตัวเลือกไม่ถูกต้อง", "ตัวเลือกต้องเป็นของคำถามเดียวกัน"); }
                await Execute(c, tx, "INSERT dbo.TDSVSurveyAnswerOption(CompanyID,AnswerID,OptionID) VALUES(@co,@answer,@option)", token,
                    ("@co", company), ("@answer", answerId), ("@option", option));
            }
        }
        await Execute(c, tx, "UPDATE dbo.TDSVSurveyAssignment SET RespondedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND AssignmentID=@assignment", token, ("@co", company), ("@assignment", assignment));
        await tx.CommitAsync(token); return Ok(new { id = response });
    }

    [HttpGet("results")]
    public Task<IActionResult> Results(CancellationToken token) => Read("40005", """
SELECT s.SurveyID id,s.SurveyCode code,s.SurveyName name,s.StatusCode status,s.OpenAt,s.CloseAt,
 COUNT(a.AssignmentID) audienceCount,SUM(CASE WHEN a.RespondedAt IS NOT NULL THEN 1 ELSE 0 END) respondedCount
FROM dbo.TDSVSurvey s LEFT JOIN dbo.TDSVSurveyAssignment a ON a.SurveyID=s.SurveyID AND a.IsActive=1
WHERE s.CompanyID=@co AND s.StatusCode=N'CLOSED'
GROUP BY s.SurveyID,s.SurveyCode,s.SurveyName,s.StatusCode,s.OpenAt,s.CloseAt ORDER BY s.CloseAt DESC
""", token);

    [HttpGet("results/{id:long}")]
    public async Task<IActionResult> ResultDetail(long id, CancellationToken token)
    {
        if (!Scope(out var company, out _)) return Forbid(); await using var c = await Open(token);
        if (!await Can(c, "40005", "VIEW", token)) return Forbid();
        const string sql = """
SELECT s.SurveyID id,s.SurveyCode code,s.SurveyName name,s.IsAnonymous anonymous,s.StatusCode status,s.OpenAt,s.CloseAt,
 COUNT(a.AssignmentID) audienceCount,SUM(CASE WHEN a.RespondedAt IS NOT NULL THEN 1 ELSE 0 END) respondedCount
FROM dbo.TDSVSurvey s LEFT JOIN dbo.TDSVSurveyAssignment a ON a.SurveyID=s.SurveyID AND a.IsActive=1
WHERE s.CompanyID=@co AND s.SurveyID=@id AND s.StatusCode=N'CLOSED'
GROUP BY s.SurveyID,s.SurveyCode,s.SurveyName,s.IsAnonymous,s.StatusCode,s.OpenAt,s.CloseAt;
SELECT q.QuestionID id,q.QuestionNo number,q.QuestionText text,q.QuestionType type,COUNT(DISTINCT a.AnswerID) answerCount,AVG(a.NumberValue) average
FROM dbo.TDSVSurveyQuestion q LEFT JOIN dbo.TDSVSurveyAnswer a ON a.QuestionID=q.QuestionID
WHERE q.CompanyID=@co AND q.SurveyID=@id AND q.IsActive=1 GROUP BY q.QuestionID,q.QuestionNo,q.QuestionText,q.QuestionType ORDER BY q.QuestionNo;
SELECT o.QuestionID,o.OptionID id,o.OptionText text,COUNT(ao.AnswerOptionID) answerCount
FROM dbo.TDSVSurveyQuestionOption o JOIN dbo.TDSVSurveyQuestion q ON q.QuestionID=o.QuestionID
LEFT JOIN dbo.TDSVSurveyAnswerOption ao ON ao.OptionID=o.OptionID
WHERE q.CompanyID=@co AND q.SurveyID=@id AND o.IsActive=1 GROUP BY o.QuestionID,o.OptionID,o.OptionText,o.OptionNo ORDER BY o.QuestionID,o.OptionNo;
""";
        await using var q = new SqlCommand(sql, c); P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id);
        var data = await Multi(q, token, ["summary", "questions", "options"]);
        if (((List<Dictionary<string, object?>>)data["summary"]).Count == 0) return NotFound(); return Ok(data);
    }

    [HttpGet("reports")]
    public async Task<IActionResult> Reports(CancellationToken token)
    {
        if (!Scope(out var company, out _)) return Forbid(); await using var c = await Open(token);
        if (!await Can(c, "40006", "VIEW", token)) return Forbid();
        const string sql = """
SELECT COUNT(*) totalCount,SUM(CASE WHEN StatusCode=N'DRAFT' THEN 1 ELSE 0 END) draftCount,
 SUM(CASE WHEN StatusCode=N'PENDING_APPROVAL' THEN 1 ELSE 0 END) pendingCount,
 SUM(CASE WHEN StatusCode=N'PUBLISHED' THEN 1 ELSE 0 END) publishedCount,SUM(CASE WHEN StatusCode=N'CLOSED' THEN 1 ELSE 0 END) closedCount,
 (SELECT COUNT(*) FROM dbo.TDSVSurveyAssignment WHERE CompanyID=@co AND IsActive=1) audienceCount,
 (SELECT COUNT(*) FROM dbo.TDSVSurveyAssignment WHERE CompanyID=@co AND RespondedAt IS NOT NULL AND IsActive=1) respondedCount
FROM dbo.TDSVSurvey WHERE CompanyID=@co AND IsActive=1;
SELECT TOP(100) s.SurveyID id,s.SurveyCode code,s.SurveyName name,s.StatusCode status,s.OpenAt,s.CloseAt,
 COUNT(a.AssignmentID) audienceCount,SUM(CASE WHEN a.RespondedAt IS NOT NULL THEN 1 ELSE 0 END) respondedCount
FROM dbo.TDSVSurvey s LEFT JOIN dbo.TDSVSurveyAssignment a ON a.SurveyID=s.SurveyID AND a.IsActive=1
WHERE s.CompanyID=@co AND s.IsActive=1 GROUP BY s.SurveyID,s.SurveyCode,s.SurveyName,s.StatusCode,s.OpenAt,s.CloseAt,s.CreateDate
ORDER BY s.CreateDate DESC;
""";
        await using var q = new SqlCommand(sql, c); P(q, "@co", SqlDbType.BigInt, company);
        return Ok(await Multi(q, token, ["summary", "surveys"]));
    }
}
