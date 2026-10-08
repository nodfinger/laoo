using Microsoft.AspNetCore.Mvc;
namespace Laoo.DigitalChecklist.Controllers;

public sealed partial class DigitalChecklistController
{
    [HttpPut("settings")]
    public async Task<IActionResult> UpdateSettings(ChecklistSettingInput input, CancellationToken ct)
    {
        if (input.ReminderMinutes is < 0 or > 10080 || input.TimeZoneId is not ("Asia/Bangkok" or "UTC") ||
            input.ServiceMenuCode is { Length: > 20 })
            return BadRequest(new { message = "ตรวจเวลาเตือน เขตเวลา และเมนูแจ้งซ่อมให้ถูกต้อง" });
        await using var db = await Open(ct);
        if (await Guard(db, "58001", "EDIT", ct) is { } denied) return denied;
        const string sql = """
            BEGIN TRY BEGIN TRAN;
            MERGE dbo.TDCLSetting WITH(HOLDLOCK) AS T
            USING (SELECT @co CompanyID) AS S ON T.CompanyID=S.CompanyID
            WHEN MATCHED THEN UPDATE SET TimeZoneId=@tz,NotifyInApp=@app,NotifyEmail=@email,ReminderMinutes=@minutes,ServiceMenuCode=@service,UpdatedAt=SYSUTCDATETIME()
            WHEN NOT MATCHED THEN INSERT(CompanyID,ProjectID,TimeZoneId,NotifyInApp,NotifyEmail,ReminderMinutes,ServiceMenuCode)
              VALUES(@co,(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_DIGITAL_CHECKLIST'),@tz,@app,@email,@minutes,@service);
            INSERT dbo.TDCLAudit(CompanyID,ActorUserID,ActionCode,EntityCode,EntityID,Detail)
              SELECT @co,@actor,'EDIT','SETTING',@co,N'ปรับตั้งค่าระบบตรวจสอบดิจิทัล';
            COMMIT; END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH
            """;
        await DigitalChecklistDb.Id(db, sql + " SELECT @co;", ct, ("@co", Company), ("@actor", Actor), ("@tz", input.TimeZoneId), ("@app", input.NotifyInApp), ("@email", input.NotifyEmail), ("@minutes", input.ReminderMinutes), ("@service", (object?)input.ServiceMenuCode ?? DBNull.Value));
        return Ok(new { saved = true });
    }
}
