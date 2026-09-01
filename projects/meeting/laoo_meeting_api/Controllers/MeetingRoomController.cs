using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Route("api/company/meeting-rooms"), Authorize]
public sealed class MeetingRoomController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private const string ScreenCode = "15002";

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission("VIEW", token)) return Forbid();
        await using var c = await Open(token);
        const string sql = "SELECT R.RoomID,R.BuildingID,R.FloorID,R.RoomCode,R.RoomNameTH,R.Capacity,R.Description,R.RoomImageUrl,R.LocationImageUrl,R.IsActive,(SELECT RF.FacilityID facilityId,RF.Quantity quantity,RF.Remark remark,RF.IsActive isActive FROM dbo.TDADMeetingRoomFacility RF WHERE RF.RoomID=R.RoomID FOR JSON PATH) FROM dbo.TDADMeetingRoom R WHERE R.CompanyID=@company ORDER BY R.RoomCode";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", company);
        await using var reader = await cmd.ExecuteReaderAsync(token); var rows = new List<object>();
        while (await reader.ReadAsync(token)) { var items = JsonSerializer.Deserialize<List<RoomFacilityItem>>(N(reader,10) ?? "[]", new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? []; rows.Add(new { roomId = Convert.ToInt64(reader.GetValue(0)), buildingId = I(reader,1), floorId = I(reader,2), code = reader.GetString(3), nameTh = reader.GetString(4), capacity = I(reader,5), description = N(reader,6), roomImageUrl = N(reader,7), locationImageUrl = N(reader,8), isActive = reader.GetBoolean(9), facilityIds = items.Select(x=>x.FacilityId).ToList(), facilityItems = items }); }
        return Ok(rows);
    }

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token) { await using var c = await Open(token); return Ok(new { view=await Allowed(c,"VIEW",token), create=await Allowed(c,"CREATE",token), edit=await Allowed(c,"EDIT",token), delete=await Allowed(c,"DELETE",token) }); }

    [HttpPost]
    public Task<IActionResult> Create(RoomRequest request, CancellationToken token) => Save(null, request, token);
    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, RoomRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission("DELETE", token)) return Forbid();
        await using var c = await Open(token); await using var cmd = new SqlCommand("DELETE FROM dbo.TDADMeetingRoom WHERE RoomID=@id AND CompanyID=@company", c); Add(cmd,"@id",id); Add(cmd,"@company",company);
        return await cmd.ExecuteNonQueryAsync(token)==0 ? NotFound(new { message="ไม่พบห้องประชุม", description=$"RoomID {id} ไม่อยู่ในบริษัทของผู้ใช้งาน" }) : NoContent();
    }

    [HttpPost("{id:long}/images/{kind}")]
    public async Task<IActionResult> Upload(long id, string kind, IFormFile file, CancellationToken token)
    {
        if (CompanyId() is not long company || !new[]{"room","location"}.Contains(kind,StringComparer.OrdinalIgnoreCase) || file.Length == 0 || file.Length > 1024*1024 || !await Permission("EDIT",token)) return BadRequest(new { message="อัปโหลดรูปไม่สำเร็จ", description="รองรับรูปขนาดไม่เกิน 1 MB และชนิด room หรือ location เท่านั้น" });
        var root = Path.Combine(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath,"wwwroot"), "uploads", "meeting-rooms"); Directory.CreateDirectory(root); var name = $"{company}_{id}_{kind}_{Guid.NewGuid():N}{Path.GetExtension(file.FileName).ToLowerInvariant()}"; var path=Path.Combine(root,name); await using(var stream=System.IO.File.Create(path)) await file.CopyToAsync(stream,token); var url=$"/uploads/meeting-rooms/{name}";
        await using var c=await Open(token); var column=kind.Equals("location",StringComparison.OrdinalIgnoreCase)?"LocationImageUrl":"RoomImageUrl"; await using var cmd=new SqlCommand($"UPDATE dbo.TDADMeetingRoom SET {column}=@url,UpdateDate=SYSUTCDATETIME() WHERE RoomID=@id AND CompanyID=@company",c); Add(cmd,"@url",url); Add(cmd,"@id",id); Add(cmd,"@company",company); await cmd.ExecuteNonQueryAsync(token); return Ok(new { url });
    }

    private async Task<IActionResult> Save(long? id, RoomRequest r, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission(id is null?"CREATE":"EDIT",token)) return Forbid(); await using var c=await Open(token); await using var tx=await c.BeginTransactionAsync(token);
        try { const string sql="IF EXISTS(SELECT 1 FROM dbo.TDADMeetingRoom WHERE CompanyID=@company AND RoomCode=@code AND (@id IS NULL OR RoomID<>@id)) THROW 50012,'DUPLICATE_ROOM',1; IF @id IS NULL BEGIN INSERT dbo.TDADMeetingRoom(CompanyID,BuildingID,FloorID,RoomCode,RoomNameTH,Capacity,Description,IsActive) VALUES(@company,@building,@floor,@code,@name,@capacity,@description,@active); SELECT CAST(SCOPE_IDENTITY() AS BIGINT); END ELSE BEGIN UPDATE dbo.TDADMeetingRoom SET BuildingID=@building,FloorID=@floor,RoomCode=@code,RoomNameTH=@name,Capacity=@capacity,Description=@description,IsActive=@active,UpdateDate=SYSUTCDATETIME() WHERE RoomID=@id AND CompanyID=@company; SELECT @id; END"; await using var cmd=new SqlCommand(sql,c,(SqlTransaction)tx); Add(cmd,"@id",id); Add(cmd,"@company",company); Add(cmd,"@building",r.BuildingId); Add(cmd,"@floor",r.FloorId); Add(cmd,"@code",r.Code.Trim().ToUpperInvariant()); Add(cmd,"@name",r.NameTh.Trim()); Add(cmd,"@capacity",r.Capacity); Add(cmd,"@description",r.Description); Add(cmd,"@active",r.IsActive); var room=Convert.ToInt64(await cmd.ExecuteScalarAsync(token)); await using var clear=new SqlCommand("DELETE FROM dbo.TDADMeetingRoomFacility WHERE RoomID=@room",c,(SqlTransaction)tx); Add(clear,"@room",room); await clear.ExecuteNonQueryAsync(token); foreach(var f in r.FacilityItems ?? []){ await using var add=new SqlCommand("INSERT dbo.TDADMeetingRoomFacility(RoomID,FacilityID,Quantity,Remark,IsActive) SELECT @room,F.FacilityID,@quantity,@remark,@isActive FROM dbo.TDADMeetingFacility F WHERE F.FacilityID=@facility AND F.CompanyID=@company",c,(SqlTransaction)tx); Add(add,"@room",room); Add(add,"@facility",f.FacilityId); Add(add,"@quantity",f.Quantity); Add(add,"@remark",f.Remark); Add(add,"@isActive",f.IsActive); Add(add,"@company",company); await add.ExecuteNonQueryAsync(token); } await tx.CommitAsync(token); return Ok(new { roomId=room }); } catch(SqlException ex) when(ex.Number==50012){ await tx.RollbackAsync(token); return Conflict(new {message="รหัสห้องประชุมซ้ำ",description="กรุณาใช้รหัสห้องประชุมอื่น"}); }
    }
    [HttpGet("{id:long}/contacts")]
    public async Task<IActionResult> Contacts(long id, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission("VIEW", token)) return Forbid();
        await using var c = await Open(token);
        const string sql = "SELECT E.EmployeeID,E.EmployeeCode,E.FullName,E.NickName,DP.NameTH FROM dbo.TDADMeetingRoomContact C INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=C.RoomID AND R.CompanyID=@company INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=C.EmployeeID AND E.CompanyID=@company LEFT JOIN dbo.TDADOrganizationUnit DP ON DP.OrgUnitID=E.DepartmentOrgUnitID WHERE C.RoomID=@room AND C.IsActive=1 ORDER BY E.EmployeeCode";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", company); Add(cmd, "@room", id);
        await using var reader = await cmd.ExecuteReaderAsync(token); var result = new List<object>();
        while (await reader.ReadAsync(token)) result.Add(new { employeeId = reader.GetInt64(0), code = reader.GetString(1), fullName = reader.GetString(2), nickName = N(reader, 3), department = N(reader, 4) });
        return Ok(result);
    }

    [HttpPut("{id:long}/contacts")]
    public async Task<IActionResult> SaveContacts(long id, RoomContactsRequest request, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission("EDIT", token)) return Forbid();
        await using var c = await Open(token); await using var tx = await c.BeginTransactionAsync(token);
        try
        {
            await using var clear = new SqlCommand("DELETE C FROM dbo.TDADMeetingRoomContact C INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=C.RoomID WHERE C.RoomID=@room AND R.CompanyID=@company", c, (SqlTransaction)tx); Add(clear, "@room", id); Add(clear, "@company", company); await clear.ExecuteNonQueryAsync(token);
            foreach (var employeeId in (request.EmployeeIds ?? []).Distinct())
            {
                await using var add = new SqlCommand("INSERT dbo.TDADMeetingRoomContact(RoomID,EmployeeID) SELECT @room,E.EmployeeID FROM dbo.TDADEmployee E WHERE E.EmployeeID=@employee AND E.CompanyID=@company AND E.IsActive=1", c, (SqlTransaction)tx); Add(add, "@room", id); Add(add, "@employee", employeeId); Add(add, "@company", company); await add.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token); return Ok(new { roomId = id, count = request.EmployeeIds?.Distinct().Count() ?? 0 });
        }
        catch { await tx.RollbackAsync(token); throw; }
    }

    private async Task<bool> Permission(string action,CancellationToken t){await using var c=await Open(t);return await Allowed(c,action,t);} private async Task<bool> Allowed(SqlConnection c,string action,CancellationToken t){if(!IsCompany()||CompanyId() is null||!long.TryParse(User.FindFirstValue("project_id"),out var p)||!long.TryParse(User.FindFirstValue("user_id"),out var u))return false;const string s="SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@u AND CompanyID=@c AND IsActive=1 AND IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@u AND UP.ProjectID=@p AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action) THEN 1 ELSE 0 END";await using var q=new SqlCommand(s,c);Add(q,"@u",u);Add(q,"@c",CompanyId()??0);Add(q,"@p",p);Add(q,"@screen",ScreenCode);Add(q,"@action",action);return Convert.ToBoolean(await q.ExecuteScalarAsync(t));}
    private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;} private bool IsCompany()=>string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase); private long? CompanyId()=>long.TryParse(User.FindFirstValue("company_id"),out var id)&&id>0?id:null; private static string? N(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i); private static long? I(SqlDataReader r,int i)=>r.IsDBNull(i)?null:Convert.ToInt64(r.GetValue(i)); private static void Add(SqlCommand c,string n,object? v)=>c.Parameters.AddWithValue(n,v??DBNull.Value);
}
public sealed record RoomRequest(long? BuildingId,long? FloorId,string Code,string NameTh,int? Capacity,string? Description,List<RoomFacilityItem>? FacilityItems,bool IsActive=true);
public sealed record RoomFacilityItem(long FacilityId,int? Quantity,string? Remark,bool IsActive=true);
public sealed record RoomContactsRequest(List<long>? EmployeeIds);


