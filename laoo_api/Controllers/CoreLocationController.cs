using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/locations")]
public sealed class CoreLocationController(IConfiguration configuration) : ControllerBase
{
    private long Company => long.TryParse(User.FindFirstValue("company_id"), out var id) ? id : 0;
    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(token);
        return c;
    }

    private async Task<bool> Allowed(SqlConnection c, string action, CancellationToken token)
    {
        if (!await CompanyProjectPermission.IsAllowedAsync(c, User, "14001", action, token)) return false;
        if (!long.TryParse(User.FindFirstValue("partner_id"),out var partner)) return false;
        using var cmd = new SqlCommand("SELECT COUNT(*) FROM dbo.TDADMainMenu M WHERE M.MenuCode=N'14001' AND M.IsActive=1 AND M.ScreenType=1 AND EXISTS(SELECT 1 FROM dbo.TDSTCompanySetUp C WHERE C.CompanyID=@company AND C.PartnerID=@partner AND C.IsActive=1);", c);
        cmd.Parameters.AddWithValue("@company",Company);
        cmd.Parameters.AddWithValue("@partner",partner);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(token)) == 1;
    }

    private async Task<string> BusinessType(SqlConnection connection, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT BusinessTypeCode FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND IsActive=1", connection);
        command.Parameters.Add("@company", SqlDbType.BigInt).Value = Company;
        return CompanyBusinessType.Normalize(Convert.ToString(await command.ExecuteScalarAsync(token)));
    }
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Allowed(c, "VIEW", token)) return StatusCode(403, new { message="ไม่สามารถดูสถานที่ได้", description="บัญชีนี้ไม่มีสิทธิ์ดูทะเบียนสถานที่ของ Company" });
        var businessType = await BusinessType(c, token);
        var actions = new { create=await Allowed(c,"CREATE",token), edit=await Allowed(c,"EDIT",token), delete=await Allowed(c,"DELETE",token) };
        const string sql = """
SELECT BuildingID id,BuildingCode code,BuildingNameTH name,IsActive active FROM dbo.TDADBuilding WHERE CompanyID=@company ORDER BY BuildingCode,BuildingID;
SELECT F.FloorID id,F.BuildingID parentId,F.FloorCode code,F.FloorNameTH name,F.IsActive active FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE B.CompanyID=@company ORDER BY F.FloorNumber,F.FloorCode,F.FloorID;
SELECT RoomID id,BuildingID buildingId,FloorID parentId,RoomCode code,RoomNameTH name,RoomTypeCode type,Description description,IsActive active FROM dbo.TDADRoom WHERE CompanyID=@company ORDER BY RoomCode,RoomID;
""";
        using var cmd = new SqlCommand(sql,c);
        cmd.Parameters.AddWithValue("@company",Company);
        await using var r = await cmd.ExecuteReaderAsync(token);
        var sets = new List<List<Dictionary<string,object?>>>();
        do
        {
            var rows=new List<Dictionary<string,object?>>();
            while(await r.ReadAsync(token))
            {
                var row=new Dictionary<string,object?>();
                for(var i=0;i<r.FieldCount;i++) row[r.GetName(i)]=r.IsDBNull(i)?null:r.GetValue(i);
                rows.Add(row);
            }
            sets.Add(rows);
        } while(await r.NextResultAsync(token));
        return Ok(new { businessType, buildings=sets[0], floors=sets[1], rooms=sets[2], actions });
    }

    [HttpPost("{kind}")]
    public Task<IActionResult> Create(string kind, LocationRequest request, CancellationToken token) => Save(kind,null,request,token);
    [HttpPut("{kind}/{id:long}")]
    public Task<IActionResult> Update(string kind,long id,LocationRequest request,CancellationToken token) => Save(kind,id,request,token);

    [HttpGet("rooms/{roomId:long}/residents")]
    public async Task<IActionResult> RoomResidents(long roomId, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Allowed(c, "VIEW", token)) return Forbid();
        const string sql = """
SELECT RoomID id, RoomCode code, RoomNameTH name, RoomTypeCode type
FROM dbo.TDADRoom WHERE CompanyID=@company AND RoomID=@roomId AND IsActive=1;
SELECT R.ResidentID residentID,R.PersonID personID,P.FullName fullName,P.NickName nickName,P.Mobile mobile,R.RoomID roomID,R.HouseID houseID,R.StartDate startDate,R.EndDate endDate,R.IsActive active
FROM dbo.TDADResident R JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID
WHERE R.CompanyID=@company AND R.RoomID=@roomId AND R.HouseID IS NULL AND R.IsActive=1 AND P.IsActive=1 ORDER BY P.FullName,R.ResidentID;
SELECT R.ResidentID residentID,R.PersonID personID,P.FullName fullName,P.NickName nickName,P.Mobile mobile,R.RoomID roomID,R.HouseID houseID,R.StartDate startDate,R.EndDate endDate,R.IsActive active
FROM dbo.TDADResident R JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID
WHERE R.CompanyID=@company AND R.RoomID IS NULL AND R.HouseID IS NULL AND R.IsActive=1 AND P.IsActive=1 ORDER BY P.FullName,R.ResidentID;
""";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.AddWithValue("@company", Company); cmd.Parameters.AddWithValue("@roomId", roomId);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        var sets = new List<List<Dictionary<string, object?>>>();
        do
        {
            var rows = new List<Dictionary<string, object?>>();
            while (await reader.ReadAsync(token))
            {
                var row = new Dictionary<string, object?>();
                for (var i = 0; i < reader.FieldCount; i++) row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                rows.Add(row);
            }
            sets.Add(rows);
        } while (await reader.NextResultAsync(token));
        if (sets[0].Count == 0 || Convert.ToString(sets[0][0]["type"]) != "RESIDENTIAL") return BadRequest(new { message = "ห้องนี้ไม่ใช่ห้องพักอาศัย" });
        return Ok(new { room = sets[0][0], assigned = sets[1], available = sets[2] });
    }

    [HttpPut("rooms/{roomId:long}/residents")]
    public async Task<IActionResult> AssignRoomResidents(long roomId, RoomResidentAssignmentRequest request, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Allowed(c, "EDIT", token)) return Forbid();
        var residentIds = (request.ResidentIds ?? new List<long>()).Where(id => id > 0).Distinct().ToArray();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            const string roomSql = "SELECT COUNT(1) FROM dbo.TDADRoom WHERE CompanyID=@company AND RoomID=@roomId AND RoomTypeCode=N'RESIDENTIAL' AND IsActive=1;";
            await using (var room = new SqlCommand(roomSql, c, tx))
            {
                room.Parameters.AddWithValue("@company", Company); room.Parameters.AddWithValue("@roomId", roomId);
                if (Convert.ToInt32(await room.ExecuteScalarAsync(token)) != 1) return BadRequest(new { message = "ห้องนี้ไม่ใช่ห้องพักอาศัยหรือไม่อยู่ใน Company" });
            }
            var parameters = new List<string>();
            await using var validate = new SqlCommand { Connection = c, Transaction = tx };
            validate.Parameters.AddWithValue("@company", Company);
            for (var i = 0; i < residentIds.Length; i++) { var name = "@r" + i; parameters.Add(name); validate.Parameters.Add(name, SqlDbType.BigInt).Value = residentIds[i]; }
            if (residentIds.Length > 0)
            {
                validate.CommandText = $"SELECT COUNT(1) FROM dbo.TDADResident R JOIN dbo.TDADPerson P ON P.CompanyID=R.CompanyID AND P.PersonID=R.PersonID WHERE R.CompanyID=@company AND R.ResidentID IN ({string.Join(',', parameters)}) AND R.IsActive=1 AND P.IsActive=1 AND R.HouseID IS NULL AND (R.RoomID IS NULL OR R.RoomID=@roomId);";
                validate.Parameters.AddWithValue("@roomId", roomId);
                if (Convert.ToInt32(await validate.ExecuteScalarAsync(token)) != residentIds.Length) return Conflict(new { message = "เลือกผู้พักอาศัยได้เฉพาะรายการที่ยังไม่จัดห้องหรืออยู่ในห้องนี้" });
            }
            var clear = residentIds.Length == 0
                ? "UPDATE dbo.TDADResident SET RoomID=NULL,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND RoomID=@roomId AND HouseID IS NULL;"
                : $"UPDATE dbo.TDADResident SET RoomID=NULL,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND RoomID=@roomId AND HouseID IS NULL AND ResidentID NOT IN ({string.Join(',', parameters)});";
            await using (var command = new SqlCommand(clear, c, tx))
            {
                command.Parameters.AddWithValue("@company", Company); command.Parameters.AddWithValue("@roomId", roomId); command.Parameters.AddWithValue("@actor", User.FindFirstValue("user_id") ?? "api");
                await command.ExecuteNonQueryAsync(token);
            }
            if (residentIds.Length > 0)
            {
                var assign = $"UPDATE dbo.TDADResident SET RoomID=@roomId,HouseID=NULL,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company AND ResidentID IN ({string.Join(',', parameters)});";
                await using var command = new SqlCommand(assign, c, tx);
                command.Parameters.AddWithValue("@company", Company); command.Parameters.AddWithValue("@roomId", roomId); command.Parameters.AddWithValue("@actor", User.FindFirstValue("user_id") ?? "api");
                for (var i = 0; i < residentIds.Length; i++) command.Parameters.Add(parameters[i], SqlDbType.BigInt).Value = residentIds[i];
                await command.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return NoContent();
        }
        catch { await tx.RollbackAsync(token); throw; }
    }
    [HttpDelete("{kind}/{id:long}")]
    public async Task<IActionResult> Delete(string kind,long id,CancellationToken token)
    {
        var sql=kind switch
        {
            "buildings" => "IF EXISTS(SELECT 1 FROM dbo.TDADMeetingRoom WHERE BuildingID=@id AND CompanyID=@company) THROW 51204,'REFERENCED',1; DELETE FROM dbo.TDADBuilding WHERE BuildingID=@id AND CompanyID=@company;",
            "floors" => "IF EXISTS(SELECT 1 FROM dbo.TDADMeetingRoom WHERE FloorID=@id AND CompanyID=@company) THROW 51204,'REFERENCED',1; DELETE F FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE F.FloorID=@id AND B.CompanyID=@company;",
            "rooms" => """
IF OBJECT_ID(N'dbo.TDADResident', N'U') IS NOT NULL
   AND EXISTS(SELECT 1 FROM dbo.TDADResident WHERE CompanyID=@company AND RoomID=@id)
    THROW 51204,'REFERENCED',1;
DELETE FROM dbo.TDADRoom WHERE RoomID=@id AND CompanyID=@company;
""",
            _ => null
        };
        if(sql is null) return NotFound();
        await using var c=await Open(token);
        if(!await Allowed(c,"DELETE",token)) return StatusCode(403,new { message="ลบสถานที่ไม่ได้",description="บัญชีนี้ไม่มีสิทธิ์ลบทะเบียนสถานที่" });
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        using var cmd=new SqlCommand(sql,c,tx);
        cmd.Parameters.AddWithValue("@company",Company);
        cmd.Parameters.AddWithValue("@id",id);
        try
        {
            var changed=await cmd.ExecuteNonQueryAsync(token);
            await tx.CommitAsync(token);
            return changed==0?NotFound(new {message="ไม่พบสถานที่",description="กรุณาโหลดรายการใหม่"}):NoContent();
        }
        catch(SqlException e) when(e.Number is 547 or 51204)
        {
            await tx.RollbackAsync(token);
            return Conflict(new { message="สถานที่นี้ยังลบไม่ได้",description="มีชั้น ห้อง หรือข้อมูลอื่นอ้างอิงอยู่ ให้ปิดใช้งานแทนการลบ" });
        }
    }

    private async Task<IActionResult> Save(string kind,long? id,LocationRequest x,CancellationToken token)
    {
        if(kind is not ("buildings" or "floors" or "rooms")) return NotFound();
        if(string.IsNullOrWhiteSpace(x.Code)||x.Code.Trim().Length>20||string.IsNullOrWhiteSpace(x.Name)||x.Name.Trim().Length>200||x.Description?.Length>1000)
            return BadRequest(new { message="ข้อมูลสถานที่ไม่ถูกต้อง",description="ระบุรหัสไม่เกิน 20 ตัวอักษร ชื่อไม่เกิน 200 ตัวอักษร และรายละเอียดไม่เกิน 1,000 ตัวอักษร" });
        if(kind=="rooms" && x.Type is not ("RESIDENTIAL" or "OFFICE" or "COMMON" or "OTHER"))
            return BadRequest(new { message="ประเภทห้องไม่ถูกต้อง",description="กรุณาเลือกประเภทห้องจากรายการ" });
        await using var c=await Open(token);
        if(!await Allowed(c,id.HasValue?"EDIT":"CREATE",token)) return StatusCode(403,new { message="บันทึกสถานที่ไม่ได้",description="บัญชีนี้ไม่มีสิทธิ์ดำเนินการ" });
        var businessType = await BusinessType(c, token);
        if (businessType == CompanyBusinessType.Village) return BadRequest(new { message = "Company ประเภทหมู่บ้านต้องใช้ทะเบียนซอย/แยกและบ้านเลขที่" });
        if (businessType == CompanyBusinessType.RentalOffice && kind == "rooms" && x.Type != "OFFICE") return BadRequest(new { message = "สำนักงานเช่าต้องใช้ห้องประเภท OFFICE" });
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        var sql=kind switch
        {
            "buildings" => """
IF @id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADBuilding WHERE BuildingID=@id AND CompanyID=@company) THROW 51201,'NOT_FOUND',1;
IF EXISTS(SELECT 1 FROM dbo.TDADBuilding WHERE CompanyID=@company AND BuildingCode=@code AND (@id IS NULL OR BuildingID<>@id)) THROW 51202,'DUPLICATE_CODE',1;
IF @id IS NULL BEGIN INSERT dbo.TDADBuilding(CompanyID,BranchID,BuildingCode,BuildingNameTH,IsActive,CreateDate,CreateBy) VALUES(@company,NULL,@code,@name,@active,SYSUTCDATETIME(),@actor); SET @id=SCOPE_IDENTITY(); END
ELSE UPDATE dbo.TDADBuilding SET BuildingCode=@code,BuildingNameTH=@name,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE BuildingID=@id AND CompanyID=@company;
SELECT @id;
""",
            "floors" => """
IF NOT EXISTS(SELECT 1 FROM dbo.TDADBuilding WHERE BuildingID=@parent AND CompanyID=@company AND (IsActive=1 OR @active=0)) THROW 51203,'INVALID_PARENT',1;
IF @id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE F.FloorID=@id AND B.CompanyID=@company AND F.BuildingID=@parent) THROW 51201,'NOT_FOUND',1;
IF EXISTS(SELECT 1 FROM dbo.TDADFloor WHERE BuildingID=@parent AND FloorCode=@code AND (@id IS NULL OR FloorID<>@id)) THROW 51202,'DUPLICATE_CODE',1;
IF @id IS NULL BEGIN INSERT dbo.TDADFloor(BuildingID,FloorCode,FloorNameTH,IsActive,CreateDate,CreateBy) VALUES(@parent,@code,@name,@active,SYSUTCDATETIME(),@actor); SET @id=SCOPE_IDENTITY(); END
ELSE UPDATE dbo.TDADFloor SET FloorCode=@code,FloorNameTH=@name,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE FloorID=@id AND BuildingID=@parent;
SELECT @id;
""",
            _ => """
DECLARE @building bigint;
SELECT @building=B.BuildingID FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE F.FloorID=@parent AND B.CompanyID=@company AND (@active=0 OR (F.IsActive=1 AND B.IsActive=1));
IF @building IS NULL THROW 51203,'INVALID_PARENT',1;
IF @id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADRoom WHERE RoomID=@id AND CompanyID=@company AND FloorID=@parent) THROW 51201,'NOT_FOUND',1;
IF @id IS NULL BEGIN INSERT dbo.TDADRoom(CompanyID,BuildingID,FloorID,RoomCode,RoomNameTH,RoomTypeCode,Description,IsActive,CreateBy) VALUES(@company,@building,@parent,@code,@name,@type,@description,@active,@actor); SET @id=SCOPE_IDENTITY(); END
ELSE UPDATE dbo.TDADRoom SET RoomCode=@code,RoomNameTH=@name,RoomTypeCode=@type,Description=@description,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE RoomID=@id AND CompanyID=@company;
SELECT @id;
"""
        };
        using var cmd=new SqlCommand(sql,c,tx);
        cmd.Parameters.AddWithValue("@company",Company);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=(object?)id??DBNull.Value;
        cmd.Parameters.Add("@parent",SqlDbType.BigInt).Value=(object?)x.ParentId??DBNull.Value;
        cmd.Parameters.AddWithValue("@code",x.Code.Trim());
        cmd.Parameters.AddWithValue("@name",x.Name.Trim());
        cmd.Parameters.AddWithValue("@type",x.Type??"OTHER");
        cmd.Parameters.AddWithValue("@description",(object?)x.Description??DBNull.Value);
        cmd.Parameters.AddWithValue("@active",x.Active);
        cmd.Parameters.AddWithValue("@actor",User.FindFirstValue("user_id")??"api");
        try
        {
            var saved=Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
            await tx.CommitAsync(token);
            return Ok(new { id=saved });
        }
        catch(SqlException e) when(e.Number is 51201 or 51202 or 51203 or 2601 or 2627)
        {
            await tx.RollbackAsync(token);
            return Conflict(new { message="บันทึกสถานที่ไม่ได้",description=e.Number switch { 51201=>"ไม่พบรายการใน Company หรือสถานที่แม่เดิม กรุณาโหลดข้อมูลใหม่",51203=>"กรุณาเลือกอาคารและชั้นที่เปิดใช้งานใน Company ของตน",_=>"รหัสซ้ำในสถานที่เดียวกัน กรุณาเปลี่ยนรหัส" } });
        }
    }
}

public sealed record LocationRequest(string Code,string Name,long? ParentId,string? Type,string? Description,bool Active=true);
public sealed record RoomResidentAssignmentRequest(List<long>? ResidentIds);
