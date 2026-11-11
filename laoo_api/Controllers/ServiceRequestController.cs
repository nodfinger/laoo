using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using LaooApi.Security;
using Laoo.Shared.Contracts.Evaluations;
using InventoryItemProjectAccess = LaooServiceModule.Infrastructure.ItemProjectAccess;
using InventoryWarehouseAccess = LaooServiceModule.Infrastructure.WarehouseAccessService;
using InventoryItemProjectDeniedException = LaooServiceModule.Infrastructure.ItemProjectDeniedException;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using SkiaSharp;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/service/requests")]
public sealed class ServiceRequestController(
    IConfiguration configuration,
    IWebHostEnvironment environment,
    IEvaluationSourceCompletedPublisher evaluationPublisher,
    ILogger<ServiceRequestController> logger) : ControllerBase
{
    private const long MaxAttachmentBytes = 1_048_576;
    private const long MaxIncomingAttachmentBytes = 25_000_000;
    // Display-only: never alter the historical requester snapshot.
    private const string RequesterDisplaySql = """
CASE WHEN R.RequesterType=N'EMPLOYEE' THEN COALESCE((
    SELECT TOP (1) CASE COALESCE(S.EmployeeNameDisplay,'FULL')
      WHEN 'NICK' THEN COALESCE(NULLIF(LTRIM(RTRIM(Emp.NickName)),N''),R.RequesterNameSnapshot)
      WHEN 'BOTH' THEN CASE WHEN NULLIF(LTRIM(RTRIM(Emp.NickName)),N'') IS NULL THEN R.RequesterNameSnapshot ELSE CONCAT(R.RequesterNameSnapshot,N' (',LTRIM(RTRIM(Emp.NickName)),N')') END
      ELSE R.RequesterNameSnapshot END
    FROM dbo.TDADEmployee Emp
    LEFT JOIN dbo.TDSTCompanySetUp S ON S.CompanyID=R.CompanyID AND S.OwnerType='C'
    WHERE Emp.CompanyID=R.CompanyID AND Emp.PersonID=R.RequesterID
    ORDER BY Emp.EmployeeID
),R.RequesterNameSnapshot) ELSE R.RequesterNameSnapshot END
""";
    private const string AssignedDisplaySql = """
COALESCE((SELECT TOP (1) CASE COALESCE(S.EmployeeNameDisplay,'FULL')
    WHEN 'NICK' THEN COALESCE(NULLIF(LTRIM(RTRIM(Emp.NickName)),N''),R.AssignedEmployeeNameSnapshot)
    WHEN 'BOTH' THEN CASE WHEN NULLIF(LTRIM(RTRIM(Emp.NickName)),N'') IS NULL THEN R.AssignedEmployeeNameSnapshot ELSE CONCAT(R.AssignedEmployeeNameSnapshot,N' (',LTRIM(RTRIM(Emp.NickName)),N')') END
    ELSE R.AssignedEmployeeNameSnapshot END
    FROM dbo.TDADEmployee Emp LEFT JOIN dbo.TDSTCompanySetUp S ON S.CompanyID=R.CompanyID AND S.OwnerType='C'
    WHERE Emp.CompanyID=R.CompanyID AND Emp.EmployeeID=R.AssignedEmployeeID),R.AssignedEmployeeNameSnapshot)
""";
    private long CompanyId => ClaimLong("company_id");
    private long UserId => ClaimLong("user_id");
    private long? PersonId => ClaimLongNullable("person_id");

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        var screenType = await ScreenType(c, "15001", token);
        var selfScreenType = await ScreenType(c, "20001", token);
        return Ok(new
        {
            screenType,
            selfScreenType,
            view = await Allowed(c, "15001", "VIEW", token),
            create = screenType == 1 && await Allowed(c, "15001", "CREATE", token),
            edit = screenType == 1 && await Allowed(c, "15001", "EDIT", token),
            delete = screenType == 1 && await Allowed(c, "15001", "DELETE", token),
            selfCreate = selfScreenType == 1 && await Allowed(c, "20001", "CREATE", token),
            selfEdit = selfScreenType == 1 && await Allowed(c, "20001", "EDIT", token),
            selfDelete = selfScreenType == 1 && await Allowed(c, "20001", "DELETE", token),
            dispatchEdit = await ScreenType(c, "17001", token) == 2 && await Allowed(c, "17001", "EDIT", token),
            workOrderEdit = await ScreenType(c, "17002", token) == 2 && await Allowed(c, "17002", "EDIT", token)
        });
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup([FromQuery] string? search, [FromQuery] bool self, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token) ||
            (self
                ? await ScreenType(c, "20001", token) != 1 || !await Allowed(c, "20001", "CREATE", token)
                : !await Allowed(c, "15001", "VIEW", token))) return Forbid();
        var type = await BusinessType(c, token);
        var rows = new List<object>();
        var q = search?.Trim() ?? string.Empty;

        if (!self && type == CompanyBusinessType.Dormitory)
        {
            const string sql = """
SELECT R.ResidentID id,N'RESIDENT' requesterType,P.FullName name,P.Mobile phone,P.Email email,
       CONCAT(B.BuildingNameTH,N' / ',F.FloorNameTH,N' / ',RM.RoomCode) locationSnapshot
FROM dbo.TDADResident R JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID
JOIN dbo.TDADRoom RM ON RM.CompanyID=R.CompanyID AND RM.RoomID=R.RoomID
JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID
JOIN dbo.TDADFloor F ON F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID
WHERE R.CompanyID=@company AND R.RoomID IS NOT NULL AND R.IsActive=1 AND P.IsActive=1 AND RM.IsActive=1
AND (@q=N'' OR P.FullName LIKE N'%'+@q+N'%' OR RM.RoomCode LIKE N'%'+@q+N'%') ORDER BY P.FullName;
""";
            rows.AddRange(await ReadRequesterRows(new SqlCommand(sql, c), q, token));
        }
        else if (!self && type == CompanyBusinessType.RentalOffice)
        {
            const string sql = """
SELECT C.TenantContactID id,N'TENANT_CONTACT' requesterType,C.ContactName name,C.Phone phone,C.Email email,
       CONCAT(T.TenantCompanyName,N' / ',B.BuildingNameTH,N' / ',F.FloorNameTH,N' / ',RM.RoomCode) locationSnapshot
FROM dbo.TDADRentalOfficeTenantContact C JOIN dbo.TDADRentalOfficeTenant T ON T.CompanyID=C.CompanyID AND T.TenantID=C.TenantID
JOIN dbo.TDADRoom RM ON RM.CompanyID=T.CompanyID AND RM.RoomID=T.RoomID
JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID
JOIN dbo.TDADFloor F ON F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID
WHERE C.CompanyID=@company AND C.IsActive=1 AND T.IsActive=1 AND RM.IsActive=1
AND (@q=N'' OR C.ContactName LIKE N'%'+@q+N'%' OR T.TenantCompanyName LIKE N'%'+@q+N'%') ORDER BY C.ContactName;
""";
            rows.AddRange(await ReadRequesterRows(new SqlCommand(sql, c), q, token));
        }
        else if (!self && type == CompanyBusinessType.Village)
        {
            const string sql = """
SELECT R.ResidentID id,N'RESIDENT' requesterType,P.FullName name,P.Mobile phone,P.Email email,
       CONCAT(L.LaneName,N' / ',H.HouseNo) locationSnapshot
FROM dbo.TDADResident R JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID
JOIN dbo.TDADVillageHouse H ON H.CompanyID=R.CompanyID AND H.HouseID=R.HouseID
JOIN dbo.TDADVillageLane L ON L.CompanyID=H.CompanyID AND L.LaneID=H.LaneID
WHERE R.CompanyID=@company AND R.HouseID IS NOT NULL AND R.IsActive=1 AND P.IsActive=1 AND H.IsActive=1
AND (@q=N'' OR P.FullName LIKE N'%'+@q+N'%' OR H.HouseNo LIKE N'%'+@q+N'%' OR L.LaneName LIKE N'%'+@q+N'%') ORDER BY P.FullName;
""";
            rows.AddRange(await ReadRequesterRows(new SqlCommand(sql, c), q, token));
        }

        const string customerSql = """
SELECT TOP(100) P.PersonID id,N'SERVICE_CUSTOMER' requesterType,P.FullName name,P.Mobile phone,P.Email email,
       NULL locationSnapshot
FROM dbo.TDADServiceCustomer S JOIN dbo.TDADPerson P ON P.CompanyID=S.CompanyID AND P.PersonID=S.PersonID
WHERE S.CompanyID=@company AND S.IsActive=1 AND P.IsActive=1
AND (@q=N'' OR P.FullName LIKE N'%'+@q+N'%' OR P.Mobile LIKE N'%'+@q+N'%') ORDER BY P.FullName;
""";
        if (!self && type is CompanyBusinessType.Company or CompanyBusinessType.ServiceCenter)
        {
            const string employeeSql = "SELECT TOP(100) P.PersonID id,N'EMPLOYEE' requesterType,P.FullName name,P.Mobile phone,P.Email email,CONCAT(ISNULL(DV.NameTH,N'-'),N' / ',ISNULL(DP.NameTH,N'-')) locationSnapshot,E.NickName FROM dbo.TDADEmployee E JOIN dbo.TDADPerson P ON P.CompanyID=E.CompanyID AND P.PersonID=E.PersonID LEFT JOIN dbo.TDADOrganizationUnit DV ON DV.OrgUnitID=E.DivisionOrgUnitID AND DV.CompanyID=E.CompanyID LEFT JOIN dbo.TDADOrganizationUnit DP ON DP.OrgUnitID=E.DepartmentOrgUnitID AND DP.CompanyID=E.CompanyID WHERE E.CompanyID=@company AND E.IsActive=1 AND P.IsActive=1 AND (@q=N'' OR P.FullName LIKE N'%'+@q+N'%' OR E.NickName LIKE N'%'+@q+N'%' OR E.EmployeeCode LIKE N'%'+@q+N'%' OR DP.NameTH LIKE N'%'+@q+N'%') ORDER BY P.FullName";
            rows.AddRange(await ReadRequesterRows(new SqlCommand(employeeSql, c), q, token));
        }
        if (!self) rows.AddRange(await ReadRequesterRows(new SqlCommand(customerSql, c), q, token));
        var equipment = new List<object>();
        const string equipmentSql = "SELECT TOP(100) I.ItemID,I.ItemCode,I.ItemName FROM dbo.TDIVItem I JOIN dbo.TDIVItemUsage U ON U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode=N'EQUIPMENT' WHERE I.CompanyID=@company AND I.IsActive=1 ORDER BY I.ItemCode";
        await using (var equipmentCommand = new SqlCommand(equipmentSql, c))
        {
            Add(equipmentCommand, "@company", SqlDbType.BigInt, CompanyId);
            await using var er = await equipmentCommand.ExecuteReaderAsync(token);
            while (await er.ReadAsync(token)) equipment.Add(new { itemID = er.GetInt64(0), itemCode = er.GetString(1), itemName = er.GetString(2) });
        }
        var subjects = new List<object>();
        const string subjectSql = """
SELECT SubjectCode,Name,NULLIF(ShortCode,N'') ShortCode
FROM dbo.TDADServiceRequestSubject
WHERE IsActive=1
  AND OwnerType=N'C' AND OwnerCompanyID=@company
ORDER BY Seq,Name,SubjectCode;
""";
        await using (var subjectCommand = new SqlCommand(subjectSql, c))
        {
            Add(subjectCommand, "@company", SqlDbType.BigInt, CompanyId);
            await using var sr = await subjectCommand.ExecuteReaderAsync(token);
            while (await sr.ReadAsync(token))
                subjects.Add(new { code = sr.GetString(0), name = sr.GetString(1), shortCode = Text(sr, 2) });
        }
        var priorities = new List<object>();
        await using (var priorityCommand = new SqlCommand("SELECT Code,Name FROM dbo.TDSTMasterCont WHERE GroupCode=@group ORDER BY Seq,Code", c))
        {
            Add(priorityCommand, "@group", SqlDbType.NVarChar, MasterConstCodes.ServiceRequestPriority, 10);
            await using var reader = await priorityCommand.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token)) priorities.Add(new { code = reader.GetString(0), name = reader.GetString(1) });
        }
        var settings = await ReadSettings(c, token);
        return Ok(new { businessTypeCode = type, requesters = rows, equipment, subjects, priorities, requireEquipment = settings.RequireEquipment, attachmentRequired = settings.AttachmentRequired });
    }

    [HttpGet("equipment-options")]
    public async Task<IActionResult> EquipmentOptions([FromQuery] bool self, [FromQuery] string? search, CancellationToken token)
    {
        await using var c = await Open(token);
        var menu = self ? "20001" : "15001";
        if (!await InService(c, token) || !await Allowed(c, menu, "VIEW", token)) return Forbid();
        const string sql = "SELECT TOP(100) I.ItemID,I.ItemCode,I.ItemName FROM dbo.TDIVItem I JOIN dbo.TDIVItemUsage U ON U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode=N'EQUIPMENT' WHERE I.CompanyID=@company AND I.IsActive=1 AND (@search=N'' OR I.ItemCode LIKE N'%'+@search+N'%' OR I.ItemName LIKE N'%'+@search+N'%') ORDER BY I.ItemCode";
        await using var q = new SqlCommand(sql, c);
        Add(q, "@company", SqlDbType.BigInt, CompanyId);
        Add(q, "@search", SqlDbType.NVarChar, search?.Trim() ?? string.Empty, 200);
        var items = new List<object>();
        await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) items.Add(new { itemID = r.GetInt64(0), itemCode = r.GetString(1), itemName = r.GetString(2) });
        return Ok(items);
    }

    [HttpGet("subject-options")]
    public async Task<IActionResult> SubjectOptions([FromQuery] bool self, CancellationToken token)
    {
        await using var c = await Open(token);
        var menu = self ? "20001" : "15001";
        if (!await InService(c, token) || !await Allowed(c, menu, "VIEW", token)) return Forbid();
        var items = new List<object>();
        await using var q = new SqlCommand("SELECT SubjectCode,Name,NULLIF(ShortCode,N'') FROM dbo.TDADServiceRequestSubject WHERE IsActive=1 AND OwnerType=N'C' AND OwnerCompanyID=@company ORDER BY Seq,Name,SubjectCode", c);
        Add(q, "@company", SqlDbType.BigInt, CompanyId);
        await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) items.Add(new { code = r.GetString(0), name = r.GetString(1), shortCode = Text(r, 2) });
        return Ok(items);
    }

    [HttpGet("priority-options")]
    public async Task<IActionResult> PriorityOptions(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token) || !(await Allowed(c, "20001", "VIEW", token) || await Allowed(c, "15001", "VIEW", token))) return Forbid();
        var items = new List<object>();
        await using var q = new SqlCommand("SELECT Code,Name FROM dbo.TDSTMasterCont WHERE GroupCode=@group ORDER BY Seq,Code", c);
        Add(q, "@group", SqlDbType.NVarChar, MasterConstCodes.ServiceRequestPriority, 10);
        await using var reader = await q.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token)) items.Add(new { code = reader.GetString(0), name = reader.GetString(1) });
        return Ok(items);
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? status, [FromQuery] bool self = false, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, [FromQuery] string? menuCode = null, CancellationToken token = default, [FromQuery] bool? queueJump = null, [FromQuery] string? priority = null, [FromQuery] bool strictOwn = false)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        if (queueJump.HasValue && menuCode != "17001") return Forbid();
        if (!string.IsNullOrEmpty(priority) && priority is not ("0" or "1" or "2")) return BadRequest(new { message = "Invalid priority" });
        if (menuCode is not null)
        {
            if (menuCode is not ("15001" or "17001" or "17002" or "20001" or "20002" or "20003"))
                return BadRequest(new { message = "เมนูรายการใบแจ้งซ่อมไม่ถูกต้อง" });
            var expectedType = menuCode is "17001" or "17002" ? 2 : menuCode is "20002" or "20003" ? 3 : 1;
            if (await ScreenType(c, menuCode, token) != expectedType ||
                !await Allowed(c, menuCode, "VIEW", token)) return Forbid();
            self = menuCode is "20001" or "20002" or "20003";
            if (menuCode == "17001") status = "NEW";
            if (menuCode == "20003") status = "COMPLETED";
        }
        else
        {
            var canManage = await Allowed(c, "15001", "VIEW", token);
            var canSelfView = await Allowed(c, "20001", "VIEW", token);
            if (self ? !canManage && !canSelfView : !canManage) return Forbid();
        }
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        var canViewSerial = await Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedForProjectAsync(c, User, "LAOO_STOCK", "08006", "VIEW", token);
        var useMenuScope = menuCode == "20001" || (menuCode is null && self);
        var selfView = useMenuScope ? MenuViewPredicate : SelfViewPredicate;
        var selfEdit = useMenuScope ? MenuEditPredicate : SelfEditPredicate;
        var selfDelete = useMenuScope ? MenuDeletePredicate : SelfDeletePredicate;
        var sql = $$"""
SELECT COUNT_BIG(1) OVER(),RequestID,RequestNo,RequesterType,{{RequesterDisplaySql}},LocationSnapshot,
       EquipmentNameSnapshot,Subject,StatusCode,{{AssignedDisplaySql}},ReceivedDate,StartedDate,RequestDate,RowVersion,
       CAST(CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADServiceRequestAttachment A
            WHERE A.CompanyID=R.CompanyID AND A.RequestID=R.RequestID AND A.IsActive=1
              AND A.ContentType LIKE N'image/%') THEN 1 ELSE 0 END AS bit) AS HasImages,
       R.PriorityCode, (SELECT TOP(1) C.Name FROM dbo.TDSTMasterCont C WHERE C.GroupCode=N'006' AND C.Code=R.PriorityCode ORDER BY C.Seq) AS PriorityName, R.IsQueueJump,
       CAST(CASE WHEN {{selfEdit}} THEN 1 ELSE 0 END AS bit), CAST(CASE WHEN {{selfDelete}} THEN 1 ELSE 0 END AS bit), E.SerialNo
FROM dbo.TDADServiceRequest R
OUTER APPLY (
    SELECT X.SerialNo FROM dbo.TDIVItemInstance X
    JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID
    LEFT JOIN dbo.TDIVWarehouse W ON W.WarehouseID=X.WarehouseID AND W.CompanyID=X.CompanyID
    LEFT JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1
    WHERE @canSerial=1 AND X.CompanyID=R.CompanyID AND X.ItemInstanceID=R.EquipmentInstanceID
      AND X.ItemID=R.EquipmentItemID
      AND (X.WarehouseID IS NULL OR {{InventoryWarehouseAccess.WarehouseAliasPredicate}})
) E
WHERE R.CompanyID=@company AND R.IsActive=1
  AND (@self=0 OR {{selfView}})
  AND (@strictOwn=0 OR R.CreateBy=@user)
  AND (@queueJump IS NULL OR R.IsQueueJump=@queueJump)
  AND (@priority IS NULL OR R.PriorityCode=@priority)
  AND (@status IN(N'',N'ALL')
       OR (@status=N'OPEN' AND StatusCode IN(N'RECEIVED',N'IN_PROGRESS'))
       OR (@status NOT IN(N'',N'ALL',N'OPEN') AND StatusCode=@status))
  AND (@q=N'' OR R.RequestNo LIKE N'%'+@q+N'%' OR R.RequesterNameSnapshot LIKE N'%'+@q+N'%' OR R.Subject LIKE N'%'+@q+N'%' OR R.LocationSnapshot LIKE N'%'+@q+N'%' OR R.EquipmentNameSnapshot LIKE N'%'+@q+N'%' OR R.EquipmentCodeSnapshot LIKE N'%'+@q+N'%' OR E.SerialNo LIKE N'%'+@q+N'%')
ORDER BY RequestDate DESC,RequestID DESC OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId);
        Add(cmd, "@self", SqlDbType.Bit, self); Add(cmd, "@user", SqlDbType.BigInt, UserId);
        Add(cmd, "@canSerial", SqlDbType.Bit, canViewSerial);
        Add(cmd, "@strictOwn", SqlDbType.Bit, strictOwn);
        Add(cmd, "@queueJump", SqlDbType.Bit, queueJump);
        Add(cmd, "@priority", SqlDbType.NVarChar, string.IsNullOrEmpty(priority) ? null : priority, 1);
        Add(cmd, "@status", SqlDbType.NVarChar, status?.Trim() ?? string.Empty, 30);
        Add(cmd, "@q", SqlDbType.NVarChar, search?.Trim() ?? string.Empty, 200);
        Add(cmd, "@offset", SqlDbType.Int, (page - 1) * pageSize);
        Add(cmd, "@take", SqlDbType.Int, pageSize);
        var items = new List<object>(); long total = 0;
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
        {
            total = r.GetInt64(0);
            var item = new Dictionary<string, object?>
            {
                ["requestId"] = r.GetInt64(1), ["requestNo"] = r.GetString(2),
                ["requesterType"] = r.GetString(3), ["requesterName"] = r.GetString(4),
                ["locationSnapshot"] = Text(r, 5), ["equipmentName"] = Text(r, 6), ["equipmentSerial"] = Text(r, 20),
                ["subject"] = r.GetString(7), ["statusCode"] = r.GetString(8),
                ["assignedEmployeeName"] = Text(r, 9), ["receivedDate"] = DateTimeValue(r, 10),
                ["startedDate"] = DateTimeValue(r, 11), ["requestDate"] = r.GetDateTime(12),
                ["rowVersion"] = Convert.ToBase64String((byte[])r[13]),
                ["hasImages"] = r.GetBoolean(14), ["priorityCode"] = r.GetString(15), ["priorityName"] = Text(r, 16)
            };
            if (menuCode == "17001") item["isQueueJump"] = r.GetBoolean(17);
            if (self) { item["selfCanEdit"] = r.GetBoolean(18); item["selfCanDelete"] = r.GetBoolean(19); }
            items.Add(item);
        }
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("assistant/self")]
    public async Task<IActionResult> AssistantOwnRequests(CancellationToken token)
    {
        await using var db = await Open(token);
        if (!await LaooApi.Services.Assistant.AssistantCapabilityAccess.IsAllowed(db, User, "repair.track_own", token)) return Forbid();
        return await List(null, null, true, 1, 20, "20002", token, strictOwn: true);
    }

    [HttpGet("assistant/pending")]
    public async Task<IActionResult> AssistantPendingRequests(CancellationToken token)
    {
        await using var db = await Open(token);
        if (!await LaooApi.Services.Assistant.AssistantCapabilityAccess.IsAllowed(db, User, "repair.pending", token)) return Forbid();
        // Reuse the dispatch screen's company scope, permission and NEW status checks.
        return await List(null, null, false, 1, 20, "17001", token);
    }

    [HttpGet("assistant/parts-cost")]
    public async Task<IActionResult> AssistantPartsCost([FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken token)
    {
        if ((from.HasValue && from.Value.TimeOfDay != TimeSpan.Zero) ||
            (to.HasValue && to.Value.TimeOfDay != TimeSpan.Zero) ||
            (from.HasValue && to.HasValue && from.Value.Date > to.Value.Date) ||
            (to.HasValue && to.Value.Date == DateTime.MaxValue.Date))
            return BadRequest(new { message = "ช่วงวันที่ไม่ถูกต้อง" });
        await using var db = await Open(token);
        if (!await InService(db, token) || !await LaooApi.Services.Assistant.AssistantCapabilityAccess.IsAllowed(db, User, "repair.parts_cost", token)) return Forbid();
        var companyScope = await ScreenType(db, "19002", token) == 3 && await Allowed(db, "19002", "VIEW", token);
        var sql = $$"""
