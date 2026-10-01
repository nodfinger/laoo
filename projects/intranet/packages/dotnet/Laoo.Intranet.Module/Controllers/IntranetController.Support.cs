using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooIntranetModule.Controllers;

public sealed partial class IntranetController
{
    async Task<IActionResult> SaveContent(long? id, IntranetContentInput input, CancellationToken token)
    {
        var error = ValidateContent(input);
        if (error is not null) return Bad("ข้อมูลเนื้อหาไม่ถูกต้อง", error);
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, "43002", id is null ? "CREATE" : "EDIT", token)) return Forbid();
        if (input.ApproverEmployeeID is long approver && !await EmployeeExists(c, company, approver, token))
            return Bad("ผู้อนุมัติไม่ถูกต้อง", "เลือกพนักงานที่เปิดใช้งานในบริษัทเดียวกัน");
        if (!await TargetsValid(c, company, input, token))
            return Bad("กลุ่มเป้าหมายไม่ถูกต้อง", "เลือกแผนกหรือพนักงานที่เปิดใช้งานในบริษัทเดียวกัน");
        await EnsureSettings(c, company, user, token);
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        long contentId;
        var code = string.IsNullOrWhiteSpace(input.Code) ? $"IN{DateTime.UtcNow:yyyyMMddHHmmssfff}" : input.Code.Trim().ToUpperInvariant();
        if (id is null)
        {
            const string sql = """
INSERT dbo.TDINContent(CompanyID,ProjectID,ContentCode,ContentTypeCode,Title,SummaryText,BodyText,SourceUrl,
 TargetMode,IsPinned,RequiresAcknowledgement,PublishAt,ExpireAt,ApproverEmployeeID,CreateBy)
OUTPUT INSERTED.ContentID
SELECT @co,ProjectID,@code,@type,@title,@summary,@body,@url,@target,@pinned,@ack,@publish,@expire,@approver,@user
FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_INTRANET' AND IsActive=1;
""";
            await using var q = new SqlCommand(sql, c, tx);
            BindContent(q, company, user, code, input);
            contentId = Convert.ToInt64(await q.ExecuteScalarAsync(token));
        }
        else
        {
            const string sql = """
UPDATE dbo.TDINContent SET ContentCode=@code,ContentTypeCode=@type,Title=@title,SummaryText=@summary,
 BodyText=@body,SourceUrl=@url,TargetMode=@target,IsPinned=@pinned,RequiresAcknowledgement=@ack,
 PublishAt=@publish,ExpireAt=@expire,ApproverEmployeeID=@approver,ReturnReason=NULL,
 UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@co AND ContentID=@id AND CreateBy=@user AND StatusCode IN(N'DRAFT',N'RETURNED');
SELECT @@ROWCOUNT;
""";
            await using var q = new SqlCommand(sql, c, tx);
            BindContent(q, company, user, code, input); P(q, "@id", SqlDbType.BigInt, id);
            if (Convert.ToInt32(await q.ExecuteScalarAsync(token)) != 1)
            {
                await tx.RollbackAsync(token);
                return Conflict(new { message = "แก้ไขเนื้อหาไม่ได้", description = "แก้ไขได้เฉพาะฉบับร่างหรือรายการที่ส่งกลับของผู้สร้าง" });
            }
            contentId = id.Value;
            await Execute(c, tx, "DELETE dbo.TDINContentTargetDepartment WHERE CompanyID=@co AND ContentID=@id;DELETE dbo.TDINContentTargetEmployee WHERE CompanyID=@co AND ContentID=@id;", token, ("@co", company), ("@id", contentId));
        }
        foreach (var department in input.DepartmentIDs.Distinct())
            await Execute(c, tx, "INSERT dbo.TDINContentTargetDepartment(CompanyID,ContentID,DepartmentOrgUnitID,CreateBy) VALUES(@co,@id,@target,@user)", token, ("@co", company), ("@id", contentId), ("@target", department), ("@user", user));
        foreach (var employee in input.EmployeeIDs.Distinct())
            await Execute(c, tx, "INSERT dbo.TDINContentTargetEmployee(CompanyID,ContentID,EmployeeID,CreateBy) VALUES(@co,@id,@target,@user)", token, ("@co", company), ("@id", contentId), ("@target", employee), ("@user", user));
        await tx.CommitAsync(token);
        return Ok(new { id = contentId, code, status = "DRAFT" });
    }

    static string? ValidateContent(IntranetContentInput input)
    {
        if (string.IsNullOrWhiteSpace(input.Title)) return "ระบุชื่อเนื้อหา";
        if (!new[] { "NEWS", "ANNOUNCEMENT", "ACTIVITY", "DOCUMENT" }.Contains(input.Type.Trim().ToUpperInvariant())) return "ประเภทเนื้อหาไม่ถูกต้อง";
        if (!new[] { "ALL", "DEPARTMENT", "EMPLOYEE" }.Contains(input.TargetMode.Trim().ToUpperInvariant())) return "รูปแบบกลุ่มเป้าหมายไม่ถูกต้อง";
        if (input.ExpireAt is not null && input.PublishAt >= input.ExpireAt) return "วันเวลาสิ้นสุดต้องมากกว่าวันเวลาเผยแพร่";
        if (input.TargetMode.Equals("DEPARTMENT", StringComparison.OrdinalIgnoreCase) && input.DepartmentIDs.Count == 0) return "เลือกแผนกอย่างน้อย 1 รายการ";
        if (input.TargetMode.Equals("EMPLOYEE", StringComparison.OrdinalIgnoreCase) && input.EmployeeIDs.Count == 0) return "เลือกพนักงานอย่างน้อย 1 รายการ";
        return null;
    }

    static void BindContent(SqlCommand q, long company, long user, string code, IntranetContentInput input)
    {
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@user", SqlDbType.BigInt, user);
        P(q, "@code", SqlDbType.NVarChar, code, 40); P(q, "@type", SqlDbType.NVarChar, input.Type.Trim().ToUpperInvariant(), 20);
        P(q, "@title", SqlDbType.NVarChar, input.Title.Trim(), 250); P(q, "@summary", SqlDbType.NVarChar, Clean(input.Summary), 1000);
        P(q, "@body", SqlDbType.NVarChar, Clean(input.Body)); P(q, "@url", SqlDbType.NVarChar, Clean(input.SourceUrl), 1000);
        P(q, "@target", SqlDbType.NVarChar, input.TargetMode.Trim().ToUpperInvariant(), 20);
        P(q, "@pinned", SqlDbType.Bit, input.IsPinned); P(q, "@ack", SqlDbType.Bit, input.RequiresAcknowledgement);
        P(q, "@publish", SqlDbType.DateTime2, input.PublishAt); P(q, "@expire", SqlDbType.DateTime2, input.ExpireAt);
        P(q, "@approver", SqlDbType.BigInt, input.ApproverEmployeeID);
    }

    async Task<bool> TargetsValid(SqlConnection c, long company, IntranetContentInput input, CancellationToken token)
    {
        foreach (var id in input.EmployeeIDs.Distinct())
            if (!await EmployeeExists(c, company, id, token)) return false;
        foreach (var id in input.DepartmentIDs.Distinct())
        {
            await using var q = new SqlCommand("SELECT COUNT(*) FROM dbo.TDADOrganizationUnit WHERE CompanyID=@co AND OrgUnitID=@id AND UnitType=N'DEP' AND IsActive=1", c);
            P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id);
            if (Convert.ToInt32(await q.ExecuteScalarAsync(token)) != 1) return false;
        }
        return true;
    }

    async Task EnsureSettings(SqlConnection c, long company, long user, CancellationToken token)
    {
        await using var q = new SqlCommand("""
IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanySetupSystemIntranet WHERE CompanyID=@co)
 INSERT dbo.TDSTCompanySetupSystemIntranet(CompanyID,ProjectID,CreateBy)
 SELECT @co,ProjectID,@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_INTRANET' AND IsActive=1;
""", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@user", SqlDbType.BigInt, user);
        await q.ExecuteNonQueryAsync(token);
    }

    async Task<bool> EmployeeExists(SqlConnection c, long company, long id, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT COUNT(*) FROM dbo.TDADEmployee WHERE CompanyID=@co AND EmployeeID=@id AND IsActive=1", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id);
        return Convert.ToInt32(await q.ExecuteScalarAsync(token)) == 1;
    }

    async Task<long?> CurrentEmployee(SqlConnection c, long company, long user, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT TOP(1) EmployeeID FROM dbo.TDADUserEmployee WHERE CompanyID=@co AND UserID=@user AND IsActive=1 ORDER BY UserEmployeeID", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@user", SqlDbType.BigInt, user);
        var value = await q.ExecuteScalarAsync(token);
        return value is null or DBNull ? null : Convert.ToInt64(value);
    }

    async Task<long?> CurrentDepartment(SqlConnection c, long company, long? employee, CancellationToken token)
    {
        if (employee is null) return null;
        await using var q = new SqlCommand("""
SELECT TOP(1) COALESCE(a.DepartmentOrgUnitID,e.DepartmentOrgUnitID)
FROM dbo.TDADEmployee e
OUTER APPLY(SELECT TOP(1) x.DepartmentOrgUnitID FROM dbo.TDADEmployeeOrganizationAssignment x
 WHERE x.CompanyID=e.CompanyID AND x.EmployeeID=e.EmployeeID AND x.IsActive=1
  AND x.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND(x.EffectiveTo IS NULL OR x.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
 ORDER BY x.EffectiveFrom DESC,x.EmployeeOrganizationAssignmentID DESC)a
WHERE e.CompanyID=@co AND e.EmployeeID=@employee AND e.IsActive=1;
""", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@employee", SqlDbType.BigInt, employee);
        var value = await q.ExecuteScalarAsync(token);
        return value is null or DBNull ? null : Convert.ToInt64(value);
    }

    async Task<bool> IsCompanyAdmin(SqlConnection c, long company, long user, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE CompanyID=@co AND UserID=@user AND IsCompanyAdmin=1 AND IsActive=1) THEN 1 ELSE 0 END", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@user", SqlDbType.BigInt, user);
        return Convert.ToBoolean(await q.ExecuteScalarAsync(token));
    }

    Task<bool> Can(SqlConnection c, string menu, string action, CancellationToken token) => CompanyMenuAccess.IsAllowedAsync(c, User, menu, action, token);
    async Task<bool> HasAnyView(SqlConnection c, CancellationToken token) { foreach (var menu in Menus) if (await Can(c, menu, "VIEW", token)) return true; return false; }
    bool Scope(out long company, out long user)
    {
        company = 0; user = 0;
        return string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase)
            && long.TryParse(User.FindFirstValue("company_id"), out company)
            && long.TryParse(User.FindFirstValue("user_id"), out user)
            && company > 0 && user > 0;
    }
    async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    static IActionResult Bad(string message, string description) => new BadRequestObjectResult(new { message, description });
    static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    static void P(SqlCommand q, string name, SqlDbType type, object? value, int size = 0) { var p = size > 0 ? q.Parameters.Add(name, type, size) : q.Parameters.Add(name, type); p.Value = value ?? DBNull.Value; }
    static async Task<int> Execute(SqlConnection c, SqlTransaction tx, string sql, CancellationToken token, params (string, object?)[] values)
    { await using var q = new SqlCommand(sql, c, tx); foreach (var value in values) q.Parameters.AddWithValue(value.Item1, value.Item2 ?? DBNull.Value); return await q.ExecuteNonQueryAsync(token); }
    static async Task<object?> Scalar(SqlConnection c, string sql, long company, CancellationToken token)
    { await using var q = new SqlCommand(sql, c); P(q, "@co", SqlDbType.BigInt, company); return await q.ExecuteScalarAsync(token); }
    static async Task<List<Dictionary<string, object?>>> Rows(SqlCommand q, CancellationToken token)
    { var list = new List<Dictionary<string, object?>>(); await using var r = await q.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) { var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase); for (var i = 0; i < r.FieldCount; i++) row[r.GetName(i)] = r.IsDBNull(i) ? null : r.GetValue(i); list.Add(row); } return list; }
    static async Task<Dictionary<string, object>> Multi(SqlCommand q, CancellationToken token, string[] names)
    { var result = new Dictionary<string, object>(); await using var r = await q.ExecuteReaderAsync(token); var index = 0; do { var list = new List<Dictionary<string, object?>>(); while (await r.ReadAsync(token)) { var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase); for (var i = 0; i < r.FieldCount; i++) row[r.GetName(i)] = r.IsDBNull(i) ? null : r.GetValue(i); list.Add(row); } result[names[index++]] = list; } while (index < names.Length && await r.NextResultAsync(token)); return result; }
}

public sealed record IntranetSettingsInput(bool IsEnabled, bool RequireApproval, bool AllowSelfApproval, long? DefaultApproverEmployeeID, int DefaultPublishDays);
public sealed record IntranetContentInput(string? Code, string Type, string Title, string? Summary, string? Body, string? SourceUrl, string TargetMode, bool IsPinned, bool RequiresAcknowledgement, DateTime PublishAt, DateTime? ExpireAt, long? ApproverEmployeeID, List<long> DepartmentIDs, List<long> EmployeeIDs);
public sealed record IntranetDecisionInput(string Action, string? Reason);
public sealed record IntranetReceiptInput(bool Acknowledge);
