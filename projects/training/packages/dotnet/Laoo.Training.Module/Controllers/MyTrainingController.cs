using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTrainingModule.Controllers;

[ApiController, Authorize]
[Route("api/company/my-training")]
public sealed class MyTrainingController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] int page = 1, [FromQuery] int pageSize = 30,
        [FromQuery] string? course = null, [FromQuery] string? resultStatus = null,
        CancellationToken token = default)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        await using var db = await Open(token);
        var employee = await Employee(db, company, user, token);
        if (employee is null) return Ok(new { total = 0, page, pageSize, items = Array.Empty<object>() });
        if (employee is not null)
            return await ListMulti(db, company, employee.Value, page, pageSize, course, resultStatus, token);

        var filterSql = "";
        var filterArgs = new List<(string, object?)>();
        if (!string.IsNullOrWhiteSpace(course)) {
            filterSql += " AND B.Subject LIKE @course";
            filterArgs.Add(("@course", $"%{course.Trim()}%"));
        }
        if (string.Equals(resultStatus, "PASSED", StringComparison.OrdinalIgnoreCase)) {
            filterSql += " AND (APre.Passed=1 OR EPostA.Passed=1)";
        } else if (string.Equals(resultStatus, "FAILED", StringComparison.OrdinalIgnoreCase)) {
            filterSql += " AND (APre.Passed=0 OR EPostA.Passed=0)";
        }
        var source = """
FROM dbo.TDADMeetingRoomBookingParticipant P
JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID AND B.ActivityTypeCode=N'TRAINING'
JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
JOIN dbo.TDADEmployee E ON E.EmployeeID=P.EmployeeID AND E.CompanyID=P.CompanyID
LEFT JOIN dbo.TDADOrganizationUnit DEP ON DEP.OrgUnitID=E.DepartmentOrgUnitID AND DEP.CompanyID=E.CompanyID AND DEP.UnitType=N'DEP'
LEFT JOIN dbo.TDADOrganizationUnit DV ON DV.OrgUnitID=E.DivisionOrgUnitID AND DV.CompanyID=E.CompanyID AND DV.UnitType=N'DIV'
LEFT JOIN dbo.TDTRBookingExam EPre ON EPre.CompanyID=B.CompanyID AND EPre.BookingID=B.BookingID AND EPre.SectionCode=N'PRE'
LEFT JOIN dbo.TDTRBookingExamAttempt APre ON APre.ExamID=EPre.ExamID AND APre.CompanyID=EPre.CompanyID AND APre.BookingParticipantID=P.BookingParticipantID
LEFT JOIN dbo.TDTRBookingExam EPost ON EPost.CompanyID=B.CompanyID AND EPost.BookingID=B.BookingID AND EPost.SectionCode=N'POST'
LEFT JOIN dbo.TDTRBookingExamAttempt EPostA ON EPostA.ExamID=EPost.ExamID AND EPostA.CompanyID=EPost.CompanyID AND EPostA.BookingParticipantID=P.BookingParticipantID
WHERE P.CompanyID=@company AND P.EmployeeID=@employee
""" + filterSql;
        var examInvitationFilter = " AND P.InvitationStatus=N'ACCEPTED' AND EXISTS (SELECT 1 FROM dbo.TDTRBookingExam EI WHERE EI.CompanyID=B.CompanyID AND EI.BookingID=B.BookingID AND EI.SectionCode IN (N'PRE',N'POST'))";
        source += examInvitationFilter;
        var total = await Scalar("SELECT COUNT(DISTINCT P.BookingParticipantID) " + source, db, company, employee.GetValueOrDefault(), token, filterArgs.ToArray());
        var rows = await Rows("""
SELECT P.BookingParticipantID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,MIN(S.StartDateTime) StartDateTime,
MAX(S.EndDateTime) EndDateTime,P.InvitationStatus,DV.NameTH DivisionName,DEP.NameTH DepartmentName,
EPre.ExamID PreExamID,APre.AttemptID PreAttemptID,APre.Score PreScore,APre.MaxScore PreMaxScore,APre.Passed PrePassed,APre.SubmittedDate PreSubmittedDate,
EPost.ExamID PostExamID,EPostA.AttemptID PostAttemptID,EPostA.Score PostScore,EPostA.MaxScore PostMaxScore,EPostA.Passed PostPassed,EPostA.SubmittedDate PostSubmittedDate
""" + Environment.NewLine + source + Environment.NewLine + """
GROUP BY P.BookingParticipantID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,P.InvitationStatus,DV.NameTH,DEP.NameTH,
EPre.ExamID,APre.AttemptID,APre.Score,APre.MaxScore,APre.Passed,APre.SubmittedDate,
EPost.ExamID,EPostA.AttemptID,EPostA.Score,EPostA.MaxScore,EPostA.Passed,EPostA.SubmittedDate
ORDER BY MIN(S.StartDateTime) DESC,P.BookingParticipantID DESC
""", db, company, employee.GetValueOrDefault(), token, filterArgs.ToArray());
        var paged = rows.Skip((page - 1) * pageSize).Take(pageSize);
        return Ok(new { total = Convert.ToInt64(total), page, pageSize, items = paged.Select(Row) });
    }

    private async Task<IActionResult> ListMulti(SqlConnection db, long company, long employee, int page, int pageSize, string? course, string? resultStatus, CancellationToken token)
    {
        var rows = await Rows("""
SELECT P.BookingParticipantID,B.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,
MIN(S.StartDateTime) StartDateTime,MAX(S.EndDateTime) EndDateTime,P.InvitationStatus,
DV.NameTH DivisionName,DEP.NameTH DepartmentName
FROM dbo.TDADMeetingRoomBookingParticipant P
JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID AND B.ActivityTypeCode=N'TRAINING'
JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
JOIN dbo.TDADEmployee E ON E.EmployeeID=P.EmployeeID AND E.CompanyID=P.CompanyID
LEFT JOIN dbo.TDADOrganizationUnit DEP ON DEP.OrgUnitID=E.DepartmentOrgUnitID AND DEP.CompanyID=E.CompanyID
LEFT JOIN dbo.TDADOrganizationUnit DV ON DV.OrgUnitID=E.DivisionOrgUnitID AND DV.CompanyID=E.CompanyID
WHERE P.CompanyID=@company AND P.EmployeeID=@employee AND P.InvitationStatus=N'ACCEPTED'
AND EXISTS (SELECT 1 FROM dbo.TDTRBookingExam X WHERE X.CompanyID=B.CompanyID AND X.BookingID=B.BookingID)
AND (@course IS NULL OR @course=N'' OR B.Subject LIKE N'%'+@course+N'%')
GROUP BY P.BookingParticipantID,B.BookingID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,P.InvitationStatus,DV.NameTH,DEP.NameTH
ORDER BY MIN(S.StartDateTime) DESC,P.BookingParticipantID DESC
""", db, company, employee, token, ("@course", string.IsNullOrWhiteSpace(course) ? null : course.Trim()));
        var items = new List<object>();
        foreach (var row in rows)
        {
            var exams = await Rows("""
SELECT X.SectionCode,X.ExamID,X.SequenceNo,X.TrainingTestTemplateNameSnapshot,A.AttemptID,A.Score,A.MaxScore,A.Passed,A.SubmittedDate
FROM dbo.TDTRBookingExam X
LEFT JOIN dbo.TDTRBookingExamAttempt A ON A.ExamID=X.ExamID AND A.CompanyID=X.CompanyID AND A.BookingParticipantID=@participant
WHERE X.CompanyID=@company AND X.BookingID=@booking ORDER BY X.SectionCode,X.SequenceNo
""", db, company, employee, token, ("@booking", row["BookingID"]), ("@participant", row["BookingParticipantID"]));
            var pre = Summary(exams.Where(x => x["SectionCode"]?.ToString() == "PRE").ToList());
            var post = Summary(exams.Where(x => x["SectionCode"]?.ToString() == "POST").ToList());
            var passed = pre.Total + post.Total > 0 && pre.PassedAll && post.PassedAll;
            var failed = pre.Failed || post.Failed;
            if (string.Equals(resultStatus, "PASSED", StringComparison.OrdinalIgnoreCase) && !passed) continue;
            if (string.Equals(resultStatus, "FAILED", StringComparison.OrdinalIgnoreCase) && !failed) continue;
            items.Add(new {
                participantId=row["BookingParticipantID"], bookingNo=row["BookingNo"], subject=row["Subject"],
                roomCode=row["RoomCode"], roomName=row["RoomNameTH"], startDateTime=row["StartDateTime"], endDateTime=row["EndDateTime"],
                invitationStatus=row["InvitationStatus"], divisionName=row["DivisionName"], departmentName=row["DepartmentName"],
                pre=new { total=pre.Total, submitted=pre.Submitted, passed=pre.Passed, passedAll=pre.PassedAll, result=pre.Failed?"FAILED":pre.PassedAll?"PASSED":"INCOMPLETE", items=pre.Items },
                post=new { total=post.Total, submitted=post.Submitted, passed=post.Passed, passedAll=post.PassedAll, result=post.Failed?"FAILED":post.PassedAll?"PASSED":"INCOMPLETE", items=post.Items },
                result=failed?"FAILED":passed?"PASSED":"INCOMPLETE"
            });
        }
        var total = items.Count;
        return Ok(new { total, page, pageSize, items = items.Skip((page - 1) * pageSize).Take(pageSize) });
    }

    private static ExamSummary Summary(List<Dictionary<string, object?>> rows)
    {
        var items = rows.Select(x => {
            var submitted = x["SubmittedDate"] is not null;
            var passed = x["Passed"] as bool?;
            return (object)new {
                examId=x["ExamID"], sequenceNo=x["SequenceNo"], templateName=x["TrainingTestTemplateNameSnapshot"],
                status=!submitted && x["AttemptID"] is null?"NOT_STARTED":!submitted?"IN_PROGRESS":passed is true?"PASSED":"FAILED",
                score=x["Score"], maxScore=x["MaxScore"], percent=x["Score"] is int score && x["MaxScore"] is int max?decimal.Round(score*100m/max,2):(decimal?)null,
                passed, submitted, submittedDate=x["SubmittedDate"]
            };
        }).ToList();
        return new(items.Count, items.Count(x => ((dynamic)x).submitted), items.Count(x => ((dynamic)x).passed is true), items.Count > 0 && items.All(x => ((dynamic)x).passed is true), items.Any(x => ((dynamic)x).submitted && ((dynamic)x).passed is false), items);
    }

    private sealed record ExamSummary(int Total, int Submitted, int Passed, bool PassedAll, bool Failed, List<object> Items);

    [HttpGet("{participantId:long}")]
    public async Task<IActionResult> Detail(long participantId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        var employee = await Employee(db, company, user, token);
        if (employee is null) return Forbid();
        var header = await Rows("""
SELECT TOP(1) P.BookingParticipantID,B.BookingNo,B.Subject,P.InvitationStatus,P.BookingID
FROM dbo.TDADMeetingRoomBookingParticipant P
JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID
WHERE P.CompanyID=@company AND P.BookingParticipantID=@participant AND P.EmployeeID=@employee AND B.ActivityTypeCode=N'TRAINING'
""", db, company, employee.Value, token, ("@participant", participantId));
        if (header.Count == 0) return Forbid();
        var results = await Rows("""
        SELECT X.ExamID,X.SectionCode,X.SequenceNo,X.TrainingTestTemplateNameSnapshot,A.Score,A.MaxScore,A.Passed,A.SubmittedDate,
        CASE WHEN P.InvitationStatus<>N'ACCEPTED' THEN N'NOT_ELIGIBLE' WHEN A.AttemptID IS NULL THEN N'NOT_STARTED' WHEN A.SubmittedDate IS NULL THEN N'IN_PROGRESS' ELSE N'SUBMITTED' END Status
        FROM dbo.TDTRBookingExam X
        JOIN dbo.TDADMeetingRoomBookingParticipant P ON P.BookingParticipantID=@participant AND P.CompanyID=X.CompanyID
        LEFT JOIN dbo.TDTRBookingExamAttempt A ON A.ExamID=X.ExamID AND A.CompanyID=X.CompanyID AND A.BookingParticipantID=@participant
WHERE X.CompanyID=@company AND X.BookingID=@booking
ORDER BY X.SectionCode
""", db, company, employee.Value, token, ("@participant", participantId), ("@booking", header[0]["BookingID"]));
        var h = header[0];
        return Ok(new
        {
            participantId,
            bookingNo = h["BookingNo"],
            subject = h["Subject"],
            invitationStatus = h["InvitationStatus"],
            results = results.Select(x => new
            {
                examId = x["ExamID"], section = x["SectionCode"], sequenceNo = x["SequenceNo"], templateName = x["TrainingTestTemplateNameSnapshot"],
                status = x["Status"],
                score = x["Score"],
                maxScore = x["MaxScore"],
                percent = Percent(x["Score"], x["MaxScore"]),
                passed = x["Passed"],
                submitted = x["SubmittedDate"] is not null
            })
        });
    }

    private static object Row(Dictionary<string, object?> r) => new
    {
        participantId = r["BookingParticipantID"],
        bookingNo = r["BookingNo"],
        subject = r["Subject"],
        roomCode = r["RoomCode"],
        roomName = r["RoomNameTH"],
        startDateTime = r["StartDateTime"],
        endDateTime = r["EndDateTime"],
        invitationStatus = r["InvitationStatus"],
        divisionName = r["DivisionName"],
        departmentName = r["DepartmentName"],
        pre = Exam(r, "Pre"),
        post = Exam(r, "Post")
    };

    private static object Exam(Dictionary<string, object?> r, string prefix)
    {
        var exam = r[prefix + "ExamID"];
        var attempt = r[prefix + "AttemptID"];
        var submitted = r[prefix + "SubmittedDate"] is not null;
        var eligible = string.Equals(r["InvitationStatus"]?.ToString(), "ACCEPTED", StringComparison.OrdinalIgnoreCase);
        return new
        {
            status = !eligible || exam is null ? "NOT_ELIGIBLE" : attempt is null ? "NOT_STARTED" : submitted ? "SUBMITTED" : "IN_PROGRESS",
            score = r[prefix + "Score"],
            maxScore = r[prefix + "MaxScore"],
            percent = Percent(r[prefix + "Score"], r[prefix + "MaxScore"]),
            passed = r[prefix + "Passed"],
            submitted
        };
    }

    private static decimal? Percent(object? score, object? max) =>
        score is null || max is null || Convert.ToDecimal(max) == 0
            ? null
            : decimal.Round(Convert.ToDecimal(score) * 100m / Convert.ToDecimal(max), 2);

    private async Task<long?> Employee(SqlConnection db, long company, long user, CancellationToken token)
    {
        await using var command = new SqlCommand("""
SELECT TOP(1) UE.EmployeeID
FROM dbo.TDADUserEmployee UE
JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1
WHERE UE.UserID=@user AND UE.CompanyID=@company AND UE.IsActive=1
ORDER BY UE.EmployeeID
""", db);
        command.Parameters.AddWithValue("@user", user);
        command.Parameters.AddWithValue("@company", company);
        var value = await command.ExecuteScalarAsync(token);
        return value is null || value == DBNull.Value ? null : Convert.ToInt64(value);
    }

    private bool Scope(out long company, out long user)
    {
        company = 0;
        user = 0;
        return long.TryParse(User.FindFirstValue("company_id"), out company) &&
            long.TryParse(User.FindFirstValue("user_id"), out user) &&
            User.FindFirstValue("user_type") == "COMPANY_USER";
    }

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        return db;
    }

    private static async Task<object?> Scalar(string sql, SqlConnection db, long company, long employee, CancellationToken token, params (string, object?)[] args)
    {
        await using var command = Command(sql, db, company, employee, args);
        return await command.ExecuteScalarAsync(token);
    }

    private static async Task<List<Dictionary<string, object?>>> Rows(string sql, SqlConnection db, long company, long employee, CancellationToken token, params (string, object?)[] args)
    {
        await using var command = Command(sql, db, company, employee, args);
        await using var reader = await command.ExecuteReaderAsync(token);
        var rows = new List<Dictionary<string, object?>>();
        while (await reader.ReadAsync(token))
        {
            var row = new Dictionary<string, object?>();
            for (var i = 0; i < reader.FieldCount; i++)
                row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
            rows.Add(row);
        }
        return rows;
    }

    private static SqlCommand Command(string sql, SqlConnection db, long company, long employee, params (string, object?)[] args)
    {
        var command = new SqlCommand(sql, db);
        command.Parameters.AddWithValue("@company", company);
        command.Parameters.AddWithValue("@employee", employee);
        foreach (var (name, value) in args)
            command.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return command;
    }
}

