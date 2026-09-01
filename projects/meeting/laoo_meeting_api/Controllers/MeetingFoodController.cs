using System.Data;
using System.Security.Claims;
using LaooMeetingApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Route("api/company/meeting-foods"), Authorize]
public sealed class MeetingFoodController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private const string ScreenCode = "15004";

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long companyId) return Forbid();
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        const string sql = @"
SELECT F.FoodID,F.FoodCode,F.FoodNameTH,F.FoodTypeCode,T.Name,F.FoodImageUrl
FROM dbo.TDADMeetingFood F
LEFT JOIN dbo.TDSTMaster T
  ON T.MasterGroupCode=@foodTypeGroup
 AND T.MasterCode=F.FoodTypeCode
 AND T.OwnerType='L'
 AND T.OwnerPartnerID IS NULL
 AND T.OwnerCompanyID IS NULL
WHERE F.CompanyID=@company
ORDER BY F.FoodCode";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@company", companyId);
        Add(command, "@foodTypeGroup", MasterGroupCodes.FoodType);
        await using var reader = await command.ExecuteReaderAsync(token);
        var result = new List<FoodRow>();
        while (await reader.ReadAsync(token))
        {
            result.Add(new(
                reader.GetInt64(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetString(3),
                Text(reader, 4),
                Text(reader, 5)));
        }
        return Ok(result);
    }

    [HttpGet("types")]
    public async Task<IActionResult> Types(CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is null) return Forbid();
        await using var connection = await Open(token);
        if (!await Allowed(connection, "VIEW", token)) return Forbid();
        const string sql = @"
SELECT MasterCode,Name
FROM dbo.TDSTMaster
WHERE MasterGroupCode=@foodTypeGroup
  AND OwnerType='L'
  AND OwnerPartnerID IS NULL
  AND OwnerCompanyID IS NULL
  AND IsActive=1
