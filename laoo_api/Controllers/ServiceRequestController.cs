using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using LaooApi.Security;
using InventoryItemProjectAccess = LaooServiceModule.Infrastructure.ItemProjectAccess;
using InventoryWarehouseAccess = LaooServiceModule.Infrastructure.WarehouseAccessService;
using InventoryItemProjectDeniedException = LaooServiceModule.Infrastructure.ItemProjectDeniedException;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/service/requests")]
public sealed class ServiceRequestController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private const long MaxAttachmentBytes = 1_048_576;
    private const long MaxIncomingAttachmentBytes = 25_000_000;
    private const string ServiceRequestSubjectMasterGroup = "014";
    private long CompanyId => ClaimLong("company_id");
    private long UserId => ClaimLong("user_id");
    private long? PersonId => ClaimLongNullable("person_id");

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        return Ok(new
        {
            view = await Allowed(c, "15001", "VIEW", token),
            create = await Allowed(c, "15001", "CREATE", token),
            edit = await Allowed(c, "15001", "EDIT", token),
            selfCreate = await Allowed(c, "20001", "CREATE", token)
        });
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup([FromQuery] string? search, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token) || !await Allowed(c, "15001", "VIEW", token)) return Forbid();
        var type = await BusinessType(c, token);
        var rows = new List<object>();
        var q = search?.Trim() ?? string.Empty;

        if (type == CompanyBusinessType.Dormitory)
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
        else if (type == CompanyBusinessType.RentalOffice)
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
        else if (type == CompanyBusinessType.Village)
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
        if (type is CompanyBusinessType.Company or CompanyBusinessType.ServiceCenter)
        {
            const string employeeSql = "SELECT TOP(100) P.PersonID id,N'EMPLOYEE' requesterType,P.FullName name,P.Mobile phone,P.Email email,CONCAT(ISNULL(DV.NameTH,N'-'),N' / ',ISNULL(DP.NameTH,N'-')) locationSnapshot FROM dbo.TDADEmployee E JOIN dbo.TDADPerson P ON P.CompanyID=E.CompanyID AND P.PersonID=E.PersonID LEFT JOIN dbo.TDADOrganizationUnit DV ON DV.OrgUnitID=E.DivisionOrgUnitID AND DV.CompanyID=E.CompanyID LEFT JOIN dbo.TDADOrganizationUnit DP ON DP.OrgUnitID=E.DepartmentOrgUnitID AND DP.CompanyID=E.CompanyID WHERE E.CompanyID=@company AND E.IsActive=1 AND P.IsActive=1 AND (@q=N'' OR P.FullName LIKE N'%'+@q+N'%' OR E.EmployeeCode LIKE N'%'+@q+N'%' OR DP.NameTH LIKE N'%'+@q+N'%') ORDER BY P.FullName";
            rows.AddRange(await ReadRequesterRows(new SqlCommand(employeeSql, c), q, token));
        }        rows.AddRange(await ReadRequesterRows(new SqlCommand(customerSql, c), q, token));
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
SELECT MasterCode,Name,NULLIF(ShortCode,N'') ShortCode
FROM dbo.TDSTMaster
WHERE MasterGroupCode=@group AND IsActive=1
  AND ((OwnerType=N'L' AND ISNULL(OwnerPartnerID,0)=0 AND ISNULL(OwnerCompanyID,0)=0)
       OR (OwnerType=N'C' AND ISNULL(OwnerCompanyID,0)=@company))
ORDER BY CASE WHEN OwnerType=N'L' THEN 0 ELSE 1 END,Seq,Name,MasterCode;
""";
        await using (var subjectCommand = new SqlCommand(subjectSql, c))
        {
            Add(subjectCommand, "@company", SqlDbType.BigInt, CompanyId);
            Add(subjectCommand, "@group", SqlDbType.NVarChar, ServiceRequestSubjectMasterGroup, 10);
            await using var sr = await subjectCommand.ExecuteReaderAsync(token);
            while (await sr.ReadAsync(token))
                subjects.Add(new { code = sr.GetString(0), name = sr.GetString(1), shortCode = Text(sr, 2) });
        }
        return Ok(new { businessTypeCode = type, requesters = rows, equipment, subjects });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? status, [FromQuery] bool self = false, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken token = default)
    {
        await using var c = await Open(token);
        var canManage = await Allowed(c, "15001", "VIEW", token);
        var canSelfView = await Allowed(c, "20001", "VIEW", token);
        if (!await InService(c, token) || (self ? !canManage && !canSelfView : !canManage)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        const string sql = """
SELECT COUNT_BIG(1) OVER(),RequestID,RequestNo,RequesterType,RequesterNameSnapshot,LocationSnapshot,
       EquipmentNameSnapshot,Subject,StatusCode,AssignedEmployeeNameSnapshot,ReceivedDate,StartedDate,RequestDate,RowVersion
FROM dbo.TDADServiceRequest
WHERE CompanyID=@company AND IsActive=1
  AND (@self=0 OR CreateBy=@user)
  AND (@status IN(N'',N'ALL')
       OR (@status=N'OPEN' AND StatusCode IN(N'RECEIVED',N'IN_PROGRESS'))
       OR (@status NOT IN(N'',N'ALL',N'OPEN') AND StatusCode=@status))
  AND (@q=N'' OR RequestNo LIKE N'%'+@q+N'%' OR RequesterNameSnapshot LIKE N'%'+@q+N'%' OR Subject LIKE N'%'+@q+N'%')
