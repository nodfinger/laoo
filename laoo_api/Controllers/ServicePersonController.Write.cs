using System.Data;
using LaooApi.Security;
using LaooApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

public sealed partial class ServicePersonController
{
    [HttpGet("{personId:long}/login")]
    public async Task<IActionResult> ResidentLogin(long personId, CancellationToken token)
    {
        if (!Request.Path.StartsWithSegments("/api/service/residents")) return NotFound();
        await using var c = await Open(token);
        if (!await InServiceScope(c, token) || !await Allowed(c, "EDIT", token)) return Forbid();
        const string sql = """
SELECT U.UserID,U.Username,U.IsActive
FROM dbo.TDADResident R
JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID AND P.IsActive=1
LEFT JOIN dbo.TDADUser U ON U.CompanyID=R.CompanyID AND U.PersonID=R.PersonID
WHERE R.CompanyID=@company AND R.PersonID=@person AND R.IsActive=1;
""";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@person", SqlDbType.BigInt, personId);
        await using var r = await cmd.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound(Issue("ไม่พบผู้พักอาศัย", "ผู้พักอาศัยต้องอยู่ใน Company ปัจจุบันและมีสถานะใช้งาน"));
        return Ok(new { hasUser = !r.IsDBNull(0), userId = Long(r, 0), username = Text(r, 1), isActive = r.IsDBNull(2) || r.GetBoolean(2) });
    }

