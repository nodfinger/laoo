using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Authorize]
[Route("api/time/holiday-calendars")]
public sealed class HolidayCalendarsController(IConfiguration configuration) : ControllerBase
{
    private const string CalendarMenu = "28005";
    private const string DateMenu = "28006";
    private const string AssignmentMenu = "28007";
    private const string ExceptionMenu = "28008";

    public sealed record CalendarRequest(string CalendarCode, string CalendarName, string? DescriptionText, bool IsActive, string? RowVersion);
    public sealed record HolidayDateRequest(long HolidayCalendarId, DateOnly HolidayDate, string HolidayName, bool IsActive, string? RowVersion);
    public sealed record AssignmentRequest(long BranchId, long HolidayCalendarId, DateOnly EffectiveFrom, DateOnly? EffectiveTo, bool IsActive, string? RowVersion);
    public sealed record ExceptionRequest(long BranchId, DateOnly HolidayDate, bool IsHoliday, string? HolidayName, string? Reason, bool IsActive, string? RowVersion);

    [HttpGet("actions")]
    public Task<IActionResult> CalendarActions(CancellationToken token) => Actions(CalendarMenu, 1, token);
    [HttpGet("dates/actions")]
    public Task<IActionResult> DateActions(CancellationToken token) => Actions(DateMenu, 1, token);
    [HttpGet("assignments/actions")]
    public Task<IActionResult> AssignmentActions(CancellationToken token) => Actions(AssignmentMenu, 1, token);
    [HttpGet("exceptions/actions")]
    public Task<IActionResult> ExceptionActions(CancellationToken token) => Actions(ExceptionMenu, 1, token);

