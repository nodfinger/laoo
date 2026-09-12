using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Route("api/time/corrections")]
[Authorize]
public sealed class TimeCorrectionsController(IConfiguration configuration) : ControllerBase
{
    private const string ProxyMenu = "26001";
    private const string InboxMenu = "26002";
    private const string SelfMenu = "30001";

    public sealed record DetailRequest(
        long? AttendanceSessionRuleId,
        string SessionName,
        string EndpointCode,
        DateTime? OriginalDateTime,
        DateTime RequestedDateTime);

    public sealed record SaveRequest(
        long? EmployeeId,
        DateOnly WorkDate,
        long TimeAdjustmentReasonId,
        long? OnBehalfReasonId,
        string? RequestRemark,
        string? OnBehalfRemark,
        string? EvidenceReference,
        IReadOnlyList<DetailRequest> Details);

    public sealed record DecisionRequest(string DecisionCode, string? Reason,
        string? EvidenceReference, string RowVersion);

    [HttpGet("actions")]
    public async Task<IActionResult> Actions([FromQuery] string mode,
        CancellationToken token)
    {
        if (!TryScope(out _, out _)) return Forbid();
        var menu = Menu(mode);
        if (menu is null) return BadRequest(new { message = "โหมดหน้าจอไม่ถูกต้อง" });
        await using var connection = await Open(token);
        return Ok(new
        {
            menuCode = menu,
            caption = await Caption(connection, menu, token),
            screenType = mode.Equals("approval", StringComparison.OrdinalIgnoreCase) ? 3 : 4,
            view = await Can(connection, menu, "VIEW", token),
            create = mode.Equals("approval", StringComparison.OrdinalIgnoreCase)
                ? false : await Can(connection, menu, "CREATE", token),
            submit = mode.Equals("self", StringComparison.OrdinalIgnoreCase) &&
                     await Can(connection, menu, "SUBMIT", token),
            actOnBehalf = mode.Equals("proxy", StringComparison.OrdinalIgnoreCase) &&
                          await Can(connection, menu, "ACT_ON_BEHALF", token),
            approve = mode.Equals("approval", StringComparison.OrdinalIgnoreCase) &&
                      await Can(connection, menu, "APPROVE", token),
            cancel = mode.Equals("self", StringComparison.OrdinalIgnoreCase) &&
                     await Can(connection, menu, "CANCEL", token),
        });
    }

    [HttpGet("lookups")]
    public async Task<IActionResult> Lookups([FromQuery] string mode,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var menu = Menu(mode);
        if (menu is null) return BadRequest(new { message = "โหมดหน้าจอไม่ถูกต้อง" });
        await using var connection = await Open(token);
        if (!await Can(connection, menu, "VIEW", token)) return Forbid();
        var employees = await Employees(connection, companyId, userId,
            mode.Equals("self", StringComparison.OrdinalIgnoreCase), token);
        var adjustmentReasons = await LookupReasons(connection,
            "TDTMTimeAdjustmentReason", "TimeAdjustmentReasonID", companyId, token);
        var onBehalfReasons = mode.Equals("proxy", StringComparison.OrdinalIgnoreCase)
            ? await LookupReasons(connection, "TDTMOnBehalfReason", "OnBehalfReasonID", companyId, token)
            : [];
        return Ok(new { employees, adjustmentReasons, onBehalfReasons });
    }

