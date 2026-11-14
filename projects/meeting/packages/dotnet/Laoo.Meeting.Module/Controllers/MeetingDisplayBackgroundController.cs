using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Authorize, Route("api/company/meeting-display-backgrounds")]
[LaooMeetingApi.Security.RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingDisplayBackgroundController(IConfiguration configuration) : ControllerBase
{
    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        return db;
    }

    private long? Company => long.TryParse(User.FindFirstValue("company_id"), out var value) && value > 0 ? value : null;

    [HttpGet("visibility")]
    public async Task<IActionResult> Visibility(CancellationToken token)
    {
        if (Company is not long company) return Forbid();
        await using var db = await Open(token);
        if (!await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, "LAOO_MEETING", "22006", "VIEW", token)) return Forbid();
        await using var cmd = new SqlCommand("SELECT PrivateSubject,ShowRequester,ShowDepartment,ShowActivityType,ShowAttendeeCount,ShowSubject,ShowDetails,ShowRemark,ShowWaitingList FROM dbo.TDADMeetingDisplayVisibility WHERE CompanyID=@company", db);
        cmd.Parameters.AddWithValue("@company", company);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return Ok(new DisplayVisibility(false,false,false,false,false,false,false,false,false));
        return Ok(new DisplayVisibility(reader.GetBoolean(0),reader.GetBoolean(1),reader.GetBoolean(2),reader.GetBoolean(3),reader.GetBoolean(4),reader.GetBoolean(5),reader.GetBoolean(6),reader.GetBoolean(7),reader.GetBoolean(8)));
    }

    [HttpPut("visibility")]
    public async Task<IActionResult> SaveVisibility(DisplayVisibility value, CancellationToken token)
    {
        if (Company is not long company || !long.TryParse(User.FindFirstValue("user_id"), out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, "LAOO_MEETING", "22006", "EDIT", token)) return Forbid();
        const string sql = "UPDATE dbo.TDADMeetingDisplayVisibility SET PrivateSubject=@private,ShowRequester=@requester,ShowDepartment=@department,ShowActivityType=@activity,ShowAttendeeCount=@count,ShowSubject=@subject,ShowDetails=@details,ShowRemark=@remark,ShowWaitingList=COALESCE(@waiting,ShowWaitingList),UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company; IF @@ROWCOUNT=0 INSERT dbo.TDADMeetingDisplayVisibility(CompanyID,PrivateSubject,ShowRequester,ShowDepartment,ShowActivityType,ShowAttendeeCount,ShowSubject,ShowDetails,ShowRemark,ShowWaitingList,UpdateBy) VALUES(@company,@private,@requester,@department,@activity,@count,@subject,@details,@remark,COALESCE(@waiting,0),@user);";
        await using var cmd = new SqlCommand(sql, db);
        cmd.Parameters.AddWithValue("@company",company); cmd.Parameters.AddWithValue("@user",user);
        cmd.Parameters.AddWithValue("@private",value.PrivateSubject); cmd.Parameters.AddWithValue("@requester",value.ShowRequester); cmd.Parameters.AddWithValue("@department",value.ShowDepartment); cmd.Parameters.AddWithValue("@activity",value.ShowActivityType); cmd.Parameters.AddWithValue("@count",value.ShowAttendeeCount); cmd.Parameters.AddWithValue("@subject",value.ShowSubject); cmd.Parameters.AddWithValue("@details",value.ShowDetails); cmd.Parameters.AddWithValue("@remark",value.ShowRemark);
        cmd.Parameters.Add("@waiting", System.Data.SqlDbType.Bit).Value = (object?)value.ShowWaitingList ?? DBNull.Value;
        await cmd.ExecuteNonQueryAsync(token); return NoContent();
    }

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        if (Company is not long company) return Forbid();
        await using var db = await Open(token);
        if (!await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, "LAOO_MEETING", "22006", "VIEW", token)) return Forbid();
        await using var cmd = new SqlCommand("SELECT SlotNo,Orientation,ImageData,ContentType FROM dbo.TDADMeetingDisplayBackground WHERE CompanyID=@company ORDER BY SlotNo", db);
        cmd.Parameters.AddWithValue("@company", company);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token))
            items.Add(new { slot = reader.GetByte(0), orientation = reader.GetString(1), image = reader.IsDBNull(2) ? null : Convert.ToBase64String((byte[])reader[2]), contentType = reader.IsDBNull(3) ? null : reader.GetString(3) });
        return Ok(items);
    }

    [HttpPut("{slot:int}")]
    [RequestSizeLimit(8 * 1024 * 1024)]
    public async Task<IActionResult> Save(int slot, BackgroundRequest request, CancellationToken token)
    {
        if (Company is not long company || !long.TryParse(User.FindFirstValue("user_id"), out var user)) return Forbid();
        if (slot is < 1 or > 10 || request.Orientation is not ("PORTRAIT" or "LANDSCAPE")) return BadRequest();
        byte[]? bytes = null;
        string? contentType = null;
        if (!string.IsNullOrEmpty(request.Image))
        {
            try { bytes = Convert.FromBase64String(request.Image); } catch (FormatException) { return BadRequest(); }
            if (bytes.Length is 0 or > 5 * 1024 * 1024) return BadRequest(new { message = "รูปต้องมีขนาดไม่เกิน 5 MB" });
            contentType = bytes.Length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff ? "image/jpeg"
                : bytes.Length >= 8 && bytes.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }) ? "image/png"
                : bytes.Length >= 12 && System.Text.Encoding.ASCII.GetString(bytes, 0, 4) == "RIFF" && System.Text.Encoding.ASCII.GetString(bytes, 8, 4) == "WEBP" ? "image/webp" : null;
            if (contentType is null) return BadRequest(new { message = "รองรับเฉพาะ JPG, PNG และ WEBP" });
        }
        await using var db = await Open(token);
        if (!await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, "LAOO_MEETING", "22006", "EDIT", token)) return Forbid();
        const string sql = "UPDATE dbo.TDADMeetingDisplayBackground SET Orientation=@orientation,ImageData=@image,ContentType=@type,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND SlotNo=@slot; IF @@ROWCOUNT=0 INSERT dbo.TDADMeetingDisplayBackground(CompanyID,SlotNo,Orientation,ImageData,ContentType,UpdateBy) VALUES(@company,@slot,@orientation,@image,@type,@user);";
        await using var cmd = new SqlCommand(sql, db);
        cmd.Parameters.AddWithValue("@company", company); cmd.Parameters.AddWithValue("@slot", slot);
        cmd.Parameters.AddWithValue("@orientation", request.Orientation); cmd.Parameters.AddWithValue("@user", user);
        cmd.Parameters.Add("@image", System.Data.SqlDbType.VarBinary, -1).Value = (object?)bytes ?? DBNull.Value;
        cmd.Parameters.AddWithValue("@type", (object?)contentType ?? DBNull.Value);
        await cmd.ExecuteNonQueryAsync(token);
        return NoContent();
    }
}

public sealed record BackgroundRequest(string Orientation, string? Image);
public sealed record DisplayVisibility(bool PrivateSubject, bool ShowRequester, bool ShowDepartment, bool ShowActivityType, bool ShowAttendeeCount, bool ShowSubject, bool ShowDetails, bool ShowRemark, bool? ShowWaitingList = null);