SELECT COUNT_BIG(*), COALESCE(SUM(P.PartsTotal), 0)
FROM dbo.TDADServiceRequest R
OUTER APPLY (SELECT COALESCE(SUM(TotalCost),0) PartsTotal FROM dbo.TDADServiceRequestPart P
 WHERE P.CompanyID=R.CompanyID AND P.RequestID=R.RequestID AND P.IsActive=1) P
WHERE R.CompanyID=@company AND R.IsActive=1 AND R.StatusCode=N'COMPLETED'
  AND (@companyScope=1 OR {{SelfViewPredicate}})
  AND (@from IS NULL OR R.CompletedDate>=@from)
  AND (@until IS NULL OR R.CompletedDate<@until)
""";
        await using var command = new SqlCommand(sql, db);
        Add(command, "@company", SqlDbType.BigInt, CompanyId);
        Add(command, "@user", SqlDbType.BigInt, UserId);
        Add(command, "@companyScope", SqlDbType.Bit, companyScope);
        Add(command, "@from", SqlDbType.DateTime2, from?.Date);
        Add(command, "@until", SqlDbType.DateTime2, to?.Date.AddDays(1));
        await using var reader = await command.ExecuteReaderAsync(token);
        await reader.ReadAsync(token);
        return Ok(new { count = reader.GetInt64(0), partsTotal = reader.GetDecimal(1),
            scope = companyScope ? "company" : "self", from, to,
            description = "ต้นทุนอะไหล่ของงานที่เสร็จ ไม่รวมค่าแรงและค่าบริการอื่น" });
    }

    [HttpGet("assistant/serial-history")]
    public async Task<IActionResult> AssistantSerialHistory([FromQuery] string? serial, CancellationToken token)
    {
        serial = serial?.Trim();
        if (string.IsNullOrWhiteSpace(serial) || serial.Length > 200) return BadRequest(new { message = "กรุณาระบุ Serial ที่ถูกต้อง" });
        await using var db = await Open(token);
        if (!await InService(db, token) || !await LaooApi.Services.Assistant.AssistantCapabilityAccess.IsAllowed(db, User, "repair.serial_history", token)) return Forbid();
        var companyScope = await ScreenType(db, "19002", token) == 3 && await Allowed(db, "19002", "VIEW", token);
        var selfTracking = await ScreenType(db, "20002", token) == 3 && await Allowed(db, "20002", "VIEW", token);
        var selfHistory = await ScreenType(db, "20003", token) == 3 && await Allowed(db, "20003", "VIEW", token);
        var sql = $$"""
SELECT TOP (20) R.RequestNo,R.Subject,R.StatusCode,R.CompletedDate
FROM dbo.TDADServiceRequest R
WHERE R.CompanyID=@company AND R.IsActive=1
 AND EXISTS (SELECT 1 FROM dbo.TDIVItemInstance X WHERE X.CompanyID=R.CompanyID
             AND X.ItemInstanceID=R.EquipmentInstanceID AND X.ItemID=R.EquipmentItemID AND X.SerialNo=@serial)
 AND ((@companyScope=1 AND R.StatusCode=N'COMPLETED') OR (@selfTracking=1 AND {{SelfViewPredicate}})
      OR (@selfHistory=1 AND R.StatusCode=N'COMPLETED' AND {{SelfViewPredicate}}))
ORDER BY R.RequestDate DESC,R.RequestID DESC
""";
        await using var q = new SqlCommand(sql, db);
        Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@serial", SqlDbType.NVarChar, serial, 200);
        Add(q, "@user", SqlDbType.BigInt, UserId); Add(q, "@companyScope", SqlDbType.Bit, companyScope);
        Add(q, "@selfTracking", SqlDbType.Bit, selfTracking); Add(q, "@selfHistory", SqlDbType.Bit, selfHistory);
        var items = new List<object>();
        await using var reader = await q.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token)) items.Add(new { requestNo = reader.GetString(0), subject = reader.GetString(1), statusCode = reader.GetString(2), completedDate = DateTimeValue(reader, 3) });
        return Ok(new { items });
    }

    [HttpGet("assistant/created/{id:long}")]
    public async Task<IActionResult> AssistantCreatedRequest(long id, CancellationToken token)
    {
        await using var db = await Open(token);
        if (!await InService(db, token) || !await LaooApi.Services.Assistant.AssistantCapabilityAccess.IsAllowed(db, User, "repair.create_own", token)) return Forbid();
        await using var query = new SqlCommand("SELECT RequestNo,Subject,Detail,StatusCode FROM dbo.TDADServiceRequest WHERE CompanyID=@company AND RequestID=@id AND CreateBy=@user AND RequestChannelCode=N'2' AND IsActive=1", db);
        Add(query, "@company", SqlDbType.BigInt, CompanyId); Add(query, "@id", SqlDbType.BigInt, id); Add(query, "@user", SqlDbType.BigInt, UserId);
        await using var reader = await query.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound();
        return Ok(new { requestNo=reader.GetString(0), subject=reader.GetString(1), detail=reader.GetString(2), statusCode=reader.GetString(3) });
    }

    public sealed record AssistantEmailRequest(string? Email, DateTime? From, DateTime? To, bool Confirmed, string? CapabilityCode = null, long? RequestId = null);

    [HttpPost("assistant/parts-cost/email")]
    [HttpPost("assistant/report/email")]
    public async Task<IActionResult> AssistantEmailPartsCost(AssistantEmailRequest request, CancellationToken token)
    {
        if (!request.Confirmed || string.IsNullOrWhiteSpace(request.Email) || request.Email.Length > 320 ||
            !System.Net.Mail.MailAddress.TryCreate(request.Email.Trim(), out var address) || address.Address != request.Email.Trim())
            return BadRequest(new { message = "กรุณาระบุอีเมลที่ถูกต้องและยืนยันการส่ง" });
        await using var db = await Open(token);
        var code = request.CapabilityCode ?? "repair.parts_cost";
        if (code is not ("repair.parts_cost" or "repair.track_own" or "repair.create_own")) return BadRequest(new { message = "ไม่รองรับรายงานนี้" });
        if (!await LaooApi.Services.Assistant.AssistantCapabilityAccess.IsAllowed(db, User, code, token)) return Forbid();
        await using (var permission = new SqlCommand("SELECT AllowEmail FROM dbo.TDADAiCapabilityCompany WHERE CompanyID=@company AND CapabilityCode=@code AND IsEnabled=1", db))
        {
            Add(permission, "@company", SqlDbType.BigInt, CompanyId);
            Add(permission, "@code", SqlDbType.NVarChar, code, 100);
            if (Convert.ToBoolean(await permission.ExecuteScalarAsync(token) ?? false) != true) return Forbid();
        }
        string body;
        if (code == "repair.parts_cost")
        {
            var calculation = await AssistantPartsCost(request.From, request.To, token);
            if (calculation is not OkObjectResult ok) return calculation;
            using var data = System.Text.Json.JsonDocument.Parse(System.Text.Json.JsonSerializer.Serialize(ok.Value));
            var root = data.RootElement;
            var scope = root.GetProperty("scope").GetString() == "company" ? "ทั้งบริษัท" : "ตามขอบเขตบริการตนเอง";
            body = $"สรุปต้นทุนอะไหล่งานซ่อม ({scope})\nช่วงวันที่: {request.From?.ToString("dd/MM/yyyy") ?? "เริ่มต้น"} - {request.To?.ToString("dd/MM/yyyy") ?? "ปัจจุบัน"}\nจำนวนงาน: {root.GetProperty("count")}\nต้นทุนอะไหล่: {root.GetProperty("partsTotal")} บาท\nไม่รวมค่าแรงและค่าบริการอื่น";
        }
        else if (code == "repair.track_own")
        {
            var result = await AssistantOwnRequests(token);
            if (result is not OkObjectResult ok) return result;
            using var data = System.Text.Json.JsonDocument.Parse(System.Text.Json.JsonSerializer.Serialize(ok.Value));
            body = "รายการแจ้งซ่อมของคุณ (ล่าสุดไม่เกิน 20 รายการ)\n" + string.Join("\n", data.RootElement.GetProperty("items").EnumerateArray().Select(x => $"{x.GetProperty("requestNo")} • {x.GetProperty("subject")} • {AssistantStatus(x.GetProperty("statusCode").GetString())}"));
        }
        else
        {
            if (request.RequestId is not > 0) return BadRequest(new { message = "ไม่พบเลขที่รายการ" });
            var result = await AssistantCreatedRequest(request.RequestId.Value, token);
            if (result is not OkObjectResult ok) return result;
            using var data = System.Text.Json.JsonDocument.Parse(System.Text.Json.JsonSerializer.Serialize(ok.Value));
            var item = data.RootElement;
            body = $"แจ้งซ่อมสำเร็จ\nเลขที่: {item.GetProperty("requestNo")}\nหัวข้อ: {item.GetProperty("subject")}\nรายละเอียด: {item.GetProperty("detail")}\nสถานะ: {AssistantStatus(item.GetProperty("statusCode").GetString())}";
        }
        await using var config = new SqlCommand("SELECT EmailHost,EmailPort,EmailCenter,EmailPasswordCenter FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND IsActive=1", db);
        Add(config, "@company", SqlDbType.BigInt, CompanyId);
        await using var reader = await config.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return BadRequest(new { message = "ไม่พบการตั้งค่าอีเมลของบริษัท" });
        var host = reader.IsDBNull(0) ? null : reader.GetString(0);
        var port = reader.IsDBNull(1) ? 587 : Convert.ToInt32(reader.GetValue(1));
        var sender = reader.IsDBNull(2) ? null : reader.GetString(2);
        var protectedPassword = reader.IsDBNull(3) ? null : reader.GetString(3);
        await reader.DisposeAsync();
        var password = HttpContext.RequestServices.GetRequiredService<CompanySetupSecretService>().Unprotect(protectedPassword);
        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(sender) || string.IsNullOrWhiteSpace(password) || port is < 1 or > 65535)
            return BadRequest(new { message = "ยังตั้งค่าอีเมลบริษัทไม่ครบ กรุณาติดต่อผู้ดูแลระบบ" });
        try
        {
            using var mail = new System.Net.Mail.MailMessage(sender, address.Address, "ข้อมูลระบบแจ้งซ่อม", body);
            using var smtp = new System.Net.Mail.SmtpClient(host, port) { EnableSsl = true, Credentials = new System.Net.NetworkCredential(sender, password) };
            await smtp.SendMailAsync(mail, token);
            return Ok(new { message = "ส่งอีเมลแล้ว" });
        }
        catch (Exception ex) when (ex is System.Net.Mail.SmtpException or System.IO.IOException or InvalidOperationException or FormatException)
        {
            logger.LogWarning("AI report email delivery failed for company {CompanyId}", CompanyId);
            return StatusCode(503, new { message = "ส่งอีเมลไม่สำเร็จ กรุณาตรวจสอบการตั้งค่าอีเมลและลองใหม่" });
        }
    }

    private static string AssistantStatus(string? status) => status switch
    {
        "NEW" => "สร้างใหม่", "RECEIVED" => "รับงานแล้ว", "IN_PROGRESS" => "กำลังดำเนินการ",
        "COMPLETED" => "เสร็จแล้ว", "CANCELLED" => "ยกเลิก", _ => status ?? "-"
    };

    [HttpGet("repair-history")]
    public async Task<IActionResult> RepairHistory([FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken token = default)
    {
        await using var c = await Open(token);
        if (!await InService(c, token) || !await Allowed(c, "19002", "VIEW", token)) return Forbid();

        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        const string sql = """
