using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooSurveyModule.Controllers;

[ApiController, Authorize, Route("api/company/surveys")]
public sealed partial class SurveyController : ControllerBase
{
    static readonly string[] Menus = ["40001", "40002", "40003", "40004", "40005", "40006", "40007"];
    readonly IConfiguration configuration;
    public SurveyController(IConfiguration configuration) => this.configuration = configuration;

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken token)
    {
        if (!Menus.Contains(menu) || !Scope(out _, out _)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, menu, "VIEW", token)) return Forbid();
        return Ok(new
        {
            create = await Can(c, menu, "CREATE", token),
            edit = await Can(c, menu, "EDIT", token),
            delete = await Can(c, menu, "DELETE", token),
            submit = await Can(c, menu, "SUBMIT", token),
            cancel = await Can(c, menu, "CANCEL", token),
            approve = await Can(c, menu, "APPROVE", token),
            selfApprove = await Can(c, menu, "SELF_APPROVE", token),
            resend = await Can(c, menu, "RESEND", token),
        });
    }

    [HttpGet("options")]
    public async Task<IActionResult> Options(CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await HasAnyView(c, token)) return Forbid();
        const string sql = """
SELECT e.EmployeeID id,e.EmployeeCode code,e.FullName name,
 CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUserEmployee ue WHERE ue.CompanyID=e.CompanyID AND ue.EmployeeID=e.EmployeeID AND ue.UserID=@user AND ue.IsActive=1) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END isCurrent
FROM dbo.TDADEmployee e WHERE e.CompanyID=@co AND e.IsActive=1 ORDER BY e.FullName;
SELECT OrgUnitID id,UnitCode code,NameTH name
FROM dbo.TDADOrganizationUnit WHERE CompanyID=@co AND UnitType=N'DEP' AND IsActive=1 ORDER BY UnitCode;
""";
        await using var q = new SqlCommand(sql, c);
        P(q, "@co", SqlDbType.BigInt, company);
        P(q, "@user", SqlDbType.BigInt, user);
        return Ok(await Multi(q, token, ["employees", "departments"]));
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "40001", "VIEW", token)) return Forbid();
        await EnsureSettings(c, company, user, token);
        var rows = await Query(c, "SELECT IsEnabled,DefaultDurationDays,RequireApproval,DefaultAnonymous,ResultsAfterClose,DefaultApproverEmployeeID FROM dbo.TDSTCompanySetupSystemSurvey WHERE CompanyID=@co", company, token);
        return Ok(rows.FirstOrDefault());
    }

    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(SurveySettingsInput input, CancellationToken token)
    {
        if (input.DefaultDurationDays is < 1 or > 365)
            return Bad("ข้อมูลตั้งค่าไม่ถูกต้อง", "ระยะเวลาเริ่มต้นต้องอยู่ระหว่าง 1-365 วัน");
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "40001", "EDIT", token)) return Forbid();
        if (input.DefaultApproverEmployeeID is long approver && !await EmployeeExists(c, company, approver, token))
            return Bad("ผู้อนุมัติไม่ถูกต้อง", "เลือกพนักงาน Active ในบริษัทเดียวกัน");
        await EnsureSettings(c, company, user, token);
        await using var q = new SqlCommand("""
UPDATE dbo.TDSTCompanySetupSystemSurvey
SET IsEnabled=@enabled,DefaultDurationDays=@days,RequireApproval=@approval,
 DefaultAnonymous=@anonymous,ResultsAfterClose=@results,DefaultApproverEmployeeID=@approver,
 UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@co
""", c);
        P(q, "@enabled", SqlDbType.Bit, input.IsEnabled);
        P(q, "@days", SqlDbType.Int, input.DefaultDurationDays);
        P(q, "@approval", SqlDbType.Bit, input.RequireApproval);
        P(q, "@anonymous", SqlDbType.Bit, input.DefaultAnonymous);
        P(q, "@results", SqlDbType.Bit, input.ResultsAfterClose);
        P(q, "@approver", SqlDbType.BigInt, input.DefaultApproverEmployeeID);
        P(q, "@user", SqlDbType.BigInt, user);
        P(q, "@co", SqlDbType.BigInt, company);
        await q.ExecuteNonQueryAsync(token);
        return NoContent();
    }

    [HttpGet]
    public Task<IActionResult> List(CancellationToken token) => Read("40002", """
SELECT s.SurveyID id,s.SurveyCode code,s.SurveyName name,s.OpenAt,s.CloseAt,
 s.IsAnonymous anonymous,s.StatusCode status,e.FullName approver,
 (SELECT COUNT(*) FROM dbo.TDSVSurveyQuestion q WHERE q.SurveyID=s.SurveyID AND q.IsActive=1) questionCount,
 (SELECT COUNT(*) FROM dbo.TDSVSurveyAssignment a WHERE a.SurveyID=s.SurveyID AND a.IsActive=1) audienceCount
FROM dbo.TDSVSurvey s
LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=s.CompanyID AND e.EmployeeID=s.ApproverEmployeeID
WHERE s.CompanyID=@co AND s.IsActive=1 ORDER BY s.CreateDate DESC
""", token);

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Detail(long id, CancellationToken token)
    {
        if (!Scope(out var company, out _)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "40002", "VIEW", token)) return Forbid();
        const string sql = """
SELECT SurveyID id,SurveyCode code,SurveyName name,DescriptionText description,OpenAt,CloseAt,
 IsAnonymous anonymous,ShowResultAfterClose,ApproverEmployeeID,TargetMode,StatusCode status,ReturnReason
FROM dbo.TDSVSurvey WHERE CompanyID=@co AND SurveyID=@id AND IsActive=1;
SELECT QuestionID id,QuestionNo number,QuestionText text,QuestionType type,IsRequired required,MinValue,MaxValue
FROM dbo.TDSVSurveyQuestion WHERE CompanyID=@co AND SurveyID=@id AND IsActive=1 ORDER BY QuestionNo;
SELECT o.OptionID id,o.QuestionID questionID,o.OptionNo number,o.OptionText text
FROM dbo.TDSVSurveyQuestionOption o JOIN dbo.TDSVSurveyQuestion q ON q.QuestionID=o.QuestionID
WHERE q.CompanyID=@co AND q.SurveyID=@id AND o.IsActive=1 ORDER BY o.QuestionID,o.OptionNo;
""";
        await using var q = new SqlCommand(sql, c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id);
        var data = await Multi(q, token, ["header", "questions", "options"]);
        if (((List<Dictionary<string, object?>>)data["header"]).Count == 0) return NotFound();
        return Ok(data);
    }
}