    [HttpPost("{personId:long}/login")]
    public async Task<IActionResult> SaveResidentLogin(long personId, ResidentLoginSaveRequest request, CancellationToken token)
    {
        if (!Request.Path.StartsWithSegments("/api/service/residents")) return NotFound();
        var username = request.Username?.Trim() ?? string.Empty;
        if (username.Length is 0 or > 100 || string.IsNullOrWhiteSpace(request.Password))
            return BadRequest(Issue("ข้อมูลบัญชีไม่ครบ", "กรุณาระบุ Username และรหัสผ่าน"));
        await using var c = await Open(token);
        if (!await InServiceScope(c, token) || !await Allowed(c, "EDIT", token)) return Forbid();
        var policy = await passwordService.GetPolicyAsync(c, "C", ClaimLong("partner_id"), CompanyId, token);
        if (!PasswordService.MeetsPolicy(username, request.Password, policy))
            return BadRequest(Issue("รหัสผ่านไม่เป็นไปตามนโยบาย", PasswordService.GetReadablePolicyMessage(policy)));
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            const string sql = """
DECLARE @name nvarchar(200),@user bigint,@currentUsername nvarchar(100),@project bigint;
SELECT @name=P.FullName FROM dbo.TDADResident R WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID AND P.IsActive=1
WHERE R.CompanyID=@company AND R.PersonID=@person AND R.IsActive=1;
IF @name IS NULL THROW 52958,'RESIDENT_NOT_ACTIVE',1;
SELECT @project=P.ProjectID FROM dbo.TDADProject P
JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=P.ProjectID AND CP.CompanyID=@company AND CP.PartnerID=@partner AND CP.IsEnabled=1
WHERE P.ProjectCode=N'LAOO_SERVICE' AND P.IsActive=1
AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()));
IF @project IS NULL THROW 52959,'SERVICE_NOT_ENABLED',1;
SELECT @user=UserID,@currentUsername=Username FROM dbo.TDADUser WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND PersonID=@person;
IF @user IS NOT NULL AND UPPER(@currentUsername)<>@normalized THROW 52960,'USERNAME_IMMUTABLE',1;
IF @user IS NULL
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.TDADLaooUser WHERE NormalizedUsername=@normalized)
 OR EXISTS(SELECT 1 FROM dbo.TDADPartnerUser WHERE NormalizedUsername=@normalized)
 OR EXISTS(SELECT 1 FROM dbo.TDADUser WHERE NormalizedUsername=@normalized)
    THROW 50008,'USERNAME_EXISTS',1;
 INSERT dbo.TDADUser(CompanyID,PersonID,Username,NormalizedUsername,PasswordHash,DisplayName,IsCompanyAdmin,IsActive,FailedLoginCount,LastPasswordChangeDate,CreateDate,CreateBy)
 VALUES(@company,@person,@username,@normalized,@hash,@name,0,@active,0,SYSUTCDATETIME(),SYSUTCDATETIME(),@actor);
 SET @user=CONVERT(bigint,SCOPE_IDENTITY());
END
ELSE UPDATE dbo.TDADUser SET PasswordHash=@hash,IsActive=@active,FailedLoginCount=0,LastPasswordChangeDate=SYSUTCDATETIME(),UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE UserID=@user AND CompanyID=@company;
INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate)
SELECT @company,@user,@project,1,1,SYSUTCDATETIME()
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@company AND UserID=@user AND ProjectID=@project);
UPDATE dbo.TDADUserProject SET IsActive=1 WHERE CompanyID=@company AND UserID=@user AND ProjectID=@project;
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedDate,CreatedBy)
SELECT @user,@project,P.PermissionID,1,1,N'Resident self-service',SYSUTCDATETIME(),@actor
FROM dbo.TDADPermission P
WHERE P.ProjectID=@project AND P.ScreenCode=N'20001' AND P.ActionCode IN(N'VIEW',N'CREATE') AND P.IsActive=1
AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission X WHERE X.UserID=@user AND X.ProjectID=@project AND X.PermissionID=P.PermissionID);
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsActive=1 AND UP.IsAllowed=1 AND P.ScreenCode=N'20001' AND P.ActionCode=N'CREATE' AND P.IsActive=1) THROW 52961,'SELF_SERVICE_PERMISSION_MISSING',1;
SELECT @user UserID,@username Username,@active IsActive;
""";
            await using var cmd = new SqlCommand(sql, c, tx);
            Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@partner", SqlDbType.BigInt, ClaimLong("partner_id")); Add(cmd, "@person", SqlDbType.BigInt, personId);
            Add(cmd, "@username", SqlDbType.NVarChar, username, 100); Add(cmd, "@normalized", SqlDbType.NVarChar, username.ToUpperInvariant(), 100);
            Add(cmd, "@hash", SqlDbType.NVarChar, passwordService.HashPassword(username, request.Password), 500); Add(cmd, "@active", SqlDbType.Bit, request.IsActive); Add(cmd, "@actor", SqlDbType.BigInt, ClaimLong("user_id"));
            long userId; string savedUsername; bool isActive;
            await using (var reader = await cmd.ExecuteReaderAsync(token))
            {
                if (!await reader.ReadAsync(token)) throw new InvalidOperationException("RESIDENT_LOGIN_SAVE_FAILED");
                userId = reader.GetInt64(0); savedUsername = reader.GetString(1); isActive = reader.GetBoolean(2);
            }
            await tx.CommitAsync(token);
            return Ok(new { userId, username = savedUsername, isActive });
        }
        catch (SqlException e) when (e.Number is 50008 or 2601 or 2627) { await tx.RollbackAsync(token); return Conflict(Issue("Username นี้ถูกใช้งานแล้ว", "กรุณาระบุ Username อื่น ระบบไม่อนุญาตให้ Username ซ้ำกันทั้งระบบ")); }
        catch (SqlException e) when (e.Number == 52958) { await tx.RollbackAsync(token); return NotFound(Issue("ไม่พบผู้พักอาศัย", "ผู้พักอาศัยต้องอยู่ใน Company ปัจจุบันและมีสถานะใช้งาน")); }
        catch (SqlException e) when (e.Number == 52959) { await tx.RollbackAsync(token); return BadRequest(Issue("ระบบ Service ยังไม่เปิดใช้งาน", "Company นี้ต้องเปิด Project LAOO_SERVICE ก่อนสร้างบัญชีผู้พักอาศัย")); }
        catch (SqlException e) when (e.Number == 52960) { await tx.RollbackAsync(token); return BadRequest(Issue("ไม่สามารถเปลี่ยน Username ได้", "บัญชีนี้มี Username อยู่แล้ว ให้ตั้งรหัสผ่านใหม่โดยใช้ Username เดิม")); }
        catch (SqlException e) when (e.Number == 52961) { await tx.RollbackAsync(token); return BadRequest(Issue("กำหนดสิทธิ์ Self-service ไม่สำเร็จ", "ไม่พบสิทธิ์ CREATE ของเมนู 20001 ใน Project LAOO_SERVICE")); }
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup([FromQuery] long? includePersonId, [FromQuery] long? includeRoomId, [FromQuery] long? includeHouseId, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InServiceScope(c, token) || !await Allowed(c, "VIEW", token)) return Forbid();
        const string sql = """
SELECT ISNULL(NULLIF(UPPER(LTRIM(RTRIM(BusinessTypeCode))),N''),N'COMPANY') FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company;
SELECT PersonID id,FullName name,NickName nickName,Mobile mobile,Email email,IsActive active,RowVersion rowVersion
FROM dbo.TDADPerson WHERE CompanyID=@company AND (IsActive=1 OR PersonID=@person) ORDER BY FullName,PersonID;
SELECT BuildingID id,BuildingCode code,BuildingNameTH name FROM dbo.TDADBuilding WHERE CompanyID=@company AND IsActive=1 ORDER BY BuildingCode;
SELECT F.FloorID id,F.BuildingID parentId,F.FloorCode code,F.FloorNameTH name FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE B.CompanyID=@company AND F.IsActive=1 ORDER BY F.FloorNumber,F.FloorCode;
SELECT RoomID id,BuildingID buildingId,FloorID parentId,RoomCode code,RoomNameTH name FROM dbo.TDADRoom WHERE CompanyID=@company AND (IsActive=1 OR RoomID=@room) AND RoomTypeCode=N'RESIDENTIAL' ORDER BY RoomCode;
SELECT LaneID id,LaneType type,LaneCode code,LaneName name FROM dbo.TDADVillageLane WHERE CompanyID=@company AND IsActive=1 ORDER BY LaneCode;
SELECT HouseID id,LaneID parentId,HouseNo code,AddressText name FROM dbo.TDADVillageHouse WHERE CompanyID=@company AND (IsActive=1 OR HouseID=@house) ORDER BY HouseNo;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@person", SqlDbType.BigInt, includePersonId); Add(cmd, "@room", SqlDbType.BigInt, includeRoomId); Add(cmd, "@house", SqlDbType.BigInt, includeHouseId);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        var businessType = CompanyBusinessType.Company;
        if (await reader.ReadAsync(token)) businessType = CompanyBusinessType.Normalize(reader.GetString(0));
        var sets = new List<List<Dictionary<string, object?>>>();
        while (await reader.NextResultAsync(token))
        {
            var rows = new List<Dictionary<string, object?>>();
            while (await reader.ReadAsync(token))
            {
                var row = new Dictionary<string, object?>();
                for (var i = 0; i < reader.FieldCount; i++)
                    row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i) is byte[] bytes ? Convert.ToBase64String(bytes) : reader.GetValue(i);
                rows.Add(row);
            }
            sets.Add(rows);
        }
        return Ok(new { businessTypeCode = businessType, persons = sets[0], buildings = sets[1], floors = sets[2], rooms = sets[3], lanes = sets.ElementAtOrDefault(4) ?? [], houses = sets.ElementAtOrDefault(5) ?? [] });
    }

    [HttpPost]
    public Task<IActionResult> Create(ServicePersonSaveRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{personId:long}")]
    public Task<IActionResult> Update(long personId, ServicePersonSaveRequest request, CancellationToken token) => Save(personId, request, token);

    [HttpDelete("{residentId:long}")]
    public async Task<IActionResult> DeleteResident(long residentId, [FromQuery] string rowVersion, CancellationToken token)
    {
        if (!Request.Path.StartsWithSegments("/api/service/residents")) return NotFound();
        var version = Version(rowVersion);
        if (version is null) return BadRequest(Issue("ข้อมูลไม่ครบ", "ไม่พบ RowVersion ของผู้พักอาศัย"));
        await using var c = await Open(token);
        if (!await InServiceScope(c, token) || !await Allowed(c, "DELETE", token)) return Forbid();
        const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDADResident WHERE CompanyID=@company AND ResidentID=@id AND RowVersion=@version)
    THROW 52956,'RESIDENT_CONFLICT',1;
IF (OBJECT_ID(N'dbo.TDADServiceRequest',N'U') IS NOT NULL AND EXISTS
    (SELECT 1 FROM dbo.TDADServiceRequest WHERE CompanyID=@company AND ResidentID=@id))
 OR (OBJECT_ID(N'dbo.TDTMVisitorVisit',N'U') IS NOT NULL AND EXISTS
    (SELECT 1 FROM dbo.TDTMVisitorVisit WHERE CompanyID=@company AND HostResidentID=@id))
 OR (OBJECT_ID(N'dbo.TDADVillageResident',N'U') IS NOT NULL AND EXISTS
    (SELECT 1 FROM dbo.TDADVillageResident WHERE CompanyID=@company AND ResidentID=@id))
    THROW 52824,'RESIDENT_REFERENCED',1;
UPDATE dbo.TDADResident SET IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor
WHERE CompanyID=@company AND ResidentID=@id AND RowVersion=@version;
""";
        try
        {
            await using var cmd = new SqlCommand(sql, c);
            Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@id", SqlDbType.BigInt, residentId);
            Add(cmd, "@version", SqlDbType.Timestamp, version); Add(cmd, "@actor", SqlDbType.BigInt, ClaimLong("user_id"));
            await cmd.ExecuteNonQueryAsync(token);
            return NoContent();
        }
        catch (SqlException e) when (e.Number == 52956) { return Conflict(Issue("ข้อมูลถูกเปลี่ยนแล้ว", "กรุณาโหลดรายการใหม่ก่อนลบ")); }
        catch (SqlException e) when (e.Number == 52824) { return Conflict(Issue("ลบผู้พักอาศัยไม่ได้", "ข้อมูลนี้ถูกใช้อ้างอิงในระบบอื่นแล้ว")); }
    }

    private async Task<IActionResult> Save(long? routePersonId, ServicePersonSaveRequest x, CancellationToken token)
    {
        if (routePersonId.HasValue && x.PersonId.HasValue && routePersonId != x.PersonId)
            return BadRequest(Issue("ข้อมูลบุคคลไม่ถูกต้อง", "PersonID ใน URL และข้อมูลบันทึกไม่ตรงกัน"));
        var personId = routePersonId ?? x.PersonId;
        var name = x.FullName?.Trim() ?? string.Empty;
        if (!personId.HasValue && (name.Length is 0 or > 200))
            return BadRequest(Issue("ข้อมูลบุคคลไม่ถูกต้อง", "กรุณาระบุชื่อ-นามสกุลไม่เกิน 200 ตัวอักษร"));
        if (x.NickName?.Trim().Length > 100 || x.Email?.Trim().Length > 320 || x.Mobile?.Trim().Length > 50)
            return BadRequest(Issue("ข้อมูลบุคคลไม่ถูกต้อง", "ชื่อเล่น อีเมล หรือโทรศัพท์ยาวเกินกำหนด"));
        if (x.EndDate.HasValue && x.StartDate.HasValue && x.EndDate < x.StartDate)
            return BadRequest(Issue("ช่วงเวลาพักอาศัยไม่ถูกต้อง", "วันสิ้นสุดต้องไม่ก่อนวันเริ่มต้น"));

        await using var c = await Open(token);
        if (!await InServiceScope(c, token) || !await Allowed(c, routePersonId.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        var businessType = await BusinessType(c, token);
        var dormitory = businessType == CompanyBusinessType.Dormitory;
        var village = businessType == CompanyBusinessType.Village;
        var customerEndpoint = Request.Path.StartsWithSegments("/api/service/customers");
        var residentEndpoint = Request.Path.StartsWithSegments("/api/service/residents");
        if (residentEndpoint && !dormitory && !village) return Forbid();
        var serviceCustomer = customerEndpoint ? true : residentEndpoint ? false : dormitory ? x.IsServiceCustomer : true;
        var resident = residentEndpoint ? true : customerEndpoint ? false : (dormitory || village) && x.IsResident;
        if (!serviceCustomer && !resident)
            return BadRequest(Issue("กรุณาเลือกบทบาท", "บุคคลในระบบ Service ต้องมีอย่างน้อยหนึ่งบทบาท"));

        byte[]? personVersion = Version(x.PersonRowVersion);
        byte[]? customerVersion = Version(x.ServiceCustomerRowVersion);
        byte[]? residentVersion = Version(x.ResidentRowVersion);
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            if (!personId.HasValue)
            {
                await using (var duplicate = new SqlCommand("SELECT COUNT(1) FROM dbo.TDADPerson WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND REPLACE(FullName,N' ',N'')=REPLACE(@name,N' ',N'')", c, tx))
                {
                    Add(duplicate, "@company", SqlDbType.BigInt, CompanyId);
                    Add(duplicate, "@name", SqlDbType.NVarChar, name, 200);
                    if (Convert.ToInt32(await duplicate.ExecuteScalarAsync(token)) > 0)
                        throw new ServicePersonException("DUPLICATE_NAME");
                }                const string insertPerson = "INSERT dbo.TDADPerson(CompanyID,FullName,NickName,Email,Mobile,IsActive,CreateBy) OUTPUT INSERTED.PersonID VALUES(@company,@name,@nick,@email,@mobile,@active,@actor);";
                await using var cmd = new SqlCommand(insertPerson, c, tx); BindPerson(cmd, x, name); personId = Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
            }
            else
            {
                await using var exists = new SqlCommand("SELECT COUNT(1) FROM dbo.TDADPerson WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND PersonID=@person", c, tx);
                Add(exists, "@company", SqlDbType.BigInt, CompanyId); Add(exists, "@person", SqlDbType.BigInt, personId);
                if (Convert.ToInt32(await exists.ExecuteScalarAsync(token)) == 0) throw new ServicePersonException("NOT_FOUND");
                if (x.UpdatePerson)
                {
                    if (!await CanEditPerson(c, tx, token)) return Forbid();
                    if (name.Length is 0 or > 200 || personVersion is null) return BadRequest(Issue("ข้อมูลกลางไม่ครบ", "กรุณาระบุชื่อและโหลดข้อมูลล่าสุดก่อนแก้ไข"));
                    const string updatePerson = """
DECLARE @before nvarchar(max)=(SELECT PersonID,FullName,NickName,Email,Mobile,IsActive FROM dbo.TDADPerson WHERE CompanyID=@company AND PersonID=@person FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
UPDATE dbo.TDADPerson SET FullName=@name,NickName=@nick,Email=@email,Mobile=@mobile,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor
WHERE CompanyID=@company AND PersonID=@person AND RowVersion=@version;
IF @@ROWCOUNT=0 THROW 52951,'PERSON_CONFLICT',1;
UPDATE dbo.TDADEmployee SET FullName=@name,NickName=@nick,Email=@email,PersonalTelephone=@mobile,IsActive=@active,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND PersonID=@person;
UPDATE dbo.TDADUser SET DisplayName=@name,Email=@email,Mobile=@mobile,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND PersonID=@person;
DECLARE @after nvarchar(max)=(SELECT PersonID,FullName,NickName,Email,Mobile,IsActive FROM dbo.TDADPerson WHERE CompanyID=@company AND PersonID=@person FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
INSERT dbo.TDADServicePersonAudit(CompanyID,PersonID,ActionCode,BeforeData,AfterData,CreateBy) VALUES(@company,@person,N'PERSON_UPDATE',@before,@after,@actor);
""";
                    await using var cmd = new SqlCommand(updatePerson, c, tx); BindPerson(cmd, x, name); Add(cmd, "@person", SqlDbType.BigInt, personId); Add(cmd, "@version", SqlDbType.Timestamp, personVersion); await cmd.ExecuteNonQueryAsync(token);
                }
            }

            await UpsertServiceCustomer(c, tx, personId.Value, serviceCustomer, x.IsActive, customerVersion, token);
            await UpsertResident(c, tx, personId.Value, resident, x, residentVersion, resident, token);
            await tx.CommitAsync(token);
            return Ok(new { personID = personId });
        }
        catch (SqlException e) when (e.Number is 52951 or 52952 or 52953)
        {
            await tx.RollbackAsync(token);
            return Conflict(Issue("ข้อมูลถูกเปลี่ยนแล้ว", "กรุณาโหลดรายการใหม่ก่อนบันทึก"));
        }
        catch (SqlException e) when (e.Number is 52954 or 52955)
        {
            await tx.RollbackAsync(token);
            return Conflict(Issue("ข้อมูลผู้พักอาศัยซ้ำ", "บุคคลนี้มีช่วงเวลาพักอาศัยที่ทับซ้อนกัน"));
        }
        catch (ServicePersonException e) when (e.Code == "DUPLICATE_NAME")
        {
            await tx.RollbackAsync(token);
            return Conflict(Issue("พบชื่อบุคคลซ้ำ", "กรุณาตรวจสอบทะเบียนบุคคลกลาง หรือใช้การผูกบุคคลเดิม"));
        }
        catch (ServicePersonException)
        {
            await tx.RollbackAsync(token);
            return NotFound(Issue("ไม่พบข้อมูลบุคคล", "กรุณาโหลดรายการใหม่"));
        }
    }

    private async Task UpsertServiceCustomer(SqlConnection c, SqlTransaction tx, long personId, bool selected, bool active, byte[]? version, CancellationToken token)
    {
        const string sql = """
DECLARE @id bigint,@current varbinary(8); SELECT @id=ServiceCustomerID,@current=RowVersion FROM dbo.TDADServiceCustomer WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND PersonID=@person;
IF @id IS NULL
BEGIN IF @selected=1 INSERT dbo.TDADServiceCustomer(CompanyID,PersonID,IsActive,CreateBy) VALUES(@company,@person,@active,@actor); END
ELSE BEGIN
 IF @version IS NOT NULL AND @current<>@version THROW 52952,'SERVICE_CUSTOMER_CONFLICT',1;
 UPDATE dbo.TDADServiceCustomer SET IsActive=CASE WHEN @selected=1 THEN @active ELSE 0 END,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE ServiceCustomerID=@id AND CompanyID=@company;
END
""";
        await using var cmd = new SqlCommand(sql, c, tx); Add(cmd,"@company",SqlDbType.BigInt,CompanyId);Add(cmd,"@person",SqlDbType.BigInt,personId);Add(cmd,"@selected",SqlDbType.Bit,selected);Add(cmd,"@active",SqlDbType.Bit,active);Add(cmd,"@actor",SqlDbType.BigInt,ClaimLong("user_id"));Add(cmd,"@version",SqlDbType.Timestamp,version);await cmd.ExecuteNonQueryAsync(token);
    }

    private async Task UpsertResident(SqlConnection c, SqlTransaction tx, long personId, bool selected, ServicePersonSaveRequest x, byte[]? version, bool allowUnassigned, CancellationToken token)
    {
        const string sql = """
DECLARE @id bigint,@current varbinary(8); SELECT TOP(1) @id=ResidentID,@current=RowVersion FROM dbo.TDADResident WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND PersonID=@person ORDER BY IsActive DESC,StartDate DESC,ResidentID DESC;
IF @selected=0 BEGIN IF @id IS NOT NULL UPDATE dbo.TDADResident SET IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND ResidentID=@id; RETURN; END
IF @room IS NULL AND @house IS NULL AND @allowUnassigned=0 THROW 52954,'INVALID_RESIDENCE',1;
IF @room IS NOT NULL AND @house IS NOT NULL THROW 52954,'INVALID_RESIDENCE',1;
IF @room IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADRoom RM JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID JOIN dbo.TDADFloor F ON F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID WHERE RM.CompanyID=@company AND RM.RoomID=@room AND RM.RoomTypeCode=N'RESIDENTIAL' AND RM.IsActive=1 AND B.IsActive=1 AND F.IsActive=1) THROW 52954,'INVALID_ROOM',1;
IF @house IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADVillageHouse WHERE CompanyID=@company AND HouseID=@house AND IsActive=1) THROW 52954,'INVALID_HOUSE',1;
IF EXISTS(SELECT 1 FROM dbo.TDADResident R WHERE R.CompanyID=@company AND R.PersonID=@person AND R.ResidentID<>ISNULL(@id,0) AND R.IsActive=1) THROW 52955,'RESIDENT_OVERLAP',1;
IF @id IS NULL INSERT dbo.TDADResident(CompanyID,PersonID,RoomID,HouseID,StartDate,EndDate,IsActive,CreateBy) VALUES(@company,@person,@room,@house,@start,@end,@active,@actor);
ELSE BEGIN IF @version IS NOT NULL AND @current<>@version THROW 52953,'RESIDENT_CONFLICT',1; UPDATE dbo.TDADResident SET RoomID=@room,HouseID=@house,StartDate=@start,EndDate=@end,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND ResidentID=@id; END
""";
        await using var cmd = new SqlCommand(sql, c, tx); Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@person", SqlDbType.BigInt, personId); Add(cmd, "@selected", SqlDbType.Bit, selected); Add(cmd, "@room", SqlDbType.BigInt, x.RoomId); Add(cmd, "@house", SqlDbType.BigInt, x.HouseId); Add(cmd, "@start", SqlDbType.Date, x.StartDate); Add(cmd, "@end", SqlDbType.Date, x.EndDate); Add(cmd, "@active", SqlDbType.Bit, x.IsActive); Add(cmd, "@actor", SqlDbType.BigInt, ClaimLong("user_id")); Add(cmd, "@allowUnassigned", SqlDbType.Bit, allowUnassigned); Add(cmd, "@version", SqlDbType.Timestamp, version); await cmd.ExecuteNonQueryAsync(token);
    }
    private async Task<string> BusinessType(SqlConnection c, CancellationToken token)
    {
        await using var cmd = new SqlCommand("SELECT ISNULL(NULLIF(UPPER(LTRIM(RTRIM(BusinessTypeCode))),N''),N'COMPANY') FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company", c);Add(cmd,"@company",SqlDbType.BigInt,CompanyId);return CompanyBusinessType.Normalize(Convert.ToString(await cmd.ExecuteScalarAsync(token)));
    }

    private async Task<bool> CanEditPerson(SqlConnection c, SqlTransaction? tx, CancellationToken token)
    {
        const string sql = """
SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@user AND IsCompanyAdmin=1 AND IsActive=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE JOIN dbo.TDADUserPermissionPoint PP ON PP.CompanyID=UE.CompanyID AND PP.EmployeeID=UE.EmployeeID AND PP.PartnerID=@partner AND PP.MenuCode=@screen AND PP.PermissionPointCode=N'PERSON_EDIT' AND PP.IsAllowed=1 AND PP.IsActive=1 JOIN dbo.TDADProject PR ON PR.ProjectID=PP.ProjectID AND PR.ProjectCode=N'LAOO_SERVICE' AND PR.IsActive=1 JOIN dbo.TDADUserProject UP ON UP.ProjectID=PR.ProjectID AND UP.CompanyID=UE.CompanyID AND UP.UserID=UE.UserID AND UP.IsActive=1 WHERE UE.CompanyID=@company AND UE.UserID=@user AND UE.IsActive=1) THEN 1 ELSE 0 END AS bit);
""";
        await using var cmd = new SqlCommand(sql,c,tx);Add(cmd,"@company",SqlDbType.BigInt,CompanyId);Add(cmd,"@user",SqlDbType.BigInt,ClaimLong("user_id"));Add(cmd,"@partner",SqlDbType.BigInt,ClaimLong("partner_id"));Add(cmd,"@screen",SqlDbType.NVarChar,ScreenCode,5);return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }

    private void BindPerson(SqlCommand cmd, ServicePersonSaveRequest x, string name)
    {
        Add(cmd,"@company",SqlDbType.BigInt,CompanyId);Add(cmd,"@name",SqlDbType.NVarChar,name,200);Add(cmd,"@nick",SqlDbType.NVarChar,Blank(x.NickName),100);Add(cmd,"@email",SqlDbType.NVarChar,Blank(x.Email),320);Add(cmd,"@mobile",SqlDbType.NVarChar,Blank(x.Mobile),50);Add(cmd,"@active",SqlDbType.Bit,x.IsActive);Add(cmd,"@actor",SqlDbType.BigInt,ClaimLong("user_id"));
    }
    private static byte[]? Version(string? value) { try { return string.IsNullOrWhiteSpace(value) ? null : Convert.FromBase64String(value); } catch { return null; } }
    private static string? Blank(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static object Issue(string message,string description) => new { message,description };
}

public sealed record ServicePersonSaveRequest(long? PersonId,string? FullName,string? NickName,string? Email,string? Mobile,bool IsActive,bool IsServiceCustomer,bool IsResident,long? RoomId,long? HouseId,DateOnly? StartDate,DateOnly? EndDate,bool UpdatePerson=false,string? PersonRowVersion=null,string? ServiceCustomerRowVersion=null,string? ResidentRowVersion=null);
public sealed record ResidentLoginSaveRequest(string? Username, string? Password, bool IsActive = true);
file sealed class ServicePersonException(string code) : Exception(code)
{
    public string Code { get; } = code;
}
