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

public sealed record LeaveRequestSaveRequest(long? EmployeeId, long LeaveTypeId,
    DateOnly StartWorkDate, DateOnly EndWorkDate, decimal RequestedQuantity,
    string? RequestRemark, string? EvidenceReference, long? OnBehalfReasonId,
    string? OnBehalfRemark, int? StartMinute, int? EndMinute);
public sealed record LeaveDecisionRequest(string DecisionCode, string? Reason,
    string RowVersion);
public sealed record LeaveCancelRequest(string RowVersion, string? Reason);

[ApiController]
[Route("api/time/leave-requests")]
[Authorize]
public sealed class LeaveRequestsController(IConfiguration configuration) : ControllerBase
{
    private const string ProxyMenu = "26003", InboxMenu = "26004", SelfMenu = "30003";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions([FromQuery] string mode,
        CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid();
        var normalizedMode = mode.ToLowerInvariant();
        var (menu, screenType) = normalizedMode switch
        {
            "proxy" => (ProxyMenu, 4), "self" => (SelfMenu, 4),
            "approval" => (InboxMenu, 3), _ => (string.Empty, 0),
        };
        if (screenType == 0) return BadRequest(new { message = "รูปแบบหน้าจอไม่ถูกต้อง" });
        await using var c = await Open(token);
        await using var caption = new SqlCommand("SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@M", c);
        Add(caption,"@M",SqlDbType.Char,menu,5);
        return Ok(new { menuCode=menu, caption=Convert.ToString(await caption.ExecuteScalarAsync(token)) ?? menu, screenType,
            view=await Can(c,menu,"VIEW",token), create=normalizedMode is "proxy" or "self" && await Can(c,menu,"CREATE",token),
            submit=normalizedMode=="self" && await Can(c,menu,"SUBMIT",token), actOnBehalf=normalizedMode=="proxy" && await Can(c,menu,"ACT_ON_BEHALF",token),
            approve=normalizedMode=="approval" && await Can(c,menu,"APPROVE",token), cancel=normalizedMode=="self" && await Can(c,menu,"CANCEL",token) });
    }

