using System.Data;
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
        string RequestId);

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
            employeeAllowed = false,
            residentAllowed = businessType is "DORMITORY" or "VILLAGE",
            serviceCustomerAllowed = businessType is "COMPANY" or "SERVICE_CENTER",
            defaultHostType = businessType switch
            {
                "DORMITORY" => "RESIDENT",
                "RENTAL_OFFICE" => "RENTAL_OFFICE",
                "VILLAGE" => "VILLAGE",
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
        if (type is not ("RESIDENT" or "SERVICE_CUSTOMER" or "RENTAL_OFFICE" or "VILLAGE") ||
            (businessType == "DORMITORY" && type != "RESIDENT") ||
            (businessType is "COMPANY" or "SERVICE_CENTER" && type != "SERVICE_CUSTOMER") ||
            (businessType == "RENTAL_OFFICE" && type != "RENTAL_OFFICE") ||
            (businessType == "VILLAGE" && type != "VILLAGE"))
            return BadRequest(new { message = "ประเภทผู้รับรองไม่ถูกต้องสำหรับ Company นี้" });
        if (type is "RENTAL_OFFICE" or "VILLAGE")
            return Ok(new { hostType = type, items = await SharedHostRows(type, Clean(search), token) });
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
        if (!TryScope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "VIEW", token)) return Forbid();
        var branch = ScopedBranch(branchId);
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var query = Clean(search) ?? string.Empty;
        await using var command = new SqlCommand("""
SELECT COUNT_BIG(1) OVER(),VisitorVisitID,BranchID,VisitorName,Phone,NationalIdMasked,HostType,
       HostEmployeeID,HostResidentID,HostNameSnapshot,HostRoomSnapshot,
       VisitPurpose,CaptureMethod,CheckedInDate,ContactPointNameSnapshot
FROM dbo.TDTMVisitorVisit
WHERE CompanyID=@CompanyID AND StatusCode='CHECKED_IN'
  AND (@BranchID IS NULL OR BranchID=@BranchID)
  AND (@Search=N'' OR VisitorName LIKE @Like OR Phone LIKE @Like
       OR HostNameSnapshot LIKE @Like OR ContactPointNameSnapshot LIKE @Like)
ORDER BY CheckedInDate DESC,VisitorVisitID DESC
OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@BranchID", SqlDbType.BigInt, branch);
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
        if (!await Can(connection, CheckInMenu, "CREATE", token)) return Forbid();
        var contactPoint = await ActiveContactPoint(connection, null, companyId, userId, token);
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
                _ => hostType == "SERVICE_CUSTOMER" && request.HostServiceCustomerId is not null,
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
            var hostSnapshot = hostType is "RENTAL_OFFICE" or "VILLAGE"
                ? await LoadSharedHostSnapshot(hostType, request.HostTenantId,
                    request.HostTenantContactId, request.HostResidentId, token)
                : await LoadHostSnapshot(connection, transaction, companyId,
                    hostType!, request.HostResidentId, request.HostServiceCustomerId, request.HostRoomId, token);
            if (hostSnapshot is null)
                return BadRequest(new { message = "ไม่พบผู้รับการติดต่อ หรือข้อมูลไม่ Active" });

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
            await transaction.CommitAsync(token);
            return Ok(new { visitorVisitId = visitId, statusCode = status });
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = "ข้อมูลผู้มาติดต่อรายการนี้ถูกบันทึกแล้ว" });
        }
    }

    [HttpPost("check-ins/{visitId:long}/images")]
    [RequestSizeLimit(10_000_000)]
    public async Task<IActionResult> UploadImage(long visitId, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, CheckInMenu, "CREATE", token)) return Forbid();
        var form = await Request.ReadFormAsync(token);
        var file = form.Files.GetFile("file");
        var side = Clean(form["side"].ToString())?.ToUpperInvariant();
        if (file is null || file.Length == 0 || side is not ("FRONT" or "BACK"))
            return BadRequest(new { message = "กรุณาระบุภาพบัตรและด้าน FRONT หรือ BACK" });
        if (file.Length > 10_000_000 || !new[] { "image/jpeg", "image/png" }.Contains(file.ContentType))
            return BadRequest(new { message = "รองรับเฉพาะภาพ JPG หรือ PNG ขนาดไม่เกิน 10 MB" });

        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(
            IsolationLevel.Serializable, token);
        try
        {
            await using var visit = new SqlCommand("""
SELECT StatusCode FROM dbo.TDTMVisitorVisit WITH (UPDLOCK,HOLDLOCK)
WHERE VisitorVisitID=@VisitID AND CompanyID=@CompanyID AND CaptureMethod='CAMERA_CAPTURE';
""", connection, transaction);
            Add(visit, "@VisitID", SqlDbType.BigInt, visitId);
            Add(visit, "@CompanyID", SqlDbType.BigInt, companyId);
            var status = Convert.ToString(await visit.ExecuteScalarAsync(token));
            if (status is null) return NotFound(new { message = "ไม่พบรายการ Check-in" });

            var relative = Path.Combine("uploads", "visitor", companyId.ToString(),
                visitId.ToString(), $"{side.ToLowerInvariant()}-{Guid.NewGuid():N}.jpg");
            var absolute = Path.Combine(environment.ContentRootPath, "wwwroot",
                relative.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(absolute)!);
            await using (var stream = System.IO.File.Create(absolute))
                await file.CopyToAsync(stream, token);

            await using var insert = new SqlCommand("""
INSERT dbo.TDTMVisitorVisitImage
(CompanyID,VisitorVisitID,SideCode,FileRelativePath,OriginalFileName,ContentType,ContentLength,CreateBy)
VALUES(@CompanyID,@VisitID,@Side,@Path,@Original,@ContentType,@Length,@UserID);
""", connection, transaction);
            Add(insert, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(insert, "@VisitID", SqlDbType.BigInt, visitId);
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
            return Ok(new { visitorVisitId = visitId, side, statusCode = "CHECKED_IN" });
        }
        catch
        {
            await transaction.RollbackAsync(token);
            throw;
        }
    }

    [HttpPost("check-ins/{visitId:long}/check-out")]
    public async Task<IActionResult> CheckOut(long visitId, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
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

    private async Task<bool> BranchExists(SqlConnection connection, long companyId, long branchId, CancellationToken token)
    {
        await using var command = new SqlCommand(
            "SELECT COUNT_BIG(1) FROM dbo.TDADBranch WHERE CompanyID=@CompanyID AND BranchID=@BranchID AND IsActive=1",
            connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@BranchID", SqlDbType.BigInt, branchId);
        return Convert.ToInt64(await command.ExecuteScalarAsync(token)) > 0;
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
        return document.RootElement.Clone();
    }

    private async Task<HostSnapshot?> LoadSharedHostSnapshot(string hostType, long? tenantId,
        long? contactId, long? residentId, CancellationToken token)
    {
        var rows = await SharedHostRows(hostType, null, token);
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
    private static long? Long(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetInt64(index);
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
}
