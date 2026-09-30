using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooSurveyModule.Controllers;

public sealed partial class SurveyController
{
    [HttpPost]
    public Task<IActionResult> Create(SurveyInput input, CancellationToken token) => Save(null, input, "CREATE", token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, SurveyInput input, CancellationToken token) => Save(id, input, "EDIT", token);

    async Task<IActionResult> Save(long? id, SurveyInput input, string action, CancellationToken token)
    {
        var error = ValidateDocument(input);
        if (error is not null) return Bad("ข้อมูลแบบสอบถามไม่ครบ", error);
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "40002", action, token)) return Forbid();
        if (input.ApproverEmployeeID is long approver && !await EmployeeExists(c, company, approver, token))
            return Bad("ผู้อนุมัติไม่ถูกต้อง", "เลือกพนักงาน Active ในบริษัทเดียวกัน");
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var code = string.IsNullOrWhiteSpace(input.Code) ? "SV" + DateTime.UtcNow.ToString("yyyyMMddHHmmssfff") : input.Code.Trim().ToUpperInvariant();
            long survey;
            if (id is null)
            {
                await using var h = new SqlCommand("""
INSERT dbo.TDSVSurvey(CompanyID,ProjectID,SurveyCode,SurveyName,DescriptionText,OpenAt,CloseAt,
 IsAnonymous,ShowResultAfterClose,ApproverEmployeeID,StatusCode,CreateBy)
OUTPUT INSERTED.SurveyID
SELECT @co,ProjectID,@code,@name,@description,@open,@close,@anonymous,@show,@approver,N'DRAFT',@user
FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SURVEY'
""", c, tx);
                BindHeader(h, company, user, null, code, input);
                survey = Convert.ToInt64(await h.ExecuteScalarAsync(token));
            }
            else
            {
                survey = id.Value;
                await using var h = new SqlCommand("""
UPDATE dbo.TDSVSurvey SET SurveyCode=@code,SurveyName=@name,DescriptionText=@description,
 OpenAt=@open,CloseAt=@close,IsAnonymous=@anonymous,ShowResultAfterClose=@show,
 ApproverEmployeeID=@approver,StatusCode=N'DRAFT',ReturnReason=NULL,UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@co AND SurveyID=@id AND StatusCode IN(N'DRAFT',N'RETURNED');SELECT @@ROWCOUNT
""", c, tx);
                BindHeader(h, company, user, id, code, input);
                if (Convert.ToInt32(await h.ExecuteScalarAsync(token)) == 0)
                {
                    await tx.RollbackAsync(token);
                    return Conflict(new { message = "แก้ไขแบบสอบถามไม่ได้", description = "แก้ไขได้เฉพาะสถานะร่างหรือส่งกลับแก้ไข" });
                }
                await Execute(c, tx, "DELETE o FROM dbo.TDSVSurveyQuestionOption o JOIN dbo.TDSVSurveyQuestion q ON q.QuestionID=o.QuestionID WHERE q.SurveyID=@id;DELETE dbo.TDSVSurveyQuestion WHERE SurveyID=@id", token, ("@id", survey));
            }
            var no = 0;
            foreach (var question in input.Questions)
            {
                no++;
                await using var q = new SqlCommand("""
INSERT dbo.TDSVSurveyQuestion(CompanyID,SurveyID,QuestionNo,QuestionText,QuestionType,IsRequired,MinValue,MaxValue,CreateBy)
OUTPUT INSERTED.QuestionID VALUES(@co,@survey,@no,@text,@type,@required,@min,@max,@user)
""", c, tx);
                P(q, "@co", SqlDbType.BigInt, company); P(q, "@survey", SqlDbType.BigInt, survey);
                P(q, "@no", SqlDbType.Int, no); P(q, "@text", SqlDbType.NVarChar, question.Text.Trim(), 1000);
                P(q, "@type", SqlDbType.NVarChar, question.Type.Trim().ToUpperInvariant(), 20);
                P(q, "@required", SqlDbType.Bit, question.Required); P(q, "@min", SqlDbType.Int, question.MinValue);
                P(q, "@max", SqlDbType.Int, question.MaxValue); P(q, "@user", SqlDbType.BigInt, user);
                var questionId = Convert.ToInt64(await q.ExecuteScalarAsync(token));
                var optionNo = 0;
                foreach (var option in question.Options ?? [])
                {
                    optionNo++;
                    await Execute(c, tx, "INSERT dbo.TDSVSurveyQuestionOption(CompanyID,QuestionID,OptionNo,OptionText,CreateBy) VALUES(@co,@question,@no,@text,@user)", token,
                        ("@co", company), ("@question", questionId), ("@no", optionNo), ("@text", option.Trim()), ("@user", user));
                }
            }
            await tx.CommitAsync(token);
            return Ok(new { id = survey, code });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627)
        {
            await tx.RollbackAsync(token);
            return Conflict(new { message = "รหัสแบบสอบถามซ้ำ", description = "ใช้รหัสอื่นภายในบริษัท" });
        }
        catch { await tx.RollbackAsync(token); throw; }
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        if (!Scope(out var company, out _)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "40002", "DELETE", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            var state = Convert.ToString(await Scalar(c, tx,
                "SELECT StatusCode FROM dbo.TDSVSurvey WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND SurveyID=@id",
                token, ("@co", company), ("@id", id)));
            if (state != "DRAFT")
            {
                await tx.RollbackAsync(token);
                return Conflict(new { message = "ลบแบบสอบถามไม่ได้", description = "ลบได้เฉพาะสถานะร่าง" });
            }
            var deleted = await Execute(c, tx, """
DELETE o FROM dbo.TDSVSurveyQuestionOption o JOIN dbo.TDSVSurveyQuestion q ON q.QuestionID=o.QuestionID WHERE q.SurveyID=@id;
DELETE dbo.TDSVSurveyQuestion WHERE SurveyID=@id;
DELETE dbo.TDSVSurvey WHERE CompanyID=@co AND SurveyID=@id AND StatusCode=N'DRAFT';
""", token, ("@id", id), ("@co", company));
            if (deleted == 0) { await tx.RollbackAsync(token); return Conflict(new { message = "ลบแบบสอบถามไม่ได้", description = "ลบได้เฉพาะสถานะร่าง" }); }
            await tx.CommitAsync(token); return NoContent();
        }
        catch (SqlException) { await tx.RollbackAsync(token); return Conflict(new { message = "ลบแบบสอบถามไม่ได้", description = "แบบสอบถามถูกใช้งานแล้ว" }); }
    }

    [HttpPost("{id:long}/submit")]
    public async Task<IActionResult> Submit(long id, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, "40002", "SUBMIT", token)) return Forbid();
        await EnsureSettings(c, company, user, token);
        await using var q = new SqlCommand("""
UPDATE s SET StatusCode=CASE WHEN cfg.RequireApproval=1 THEN N'PENDING_APPROVAL' ELSE N'APPROVED' END,
 SubmittedAt=SYSUTCDATETIME(),ApprovedAt=CASE WHEN cfg.RequireApproval=0 THEN SYSUTCDATETIME() ELSE NULL END,
 UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
FROM dbo.TDSVSurvey s JOIN dbo.TDSTCompanySetupSystemSurvey cfg ON cfg.CompanyID=s.CompanyID
WHERE s.CompanyID=@co AND s.SurveyID=@id AND s.StatusCode IN(N'DRAFT',N'RETURNED')
 AND EXISTS(SELECT 1 FROM dbo.TDSVSurveyQuestion q WHERE q.SurveyID=s.SurveyID AND q.IsActive=1);SELECT @@ROWCOUNT
""", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id); P(q, "@user", SqlDbType.BigInt, user);
        if (Convert.ToInt32(await q.ExecuteScalarAsync(token)) == 0) return Conflict(new { message = "ส่งอนุมัติไม่ได้", description = "แบบสอบถามต้องเป็นร่างและมีคำถามอย่างน้อย 1 ข้อ" });
        return NoContent();
    }

    [HttpPost("{id:long}/cancel")]
    public Task<IActionResult> Cancel(long id, CancellationToken token) => StatusAction(id, "40002", "CANCEL",
        "UPDATE dbo.TDSVSurvey SET StatusCode=N'CANCELLED',UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND SurveyID=@id AND StatusCode IN(N'DRAFT',N'RETURNED',N'PENDING_APPROVAL',N'APPROVED')", token);
}