    [HttpGet]
    public async Task<IActionResult> Calendars([FromQuery] string? search, [FromQuery] bool? isActive, [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        if (!Page(page, pageSize)) return BadRequest(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง" });
        await using var c = await Open(token); if (!await Can(c, CalendarMenu, "VIEW", token)) return Forbid();
        var where = "FROM dbo.TDTMHolidayCalendar WHERE CompanyID=@CompanyID AND (@Search IS NULL OR CalendarCode LIKE N'%'+@Search+N'%' OR CalendarName LIKE N'%'+@Search+N'%') AND (@Active IS NULL OR IsActive=@Active)";
        await using var count = new SqlCommand($"SELECT COUNT_BIG(1) {where}", c); Bind(count, companyId, search, isActive);
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var q = new SqlCommand($"SELECT HolidayCalendarID,CalendarCode,CalendarName,DescriptionText,IsActive,CONVERT(varchar(32),RowVersion,2) {where} ORDER BY CalendarCode OFFSET @Offset ROWS FETCH NEXT @Take ROWS ONLY", c);
        Bind(q, companyId, search, isActive); Add(q, "@Offset", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@Take", SqlDbType.Int, pageSize);
        await using var r = await q.ExecuteReaderAsync(token); var items = new List<object>();
        while (await r.ReadAsync(token)) items.Add(new { holidayCalendarId = r.GetInt64(0), calendarCode = r.GetString(1), calendarName = r.GetString(2), descriptionText = Text(r, 3), isActive = r.GetBoolean(4), rowVersion = r.GetString(5) });
        return Ok(new { total, page, pageSize, items });
    }

    [HttpPost]
    public Task<IActionResult> CreateCalendar(CalendarRequest request, CancellationToken token) => SaveCalendar(null, request, token);
    [HttpPut("{id:long}")]
    public Task<IActionResult> UpdateCalendar(long id, CalendarRequest request, CancellationToken token) => SaveCalendar(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> DeleteCalendar(long id, [FromQuery] string? rowVersion, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        if (!RowVersion(rowVersion)) return BadRequest(new { message = "ไม่พบ Version ของข้อมูล กรุณาโหลดใหม่" });
        await using var c = await Open(token); if (!await Can(c, CalendarMenu, "DELETE", token)) return Forbid();
        await using var q = new SqlCommand("""
IF EXISTS(SELECT 1 FROM dbo.TDTMHolidayDate WHERE CompanyID=@CompanyID AND HolidayCalendarID=@ID AND IsActive=1)
 OR EXISTS(SELECT 1 FROM dbo.TDTMBranchHolidayCalendarAssignment WHERE CompanyID=@CompanyID AND HolidayCalendarID=@ID AND IsActive=1)
 OR EXISTS(SELECT 1 FROM dbo.TDTMDefaultHolidayCalendarVersion WHERE CompanyID=@CompanyID AND HolidayCalendarID=@ID AND IsActive=1)
 THROW 52601,N'ปฏิทินนี้มีวันหยุดหรือถูกผูกใช้งานแล้ว ไม่สามารถลบได้',1;
UPDATE dbo.TDTMHolidayCalendar SET IsActive=0,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND HolidayCalendarID=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2);
""", c);
        Add(q, "@CompanyID", SqlDbType.BigInt, companyId); Add(q, "@ID", SqlDbType.BigInt, id); Add(q, "@UserID", SqlDbType.BigInt, userId); Add(q, "@RowVersion", SqlDbType.VarChar, rowVersion, 32);
        try { return await q.ExecuteNonQueryAsync(token) == 1 ? NoContent() : Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" }); }
        catch (SqlException e) when (e.Number == 52601) { return Conflict(new { message = e.Message }); }
    }

    [HttpGet("dates")]
    public async Task<IActionResult> Dates([FromQuery] long? holidayCalendarId, [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out _)) return Forbid(); if (!holidayCalendarId.HasValue || !Page(page, pageSize)) return BadRequest(new { message = "กรุณาเลือกปฏิทินและระบุหน้าข้อมูลให้ถูกต้อง" });
        await using var c = await Open(token); if (!await Can(c, DateMenu, "VIEW", token)) return Forbid();
        const string where = "FROM dbo.TDTMHolidayDate D JOIN dbo.TDTMHolidayCalendar C ON C.CompanyID=D.CompanyID AND C.HolidayCalendarID=D.HolidayCalendarID WHERE D.CompanyID=@CompanyID AND D.HolidayCalendarID=@CalendarID";
        await using var count = new SqlCommand($"SELECT COUNT_BIG(1) {where}", c); Add(count, "@CompanyID", SqlDbType.BigInt, companyId); Add(count, "@CalendarID", SqlDbType.BigInt, holidayCalendarId); var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var q = new SqlCommand($"SELECT D.HolidayDateID,D.HolidayCalendarID,C.CalendarCode,C.CalendarName,D.HolidayDate,D.HolidayName,D.IsActive,CONVERT(varchar(32),D.RowVersion,2) {where} ORDER BY D.HolidayDate DESC OFFSET @Offset ROWS FETCH NEXT @Take ROWS ONLY", c);
        Add(q, "@CompanyID", SqlDbType.BigInt, companyId); Add(q, "@CalendarID", SqlDbType.BigInt, holidayCalendarId); Add(q, "@Offset", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@Take", SqlDbType.Int, pageSize);
        await using var r = await q.ExecuteReaderAsync(token); var items = new List<object>(); while (await r.ReadAsync(token)) items.Add(new { holidayDateId = r.GetInt64(0), holidayCalendarId = r.GetInt64(1), calendarCode = r.GetString(2), calendarName = r.GetString(3), holidayDate = DateOnly.FromDateTime(r.GetDateTime(4)), holidayName = r.GetString(5), isActive = r.GetBoolean(6), rowVersion = r.GetString(7) });
        return Ok(new { total, page, pageSize, items });
    }

    [HttpPost("dates")]
    public Task<IActionResult> CreateDate(HolidayDateRequest request, CancellationToken token) => SaveDate(null, request, token);
    [HttpPut("dates/{id:long}")]
    public Task<IActionResult> UpdateDate(long id, HolidayDateRequest request, CancellationToken token) => SaveDate(id, request, token);
    [HttpDelete("dates/{id:long}")]
    public Task<IActionResult> DeleteDate(long id, [FromQuery] string? rowVersion, CancellationToken token) => SoftDelete(DateMenu, "TDTMHolidayDate", "HolidayDateID", id, rowVersion, token);

    [HttpGet("branches")]
    public async Task<IActionResult> Branches(CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid(); await using var c = await Open(token);
        if (!await Can(c, AssignmentMenu, "VIEW", token) && !await Can(c, ExceptionMenu, "VIEW", token)) return Forbid();
        await using var q = new SqlCommand("SELECT BranchID,BranchCode,BranchNameTH FROM dbo.TDADBranch WHERE CompanyID=@CompanyID AND IsActive=1 ORDER BY BranchCode", c); Add(q, "@CompanyID", SqlDbType.BigInt, companyId);
        await using var r = await q.ExecuteReaderAsync(token); var items = new List<object>(); while (await r.ReadAsync(token)) items.Add(new { branchId = r.GetInt64(0), branchCode = r.GetString(1), branchName = r.GetString(2) }); return Ok(new { items });
    }

    [HttpGet("assignments")]
    public async Task<IActionResult> Assignments([FromQuery] long? branchId, [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out _)) return Forbid(); if (!Page(page, pageSize)) return BadRequest(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง" }); await using var c = await Open(token); if (!await Can(c, AssignmentMenu, "VIEW", token)) return Forbid();
        const string where = "FROM dbo.TDTMBranchHolidayCalendarAssignment A JOIN dbo.TDADBranch B ON B.CompanyID=A.CompanyID AND B.BranchID=A.BranchID JOIN dbo.TDTMHolidayCalendar C ON C.CompanyID=A.CompanyID AND C.HolidayCalendarID=A.HolidayCalendarID WHERE A.CompanyID=@CompanyID AND (@BranchID IS NULL OR A.BranchID=@BranchID)";
        await using var count = new SqlCommand($"SELECT COUNT_BIG(1) {where}", c); Add(count, "@CompanyID", SqlDbType.BigInt, companyId); Add(count, "@BranchID", SqlDbType.BigInt, branchId); var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var q = new SqlCommand($"SELECT A.BranchHolidayCalendarAssignmentID,A.BranchID,B.BranchCode,B.BranchNameTH,A.HolidayCalendarID,C.CalendarCode,C.CalendarName,A.EffectiveFrom,A.EffectiveTo,A.IsActive,CONVERT(varchar(32),A.RowVersion,2) {where} ORDER BY B.BranchCode,A.EffectiveFrom DESC OFFSET @Offset ROWS FETCH NEXT @Take ROWS ONLY", c); Add(q, "@CompanyID", SqlDbType.BigInt, companyId); Add(q, "@BranchID", SqlDbType.BigInt, branchId); Add(q, "@Offset", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@Take", SqlDbType.Int, pageSize);
        await using var r = await q.ExecuteReaderAsync(token); var items = new List<object>(); while (await r.ReadAsync(token)) items.Add(new { branchHolidayCalendarAssignmentId = r.GetInt64(0), branchId = r.GetInt64(1), branchCode = r.GetString(2), branchName = r.GetString(3), holidayCalendarId = r.GetInt64(4), calendarCode = r.GetString(5), calendarName = r.GetString(6), effectiveFrom = DateOnly.FromDateTime(r.GetDateTime(7)), effectiveTo = Date(r, 8), isActive = r.GetBoolean(9), rowVersion = r.GetString(10) }); return Ok(new { total, page, pageSize, items });
    }

    [HttpPost("assignments")]
    public Task<IActionResult> CreateAssignment(AssignmentRequest request, CancellationToken token) => SaveAssignment(null, request, token);
    [HttpPut("assignments/{id:long}")]
    public Task<IActionResult> UpdateAssignment(long id, AssignmentRequest request, CancellationToken token) => SaveAssignment(id, request, token);
    [HttpDelete("assignments/{id:long}")]
    public Task<IActionResult> DeleteAssignment(long id, [FromQuery] string? rowVersion, CancellationToken token) => SoftDelete(AssignmentMenu, "TDTMBranchHolidayCalendarAssignment", "BranchHolidayCalendarAssignmentID", id, rowVersion, token);

    [HttpGet("exceptions")]
    public async Task<IActionResult> Exceptions([FromQuery] long? branchId, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to, [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out _)) return Forbid(); if (!Page(page, pageSize) || from > to) return BadRequest(new { message = "เงื่อนไขค้นหาไม่ถูกต้อง" }); await using var c = await Open(token); if (!await Can(c, ExceptionMenu, "VIEW", token)) return Forbid();
        const string where = "FROM dbo.TDTMBranchHolidayException E JOIN dbo.TDADBranch B ON B.CompanyID=E.CompanyID AND B.BranchID=E.BranchID WHERE E.CompanyID=@CompanyID AND (@BranchID IS NULL OR E.BranchID=@BranchID) AND (@From IS NULL OR E.HolidayDate>=@From) AND (@To IS NULL OR E.HolidayDate<=@To)";
        await using var count = new SqlCommand($"SELECT COUNT_BIG(1) {where}", c); BindException(count, companyId, branchId, from, to); var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var q = new SqlCommand($"SELECT E.BranchHolidayExceptionID,E.BranchID,B.BranchCode,B.BranchNameTH,E.HolidayDate,E.IsHoliday,E.HolidayName,E.Reason,E.IsActive,CONVERT(varchar(32),E.RowVersion,2) {where} ORDER BY E.HolidayDate DESC,B.BranchCode OFFSET @Offset ROWS FETCH NEXT @Take ROWS ONLY", c); BindException(q, companyId, branchId, from, to); Add(q, "@Offset", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@Take", SqlDbType.Int, pageSize);
        await using var r = await q.ExecuteReaderAsync(token); var items = new List<object>(); while (await r.ReadAsync(token)) items.Add(new { branchHolidayExceptionId = r.GetInt64(0), branchId = r.GetInt64(1), branchCode = r.GetString(2), branchName = r.GetString(3), holidayDate = DateOnly.FromDateTime(r.GetDateTime(4)), isHoliday = r.GetBoolean(5), holidayName = Text(r, 6), reason = Text(r, 7), isActive = r.GetBoolean(8), rowVersion = r.GetString(9) }); return Ok(new { total, page, pageSize, items });
    }

    [HttpPost("exceptions")]
    public Task<IActionResult> CreateException(ExceptionRequest request, CancellationToken token) => SaveException(null, request, token);
    [HttpPut("exceptions/{id:long}")]
    public Task<IActionResult> UpdateException(long id, ExceptionRequest request, CancellationToken token) => SaveException(id, request, token);
    [HttpDelete("exceptions/{id:long}")]
    public Task<IActionResult> DeleteException(long id, [FromQuery] string? rowVersion, CancellationToken token) => SoftDelete(ExceptionMenu, "TDTMBranchHolidayException", "BranchHolidayExceptionID", id, rowVersion, token);

    private async Task<IActionResult> SaveCalendar(long? id, CalendarRequest x, CancellationToken token)
    {
        if (!Scope(out var co, out var user)) return Forbid(); var code = Clean(x.CalendarCode)?.ToUpperInvariant(); var name = Clean(x.CalendarName); if (code is null || code.Length > 30 || name is null || name.Length > 150 || (id.HasValue && !RowVersion(x.RowVersion))) return BadRequest(new { message = "กรุณาระบุรหัส ชื่อ และ Version ของปฏิทินให้ถูกต้อง" });
        await using var c = await Open(token); if (!await Can(c, CalendarMenu, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        try { await using var q = new SqlCommand(id.HasValue ? "UPDATE dbo.TDTMHolidayCalendar SET CalendarCode=@Code,CalendarName=@Name,DescriptionText=@Description,IsActive=@Active,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND HolidayCalendarID=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2)" : "INSERT dbo.TDTMHolidayCalendar(CompanyID,CalendarCode,CalendarName,DescriptionText,IsActive,CreateBy) VALUES(@CompanyID,@Code,@Name,@Description,@Active,@UserID)", c); BindCalendar(q, co, user, code, name, x); if (id.HasValue) { Add(q, "@ID", SqlDbType.BigInt, id); Add(q, "@RowVersion", SqlDbType.VarChar, x.RowVersion, 32); } return await q.ExecuteNonQueryAsync(token) == 1 ? NoContent() : Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" }); } catch (SqlException e) when (e.Number is 2601 or 2627) { return Conflict(new { message = "รหัสปฏิทินวันหยุดซ้ำในบริษัท" }); }
    }

    private async Task<IActionResult> SaveDate(long? id, HolidayDateRequest x, CancellationToken token)
    {
        if (!Scope(out var co, out var user)) return Forbid(); var name = Clean(x.HolidayName); if (x.HolidayCalendarId <= 0 || name is null || name.Length > 200 || (id.HasValue && !RowVersion(x.RowVersion))) return BadRequest(new { message = "กรุณาระบุปฏิทิน วันที่ ชื่อวันหยุด และ Version ให้ถูกต้อง" }); await using var c = await Open(token); if (!await Can(c, DateMenu, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid(); if (!await CalendarExists(c, co, x.HolidayCalendarId, token)) return Conflict(new { message = "ไม่พบปฏิทินวันหยุดที่ใช้งานได้" });
        try { await using var q = new SqlCommand(id.HasValue ? "UPDATE dbo.TDTMHolidayDate SET HolidayCalendarID=@CalendarID,HolidayDate=@Date,HolidayName=@Name,IsActive=@Active,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND HolidayDateID=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2)" : "INSERT dbo.TDTMHolidayDate(CompanyID,HolidayCalendarID,HolidayDate,HolidayName,IsActive,CreateBy) VALUES(@CompanyID,@CalendarID,@Date,@Name,@Active,@UserID)", c); BindDate(q, co, user, x, name); if (id.HasValue) { Add(q, "@ID", SqlDbType.BigInt, id); Add(q, "@RowVersion", SqlDbType.VarChar, x.RowVersion, 32); } return await q.ExecuteNonQueryAsync(token) == 1 ? NoContent() : Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" }); } catch (SqlException e) when (e.Number is 2601 or 2627) { return Conflict(new { message = "วันหยุดนี้มีอยู่ในปฏิทินแล้ว" }); }
    }

    private async Task<IActionResult> SaveAssignment(long? id, AssignmentRequest x, CancellationToken token)
    {
        if (!Scope(out var co, out var user)) return Forbid(); if (x.BranchId <= 0 || x.HolidayCalendarId <= 0 || x.EffectiveTo < x.EffectiveFrom || (id.HasValue && !RowVersion(x.RowVersion))) return BadRequest(new { message = "กรุณาระบุสาขา ปฏิทิน และช่วงวันที่ให้ถูกต้อง" }); await using var c = await Open(token); if (!await Can(c, AssignmentMenu, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid(); await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try { if (!await BranchExists(c, tx, co, x.BranchId, token) || !await CalendarExists(c, tx, co, x.HolidayCalendarId, token)) throw new InvalidOperationException("ไม่พบสาขาหรือปฏิทินวันหยุดที่ใช้งานได้"); await EnsureNoOverlap(c, tx, co, x.BranchId, x.EffectiveFrom, x.EffectiveTo, id, token); await using var q = new SqlCommand(id.HasValue ? "UPDATE dbo.TDTMBranchHolidayCalendarAssignment SET BranchID=@BranchID,HolidayCalendarID=@CalendarID,EffectiveFrom=@From,EffectiveTo=@To,IsActive=@Active,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND BranchHolidayCalendarAssignmentID=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2)" : "INSERT dbo.TDTMBranchHolidayCalendarAssignment(CompanyID,BranchID,HolidayCalendarID,EffectiveFrom,EffectiveTo,IsActive,CreateBy) VALUES(@CompanyID,@BranchID,@CalendarID,@From,@To,@Active,@UserID)", c, tx); BindAssignment(q, co, user, x); if (id.HasValue) { Add(q, "@ID", SqlDbType.BigInt, id); Add(q, "@RowVersion", SqlDbType.VarChar, x.RowVersion, 32); } if (await q.ExecuteNonQueryAsync(token) != 1) throw new InvalidOperationException("ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่"); await tx.CommitAsync(token); return NoContent(); } catch (InvalidOperationException e) { await tx.RollbackAsync(token); return Conflict(new { message = e.Message }); }
    }

    private async Task<IActionResult> SaveException(long? id, ExceptionRequest x, CancellationToken token)
    {
        if (!Scope(out var co, out var user)) return Forbid(); var name = Clean(x.HolidayName); var reason = Clean(x.Reason); if (x.BranchId <= 0 || name?.Length > 200 || reason?.Length > 500 || (x.IsHoliday && name is null) || (id.HasValue && !RowVersion(x.RowVersion))) return BadRequest(new { message = "กรุณาระบุสาขาและข้อมูลข้อยกเว้นให้ถูกต้อง" }); await using var c = await Open(token); if (!await Can(c, ExceptionMenu, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid(); if (!await BranchExists(c, null, co, x.BranchId, token)) return Conflict(new { message = "ไม่พบสาขาที่ใช้งานได้" });
        try { await using var q = new SqlCommand(id.HasValue ? "UPDATE dbo.TDTMBranchHolidayException SET BranchID=@BranchID,HolidayDate=@Date,IsHoliday=@IsHoliday,HolidayName=@Name,Reason=@Reason,IsActive=@Active,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND BranchHolidayExceptionID=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2)" : "INSERT dbo.TDTMBranchHolidayException(CompanyID,BranchID,HolidayDate,IsHoliday,HolidayName,Reason,IsActive,CreateBy) VALUES(@CompanyID,@BranchID,@Date,@IsHoliday,@Name,@Reason,@Active,@UserID)", c); BindException(q, co, user, x, name, reason); if (id.HasValue) { Add(q, "@ID", SqlDbType.BigInt, id); Add(q, "@RowVersion", SqlDbType.VarChar, x.RowVersion, 32); } return await q.ExecuteNonQueryAsync(token) == 1 ? NoContent() : Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" }); } catch (SqlException e) when (e.Number is 2601 or 2627) { return Conflict(new { message = "สาขานี้มีข้อยกเว้นสำหรับวันดังกล่าวแล้ว" }); }
    }

    private async Task<IActionResult> SoftDelete(string menu, string table, string idColumn, long id, string? rowVersion, CancellationToken token)
    { if (!Scope(out var co, out var user)) return Forbid(); if (!RowVersion(rowVersion)) return BadRequest(new { message = "ไม่พบ Version ของข้อมูล กรุณาโหลดใหม่" }); await using var c = await Open(token); if (!await Can(c, menu, "DELETE", token)) return Forbid(); await using var q = new SqlCommand($"UPDATE dbo.{table} SET IsActive=0,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND {idColumn}=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2)", c); Add(q, "@CompanyID", SqlDbType.BigInt, co); Add(q, "@UserID", SqlDbType.BigInt, user); Add(q, "@ID", SqlDbType.BigInt, id); Add(q, "@RowVersion", SqlDbType.VarChar, rowVersion, 32); return await q.ExecuteNonQueryAsync(token) == 1 ? NoContent() : Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" }); }

    private async Task<IActionResult> Actions(string menu, int screenType, CancellationToken token) { if (!Scope(out _, out _)) return Forbid(); await using var c = await Open(token); return Ok(new { menuCode = menu, caption = await Caption(c, menu, token), screenType, view = await Can(c, menu, "VIEW", token), create = await Can(c, menu, "CREATE", token), edit = await Can(c, menu, "EDIT", token), delete = await Can(c, menu, "DELETE", token) }); }
    private async Task<bool> Can(SqlConnection c, string menu, string action, CancellationToken token) => await CompanyMenuAccess.IsAllowedAsync(c, User, menu, action, token);
    private async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private bool Scope(out long companyId, out long userId) { companyId = 0; userId = 0; return string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase) && long.TryParse(User.FindFirstValue("company_id"), out companyId) && long.TryParse(User.FindFirstValue("user_id"), out userId) && companyId > 0 && userId > 0; }
    private static bool Page(int page, int pageSize) => page > 0 && pageSize is > 0 and <= 100;
    private static bool RowVersion(string? value) => !string.IsNullOrWhiteSpace(value) && value.Length <= 32;
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static string? Text(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static DateOnly? Date(SqlDataReader r, int i) => r.IsDBNull(i) ? null : DateOnly.FromDateTime(r.GetDateTime(i));
    private static void Add(SqlCommand q, string name, SqlDbType type, object? value, int size = 0) { var p = size == 0 ? q.Parameters.Add(name, type) : q.Parameters.Add(name, type, size); p.Value = value ?? DBNull.Value; }
    private static void Bind(SqlCommand q, long companyId, string? search, bool? active) { Add(q, "@CompanyID", SqlDbType.BigInt, companyId); Add(q, "@Search", SqlDbType.NVarChar, Clean(search), 150); Add(q, "@Active", SqlDbType.Bit, active); }
    private static void BindCalendar(SqlCommand q, long co, long user, string code, string name, CalendarRequest x) { Add(q, "@CompanyID", SqlDbType.BigInt, co); Add(q, "@Code", SqlDbType.VarChar, code, 30); Add(q, "@Name", SqlDbType.NVarChar, name, 150); Add(q, "@Description", SqlDbType.NVarChar, Clean(x.DescriptionText), 500); Add(q, "@Active", SqlDbType.Bit, x.IsActive); Add(q, "@UserID", SqlDbType.BigInt, user); }
    private static void BindDate(SqlCommand q, long co, long user, HolidayDateRequest x, string name) { Add(q, "@CompanyID", SqlDbType.BigInt, co); Add(q, "@CalendarID", SqlDbType.BigInt, x.HolidayCalendarId); Add(q, "@Date", SqlDbType.Date, x.HolidayDate.ToDateTime(TimeOnly.MinValue)); Add(q, "@Name", SqlDbType.NVarChar, name, 200); Add(q, "@Active", SqlDbType.Bit, x.IsActive); Add(q, "@UserID", SqlDbType.BigInt, user); }
    private static void BindAssignment(SqlCommand q, long co, long user, AssignmentRequest x) { Add(q, "@CompanyID", SqlDbType.BigInt, co); Add(q, "@BranchID", SqlDbType.BigInt, x.BranchId); Add(q, "@CalendarID", SqlDbType.BigInt, x.HolidayCalendarId); Add(q, "@From", SqlDbType.Date, x.EffectiveFrom.ToDateTime(TimeOnly.MinValue)); Add(q, "@To", SqlDbType.Date, x.EffectiveTo?.ToDateTime(TimeOnly.MinValue)); Add(q, "@Active", SqlDbType.Bit, x.IsActive); Add(q, "@UserID", SqlDbType.BigInt, user); }
    private static void BindException(SqlCommand q, long co, long? branch, DateOnly? from, DateOnly? to) { Add(q, "@CompanyID", SqlDbType.BigInt, co); Add(q, "@BranchID", SqlDbType.BigInt, branch); Add(q, "@From", SqlDbType.Date, from?.ToDateTime(TimeOnly.MinValue)); Add(q, "@To", SqlDbType.Date, to?.ToDateTime(TimeOnly.MinValue)); }
    private static void BindException(SqlCommand q, long co, long user, ExceptionRequest x, string? name, string? reason) { Add(q, "@CompanyID", SqlDbType.BigInt, co); Add(q, "@BranchID", SqlDbType.BigInt, x.BranchId); Add(q, "@Date", SqlDbType.Date, x.HolidayDate.ToDateTime(TimeOnly.MinValue)); Add(q, "@IsHoliday", SqlDbType.Bit, x.IsHoliday); Add(q, "@Name", SqlDbType.NVarChar, name, 200); Add(q, "@Reason", SqlDbType.NVarChar, reason, 500); Add(q, "@Active", SqlDbType.Bit, x.IsActive); Add(q, "@UserID", SqlDbType.BigInt, user); }
    private static async Task<bool> CalendarExists(SqlConnection c, long co, long id, CancellationToken t) { await using var q = new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMHolidayCalendar WHERE CompanyID=@CompanyID AND HolidayCalendarID=@ID AND IsActive=1", c); Add(q, "@CompanyID", SqlDbType.BigInt, co); Add(q, "@ID", SqlDbType.BigInt, id); return Convert.ToInt64(await q.ExecuteScalarAsync(t)) > 0; }
    private static async Task<bool> CalendarExists(SqlConnection c, SqlTransaction tx, long co, long id, CancellationToken t) { await using var q = new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMHolidayCalendar WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@CompanyID AND HolidayCalendarID=@ID AND IsActive=1", c, tx); Add(q, "@CompanyID", SqlDbType.BigInt, co); Add(q, "@ID", SqlDbType.BigInt, id); return Convert.ToInt64(await q.ExecuteScalarAsync(t)) > 0; }
    private static async Task<bool> BranchExists(SqlConnection c, SqlTransaction? tx, long co, long id, CancellationToken t) { await using var q = new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDADBranch WHERE CompanyID=@CompanyID AND BranchID=@ID AND IsActive=1", c, tx); Add(q, "@CompanyID", SqlDbType.BigInt, co); Add(q, "@ID", SqlDbType.BigInt, id); return Convert.ToInt64(await q.ExecuteScalarAsync(t)) > 0; }
    private static async Task EnsureNoOverlap(SqlConnection c, SqlTransaction tx, long companyId, long branchId, DateOnly from, DateOnly? to, long? id, CancellationToken t) { await using var q = new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMBranchHolidayCalendarAssignment WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@CompanyID AND BranchID=@BranchID AND IsActive=1 AND (@ID IS NULL OR BranchHolidayCalendarAssignmentID<>@ID) AND EffectiveFrom<=COALESCE(@To,CONVERT(date,'9999-12-31')) AND (EffectiveTo IS NULL OR EffectiveTo>=@From)", c, tx); Add(q, "@CompanyID", SqlDbType.BigInt, companyId); Add(q, "@BranchID", SqlDbType.BigInt, branchId); Add(q, "@ID", SqlDbType.BigInt, id); Add(q, "@From", SqlDbType.Date, from.ToDateTime(TimeOnly.MinValue)); Add(q, "@To", SqlDbType.Date, to?.ToDateTime(TimeOnly.MinValue)); if (Convert.ToInt64(await q.ExecuteScalarAsync(t)) > 0) throw new InvalidOperationException("ช่วงวันที่ผูกปฏิทินของสาขาซ้อนกับข้อมูลเดิม"); }
    private static async Task<string> Caption(SqlConnection c, string menu, CancellationToken t) { await using var q = new SqlCommand("SELECT TOP (1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@Menu", c); Add(q, "@Menu", SqlDbType.Char, menu, 5); return Convert.ToString(await q.ExecuteScalarAsync(t)) ?? "ปฏิทินวันหยุด"; }
}
