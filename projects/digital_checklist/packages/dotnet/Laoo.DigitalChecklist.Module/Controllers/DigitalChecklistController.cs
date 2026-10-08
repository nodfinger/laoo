using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Hosting;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.DigitalChecklist.Controllers;
[ApiController, Authorize, Route("api/company/digital-checklist")]
public sealed partial class DigitalChecklistController(IConfiguration config, IWebHostEnvironment environment) : ControllerBase
{
    private long Company => long.Parse(User.FindFirstValue("company_id")!);
    private long Actor => long.Parse(User.FindFirstValue("user_id")!);
    private async Task<SqlConnection> Open(CancellationToken ct) { var d = new SqlConnection(config.GetConnectionString("LaooDatabase")); await d.OpenAsync(ct); return d; }
    private async Task<bool> Can(SqlConnection d, string m, string a, CancellationToken ct) => await DigitalChecklistAccess.Can(d, User, m, a, ct);
    private async Task<IActionResult?> Guard(SqlConnection d, string m, string a, CancellationToken ct) => !DigitalChecklistAccess.Scope(User, out _, out _) ? Forbid() : await Can(d, m, a, ct) ? null : StatusCode(403, new { message = "ไม่มีสิทธิ์หรือไม่ได้เปิดใช้ระบบตรวจสอบดิจิทัล" });
    private async Task<bool> Admin(SqlConnection d, CancellationToken ct) => await Can(d, "58002", "MANAGE_DEPARTMENT", ct);
    private async Task<long?> Department(SqlConnection d, CancellationToken ct) { var id = await DigitalChecklistDb.Id(d, "SELECT TOP(1) A.DepartmentOrgUnitID FROM dbo.TDADUserEmployee U JOIN dbo.TDADEmployeeOrganizationAssignment A ON A.CompanyID=U.CompanyID AND A.EmployeeID=U.EmployeeID AND A.IsActive=1 AND A.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())) JOIN dbo.TDADOrganizationUnit O ON O.CompanyID=A.CompanyID AND O.OrgUnitID=A.DepartmentOrgUnitID AND O.UnitType=N'DEP' AND O.IsActive=1 WHERE U.CompanyID=@co AND U.UserID=@u AND U.IsActive=1 ORDER BY A.EffectiveFrom DESC", ct, ("@co", Company), ("@u", Actor)); return id > 0 ? id : null; }
    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken ct) { await using var d = await Open(ct); if (await Guard(d, menu, "VIEW", ct) is { } denied) return denied; if (!DigitalChecklistAccess.Menus.ContainsKey(menu)) return BadRequest(); var a = new Dictionary<string, bool>(); foreach (var k in DigitalChecklistAccess.Menus[menu].Actions.Split(' ')) a[k.ToLowerInvariant()] = await Can(d, menu, k, ct); var meta = await DigitalChecklistDb.Rows(d, "SELECT MenuName,ScreenType,IconName FROM dbo.TDADMainMenu WHERE MenuCode=@m", ct, ("@m", menu)); return Ok(new { actions = a, metadata = meta.Single() }); }
    [HttpGet("options")]
    public async Task<IActionResult> Options([FromQuery] string menuCode, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, menuCode, "VIEW", ct) is { } denied) return denied;
        var department = await Department(db, ct);
        var admin = await Admin(db, ct);
        if (department is null && !admin)
            return StatusCode(403, new { message = "ไม่พบแผนกปัจจุบัน กรุณาติดต่อผู้ดูแล" });

        var scope = new (string, object?)[] { ("@co", Company), ("@dep", department), ("@admin", admin ? 1 : 0) };
        var departmentSql = admin
            ? "SELECT OrgUnitID id,UnitCode code,NameTH name FROM dbo.TDADOrganizationUnit WHERE CompanyID=@co AND UnitType=N'DEP' AND IsActive=1 ORDER BY NameTH"
            : "SELECT OrgUnitID id,UnitCode code,NameTH name FROM dbo.TDADOrganizationUnit WHERE CompanyID=@co AND OrgUnitID=@dep AND IsActive=1";
        var departments = await DigitalChecklistDb.Rows(db, departmentSql, ct, ("@co", Company), ("@dep", department));
        var employees = await DigitalChecklistDb.Rows(db,
            "SELECT E.EmployeeID id,E.EmployeeCode code,E.FullName name FROM dbo.TDADEmployee E WHERE E.CompanyID=@co AND E.IsActive=1 AND (@admin=1 OR EXISTS(SELECT 1 FROM dbo.TDADEmployeeOrganizationAssignment A WHERE A.CompanyID=E.CompanyID AND A.EmployeeID=E.EmployeeID AND A.DepartmentOrgUnitID=@dep AND A.IsActive=1 AND A.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))) ORDER BY E.FullName",
            ct, scope);
        var groups = await DigitalChecklistDb.Rows(db,
            "SELECT GroupID id,GroupCode code,GroupName name FROM dbo.TDCLGroup WHERE CompanyID=@co AND (@admin=1 OR DepartmentOrgUnitID=@dep) AND IsActive=1 ORDER BY GroupName",
            ct, scope);
        var types = await DigitalChecklistDb.Rows(db,
            "SELECT T.TypeID id,T.TypeCode code,T.TypeName name,T.GroupID groupId FROM dbo.TDCLType T JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID WHERE T.CompanyID=@co AND T.IsActive=1 AND G.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep) ORDER BY T.TypeName",
            ct, scope);
        var templates = await DigitalChecklistDb.Rows(db,
            "SELECT X.TemplateID id,X.TypeID typeId,X.TemplateName name FROM dbo.TDCLTemplate X JOIN dbo.TDCLType T ON T.CompanyID=X.CompanyID AND T.TypeID=X.TypeID JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID WHERE X.CompanyID=@co AND X.IsActive=1 AND T.IsActive=1 AND G.IsActive=1 AND (@admin=1 OR G.DepartmentOrgUnitID=@dep) ORDER BY X.TemplateName",
            ct, scope);
        return Ok(new { departments, employees, groups, types, templates });
    }
    [HttpGet("data")]
    public async Task<IActionResult> Data([FromQuery] string menuCode, CancellationToken ct)
    {
        await using var d = await Open(ct); if (await Guard(d, menuCode, "VIEW", ct) is { } denied) return denied; if (menuCode == "58009" && !await Can(d, menuCode, "AUDIT", ct)) return Forbid(); var dep = await Department(d, ct); var admin = await Admin(d, ct); if (dep is null && !admin && menuCode != "58007") return StatusCode(403, new { message = "ไม่พบแผนกปัจจุบัน กรุณาติดต่อผู้ดูแล" }); var args = new (string, object?)[] { ("@co", Company), ("@dep", dep), ("@admin", admin ? 1 : 0), ("@user", Actor) }; var sql = menuCode switch
        {
            "58001" => "SELECT * FROM dbo.TDCLSetting WHERE CompanyID=@co",
            "58002" => "SELECT G.GroupID id,G.GroupCode code,G.GroupName name,G.DepartmentOrgUnitID departmentId,O.NameTH department,G.IsActive isActive FROM dbo.TDCLGroup G JOIN dbo.TDADOrganizationUnit O ON O.CompanyID=G.CompanyID AND O.OrgUnitID=G.DepartmentOrgUnitID WHERE G.CompanyID=@co AND (@admin=1 OR G.DepartmentOrgUnitID=@dep OR EXISTS(SELECT 1 FROM dbo.TDCLApproval A WHERE A.CompanyID=G.CompanyID AND A.GroupID=G.GroupID AND A.ApproverUserID=@user AND A.StatusCode=N'PENDING')) ORDER BY G.GroupName",
            "58003" => "SELECT T.TemplateID id,T.TypeID typeId,T.TemplateCode code,T.TemplateName name,T.IsActive isActive FROM dbo.TDCLTemplate T JOIN dbo.TDCLType Y ON Y.CompanyID=T.CompanyID AND Y.TypeID=T.TypeID JOIN dbo.TDCLGroup G ON G.CompanyID=Y.CompanyID AND G.GroupID=Y.GroupID WHERE T.CompanyID=@co AND (@admin=1 OR G.DepartmentOrgUnitID=@dep) ORDER BY T.TemplateName",
            "58004" => "SELECT W.WorkflowID id,W.TypeID typeId,W.WorkflowName name,W.IsActive isActive FROM dbo.TDCLWorkflow W JOIN dbo.TDCLType Y ON Y.CompanyID=W.CompanyID AND Y.TypeID=W.TypeID JOIN dbo.TDCLGroup G ON G.CompanyID=Y.CompanyID AND G.GroupID=Y.GroupID WHERE W.CompanyID=@co AND (@admin=1 OR G.DepartmentOrgUnitID=@dep) ORDER BY W.WorkflowName",
            "58005" => "SELECT S.ScheduleID id,S.TypeID typeId,S.ScheduleName name,S.FrequencyCode frequency,S.TimesJson times,S.IsActive isActive FROM dbo.TDCLSchedule S JOIN dbo.TDCLType Y ON Y.CompanyID=S.CompanyID AND Y.TypeID=S.TypeID JOIN dbo.TDCLGroup G ON G.CompanyID=Y.CompanyID AND G.GroupID=Y.GroupID WHERE S.CompanyID=@co AND (@admin=1 OR G.DepartmentOrgUnitID=@dep) ORDER BY S.ScheduleName",
            "58006" => """
                SELECT I.InspectionID id,I.ScheduleID scheduleId,I.InspectionCode code,I.TypeID typeId,
                  I.DueAt dueAt,I.StatusCode status,I.VersionNo version,
                  CAST(CASE WHEN (I.CreatedBy=@user OR @admin=1) AND I.StatusCode='IN_APPROVAL'
                    AND EXISTS(SELECT 1 FROM dbo.TDCLInspectionItem X WHERE X.CompanyID=I.CompanyID
                      AND X.InspectionID=I.InspectionID AND X.VersionNo=I.VersionNo AND X.ResultCode='FAIL'
                      AND NOT EXISTS(SELECT 1 FROM dbo.TDCLAttachment E WHERE E.CompanyID=X.CompanyID
                        AND E.InspectionID=X.InspectionID AND E.InspectionItemID=X.InspectionItemID))
                    THEN 1 ELSE 0 END AS bit) canUploadEvidence
                FROM dbo.TDCLInspection I
                WHERE I.CompanyID=@co AND (@admin=1 OR I.DepartmentOrgUnitID=@dep)
                  AND I.StatusCode IN('DUE','OVERDUE','RETURNED','IN_APPROVAL','APPROVED')
                ORDER BY I.DueAt DESC
                """,
            "58007" => "SELECT A.ApprovalID id,I.InspectionID inspectionId,I.InspectionCode code,A.StatusCode status,I.SubmittedAt submittedAt FROM dbo.TDCLApproval A JOIN dbo.TDCLInspection I ON I.CompanyID=A.CompanyID AND I.InspectionID=A.InspectionID AND I.VersionNo=A.VersionNo WHERE A.CompanyID=@co AND A.ApproverUserID=@user AND A.StatusCode=N'PENDING' ORDER BY I.SubmittedAt",
            "58008" => "SELECT C.TaskID id,C.InspectionID inspectionId,C.TaskCode code,C.Subject subject,C.StatusCode status,C.ServiceHandoffStatus handoffStatus,C.CreatedAt createdAt FROM dbo.TDCLCorrectiveTask C JOIN dbo.TDCLInspection I ON I.CompanyID=C.CompanyID AND I.InspectionID=C.InspectionID WHERE C.CompanyID=@co AND (@admin=1 OR I.DepartmentOrgUnitID=@dep) ORDER BY C.CreatedAt DESC",
            "58009" => "SELECT TOP(500) AuditID id,ActionCode action,EntityCode entity,EntityID entityId,ActorUserID actor,Detail detail,CreatedAt createdAt FROM dbo.TDCLAudit WHERE CompanyID=@co ORDER BY CreatedAt DESC",
            "58010" => "SELECT (SELECT COUNT(*) FROM dbo.TDCLInspection WHERE CompanyID=@co AND (@admin=1 OR DepartmentOrgUnitID=@dep) AND StatusCode=N'IN_APPROVAL') pending,(SELECT COUNT(*) FROM dbo.TDCLInspection WHERE CompanyID=@co AND (@admin=1 OR DepartmentOrgUnitID=@dep) AND StatusCode=N'OVERDUE') overdue,(SELECT COUNT(*) FROM dbo.TDCLCorrectiveTask C JOIN dbo.TDCLInspection I ON I.CompanyID=C.CompanyID AND I.InspectionID=C.InspectionID WHERE C.CompanyID=@co AND (@admin=1 OR I.DepartmentOrgUnitID=@dep) AND C.StatusCode<>N'RESOLVED') corrective,(SELECT COUNT(*) FROM dbo.TDCLInspection WHERE CompanyID=@co AND (@admin=1 OR DepartmentOrgUnitID=@dep) AND CAST(DueAt AS date)=CAST(SYSUTCDATETIME() AS date)) today",
            _ => "SELECT TOP(500) I.InspectionID id,I.InspectionCode code,I.TypeID typeId,I.DueAt dueAt,I.SubmittedAt submittedAt,I.StatusCode status,I.VersionNo version FROM dbo.TDCLInspection I WHERE I.CompanyID=@co AND (I.DepartmentOrgUnitID=@dep OR EXISTS(SELECT 1 FROM dbo.TDCLApproval A WHERE A.CompanyID=@co AND A.InspectionID=I.InspectionID AND A.ApproverUserID=@user)) ORDER BY I.DueAt DESC"
        }; return Ok(await DigitalChecklistDb.Rows(d, sql, ct, args));
    }
}