ORDER BY ISNULL(Seq,0),Name";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@foodTypeGroup", MasterGroupCodes.FoodType);
        await using var reader = await command.ExecuteReaderAsync(token);
        var result = new List<object>();
        while (await reader.ReadAsync(token))
            result.Add(new { code = reader.GetString(0), name = reader.GetString(1) });
        return Ok(result);
    }

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var connection = await Open(token);
        return Ok(new
        {
            view = await Allowed(connection, "VIEW", token),
            create = await Allowed(connection, "CREATE", token),
            edit = await Allowed(connection, "EDIT", token),
            delete = await Allowed(connection, "DELETE", token),
        });
    }

    [HttpPost]
    public Task<IActionResult> Create(FoodRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, FoodRequest request, CancellationToken token) => Save(id, request, token);

    [HttpPost("{id:long}/image")]
    [RequestSizeLimit(100 * 1024)]
    public async Task<IActionResult> UploadImage(long id, IFormFile file, CancellationToken token)
    {
        const int maximumBytes = 70 * 1024;
        if (!IsCompany() || CompanyId() is not long company || !await Permission("EDIT", token)) return Forbid();
        if (file.Length == 0 || file.Length > maximumBytes)
            return BadRequest(new { message = "ขนาดรูปอาหารไม่ถูกต้อง", description = "กรุณาเลือกรูปที่บีบอัดแล้วไม่เกิน 70 KB" });
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (extension is not (".jpg" or ".jpeg" or ".png" or ".webp"))
            return BadRequest(new { message = "รูปแบบไฟล์ไม่รองรับ", description = "รองรับเฉพาะ JPG, PNG และ WebP" });

        await using var connection = await Open(token);
        await using var find = new SqlCommand("SELECT FoodImageUrl FROM dbo.TDADMeetingFood WHERE FoodID=@id AND CompanyID=@company", connection);
        Add(find, "@id", id);
        Add(find, "@company", company);
        var existingValue = await find.ExecuteScalarAsync(token);
        if (existingValue is null)
            return NotFound(new { message = "ไม่พบรายการอาหารที่ต้องการบันทึกรูป", description = $"FoodID {id} ไม่อยู่ในขอบเขตบริษัทของผู้ใช้งาน" });
        var existingUrl = existingValue is DBNull ? null : Convert.ToString(existingValue);

        var webRoot = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
        var folder = Path.Combine(webRoot, "uploads", "meeting-foods", company.ToString());
        Directory.CreateDirectory(folder);
        var filename = $"{id}_{Guid.NewGuid():N}{extension}";
        var path = Path.Combine(folder, filename);
        await using (var stream = System.IO.File.Create(path))
            await file.CopyToAsync(stream, token);

        var imageUrl = $"/uploads/meeting-foods/{company}/{filename}";
        await using var update = new SqlCommand("UPDATE dbo.TDADMeetingFood SET FoodImageUrl=@url,UpdateDate=SYSUTCDATETIME() WHERE FoodID=@id AND CompanyID=@company", connection);
        Add(update, "@url", imageUrl);
        Add(update, "@id", id);
        Add(update, "@company", company);
        await update.ExecuteNonQueryAsync(token);

        DeletePreviousImage(webRoot, existingUrl, imageUrl);
        return Ok(new { imageUrl });
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission("DELETE", token)) return Forbid();
        await using var connection = await Open(token);
        await using var command = new SqlCommand("DELETE FROM dbo.TDADMeetingFood OUTPUT DELETED.FoodImageUrl WHERE FoodID=@id AND CompanyID=@company", connection);
        Add(command, "@id", id);
        Add(command, "@company", company);
        var deletedValue = await command.ExecuteScalarAsync(token);
        if (deletedValue is null)
            return NotFound(new { message = "ไม่พบรายการอาหารที่ต้องการลบ", description = $"FoodID {id} ไม่อยู่ในขอบเขตบริษัทของผู้ใช้งาน" });
        var imageUrl = deletedValue is DBNull ? null : Convert.ToString(deletedValue);
        var webRoot = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
        DeletePreviousImage(webRoot, imageUrl, string.Empty);
        return NoContent();
    }

    private async Task<IActionResult> Save(long? id, FoodRequest request, CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(request.Code) || string.IsNullOrWhiteSpace(request.NameTh))
            return BadRequest(new { message = "ข้อมูลรายการอาหารไม่ครบ", description = "กรุณาระบุรหัสและชื่อรายการอาหาร" });
        if (string.IsNullOrWhiteSpace(request.FoodTypeCode))
            return BadRequest(new { message = "กรุณาเลือกประเภทอาหาร", description = "ประเภทอาหารเป็นข้อมูลบังคับ" });
        if (!IsCompany() || CompanyId() is not long company || !await Permission(id is null ? "CREATE" : "EDIT", token)) return Forbid();

        await using var connection = await Open(token);
        const string sql = @"
IF NOT EXISTS
(
    SELECT 1 FROM dbo.TDSTMaster
    WHERE MasterGroupCode=@foodTypeGroup AND MasterCode=@foodType
      AND OwnerType='L' AND OwnerPartnerID IS NULL AND OwnerCompanyID IS NULL
      AND IsActive=1
) THROW 50014,'INVALID_FOOD_TYPE',1;
IF EXISTS
(
    SELECT 1 FROM dbo.TDADMeetingFood
    WHERE CompanyID=@company AND FoodCode=@code
      AND (@id IS NULL OR FoodID<>@id)
) THROW 50013,'DUPLICATE_FOOD',1;
IF @id IS NULL
BEGIN
    INSERT dbo.TDADMeetingFood
        (CompanyID,FoodCode,FoodNameTH,FoodTypeCode,CreateDate)
    VALUES
        (@company,@code,@name,@foodType,SYSUTCDATETIME());
    SELECT CAST(SCOPE_IDENTITY() AS BIGINT);
