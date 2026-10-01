using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooSurveyModule.Controllers;

public sealed partial class SurveyController
{
    async Task<IActionResult> Read(string menu, string sql, CancellationToken token)
    {
        if (!Scope(out var company, out _)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, menu, "VIEW", token)) return Forbid();
        return Ok(await Query(c, sql, company, token));
    }

    async Task<IActionResult> StatusAction(long id, string menu, string action, string sql, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, menu, action, token)) return Forbid();
        await using var q = new SqlCommand(sql + ";SELECT @@ROWCOUNT", c);
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id); P(q, "@user", SqlDbType.BigInt, user);
        if (Convert.ToInt32(await q.ExecuteScalarAsync(token)) == 0)
            return Conflict(new { message = "เปลี่ยนสถานะไม่ได้", description = "สถานะปัจจุบันไม่รองรับคำสั่งนี้" });
        return NoContent();
    }

    async Task EnsureSettings(SqlConnection c, long company, long user, CancellationToken token)
    {
        const string sql = "IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanySetupSystemSurvey WHERE CompanyID=@co) INSERT dbo.TDSTCompanySetupSystemSurvey(CompanyID,ProjectID,CreateBy) SELECT @co,ProjectID,@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SURVEY'";
        await using var q = new SqlCommand(sql, c); P(q, "@co", SqlDbType.BigInt, company); P(q, "@user", SqlDbType.BigInt, user); await q.ExecuteNonQueryAsync(token);
    }

    async Task<bool> TargetsValid(SqlConnection c, long company, SurveyTargetInput input, CancellationToken token)
    {
        foreach (var id in input.EmployeeIDs.Distinct()) if (!await EmployeeExists(c, company, id, token)) return false;
        foreach (var id in input.DepartmentIDs.Distinct())
        {
            await using var q = new SqlCommand("SELECT COUNT(*) FROM dbo.TDADOrganizationUnit WHERE CompanyID=@co AND OrgUnitID=@id AND UnitType=N'DEP' AND IsActive=1", c);
            P(q, "@co", SqlDbType.BigInt, company); P(q, "@id", SqlDbType.BigInt, id);
            if (Convert.ToInt32(await q.ExecuteScalarAsync(token)) == 0) return false;
        }
        return true;
    }

    static string? ValidateDocument(SurveyInput input)
    {
        if (string.IsNullOrWhiteSpace(input.Name)) return "ระบุชื่อแบบสอบถาม";
        if (input.OpenAt >= input.CloseAt) return "วันเวลาเปิดต้องน้อยกว่าวันเวลาปิด";
        if (input.Questions.Count == 0) return "เพิ่มคำถามอย่างน้อย 1 ข้อ";
        foreach (var question in input.Questions)
        {
            var type = question.Type.Trim().ToUpperInvariant();
            if (string.IsNullOrWhiteSpace(question.Text) || !new[] { "SINGLE", "MULTI", "SCALE", "TEXT", "YES_NO" }.Contains(type)) return "คำถามหรือประเภทคำถามไม่ถูกต้อง";
            if (type is "SINGLE" or "MULTI" && (question.Options?.Count ?? 0) < 2) return "คำถามแบบตัวเลือกต้องมีอย่างน้อย 2 ตัวเลือก";
            if (type == "SCALE" && (question.MinValue is null || question.MaxValue is null || question.MinValue >= question.MaxValue)) return "คำถามคะแนนต้องกำหนดค่าต่ำสุดน้อยกว่าค่าสูงสุด";
        }
        return null;
    }

    static void BindHeader(SqlCommand q, long company, long user, long? id, string code, SurveyInput input)
    {
        P(q, "@co", SqlDbType.BigInt, company); P(q, "@user", SqlDbType.BigInt, user); P(q, "@id", SqlDbType.BigInt, id);
        P(q, "@code", SqlDbType.NVarChar, code, 40); P(q, "@name", SqlDbType.NVarChar, input.Name.Trim(), 250);
        P(q, "@description", SqlDbType.NVarChar, Clean(input.Description), 2000); P(q, "@open", SqlDbType.DateTime2, input.OpenAt);
        P(q, "@close", SqlDbType.DateTime2, input.CloseAt); P(q, "@anonymous", SqlDbType.Bit, input.IsAnonymous);
        P(q, "@show", SqlDbType.Bit, input.ShowResultAfterClose); P(q, "@approver", SqlDbType.BigInt, input.ApproverEmployeeID);
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
        var value = await q.ExecuteScalarAsync(token); return value is null or DBNull ? null : Convert.ToInt64(value);
    }

    Task<bool> Can(SqlConnection c, string menu, string action, CancellationToken token) => CompanyMenuAccess.IsAllowedAsync(c, User, menu, action, token);
    async Task<bool> HasAnyView(SqlConnection c, CancellationToken token) { foreach (var menu in Menus) if (await Can(c, menu, "VIEW", token)) return true; return false; }
    bool Scope(out long company, out long user)
    {
        company = 0; user = 0;
        return User.FindFirstValue("user_type") == "COMPANY_USER"
            && string.Equals(User.FindFirstValue("project_code"), "LAOO_SURVEY", StringComparison.OrdinalIgnoreCase)
            && long.TryParse(User.FindFirstValue("company_id"), out company)
            && long.TryParse(User.FindFirstValue("user_id"), out user);
    }
    async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    static IActionResult Bad(string message, string description) => new BadRequestObjectResult(new { message, description });
    static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    static void P(SqlCommand q, string name, SqlDbType type, object? value, int size = 0) { var p = q.Parameters.Add(name, type); if (size > 0) p.Size = size; p.Value = value ?? DBNull.Value; }

    static async Task<int> Execute(SqlConnection c, SqlTransaction tx, string sql, CancellationToken token, params (string, object?)[] values)
    { await using var q = new SqlCommand(sql, c, tx); foreach (var value in values) q.Parameters.AddWithValue(value.Item1, value.Item2 ?? DBNull.Value); return await q.ExecuteNonQueryAsync(token); }
    static async Task<object?> Scalar(SqlConnection c, SqlTransaction tx, string sql, CancellationToken token, params (string, object?)[] values)
    { await using var q = new SqlCommand(sql, c, tx); foreach (var value in values) q.Parameters.AddWithValue(value.Item1, value.Item2 ?? DBNull.Value); return await q.ExecuteScalarAsync(token); }
    static async Task<List<Dictionary<string, object?>>> Query(SqlConnection c, string sql, long company, CancellationToken token)
    { await using var q = new SqlCommand(sql, c); P(q, "@co", SqlDbType.BigInt, company); return await ReadRows(q, token); }
    static async Task<List<Dictionary<string, object?>>> Query(SqlConnection c, SqlTransaction tx, string sql, CancellationToken token, params (string, object?)[] values)
    { await using var q = new SqlCommand(sql, c, tx); foreach (var value in values) q.Parameters.AddWithValue(value.Item1, value.Item2 ?? DBNull.Value); return await ReadRows(q, token); }
    static async Task<List<Dictionary<string, object?>>> ReadRows(SqlCommand q, CancellationToken token)
    { var list = new List<Dictionary<string, object?>>(); await using var r = await q.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) { var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase); for (var i = 0; i < r.FieldCount; i++) row[r.GetName(i)] = r.IsDBNull(i) ? null : r.GetValue(i); list.Add(row); } return list; }
    static async Task<Dictionary<string, object>> Multi(SqlCommand q, CancellationToken token, string[] names)
    { var result = new Dictionary<string, object>(); await using var r = await q.ExecuteReaderAsync(token); var index = 0; do { var list = new List<Dictionary<string, object?>>(); while (await r.ReadAsync(token)) { var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase); for (var i = 0; i < r.FieldCount; i++) row[r.GetName(i)] = r.IsDBNull(i) ? null : r.GetValue(i); list.Add(row); } result[names[index++]] = list; } while (index < names.Length && await r.NextResultAsync(token)); return result; }
}

public sealed record SurveySettingsInput(bool IsEnabled, int DefaultDurationDays, bool RequireApproval, bool DefaultAnonymous, bool ResultsAfterClose, long? DefaultApproverEmployeeID);
public sealed record SurveyInput(string? Code, string Name, string? Description, DateTime OpenAt, DateTime CloseAt, bool IsAnonymous, bool ShowResultAfterClose, long? ApproverEmployeeID, List<SurveyQuestionInput> Questions);
public sealed record SurveyQuestionInput(string Text, string Type, bool Required, int? MinValue, int? MaxValue, List<string>? Options);
public sealed record SurveyDecisionInput(string Action, string? Reason);
public sealed record SurveyTargetInput(string Mode, List<long> DepartmentIDs, List<long> EmployeeIDs);
public sealed record SurveyResponseInput(List<SurveyAnswerInput> Answers);
public sealed record SurveyAnswerInput(long QuestionID, string? TextValue, decimal? NumberValue, List<long> OptionIDs);
