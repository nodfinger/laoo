using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Route("api/company/meeting-structure"), Authorize]
public sealed class MeetingStructureController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private const string ScreenCode = "23001";

    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] long? branchId, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long companyId) return Forbid();
        await using var c = await Open(token);
        if (!await Allowed(c, "VIEW", token)) return Forbid();
        const string sql = "SELECT B.BuildingID,B.BranchID,B.BuildingCode,B.BuildingNameTH,B.BuildingNameEN,B.BuildingImageUrl,B.ContName,B.ContPhone,B.ContEmail,B.IsActive FROM dbo.TDADBuilding B WHERE B.CompanyID=@company AND (@branch IS NULL OR B.BranchID=@branch) ORDER BY B.BuildingCode; SELECT F.FloorID,F.BuildingID,F.FloorCode,F.FloorNameTH,F.FloorNameEN,F.FloorNumber,F.IsActive FROM dbo.TDADFloor F INNER JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE B.CompanyID=@company AND (@branch IS NULL OR B.BranchID=@branch) ORDER BY F.BuildingID,F.FloorNumber,F.FloorCode;";
        await using var cmd = new SqlCommand(sql, c); cmd.Parameters.AddWithValue("@company", companyId); cmd.Parameters.Add("@branch", SqlDbType.BigInt).Value = branchId ?? (object)DBNull.Value;
        await using var r = await cmd.ExecuteReaderAsync(token);
        var buildings = new List<BuildingRow>();
        while (await r.ReadAsync(token)) buildings.Add(new(r.GetInt64(0), r.GetInt64(1), r.GetString(2), r.GetString(3), N(r,4), N(r,5), N(r,6), N(r,7), N(r,8), r.GetBoolean(9), []));
        await r.NextResultAsync(token);
        var floors = new List<FloorRow>();
        while (await r.ReadAsync(token)) floors.Add(new(r.GetInt64(0), r.GetInt64(1), r.GetString(2), r.GetString(3), N(r,4), r.IsDBNull(5)?null:r.GetInt32(5), r.GetBoolean(6)));
        return Ok(buildings.Select(b => b with { Floors = floors.Where(f => f.BuildingId == b.BuildingId).ToList() }));
    }

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        return Ok(new { view = await Allowed(c,"VIEW",token), create = await Allowed(c,"CREATE",token), edit = await Allowed(c,"EDIT",token), delete = await Allowed(c,"DELETE",token) });
    }

    [HttpPost("buildings")]
    public Task<IActionResult> CreateBuilding(BuildingRequest request, CancellationToken token) => SaveBuilding(null, request, token);
    [HttpPut("buildings/{id:long}")]
    public Task<IActionResult> UpdateBuilding(long id, BuildingRequest request, CancellationToken token) => SaveBuilding(id, request, token);
    [HttpDelete("buildings/{id:long}")]
    public Task<IActionResult> DeleteBuilding(long id, CancellationToken token) => DeleteBuildingCore(id, token);

    [HttpPost("buildings/{id:long}/image")]
    [RequestSizeLimit(1024 * 1024)]
    public async Task<IActionResult> UploadBuildingImage(long id, IFormFile file, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission("EDIT", token)) return Forbid();
        if (file.Length == 0 || file.Length > 1024 * 1024) return BadRequest(new { message = "รูปอาคารไม่ถูกต้อง", description = "กรุณาเลือกไฟล์ขนาดไม่เกิน 1 MB" });
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (extension is not (".jpg" or ".jpeg" or ".png" or ".webp")) return BadRequest(new { message = "รูปแบบไฟล์ไม่รองรับ", description = "รองรับเฉพาะ JPG, PNG และ WebP" });
        var webRoot = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
        var folder = Path.Combine(webRoot, "uploads", "buildings", company.ToString());
        Directory.CreateDirectory(folder);
        var filename = $"{id}_{Guid.NewGuid():N}{extension}";
        var path = Path.Combine(folder, filename);
        await using (var stream = System.IO.File.Create(path)) await file.CopyToAsync(stream, token);
        await using var c = await Open(token);
        await using var cmd = new SqlCommand("UPDATE dbo.TDADBuilding SET BuildingImageUrl=@url,UpdateDate=SYSUTCDATETIME() WHERE BuildingID=@id AND CompanyID=@company", c);
        var imageUrl = $"/uploads/buildings/{company}/{filename}";
        Add(cmd, "@url", imageUrl); Add(cmd, "@id", id); Add(cmd, "@company", company);
        var affected = await cmd.ExecuteNonQueryAsync(token);
        if (affected == 0)
        {
            System.IO.File.Delete(path);
            return NotFound(new { message = "ไม่พบอาคารที่ต้องการบันทึกรูป", description = $"BuildingID {id} ไม่อยู่ในขอบเขตบริษัทของผู้ใช้งาน" });
        }
        return Ok(new { imageUrl });
    }

    [HttpPost("floors")]
    public Task<IActionResult> CreateFloor(FloorRequest request, CancellationToken token) => SaveFloor(null, request, token);
    [HttpPut("floors/{id:long}")]
    public Task<IActionResult> UpdateFloor(long id, FloorRequest request, CancellationToken token) => SaveFloor(id, request, token);
    [HttpDelete("floors/{id:long}")]
    public Task<IActionResult> DeleteFloor(long id, CancellationToken token) => DeleteFloorCore(id, token);

    private async Task<IActionResult> SaveBuilding(long? id, BuildingRequest x, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission(id is null ? "CREATE" : "EDIT", token)) return Forbid();
        await using var c = await Open(token);
        const string sql = "IF NOT EXISTS(SELECT 1 FROM dbo.TDADBranch WHERE BranchID=@branch AND CompanyID=@company) THROW 50101,'BRANCH_SCOPE',1; IF EXISTS(SELECT 1 FROM dbo.TDADBuilding WHERE BranchID=@branch AND BuildingCode=@code AND (@id IS NULL OR BuildingID<>@id)) THROW 50102,'DUPLICATE_CODE',1; IF @id IS NULL INSERT dbo.TDADBuilding(CompanyID,BranchID,BuildingCode,BuildingNameTH,BuildingNameEN,BuildingImageUrl,ContName,ContPhone,ContEmail,IsActive,CreateDate) VALUES(@company,@branch,@code,@th,@en,@image,@contName,@contPhone,@contEmail,@active,SYSUTCDATETIME()); ELSE UPDATE dbo.TDADBuilding SET BuildingCode=@code,BuildingNameTH=@th,BuildingNameEN=@en,BuildingImageUrl=@image,ContName=@contName,ContPhone=@contPhone,ContEmail=@contEmail,IsActive=@active,UpdateDate=SYSUTCDATETIME() WHERE BuildingID=@id AND CompanyID=@company; SELECT COALESCE(@id, SCOPE_IDENTITY());";
        await using var cmd = new SqlCommand(sql,c); Add(cmd,"@company",company); Add(cmd,"@branch",x.BranchId); Add(cmd,"@code",x.Code.ToUpperInvariant()); Add(cmd,"@th",x.NameTh); Add(cmd,"@en",x.NameEn); Add(cmd,"@image",x.ImageUrl); Add(cmd,"@contName",x.ContName); Add(cmd,"@contPhone",x.ContPhone); Add(cmd,"@contEmail",x.ContEmail); Add(cmd,"@active",x.IsActive); cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id??(object)DBNull.Value;
        try { var savedId = Convert.ToInt64(await cmd.ExecuteScalarAsync(token)); return Ok(new { buildingId = savedId }); } catch(SqlException ex) when(ex.Number is 50101 or 50102){ return Conflict(new { message = ex.Number==50101 ? "สาขาไม่อยู่ในบริษัทของผู้ใช้งาน" : "รหัสอาคารซ้ำ" }); }
    }

    private async Task<IActionResult> SaveFloor(long? id, FloorRequest x, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission(id is null ? "CREATE" : "EDIT", token)) return Forbid();
        await using var c = await Open(token);
        const string sql = "IF NOT EXISTS(SELECT 1 FROM dbo.TDADBuilding WHERE BuildingID=@building AND CompanyID=@company) THROW 50103,'BUILDING_SCOPE',1; IF EXISTS(SELECT 1 FROM dbo.TDADFloor WHERE BuildingID=@building AND FloorCode=@code AND (@id IS NULL OR FloorID<>@id)) THROW 50104,'DUPLICATE_CODE',1; IF @id IS NULL INSERT dbo.TDADFloor(BuildingID,FloorCode,FloorNameTH,FloorNameEN,FloorNumber,IsActive,CreateDate) VALUES(@building,@code,@th,@en,@number,@active,SYSUTCDATETIME()); ELSE UPDATE dbo.TDADFloor SET FloorCode=@code,FloorNameTH=@th,FloorNameEN=@en,FloorNumber=@number,IsActive=@active,UpdateDate=SYSUTCDATETIME() WHERE FloorID=@id AND BuildingID=@building;";
        await using var cmd = new SqlCommand(sql,c); Add(cmd,"@company",company); Add(cmd,"@building",x.BuildingId); Add(cmd,"@code",x.Code); Add(cmd,"@th",x.NameTh); Add(cmd,"@en",x.NameEn); cmd.Parameters.Add("@number",SqlDbType.Int).Value=x.Number??(object)DBNull.Value; Add(cmd,"@active",x.IsActive); cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id??(object)DBNull.Value;
        try { return await cmd.ExecuteNonQueryAsync(token)==0 ? NotFound() : NoContent(); } catch(SqlException ex) when(ex.Number is 50103 or 50104){ return Conflict(new { message = ex.Number==50103 ? "อาคารไม่อยู่ในบริษัทของผู้ใช้งาน" : "รหัสชั้นซ้ำ" }); }
    }

    private async Task<IActionResult> DeleteBuildingCore(long id,CancellationToken t){if(!await Permission("DELETE",t))return Forbid();await using var c=await Open(t);await using var q=new SqlCommand("IF EXISTS(SELECT 1 FROM dbo.TDADFloor WHERE BuildingID=@id) THROW 50105,'HAS_FLOORS',1; DELETE FROM dbo.TDADBuilding WHERE BuildingID=@id AND CompanyID=@company",c);Add(q,"@id",id);Add(q,"@company",CompanyId()??0);try{return await q.ExecuteNonQueryAsync(t)==0?NotFound():NoContent();}catch(SqlException ex)when(ex.Number==50105){return Conflict(new{message="ไม่สามารถลบอาคารที่มีชั้นอยู่ได้"});}}
    private async Task<IActionResult> DeleteFloorCore(long id,CancellationToken t){if(!await Permission("DELETE",t))return Forbid();await using var c=await Open(t);await using var q=new SqlCommand("DELETE F FROM dbo.TDADFloor F INNER JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID WHERE F.FloorID=@id AND B.CompanyID=@company",c);Add(q,"@id",id);Add(q,"@company",CompanyId()??0);return await q.ExecuteNonQueryAsync(t)==0?NotFound():NoContent();}
    private async Task<bool> Permission(string action,CancellationToken t){await using var c=await Open(t);return await Allowed(c,action,t);}
    private async Task<bool> Allowed(SqlConnection c,string action,CancellationToken t){if(!IsCompany()||CompanyId() is null||!long.TryParse(User.FindFirstValue("project_id"),out var project)||!long.TryParse(User.FindFirstValue("user_id"),out var user))return false;const string sql="SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action) THEN 1 ELSE 0 END";await using var q=new SqlCommand(sql,c);Add(q,"@user",user);Add(q,"@company",CompanyId()??0);Add(q,"@project",project);Add(q,"@screen",ScreenCode);Add(q,"@action",action);return Convert.ToBoolean(await q.ExecuteScalarAsync(t));}
    private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private bool IsCompany()=>string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase);
    private long? CompanyId()=>long.TryParse(User.FindFirstValue("company_id"),out var id)&&id>0?id:null;
    private static string? N(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i);
    private static void Add(SqlCommand c,string n,object? v){c.Parameters.AddWithValue(n,v??DBNull.Value);}
}
public sealed record BuildingRequest(long BranchId,string Code,string NameTh,string? NameEn,string? ImageUrl,string? ContName,string? ContPhone,string? ContEmail,bool IsActive=true);
public sealed record FloorRequest(long BuildingId,string Code,string NameTh,string? NameEn,int? Number,bool IsActive=true);
public sealed record BuildingRow(long BuildingId,long BranchId,string Code,string NameTh,string? NameEn,string? ImageUrl,string? ContName,string? ContPhone,string? ContEmail,bool IsActive,List<FloorRow> Floors);
public sealed record FloorRow(long FloorId,long BuildingId,string Code,string NameTh,string? NameEn,int? Number,bool IsActive);