    [HttpGet("lookups")]
    public async Task<IActionResult> Lookups([FromQuery] string mode,
        CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var self = mode.Equals("self", StringComparison.OrdinalIgnoreCase);
        if (!self && !mode.Equals("proxy", StringComparison.OrdinalIgnoreCase))
            return BadRequest(new { message = "รูปแบบหน้าจอไม่ถูกต้อง" });
        var menu = self ? SelfMenu : ProxyMenu;
        await using var c = await Open(token);
        if (!await Can(c, menu, "CREATE", token) ||
            self && !await Can(c, menu, "SUBMIT", token) ||
            !self && !await Can(c, menu, "ACT_ON_BEHALF", token)) return Forbid();
        var leaveTypes = await LookupRows(c, """
SELECT LeaveTypeID,LeaveTypeCode,LeaveTypeName,UnitCode,RequireRemark,RequireEvidence
FROM dbo.TDTMLeaveType WHERE CompanyID=@C AND IsActive=1
ORDER BY LeaveTypeCode
""", companyId, token);
        var onBehalfReasons = self ? new List<object>() : await LookupRows(c, """
SELECT OnBehalfReasonID,ReasonCode,ReasonName,RequireRemark,RequireEvidence
FROM dbo.TDTMOnBehalfReason WHERE CompanyID=@C AND IsActive=1
ORDER BY ReasonCode
""", companyId, token);
        var employees = self ? new List<object>() : await LookupRows(c, """
SELECT E.EmployeeID,E.EmployeeCode,E.FullName
FROM dbo.TDADEmployee E WHERE E.CompanyID=@C AND E.IsActive=1
AND(EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@C AND U.UserID=@U AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDTMEmployeeDataScopeGrant G WHERE G.CompanyID=@C AND G.IsActive=1 AND(G.UserID=@U OR G.RoleGroupID IN(SELECT ERG.RoleGroupID FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSDATETIME()) AND(ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSDATETIME())) WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.IsActive=1)) AND G.EffectiveFrom<=SYSDATETIME() AND(G.EffectiveTo IS NULL OR G.EffectiveTo>SYSDATETIME()) AND(G.ScopeTypeCode='ALL' OR G.ScopeTypeCode='SELF' AND E.EmployeeID=@ActorEmployee OR G.ScopeTypeCode='DIVISION' AND G.ScopeReferenceID=E.DivisionOrgUnitID OR G.ScopeTypeCode='DEPARTMENT' AND G.ScopeReferenceID=E.DepartmentOrgUnitID)))
ORDER BY E.EmployeeCode
""", companyId, token, userId, await EmployeeForUser(c, companyId, userId, token));
        return Ok(new { leaveTypes, onBehalfReasons, employees });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string mode,
        [FromQuery] string? status, [FromQuery] DateOnly? fromWorkDate,
        [FromQuery] DateOnly? toWorkDate, [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var menu = mode.ToLowerInvariant() switch
        { "proxy" => ProxyMenu, "self" => SelfMenu, "approval" => InboxMenu, _ => null };
        if (menu is null || page < 1 || pageSize is < 1 or > 100)
            return BadRequest(new { message = "เงื่อนไขค้นหาไม่ถูกต้อง" });
        var self = mode.Equals("self",StringComparison.OrdinalIgnoreCase);
        var approval = mode.Equals("approval",StringComparison.OrdinalIgnoreCase);
        await using var c = await Open(token);
        var ownEmployee = await EmployeeForUser(c,companyId,userId,token);
        if (self && !ownEmployee.HasValue) return Conflict(new { message="บัญชีผู้ใช้ยังไม่ได้ผูกกับพนักงานที่ใช้งานอยู่" });
        if (!await Can(c,menu,"VIEW",token)) return Forbid();
        var from=fromWorkDate ?? ThailandToday().AddDays(-30);var to=toWorkDate ?? ThailandToday(); if(to<from)return BadRequest(new{message="ช่วงวันที่ไม่ถูกต้อง"});
        const string where="""
FROM dbo.TDTMRequest R
JOIN dbo.TDTMLeaveRequest L ON L.RequestID=R.RequestID
JOIN dbo.TDTMLeaveType T ON T.LeaveTypeID=L.LeaveTypeID
JOIN dbo.TDADEmployee E ON E.CompanyID=R.CompanyID AND E.EmployeeID=R.SubjectEmployeeID
WHERE R.CompanyID=@C AND L.EndWorkDate>=@F AND L.StartWorkDate<=@T
AND (@Status IS NULL OR R.StatusCode=@Status)
AND (@Self=0 OR R.SubjectEmployeeID=@Employee)
AND (@Approval=0 OR R.StatusCode='PENDING')
AND (@Self=1
 OR EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@C AND U.UserID=@U AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS(
    SELECT 1
    FROM dbo.TDTMEmployeeDataScopeGrant G
    WHERE G.CompanyID=@C AND G.IsActive=1
      AND (G.UserID=@U OR G.RoleGroupID IN(
          SELECT ERG.RoleGroupID
          FROM dbo.TDADUserEmployee UE
          JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID
           AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSDATETIME())
           AND(ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSDATETIME()))
          WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.IsActive=1))
      AND G.EffectiveFrom<=SYSDATETIME() AND(G.EffectiveTo IS NULL OR G.EffectiveTo>SYSDATETIME())
      AND(G.ScopeTypeCode='ALL'
          OR G.ScopeTypeCode='SELF' AND R.SubjectEmployeeID=@ActorEmployee
          OR G.ScopeTypeCode='DIVISION' AND G.ScopeReferenceID=E.DivisionOrgUnitID
          OR G.ScopeTypeCode='DEPARTMENT' AND G.ScopeReferenceID=E.DepartmentOrgUnitID)))
""";
        await using var count = new SqlCommand("SELECT COUNT_BIG(1) "+where,c); BindList(count,companyId,userId,ownEmployee,status,from,to,self,approval);
        var total=Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var q=new SqlCommand("SELECT R.RequestID,R.SubjectEmployeeID,E.EmployeeCode,E.FullName,T.LeaveTypeCode,T.LeaveTypeName,L.UnitCode,L.StartWorkDate,L.EndWorkDate,L.RequestedQuantity,R.InitiationModeCode,R.StatusCode,R.SubmittedDate,CONVERT(varchar(32),R.RowVersion,2) "+where+" ORDER BY R.CreateDate DESC,R.RequestID DESC OFFSET @O ROWS FETCH NEXT @Take ROWS ONLY",c);BindList(q,companyId,userId,ownEmployee,status,from,to,self,approval);Add(q,"@O",SqlDbType.Int,(page-1)*pageSize);Add(q,"@Take",SqlDbType.Int,pageSize);
        await using var r=await q.ExecuteReaderAsync(token);var items=new List<object>();while(await r.ReadAsync(token))items.Add(new{requestId=r.GetInt64(0),employeeId=r.GetInt64(1),employeeCode=r.GetString(2),fullName=r.GetString(3),leaveTypeCode=r.GetString(4),leaveTypeName=r.GetString(5),unitCode=r.GetString(6),startWorkDate=DateOnly.FromDateTime(r.GetDateTime(7)),endWorkDate=DateOnly.FromDateTime(r.GetDateTime(8)),requestedQuantity=r.GetDecimal(9),initiationModeCode=r.GetString(10),statusCode=r.GetString(11),submittedDate=r.IsDBNull(12)?(DateTime?)null:r.GetDateTime(12),rowVersion=r.GetString(13)});return Ok(new{total,page,pageSize,items});
    }

    [HttpGet("{requestId:long}")]
    public async Task<IActionResult> Get(long requestId, [FromQuery] string mode,
        CancellationToken token)
    {
        if (!Scope(out var companyId, out var userId)) return Forbid();
        var menu = mode.ToLowerInvariant() switch
        { "proxy" => ProxyMenu, "self" => SelfMenu, "approval" => InboxMenu, _ => null };
        if (menu is null) return BadRequest(new { message = "รูปแบบหน้าจอไม่ถูกต้อง" });
        await using var c = await Open(token);
        if (!await Can(c, menu, "VIEW", token)) return Forbid();
        await using var header = new SqlCommand("""
SELECT R.RequestID,R.SubjectEmployeeID,E.EmployeeCode,E.FullName,T.LeaveTypeCode,T.LeaveTypeName,L.UnitCode,L.StartWorkDate,L.EndWorkDate,L.RequestedQuantity,L.RequestRemark,R.InitiationModeCode,R.StatusCode,R.OnBehalfRemark,R.EvidenceReference,O.ReasonName,CONVERT(varchar(32),R.RowVersion,2)
FROM dbo.TDTMRequest R JOIN dbo.TDTMLeaveRequest L ON L.RequestID=R.RequestID
JOIN dbo.TDTMLeaveType T ON T.LeaveTypeID=L.LeaveTypeID
JOIN dbo.TDADEmployee E ON E.CompanyID=R.CompanyID AND E.EmployeeID=R.SubjectEmployeeID
LEFT JOIN dbo.TDTMOnBehalfReason O ON O.CompanyID=R.CompanyID AND O.OnBehalfReasonID=R.OnBehalfReasonID
WHERE R.CompanyID=@C AND R.RequestID=@R AND R.ProcessCode='LEAVE_REQUEST'
""",c);Add(header,"@C",SqlDbType.BigInt,companyId);Add(header,"@R",SqlDbType.BigInt,requestId);
        await using var reader=await header.ExecuteReaderAsync(token);
        if(!await reader.ReadAsync(token))return NotFound();
        var subject=reader.GetInt64(1);
        var value=new { requestId=reader.GetInt64(0),employeeId=subject,employeeCode=reader.GetString(2),fullName=reader.GetString(3),leaveTypeCode=reader.GetString(4),leaveTypeName=reader.GetString(5),unitCode=reader.GetString(6),startWorkDate=DateOnly.FromDateTime(reader.GetDateTime(7)),endWorkDate=DateOnly.FromDateTime(reader.GetDateTime(8)),requestedQuantity=reader.GetDecimal(9),requestRemark=reader.IsDBNull(10)?null:reader.GetString(10),initiationModeCode=reader.GetString(11),statusCode=reader.GetString(12),onBehalfRemark=reader.IsDBNull(13)?null:reader.GetString(13),evidenceReference=reader.IsDBNull(14)?null:reader.GetString(14),onBehalfReasonName=reader.IsDBNull(15)?null:reader.GetString(15),rowVersion=reader.GetString(16)};
        await reader.CloseAsync();
        var selfEmployee=await EmployeeForUser(c,companyId,userId,token);
        if(mode.Equals("self",StringComparison.OrdinalIgnoreCase) ? selfEmployee!=subject : !await InScope(c,companyId,userId,subject,token))return Forbid();
        await using var details=new SqlCommand("SELECT WorkDate,StartMinute,EndMinute,RequestedQuantity,ScheduledNetMinutes FROM dbo.TDTMLeaveRequestDate WHERE RequestID=@R ORDER BY WorkDate",c);Add(details,"@R",SqlDbType.BigInt,requestId);await using var d=await details.ExecuteReaderAsync(token);var dateRows=new List<object>();while(await d.ReadAsync(token))dateRows.Add(new{workDate=DateOnly.FromDateTime(d.GetDateTime(0)),startMinute=d.IsDBNull(1)?(int?)null:d.GetInt32(1),endMinute=d.IsDBNull(2)?(int?)null:d.GetInt32(2),requestedQuantity=d.GetDecimal(3),scheduledNetMinutes=d.IsDBNull(4)?(int?)null:d.GetInt32(4)});await d.CloseAsync();
        await using var decisions=new SqlCommand("SELECT DecisionCode,Reason,DecisionDate FROM dbo.TDTMApprovalDecision WHERE RequestID=@R ORDER BY DecisionDate",c);Add(decisions,"@R",SqlDbType.BigInt,requestId);await using var a=await decisions.ExecuteReaderAsync(token);var decisionRows=new List<object>();while(await a.ReadAsync(token))decisionRows.Add(new{decisionCode=a.GetString(0),reason=a.IsDBNull(1)?null:a.GetString(1),decisionDate=a.GetDateTime(2)});
        return Ok(new { header=value, details=dateRows, decisions=decisionRows });
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromQuery] string mode, LeaveRequestSaveRequest request, CancellationToken token)
    {
        var self = string.Equals(mode, "self", StringComparison.OrdinalIgnoreCase);
        if (!self && !string.Equals(mode, "proxy", StringComparison.OrdinalIgnoreCase)) return BadRequest(new { message = "รูปแบบการยื่นคำขอไม่ถูกต้อง" });
        if (!Scope(out var companyId, out var userId)) return Forbid();
        if (request.LeaveTypeId <= 0 || request.RequestedQuantity <= 0 || request.EndWorkDate < request.StartWorkDate) return BadRequest(new { message = "ข้อมูลคำขอลาไม่ถูกต้อง" });
        await using var c = await Open(token); var menu = self ? SelfMenu : ProxyMenu;
        if (!await Can(c, menu, "CREATE", token) || self && !await Can(c, menu, "SUBMIT", token) || !self && !await Can(c, menu, "ACT_ON_BEHALF", token)) return Forbid();
        var employeeId = self ? await EmployeeForUser(c, companyId, userId, token) : request.EmployeeId;
        if (!employeeId.HasValue) return Conflict(new { message = "ไม่พบพนักงานสำหรับคำขอนี้" });
        if (!self && !await InScope(c, companyId, userId, employeeId.Value, token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var today = ThailandToday();
            var policy = await RequestPolicy(c, tx, companyId, today, token) ?? throw new InvalidOperationException("ยังไม่ได้กำหนดนโยบายผู้เริ่มคำขอสำหรับการลา");
            if (self && policy.Code == "PROXY_ONLY") throw new InvalidOperationException("บริษัทกำหนดให้ผู้ดูแลยื่นคำขอแทนเท่านั้น");
            if (!self && policy.Code == "SELF_SERVICE_ONLY") throw new InvalidOperationException("บริษัทกำหนดให้พนักงานยื่นคำขอด้วยตนเอง");
            var type = await LeaveType(c, tx, companyId, request.LeaveTypeId, token) ?? throw new InvalidOperationException("ไม่พบประเภทลาที่ใช้งานอยู่");
            if (!await ActiveEmployee(c, tx, companyId, employeeId.Value, token)) throw new InvalidOperationException("พนักงานไม่มีสถานะการจ้างที่ใช้งานอยู่");
            if (!self && (!request.OnBehalfReasonId.HasValue || !await OnBehalfValid(c, tx, companyId, request.OnBehalfReasonId.Value, request.OnBehalfRemark, request.EvidenceReference, token))) throw new InvalidOperationException("กรุณาระบุเหตุผลทำแทนตามที่กำหนด");
            if ((type.RequireRemark && string.IsNullOrWhiteSpace(request.RequestRemark)) || (type.RequireEvidence && string.IsNullOrWhiteSpace(request.EvidenceReference))) throw new InvalidOperationException("ประเภทลานี้ต้องระบุข้อมูลประกอบให้ครบ");
            var profile = await ApprovalProfile(c, tx, companyId, today, token) ?? throw new InvalidOperationException("ยังไม่ได้กำหนดรูปแบบการอนุมัติสำหรับการลา");
            var direct = !self && profile.Code == "OWNER_OPERATED" && await Can(c, ProxyMenu, "APPROVE", token);
            var actorEmployee = await EmployeeForUser(c, companyId, userId, token);
            if (direct && actorEmployee == employeeId && !await Can(c, ProxyMenu, "SELF_APPROVE", token)) throw new InvalidOperationException("ไม่มีสิทธิ์อนุมัติคำขอของตนเอง");
            await EnsureNoOverlappingRequest(c, tx, companyId,
                employeeId.Value, request.StartWorkDate,
                request.EndWorkDate, token);
            var balance = await Balance(c, tx, companyId, employeeId.Value, type.Id, token);
            if (balance < request.RequestedQuantity) throw new InvalidOperationException("สิทธิ์ลาคงเหลือไม่เพียงพอ");
            var requestId = await InsertRequest(c, tx, companyId, userId, employeeId.Value, request, self, direct, token);
            await Snapshots(c, tx, requestId, policy, profile, token);
            var allocations = await Detail(c, tx, companyId, employeeId.Value,
                requestId, type, request, token);
            if (direct)
            {
                foreach (var allocation in allocations)
                {
                    var usageLedgerId = await Ledger(c, tx, companyId,
                        employeeId.Value, type, requestId, "USAGE",
                        -allocation.Quantity, userId, token);
                    await Usage(c, tx, companyId, employeeId.Value, type,
                        requestId, allocation, usageLedgerId, userId, token);
                }
                await Decision(c, tx, requestId, userId, actorEmployee,
                    actorEmployee == employeeId, token);
            }
            else
            {
                var reservationLedgerId = await Ledger(c, tx, companyId,
                    employeeId.Value, type, requestId, "RESERVATION",
                    -request.RequestedQuantity, userId, token);
                await Reservation(c, tx, companyId, employeeId.Value, type,
                    requestId, request.RequestedQuantity, reservationLedgerId,
                    token);
            }
            await Notify(c, tx, companyId, requestId, employeeId.Value, direct ? "APPROVED" : "PENDING", token);
            await tx.CommitAsync(token); return Ok(new { requestId, statusCode = direct ? "APPROVED" : "PENDING" });
        }
        catch (InvalidOperationException e) { await tx.RollbackAsync(token); return Conflict(new { message = e.Message }); }
    }

    [HttpPost("{requestId:long}/decision")]
    public async Task<IActionResult> Decide(long requestId, LeaveDecisionRequest request,
        CancellationToken token)
    {
        var decision = request.DecisionCode.Trim().ToUpperInvariant();
        if (decision is not ("APPROVED" or "REJECTED") || !RowVersion(request.RowVersion))
            return BadRequest(new { message = "ข้อมูลการอนุมัติไม่ถูกต้อง" });
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var c = await Open(token);
        if (!await Can(c, InboxMenu, "APPROVE", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(
            IsolationLevel.Serializable, token);
        try
        {
            var pending = await Pending(c, tx, companyId, requestId, token)
                ?? throw new InvalidOperationException("ไม่พบคำขอลาที่รออนุมัติ");
            if (!await InScope(c, companyId, userId, pending.EmployeeId, token))
                return Forbid();
            var actorEmployee = await EmployeeForUser(c, companyId, userId, token);
            if (actorEmployee == pending.EmployeeId && !await Can(c, InboxMenu, "SELF_APPROVE", token))
                throw new InvalidOperationException("ไม่มีสิทธิ์อนุมัติคำขอของตนเอง");
            if (decision == "REJECTED" && string.IsNullOrWhiteSpace(request.Reason))
                throw new InvalidOperationException("กรุณาระบุเหตุผลไม่อนุมัติ");
            var reservation = await ReservationForRequest(c, tx, requestId, token)
                ?? throw new InvalidOperationException("ไม่พบยอดสิทธิ์ที่กันไว้สำหรับคำขอนี้");
            var releaseLedgerId = await Ledger(c, tx, companyId, pending.EmployeeId,
                new Type(reservation.LeaveTypeId, reservation.UnitCode, false, false),
                requestId, "RELEASE", reservation.Quantity, userId, token);
            if (decision == "APPROVED")
            {
                foreach (var allocation in await Allocations(c, tx, requestId, token))
                {
                    var usageLedgerId = await Ledger(c, tx, companyId, pending.EmployeeId,
                        new Type(reservation.LeaveTypeId, reservation.UnitCode, false, false),
                        requestId, "USAGE", -allocation.Quantity, userId, token);
                    await Usage(c, tx, companyId, pending.EmployeeId,
                        new Type(reservation.LeaveTypeId, reservation.UnitCode, false, false),
                        requestId, allocation, usageLedgerId, userId, token);
                }
            }
            await using (var status = new SqlCommand("UPDATE dbo.TDTMRequest SET StatusCode=@S,UpdateDate=SYSDATETIME(),UpdateBy=@U WHERE CompanyID=@C AND RequestID=@R AND StatusCode='PENDING' AND RowVersion=CONVERT(binary(8),@V,2)", c, tx))
            { Add(status,"@S",SqlDbType.VarChar,decision,20);Add(status,"@U",SqlDbType.BigInt,userId);Add(status,"@C",SqlDbType.BigInt,companyId);Add(status,"@R",SqlDbType.BigInt,requestId);Add(status,"@V",SqlDbType.VarChar,request.RowVersion,32);if(await status.ExecuteNonQueryAsync(token)!=1)throw new InvalidOperationException("คำขอถูกแก้ไขแล้ว กรุณาโหลดใหม่"); }
            await using (var close = new SqlCommand("UPDATE dbo.TDTMLeaveReservation SET StatusCode=@S,ReleasedLedgerID=@L,ResolvedDate=SYSDATETIME() WHERE RequestID=@R AND StatusCode='ACTIVE'", c, tx))
            { Add(close,"@S",SqlDbType.VarChar,decision=="APPROVED"?"CONSUMED":"RELEASED",20);Add(close,"@L",SqlDbType.BigInt,releaseLedgerId);Add(close,"@R",SqlDbType.BigInt,requestId);await close.ExecuteNonQueryAsync(token); }
            await using (var audit = new SqlCommand("INSERT dbo.TDTMApprovalDecision(RequestID,StepOrder,DecisionCode,ActorUserID,ActorEmployeeID,IsSelfApproved,Reason,CorrelationID)VALUES(@R,0,@D,@U,@E,@Self,@Reason,NEWID())", c, tx))
            { Add(audit,"@R",SqlDbType.BigInt,requestId);Add(audit,"@D",SqlDbType.VarChar,decision,20);Add(audit,"@U",SqlDbType.BigInt,userId);Add(audit,"@E",SqlDbType.BigInt,actorEmployee);Add(audit,"@Self",SqlDbType.Bit,actorEmployee==pending.EmployeeId);Add(audit,"@Reason",SqlDbType.NVarChar,request.Reason,1000);await audit.ExecuteNonQueryAsync(token); }
            await Notify(c,tx,companyId,requestId,pending.EmployeeId,decision,token);
            await tx.CommitAsync(token); return NoContent();
        }
        catch (InvalidOperationException e) { await tx.RollbackAsync(token); return Conflict(new { message=e.Message }); }
    }

    [HttpPost("{requestId:long}/cancel")]
    public async Task<IActionResult> Cancel(long requestId, LeaveCancelRequest request,
        CancellationToken token)
    {
        if (!RowVersion(request.RowVersion) || !Scope(out var companyId, out var userId))
            return BadRequest(new { message = "ข้อมูลการยกเลิกคำขอไม่ถูกต้อง" });
        await using var c = await Open(token);
        if (!await Can(c, SelfMenu, "CANCEL", token)) return Forbid();
        var actorEmployee = await EmployeeForUser(c, companyId, userId, token);
        if (!actorEmployee.HasValue) return Conflict(new { message = "บัญชีผู้ใช้ยังไม่ผูกกับพนักงานที่ใช้งานอยู่" });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            await using var owner = new SqlCommand("SELECT SubjectEmployeeID FROM dbo.TDTMRequest WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND RequestID=@R AND ProcessCode='LEAVE_REQUEST' AND StatusCode='PENDING' AND ActorUserID=@U", c, tx);
            Add(owner,"@C",SqlDbType.BigInt,companyId);Add(owner,"@R",SqlDbType.BigInt,requestId);Add(owner,"@U",SqlDbType.BigInt,userId);
            var value=await owner.ExecuteScalarAsync(token);
            if(value is null || Convert.ToInt64(value)!=actorEmployee.Value) throw new InvalidOperationException("ยกเลิกได้เฉพาะคำขอของตนที่ยังรออนุมัติ");
            var reservation=await ReservationForRequest(c,tx,requestId,token) ?? throw new InvalidOperationException("ไม่พบยอดสิทธิ์ที่กันไว้สำหรับคำขอนี้");
            var releaseLedgerId=await Ledger(c,tx,companyId,actorEmployee.Value,new Type(reservation.LeaveTypeId,reservation.UnitCode,false,false),requestId,"RELEASE",reservation.Quantity,userId,token);
            await using(var update=new SqlCommand("UPDATE dbo.TDTMRequest SET StatusCode='CANCELLED',UpdateDate=SYSDATETIME(),UpdateBy=@U WHERE CompanyID=@C AND RequestID=@R AND StatusCode='PENDING' AND RowVersion=CONVERT(binary(8),@V,2)",c,tx))
            {Add(update,"@U",SqlDbType.BigInt,userId);Add(update,"@C",SqlDbType.BigInt,companyId);Add(update,"@R",SqlDbType.BigInt,requestId);Add(update,"@V",SqlDbType.VarChar,request.RowVersion,32);if(await update.ExecuteNonQueryAsync(token)!=1)throw new InvalidOperationException("คำขอถูกแก้ไขแล้ว กรุณาโหลดใหม่");}
            await using(var close=new SqlCommand("UPDATE dbo.TDTMLeaveReservation SET StatusCode='RELEASED',ReleasedLedgerID=@L,ResolvedDate=SYSDATETIME() WHERE RequestID=@R AND StatusCode='ACTIVE'",c,tx))
            {Add(close,"@L",SqlDbType.BigInt,releaseLedgerId);Add(close,"@R",SqlDbType.BigInt,requestId);if(await close.ExecuteNonQueryAsync(token)!=1)throw new InvalidOperationException("คำขอไม่มีรายการกันสิทธิ์ที่ยกเลิกได้");}
            await using(var audit=new SqlCommand("INSERT dbo.TDTMApprovalDecision(RequestID,StepOrder,DecisionCode,ActorUserID,ActorEmployeeID,Reason,CorrelationID)VALUES(@R,0,'CANCELLED',@U,@E,@Reason,NEWID())",c,tx))
            {Add(audit,"@R",SqlDbType.BigInt,requestId);Add(audit,"@U",SqlDbType.BigInt,userId);Add(audit,"@E",SqlDbType.BigInt,actorEmployee);Add(audit,"@Reason",SqlDbType.NVarChar,request.Reason,1000);await audit.ExecuteNonQueryAsync(token);}
            await Notify(c,tx,companyId,requestId,actorEmployee.Value,"CANCELLED",token);
            await tx.CommitAsync(token);return NoContent();
        }
        catch(InvalidOperationException e){await tx.RollbackAsync(token);return Conflict(new { message=e.Message });}
    }

    private sealed record Policy(long Id,string Code); private sealed record Profile(long BaseId,long? ProcessId,string Code); private sealed record Type(long Id,string Unit,bool RequireRemark,bool RequireEvidence); private sealed record Allocation(long Id,DateOnly WorkDate,decimal Quantity); private sealed record PendingRequest(long EmployeeId); private sealed record Reserved(long LeaveTypeId,string UnitCode,decimal Quantity);
    private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private bool Scope(out long c,out long u){c=0;u=0;return string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&long.TryParse(User.FindFirstValue("company_id"),out c)&&long.TryParse(User.FindFirstValue("user_id"),out u)&&c>0&&u>0;}
    private Task<bool> Can(SqlConnection c,string m,string a,CancellationToken t)=>CompanyMenuAccess.IsAllowedAsync(c,User,m,a,t);
    private static async Task<long?> EmployeeForUser(SqlConnection c,long company,long user,CancellationToken t){await using var q=new SqlCommand("SELECT TOP(1) E.EmployeeID FROM dbo.TDADUserEmployee UE JOIN dbo.TDADUser U ON U.CompanyID=UE.CompanyID AND U.UserID=UE.UserID AND U.IsActive=1 JOIN dbo.TDADEmployee E ON E.CompanyID=UE.CompanyID AND E.EmployeeID=UE.EmployeeID AND E.IsActive=1 WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.IsActive=1",c);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@U",SqlDbType.BigInt,user);var x=await q.ExecuteScalarAsync(t);return x is null?null:Convert.ToInt64(x);}
    private static async Task<bool> ActiveEmployee(SqlConnection c,SqlTransaction tx,long company,long employee,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDADEmployee WHERE CompanyID=@C AND EmployeeID=@E AND IsActive=1",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,employee);return Convert.ToInt64(await q.ExecuteScalarAsync(t))==1;}
    private static async Task<bool> InScope(SqlConnection c,long company,long user,long employee,CancellationToken t){await using var q=new SqlCommand("""
SELECT CAST(CASE WHEN EXISTS
(
 SELECT 1 FROM dbo.TDADEmployee E WHERE E.CompanyID=@C AND E.EmployeeID=@E AND E.IsActive=1
 AND(EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@C AND U.UserID=@U AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDTMEmployeeDataScopeGrant G WHERE G.CompanyID=@C AND G.IsActive=1 AND(G.UserID=@U OR G.RoleGroupID IN(SELECT ERG.RoleGroupID FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSDATETIME()) AND(ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSDATETIME())) WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.IsActive=1)) AND G.EffectiveFrom<=SYSDATETIME() AND(G.EffectiveTo IS NULL OR G.EffectiveTo>SYSDATETIME()) AND(G.ScopeTypeCode='ALL' OR G.ScopeTypeCode='SELF' AND EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE WHERE UE.CompanyID=@C AND UE.UserID=@U AND UE.EmployeeID=@E AND UE.IsActive=1) OR G.ScopeTypeCode='DIVISION' AND G.ScopeReferenceID=E.DivisionOrgUnitID OR G.ScopeTypeCode='DEPARTMENT' AND G.ScopeReferenceID=E.DepartmentOrgUnitID)))
) THEN 1 ELSE 0 END AS bit)
""",c);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@U",SqlDbType.BigInt,user);Add(q,"@E",SqlDbType.BigInt,employee);return Convert.ToBoolean(await q.ExecuteScalarAsync(t));}
    private static async Task<Policy?> RequestPolicy(SqlConnection c,SqlTransaction tx,long company,DateOnly d,CancellationToken t){await using var q=new SqlCommand("SELECT TOP(1) RequestPolicyVersionID,PolicyCode FROM dbo.TDTMEmployeeRequestPolicyVersion WHERE CompanyID=@C AND ProcessCode='LEAVE_REQUEST' AND IsActive=1 AND EffectiveFrom<=@D AND(EffectiveTo IS NULL OR EffectiveTo>=@D) ORDER BY EffectiveFrom DESC",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@D",SqlDbType.Date,d.ToDateTime(TimeOnly.MinValue));await using var r=await q.ExecuteReaderAsync(t);return await r.ReadAsync(t)?new Policy(r.GetInt64(0),r.GetString(1)):null;}
    private static async Task<Profile?> ApprovalProfile(SqlConnection c,SqlTransaction tx,long company,DateOnly d,CancellationToken t){await using var q=new SqlCommand("SELECT TOP(1) B.ApprovalProfileVersionID,P.ProcessApprovalPolicyVersionID,COALESCE(P.ProfileCode,B.ProfileCode) FROM dbo.TDTMApprovalProfileVersion B OUTER APPLY(SELECT TOP(1) ProcessApprovalPolicyVersionID,ProfileCode FROM dbo.TDTMProcessApprovalPolicyVersion WHERE CompanyID=B.CompanyID AND ProcessCode='LEAVE' AND IsActive=1 AND EffectiveFrom<=@D AND(EffectiveTo IS NULL OR EffectiveTo>=@D) ORDER BY EffectiveFrom DESC)P WHERE B.CompanyID=@C AND B.IsActive=1 AND B.EffectiveFrom<=@D AND(B.EffectiveTo IS NULL OR B.EffectiveTo>=@D) ORDER BY B.EffectiveFrom DESC",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@D",SqlDbType.Date,d.ToDateTime(TimeOnly.MinValue));await using var r=await q.ExecuteReaderAsync(t);return await r.ReadAsync(t)?new Profile(r.GetInt64(0),r.IsDBNull(1)?null:r.GetInt64(1),r.GetString(2)):null;}
    private static async Task<Type?> LeaveType(SqlConnection c,SqlTransaction tx,long company,long id,CancellationToken t){await using var q=new SqlCommand("SELECT LeaveTypeID,UnitCode,RequireRemark,RequireEvidence FROM dbo.TDTMLeaveType WHERE CompanyID=@C AND LeaveTypeID=@ID AND IsActive=1",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@ID",SqlDbType.BigInt,id);await using var r=await q.ExecuteReaderAsync(t);return await r.ReadAsync(t)?new Type(r.GetInt64(0),r.GetString(1),r.GetBoolean(2),r.GetBoolean(3)):null;}
    private static async Task<bool> OnBehalfValid(SqlConnection c,SqlTransaction tx,long company,long id,string? remark,string? evidence,CancellationToken t){await using var q=new SqlCommand("SELECT RequireRemark,RequireEvidence FROM dbo.TDTMOnBehalfReason WHERE CompanyID=@C AND OnBehalfReasonID=@ID AND IsActive=1",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@ID",SqlDbType.BigInt,id);await using var r=await q.ExecuteReaderAsync(t);return await r.ReadAsync(t)&&(!r.GetBoolean(0)||!string.IsNullOrWhiteSpace(remark))&&(!r.GetBoolean(1)||!string.IsNullOrWhiteSpace(evidence));}
    private static async Task<decimal> Balance(SqlConnection c,SqlTransaction tx,long company,long employee,long type,CancellationToken t){await using var q=new SqlCommand("SELECT COALESCE(SUM(Quantity),0) FROM dbo.TDTMLeaveEntitlementLedger WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND EmployeeID=@E AND LeaveTypeID=@T",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@T",SqlDbType.BigInt,type);return Convert.ToDecimal(await q.ExecuteScalarAsync(t));}
    private static async Task<PendingRequest?> Pending(SqlConnection c,SqlTransaction tx,long company,long request,CancellationToken t){await using var q=new SqlCommand("SELECT SubjectEmployeeID FROM dbo.TDTMRequest WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND RequestID=@R AND ProcessCode='LEAVE_REQUEST' AND StatusCode='PENDING'",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@R",SqlDbType.BigInt,request);var value=await q.ExecuteScalarAsync(t);return value is null?null:new PendingRequest(Convert.ToInt64(value));}
    private static async Task<Reserved?> ReservationForRequest(SqlConnection c,SqlTransaction tx,long request,CancellationToken t){await using var q=new SqlCommand("SELECT LeaveTypeID,UnitCode,ReservedQuantity FROM dbo.TDTMLeaveReservation WITH(UPDLOCK,HOLDLOCK) WHERE RequestID=@R AND StatusCode='ACTIVE'",c,tx);Add(q,"@R",SqlDbType.BigInt,request);await using var r=await q.ExecuteReaderAsync(t);return await r.ReadAsync(t)?new Reserved(r.GetInt64(0),r.GetString(1),r.GetDecimal(2)):null;}
    private static async Task<List<Allocation>> Allocations(SqlConnection c,SqlTransaction tx,long request,CancellationToken t){await using var q=new SqlCommand("SELECT LeaveRequestDateID,WorkDate,RequestedQuantity FROM dbo.TDTMLeaveRequestDate WHERE RequestID=@R ORDER BY WorkDate",c,tx);Add(q,"@R",SqlDbType.BigInt,request);await using var r=await q.ExecuteReaderAsync(t);var rows=new List<Allocation>();while(await r.ReadAsync(t))rows.Add(new Allocation(r.GetInt64(0),DateOnly.FromDateTime(r.GetDateTime(1)),r.GetDecimal(2)));return rows;}
    private static async Task EnsureNoOverlappingRequest(SqlConnection c,SqlTransaction tx,long company,long employee,DateOnly from,DateOnly to,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDTMLeaveRequest L WITH(UPDLOCK,HOLDLOCK) JOIN dbo.TDTMRequest R ON R.RequestID=L.RequestID WHERE L.CompanyID=@C AND L.SubjectEmployeeID=@E AND R.StatusCode IN('PENDING','APPROVED') AND L.StartWorkDate<=@To AND L.EndWorkDate>=@From",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@From",SqlDbType.Date,from.ToDateTime(TimeOnly.MinValue));Add(q,"@To",SqlDbType.Date,to.ToDateTime(TimeOnly.MinValue));if(Convert.ToInt64(await q.ExecuteScalarAsync(t))>0)throw new InvalidOperationException("มีคำขอลาที่กำลังรอหรืออนุมัติแล้วทับช่วงวันที่นี้");}
    private static async Task<long> InsertRequest(SqlConnection c,SqlTransaction tx,long company,long user,long employee,LeaveRequestSaveRequest x,bool self,bool direct,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMRequest(CompanyID,ProcessCode,SubjectEmployeeID,InitiationModeCode,ActorUserID,OnBehalfReasonID,OnBehalfRemark,EvidenceReference,StatusCode,SubmittedDate,CreateBy) OUTPUT INSERTED.RequestID VALUES(@C,'LEAVE_REQUEST',@E,@M,@U,@R,@Remark,@Evidence,@S,SYSDATETIME(),@U)",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@M",SqlDbType.VarChar,self?"SELF":"PROXY",10);Add(q,"@U",SqlDbType.BigInt,user);Add(q,"@R",SqlDbType.BigInt,self?null:x.OnBehalfReasonId);Add(q,"@Remark",SqlDbType.NVarChar,self?null:x.OnBehalfRemark,1000);Add(q,"@Evidence",SqlDbType.NVarChar,x.EvidenceReference,1000);Add(q,"@S",SqlDbType.VarChar,direct?"APPROVED":"PENDING",20);return Convert.ToInt64(await q.ExecuteScalarAsync(t));}
    private static async Task Snapshots(SqlConnection c,SqlTransaction tx,long id,Policy policy,Profile profile,CancellationToken t){var p=JsonSerializer.Serialize(new{processCode="LEAVE_REQUEST",policyCode=policy.Code,policyVersionId=policy.Id});var w=JsonSerializer.Serialize(new{processCode="LEAVE",profileCode=profile.Code,approvalProfileVersionId=profile.BaseId,processApprovalPolicyVersionId=profile.ProcessId});await using var a=new SqlCommand("INSERT dbo.TDTMRequestPolicySnapshot(RequestID,RequestPolicyVersionID,PolicyCode,SnapshotJson,SnapshotHash)VALUES(@R,@V,@C,@J,@H)",c,tx);Add(a,"@R",SqlDbType.BigInt,id);Add(a,"@V",SqlDbType.BigInt,policy.Id);Add(a,"@C",SqlDbType.VarChar,policy.Code,30);Add(a,"@J",SqlDbType.NVarChar,p,-1);Add(a,"@H",SqlDbType.VarBinary,SHA256.HashData(Encoding.UTF8.GetBytes(p)),32);await a.ExecuteNonQueryAsync(t);await using var b=new SqlCommand("INSERT dbo.TDTMWorkflowSnapshot(RequestID,ApprovalProfileVersionID,ProcessApprovalPolicyVersionID,SnapshotJson,SnapshotHash)VALUES(@R,@B,@P,@J,@H)",c,tx);Add(b,"@R",SqlDbType.BigInt,id);Add(b,"@B",SqlDbType.BigInt,profile.BaseId);Add(b,"@P",SqlDbType.BigInt,profile.ProcessId);Add(b,"@J",SqlDbType.NVarChar,w,-1);Add(b,"@H",SqlDbType.VarBinary,SHA256.HashData(Encoding.UTF8.GetBytes(w)),32);await b.ExecuteNonQueryAsync(t);}
    private static async Task<List<Allocation>> Detail(SqlConnection c,SqlTransaction tx,long company,long employee,long id,Type type,LeaveRequestSaveRequest x,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMLeaveRequest(RequestID,CompanyID,SubjectEmployeeID,LeaveTypeID,UnitCode,StartWorkDate,EndWorkDate,RequestedQuantity,RequestRemark)VALUES(@R,@C,@E,@T,@U,@S,@End,@Q,@Remark)",c,tx);Add(q,"@R",SqlDbType.BigInt,id);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@T",SqlDbType.BigInt,type.Id);Add(q,"@U",SqlDbType.VarChar,type.Unit,10);Add(q,"@S",SqlDbType.Date,x.StartWorkDate.ToDateTime(TimeOnly.MinValue));Add(q,"@End",SqlDbType.Date,x.EndWorkDate.ToDateTime(TimeOnly.MinValue));Add(q,"@Q",SqlDbType.Decimal,x.RequestedQuantity);q.Parameters["@Q"].Precision=18;q.Parameters["@Q"].Scale=4;Add(q,"@Remark",SqlDbType.NVarChar,x.RequestRemark,1000);await q.ExecuteNonQueryAsync(t);
        var scheduled=new List<(DateOnly Date,int Minutes)>();for(var date=x.StartWorkDate;date<=x.EndWorkDate;date=date.AddDays(1)){var minutes=await AttendanceCalculator.ScheduledNetMinutesAsync(c,tx,company,employee,date,t);if(minutes>0)scheduled.Add((date,minutes));}
        if(type.Unit=="MINUTE"){
            if(scheduled.Count!=1||x.StartWorkDate!=x.EndWorkDate||!x.StartMinute.HasValue||!x.EndMinute.HasValue||x.StartMinute<0||x.EndMinute>1440||x.EndMinute<=x.StartMinute)throw new InvalidOperationException("การลาแบบนาทีต้องเลือกช่วงเวลาในวันทำงานเดียว");
            var netMinutes=await AttendanceCalculator.ScheduledLeaveMinutesAsync(c,tx,company,employee,x.StartWorkDate,x.StartMinute.Value,x.EndMinute.Value,t);
            if(netMinutes<=0||x.RequestedQuantity!=netMinutes)throw new InvalidOperationException("ช่วงเวลาที่ขอลาไม่อยู่ในเวลาทำงาน หรือจำนวนไม่ตรงกับนาทีงานสุทธิ");
            await using var minuteDetail=new SqlCommand("INSERT dbo.TDTMLeaveRequestDate(RequestID,CompanyID,SubjectEmployeeID,WorkDate,StartMinute,EndMinute,RequestedQuantity,ScheduledNetMinutes) OUTPUT INSERTED.LeaveRequestDateID VALUES(@R,@C,@E,@D,@S,@End,@Q,@M)",c,tx);Add(minuteDetail,"@R",SqlDbType.BigInt,id);Add(minuteDetail,"@C",SqlDbType.BigInt,company);Add(minuteDetail,"@E",SqlDbType.BigInt,employee);Add(minuteDetail,"@D",SqlDbType.Date,x.StartWorkDate.ToDateTime(TimeOnly.MinValue));Add(minuteDetail,"@S",SqlDbType.Int,x.StartMinute);Add(minuteDetail,"@End",SqlDbType.Int,x.EndMinute);Add(minuteDetail,"@Q",SqlDbType.Decimal,x.RequestedQuantity);minuteDetail.Parameters["@Q"].Precision=18;minuteDetail.Parameters["@Q"].Scale=4;Add(minuteDetail,"@M",SqlDbType.Int,scheduled[0].Minutes);return[new Allocation(Convert.ToInt64(await minuteDetail.ExecuteScalarAsync(t)),x.StartWorkDate,x.RequestedQuantity)];
        }
        if(scheduled.Count==0)throw new InvalidOperationException("ช่วงวันที่ลาไม่มีวันทำงานตามตารางที่มีผล");
        if(type.Unit=="DAY"&&x.RequestedQuantity!=scheduled.Count)throw new InvalidOperationException("จำนวนวันลาต้องเท่ากับจำนวนวันทำงานในช่วงที่เลือก");
        if(type.Unit=="MINUTE"&&(scheduled.Count!=1||x.RequestedQuantity!=decimal.Truncate(x.RequestedQuantity)||x.RequestedQuantity>scheduled[0].Minutes))throw new InvalidOperationException("การลาแบบนาทีต้องอยู่ในวันทำงานเดียวและไม่เกินนาทีงานสุทธิ");
        var allocations=new List<Allocation>();foreach(var row in scheduled){var quantity=type.Unit=="DAY"?1m:x.RequestedQuantity;await using var d=new SqlCommand("INSERT dbo.TDTMLeaveRequestDate(RequestID,CompanyID,SubjectEmployeeID,WorkDate,RequestedQuantity,ScheduledNetMinutes) OUTPUT INSERTED.LeaveRequestDateID VALUES(@R,@C,@E,@D,@Q,@M)",c,tx);Add(d,"@R",SqlDbType.BigInt,id);Add(d,"@C",SqlDbType.BigInt,company);Add(d,"@E",SqlDbType.BigInt,employee);Add(d,"@D",SqlDbType.Date,row.Date.ToDateTime(TimeOnly.MinValue));Add(d,"@Q",SqlDbType.Decimal,quantity);d.Parameters["@Q"].Precision=18;d.Parameters["@Q"].Scale=4;Add(d,"@M",SqlDbType.Int,row.Minutes);var detailId=Convert.ToInt64(await d.ExecuteScalarAsync(t));allocations.Add(new Allocation(detailId,row.Date,quantity));}return allocations;}
    private static async Task<long> Ledger(SqlConnection c,SqlTransaction tx,long company,long employee,Type type,long request,string code,decimal quantity,long user,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMLeaveEntitlementLedger(CompanyID,EmployeeID,LeaveTypeID,UnitCode,EntryTypeCode,Quantity,EffectiveDate,RequestID,CreateBy) OUTPUT INSERTED.LeaveEntitlementLedgerID VALUES(@C,@E,@T,@U,@Code,@Q,CONVERT(date,SYSDATETIME()),@R,@By)",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@T",SqlDbType.BigInt,type.Id);Add(q,"@U",SqlDbType.VarChar,type.Unit,10);Add(q,"@Code",SqlDbType.VarChar,code,20);Add(q,"@Q",SqlDbType.Decimal,quantity);q.Parameters["@Q"].Precision=18;q.Parameters["@Q"].Scale=4;Add(q,"@R",SqlDbType.BigInt,request);Add(q,"@By",SqlDbType.BigInt,user);return Convert.ToInt64(await q.ExecuteScalarAsync(t));}
    private static async Task Reservation(SqlConnection c,SqlTransaction tx,long company,long employee,Type type,long request,decimal quantity,long ledger,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMLeaveReservation(CompanyID,RequestID,EmployeeID,LeaveTypeID,UnitCode,ReservedQuantity,ReservedLedgerID)VALUES(@C,@R,@E,@T,@U,@Q,@L)",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@R",SqlDbType.BigInt,request);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@T",SqlDbType.BigInt,type.Id);Add(q,"@U",SqlDbType.VarChar,type.Unit,10);Add(q,"@Q",SqlDbType.Decimal,quantity);q.Parameters["@Q"].Precision=18;q.Parameters["@Q"].Scale=4;Add(q,"@L",SqlDbType.BigInt,ledger);await q.ExecuteNonQueryAsync(t);}
    private static async Task Decision(SqlConnection c,SqlTransaction tx,long request,long user,long? employee,bool self,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMApprovalDecision(RequestID,StepOrder,DecisionCode,ActorUserID,ActorEmployeeID,IsSelfApproved,CorrelationID)VALUES(@R,0,'APPROVED',@U,@E,@S,NEWID())",c,tx);Add(q,"@R",SqlDbType.BigInt,request);Add(q,"@U",SqlDbType.BigInt,user);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@S",SqlDbType.Bit,self);await q.ExecuteNonQueryAsync(t);}
    private static async Task Usage(SqlConnection c,SqlTransaction tx,long company,long employee,Type type,long request,Allocation allocation,long ledger,long user,CancellationToken t){await using var q=new SqlCommand("INSERT dbo.TDTMLeaveUsage(CompanyID,RequestID,LeaveRequestDateID,EmployeeID,LeaveTypeID,WorkDate,UnitCode,UsedQuantity,UsageLedgerID,CreateBy)VALUES(@C,@R,@D,@E,@T,@W,@U,@Q,@L,@By)",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@R",SqlDbType.BigInt,request);Add(q,"@D",SqlDbType.BigInt,allocation.Id);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@T",SqlDbType.BigInt,type.Id);Add(q,"@W",SqlDbType.Date,allocation.WorkDate.ToDateTime(TimeOnly.MinValue));Add(q,"@U",SqlDbType.VarChar,type.Unit,10);Add(q,"@Q",SqlDbType.Decimal,allocation.Quantity);q.Parameters["@Q"].Precision=18;q.Parameters["@Q"].Scale=4;Add(q,"@L",SqlDbType.BigInt,ledger);Add(q,"@By",SqlDbType.BigInt,user);await q.ExecuteNonQueryAsync(t);}
    private static async Task Notify(SqlConnection c,SqlTransaction tx,long company,long request,long employee,string status,CancellationToken t){var json=JsonSerializer.Serialize(new{requestId=request,processCode="LEAVE_REQUEST",statusCode=status});await using var q=new SqlCommand("INSERT dbo.TDTMNotificationDelivery(CompanyID,RequestID,RecipientEmployeeID,ChannelCode,StatusCode,PayloadJson)VALUES(@C,@R,@E,'IN_APP','PENDING',@J)",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@R",SqlDbType.BigInt,request);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@J",SqlDbType.NVarChar,json,-1);await q.ExecuteNonQueryAsync(t);}
    private static DateOnly ThailandToday()=>DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow,TimeZoneInfo.FindSystemTimeZoneById("Asia/Bangkok")));
    private static bool RowVersion(string? value)=>value is {Length:16}&&value.All(Uri.IsHexDigit);
    private static async Task<List<object>> LookupRows(SqlConnection c,
        string sql,long company,CancellationToken token,long? user=null,long? actorEmployee=null)
    {
        await using var q=new SqlCommand(sql,c);Add(q,"@C",SqlDbType.BigInt,company);
        if(sql.Contains("@U",StringComparison.Ordinal))Add(q,"@U",SqlDbType.BigInt,user);
        if(sql.Contains("@ActorEmployee",StringComparison.Ordinal))Add(q,"@ActorEmployee",SqlDbType.BigInt,actorEmployee);
        await using var r=await q.ExecuteReaderAsync(token);var rows=new List<object>();
        while(await r.ReadAsync(token)){var row=new Dictionary<string,object?>();for(var i=0;i<r.FieldCount;i++)row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);rows.Add(row);}return rows;
    }
    private static void BindList(SqlCommand q,long company,long user,long? employee,string? status,DateOnly from,DateOnly to,bool self,bool approval){Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@U",SqlDbType.BigInt,user);Add(q,"@Employee",SqlDbType.BigInt,employee);Add(q,"@ActorEmployee",SqlDbType.BigInt,employee);Add(q,"@Status",SqlDbType.VarChar,string.IsNullOrWhiteSpace(status)?null:status.Trim().ToUpperInvariant(),20);Add(q,"@F",SqlDbType.Date,from.ToDateTime(TimeOnly.MinValue));Add(q,"@T",SqlDbType.Date,to.ToDateTime(TimeOnly.MinValue));Add(q,"@Self",SqlDbType.Bit,self);Add(q,"@Approval",SqlDbType.Bit,approval);}
    private static void Add(SqlCommand q,string n,SqlDbType t,object? v,int s=0){var p=s==0?q.Parameters.Add(n,t):q.Parameters.Add(n,t,s);p.Value=v??DBNull.Value;}
}
