using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Authorize]
[Route("api/time/attendance-periods")]
public sealed class AttendancePeriodsController(IConfiguration configuration) : ControllerBase
{
    private const string SchemeMenu = "29001";
    private const string AssignmentMenu = "29002";
    private const string PeriodMenu = "29003";
    private static readonly string[] PatternCodes = ["CALENDAR_MONTH", "CUT_OFF_DAY", "FIXED_INTERVAL", "CUSTOM_CALENDAR"];

    public sealed record DateRange(DateOnly StartDate, DateOnly EndDate);
    public sealed record SchemeRequest(
        long? AttendancePeriodSchemeId, string SchemeCode, string SchemeName,
        string? DescriptionText, bool IsActive, string PatternCode,
        DateOnly EffectiveFrom, int? CutOffDay, int? IntervalCount,
        string? IntervalUnitCode, DateOnly? AnchorDate,
        int BranchReviewDueDays, int FinalizeDueDays,
        IReadOnlyList<DateRange>? CustomPeriods, string? RowVersion);
    public sealed record BulkAssignmentRequest(long AttendancePeriodSchemeId,
        DateOnly EffectiveFrom, IReadOnlyList<long> EmployeeIds, string? Reason);
    public sealed record ReviewRequest(long BranchId, string? Remark);
    public sealed record ReopenRequest(string Reason);

    [HttpGet("schemes/actions")]
    public Task<IActionResult> SchemeActions(CancellationToken token) => Actions(SchemeMenu, 1, token);

    [HttpGet("assignments/actions")]
    public Task<IActionResult> AssignmentActions(CancellationToken token) => Actions(AssignmentMenu, 4, token);

    [HttpGet("actions")]
    public Task<IActionResult> PeriodActions(CancellationToken token) => Actions(PeriodMenu, 3, token);