ORDER BY RequestDate DESC,RequestID DESC OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId);
        Add(cmd, "@self", SqlDbType.Bit, self); Add(cmd, "@user", SqlDbType.BigInt, UserId);
        Add(cmd, "@status", SqlDbType.NVarChar, status?.Trim() ?? string.Empty, 30);
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
                requesterType = r.GetString(3),
                requesterName = r.GetString(4),
                locationSnapshot = Text(r, 5),
                equipmentName = Text(r, 6),
                subject = r.GetString(7),
                statusCode = r.GetString(8),
                assignedEmployeeName = Text(r, 9),
                receivedDate = DateTimeValue(r, 10),
                startedDate = DateTimeValue(r, 11),
                requestDate = r.GetDateTime(12),
                rowVersion = Convert.ToBase64String((byte[])r[13])
            });
        }
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Detail(long id, CancellationToken token)
    {
        await using var c = await Open(token);
        var canManage = await Allowed(c, "15001", "VIEW", token);
        var canSelfView = await Allowed(c, "20001", "VIEW", token);
        if (!await InService(c, token) || (!canManage && !canSelfView)) return Forbid();
        const string sql = "SELECT RequestID,RequestNo,RequesterType,RequesterID,RequesterNameSnapshot,RequesterPhoneSnapshot,RequesterEmailSnapshot,LocationSnapshot,EquipmentItemID,EquipmentCodeSnapshot,EquipmentNameSnapshot,Subject,Detail,StatusCode,RequestDate,AssignedEmployeeID,AssignedEmployeeNameSnapshot,ReceivedDate,StartedDate,CompletedDate,ResolutionDetail,CancellationReason,RowVersion FROM dbo.TDADServiceRequest WHERE CompanyID=@company AND RequestID=@id AND IsActive=1 AND (@manage=1 OR CreateBy=@user)";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id); Add(q, "@manage", SqlDbType.Bit, canManage); Add(q, "@user", SqlDbType.BigInt, UserId);
        await using var r = await q.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound();
        var response = new Dictionary<string, object?>
        {
            ["requestId"] = r.GetInt64(0), ["requestNo"] = r.GetString(1), ["requesterType"] = r.GetString(2),
            ["requesterId"] = Long(r,3), ["requesterName"] = r.GetString(4), ["requesterPhone"] = Text(r,5),
            ["requesterEmail"] = Text(r,6), ["locationSnapshot"] = Text(r,7), ["equipmentItemId"] = Long(r,8),
            ["equipmentCode"] = Text(r,9), ["equipmentName"] = Text(r,10), ["subject"] = r.GetString(11),
            ["detail"] = r.GetString(12), ["statusCode"] = r.GetString(13), ["requestDate"] = r.GetDateTime(14),
            ["assignedEmployeeId"] = Long(r,15), ["assignedEmployeeName"] = Text(r,16), ["receivedDate"] = DateTimeValue(r,17),
            ["startedDate"] = DateTimeValue(r,18), ["completedDate"] = DateTimeValue(r,19), ["resolutionDetail"] = Text(r,20),
            ["cancellationReason"] = Text(r,21), ["rowVersion"] = Convert.ToBase64String((byte[])r[22])
        };
        await r.DisposeAsync();
        var parts = new List<object>(); decimal partsTotal = 0;
        const string partSql = "SELECT P.ServiceRequestPartID,P.WarehouseID,P.ItemID,P.ItemCodeSnapshot,P.ItemNameSnapshot,P.UnitCodeSnapshot,P.Quantity,P.UnitCostSnapshot,P.TotalCost,W.WarehouseName,(SELECT STRING_AGG(X.SerialNo,N', ') FROM dbo.TDIVStockIssueSerial S JOIN dbo.TDIVItemInstance X ON X.ItemInstanceID=S.ItemInstanceID WHERE S.StockIssueDetailID=P.StockIssueDetailID) SerialNos FROM dbo.TDADServiceRequestPart P JOIN dbo.TDIVWarehouse W ON W.CompanyID=P.CompanyID AND W.WarehouseID=P.WarehouseID WHERE P.CompanyID=@company AND P.RequestID=@request AND P.IsActive=1 ORDER BY P.ServiceRequestPartID";
        await using (var partCommand = new SqlCommand(partSql, c))
        {
            Add(partCommand,"@company",SqlDbType.BigInt,CompanyId); Add(partCommand,"@request",SqlDbType.BigInt,id);
            await using var partReader = await partCommand.ExecuteReaderAsync(token);
            while (await partReader.ReadAsync(token))
            {
                var total = partReader.GetDecimal(8); partsTotal += total;
                parts.Add(new { serviceRequestPartId=partReader.GetInt64(0),warehouseId=partReader.GetInt64(1),itemId=partReader.GetInt64(2),itemCode=partReader.GetString(3),itemName=partReader.GetString(4),unitCode=Text(partReader,5),quantity=partReader.GetDecimal(6),unitCost=partReader.GetDecimal(7),totalCost=total,warehouseName=partReader.GetString(9),serialNos=(Text(partReader,10)?.Split(", ",StringSplitOptions.RemoveEmptyEntries)??[]) });
            }
        }
        response["parts"] = parts; response["partsTotal"] = partsTotal;
        return Ok(response);
    }

    [HttpGet("parts/lookup")]
    public async Task<IActionResult> PartsLookup(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token) || !await Allowed(c, "15001", "EDIT", token)) return Forbid();
        var warehouses = new List<object>(); var items = new List<object>(); var serials = new List<object>();
        var warehouseSql = $"SELECT W.WarehouseID,W.WarehouseCode,W.WarehouseName,W.IsDefault FROM dbo.TDIVWarehouse W INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE W.CompanyID=@company AND W.IsActive=1 AND {InventoryWarehouseAccess.WarehouseAliasPredicate} ORDER BY W.IsDefault DESC,W.WarehouseCode";
        await using (var command = new SqlCommand(warehouseSql,c))
        {
            Add(command,"@company",SqlDbType.BigInt,CompanyId); Add(command,"@user",SqlDbType.BigInt,UserId);
            await using var reader=await command.ExecuteReaderAsync(token);
            while(await reader.ReadAsync(token)) warehouses.Add(new { warehouseId=reader.GetInt64(0),warehouseCode=reader.GetString(1),warehouseName=reader.GetString(2),isDefault=reader.GetBoolean(3) });
        }
        var itemSql = $"SELECT SB.WarehouseID,I.ItemID,I.ItemCode,I.ItemName,I.UnitCode,I.CostPrice,I.StockTrackingCode,SB.Quantity FROM dbo.TDIVStockBalance SB INNER JOIN dbo.TDIVItem I ON I.CompanyID=SB.CompanyID AND I.ItemID=SB.ItemID INNER JOIN dbo.TDIVWarehouse W ON W.CompanyID=SB.CompanyID AND W.WarehouseID=SB.WarehouseID AND W.IsActive=1 INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE SB.CompanyID=@company AND SB.Quantity>0 AND I.IsActive=1 AND I.ItemKindCode=N'GOODS' AND I.StockTrackingCode<>N'NONE' AND EXISTS(SELECT 1 FROM dbo.TDIVItemUsage U WHERE U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode IN(N'MATERIAL',N'SPARE_PART')) AND {InventoryWarehouseAccess.WarehouseAliasPredicate} AND {InventoryItemProjectAccess.ItemAliasPredicate} ORDER BY W.IsDefault DESC,I.ItemCode";
        await using (var command = new SqlCommand(itemSql,c))
        {
            Add(command,"@company",SqlDbType.BigInt,CompanyId); Add(command,"@user",SqlDbType.BigInt,UserId);
            await using var reader=await command.ExecuteReaderAsync(token);
            while(await reader.ReadAsync(token)) items.Add(new { warehouseId=reader.GetInt64(0),itemId=reader.GetInt64(1),itemCode=reader.GetString(2),itemName=reader.GetString(3),unitCode=Text(reader,4),unitCost=reader.GetDecimal(5),stockTrackingCode=reader.GetString(6),availableQuantity=reader.GetDecimal(7) });
        }
        var serialSql = $"SELECT X.ItemInstanceID,X.ItemID,X.WarehouseID,X.SerialNo FROM dbo.TDIVItemInstance X INNER JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID INNER JOIN dbo.TDIVWarehouse W ON W.WarehouseID=X.WarehouseID AND W.CompanyID=X.CompanyID INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE X.CompanyID=@company AND X.StatusCode=N'IN_STOCK' AND {InventoryWarehouseAccess.WarehouseAliasPredicate} AND {InventoryItemProjectAccess.ItemAliasPredicate} ORDER BY X.SerialNo";
        await using (var command = new SqlCommand(serialSql,c))
        {
            Add(command,"@company",SqlDbType.BigInt,CompanyId); Add(command,"@user",SqlDbType.BigInt,UserId);
            await using var reader=await command.ExecuteReaderAsync(token);
            while(await reader.ReadAsync(token)) serials.Add(new { itemInstanceId=reader.GetInt64(0),itemId=reader.GetInt64(1),warehouseId=reader.GetInt64(2),serialNo=reader.GetString(3) });
        }
        return Ok(new { warehouses,items,serials });
    }
    [HttpGet("{id:long}/attachments")]
    public async Task<IActionResult> Attachments(long id, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        var access = await RequestAccess(c, id, token);
        if (!access.Found) return NotFound();
        var canManage = await Allowed(c, "15001", "VIEW", token);
        var canOwnerView = access.CreatedBy == UserId && await Allowed(c, "20001", "VIEW", token);
        if (!canManage && !canOwnerView) return Forbid();
        const string sql = "SELECT AttachmentID,FileName,ContentType,FileSize,ImageWidth,ImageHeight,CreateDate FROM dbo.TDADServiceRequestAttachment WHERE CompanyID=@company AND RequestID=@request AND IsActive=1 ORDER BY CreateDate,AttachmentID";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@request", SqlDbType.BigInt, id);
        var items = new List<object>(); await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) items.Add(new { attachmentId=r.GetInt64(0),requestId=id,fileName=r.GetString(1),contentType=r.GetString(2),fileSize=r.GetInt64(3),imageWidth=LongInt(r,4),imageHeight=LongInt(r,5),createDate=r.GetDateTime(6),url=$"/api/service/requests/{id}/attachments/{r.GetInt64(0)}" });
        return Ok(new { items });
    }

    [HttpGet("{id:long}/attachments/{attachmentId:long}")]
    public async Task<IActionResult> Attachment(long id, long attachmentId, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        var access = await RequestAccess(c, id, token);
        if (!access.Found) return NotFound();
        var canManage = await Allowed(c, "15001", "VIEW", token);
        var canOwnerView = access.CreatedBy == UserId && await Allowed(c, "20001", "VIEW", token);
        if (!canManage && !canOwnerView) return Forbid();
        const string sql = "SELECT FileName,StoredPath,ContentType FROM dbo.TDADServiceRequestAttachment WHERE CompanyID=@company AND RequestID=@request AND AttachmentID=@attachment AND IsActive=1";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@request", SqlDbType.BigInt, id); Add(q, "@attachment", SqlDbType.BigInt, attachmentId);
        await using var r = await q.ExecuteReaderAsync(token); if (!await r.ReadAsync(token)) return NotFound();
        var fileName = r.GetString(0); var relative = r.GetString(1); var contentType = r.GetString(2); var fullPath = SafeFilePath(relative);
        if (fullPath is null || !System.IO.File.Exists(fullPath)) return NotFound();
        return PhysicalFile(fullPath, contentType, fileName, enableRangeProcessing:true);
    }

    [HttpPost("{id:long}/attachments"), RequestSizeLimit(MaxIncomingAttachmentBytes)]
    public async Task<IActionResult> UploadAttachment(long id, IFormFile? file, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        var access = await RequestAccess(c, id, token);
        if (!access.Found) return NotFound();
        if (access.Status is "COMPLETED" or "CANCELLED") return Conflict(new { message="ไม่สามารถเพิ่มรูปในใบแจ้งซ่อมที่ปิดแล้ว" });
        var canManage = await Allowed(c, "15001", "EDIT", token);
        var canOwner = access.CreatedBy == UserId && await Allowed(c, "20001", "CREATE", token);
        if (!canManage && !canOwner) return Forbid();
        if (file is null || file.Length == 0) return BadRequest(new { message="กรุณาเลือกไฟล์รูปภาพ" });
        if (file.Length > MaxIncomingAttachmentBytes) return BadRequest(new { message="ไฟล์ใหญ่เกินกำหนด", description="ไฟล์ต้นฉบับต้องไม่เกิน 25 MB" });
        var processed = await ProcessImage(file, token);
        if (processed.Error is not null) return BadRequest(new { message=processed.Error });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        string? storedPath = null;
        try
        {
            const string insert = "INSERT dbo.TDADServiceRequestAttachment(CompanyID,RequestID,FileName,StoredPath,ContentType,FileSize,ImageWidth,ImageHeight,CreateBy) OUTPUT INSERTED.AttachmentID VALUES(@company,@request,@name,N'',@type,@size,@width,@height,@user)";
            await using var insertCommand = new SqlCommand(insert, c, tx); Add(insertCommand,"@company",SqlDbType.BigInt,CompanyId); Add(insertCommand,"@request",SqlDbType.BigInt,id); Add(insertCommand,"@name",SqlDbType.NVarChar,SafeOriginalName(file.FileName),255); Add(insertCommand,"@type",SqlDbType.NVarChar,processed.ContentType,100); Add(insertCommand,"@size",SqlDbType.BigInt,processed.Bytes.Length); Add(insertCommand,"@width",SqlDbType.Int,processed.Width); Add(insertCommand,"@height",SqlDbType.Int,processed.Height); Add(insertCommand,"@user",SqlDbType.BigInt,UserId);
            var attachmentId = Convert.ToInt64(await insertCommand.ExecuteScalarAsync(token));
            storedPath = $"uploads/service-requests/{CompanyId}/{id}/{attachmentId}{processed.Extension}";
            var fullPath = SafeFilePath(storedPath) ?? throw new InvalidOperationException("Invalid attachment path");
            Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
            await System.IO.File.WriteAllBytesAsync(fullPath, processed.Bytes, token);
            await using var update = new SqlCommand("UPDATE dbo.TDADServiceRequestAttachment SET StoredPath=@path,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND AttachmentID=@attachment", c, tx); Add(update,"@path",SqlDbType.NVarChar,storedPath,500); Add(update,"@user",SqlDbType.BigInt,UserId); Add(update,"@company",SqlDbType.BigInt,CompanyId); Add(update,"@attachment",SqlDbType.BigInt,attachmentId); await update.ExecuteNonQueryAsync(token);
            await tx.CommitAsync(token);
            return Ok(new { attachmentId,requestId=id,fileName=SafeOriginalName(file.FileName),contentType=processed.ContentType,fileSize=processed.Bytes.Length,imageWidth=processed.Width,imageHeight=processed.Height,url=$"/api/service/requests/{id}/attachments/{attachmentId}" });
        }
        catch
        {
            await tx.RollbackAsync(token); if (storedPath is not null) TryDelete(storedPath); throw;
        }
    }

    [HttpDelete("{id:long}/attachments/{attachmentId:long}")]
    public async Task<IActionResult> DeleteAttachment(long id, long attachmentId, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token) || !await Allowed(c, "15001", "EDIT", token)) return Forbid();
        var access = await RequestAccess(c, id, token); if (!access.Found) return NotFound();
        if (access.Status is "COMPLETED" or "CANCELLED") return Conflict(new { message="ไม่สามารถลบรูปในใบแจ้งซ่อมที่ปิดแล้ว" });
        const string sql = "SELECT StoredPath FROM dbo.TDADServiceRequestAttachment WHERE CompanyID=@company AND RequestID=@request AND AttachmentID=@attachment AND IsActive=1";
        await using var q = new SqlCommand(sql,c); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@request",SqlDbType.BigInt,id); Add(q,"@attachment",SqlDbType.BigInt,attachmentId); var path=Convert.ToString(await q.ExecuteScalarAsync(token)); if (string.IsNullOrWhiteSpace(path)) return NotFound();
        await using var update = new SqlCommand("UPDATE dbo.TDADServiceRequestAttachment SET IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND RequestID=@request AND AttachmentID=@attachment AND IsActive=1",c); Add(update,"@user",SqlDbType.BigInt,UserId); Add(update,"@company",SqlDbType.BigInt,CompanyId); Add(update,"@request",SqlDbType.BigInt,id); Add(update,"@attachment",SqlDbType.BigInt,attachmentId); await update.ExecuteNonQueryAsync(token); TryDelete(path!); return Ok(new { attachmentId,deleted=true });
    }

    [HttpGet("technicians")]
    public async Task<IActionResult> Technicians(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InService(c, token) || !await Allowed(c, "15001", "EDIT", token)) return Forbid();
        const string sql = "SELECT EmployeeID,EmployeeCode,FullName FROM dbo.TDADEmployee WHERE CompanyID=@company AND IsActive=1 AND IsServiceTechnician=1 ORDER BY FullName,EmployeeCode";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); var rows=new List<object>(); await using var r=await q.ExecuteReaderAsync(token);
        while(await r.ReadAsync(token)) rows.Add(new { employeeId=r.GetInt64(0),employeeCode=r.GetString(1),fullName=r.GetString(2) });
        return Ok(new { items=rows });
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
        if (!await InService(c, token) || !await Allowed(c, "15001", "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            string? current=null; string? requestNo=null; byte[]? version=null;
            await using (var q=new SqlCommand("SELECT StatusCode,RequestNo,RowVersion FROM dbo.TDADServiceRequest WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND RequestID=@id AND IsActive=1",c,tx))
            { Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id); await using var r=await q.ExecuteReaderAsync(token); if(!await r.ReadAsync(token)) return NotFound(); current=r.GetString(0); requestNo=r.GetString(1); version=(byte[])r[2]; }
            var valid = next=="RECEIVED" && current=="NEW" || next=="IN_PROGRESS" && current=="RECEIVED" || next=="COMPLETED" && current=="IN_PROGRESS" || next=="CANCELLED" && current is "NEW" or "RECEIVED" or "IN_PROGRESS";
            if (!valid) return Conflict(new { message="ไม่สามารถเปลี่ยนสถานะได้", description="สถานะปัจจุบันไม่อยู่ในลำดับที่อนุญาต" });
            if (next=="RECEIVED")
            {
                if (!x.AssignedEmployeeId.HasValue) return BadRequest(new { message="กรุณาเลือกช่างซ่อม" });
                await using var e=new SqlCommand("SELECT FullName FROM dbo.TDADEmployee WHERE CompanyID=@company AND EmployeeID=@employee AND IsActive=1 AND IsServiceTechnician=1",c,tx); Add(e,"@company",SqlDbType.BigInt,CompanyId); Add(e,"@employee",SqlDbType.BigInt,x.AssignedEmployeeId); var name=Convert.ToString(await e.ExecuteScalarAsync(token)); if(string.IsNullOrWhiteSpace(name)) return BadRequest(new { message="ไม่พบช่างซ่อมที่ใช้งานได้ใน Company นี้" });
                await using var u=new SqlCommand("UPDATE dbo.TDADServiceRequest SET StatusCode=N'RECEIVED',AssignedEmployeeID=@employee,AssignedEmployeeNameSnapshot=@name,ReceivedDate=SYSUTCDATETIME(),ReceivedBy=@user,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND RequestID=@id AND RowVersion=@version",c,tx); Add(u,"@employee",SqlDbType.BigInt,x.AssignedEmployeeId); Add(u,"@name",SqlDbType.NVarChar,name,200); Add(u,"@user",SqlDbType.BigInt,UserId); Add(u,"@company",SqlDbType.BigInt,CompanyId); Add(u,"@id",SqlDbType.BigInt,id); Add(u,"@version",SqlDbType.VarBinary,version); await u.ExecuteNonQueryAsync(token);
            }
            else if (next=="IN_PROGRESS") await UpdateStatus(c,tx,id,"IN_PROGRESS","StartedDate=SYSUTCDATETIME(),StartedBy=@user",token);
            else if (next=="COMPLETED")
            {
                if(string.IsNullOrWhiteSpace(x.ResolutionDetail)) return BadRequest(new { message="กรุณาระบุผลการซ่อม" });
                var parts=x.Parts??[];
                if(parts.Any(p=>p.WarehouseId<=0||p.ItemId<=0||p.Quantity<=0)) return BadRequest(new { message="ข้อมูลอะไหล่ไม่ถูกต้อง",description="กรุณาเลือกคลัง อะไหล่ และระบุจำนวนมากกว่า 0" });
                if(parts.GroupBy(p=>new{p.WarehouseId,p.ItemId}).Any(g=>g.Count()>1)) return BadRequest(new { message="รายการอะไหล่ซ้ำ",description="อะไหล่เดียวกันในคลังเดียวกันต้องรวมเป็นหนึ่งรายการ" });
                await IssueRepairParts(c,tx,id,requestNo!,parts,token);
                await UpdateStatus(c,tx,id,"COMPLETED","CompletedDate=SYSUTCDATETIME(),CompletedBy=@user,ResolutionDetail=@detail",token,x.ResolutionDetail);
            }
            else { if(string.IsNullOrWhiteSpace(x.CancellationReason)) return BadRequest(new { message="กรุณาระบุเหตุผลการยกเลิก" }); await UpdateStatus(c,tx,id,"CANCELLED","CancellationReason=@reason",token,null,x.CancellationReason); }
            await tx.CommitAsync(token); return Ok(new { requestId=id,statusCode=next });
        }
        catch (SqlException ex) when (ex.Number is 52330 or 52331)
        { await tx.RollbackAsync(token); return Conflict(new { message="ตัดสต๊อกอะไหล่ไม่สำเร็จ",description=ex.Number==52331?"จำนวนอะไหล่ในคลังไม่เพียงพอ กรุณาโหลดข้อมูลใหม่":"Serial อะไหล่ไม่พร้อมใช้งานหรือไม่อยู่ในคลังที่เลือก" }); }
        catch (InventoryItemProjectDeniedException)
        { await tx.RollbackAsync(token); return StatusCode(403,new { message="ไม่มีสิทธิ์ใช้อะไหล่",description="อะไหล่ไม่ได้เปิดใช้งานสำหรับ Project ของ Company นี้" }); }
        catch (InvalidOperationException ex)
        { await tx.RollbackAsync(token); return BadRequest(new { message="ข้อมูลอะไหล่ไม่ถูกต้อง",description=ex.Message }); }
        catch { await tx.RollbackAsync(token); throw; }
    }

    private async Task IssueRepairParts(SqlConnection c,SqlTransaction tx,long requestId,string requestNo,IReadOnlyList<ServicePartRequest> parts,CancellationToken token)
    {
        foreach(var warehouseGroup in parts.GroupBy(p=>p.WarehouseId))
        {
            if(!await InventoryWarehouseAccess.CanAccessAsync(c,tx,CompanyId,UserId,warehouseGroup.Key,token)) throw new InvalidOperationException("ไม่มีสิทธิ์เข้าถึงคลังที่เลือก");
            var issueCode=$"IS{DateTime.UtcNow:yyyyMMddHHmmssfff}{warehouseGroup.Key%1000:000}";
            await using var header=new SqlCommand("INSERT dbo.TDIVStockIssue(CompanyID,WarehouseID,IssueCode,IssueDate,WorkOrderID,WorkOrderCode,StatusCode,Remark,CreatedBy,ConfirmDate,ConfirmedBy) OUTPUT INSERTED.StockIssueID VALUES(@company,@warehouse,@code,CONVERT(date,SYSUTCDATETIME()),@request,@requestNo,N'CONFIRMED',N'เบิกอะไหล่จากงานซ่อม',@user,SYSUTCDATETIME(),@user)",c,tx);
            Add(header,"@company",SqlDbType.BigInt,CompanyId); Add(header,"@warehouse",SqlDbType.BigInt,warehouseGroup.Key); Add(header,"@code",SqlDbType.NVarChar,issueCode,30); Add(header,"@request",SqlDbType.BigInt,requestId); Add(header,"@requestNo",SqlDbType.NVarChar,requestNo,50); Add(header,"@user",SqlDbType.BigInt,UserId);
            var issueId=Convert.ToInt64(await header.ExecuteScalarAsync(token)); var lineNo=0;
            foreach(var line in warehouseGroup)
            {
                await InventoryItemProjectAccess.EnsureAsync(c,tx,CompanyId,line.ItemId,token);
                string? itemCode=null,itemName=null,unitCode=null,tracking=null; decimal unitCost=0;
                await using(var item=new SqlCommand("SELECT ItemCode,ItemName,UnitCode,CostPrice,StockTrackingCode FROM dbo.TDIVItem I WITH(UPDLOCK,HOLDLOCK) WHERE I.CompanyID=@company AND I.ItemID=@item AND I.IsActive=1 AND I.ItemKindCode=N'GOODS' AND I.StockTrackingCode<>N'NONE' AND EXISTS(SELECT 1 FROM dbo.TDIVItemUsage U WHERE U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode IN(N'MATERIAL',N'SPARE_PART'))",c,tx))
                {
                    Add(item,"@company",SqlDbType.BigInt,CompanyId); Add(item,"@item",SqlDbType.BigInt,line.ItemId); await using var reader=await item.ExecuteReaderAsync(token);
                    if(await reader.ReadAsync(token)){itemCode=reader.GetString(0);itemName=reader.GetString(1);unitCode=Text(reader,2);unitCost=reader.GetDecimal(3);tracking=reader.GetString(4);}
                }
                if(itemCode is null) throw new InvalidOperationException($"ไม่พบอะไหล่ ItemID {line.ItemId} ใน Company นี้");
                var serials=(line.SerialInstanceIds??[]).Distinct().ToArray();
                if(tracking=="SERIAL"&&(line.Quantity!=decimal.Truncate(line.Quantity)||serials.Length!=(int)line.Quantity)) throw new InvalidOperationException($"อะไหล่ {itemCode} ต้องเลือก Serial ให้ครบตามจำนวน");
                if(tracking!="SERIAL"&&serials.Length>0) throw new InvalidOperationException($"อะไหล่ {itemCode} ไม่ได้ควบคุมแบบ Serial");
                lineNo++;
                await using var detail=new SqlCommand("INSERT dbo.TDIVStockIssueDetail(StockIssueID,[LineNo],ItemID,Quantity,Remark) OUTPUT INSERTED.StockIssueDetailID VALUES(@issue,@line,@item,@qty,N'เบิกใช้ในงานซ่อม')",c,tx);
                Add(detail,"@issue",SqlDbType.BigInt,issueId); Add(detail,"@line",SqlDbType.Int,lineNo); Add(detail,"@item",SqlDbType.BigInt,line.ItemId); Add(detail,"@qty",SqlDbType.Decimal,line.Quantity); var detailId=Convert.ToInt64(await detail.ExecuteScalarAsync(token));
                foreach(var serialId in serials)
                {
                    await using var serial=new SqlCommand("INSERT dbo.TDIVStockIssueSerial(StockIssueDetailID,ItemInstanceID) SELECT @detail,X.ItemInstanceID FROM dbo.TDIVItemInstance X WITH(UPDLOCK,HOLDLOCK) WHERE X.ItemInstanceID=@serial AND X.CompanyID=@company AND X.ItemID=@item AND X.WarehouseID=@warehouse AND X.StatusCode=N'IN_STOCK'; IF @@ROWCOUNT=0 THROW 52330,N'Invalid serial for service repair',1",c,tx);
                    Add(serial,"@detail",SqlDbType.BigInt,detailId); Add(serial,"@serial",SqlDbType.BigInt,serialId); Add(serial,"@company",SqlDbType.BigInt,CompanyId); Add(serial,"@item",SqlDbType.BigInt,line.ItemId); Add(serial,"@warehouse",SqlDbType.BigInt,warehouseGroup.Key); await serial.ExecuteNonQueryAsync(token);
                }
                await using(var balance=new SqlCommand("UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK) SET Quantity=Quantity-@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND WarehouseID=@warehouse AND ItemID=@item AND Quantity>=@qty; IF @@ROWCOUNT=0 THROW 52331,N'Insufficient warehouse stock',1; UPDATE dbo.TDIVItem SET StockBalance=StockBalance-@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ItemID=@item AND StockBalance>=@qty",c,tx))
                { Add(balance,"@qty",SqlDbType.Decimal,line.Quantity); Add(balance,"@company",SqlDbType.BigInt,CompanyId); Add(balance,"@warehouse",SqlDbType.BigInt,warehouseGroup.Key); Add(balance,"@item",SqlDbType.BigInt,line.ItemId); await balance.ExecuteNonQueryAsync(token); }
                await using(var movement=new SqlCommand("INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@warehouse,@item,N'SERVICE_REQUEST',@request,@detail,N'ISSUE',-@qty,N'เบิกอะไหล่ใช้ในงานซ่อม',@user)",c,tx))
                { Add(movement,"@company",SqlDbType.BigInt,CompanyId); Add(movement,"@warehouse",SqlDbType.BigInt,warehouseGroup.Key); Add(movement,"@item",SqlDbType.BigInt,line.ItemId); Add(movement,"@request",SqlDbType.BigInt,requestId); Add(movement,"@detail",SqlDbType.BigInt,detailId); Add(movement,"@qty",SqlDbType.Decimal,line.Quantity); Add(movement,"@user",SqlDbType.BigInt,UserId); await movement.ExecuteNonQueryAsync(token); }
                if(serials.Length>0)
                {
                    await using var updateSerial=new SqlCommand("UPDATE X SET StatusCode=N'ISSUED',WarehouseID=NULL,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user FROM dbo.TDIVItemInstance X JOIN dbo.TDIVStockIssueSerial S ON S.ItemInstanceID=X.ItemInstanceID WHERE S.StockIssueDetailID=@detail AND X.CompanyID=@company AND X.StatusCode=N'IN_STOCK'; INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy) SELECT @company,S.ItemInstanceID,N'IN_STOCK',N'ISSUED',N'SERVICE_REQUEST',@request,@detail,N'เบิกอะไหล่ใช้ในงานซ่อม',@user FROM dbo.TDIVStockIssueSerial S WHERE S.StockIssueDetailID=@detail",c,tx);
                    Add(updateSerial,"@user",SqlDbType.BigInt,UserId); Add(updateSerial,"@detail",SqlDbType.BigInt,detailId); Add(updateSerial,"@company",SqlDbType.BigInt,CompanyId); Add(updateSerial,"@request",SqlDbType.BigInt,requestId); await updateSerial.ExecuteNonQueryAsync(token);
                }
                await using var part=new SqlCommand("INSERT dbo.TDADServiceRequestPart(CompanyID,RequestID,StockIssueID,StockIssueDetailID,WarehouseID,ItemID,ItemCodeSnapshot,ItemNameSnapshot,UnitCodeSnapshot,Quantity,UnitCostSnapshot,CreateBy) VALUES(@company,@request,@issue,@detail,@warehouse,@item,@code,@name,@unit,@qty,@cost,@user)",c,tx);
                Add(part,"@company",SqlDbType.BigInt,CompanyId); Add(part,"@request",SqlDbType.BigInt,requestId); Add(part,"@issue",SqlDbType.BigInt,issueId); Add(part,"@detail",SqlDbType.BigInt,detailId); Add(part,"@warehouse",SqlDbType.BigInt,warehouseGroup.Key); Add(part,"@item",SqlDbType.BigInt,line.ItemId); Add(part,"@code",SqlDbType.NVarChar,itemCode,50); Add(part,"@name",SqlDbType.NVarChar,itemName,255); Add(part,"@unit",SqlDbType.NVarChar,unitCode,50); Add(part,"@qty",SqlDbType.Decimal,line.Quantity); Add(part,"@cost",SqlDbType.Decimal,unitCost); Add(part,"@user",SqlDbType.BigInt,UserId); await part.ExecuteNonQueryAsync(token);
            }
        }
    }
    private async Task UpdateStatus(SqlConnection c, SqlTransaction tx, long id, string status, string fields, CancellationToken token, string? detail=null, string? reason=null)
    {
        var sql=$"UPDATE dbo.TDADServiceRequest SET StatusCode=N'{status}',{fields},UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND RequestID=@id AND IsActive=1";
        await using var q=new SqlCommand(sql,c,tx); Add(q,"@user",SqlDbType.BigInt,UserId); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id); Add(q,"@detail",SqlDbType.NVarChar,detail,2000); Add(q,"@reason",SqlDbType.NVarChar,reason,1000); await q.ExecuteNonQueryAsync(token);
    }

    [HttpPost]
    public Task<IActionResult> Create(CreateRequest request, CancellationToken token) =>
        Save(request, false, token);

    [HttpPost("self")]
    public Task<IActionResult> CreateSelf(CreateRequest request, CancellationToken token) =>
        Save(request, true, token);

    private async Task<IActionResult> Save(CreateRequest x, bool self, CancellationToken token)
    {
        await using var c = await Open(token);
        var screen = self ? "20001" : "15001";
        if (!await InService(c, token) || !await Allowed(c, screen, "CREATE", token)) return Forbid();
        var settings = await ReadSettings(c, token);
        if (!settings.ServiceEnabled)
            return BadRequest(new { message = "ระบบบริการปิดใช้งาน", description = "กรุณาติดต่อผู้ดูแลระบบเพื่อเปิดใช้งานระบบบริการ" });
        if (string.IsNullOrWhiteSpace(x.Subject) || string.IsNullOrWhiteSpace(x.Detail))
            return BadRequest(new { message = "กรุณาระบุหัวข้อและรายละเอียด", description = "หัวข้อและรายละเอียดเป็นข้อมูลบังคับ" });

        var type = await BusinessType(c, token);
        var qr = string.IsNullOrWhiteSpace(x.QrToken) ? null : await ResolveQrContext(c, x.QrToken, token);
        if (!string.IsNullOrWhiteSpace(x.QrToken) && qr is null)
            return BadRequest(new { message = "QR Code ไม่ถูกต้อง", description = "QR นี้ปิดใช้งาน ไม่พบข้อมูล หรือไม่ได้อยู่ใน Company ปัจจุบัน" });
        var equipmentItemId = qr?.ItemId ?? x.EquipmentItemId;
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
        try
        {
            var resolved = await Resolve(c, tx, x, type, self, token);
            if (resolved is null)
                return BadRequest(new { message = "ผู้แจ้งไม่ถูกต้อง", description = "ไม่พบข้อมูลผู้แจ้งที่ใช้งานอยู่ใน Company นี้" });
            if (!settings.AllowWalkIn && resolved.Type == "SERVICE_CUSTOMER")
                return BadRequest(new { message = "ไม่อนุญาตผู้แจ้ง Walk-in", description = "ผู้ดูแลระบบปิดการรับแจ้งจากลูกค้าภายนอกไว้" });

            const string nextNo = """
SELECT N'SR'+CONVERT(nvarchar(8),CONVERT(date,SYSUTCDATETIME()),112)
 +RIGHT(N'000000'+CONVERT(nvarchar(6),ISNULL(MAX(TRY_CONVERT(int,RIGHT(RequestNo,6))),0)+1),6)
FROM dbo.TDADServiceRequest WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@company AND RequestNo LIKE N'SR'+CONVERT(nvarchar(8),CONVERT(date,SYSUTCDATETIME()),112)+N'%';
""";
            await using var no = new SqlCommand(nextNo, c, tx);
            Add(no, "@company", SqlDbType.BigInt, CompanyId);
            var requestNo = Convert.ToString(await no.ExecuteScalarAsync(token))!;
            const string insert = """
INSERT dbo.TDADServiceRequest
(CompanyID,RequestNo,RequesterType,RequesterID,RequesterNameSnapshot,RequesterPhoneSnapshot,RequesterEmailSnapshot,
 ServiceCustomerID,ResidentID,TenantID,TenantContactID,RoomID,HouseID,LocationSnapshot,EquipmentItemID,EquipmentCodeSnapshot,EquipmentNameSnapshot,Subject,Detail,CreateBy)
OUTPUT INSERTED.RequestID
VALUES(@company,@no,@rtype,@rid,@name,@phone,@email,@sc,@res,@tenant,@contact,@room,@house,@location,@equipment,@equipmentCode,@equipmentName,@subject,@detail,@user);
""";
            await using var cmd = new SqlCommand(insert, c, tx);
            Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@no", SqlDbType.NVarChar, requestNo, 30);
            Add(cmd, "@rtype", SqlDbType.NVarChar, resolved.Type, 30); Add(cmd, "@rid", SqlDbType.BigInt, resolved.PersonId);
            Add(cmd, "@name", SqlDbType.NVarChar, resolved.Name, 200); Add(cmd, "@phone", SqlDbType.NVarChar, resolved.Phone, 50); Add(cmd, "@email", SqlDbType.NVarChar, resolved.Email, 320);
            Add(cmd, "@sc", SqlDbType.BigInt, resolved.ServiceCustomerId); Add(cmd, "@res", SqlDbType.BigInt, resolved.ResidentId); Add(cmd, "@tenant", SqlDbType.BigInt, resolved.TenantId); Add(cmd, "@contact", SqlDbType.BigInt, resolved.ContactId);
            Add(cmd, "@room", SqlDbType.BigInt, resolved.RoomId); Add(cmd, "@house", SqlDbType.BigInt, resolved.HouseId); Add(cmd, "@location", SqlDbType.NVarChar, qr?.LocationSnapshot ?? resolved.Location, 500); Add(cmd, "@equipment", SqlDbType.BigInt, equipmentItemId); Add(cmd, "@equipmentCode", SqlDbType.NVarChar, equipmentCode, 50); Add(cmd, "@equipmentName", SqlDbType.NVarChar, equipmentName, 200);
            Add(cmd, "@subject", SqlDbType.NVarChar, x.Subject.Trim(), 200); Add(cmd, "@detail", SqlDbType.NVarChar, x.Detail.Trim(), 2000); Add(cmd, "@user", SqlDbType.BigInt, UserId);
            var id = Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
            await tx.CommitAsync(token);
            return Ok(new { requestId = id, requestNo });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627)
        {
            await tx.RollbackAsync(token);
            return Conflict(new { message = "บันทึกไม่สำเร็จ", description = "เลขที่ใบแจ้งซ่อมซ้ำ กรุณาลองใหม่" });
        }
        catch
        {
            await tx.RollbackAsync(token);
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
        while (await r.ReadAsync(token)) rows.Add(new { id = r.GetInt64(0), requesterType = r.GetString(1), name = r.GetString(2), phone = Text(r, 3), email = Text(r, 4), locationSnapshot = Text(r, 5) });
        return rows;
    }

    private async Task<bool> InService(SqlConnection c, CancellationToken t) =>
        CompanyId > 0 && await CompanyProjectPermission.IsAllowedAsync(c, User, "15001", "VIEW", t) || CompanyId > 0 && await CompanyProjectPermission.IsAllowedAsync(c, User, "20001", "VIEW", t);

    private Task<bool> Allowed(SqlConnection c, string screen, string action, CancellationToken t) =>
        CompanyProjectPermission.IsAllowedAsync(c, User, screen, action, t);

    private async Task<string> BusinessType(SqlConnection c, CancellationToken t)
    {
        await using var q = new SqlCommand("SELECT ISNULL(NULLIF(UPPER(LTRIM(RTRIM(BusinessTypeCode))),N''),N'COMPANY') FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company", c);
        Add(q, "@company", SqlDbType.BigInt, CompanyId); return CompanyBusinessType.Normalize(Convert.ToString(await q.ExecuteScalarAsync(t)));
    }

    private async Task<QrContext?> ResolveQrContext(SqlConnection c, string tokenValue, CancellationToken token)
    {
        const string sql = """
SELECT X.ItemID,CONCAT_WS(N' / ',NULLIF(B.BuildingNameTH,N''),NULLIF(F.FloorNameTH,N''),NULLIF(R.RoomCode,N''))
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
        return await r.ReadAsync(token) ? new(r.GetInt64(0), Text(r, 1)) : null;
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

    private async Task<RequestAccessInfo> RequestAccess(SqlConnection c, long id, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT StatusCode,CreateBy FROM dbo.TDADServiceRequest WHERE CompanyID=@company AND RequestID=@id AND IsActive=1", c);
        Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id); await using var r=await q.ExecuteReaderAsync(token);
        return await r.ReadAsync(token) ? new(true,r.GetString(0),r.IsDBNull(1)?null:r.GetInt64(1)) : new(false,string.Empty,null);
    }

    private async Task<ProcessedImage> ProcessImage(IFormFile file, CancellationToken token)
    {
        var contentType = (file.ContentType ?? string.Empty).Trim().ToLowerInvariant();
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        var supported = contentType is "image/jpeg" or "image/png" or "image/webp" || extension is ".jpg" or ".jpeg" or ".png" or ".webp";
        if (!supported) return ProcessedImage.Rejected("รองรับเฉพาะไฟล์ JPG, PNG และ WEBP");
        await using var input = new MemoryStream(); await file.CopyToAsync(input, token); var original = input.ToArray(); input.Position=0;
        try
        {
            using var image = await Image.LoadAsync(input, token);
            if (original.Length <= MaxAttachmentBytes)
                return new(original, NormalizeContentType(contentType, extension), NormalizeExtension(contentType, extension), image.Width, image.Height, null);
            foreach (var maxDimension in new[] { 2400, 2000, 1600, 1200, 900, 700, 500 })
            {
                using var candidate = image.CloneAs<Rgba32>();
                if (image.Width > maxDimension || image.Height > maxDimension)
                    candidate.Mutate(ctx => ctx.Resize(new ResizeOptions { Mode=ResizeMode.Max, Size=new Size(maxDimension,maxDimension) }));
                foreach (var quality in new[] { 88, 78, 68, 58, 48, 38, 30 })
                {
                    await using var output = new MemoryStream(); candidate.SaveAsJpeg(output, new JpegEncoder { Quality=quality });
                    if (output.Length <= MaxAttachmentBytes) return new(output.ToArray(),"image/jpeg",".jpg",candidate.Width,candidate.Height,null);
                }
            }
            return ProcessedImage.Rejected("ระบบลดขนาดรูปแล้ว แต่ไฟล์ยังเกิน 1 MB");
        }
        catch (Exception) { return ProcessedImage.Rejected("ไฟล์รูปภาพไม่ถูกต้องหรือไม่สามารถอ่านได้"); }
    }

    private string? SafeFilePath(string relative)
    {
        var root = environment.WebRootPath; if (string.IsNullOrWhiteSpace(root)) root=Path.Combine(environment.ContentRootPath,"wwwroot");
        var rootPath=Path.GetFullPath(root)+Path.DirectorySeparatorChar; var full=Path.GetFullPath(Path.Combine(root,relative.Replace('/',Path.DirectorySeparatorChar)));
        return full.StartsWith(rootPath,StringComparison.OrdinalIgnoreCase) ? full : null;
    }

    private void TryDelete(string relative) { var full=SafeFilePath(relative); if (full is not null) try { if(System.IO.File.Exists(full)) System.IO.File.Delete(full); } catch { } }
    private static string SafeOriginalName(string value) => Path.GetFileName(value).Trim() is { Length: > 0 } name ? name[..Math.Min(name.Length,255)] : "attachment";
    private static string NormalizeContentType(string contentType,string extension) => contentType switch { "image/jpeg" or "image/png" or "image/webp" => contentType, ".png" => "image/png", ".webp" => "image/webp", _ => "image/jpeg" };
    private static string NormalizeExtension(string contentType,string extension) => contentType switch { "image/png" => ".png", "image/webp" => ".webp", _ => extension is ".png" or ".webp" ? extension : ".jpg" };

    private async Task<SqlConnection> Open(CancellationToken t) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(t); return c; }
    private long ClaimLong(string name) => long.TryParse(User.FindFirstValue(name), out var value) ? value : 0;
    private long? ClaimLongNullable(string name) => long.TryParse(User.FindFirstValue(name), out var value) ? value : null;
    private static long? Long(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetInt64(index);
    private static int? LongInt(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetInt32(index);
    private static string? Text(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetString(index);
    private static DateTime? DateTimeValue(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetDateTime(index);
    private static void Add(SqlCommand c, string name, SqlDbType type, object? value, int size = 0) { var p = size == 0 ? c.Parameters.Add(name, type) : c.Parameters.Add(name, type, size); p.Value = value ?? DBNull.Value; }

    public sealed record CreateRequest(string? RequesterType, long? RequesterId, long? EquipmentItemId, string? Subject, string? Detail, string? QrToken = null);
    public sealed record ActionRequest(long? AssignedEmployeeId, string? ResolutionDetail, string? CancellationReason, IReadOnlyList<ServicePartRequest>? Parts = null);
    public sealed record ServicePartRequest(long WarehouseId,long ItemId,decimal Quantity,IReadOnlyList<long>? SerialInstanceIds = null);
    private sealed record RequestAccessInfo(bool Found,string Status,long? CreatedBy);
    private sealed record ProcessedImage(byte[] Bytes,string ContentType,string Extension,int Width,int Height,string? Error)
    {
        public static ProcessedImage Rejected(string error) => new(Array.Empty<byte>(),string.Empty,string.Empty,0,0,error);
    }
    private sealed record Resolved(string Type,long PersonId,string Name,string? Phone,string? Email,long? ServiceCustomerId,long? ResidentId,long? TenantId,long? ContactId,long? RoomId,long? HouseId,string? Location);
    private sealed record QrContext(long ItemId, string? LocationSnapshot);
}
