using System.Data;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooVisitorModule.Controllers;

[ApiController]
[Authorize]
[Route("api/visitor")]
public sealed class VisitorSystemController(
    IConfiguration configuration,
    IWebHostEnvironment environment) : ControllerBase
{
    private const string SettingsMenu = "36004";
    private const string CheckInMenu = "31002";
    private const string HistoryMenu = "31005";
    private const string HostConfirmMenu = "32003";
    private static readonly TimeSpan ThailandOffset = TimeSpan.FromHours(7);

    public sealed record VisitorSettingsUpdateRequest(
        DateOnly EffectiveFrom,
        bool AllowManualEntry,
        bool AllowCameraCapture,
        bool AllowNationalIdReader,
        bool RequireVisitorPhone,
        bool RequireHostEmployee,
        bool RequireVisitPurpose,
        bool RequireCardImage,
        bool RequireNationalIdNumber,
        bool RequireNationalIdExpiry,
        bool RequireCheckOut,
        string RetentionPolicyCode,
        string Reason,
        string StateToken);

    public sealed record CheckInRequest(
        string VisitorName,
        string? Phone,
        string? NationalIdNumber,
        DateOnly? NationalIdExpiryDate,
        string HostType,
        long? HostEmployeeId,
        long? HostResidentId,
        long? HostServiceCustomerId,
        long? HostRoomId,
        long? HostTenantId,
        long? HostTenantContactId,
        string? VisitPurpose,
        string CaptureMethod,
        string RequestId,
        long? VisitorAppointmentId = null);

    public sealed record CheckOutRequest(
        string VisitOutcomeCode,
        string CheckoutReasonCode,
        string? CheckoutNote);

    public sealed record VisitNoteRequest(string NoteStageCode, string NoteText);
    public sealed record HostConfirmationRequest(string ConfirmationResultCode, string? ConfirmationNote);

    [HttpGet("host-confirm/actions")]
    public async Task<IActionResult> HostConfirmActions(CancellationToken token)
    {
        if (!TryScope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        return Ok(new { caption = await Caption(connection, HostConfirmMenu, token),
            view = await Can(connection, HostConfirmMenu, "VIEW", token),
            edit = await Can(connection, HostConfirmMenu, "EDIT", token) });
    }

    [HttpGet("host-confirm/pending")]
    public async Task<IActionResult> HostConfirmPending(CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, HostConfirmMenu, "VIEW", token)) return Forbid();
        var identities = await CurrentHostIdentities(token);
        var rows = await HostPendingRows(connection, companyId, identities, token);
        return Ok(new { items = rows });
    }

    [HttpGet("host-confirm/visits/{visitId:long}")]
    public async Task<IActionResult> HostConfirmDetail(long visitId, CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, HostConfirmMenu, "VIEW", token)) return Forbid();
        var visit = await HostVisit(connection, companyId, visitId, await CurrentHostIdentities(token), token);
        if (visit is null) return NotFound(new { message = "ไม่พบรายการรอเข้าพบของคุณ" });
        var images = await ReadRows(connection, """
SELECT VisitorVisitImageID,EvidenceType,CaptureStage,SideCode,OriginalFileName,ContentType,ContentLength,CreateDate,CreateBy
FROM dbo.TDTMVisitorVisitImage WHERE CompanyID=@CompanyID AND VisitorVisitID=@VisitID ORDER BY CreateDate,VisitorVisitImageID;
""", companyId, visitId, token);
        return Ok(new { visit, images });
    }

    [HttpGet("host-confirm/visits/{visitId:long}/images/{imageId:long}")]
    public async Task<IActionResult> HostConfirmImage(long visitId, long imageId, CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, HostConfirmMenu, "VIEW", token) ||
            await HostVisit(connection, companyId, visitId, await CurrentHostIdentities(token), token) is null) return Forbid();
        await using var command = new SqlCommand("SELECT FileRelativePath,ContentType FROM dbo.TDTMVisitorVisitImage WHERE CompanyID=@CompanyID AND VisitorVisitID=@VisitID AND VisitorVisitImageID=@ImageID", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@VisitID", SqlDbType.BigInt, visitId); Add(command, "@ImageID", SqlDbType.BigInt, imageId);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound();
        var relative = reader.GetString(0); var contentType = reader.GetString(1);
        var root = Path.GetFullPath(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"));
        var file = Path.GetFullPath(Path.Combine(root, relative));
        if (!IsWithinRoot(root, file) || !System.IO.File.Exists(file)) return NotFound();
        return PhysicalFile(file, contentType);
    }

    [HttpPost("host-confirm/visits/{visitId:long}")]
    public async Task<IActionResult> ConfirmHostVisit(long visitId, HostConfirmationRequest request, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var result = Clean(request.ConfirmationResultCode)?.ToUpperInvariant();
        if (result is not ("MET" or "NOT_MET")) return BadRequest(new { message = "ผลการเข้าพบไม่ถูกต้อง" });
        if (request.ConfirmationNote?.Length > 1000) return BadRequest(new { message = "หมายเหตุต้องไม่เกิน 1,000 ตัวอักษร" });
        await using var connection = await Open(token);
        if (!await Can(connection, HostConfirmMenu, "EDIT", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            if (await HostVisit(connection, companyId, visitId, await CurrentHostIdentities(token), token, transaction) is null)
                return NotFound(new { message = "ไม่พบรายการรอเข้าพบของคุณ" });
            var name = User.FindFirstValue(ClaimTypes.Name) ?? User.FindFirstValue("name") ?? userId.ToString();
            await using var insert = new SqlCommand("""
INSERT dbo.TDTMVisitorHostConfirmation(CompanyID,VisitorVisitID,ConfirmationResultCode,ConfirmationNote,ConfirmedByUserID,ConfirmedByNameSnapshot)
VALUES(@CompanyID,@VisitID,@Result,@Note,@UserID,@Name);
""", connection, transaction);
            Add(insert, "@CompanyID", SqlDbType.BigInt, companyId); Add(insert, "@VisitID", SqlDbType.BigInt, visitId); Add(insert, "@Result", SqlDbType.VarChar, result, 20); Add(insert, "@Note", SqlDbType.NVarChar, Clean(request.ConfirmationNote), 1000); Add(insert, "@UserID", SqlDbType.BigInt, userId); Add(insert, "@Name", SqlDbType.NVarChar, name, 200);
            try { await insert.ExecuteNonQueryAsync(token); }
            catch (SqlException exception) when (exception.Number is 2601 or 2627) { return Conflict(new { message = "รายการนี้ได้รับการยืนยันแล้ว" }); }
            await transaction.CommitAsync(token);
            return Ok(new { visitorVisitId = visitId, confirmationResultCode = result });
        }
        catch { await transaction.RollbackAsync(token); throw; }
    }

    [HttpGet("company-context")]
    public async Task<IActionResult> CompanyContext(CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, SettingsMenu, "VIEW", token) &&
            !await Can(connection, CheckInMenu, "VIEW", token)) return Forbid();
        var businessType = await BusinessType(connection, companyId, token);
        return Ok(new
        {
            businessTypeCode = businessType,
            employeeAllowed = businessType == "COMPANY",
            residentAllowed = businessType is "DORMITORY" or "VILLAGE",
            serviceCustomerAllowed = businessType == "SERVICE_CENTER",
            defaultHostType = businessType switch
            {
                "DORMITORY" => "RESIDENT",
                "RENTAL_OFFICE" => "RENTAL_OFFICE",
                "VILLAGE" => "VILLAGE",
                "COMPANY" => "EMPLOYEE",
                _ => "SERVICE_CUSTOMER",
            },
        });
    }

    [HttpGet("check-in-context")]
    public async Task<IActionResult> CheckInContext(CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "VIEW", token)) return Forbid();
        var point = await ActiveContactPoint(connection, null, companyId, userId, token);
        if (point is null)
            return NotFound(new { message = "บัญชีนี้ยังไม่ได้กำหนดจุดติดต่อที่ใช้งานอยู่ กรุณาติดต่อผู้ดูแล" });
        return Ok(new { contactPointId = point.Id, contactPointCode = point.Code,
            contactPointName = point.Name, branchId = point.BranchId, branchName = point.BranchName });
    }

    [HttpGet("guarantor-rooms")]
    public async Task<IActionResult> GuarantorRooms([FromQuery] string? search, CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "VIEW", token)) return Forbid();
        if (!await IsDormitory(connection, companyId, token))
            return BadRequest(new { message = "Company นี้ไม่ได้ใช้ทะเบียนผู้พักอาศัยเป็นผู้รับรอง" });
        var q = Clean(search) ?? string.Empty;
        await using var command = new SqlCommand("""
SELECT TOP (50) RM.RoomID,RM.RoomCode,RM.RoomNameTH,B.BuildingNameTH,F.FloorNameTH
FROM dbo.TDADRoom RM
JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID AND B.IsActive=1
JOIN dbo.TDADFloor F ON F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID AND F.IsActive=1
WHERE RM.CompanyID=@CompanyID AND RM.IsActive=1 AND RM.RoomTypeCode=N'RESIDENTIAL'
  AND (@Search=N'' OR RM.RoomCode LIKE @Like OR RM.RoomNameTH LIKE @Like
       OR B.BuildingNameTH LIKE @Like OR F.FloorNameTH LIKE @Like)
ORDER BY B.BuildingNameTH,F.FloorNumber,RM.RoomCode,RM.RoomID;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@Search", SqlDbType.NVarChar, q, 200);
        Add(command, "@Like", SqlDbType.NVarChar, $"%{q}%", 210);
        var items = new List<object>();
        await using var reader = await command.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
            items.Add(new { id = reader.GetInt64(0), code = reader.GetString(1), name = Text(reader, 2), building = reader.GetString(3), floor = reader.GetString(4) });
        return Ok(new { items });
    }

    [HttpGet("host-options")]
    public async Task<IActionResult> HostOptions(
        [FromQuery] string hostType,
        [FromQuery] string? search,
        [FromQuery] long? roomId,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "VIEW", token)) return Forbid();
        var type = Clean(hostType)?.ToUpperInvariant();
        var businessType = await BusinessType(connection, companyId, token);
        if (type is not ("EMPLOYEE" or "RESIDENT" or "SERVICE_CUSTOMER" or "RENTAL_OFFICE" or "VILLAGE") ||
            (businessType == "DORMITORY" && type != "RESIDENT") ||
            (businessType == "COMPANY" && type != "EMPLOYEE") ||
            (businessType == "SERVICE_CENTER" && type != "SERVICE_CUSTOMER") ||
            (businessType == "RENTAL_OFFICE" && type != "RENTAL_OFFICE") ||
            (businessType == "VILLAGE" && type != "VILLAGE"))
            return BadRequest(new { message = "ประเภทผู้รับรองไม่ถูกต้องสำหรับ Company นี้" });
        if (type is "EMPLOYEE" or "RENTAL_OFFICE" or "VILLAGE")
        {
            var sharedType = type == "EMPLOYEE" ? "COMPANY" : type;
            return Ok(new { hostType = type, items = await SharedHostRows(sharedType, Clean(search), token) });
        }
        if (type == "RESIDENT" && roomId is null)
            return BadRequest(new { message = "กรุณาเลือกห้องพักก่อนค้นหาผู้รับรอง" });

        var q = Clean(search) ?? string.Empty;
        var items = new List<object>();
        if (type == "SERVICE_CUSTOMER")
        {
            await using var command = new SqlCommand("""
SELECT TOP (50) SC.ServiceCustomerID,P.FullName,P.Mobile
FROM dbo.TDADServiceCustomer SC
JOIN dbo.TDADPerson P ON P.CompanyID=SC.CompanyID AND P.PersonID=SC.PersonID AND P.IsActive=1
WHERE SC.CompanyID=@CompanyID AND SC.IsActive=1
  AND (@Search=N'' OR P.FullName LIKE @Like OR P.Mobile LIKE @Like)
ORDER BY P.FullName,SC.ServiceCustomerID;
""", connection);
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(command, "@Search", SqlDbType.NVarChar, q, 200);
            Add(command, "@Like", SqlDbType.NVarChar, $"%{q}%", 210);
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token))
                items.Add(new { id = reader.GetInt64(0), code = "ผู้ใช้บริการ", name = reader.GetString(1), phone = Text(reader, 2), room = (string?)null });
        }
        else
        {
            await using var command = new SqlCommand("""
SELECT TOP (50) R.ResidentID,P.FullName,P.Mobile,RM.RoomCode,RM.RoomNameTH,B.BuildingNameTH,F.FloorNameTH
FROM dbo.TDADResident R
JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID AND P.IsActive=1
JOIN dbo.TDADRoom RM ON RM.CompanyID=R.CompanyID AND RM.RoomID=R.RoomID AND RM.IsActive=1
JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID AND B.IsActive=1
JOIN dbo.TDADFloor F ON F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID AND F.IsActive=1
WHERE R.CompanyID=@CompanyID AND R.IsActive=1 AND RM.RoomID=@RoomID
  AND R.StartDate<=CONVERT(date,SYSUTCDATETIME())
  AND (R.EndDate IS NULL OR R.EndDate>=CONVERT(date,SYSUTCDATETIME()))
  AND (@Search=N'' OR P.FullName LIKE @Like OR P.Mobile LIKE @Like)
ORDER BY P.FullName,R.ResidentID;
""", connection);
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(command, "@Search", SqlDbType.NVarChar, q, 200);
            Add(command, "@Like", SqlDbType.NVarChar, $"%{q}%", 210);
            Add(command, "@RoomID", SqlDbType.BigInt, roomId);
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token))
                items.Add(new { id = reader.GetInt64(0), code = $"ห้อง {reader.GetString(3)}", name = reader.GetString(1), phone = Text(reader, 2), room = Text(reader, 4) ?? reader.GetString(3), building = reader.GetString(5), floor = reader.GetString(6) });
        }
        return Ok(new { hostType = type, items });
    }

    [HttpGet("system-settings/actions")]
    public async Task<IActionResult> SettingsActions(CancellationToken token)
    {
        if (!TryScope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        return Ok(new
        {
            menuCode = SettingsMenu,
            caption = await Caption(connection, SettingsMenu, token),
            screenType = 2,
            view = await Can(connection, SettingsMenu, "VIEW", token),
            edit = await Can(connection, SettingsMenu, "EDIT", token),
            create = false,
            delete = false,
        });
    }

    [HttpGet("system-settings")]
    public async Task<IActionResult> GetSettings(CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, SettingsMenu, "VIEW", token) &&
            !await Can(connection, CheckInMenu, "VIEW", token)) return Forbid();
        var state = await LoadSettings(connection, null, companyId, ThailandDate(), token);
        return Ok(ToSettingsJson(state));
    }

    [HttpPut("system-settings")]
    public async Task<IActionResult> UpdateSettings(
        VisitorSettingsUpdateRequest request,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var reason = Clean(request.Reason);
        var retention = Clean(request.RetentionPolicyCode)?.ToUpperInvariant();
        if (request.EffectiveFrom < ThailandDate())
            return BadRequest(new { message = "วันที่เริ่มใช้ต้องไม่ย้อนหลัง" });
        if (reason is null || reason.Length > 1000)
            return BadRequest(new { message = "กรุณาระบุเหตุผลไม่เกิน 1,000 ตัวอักษร" });
        if (request.AllowNationalIdReader)
            return BadRequest(new { message = "การอ่านบัตรด้วยเครื่องอ่านยังไม่เปิดใช้งาน" });
        if (!request.AllowManualEntry && !request.AllowCameraCapture)
            return BadRequest(new { message = "ต้องเปิดวิธีบันทึกอย่างน้อย 1 วิธี" });
        if (retention is not ("COMPANY_POLICY" or "90_DAYS"))
            return BadRequest(new { message = "นโยบายเก็บข้อมูลไม่ถูกต้อง" });

        await using var connection = await Open(token);
        if (!await Can(connection, SettingsMenu, "EDIT", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(
            IsolationLevel.Serializable, token);
        try
        {
            var before = await LoadSettings(connection, transaction, companyId,
                request.EffectiveFrom, token);
            if (!string.Equals(request.StateToken, StateToken(before), StringComparison.Ordinal))
            {
                await transaction.RollbackAsync(token);
                return Conflict(new { message = "ค่าถูกแก้ไขแล้ว กรุณาโหลดข้อมูลใหม่" });
            }

            var settings = new SettingsState(
                before.VersionId,
                before.VersionNo + (before.EffectiveFrom == request.EffectiveFrom ? 1 : 1),
                request.EffectiveFrom,
                request.AllowManualEntry,
                request.AllowCameraCapture,
                false,
                request.RequireVisitorPhone,
                request.RequireHostEmployee,
                request.RequireVisitPurpose,
                request.RequireCardImage,
                request.RequireNationalIdNumber,
                request.RequireNationalIdExpiry,
                request.RequireCheckOut,
                retention!);

            if (before.VersionId is long currentId && before.EffectiveFrom == request.EffectiveFrom)
            {
                await using var update = new SqlCommand("""
UPDATE dbo.TDTMVisitorSystemSettingVersion
SET VersionNo=@VersionNo,AllowManualEntry=@Manual,AllowCameraCapture=@Camera,
    AllowNationalIdReader=0,RequireVisitorPhone=@Phone,RequireHostEmployee=@Host,
    RequireVisitPurpose=@Purpose,RequireCardImage=@Image,RequireNationalIdNumber=@IdNo,
    RequireNationalIdExpiry=@IdExpiry,RequireCheckOut=@CheckOut,
    RetentionPolicyCode=@Retention,UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE VisitorSystemSettingVersionID=@ID AND CompanyID=@CompanyID;
""", connection, transaction);
                Add(update, "@VersionNo", SqlDbType.Int, settings.VersionNo);
                BindSettings(update, settings);
                Add(update, "@UserID", SqlDbType.BigInt, userId);
                Add(update, "@ID", SqlDbType.BigInt, currentId);
                Add(update, "@CompanyID", SqlDbType.BigInt, companyId);
                await update.ExecuteNonQueryAsync(token);
                settings = settings with { VersionId = currentId };
            }
            else
            {
                await using var close = new SqlCommand("""
UPDATE dbo.TDTMVisitorSystemSettingVersion
SET EffectiveTo=DATEADD(day,-1,@EffectiveFrom),UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE CompanyID=@CompanyID AND IsActive=1 AND EffectiveFrom<@EffectiveFrom AND EffectiveTo IS NULL;
""", connection, transaction);
                Add(close, "@EffectiveFrom", SqlDbType.Date, request.EffectiveFrom.ToDateTime(TimeOnly.MinValue));
                Add(close, "@UserID", SqlDbType.BigInt, userId);
                Add(close, "@CompanyID", SqlDbType.BigInt, companyId);
                await close.ExecuteNonQueryAsync(token);

                await using var insert = new SqlCommand("""
INSERT dbo.TDTMVisitorSystemSettingVersion
(CompanyID,ProjectID,VersionNo,EffectiveFrom,AllowManualEntry,AllowCameraCapture,
 AllowNationalIdReader,RequireVisitorPhone,RequireHostEmployee,RequireVisitPurpose,
 RequireCardImage,RequireNationalIdNumber,RequireNationalIdExpiry,RequireCheckOut,
 RetentionPolicyCode,CreateBy)
SELECT @CompanyID,ProjectID,@VersionNo,@EffectiveFrom,@Manual,@Camera,0,@Phone,@Host,
       @Purpose,@Image,@IdNo,@IdExpiry,@CheckOut,@Retention,@UserID
FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_VISITOR' AND IsActive=1;
SELECT CONVERT(bigint,SCOPE_IDENTITY());
""", connection, transaction);
                Add(insert, "@CompanyID", SqlDbType.BigInt, companyId);
                BindSettings(insert, settings);
                Add(insert, "@UserID", SqlDbType.BigInt, userId);
                settings = settings with
                {
                    VersionId = Convert.ToInt64(await insert.ExecuteScalarAsync(token)),
                };
            }

            await using var audit = new SqlCommand("""
INSERT dbo.TDTMVisitorSystemSettingAudit
(CompanyID,SettingVersionID,BeforeJson,AfterJson,Reason,ActorUserID)
VALUES(@CompanyID,@VersionID,@BeforeJson,@AfterJson,@Reason,@UserID);
""", connection, transaction);
            Add(audit, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(audit, "@VersionID", SqlDbType.BigInt, settings.VersionId);
            Add(audit, "@BeforeJson", SqlDbType.NVarChar,
                JsonSerializer.Serialize(ToSettingsJson(before)), -1);
            Add(audit, "@AfterJson", SqlDbType.NVarChar,
                JsonSerializer.Serialize(ToSettingsJson(settings)), -1);
            Add(audit, "@Reason", SqlDbType.NVarChar, reason, 1000);
            Add(audit, "@UserID", SqlDbType.BigInt, userId);
            await audit.ExecuteNonQueryAsync(token);
            await transaction.CommitAsync(token);
            return NoContent();
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = "ค่าตั้งค่าซ้ำกับ Version ที่มีอยู่" });
        }
    }

    [HttpGet("check-ins/actions")]
    public async Task<IActionResult> CheckInActions(CancellationToken token)
    {
        if (!TryScope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        return Ok(new
        {
            menuCode = CheckInMenu,
            caption = await Caption(connection, CheckInMenu, token),
            screenType = 1,
            view = await Can(connection, CheckInMenu, "VIEW", token),
            create = await Can(connection, CheckInMenu, "CREATE", token),
            edit = await Can(connection, CheckInMenu, "EDIT", token),
            delete = await Can(connection, CheckInMenu, "DELETE", token),
        });
    }

    [HttpGet("check-ins/inside/actions")]
    public async Task<IActionResult> InsideActions(CancellationToken token)
    {
        if (!TryScope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        return Ok(new
        {
            menuCode = CheckInMenu,
            caption = await Caption(connection, CheckInMenu, token),
            screenType = 1,
            view = await Can(connection, CheckInMenu, "VIEW", token),
            create = await Can(connection, CheckInMenu, "CREATE", token),
            edit = await Can(connection, CheckInMenu, "EDIT", token),
        });
    }

    [HttpGet("check-ins/inside")]
    public async Task<IActionResult> Inside(
        CancellationToken token,
        [FromQuery] long? branchId,
        [FromQuery] string? search,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "VIEW", token)) return Forbid();
        var contactPoint = await ActiveContactPoint(connection, null, companyId, userId, token);
        if (contactPoint is null) return NotFound(new { message = "No active contact point is assigned to this account." });
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var query = Clean(search) ?? string.Empty;
        await using var command = new SqlCommand("""
SELECT COUNT_BIG(1) OVER(),VisitorVisitID,BranchID,VisitorName,Phone,NationalIdMasked,HostType,
       HostEmployeeID,HostResidentID,HostNameSnapshot,HostRoomSnapshot,
       VisitPurpose,CaptureMethod,CheckedInDate,ContactPointNameSnapshot
FROM dbo.TDTMVisitorVisit
WHERE CompanyID=@CompanyID AND StatusCode='CHECKED_IN'
  AND VisitorContactPointID=@ContactPointID
  AND (@Search=N'' OR VisitorName LIKE @Like OR Phone LIKE @Like
       OR HostNameSnapshot LIKE @Like OR ContactPointNameSnapshot LIKE @Like)
ORDER BY CheckedInDate DESC,VisitorVisitID DESC
OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@ContactPointID", SqlDbType.BigInt, contactPoint.Id);
        Add(command, "@Search", SqlDbType.NVarChar, query, 200);
        Add(command, "@Like", SqlDbType.NVarChar, $"%{query}%", 210);
        Add(command, "@Offset", SqlDbType.Int, (page - 1) * pageSize);
        Add(command, "@PageSize", SqlDbType.Int, pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        long total = 0;
        while (await reader.ReadAsync(token))
        {
            total = reader.GetInt64(0);
            items.Add(new
            {
                visitorVisitId = reader.GetInt64(1), branchId = reader.GetInt64(2),
                visitorName = reader.GetString(3), phone = Text(reader, 4),
                nationalIdMasked = Text(reader, 5), hostType = reader.GetString(6),
                hostEmployeeId = Long(reader, 7), hostResidentId = Long(reader, 8),
                hostName = Text(reader, 9), hostRoom = Text(reader, 10),
                visitPurpose = Text(reader, 11), captureMethod = reader.GetString(12),
                checkedInDate = reader.GetDateTime(13),
                contactPointName = Text(reader, 14),
            });
        }
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("check-ins/history/actions")]
    public async Task<IActionResult> HistoryActions(CancellationToken token)
    {
        if (!TryScope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        return Ok(new
        {
            menuCode = HistoryMenu,
            caption = await Caption(connection, HistoryMenu, token),
            screenType = 3,
            view = await Can(connection, HistoryMenu, "VIEW", token),
        });
    }

    [HttpGet("check-ins/history")]
    public async Task<IActionResult> History(
        CancellationToken token,
        [FromQuery] string? search,
        [FromQuery] string? outcomeCode,
        [FromQuery] DateOnly? dateFrom,
        [FromQuery] DateOnly? dateTo,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, HistoryMenu, "VIEW", token)) return Forbid();
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var contactPoint = await ActiveContactPoint(connection, null, companyId, userId, token);
        if (contactPoint is null) return NotFound(new { message = "No active contact point is assigned to this account." });
        var query = Clean(search) ?? string.Empty;
        var outcome = Clean(outcomeCode)?.ToUpperInvariant();
        if (outcome is not null && outcome is not ("MET" or "NOT_MET" or "CANCELLED"))
            return BadRequest(new { message = "Invalid visit outcome." });
        if (dateFrom.HasValue && dateTo.HasValue && dateFrom > dateTo)
            return BadRequest(new { message = "Start date must not be after end date." });
        await using var command = new SqlCommand("""
SELECT COUNT_BIG(1) OVER(),VisitorVisitID,VisitorName,HostNameSnapshot,ContactPointNameSnapshot,
       VisitPurpose,CheckedInDate,CheckedOutDate,VisitOutcomeCode,CheckoutReasonCode,
       CheckedOutByNameSnapshot
FROM dbo.TDTMVisitorVisit
WHERE CompanyID=@CompanyID AND StatusCode='CHECKED_OUT'
  AND VisitorContactPointID=@ContactPointID
  AND (@Search=N'' OR VisitorName LIKE @Like OR HostNameSnapshot LIKE @Like
       OR ContactPointNameSnapshot LIKE @Like OR VisitPurpose LIKE @Like)
  AND (@Outcome IS NULL OR VisitOutcomeCode=@Outcome)
  AND (@DateFrom IS NULL OR CheckedOutDate>=@DateFrom)
  AND (@DateTo IS NULL OR CheckedOutDate<DATEADD(DAY,1,@DateTo))
ORDER BY CheckedOutDate DESC,VisitorVisitID DESC
OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@ContactPointID", SqlDbType.BigInt, contactPoint.Id);
        Add(command, "@Search", SqlDbType.NVarChar, query, 200);
        Add(command, "@Like", SqlDbType.NVarChar, $"%{query}%", 210);
        Add(command, "@Outcome", SqlDbType.VarChar, outcome, 20);
        Add(command, "@DateFrom", SqlDbType.Date, dateFrom?.ToDateTime(TimeOnly.MinValue));
        Add(command, "@DateTo", SqlDbType.Date, dateTo?.ToDateTime(TimeOnly.MinValue));
        Add(command, "@Offset", SqlDbType.Int, (page - 1) * pageSize);
        Add(command, "@PageSize", SqlDbType.Int, pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        long total = 0;
        while (await reader.ReadAsync(token))
        {
            total = reader.GetInt64(0);
            items.Add(new
            {
                visitorVisitId = reader.GetInt64(1), visitorName = reader.GetString(2),
                hostName = Text(reader, 3), contactPointName = Text(reader, 4),
                visitPurpose = Text(reader, 5), checkedInDate = reader.GetDateTime(6),
                checkedOutDate = reader.GetDateTime(7), visitOutcomeCode = Text(reader, 8),
                checkoutReasonCode = Text(reader, 9), checkedOutByName = Text(reader, 10),
            });
        }
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("check-ins/{visitId:long}")]
    public async Task<IActionResult> Detail(long visitId, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "VIEW", token) &&
            !await Can(connection, HistoryMenu, "VIEW", token)) return Forbid();
        var contactPoint = await ActiveContactPoint(connection, null, companyId, userId, token);
        if (contactPoint is null) return NotFound(new { message = "No active contact point is assigned to this account." });
        await using var visit = new SqlCommand("""
SELECT V.VisitorVisitID,V.VisitorName,V.Phone,V.HostType,V.HostNameSnapshot,V.HostRoomSnapshot,
       V.ContactPointNameSnapshot,V.VisitPurpose,V.CaptureMethod,V.StatusCode,V.CheckedInDate,
       V.CheckedOutDate,V.VisitOutcomeCode,V.CheckoutReasonCode,V.CheckoutNote,
       V.CheckedOutByUserID,V.CheckedOutByNameSnapshot,V.ResultRecordedDate,
       C.ConfirmationResultCode,C.ConfirmationNote,C.ConfirmedByNameSnapshot,C.CreateDate
FROM dbo.TDTMVisitorVisit V
LEFT JOIN dbo.TDTMVisitorHostConfirmation C
  ON C.CompanyID=V.CompanyID AND C.VisitorVisitID=V.VisitorVisitID
WHERE V.CompanyID=@CompanyID AND V.VisitorVisitID=@VisitID
  AND V.VisitorContactPointID=@ContactPointID;
""", connection);
        Add(visit, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(visit, "@VisitID", SqlDbType.BigInt, visitId);
        Add(visit, "@ContactPointID", SqlDbType.BigInt, contactPoint.Id);
        await using var reader = await visit.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound(new { message = "ไม่พบรายการผู้มาติดต่อ" });
        var detail = new
        {
            visitorVisitId = reader.GetInt64(0), visitorName = reader.GetString(1), phone = Text(reader, 2),
            hostType = reader.GetString(3), hostName = Text(reader, 4), hostRoom = Text(reader, 5),
            contactPointName = Text(reader, 6), visitPurpose = Text(reader, 7), captureMethod = reader.GetString(8),
            statusCode = reader.GetString(9), checkedInDate = reader.GetDateTime(10),
            checkedOutDate = reader.IsDBNull(11) ? (DateTime?)null : reader.GetDateTime(11),
            visitOutcomeCode = Text(reader, 12), checkoutReasonCode = Text(reader, 13), checkoutNote = Text(reader, 14),
            checkedOutByUserId = Long(reader, 15), checkedOutByName = Text(reader, 16),
            resultRecordedDate = reader.IsDBNull(17) ? (DateTime?)null : reader.GetDateTime(17),
            hostConfirmationResultCode = Text(reader, 18), hostConfirmationNote = Text(reader, 19),
            hostConfirmedByName = Text(reader, 20), hostConfirmedDate = Date(reader, 21)
        };
        await reader.CloseAsync();
        var images = await ReadRows(connection, """
SELECT VisitorVisitImageID,EvidenceType,CaptureStage,SideCode,FileRelativePath,OriginalFileName,ContentType,ContentLength,CreateDate,CreateBy
FROM dbo.TDTMVisitorVisitImage WHERE CompanyID=@CompanyID AND VisitorVisitID=@VisitID ORDER BY CreateDate,VisitorVisitImageID;
""", companyId, visitId, token);
        var notes = await ReadRows(connection, """
SELECT VisitorVisitNoteID,NoteStageCode,NoteText,CreateDate,CreateBy
FROM dbo.TDTMVisitorVisitNote WHERE CompanyID=@CompanyID AND VisitorVisitID=@VisitID ORDER BY CreateDate,VisitorVisitNoteID;
""", companyId, visitId, token);
        var notifications = await ReadRows(connection, """
SELECT VisitorNotificationOutboxID,ChannelCode,StatusCode,NotificationID,LastErrorMessage,
       AttemptCount,FirstAttemptDate,CompletedDate,CreateDate
FROM dbo.TDTMVisitorNotificationOutbox
WHERE CompanyID=@CompanyID AND VisitorVisitID=@VisitID
ORDER BY VisitorNotificationOutboxID;
""", companyId, visitId, token);
        return Ok(new { visit = detail, images, notes, notifications });
    }

    [HttpGet("check-ins/{visitId:long}/images/{imageId:long}")]
    public async Task<IActionResult> CheckInImage(long visitId, long imageId, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "VIEW", token) &&
            !await Can(connection, HistoryMenu, "VIEW", token)) return Forbid();
        var contactPoint = await ActiveContactPoint(connection, null, companyId, userId, token);
        if (contactPoint is null) return NotFound(new { message = "No active contact point is assigned to this account." });
        await using var command = new SqlCommand("""
SELECT I.FileRelativePath,I.ContentType
FROM dbo.TDTMVisitorVisitImage I
JOIN dbo.TDTMVisitorVisit V ON V.CompanyID=I.CompanyID AND V.VisitorVisitID=I.VisitorVisitID
WHERE I.CompanyID=@CompanyID AND I.VisitorVisitID=@VisitID AND I.VisitorVisitImageID=@ImageID
  AND V.VisitorContactPointID=@ContactPointID;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@VisitID", SqlDbType.BigInt, visitId);
        Add(command, "@ImageID", SqlDbType.BigInt, imageId); Add(command, "@ContactPointID", SqlDbType.BigInt, contactPoint.Id);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound();
        var root = Path.GetFullPath(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"));
        var file = Path.GetFullPath(Path.Combine(root, reader.GetString(0)));
        if (!IsWithinRoot(root, file) || !System.IO.File.Exists(file)) return NotFound();
        return PhysicalFile(file, reader.GetString(1));
    }

    [HttpPost("check-ins/{visitId:long}/notification/retry")]
    public async Task<IActionResult> RetryNotification(long visitId, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "EDIT", token)) return Forbid();
        var contactPoint = await ActiveContactPoint(connection, null, companyId, userId, token);
        if (contactPoint is null) return Forbid();
        await using var command = new SqlCommand("""
SELECT COUNT_BIG(1) FROM dbo.TDTMVisitorVisit
WHERE CompanyID=@CompanyID AND VisitorVisitID=@VisitID AND VisitorContactPointID=@ContactPointID;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@VisitID", SqlDbType.BigInt, visitId);
        Add(command, "@ContactPointID", SqlDbType.BigInt, contactPoint.Id);
        if (Convert.ToInt64(await command.ExecuteScalarAsync(token)) != 1) return NotFound();
        await QueueHostNotificationAsync(companyId, visitId, userId, token, retryFailed: true);
        return Ok(new { visitorVisitId = visitId, retried = true });
    }

    [HttpPost("check-ins/{visitId:long}/notes")]
    public async Task<IActionResult> AddNote(long visitId, VisitNoteRequest request, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        if (string.IsNullOrWhiteSpace(request.NoteText) || request.NoteText.Trim().Length > 2000)
            return BadRequest(new { message = "กรุณาระบุข้อความไม่เกิน 2,000 ตัวอักษร" });
        var stage = Clean(request.NoteStageCode)?.ToUpperInvariant();
        if (stage is not ("CHECKIN" or "CHECKOUT" or "GENERAL"))
            return BadRequest(new { message = "ประเภทข้อความไม่ถูกต้อง" });
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "EDIT", token)) return Forbid();
        await using var command = new SqlCommand("""
INSERT dbo.TDTMVisitorVisitNote(CompanyID,VisitorVisitID,NoteStageCode,NoteText,CreateBy)
SELECT @CompanyID,VisitorVisitID,@Stage,@Text,@UserID FROM dbo.TDTMVisitorVisit
WHERE CompanyID=@CompanyID AND VisitorVisitID=@VisitID AND StatusCode IN('CHECKED_IN','CHECKED_OUT');
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@VisitID", SqlDbType.BigInt, visitId);
        Add(command, "@Stage", SqlDbType.VarChar, stage, 20); Add(command, "@Text", SqlDbType.NVarChar, request.NoteText.Trim(), 2000);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        return await command.ExecuteNonQueryAsync(token) == 1 ? Ok() : NotFound(new { message = "ไม่พบรายการที่สามารถเพิ่มข้อความได้" });
    }

    [HttpGet("check-ins/{visitId:long}/audit")]
    public async Task<IActionResult> Audit(long visitId, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "VIEW", token)) return Forbid();
        var contactPoint = await ActiveContactPoint(connection, null, companyId, userId, token);
        if (contactPoint is null) return Forbid();
        await using var scope = new SqlCommand("""
SELECT COUNT_BIG(1) FROM dbo.TDTMVisitorVisit
WHERE CompanyID=@CompanyID AND VisitorVisitID=@VisitID AND VisitorContactPointID=@ContactPointID;
""", connection);
        Add(scope, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(scope, "@VisitID", SqlDbType.BigInt, visitId);
        Add(scope, "@ContactPointID", SqlDbType.BigInt, contactPoint.Id);
        if (Convert.ToInt64(await scope.ExecuteScalarAsync(token)) != 1) return NotFound();
        return Ok(new { items = await ReadRows(connection, """
SELECT VisitorVisitAuditID,FromStatusCode,ToStatusCode,OutcomeCode,ReasonCode,NoteText,ActorUserID,ActorNameSnapshot,OccurredDate
FROM dbo.TDTMVisitorVisitAudit WHERE CompanyID=@CompanyID AND VisitorVisitID=@VisitID ORDER BY OccurredDate,VisitorVisitAuditID;
""", companyId, visitId, token) });
    }

    [HttpPost("check-ins")]
    public async Task<IActionResult> CheckIn(
        CheckInRequest request,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var method = Clean(request.CaptureMethod)?.ToUpperInvariant();
        var hostType = Clean(request.HostType)?.ToUpperInvariant();
        var name = Clean(request.VisitorName);
        var phone = Clean(request.Phone);
        var purpose = Clean(request.VisitPurpose);
        var requestId = Clean(request.RequestId);
        if (method is not ("MANUAL_ENTRY" or "CAMERA_CAPTURE"))
            return BadRequest(new { message = "วิธีบันทึกยังไม่เปิดใช้งาน" });
        if (name is null || requestId is null)
            return BadRequest(new { message = "กรุณาระบุชื่อผู้มาติดต่อและ Request ID" });

        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "EDIT", token)) return Forbid();
        var contactPoint = await ActiveContactPoint(connection, null, companyId, userId, token);
        if (contactPoint is null) return Forbid();
        var branch = contactPoint?.BranchId;
        if (branch is null || !await BranchExists(connection, companyId, branch.Value, token))
            return BadRequest(new { message = "สาขาไม่ถูกต้องหรืออยู่นอก Company" });
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(
            IsolationLevel.Serializable, token);
        try
        {
            var settings = await LoadSettings(connection, transaction, companyId,
                ThailandDate(), token);
            if (settings.VersionId is null)
                return Conflict(new { message = "ยังไม่ได้กำหนดค่าระบบ Visitor กรุณาให้ผู้ดูแลบันทึกค่ากลางก่อนทำ Check-in" });
            var businessType = await BusinessType(connection, companyId, token, transaction);
            var validHost = businessType switch
            {
                "DORMITORY" => hostType == "RESIDENT" && request.HostResidentId is not null && request.HostRoomId is not null,
                "RENTAL_OFFICE" => hostType == "RENTAL_OFFICE" && request.HostTenantId is not null && request.HostTenantContactId is not null,
                "VILLAGE" => hostType == "VILLAGE" && request.HostResidentId is not null,
                "COMPANY" => hostType == "EMPLOYEE" && request.HostEmployeeId is not null,
                "SERVICE_CENTER" => hostType == "SERVICE_CUSTOMER" && request.HostServiceCustomerId is not null,
                _ => false,
            };
            if (!validHost)
                return BadRequest(new { message = "ประเภทผู้รับการติดต่อไม่ถูกต้องสำหรับ Company นี้" });
            if (method == "MANUAL_ENTRY" && !settings.AllowManualEntry ||
                method == "CAMERA_CAPTURE" && !settings.AllowCameraCapture)
                return BadRequest(new { message = "วิธีบันทึกนี้ถูกปิดจากกำหนดค่าระบบ Visitor" });
            if (settings.RequireVisitorPhone && phone is null)
                return BadRequest(new { message = "กรุณาระบุเบอร์โทรศัพท์ผู้มาติดต่อ" });
            if (settings.RequireHostEmployee && !validHost)
                return BadRequest(new { message = "กรุณาระบุผู้รับรอง" });
            if (settings.RequireVisitPurpose && purpose is null)
                return BadRequest(new { message = "กรุณาระบุวัตถุประสงค์" });
            if (settings.RequireNationalIdNumber && Clean(request.NationalIdNumber) is null)
                return BadRequest(new { message = "กรุณาระบุเลขบัตรประชาชน" });
            if (settings.RequireNationalIdExpiry && request.NationalIdExpiryDate is null)
                return BadRequest(new { message = "กรุณาระบุวันหมดอายุบัตรประชาชน" });
            var hostSnapshot = hostType is "EMPLOYEE" or "RENTAL_OFFICE" or "VILLAGE"
                ? await LoadSharedHostSnapshot(hostType, request.HostTenantId,
                    request.HostTenantContactId, request.HostResidentId, request.HostEmployeeId, token)
                : await LoadHostSnapshot(connection, transaction, companyId,
                    hostType!, request.HostResidentId, request.HostServiceCustomerId, request.HostRoomId, token);
            if (hostSnapshot is null)
                return BadRequest(new { message = "ไม่พบผู้รับการติดต่อ หรือข้อมูลไม่ Active" });

            if (request.VisitorAppointmentId is not null && !await IsApprovedAppointment(
                    connection, transaction, companyId, request.VisitorAppointmentId.Value,
                    name!, phone, hostType!, request.HostEmployeeId, request.HostResidentId,
                    request.HostServiceCustomerId, request.HostTenantId, request.HostTenantContactId, token))
                return Conflict(new { message = "นัดหมายนี้ใช้ไม่ได้ ถูกใช้แล้ว หรือข้อมูลผู้มาติดต่อไม่ตรงกับนัดหมาย" });

            await using var duplicate = new SqlCommand("""
SELECT VisitorVisitID FROM dbo.TDTMVisitorVisit WITH (UPDLOCK,HOLDLOCK)
WHERE CompanyID=@CompanyID AND RequestId=@RequestId;
""", connection, transaction);
            Add(duplicate, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(duplicate, "@RequestId", SqlDbType.NVarChar, requestId, 100);
            var existing = await duplicate.ExecuteScalarAsync(token);
            if (existing is not null)
            {
                await transaction.RollbackAsync(token);
                return Ok(new { visitorVisitId = Convert.ToInt64(existing), idempotent = true });
            }

            var status = method == "CAMERA_CAPTURE" && settings.RequireCardImage
                ? "PENDING_EVIDENCE" : "CHECKED_IN";
            var nationalId = Clean(request.NationalIdNumber);
            var masked = MaskNationalId(nationalId);
            await using var insert = new SqlCommand("""
INSERT dbo.TDTMVisitorVisit
(CompanyID,BranchID,VisitorName,Phone,NationalIdMasked,NationalIdHash,NationalIdExpiryDate,
 HostType,HostEmployeeID,HostResidentID,HostServiceCustomerID,HostRoomID,HostTenantID,HostTenantContactID,BusinessTypeCodeSnapshot,HostNameSnapshot,HostRoomSnapshot,HostLocationSnapshot,
 ResidentNameSnapshot,BuildingNameSnapshot,FloorNameSnapshot,RoomNameSnapshot,
 VisitorContactPointID,ContactPointNameSnapshot,
 VisitPurpose,CaptureMethod,StatusCode,CheckedInDate,SettingsVersionID,RequestId,SettingsSnapshotJson,CreateBy)
VALUES(@CompanyID,@BranchID,@Name,@Phone,@NationalIdMasked,@NationalIdHash,@Expiry,@HostType,
 @HostEmployeeID,@HostResidentID,@HostServiceCustomerID,@HostRoomID,@HostTenantID,@HostTenantContactID,@BusinessType,@HostName,@HostRoom,@HostLocation,
 @ResidentName,@BuildingName,@FloorName,@RoomName,@ContactPointID,@ContactPointName,@Purpose,@Method,@Status,
 SYSUTCDATETIME(),@SettingsVersionID,@RequestId,@Snapshot,@UserID);
SELECT CONVERT(bigint,SCOPE_IDENTITY());
""", connection, transaction);
            Add(insert, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(insert, "@BranchID", SqlDbType.BigInt, branch);
            Add(insert, "@Name", SqlDbType.NVarChar, name, 200);
            Add(insert, "@Phone", SqlDbType.NVarChar, phone, 50);
            Add(insert, "@NationalIdMasked", SqlDbType.NVarChar, masked, 30);
            Add(insert, "@NationalIdHash", SqlDbType.VarBinary,
                nationalId is null ? null : SHA256.HashData(Encoding.UTF8.GetBytes(nationalId)));
            Add(insert, "@Expiry", SqlDbType.Date,
                request.NationalIdExpiryDate?.ToDateTime(TimeOnly.MinValue));
            Add(insert, "@HostType", SqlDbType.VarChar, hostType, 20);
            Add(insert, "@HostEmployeeID", SqlDbType.BigInt, request.HostEmployeeId);
            Add(insert, "@HostResidentID", SqlDbType.BigInt, request.HostResidentId);
            Add(insert, "@HostServiceCustomerID", SqlDbType.BigInt, request.HostServiceCustomerId);
            Add(insert, "@HostRoomID", SqlDbType.BigInt, request.HostRoomId);
            Add(insert, "@HostTenantID", SqlDbType.BigInt, request.HostTenantId);
            Add(insert, "@HostTenantContactID", SqlDbType.BigInt, request.HostTenantContactId);
            Add(insert, "@BusinessType", SqlDbType.VarChar, businessType, 20);
            Add(insert, "@HostName", SqlDbType.NVarChar, hostSnapshot.Name, 200);
            Add(insert, "@HostRoom", SqlDbType.NVarChar, hostSnapshot.Room, 100);
            Add(insert, "@HostLocation", SqlDbType.NVarChar, hostSnapshot.Room, 500);
            Add(insert, "@ResidentName", SqlDbType.NVarChar, hostSnapshot.ResidentName, 200);
            Add(insert, "@BuildingName", SqlDbType.NVarChar, hostSnapshot.BuildingName, 200);
            Add(insert, "@FloorName", SqlDbType.NVarChar, hostSnapshot.FloorName, 200);
            Add(insert, "@RoomName", SqlDbType.NVarChar, hostSnapshot.RoomName, 200);
            Add(insert, "@ContactPointID", SqlDbType.BigInt, contactPoint!.Id);
            Add(insert, "@ContactPointName", SqlDbType.NVarChar, contactPoint.Name, 200);
            Add(insert, "@Purpose", SqlDbType.NVarChar, purpose, 500);
            Add(insert, "@Method", SqlDbType.VarChar, method, 30);
            Add(insert, "@Status", SqlDbType.VarChar, status, 30);
            Add(insert, "@SettingsVersionID", SqlDbType.BigInt, settings.VersionId);
            Add(insert, "@RequestId", SqlDbType.NVarChar, requestId, 100);
            Add(insert, "@Snapshot", SqlDbType.NVarChar,
                JsonSerializer.Serialize(ToSettingsJson(settings)), -1);
            Add(insert, "@UserID", SqlDbType.BigInt, userId);
            var visitId = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            if (request.VisitorAppointmentId is not null)
            {
                await using var useAppointment = new SqlCommand("""
UPDATE dbo.TDTMVisitorAppointment SET StatusCode='USED',UsedVisitorVisitID=@VisitID,
 UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE CompanyID=@CompanyID AND VisitorAppointmentID=@AppointmentID AND StatusCode='APPROVED';
""", connection, transaction);
                Add(useAppointment, "@VisitID", SqlDbType.BigInt, visitId);
                Add(useAppointment, "@UserID", SqlDbType.BigInt, userId);
                Add(useAppointment, "@CompanyID", SqlDbType.BigInt, companyId);
                Add(useAppointment, "@AppointmentID", SqlDbType.BigInt, request.VisitorAppointmentId.Value);
                if (await useAppointment.ExecuteNonQueryAsync(token) != 1)
                    return Conflict(new { message = "นัดหมายนี้ถูกใช้ไปแล้ว" });
            }
            await using var audit = new SqlCommand("""
INSERT dbo.TDTMVisitorVisitAudit(CompanyID,VisitorVisitID,FromStatusCode,ToStatusCode,ActorUserID,ActorNameSnapshot)
VALUES(@CompanyID,@VisitID,NULL,@Status,@UserID,COALESCE(NULLIF(LTRIM(RTRIM(@ActorName)),N''),CONVERT(nvarchar(30),@UserID)));
""", connection, transaction);
            Add(audit, "@CompanyID", SqlDbType.BigInt, companyId); Add(audit, "@VisitID", SqlDbType.BigInt, visitId);
            Add(audit, "@Status", SqlDbType.VarChar, status, 30); Add(audit, "@UserID", SqlDbType.BigInt, userId);
            Add(audit, "@ActorName", SqlDbType.NVarChar, User.FindFirstValue(ClaimTypes.Name) ?? User.FindFirstValue("name"), 200);
            await audit.ExecuteNonQueryAsync(token);
            await transaction.CommitAsync(token);
            if (status == "CHECKED_IN")
                await QueueHostNotificationAsync(companyId, visitId, userId, token);
            return Ok(new { visitorVisitId = visitId, statusCode = status });
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = "ข้อมูลผู้มาติดต่อรายการนี้ถูกบันทึกแล้ว" });
        }
    }

    [HttpPost("check-ins/{visitId:long}/images")]
    [RequestSizeLimit(2_000_000)]
    public async Task<IActionResult> UploadImage(long visitId, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "EDIT", token)) return Forbid();
        var contactPoint = await ActiveContactPoint(connection, null, companyId, userId, token);
        if (contactPoint is null) return Forbid();
        var form = await Request.ReadFormAsync(token);
        var file = form.Files.GetFile("file");
        var evidenceType = Clean(form["evidenceType"].ToString())?.ToUpperInvariant() ?? "DOCUMENT";
        var captureStage = Clean(form["captureStage"].ToString())?.ToUpperInvariant() ?? "CHECKIN";
        var side = Clean(form["side"].ToString())?.ToUpperInvariant();
        if (file is null || file.Length == 0 || evidenceType is not ("DOCUMENT" or "VEHICLE" or "OTHER") ||
            captureStage is not ("CHECKIN" or "CHECKOUT") ||
            (evidenceType == "DOCUMENT" && side is not ("FRONT" or "BACK")) ||
            (evidenceType != "DOCUMENT" && side is not null))
            return BadRequest(new { message = "กรุณาระบุภาพบัตรและด้าน FRONT หรือ BACK" });
        if (file.Length > 1_000_000 || !new[] { "image/jpeg", "image/png" }.Contains(file.ContentType))
            return BadRequest(new { message = "รองรับเฉพาะภาพ JPG หรือ PNG ขนาดไม่เกิน 10 MB" });

        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(
            IsolationLevel.Serializable, token);
        try
        {
            await using var visit = new SqlCommand("""
SELECT BranchID,VisitorContactPointID,StatusCode FROM dbo.TDTMVisitorVisit WITH (UPDLOCK,HOLDLOCK)
WHERE VisitorVisitID=@VisitID AND CompanyID=@CompanyID;
""", connection, transaction);
            Add(visit, "@VisitID", SqlDbType.BigInt, visitId);
            Add(visit, "@CompanyID", SqlDbType.BigInt, companyId);
            await using var visitReader = await visit.ExecuteReaderAsync(token);
            if (!await visitReader.ReadAsync(token)) return NotFound(new { message = "ไม่พบรายการ Check-in" });
            var branchId = visitReader.GetInt64(0);
            var pointId = visitReader.GetInt64(1);
            var status = visitReader.GetString(2);
            await visitReader.CloseAsync();
            if (branchId != contactPoint.BranchId || pointId != contactPoint.Id) return Forbid();
            if (status is null) return NotFound(new { message = "ไม่พบรายการ Check-in" });

            if (status is not ("CHECKED_IN" or "PENDING_EVIDENCE") || (captureStage == "CHECKOUT" && status != "CHECKED_IN"))
                return BadRequest(new { message = "รายการนี้ไม่อยู่ในสถานะที่แนบหลักฐานได้" });
            var prefix = side?.ToLowerInvariant() ?? evidenceType.ToLowerInvariant();
            var relative = Path.Combine("uploads", "visitor", companyId.ToString(),
                visitId.ToString(), captureStage.ToLowerInvariant(), $"{prefix}-{Guid.NewGuid():N}{Path.GetExtension(file.FileName).ToLowerInvariant()}");
            var absolute = Path.Combine(environment.ContentRootPath, "wwwroot",
                relative.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(absolute)!);
            await using (var stream = System.IO.File.Create(absolute))
                await file.CopyToAsync(stream, token);

            await using var insert = new SqlCommand("""
INSERT dbo.TDTMVisitorVisitImage
 (CompanyID,VisitorVisitID,EvidenceType,CaptureStage,SideCode,FileRelativePath,OriginalFileName,ContentType,ContentLength,CreateBy)
VALUES(@CompanyID,@VisitID,@EvidenceType,@CaptureStage,@Side,@Path,@Original,@ContentType,@Length,@UserID);
""", connection, transaction);
            Add(insert, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(insert, "@VisitID", SqlDbType.BigInt, visitId);
            Add(insert, "@EvidenceType", SqlDbType.VarChar, evidenceType, 20);
            Add(insert, "@CaptureStage", SqlDbType.VarChar, captureStage, 20);
            Add(insert, "@Side", SqlDbType.VarChar, side, 10);
            Add(insert, "@Path", SqlDbType.NVarChar, relative.Replace('\\', '/'), 500);
            Add(insert, "@Original", SqlDbType.NVarChar, file.FileName, 260);
            Add(insert, "@ContentType", SqlDbType.VarChar, file.ContentType, 100);
            Add(insert, "@Length", SqlDbType.BigInt, file.Length);
            Add(insert, "@UserID", SqlDbType.BigInt, userId);
            await insert.ExecuteNonQueryAsync(token);
            await using var finalize = new SqlCommand("""
UPDATE dbo.TDTMVisitorVisit SET StatusCode='CHECKED_IN',UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE VisitorVisitID=@VisitID AND CompanyID=@CompanyID AND StatusCode='PENDING_EVIDENCE';
""", connection, transaction);
            Add(finalize, "@VisitID", SqlDbType.BigInt, visitId);
            Add(finalize, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(finalize, "@UserID", SqlDbType.BigInt, userId);
            await finalize.ExecuteNonQueryAsync(token);
            await transaction.CommitAsync(token);
            if (status == "PENDING_EVIDENCE")
                await QueueHostNotificationAsync(companyId, visitId, userId, token);
            return Ok(new { visitorVisitId = visitId, evidenceType, captureStage, side, statusCode = "CHECKED_IN" });
        }
        catch
        {
            await transaction.RollbackAsync(token);
            throw;
        }
    }

    [HttpPost("check-ins/{visitId:long}/check-out")]
    public async Task<IActionResult> CheckOut(long visitId, CheckOutRequest? request, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        if (User.Identity?.IsAuthenticated == true)
            return await CheckOutWithResult(visitId, companyId, userId,
                request ?? new CheckOutRequest("MET", "NORMAL", null), token);
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "EDIT", token)) return Forbid();
        await using var command = new SqlCommand("""
UPDATE dbo.TDTMVisitorVisit SET StatusCode='CHECKED_OUT',CheckedOutDate=SYSUTCDATETIME(),
UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE VisitorVisitID=@VisitID AND CompanyID=@CompanyID AND StatusCode='CHECKED_IN';
""", connection);
        Add(command, "@VisitID", SqlDbType.BigInt, visitId);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        return await command.ExecuteNonQueryAsync(token) == 1
            ? NoContent()
            : NotFound(new { message = "ไม่พบผู้มาติดต่อที่อยู่ภายใน" });
    }

    private async Task<IActionResult> CheckOutWithResult(long visitId, long companyId, long userId,
        CheckOutRequest request, CancellationToken token)
    {
        var outcome = Clean(request.VisitOutcomeCode)?.ToUpperInvariant();
        var reason = Clean(request.CheckoutReasonCode)?.ToUpperInvariant();
        var note = Clean(request.CheckoutNote);
        if (outcome is not ("MET" or "NOT_MET" or "CANCELLED") ||
            reason is not ("NORMAL" or "HOST_ABSENT" or "VISITOR_LEFT" or "FORGOT_MEETING_CONFIRMATION" or "OTHER"))
            return BadRequest(new { message = "ผลการเข้าพบหรือประเภท Check-out ไม่ถูกต้อง" });
        var validPair = (outcome == "MET" && (reason is "NORMAL" or "FORGOT_MEETING_CONFIRMATION")) ||
                        (outcome == "NOT_MET" && (reason is "HOST_ABSENT" or "VISITOR_LEFT")) || reason == "OTHER";
        if (!validPair || (reason == "OTHER" && string.IsNullOrWhiteSpace(note)))
            return BadRequest(new { message = "ผลการเข้าพบและประเภท Check-out ไม่สัมพันธ์กัน หรือยังไม่กรอกหมายเหตุ" });
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "EDIT", token)) return Forbid();
        var point = await ActiveContactPoint(connection, null, companyId, userId, token);
        if (point is null) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            await using var current = new SqlCommand("""
SELECT BranchID,VisitorContactPointID,StatusCode FROM dbo.TDTMVisitorVisit WITH (UPDLOCK,HOLDLOCK)
WHERE VisitorVisitID=@VisitID AND CompanyID=@CompanyID;
""", connection, transaction);
            Add(current, "@VisitID", SqlDbType.BigInt, visitId); Add(current, "@CompanyID", SqlDbType.BigInt, companyId);
            await using var reader = await current.ExecuteReaderAsync(token);
            if (!await reader.ReadAsync(token)) return NotFound(new { message = "ไม่พบผู้มาติดต่อ" });
            if (reader.GetString(2) != "CHECKED_IN") return Conflict(new { message = "รายการนี้ถูก Check-out แล้วหรือไม่อยู่ภายใน" });
            if (reader.GetInt64(0) != point.BranchId || reader.GetInt64(1) != point.Id) return Forbid();
            await reader.CloseAsync();
            var actorName = User.FindFirstValue(ClaimTypes.Name) ?? User.FindFirstValue("name");
            await using var update = new SqlCommand("""
UPDATE dbo.TDTMVisitorVisit SET StatusCode='CHECKED_OUT',CheckedOutDate=SYSUTCDATETIME(),
VisitOutcomeCode=@Outcome,CheckoutReasonCode=@Reason,CheckoutNote=@Note,
CheckedOutByUserID=@UserID,CheckedOutByNameSnapshot=COALESCE(NULLIF(LTRIM(RTRIM(@ActorName)),N''),CONVERT(nvarchar(30),@UserID)),
ResultRecordedDate=SYSUTCDATETIME(),UpdateDate=SYSUTCDATETIME(),UpdateBy=@UserID
WHERE VisitorVisitID=@VisitID AND CompanyID=@CompanyID AND StatusCode='CHECKED_IN';
""", connection, transaction);
            Add(update, "@VisitID", SqlDbType.BigInt, visitId); Add(update, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(update, "@Outcome", SqlDbType.VarChar, outcome, 20); Add(update, "@Reason", SqlDbType.VarChar, reason, 40);
            Add(update, "@Note", SqlDbType.NVarChar, note, 1000); Add(update, "@UserID", SqlDbType.BigInt, userId);
            Add(update, "@ActorName", SqlDbType.NVarChar, actorName, 200);
            if (await update.ExecuteNonQueryAsync(token) != 1) return Conflict(new { message = "ไม่สามารถ Check-out รายการนี้ซ้ำได้" });
            await using var audit = new SqlCommand("""
INSERT dbo.TDTMVisitorVisitAudit(CompanyID,VisitorVisitID,FromStatusCode,ToStatusCode,OutcomeCode,ReasonCode,NoteText,ActorUserID,ActorNameSnapshot)
VALUES(@CompanyID,@VisitID,'CHECKED_IN','CHECKED_OUT',@Outcome,@Reason,@Note,@UserID,@ActorName);
""", connection, transaction);
            Add(audit, "@CompanyID", SqlDbType.BigInt, companyId); Add(audit, "@VisitID", SqlDbType.BigInt, visitId);
            Add(audit, "@Outcome", SqlDbType.VarChar, outcome, 20); Add(audit, "@Reason", SqlDbType.VarChar, reason, 40);
            Add(audit, "@Note", SqlDbType.NVarChar, note, 1000); Add(audit, "@UserID", SqlDbType.BigInt, userId);
            Add(audit, "@ActorName", SqlDbType.NVarChar, actorName, 200);
            await audit.ExecuteNonQueryAsync(token); await transaction.CommitAsync(token);
            return Ok(new { visitorVisitId = visitId, statusCode = "CHECKED_OUT", outcomeCode = outcome, reasonCode = reason });
        }
        catch { await transaction.RollbackAsync(token); throw; }
    }

    private static async Task<ContactPointContext?> ActiveContactPoint(SqlConnection connection,
        SqlTransaction? transaction, long companyId, long userId, CancellationToken token)
    {
        await using var command = new SqlCommand("""
SELECT TOP(1) P.VisitorContactPointID,P.BranchID,P.ContactPointCode,P.ContactPointName,B.BranchNameTH
FROM dbo.TDADUserEmployee U
JOIN dbo.TDADEmployee E ON E.CompanyID=U.CompanyID AND E.EmployeeID=U.EmployeeID AND E.IsActive=1
JOIN dbo.TDTMVisitorContactPointEmployee A ON A.CompanyID=E.CompanyID AND A.EmployeeID=E.EmployeeID AND A.IsActive=1
JOIN dbo.TDTMVisitorContactPoint P ON P.CompanyID=A.CompanyID AND P.VisitorContactPointID=A.VisitorContactPointID AND P.IsActive=1
JOIN dbo.TDADBranch B ON B.CompanyID=P.CompanyID AND B.BranchID=P.BranchID AND B.IsActive=1
WHERE U.CompanyID=@CompanyID AND U.UserID=@UserID AND U.IsActive=1
ORDER BY P.VisitorContactPointID;
""", connection, transaction);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        await using var reader = await command.ExecuteReaderAsync(token);
        return await reader.ReadAsync(token)
            ? new ContactPointContext(reader.GetInt64(0), reader.GetInt64(1), reader.GetString(2),
                reader.GetString(3), reader.GetString(4))
            : null;
    }

    private async Task QueueHostNotificationAsync(long companyId, long visitId, long actorUserId,
        CancellationToken token, bool retryFailed = false)
    {
        // Notification is deliberately best-effort: a successful check-in must never be rolled back
        // because the recipient has no channel or the notification service is temporarily unavailable.
        try
        {
            await using var connection = await Open(token);
            await using var visit = new SqlCommand("""
SELECT HostType,HostEmployeeID,HostResidentID,HostServiceCustomerID,HostTenantID,HostTenantContactID,
       VisitorName,VisitPurpose,CheckedInDate,ContactPointNameSnapshot,HostNameSnapshot
FROM dbo.TDTMVisitorVisit
WHERE CompanyID=@CompanyID AND VisitorVisitID=@VisitID AND StatusCode='CHECKED_IN';
""", connection);
            Add(visit, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(visit, "@VisitID", SqlDbType.BigInt, visitId);
            await using var reader = await visit.ExecuteReaderAsync(token);
            if (!await reader.ReadAsync(token)) return;
            var hostType = reader.GetString(0);
            var employeeId = Long(reader, 1); var residentId = Long(reader, 2);
            var serviceCustomerId = Long(reader, 3); var tenantId = Long(reader, 4);
            var contactId = Long(reader, 5); var visitorName = reader.GetString(6);
            var purpose = Text(reader, 7); var checkedIn = reader.GetDateTime(8);
            var contactPoint = Text(reader, 9); var hostName = Text(reader, 10);
            await reader.CloseAsync();

            var idempotencyKey = $"VISITOR_CHECKIN:{visitId}:IN_APP";
            var recipient = await ResolveNotificationRecipientAsync(hostType, employeeId, residentId,
                serviceCustomerId, tenantId, contactId, token);
            var payload = JsonSerializer.Serialize(new
            {
                visitorVisitId = visitId,
                visitorName,
                visitPurpose = purpose,
                checkedInDate = checkedIn,
                contactPoint,
                hostName,
                hostType
            });
            var initialStatus = recipient is { CanNotify: true, UserId: not null }
                ? "PENDING" : "NO_CHANNEL";
            var outboxId = await InsertNotificationOutboxAsync(connection, companyId, visitId,
                hostType, recipient?.UserId, recipient?.PersonId, initialStatus, idempotencyKey,
                payload, actorUserId, token);
            if (outboxId is null && retryFailed)
                outboxId = await ResetFailedNotificationOutboxAsync(connection, companyId, idempotencyKey,
                    recipient?.UserId, recipient?.PersonId, actorUserId, token);
            if (outboxId is null || initialStatus == "NO_CHANNEL") return;

            var message = $"มีผู้มาติดต่อรอพบคุณ\n\nผู้มาติดต่อ: {visitorName}\n" +
                $"วัตถุประสงค์: {purpose ?? "-"}\nจุดติดต่อ: {contactPoint ?? "-"}\n" +
                $"เวลาเข้า: {checkedIn.Add(ThailandOffset):HH:mm} น.";
            using var client = new HttpClient();
            using var request = new HttpRequestMessage(HttpMethod.Post,
                $"{Request.Scheme}://{Request.Host}/api/notifications")
            {
                Content = JsonContent.Create(new
                {
                    companyId,
                    recipientUserId = recipient!.UserId,
                    sourceProject = "LAOO_VISITOR",
                    sourceType = "VISITOR_CHECKIN",
                    sourceId = visitId,
                    title = "มีผู้มาติดต่อรอพบคุณ",
                    message,
                    payloadJson = payload,
                    idempotencyKey
                })
            };
            if (Request.Headers.TryGetValue("Authorization", out var authorization))
                request.Headers.TryAddWithoutValidation("Authorization", authorization.ToString());
            using var response = await client.SendAsync(request, token);
            var responseBody = await response.Content.ReadAsStringAsync(token);
            if (!response.IsSuccessStatusCode)
            {
                await UpdateNotificationOutboxAsync(connection, companyId, outboxId.Value, "FAILED",
                    null, responseBody, actorUserId, token);
                return;
            }
            using var document = JsonDocument.Parse(responseBody);
            var root = document.RootElement;
            var notificationId = root.TryGetProperty("notificationId", out var id) && id.TryGetInt64(out var value)
                ? value : (long?)null;
            var status = root.TryGetProperty("status", out var statusValue)
                ? statusValue.GetString()?.ToUpperInvariant() : "SENT";
            await UpdateNotificationOutboxAsync(connection, companyId, outboxId.Value,
                status is "NO_CHANNEL" ? "NO_CHANNEL" : "SENT", notificationId, null, actorUserId, token);
        }
        catch
        {
            // A database/schema or network fault here must not alter the already committed Visit.
        }
    }

    private async Task<NotificationRecipient?> ResolveNotificationRecipientAsync(string hostType,
        long? employeeId, long? residentId, long? serviceCustomerId, long? tenantId, long? contactId,
        CancellationToken token)
    {
        var query = $"hostType={Uri.EscapeDataString(hostType)}" +
            $"&employeeId={employeeId}&residentId={residentId}&serviceCustomerId={serviceCustomerId}" +
            $"&tenantId={tenantId}&contactId={contactId}";
        using var client = new HttpClient();
        using var request = new HttpRequestMessage(HttpMethod.Get,
            $"{Request.Scheme}://{Request.Host}/api/company/host-notification-recipient?{query}");
        if (Request.Headers.TryGetValue("Authorization", out var authorization))
            request.Headers.TryAddWithoutValidation("Authorization", authorization.ToString());
        using var response = await client.SendAsync(request, token);
        if (!response.IsSuccessStatusCode) return null;
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync(token));
        var root = document.RootElement;
        return new NotificationRecipient(
            root.TryGetProperty("personId", out var person) && person.TryGetInt64(out var personId) ? personId : null,
            root.TryGetProperty("userId", out var user) && user.ValueKind != JsonValueKind.Null && user.TryGetInt64(out var userId) ? userId : null,
            root.TryGetProperty("canNotify", out var allowed) && allowed.GetBoolean());
    }

    private static async Task<long?> InsertNotificationOutboxAsync(SqlConnection connection,
        long companyId, long visitId, string hostType, long? userId, long? personId, string status,
        string idempotencyKey, string payload, long actorUserId, CancellationToken token)
    {
        await using var command = new SqlCommand("""
INSERT dbo.TDTMVisitorNotificationOutbox
 (CompanyID,VisitorVisitID,RecipientHostType,RecipientUserID,RecipientPersonID,ChannelCode,StatusCode,IdempotencyKey,PayloadSnapshotJson,CreateBy)
OUTPUT INSERTED.VisitorNotificationOutboxID
VALUES(@CompanyID,@VisitID,@HostType,@UserID,@PersonID,'IN_APP',@Status,@Key,@Payload,@ActorUserID);
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@VisitID", SqlDbType.BigInt, visitId);
        Add(command, "@HostType", SqlDbType.VarChar, hostType, 30); Add(command, "@UserID", SqlDbType.BigInt, userId);
        Add(command, "@PersonID", SqlDbType.BigInt, personId); Add(command, "@Status", SqlDbType.VarChar, status, 20);
        Add(command, "@Key", SqlDbType.NVarChar, idempotencyKey, 200); Add(command, "@Payload", SqlDbType.NVarChar, payload, -1);
        Add(command, "@ActorUserID", SqlDbType.BigInt, actorUserId);
        try { return Convert.ToInt64(await command.ExecuteScalarAsync(token)); }
        catch (SqlException exception) when (exception.Number is 2601 or 2627) { return null; }
    }

    private static async Task UpdateNotificationOutboxAsync(SqlConnection connection, long companyId,
        long outboxId, string status, long? notificationId, string? error, long actorUserId,
        CancellationToken token)
    {
        await using var command = new SqlCommand("""
UPDATE dbo.TDTMVisitorNotificationOutbox
SET StatusCode=@Status,NotificationID=@NotificationID,LastErrorMessage=@Error,
    AttemptCount=AttemptCount+1,FirstAttemptDate=COALESCE(FirstAttemptDate,SYSUTCDATETIME()),
    CompletedDate=CASE WHEN @Status IN('SENT','NO_CHANNEL') THEN SYSUTCDATETIME() END,
    UpdateDate=SYSUTCDATETIME(),UpdateBy=@ActorUserID
WHERE CompanyID=@CompanyID AND VisitorNotificationOutboxID=@OutboxID;
INSERT dbo.TDTMVisitorNotificationOutboxAudit
 (CompanyID,VisitorNotificationOutboxID,FromStatusCode,ToStatusCode,DetailText,ActorUserID)
VALUES(@CompanyID,@OutboxID,'PENDING',@Status,@Error,@ActorUserID);
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@OutboxID", SqlDbType.BigInt, outboxId);
        Add(command, "@Status", SqlDbType.VarChar, status, 20); Add(command, "@NotificationID", SqlDbType.BigInt, notificationId);
        Add(command, "@Error", SqlDbType.NVarChar, error, 2000); Add(command, "@ActorUserID", SqlDbType.BigInt, actorUserId);
        await command.ExecuteNonQueryAsync(token);
    }

    private static async Task<long?> ResetFailedNotificationOutboxAsync(SqlConnection connection,
        long companyId, string idempotencyKey, long? userId, long? personId, long actorUserId,
        CancellationToken token)
    {
        await using var command = new SqlCommand("""
UPDATE dbo.TDTMVisitorNotificationOutbox
SET RecipientUserID=@UserID,RecipientPersonID=@PersonID,StatusCode='PENDING',
    LastErrorMessage=NULL,UpdateDate=SYSUTCDATETIME(),UpdateBy=@ActorUserID
OUTPUT INSERTED.VisitorNotificationOutboxID
WHERE CompanyID=@CompanyID AND IdempotencyKey=@Key AND StatusCode='FAILED';
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@Key", SqlDbType.NVarChar, idempotencyKey, 200);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        Add(command, "@PersonID", SqlDbType.BigInt, personId);
        Add(command, "@ActorUserID", SqlDbType.BigInt, actorUserId);
        var id = await command.ExecuteScalarAsync(token);
        if (id is null) return null;
        var outboxId = Convert.ToInt64(id);
        await using var audit = new SqlCommand("""
INSERT dbo.TDTMVisitorNotificationOutboxAudit
 (CompanyID,VisitorNotificationOutboxID,FromStatusCode,ToStatusCode,DetailText,ActorUserID)
VALUES(@CompanyID,@OutboxID,'FAILED','PENDING',N'ผู้ใช้สั่งลองส่งใหม่',@ActorUserID);
""", connection);
        Add(audit, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(audit, "@OutboxID", SqlDbType.BigInt, outboxId);
        Add(audit, "@ActorUserID", SqlDbType.BigInt, actorUserId);
        await audit.ExecuteNonQueryAsync(token);
        return outboxId;
    }

    private async Task<HostIdentitySet> CurrentHostIdentities(CancellationToken token)
    {
        using var client = new HttpClient();
        using var request = new HttpRequestMessage(HttpMethod.Get,
            $"{Request.Scheme}://{Request.Host}/api/company/current-user/host-identities");
        if (Request.Headers.TryGetValue("Authorization", out var authorization))
            request.Headers.TryAddWithoutValidation("Authorization", authorization.ToString());
        using var response = await client.SendAsync(request, token);
        var body = await response.Content.ReadAsStringAsync(token);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException("ไม่สามารถตรวจสอบสิทธิ์ผู้รับรองได้ กรุณาเข้าสู่ระบบใหม่");
        using var document = JsonDocument.Parse(body);
        static HashSet<long> Values(JsonElement root, string name) => root.TryGetProperty(name, out var array) && array.ValueKind == JsonValueKind.Array
            ? array.EnumerateArray().Where(value => value.TryGetInt64(out _)).Select(value => value.GetInt64()).ToHashSet() : [];
        var root = document.RootElement;
        return new HostIdentitySet(Values(root, "employeeIds"), Values(root, "residentIds"),
            Values(root, "serviceCustomerIds"), Values(root, "tenantContactIds"));
    }

    private static async Task<List<object>> HostPendingRows(SqlConnection connection, long companyId,
        HostIdentitySet identities, CancellationToken token)
    {
        await using var command = new SqlCommand("""
SELECT V.VisitorVisitID,V.VisitorName,V.HostType,V.HostEmployeeID,V.HostResidentID,V.HostServiceCustomerID,V.HostTenantContactID,
       V.HostNameSnapshot,V.ContactPointNameSnapshot,V.VisitPurpose,V.CheckedInDate
FROM dbo.TDTMVisitorVisit V
WHERE V.CompanyID=@CompanyID AND V.StatusCode='CHECKED_IN'
  AND NOT EXISTS(SELECT 1 FROM dbo.TDTMVisitorHostConfirmation C WHERE C.CompanyID=V.CompanyID AND C.VisitorVisitID=V.VisitorVisitID)
ORDER BY V.CheckedInDate,V.VisitorVisitID;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token))
        {
            var hostType = reader.GetString(2); var employee = Long(reader, 3); var resident = Long(reader, 4);
            var customer = Long(reader, 5); var contact = Long(reader, 6);
            if (!identities.Matches(hostType, employee, resident, customer, contact)) continue;
            items.Add(new { visitorVisitId = reader.GetInt64(0), visitorName = reader.GetString(1), hostName = Text(reader, 7),
                contactPointName = Text(reader, 8), visitPurpose = Text(reader, 9), checkedInDate = reader.GetDateTime(10) });
        }
        return items;
    }

    private static async Task<object?> HostVisit(SqlConnection connection, long companyId, long visitId,
        HostIdentitySet identities, CancellationToken token, SqlTransaction? transaction = null)
    {
        await using var command = new SqlCommand("""
SELECT V.VisitorVisitID,V.VisitorName,V.Phone,V.HostType,V.HostEmployeeID,V.HostResidentID,V.HostServiceCustomerID,V.HostTenantContactID,
       V.HostNameSnapshot,V.HostLocationSnapshot,V.ContactPointNameSnapshot,V.VisitPurpose,V.CheckedInDate
FROM dbo.TDTMVisitorVisit V WHERE V.CompanyID=@CompanyID AND V.VisitorVisitID=@VisitID AND V.StatusCode='CHECKED_IN'
  AND NOT EXISTS(SELECT 1 FROM dbo.TDTMVisitorHostConfirmation C WHERE C.CompanyID=V.CompanyID AND C.VisitorVisitID=V.VisitorVisitID);
""", connection, transaction);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId); Add(command, "@VisitID", SqlDbType.BigInt, visitId);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return null;
        var hostType = reader.GetString(3);
        if (!identities.Matches(hostType, Long(reader, 4), Long(reader, 5), Long(reader, 6), Long(reader, 7))) return null;
        return new { visitorVisitId = reader.GetInt64(0), visitorName = reader.GetString(1), phone = Text(reader, 2), hostType,
            hostName = Text(reader, 8), hostLocation = Text(reader, 9), contactPointName = Text(reader, 10),
            visitPurpose = Text(reader, 11), checkedInDate = reader.GetDateTime(12) };
    }

    private async Task<SettingsState> LoadSettings(
        SqlConnection connection, SqlTransaction? transaction, long companyId,
        DateOnly date, CancellationToken token)
    {
        await using var command = new SqlCommand("""
SELECT TOP(1) VisitorSystemSettingVersionID,VersionNo,EffectiveFrom,
 AllowManualEntry,AllowCameraCapture,AllowNationalIdReader,RequireVisitorPhone,
 RequireHostEmployee,RequireVisitPurpose,RequireCardImage,RequireNationalIdNumber,
 RequireNationalIdExpiry,RequireCheckOut,RetentionPolicyCode
FROM dbo.TDTMVisitorSystemSettingVersion
WHERE CompanyID=@CompanyID AND IsActive=1 AND EffectiveFrom<=@Date
  AND (EffectiveTo IS NULL OR EffectiveTo>=@Date)
ORDER BY EffectiveFrom DESC,VersionNo DESC;
""", connection, transaction);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@Date", SqlDbType.Date, date.ToDateTime(TimeOnly.MinValue));
        await using var reader = await command.ExecuteReaderAsync(token);
        if (await reader.ReadAsync(token))
            return new SettingsState(
                reader.GetInt64(0), reader.GetInt32(1), DateOnly.FromDateTime(reader.GetDateTime(2)),
                reader.GetBoolean(3), reader.GetBoolean(4), reader.GetBoolean(5),
                reader.GetBoolean(6), reader.GetBoolean(7), reader.GetBoolean(8),
                reader.GetBoolean(9), reader.GetBoolean(10), reader.GetBoolean(11),
                reader.GetBoolean(12), reader.GetString(13));
        return new SettingsState(null, 0, date, true, true, false, false, true,
            true, true, false, false, true, "COMPANY_POLICY");
    }

    private static object ToSettingsJson(SettingsState state)
    {
        var payload = SettingsPayload(state);
        payload["stateToken"] = StateToken(state);
        return payload;
    }

    private static Dictionary<string, object?> SettingsPayload(SettingsState state) => new()
    {
        ["visitorSystemSettingVersionId"] = state.VersionId,
        ["versionNo"] = state.VersionNo,
        ["effectiveFrom"] = state.EffectiveFrom,
        ["allowManualEntry"] = state.AllowManualEntry,
        ["allowCameraCapture"] = state.AllowCameraCapture,
        ["allowNationalIdReader"] = false,
        ["requireVisitorPhone"] = state.RequireVisitorPhone,
        ["requireHostEmployee"] = state.RequireHostEmployee,
        ["requireVisitPurpose"] = state.RequireVisitPurpose,
        ["requireCardImage"] = state.RequireCardImage,
        ["requireNationalIdNumber"] = state.RequireNationalIdNumber,
        ["requireNationalIdExpiry"] = state.RequireNationalIdExpiry,
        ["requireCheckOut"] = state.RequireCheckOut,
        ["retentionPolicyCode"] = state.RetentionPolicyCode,
    };

    private static string StateToken(SettingsState state) => Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(SettingsPayload(state)))));

    private async Task<bool> Can(SqlConnection connection, string menu, string action, CancellationToken token) =>
        await CompanyMenuAccess.IsAllowedAsync(connection, User, menu, action, token);

    private static async Task<List<Dictionary<string, object?>>> ReadRows(
        SqlConnection connection, string sql, long companyId, long visitId, CancellationToken token)
    {
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@VisitID", SqlDbType.BigInt, visitId);
        await using var reader = await command.ExecuteReaderAsync(token);
        var rows = new List<Dictionary<string, object?>>();
        while (await reader.ReadAsync(token))
        {
            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            for (var i = 0; i < reader.FieldCount; i++)
                row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
            rows.Add(row);
        }
        return rows;
    }

    private async Task<bool> BranchExists(SqlConnection connection, long companyId, long branchId, CancellationToken token)
    {
        await using var command = new SqlCommand(
            "SELECT COUNT_BIG(1) FROM dbo.TDADBranch WHERE CompanyID=@CompanyID AND BranchID=@BranchID AND IsActive=1",
            connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@BranchID", SqlDbType.BigInt, branchId);
        return Convert.ToInt64(await command.ExecuteScalarAsync(token)) > 0;
    }

    private static async Task<bool> IsApprovedAppointment(SqlConnection connection, SqlTransaction transaction,
        long companyId, long appointmentId, string visitorName, string? phone, string hostType,
        long? employeeId, long? residentId, long? serviceCustomerId, long? tenantId, long? tenantContactId,
        CancellationToken token)
    {
        await using var command = new SqlCommand("""
SELECT COUNT_BIG(1)
FROM dbo.TDTMVisitorAppointment WITH (UPDLOCK,HOLDLOCK)
WHERE CompanyID=@CompanyID AND VisitorAppointmentID=@AppointmentID AND StatusCode='APPROVED'
  AND VisitorName=@VisitorName AND (Phone=@Phone OR (Phone IS NULL AND @Phone IS NULL))
  AND HostType=@HostType
  AND (HostEmployeeID=@EmployeeID OR (HostEmployeeID IS NULL AND @EmployeeID IS NULL))
  AND (HostResidentID=@ResidentID OR (HostResidentID IS NULL AND @ResidentID IS NULL))
  AND (HostServiceCustomerID=@ServiceCustomerID OR (HostServiceCustomerID IS NULL AND @ServiceCustomerID IS NULL))
  AND (HostTenantID=@TenantID OR (HostTenantID IS NULL AND @TenantID IS NULL))
  AND (HostTenantContactID=@TenantContactID OR (HostTenantContactID IS NULL AND @TenantContactID IS NULL));
""", connection, transaction);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@AppointmentID", SqlDbType.BigInt, appointmentId);
        Add(command, "@VisitorName", SqlDbType.NVarChar, visitorName, 200);
        Add(command, "@Phone", SqlDbType.NVarChar, phone, 50);
        Add(command, "@HostType", SqlDbType.VarChar, hostType, 20);
        Add(command, "@EmployeeID", SqlDbType.BigInt, employeeId);
        Add(command, "@ResidentID", SqlDbType.BigInt, residentId);
        Add(command, "@ServiceCustomerID", SqlDbType.BigInt, serviceCustomerId);
        Add(command, "@TenantID", SqlDbType.BigInt, tenantId);
        Add(command, "@TenantContactID", SqlDbType.BigInt, tenantContactId);
        return Convert.ToInt64(await command.ExecuteScalarAsync(token)) == 1;
    }

    private static async Task<string> BusinessType(SqlConnection connection, long companyId,
        CancellationToken token, SqlTransaction? transaction = null)
    {
        await using var command = new SqlCommand("""
SELECT ISNULL(NULLIF(UPPER(LTRIM(RTRIM(BusinessTypeCode))),N''),N'COMPANY')
FROM dbo.TDSTCompanySetUp WHERE CompanyID=@CompanyID;
""", connection, transaction);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        var type = Convert.ToString(await command.ExecuteScalarAsync(token))?.Trim().ToUpperInvariant();
        return type is "DORMITORY" or "RENTAL_OFFICE" or "VILLAGE" or "SERVICE_CENTER"
            ? type : "COMPANY";
    }

    private static async Task<bool> IsDormitory(SqlConnection connection, long companyId,
        CancellationToken token, SqlTransaction? transaction = null) =>
        await BusinessType(connection, companyId, token, transaction) == "DORMITORY";

    private async Task<JsonElement> SharedHostRows(string businessType, string? search,
        CancellationToken token)
    {
        var path = $"/api/company/business-locations/hosts?businessTypeCode={Uri.EscapeDataString(businessType)}&search={Uri.EscapeDataString(search ?? string.Empty)}";
        using var client = new HttpClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, $"{Request.Scheme}://{Request.Host}{path}");
        if (Request.Headers.TryGetValue("Authorization", out var authorization))
            request.Headers.TryAddWithoutValidation("Authorization", authorization.ToString());
        using var response = await client.SendAsync(request, token);
        var body = await response.Content.ReadAsStringAsync(token);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(string.IsNullOrWhiteSpace(body)
                ? "Shared Host API request failed." : body);
        using var document = JsonDocument.Parse(body);
        var root = document.RootElement;
        return root.ValueKind == JsonValueKind.Object && root.TryGetProperty("items", out var items)
            ? items.Clone()
            : root.Clone();
    }

    private async Task<HostSnapshot?> LoadSharedHostSnapshot(string hostType, long? tenantId,
        long? contactId, long? residentId, long? employeeId, CancellationToken token)
    {
        var sharedType = hostType == "EMPLOYEE" ? "COMPANY" : hostType;
        var rows = await SharedHostRows(sharedType, null, token);
        foreach (var row in rows.EnumerateArray())
        {
            var tenant = row.TryGetProperty("tenantId", out var tenantValue) ? tenantValue.GetInt64() : (long?)null;
            var contact = row.TryGetProperty("contactId", out var contactValue) && contactValue.ValueKind != JsonValueKind.Null ? contactValue.GetInt64() : (long?)null;
            var resident = row.TryGetProperty("hostId", out var residentValue) ? residentValue.GetInt64() : (long?)null;
            if (hostType == "RENTAL_OFFICE" && tenant == tenantId && contact == contactId)
            {
                var name = row.GetProperty("contactName").GetString() ?? row.GetProperty("displayName").GetString()!;
                var location = string.Join(" / ", new[] { "buildingName", "floorName", "roomCode" }
                    .Select(key => row.TryGetProperty(key, out var value) ? value.GetString() : null)
                    .Where(value => !string.IsNullOrWhiteSpace(value)));
                return new HostSnapshot(name, location, null, null, null, null);
            }
            if (hostType == "VILLAGE" && resident == residentId)
            {
                var name = row.GetProperty("displayName").GetString()!;
                var location = string.Join(" / ", new[] { "laneName", "houseNo" }
                    .Select(key => row.TryGetProperty(key, out var value) ? value.GetString() : null)
                    .Where(value => !string.IsNullOrWhiteSpace(value)));
                return new HostSnapshot(name, location, name, null, null, null);
            }
            if (hostType == "EMPLOYEE" &&
                row.TryGetProperty("employeeId", out var employeeValue) &&
                employeeValue.ValueKind != JsonValueKind.Null && employeeValue.GetInt64() == employeeId)
            {
                var name = row.GetProperty("displayName").GetString()!;
                var branch = row.TryGetProperty("branchName", out var branchValue)
                    ? branchValue.GetString() : null;
                return new HostSnapshot(name, branch, null, null, null, null);
            }
        }
        return null;
    }

    private static async Task<HostSnapshot?> LoadHostSnapshot(SqlConnection connection,
        SqlTransaction transaction, long companyId, string hostType, long? residentId,
        long? serviceCustomerId, long? roomId, CancellationToken token)
    {
        const string residentSql = """
SELECT P.FullName,B.BuildingNameTH,F.FloorNameTH,RM.RoomNameTH,RM.RoomCode
FROM dbo.TDADResident R
JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID AND P.IsActive=1
JOIN dbo.TDADRoom RM ON RM.CompanyID=R.CompanyID AND RM.RoomID=R.RoomID AND RM.IsActive=1
JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID AND B.IsActive=1
JOIN dbo.TDADFloor F ON F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID AND F.IsActive=1
WHERE R.CompanyID=@CompanyID AND R.ResidentID=@ID AND RM.RoomID=@RoomID AND R.IsActive=1
  AND R.StartDate<=CONVERT(date,SYSUTCDATETIME())
  AND (R.EndDate IS NULL OR R.EndDate>=CONVERT(date,SYSUTCDATETIME()));
""";
        const string serviceCustomerSql = """
SELECT P.FullName
FROM dbo.TDADServiceCustomer SC
JOIN dbo.TDADPerson P ON P.CompanyID=SC.CompanyID AND P.PersonID=SC.PersonID AND P.IsActive=1
WHERE SC.CompanyID=@CompanyID AND SC.ServiceCustomerID=@ID AND SC.IsActive=1;
""";
        var isResident = hostType == "RESIDENT";
        await using var command = new SqlCommand(isResident ? residentSql : serviceCustomerSql,
            connection, transaction);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@ID", SqlDbType.BigInt, isResident ? residentId : serviceCustomerId);
        if (isResident) Add(command, "@RoomID", SqlDbType.BigInt, roomId);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return null;
        return isResident
            ? new HostSnapshot(reader.GetString(0), Text(reader, 3) ?? reader.GetString(4), reader.GetString(0), reader.GetString(1), reader.GetString(2), Text(reader, 3) ?? reader.GetString(4))
            : new HostSnapshot(reader.GetString(0), null, null, null, null, null);
    }

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private bool TryScope(out long companyId, out long userId)
    {
        companyId = userId = 0;
        return User.FindFirstValue("user_type") == "COMPANY_USER" &&
            long.TryParse(User.FindFirstValue("company_id"), out companyId) &&
            long.TryParse(User.FindFirstValue("user_id"), out userId) && companyId > 0 && userId > 0;
    }

    private long? ScopedBranch(long? requested)
    {
        return long.TryParse(User.FindFirstValue("branch_id"), out var claimBranch) && claimBranch > 0
            ? claimBranch : requested;
    }

    private static DateOnly ThailandDate() => DateOnly.FromDateTime(DateTime.UtcNow.Add(ThailandOffset));
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static string? Text(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
    private static DateTime? Date(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetDateTime(index);
    private static long? Long(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetInt64(index);
    private static bool IsWithinRoot(string root, string file)
    {
        var relative = Path.GetRelativePath(root, file);
        return relative != ".." &&
            !relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal) &&
            !Path.IsPathRooted(relative);
    }
    private static string? MaskNationalId(string? value) =>
        value is null ? null : new string('*', Math.Max(0, value.Length - 4)) + value[^Math.Min(4, value.Length)..];

    private static void BindSettings(SqlCommand command, SettingsState settings)
    {
        Add(command, "@VersionNo", SqlDbType.Int, settings.VersionNo);
        Add(command, "@EffectiveFrom", SqlDbType.Date, settings.EffectiveFrom.ToDateTime(TimeOnly.MinValue));
        Add(command, "@Manual", SqlDbType.Bit, settings.AllowManualEntry);
        Add(command, "@Camera", SqlDbType.Bit, settings.AllowCameraCapture);
        Add(command, "@Phone", SqlDbType.Bit, settings.RequireVisitorPhone);
        Add(command, "@Host", SqlDbType.Bit, settings.RequireHostEmployee);
        Add(command, "@Purpose", SqlDbType.Bit, settings.RequireVisitPurpose);
        Add(command, "@Image", SqlDbType.Bit, settings.RequireCardImage);
        Add(command, "@IdNo", SqlDbType.Bit, settings.RequireNationalIdNumber);
        Add(command, "@IdExpiry", SqlDbType.Bit, settings.RequireNationalIdExpiry);
        Add(command, "@CheckOut", SqlDbType.Bit, settings.RequireCheckOut);
        Add(command, "@Retention", SqlDbType.VarChar, settings.RetentionPolicyCode, 30);
    }

    private static async Task<string> Caption(SqlConnection connection, string menuCode, CancellationToken token)
    {
        await using var command = new SqlCommand(
            "SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@MenuCode", connection);
        Add(command, "@MenuCode", SqlDbType.Char, menuCode, 5);
        return Convert.ToString(await command.ExecuteScalarAsync(token)) ?? menuCode;
    }

    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0)
    {
        var parameter = size == 0 ? command.Parameters.Add(name, type) : command.Parameters.Add(name, type, size);
        parameter.Value = value ?? DBNull.Value;
    }

    private sealed record SettingsState(
        long? VersionId, int VersionNo, DateOnly EffectiveFrom,
        bool AllowManualEntry, bool AllowCameraCapture, bool AllowNationalIdReader,
        bool RequireVisitorPhone, bool RequireHostEmployee, bool RequireVisitPurpose,
        bool RequireCardImage, bool RequireNationalIdNumber, bool RequireNationalIdExpiry,
        bool RequireCheckOut, string RetentionPolicyCode);

    private sealed record HostSnapshot(
        string Name, string? Room, string? ResidentName, string? BuildingName,
        string? FloorName, string? RoomName);

    private sealed record ContactPointContext(long Id, long BranchId, string Code, string Name,
        string BranchName);

    private sealed record NotificationRecipient(long? PersonId, long? UserId, bool CanNotify);

    private sealed record HostIdentitySet(HashSet<long> EmployeeIds, HashSet<long> ResidentIds,
        HashSet<long> ServiceCustomerIds, HashSet<long> TenantContactIds)
    {
        public bool Matches(string hostType, long? employeeId, long? residentId, long? serviceCustomerId,
            long? tenantContactId) => hostType switch
        {
            "EMPLOYEE" => employeeId is not null && EmployeeIds.Contains(employeeId.Value),
            "RESIDENT" or "VILLAGE" => residentId is not null && ResidentIds.Contains(residentId.Value),
            "SERVICE_CUSTOMER" => serviceCustomerId is not null && ServiceCustomerIds.Contains(serviceCustomerId.Value),
            "RENTAL_OFFICE" => tenantContactId is not null && TenantContactIds.Contains(tenantContactId.Value),
            _ => false,
        };
    }
}