    [HttpGet("schemes")]
    public async Task<IActionResult> Schemes([FromQuery] bool? active, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, SchemeMenu, "VIEW", token)) return Forbid();
        await using var command = new SqlCommand("""
SELECT S.AttendancePeriodSchemeID,S.SchemeCode,S.SchemeName,S.DescriptionText,S.IsActive,
       V.PatternCode,V.EffectiveFrom,V.CutOffDay,V.IntervalCount,V.IntervalUnitCode,V.AnchorDate,
       V.BranchReviewDueDays,V.FinalizeDueDays,CONVERT(varchar(32),S.RowVersion,2) RowVersion
FROM dbo.TDTMAttendancePeriodScheme S
OUTER APPLY
(
 SELECT TOP (1) * FROM dbo.TDTMAttendancePeriodSchemeVersion V
 WHERE V.AttendancePeriodSchemeID=S.AttendancePeriodSchemeID AND V.IsActive=1
 ORDER BY V.EffectiveFrom DESC,V.AttendancePeriodSchemeVersionID DESC
) V
WHERE S.CompanyID=@CompanyID AND (@Active IS NULL OR S.IsActive=@Active)
ORDER BY S.SchemeCode,S.AttendancePeriodSchemeID;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@Active", SqlDbType.Bit, active);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new
        {
            attendancePeriodSchemeId = reader.GetInt64(0), schemeCode = reader.GetString(1),
            schemeName = reader.GetString(2), descriptionText = Text(reader, 3), isActive = reader.GetBoolean(4),
            patternCode = Text(reader, 5), effectiveFrom = Date(reader, 6), cutOffDay = Int(reader, 7),
            intervalCount = Int(reader, 8), intervalUnitCode = Text(reader, 9), anchorDate = Date(reader, 10),
            branchReviewDueDays = Int(reader, 11) ?? 3, finalizeDueDays = Int(reader, 12) ?? 7,
            rowVersion = Text(reader, 13),
        });
        return Ok(new { items });
    }

    [HttpPost("schemes")]
    public Task<IActionResult> CreateScheme(SchemeRequest request, CancellationToken token) => SaveScheme(request with { AttendancePeriodSchemeId = null }, true, token);

    [HttpPut("schemes/{schemeId:long}")]
    public Task<IActionResult> UpdateScheme(long schemeId, SchemeRequest request, CancellationToken token) =>
        SaveScheme(request with { AttendancePeriodSchemeId = schemeId }, false, token);

    [HttpPost("schemes/{schemeId:long}/extend")]
    public async Task<IActionResult> Extend(long schemeId, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, SchemeMenu, "EDIT", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var version = await CurrentVersion(connection, transaction, companyId, schemeId, token);
            if (version is null) throw new InvalidOperationException("ไม่พบรูปแบบงวดที่ใช้งานอยู่");
            var lastEnd = await LastPeriodEnd(connection, transaction, companyId, schemeId, token);
            var start = lastEnd?.AddDays(1) ?? version.Value.EffectiveFrom;
            await Generate(connection, transaction, companyId, schemeId, version.Value, start, 12, null, userId, token);
            await Audit(connection, transaction, companyId, null, "EXTEND", null, new { schemeId, start }, null, userId, token);
            await transaction.CommitAsync(token);
            return NoContent();
        }
        catch (InvalidOperationException exception) { await transaction.RollbackAsync(token); return Conflict(new { message = exception.Message }); }
    }

    [HttpGet("assignment-employees")]
    public async Task<IActionResult> AssignmentEmployees([FromQuery] string? search, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, AssignmentMenu, "VIEW", token)) return Forbid();
        await using var command = new SqlCommand("""
SELECT E.EmployeeID,E.EmployeeCode,E.FullName,
       A.AttendancePeriodSchemeID,S.SchemeCode,S.SchemeName,A.EffectiveFrom,A.EffectiveTo
FROM dbo.TDADEmployee E
OUTER APPLY
(
 SELECT TOP (1) * FROM dbo.TDTMEmployeeAttendancePeriodAssignment A
 WHERE A.CompanyID=E.CompanyID AND A.EmployeeID=E.EmployeeID AND A.EffectiveTo IS NULL
 ORDER BY A.EffectiveFrom DESC,A.EmployeeAttendancePeriodAssignmentID DESC
) A
LEFT JOIN dbo.TDTMAttendancePeriodScheme S ON S.AttendancePeriodSchemeID=A.AttendancePeriodSchemeID
WHERE E.CompanyID=@CompanyID AND E.IsActive=1
  AND (@Search IS NULL OR E.EmployeeCode LIKE N'%'+@Search+N'%' OR E.FullName LIKE N'%'+@Search+N'%')
ORDER BY E.EmployeeCode,E.EmployeeID;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@Search", SqlDbType.NVarChar, Clean(search), 150);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new { employeeId = reader.GetInt64(0), employeeCode = reader.GetString(1), fullName = reader.GetString(2), attendancePeriodSchemeId = Long(reader, 3), schemeCode = Text(reader, 4), schemeName = Text(reader, 5), effectiveFrom = Date(reader, 6), effectiveTo = Date(reader, 7) });
        return Ok(new { items });
    }

    [HttpPost("assignments/bulk")]
    public async Task<IActionResult> BulkAssign(BulkAssignmentRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        if (request.AttendancePeriodSchemeId <= 0 || request.EmployeeIds is null || request.EmployeeIds.Count is < 1 or > 1000 || request.EmployeeIds.Distinct().Count() != request.EmployeeIds.Count)
            return BadRequest(new { message = "ข้อมูลการผูกพนักงานกับงวดไม่ถูกต้อง" });
        await using var connection = await Open(token);
        if (!await Can(connection, AssignmentMenu, "CREATE", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            if (!await SchemeExists(connection, transaction, companyId, request.AttendancePeriodSchemeId, token)) throw new InvalidOperationException("ไม่พบรูปแบบงวดที่เลือก");
            foreach (var employeeId in request.EmployeeIds)
            {
                if (!await EmployeeExists(connection, transaction, companyId, employeeId, token)) throw new InvalidOperationException($"ไม่พบพนักงาน {employeeId}");
                if (await FinalizedAssignmentConflict(connection, transaction, companyId, employeeId, request.EffectiveFrom, token)) throw new InvalidOperationException("มีงวดที่ปิดแล้วได้รับผลกระทบ กรุณาเปิดงวดก่อน");
                await CloseAssignment(connection, transaction, companyId, employeeId, request.EffectiveFrom, userId, token);
                await using var insert = new SqlCommand("""
INSERT dbo.TDTMEmployeeAttendancePeriodAssignment
 (CompanyID,EmployeeID,AttendancePeriodSchemeID,EffectiveFrom,AssignmentSourceCode,Reason,CreateBy)
VALUES(@CompanyID,@EmployeeID,@SchemeID,@EffectiveFrom,'BULK',@Reason,@UserID);
""", connection, transaction);
                Add(insert, "@CompanyID", SqlDbType.BigInt, companyId); Add(insert, "@EmployeeID", SqlDbType.BigInt, employeeId);
                Add(insert, "@SchemeID", SqlDbType.BigInt, request.AttendancePeriodSchemeId); Add(insert, "@EffectiveFrom", SqlDbType.Date, request.EffectiveFrom.ToDateTime(TimeOnly.MinValue));
                Add(insert, "@Reason", SqlDbType.NVarChar, Clean(request.Reason), 1000); Add(insert, "@UserID", SqlDbType.BigInt, userId);
                await insert.ExecuteNonQueryAsync(token);
            }
            await Audit(connection, transaction, companyId, null, "BULK_ASSIGNMENT", null, new { request.AttendancePeriodSchemeId, request.EffectiveFrom, request.EmployeeIds }, Clean(request.Reason), userId, token);
            await transaction.CommitAsync(token); return NoContent();
        }
        catch (InvalidOperationException exception) { await transaction.RollbackAsync(token); return Conflict(new { message = exception.Message }); }
        catch (SqlException exception) when (exception.Number is 2601 or 2627) { await transaction.RollbackAsync(token); return Conflict(new { message = "ช่วงการผูกงวดของพนักงานซ้อนกับข้อมูลเดิม" }); }
    }

    [HttpGet]
    public async Task<IActionResult> Periods([FromQuery] string? statusCode, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, PeriodMenu, "VIEW", token)) return Forbid();
        await using var command = new SqlCommand("""
SELECT P.AttendancePeriodID,S.SchemeCode,S.SchemeName,P.PeriodStartDate,P.PeriodEndDate,P.PeriodStatusCode,P.FinalResultVersion,
 (SELECT COUNT_BIG(1) FROM dbo.TDTMAttendanceResult R JOIN dbo.TDTMEmployeeAttendancePeriodAssignment A ON A.CompanyID=R.CompanyID AND A.EmployeeID=R.EmployeeID AND A.AttendancePeriodSchemeID=P.AttendancePeriodSchemeID AND A.EffectiveFrom<=R.WorkDate AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=R.WorkDate) WHERE R.CompanyID=P.CompanyID AND R.IsCurrent=1 AND R.StatusCode='UNRESOLVED' AND R.WorkDate BETWEEN P.PeriodStartDate AND P.PeriodEndDate) UnresolvedCount,
 (SELECT COUNT_BIG(1) FROM dbo.TDTMAttendancePeriodBranchReview BR WHERE BR.AttendancePeriodID=P.AttendancePeriodID AND BR.ReviewStatusCode='PENDING') PendingReviewCount
FROM dbo.TDTMAttendancePeriod P
JOIN dbo.TDTMAttendancePeriodScheme S ON S.AttendancePeriodSchemeID=P.AttendancePeriodSchemeID
WHERE P.CompanyID=@CompanyID AND (@Status IS NULL OR P.PeriodStatusCode=@Status)
ORDER BY P.PeriodEndDate DESC,S.SchemeCode;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@Status", SqlDbType.VarChar, Clean(statusCode)?.ToUpperInvariant(), 20);
        await using var reader = await command.ExecuteReaderAsync(token); var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new { attendancePeriodId = reader.GetInt64(0), schemeCode = reader.GetString(1), schemeName = reader.GetString(2), periodStartDate = Date(reader, 3), periodEndDate = Date(reader, 4), statusCode = reader.GetString(5), finalResultVersion = reader.GetInt32(6), unresolvedCount = reader.GetInt64(7), pendingReviewCount = reader.GetInt64(8) });
        return Ok(new { items });
    }

    [HttpPost("{periodId:long}/reviews")]
    public async Task<IActionResult> Review(long periodId, ReviewRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, PeriodMenu, "APPROVE", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            await EnsureBranchReviews(connection, transaction, companyId, periodId, token);
            await using var update = new SqlCommand("""
UPDATE dbo.TDTMAttendancePeriodBranchReview SET ReviewStatusCode='REVIEWED',ReviewedDate=SYSUTCDATETIME(),ReviewedByUserID=@UserID,Remark=@Remark,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE AttendancePeriodID=@PeriodID AND CompanyID=@CompanyID AND BranchID=@BranchID;
""", connection, transaction);
            Add(update, "@PeriodID", SqlDbType.BigInt, periodId); Add(update, "@CompanyID", SqlDbType.BigInt, companyId); Add(update, "@BranchID", SqlDbType.BigInt, request.BranchId); Add(update, "@UserID", SqlDbType.BigInt, userId); Add(update, "@Remark", SqlDbType.NVarChar, Clean(request.Remark), 1000);
            if (await update.ExecuteNonQueryAsync(token) != 1) throw new InvalidOperationException("ไม่พบสาขาที่ต้องรับรองในงวดนี้");
            await Audit(connection, transaction, companyId, periodId, "BRANCH_REVIEW", null, new { request.BranchId }, Clean(request.Remark), userId, token);
            await transaction.CommitAsync(token); return NoContent();
        }
        catch (InvalidOperationException exception) { await transaction.RollbackAsync(token); return Conflict(new { message = exception.Message }); }
    }

    [HttpGet("{periodId:long}/reviews")]
    public async Task<IActionResult> Reviews(long periodId, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, PeriodMenu, "VIEW", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        await EnsureBranchReviews(connection, transaction, companyId, periodId, token);
        await transaction.CommitAsync(token);
        await using var command = new SqlCommand("""
SELECT R.BranchID,B.BranchCode,B.BranchName,R.ReviewStatusCode,R.ReviewedDate,R.Remark
FROM dbo.TDTMAttendancePeriodBranchReview R
LEFT JOIN dbo.TDADBranch B ON B.CompanyID=R.CompanyID AND B.BranchID=R.BranchID
WHERE R.CompanyID=@CompanyID AND R.AttendancePeriodID=@PeriodID
ORDER BY B.BranchCode,R.BranchID;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@PeriodID", SqlDbType.BigInt, periodId);
        await using var reader = await command.ExecuteReaderAsync(token); var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new { branchId = reader.GetInt64(0), branchCode = Text(reader, 1), branchName = Text(reader, 2), statusCode = reader.GetString(3), reviewedDate = reader.IsDBNull(4) ? (DateTime?)null : reader.GetDateTime(4), remark = Text(reader, 5) });
        return Ok(new { items });
    }

    [HttpPost("{periodId:long}/finalize")]
    public async Task<IActionResult> Finalize(long periodId, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, PeriodMenu, "FINALIZE", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var period = await Period(connection, transaction, companyId, periodId, token);
            if (period is null) return NotFound();
            if (period.Value.Status == "FINALIZED") throw new InvalidOperationException("งวดนี้ปิดแล้ว");
            await EnsureBranchReviews(connection, transaction, companyId, periodId, token);
            if (await OwnerOperated(connection, transaction, companyId, period.Value.End, token) && await Can(connection, PeriodMenu, "APPROVE", token))
                await MarkAllReviews(connection, transaction, companyId, periodId, userId, token);
            if (await UnresolvedCount(connection, transaction, companyId, period.Value, token) > 0) throw new InvalidOperationException("ยังมีผลลงเวลาที่รอตรวจสอบ");
            if (await AssignmentGapCount(connection, transaction, companyId, period.Value, token) > 0) throw new InvalidOperationException("ยังมีพนักงานที่ไม่มีการผูกงวดครอบคลุม");
            if (await PendingReviews(connection, transaction, companyId, periodId, token) > 0) throw new InvalidOperationException("ยังมีสาขาที่ยังไม่รับรองงวด");
            await using var update = new SqlCommand("""
UPDATE dbo.TDTMAttendancePeriod SET PeriodStatusCode='FINALIZED',FinalResultVersion=FinalResultVersion+1,FinalizedDate=SYSUTCDATETIME(),FinalizedByUserID=@UserID,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE AttendancePeriodID=@PeriodID AND CompanyID=@CompanyID AND PeriodStatusCode='OPEN';
""", connection, transaction);
            Add(update, "@PeriodID", SqlDbType.BigInt, periodId); Add(update, "@CompanyID", SqlDbType.BigInt, companyId); Add(update, "@UserID", SqlDbType.BigInt, userId);
            if (await update.ExecuteNonQueryAsync(token) != 1) throw new InvalidOperationException("สถานะงวดถูกเปลี่ยนแล้ว กรุณาโหลดใหม่");
            await Audit(connection, transaction, companyId, periodId, "FINALIZE", new { status = "OPEN" }, new { status = "FINALIZED" }, null, userId, token);
            await transaction.CommitAsync(token); return NoContent();
        }
        catch (InvalidOperationException exception) { await transaction.RollbackAsync(token); return Conflict(new { message = exception.Message }); }
    }

    [HttpPost("{periodId:long}/reopen")]
    public async Task<IActionResult> Reopen(long periodId, ReopenRequest request, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var reason = Clean(request.Reason); if (reason is null) return BadRequest(new { message = "กรุณาระบุเหตุผลที่เปิดงวดแก้ไข" });
        await using var connection = await Open(token); if (!await Can(connection, PeriodMenu, "REOPEN", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        await using var update = new SqlCommand("""
UPDATE dbo.TDTMAttendancePeriod SET PeriodStatusCode='OPEN',FinalizedDate=NULL,FinalizedByUserID=NULL,ReopenedDate=SYSUTCDATETIME(),ReopenedByUserID=@UserID,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE AttendancePeriodID=@PeriodID AND CompanyID=@CompanyID AND PeriodStatusCode='FINALIZED';
""", connection, transaction);
        Add(update, "@PeriodID", SqlDbType.BigInt, periodId); Add(update, "@CompanyID", SqlDbType.BigInt, companyId); Add(update, "@UserID", SqlDbType.BigInt, userId);
        if (await update.ExecuteNonQueryAsync(token) != 1) { await transaction.RollbackAsync(token); return Conflict(new { message = "งวดนี้ยังไม่ถูกปิดหรือถูกเปลี่ยนสถานะแล้ว" }); }
        await using (var reset = new SqlCommand("UPDATE dbo.TDTMAttendancePeriodBranchReview SET ReviewStatusCode='PENDING',ReviewedDate=NULL,ReviewedByUserID=NULL,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID WHERE AttendancePeriodID=@PeriodID;", connection, transaction)) { Add(reset, "@PeriodID", SqlDbType.BigInt, periodId); Add(reset, "@UserID", SqlDbType.BigInt, userId); await reset.ExecuteNonQueryAsync(token); }
        await Audit(connection, transaction, companyId, periodId, "REOPEN", new { status = "FINALIZED" }, new { status = "OPEN" }, reason, userId, token);
        await transaction.CommitAsync(token); return NoContent();
    }

    private async Task<IActionResult> Actions(string menuCode, int screenType, CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid(); await using var connection = await Open(token);
        var view = await Can(connection, menuCode, "VIEW", token); if (!view) return Forbid();
        return Ok(new { menuCode, caption = await Caption(connection, menuCode, token), screenType, view, create = await Can(connection, menuCode, "CREATE", token), edit = await Can(connection, menuCode, "EDIT", token), delete = await Can(connection, menuCode, "DELETE", token), approve = await Can(connection, menuCode, "APPROVE", token), finalize = await Can(connection, menuCode, "FINALIZE", token), reopen = await Can(connection, menuCode, "REOPEN", token) });
    }

    private async Task<IActionResult> SaveScheme(SchemeRequest request, bool create, CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var code = Clean(request.SchemeCode)?.ToUpperInvariant(); var name = Clean(request.SchemeName); var pattern = Clean(request.PatternCode)?.ToUpperInvariant();
        if (code is null || name is null || pattern is null || !PatternCodes.Contains(pattern) || code.Length > 30 || name.Length > 200 || request.BranchReviewDueDays < 0 || request.FinalizeDueDays < 0) return BadRequest(new { message = "ข้อมูลรูปแบบงวดไม่ถูกต้อง" });
        if (pattern == "CUT_OFF_DAY" && request.CutOffDay is not >= 1 and <= 27) return BadRequest(new { message = "วันตัดงวดต้องอยู่ระหว่าง 1 ถึง 27" });
        if (pattern == "FIXED_INTERVAL" && (request.IntervalCount is not > 0 || Clean(request.IntervalUnitCode)?.ToUpperInvariant() is not ("DAY" or "WEEK") || request.AnchorDate is null)) return BadRequest(new { message = "กรุณาระบุรอบและวันอ้างอิงให้ครบ" });
        await using var connection = await Open(token); if (!await Can(connection, SchemeMenu, create ? "CREATE" : "EDIT", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            long schemeId;
            if (create)
            {
                await using var insert = new SqlCommand("INSERT dbo.TDTMAttendancePeriodScheme(CompanyID,SchemeCode,SchemeName,DescriptionText,IsActive,CreateBy) OUTPUT INSERTED.AttendancePeriodSchemeID VALUES(@CompanyID,@Code,@Name,@Description,@Active,@UserID);", connection, transaction);
                Add(insert, "@CompanyID", SqlDbType.BigInt, companyId); Add(insert, "@Code", SqlDbType.VarChar, code, 30); Add(insert, "@Name", SqlDbType.NVarChar, name, 200); Add(insert, "@Description", SqlDbType.NVarChar, Clean(request.DescriptionText), 500); Add(insert, "@Active", SqlDbType.Bit, request.IsActive); Add(insert, "@UserID", SqlDbType.BigInt, userId); schemeId = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            }
            else
            {
                schemeId = request.AttendancePeriodSchemeId ?? 0; if (!await SchemeExists(connection, transaction, companyId, schemeId, token)) return NotFound();
                await using var update = new SqlCommand("UPDATE dbo.TDTMAttendancePeriodScheme SET SchemeCode=@Code,SchemeName=@Name,DescriptionText=@Description,IsActive=@Active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID WHERE AttendancePeriodSchemeID=@ID AND CompanyID=@CompanyID;", connection, transaction);
                Add(update, "@ID", SqlDbType.BigInt, schemeId); Add(update, "@CompanyID", SqlDbType.BigInt, companyId); Add(update, "@Code", SqlDbType.VarChar, code, 30); Add(update, "@Name", SqlDbType.NVarChar, name, 200); Add(update, "@Description", SqlDbType.NVarChar, Clean(request.DescriptionText), 500); Add(update, "@Active", SqlDbType.Bit, request.IsActive); Add(update, "@UserID", SqlDbType.BigInt, userId); await update.ExecuteNonQueryAsync(token);
                await CloseVersion(connection, transaction, schemeId, request.EffectiveFrom, userId, token);
            }
            var version = await InsertVersion(connection, transaction, companyId, schemeId, request, pattern, userId, token);
            await Generate(connection, transaction, companyId, schemeId, version, request.EffectiveFrom, 12, request.CustomPeriods, userId, token);
            await Audit(connection, transaction, companyId, null, create ? "CREATE_SCHEME" : "VERSION_SCHEME", null, new { schemeId, pattern, request.EffectiveFrom }, null, userId, token);
            await transaction.CommitAsync(token); return Ok(new { attendancePeriodSchemeId = schemeId });
        }
        catch (InvalidOperationException exception) { await transaction.RollbackAsync(token); return Conflict(new { message = exception.Message }); }
        catch (SqlException exception) when (exception.Number is 2601 or 2627) { await transaction.RollbackAsync(token); return Conflict(new { message = "รหัสหรือวันที่มีผลของรูปแบบงวดซ้ำกับข้อมูลเดิม" }); }
    }

    private static async Task<(long Id, string Pattern, DateOnly EffectiveFrom, int? CutOff, int? Interval, string? Unit, DateOnly? Anchor)?> CurrentVersion(SqlConnection c, SqlTransaction tx, long company, long scheme, CancellationToken t)
    { await using var q = new SqlCommand("SELECT TOP(1) AttendancePeriodSchemeVersionID,PatternCode,EffectiveFrom,CutOffDay,IntervalCount,IntervalUnitCode,AnchorDate FROM dbo.TDTMAttendancePeriodSchemeVersion WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND AttendancePeriodSchemeID=@S AND IsActive=1 AND EffectiveTo IS NULL ORDER BY EffectiveFrom DESC", c, tx); Add(q,"@C",SqlDbType.BigInt,company); Add(q,"@S",SqlDbType.BigInt,scheme); await using var r=await q.ExecuteReaderAsync(t); return await r.ReadAsync(t) ? (r.GetInt64(0),r.GetString(1),DateOnly.FromDateTime(r.GetDateTime(2)),Int(r,3),Int(r,4),Text(r,5),Date(r,6)) : null; }
    private static async Task<(long Id, string Pattern, DateOnly EffectiveFrom, int? CutOff, int? Interval, string? Unit, DateOnly? Anchor)> InsertVersion(SqlConnection c, SqlTransaction tx, long company, long scheme, SchemeRequest x, string pattern, long user, CancellationToken t)
    { await using var q=new SqlCommand("INSERT dbo.TDTMAttendancePeriodSchemeVersion(AttendancePeriodSchemeID,CompanyID,PatternCode,EffectiveFrom,CutOffDay,IntervalCount,IntervalUnitCode,AnchorDate,BranchReviewDueDays,FinalizeDueDays,CreateBy) OUTPUT INSERTED.AttendancePeriodSchemeVersionID VALUES(@S,@C,@P,@F,@CO,@I,@U,@A,@B,@FD,@X);",c,tx); Add(q,"@S",SqlDbType.BigInt,scheme);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@P",SqlDbType.VarChar,pattern,30);Add(q,"@F",SqlDbType.Date,x.EffectiveFrom.ToDateTime(TimeOnly.MinValue));Add(q,"@CO",SqlDbType.TinyInt,x.CutOffDay);Add(q,"@I",SqlDbType.SmallInt,x.IntervalCount);Add(q,"@U",SqlDbType.VarChar,Clean(x.IntervalUnitCode)?.ToUpperInvariant(),10);Add(q,"@A",SqlDbType.Date,x.AnchorDate?.ToDateTime(TimeOnly.MinValue));Add(q,"@B",SqlDbType.SmallInt,x.BranchReviewDueDays);Add(q,"@FD",SqlDbType.SmallInt,x.FinalizeDueDays);Add(q,"@X",SqlDbType.BigInt,user); var id=Convert.ToInt64(await q.ExecuteScalarAsync(t));return(id,pattern,x.EffectiveFrom,x.CutOffDay,x.IntervalCount,Clean(x.IntervalUnitCode)?.ToUpperInvariant(),x.AnchorDate); }
    private static async Task CloseVersion(SqlConnection c,SqlTransaction tx,long scheme,DateOnly start,long user,CancellationToken t)
    { await using var q=new SqlCommand("UPDATE dbo.TDTMAttendancePeriodSchemeVersion SET EffectiveTo=DATEADD(day,-1,@F),UpdateDate=SYSUTCDATETIME(),UpdateBy=@U WHERE AttendancePeriodSchemeID=@S AND IsActive=1 AND EffectiveTo IS NULL;",c,tx);Add(q,"@F",SqlDbType.Date,start.ToDateTime(TimeOnly.MinValue));Add(q,"@U",SqlDbType.BigInt,user);Add(q,"@S",SqlDbType.BigInt,scheme);await q.ExecuteNonQueryAsync(t); }
    private static async Task<DateOnly?> LastPeriodEnd(SqlConnection c,SqlTransaction tx,long company,long scheme,CancellationToken t) { await using var q=new SqlCommand("SELECT MAX(PeriodEndDate) FROM dbo.TDTMAttendancePeriod WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND AttendancePeriodSchemeID=@S",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@S",SqlDbType.BigInt,scheme);var v=await q.ExecuteScalarAsync(t);return v is DBNull or null?null:DateOnly.FromDateTime((DateTime)v); }
    private static async Task Generate(SqlConnection c,SqlTransaction tx,long company,long scheme,(long Id,string Pattern,DateOnly EffectiveFrom,int? CutOff,int? Interval,string? Unit,DateOnly? Anchor) version,DateOnly from,int months,IReadOnlyList<DateRange>? custom,long user,CancellationToken t)
    { var ranges = version.Pattern=="CUSTOM_CALENDAR" ? ValidateCustom(custom,from) : Automatic(version,from,months); foreach(var range in ranges) await InsertPeriod(c,tx,company,scheme,version.Id,range.StartDate,range.EndDate,user,t); }
    private static IReadOnlyList<DateRange> ValidateCustom(IReadOnlyList<DateRange>? ranges,DateOnly from) { if(ranges is null||ranges.Count==0) throw new InvalidOperationException("ปฏิทินกำหนดเองต้องระบุงวดล่วงหน้า"); var ordered=ranges.OrderBy(x=>x.StartDate).ToArray(); if(ordered[0].StartDate!=from || ordered.Any(x=>x.EndDate<x.StartDate) || ordered.Skip(1).Where((x,i)=>x.StartDate!=ordered[i].EndDate.AddDays(1)).Any()) throw new InvalidOperationException("งวดกำหนดเองต้องต่อเนื่อง ไม่ซ้อน และเริ่มตามวันที่มีผล"); return ordered; }
    private static IReadOnlyList<DateRange> Automatic((long Id,string Pattern,DateOnly EffectiveFrom,int? CutOff,int? Interval,string? Unit,DateOnly? Anchor) v,DateOnly from,int months) { var until=from.AddMonths(months);var result=new List<DateRange>();var cursor=from;while(cursor<until){DateOnly end; if(v.Pattern=="CALENDAR_MONTH") end=new DateOnly(cursor.Year,cursor.Month,DateTime.DaysInMonth(cursor.Year,cursor.Month)); else if(v.Pattern=="CUT_OFF_DAY"){var cut=v.CutOff!.Value;end=cursor.Day<=cut?new DateOnly(cursor.Year,cursor.Month,cut):new DateOnly(cursor.AddMonths(1).Year,cursor.AddMonths(1).Month,cut);} else {var days=v.Interval!.Value*(v.Unit=="WEEK"?7:1);end=cursor.AddDays(days-1);} result.Add(new DateRange(cursor,end));cursor=end.AddDays(1);}return result; }
    private static async Task InsertPeriod(SqlConnection c,SqlTransaction tx,long company,long scheme,long version,DateOnly start,DateOnly end,long user,CancellationToken t){await using var q=new SqlCommand("IF NOT EXISTS(SELECT 1 FROM dbo.TDTMAttendancePeriod WHERE CompanyID=@C AND AttendancePeriodSchemeID=@S AND PeriodStartDate=@F AND PeriodEndDate=@T) INSERT dbo.TDTMAttendancePeriod(CompanyID,AttendancePeriodSchemeID,AttendancePeriodSchemeVersionID,PeriodStartDate,PeriodEndDate,CreateBy) VALUES(@C,@S,@V,@F,@T,@U);",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@S",SqlDbType.BigInt,scheme);Add(q,"@V",SqlDbType.BigInt,version);Add(q,"@F",SqlDbType.Date,start.ToDateTime(TimeOnly.MinValue));Add(q,"@T",SqlDbType.Date,end.ToDateTime(TimeOnly.MinValue));Add(q,"@U",SqlDbType.BigInt,user);await q.ExecuteNonQueryAsync(t);}
    private static async Task<bool> SchemeExists(SqlConnection c,SqlTransaction tx,long company,long id,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMAttendancePeriodScheme WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND AttendancePeriodSchemeID=@I AND IsActive=1",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@I",SqlDbType.BigInt,id);return Convert.ToInt64(await q.ExecuteScalarAsync(t))>0;}
    private static async Task<bool> EmployeeExists(SqlConnection c,SqlTransaction tx,long company,long id,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDADEmployee WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND EmployeeID=@I AND IsActive=1",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@I",SqlDbType.BigInt,id);return Convert.ToInt64(await q.ExecuteScalarAsync(t))>0;}
    private static async Task CloseAssignment(SqlConnection c,SqlTransaction tx,long company,long employee,DateOnly start,long user,CancellationToken t){await using var q=new SqlCommand("UPDATE dbo.TDTMEmployeeAttendancePeriodAssignment SET EffectiveTo=DATEADD(day,-1,@F),UpdateDate=SYSUTCDATETIME(),UpdateBy=@U WHERE CompanyID=@C AND EmployeeID=@E AND EffectiveTo IS NULL;",c,tx);Add(q,"@F",SqlDbType.Date,start.ToDateTime(TimeOnly.MinValue));Add(q,"@U",SqlDbType.BigInt,user);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,employee);await q.ExecuteNonQueryAsync(t);}
    private static async Task<bool> FinalizedAssignmentConflict(SqlConnection c,SqlTransaction tx,long company,long employee,DateOnly start,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMAttendancePeriod P JOIN dbo.TDTMEmployeeAttendancePeriodAssignment A ON A.CompanyID=P.CompanyID AND A.AttendancePeriodSchemeID=P.AttendancePeriodSchemeID AND A.EmployeeID=@E WHERE P.CompanyID=@C AND P.PeriodStatusCode='FINALIZED' AND P.PeriodEndDate>=@F AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=@F);",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@F",SqlDbType.Date,start.ToDateTime(TimeOnly.MinValue));return Convert.ToInt64(await q.ExecuteScalarAsync(t))>0;}
    private static async Task<(long Scheme,DateOnly Start,DateOnly End,string Status)?> Period(SqlConnection c,SqlTransaction tx,long company,long id,CancellationToken t){await using var q=new SqlCommand("SELECT AttendancePeriodSchemeID,PeriodStartDate,PeriodEndDate,PeriodStatusCode FROM dbo.TDTMAttendancePeriod WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND AttendancePeriodID=@I",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@I",SqlDbType.BigInt,id);await using var r=await q.ExecuteReaderAsync(t);return await r.ReadAsync(t)?(r.GetInt64(0),DateOnly.FromDateTime(r.GetDateTime(1)),DateOnly.FromDateTime(r.GetDateTime(2)),r.GetString(3)):null;}
    private static async Task EnsureBranchReviews(SqlConnection c,SqlTransaction tx,long company,long period,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMAttendancePeriodBranchReview(AttendancePeriodID,CompanyID,BranchID) SELECT @P,@C,E.BranchID FROM dbo.TDTMAttendancePeriod X JOIN dbo.TDTMEmployeeAttendancePeriodAssignment A ON A.CompanyID=X.CompanyID AND A.AttendancePeriodSchemeID=X.AttendancePeriodSchemeID AND A.EffectiveFrom<=X.PeriodEndDate AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=X.PeriodStartDate) JOIN dbo.TDADEmployee E ON E.CompanyID=A.CompanyID AND E.EmployeeID=A.EmployeeID WHERE X.CompanyID=@C AND X.AttendancePeriodID=@P AND E.BranchID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDTMAttendancePeriodBranchReview R WHERE R.AttendancePeriodID=@P AND R.BranchID=E.BranchID) GROUP BY E.BranchID;",c,tx);Add(q,"@P",SqlDbType.BigInt,period);Add(q,"@C",SqlDbType.BigInt,company);await q.ExecuteNonQueryAsync(t);}
    private static async Task MarkAllReviews(SqlConnection c,SqlTransaction tx,long company,long period,long user,CancellationToken t){await using var q=new SqlCommand("UPDATE dbo.TDTMAttendancePeriodBranchReview SET ReviewStatusCode='REVIEWED',ReviewedDate=SYSUTCDATETIME(),ReviewedByUserID=@U,UpdateDate=SYSUTCDATETIME(),UpdateBy=@U WHERE CompanyID=@C AND AttendancePeriodID=@P AND ReviewStatusCode='PENDING';",c,tx);Add(q,"@U",SqlDbType.BigInt,user);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@P",SqlDbType.BigInt,period);await q.ExecuteNonQueryAsync(t);}
    private static async Task<long> PendingReviews(SqlConnection c,SqlTransaction tx,long company,long period,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMAttendancePeriodBranchReview WHERE CompanyID=@C AND AttendancePeriodID=@P AND ReviewStatusCode='PENDING'",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@P",SqlDbType.BigInt,period);return Convert.ToInt64(await q.ExecuteScalarAsync(t));}
    private static async Task<long> UnresolvedCount(SqlConnection c,SqlTransaction tx,long company,(long Scheme,DateOnly Start,DateOnly End,string Status) p,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMAttendanceResult R JOIN dbo.TDTMEmployeeAttendancePeriodAssignment A ON A.CompanyID=R.CompanyID AND A.EmployeeID=R.EmployeeID AND A.AttendancePeriodSchemeID=@S AND A.EffectiveFrom<=R.WorkDate AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=R.WorkDate) WHERE R.CompanyID=@C AND R.IsCurrent=1 AND R.StatusCode='UNRESOLVED' AND R.WorkDate BETWEEN @F AND @T",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@S",SqlDbType.BigInt,p.Scheme);Add(q,"@F",SqlDbType.Date,p.Start.ToDateTime(TimeOnly.MinValue));Add(q,"@T",SqlDbType.Date,p.End.ToDateTime(TimeOnly.MinValue));return Convert.ToInt64(await q.ExecuteScalarAsync(t));}
    private static async Task<long> AssignmentGapCount(SqlConnection c,SqlTransaction tx,long company,(long Scheme,DateOnly Start,DateOnly End,string Status) p,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDADEmployee E JOIN dbo.TDTMAttendanceRequirement R ON R.CompanyID=E.CompanyID AND R.EmployeeID=E.EmployeeID AND R.RequirementCode='REQUIRED' AND R.EffectiveFrom<=@T AND (R.EffectiveTo IS NULL OR R.EffectiveTo>=@F) WHERE E.CompanyID=@C AND E.IsActive=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDTMEmployeeAttendancePeriodAssignment A WHERE A.CompanyID=E.CompanyID AND A.EmployeeID=E.EmployeeID AND A.AttendancePeriodSchemeID=@S AND A.EffectiveFrom<=@F AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=@T))",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@S",SqlDbType.BigInt,p.Scheme);Add(q,"@F",SqlDbType.Date,p.Start.ToDateTime(TimeOnly.MinValue));Add(q,"@T",SqlDbType.Date,p.End.ToDateTime(TimeOnly.MinValue));return Convert.ToInt64(await q.ExecuteScalarAsync(t));}
    private static async Task<bool> OwnerOperated(SqlConnection c,SqlTransaction tx,long company,DateOnly date,CancellationToken t){await using var q=new SqlCommand("SELECT TOP(1) COALESCE(P.ProfileCode,D.ProfileCode,'OWNER_OPERATED') FROM dbo.TDTMApprovalProfileVersion D LEFT JOIN dbo.TDTMProcessApprovalPolicyVersion P ON P.CompanyID=D.CompanyID AND P.ProcessCode='PERIOD' AND P.IsActive=1 AND P.EffectiveFrom<=@D AND (P.EffectiveTo IS NULL OR P.EffectiveTo>=@D) WHERE D.CompanyID=@C AND D.IsActive=1 AND D.EffectiveFrom<=@D AND (D.EffectiveTo IS NULL OR D.EffectiveTo>=@D) ORDER BY D.EffectiveFrom DESC",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@D",SqlDbType.Date,date.ToDateTime(TimeOnly.MinValue));return string.Equals(Convert.ToString(await q.ExecuteScalarAsync(t)),"OWNER_OPERATED",StringComparison.OrdinalIgnoreCase);}
    private static async Task Audit(SqlConnection c,SqlTransaction tx,long company,long? period,string action,object? before,object? after,string? reason,long user,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMAttendancePeriodAudit(CompanyID,AttendancePeriodID,ActionCode,BeforeJson,AfterJson,Reason,ActorUserID) VALUES(@C,@P,@A,@B,@F,@R,@U)",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@P",SqlDbType.BigInt,period);Add(q,"@A",SqlDbType.VarChar,action,30);Add(q,"@B",SqlDbType.NVarChar,before is null?null:JsonSerializer.Serialize(before),-1);Add(q,"@F",SqlDbType.NVarChar,after is null?null:JsonSerializer.Serialize(after),-1);Add(q,"@R",SqlDbType.NVarChar,reason,1000);Add(q,"@U",SqlDbType.BigInt,user);await q.ExecuteNonQueryAsync(t);}
    private async Task<bool> Can(SqlConnection c,string menu,string action,CancellationToken t)=>await CompanyMenuAccess.IsAllowedAsync(c,User,menu,action,t);
    private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private bool Scope(out long company,out long user){company=0;user=0;return string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}
    private static async Task<string> Caption(SqlConnection c,string menu,CancellationToken t){await using var q=new SqlCommand("SELECT MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@M",c);Add(q,"@M",SqlDbType.Char,menu,5);return Convert.ToString(await q.ExecuteScalarAsync(t))??menu;}
    private static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
    private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i);
    private static int? Int(SqlDataReader r,int i)=>r.IsDBNull(i)?null:Convert.ToInt32(r.GetValue(i));
    private static long? Long(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetInt64(i);
    private static DateOnly? Date(SqlDataReader r,int i)=>r.IsDBNull(i)?null:DateOnly.FromDateTime(r.GetDateTime(i));
    private static void Add(SqlCommand q,string name,SqlDbType type,object? value,int size=0){var p=size==0?q.Parameters.Add(name,type):q.Parameters.Add(name,type,size);p.Value=value??DBNull.Value;}
}