    [HttpGet("sessions")]
    public async Task<IActionResult> Sessions([FromQuery] string mode,
        [FromQuery] long employeeId, [FromQuery] DateOnly workDate,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var menu = Menu(mode);
        if (menu is null || employeeId <= 0) return BadRequest(new { message = "ข้อมูลค้นหารอบเวลาไม่ถูกต้อง" });
        await using var connection = await Open(token);
        if (!await Can(connection, menu, "VIEW", token)) return Forbid();
        if (mode.Equals("self", StringComparison.OrdinalIgnoreCase))
        {
            var ownEmployeeId = await ResolveEmployee(connection, companyId, userId, token);
            if (ownEmployeeId != employeeId) return Forbid();
        }
        else if (!await EmployeeInScope(connection, null, companyId, userId, employeeId, token)) return Forbid();
        return Ok(new { items = await EffectiveSessions(connection, companyId, employeeId, workDate, token) });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string mode,
        [FromQuery] string? status, [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var menu = Menu(mode);
        if (menu is null) return BadRequest(new { message = "โหมดหน้าจอไม่ถูกต้อง" });
        if (page < 1 || pageSize is < 1 or > 100)
            return BadRequest(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง" });
        await using var connection = await Open(token);
        if (!await Can(connection, menu, "VIEW", token)) return Forbid();
        var selfEmployeeId = await ResolveEmployee(connection, companyId, userId, token);
        if (mode.Equals("self", StringComparison.OrdinalIgnoreCase))
        {
            if (!selfEmployeeId.HasValue)
                return Conflict(new { message = "User ยังไม่ได้ผูกกับพนักงานที่ใช้งานอยู่" });
        }
        status = Clean(status)?.ToUpperInvariant();
        if (mode.Equals("approval", StringComparison.OrdinalIgnoreCase)) status ??= "PENDING";
        const string from = """
FROM dbo.TDTMRequest R
JOIN dbo.TDTMTimeCorrectionRequest C ON C.RequestID=R.RequestID AND C.CompanyID=R.CompanyID
JOIN dbo.TDADEmployee E ON E.EmployeeID=R.SubjectEmployeeID AND E.CompanyID=R.CompanyID
JOIN dbo.TDTMTimeAdjustmentReason AR ON AR.TimeAdjustmentReasonID=C.TimeAdjustmentReasonID AND AR.CompanyID=C.CompanyID
WHERE R.CompanyID=@CompanyID AND R.ProcessCode='TIME_CORRECTION'
  AND (@Status IS NULL OR R.StatusCode=@Status)
  AND (@SelfMode=0 OR R.SubjectEmployeeID=@SelfEmployeeID)
  AND (@SelfMode=1 OR
       EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@CompanyID AND U.UserID=@UserID AND U.IsActive=1 AND U.IsCompanyAdmin=1)
       OR EXISTS(SELECT 1 FROM dbo.TDTMEmployeeDataScopeGrant G WHERE G.CompanyID=@CompanyID AND G.IsActive=1 AND(G.UserID=@UserID OR G.RoleGroupID IN(SELECT ERG.RoleGroupID FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSDATETIME()) AND(ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSDATETIME())) WHERE UE.CompanyID=@CompanyID AND UE.UserID=@UserID AND UE.IsActive=1)) AND G.EffectiveFrom<=SYSDATETIME() AND(G.EffectiveTo IS NULL OR G.EffectiveTo>SYSDATETIME()) AND
          (G.ScopeTypeCode='ALL' OR G.ScopeTypeCode='SELF' AND R.SubjectEmployeeID=@SelfEmployeeID OR G.ScopeTypeCode='DIVISION' AND G.ScopeReferenceID=E.DivisionOrgUnitID OR G.ScopeTypeCode='DEPARTMENT' AND G.ScopeReferenceID=E.DepartmentOrgUnitID)))
  AND (@ApprovalMode=0 OR R.StatusCode='PENDING')
  AND (@ApprovalMode=0 OR NOT EXISTS(SELECT 1 FROM dbo.TDTMWorkflowSnapshot W JOIN dbo.TDTMApprovalProfileVersion V ON V.ApprovalProfileVersionID=W.ApprovalProfileVersionID WHERE W.RequestID=R.RequestID AND COALESCE((SELECT P.ProfileCode FROM dbo.TDTMProcessApprovalPolicyVersion P WHERE P.ProcessApprovalPolicyVersionID=W.ProcessApprovalPolicyVersionID),V.ProfileCode)='SEGREGATED_WORKFLOW' AND R.ActorUserID=@UserID))
""";
        await using var count = new SqlCommand($"SELECT COUNT_BIG(1) {from}", connection);
        BindList(count, companyId, userId, status, selfEmployeeId,
            mode.Equals("self", StringComparison.OrdinalIgnoreCase),
            mode.Equals("approval", StringComparison.OrdinalIgnoreCase));
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var command = new SqlCommand($"""
SELECT R.RequestID,E.EmployeeCode,E.FullName,C.WorkDate,AR.ReasonName,
       R.InitiationModeCode,R.StatusCode,R.SubmittedDate,C.RequestRemark,
       R.EvidenceReference,CONVERT(varchar(32),R.RowVersion,2),
       (SELECT COUNT_BIG(1) FROM dbo.TDTMTimeCorrectionDetail D WHERE D.RequestID=R.RequestID)
{from}
ORDER BY R.CreateDate DESC,R.RequestID DESC
OFFSET @Offset ROWS FETCH NEXT @Take ROWS ONLY;
""", connection);
        BindList(command, companyId, userId, status, selfEmployeeId,
            mode.Equals("self", StringComparison.OrdinalIgnoreCase),
            mode.Equals("approval", StringComparison.OrdinalIgnoreCase));
        Add(command, "@Offset", SqlDbType.Int, (page - 1) * pageSize);
        Add(command, "@Take", SqlDbType.Int, pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new
        {
            requestId = reader.GetInt64(0), employeeCode = reader.GetString(1),
            employeeName = reader.GetString(2), workDate = DateOnly.FromDateTime(reader.GetDateTime(3)),
            reasonName = reader.GetString(4), initiationModeCode = reader.GetString(5),
            statusCode = reader.GetString(6), submittedDate = reader.GetDateTime(7),
            remark = Text(reader, 8), evidenceReference = Text(reader, 9),
            rowVersion = reader.GetString(10), detailCount = reader.GetInt64(11),
        });
        return Ok(new { total, page, pageSize, items });
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, [FromQuery] string mode,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var menu = Menu(mode);
        if (menu is null) return BadRequest(new { message = "โหมดหน้าจอไม่ถูกต้อง" });
        await using var connection = await Open(token);
        if (!await Can(connection, menu, "VIEW", token)) return Forbid();
        var selfEmployeeId = mode.Equals("self", StringComparison.OrdinalIgnoreCase)
            ? await ResolveEmployee(connection, companyId, userId, token) : null;
        await using var command = new SqlCommand("""
SELECT R.RequestID,R.SubjectEmployeeID,E.EmployeeCode,E.FullName,C.WorkDate,
       C.TimeAdjustmentReasonID,AR.ReasonName,R.OnBehalfReasonID,OB.ReasonName,
       R.InitiationModeCode,R.StatusCode,C.RequestRemark,R.EvidenceReference,
       CONVERT(varchar(32),R.RowVersion,2)
FROM dbo.TDTMRequest R
JOIN dbo.TDTMTimeCorrectionRequest C ON C.RequestID=R.RequestID AND C.CompanyID=R.CompanyID
JOIN dbo.TDADEmployee E ON E.EmployeeID=R.SubjectEmployeeID AND E.CompanyID=R.CompanyID
JOIN dbo.TDTMTimeAdjustmentReason AR ON AR.TimeAdjustmentReasonID=C.TimeAdjustmentReasonID
LEFT JOIN dbo.TDTMOnBehalfReason OB ON OB.OnBehalfReasonID=R.OnBehalfReasonID
WHERE R.CompanyID=@CompanyID AND R.RequestID=@ID
  AND (@SelfEmployeeID IS NULL OR R.SubjectEmployeeID=@SelfEmployeeID);
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@ID", SqlDbType.BigInt, id);
        Add(command, "@SelfEmployeeID", SqlDbType.BigInt, selfEmployeeId);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound();
        var header = new
        {
            requestId = reader.GetInt64(0), employeeId = reader.GetInt64(1),
            employeeCode = reader.GetString(2), employeeName = reader.GetString(3),
            workDate = DateOnly.FromDateTime(reader.GetDateTime(4)),
            timeAdjustmentReasonId = reader.GetInt64(5), adjustmentReasonName = reader.GetString(6),
            onBehalfReasonId = Long(reader, 7), onBehalfReasonName = Text(reader, 8),
            initiationModeCode = reader.GetString(9), statusCode = reader.GetString(10),
            remark = Text(reader, 11), evidenceReference = Text(reader, 12),
            rowVersion = reader.GetString(13),
        };
        await reader.CloseAsync();
        if (!mode.Equals("self", StringComparison.OrdinalIgnoreCase) &&
            !await EmployeeInScope(connection, null, companyId, userId, header.employeeId, token)) return Forbid();
        await using var detailsCommand = new SqlCommand("""
SELECT TimeCorrectionDetailID,SequenceNo,AttendanceSessionRuleID,SessionName,
       EndpointCode,OriginalDateTime,RequestedDateTime
FROM dbo.TDTMTimeCorrectionDetail WHERE RequestID=@ID ORDER BY SequenceNo;
""", connection);
        Add(detailsCommand, "@ID", SqlDbType.BigInt, id);
        await using var detailsReader = await detailsCommand.ExecuteReaderAsync(token);
        var details = new List<object>();
        while (await detailsReader.ReadAsync(token)) details.Add(new
        {
            detailId = detailsReader.GetInt64(0), sequenceNo = detailsReader.GetInt32(1),
            attendanceSessionRuleId = Long(detailsReader, 2), sessionName = detailsReader.GetString(3),
            endpointCode = detailsReader.GetString(4), originalDateTime = DateTimeValue(detailsReader, 5),
            requestedDateTime = detailsReader.GetDateTime(6),
        });
        return Ok(new { header, details });
    }

    [HttpPost("proxy")]
    public Task<IActionResult> CreateProxy(SaveRequest request, CancellationToken token) =>
        Create(request, false, token);

    [HttpPost("self")]
    public Task<IActionResult> CreateSelf(SaveRequest request, CancellationToken token) =>
        Create(request, true, token);

    [HttpPost("{id:long}/decision")]
    public async Task<IActionResult> Decide(long id, DecisionRequest request,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var decision = request.DecisionCode.Trim().ToUpperInvariant();
        if (decision is not ("APPROVED" or "REJECTED") ||
            !ValidRowVersion(request.RowVersion))
            return BadRequest(new { message = "ผลการอนุมัติหรือ Version ไม่ถูกต้อง" });
        if (decision == "REJECTED" && Clean(request.Reason) is null)
            return BadRequest(new { message = "กรุณาระบุเหตุผลที่ไม่อนุมัติ" });
        await using var connection = await Open(token);
        if (!await Can(connection, InboxMenu, "APPROVE", token)) return Forbid();
        var canSelfApprove = await Can(connection, InboxMenu, "SELF_APPROVE", token);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var current = await LoadPending(connection, transaction, companyId, id, token);
            if (current is null) return Conflict(new { message = "คำขอนี้ไม่ได้อยู่ระหว่างรออนุมัติ" });
            if (!await EmployeeInScope(connection, transaction, companyId, userId, current.EmployeeId, token)) return Forbid();
            var actorEmployee = await ResolveEmployee(connection, transaction, companyId, userId, token);
            var selfApprove = actorEmployee == current.EmployeeId;
            if (current.ActorUserId == userId && current.ProfileCode == "SEGREGATED_WORKFLOW") return Forbid();
            if (selfApprove && !canSelfApprove) return Forbid();
            await using var update = new SqlCommand("UPDATE dbo.TDTMRequest SET StatusCode=@Status,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND RequestID=@ID AND StatusCode='PENDING' AND RowVersion=CONVERT(binary(8),@RowVersion,2)", connection, transaction);
            Add(update, "@Status", SqlDbType.VarChar, decision, 20); Add(update, "@UserID", SqlDbType.BigInt, userId);
            Add(update, "@CompanyID", SqlDbType.BigInt, companyId); Add(update, "@ID", SqlDbType.BigInt, id);
            Add(update, "@RowVersion", SqlDbType.VarChar, request.RowVersion, 32);
            if (await update.ExecuteNonQueryAsync(token) != 1) throw new InvalidOperationException("คำขอถูกแก้ไขแล้ว กรุณาโหลดใหม่");
            await InsertDecision(connection, transaction, id, userId, actorEmployee, selfApprove,
                decision, Clean(request.Reason), Clean(request.EvidenceReference), token);
            if (decision == "APPROVED") await CreateAdjustments(connection, transaction, companyId, id, current.EmployeeId, userId, token);
            await InsertNotification(connection, transaction, companyId, id, current.EmployeeId, decision, token);
            await transaction.CommitAsync(token);
            return NoContent();
        }
        catch (InvalidOperationException exception)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = exception.Message });
        }
    }

    [HttpPost("{id:long}/cancel")]
    public async Task<IActionResult> Cancel(long id, DecisionRequest request,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        if (Clean(request.Reason) is null || !ValidRowVersion(request.RowVersion))
            return BadRequest(new { message = "กรุณาระบุเหตุผลและ Version ของคำขอ" });
        await using var connection = await Open(token);
        if (!await Can(connection, SelfMenu, "CANCEL", token)) return Forbid();
        var employeeId = await ResolveEmployee(connection, companyId, userId, token);
        if (!employeeId.HasValue) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        await using var command = new SqlCommand("UPDATE dbo.TDTMRequest SET StatusCode='CANCELLED',UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND RequestID=@ID AND SubjectEmployeeID=@EmployeeID AND StatusCode='PENDING' AND RowVersion=CONVERT(binary(8),@RowVersion,2)", connection, transaction);
        Add(command, "@UserID", SqlDbType.BigInt, userId); Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@ID", SqlDbType.BigInt, id); Add(command, "@EmployeeID", SqlDbType.BigInt, employeeId.Value);
        Add(command, "@RowVersion", SqlDbType.VarChar, request.RowVersion, 32);
        if (await command.ExecuteNonQueryAsync(token) != 1)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = "คำขอถูกดำเนินการแล้ว กรุณาโหลดใหม่" });
        }
        await InsertDecision(connection, transaction, id, userId, employeeId, false,
            "CANCELLED", Clean(request.Reason), Clean(request.EvidenceReference), token);
        await InsertEditLog(connection, transaction, id, userId, "StatusCode",
            "PENDING", "CANCELLED", Clean(request.Reason)!, token);
        await InsertNotification(connection, transaction, companyId, id, employeeId.Value,
            "CANCELLED", token);
        await transaction.CommitAsync(token);
        return NoContent();
    }

    private async Task<IActionResult> Create(SaveRequest request, bool self,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var error = Validate(request);
        if (error is not null) return BadRequest(new { message = error });
        await using var connection = await Open(token);
        var menu = self ? SelfMenu : ProxyMenu;
        if (!await Can(connection, menu, "CREATE", token) ||
            self && !await Can(connection, menu, "SUBMIT", token) ||
            !self && !await Can(connection, menu, "ACT_ON_BEHALF", token)) return Forbid();
        var canDirectApprove = !self && await Can(connection, ProxyMenu, "APPROVE", token);
        var canSelfApprove = !self && await Can(connection, ProxyMenu, "SELF_APPROVE", token);
        var employeeId = self
            ? await ResolveEmployee(connection, companyId, userId, token)
            : request.EmployeeId;
        if (!employeeId.HasValue) return Conflict(new { message = "ไม่พบพนักงานที่ทำรายการ" });
        if (!self && !await EmployeeInScope(connection, null, companyId, userId, employeeId.Value, token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            if (!await ActiveEmployee(connection, transaction, companyId, employeeId.Value, token))
                throw new InvalidOperationException("พนักงานไม่มีสถานะการจ้างที่ใช้งานอยู่");
            var submittedDate = ThailandToday();
            var policy = await ResolvePolicy(connection, transaction, companyId, submittedDate, token)
                ?? throw new InvalidOperationException("ยังไม่ได้กำหนด Employee Request Policy กรุณาบันทึกหน้ากำหนดค่าระบบเวลา");
            if (self && policy.Code == "PROXY_ONLY") throw new InvalidOperationException("บริษัทกำหนดให้ผู้ดูแลทำคำขอแทนเท่านั้น");
            if (!self && policy.Code == "SELF_SERVICE_ONLY") throw new InvalidOperationException("บริษัทกำหนดให้พนักงานต้องเริ่มคำขอด้วยตนเอง");
            var profile = await ResolveProfile(connection, transaction, companyId, submittedDate, token)
                ?? throw new InvalidOperationException("ยังไม่ได้กำหนด Approval Control Profile กรุณาบันทึกหน้ากำหนดค่าระบบเวลา");
            if (!await ReasonValid(connection, transaction, "TDTMTimeAdjustmentReason", "TimeAdjustmentReasonID", companyId, request.TimeAdjustmentReasonId, request.RequestRemark, request.EvidenceReference, token))
                throw new InvalidOperationException("เหตุผลปรับเวลาหรือข้อมูลประกอบไม่ครบตามที่กำหนด");
            if (!self && (!request.OnBehalfReasonId.HasValue || !await ReasonValid(connection, transaction, "TDTMOnBehalfReason", "OnBehalfReasonID", companyId, request.OnBehalfReasonId.Value, request.OnBehalfRemark, request.EvidenceReference, token)))
                throw new InvalidOperationException("เหตุผลทำแทนหรือข้อมูลประกอบไม่ครบตามที่กำหนด");
            await EnsureSessionsValid(connection, transaction, companyId,
                employeeId.Value, request, token);
            await EnsureNoPendingDuplicates(connection, transaction, companyId, employeeId.Value, request, token);
            var direct = !self && profile.Code == "OWNER_OPERATED" && canDirectApprove;
            var actorEmployee = await ResolveEmployee(connection, transaction, companyId, userId, token);
            var selfApprove = direct && actorEmployee == employeeId.Value;
            if (selfApprove && !canSelfApprove)
                throw new InvalidOperationException("ไม่มีสิทธิ์อนุมัติรายการของตนเอง");
            var requestId = await InsertRequest(connection, transaction, companyId, userId,
                employeeId.Value, request, self, direct, token);
            await InsertSnapshots(connection, transaction, requestId, policy, profile, token);
            await InsertCorrection(connection, transaction, companyId, employeeId.Value, requestId, request, token);
            if (direct)
            {
                await InsertDecision(connection, transaction, requestId, userId, actorEmployee,
                    selfApprove, "APPROVED", Clean(request.RequestRemark), Clean(request.EvidenceReference), token);
                await CreateAdjustments(connection, transaction, companyId, requestId, employeeId.Value, userId, token);
            }
            await InsertNotification(connection, transaction, companyId, requestId,
                employeeId.Value, direct ? "APPROVED" : "PENDING", token);
            await transaction.CommitAsync(token);
            return Ok(new { requestId, statusCode = direct ? "APPROVED" : "PENDING" });
        }
        catch (InvalidOperationException exception)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = exception.Message });
        }
    }

    private sealed record Policy(long Id, string Code);
    private sealed record Profile(long Id, long? ProcessId, string Code);
    private sealed record Pending(long EmployeeId, long ActorUserId, string ProfileCode);

    private static string? Validate(SaveRequest request)
    {
        if (request.TimeAdjustmentReasonId <= 0 || request.Details is null || request.Details.Count == 0)
            return "กรุณาระบุเหตุผลและรายการเวลาที่ต้องการปรับ";
        if (request.Details.Count > 20) return "คำขอหนึ่งรายการแก้เวลาได้ไม่เกิน 20 จุด";
        var keys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var detail in request.Details)
        {
            var name = Clean(detail.SessionName);
            var endpoint = detail.EndpointCode.Trim().ToUpperInvariant();
            if (!detail.AttendanceSessionRuleId.HasValue || detail.AttendanceSessionRuleId <= 0 ||
                name is null || name.Length > 100 || endpoint is not ("IN" or "OUT")) return "ข้อมูลรอบเวลาไม่ถูกต้อง";
            var requested = DateTime.SpecifyKind(detail.RequestedDateTime, DateTimeKind.Unspecified);
            if (DateOnly.FromDateTime(requested) != request.WorkDate && DateOnly.FromDateTime(requested) != request.WorkDate.AddDays(1)) return "เวลาที่ขอต้องอยู่ในวันทำงานหรือวันถัดไปสำหรับกะข้ามวัน";
            if (!keys.Add($"{name}|{endpoint}")) return "มีรายการรอบเวลาและฝั่งเข้าออกซ้ำกัน";
        }
        if (Clean(request.RequestRemark)?.Length > 1000 || Clean(request.OnBehalfRemark)?.Length > 1000 || Clean(request.EvidenceReference)?.Length > 1000) return "หมายเหตุหรือหลักฐานยาวเกิน 1,000 ตัวอักษร";
        return null;
    }

    private async Task<bool> Can(SqlConnection connection, string menu, string action,
        CancellationToken token) => await CompanyMenuAccess.IsAllowedAsync(connection, User, menu, action, token);

    private static string? Menu(string mode) => mode.Trim().ToLowerInvariant() switch
    {
        "proxy" => ProxyMenu, "approval" => InboxMenu, "self" => SelfMenu, _ => null,
    };

    private static async Task<Policy?> ResolvePolicy(SqlConnection c, SqlTransaction tx,
        long companyId, DateOnly date, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT TOP(1) RequestPolicyVersionID,PolicyCode FROM dbo.TDTMEmployeeRequestPolicyVersion WHERE CompanyID=@C AND ProcessCode='TIME_CORRECTION' AND IsActive=1 AND EffectiveFrom<=@D AND(EffectiveTo IS NULL OR EffectiveTo>=@D) ORDER BY EffectiveFrom DESC,RequestPolicyVersionID DESC", c, tx);
        Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@D", SqlDbType.Date, date.ToDateTime(TimeOnly.MinValue));
        await using var r = await q.ExecuteReaderAsync(token); return await r.ReadAsync(token) ? new Policy(r.GetInt64(0), r.GetString(1)) : null;
    }

    private static async Task<Profile?> ResolveProfile(SqlConnection c, SqlTransaction tx,
        long companyId, DateOnly date, CancellationToken token)
    {
        await using var q = new SqlCommand("""
SELECT TOP(1) B.ApprovalProfileVersionID,P.ProcessApprovalPolicyVersionID,
       COALESCE(P.ProfileCode,B.ProfileCode)
FROM dbo.TDTMApprovalProfileVersion B
OUTER APPLY(SELECT TOP(1) X.ProcessApprovalPolicyVersionID,X.ProfileCode FROM dbo.TDTMProcessApprovalPolicyVersion X WHERE X.CompanyID=B.CompanyID AND X.ProcessCode='TIME' AND X.IsActive=1 AND X.EffectiveFrom<=@D AND(X.EffectiveTo IS NULL OR X.EffectiveTo>=@D) ORDER BY X.EffectiveFrom DESC,X.ProcessApprovalPolicyVersionID DESC)P
WHERE B.CompanyID=@C AND B.IsActive=1 AND B.EffectiveFrom<=@D AND(B.EffectiveTo IS NULL OR B.EffectiveTo>=@D)
ORDER BY B.EffectiveFrom DESC,B.ApprovalProfileVersionID DESC;
""", c, tx);
        Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@D", SqlDbType.Date, date.ToDateTime(TimeOnly.MinValue));
        await using var r = await q.ExecuteReaderAsync(token); return await r.ReadAsync(token) ? new Profile(r.GetInt64(0), Long(r, 1), r.GetString(2)) : null;
    }

    private static async Task<long> InsertRequest(SqlConnection c, SqlTransaction tx,
        long companyId, long userId, long employeeId, SaveRequest request,
        bool self, bool direct, CancellationToken token)
    {
        await using var q = new SqlCommand("INSERT dbo.TDTMRequest(CompanyID,ProcessCode,SubjectEmployeeID,InitiationModeCode,ActorUserID,OnBehalfReasonID,OnBehalfRemark,EvidenceReference,StatusCode,SubmittedDate,CreateBy) OUTPUT INSERTED.RequestID VALUES(@C,'TIME_CORRECTION',@E,@Mode,@U,@OnBehalf,@Remark,@Evidence,@Status,SYSDATETIME(),@U)", c, tx);
        Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@E", SqlDbType.BigInt, employeeId);
        Add(q, "@Mode", SqlDbType.VarChar, self ? "SELF" : "PROXY", 10); Add(q, "@U", SqlDbType.BigInt, userId);
        Add(q, "@OnBehalf", SqlDbType.BigInt, self ? null : request.OnBehalfReasonId);
        Add(q, "@Remark", SqlDbType.NVarChar, self ? null : Clean(request.OnBehalfRemark), 1000); Add(q, "@Evidence", SqlDbType.NVarChar, Clean(request.EvidenceReference), 1000);
        Add(q, "@Status", SqlDbType.VarChar, direct ? "APPROVED" : "PENDING", 20);
        return Convert.ToInt64(await q.ExecuteScalarAsync(token));
    }

    private static async Task InsertSnapshots(SqlConnection c, SqlTransaction tx,
        long requestId, Policy policy, Profile profile, CancellationToken token)
    {
        var policyJson = JsonSerializer.Serialize(new { processCode = "TIME_CORRECTION", policyCode = policy.Code, policyVersionId = policy.Id });
        var workflowJson = JsonSerializer.Serialize(new { processCode = "TIME", profileCode = profile.Code, approvalProfileVersionId = profile.Id, processApprovalPolicyVersionId = profile.ProcessId });
        await using var p = new SqlCommand("INSERT dbo.TDTMRequestPolicySnapshot(RequestID,RequestPolicyVersionID,PolicyCode,SnapshotJson,SnapshotHash)VALUES(@R,@V,@Code,@Json,@Hash)", c, tx);
        Add(p, "@R", SqlDbType.BigInt, requestId); Add(p, "@V", SqlDbType.BigInt, policy.Id); Add(p, "@Code", SqlDbType.VarChar, policy.Code, 30); Add(p, "@Json", SqlDbType.NVarChar, policyJson, -1); Add(p, "@Hash", SqlDbType.VarBinary, SHA256.HashData(Encoding.UTF8.GetBytes(policyJson)), 32); await p.ExecuteNonQueryAsync(token);
        await using var w = new SqlCommand("INSERT dbo.TDTMWorkflowSnapshot(RequestID,ApprovalProfileVersionID,ProcessApprovalPolicyVersionID,SnapshotJson,SnapshotHash)VALUES(@R,@B,@P,@Json,@Hash)", c, tx);
        Add(w, "@R", SqlDbType.BigInt, requestId); Add(w, "@B", SqlDbType.BigInt, profile.Id); Add(w, "@P", SqlDbType.BigInt, profile.ProcessId); Add(w, "@Json", SqlDbType.NVarChar, workflowJson, -1); Add(w, "@Hash", SqlDbType.VarBinary, SHA256.HashData(Encoding.UTF8.GetBytes(workflowJson)), 32); await w.ExecuteNonQueryAsync(token);
    }

    private static async Task InsertCorrection(SqlConnection c, SqlTransaction tx,
        long companyId, long employeeId, long requestId, SaveRequest request,
        CancellationToken token)
    {
        await using var h = new SqlCommand("INSERT dbo.TDTMTimeCorrectionRequest(RequestID,CompanyID,SubjectEmployeeID,WorkDate,TimeAdjustmentReasonID,RequestRemark)VALUES(@R,@C,@E,@D,@Reason,@Remark)", c, tx);
        Add(h, "@R", SqlDbType.BigInt, requestId); Add(h, "@C", SqlDbType.BigInt, companyId); Add(h, "@E", SqlDbType.BigInt, employeeId); Add(h, "@D", SqlDbType.Date, request.WorkDate.ToDateTime(TimeOnly.MinValue)); Add(h, "@Reason", SqlDbType.BigInt, request.TimeAdjustmentReasonId); Add(h, "@Remark", SqlDbType.NVarChar, Clean(request.RequestRemark), 1000); await h.ExecuteNonQueryAsync(token);
        for (var i = 0; i < request.Details.Count; i++)
        {
            var d = request.Details[i]; await using var q = new SqlCommand("INSERT dbo.TDTMTimeCorrectionDetail(RequestID,CompanyID,SubjectEmployeeID,WorkDate,SequenceNo,AttendanceSessionRuleID,SessionName,EndpointCode,OriginalDateTime,RequestedDateTime)VALUES(@R,@C,@E,@D,@N,@Rule,@Name,@Endpoint,@Original,@Requested)", c, tx);
            Add(q, "@R", SqlDbType.BigInt, requestId); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@E", SqlDbType.BigInt, employeeId); Add(q, "@D", SqlDbType.Date, request.WorkDate.ToDateTime(TimeOnly.MinValue)); Add(q, "@N", SqlDbType.Int, i + 1); Add(q, "@Rule", SqlDbType.BigInt, d.AttendanceSessionRuleId); Add(q, "@Name", SqlDbType.NVarChar, Clean(d.SessionName), 100); Add(q, "@Endpoint", SqlDbType.VarChar, d.EndpointCode.Trim().ToUpperInvariant(), 10); Add(q, "@Original", SqlDbType.DateTime2, Local(d.OriginalDateTime)); Add(q, "@Requested", SqlDbType.DateTime2, Local(d.RequestedDateTime)); await q.ExecuteNonQueryAsync(token);
        }
    }

    private static async Task CreateAdjustments(SqlConnection c, SqlTransaction tx,
        long companyId, long requestId, long employeeId, long userId, CancellationToken token)
    {
        await using var read = new SqlCommand("SELECT TimeCorrectionDetailID,WorkDate,AttendanceSessionRuleID,SessionName,EndpointCode,RequestedDateTime FROM dbo.TDTMTimeCorrectionDetail WHERE RequestID=@R ORDER BY SequenceNo", c, tx); Add(read, "@R", SqlDbType.BigInt, requestId);
        await using var reader = await read.ExecuteReaderAsync(token); var rows = new List<(long Id,DateTime Date,long RuleId,string Name,string Endpoint,DateTime Value)>(); while (await reader.ReadAsync(token)) rows.Add((reader.GetInt64(0),reader.GetDateTime(1),reader.GetInt64(2),reader.GetString(3),reader.GetString(4),reader.GetDateTime(5))); await reader.CloseAsync();
        foreach (var row in rows)
        {
            await using var q = new SqlCommand("""
DECLARE @Previous bigint=(SELECT TOP(1) TimeAdjustmentID FROM dbo.TDTMTimeAdjustment WHERE CompanyID=@C AND SubjectEmployeeID=@E AND WorkDate=@D AND AttendanceSessionRuleID=@Rule AND EndpointCode=@Endpoint ORDER BY CreateDate DESC,TimeAdjustmentID DESC);
INSERT dbo.TDTMTimeAdjustment(CompanyID,RequestID,TimeCorrectionDetailID,SubjectEmployeeID,WorkDate,AttendanceSessionRuleID,SessionName,EndpointCode,AdjustedDateTime,SupersedesTimeAdjustmentID,CreateBy,CorrelationID)
VALUES(@C,@R,@Detail,@E,@D,@Rule,@Name,@Endpoint,@Value,@Previous,@U,NEWID());
""", c, tx);
            Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@R", SqlDbType.BigInt, requestId); Add(q, "@Detail", SqlDbType.BigInt, row.Id); Add(q, "@E", SqlDbType.BigInt, employeeId); Add(q, "@D", SqlDbType.Date, row.Date); Add(q, "@Rule", SqlDbType.BigInt, row.RuleId); Add(q, "@Name", SqlDbType.NVarChar, row.Name, 100); Add(q, "@Endpoint", SqlDbType.VarChar, row.Endpoint, 10); Add(q, "@Value", SqlDbType.DateTime2, row.Value); Add(q, "@U", SqlDbType.BigInt, userId); await q.ExecuteNonQueryAsync(token);
        }
    }

    private static async Task InsertDecision(SqlConnection c, SqlTransaction tx,
        long requestId, long userId, long? actorEmployeeId, bool selfApproved,
        string decision, string? reason, string? evidence, CancellationToken token)
    {
        await using var q = new SqlCommand("INSERT dbo.TDTMApprovalDecision(RequestID,StepOrder,DecisionCode,ActorUserID,ActorEmployeeID,IsSelfApproved,Reason,EvidenceReference,CorrelationID)VALUES(@R,0,@Decision,@U,@E,@Self,@Reason,@Evidence,NEWID())", c, tx);
        Add(q, "@R", SqlDbType.BigInt, requestId); Add(q, "@Decision", SqlDbType.VarChar, decision, 20); Add(q, "@U", SqlDbType.BigInt, userId); Add(q, "@E", SqlDbType.BigInt, actorEmployeeId); Add(q, "@Self", SqlDbType.Bit, selfApproved); Add(q, "@Reason", SqlDbType.NVarChar, reason, 1000); Add(q, "@Evidence", SqlDbType.NVarChar, evidence, 1000); await q.ExecuteNonQueryAsync(token);
    }

    private static async Task InsertEditLog(SqlConnection c, SqlTransaction tx,
        long requestId, long userId, string field, string? before, string? after,
        string reason, CancellationToken token)
    {
        await using var q = new SqlCommand("INSERT dbo.TDTMRequestEditLog(RequestID,FieldPath,BeforeValue,AfterValue,Reason,ActorUserID,CorrelationID)VALUES(@R,@Field,@Before,@After,@Reason,@U,NEWID())", c, tx);
        Add(q, "@R", SqlDbType.BigInt, requestId); Add(q, "@Field", SqlDbType.NVarChar, field, 300);
        Add(q, "@Before", SqlDbType.NVarChar, before, -1); Add(q, "@After", SqlDbType.NVarChar, after, -1);
        Add(q, "@Reason", SqlDbType.NVarChar, reason, 1000); Add(q, "@U", SqlDbType.BigInt, userId);
        await q.ExecuteNonQueryAsync(token);
    }

    private static async Task InsertNotification(SqlConnection c, SqlTransaction tx,
        long companyId, long requestId, long employeeId, string status,
        CancellationToken token)
    {
        var json = JsonSerializer.Serialize(new { requestId, processCode = "TIME_CORRECTION", statusCode = status });
        await using var q = new SqlCommand("INSERT dbo.TDTMNotificationDelivery(CompanyID,RequestID,RecipientEmployeeID,ChannelCode,StatusCode,PayloadJson,CorrelationID)VALUES(@C,@R,@E,'IN_APP','PENDING',@Json,NEWID())", c, tx); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@R", SqlDbType.BigInt, requestId); Add(q, "@E", SqlDbType.BigInt, employeeId); Add(q, "@Json", SqlDbType.NVarChar, json, -1); await q.ExecuteNonQueryAsync(token);
    }

    private static async Task EnsureNoPendingDuplicates(SqlConnection c, SqlTransaction tx,
        long companyId, long employeeId, SaveRequest request, CancellationToken token)
    {
        foreach (var d in request.Details)
        {
            await using var q = new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMTimeCorrectionDetail D WITH(UPDLOCK,HOLDLOCK) JOIN dbo.TDTMRequest R ON R.RequestID=D.RequestID WHERE D.CompanyID=@C AND D.SubjectEmployeeID=@E AND D.WorkDate=@D AND D.AttendanceSessionRuleID=@Rule AND D.EndpointCode=@Endpoint AND R.StatusCode='PENDING'", c, tx); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@E", SqlDbType.BigInt, employeeId); Add(q, "@D", SqlDbType.Date, request.WorkDate.ToDateTime(TimeOnly.MinValue)); Add(q, "@Rule", SqlDbType.BigInt, d.AttendanceSessionRuleId); Add(q, "@Endpoint", SqlDbType.VarChar, d.EndpointCode.Trim().ToUpperInvariant(), 10); if (Convert.ToInt64(await q.ExecuteScalarAsync(token)) > 0) throw new InvalidOperationException("มีคำขอปรับเวลาจุดเดียวกันที่กำลังรออนุมัติอยู่แล้ว");
        }
    }

    private static async Task EnsureSessionsValid(SqlConnection c, SqlTransaction tx,
        long companyId, long employeeId, SaveRequest request, CancellationToken token)
    {
        var valid = await EffectiveSessions(c, tx, companyId, employeeId, request.WorkDate, token);
        foreach (var detail in request.Details)
        {
            var session = valid.FirstOrDefault(x => x.Id == detail.AttendanceSessionRuleId);
            if (session is null || !string.Equals(session.Name, Clean(detail.SessionName), StringComparison.Ordinal))
                throw new InvalidOperationException("รอบเวลาที่เลือกไม่ตรงกับตารางทำงานของพนักงานในวันที่ระบุ");
            var offset = detail.EndpointCode.Equals("OUT", StringComparison.OrdinalIgnoreCase)
                ? session.OutDayOffset : session.InDayOffset;
            if (DateOnly.FromDateTime(detail.RequestedDateTime) != request.WorkDate.AddDays(offset))
                throw new InvalidOperationException("วันที่ของเวลาที่ขอปรับไม่ตรงกับรอบทำงาน");
        }
    }

    private sealed record Session(long Id, string Name, int InDayOffset,
        string InTime, int OutDayOffset, string OutTime);

    private static Task<List<Session>> EffectiveSessions(SqlConnection c, long companyId,
        long employeeId, DateOnly workDate, CancellationToken token) =>
        EffectiveSessions(c, null, companyId, employeeId, workDate, token);

    private static async Task<List<Session>> EffectiveSessions(SqlConnection c, SqlTransaction? tx,
        long companyId, long employeeId, DateOnly workDate, CancellationToken token)
    {
        await using var q = new SqlCommand("""
WITH EffectiveShift AS
(
 SELECT COALESCE(O.ShiftTemplateID,RD.ShiftTemplateID) ShiftTemplateID
 FROM (VALUES(1)) X(N)
 OUTER APPLY(SELECT TOP(1) SO.ShiftTemplateID,SO.IsDayOff FROM dbo.TDTMScheduleOverride SO
   WHERE SO.CompanyID=@C AND SO.EmployeeID=@E AND SO.WorkDate=@D AND SO.IsActive=1 ORDER BY SO.ScheduleOverrideID DESC) O
 OUTER APPLY(SELECT TOP(1) A.WorkScheduleGroupID FROM dbo.TDTMWorkScheduleGroupAssignment A
   WHERE A.CompanyID=@C AND A.EmployeeID=@E AND A.IsActive=1 AND A.EffectiveFrom<=@D AND(A.EffectiveTo IS NULL OR A.EffectiveTo>=@D) ORDER BY A.EffectiveFrom DESC) A
 OUTER APPLY(SELECT TOP(1) G.RotationPatternID,G.AnchorDate FROM dbo.TDTMGroupShiftRotation G
   WHERE G.CompanyID=@C AND G.WorkScheduleGroupID=A.WorkScheduleGroupID AND G.IsActive=1 AND G.EffectiveFrom<=@D AND(G.EffectiveTo IS NULL OR G.EffectiveTo>=@D) ORDER BY G.EffectiveFrom DESC) G
 OUTER APPLY(SELECT TOP(1) V.RotationPatternVersionID,V.CycleDays FROM dbo.TDTMRotationPatternVersion V
   WHERE V.CompanyID=@C AND V.RotationPatternID=G.RotationPatternID AND V.IsActive=1 AND V.EffectiveFrom<=@D AND(V.EffectiveTo IS NULL OR V.EffectiveTo>=@D) ORDER BY V.EffectiveFrom DESC) V
 OUTER APPLY(SELECT TOP(1) D.ShiftTemplateID,D.IsDayOff FROM dbo.TDTMRotationDay D
   WHERE D.CompanyID=@C AND D.RotationPatternVersionID=V.RotationPatternVersionID
     AND D.DayNo=((DATEDIFF(day,G.AnchorDate,@D)%V.CycleDays+V.CycleDays)%V.CycleDays)+1) RD
 WHERE ISNULL(O.IsDayOff,ISNULL(RD.IsDayOff,1))=0
), EffectiveVersion AS
(
 SELECT TOP(1) V.ShiftTemplateVersionID FROM EffectiveShift S
 JOIN dbo.TDTMShiftTemplateVersion V ON V.CompanyID=@C AND V.ShiftTemplateID=S.ShiftTemplateID
 WHERE V.IsActive=1 AND V.EffectiveFrom<=@D AND(V.EffectiveTo IS NULL OR V.EffectiveTo>=@D)
 ORDER BY V.EffectiveFrom DESC,V.ShiftTemplateVersionID DESC
)
SELECT R.AttendanceSessionRuleID,R.RuleName,R.ScheduledInDayOffset,
       CONVERT(varchar(8),R.ScheduledInTime,108),R.ScheduledOutDayOffset,
       CONVERT(varchar(8),R.ScheduledOutTime,108)
FROM dbo.TDTMAttendanceSessionRule R JOIN EffectiveVersion V ON V.ShiftTemplateVersionID=R.ShiftTemplateVersionID
WHERE R.CompanyID=@C ORDER BY R.SequenceNo;
""", c, tx);
        Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@E", SqlDbType.BigInt, employeeId);
        Add(q, "@D", SqlDbType.Date, workDate.ToDateTime(TimeOnly.MinValue));
        await using var reader = await q.ExecuteReaderAsync(token);
        var rows = new List<Session>();
        while (await reader.ReadAsync(token)) rows.Add(new Session(reader.GetInt64(0),
            reader.GetString(1), reader.GetByte(2), reader.GetString(3), reader.GetByte(4), reader.GetString(5)));
        return rows;
    }

    private static async Task<bool> ReasonValid(SqlConnection c, SqlTransaction tx,
        string table, string idColumn, long companyId, long id, string? remark,
        string? evidence, CancellationToken token)
    {
        await using var q = new SqlCommand($"SELECT RequireRemark,RequireEvidence FROM dbo.{table} WHERE CompanyID=@C AND {idColumn}=@ID AND IsActive=1", c, tx); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@ID", SqlDbType.BigInt, id); await using var r = await q.ExecuteReaderAsync(token); if (!await r.ReadAsync(token)) return false; return (!r.GetBoolean(0) || Clean(remark) is not null) && (!r.GetBoolean(1) || Clean(evidence) is not null);
    }

    private static async Task<Pending?> LoadPending(SqlConnection c, SqlTransaction tx,
        long companyId, long id, CancellationToken token)
    {
        await using var q = new SqlCommand("""
SELECT R.SubjectEmployeeID,R.ActorUserID,COALESCE(P.ProfileCode,V.ProfileCode)
FROM dbo.TDTMRequest R WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDTMWorkflowSnapshot W ON W.RequestID=R.RequestID
JOIN dbo.TDTMApprovalProfileVersion V ON V.ApprovalProfileVersionID=W.ApprovalProfileVersionID
LEFT JOIN dbo.TDTMProcessApprovalPolicyVersion P ON P.ProcessApprovalPolicyVersionID=W.ProcessApprovalPolicyVersionID
WHERE R.CompanyID=@C AND R.RequestID=@ID AND R.ProcessCode='TIME_CORRECTION' AND R.StatusCode='PENDING'
""", c, tx);
        Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@ID", SqlDbType.BigInt, id);
        await using var reader = await q.ExecuteReaderAsync(token);
        return await reader.ReadAsync(token)
            ? new Pending(reader.GetInt64(0), reader.GetInt64(1), reader.GetString(2)) : null;
    }

    private static async Task<bool> ActiveEmployee(SqlConnection c, SqlTransaction tx,
        long companyId, long employeeId, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDADEmployee WHERE CompanyID=@C AND EmployeeID=@E AND IsActive=1", c, tx); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@E", SqlDbType.BigInt, employeeId); return Convert.ToInt64(await q.ExecuteScalarAsync(token)) == 1;
    }

    private static Task<long?> ResolveEmployee(SqlConnection c, long companyId,
        long userId, CancellationToken token) => ResolveEmployee(c, null, companyId, userId, token);
    private static async Task<long?> ResolveEmployee(SqlConnection c, SqlTransaction? tx,
        long companyId, long userId, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT TOP(1) E.EmployeeID FROM dbo.TDADUserEmployee UE JOIN dbo.TDADUser U ON U.UserID=UE.UserID AND U.CompanyID=UE.CompanyID AND U.IsActive=1 JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1 WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.IsActive=1 ORDER BY UE.EmployeeID", c, tx); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@U", SqlDbType.BigInt, userId); var value = await q.ExecuteScalarAsync(token); return value is null ? null : Convert.ToInt64(value);
    }

    private static async Task<bool> EmployeeInScope(SqlConnection c, SqlTransaction? tx,
        long companyId, long userId, long employeeId, CancellationToken token)
    {
        await using var q = new SqlCommand("""
SELECT CAST(CASE WHEN EXISTS
(
 SELECT 1 FROM dbo.TDADEmployee E WHERE E.CompanyID=@C AND E.EmployeeID=@E AND E.IsActive=1
 AND(EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@C AND U.UserID=@U AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDTMEmployeeDataScopeGrant G WHERE G.CompanyID=@C AND G.IsActive=1 AND(G.UserID=@U OR G.RoleGroupID IN(SELECT ERG.RoleGroupID FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSDATETIME()) AND(ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSDATETIME())) WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.IsActive=1)) AND G.EffectiveFrom<=SYSDATETIME() AND(G.EffectiveTo IS NULL OR G.EffectiveTo>SYSDATETIME()) AND(G.ScopeTypeCode='ALL' OR G.ScopeTypeCode='SELF' AND EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.EmployeeID=@E AND UE.IsActive=1) OR G.ScopeTypeCode='DIVISION' AND G.ScopeReferenceID=E.DivisionOrgUnitID OR G.ScopeTypeCode='DEPARTMENT' AND G.ScopeReferenceID=E.DepartmentOrgUnitID)))
) THEN 1 ELSE 0 END AS bit)
""", c, tx); Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@U", SqlDbType.BigInt, userId); Add(q, "@E", SqlDbType.BigInt, employeeId); return Convert.ToBoolean(await q.ExecuteScalarAsync(token));
    }

    private static async Task<List<object>> Employees(SqlConnection c, long companyId,
        long userId, bool self, CancellationToken token)
    {
        var selfEmployee = await ResolveEmployee(c, companyId, userId, token);
        if (self && !selfEmployee.HasValue) return [];
        await using var q = new SqlCommand("""
SELECT E.EmployeeID,E.EmployeeCode,E.FullName
FROM dbo.TDADEmployee E WHERE E.CompanyID=@C AND E.IsActive=1
AND (@SelfMode=0 OR E.EmployeeID=@Self)
AND (@SelfMode=1 OR
  EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@C AND U.UserID=@U AND U.IsActive=1 AND U.IsCompanyAdmin=1)
  OR EXISTS(SELECT 1 FROM dbo.TDTMEmployeeDataScopeGrant G WHERE G.CompanyID=@C AND G.IsActive=1 AND(G.UserID=@U OR G.RoleGroupID IN(SELECT ERG.RoleGroupID FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSDATETIME()) AND(ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSDATETIME())) WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.IsActive=1)) AND G.EffectiveFrom<=SYSDATETIME() AND(G.EffectiveTo IS NULL OR G.EffectiveTo>SYSDATETIME()) AND
     (G.ScopeTypeCode='ALL' OR G.ScopeTypeCode='SELF' AND E.EmployeeID=@Self OR G.ScopeTypeCode='DIVISION' AND G.ScopeReferenceID=E.DivisionOrgUnitID OR G.ScopeTypeCode='DEPARTMENT' AND G.ScopeReferenceID=E.DepartmentOrgUnitID)))
