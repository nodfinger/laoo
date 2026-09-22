using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/service/requests")]
public sealed class ServiceRequestController(IConfiguration configuration) : ControllerBase
{
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
        return Ok(new { businessTypeCode = type, requesters = rows, equipment });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? status, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken token = default)
    {
        await using var c = await Open(token);
        if (!await InService(c, token) || !await Allowed(c, "15001", "VIEW", token)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        const string sql = """
SELECT COUNT_BIG(1) OVER(),RequestID,RequestNo,RequesterType,RequesterNameSnapshot,LocationSnapshot,
       Subject,StatusCode,RequestDate,RowVersion
FROM dbo.TDADServiceRequest
WHERE CompanyID=@company AND IsActive=1
  AND (@status=N'' OR StatusCode=@status)
  AND (@q=N'' OR RequestNo LIKE N'%'+@q+N'%' OR RequesterNameSnapshot LIKE N'%'+@q+N'%' OR Subject LIKE N'%'+@q+N'%')
ORDER BY RequestDate DESC,RequestID DESC OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId);
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
                subject = r.GetString(6),
                statusCode = r.GetString(7),
                requestDate = r.GetDateTime(8),
                rowVersion = Convert.ToBase64String((byte[])r[9])
            });
        }
        return Ok(new { items, total, page, pageSize });
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
        if (string.IsNullOrWhiteSpace(x.Subject) || string.IsNullOrWhiteSpace(x.Detail))
            return BadRequest(new { message = "กรุณาระบุหัวข้อและรายละเอียด", description = "หัวข้อและรายละเอียดเป็นข้อมูลบังคับ" });

        var type = await BusinessType(c, token);
        if (!x.EquipmentItemId.HasValue)
            return BadRequest(new { message = "กรุณาเลือกอุปกรณ์", description = "รายการแจ้งซ่อมต้องระบุอุปกรณ์ที่ใช้กับระบบ Service" });
        string? equipmentCode = null, equipmentName = null;
        await using (var equipmentCheck = new SqlCommand("SELECT I.ItemCode,I.ItemName FROM dbo.TDIVItem I JOIN dbo.TDIVItemUsage U ON U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode=N'EQUIPMENT' WHERE I.CompanyID=@company AND I.ItemID=@id AND I.IsActive=1", c))
        {
            Add(equipmentCheck, "@company", SqlDbType.BigInt, CompanyId);
            Add(equipmentCheck, "@id", SqlDbType.BigInt, x.EquipmentItemId);
            await using var equipmentReader = await equipmentCheck.ExecuteReaderAsync(token);
            if (!await equipmentReader.ReadAsync(token))
                return BadRequest(new { message = "ข้อมูลอุปกรณ์ไม่ถูกต้อง", description = "ไม่พบอุปกรณ์ที่ใช้งานได้ในระบบ Service" });
            equipmentCode = equipmentReader.GetString(0);
            equipmentName = equipmentReader.GetString(1);
        }
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            var resolved = await Resolve(c, tx, x, type, self, token);
            if (resolved is null)
                return BadRequest(new { message = "ผู้แจ้งไม่ถูกต้อง", description = "ไม่พบข้อมูลผู้แจ้งที่ใช้งานอยู่ใน Company นี้" });

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
            Add(cmd, "@room", SqlDbType.BigInt, resolved.RoomId); Add(cmd, "@house", SqlDbType.BigInt, resolved.HouseId); Add(cmd, "@location", SqlDbType.NVarChar, resolved.Location, 500); Add(cmd, "@equipment", SqlDbType.BigInt, x.EquipmentItemId); Add(cmd, "@equipmentCode", SqlDbType.NVarChar, equipmentCode, 50); Add(cmd, "@equipmentName", SqlDbType.NVarChar, equipmentName, 200);
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

    private async Task<SqlConnection> Open(CancellationToken t) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(t); return c; }
    private long ClaimLong(string name) => long.TryParse(User.FindFirstValue(name), out var value) ? value : 0;
    private long? ClaimLongNullable(string name) => long.TryParse(User.FindFirstValue(name), out var value) ? value : null;
    private static long? Long(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetInt64(index);
    private static string? Text(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetString(index);
    private static void Add(SqlCommand c, string name, SqlDbType type, object? value, int size = 0) { var p = size == 0 ? c.Parameters.Add(name, type) : c.Parameters.Add(name, type, size); p.Value = value ?? DBNull.Value; }

    public sealed record CreateRequest(string? RequesterType, long? RequesterId, long? EquipmentItemId, string? Subject, string? Detail);
    private sealed record Resolved(string Type,long PersonId,string Name,string? Phone,string? Email,long? ServiceCustomerId,long? ResidentId,long? TenantId,long? ContactId,long? RoomId,long? HouseId,string? Location);
}