END
ELSE
BEGIN
    UPDATE dbo.TDADMeetingFood
    SET FoodCode=@code,FoodNameTH=@name,FoodTypeCode=@foodType,
        UpdateDate=SYSUTCDATETIME()
    WHERE FoodID=@id AND CompanyID=@company;
    SELECT @id;
END";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@id", id);
        Add(command, "@company", company);
        Add(command, "@code", request.Code.Trim().ToUpperInvariant());
        Add(command, "@name", request.NameTh.Trim());
        Add(command, "@foodType", request.FoodTypeCode.Trim());
        Add(command, "@foodTypeGroup", MasterGroupCodes.FoodType);
        try
        {
            return Ok(new { foodId = Convert.ToInt64(await command.ExecuteScalarAsync(token)) });
        }
        catch (SqlException exception) when (exception.Number == 50013)
        {
            return Conflict(new { message = "รหัสรายการอาหารซ้ำ", description = "กรุณาใช้รหัสอื่นที่ยังไม่ถูกใช้งานในบริษัทนี้" });
        }
        catch (SqlException exception) when (exception.Number == 50014)
        {
            return BadRequest(new { message = "ประเภทอาหารไม่ถูกต้อง", description = "กรุณาเลือกประเภทอาหารที่ยังใช้งานอยู่" });
        }
    }

    private async Task<bool> Permission(string action, CancellationToken token)
    {
        await using var connection = await Open(token);
        return await Allowed(connection, action, token);
    }

    private async Task<bool> Allowed(SqlConnection connection, string action, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is null ||
            !long.TryParse(User.FindFirstValue("project_id"), out var project) ||
            !long.TryParse(User.FindFirstValue("user_id"), out var user)) return false;
        const string sql = @"
SELECT CASE WHEN EXISTS
(
    SELECT 1 FROM dbo.TDADUser U
    WHERE U.UserID=@user AND U.CompanyID=@company
      AND U.IsActive=1 AND U.IsCompanyAdmin=1
)
OR EXISTS
(
    SELECT 1
    FROM dbo.TDADUserPermission UP
    INNER JOIN dbo.TDADPermission P
      ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
    WHERE UP.UserID=@user AND UP.ProjectID=@project
      AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1
      AND P.ScreenCode=@screen AND P.ActionCode=@action
)
THEN 1 ELSE 0 END";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@user", user);
        Add(command, "@company", CompanyId() ?? 0);
        Add(command, "@project", project);
        Add(command, "@screen", ScreenCode);
        Add(command, "@action", action);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private bool IsCompany() => string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase);
    private long? CompanyId() => long.TryParse(User.FindFirstValue("company_id"), out var id) && id > 0 ? id : null;
    private static string? Text(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
    private static void Add(SqlCommand command, string name, object? value) => command.Parameters.AddWithValue(name, value ?? DBNull.Value);
    private static void DeletePreviousImage(string webRoot, string? existingUrl, string newUrl)
    {
        if (string.IsNullOrWhiteSpace(existingUrl) || existingUrl == newUrl || !existingUrl.StartsWith("/uploads/meeting-foods/", StringComparison.OrdinalIgnoreCase)) return;
        var relative = existingUrl.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
        var candidate = Path.GetFullPath(Path.Combine(webRoot, relative));
        var allowedRoot = Path.GetFullPath(Path.Combine(webRoot, "uploads", "meeting-foods")) + Path.DirectorySeparatorChar;
        if (candidate.StartsWith(allowedRoot, StringComparison.OrdinalIgnoreCase) && System.IO.File.Exists(candidate))
            System.IO.File.Delete(candidate);
    }
}

public sealed record FoodRequest(string Code, string NameTh, string FoodTypeCode);
public sealed record FoodRow(long FoodId, string Code, string NameTh, string FoodTypeCode, string? FoodTypeName, string? ImageUrl);
