using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Laoo.Patrol.Controllers;

[ApiController, Authorize, Route("api/company/patrol")]
public sealed partial class PatrolController(IConfiguration configuration) : ControllerBase
{
    private long Company => long.Parse(User.FindFirst("company_id")!.Value);
    private long Actor => long.Parse(User.FindFirst("user_id")!.Value);
    private async Task<SqlConnection> Open(CancellationToken ct) { var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await db.OpenAsync(ct); return db; }
    private async Task<IActionResult?> Guard(SqlConnection db, string menu, string action, CancellationToken ct)
    {
        if (!PatrolAccess.Scope(User, out _, out _)) return Forbid();
        return await PatrolAccess.Can(db, User, menu, action, ct) ? null : StatusCode(403, new { message = "Invalid patrol request", description = "Invalid patrol request" });
    }
    private static IActionResult Invalid(string detail) => new BadRequestObjectResult(new { message = "Invalid patrol request", description = detail });
    private async Task<long?> Employee(SqlConnection db, CancellationToken ct)
    {
        var rows = await PatrolDb.Rows(db, null, "SELECT TOP(1) EmployeeID FROM dbo.TDADUserEmployee WHERE CompanyID=@co AND UserID=@user AND IsActive=1", ct, ("@co", Company), ("@user", Actor));
        return rows.Count == 0 ? null : Convert.ToInt64(rows[0]["EmployeeID"]);
    }
    private async Task Audit(SqlConnection db, SqlTransaction? tx, string action, string entity, long id, string? detail, CancellationToken ct) =>
        await PatrolDb.Execute(db, tx, "INSERT dbo.TDPCAudit(CompanyID,ActorUserID,ActionCode,EntityType,EntityID,Detail) VALUES(@co,@actor,@action,@entity,@id,@detail)", ct, ("@co", Company), ("@actor", Actor), ("@action", action), ("@entity", entity), ("@id", id), ("@detail", detail));
    private async Task<IActionResult> List(string menu, string sql, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, menu, "VIEW", ct) is { } denied) return denied;
        return Ok(await PatrolDb.Rows(db, null, sql, ct, ("@co", Company)));
    }

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, menu, "VIEW", ct) is { } denied) return denied;
        var rows = await PatrolDb.Rows(db, null, "SELECT ActionCode FROM dbo.TDADPermission P JOIN dbo.TDADProject J ON J.ProjectID=P.ProjectID WHERE J.ProjectCode=N'LAOO_PATROL' AND P.ScreenCode=@menu AND P.IsActive=1", ct, ("@menu", menu));
        var actions = new Dictionary<string, bool>();
        foreach (var row in rows) { var action = Convert.ToString(row["ActionCode"])!; actions[action.ToLowerInvariant()] = await PatrolAccess.Can(db, User, menu, action, ct); }
        var meta = await PatrolDb.Rows(db, null, "SELECT MenuName,ScreenType,IconName FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1", ct, ("@menu", menu));
        return Ok(new { actions, metadata = meta.Single() });
    }

    [HttpGet("options")]
    public async Task<IActionResult> Options([FromQuery] string menuCode, CancellationToken ct)
    {
        if (menuCode is not ("56002" or "56003" or "56004" or "56005" or "56006" or "56007")) return BadRequest(new { message = "Invalid menu", description = "เลือกหน้าจอจัดการที่ถูกต้องแล้วลองใหม่" });
        await using var db = await Open(ct); if (await Guard(db, menuCode, "VIEW", ct) is { } denied) return denied;
        return Ok(new
        {
            branches = await PatrolDb.Rows(db, null, "SELECT BranchID id,BranchCode code,BranchNameTH name FROM dbo.TDADBranch WHERE CompanyID=@co AND IsActive=1 ORDER BY BranchNameTH", ct, ("@co", Company)),
            buildings = await PatrolDb.Rows(db, null, "SELECT BuildingID id,BranchID branchId,BuildingCode code,BuildingNameTH name FROM dbo.TDADBuilding WHERE CompanyID=@co AND IsActive=1 ORDER BY BuildingNameTH", ct, ("@co", Company)),
            floors = await PatrolDb.Rows(db, null, "SELECT F.FloorID id,F.BuildingID buildingId,F.FloorCode code,F.FloorNameTH name FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.BuildingID=F.BuildingID AND B.CompanyID=@co WHERE F.IsActive=1 ORDER BY F.FloorNameTH", ct, ("@co", Company)),
            rooms = await PatrolDb.Rows(db, null, "SELECT RoomID id,BuildingID buildingId,FloorID floorId,RoomCode code,RoomNameTH name FROM dbo.TDADRoom WHERE CompanyID=@co AND IsActive=1 ORDER BY RoomCode", ct, ("@co", Company)),
            employees = await PatrolDb.Rows(db, null, "SELECT EmployeeID id,EmployeeCode code,FullName name FROM dbo.TDADEmployee WHERE CompanyID=@co AND IsActive=1 ORDER BY FullName", ct, ("@co", Company)),
            checkpoints = await PatrolDb.Rows(db, null, "SELECT CheckpointID id,CheckpointCode code,CheckpointName name,BranchID branchId FROM dbo.TDPCCheckpoint WHERE CompanyID=@co AND IsActive=1 ORDER BY CheckpointName", ct, ("@co", Company)),
            checklists = await PatrolDb.Rows(db, null, "SELECT TemplateID id,TemplateCode code,TemplateName name,WorkType workType FROM dbo.TDPCChecklistTemplate WHERE CompanyID=@co AND IsActive=1 ORDER BY TemplateName", ct, ("@co", Company)),
            devices = await PatrolDb.Rows(db, null, "SELECT DeviceID id,DeviceCode code,DeviceName name,CheckpointID checkpointId FROM dbo.TDPCDevice WHERE CompanyID=@co AND IsActive=1 ORDER BY DeviceName", ct, ("@co", Company)),
            routes = await PatrolDb.Rows(db, null, "SELECT RouteID id,RouteCode code,RouteName name FROM dbo.TDPCRoute WHERE CompanyID=@co AND IsActive=1 ORDER BY RouteName", ct, ("@co", Company))
        });
    }
    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56001", "VIEW", ct) is { } denied) return denied;
        var rows = await PatrolDb.Rows(db, null, "SELECT DefaultGraceBeforeMinutes,DefaultGraceAfterMinutes,OfflineMaxHours,GpsRadiusMeters,EscalateAfterMinutes FROM dbo.TDPCSetting WHERE CompanyID=@co", ct, ("@co", Company));
        return Ok(rows.FirstOrDefault() ?? new Dictionary<string, object?> { { "DefaultGraceBeforeMinutes", 0 }, { "DefaultGraceAfterMinutes", 15 }, { "OfflineMaxHours", 24 }, { "GpsRadiusMeters", 100 }, { "EscalateAfterMinutes", 30 } });
    }

    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(SettingInput x, CancellationToken ct)
    {
        if (x.GraceBefore is < 0 or > 1440 || x.GraceAfter is < 0 or > 1440 || x.OfflineHours is < 1 or > 72 || x.GpsRadius is < 5 or > 5000 || x.EscalateAfter is < 1 or > 10080) return Invalid("Invalid patrol request");
        await using var db = await Open(ct); if (await Guard(db, "56001", "EDIT", ct) is { } denied) return denied;
        await PatrolDb.Execute(db, null, "MERGE dbo.TDPCSetting WITH(HOLDLOCK) T USING(SELECT @co CompanyID) S ON T.CompanyID=S.CompanyID WHEN MATCHED THEN UPDATE SET DefaultGraceBeforeMinutes=@gb,DefaultGraceAfterMinutes=@ga,OfflineMaxHours=@off,GpsRadiusMeters=@gps,EscalateAfterMinutes=@esc,UpdatedAt=SYSUTCDATETIME() WHEN NOT MATCHED THEN INSERT(CompanyID,ProjectID,DefaultGraceBeforeMinutes,DefaultGraceAfterMinutes,OfflineMaxHours,GpsRadiusMeters,EscalateAfterMinutes) VALUES(@co,(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_PATROL'),@gb,@ga,@off,@gps,@esc);", ct, ("@co", Company), ("@gb", x.GraceBefore), ("@ga", x.GraceAfter), ("@off", x.OfflineHours), ("@gps", x.GpsRadius), ("@esc", x.EscalateAfter));
        await Audit(db, null, "EDIT", "SETTING", Company, null, ct); return Ok(new { saved = true });
    }
}
