using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Authorize]
[Route("api/company/meeting-room-issues")]
[LaooMeetingApi.Security.RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingRoomIssueController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "22003";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var db = await Open(token);
        return Ok(new
        {
            view = await Permission("VIEW", token),
            create = await Permission("CREATE", token),
            edit = await Permission("EDIT", token),
        });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] long? roomId, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company ||
            !await Permission("VIEW", token)) return Forbid();
        await using var db = await Open(token);
        const string sql = """
SELECT X.IssueID,X.RoomID,R.RoomCode,R.RoomNameTH,X.ItemID,I.ItemCode,I.ItemName,
       X.Description,X.ImageUrl,X.StatusCode,X.CreateDate
FROM dbo.TDADMeetingRoomIssue X
INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=X.RoomID AND R.CompanyID=X.CompanyID
INNER JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID
WHERE X.CompanyID=@company AND (@room IS NULL OR X.RoomID=@room)
ORDER BY X.CreateDate DESC,X.IssueID DESC
""";
        await using var command = new SqlCommand(sql, db);
        Add(command, "@company", company); Add(command, "@room", roomId);
        await using var reader = await command.ExecuteReaderAsync(token);
        var result = new List<object>();
        while (await reader.ReadAsync(token))
        {
            result.Add(new
            {
                issueId = reader.GetInt64(0),
                roomId = reader.GetInt64(1),
                roomCode = reader.GetString(2),
                roomNameTh = reader.GetString(3),
                itemId = reader.GetInt64(4),
                itemCode = reader.GetString(5),
                itemName = reader.GetString(6),
                description = reader.GetString(7),
                imageUrl = N(reader, 8),
                statusCode = reader.GetString(9),
                createDate = reader.GetDateTime(10),
            });
        }
        return Ok(result);
    }

    [HttpPost]
    public async Task<IActionResult> Create(RoomIssueRequest request, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company ||
            !TryUser(out var user) || !await Permission("CREATE", token)) return Forbid();
        if (request.Description?.Trim() is not { Length: > 0 } description)
            return BadRequest(new { message = "กรุณาระบุอาการหรือรายละเอียดปัญหา" });

        await using var db = await Open(token);
        const string sql = """
IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADMeetingRoomItem RI
    INNER JOIN dbo.TDADMeetingRoom R ON R.RoomID=RI.RoomID AND R.CompanyID=@company
    INNER JOIN dbo.TDIVItem I ON I.ItemID=RI.ItemID AND I.CompanyID=@company
    INNER JOIN dbo.TDIVItemUsage IU ON IU.CompanyID=I.CompanyID
        AND IU.ItemID=I.ItemID AND IU.UsageCode=N'EQUIPMENT'
    WHERE RI.RoomID=@room AND RI.ItemID=@item AND RI.IsActive=1 AND I.IsActive=1
)
    THROW 50031,'INVALID_ROOM_ITEM',1;
INSERT dbo.TDADMeetingRoomIssue
    (CompanyID,RoomID,ItemID,ReportedByUserID,Description,ImageUrl,StatusCode)
VALUES (@company,@room,@item,@user,@description,@image,N'OPEN');
SELECT CAST(SCOPE_IDENTITY() AS BIGINT);
""";
        await using var command = new SqlCommand(sql, db);
        Add(command, "@company", company); Add(command, "@room", request.RoomId);
        Add(command, "@item", request.ItemId); Add(command, "@user", user);
        Add(command, "@description", description);
        Add(command, "@image", request.ImageUrl?.Trim());
        try
        {
            var issueId = Convert.ToInt64(await command.ExecuteScalarAsync(token));
            return Ok(new { issueId, statusCode = "OPEN" });
        }
        catch (SqlException ex) when (ex.Number == 50031)
        {
            return BadRequest(new { message = "อุปกรณ์นี้ไม่ได้ถูกกำหนดให้กับห้อง", description = "กรุณาเลือกอุปกรณ์ที่ห้องนี้ใช้งานอยู่" });
        }
    }

    [HttpPut("{id:long}/status")]
    public async Task<IActionResult> UpdateStatus(long id, IssueStatusRequest request, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company ||
            !await Permission("EDIT", token)) return Forbid();
        if (request.StatusCode is not ("OPEN" or "IN_PROGRESS" or "RESOLVED" or "CANCELLED"))
            return BadRequest(new { message = "สถานะรายการแจ้งซ่อมไม่ถูกต้อง" });
        await using var db = await Open(token);
        await using var command = new SqlCommand("""
UPDATE dbo.TDADMeetingRoomIssue
SET StatusCode=@status,UpdateDate=SYSUTCDATETIME()
WHERE IssueID=@id AND CompanyID=@company
""", db);
        Add(command, "@status", request.StatusCode);
        Add(command, "@id", id); Add(command, "@company", company);
        return await command.ExecuteNonQueryAsync(token) == 0
            ? NotFound(new { message = "ไม่พบรายการแจ้งซ่อม" })
            : NoContent();
    }

    private async Task<bool> Permission(string action, CancellationToken token)
    {
        await using var db = await Open(token);
        return await LaooMeetingApi.Security.MeetingFoodPlanAccess
            .Allowed(db, User, action, token, ScreenCode);
    }

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        return db;
    }

    private bool IsCompany() =>
        string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase);

    private long? CompanyId() =>
        long.TryParse(User.FindFirstValue("company_id"), out var id) && id > 0 ? id : null;

    private bool TryUser(out long id) =>
        long.TryParse(User.FindFirstValue("user_id"), out id) && id > 0;

    private static string? N(SqlDataReader reader, int index) =>
        reader.IsDBNull(index) ? null : reader.GetString(index);

    private static void Add(SqlCommand command, string name, object? value) =>
        command.Parameters.AddWithValue(name, value ?? DBNull.Value);
}

public sealed record RoomIssueRequest(long RoomId, long ItemId, string? Description, string? ImageUrl);
public sealed record IssueStatusRequest(string StatusCode);
