using System.Data;
using System.Security.Claims;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/persons")]
public sealed class PersonRegistryController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "13002";
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await ScopeValid(connection, token)) return Forbid();
        return Ok(new
        {
            view = await Can(connection, "VIEW", token),
            create = await Can(connection, "CREATE", token),
            edit = await Can(connection, "EDIT", token),
            delete = await Can(connection, "DELETE", token)
        });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] bool? isActive,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken token = default)
    {
        await using var connection = await Open(token);
        if (!await ScopeValid(connection, token) || !await Can(connection, "VIEW", token)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 200);
        var query = search?.Trim() ?? string.Empty;
        const string sql = """
SELECT COUNT_BIG(1) OVER(),P.PersonID,P.FullName,P.NickName,P.Email,P.Mobile,P.IsActive,P.RowVersion,
       CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADEmployee E WHERE E.CompanyID=P.CompanyID AND E.PersonID=P.PersonID) THEN 1 ELSE 0 END AS bit),
       CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=P.CompanyID AND U.PersonID=P.PersonID) THEN 1 ELSE 0 END AS bit),
       CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADResident R WHERE R.CompanyID=P.CompanyID AND R.PersonID=P.PersonID) THEN 1 ELSE 0 END AS bit),
       CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADServiceCustomer S WHERE S.CompanyID=P.CompanyID AND S.PersonID=P.PersonID AND S.IsActive=1) THEN 1 ELSE 0 END AS bit)
FROM dbo.TDADPerson P
WHERE P.CompanyID=@company AND (@active IS NULL OR P.IsActive=@active)
  AND (@search=N'' OR P.FullName LIKE @like OR P.NickName LIKE @like OR P.Email LIKE @like OR P.Mobile LIKE @like)
ORDER BY P.FullName,P.PersonID
OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command,"@company",SqlDbType.BigInt,CompanyId); Add(command,"@active",SqlDbType.Bit,isActive);
        Add(command,"@search",SqlDbType.NVarChar,query,320); Add(command,"@like",SqlDbType.NVarChar,$"%{query}%",330);
        Add(command,"@offset",SqlDbType.Int,(page-1)*pageSize); Add(command,"@pageSize",SqlDbType.Int,pageSize);
        var items = new List<object>(); long total = 0;
        await using var reader = await command.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
        {
            total=reader.GetInt64(0);
            items.Add(PersonRow(reader,1));
        }
        return Ok(new { items,total,page,pageSize });
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup([FromQuery] long? includePersonId, CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await ScopeValid(connection, token) || !await Can(connection,"VIEW",token)) return Forbid();
        const string sql="SELECT PersonID,FullName,NickName,Mobile FROM dbo.TDADPerson WHERE CompanyID=@company AND (IsActive=1 OR PersonID=@include) ORDER BY FullName,PersonID";
        await using var command=new SqlCommand(sql,connection); Add(command,"@company",SqlDbType.BigInt,CompanyId); Add(command,"@include",SqlDbType.BigInt,includePersonId);
        var rows=new List<object>(); await using var reader=await command.ExecuteReaderAsync(token);
        while(await reader.ReadAsync(token)) rows.Add(new { personID=reader.GetInt64(0),fullName=reader.GetString(1),nickName=Text(reader,2),mobile=Text(reader,3) });
        return Ok(rows);
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id,CancellationToken token)
    {
        await using var connection=await Open(token);
        if(!await ScopeValid(connection,token)||!await Can(connection,"VIEW",token))return Forbid();
        const string sql="SELECT PersonID,FullName,NickName,Email,Mobile,IsActive,RowVersion,CAST(0 AS bit),CAST(0 AS bit),CAST(0 AS bit),CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADServiceCustomer S WHERE S.CompanyID=P.CompanyID AND S.PersonID=P.PersonID AND S.IsActive=1) THEN 1 ELSE 0 END AS bit) FROM dbo.TDADPerson P WHERE CompanyID=@company AND PersonID=@id";
        await using var command=new SqlCommand(sql,connection);Add(command,"@company",SqlDbType.BigInt,CompanyId);Add(command,"@id",SqlDbType.BigInt,id);
        await using var reader=await command.ExecuteReaderAsync(token);return await reader.ReadAsync(token)?Ok(PersonRow(reader,0)):NotFound();
    }

    [HttpPost]
    public Task<IActionResult> Create(PersonRegistryRequest request,CancellationToken token)=>Save(null,request,token);
    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id,PersonRegistryRequest request,CancellationToken token)=>Save(id,request,token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,[FromQuery]string rowVersion,CancellationToken token)
    {
        if(!RegistryControllerSupport.TryVersion(rowVersion,out var version))return BadRequest(Problem("ข้อมูลเวอร์ชันไม่ถูกต้อง","กรุณาโหลดรายการใหม่แล้วลองอีกครั้ง"));
        await using var connection=await Open(token);
        if(!await ScopeValid(connection,token)||!await Can(connection,"DELETE",token))return Forbid();
        await using var transaction=(SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable,token);
        const string sql="""
IF EXISTS(SELECT 1 FROM dbo.TDADEmployee WHERE CompanyID=@company AND PersonID=@id)
 OR EXISTS(SELECT 1 FROM dbo.TDADUser WHERE CompanyID=@company AND PersonID=@id)
 OR EXISTS(SELECT 1 FROM dbo.TDADResident WHERE CompanyID=@company AND PersonID=@id)
 OR EXISTS(SELECT 1 FROM dbo.TDADServiceCustomer WHERE CompanyID=@company AND PersonID=@id)
 THROW 52810,'PERSON_REFERENCED',1;
DELETE dbo.TDADPerson WHERE CompanyID=@company AND PersonID=@id AND RowVersion=@version;
SELECT @@ROWCOUNT;
""";
        try
        {
            await using var command=new SqlCommand(sql,connection,transaction);Add(command,"@company",SqlDbType.BigInt,CompanyId);Add(command,"@id",SqlDbType.BigInt,id);Add(command,"@version",SqlDbType.Timestamp,version);
            var changed=Convert.ToInt32(await command.ExecuteScalarAsync(token));
            if(changed==0){await transaction.RollbackAsync(token);return Conflict(Problem("ข้อมูลถูกเปลี่ยนแล้ว","กรุณาโหลดรายการใหม่ก่อนลบ"));}
            await transaction.CommitAsync(token);return NoContent();
        }
        catch(SqlException e) when(e.Number==52810)
        {await transaction.RollbackAsync(token);return Conflict(Problem("ยังลบบุคคลนี้ไม่ได้","บุคคลนี้เชื่อมกับพนักงาน ผู้ใช้งาน หรือผู้พักอาศัย กรุณาปิดสถานะแทน"));}
    }

    private async Task<IActionResult> Save(long? id,PersonRegistryRequest request,CancellationToken token)
    {
        var fullName=request.FullName?.Trim()??string.Empty;
        if(fullName.Length is 0 or >200||request.NickName?.Trim().Length>100||request.Email?.Trim().Length>320||request.Mobile?.Trim().Length>50)
            return BadRequest(Problem("ข้อมูลบุคคลไม่ถูกต้อง","กรุณาระบุชื่อไม่เกิน 200 ตัวอักษร และตรวจสอบอีเมลกับโทรศัพท์"));
        byte[]? version=null;if(id.HasValue&&!RegistryControllerSupport.TryVersion(request.RowVersion,out version))return BadRequest(Problem("ข้อมูลเวอร์ชันไม่ถูกต้อง","กรุณาโหลดรายการใหม่แล้วลองอีกครั้ง"));
        await using var connection=await Open(token);
        if(!await ScopeValid(connection,token)||!await Can(connection,id.HasValue?"EDIT":"CREATE",token))return Forbid();
        await using var transaction=(SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable,token);
        const string insert="""
INSERT dbo.TDADPerson(CompanyID,FullName,NickName,Email,Mobile,IsActive,CreateBy)
OUTPUT INSERTED.PersonID VALUES(@company,@name,@nick,@email,@mobile,@active,@actor);
""";
        const string update="""
UPDATE dbo.TDADPerson SET FullName=@name,NickName=@nick,Email=@email,Mobile=@mobile,IsActive=@active,
 UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor
WHERE CompanyID=@company AND PersonID=@id AND RowVersion=@version;
IF @@ROWCOUNT=0 THROW 52811,'PERSON_CONFLICT',1;
UPDATE dbo.TDADEmployee SET FullName=@name,NickName=@nick,Email=@email,PersonalTelephone=@mobile,IsActive=@active,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@company AND PersonID=@id;
UPDATE dbo.TDADUser SET DisplayName=@name,Email=@email,Mobile=@mobile,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor
WHERE CompanyID=@company AND PersonID=@id;
SELECT @id;
""";
        try
        {
            await using var command=new SqlCommand(id.HasValue?update:insert,connection,transaction);
            Add(command,"@company",SqlDbType.BigInt,CompanyId);Add(command,"@id",SqlDbType.BigInt,id);Add(command,"@name",SqlDbType.NVarChar,fullName,200);
            Add(command,"@nick",SqlDbType.NVarChar,Blank(request.NickName),100);Add(command,"@email",SqlDbType.NVarChar,Blank(request.Email),320);Add(command,"@mobile",SqlDbType.NVarChar,Blank(request.Mobile),50);
            Add(command,"@active",SqlDbType.Bit,request.IsActive);Add(command,"@actor",SqlDbType.BigInt,UserId);Add(command,"@version",SqlDbType.Timestamp,version);
            var saved=Convert.ToInt64(await command.ExecuteScalarAsync(token));await transaction.CommitAsync(token);return Ok(new{personID=saved});
        }
        catch(SqlException e) when(e.Number==52811)
        {await transaction.RollbackAsync(token);return Conflict(Problem("ข้อมูลถูกเปลี่ยนแล้ว","กรุณาโหลดรายการใหม่ก่อนบันทึก"));}
    }

    private Task<SqlConnection> Open(CancellationToken token)=>RegistryControllerSupport.Open(configuration,token);
    private Task<bool> Can(SqlConnection connection,string action,CancellationToken token)=>CompanyProjectPermission.IsAllowedAsync(connection,User,ScreenCode,action,token);
    private Task<bool> ScopeValid(SqlConnection connection,CancellationToken token)=>RegistryControllerSupport.ScopeValid(connection,User,token);
    private static object PersonRow(SqlDataReader r,int i)=>new {personID=r.GetInt64(i),fullName=r.GetString(i+1),nickName=Text(r,i+2),email=Text(r,i+3),mobile=Text(r,i+4),isActive=r.GetBoolean(i+5),rowVersion=Convert.ToBase64String((byte[])r[i+6]),hasEmployee=r.GetBoolean(i+7),hasUser=r.GetBoolean(i+8),hasResident=r.GetBoolean(i+9),hasServiceCustomer=r.GetBoolean(i+10)};
    private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i);
    private static string? Blank(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
    private static object Problem(string message,string description)=>new{message,description};
    private static void Add(SqlCommand c,string n,SqlDbType t,object? v,int size=0)=>RegistryControllerSupport.Add(c,n,t,v,size);
}

[ApiController, Authorize, Route("api/company/residents")]
public sealed class ResidentRegistryController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "14004";
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await ScopeValid(c, token)) return Forbid();
        return Ok(new { view = await Can(c, "VIEW", token), create = await Can(c, "CREATE", token), edit = await Can(c, "EDIT", token), delete = await Can(c, "DELETE", token) });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] bool? isActive, [FromQuery] long? buildingId, [FromQuery] long? roomId, [FromQuery] long? laneId, [FromQuery] long? houseId, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken token = default)
    {
        await using var c = await Open(token);
        if (!await ScopeValid(c, token) || !await Can(c, "VIEW", token)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 200); var q = search?.Trim() ?? string.Empty;
        const string sql = """
SELECT COUNT_BIG(1) OVER(),R.ResidentID,R.PersonID,P.FullName,P.NickName,P.Mobile,R.RoomID,RM.RoomCode,RM.RoomNameTH,
 B.BuildingID,B.BuildingCode,B.BuildingNameTH,F.FloorID,F.FloorCode,F.FloorNameTH,
 R.HouseID,H.HouseNo,L.LaneID,L.LaneCode,L.LaneName,R.StartDate,R.EndDate,R.IsActive,R.RowVersion,
 CAST(CASE WHEN R.HouseID IS NULL THEN 0 ELSE 1 END AS bit) IsVillage
FROM dbo.TDADResident R JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID
LEFT JOIN dbo.TDADRoom RM ON RM.CompanyID=R.CompanyID AND RM.RoomID=R.RoomID
LEFT JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID
LEFT JOIN dbo.TDADFloor F ON F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID
LEFT JOIN dbo.TDADVillageHouse H ON H.CompanyID=R.CompanyID AND H.HouseID=R.HouseID
LEFT JOIN dbo.TDADVillageLane L ON L.CompanyID=H.CompanyID AND L.LaneID=H.LaneID
WHERE R.CompanyID=@company AND (@active IS NULL OR R.IsActive=@active)
 AND (@building IS NULL OR B.BuildingID=@building) AND (@room IS NULL OR R.RoomID=@room)
 AND (@lane IS NULL OR L.LaneID=@lane) AND (@house IS NULL OR R.HouseID=@house)
 AND (@search=N'' OR P.FullName LIKE @like OR P.NickName LIKE @like OR P.Mobile LIKE @like OR RM.RoomCode LIKE @like OR H.HouseNo LIKE @like OR L.LaneName LIKE @like)
ORDER BY R.IsActive DESC,P.FullName,R.ResidentID OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
""";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@active", SqlDbType.Bit, isActive); Add(cmd, "@building", SqlDbType.BigInt, buildingId); Add(cmd, "@room", SqlDbType.BigInt, roomId); Add(cmd, "@lane", SqlDbType.BigInt, laneId); Add(cmd, "@house", SqlDbType.BigInt, houseId); Add(cmd, "@search", SqlDbType.NVarChar, q, 200); Add(cmd, "@like", SqlDbType.NVarChar, $"%{q}%", 210); Add(cmd, "@offset", SqlDbType.Int, (page - 1) * pageSize); Add(cmd, "@pageSize", SqlDbType.Int, pageSize);
        var items = new List<object>(); long total = 0; await using var r = await cmd.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) { total = r.GetInt64(0); items.Add(Row(r)); }
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup([FromQuery] long? includePersonId, [FromQuery] long? includeRoomId, [FromQuery] long? includeHouseId, CancellationToken token)
    {
        await using var c = await Open(token); if (!await ScopeValid(c, token) || !await Can(c, "VIEW", token)) return Forbid();
        const string sql = """
SELECT ISNULL(NULLIF(UPPER(LTRIM(RTRIM(BusinessTypeCode))),N''),N'COMPANY') businessType FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company;
SELECT PersonID id,FullName name,NickName nickName,Mobile mobile FROM dbo.TDADPerson WHERE CompanyID=@company AND (IsActive=1 OR PersonID=@person) ORDER BY FullName;
SELECT BuildingID id,BuildingCode code,BuildingNameTH name FROM dbo.TDADBuilding WHERE CompanyID=@company AND IsActive=1 ORDER BY BuildingCode;
SELECT F.FloorID id,F.BuildingID parentId,F.FloorCode code,F.FloorNameTH name FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.CompanyID=F.CompanyID AND B.BuildingID=F.BuildingID WHERE B.CompanyID=@company AND F.IsActive=1 ORDER BY F.FloorNumber,F.FloorCode;
SELECT RoomID id,BuildingID buildingId,FloorID parentId,RoomCode code,RoomNameTH name FROM dbo.TDADRoom WHERE CompanyID=@company AND (IsActive=1 OR RoomID=@room) AND RoomTypeCode=N'RESIDENTIAL' ORDER BY RoomCode;
SELECT LaneID id,LaneType type,LaneCode code,LaneName name FROM dbo.TDADVillageLane WHERE CompanyID=@company AND IsActive=1 ORDER BY LaneCode;
SELECT HouseID id,LaneID parentId,HouseNo code,AddressText name FROM dbo.TDADVillageHouse WHERE CompanyID=@company AND (IsActive=1 OR HouseID=@house) ORDER BY HouseNo;
""";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@person", SqlDbType.BigInt, includePersonId); Add(cmd, "@room", SqlDbType.BigInt, includeRoomId); Add(cmd, "@house", SqlDbType.BigInt, includeHouseId);
        await using var reader = await cmd.ExecuteReaderAsync(token); var sets = new List<List<Dictionary<string, object?>>>(); do { var rows = new List<Dictionary<string, object?>>(); while (await reader.ReadAsync(token)) { var row = new Dictionary<string, object?>(); for (var i = 0; i < reader.FieldCount; i++) row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i); rows.Add(row); } sets.Add(rows); } while (await reader.NextResultAsync(token));
        return Ok(new { businessType = sets[0].FirstOrDefault()?.GetValueOrDefault("businessType")?.ToString() ?? "COMPANY", persons = sets[1], buildings = sets[2], floors = sets[3], rooms = sets[4], lanes = sets[5], houses = sets[6] });
    }

    [HttpPost] public Task<IActionResult> Create(ResidentRegistryRequest request, CancellationToken token) => Save(null, request, token);
    [HttpPut("{id:long}")] public Task<IActionResult> Update(long id, ResidentRegistryRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, [FromQuery] string rowVersion, CancellationToken token)
    {
        if (!RegistryControllerSupport.TryVersion(rowVersion, out var version)) return BadRequest(Problem("ข้อมูลเวอร์ชันไม่ถูกต้อง", "กรุณาโหลดรายการใหม่แล้วลองอีกครั้ง"));
        await using var c = await Open(token); if (!await ScopeValid(c, token) || !await Can(c, "DELETE", token)) return Forbid();
        const string sql = "UPDATE dbo.TDADResident SET IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND ResidentID=@id AND RowVersion=@version; SELECT @@ROWCOUNT;";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@version", SqlDbType.Timestamp, version); Add(cmd, "@actor", SqlDbType.BigInt, UserId);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(token)) == 0 ? Conflict(Problem("ข้อมูลถูกเปลี่ยนแล้ว", "กรุณาโหลดรายการใหม่ก่อนปิดสถานะ")) : NoContent();
    }

    private async Task<IActionResult> Save(long? id, ResidentRegistryRequest x, CancellationToken token)
    {
        if (x.PersonId <= 0 || x.StartDate == default || x.EndDate < x.StartDate || (x.RoomId.HasValue && x.HouseId.HasValue)) return BadRequest(Problem("ข้อมูลผู้พักอาศัยไม่ถูกต้อง", "กรุณาเลือกห้องพักหรือบ้านเลขที่เพียงหนึ่งรายการ และตรวจสอบช่วงวันที่"));
        byte[]? version = null; if (id.HasValue && !RegistryControllerSupport.TryVersion(x.RowVersion, out version)) return BadRequest(Problem("ข้อมูลเวอร์ชันไม่ถูกต้อง", "กรุณาโหลดรายการใหม่แล้วลองอีกครั้ง"));
        await using var c = await Open(token); if (!await ScopeValid(c, token) || !await Can(c, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        var businessType = await BusinessType(c, token); if (businessType == "VILLAGE" && !x.HouseId.HasValue || businessType != "VILLAGE" && x.HouseId.HasValue) return BadRequest(Problem("สถานที่ไม่ตรงกับประเภทธุรกิจ", "กรุณาเลือกสถานที่ตาม Company Type"));
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        const string sql = """
IF NOT EXISTS(SELECT 1 FROM dbo.TDADPerson WHERE CompanyID=@company AND PersonID=@person AND (@active=0 OR IsActive=1)) THROW 52820,'INVALID_PERSON',1;
IF @room IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADRoom RM JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID JOIN dbo.TDADFloor F ON F.CompanyID=RM.CompanyID AND F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID WHERE RM.CompanyID=@company AND RM.RoomID=@room AND RM.RoomTypeCode=N'RESIDENTIAL' AND (@active=0 OR (RM.IsActive=1 AND B.IsActive=1 AND F.IsActive=1))) THROW 52821,'INVALID_ROOM',1;
IF @house IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADVillageHouse WHERE CompanyID=@company AND HouseID=@house AND (@active=0 OR IsActive=1)) THROW 52823,'INVALID_HOUSE',1;
IF @id IS NULL INSERT dbo.TDADResident(CompanyID,PersonID,RoomID,HouseID,StartDate,EndDate,IsActive,CreateBy) OUTPUT INSERTED.ResidentID VALUES(@company,@person,@room,@house,@start,@end,@active,@actor);
ELSE BEGIN UPDATE dbo.TDADResident SET PersonID=@person,RoomID=@room,HouseID=@house,StartDate=@start,EndDate=@end,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND ResidentID=@id AND RowVersion=@version; IF @@ROWCOUNT=0 THROW 52822,'RESIDENT_CONFLICT',1; SELECT @id; END
""";
        try { await using var cmd = new SqlCommand(sql, c, tx); Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@person", SqlDbType.BigInt, x.PersonId); Add(cmd, "@room", SqlDbType.BigInt, x.RoomId); Add(cmd, "@house", SqlDbType.BigInt, x.HouseId); Add(cmd, "@start", SqlDbType.Date, x.StartDate); Add(cmd, "@end", SqlDbType.Date, x.EndDate); Add(cmd, "@active", SqlDbType.Bit, x.IsActive); Add(cmd, "@actor", SqlDbType.BigInt, UserId); Add(cmd, "@version", SqlDbType.Timestamp, version); var saved = Convert.ToInt64(await cmd.ExecuteScalarAsync(token)); await tx.CommitAsync(token); return Ok(new { residentID = saved }); }
        catch (SqlException e) when (e.Number is 52820 or 52821 or 52822 or 52823 or 2601 or 2627) { await tx.RollbackAsync(token); return Conflict(Problem("บันทึกผู้พักอาศัยไม่สำเร็จ", e.Number == 52823 ? "บ้านเลขที่ไม่อยู่ใน Company หรือถูกปิดใช้งาน" : "บุคคลหรือสถานที่ไม่ถูกต้อง หรือบุคคลนี้มีที่อยู่อาศัย Active แล้ว")); }
    }

    private async Task<string> BusinessType(SqlConnection c, CancellationToken token) { await using var cmd = new SqlCommand("SELECT ISNULL(NULLIF(UPPER(LTRIM(RTRIM(BusinessTypeCode))),N''),N'COMPANY') FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company", c); Add(cmd, "@company", SqlDbType.BigInt, CompanyId); return Convert.ToString(await cmd.ExecuteScalarAsync(token)) ?? "COMPANY"; }
    private static object Row(SqlDataReader r) => new { residentID = r.GetInt64(1), personID = r.GetInt64(2), fullName = r.GetString(3), nickName = Text(r, 4), mobile = Text(r, 5), roomID = NullableLong(r, 6), roomCode = Text(r, 7), roomName = Text(r, 8), buildingID = NullableLong(r, 9), buildingCode = Text(r, 10), buildingName = Text(r, 11), floorID = NullableLong(r, 12), floorCode = Text(r, 13), floorName = Text(r, 14), houseID = NullableLong(r, 15), houseNo = Text(r, 16), laneID = NullableLong(r, 17), laneCode = Text(r, 18), laneName = Text(r, 19), startDate = r.GetDateTime(20), endDate = r.IsDBNull(21) ? null : (DateTime?)r.GetDateTime(21), isActive = r.GetBoolean(22), rowVersion = Convert.ToBase64String((byte[])r[23]), isVillage = r.GetBoolean(24) };
    private static long? NullableLong(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static string? Text(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private Task<SqlConnection> Open(CancellationToken t) => RegistryControllerSupport.Open(configuration, t); private Task<bool> Can(SqlConnection c, string a, CancellationToken t) => CompanyProjectPermission.IsAllowedAsync(c, User, ScreenCode, a, t); private Task<bool> ScopeValid(SqlConnection c, CancellationToken t) => RegistryControllerSupport.ScopeValid(c, User, t); private static object Problem(string message, string description) => new { message, description }; private static void Add(SqlCommand c, string n, SqlDbType t, object? v, int size = 0) => RegistryControllerSupport.Add(c, n, t, v, size);
}

public sealed record ResidentRegistryRequest(long PersonId, long? RoomId, long? HouseId, DateOnly StartDate, DateOnly? EndDate, bool IsActive = true, string? RowVersion = null);
public sealed record PersonRegistryRequest(string? FullName,string? NickName,string? Email,string? Mobile,bool IsActive=true,string? RowVersion=null);

internal static class RegistryControllerSupport
{
    internal static long ClaimLong(ClaimsPrincipal user,string name)=>long.TryParse(user.FindFirstValue(name),out var value)?value:0;
    internal static async Task<SqlConnection> Open(IConfiguration configuration,CancellationToken token){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(token);return c;}
    internal static async Task<bool> ScopeValid(SqlConnection c,ClaimsPrincipal user,CancellationToken token)
    {var company=ClaimLong(user,"company_id");var partner=ClaimLong(user,"partner_id");if(company<=0||partner<=0||user.FindFirstValue("user_type")!="COMPANY_USER")return false;await using var cmd=new SqlCommand("SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND PartnerID=@partner AND IsActive=1) THEN 1 ELSE 0 END AS bit)",c);Add(cmd,"@company",SqlDbType.BigInt,company);Add(cmd,"@partner",SqlDbType.BigInt,partner);return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));}
    internal static bool TryVersion(string? value,out byte[]? version){version=null;if(string.IsNullOrWhiteSpace(value))return false;try{version=Convert.FromBase64String(value);return version.Length==8;}catch(FormatException){return false;}}
    internal static void Add(SqlCommand command,string name,SqlDbType type,object? value,int size=0){var p=size>0?command.Parameters.Add(name,type,size):command.Parameters.Add(name,type);p.Value=value??DBNull.Value;}
}
