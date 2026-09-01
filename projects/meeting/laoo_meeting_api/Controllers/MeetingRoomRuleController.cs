using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Route("api/company/meeting-rooms/{roomId:long}/rules"), Authorize]
public sealed class MeetingRoomRuleController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "23002";

    [HttpGet]
    public async Task<IActionResult> Get(long roomId, CancellationToken token)
    {
        if (!CanCompany() || CompanyId() is not long company || !await Permission("VIEW", token)) return Forbid();
        await using var c = await Open(token);
        const string sql = "SELECT B.RuleID,B.ApprovalMode,B.MaxAdvanceDays,B.MaxDurationMinutes,B.CancelBeforeMinutes,B.RequireAllApprovers,B.Remark,B.IsActive,R.RoomCode,R.RoomNameTH FROM dbo.TDADMeetingRoomBookingRule B INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=@company WHERE B.RoomID=@room";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", company); Add(cmd, "@room", roomId);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return Ok(Array.Empty<object>());
        var ruleId = reader.GetInt64(0);
        var result = new Dictionary<string, object?> {
            ["ruleId"] = ruleId, ["roomId"] = roomId, ["approvalMode"] = reader.GetString(1),
            ["maxAdvanceDays"] = I(reader, 2), ["maxDurationMinutes"] = I(reader, 3), ["cancelBeforeMinutes"] = I(reader, 4),
            ["requireAllApprovers"] = reader.GetBoolean(5), ["remark"] = N(reader, 6), ["isActive"] = reader.GetBoolean(7),
            ["roomCode"] = reader.GetString(8), ["roomName"] = reader.GetString(9)
        };
        await reader.CloseAsync();
        const string approverSql = "SELECT EmployeeID,ApprovalOrder FROM dbo.TDADMeetingRoomBookingRuleApprover WHERE RuleID=@rule ORDER BY ApprovalOrder,EmployeeID";
        await using var approver = new SqlCommand(approverSql, c); Add(approver, "@rule", ruleId);
        await using var approverReader = await approver.ExecuteReaderAsync(token); var approvers = new List<object>();
        while (await approverReader.ReadAsync(token)) approvers.Add(new { employeeId = approverReader.GetInt64(0), approvalOrder = approverReader.GetInt32(1) });
        result["approvers"] = approvers;
        return Ok(new[] { result });
    }

    [HttpPost]
    public Task<IActionResult> Create(long roomId, RuleRequest request, CancellationToken token) => Save(roomId, request, token);

    [HttpPut]
    public Task<IActionResult> Update(long roomId, RuleRequest request, CancellationToken token) => Save(roomId, request, token);

    [HttpDelete]
    public async Task<IActionResult> Delete(long roomId, CancellationToken token)
    {
        if (!CanCompany() || CompanyId() is not long company || !await Permission("DELETE", token)) return Forbid();
        await using var c = await Open(token);
        const string sql = "DELETE B FROM dbo.TDADMeetingRoomBookingRule B INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=@company WHERE B.RoomID=@room";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", company); Add(cmd, "@room", roomId);
        return await cmd.ExecuteNonQueryAsync(token) == 0 ? NotFound(new { message = "ไม่พบกฎของห้องประชุม", description = $"RoomID {roomId} ยังไม่มีกฎ" }) : NoContent();
    }

    private async Task<IActionResult> Save(long roomId, RuleRequest request, CancellationToken token)
    {
        if (!CanCompany() || CompanyId() is not long company || !await Permission("EDIT", token)) return Forbid();
        if (request.ApprovalMode is not ("NONE" or "LINE_MANAGER" or "SELECTED")) return BadRequest(new { message = "รูปแบบการอนุมัติไม่ถูกต้อง", description = "ใช้ NONE, LINE_MANAGER หรือ SELECTED เท่านั้น" });
        if (request.ApprovalMode == "SELECTED" && (request.EmployeeIds is null || request.EmployeeIds.Count == 0)) return BadRequest(new { message = "ยังไม่ได้กำหนดผู้อนุมัติ", description = "กรุณาเลือกผู้อนุมัติอย่างน้อย 1 คน" });
        await using var c = await Open(token); await using var tx = await c.BeginTransactionAsync(token);
        try
        {
            const string sql = "IF NOT EXISTS(SELECT 1 FROM dbo.TDADMeetingRoom WHERE RoomID=@room AND CompanyID=@company) THROW 50021,'ROOM_NOT_FOUND',1; IF EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomBookingRule WHERE RoomID=@room AND CompanyID=@company) BEGIN UPDATE dbo.TDADMeetingRoomBookingRule SET ApprovalMode=@mode,MaxAdvanceDays=@advance,MaxDurationMinutes=@duration,CancelBeforeMinutes=@cancel,RequireAllApprovers=@all,Remark=@remark,IsActive=@active,UpdateDate=SYSUTCDATETIME() WHERE RoomID=@room AND CompanyID=@company; SELECT RuleID FROM dbo.TDADMeetingRoomBookingRule WHERE RoomID=@room AND CompanyID=@company; END ELSE BEGIN INSERT dbo.TDADMeetingRoomBookingRule(CompanyID,RoomID,ApprovalMode,MaxAdvanceDays,MaxDurationMinutes,CancelBeforeMinutes,RequireAllApprovers,Remark,IsActive) VALUES(@company,@room,@mode,@advance,@duration,@cancel,@all,@remark,@active); SELECT CAST(SCOPE_IDENTITY() AS BIGINT); END";
            await using var cmd = new SqlCommand(sql, c, (SqlTransaction)tx); Add(cmd, "@company", company); Add(cmd, "@room", roomId); Add(cmd, "@mode", request.ApprovalMode); Add(cmd, "@advance", request.MaxAdvanceDays); Add(cmd, "@duration", request.MaxDurationMinutes); Add(cmd, "@cancel", request.CancelBeforeMinutes); Add(cmd, "@all", request.RequireAllApprovers); Add(cmd, "@remark", request.Remark); Add(cmd, "@active", request.IsActive);
            var ruleId = Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
            await using var clear = new SqlCommand("DELETE FROM dbo.TDADMeetingRoomBookingRuleApprover WHERE RuleID=@rule", c, (SqlTransaction)tx); Add(clear, "@rule", ruleId); await clear.ExecuteNonQueryAsync(token);
            var order = 1;
            foreach (var employeeId in (request.EmployeeIds ?? []).Distinct())
            {
                await using var add = new SqlCommand("INSERT dbo.TDADMeetingRoomBookingRuleApprover(RuleID,EmployeeID,ApprovalOrder) SELECT @rule,EmployeeID,@order FROM dbo.TDADEmployee WHERE EmployeeID=@employee AND CompanyID=@company AND IsActive=1", c, (SqlTransaction)tx);
                Add(add, "@rule", ruleId); Add(add, "@employee", employeeId); Add(add, "@company", company); Add(add, "@order", order);
                if (await add.ExecuteNonQueryAsync(token) != 1)
                {
                    throw new InvalidApproverException(employeeId);
                }
                order++;
            }
            await tx.CommitAsync(token); return Ok(new { ruleId, roomId });
        }
        catch (SqlException ex) when (ex.Number == 50021) { await tx.RollbackAsync(token); return NotFound(new { message = "ไม่พบห้องประชุม", description = $"RoomID {roomId} ไม่อยู่ในบริษัทของผู้ใช้งาน" }); }
        catch (InvalidApproverException ex) { await tx.RollbackAsync(token); return BadRequest(new { message = "บันทึกผู้อนุมัติไม่สำเร็จ", description = $"ไม่พบพนักงานรหัส ID {ex.EmployeeId} ในบริษัท หรือพนักงานไม่ได้อยู่ในสถานะใช้งาน" }); }
        catch { await tx.RollbackAsync(token); throw; }
    }

    private async Task<bool> Permission(string action, CancellationToken token) { await using var c = await Open(token); return await Allowed(c, action, token); }
    private async Task<bool> Allowed(SqlConnection c, string action, CancellationToken token) { if (!CanCompany() || CompanyId() is null || !long.TryParse(User.FindFirstValue("project_id"), out var project) || !long.TryParse(User.FindFirstValue("user_id"), out var user)) return false; const string sql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action) THEN 1 ELSE 0 END"; await using var cmd = new SqlCommand(sql, c); Add(cmd, "@user", user); Add(cmd, "@company", CompanyId() ?? 0); Add(cmd, "@project", project); Add(cmd, "@screen", ScreenCode); Add(cmd, "@action", action); return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token)); }
    private async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private bool CanCompany() => string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase);
    private long? CompanyId() => long.TryParse(User.FindFirstValue("company_id"), out var id) && id > 0 ? id : null;
    private static long? I(SqlDataReader r, int i) => r.IsDBNull(i) ? null : Convert.ToInt64(r.GetValue(i));
    private static string? N(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static void Add(SqlCommand c, string name, object? value) => c.Parameters.AddWithValue(name, value ?? DBNull.Value);
}

file sealed class InvalidApproverException(long employeeId) : Exception
{
    public long EmployeeId { get; } = employeeId;
}

public sealed record RuleRequest(string ApprovalMode, int? MaxAdvanceDays, int? MaxDurationMinutes, int? CancelBeforeMinutes, bool RequireAllApprovers, string? Remark, List<long>? EmployeeIds, bool IsActive = true);
