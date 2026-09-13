using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Route("api/company/meeting-rooms"), Authorize]
[LaooMeetingApi.Security.RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingRoomController(
    IConfiguration configuration,
    IWebHostEnvironment environment) : ControllerBase
{
    private const string ScreenCode = "23002";

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company ||
            !await Permission("VIEW", token)) return Forbid();
        await using var db = await Open(token);
        const string sql = """
SELECT R.RoomID,R.BuildingID,R.FloorID,R.RoomCode,R.RoomNameTH,R.Capacity,
       R.Description,R.RoomImageUrl,R.LocationImageUrl,R.IsActive,
       (SELECT RI.ItemID itemId,I.ItemCode code,I.ItemName nameTh,I.UnitCode unitCode,
               RI.Quantity quantity,RI.Remark remark,RI.IsActive isActive
        FROM dbo.TDADMeetingRoomItem RI
        INNER JOIN dbo.TDIVItem I ON I.ItemID=RI.ItemID AND I.CompanyID=R.CompanyID
        WHERE RI.RoomID=R.RoomID
        ORDER BY I.ItemCode FOR JSON PATH)
FROM dbo.TDADMeetingRoom R
WHERE R.CompanyID=@company
ORDER BY R.RoomCode
""";
        await using var command = new SqlCommand(sql, db);
        Add(command, "@company", company);
        await using var reader = await command.ExecuteReaderAsync(token);
        var rows = new List<object>();
        while (await reader.ReadAsync(token))
        {
            var items = JsonSerializer.Deserialize<List<RoomItem>>(
                Text(reader, 10) ?? "[]",
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];
            rows.Add(new
            {
                roomId = reader.GetInt64(0),
                buildingId = Long(reader, 1),
                floorId = Long(reader, 2),
                code = reader.GetString(3),
                nameTh = reader.GetString(4),
                capacity = Long(reader, 5),
                description = Text(reader, 6),
                roomImageUrl = Text(reader, 7),
                locationImageUrl = Text(reader, 8),
                isActive = reader.GetBoolean(9),
                itemIds = items.Select(x => x.ItemId).ToList(),
                itemItems = items,
            });
        }
        return Ok(rows);
    }

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var db = await Open(token);
        return Ok(new
        {
            view = await Allowed(db, "VIEW", token),
            create = await Allowed(db, "CREATE", token),
            edit = await Allowed(db, "EDIT", token),
            delete = await Allowed(db, "DELETE", token),
        });
    }

    [HttpPost]
    public Task<IActionResult> Create(RoomRequest request, CancellationToken token) =>
        Save(null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, RoomRequest request, CancellationToken token) =>
        Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company ||
            !await Permission("DELETE", token)) return Forbid();
        await using var db = await Open(token);
        await using var command = new SqlCommand(
            "DELETE FROM dbo.TDADMeetingRoom WHERE RoomID=@id AND CompanyID=@company",
            db);
        Add(command, "@id", id); Add(command, "@company", company);
        return await command.ExecuteNonQueryAsync(token) == 0
            ? NotFound(new
            {
                message = "ไม่พบห้องประชุม",
                description = "ห้องประชุมไม่อยู่ในบริษัทของผู้ใช้งาน",
            })
            : NoContent();
    }

    [HttpGet("{id:long}/images/{kind}")]
    public async Task<IActionResult> Image(long id, string kind, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company ||
            !new[] { "room", "location" }.Contains(kind, StringComparer.OrdinalIgnoreCase) ||
            !await Permission("VIEW", token)) return Forbid();
        await using var db = await Open(token);
        var column = kind.Equals("location", StringComparison.OrdinalIgnoreCase)
            ? "LocationImageUrl" : "RoomImageUrl";
        await using var command = new SqlCommand(
            "SELECT " + column + " FROM dbo.TDADMeetingRoom WHERE RoomID=@id AND CompanyID=@company",
            db);
        Add(command, "@id", id); Add(command, "@company", company);
        var stored = Convert.ToString(await command.ExecuteScalarAsync(token));
        if (string.IsNullOrWhiteSpace(stored) ||
            !stored.StartsWith("/uploads/meeting-rooms/", StringComparison.OrdinalIgnoreCase))
            return NotFound(new { message = "ไม่พบรูปห้องประชุม", description = "ห้องนี้ยังไม่มีรูปภาพ" });
        var fileName = Path.GetFileName(stored);
        var root = Path.Combine(
            environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"),
            "uploads", "meeting-rooms");
        var path = Path.Combine(root, fileName);
        if (!System.IO.File.Exists(path))
            return NotFound(new { message = "ไม่พบไฟล์รูปห้องประชุม", description = "กรุณาแนบรูปใหม่" });
        var contentType = Path.GetExtension(fileName).ToLowerInvariant() switch
        {
            ".png" => "image/png",
            ".webp" => "image/webp",
            ".gif" => "image/gif",
            _ => "image/jpeg",
        };
        return PhysicalFile(path, contentType);
    }

    [HttpPost("{id:long}/images/{kind}")]
    public async Task<IActionResult> Upload(
        long id, string kind, IFormFile file, CancellationToken token)
    {
        if (CompanyId() is not long company ||
            !new[] { "room", "location" }.Contains(kind, StringComparer.OrdinalIgnoreCase) ||
            file.Length == 0 || file.Length > 1024 * 1024 ||
            !await Permission("EDIT", token))
            return BadRequest(new { message = "อัปโหลดรูปไม่สำเร็จ", description = "ไฟล์ไม่ถูกต้อง" });
        var root = Path.Combine(
            environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"),
            "uploads", "meeting-rooms");
        Directory.CreateDirectory(root);
        var name = string.Concat(company, "_", id, "_", kind, "_",
            Guid.NewGuid().ToString("N"), Path.GetExtension(file.FileName).ToLowerInvariant());
        var path = Path.Combine(root, name);
        await using (var stream = System.IO.File.Create(path))
            await file.CopyToAsync(stream, token);
        var url = "/uploads/meeting-rooms/" + name;
        await using var db = await Open(token);
        var column = kind.Equals("location", StringComparison.OrdinalIgnoreCase)
            ? "LocationImageUrl" : "RoomImageUrl";
        await using var command = new SqlCommand(
            "UPDATE dbo.TDADMeetingRoom SET " + column +
            "=@url,UpdateDate=SYSUTCDATETIME() WHERE RoomID=@id AND CompanyID=@company",
            db);
        Add(command, "@url", url); Add(command, "@id", id); Add(command, "@company", company);
        await command.ExecuteNonQueryAsync(token);
        return Ok(new { url });
    }

    private async Task<IActionResult> Save(
        long? id, RoomRequest request, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company ||
            !await Permission(id is null ? "CREATE" : "EDIT", token)) return Forbid();
        await using var db = await Open(token);
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(token);
        try
        {
            const string roomSql = """
IF EXISTS(SELECT 1 FROM dbo.TDADMeetingRoom
          WHERE CompanyID=@company AND RoomCode=@code
            AND (@id IS NULL OR RoomID<>@id))
    THROW 50012,'DUPLICATE_ROOM',1;
IF @id IS NULL
BEGIN
    INSERT dbo.TDADMeetingRoom
        (CompanyID,BuildingID,FloorID,RoomCode,RoomNameTH,Capacity,Description,IsActive)
    VALUES (@company,@building,@floor,@code,@name,@capacity,@description,@active);
    SELECT CAST(SCOPE_IDENTITY() AS BIGINT);
END
ELSE
BEGIN
    UPDATE dbo.TDADMeetingRoom
    SET BuildingID=@building,FloorID=@floor,RoomCode=@code,RoomNameTH=@name,
        Capacity=@capacity,Description=@description,IsActive=@active,
        UpdateDate=SYSUTCDATETIME()
    WHERE RoomID=@id AND CompanyID=@company;
    SELECT @id;
END
""";
            await using var roomCommand = new SqlCommand(roomSql, db, tx);
            Add(roomCommand, "@id", id); Add(roomCommand, "@company", company);
            Add(roomCommand, "@building", request.BuildingId);
            Add(roomCommand, "@floor", request.FloorId);
            Add(roomCommand, "@code", request.Code.Trim().ToUpperInvariant());
            Add(roomCommand, "@name", request.NameTh.Trim());
            Add(roomCommand, "@capacity", request.Capacity);
            Add(roomCommand, "@description", request.Description);
            Add(roomCommand, "@active", request.IsActive);
            var room = Convert.ToInt64(await roomCommand.ExecuteScalarAsync(token));

            await using var clear = new SqlCommand(
                "DELETE FROM dbo.TDADMeetingRoomItem WHERE RoomID=@room", db, tx);
            Add(clear, "@room", room);
            await clear.ExecuteNonQueryAsync(token);
            foreach (var item in (request.ItemItems ?? [])
                .GroupBy(x => x.ItemId).Select(x => x.First()))
            {
                await using var add = new SqlCommand("""
IF NOT EXISTS
(
    SELECT 1 FROM dbo.TDIVItem I
    INNER JOIN dbo.TDIVItemUsage IU ON IU.CompanyID=I.CompanyID
        AND IU.ItemID=I.ItemID AND IU.UsageCode=N'EQUIPMENT'
    WHERE I.ItemID=@item AND I.CompanyID=@company AND I.IsActive=1
      AND (NOT EXISTS
           (SELECT 1 FROM dbo.TDIVItemProjectPolicy IP
            WHERE IP.CompanyID=I.CompanyID AND IP.ItemID=I.ItemID
              AND IP.AccessModeCode=N'SELECTED')
           OR EXISTS
           (SELECT 1 FROM dbo.TDIVItemProject IX
            INNER JOIN dbo.TDADProject MP ON MP.ProjectID=IX.ProjectID
                AND MP.ProjectCode=N'LAOO_MEETING' AND MP.IsActive=1
            WHERE IX.CompanyID=I.CompanyID AND IX.ItemID=I.ItemID))
)
    THROW 50013,'INVALID_MEETING_ITEM',1;
INSERT dbo.TDADMeetingRoomItem(RoomID,ItemID,Quantity,Remark,IsActive)
VALUES(@room,@item,@quantity,@remark,@isActive);
""", db, tx);
                Add(add, "@room", room); Add(add, "@item", item.ItemId);
                Add(add, "@company", company);
                add.Parameters.Add("@quantity", System.Data.SqlDbType.Int).Value =
                    item.Quantity is > 0 ? item.Quantity.Value : 1;
                add.Parameters.Add("@remark", System.Data.SqlDbType.NVarChar, 500).Value =
                    string.IsNullOrWhiteSpace(item.Remark)
                        ? DBNull.Value
                        : item.Remark.Trim();
                Add(add, "@isActive", item.IsActive);
                await add.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return Ok(new { roomId = room });
        }
        catch (SqlException ex) when (ex.Number == 50012)
        {
            await tx.RollbackAsync(token);
            return Conflict(new { message = "รหัสห้องประชุมซ้ำ", description = "กรุณาใช้รหัสห้องอื่น" });
        }
        catch (SqlException ex) when (ex.Number == 50013)
        {
            await tx.RollbackAsync(token);
            return BadRequest(new { message = "สินค้าอุปกรณ์ไม่ถูกต้อง", description = "เลือกเฉพาะสินค้า EQUIPMENT ที่เปิดใช้ใน Meeting" });
        }
    }

    [HttpGet("{id:long}/contacts")]
    public async Task<IActionResult> Contacts(long id, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company ||
            !await Permission("VIEW", token)) return Forbid();
        await using var db = await Open(token);
        const string sql = "SELECT E.EmployeeID,E.EmployeeCode,E.FullName,E.NickName,DP.NameTH FROM dbo.TDADMeetingRoomContact C INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=C.RoomID AND R.CompanyID=@company INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=C.EmployeeID AND E.CompanyID=@company LEFT JOIN dbo.TDADOrganizationUnit DP ON DP.OrgUnitID=E.DepartmentOrgUnitID WHERE C.RoomID=@room AND C.IsActive=1 ORDER BY E.EmployeeCode";
        await using var command = new SqlCommand(sql, db);
        Add(command, "@company", company); Add(command, "@room", id);
        await using var reader = await command.ExecuteReaderAsync(token);
        var result = new List<object>();
        while (await reader.ReadAsync(token))
            result.Add(new
            {
                employeeId = reader.GetInt64(0),
                code = reader.GetString(1),
                fullName = reader.GetString(2),
                nickName = Text(reader, 3),
                department = Text(reader, 4),
            });
        return Ok(result);
    }

    [HttpPut("{id:long}/contacts")]
    public async Task<IActionResult> SaveContacts(
        long id, RoomContactsRequest request, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company ||
            !await Permission("EDIT", token)) return Forbid();
        await using var db = await Open(token);
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(token);
        try
        {
            await using var clear = new SqlCommand(
                "DELETE C FROM dbo.TDADMeetingRoomContact C INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=C.RoomID WHERE C.RoomID=@room AND R.CompanyID=@company",
                db, tx);
            Add(clear, "@room", id); Add(clear, "@company", company);
            await clear.ExecuteNonQueryAsync(token);
            foreach (var employeeId in (request.EmployeeIds ?? []).Distinct())
            {
                await using var add = new SqlCommand(
                    "INSERT dbo.TDADMeetingRoomContact(RoomID,EmployeeID) SELECT @room,E.EmployeeID FROM dbo.TDADEmployee E WHERE E.EmployeeID=@employee AND E.CompanyID=@company AND E.IsActive=1",
                    db, tx);
                Add(add, "@room", id); Add(add, "@employee", employeeId);
                Add(add, "@company", company);
                await add.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return Ok(new { roomId = id, count = request.EmployeeIds?.Distinct().Count() ?? 0 });
        }
        catch
        {
            await tx.RollbackAsync(token);
            throw;
        }
    }

    private async Task<bool> Permission(string action, CancellationToken token)
    {
        await using var db = await Open(token);
        return await Allowed(db, action, token);
    }

    private Task<bool> Allowed(SqlConnection db, string action, CancellationToken token) =>
        LaooMeetingApi.Security.MeetingFoodPlanAccess.Allowed(db, User, action, token, ScreenCode);

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        return db;
    }

    private bool IsCompany() =>
        string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER",
            StringComparison.OrdinalIgnoreCase);

    private long? CompanyId() =>
        long.TryParse(User.FindFirstValue("company_id"), out var id) && id > 0 ? id : null;

    private static string? Text(SqlDataReader reader, int index) =>
        reader.IsDBNull(index) ? null : reader.GetString(index);

    private static long? Long(SqlDataReader reader, int index) =>
        reader.IsDBNull(index) ? null : Convert.ToInt64(reader.GetValue(index));

    private static void Add(SqlCommand command, string name, object? value) =>
        command.Parameters.AddWithValue(name, value ?? DBNull.Value);
}

public sealed record RoomRequest(
    long? BuildingId,
    long? FloorId,
    string Code,
    string NameTh,
    int? Capacity,
    string? Description,
    List<RoomItem>? ItemItems,
    bool IsActive = true);

public sealed record RoomItem(
    long ItemId,
    string? Code,
    string? NameTh,
    string? UnitCode,
    int? Quantity,
    string? Remark,
    bool IsActive = true);

public sealed record RoomContactsRequest(List<long>? EmployeeIds);
