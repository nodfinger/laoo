using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Laoo.Sport.Controllers;

[ApiController, Authorize, Route("api/company/sport")]
public sealed partial class SportController(IConfiguration configuration) : ControllerBase
{
    private async Task<SqlConnection> Open(CancellationToken ct)
    {
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        return db;
    }

    private async Task<IActionResult?> Guard(SqlConnection db, string menu, string action, CancellationToken ct)
    {
        if (!SportAccess.Scope(User, out _, out _)) return Forbid();
        if (!await SportAccess.Can(db, User, menu, action, ct))
            return StatusCode(403, new { message = "ไม่มีสิทธิ์ทำรายการกีฬา",
                description = "ตรวจสอบแพ็กเกจระบบกีฬาและสิทธิ์เมนูกับผู้ดูแล" });
        return null;
    }

    private long Company => long.Parse(User.FindFirst("company_id")!.Value);
    private long Actor => long.Parse(User.FindFirst("user_id")!.Value);
    private static IActionResult Invalid(string detail) =>
        new BadRequestObjectResult(new { message = "ข้อมูลไม่ถูกต้อง", description = detail });

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, menu, "VIEW", ct) is { } denied) return denied;
        var rows = await SportDb.Rows(db, null,
            "SELECT ActionCode FROM dbo.TDADPermission P JOIN dbo.TDADProject J ON J.ProjectID=P.ProjectID WHERE J.ProjectCode=N'LAOO_SPORT' AND P.ScreenCode=@menu AND P.IsActive=1",
            ct, ("@menu", menu));
        var actions = new Dictionary<string, bool>();
        foreach (var row in rows)
        {
            var action = Convert.ToString(row["ActionCode"])!;
            actions[action.ToLowerInvariant()] = await SportAccess.Can(db, User, menu, action, ct);
        }
        var meta = await SportDb.Rows(db, null,
            "SELECT MenuName,ScreenType,IconName FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1",
            ct, ("@menu", menu));
        return Ok(new { actions, metadata = meta.Single() });
    }

    [HttpGet("settings")]
    public async Task<IActionResult> GetSettings(CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54001", "VIEW", ct) is { } denied) return denied;
        var rows = await SportDb.Rows(db, null,
            "SELECT PaymentHoldMinutes,CancelBeforeMinutes,CheckInGraceMinutes,ExpiryNoticeDays FROM dbo.TDSPSetting WHERE CompanyID=@co",
            ct, ("@co", Company));
        return Ok(rows.FirstOrDefault() ?? new Dictionary<string, object?>
        {
            ["PaymentHoldMinutes"] = 30,
            ["CancelBeforeMinutes"] = 120,
            ["CheckInGraceMinutes"] = 15,
            ["ExpiryNoticeDays"] = 30
        });
    }

    [HttpPut("settings")]
    public async Task<IActionResult> PutSettings(SportSettingInput input, CancellationToken ct)
    {
        if (input.PaymentHoldMinutes is < 1 or > 1440 || input.CancelBeforeMinutes is < 0 or > 10080
            || input.CheckInGraceMinutes is < 0 or > 1440 || input.ExpiryNoticeDays is < 1 or > 365)
            return Invalid("ช่วงเวลาที่กำหนดไม่ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "54001", "EDIT", ct) is { } denied) return denied;
        await SportDb.Execute(db, null, """
MERGE dbo.TDSPSetting WITH(HOLDLOCK) AS T
USING(SELECT @co CompanyID) S ON T.CompanyID=S.CompanyID
WHEN MATCHED THEN UPDATE SET PaymentHoldMinutes=@hold,CancelBeforeMinutes=@cancel,
 CheckInGraceMinutes=@grace,ExpiryNoticeDays=@notice,UpdatedAt=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(CompanyID,ProjectID,PaymentHoldMinutes,CancelBeforeMinutes,CheckInGraceMinutes,ExpiryNoticeDays)
 VALUES(@co,(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SPORT'),@hold,@cancel,@grace,@notice);
""", ct, ("@co", Company), ("@hold", input.PaymentHoldMinutes),
            ("@cancel", input.CancelBeforeMinutes), ("@grace", input.CheckInGraceMinutes),
            ("@notice", input.ExpiryNoticeDays));
        return Ok(new { saved = true });
    }
}

public sealed record SportSettingInput(int PaymentHoldMinutes, int CancelBeforeMinutes,
    int CheckInGraceMinutes, int ExpiryNoticeDays);