SELECT COUNT_BIG(1) OVER(),R.RequestID,R.RequestNo,R.RequesterNameSnapshot,R.LocationSnapshot,
       R.EquipmentNameSnapshot,R.Subject,R.AssignedEmployeeNameSnapshot,R.CompletedDate,
       ISNULL(P.PartCount,0),ISNULL(P.PartsTotal,0)
FROM dbo.TDADServiceRequest R
OUTER APPLY
(
    SELECT COUNT_BIG(1) PartCount,ISNULL(SUM(TotalCost),0) PartsTotal
    FROM dbo.TDADServiceRequestPart
    WHERE CompanyID=R.CompanyID AND RequestID=R.RequestID AND IsActive=1
) P
WHERE R.CompanyID=@company AND R.IsActive=1 AND R.StatusCode=N'COMPLETED'
  AND (@q=N'' OR R.RequestNo LIKE N'%'+@q+N'%' OR R.RequesterNameSnapshot LIKE N'%'+@q+N'%'
       OR R.Subject LIKE N'%'+@q+N'%' OR R.AssignedEmployeeNameSnapshot LIKE N'%'+@q+N'%')
ORDER BY R.CompletedDate DESC,R.RequestID DESC OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId);
        Add(cmd, "@q", SqlDbType.NVarChar, search?.Trim() ?? string.Empty, 200);
        Add(cmd, "@offset", SqlDbType.Int, (page - 1) * pageSize);
        Add(cmd, "@take", SqlDbType.Int, pageSize);
        var items = new List<object>(); long total = 0;
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
        {
            total = r.GetInt64(0);
            items.Add(new
            {
                requestId = r.GetInt64(1),
                requestNo = r.GetString(2),
                requesterName = r.GetString(3),
                locationSnapshot = Text(r, 4),
                equipmentName = Text(r, 5),
                subject = r.GetString(6),
                assignedEmployeeName = Text(r, 7),
                completedDate = DateTimeValue(r, 8),
                partsCount = r.GetInt64(9),
                partsTotal = r.GetDecimal(10)
            });
        }
        return Ok(new { items, total, page, pageSize });
    }
    [HttpGet("{id:long}")]
    public async Task<IActionResult> Detail(long id, [FromQuery] string? menuCode, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        bool canManage, canSelfView, canHistoryView;
        string requiredStatus = "";
        if (menuCode is not null)
        {
            if (menuCode is not ("15001" or "17001" or "17002" or "19002" or "20001" or "20002" or "20003"))
                return BadRequest(new { message = "เมนูรายละเอียดใบแจ้งซ่อมไม่ถูกต้อง" });
            var expectedType = menuCode is "17001" or "17002" ? 2 : menuCode is "19002" or "20002" or "20003" ? 3 : 1;
            if (await ScreenType(c, menuCode, token) != expectedType ||
                !await Allowed(c, menuCode, "VIEW", token)) return Forbid();
            canManage = menuCode is "15001" or "17001" or "17002";
            canSelfView = menuCode is "20001" or "20002" or "20003";
            canHistoryView = menuCode == "19002";
            if (menuCode == "17001") requiredStatus = "NEW";
            if (menuCode == "20003") requiredStatus = "COMPLETED";
        }
        else
        {
            canManage = await Allowed(c, "15001", "VIEW", token);
            canSelfView = await Allowed(c, "20001", "VIEW", token);
            canHistoryView = await Allowed(c, "19002", "VIEW", token);
            if (!canManage && !canSelfView && !canHistoryView) return Forbid();
        }
        var detailScope = menuCode is null or "20001" ? MenuViewPredicate : SelfViewPredicate;
        var sql = $"SELECT RequestID,RequestNo,RequesterType,RequesterID,{RequesterDisplaySql},RequesterPhoneSnapshot,RequesterEmailSnapshot,LocationSnapshot,EquipmentItemID,EquipmentCodeSnapshot,EquipmentNameSnapshot,Subject,Detail,StatusCode,RequestDate,AssignedEmployeeID,{AssignedDisplaySql},ReceivedDate,StartedDate,CompletedDate,ResolutionDetail,CancellationReason,RowVersion,PriorityCode,RequestChannelCode,R.EquipmentInstanceID FROM dbo.TDADServiceRequest R WHERE CompanyID=@company AND RequestID=@id AND IsActive=1 AND (@manage=1 OR (@history=1 AND StatusCode=N'COMPLETED') OR (@owner=1 AND {detailScope})) AND (@requiredStatus=N'' OR StatusCode=@requiredStatus)";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id); Add(q, "@manage", SqlDbType.Bit, canManage); Add(q, "@history", SqlDbType.Bit, canHistoryView); Add(q, "@owner", SqlDbType.Bit, canSelfView); Add(q, "@user", SqlDbType.BigInt, UserId); Add(q, "@requiredStatus", SqlDbType.NVarChar, requiredStatus, 30);
        await using var r = await q.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound();
        var equipmentInstanceId = Long(r, 25);
        var response = new Dictionary<string, object?>
        {
            ["requestId"] = r.GetInt64(0),
            ["requestNo"] = r.GetString(1),
            ["requesterType"] = r.GetString(2),
            ["requesterId"] = Long(r, 3),
            ["requesterName"] = r.GetString(4),
            ["requesterPhone"] = Text(r, 5),
            ["requesterEmail"] = Text(r, 6),
            ["locationSnapshot"] = Text(r, 7),
            ["equipmentItemId"] = Long(r, 8),
            ["equipmentCode"] = Text(r, 9),
            ["equipmentName"] = Text(r, 10),
            ["subject"] = r.GetString(11),
            ["detail"] = r.GetString(12),
            ["statusCode"] = r.GetString(13),
            ["requestDate"] = r.GetDateTime(14),
            ["assignedEmployeeId"] = Long(r, 15),
            ["assignedEmployeeName"] = Text(r, 16),
            ["receivedDate"] = DateTimeValue(r, 17),
            ["startedDate"] = DateTimeValue(r, 18),
            ["completedDate"] = DateTimeValue(r, 19),
            ["resolutionDetail"] = Text(r, 20),
            ["cancellationReason"] = Text(r, 21),
            ["rowVersion"] = Convert.ToBase64String((byte[])r[22]),
            ["priorityCode"] = r.GetString(23), ["requestChannelCode"] = Text(r, 24)
        };
        await r.DisposeAsync();
        if (equipmentInstanceId is long serialId && response["equipmentItemId"] is long itemId &&
            await Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedForProjectAsync(c, User, "LAOO_STOCK", "08006", "VIEW", token))
        {
            await using var serialQuery = new SqlCommand("SELECT SerialNo FROM dbo.TDIVItemInstance WHERE CompanyID=@company AND ItemInstanceID=@id", c);
            Add(serialQuery, "@company", SqlDbType.BigInt, CompanyId); Add(serialQuery, "@id", SqlDbType.BigInt, serialId);
            var serial = Convert.ToString(await serialQuery.ExecuteScalarAsync(token));
            if (!string.IsNullOrWhiteSpace(serial) && await FindAccessibleEquipmentSerial(serial, itemId, token) == serialId)
                response["equipmentSerial"] = serial;
        }
        response["requireEquipment"] = (await ReadSettings(c, token)).RequireEquipment;
        var parts = new List<object>(); decimal partsTotal = 0;
        const string partSql = "SELECT P.ServiceRequestPartID,P.WarehouseID,P.ItemID,P.ItemCodeSnapshot,P.ItemNameSnapshot,P.UnitCodeSnapshot,P.Quantity,P.UnitCostSnapshot,P.TotalCost,W.WarehouseName,(SELECT STRING_AGG(X.SerialNo,N', ') FROM dbo.TDIVStockIssueSerial S JOIN dbo.TDIVItemInstance X ON X.ItemInstanceID=S.ItemInstanceID WHERE S.StockIssueDetailID=P.StockIssueDetailID) SerialNos FROM dbo.TDADServiceRequestPart P JOIN dbo.TDIVWarehouse W ON W.CompanyID=P.CompanyID AND W.WarehouseID=P.WarehouseID WHERE P.CompanyID=@company AND P.RequestID=@request AND P.IsActive=1 ORDER BY P.ServiceRequestPartID";
        await using (var partCommand = new SqlCommand(partSql, c))
        {
            Add(partCommand, "@company", SqlDbType.BigInt, CompanyId); Add(partCommand, "@request", SqlDbType.BigInt, id);
            await using var partReader = await partCommand.ExecuteReaderAsync(token);
            while (await partReader.ReadAsync(token))
            {
                var total = partReader.GetDecimal(8); partsTotal += total;
                parts.Add(new { serviceRequestPartId = partReader.GetInt64(0), warehouseId = partReader.GetInt64(1), itemId = partReader.GetInt64(2), itemCode = partReader.GetString(3), itemName = partReader.GetString(4), unitCode = Text(partReader, 5), quantity = partReader.GetDecimal(6), unitCost = partReader.GetDecimal(7), totalCost = total, warehouseName = partReader.GetString(9), serialNos = (Text(partReader, 10)?.Split(", ", StringSplitOptions.RemoveEmptyEntries) ?? []) });
            }
        }
        response["parts"] = parts; response["partsTotal"] = partsTotal;
        return Ok(response);
    }

    [HttpGet("parts/lookup")]
    public async Task<IActionResult> PartsLookup(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token) ||
            !(await Allowed(c, "15001", "EDIT", token) ||
              await ScreenType(c, "17002", token) == 2 && await Allowed(c, "17002", "EDIT", token))) return Forbid();
        var warehouses = new List<object>(); var items = new List<object>(); var serials = new List<object>();
        var warehouseSql = $"SELECT W.WarehouseID,W.WarehouseCode,W.WarehouseName,W.IsDefault FROM dbo.TDIVWarehouse W INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE W.CompanyID=@company AND W.IsActive=1 AND {InventoryWarehouseAccess.WarehouseAliasPredicate} ORDER BY W.IsDefault DESC,W.WarehouseCode";
        await using (var command = new SqlCommand(warehouseSql, c))
        {
            Add(command, "@company", SqlDbType.BigInt, CompanyId); Add(command, "@user", SqlDbType.BigInt, UserId);
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token)) warehouses.Add(new { warehouseId = reader.GetInt64(0), warehouseCode = reader.GetString(1), warehouseName = reader.GetString(2), isDefault = reader.GetBoolean(3) });
        }
        var itemSql = $"SELECT SB.WarehouseID,I.ItemID,I.ItemCode,I.ItemName,I.UnitCode,I.CostPrice,I.StockTrackingCode,SB.Quantity FROM dbo.TDIVStockBalance SB INNER JOIN dbo.TDIVItem I ON I.CompanyID=SB.CompanyID AND I.ItemID=SB.ItemID INNER JOIN dbo.TDIVWarehouse W ON W.CompanyID=SB.CompanyID AND W.WarehouseID=SB.WarehouseID AND W.IsActive=1 INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE SB.CompanyID=@company AND SB.Quantity>0 AND I.IsActive=1 AND I.ItemKindCode=N'GOODS' AND I.StockTrackingCode<>N'NONE' AND EXISTS(SELECT 1 FROM dbo.TDIVItemUsage U WHERE U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode IN(N'MATERIAL',N'SPARE_PART')) AND {InventoryWarehouseAccess.WarehouseAliasPredicate} AND {InventoryItemProjectAccess.ItemAliasPredicate} ORDER BY W.IsDefault DESC,I.ItemCode";
        await using (var command = new SqlCommand(itemSql, c))
        {
            Add(command, "@company", SqlDbType.BigInt, CompanyId); Add(command, "@user", SqlDbType.BigInt, UserId);
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token)) items.Add(new { warehouseId = reader.GetInt64(0), itemId = reader.GetInt64(1), itemCode = reader.GetString(2), itemName = reader.GetString(3), unitCode = Text(reader, 4), unitCost = reader.GetDecimal(5), stockTrackingCode = reader.GetString(6), availableQuantity = reader.GetDecimal(7) });
        }
        var serialSql = $"SELECT X.ItemInstanceID,X.ItemID,X.WarehouseID,X.SerialNo FROM dbo.TDIVItemInstance X INNER JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID INNER JOIN dbo.TDIVWarehouse W ON W.WarehouseID=X.WarehouseID AND W.CompanyID=X.CompanyID INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE X.CompanyID=@company AND X.StatusCode=N'IN_STOCK' AND {InventoryWarehouseAccess.WarehouseAliasPredicate} AND {InventoryItemProjectAccess.ItemAliasPredicate} ORDER BY X.SerialNo";
        await using (var command = new SqlCommand(serialSql, c))
        {
            Add(command, "@company", SqlDbType.BigInt, CompanyId); Add(command, "@user", SqlDbType.BigInt, UserId);
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token)) serials.Add(new { itemInstanceId = reader.GetInt64(0), itemId = reader.GetInt64(1), warehouseId = reader.GetInt64(2), serialNo = reader.GetString(3) });
        }
        return Ok(new { warehouses, items, serials });
    }
    [HttpGet("{id:long}/attachments")]
    public async Task<IActionResult> Attachments(long id, [FromQuery] string? menuCode, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        var access = await RequestAccess(c, id, token);
        if (!access.Found) return NotFound();
        if (!await CanReadRequest(c, access, menuCode, token)) return Forbid();
        const string sql = "SELECT AttachmentID,FileName,ContentType,FileSize,ImageWidth,ImageHeight,CreateDate FROM dbo.TDADServiceRequestAttachment WHERE CompanyID=@company AND RequestID=@request AND IsActive=1 ORDER BY CreateDate,AttachmentID";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@request", SqlDbType.BigInt, id);
        var items = new List<object>(); await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) items.Add(new { attachmentId = r.GetInt64(0), requestId = id, fileName = r.GetString(1), contentType = r.GetString(2), fileSize = r.GetInt64(3), imageWidth = LongInt(r, 4), imageHeight = LongInt(r, 5), createDate = r.GetDateTime(6), url = $"/api/service/requests/{id}/attachments/{r.GetInt64(0)}{(menuCode is null ? "" : $"?menuCode={menuCode}")}" });
        return Ok(new { items });
    }

    [HttpGet("{id:long}/attachments/{attachmentId:long}")]
    public async Task<IActionResult> Attachment(long id, long attachmentId, [FromQuery] string? menuCode, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        var access = await RequestAccess(c, id, token);
        if (!access.Found) return NotFound();
        if (!await CanReadRequest(c, access, menuCode, token)) return Forbid();
        const string sql = "SELECT FileName,StoredPath,ContentType FROM dbo.TDADServiceRequestAttachment WHERE CompanyID=@company AND RequestID=@request AND AttachmentID=@attachment AND IsActive=1";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@request", SqlDbType.BigInt, id); Add(q, "@attachment", SqlDbType.BigInt, attachmentId);
        await using var r = await q.ExecuteReaderAsync(token); if (!await r.ReadAsync(token)) return NotFound();
        var fileName = r.GetString(0); var relative = r.GetString(1); var contentType = r.GetString(2); var fullPath = SafeFilePath(relative);
        if (fullPath is null || !System.IO.File.Exists(fullPath)) return NotFound();
        return PhysicalFile(fullPath, contentType, fileName, enableRangeProcessing: true);
    }

    [HttpPost("{id:long}/attachments"), RequestSizeLimit(MaxIncomingAttachmentBytes)]
    public async Task<IActionResult> UploadAttachment(long id, IFormFile? file, CancellationToken token, [FromQuery] bool editSelf = false, [FromQuery] bool editNew = false)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        var access = await RequestAccess(c, id, token);
        if (!access.Found) return NotFound();
        if (access.Status is "COMPLETED" or "CANCELLED") return Conflict(new { message = "ไม่สามารถเพิ่มรูปในใบแจ้งซ่อมที่ปิดแล้ว" });
        var canManage = !editSelf && await Allowed(c, "15001", "EDIT", token);
        var canOwner = editSelf
            ? await ScreenType(c, "20001", token) == 1 && await Allowed(c, "20001", "EDIT", token) && await HasMenuScope(c, id, "VIEW", token) && await HasMenuScope(c, id, "EDIT", token)
            : access.CreatedBy == UserId && await Allowed(c, "20001", "CREATE", token);
        if (!canManage && !canOwner) return Forbid();
        if ((editSelf || editNew || !canManage) && access.Status != "NEW") return Conflict(new { message = "เพิ่มรูปได้เฉพาะใบแจ้งซ่อมสถานะสร้างใหม่" });
        if (file is null || file.Length == 0) return BadRequest(new { message = "กรุณาเลือกไฟล์รูปภาพ" });
        if (file.Length > MaxIncomingAttachmentBytes) return BadRequest(new { message = "ไฟล์ใหญ่เกินกำหนด", description = "ไฟล์ต้นฉบับต้องไม่เกิน 25 MB" });
        var processed = await ProcessImage(file, token);
        if (processed.Error is not null) return BadRequest(new { message = processed.Error });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        string? storedPath = null;
        try
        {
            if ((editSelf || editNew || !canManage) && !await LockNewRequest(c, tx, id, editSelf || !canManage, token))
            {
                await tx.RollbackAsync(token);
                return Conflict(new { message = "เพิ่มรูปได้เฉพาะใบแจ้งซ่อมสถานะสร้างใหม่" });
            }
            const string insert = "INSERT dbo.TDADServiceRequestAttachment(CompanyID,RequestID,FileName,StoredPath,ContentType,FileSize,ImageWidth,ImageHeight,CreateBy) OUTPUT INSERTED.AttachmentID VALUES(@company,@request,@name,N'',@type,@size,@width,@height,@user)";
            await using var insertCommand = new SqlCommand(insert, c, tx); Add(insertCommand, "@company", SqlDbType.BigInt, CompanyId); Add(insertCommand, "@request", SqlDbType.BigInt, id); Add(insertCommand, "@name", SqlDbType.NVarChar, SafeOriginalName(file.FileName), 255); Add(insertCommand, "@type", SqlDbType.NVarChar, processed.ContentType, 100); Add(insertCommand, "@size", SqlDbType.BigInt, processed.Bytes.Length); Add(insertCommand, "@width", SqlDbType.Int, processed.Width); Add(insertCommand, "@height", SqlDbType.Int, processed.Height); Add(insertCommand, "@user", SqlDbType.BigInt, UserId);
            var attachmentId = Convert.ToInt64(await insertCommand.ExecuteScalarAsync(token));
            storedPath = $"uploads/service-requests/{CompanyId}/{id}/{attachmentId}{processed.Extension}";
            var fullPath = SafeFilePath(storedPath) ?? throw new InvalidOperationException("Invalid attachment path");
            Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
            await System.IO.File.WriteAllBytesAsync(fullPath, processed.Bytes, token);
            await using var update = new SqlCommand("UPDATE dbo.TDADServiceRequestAttachment SET StoredPath=@path,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND AttachmentID=@attachment", c, tx); Add(update, "@path", SqlDbType.NVarChar, storedPath, 500); Add(update, "@user", SqlDbType.BigInt, UserId); Add(update, "@company", SqlDbType.BigInt, CompanyId); Add(update, "@attachment", SqlDbType.BigInt, attachmentId); await update.ExecuteNonQueryAsync(token);
            await tx.CommitAsync(token);
            return Ok(new { attachmentId, requestId = id, fileName = SafeOriginalName(file.FileName), contentType = processed.ContentType, fileSize = processed.Bytes.Length, imageWidth = processed.Width, imageHeight = processed.Height, url = $"/api/service/requests/{id}/attachments/{attachmentId}" });
        }
        catch
        {
            await tx.RollbackAsync(token); if (storedPath is not null) TryDelete(storedPath); throw;
        }
    }

    [HttpDelete("{id:long}/attachments/{attachmentId:long}")]
    public async Task<IActionResult> DeleteAttachment(long id, long attachmentId, CancellationToken token, [FromQuery] bool editSelf = false, [FromQuery] bool editNew = false)
    {
        await using var c = await Open(token);
        var menu = editSelf ? "20001" : "15001";
        if (!await InService(c, token) || await ScreenType(c, menu, token) != 1 || !await Allowed(c, menu, "EDIT", token)) return Forbid();
        var access = await RequestAccess(c, id, token); if (!access.Found) return NotFound();
        if (editSelf && (!await HasMenuScope(c, id, "VIEW", token) || !await HasMenuScope(c, id, "EDIT", token))) return Forbid();
        if ((editSelf || editNew) && access.Status != "NEW") return Conflict(new { message = "ลบรูปได้เฉพาะใบแจ้งซ่อมสถานะสร้างใหม่" });
        if (access.Status is "COMPLETED" or "CANCELLED") return Conflict(new { message = "ไม่สามารถลบรูปในใบแจ้งซ่อมที่ปิดแล้ว" });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        if ((editSelf || editNew) && !await LockNewRequest(c, tx, id, editSelf, token))
        {
            await tx.RollbackAsync(token);
            return Conflict(new { message = "ลบรูปได้เฉพาะใบแจ้งซ่อมสถานะสร้างใหม่" });
        }
        const string sql = "SELECT StoredPath FROM dbo.TDADServiceRequestAttachment WHERE CompanyID=@company AND RequestID=@request AND AttachmentID=@attachment AND IsActive=1";
        await using var q = new SqlCommand(sql, c, tx); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@request", SqlDbType.BigInt, id); Add(q, "@attachment", SqlDbType.BigInt, attachmentId); var path = Convert.ToString(await q.ExecuteScalarAsync(token)); if (string.IsNullOrWhiteSpace(path)) return NotFound();
        await using var delete = new SqlCommand("DELETE FROM dbo.TDADServiceRequestAttachment WHERE CompanyID=@company AND RequestID=@request AND AttachmentID=@attachment AND IsActive=1", c, tx);
        Add(delete, "@company", SqlDbType.BigInt, CompanyId);
        Add(delete, "@request", SqlDbType.BigInt, id);
        Add(delete, "@attachment", SqlDbType.BigInt, attachmentId);
        if (await delete.ExecuteNonQueryAsync(token) != 1) return NotFound();
        await tx.CommitAsync(token);
        TryDelete(path!);
        return Ok(new { attachmentId, deleted = true });
    }

    private async Task<bool> LockNewRequest(SqlConnection c, SqlTransaction tx, long id, bool self, CancellationToken token)
    {
        await using var q = new SqlCommand($"SELECT 1 FROM dbo.TDADServiceRequest R WITH (UPDLOCK, HOLDLOCK) WHERE CompanyID=@company AND RequestID=@request AND (@self=0 OR ({MenuViewPredicate} AND {MenuEditPredicate})) AND IsActive=1 AND StatusCode=N'NEW'", c, tx);
        Add(q, "@company", SqlDbType.BigInt, CompanyId);
        Add(q, "@request", SqlDbType.BigInt, id);
        Add(q, "@user", SqlDbType.BigInt, UserId);
        Add(q, "@self", SqlDbType.Bit, self);
        return await q.ExecuteScalarAsync(token) is not null;
    }

    [HttpGet("technicians")]
    public async Task<IActionResult> Technicians(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token) ||
            !(await ScreenType(c, "17001", token) == 2 && await Allowed(c, "17001", "EDIT", token) ||
              await ScreenType(c, "15001", token) == 1 && await Allowed(c, "15001", "EDIT", token))) return Forbid();
        const string sql = "SELECT EmployeeID,EmployeeCode,FullName FROM dbo.TDADEmployee WHERE CompanyID=@company AND IsActive=1 AND IsServiceTechnician=1 ORDER BY FullName,EmployeeCode";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); var rows = new List<object>(); await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) rows.Add(new { employeeId = r.GetInt64(0), employeeCode = r.GetString(1), fullName = r.GetString(2) });
        return Ok(new { items = rows });
    }

    [HttpGet("evaluation-templates")]
    public async Task<IActionResult> EvaluationTemplates(CancellationToken token)
    {
        await using var c = await Open(token);
        var canReceive = await ScreenType(c, "17001", token) == 2 && await Allowed(c, "17001", "EDIT", token) ||
                         await ScreenType(c, "15001", token) == 1 && await Allowed(c, "15001", "EDIT", token);
        if (!await InService(c, token) || !canReceive) return Forbid();
        if (!await EvaluationEnabled(c, null, token))
            return Ok(new { evaluationEnabled = false, defaultTemplateId = (long?)null, items = Array.Empty<object>() });

        const string sql = """
SELECT T.EvaluationTemplateID,T.TemplateCode,T.TemplateName,
       CASE WHEN S.DefaultEvaluationTemplateID=T.EvaluationTemplateID AND S.IsActive=1 THEN 1 ELSE 0 END IsDefault
FROM dbo.TDEVTemplate T
LEFT JOIN dbo.TDEVSystemSetting S
  ON S.CompanyID=T.CompanyID AND S.SourceType=N'SERVICE'
WHERE T.CompanyID=@company AND T.SourceType=N'SERVICE' AND T.IsActive=1
ORDER BY IsDefault DESC,T.TemplateCode,T.EvaluationTemplateID;
""";
        await using var command = new SqlCommand(sql, c);
        Add(command, "@company", SqlDbType.BigInt, CompanyId);
        var items = new List<object>();
        long? defaultTemplateId = null;
        await using var reader = await command.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
        {
            var id = reader.GetInt64(0);
            var isDefault = Convert.ToBoolean(reader.GetValue(3));
            if (isDefault) defaultTemplateId = id;
            items.Add(new { id, code = reader.GetString(1), name = reader.GetString(2), isDefault });
        }
        return Ok(new { evaluationEnabled = true, defaultTemplateId, items });
    }

    [HttpPost("{id:long}/receive")]
    public Task<IActionResult> Receive(long id, ActionRequest request, CancellationToken token) => Transition(id, "RECEIVED", request, token);
    [HttpPost("{id:long}/start")]
    public Task<IActionResult> Start(long id, ActionRequest request, CancellationToken token) => Transition(id, "IN_PROGRESS", request, token);
    [HttpPost("{id:long}/complete")]
    public Task<IActionResult> Complete(long id, ActionRequest request, CancellationToken token) => Transition(id, "COMPLETED", request, token);
    [HttpPost("{id:long}/cancel")]
    public Task<IActionResult> Cancel(long id, ActionRequest request, CancellationToken token) => Transition(id, "CANCELLED", request, token);

    private async Task<IActionResult> Transition(long id, string next, ActionRequest x, CancellationToken token)
    {
        await using var c = await Open(token);
        var staffEdit = await ScreenType(c, "15001", token) == 1 && await Allowed(c, "15001", "EDIT", token);
        var workOrderEdit = await ScreenType(c, "17002", token) == 2 && await Allowed(c, "17002", "EDIT", token);
        var dispatchEdit = next == "RECEIVED" && await ScreenType(c, "17001", token) == 2 &&
                           await Allowed(c, "17001", "EDIT", token);
        if (!await InService(c, token) || !(staffEdit || workOrderEdit || dispatchEdit)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            string? current = null; string? requestNo = null; byte[]? version = null;
            await using (var q = new SqlCommand("SELECT StatusCode,RequestNo,RowVersion FROM dbo.TDADServiceRequest WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND RequestID=@id AND IsActive=1", c, tx))
            { Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id); await using var r = await q.ExecuteReaderAsync(token); if (!await r.ReadAsync(token)) return NotFound(); current = r.GetString(0); requestNo = r.GetString(1); version = (byte[])r[2]; }
            var valid = next == "RECEIVED" && current == "NEW" || next == "IN_PROGRESS" && current == "RECEIVED" || next == "COMPLETED" && current == "IN_PROGRESS" || next == "CANCELLED" && current is "NEW" or "RECEIVED" or "IN_PROGRESS";
            if (!valid) return Conflict(new { message = "ไม่สามารถเปลี่ยนสถานะได้", description = "สถานะปัจจุบันไม่อยู่ในลำดับที่อนุญาต" });
            if (next == "RECEIVED")
            {
                if (!x.AssignedEmployeeId.HasValue) return BadRequest(new { message = "กรุณาเลือกช่างซ่อม" });
                await using var e = new SqlCommand("SELECT FullName FROM dbo.TDADEmployee WHERE CompanyID=@company AND EmployeeID=@employee AND IsActive=1 AND IsServiceTechnician=1", c, tx); Add(e, "@company", SqlDbType.BigInt, CompanyId); Add(e, "@employee", SqlDbType.BigInt, x.AssignedEmployeeId); var name = Convert.ToString(await e.ExecuteScalarAsync(token)); if (string.IsNullOrWhiteSpace(name)) return BadRequest(new { message = "ไม่พบช่างซ่อมที่ใช้งานได้ใน Company นี้" });
                var evaluationEnabled = await EvaluationEnabled(c, tx, token);
                if (evaluationEnabled && !x.EvaluationTemplateId.HasValue)
                    return BadRequest(new { message = "กรุณาเลือกแบบประเมินงานบริการ", description = "บริษัทเปิดใช้งานระบบประเมิน จึงต้องเลือกแบบประเมินก่อนรับงาน" });
                if (!evaluationEnabled && x.EvaluationTemplateId.HasValue)
                    return BadRequest(new { message = "บริษัทไม่ได้เปิดใช้งานระบบประเมิน", description = "ไม่สามารถกำหนดแบบประเมินให้ใบงานนี้ได้" });
                if (x.EvaluationTemplateId.HasValue)
                {
                    await using var template = new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDEVTemplate WHERE CompanyID=@company AND EvaluationTemplateID=@template AND SourceType=N'SERVICE' AND IsActive=1", c, tx);
                    Add(template, "@company", SqlDbType.BigInt, CompanyId); Add(template, "@template", SqlDbType.BigInt, x.EvaluationTemplateId);
                    if (Convert.ToInt64(await template.ExecuteScalarAsync(token)) != 1)
                        return BadRequest(new { message = "แบบประเมินไม่ถูกต้อง", description = "ต้องเลือกแบบประเมินงานบริการที่เปิดใช้งานและอยู่ในบริษัทเดียวกัน" });
                }
                await using var u = new SqlCommand("UPDATE dbo.TDADServiceRequest SET StatusCode=N'RECEIVED',AssignedEmployeeID=@employee,AssignedEmployeeNameSnapshot=@name,EvaluationTemplateID=@template,ReceivedDate=SYSUTCDATETIME(),ReceivedBy=@user,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND RequestID=@id AND RowVersion=@version", c, tx); Add(u, "@employee", SqlDbType.BigInt, x.AssignedEmployeeId); Add(u, "@name", SqlDbType.NVarChar, name, 200); Add(u, "@template", SqlDbType.BigInt, x.EvaluationTemplateId); Add(u, "@user", SqlDbType.BigInt, UserId); Add(u, "@company", SqlDbType.BigInt, CompanyId); Add(u, "@id", SqlDbType.BigInt, id); Add(u, "@version", SqlDbType.VarBinary, version); await u.ExecuteNonQueryAsync(token);
            }
            else if (next == "IN_PROGRESS") await UpdateStatus(c, tx, id, "IN_PROGRESS", "StartedDate=SYSUTCDATETIME(),StartedBy=@user", token);
            else if (next == "COMPLETED")
            {
                if (string.IsNullOrWhiteSpace(x.ResolutionDetail)) return BadRequest(new { message = "กรุณาระบุผลการซ่อม" });
                var parts = x.Parts ?? [];
                if (parts.Any(p => p.WarehouseId <= 0 || p.ItemId <= 0 || p.Quantity <= 0)) return BadRequest(new { message = "ข้อมูลอะไหล่ไม่ถูกต้อง", description = "กรุณาเลือกคลัง อะไหล่ และระบุจำนวนมากกว่า 0" });
                if (parts.GroupBy(p => new { p.WarehouseId, p.ItemId }).Any(g => g.Count() > 1)) return BadRequest(new { message = "รายการอะไหล่ซ้ำ", description = "อะไหล่เดียวกันในคลังเดียวกันต้องรวมเป็นหนึ่งรายการ" });
                await IssueRepairParts(c, tx, id, requestNo!, parts, token);
                await UpdateStatus(c, tx, id, "COMPLETED", "CompletedDate=SYSUTCDATETIME(),CompletedBy=@user,ResolutionDetail=@detail", token, x.ResolutionDetail);
            }
            else { if (string.IsNullOrWhiteSpace(x.CancellationReason)) return BadRequest(new { message = "กรุณาระบุเหตุผลการยกเลิก" }); await UpdateStatus(c, tx, id, "CANCELLED", "CancellationReason=@reason", token, null, x.CancellationReason); }
            await tx.CommitAsync(token);
            if (next == "COMPLETED")
                await PublishServiceEvaluation(id, token);
            return Ok(new { requestId = id, statusCode = next });
        }
        catch (SqlException ex) when (ex.Number is 52330 or 52331)
        { await tx.RollbackAsync(token); return Conflict(new { message = "ตัดสต๊อกอะไหล่ไม่สำเร็จ", description = ex.Number == 52331 ? "จำนวนอะไหล่ในคลังไม่เพียงพอ กรุณาโหลดข้อมูลใหม่" : "Serial อะไหล่ไม่พร้อมใช้งานหรือไม่อยู่ในคลังที่เลือก" }); }
        catch (InventoryItemProjectDeniedException)
        { await tx.RollbackAsync(token); return StatusCode(403, new { message = "ไม่มีสิทธิ์ใช้อะไหล่", description = "อะไหล่ไม่ได้เปิดใช้งานสำหรับ Project ของ Company นี้" }); }
        catch (InvalidOperationException ex)
        { await tx.RollbackAsync(token); return BadRequest(new { message = "ข้อมูลอะไหล่ไม่ถูกต้อง", description = ex.Message }); }
        catch { await tx.RollbackAsync(token); throw; }
    }

    private async Task PublishServiceEvaluation(long requestId, CancellationToken token)
    {
        try
        {
            await using var connection = await Open(token);
            const string sql = """
SELECT R.RequestNo,R.Subject,R.CompletedDate,U.UserID,R.EvaluationTemplateID
FROM dbo.TDADServiceRequest R
JOIN dbo.TDADUser U
  ON U.CompanyID=R.CompanyID
 AND U.PersonID=R.RequesterID
 AND U.IsActive=1
WHERE R.CompanyID=@company
  AND R.RequestID=@request
  AND R.StatusCode=N'COMPLETED'
  AND R.IsActive=1
  AND R.CompletedDate IS NOT NULL
  AND EXISTS
  (
      SELECT 1
      FROM dbo.TDADCompanyProject CP
      JOIN dbo.TDADProject P ON P.ProjectID=CP.ProjectID
      WHERE CP.CompanyID=R.CompanyID AND CP.PartnerID=@partner
        AND CP.IsEnabled=1 AND P.ProjectCode=N'LAOO_EVALUATION' AND P.IsActive=1
        AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
        AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
  );
""";
            await using var command = new SqlCommand(sql, connection);
            Add(command, "@company", SqlDbType.BigInt, CompanyId);
            Add(command, "@request", SqlDbType.BigInt, requestId);
            Add(command, "@partner", SqlDbType.BigInt, ClaimLong("partner_id"));
            await using var reader = await command.ExecuteReaderAsync(token);
            if (!await reader.ReadAsync(token)) return;
            var requestNo = reader.GetString(0);
            var subject = reader.GetString(1);
            var completedAt = reader.GetDateTime(2);
            var requesterUserId = reader.GetInt64(3);
            var evaluationTemplateId = Long(reader, 4);
            await reader.DisposeAsync();

            await evaluationPublisher.PublishAsync(
                new EvaluationSourceCompletedContract(
                    CompanyId,
                    "LAOO_SERVICE",
                    EvaluationSourceTypes.Service,
                    requestId,
                    $"{requestNo} | {subject}",
                    DateTime.SpecifyKind(completedAt, DateTimeKind.Utc),
                    [requesterUserId],
                    evaluationTemplateId),
                token);
        }
        catch (Exception exception) when (!token.IsCancellationRequested)
        {
            logger.LogError(
                exception,
                "Unable to create evaluation draft for completed service request {RequestId}",
                requestId);
        }
    }

    private async Task IssueRepairParts(SqlConnection c, SqlTransaction tx, long requestId, string requestNo, IReadOnlyList<ServicePartRequest> parts, CancellationToken token)
    {
        foreach (var warehouseGroup in parts.GroupBy(p => p.WarehouseId))
        {
            if (!await InventoryWarehouseAccess.CanAccessAsync(c, tx, CompanyId, UserId, warehouseGroup.Key, token)) throw new InvalidOperationException("ไม่มีสิทธิ์เข้าถึงคลังที่เลือก");
            await using var issueNumber = new SqlCommand(Laoo.Shared.Contracts.DocumentNumbering.Sql("08003"), c, tx);
            issueNumber.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
            var configuredNumber = await issueNumber.ExecuteScalarAsync(token);
            var issueCode = configuredNumber is null or DBNull ? $"IS{DateTime.UtcNow:yyyyMMddHHmmssfff}{warehouseGroup.Key % 1000:000}" : Convert.ToString(configuredNumber)!;
            await using var header = new SqlCommand("INSERT dbo.TDIVStockIssue(CompanyID,WarehouseID,IssueCode,IssueDate,WorkOrderID,WorkOrderCode,StatusCode,Remark,CreatedBy,ConfirmDate,ConfirmedBy) OUTPUT INSERTED.StockIssueID VALUES(@company,@warehouse,@code,CONVERT(date,SYSUTCDATETIME()),@request,@requestNo,N'CONFIRMED',N'เบิกอะไหล่จากงานซ่อม',@user,SYSUTCDATETIME(),@user)", c, tx);
            Add(header, "@company", SqlDbType.BigInt, CompanyId); Add(header, "@warehouse", SqlDbType.BigInt, warehouseGroup.Key); Add(header, "@code", SqlDbType.NVarChar, issueCode, 30); Add(header, "@request", SqlDbType.BigInt, requestId); Add(header, "@requestNo", SqlDbType.NVarChar, requestNo, 50); Add(header, "@user", SqlDbType.BigInt, UserId);
            var issueId = Convert.ToInt64(await header.ExecuteScalarAsync(token)); var lineNo = 0;
            foreach (var line in warehouseGroup)
            {
                await InventoryItemProjectAccess.EnsureAsync(c, tx, CompanyId, line.ItemId, token);
                string? itemCode = null, itemName = null, unitCode = null, tracking = null; decimal unitCost = 0;
                await using (var item = new SqlCommand("SELECT ItemCode,ItemName,UnitCode,CostPrice,StockTrackingCode FROM dbo.TDIVItem I WITH(UPDLOCK,HOLDLOCK) WHERE I.CompanyID=@company AND I.ItemID=@item AND I.IsActive=1 AND I.ItemKindCode=N'GOODS' AND I.StockTrackingCode<>N'NONE' AND EXISTS(SELECT 1 FROM dbo.TDIVItemUsage U WHERE U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode IN(N'MATERIAL',N'SPARE_PART'))", c, tx))
                {
                    Add(item, "@company", SqlDbType.BigInt, CompanyId); Add(item, "@item", SqlDbType.BigInt, line.ItemId); await using var reader = await item.ExecuteReaderAsync(token);
                    if (await reader.ReadAsync(token)) { itemCode = reader.GetString(0); itemName = reader.GetString(1); unitCode = Text(reader, 2); unitCost = reader.GetDecimal(3); tracking = reader.GetString(4); }
                }
                if (itemCode is null) throw new InvalidOperationException($"ไม่พบอะไหล่ ItemID {line.ItemId} ใน Company นี้");
                var serials = (line.SerialInstanceIds ?? []).Distinct().ToArray();
                if (tracking == "SERIAL" && (line.Quantity != decimal.Truncate(line.Quantity) || serials.Length != (int)line.Quantity)) throw new InvalidOperationException($"อะไหล่ {itemCode} ต้องเลือก Serial ให้ครบตามจำนวน");
                if (tracking != "SERIAL" && serials.Length > 0) throw new InvalidOperationException($"อะไหล่ {itemCode} ไม่ได้ควบคุมแบบ Serial");
                lineNo++;
                await using var detail = new SqlCommand("INSERT dbo.TDIVStockIssueDetail(StockIssueID,[LineNo],ItemID,Quantity,Remark) OUTPUT INSERTED.StockIssueDetailID VALUES(@issue,@line,@item,@qty,N'เบิกใช้ในงานซ่อม')", c, tx);
                Add(detail, "@issue", SqlDbType.BigInt, issueId); Add(detail, "@line", SqlDbType.Int, lineNo); Add(detail, "@item", SqlDbType.BigInt, line.ItemId); Add(detail, "@qty", SqlDbType.Decimal, line.Quantity); var detailId = Convert.ToInt64(await detail.ExecuteScalarAsync(token));
                foreach (var serialId in serials)
                {
                    await using var serial = new SqlCommand("INSERT dbo.TDIVStockIssueSerial(StockIssueDetailID,ItemInstanceID) SELECT @detail,X.ItemInstanceID FROM dbo.TDIVItemInstance X WITH(UPDLOCK,HOLDLOCK) WHERE X.ItemInstanceID=@serial AND X.CompanyID=@company AND X.ItemID=@item AND X.WarehouseID=@warehouse AND X.StatusCode=N'IN_STOCK'; IF @@ROWCOUNT=0 THROW 52330,N'Invalid serial for service repair',1", c, tx);
                    Add(serial, "@detail", SqlDbType.BigInt, detailId); Add(serial, "@serial", SqlDbType.BigInt, serialId); Add(serial, "@company", SqlDbType.BigInt, CompanyId); Add(serial, "@item", SqlDbType.BigInt, line.ItemId); Add(serial, "@warehouse", SqlDbType.BigInt, warehouseGroup.Key); await serial.ExecuteNonQueryAsync(token);
                }
                await using (var balance = new SqlCommand("UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK) SET Quantity=Quantity-@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND WarehouseID=@warehouse AND ItemID=@item AND Quantity>=@qty; IF @@ROWCOUNT=0 THROW 52331,N'Insufficient warehouse stock',1; UPDATE dbo.TDIVItem SET StockBalance=StockBalance-@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ItemID=@item AND StockBalance>=@qty; IF @@ROWCOUNT=0 THROW 52331,N'Insufficient item stock',1", c, tx))
                { Add(balance, "@qty", SqlDbType.Decimal, line.Quantity); Add(balance, "@company", SqlDbType.BigInt, CompanyId); Add(balance, "@warehouse", SqlDbType.BigInt, warehouseGroup.Key); Add(balance, "@item", SqlDbType.BigInt, line.ItemId); await balance.ExecuteNonQueryAsync(token); }
                await using (var movement = new SqlCommand("INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@warehouse,@item,N'SERVICE_REQUEST',@request,@detail,N'ISSUE',-@qty,N'เบิกอะไหล่ใช้ในงานซ่อม',@user)", c, tx))
                { Add(movement, "@company", SqlDbType.BigInt, CompanyId); Add(movement, "@warehouse", SqlDbType.BigInt, warehouseGroup.Key); Add(movement, "@item", SqlDbType.BigInt, line.ItemId); Add(movement, "@request", SqlDbType.BigInt, requestId); Add(movement, "@detail", SqlDbType.BigInt, detailId); Add(movement, "@qty", SqlDbType.Decimal, line.Quantity); Add(movement, "@user", SqlDbType.BigInt, UserId); await movement.ExecuteNonQueryAsync(token); }
                if (serials.Length > 0)
                {
                    await using var updateSerial = new SqlCommand("UPDATE X SET StatusCode=N'ISSUED',WarehouseID=NULL,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user FROM dbo.TDIVItemInstance X JOIN dbo.TDIVStockIssueSerial S ON S.ItemInstanceID=X.ItemInstanceID WHERE S.StockIssueDetailID=@detail AND X.CompanyID=@company AND X.StatusCode=N'IN_STOCK'; INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy) SELECT @company,S.ItemInstanceID,N'IN_STOCK',N'ISSUED',N'SERVICE_REQUEST',@request,@detail,N'เบิกอะไหล่ใช้ในงานซ่อม',@user FROM dbo.TDIVStockIssueSerial S WHERE S.StockIssueDetailID=@detail", c, tx);
                    Add(updateSerial, "@user", SqlDbType.BigInt, UserId); Add(updateSerial, "@detail", SqlDbType.BigInt, detailId); Add(updateSerial, "@company", SqlDbType.BigInt, CompanyId); Add(updateSerial, "@request", SqlDbType.BigInt, requestId); await updateSerial.ExecuteNonQueryAsync(token);
                }
                await using var part = new SqlCommand("INSERT dbo.TDADServiceRequestPart(CompanyID,RequestID,StockIssueID,StockIssueDetailID,WarehouseID,ItemID,ItemCodeSnapshot,ItemNameSnapshot,UnitCodeSnapshot,Quantity,UnitCostSnapshot,CreateBy) VALUES(@company,@request,@issue,@detail,@warehouse,@item,@code,@name,@unit,@qty,@cost,@user)", c, tx);
                Add(part, "@company", SqlDbType.BigInt, CompanyId); Add(part, "@request", SqlDbType.BigInt, requestId); Add(part, "@issue", SqlDbType.BigInt, issueId); Add(part, "@detail", SqlDbType.BigInt, detailId); Add(part, "@warehouse", SqlDbType.BigInt, warehouseGroup.Key); Add(part, "@item", SqlDbType.BigInt, line.ItemId); Add(part, "@code", SqlDbType.NVarChar, itemCode, 50); Add(part, "@name", SqlDbType.NVarChar, itemName, 255); Add(part, "@unit", SqlDbType.NVarChar, unitCode, 50); Add(part, "@qty", SqlDbType.Decimal, line.Quantity); Add(part, "@cost", SqlDbType.Decimal, unitCost); Add(part, "@user", SqlDbType.BigInt, UserId); await part.ExecuteNonQueryAsync(token);
            }
        }
    }
    private async Task UpdateStatus(SqlConnection c, SqlTransaction tx, long id, string status, string fields, CancellationToken token, string? detail = null, string? reason = null)
    {
        var sql = $"UPDATE dbo.TDADServiceRequest SET StatusCode=N'{status}',{fields},UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND RequestID=@id AND IsActive=1";
        await using var q = new SqlCommand(sql, c, tx); Add(q, "@user", SqlDbType.BigInt, UserId); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id); Add(q, "@detail", SqlDbType.NVarChar, detail, 2000); Add(q, "@reason", SqlDbType.NVarChar, reason, 1000); await q.ExecuteNonQueryAsync(token);
    }

    [HttpPost]
    public Task<IActionResult> Create(CreateRequest request, CancellationToken token) =>
        Save(request, false, token);

    [HttpPost("self")]
    public Task<IActionResult> CreateSelf(CreateRequest request, CancellationToken token) =>
        Save(request, true, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Edit(long id, EditRequest x, CancellationToken token) =>
        EditCore(id, x, false, token);

    [HttpPut("self/{id:long}")]
    public Task<IActionResult> EditSelf(long id, EditRequest x, CancellationToken token) =>
        EditCore(id, x, true, token);

    private async Task<IActionResult> EditCore(long id, EditRequest x, bool self, CancellationToken token)
    {
        await using var c = await Open(token);
        var menu = self ? "20001" : "15001";
        if (!await InService(c, token) || await ScreenType(c, menu, token) != 1 ||
            !await Allowed(c, menu, "EDIT", token)) return Forbid();
        var subject = x.Subject?.Trim();
        var detail = x.Detail?.Trim();
        if (x.PriorityCode is not null && x.PriorityCode is not ("0" or "1" or "2")) return BadRequest(new { message = "ระดับงานไม่ถูกต้อง" });
        if (string.IsNullOrWhiteSpace(subject) || subject.Length > 200 ||
            string.IsNullOrWhiteSpace(detail) || detail.Length > 2000)
            return BadRequest(new { message = "กรุณาระบุหัวข้อและรายละเอียดตามความยาวที่กำหนด" });
        if (!TryRowVersion(x.RowVersion, out var version))
            return BadRequest(new { message = "ข้อมูลรุ่นรายการไม่ถูกต้อง" });
        string? equipmentCode = null, equipmentName = null;
        if (x.UpdateEquipment && x.EquipmentItemId.HasValue)
        {
            await using var check = new SqlCommand("SELECT I.ItemCode,I.ItemName FROM dbo.TDIVItem I JOIN dbo.TDIVItemUsage U ON U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode=N'EQUIPMENT' WHERE I.CompanyID=@company AND I.ItemID=@id AND I.IsActive=1", c);
            Add(check, "@company", SqlDbType.BigInt, CompanyId);
            Add(check, "@id", SqlDbType.BigInt, x.EquipmentItemId);
            await using var equipment = await check.ExecuteReaderAsync(token);
            if (!await equipment.ReadAsync(token)) return BadRequest(new { message = "ข้อมูลอุปกรณ์ไม่ถูกต้อง", description = "กรุณาเลือกอุปกรณ์ที่เปิดใช้งานในบริษัทนี้" });
            equipmentCode = equipment.GetString(0); equipmentName = equipment.GetString(1);
        }
        if (x.UpdateEquipment && !x.EquipmentItemId.HasValue && (await ReadSettings(c, token)).RequireEquipment)
            return BadRequest(new { message = "กรุณาเลือกอุปกรณ์" });
        long? equipmentInstanceId = null;
        if (x.UpdateSerial && !string.IsNullOrWhiteSpace(x.EquipmentSerial))
        {
            if (!x.EquipmentItemId.HasValue || x.EquipmentSerial.Trim().Length > 200)
                return BadRequest(new { message = "กรุณาเลือกอุปกรณ์และระบุ Serial ที่ถูกต้อง" });
            if (!await Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedForProjectAsync(c, User, "LAOO_STOCK", "08006", "VIEW", token)) return Forbid();
            equipmentInstanceId = await FindAccessibleEquipmentSerial(x.EquipmentSerial.Trim(), x.EquipmentItemId.Value, token);
            if (!equipmentInstanceId.HasValue) return BadRequest(new { message = "ไม่พบ Serial ของอุปกรณ์ที่เลือก" });
        }
        await using var q = new SqlCommand($$"""
UPDATE R SET Subject=@subject,Detail=@detail,PriorityCode=COALESCE(@priority,PriorityCode),
    EquipmentItemID=CASE WHEN @updateEquipment=1 THEN @equipmentId ELSE EquipmentItemID END,
    EquipmentInstanceID=CASE WHEN @updateSerial=1 THEN @equipmentInstance WHEN @updateEquipment=1 AND ISNULL(EquipmentItemID,0)<>ISNULL(@equipmentId,0) THEN NULL ELSE EquipmentInstanceID END,
    EquipmentCodeSnapshot=CASE WHEN @updateEquipment=1 THEN @equipmentCode ELSE EquipmentCodeSnapshot END,
    EquipmentNameSnapshot=CASE WHEN @updateEquipment=1 THEN @equipmentName ELSE EquipmentNameSnapshot END,
    UpdateDate=SYSUTCDATETIME(),UpdateBy=@user
FROM dbo.TDADServiceRequest R WHERE CompanyID=@company AND RequestID=@id AND IsActive=1 AND StatusCode=N'NEW'
    AND RowVersion=@version AND (@self=0 OR ({{MenuViewPredicate}} AND {{MenuEditPredicate}}));
""", c);
        Add(q, "@subject", SqlDbType.NVarChar, subject, 200);
        Add(q, "@detail", SqlDbType.NVarChar, detail, 2000);
        Add(q, "@priority", SqlDbType.NVarChar, x.PriorityCode, 1);
        Add(q, "@updateEquipment", SqlDbType.Bit, x.UpdateEquipment);
        Add(q, "@equipmentId", SqlDbType.BigInt, x.EquipmentItemId);
        Add(q, "@updateSerial", SqlDbType.Bit, x.UpdateSerial);
        Add(q, "@equipmentInstance", SqlDbType.BigInt, equipmentInstanceId);
        Add(q, "@equipmentCode", SqlDbType.NVarChar, equipmentCode, 50);
        Add(q, "@equipmentName", SqlDbType.NVarChar, equipmentName, 200);
        Add(q, "@user", SqlDbType.BigInt, UserId);
        Add(q, "@company", SqlDbType.BigInt, CompanyId);
        Add(q, "@id", SqlDbType.BigInt, id);
        Add(q, "@version", SqlDbType.VarBinary, version, 8);
        Add(q, "@self", SqlDbType.Bit, self);
        if (await q.ExecuteNonQueryAsync(token) == 1) return NoContent();
        return await RequestExists(c, id, self, token)
            ? Conflict(new { message = "แก้ไขได้เฉพาะใบงานใหม่ที่ยังไม่เปลี่ยนแปลง" })
            : NotFound();
    }

    [HttpDelete("{id:long}")]
    public Task<IActionResult> Delete(long id, [FromQuery] string? rowVersion, CancellationToken token) =>
        DeleteCore(id, rowVersion, false, token);

    [HttpDelete("self/{id:long}")]
    public Task<IActionResult> DeleteSelf(long id, [FromQuery] string? rowVersion, CancellationToken token) =>
        DeleteCore(id, rowVersion, true, token);

    private async Task<IActionResult> DeleteCore(long id, string? rowVersion, bool self, CancellationToken token)
    {
        await using var c = await Open(token);
        var menu = self ? "20001" : "15001";
        if (!await InService(c, token) || await ScreenType(c, menu, token) != 1 ||
            !await Allowed(c, menu, "DELETE", token)) return Forbid();
        if (!TryRowVersion(rowVersion, out var version))
            return BadRequest(new { message = "ข้อมูลรุ่นรายการไม่ถูกต้อง" });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        var paths = new List<string>();
        await using (var q = new SqlCommand($$"""
SELECT StatusCode,RowVersion FROM dbo.TDADServiceRequest R WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@company AND RequestID=@id AND IsActive=1
    AND (@self=0 OR ({{MenuViewPredicate}} AND {{MenuDeletePredicate}}));
""", c, tx))
        {
            Add(q, "@company", SqlDbType.BigInt, CompanyId);
            Add(q, "@id", SqlDbType.BigInt, id);
            Add(q, "@self", SqlDbType.Bit, self);
            Add(q, "@user", SqlDbType.BigInt, UserId);
            await using var r = await q.ExecuteReaderAsync(token);
            if (!await r.ReadAsync(token)) return NotFound();
            if (r.GetString(0) != "NEW" || !((byte[])r[1]).SequenceEqual(version))
                return Conflict(new { message = "ลบได้เฉพาะใบงานใหม่ที่ยังไม่เปลี่ยนแปลง" });
        }
        await using (var q = new SqlCommand("""
SELECT COUNT_BIG(*) FROM dbo.TDADServiceRequestPart
WHERE CompanyID=@company AND RequestID=@id;
""", c, tx))
        {
            Add(q, "@company", SqlDbType.BigInt, CompanyId);
            Add(q, "@id", SqlDbType.BigInt, id);
            if (Convert.ToInt64(await q.ExecuteScalarAsync(token)) > 0)
                return Conflict(new { message = "ใบงานนี้ถูกนำไปใช้แล้ว ไม่สามารถลบได้" });
        }
        await using (var q = new SqlCommand("""
SELECT StoredPath FROM dbo.TDADServiceRequestAttachment
WHERE CompanyID=@company AND RequestID=@id;
""", c, tx))
        {
            Add(q, "@company", SqlDbType.BigInt, CompanyId);
            Add(q, "@id", SqlDbType.BigInt, id);
            await using var r = await q.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) paths.Add(r.GetString(0));
        }
        await using (var q = new SqlCommand($$"""
DELETE FROM dbo.TDADServiceRequestAttachment WHERE CompanyID=@company AND RequestID=@id;
DELETE R FROM dbo.TDADServiceRequest R WHERE CompanyID=@company AND RequestID=@id
    AND StatusCode=N'NEW' AND RowVersion=@version
    AND (@self=0 OR ({{MenuViewPredicate}} AND {{MenuDeletePredicate}}));
IF @@ROWCOUNT <> 1 THROW 52973, 'REQUEST_DELETE_CONFLICT', 1;
""", c, tx))
        {
            Add(q, "@company", SqlDbType.BigInt, CompanyId);
            Add(q, "@id", SqlDbType.BigInt, id);
            Add(q, "@version", SqlDbType.VarBinary, version, 8);
            Add(q, "@self", SqlDbType.Bit, self);
            Add(q, "@user", SqlDbType.BigInt, UserId);
            try { await q.ExecuteNonQueryAsync(token); }
            catch (SqlException e) when (e.Number == 52973)
            {
                await tx.RollbackAsync(token);
                return Conflict(new { message = "ไม่สามารถลบใบแจ้งซ่อมได้", description = "รายการหรือสิทธิ์เปลี่ยนแปลง กรุณาโหลดข้อมูลใหม่และลองอีกครั้ง" });
            }
        }
        await tx.CommitAsync(token);
        foreach (var path in paths) TryDelete(path);
        return NoContent();
    }

    private async Task<bool> RequestExists(SqlConnection c, long id, bool self, CancellationToken token)
    {
        await using var q = new SqlCommand(
            "SELECT COUNT_BIG(*) FROM dbo.TDADServiceRequest WHERE CompanyID=@company AND RequestID=@id AND IsActive=1 AND (@self=0 OR CreateBy=@user)", c);
        Add(q, "@company", SqlDbType.BigInt, CompanyId);
        Add(q, "@id", SqlDbType.BigInt, id);
        Add(q, "@self", SqlDbType.Bit, self);
        Add(q, "@user", SqlDbType.BigInt, UserId);
        return Convert.ToInt64(await q.ExecuteScalarAsync(token)) > 0;
    }

    private static bool TryRowVersion(string? encoded, out byte[] version)
    {
        try
        {
            version = Convert.FromBase64String(encoded ?? string.Empty);
            return version.Length == 8;
        }
        catch (FormatException)
        {
            version = [];
            return false;
        }
    }

    public sealed record AiImage(string? FileName, string? DataBase64);
    public sealed record AiCreateRequest(string? Subject, string? Detail, Guid RequestKey, long? EquipmentItemId, IReadOnlyList<AiImage>? Images, string? EquipmentSerial = null);
    private sealed record AiPreparedImage(string Name, ProcessedImage Image);

    [HttpPost("assistant/self"), RequestSizeLimit(36_000_000)]
    public async Task<IActionResult> AssistantCreate(AiCreateRequest request, CancellationToken token)
    {
        if (request.RequestKey == Guid.Empty) return BadRequest(new { message = "ไม่พบรหัสยืนยันรายการ" });
        await using var db = await Open(token);
        if (!await LaooApi.Services.Assistant.AssistantCapabilityAccess.IsAllowed(db, User, "repair.create_own", token)) return Forbid();
        await using (var schema = new SqlCommand("SELECT CASE WHEN COL_LENGTH(N'dbo.TDADServiceRequest',N'AiRequestKey') IS NULL THEN 0 ELSE 1 END", db))
            if (Convert.ToInt32(await schema.ExecuteScalarAsync(token)) == 0)
                return StatusCode(503, new { message = "การแจ้งซ่อมผ่าน AI ยังไม่พร้อม", description = "กรุณาใช้หน้าแจ้งซ่อมปกติ" });
        var settings = await ReadSettings(db, token);
        var images = new List<AiPreparedImage>();
        long totalBytes = 0;
        if (request.Images?.Count > 10) return BadRequest(new { message = "แนบรูปได้ไม่เกิน 10 รูป" });
        foreach (var image in request.Images ?? Array.Empty<AiImage>())
        {
            byte[] bytes;
            try { bytes = Convert.FromBase64String(image.DataBase64 ?? ""); }
            catch (FormatException) { return BadRequest(new { message = "ข้อมูลรูปภาพไม่ถูกต้อง" }); }
            totalBytes += bytes.Length;
            if (bytes.Length == 0 || totalBytes > MaxIncomingAttachmentBytes) return BadRequest(new { message = "ไฟล์รูปต้นฉบับรวมกันต้องไม่เกิน 25 MB" });
            await using var stream = new MemoryStream(bytes);
            var file = new FormFile(stream, 0, bytes.Length, "file", image.FileName ?? "") { Headers = new HeaderDictionary(), ContentType = "application/octet-stream" };
            var processed = await ProcessImage(file, token);
            if (processed.Error is not null) return BadRequest(new { message = processed.Error });
            images.Add(new AiPreparedImage(SafeOriginalName(file.FileName), processed));
        }
        if (settings.AttachmentRequired && images.Count == 0) return BadRequest(new { message = "บริษัทกำหนดให้แนบรูปก่อนแจ้งซ่อม" });
        await using (var subject = new SqlCommand("SELECT COUNT_BIG(*) FROM dbo.TDADServiceRequestSubject WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND IsActive=1 AND Name=@name", db))
        {
            Add(subject, "@company", SqlDbType.BigInt, CompanyId);
            Add(subject, "@name", SqlDbType.NVarChar, request.Subject?.Trim(), 200);
            if (Convert.ToInt64(await subject.ExecuteScalarAsync(token)) != 1)
                return BadRequest(new { message = "ไม่พบหัวข้องานซ่อม", description = "กรุณาเลือกหัวข้อที่เปิดใช้งาน หรือใช้หน้าแจ้งซ่อมปกติ" });
        }
        return await Save(new CreateRequest(null, null, request.EquipmentItemId, request.Subject, request.Detail, EquipmentSerial: request.EquipmentSerial), true, token, request.RequestKey, images);
    }

    private async Task<IActionResult> Save(CreateRequest x, bool self, CancellationToken token, Guid? aiRequestKey = null, IReadOnlyList<AiPreparedImage>? aiImages = null)
    {
        if (x.PriorityCode is not null && x.PriorityCode is not ("0" or "1" or "2")) return BadRequest(new { message = "ระดับงานไม่ถูกต้อง" });
        await using var c = await Open(token);
        var screen = self ? "20001" : "15001";
        if (!await InService(c, token) || await ScreenType(c, screen, token) != 1 || !await Allowed(c, screen, "CREATE", token)) return Forbid();
        var settings = await ReadSettings(c, token);
        if (aiRequestKey.HasValue && settings.AttachmentRequired && (aiImages?.Count ?? 0) == 0) return BadRequest(new { message = "บริษัทกำหนดให้แนบรูปก่อนแจ้งซ่อม" });
        if (!settings.ServiceEnabled)
            return BadRequest(new { message = "ระบบบริการปิดใช้งาน", description = "กรุณาติดต่อผู้ดูแลระบบเพื่อเปิดใช้งานระบบบริการ" });
        if (string.IsNullOrWhiteSpace(x.Subject) || string.IsNullOrWhiteSpace(x.Detail))
            return BadRequest(new { message = "กรุณาระบุหัวข้อและรายละเอียด", description = "หัวข้อและรายละเอียดเป็นข้อมูลบังคับ" });

        var type = await BusinessType(c, token);
        var qr = string.IsNullOrWhiteSpace(x.QrToken) ? null : await ResolveQrContext(c, x.QrToken, token);
        if (!string.IsNullOrWhiteSpace(x.QrToken) && qr is null)
            return BadRequest(new { message = "QR Code ไม่ถูกต้อง", description = "QR นี้ปิดใช้งาน ไม่พบข้อมูล หรือไม่ได้อยู่ใน Company ปัจจุบัน" });
        var equipmentItemId = qr?.ItemId ?? x.EquipmentItemId;
        long? equipmentInstanceId = qr?.InstanceId;
        if (!string.IsNullOrWhiteSpace(x.EquipmentSerial))
        {
            if (!equipmentItemId.HasValue || x.EquipmentSerial.Trim().Length > 200)
                return BadRequest(new { message = "กรุณาเลือกอุปกรณ์และระบุ Serial ที่ถูกต้อง" });
            if (!await Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedForProjectAsync(c, User, "LAOO_STOCK", "08006", "VIEW", token)) return Forbid();
            var selectedInstanceId = await FindAccessibleEquipmentSerial(x.EquipmentSerial.Trim(), equipmentItemId.Value, token);
            if (!selectedInstanceId.HasValue || (qr is not null && qr.InstanceId != selectedInstanceId.Value))
                return BadRequest(new { message = "ไม่พบ Serial ของอุปกรณ์ที่เลือก", description = "ตรวจสอบ Serial และสิทธิ์เข้าถึงคลังสินค้า" });
            equipmentInstanceId = selectedInstanceId;
        }
        if (settings.RequireEquipment && !equipmentItemId.HasValue)
            return BadRequest(new { message = "กรุณาเลือกอุปกรณ์", description = "รายการแจ้งซ่อมต้องระบุอุปกรณ์ที่ใช้กับระบบ Service" });
        string? equipmentCode = null, equipmentName = null;
        if (equipmentItemId.HasValue)
        {
            await using var equipmentCheck = new SqlCommand("SELECT I.ItemCode,I.ItemName FROM dbo.TDIVItem I JOIN dbo.TDIVItemUsage U ON U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode=N'EQUIPMENT' WHERE I.CompanyID=@company AND I.ItemID=@id AND I.IsActive=1", c);
            Add(equipmentCheck, "@company", SqlDbType.BigInt, CompanyId); Add(equipmentCheck, "@id", SqlDbType.BigInt, equipmentItemId);
            await using var equipmentReader = await equipmentCheck.ExecuteReaderAsync(token);
            if (!await equipmentReader.ReadAsync(token)) return BadRequest(new { message = "ข้อมูลอุปกรณ์ไม่ถูกต้อง", description = "ไม่พบอุปกรณ์ที่ใช้งานได้ในระบบ Service" });
            equipmentCode = equipmentReader.GetString(0); equipmentName = equipmentReader.GetString(1);
        }
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        var savedAiPaths = new List<string>();
        try
        {
            await using (var numberLock = new SqlCommand(Laoo.Shared.Contracts.ServiceRequestNumbering.AcquireLockSql, c, tx))
            {
                Add(numberLock, "@company", SqlDbType.BigInt, CompanyId);
                await numberLock.ExecuteNonQueryAsync(token);
            }
            if (aiRequestKey.HasValue)
            {
                await using var existing = new SqlCommand("SELECT RequestID,RequestNo,RequestDate FROM dbo.TDADServiceRequest WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND CreateBy=@user AND AiRequestKey=@key", c, tx);
                Add(existing, "@company", SqlDbType.BigInt, CompanyId); Add(existing, "@user", SqlDbType.BigInt, UserId); Add(existing, "@key", SqlDbType.UniqueIdentifier, aiRequestKey);
                await using var reader = await existing.ExecuteReaderAsync(token);
                if (await reader.ReadAsync(token))
                {
                    var existingId = reader.GetInt64(0); var existingNo = reader.GetString(1); var existingDate = DateTime.SpecifyKind(reader.GetDateTime(2), DateTimeKind.Utc);
                    await reader.DisposeAsync(); await tx.CommitAsync(token);
                    return Ok(new { requestId = existingId, requestNo = existingNo, requestDate = existingDate, duplicate = true });
                }
            }
            var resolved = await Resolve(c, tx, x, type, self, token);
            if (resolved is null)
                return BadRequest(new { message = "ผู้แจ้งไม่ถูกต้อง", description = "ไม่พบข้อมูลผู้แจ้งที่ใช้งานอยู่ใน Company นี้" });
            if (!settings.AllowWalkIn && resolved.Type == "SERVICE_CUSTOMER")
                return BadRequest(new { message = "ไม่อนุญาตผู้แจ้ง Walk-in", description = "ผู้ดูแลระบบปิดการรับแจ้งจากลูกค้าภายนอกไว้" });

            var nextNo = Laoo.Shared.Contracts.ServiceRequestNumbering.AllocateSql + "\nSELECT @requestNo;";
            await using var no = new SqlCommand(nextNo, c, tx);
            Add(no, "@company", SqlDbType.BigInt, CompanyId);
            var requestNo = Convert.ToString(await no.ExecuteScalarAsync(token))!;
            var insert = """
INSERT dbo.TDADServiceRequest
(CompanyID,RequestNo,RequesterType,RequesterID,RequesterNameSnapshot,RequesterPhoneSnapshot,RequesterEmailSnapshot,
 ServiceCustomerID,ResidentID,TenantID,TenantContactID,RoomID,HouseID,LocationSnapshot,EquipmentItemID,EquipmentInstanceID,EquipmentCodeSnapshot,EquipmentNameSnapshot,Subject,Detail,PriorityCode,RequestChannelCode,CreateBy)
OUTPUT INSERTED.RequestID, INSERTED.RequestDate
VALUES(@company,@no,@rtype,@rid,@name,@phone,@email,@sc,@res,@tenant,@contact,@room,@house,@location,@equipment,@equipmentInstance,@equipmentCode,@equipmentName,@subject,@detail,@priority,@channel,@user);
""";
            if (aiRequestKey.HasValue) insert = insert.Replace("RequestChannelCode,CreateBy)", "RequestChannelCode,CreateBy,AiRequestKey)").Replace("@priority,@channel,@user)", "@priority,@channel,@user,@aiKey)");
            await using var cmd = new SqlCommand(insert, c, tx);
            Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@no", SqlDbType.NVarChar, requestNo, 30);
            Add(cmd, "@rtype", SqlDbType.NVarChar, resolved.Type, 30); Add(cmd, "@rid", SqlDbType.BigInt, resolved.PersonId);
            Add(cmd, "@name", SqlDbType.NVarChar, resolved.Name, 200); Add(cmd, "@phone", SqlDbType.NVarChar, resolved.Phone, 50); Add(cmd, "@email", SqlDbType.NVarChar, resolved.Email, 320);
            Add(cmd, "@sc", SqlDbType.BigInt, resolved.ServiceCustomerId); Add(cmd, "@res", SqlDbType.BigInt, resolved.ResidentId); Add(cmd, "@tenant", SqlDbType.BigInt, resolved.TenantId); Add(cmd, "@contact", SqlDbType.BigInt, resolved.ContactId);
            Add(cmd, "@equipmentInstance", SqlDbType.BigInt, equipmentInstanceId);
            Add(cmd, "@room", SqlDbType.BigInt, resolved.RoomId); Add(cmd, "@house", SqlDbType.BigInt, resolved.HouseId); Add(cmd, "@location", SqlDbType.NVarChar, qr?.LocationSnapshot ?? resolved.Location, 500); Add(cmd, "@equipment", SqlDbType.BigInt, equipmentItemId); Add(cmd, "@equipmentCode", SqlDbType.NVarChar, equipmentCode, 50); Add(cmd, "@equipmentName", SqlDbType.NVarChar, equipmentName, 200);
            Add(cmd, "@subject", SqlDbType.NVarChar, x.Subject.Trim(), 200); Add(cmd, "@detail", SqlDbType.NVarChar, x.Detail.Trim(), 2000); Add(cmd, "@user", SqlDbType.BigInt, UserId);
            Add(cmd, "@priority", SqlDbType.NVarChar, x.PriorityCode ?? "0", 1);
            Add(cmd, "@channel", SqlDbType.NVarChar, aiRequestKey.HasValue ? "2" : self || (PersonId.HasValue && resolved.PersonId == PersonId) ? "0" : "1", 1);
            Add(cmd, "@aiKey", SqlDbType.UniqueIdentifier, aiRequestKey);
            long id; DateTime requestDate;
            await using (var inserted = await cmd.ExecuteReaderAsync(token))
            {
                await inserted.ReadAsync(token);
                id = inserted.GetInt64(0); requestDate = DateTime.SpecifyKind(inserted.GetDateTime(1), DateTimeKind.Utc);
            }
            foreach (var attachment in aiImages ?? Array.Empty<AiPreparedImage>())
            {
                var p = attachment.Image;
                const string sql = "INSERT dbo.TDADServiceRequestAttachment(CompanyID,RequestID,FileName,StoredPath,ContentType,FileSize,ImageWidth,ImageHeight,CreateBy) OUTPUT INSERTED.AttachmentID VALUES(@company,@request,@name,N'',@type,@size,@width,@height,@user)";
                await using var a = new SqlCommand(sql, c, tx);
                Add(a, "@company", SqlDbType.BigInt, CompanyId); Add(a, "@request", SqlDbType.BigInt, id); Add(a, "@name", SqlDbType.NVarChar, attachment.Name, 255); Add(a, "@type", SqlDbType.NVarChar, p.ContentType, 100); Add(a, "@size", SqlDbType.BigInt, p.Bytes.Length); Add(a, "@width", SqlDbType.Int, p.Width); Add(a, "@height", SqlDbType.Int, p.Height); Add(a, "@user", SqlDbType.BigInt, UserId);
                var attachmentId = Convert.ToInt64(await a.ExecuteScalarAsync(token));
                var path = $"uploads/service-requests/{CompanyId}/{id}/{attachmentId}{p.Extension}";
                var fullPath = SafeFilePath(path) ?? throw new InvalidOperationException("Invalid attachment path");
                savedAiPaths.Add(path); Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
                await System.IO.File.WriteAllBytesAsync(fullPath, p.Bytes, token);
                await using var update = new SqlCommand("UPDATE dbo.TDADServiceRequestAttachment SET StoredPath=@path,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND AttachmentID=@attachment", c, tx);
                Add(update, "@path", SqlDbType.NVarChar, path, 500); Add(update, "@user", SqlDbType.BigInt, UserId); Add(update, "@company", SqlDbType.BigInt, CompanyId); Add(update, "@attachment", SqlDbType.BigInt, attachmentId); await update.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return Ok(new { requestId = id, requestNo, requestDate });
        }
        catch (SqlException ex) when (ex.Number == 53965)
        {
            await tx.RollbackAsync(token);
            foreach (var path in savedAiPaths) TryDelete(path);
            return Conflict(new { message = "ออกเลขที่ใบแจ้งซ่อมไม่สำเร็จ", description = "กรุณาตรวจสอบรูปแบบและจำนวนหลักเลขลำดับ หรือติดต่อผู้ดูแลระบบ" });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627)
        {
            await tx.RollbackAsync(token);
            foreach (var path in savedAiPaths) TryDelete(path);
            return Conflict(new { message = "บันทึกไม่สำเร็จ", description = "เลขที่ใบแจ้งซ่อมซ้ำ กรุณาลองใหม่" });
        }
        catch
        {
            await tx.RollbackAsync(token);
            foreach (var path in savedAiPaths) TryDelete(path);
            throw;
        }
    }

    private async Task<Resolved?> Resolve(SqlConnection c, SqlTransaction tx, CreateRequest x, string businessType, bool self, CancellationToken token)
    {
        var requesterType = self ? await SelfType(c, tx, businessType, token) : x.RequesterType?.Trim().ToUpperInvariant();
        var id = self ? PersonId : x.RequesterId;
        if (requesterType is null || id is null) return null;

        if (requesterType == "SERVICE_CUSTOMER")
        {
            const string sql = "SELECT P.PersonID,P.FullName,P.Mobile,P.Email,S.ServiceCustomerID FROM dbo.TDADServiceCustomer S JOIN dbo.TDADPerson P ON P.CompanyID=S.CompanyID AND P.PersonID=S.PersonID WHERE S.CompanyID=@company AND S.PersonID=@id AND S.IsActive=1 AND P.IsActive=1";
            await using var q = new SqlCommand(sql, c, tx); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id);
            await using var r = await q.ExecuteReaderAsync(token);
            return await r.ReadAsync(token) ? new("SERVICE_CUSTOMER", r.GetInt64(0), r.GetString(1), Text(r, 2), Text(r, 3), r.GetInt64(4), null, null, null, null, null, null) : null;
        }

        if (requesterType == "RESIDENT")
        {
            const string sql = """
SELECT P.PersonID,P.FullName,P.Mobile,P.Email,R.ResidentID,R.RoomID,R.HouseID,
 CASE WHEN R.RoomID IS NOT NULL THEN CONCAT(B.BuildingNameTH,N' / ',F.FloorNameTH,N' / ',RM.RoomCode)
      ELSE CONCAT(L.LaneName,N' / ',H.HouseNo) END
FROM dbo.TDADResident R JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID
LEFT JOIN dbo.TDADRoom RM ON RM.CompanyID=R.CompanyID AND RM.RoomID=R.RoomID
LEFT JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID
LEFT JOIN dbo.TDADFloor F ON F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID
LEFT JOIN dbo.TDADVillageHouse H ON H.CompanyID=R.CompanyID AND H.HouseID=R.HouseID
LEFT JOIN dbo.TDADVillageLane L ON L.CompanyID=H.CompanyID AND L.LaneID=H.LaneID
WHERE R.CompanyID=@company AND R.ResidentID=@id AND R.IsActive=1 AND P.IsActive=1
AND ((@business=N'DORMITORY' AND R.RoomID IS NOT NULL) OR (@business=N'VILLAGE' AND R.HouseID IS NOT NULL));
""";
            await using var q = new SqlCommand(sql, c, tx); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id); Add(q, "@business", SqlDbType.NVarChar, businessType, 30);
            await using var r = await q.ExecuteReaderAsync(token);
            return await r.ReadAsync(token) ? new("RESIDENT", r.GetInt64(0), r.GetString(1), Text(r, 2), Text(r, 3), null, r.GetInt64(4), null, null, Long(r, 5), Long(r, 6), Text(r, 7)) : null;
        }

        if (requesterType == "TENANT_CONTACT" && businessType == CompanyBusinessType.RentalOffice)
        {
            const string sql = """
SELECT P.PersonID,C.ContactName,C.Phone,C.Email,C.TenantContactID,T.TenantID,T.RoomID,
 CONCAT(T.TenantCompanyName,N' / ',B.BuildingNameTH,N' / ',F.FloorNameTH,N' / ',RM.RoomCode)
FROM dbo.TDADRentalOfficeTenantContact C JOIN dbo.TDADRentalOfficeTenant T ON T.CompanyID=C.CompanyID AND T.TenantID=C.TenantID
LEFT JOIN dbo.TDADRoom RM ON RM.CompanyID=T.CompanyID AND RM.RoomID=T.RoomID
LEFT JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID
LEFT JOIN dbo.TDADFloor F ON F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID
LEFT JOIN dbo.TDADPerson P ON P.CompanyID=C.CompanyID AND P.PersonID=C.PersonID
WHERE C.CompanyID=@company AND (C.TenantContactID=@id OR C.PersonID=@id) AND C.IsActive=1 AND T.IsActive=1;
""";
            await using var q = new SqlCommand(sql, c, tx); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id);
            await using var r = await q.ExecuteReaderAsync(token);
            return await r.ReadAsync(token) ? new("TENANT_CONTACT", Long(r, 0) ?? 0, r.GetString(1), Text(r, 2), Text(r, 3), null, null, r.GetInt64(5), r.GetInt64(4), Long(r, 6), null, Text(r, 7)) : null;
        }

        if (requesterType == "EMPLOYEE")
        {
            const string sql = "SELECT P.PersonID,P.FullName,P.Mobile,P.Email FROM dbo.TDADEmployee E JOIN dbo.TDADPerson P ON P.CompanyID=E.CompanyID AND P.PersonID=E.PersonID WHERE E.CompanyID=@company AND E.PersonID=@id AND E.IsActive=1 AND P.IsActive=1";
            await using var q = new SqlCommand(sql, c, tx); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id);
            await using var r = await q.ExecuteReaderAsync(token);
            if (await r.ReadAsync(token)) return new("EMPLOYEE", r.GetInt64(0), r.GetString(1), Text(r, 2), Text(r, 3), null, null, null, null, null, null, null);
        }
        return null;
    }

    private async Task<string?> SelfType(SqlConnection c, SqlTransaction tx, string businessType, CancellationToken token)
    {
        if (!PersonId.HasValue) return null;
        const string sql = "SELECT CASE WHEN @business IN(N'DORMITORY',N'VILLAGE') AND EXISTS(SELECT 1 FROM dbo.TDADResident WHERE CompanyID=@company AND PersonID=@person AND IsActive=1) THEN N'RESIDENT' WHEN @business=N'RENTAL_OFFICE' AND EXISTS(SELECT 1 FROM dbo.TDADRentalOfficeTenantContact WHERE CompanyID=@company AND PersonID=@person AND IsActive=1) THEN N'TENANT_CONTACT' WHEN EXISTS(SELECT 1 FROM dbo.TDADServiceCustomer WHERE CompanyID=@company AND PersonID=@person AND IsActive=1) THEN N'SERVICE_CUSTOMER' ELSE N'EMPLOYEE' END";
        await using var q = new SqlCommand(sql, c, tx); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@person", SqlDbType.BigInt, PersonId); Add(q, "@business", SqlDbType.NVarChar, businessType, 30);
        return Convert.ToString(await q.ExecuteScalarAsync(token));
    }

    private async Task<List<object>> ReadRequesterRows(SqlCommand cmd, string q, CancellationToken token)
    {
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@q", SqlDbType.NVarChar, q, 200);
        var rows = new List<object>(); await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) rows.Add(new { id = r.GetInt64(0), requesterType = r.GetString(1), name = r.GetString(2), phone = Text(r, 3), email = Text(r, 4), locationSnapshot = Text(r, 5), nickName = r.FieldCount > 6 ? Text(r, 6) : null });
        return rows;
    }

    private async Task<bool> InService(SqlConnection c, CancellationToken t) =>
        CompanyId > 0 &&
        (await Allowed(c, "15001", "VIEW", t) ||
         await Allowed(c, "17001", "VIEW", t) ||
         await Allowed(c, "17002", "VIEW", t) ||
         await Allowed(c, "19002", "VIEW", t) ||
         await Allowed(c, "20001", "VIEW", t) ||
         await Allowed(c, "20002", "VIEW", t) ||
         await Allowed(c, "20003", "VIEW", t));

    private Task<bool> Allowed(SqlConnection c, string screen, string action, CancellationToken t) =>
        CompanyProjectPermission.IsAllowedAsync(c, User, screen, action, t);

    private static async Task<int> ScreenType(SqlConnection c, string menu, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT ScreenType FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1 AND IsVisible=1", c);
        Add(q, "@menu", SqlDbType.VarChar, menu, 20);
        return Convert.ToInt32(await q.ExecuteScalarAsync(token) ?? 0);
    }

    // Scope is derived solely from the authenticated company/user and active employee relationships.
    private const string MenuViewPredicate = "dbo.LaooMenuDataAccessAllowed(R.CompanyID,@user,R.CreateBy,N'20001','VIEW')=1";
    private const string MenuEditPredicate = "dbo.LaooMenuDataAccessAllowed(R.CompanyID,@user,R.CreateBy,N'20001','EDIT')=1";
    private const string MenuDeletePredicate = "dbo.LaooMenuDataAccessAllowed(R.CompanyID,@user,R.CreateBy,N'20001','DELETE')=1";

    private const string SelfViewPredicate = """
      (R.CreateBy=@user OR EXISTS (
        SELECT 1 FROM dbo.TDSTCompanySetupSystemService S
        JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_SERVICE' AND P.IsActive=1
        JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=R.CompanyID AND UE.UserID=@user AND UE.IsActive=1
        JOIN dbo.TDADEmployee ME ON ME.CompanyID=R.CompanyID AND ME.EmployeeID=UE.EmployeeID AND ME.IsActive=1
        JOIN dbo.TDADEmployee RE ON RE.CompanyID=R.CompanyID AND RE.PersonID=R.RequesterID AND RE.IsActive=1
        WHERE S.CompanyID=R.CompanyID AND R.RequesterType=N'EMPLOYEE'
          AND ((S.SelfViewScope='DEPARTMENT' AND ME.DepartmentOrgUnitID IS NOT NULL AND ME.DepartmentOrgUnitID=RE.DepartmentOrgUnitID)
            OR (S.SelfViewScope='DIVISION' AND ME.DivisionOrgUnitID IS NOT NULL AND ME.DivisionOrgUnitID=RE.DivisionOrgUnitID))))
      """;
    private const string SelfEditPredicate = """
      (R.CreateBy=@user OR EXISTS (
        SELECT 1 FROM dbo.TDSTCompanySetupSystemService S
        JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_SERVICE' AND P.IsActive=1
        JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=R.CompanyID AND UE.UserID=@user AND UE.IsActive=1
        JOIN dbo.TDADEmployee ME ON ME.CompanyID=R.CompanyID AND ME.EmployeeID=UE.EmployeeID AND ME.IsActive=1
        JOIN dbo.TDADEmployee RE ON RE.CompanyID=R.CompanyID AND RE.PersonID=R.RequesterID AND RE.IsActive=1
        JOIN dbo.TDADOrganizationSupervisor OS ON OS.CompanyID=R.CompanyID AND OS.EmployeeID=ME.EmployeeID AND OS.IsActive=1
        JOIN dbo.TDADOrganizationUnit OU ON OU.CompanyID=R.CompanyID AND OU.OrgUnitID=OS.OrgUnitID AND OU.IsActive=1
        WHERE S.CompanyID=R.CompanyID AND R.RequesterType=N'EMPLOYEE'
          AND ((S.SelfDepartmentHeadEdit=1 AND OS.SupervisorType=N'DEPARTMENT_HEAD' AND OU.UnitType=N'DEP' AND OS.OrgUnitID=RE.DepartmentOrgUnitID)
            OR (S.SelfDivisionManagerEdit=1 AND OS.SupervisorType=N'DIVISION_MANAGER' AND OU.UnitType=N'DIV' AND OS.OrgUnitID=RE.DivisionOrgUnitID))))
      """;
    private const string SelfDeletePredicate = """
      (R.CreateBy=@user OR EXISTS (
        SELECT 1 FROM dbo.TDSTCompanySetupSystemService S
        JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_SERVICE' AND P.IsActive=1
        JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=R.CompanyID AND UE.UserID=@user AND UE.IsActive=1
        JOIN dbo.TDADEmployee ME ON ME.CompanyID=R.CompanyID AND ME.EmployeeID=UE.EmployeeID AND ME.IsActive=1
        JOIN dbo.TDADEmployee RE ON RE.CompanyID=R.CompanyID AND RE.PersonID=R.RequesterID AND RE.IsActive=1
        JOIN dbo.TDADOrganizationSupervisor OS ON OS.CompanyID=R.CompanyID AND OS.EmployeeID=ME.EmployeeID AND OS.IsActive=1
        JOIN dbo.TDADOrganizationUnit OU ON OU.CompanyID=R.CompanyID AND OU.OrgUnitID=OS.OrgUnitID AND OU.IsActive=1
        WHERE S.CompanyID=R.CompanyID AND R.RequesterType=N'EMPLOYEE'
          AND ((S.SelfDepartmentHeadDelete=1 AND OS.SupervisorType=N'DEPARTMENT_HEAD' AND OU.UnitType=N'DEP' AND OS.OrgUnitID=RE.DepartmentOrgUnitID)
            OR (S.SelfDivisionManagerDelete=1 AND OS.SupervisorType=N'DIVISION_MANAGER' AND OU.UnitType=N'DIV' AND OS.OrgUnitID=RE.DivisionOrgUnitID))))
      """;

    private async Task<bool> HasSelfScope(SqlConnection c, long id, bool edit, CancellationToken token)
    {
        var predicate = edit ? SelfEditPredicate : SelfViewPredicate;
        await using var q = new SqlCommand($"SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADServiceRequest R WHERE R.CompanyID=@company AND R.RequestID=@id AND R.IsActive=1 AND {predicate}) THEN 1 ELSE 0 END", c);
        Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id); Add(q, "@user", SqlDbType.BigInt, UserId);
        return Convert.ToInt32(await q.ExecuteScalarAsync(token)) == 1;
    }

    private async Task<bool> HasMenuScope(SqlConnection c, long id, string action, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT dbo.LaooMenuDataAccessAllowed(R.CompanyID,@user,R.CreateBy,N'20001',@action) FROM dbo.TDADServiceRequest R WHERE R.CompanyID=@company AND R.RequestID=@id AND R.IsActive=1", c);
        Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id);
        Add(q, "@user", SqlDbType.BigInt, UserId); Add(q, "@action", SqlDbType.VarChar, action, 6);
        return Convert.ToBoolean(await q.ExecuteScalarAsync(token) ?? false);
    }

    private async Task<bool> CanReadRequest(SqlConnection c, RequestAccessInfo access, string? menuCode, CancellationToken token)
    {
        if (menuCode is null)
            return await Allowed(c, "15001", "VIEW", token) ||
                   await Allowed(c, "20001", "VIEW", token) && await HasMenuScope(c, access.RequestId, "VIEW", token) ||
                   access.Status == "COMPLETED" && await Allowed(c, "19002", "VIEW", token);
        if (menuCode is not ("15001" or "17001" or "17002" or "19002" or "20001" or "20002" or "20003"))
            return false;
        var expectedType = menuCode is "17001" or "17002" ? 2 : menuCode is "19002" or "20002" or "20003" ? 3 : 1;
        if (await ScreenType(c, menuCode, token) != expectedType ||
            !await Allowed(c, menuCode, "VIEW", token)) return false;
        return menuCode switch
        {
            "17001" => access.Status == "NEW",
            "19002" => access.Status == "COMPLETED",
            "20001" => await HasMenuScope(c, access.RequestId, "VIEW", token),
            "20002" => await HasSelfScope(c, access.RequestId, false, token),
            "20003" => access.Status == "COMPLETED" && await HasSelfScope(c, access.RequestId, false, token),
            _ => true
        };
    }

    private async Task<long?> FindAccessibleEquipmentSerial(string serial, long itemId, CancellationToken token)
    {
        // Reuse the inventory registry's company, menu and warehouse filtering.
        var registry = new LaooServiceModule.Controllers.ItemInstanceController(configuration) { ControllerContext = ControllerContext };
        var result = await registry.List(serial, null, null, itemId, token);
        if (result is not OkObjectResult ok) return null;
        var rows = System.Text.Json.JsonSerializer.SerializeToElement(ok.Value);
        foreach (var row in rows.EnumerateArray())
            if (string.Equals(row.GetProperty("serialNo").GetString(), serial, StringComparison.OrdinalIgnoreCase))
                return row.GetProperty("itemInstanceID").GetInt64();
        return null;
    }

    private async Task<string> BusinessType(SqlConnection c, CancellationToken t)
    {
        await using var q = new SqlCommand("SELECT ISNULL(NULLIF(UPPER(LTRIM(RTRIM(BusinessTypeCode))),N''),N'COMPANY') FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company", c);
        Add(q, "@company", SqlDbType.BigInt, CompanyId); return CompanyBusinessType.Normalize(Convert.ToString(await q.ExecuteScalarAsync(t)));
    }

    private async Task<QrContext?> ResolveQrContext(SqlConnection c, string tokenValue, CancellationToken token)
    {
        const string sql = """
SELECT X.ItemID,CONCAT_WS(N' / ',NULLIF(B.BuildingNameTH,N''),NULLIF(F.FloorNameTH,N''),NULLIF(R.RoomCode,N'')),X.ItemInstanceID
FROM dbo.TDADServiceRequestQrPortal Q
JOIN dbo.TDIVItemInstance X ON X.ItemInstanceID=Q.ItemInstanceID AND X.CompanyID=Q.CompanyID AND X.StatusCode IN(N'INSTALLED',N'REPAIR')
JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID AND I.IsActive=1
JOIN dbo.TDIVItemUsage U ON U.ItemID=I.ItemID AND U.CompanyID=I.CompanyID AND U.UsageCode=N'EQUIPMENT'
JOIN dbo.TDADBuilding B ON B.BuildingID=X.BuildingID AND B.CompanyID=X.CompanyID AND B.IsActive=1
JOIN dbo.TDADFloor F ON F.FloorID=X.FloorID AND F.BuildingID=X.BuildingID AND F.IsActive=1
JOIN dbo.TDADRoom R ON R.RoomID=X.RoomID AND R.CompanyID=X.CompanyID AND R.IsActive=1
WHERE Q.CompanyID=@company AND Q.QrToken=@token AND Q.IsActive=1;
""";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@token", SqlDbType.NVarChar, tokenValue.Trim(), 100);
        await using var r = await q.ExecuteReaderAsync(token);
        return await r.ReadAsync(token) ? new(r.GetInt64(0), Text(r, 1), r.GetInt64(2)) : null;
    }

    private async Task<ServiceSettingsState> ReadSettings(SqlConnection c, CancellationToken token)
    {
        const string sql = "SELECT COALESCE(S.ServiceEnabled,1),COALESCE(S.AllowWalkIn,1),COALESCE(S.RequireEquipment,1),COALESCE(S.AttachmentRequired,0),COALESCE(S.WorkflowEnabled,1) FROM dbo.TDADProject P LEFT JOIN dbo.TDSTCompanySetupSystemService S ON S.ProjectID=P.ProjectID AND S.CompanyID=@company WHERE P.ProjectCode=N'LAOO_SERVICE' AND P.IsActive=1";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId);
        await using var r = await q.ExecuteReaderAsync(token);
        return await r.ReadAsync(token)
            ? new(Flag(r, 0), Flag(r, 1), Flag(r, 2), Flag(r, 3), Flag(r, 4))
            : new(true, true, true, false, true);
    }

    // Existing Company Setup databases may store these flags as either bit or int.
    private static bool Flag(SqlDataReader reader, int ordinal) =>
        !reader.IsDBNull(ordinal) && Convert.ToInt32(reader.GetValue(ordinal)) != 0;

    private sealed record ServiceSettingsState(bool ServiceEnabled, bool AllowWalkIn, bool RequireEquipment, bool AttachmentRequired, bool WorkflowEnabled);

    private async Task<bool> EvaluationEnabled(SqlConnection connection, SqlTransaction? transaction, CancellationToken token)
    {
        const string sql = """
SELECT CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDADCompanyProject CP
    JOIN dbo.TDADProject P ON P.ProjectID=CP.ProjectID
    WHERE CP.CompanyID=@company AND CP.PartnerID=@partner
      AND CP.IsEnabled=1 AND P.ProjectCode=N'LAOO_EVALUATION' AND P.IsActive=1
      AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
      AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
) THEN 1 ELSE 0 END;
""";
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@company", SqlDbType.BigInt, CompanyId);
        Add(command, "@partner", SqlDbType.BigInt, ClaimLong("partner_id"));
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private async Task<RequestAccessInfo> RequestAccess(SqlConnection c, long id, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT StatusCode,CreateBy FROM dbo.TDADServiceRequest WHERE CompanyID=@company AND RequestID=@id AND IsActive=1", c);
        Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id); await using var r = await q.ExecuteReaderAsync(token);
        return await r.ReadAsync(token) ? new(true, r.GetString(0), r.IsDBNull(1) ? null : r.GetInt64(1), id) : new(false, string.Empty, null, id);
    }

    private async Task<ProcessedImage> ProcessImage(IFormFile file, CancellationToken token)
    {
        var contentType = (file.ContentType ?? string.Empty).Trim().ToLowerInvariant();
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        var supported = contentType is "image/jpeg" or "image/png" or "image/webp" || extension is ".jpg" or ".jpeg" or ".png" or ".webp";
        if (!supported) return ProcessedImage.Rejected("รองรับเฉพาะไฟล์ JPG, PNG และ WEBP");
        await using var input = new MemoryStream(); await file.CopyToAsync(input, token); var original = input.ToArray();
        try
        {
            using var encoded = SKData.CreateCopy(original); using var codec = SKCodec.Create(encoded);
            if (codec is null) return ProcessedImage.Rejected("ไฟล์รูปภาพไม่ถูกต้องหรือไม่สามารถอ่านได้");
            var info = codec.Info;
            if (info.Width <= 0 || info.Height <= 0 || (long)info.Width * info.Height > 50_000_000) return ProcessedImage.Rejected("ความละเอียดรูปสูงเกินกำหนด");
            using var image = new SKBitmap(new SKImageInfo(info.Width, info.Height, SKColorType.Rgba8888, SKAlphaType.Premul));
            var decode = codec.GetPixels(image.Info, image.GetPixels());
            if (decode is not (SKCodecResult.Success or SKCodecResult.IncompleteInput)) return ProcessedImage.Rejected("ไฟล์รูปภาพไม่ถูกต้องหรือไม่สามารถอ่านได้");
            if (original.Length <= MaxAttachmentBytes)
                return new(original, NormalizeContentType(contentType, extension), NormalizeExtension(contentType, extension), image.Width, image.Height, null);
            foreach (var maxDimension in new[] { 2400, 2000, 1600, 1200, 900, 700, 500 })
            {
                var scale = Math.Min(1d, Math.Min((double)maxDimension / image.Width, (double)maxDimension / image.Height));
                var width = Math.Max(1, (int)Math.Round(image.Width * scale)); var height = Math.Max(1, (int)Math.Round(image.Height * scale));
                using var candidate = image.Resize(new SKImageInfo(width, height, SKColorType.Rgba8888, SKAlphaType.Premul), new SKSamplingOptions(SKFilterMode.Linear, SKMipmapMode.Linear));
                if (candidate is null) continue;
                foreach (var quality in new[] { 88, 78, 68, 58, 48, 38, 30 })
                {
                    using var rendered = SKImage.FromBitmap(candidate); using var output = rendered.Encode(SKEncodedImageFormat.Jpeg, quality); var bytes = output.ToArray();
                    if (bytes.LongLength <= MaxAttachmentBytes) return new(bytes, "image/jpeg", ".jpg", candidate.Width, candidate.Height, null);
                }
            }
            return ProcessedImage.Rejected("ระบบลดขนาดรูปแล้ว แต่ไฟล์ยังเกิน 1 MB");
        }
        catch (Exception) { return ProcessedImage.Rejected("ไฟล์รูปภาพไม่ถูกต้องหรือไม่สามารถอ่านได้"); }
    }

    private string? SafeFilePath(string relative)
    {
        var root = environment.WebRootPath; if (string.IsNullOrWhiteSpace(root)) root = Path.Combine(environment.ContentRootPath, "wwwroot");
        var rootPath = Path.GetFullPath(root) + Path.DirectorySeparatorChar; var full = Path.GetFullPath(Path.Combine(root, relative.Replace('/', Path.DirectorySeparatorChar)));
        return full.StartsWith(rootPath, StringComparison.OrdinalIgnoreCase) ? full : null;
    }

    private void TryDelete(string relative) { var full = SafeFilePath(relative); if (full is not null) try { if (System.IO.File.Exists(full)) System.IO.File.Delete(full); } catch { } }
    private static string SafeOriginalName(string value) => Path.GetFileName(value).Trim() is { Length: > 0 } name ? name[..Math.Min(name.Length, 255)] : "attachment";
    private static string NormalizeContentType(string contentType, string extension) => contentType switch { "image/jpeg" or "image/png" or "image/webp" => contentType, ".png" => "image/png", ".webp" => "image/webp", _ => "image/jpeg" };
    private static string NormalizeExtension(string contentType, string extension) => contentType switch { "image/png" => ".png", "image/webp" => ".webp", _ => extension is ".png" or ".webp" ? extension : ".jpg" };

    private async Task<SqlConnection> Open(CancellationToken t) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(t); return c; }
    private long ClaimLong(string name) => long.TryParse(User.FindFirstValue(name), out var value) ? value : 0;
    private long? ClaimLongNullable(string name) => long.TryParse(User.FindFirstValue(name), out var value) ? value : null;
    private static long? Long(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetInt64(index);
    private static int? LongInt(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetInt32(index);
    private static string? Text(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetString(index);
    private static DateTime? DateTimeValue(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetDateTime(index);
    private static void Add(SqlCommand c, string name, SqlDbType type, object? value, int size = 0) { var p = size == 0 ? c.Parameters.Add(name, type) : c.Parameters.Add(name, type, size); p.Value = value ?? DBNull.Value; }

    public sealed record CreateRequest(string? RequesterType, long? RequesterId, long? EquipmentItemId, string? Subject, string? Detail, string? QrToken = null, string? PriorityCode = null, string? EquipmentSerial = null);
    public sealed record EditRequest(string? Subject, string? Detail, string? RowVersion, string? PriorityCode = null, long? EquipmentItemId = null, bool UpdateEquipment = false, string? EquipmentSerial = null, bool UpdateSerial = false);
    public sealed record ActionRequest(long? AssignedEmployeeId, string? ResolutionDetail, string? CancellationReason, IReadOnlyList<ServicePartRequest>? Parts = null, long? EvaluationTemplateId = null);
    public sealed record ServicePartRequest(long WarehouseId, long ItemId, decimal Quantity, IReadOnlyList<long>? SerialInstanceIds = null);
    private sealed record RequestAccessInfo(bool Found, string Status, long? CreatedBy, long RequestId);
    private sealed record ProcessedImage(byte[] Bytes, string ContentType, string Extension, int Width, int Height, string? Error)
    {
        public static ProcessedImage Rejected(string error) => new(Array.Empty<byte>(), string.Empty, string.Empty, 0, 0, error);
    }
    private sealed record Resolved(string Type, long PersonId, string Name, string? Phone, string? Email, long? ServiceCustomerId, long? ResidentId, long? TenantId, long? ContactId, long? RoomId, long? HouseId, string? Location);
    private sealed record QrContext(long ItemId, string? LocationSnapshot, long InstanceId);
}
