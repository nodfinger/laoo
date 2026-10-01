using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooIntranetModule.Controllers;

public sealed partial class IntranetController
{
    [HttpGet("home")]
    public async Task<IActionResult> Home([FromQuery] string? type, [FromQuery] string? search, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43004", "VIEW", token)) return Forbid();
        await EnsureSettings(c, company, user, token);
        var employee = await CurrentEmployee(c, company, user, token);
        var department = await CurrentDepartment(c, company, employee, token);
        const string eligible = """
FROM dbo.TDINContent c
JOIN dbo.TDSTCompanySetupSystemIntranet cfg ON cfg.CompanyID=c.CompanyID AND cfg.IsEnabled=1
LEFT JOIN dbo.TDINContentReceipt r ON r.CompanyID=c.CompanyID AND r.ContentID=c.ContentID AND r.UserID=@user
WHERE c.CompanyID=@co AND c.IsActive=1 AND c.StatusCode=N'PUBLISHED'
 AND c.PublishAt<=SYSUTCDATETIME() AND(c.ExpireAt IS NULL OR c.ExpireAt>SYSUTCDATETIME())
 AND (c.TargetMode=N'ALL'
  OR(c.TargetMode=N'EMPLOYEE' AND @employee IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.TDINContentTargetEmployee te WHERE te.CompanyID=c.CompanyID AND te.ContentID=c.ContentID AND te.EmployeeID=@employee))
  OR(c.TargetMode=N'DEPARTMENT' AND @department IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.TDINContentTargetDepartment td WHERE td.CompanyID=c.CompanyID AND td.ContentID=c.ContentID AND td.DepartmentOrgUnitID=@department)))
""";
        var sql = $"""
SELECT TOP(50) c.ContentID id,c.ContentCode code,c.ContentTypeCode type,c.Title title,c.SummaryText summary,c.BodyText body,c.SourceUrl sourceUrl,
 c.IsPinned pinned,c.RequiresAcknowledgement requiresAck,c.PublishAt,c.ExpireAt,r.FirstReadAt,r.AcknowledgedAt
{eligible}
 AND (@type IS NULL OR c.ContentTypeCode=@type)
 AND (@search IS NULL OR c.Title LIKE N'%'+@search+N'%' OR c.SummaryText LIKE N'%'+@search+N'%' OR c.BodyText LIKE N'%'+@search+N'%')
ORDER BY c.IsPinned DESC,c.PublishAt DESC,c.ContentID DESC;
SELECT TOP(10) c.ContentID id,c.Title title,c.ExpireAt
{eligible} AND c.RequiresAcknowledgement=1 AND r.AcknowledgedAt IS NULL
ORDER BY c.ExpireAt,c.PublishAt;
""";
        await using var q = new SqlCommand(sql, c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@user", SqlDbType.BigInt, user);
        P(q, "@employee", SqlDbType.BigInt, employee); P(q, "@department", SqlDbType.BigInt, department);
        P(q, "@type", SqlDbType.NVarChar, Clean(type)?.ToUpperInvariant(), 20); P(q, "@search", SqlDbType.NVarChar, Clean(search), 250);
        return Ok(await Multi(q, token, ["items", "required"]));
    }

    [HttpPost("home/{id:long}/receipt")]
    public async Task<IActionResult> Receipt(long id, IntranetReceiptInput input, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43004", "VIEW", token)) return Forbid();
        var employee = await CurrentEmployee(c, company, user, token);
        var department = await CurrentDepartment(c, company, employee, token);
        const string eligible = """
SELECT COUNT(*) FROM dbo.TDINContent c
WHERE c.CompanyID=@co AND c.ContentID=@id AND c.IsActive=1 AND c.StatusCode=N'PUBLISHED'
 AND c.PublishAt<=SYSUTCDATETIME() AND(c.ExpireAt IS NULL OR c.ExpireAt>SYSUTCDATETIME())
 AND(c.TargetMode=N'ALL'
  OR(c.TargetMode=N'EMPLOYEE' AND @employee IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.TDINContentTargetEmployee te WHERE te.CompanyID=c.CompanyID AND te.ContentID=c.ContentID AND te.EmployeeID=@employee))
  OR(c.TargetMode=N'DEPARTMENT' AND @department IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.TDINContentTargetDepartment td WHERE td.CompanyID=c.CompanyID AND td.ContentID=c.ContentID AND td.DepartmentOrgUnitID=@department)))
""";
        await using var check = new SqlCommand(eligible, c);
        P(check, "@co", SqlDbType.BigInt, company); P(check, "@id", SqlDbType.BigInt, id);
        P(check, "@employee", SqlDbType.BigInt, employee); P(check, "@department", SqlDbType.BigInt, department);
        if (Convert.ToInt32(await check.ExecuteScalarAsync(token)) != 1) return NotFound();
        await using var q = new SqlCommand("""
MERGE dbo.TDINContentReceipt AS target
USING(SELECT @co CompanyID,@id ContentID,@user UserID) source
ON target.CompanyID=source.CompanyID AND target.ContentID=source.ContentID AND target.UserID=source.UserID
WHEN MATCHED THEN UPDATE SET LastReadAt=SYSUTCDATETIME(),AcknowledgedAt=CASE WHEN @ack=1 THEN COALESCE(target.AcknowledgedAt,SYSUTCDATETIME()) ELSE target.AcknowledgedAt END
WHEN NOT MATCHED THEN INSERT(CompanyID,ContentID,UserID,AcknowledgedAt) VALUES(@co,@id,@user,CASE WHEN @ack=1 THEN SYSUTCDATETIME() END);
""", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id); P(q, "@user", SqlDbType.BigInt, user); P(q, "@ack", SqlDbType.Bit, input.Acknowledge);
        await q.ExecuteNonQueryAsync(token);
        return NoContent();
    }

    [HttpGet("reports")]
    public async Task<IActionResult> Reports(CancellationToken token)
    {
        if (!Scope(out var company, out _)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43005", "VIEW", token)) return Forbid();
        const string sql = """
SELECT COUNT(*) totalContent,
 SUM(CASE WHEN StatusCode=N'PUBLISHED' THEN 1 ELSE 0 END) publishedContent,
 SUM(CASE WHEN StatusCode=N'PENDING_APPROVAL' THEN 1 ELSE 0 END) pendingContent,
 SUM(CASE WHEN RequiresAcknowledgement=1 THEN 1 ELSE 0 END) acknowledgementContent
FROM dbo.TDINContent WHERE CompanyID=@co AND IsActive=1;
SELECT TOP(100) c.ContentID id,c.ContentCode code,c.Title title,c.ContentTypeCode type,c.StatusCode status,c.PublishAt,c.ExpireAt,
 (SELECT COUNT(*) FROM dbo.TDINContentReceipt r WHERE r.CompanyID=c.CompanyID AND r.ContentID=c.ContentID) readCount,
 (SELECT COUNT(*) FROM dbo.TDINContentReceipt r WHERE r.CompanyID=c.CompanyID AND r.ContentID=c.ContentID AND r.AcknowledgedAt IS NOT NULL) acknowledgedCount
FROM dbo.TDINContent c WHERE c.CompanyID=@co AND c.IsActive=1 ORDER BY c.CreateDate DESC,c.ContentID DESC;
SELECT TOP(100) h.ContentApprovalHistoryID id,c.ContentCode code,c.Title title,h.ActionCode action,h.FromStatusCode fromStatus,h.ToStatusCode toStatus,h.ReasonText reason,h.ActionBy,h.ActionAt
FROM dbo.TDINContentApprovalHistory h JOIN dbo.TDINContent c ON c.CompanyID=h.CompanyID AND c.ContentID=h.ContentID
WHERE h.CompanyID=@co ORDER BY h.ActionAt DESC,h.ContentApprovalHistoryID DESC;
""";
        await using var q = new SqlCommand(sql, c); P(q, "@co", SqlDbType.BigInt, company);
        return Ok(await Multi(q, token, ["summary", "items", "history"]));
    }
}
