using System.Data;
using System.Security.Cryptography;
using System.Security.Claims;
using System.Text;
using System.Xml.Linq;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Route("api/time/payroll-exports")]
[Authorize]
public sealed record PayrollExportGenerateRequest(long AttendancePeriodId, long ProfileId);
public sealed record PayrollExportProfileRequest(string ProfileCode, string ProfileName, string FormatCode, string? DelimiterCode, string? EncodingCode, bool IncludeHeader, string? DateFormat, string? ColumnMapJson, string? RowVersion);

public sealed class PayrollExportsController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private const string ProfilesMenu = "28013";
    private const string ExportMenu = "25003";
    private const string HistoryMenu = "25004";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions([FromQuery] string menuCode, CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid();
        var menu = menuCode switch { ProfilesMenu => ProfilesMenu, ExportMenu => ExportMenu, HistoryMenu => HistoryMenu, _ => null };
        if (menu is null) return BadRequest(new { message = "เมนู Export Payroll ไม่ถูกต้อง" });
        await using var c = await Open(token);
        return Ok(new { menuCode = menu, caption = await Caption(c, menu, token), screenType = menu == ProfilesMenu ? 1 : menu == ExportMenu ? 4 : 3, view = await Can(c, menu, "VIEW", token) });
    }

    [HttpGet("profiles")]
    public async Task<IActionResult> Profiles(CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, ProfilesMenu, "VIEW", token)) return Forbid();
        await using var q = new SqlCommand("SELECT PayrollExportProfileID,ProfileCode,ProfileName,FormatCode,DelimiterCode,EncodingCode,IncludeHeader,DateFormat,ColumnMapJson,IsActive,CONVERT(varchar(32),RowVersion,2) FROM dbo.TDTMPayrollExportProfile WHERE CompanyID=@C ORDER BY ProfileCode", c);
        Add(q, "@C", SqlDbType.BigInt, companyId);
        await using var r = await q.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await r.ReadAsync(token)) items.Add(new { profileId = r.GetInt64(0), profileCode = r.GetString(1), profileName = r.GetString(2), formatCode = r.GetString(3), delimiter = r.GetString(4), encoding = r.GetString(5), includeHeader = r.GetBoolean(6), dateFormat = r.GetString(7), columnMapJson = r.GetString(8), isActive = r.GetBoolean(9), rowVersion = r.GetString(10) });
        return Ok(new { items });
    }

    [HttpPost("profiles")]
    public Task<IActionResult> CreateProfile(PayrollExportProfileRequest request, CancellationToken token) => SaveProfile(null, request, token);

    [HttpPut("profiles/{id:long}")]
    public Task<IActionResult> UpdateProfile(long id, PayrollExportProfileRequest request, CancellationToken token) => SaveProfile(id, request, token);

    [HttpDelete("profiles/{id:long}")]
    public async Task<IActionResult> DeleteProfile(long id, [FromQuery] string rowVersion, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid(); await using var c = await Open(token); if (!await Can(c, ProfilesMenu, "DELETE", token)) return Forbid();
        if (!ValidVersion(rowVersion)) return BadRequest(new { message = "กรุณาโหลดข้อมูลล่าสุดก่อนลบ" });
        await using var q = new SqlCommand("UPDATE dbo.TDTMPayrollExportProfile SET IsActive=0,UpdateDate=SYSDATETIME(),UpdateBy=@U WHERE CompanyID=@C AND PayrollExportProfileID=@ID AND RowVersion=CONVERT(binary(8),@V,2)", c); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@ID", SqlDbType.BigInt, id); Add(q, "@V", SqlDbType.VarChar, rowVersion, 32); Add(q, "@U", SqlDbType.BigInt, userId); return await q.ExecuteNonQueryAsync(token) == 1 ? NoContent() : Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" });
    }

    [HttpGet("periods")]
    public async Task<IActionResult> Periods(CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid(); await using var c = await Open(token); if (!await Can(c, ExportMenu, "VIEW", token)) return Forbid();
        await using var q = new SqlCommand("SELECT AttendancePeriodID,PeriodStartDate,PeriodEndDate,FinalResultVersion FROM dbo.TDTMAttendancePeriod WHERE CompanyID=@C AND PeriodStatusCode='FINALIZED' ORDER BY PeriodEndDate DESC,AttendancePeriodID DESC", c); Add(q, "@C", SqlDbType.BigInt, companyId); await using var r = await q.ExecuteReaderAsync(token); var items = new List<object>(); while (await r.ReadAsync(token)) items.Add(new { periodId = r.GetInt64(0), startDate = DateOnly.FromDateTime(r.GetDateTime(1)), endDate = DateOnly.FromDateTime(r.GetDateTime(2)), finalResultVersion = r.GetInt32(3) }); return Ok(new { items });
    }

    [HttpGet("history")]
    public async Task<IActionResult> History([FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        if (page < 1 || pageSize is < 1 or > 100) return BadRequest(new { message = "Invalid pagination" });
        await using var c = await Open(token);
        if (!await Can(c, HistoryMenu, "VIEW", token)) return Forbid();
        const string where = "FROM dbo.TDTMPayrollExportBatch B JOIN dbo.TDTMAttendancePeriod P ON P.AttendancePeriodID=B.AttendancePeriodID JOIN dbo.TDTMPayrollExportProfile F ON F.PayrollExportProfileID=B.PayrollExportProfileID WHERE B.CompanyID=@C";
        await using var count = new SqlCommand("SELECT COUNT_BIG(1) " + where, c); Add(count, "@C", SqlDbType.BigInt, companyId); var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var q = new SqlCommand("SELECT B.PayrollExportBatchID,B.AttendancePeriodID,P.PeriodStartDate,P.PeriodEndDate,F.ProfileCode,B.FormatCode,B.StatusCode,B.FileName,B.TotalRows,B.GeneratedDate,B.CreateDate " + where + " ORDER BY B.CreateDate DESC,B.PayrollExportBatchID DESC OFFSET @O ROWS FETCH NEXT @T ROWS ONLY", c);
        Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@O", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@T", SqlDbType.Int, pageSize);
        await using var r = await q.ExecuteReaderAsync(token); var items = new List<object>();
        while (await r.ReadAsync(token)) items.Add(new { batchId = r.GetInt64(0), attendancePeriodId = r.GetInt64(1), periodStartDate = DateOnly.FromDateTime(r.GetDateTime(2)), periodEndDate = DateOnly.FromDateTime(r.GetDateTime(3)), profileCode = r.GetString(4), formatCode = r.GetString(5), statusCode = r.GetString(6), fileName = r.IsDBNull(7) ? null : r.GetString(7), totalRows = r.GetInt32(8), generatedDate = r.IsDBNull(9) ? (DateTime?)null : r.GetDateTime(9), createDate = r.GetDateTime(10) });
        return Ok(new { total, page, pageSize, items });
    }

    [HttpPost("generate")]
    public async Task<IActionResult> Generate(PayrollExportGenerateRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        if (request.AttendancePeriodId <= 0 || request.ProfileId <= 0) return BadRequest(new { message = "กรุณาระบุงวดและรูปแบบ Export" });
        await using var c = await Open(token);
        if (!await Can(c, ExportMenu, "CREATE", token)) return Forbid();
        var profile = await LoadProfile(c, companyId, request.ProfileId, token);
        if (profile is null) return NotFound(new { message = "ไม่พบรูปแบบ Export" });
        var period = await LoadPeriod(c, companyId, request.AttendancePeriodId, token);
        if (period is null || period.Status != "FINALIZED") return Conflict(new { message = "ส่งออกได้เฉพาะงวดที่ปิดแล้ว" });
        const string unresolvedSql = "SELECT COUNT_BIG(1) FROM dbo.TDTMAttendanceResult WHERE CompanyID=@C AND WorkDate BETWEEN @F AND @T AND IsCurrent=1 AND StatusCode='UNRESOLVED'";
        await using var unresolved = new SqlCommand(unresolvedSql, c); Add(unresolved, "@C", SqlDbType.BigInt, companyId); Add(unresolved, "@F", SqlDbType.Date, period.Start.ToDateTime(TimeOnly.MinValue)); Add(unresolved, "@T", SqlDbType.Date, period.End.ToDateTime(TimeOnly.MinValue));
        if (Convert.ToInt64(await unresolved.ExecuteScalarAsync(token)) > 0) return Conflict(new { message = "ยังมีผลลงเวลาที่รอตรวจสอบ ไม่สามารถส่งออกได้" });
        var rows = await SummaryRows(c, companyId, period.Start, period.End, token);
        if (rows.Count == 0) return Conflict(new { message = "ไม่พบผลลงเวลาในงวดที่เลือก" });
        var batchId = 0L;
        await using (var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token))
        {
            try
            {
                await using var insert = new SqlCommand("INSERT dbo.TDTMPayrollExportBatch(CompanyID,AttendancePeriodID,FinalResultVersion,PayrollExportProfileID,FormatCode,StatusCode,TotalRows,CreateBy) OUTPUT INSERTED.PayrollExportBatchID VALUES(@C,@P,@V,@F,@Format,'PREVIEW',@N,@U)", c, tx);
                Add(insert, "@C", SqlDbType.BigInt, companyId); Add(insert, "@P", SqlDbType.BigInt, request.AttendancePeriodId); Add(insert, "@V", SqlDbType.Int, period.FinalVersion); Add(insert, "@F", SqlDbType.BigInt, request.ProfileId); Add(insert, "@Format", SqlDbType.VarChar, profile.Format); Add(insert, "@N", SqlDbType.Int, rows.Count); Add(insert, "@U", SqlDbType.BigInt, userId); batchId = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
                foreach (var row in rows)
                {
                    await using var detail = new SqlCommand("INSERT dbo.TDTMPayrollExportBatchRow(PayrollExportBatchID,CompanyID,EmployeeID,EmployeeCode,FullName,WorkDayCount,CompleteDayCount,UnresolvedDayCount,LeaveDayCount,ScheduledWorkMinutes,ActualWorkMinutes,LateMinutes,EarlyMinutes) VALUES(@B,@C,@E,@Code,@Name,@Days,@Complete,@Unresolved,@Leave,@Scheduled,@Actual,@Late,@Early)", c, tx);
                    Add(detail, "@B", SqlDbType.BigInt, batchId); Add(detail, "@C", SqlDbType.BigInt, companyId); Add(detail, "@E", SqlDbType.BigInt, row.EmployeeId); Add(detail, "@Code", SqlDbType.NVarChar, row.EmployeeCode, 100); Add(detail, "@Name", SqlDbType.NVarChar, row.FullName, 300); Add(detail, "@Days", SqlDbType.Int, row.WorkDays); Add(detail, "@Complete", SqlDbType.Int, row.CompleteDays); Add(detail, "@Unresolved", SqlDbType.Int, row.UnresolvedDays); Add(detail, "@Leave", SqlDbType.Int, row.LeaveDays); Add(detail, "@Scheduled", SqlDbType.Int, row.ScheduledMinutes); Add(detail, "@Actual", SqlDbType.Int, row.ActualMinutes); Add(detail, "@Late", SqlDbType.Int, row.LateMinutes); Add(detail, "@Early", SqlDbType.Int, row.EarlyMinutes); await detail.ExecuteNonQueryAsync(token);
                }
                await tx.CommitAsync(token);
            }
            catch { await tx.RollbackAsync(token); throw; }
        }
        var fileName = $"payroll-{companyId}-{request.AttendancePeriodId}-{batchId}.{(profile.Format == "EXCEL" ? "xls" : "txt")}";
        var relative = $"uploads/payroll/{companyId}/{batchId}/{fileName}";
        var fullPath = Path.Combine(environment.ContentRootPath, "wwwroot", relative.Replace('/', Path.DirectorySeparatorChar));
        Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
        var content = profile.Format == "EXCEL" ? ExcelXml(rows) : TextFile(rows, profile.Delimiter, profile.IncludeHeader);
        await System.IO.File.WriteAllTextAsync(fullPath, content, new UTF8Encoding(profile.Encoding == "UTF8_BOM"), token);
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(content));
        await using var update = new SqlCommand("UPDATE dbo.TDTMPayrollExportBatch SET StatusCode='GENERATED',FileName=@N,FileRelativePath=@Path,ContentHash=@Hash,GeneratedDate=SYSDATETIME(),GeneratedBy=@U WHERE CompanyID=@C AND PayrollExportBatchID=@B", c); Add(update, "@N", SqlDbType.NVarChar, fileName, 260); Add(update, "@Path", SqlDbType.NVarChar, relative, 500); Add(update, "@Hash", SqlDbType.VarBinary, hash, 32); Add(update, "@U", SqlDbType.BigInt, userId); Add(update, "@C", SqlDbType.BigInt, companyId); Add(update, "@B", SqlDbType.BigInt, batchId); await update.ExecuteNonQueryAsync(token);
        return Ok(new { batchId, fileName, statusCode = "GENERATED", totalRows = rows.Count });
    }

    [HttpGet("{batchId:long}/download")]
    public async Task<IActionResult> Download(long batchId, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var c = await Open(token); if (!await Can(c, HistoryMenu, "DOWNLOAD", token)) return Forbid();
        await using var q = new SqlCommand("SELECT FileName,FileRelativePath FROM dbo.TDTMPayrollExportBatch WHERE CompanyID=@C AND PayrollExportBatchID=@B AND StatusCode='GENERATED'", c); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@B", SqlDbType.BigInt, batchId); await using var r = await q.ExecuteReaderAsync(token); if (!await r.ReadAsync(token)) return NotFound(); var name = r.GetString(0); var relative = r.GetString(1); await r.CloseAsync();
        var root = Path.GetFullPath(Path.Combine(environment.ContentRootPath, "wwwroot", "uploads", "payroll", companyId.ToString())); var path = Path.GetFullPath(Path.Combine(environment.ContentRootPath, "wwwroot", relative.Replace('/', Path.DirectorySeparatorChar))); if (!path.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || !System.IO.File.Exists(path)) return NotFound(); return PhysicalFile(path, "application/octet-stream", name);
    }

    private sealed record ProfileData(string Format, string Delimiter, string Encoding, bool IncludeHeader);
    private sealed record PeriodData(DateOnly Start, DateOnly End, string Status, int FinalVersion);
    private sealed record SummaryRow(long EmployeeId, string EmployeeCode, string FullName, int WorkDays, int CompleteDays, int UnresolvedDays, int LeaveDays, int ScheduledMinutes, int ActualMinutes, int LateMinutes, int EarlyMinutes);

    private async Task<IActionResult> SaveProfile(long? id, PayrollExportProfileRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var code = request.ProfileCode?.Trim(); var name = request.ProfileName?.Trim(); var format = request.FormatCode?.Trim().ToUpperInvariant();
        if (string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(name) || format is not ("EXCEL" or "TEXT") || (id.HasValue && !ValidVersion(request.RowVersion))) return BadRequest(new { message = "ข้อมูลรูปแบบ Export ไม่ถูกต้อง หรือไม่มี RowVersion" });
        await using var c = await Open(token); if (!await Can(c, ProfilesMenu, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        var sql = id.HasValue ? "UPDATE dbo.TDTMPayrollExportProfile SET ProfileCode=@Code,ProfileName=@Name,FormatCode=@Format,DelimiterCode=@Delimiter,EncodingCode=@Encoding,IncludeHeader=@Header,DateFormat=@Date,ColumnMapJson=@Columns,IsActive=1,UpdateDate=SYSDATETIME(),UpdateBy=@U WHERE CompanyID=@C AND PayrollExportProfileID=@ID AND RowVersion=CONVERT(binary(8),@V,2)" : "INSERT dbo.TDTMPayrollExportProfile(CompanyID,ProfileCode,ProfileName,FormatCode,DelimiterCode,EncodingCode,IncludeHeader,DateFormat,ColumnMapJson,CreateBy) VALUES(@C,@Code,@Name,@Format,@Delimiter,@Encoding,@Header,@Date,@Columns,@U)";
        await using var q = new SqlCommand(sql, c); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@Code", SqlDbType.VarChar, code, 50); Add(q, "@Name", SqlDbType.NVarChar, name, 200); Add(q, "@Format", SqlDbType.VarChar, format, 20); Add(q, "@Delimiter", SqlDbType.VarChar, string.IsNullOrWhiteSpace(request.DelimiterCode) ? "|" : request.DelimiterCode.Trim(), 10); Add(q, "@Encoding", SqlDbType.VarChar, string.IsNullOrWhiteSpace(request.EncodingCode) ? "UTF8" : request.EncodingCode.Trim().ToUpperInvariant(), 20); Add(q, "@Header", SqlDbType.Bit, request.IncludeHeader); Add(q, "@Date", SqlDbType.VarChar, string.IsNullOrWhiteSpace(request.DateFormat) ? "yyyy-MM-dd" : request.DateFormat.Trim(), 30); Add(q, "@Columns", SqlDbType.NVarChar, string.IsNullOrWhiteSpace(request.ColumnMapJson) ? "[]" : request.ColumnMapJson.Trim(), -1); Add(q, "@U", SqlDbType.BigInt, userId); if (id.HasValue) { Add(q, "@ID", SqlDbType.BigInt, id); Add(q, "@V", SqlDbType.VarChar, request.RowVersion, 32); } try { if (await q.ExecuteNonQueryAsync(token) != 1) return Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" }); } catch (SqlException e) when (e.Number is 2601 or 2627) { return Conflict(new { message = "รหัส Profile ซ้ำในบริษัท" }); } return NoContent();
    }

    private static async Task<ProfileData?> LoadProfile(SqlConnection c, long company, long id, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT FormatCode,DelimiterCode,EncodingCode,IncludeHeader FROM dbo.TDTMPayrollExportProfile WHERE CompanyID=@C AND PayrollExportProfileID=@ID AND IsActive=1", c); Add(q, "@C", SqlDbType.BigInt, company); Add(q, "@ID", SqlDbType.BigInt, id); await using var r = await q.ExecuteReaderAsync(token); return await r.ReadAsync(token) ? new ProfileData(r.GetString(0), r.GetString(1), r.GetString(2), r.GetBoolean(3)) : null;
    }

    private static async Task<PeriodData?> LoadPeriod(SqlConnection c, long company, long id, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT PeriodStartDate,PeriodEndDate,PeriodStatusCode,FinalResultVersion FROM dbo.TDTMAttendancePeriod WHERE CompanyID=@C AND AttendancePeriodID=@ID", c); Add(q, "@C", SqlDbType.BigInt, company); Add(q, "@ID", SqlDbType.BigInt, id); await using var r = await q.ExecuteReaderAsync(token); return await r.ReadAsync(token) ? new PeriodData(DateOnly.FromDateTime(r.GetDateTime(0)), DateOnly.FromDateTime(r.GetDateTime(1)), r.GetString(2), r.GetInt32(3)) : null;
    }

    private static async Task<List<SummaryRow>> SummaryRows(SqlConnection c, long company, DateOnly from, DateOnly to, CancellationToken token)
    {
        const string sql = """
SELECT E.EmployeeID,E.EmployeeCode,E.FullName,COUNT_BIG(1),
       SUM(CASE WHEN R.StatusCode='COMPLETE' THEN 1 ELSE 0 END),
       SUM(CASE WHEN R.StatusCode='UNRESOLVED' THEN 1 ELSE 0 END),
       SUM(CASE WHEN R.StatusCode IN('LEAVE','LEAVE_PARTIAL') THEN 1 ELSE 0 END),
       SUM(R.ScheduledWorkMinutes),SUM(R.ActualWorkMinutes),SUM(R.LateMinutes),SUM(R.EarlyMinutes)
FROM dbo.TDTMAttendanceResult R JOIN dbo.TDADEmployee E ON E.CompanyID=R.CompanyID AND E.EmployeeID=R.EmployeeID
WHERE R.CompanyID=@C AND R.WorkDate BETWEEN @F AND @T AND R.IsCurrent=1
GROUP BY E.EmployeeID,E.EmployeeCode,E.FullName ORDER BY E.EmployeeCode,E.EmployeeID;
""";
        await using var q = new SqlCommand(sql, c); Add(q, "@C", SqlDbType.BigInt, company); Add(q, "@F", SqlDbType.Date, from.ToDateTime(TimeOnly.MinValue)); Add(q, "@T", SqlDbType.Date, to.ToDateTime(TimeOnly.MinValue)); await using var r = await q.ExecuteReaderAsync(token); var rows = new List<SummaryRow>(); while (await r.ReadAsync(token)) rows.Add(new(r.GetInt64(0), r.GetString(1), r.GetString(2), Convert.ToInt32(r.GetInt64(3)), r.GetInt32(4), r.GetInt32(5), r.GetInt32(6), r.GetInt32(7), r.GetInt32(8), r.GetInt32(9), r.GetInt32(10))); return rows;
    }

    private static string TextFile(IReadOnlyList<SummaryRow> rows, string delimiter, bool header)
    {
        var lines = new List<string>(); if (header) lines.Add(string.Join(delimiter, new[] { "EmployeeCode", "FullName", "WorkDayCount", "CompleteDayCount", "UnresolvedDayCount", "LeaveDayCount", "ScheduledWorkMinutes", "ActualWorkMinutes", "LateMinutes", "EarlyMinutes" })); foreach (var r in rows) lines.Add(string.Join(delimiter, new[] { r.EmployeeCode, r.FullName, r.WorkDays.ToString(), r.CompleteDays.ToString(), r.UnresolvedDays.ToString(), r.LeaveDays.ToString(), r.ScheduledMinutes.ToString(), r.ActualMinutes.ToString(), r.LateMinutes.ToString(), r.EarlyMinutes.ToString() }.Select(x => TextCell(x, delimiter)))); return string.Join(Environment.NewLine, lines) + Environment.NewLine;
    }

    private static string TextCell(string value, string delimiter) => value.Contains(delimiter) || value.Contains('"') || value.Contains('\r') || value.Contains('\n') ? '"' + value.Replace("\"", "\"\"") + '"' : value;

    private static string ExcelXml(IReadOnlyList<SummaryRow> rows)
    {
        XNamespace ss = "urn:schemas-microsoft-com:office:spreadsheet";
        var document = new XDocument(new XDeclaration("1.0", "UTF-8", "yes"), new XElement("Workbook", new XAttribute(XNamespace.Xmlns + "ss", ss.NamespaceName), new XAttribute(XNamespace.Xmlns + "x", "urn:schemas-microsoft-com:office:excel"), new XElement("Worksheet", new XAttribute(ss + "Name", "Payroll"), new XElement("Table", new XElement("Row", HeaderCells(ss)), rows.Select(r => new XElement("Row", Cells(r, ss)))))));
        return document.ToString(SaveOptions.DisableFormatting);
    }

    private static IEnumerable<XElement> HeaderCells(XNamespace ss) => new[] { "EmployeeCode", "FullName", "WorkDayCount", "CompleteDayCount", "UnresolvedDayCount", "LeaveDayCount", "ScheduledWorkMinutes", "ActualWorkMinutes", "LateMinutes", "EarlyMinutes" }.Select(x => Cell(x, ss));
    private static IEnumerable<XElement> Cells(SummaryRow r, XNamespace ss) => new[] { r.EmployeeCode, r.FullName, r.WorkDays.ToString(), r.CompleteDays.ToString(), r.UnresolvedDays.ToString(), r.LeaveDays.ToString(), r.ScheduledMinutes.ToString(), r.ActualMinutes.ToString(), r.LateMinutes.ToString(), r.EarlyMinutes.ToString() }.Select(x => Cell(x, ss));
    private static XElement Cell(string value, XNamespace ss) => new("Cell", new XElement("Data", new XAttribute(ss + "Type", int.TryParse(value, out _) ? "Number" : "String"), value));

    private async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private bool Scope(out long company, out long user) { company = 0; user = 0; return string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase) && long.TryParse(User.FindFirstValue("company_id"), out company) && long.TryParse(User.FindFirstValue("user_id"), out user) && company > 0 && user > 0; }
    private Task<bool> Can(SqlConnection c, string menu, string action, CancellationToken token) => CompanyMenuAccess.IsAllowedAsync(c, User, menu, action, token);
    private static async Task<string> Caption(SqlConnection c, string menu, CancellationToken token) { await using var q = new SqlCommand("SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@M", c); Add(q, "@M", SqlDbType.Char, menu, 5); return Convert.ToString(await q.ExecuteScalarAsync(token)) ?? menu; }
    private static void Add(SqlCommand q, string name, SqlDbType type, object? value, int size = 0) { var p = size == 0 ? q.Parameters.Add(name, type) : q.Parameters.Add(name, type, size); p.Value = value ?? DBNull.Value; }
    private static bool ValidVersion(string? value) => value is { Length: 16 } && value.All(Uri.IsHexDigit);
}