ORDER BY E.EmployeeCode
""", c);
        Add(q, "@C", SqlDbType.BigInt, companyId); Add(q, "@U", SqlDbType.BigInt, userId);
        Add(q, "@SelfMode", SqlDbType.Bit, self); Add(q, "@Self", SqlDbType.BigInt, selfEmployee);
        await using var r = await q.ExecuteReaderAsync(token);
        var rows = new List<object>();
        while (await r.ReadAsync(token)) rows.Add(new { id = r.GetInt64(0), code = r.GetString(1), name = r.GetString(2) });
        return rows;
    }

    private static async Task<List<object>> LookupReasons(SqlConnection c, string table,
        string idColumn, long companyId, CancellationToken token)
    {
        await using var q = new SqlCommand($"SELECT {idColumn},ReasonCode,ReasonName,RequireRemark,RequireEvidence FROM dbo.{table} WHERE CompanyID=@C AND IsActive=1 ORDER BY ReasonCode", c); Add(q, "@C", SqlDbType.BigInt, companyId); await using var r = await q.ExecuteReaderAsync(token); var rows = new List<object>(); while (await r.ReadAsync(token)) rows.Add(new { id = r.GetInt64(0), code = r.GetString(1), name = r.GetString(2), requireRemark = r.GetBoolean(3), requireEvidence = r.GetBoolean(4) }); return rows;
    }

    private static void BindList(SqlCommand q, long companyId, long userId, string? status,
        long? selfEmployeeId, bool self, bool approval)
    { Add(q, "@CompanyID", SqlDbType.BigInt, companyId); Add(q, "@UserID", SqlDbType.BigInt, userId); Add(q, "@Status", SqlDbType.VarChar, status, 20); Add(q, "@SelfEmployeeID", SqlDbType.BigInt, selfEmployeeId); Add(q, "@SelfMode", SqlDbType.Bit, self); Add(q, "@ApprovalMode", SqlDbType.Bit, approval); }

    private async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private bool TryScope(out long companyId, out long userId) { companyId = 0; userId = 0; return string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase) && long.TryParse(User.FindFirstValue("company_id"), out companyId) && long.TryParse(User.FindFirstValue("user_id"), out userId) && companyId > 0 && userId > 0; }
    private static async Task<string> Caption(SqlConnection c, string menu, CancellationToken token) { await using var q = new SqlCommand("SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@M", c); Add(q, "@M", SqlDbType.Char, menu, 5); return Convert.ToString(await q.ExecuteScalarAsync(token)) ?? menu; }
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static DateTime? Local(DateTime? value) => value.HasValue ? DateTime.SpecifyKind(value.Value, DateTimeKind.Unspecified) : null;
    private static DateOnly ThailandToday() => DateOnly.FromDateTime(
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow,
            TimeZoneInfo.FindSystemTimeZoneById("Asia/Bangkok")));
    private static string? Text(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static long? Long(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static DateTime? DateTimeValue(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetDateTime(i);
    private static bool ValidRowVersion(string? value) => value is { Length: 16 } && value.All(Uri.IsHexDigit);
    private static void Add(SqlCommand q, string name, SqlDbType type, object? value, int size = 0) { var p = size == 0 ? q.Parameters.Add(name, type) : q.Parameters.Add(name, type, size); p.Value = value ?? DBNull.Value; }
}
