using System.Data;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooIntranetModule.Controllers;

[ApiController, Authorize, Route("api/company/intranet")]
public sealed partial class IntranetController : ControllerBase
{
    static readonly string[] Menus = ["43001", "43002", "43003", "43004", "43005"];
    readonly IConfiguration configuration;
    public IntranetController(IConfiguration configuration) => this.configuration = configuration;

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
            approve = await Can(c, menu, "APPROVE", token),
            @return = await Can(c, menu, "RETURN", token),
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
        if (!await Can(c, "43001", "VIEW", token)) return Forbid();
        await EnsureSettings(c, company, user, token);
        await using var q = new SqlCommand("""
SELECT IsEnabled,RequireApproval,AllowSelfApproval,DefaultApproverEmployeeID,DefaultPublishDays
FROM dbo.TDSTCompanySetupSystemIntranet WHERE CompanyID=@co
""", c);
        P(q, "@co", SqlDbType.BigInt, company);
        return Ok((await Rows(q, token)).FirstOrDefault());
    }

    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(IntranetSettingsInput input, CancellationToken token)
    {
        if (input.DefaultPublishDays is < 1 or > 3650)
            return Bad("ข้อมูลตั้งค่าไม่ถูกต้อง", "จำนวนวันเผยแพร่เริ่มต้นต้องอยู่ระหว่าง 1-3650 วัน");
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43001", "EDIT", token)) return Forbid();
        if (input.DefaultApproverEmployeeID is long approver && !await EmployeeExists(c, company, approver, token))
            return Bad("ผู้อนุมัติไม่ถูกต้อง", "เลือกพนักงานที่เปิดใช้งานในบริษัทเดียวกัน");
        await EnsureSettings(c, company, user, token);
        await using var q = new SqlCommand("""
UPDATE dbo.TDSTCompanySetupSystemIntranet
SET IsEnabled=@enabled,RequireApproval=@approval,AllowSelfApproval=@self,
 DefaultApproverEmployeeID=@approver,DefaultPublishDays=@days,
 UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@co
""", c);
        P(q, "@enabled", SqlDbType.Bit, input.IsEnabled);
        P(q, "@approval", SqlDbType.Bit, input.RequireApproval);
        P(q, "@self", SqlDbType.Bit, input.AllowSelfApproval);
        P(q, "@approver", SqlDbType.BigInt, input.DefaultApproverEmployeeID);
        P(q, "@days", SqlDbType.Int, input.DefaultPublishDays);
        P(q, "@user", SqlDbType.BigInt, user);
        P(q, "@co", SqlDbType.BigInt, company);
        await q.ExecuteNonQueryAsync(token);
        return NoContent();
    }

    [HttpGet("contents")]
    public async Task<IActionResult> Contents([FromQuery] string? search, [FromQuery] string? status, [FromQuery] int page = 1, [FromQuery] int pageSize = 10, CancellationToken token = default)
    {
        if (!Scope(out var company, out _)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43002", "VIEW", token)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        const string where = """
FROM dbo.TDINContent c
LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=c.CompanyID AND e.EmployeeID=c.ApproverEmployeeID
WHERE c.CompanyID=@co AND c.IsActive=1
 AND (@status IS NULL OR c.StatusCode=@status)
 AND (@search IS NULL OR c.ContentCode LIKE N'%'+@search+N'%' OR c.Title LIKE N'%'+@search+N'%' OR c.SummaryText LIKE N'%'+@search+N'%')
""";
        var sql = $"""
SELECT COUNT(*) {where};
SELECT c.ContentID id,c.ContentCode code,c.ContentTypeCode type,c.Title title,c.SummaryText summary,
 c.TargetMode targetMode,c.IsPinned pinned,c.RequiresAcknowledgement requiresAck,c.PublishAt,c.ExpireAt,
 c.StatusCode status,c.ReturnReason,e.FullName approver
{where}
ORDER BY c.CreateDate DESC,c.ContentID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY;
""";
        await using var q = new SqlCommand(sql, c);
        P(q, "@co", SqlDbType.BigInt, company);
        P(q, "@status", SqlDbType.NVarChar, Clean(status), 30);
        P(q, "@search", SqlDbType.NVarChar, Clean(search), 250);
        P(q, "@offset", SqlDbType.Int, (page - 1) * pageSize);
        P(q, "@size", SqlDbType.Int, pageSize);
        var data = await Multi(q, token, ["count", "items"]);
        var countRows = (List<Dictionary<string, object?>>)data["count"];
        var total = countRows.Count == 0 ? 0 : Convert.ToInt32(countRows[0].Values.First() ?? 0);
        return Ok(new { items = data["items"], total, page, pageSize });
    }

    [HttpGet("contents/{id:long}")]
    public async Task<IActionResult> Content(long id, CancellationToken token)
    {
        if (!Scope(out var company, out _)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43002", "VIEW", token)) return Forbid();
        const string sql = """
SELECT ContentID id,ContentCode code,ContentTypeCode type,Title title,SummaryText summary,BodyText body,
 SourceUrl sourceUrl,TargetMode targetMode,IsPinned pinned,RequiresAcknowledgement requiresAck,
 PublishAt,ExpireAt,ApproverEmployeeID approverId,StatusCode status,ReturnReason
FROM dbo.TDINContent WHERE CompanyID=@co AND ContentID=@id AND IsActive=1;
SELECT DepartmentOrgUnitID id FROM dbo.TDINContentTargetDepartment WHERE CompanyID=@co AND ContentID=@id;
SELECT EmployeeID id FROM dbo.TDINContentTargetEmployee WHERE CompanyID=@co AND ContentID=@id;
""";
        await using var q = new SqlCommand(sql, c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id);
        var data = await Multi(q, token, ["header", "departments", "employees"]);
        if (((List<Dictionary<string, object?>>)data["header"]).Count == 0) return NotFound();
        return Ok(data);
    }

    [HttpPost("contents")]
    public Task<IActionResult> CreateContent(IntranetContentInput input, CancellationToken token) => SaveContent(null, input, token);

    [HttpPut("contents/{id:long}")]
    public Task<IActionResult> UpdateContent(long id, IntranetContentInput input, CancellationToken token) => SaveContent(id, input, token);

    [HttpDelete("contents/{id:long}")]
    public async Task<IActionResult> DeleteContent(long id, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43002", "DELETE", token)) return Forbid();
        await using var q = new SqlCommand("DELETE dbo.TDINContent WHERE CompanyID=@co AND ContentID=@id AND StatusCode IN(N'DRAFT',N'RETURNED') AND CreateBy=@user;SELECT @@ROWCOUNT", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id); P(q, "@user", SqlDbType.BigInt, user);
        return Convert.ToInt32(await q.ExecuteScalarAsync(token)) == 1
            ? NoContent()
            : Conflict(new { message = "ลบเนื้อหาไม่ได้", description = "ลบได้เฉพาะฉบับร่างหรือรายการที่ส่งกลับของผู้สร้าง" });
    }

    [HttpPost("contents/{id:long}/submit")]
    public async Task<IActionResult> Submit(long id, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43002", "SUBMIT", token)) return Forbid();
        await EnsureSettings(c, company, user, token);
        const string sql = """
DECLARE @approval bit=(SELECT RequireApproval FROM dbo.TDSTCompanySetupSystemIntranet WHERE CompanyID=@co);
UPDATE dbo.TDINContent
SET StatusCode=CASE WHEN @approval=1 THEN N'PENDING_APPROVAL' ELSE N'PUBLISHED' END,
 SubmittedAt=SYSUTCDATETIME(),ApprovedAt=CASE WHEN @approval=0 THEN SYSUTCDATETIME() ELSE ApprovedAt END,
 PublishedAt=CASE WHEN @approval=0 THEN SYSUTCDATETIME() ELSE PublishedAt END,
 UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@co AND ContentID=@id AND CreateBy=@user AND StatusCode IN(N'DRAFT',N'RETURNED');
SELECT @@ROWCOUNT;
""";
        await using var q = new SqlCommand(sql, c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id); P(q, "@user", SqlDbType.BigInt, user);
        if (Convert.ToInt32(await q.ExecuteScalarAsync(token)) != 1)
            return Conflict(new { message = "ส่งอนุมัติไม่ได้", description = "รายการต้องเป็นฉบับร่างหรือถูกส่งกลับ และเป็นของผู้ Login" });
        return NoContent();
    }

    [HttpGet("approvals")]
    public async Task<IActionResult> Approvals(CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43003", "VIEW", token)) return Forbid();
        var employee = await CurrentEmployee(c, company, user, token);
        var admin = await IsCompanyAdmin(c, company, user, token);
        await using var q = new SqlCommand("""
SELECT c.ContentID id,c.ContentCode code,c.ContentTypeCode type,c.Title title,c.SummaryText summary,
 c.PublishAt,c.ExpireAt,c.CreateDate,c.CreateBy,e.FullName approver
FROM dbo.TDINContent c LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=c.CompanyID AND e.EmployeeID=c.ApproverEmployeeID
WHERE c.CompanyID=@co AND c.IsActive=1 AND c.StatusCode=N'PENDING_APPROVAL'
 AND (@admin=1 OR c.ApproverEmployeeID IS NULL OR c.ApproverEmployeeID=@employee)
ORDER BY c.SubmittedAt,c.ContentID
""", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@admin", SqlDbType.Bit, admin); P(q, "@employee", SqlDbType.BigInt, employee);
        return Ok(await Rows(q, token));
    }

    [HttpPost("approvals/{id:long}/decision")]
    public async Task<IActionResult> Decide(long id, IntranetDecisionInput input, CancellationToken token)
    {
        var action = input.Action.Trim().ToUpperInvariant();
        if (action is not ("APPROVE" or "RETURN")) return Bad("คำสั่งไม่ถูกต้อง", "เลือกอนุมัติหรือส่งกลับแก้ไข");
        if (action == "RETURN" && string.IsNullOrWhiteSpace(input.Reason)) return Bad("กรุณาระบุเหตุผล", "การส่งกลับต้องมีเหตุผลให้ผู้สร้างแก้ไข");
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43003", action, token)) return Forbid();
        var employee = await CurrentEmployee(c, company, user, token);
        var admin = await IsCompanyAdmin(c, company, user, token);
        var allowSelf = Convert.ToBoolean(await Scalar(c, "SELECT AllowSelfApproval FROM dbo.TDSTCompanySetupSystemIntranet WHERE CompanyID=@co", company, token) ?? false);
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        const string metaSql = "SELECT CreateBy,ApproverEmployeeID FROM dbo.TDINContent WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND ContentID=@id AND StatusCode=N'PENDING_APPROVAL'";
        await using var meta = new SqlCommand(metaSql, c, tx);
        P(meta, "@co", SqlDbType.BigInt, company); P(meta, "@id", SqlDbType.BigInt, id);
        await using var reader = await meta.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) { await tx.RollbackAsync(token); return Conflict(new { message = "อนุมัติไม่ได้", description = "รายการไม่ได้อยู่สถานะรออนุมัติ" }); }
        var owner = reader.GetInt64(0);
        var approver = reader.IsDBNull(1) ? (long?)null : reader.GetInt64(1);
        await reader.DisposeAsync();
        if (!admin && approver is not null && approver != employee) { await tx.RollbackAsync(token); return Forbid(); }
        if (owner == user && !allowSelf) { await tx.RollbackAsync(token); return Conflict(new { message = "อนุมัติตนเองไม่ได้", description = "ตั้งค่าระบบไม่อนุญาตให้ผู้สร้างอนุมัติเนื้อหาของตนเอง" }); }
        var to = action == "APPROVE" ? "PUBLISHED" : "RETURNED";
        await using var update = new SqlCommand("""
UPDATE dbo.TDINContent SET StatusCode=@to,ReturnReason=@reason,
 ApprovedAt=CASE WHEN @to=N'PUBLISHED' THEN SYSUTCDATETIME() ELSE ApprovedAt END,
 PublishedAt=CASE WHEN @to=N'PUBLISHED' THEN SYSUTCDATETIME() ELSE PublishedAt END,
 UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND ContentID=@id AND StatusCode=N'PENDING_APPROVAL';
INSERT dbo.TDINContentApprovalHistory(CompanyID,ContentID,ActionCode,FromStatusCode,ToStatusCode,ReasonText,ActionBy)
VALUES(@co,@id,@action,N'PENDING_APPROVAL',@to,@reason,@user);
""", c, tx);
        P(update, "@to", SqlDbType.NVarChar, to, 30); P(update, "@reason", SqlDbType.NVarChar, Clean(input.Reason), 1000);
        P(update, "@user", SqlDbType.BigInt, user); P(update, "@co", SqlDbType.BigInt, company); P(update, "@id", SqlDbType.BigInt, id); P(update, "@action", SqlDbType.NVarChar, action, 30);
        await update.ExecuteNonQueryAsync(token);
        await tx.CommitAsync(token);
        return NoContent();
    }
}
