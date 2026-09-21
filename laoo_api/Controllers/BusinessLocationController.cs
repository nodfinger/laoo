using System.Data;
using System.Security.Claims;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/business-locations")]
public sealed class BusinessLocationController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => long.TryParse(User.FindFirstValue("company_id"), out var value) ? value : 0;
    private long ActorId => long.TryParse(User.FindFirstValue("user_id"), out var value) ? value : 0;

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private async Task<bool> Allowed(SqlConnection connection, string action, CancellationToken token)
    {
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(connection, User, "14001", action, token))
            return false;
        if (!long.TryParse(User.FindFirstValue("partner_id"), out var partnerId)) return false;
        await using var command = new SqlCommand("""
            SELECT COUNT(*) FROM dbo.TDSTCompanySetUp
            WHERE CompanyID=@company AND PartnerID=@partner AND IsActive=1;
            """, connection);
        Add(command, "@company", SqlDbType.BigInt, CompanyId);
        Add(command, "@partner", SqlDbType.BigInt, partnerId);
        return Convert.ToInt32(await command.ExecuteScalarAsync(token)) == 1;
    }

    [HttpGet("rental-office/tenants")]
    public async Task<IActionResult> RentalTenants([FromQuery] long? roomId, [FromQuery] string? search, [FromQuery] bool active = true, CancellationToken token = default)
    {
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        const string sql = """
            SELECT T.TenantID tenantId,T.RoomID roomId,T.CustomerID customerId,
                   T.TenantCompanyName tenantCompanyName,T.TenantNameSnapshot tenantNameSnapshot,
                   T.StartDate startDate,T.EndDate endDate,T.IsActive active,
                   R.RoomCode roomCode,R.RoomNameTH roomName,B.BuildingNameTH buildingName,
                   F.FloorNameTH floorName
            FROM dbo.TDADRentalOfficeTenant T
            JOIN dbo.TDADRoom R ON R.CompanyID=T.CompanyID AND R.RoomID=T.RoomID
            JOIN dbo.TDADBuilding B ON B.CompanyID=R.CompanyID AND B.BuildingID=R.BuildingID
            JOIN dbo.TDADFloor F ON F.BuildingID=R.BuildingID AND F.FloorID=R.FloorID
            WHERE T.CompanyID=@company AND (@roomId IS NULL OR T.RoomID=@roomId)
              AND T.IsActive=@active AND (@search=N'' OR T.TenantCompanyName LIKE N'%'+@search+N'%' OR R.RoomCode LIKE N'%'+@search+N'%')
            ORDER BY B.BuildingCode,F.FloorCode,R.RoomCode,T.TenantID;
            SELECT C.TenantContactID contactId,C.TenantID tenantId,C.PersonID personId,C.ContactName contactName,
                   C.Phone phone,C.Email email,C.IsPrimary isPrimary,C.IsActive active
            FROM dbo.TDADRentalOfficeTenantContact C
            JOIN dbo.TDADRentalOfficeTenant T ON T.CompanyID=C.CompanyID AND T.TenantID=C.TenantID
            WHERE C.CompanyID=@company AND C.IsActive=1;
            """;
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@company", SqlDbType.BigInt, CompanyId);
        Add(command, "@roomId", SqlDbType.BigInt, roomId);
        Add(command, "@active", SqlDbType.Bit, active);
        Add(command, "@search", SqlDbType.NVarChar, search?.Trim() ?? string.Empty, 200);
        return Ok(await ReadSets(command, token));
    }

    [HttpGet("village/lanes")]
    public async Task<IActionResult> VillageLanes([FromQuery] bool active = true, CancellationToken token = default)
    {
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        await using var command = new SqlCommand("SELECT LaneID id,LaneType type,LaneCode code,LaneName name,IsActive active FROM dbo.TDADVillageLane WHERE CompanyID=@company AND IsActive=@active ORDER BY LaneType,LaneCode,LaneID", connection);
        Add(command, "@company", SqlDbType.BigInt, CompanyId); Add(command, "@active", SqlDbType.Bit, active);
        return Ok(await ReadRows(command, token));
    }

    [HttpGet("village/houses")]
    public async Task<IActionResult> VillageHouses([FromQuery] long? laneId, [FromQuery] bool active = true, CancellationToken token = default)
    {
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        await using var command = new SqlCommand("SELECT H.HouseID id,H.LaneID laneId,H.HouseNo houseNo,H.AddressText address,H.IsActive active,L.LaneType laneType,L.LaneCode laneCode,L.LaneName laneName FROM dbo.TDADVillageHouse H JOIN dbo.TDADVillageLane L ON L.CompanyID=H.CompanyID AND L.LaneID=H.LaneID WHERE H.CompanyID=@company AND (@laneId IS NULL OR H.LaneID=@laneId) AND H.IsActive=@active ORDER BY L.LaneCode,H.HouseNo,H.HouseID", connection);
        Add(command, "@company", SqlDbType.BigInt, CompanyId); Add(command, "@laneId", SqlDbType.BigInt, laneId); Add(command, "@active", SqlDbType.Bit, active);
        return Ok(await ReadRows(command, token));
    }

    [HttpGet("village/residents")]
    public async Task<IActionResult> VillageResidents([FromQuery] long? houseId, [FromQuery] bool active = true, CancellationToken token = default)
    {
        await using var connection = await Open(token); if (!await Allowed(connection, "VIEW", token)) return Forbid();
        const string sql = """
            SELECT R.ResidentID id,R.HouseID houseId,R.PersonID personId,P.FullName personName,
                   R.StartDate startDate,R.EndDate endDate,R.IsActive active,H.HouseNo houseNo,
                   L.LaneType laneType,L.LaneCode laneCode,L.LaneName laneName
            FROM dbo.TDADResident R
            JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID
            JOIN dbo.TDADVillageHouse H ON H.CompanyID=R.CompanyID AND H.HouseID=R.HouseID
            JOIN dbo.TDADVillageLane L ON L.CompanyID=H.CompanyID AND L.LaneID=H.LaneID
            WHERE R.CompanyID=@company AND R.RoomID IS NULL AND (@houseId IS NULL OR R.HouseID=@houseId) AND R.IsActive=@active
            ORDER BY L.LaneCode,H.HouseNo,P.FullName,R.ResidentID;
            """;
        await using var command = new SqlCommand(sql, connection); Add(command, "@company", SqlDbType.BigInt, CompanyId); Add(command, "@houseId", SqlDbType.BigInt, houseId); Add(command, "@active", SqlDbType.Bit, active);
        return Ok(await ReadRows(command, token));
    }
    [HttpGet("hosts")]
    public async Task<IActionResult> Hosts([FromQuery] string businessTypeCode, [FromQuery] string? search, CancellationToken token = default)
    {
        var type = Models.CompanyBusinessType.Normalize(businessTypeCode);
        if (type is not (Models.CompanyBusinessType.RentalOffice or Models.CompanyBusinessType.Village)) return BadRequest(new { message = "รองรับเฉพาะสำนักงานเช่าหรือหมู่บ้าน" });
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        var rows = new List<Dictionary<string, object?>>();
        if (type == Models.CompanyBusinessType.RentalOffice)
        {
            await using var command = new SqlCommand("""
                SELECT T.TenantID hostId,T.TenantID tenantId,C.TenantContactID contactId,
                       T.TenantCompanyName displayName,C.ContactName contactName,
                       N'RENTAL_OFFICE' hostType,R.RoomID roomId,R.RoomCode roomCode,
                       R.RoomNameTH roomName,B.BuildingNameTH buildingName,F.FloorNameTH floorName
                FROM dbo.TDADRentalOfficeTenant T
                JOIN dbo.TDADRoom R ON R.CompanyID=T.CompanyID AND R.RoomID=T.RoomID
                JOIN dbo.TDADBuilding B ON B.CompanyID=R.CompanyID AND B.BuildingID=R.BuildingID
                JOIN dbo.TDADFloor F ON F.BuildingID=R.BuildingID AND F.FloorID=R.FloorID
                LEFT JOIN dbo.TDADRentalOfficeTenantContact C ON C.CompanyID=T.CompanyID AND C.TenantID=T.TenantID AND C.IsActive=1
                WHERE T.CompanyID=@company AND T.IsActive=1
                  AND (@search=N'' OR T.TenantCompanyName LIKE N'%'+@search+N'%' OR R.RoomCode LIKE N'%'+@search+N'%' OR C.ContactName LIKE N'%'+@search+N'%')
                ORDER BY displayName,C.IsPrimary DESC,C.ContactName
                """, connection);
            Add(command, "@company", SqlDbType.BigInt, CompanyId); Add(command, "@search", SqlDbType.NVarChar, search?.Trim() ?? string.Empty, 200);
            rows = await ReadRows(command, token);
        }
        else
        {
            await using var command = new SqlCommand("SELECT R.ResidentID hostId,P.FullName displayName,N'VILLAGE' hostType,H.HouseID houseId,H.HouseNo houseNo,L.LaneID laneId,L.LaneType laneType,L.LaneCode laneCode,L.LaneName laneName FROM dbo.TDADResident R JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID JOIN dbo.TDADVillageHouse H ON H.CompanyID=R.CompanyID AND H.HouseID=R.HouseID JOIN dbo.TDADVillageLane L ON L.CompanyID=H.CompanyID AND L.LaneID=H.LaneID WHERE R.CompanyID=@company AND R.RoomID IS NULL AND R.IsActive=1 AND P.IsActive=1 AND (@search=N'' OR P.FullName LIKE N'%'+@search+N'%' OR H.HouseNo LIKE N'%'+@search+N%' OR L.LaneName LIKE N'%'+@search+N'%') ORDER BY displayName", connection);
            Add(command, "@company", SqlDbType.BigInt, CompanyId); Add(command, "@search", SqlDbType.NVarChar, search?.Trim() ?? string.Empty, 200);
            rows = await ReadRows(command, token);
        }
        return Ok(rows);
    }

    [HttpPost("rental-office/tenants")]
    public Task<IActionResult> CreateTenant(RentalTenantRequest request, CancellationToken token) => SaveTenant(null, request, token);
    [HttpPut("rental-office/tenants/{id:long}")]
    public Task<IActionResult> UpdateTenant(long id, RentalTenantRequest request, CancellationToken token) => SaveTenant(id, request, token);

    [HttpPost("rental-office/tenants/{tenantId:long}/contacts")]
    public Task<IActionResult> CreateContact(long tenantId, RentalContactRequest request, CancellationToken token) => SaveContact(null, tenantId, request, token);
    [HttpPut("rental-office/contacts/{id:long}")]
    public Task<IActionResult> UpdateContact(long id, RentalContactRequest request, CancellationToken token) => SaveContact(id, request.TenantId, request, token);

    [HttpPost("village/lanes")]
    public Task<IActionResult> CreateLane(VillageLaneRequest request, CancellationToken token) => SaveLane(null, request, token);
    [HttpPut("village/lanes/{id:long}")]
    public Task<IActionResult> UpdateLane(long id, VillageLaneRequest request, CancellationToken token) => SaveLane(id, request, token);

    [HttpPost("village/houses")]
    public Task<IActionResult> CreateHouse(VillageHouseRequest request, CancellationToken token) => SaveHouse(null, request, token);
    [HttpPut("village/houses/{id:long}")]
    public Task<IActionResult> UpdateHouse(long id, VillageHouseRequest request, CancellationToken token) => SaveHouse(id, request, token);

    [HttpPost("village/residents")]
    public Task<IActionResult> CreateResident(VillageResidentRequest request, CancellationToken token) => SaveResident(null, request, token);
    [HttpPut("village/residents/{id:long}")]
    public Task<IActionResult> UpdateResident(long id, VillageResidentRequest request, CancellationToken token) => SaveResident(id, request, token);

    private async Task<IActionResult> SaveTenant(long? id, RentalTenantRequest x, CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(x.Name) || x.Name.Length > 200 || x.StartDate == default || (x.EndDate.HasValue && x.EndDate.Value < x.StartDate)) return BadRequest(new { message = "กรุณาระบุบริษัทผู้เช่าและช่วงวันที่เช่าให้ถูกต้อง" });
        await using var c = await Open(token); if (!await Allowed(c, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        if (!await IsBusinessType(c, Models.CompanyBusinessType.RentalOffice, token)) return BadRequest(new { message = "Company นี้ไม่ได้ตั้งเป็นสำนักงานเช่า" });
        const string sql = """
            IF NOT EXISTS(SELECT 1 FROM dbo.TDADRoom R JOIN dbo.TDADBuilding B ON B.CompanyID=R.CompanyID AND B.BuildingID=R.BuildingID JOIN dbo.TDADFloor F ON F.BuildingID=R.BuildingID AND F.FloorID=R.FloorID WHERE R.CompanyID=@company AND R.RoomID=@room AND R.RoomTypeCode=N'OFFICE' AND (@active=0 OR (R.IsActive=1 AND B.IsActive=1 AND F.IsActive=1)) ) THROW 52910,'OFFICE_ROOM_REQUIRED',1;
            IF @active=1 AND EXISTS(SELECT 1 FROM dbo.TDADRentalOfficeTenant WHERE CompanyID=@company AND RoomID=@room AND IsActive=1 AND (@id IS NULL OR TenantID<>@id)) THROW 52911,'ACTIVE_TENANT_EXISTS',1;
            IF @id IS NULL BEGIN INSERT dbo.TDADRentalOfficeTenant(CompanyID,RoomID,CustomerID,TenantCompanyName,TenantNameSnapshot,StartDate,EndDate,IsActive,CreateBy) VALUES(@company,@room,@customer,@name,@name,@start,@end,@active,@actor); SET @id=SCOPE_IDENTITY(); END
            ELSE UPDATE dbo.TDADRentalOfficeTenant SET RoomID=@room,CustomerID=@customer,TenantCompanyName=@name,TenantNameSnapshot=@name,StartDate=@start,EndDate=@end,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND TenantID=@id;
            SELECT @id;
            """;
        await using var cmd = new SqlCommand(sql, c); Add(cmd,"@id",SqlDbType.BigInt,id); Add(cmd,"@company",SqlDbType.BigInt,CompanyId); Add(cmd,"@room",SqlDbType.BigInt,x.RoomId); Add(cmd,"@customer",SqlDbType.BigInt,x.CustomerId); Add(cmd,"@name",SqlDbType.NVarChar,x.Name.Trim(),200); Add(cmd,"@start",SqlDbType.Date,x.StartDate); Add(cmd,"@end",SqlDbType.Date,x.EndDate); Add(cmd,"@active",SqlDbType.Bit,x.Active); Add(cmd,"@actor",SqlDbType.BigInt,ActorId);
        try { var saved=Convert.ToInt64(await cmd.ExecuteScalarAsync(token)); return Ok(new { id=saved }); } catch(SqlException e) when(e.Number is 52910 or 52911 or 2601 or 2627) { return Conflict(new { message="บันทึกผู้เช่าไม่ได้", description=e.Message }); }
    }

    private async Task<IActionResult> SaveContact(long? id, long tenantId, RentalContactRequest x, CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(x.Name) || x.Name.Length > 200)
            return BadRequest(new { message = "กรุณาระบุชื่อผู้ติดต่อ" });
        await using var c = await Open(token);
        if (!await Allowed(c, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        if (!await IsBusinessType(c, Models.CompanyBusinessType.RentalOffice, token))
            return BadRequest(new { message = "Company นี้ไม่ได้ตั้งเป็นสำนักงานเช่า" });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        const string sql = """
            IF NOT EXISTS(SELECT 1 FROM dbo.TDADRentalOfficeTenant WHERE CompanyID=@company AND TenantID=@tenant) THROW 52912,'TENANT_NOT_FOUND',1;
            IF @person IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADPerson WHERE CompanyID=@company AND PersonID=@person AND IsActive=1) THROW 52913,'PERSON_NOT_FOUND',1;
            IF @active=0 SET @primary=0;
            IF @primary=1 UPDATE dbo.TDADRentalOfficeTenantContact SET IsPrimary=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND TenantID=@tenant AND (@id IS NULL OR TenantContactID<>@id);
            IF @id IS NULL
            BEGIN
                INSERT dbo.TDADRentalOfficeTenantContact(CompanyID,TenantID,PersonID,ContactName,Phone,Email,IsPrimary,IsActive,CreateBy)
                VALUES(@company,@tenant,@person,@name,@phone,@email,@primary,@active,@actor); SET @id=SCOPE_IDENTITY();
            END
            ELSE UPDATE dbo.TDADRentalOfficeTenantContact SET TenantID=@tenant,PersonID=@person,ContactName=@name,Phone=@phone,Email=@email,IsPrimary=@primary,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND TenantContactID=@id;
            SELECT @id;
            """;
        await using var cmd=new SqlCommand(sql,c,tx); Add(cmd,"@id",SqlDbType.BigInt,id); Add(cmd,"@company",SqlDbType.BigInt,CompanyId); Add(cmd,"@tenant",SqlDbType.BigInt,tenantId); Add(cmd,"@person",SqlDbType.BigInt,x.PersonId); Add(cmd,"@name",SqlDbType.NVarChar,x.Name.Trim(),200); Add(cmd,"@phone",SqlDbType.NVarChar,x.Phone,50); Add(cmd,"@email",SqlDbType.NVarChar,x.Email,320); Add(cmd,"@primary",SqlDbType.Bit,x.Primary); Add(cmd,"@active",SqlDbType.Bit,x.Active); Add(cmd,"@actor",SqlDbType.BigInt,ActorId);
        try { var saved=Convert.ToInt64(await cmd.ExecuteScalarAsync(token)); await tx.CommitAsync(token); return Ok(new { id=saved }); }
        catch(SqlException e) when(e.Number is 52912 or 52913) { await tx.RollbackAsync(token); return NotFound(new { message="ไม่พบผู้เช่าหรือบุคคลใน Company นี้" }); }
    }
    private async Task<IActionResult> SaveLane(long? id, VillageLaneRequest x, CancellationToken token)
    {
        if (x.Type is not ("SOI" or "JUNCTION") || string.IsNullOrWhiteSpace(x.Code) || string.IsNullOrWhiteSpace(x.Name)) return BadRequest(new { message="ประเภทและข้อมูลซอย/แยกไม่ถูกต้อง" });
        await using var c=await Open(token); if(!await Allowed(c,id.HasValue?"EDIT":"CREATE",token)) return Forbid();
        if (!await IsBusinessType(c, Models.CompanyBusinessType.Village, token)) return BadRequest(new { message = "Company นี้ไม่ได้ตั้งเป็นหมู่บ้าน" });
        const string sql="IF @id IS NULL BEGIN INSERT dbo.TDADVillageLane(CompanyID,LaneType,LaneCode,LaneName,IsActive,CreateBy) VALUES(@company,@type,@code,@name,@active,@actor); SET @id=SCOPE_IDENTITY(); END ELSE UPDATE dbo.TDADVillageLane SET LaneType=@type,LaneCode=@code,LaneName=@name,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND LaneID=@id; SELECT @id;";
        await using var cmd=new SqlCommand(sql,c); Add(cmd,"@id",SqlDbType.BigInt,id); Add(cmd,"@company",SqlDbType.BigInt,CompanyId); Add(cmd,"@type",SqlDbType.NVarChar,x.Type,20); Add(cmd,"@code",SqlDbType.NVarChar,x.Code.Trim(),50); Add(cmd,"@name",SqlDbType.NVarChar,x.Name.Trim(),200); Add(cmd,"@active",SqlDbType.Bit,x.Active); Add(cmd,"@actor",SqlDbType.BigInt,ActorId);
        try{return Ok(new{id=Convert.ToInt64(await cmd.ExecuteScalarAsync(token))});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสซอย/แยกซ้ำใน Company"});}
    }

    private async Task<IActionResult> SaveHouse(long? id, VillageHouseRequest x, CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(x.HouseNo) || x.HouseNo.Length > 100) return BadRequest(new { message="กรุณาระบุบ้านเลขที่" });
        await using var c=await Open(token); if(!await Allowed(c,id.HasValue?"EDIT":"CREATE",token)) return Forbid();
        if (!await IsBusinessType(c, Models.CompanyBusinessType.Village, token)) return BadRequest(new { message = "Company นี้ไม่ได้ตั้งเป็นหมู่บ้าน" });
        const string sql="IF NOT EXISTS(SELECT 1 FROM dbo.TDADVillageLane WHERE CompanyID=@company AND LaneID=@lane AND IsActive=1) THROW 52914,'LANE_NOT_FOUND',1; IF @id IS NULL BEGIN INSERT dbo.TDADVillageHouse(CompanyID,LaneID,HouseNo,AddressText,IsActive,CreateBy) VALUES(@company,@lane,@house,@address,@active,@actor); SET @id=SCOPE_IDENTITY(); END ELSE UPDATE dbo.TDADVillageHouse SET LaneID=@lane,HouseNo=@house,AddressText=@address,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND HouseID=@id; SELECT @id;";
        await using var cmd=new SqlCommand(sql,c); Add(cmd,"@id",SqlDbType.BigInt,id); Add(cmd,"@company",SqlDbType.BigInt,CompanyId); Add(cmd,"@lane",SqlDbType.BigInt,x.LaneId); Add(cmd,"@house",SqlDbType.NVarChar,x.HouseNo.Trim(),100); Add(cmd,"@address",SqlDbType.NVarChar,x.AddressText,500); Add(cmd,"@active",SqlDbType.Bit,x.Active); Add(cmd,"@actor",SqlDbType.BigInt,ActorId);
        try{return Ok(new{id=Convert.ToInt64(await cmd.ExecuteScalarAsync(token))});}catch(SqlException e)when(e.Number is 52914 or 2601 or 2627){return Conflict(new{message="บันทึกบ้านไม่ได้ หรือข้อมูลซ้ำ"});}
    }

    private async Task<IActionResult> SaveResident(long? id, VillageResidentRequest x, CancellationToken token)
    {
        if (x.StartDate == default || x.EndDate < x.StartDate) return BadRequest(new { message = "กรุณาระบุช่วงวันที่อยู่อาศัยให้ถูกต้อง" });
        await using var c = await Open(token); if (!await Allowed(c, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        if (!await IsBusinessType(c, Models.CompanyBusinessType.Village, token)) return BadRequest(new { message = "Company นี้ไม่ได้ตั้งเป็นหมู่บ้าน" });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        const string sql = """
IF NOT EXISTS(SELECT 1 FROM dbo.TDADVillageHouse WHERE CompanyID=@company AND HouseID=@house AND IsActive=1) THROW 52915,'HOUSE_NOT_FOUND',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADPerson WHERE CompanyID=@company AND PersonID=@person AND IsActive=1) THROW 52913,'PERSON_NOT_FOUND',1;
IF @id IS NULL
BEGIN
    INSERT dbo.TDADResident(CompanyID,HouseID,PersonID,StartDate,EndDate,IsActive,CreateBy) VALUES(@company,@house,@person,@start,@end,@active,@actor);
    SET @id=SCOPE_IDENTITY();
    INSERT dbo.TDADVillageResident(CompanyID,HouseID,PersonID,StartDate,EndDate,IsActive,CreateBy,ResidentID) VALUES(@company,@house,@person,@start,@end,@active,@actor,@id);
END
ELSE
BEGIN
    UPDATE dbo.TDADResident SET HouseID=@house,PersonID=@person,StartDate=@start,EndDate=@end,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND ResidentID=@id;
    UPDATE dbo.TDADVillageResident SET HouseID=@house,PersonID=@person,StartDate=@start,EndDate=@end,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor,ResidentID=@id WHERE CompanyID=@company AND (ResidentID=@id OR VillageResidentID=@id);
END
SELECT @id;
""";
        try { await using var cmd = new SqlCommand(sql, c, tx); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@house", SqlDbType.BigInt, x.HouseId); Add(cmd, "@person", SqlDbType.BigInt, x.PersonId); Add(cmd, "@start", SqlDbType.Date, x.StartDate); Add(cmd, "@end", SqlDbType.Date, x.EndDate); Add(cmd, "@active", SqlDbType.Bit, x.Active); Add(cmd, "@actor", SqlDbType.BigInt, ActorId); var saved = Convert.ToInt64(await cmd.ExecuteScalarAsync(token)); await tx.CommitAsync(token); return Ok(new { id = saved, residentID = saved }); }
        catch (SqlException e) when (e.Number is 52913 or 52915 or 2601 or 2627) { await tx.RollbackAsync(token); return Conflict(new { message = "บันทึกผู้อาศัยหมู่บ้านไม่สำเร็จ", description = "บ้านหรือบุคคลไม่ถูกต้อง หรือบุคคลนี้มีที่อยู่อาศัย Active แล้ว" }); }
    }
    private async Task<bool> IsBusinessType(SqlConnection connection, string expected, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT BusinessTypeCode FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND IsActive=1", connection);
        Add(command, "@company", SqlDbType.BigInt, CompanyId);
        return string.Equals(Convert.ToString(await command.ExecuteScalarAsync(token)), expected, StringComparison.OrdinalIgnoreCase);
    }

    private static async Task<List<Dictionary<string,object?>>> ReadRows(SqlCommand command, CancellationToken token)
    {
        var rows=new List<Dictionary<string,object?>>(); await using var reader=await command.ExecuteReaderAsync(token);
        while(await reader.ReadAsync(token)){var row=new Dictionary<string,object?>();for(var i=0;i<reader.FieldCount;i++)row[reader.GetName(i)]=reader.IsDBNull(i)?null:reader.GetValue(i);rows.Add(row);} return rows;
    }
    private static async Task<object> ReadSets(SqlCommand command, CancellationToken token)
    {
        var sets=new List<List<Dictionary<string,object?>>>(); await using var reader=await command.ExecuteReaderAsync(token);
        do { sets.Add(new List<Dictionary<string,object?>>()); while(await reader.ReadAsync(token)){var row=new Dictionary<string,object?>();for(var i=0;i<reader.FieldCount;i++)row[reader.GetName(i)]=reader.IsDBNull(i)?null:reader.GetValue(i);sets[^1].Add(row);} } while(await reader.NextResultAsync(token));
        return new { tenants=sets.ElementAtOrDefault(0)??[], contacts=sets.ElementAtOrDefault(1)??[] };
    }
    private static void Add(SqlCommand command,string name,SqlDbType type,object? value,int? size=null){var p=command.Parameters.Add(name,type);if(size.HasValue)p.Size=size.Value;p.Value=value??DBNull.Value;}
}

public sealed record RentalTenantRequest(long RoomId,string Name,long? CustomerId,DateTime StartDate,DateTime? EndDate,bool Active=true);
public sealed record RentalContactRequest(long TenantId,string Name,long? PersonId,string? Phone,string? Email,bool Primary,bool Active=true);
public sealed record VillageLaneRequest(string Type,string Code,string Name,bool Active=true);
public sealed record VillageHouseRequest(long LaneId,string HouseNo,string? AddressText,bool Active=true);
public sealed record VillageResidentRequest(long HouseId,long PersonId,DateTime StartDate,DateTime? EndDate,bool Active=true);