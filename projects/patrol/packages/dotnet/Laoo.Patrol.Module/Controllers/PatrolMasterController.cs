using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Patrol.Controllers;

public sealed partial class PatrolController
{
    [HttpGet("checkpoints")]
    public async Task<IActionResult> Checkpoints(CancellationToken ct) => await List("56002", "SELECT C.CheckpointID id,C.BranchID branchId,C.BuildingID buildingId,C.FloorID floorId,C.RoomID roomId,C.CheckpointCode code,C.CheckpointName name,B.BranchNameTH branch,C.TimeMode timeMode,C.Latitude latitude,C.Longitude longitude,C.GpsRadiusMeters gpsRadius,C.RequireGps requireGps,C.RequirePhoto requirePhoto,C.RequireChecklist requireChecklist,C.AllowedMethods allowedMethods,C.IsActive isActive FROM dbo.TDPCCheckpoint C JOIN dbo.TDADBranch B ON B.CompanyID=C.CompanyID AND B.BranchID=C.BranchID WHERE C.CompanyID=@co ORDER BY C.CheckpointID DESC", ct);

    [HttpPost("checkpoints")]
    public async Task<IActionResult> AddCheckpoint(CheckpointInput x, CancellationToken ct)
    {
        if (!ValidCheckpoint(x)) return Invalid("ตรวจรหัส ชื่อ รูปแบบเวลา วิธีตรวจ และค่าพิกัดให้ถูกต้อง");
        await using var db = await Open(ct); if (await Guard(db, "56002", "CREATE", ct) is { } denied) return denied;
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDADBranch WHERE CompanyID=@co AND BranchID=@id AND IsActive=1", ct, ("@co", Company), ("@id", x.BranchId)) == 0) return Invalid("สาขาไม่ถูกต้องหรือไม่ได้เปิดใช้งาน");
        if (!await ValidCheckpointLocation(db, x, ct)) return Invalid("อาคาร ชั้น หรือห้องไม่ตรงกับสาขาที่เลือก");
        try
        {
            var id = await InsertCheckpoint(db, null, x, ct);
            await Audit(db, null, "CREATE", "CHECKPOINT", id, x.Code, ct); return Ok(new { id });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { return Conflict(new { message = "รหัสจุดตรวจซ้ำ", description = "เปลี่ยนรหัสจุดตรวจให้ไม่ซ้ำกับรายการอื่นในบริษัท" }); }
    }

    [HttpPut("checkpoints/{id:long}")]
    public async Task<IActionResult> EditCheckpoint(long id, CheckpointInput x, CancellationToken ct)
    {
        if (!ValidCheckpoint(x)) return Invalid("ตรวจรหัส ชื่อ รูปแบบเวลา วิธีตรวจ และค่าพิกัดให้ถูกต้อง");
        await using var db = await Open(ct); if (await Guard(db, "56002", "EDIT", ct) is { } denied) return denied;
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDADBranch WHERE CompanyID=@co AND BranchID=@id AND IsActive=1", ct, ("@co", Company), ("@id", x.BranchId)) == 0) return Invalid("สาขาไม่ถูกต้องหรือไม่ได้เปิดใช้งาน");
        if (!await ValidCheckpointLocation(db, x, ct)) return Invalid("อาคาร ชั้น หรือห้องไม่ตรงกับสาขาที่เลือก");
        try
        {
            var changed = await PatrolDb.Execute(db, null, "UPDATE dbo.TDPCCheckpoint SET BranchID=@branch,BuildingID=@building,FloorID=@floor,RoomID=@room,CheckpointCode=@code,CheckpointName=@name,TimeMode=@mode,Latitude=@lat,Longitude=@lng,GpsRadiusMeters=@radius,RequireGps=@gps,RequirePhoto=@photo,RequireChecklist=@list,AllowedMethods=@methods,IsActive=@active,UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND CheckpointID=@id", ct, ("@co", Company), ("@id", id), ("@branch", x.BranchId), ("@building", x.BuildingId), ("@floor", x.FloorId), ("@room", x.RoomId), ("@code", x.Code.Trim()), ("@name", x.Name.Trim()), ("@mode", x.TimeMode), ("@lat", x.Latitude), ("@lng", x.Longitude), ("@radius", x.GpsRadius), ("@gps", x.RequireGps), ("@photo", x.RequirePhoto), ("@list", x.RequireChecklist), ("@methods", string.Join(',', x.Methods.Distinct())), ("@active", x.Active));
            if (changed == 0) return NotFound(new { message = "ไม่พบจุดตรวจ", description = "โหลดรายการใหม่แล้วเลือกจุดตรวจที่ยังมีอยู่" });
            await Audit(db, null, "EDIT", "CHECKPOINT", id, x.Code, ct); return Ok(new { saved = true });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { return Conflict(new { message = "รหัสจุดตรวจซ้ำ", description = "เปลี่ยนรหัสจุดตรวจให้ไม่ซ้ำกับรายการอื่นในบริษัท" }); }
    }

    [HttpDelete("checkpoints/{id:long}")]
    public async Task<IActionResult> DeleteCheckpoint(long id, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56002", "DELETE", ct) is { } denied) return denied;
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDPCRouteCheckpoint WHERE CompanyID=@co AND CheckpointID=@id", ct, ("@co", Company), ("@id", id)) > 0) return Conflict(new { message = "จุดตรวจยังถูกใช้งาน", description = "นำจุดตรวจออกจากเส้นทางที่อ้างอิงก่อน จึงจะปิดใช้งานได้" });
        var changed = await PatrolDb.Execute(db, null, "UPDATE dbo.TDPCCheckpoint SET IsActive=0,UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND CheckpointID=@id AND IsActive=1", ct, ("@co", Company), ("@id", id));
        if (changed == 0) return NotFound(new { message = "ไม่พบจุดตรวจ", description = "โหลดรายการใหม่แล้วลองอีกครั้ง" });
        await Audit(db, null, "DEACTIVATE", "CHECKPOINT", id, null, ct); return Ok(new { deactivated = true });
    }

    [HttpGet("devices")]
    public async Task<IActionResult> Devices(CancellationToken ct) => await List("56003", "SELECT D.DeviceID id,D.CheckpointID checkpointId,C.CheckpointName [checkpoint],D.DeviceCode code,D.DeviceName name,D.AdapterCode adapter,D.LastSequence lastSequence,D.LastSeenAt lastSeen,D.IsActive isActive FROM dbo.TDPCDevice D LEFT JOIN dbo.TDPCCheckpoint C ON C.CompanyID=D.CompanyID AND C.CheckpointID=D.CheckpointID WHERE D.CompanyID=@co ORDER BY D.DeviceID DESC", ct);

    [HttpPost("devices")]
    public async Task<IActionResult> AddDevice(DeviceInput x, CancellationToken ct)
    {
        if (!ValidDevice(x)) return Invalid("กรุณากรอกรหัส ชื่อ และ Adapter ที่รองรับ");
        await using var db = await Open(ct); if (await Guard(db, "56003", "CREATE", ct) is { } denied) return denied;
        if (!await ValidCheckpointReference(db, x.CheckpointId, ct)) return Invalid("จุดตรวจต้องอยู่ในบริษัทเดียวกันและเปิดใช้งาน");
        try
        {
            var id = await PatrolDb.Id(db, null, "INSERT dbo.TDPCDevice(CompanyID,CheckpointID,DeviceCode,DeviceName,AdapterCode,PublicKey) OUTPUT INSERTED.DeviceID VALUES(@co,@cp,@code,@name,@adapter,@key)", ct, ("@co", Company), ("@cp", x.CheckpointId), ("@code", x.Code.Trim()), ("@name", x.Name.Trim()), ("@adapter", x.Adapter.Trim().ToUpperInvariant()), ("@key", x.PublicKey));
            await Audit(db, null, "CREATE", "DEVICE", id, x.Code, ct); return Ok(new { id });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { return Conflict(new { message = "รหัสอุปกรณ์ซ้ำ", description = "เปลี่ยนรหัสอุปกรณ์ให้ไม่ซ้ำในบริษัท" }); }
    }

    [HttpPut("devices/{id:long}")]
    public async Task<IActionResult> EditDevice(long id, DeviceInput x, CancellationToken ct)
    {
        if (!ValidDevice(x)) return Invalid("กรุณากรอกรหัส ชื่อ และ Adapter ที่รองรับ");
        await using var db = await Open(ct); if (await Guard(db, "56003", "EDIT", ct) is { } denied) return denied;
        if (!await ValidCheckpointReference(db, x.CheckpointId, ct)) return Invalid("จุดตรวจต้องอยู่ในบริษัทเดียวกันและเปิดใช้งาน");
        try
        {
            var changed = await PatrolDb.Execute(db, null, "UPDATE dbo.TDPCDevice SET CheckpointID=@cp,DeviceCode=@code,DeviceName=@name,AdapterCode=@adapter,PublicKey=COALESCE(@key,PublicKey) WHERE CompanyID=@co AND DeviceID=@id", ct, ("@co", Company), ("@id", id), ("@cp", x.CheckpointId), ("@code", x.Code.Trim()), ("@name", x.Name.Trim()), ("@adapter", x.Adapter.Trim().ToUpperInvariant()), ("@key", x.PublicKey));
            if (changed == 0) return NotFound(new { message = "ไม่พบอุปกรณ์", description = "โหลดรายการใหม่แล้วเลือกอุปกรณ์ที่ยังมีอยู่" });
            await Audit(db, null, "EDIT", "DEVICE", id, x.Code, ct); return Ok(new { saved = true });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { return Conflict(new { message = "รหัสอุปกรณ์ซ้ำ", description = "เปลี่ยนรหัสอุปกรณ์ให้ไม่ซ้ำในบริษัท" }); }
    }

    [HttpDelete("devices/{id:long}")]
    public async Task<IActionResult> DeleteDevice(long id, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56003", "DELETE", ct) is { } denied) return denied;
        var changed = await PatrolDb.Execute(db, null, "UPDATE dbo.TDPCDevice SET IsActive=0 WHERE CompanyID=@co AND DeviceID=@id AND IsActive=1", ct, ("@co", Company), ("@id", id));
        if (changed == 0) return NotFound(new { message = "ไม่พบอุปกรณ์", description = "โหลดรายการใหม่แล้วลองอีกครั้ง" });
        await Audit(db, null, "DEACTIVATE", "DEVICE", id, null, ct); return Ok(new { deactivated = true });
    }

    [HttpGet("credentials")]
    public async Task<IActionResult> Credentials(CancellationToken ct) => await List("56004", "SELECT C.CredentialID id,C.EmployeeID employeeId,E.EmployeeCode code,E.FullName name,C.CredentialType type,C.CredentialHint hint,C.DeviceID deviceId,C.EnrolledAt,C.IsActive isActive FROM dbo.TDPCCredential C JOIN dbo.TDADEmployee E ON E.CompanyID=C.CompanyID AND E.EmployeeID=C.EmployeeID WHERE C.CompanyID=@co ORDER BY C.CredentialID DESC", ct);

    [HttpPost("credentials")]
    public async Task<IActionResult> AddCredential(CredentialInput x, CancellationToken ct)
    {
        if (!ValidCredential(x)) return Invalid("กรุณาตรวจประเภทบัตรและรหัสอ้างอิง");
        await using var db = await Open(ct); if (await Guard(db, "56004", "ENROLL_CREDENTIAL", ct) is { } denied) return denied;
        if (!await ValidEmployeeAndDevice(db, x.EmployeeId, x.DeviceId, ct)) return Invalid("พนักงานหรืออุปกรณ์ไม่ถูกต้อง");
        return await SaveCredential(db, null, x, null, "CREATE", ct);
    }

    [HttpPut("credentials/{id:long}")]
    public async Task<IActionResult> EditCredential(long id, CredentialInput x, CancellationToken ct)
    {
        if (!ValidCredential(x)) return Invalid("กรุณากรอกรหัสอ้างอิงใหม่และเลือกประเภทให้ถูกต้อง");
        await using var db = await Open(ct); if (await Guard(db, "56004", "EDIT", ct) is { } denied) return denied;
        if (!await ValidEmployeeAndDevice(db, x.EmployeeId, x.DeviceId, ct)) return Invalid("พนักงานหรืออุปกรณ์ไม่ถูกต้อง");
        return await SaveCredential(db, null, x, id, "EDIT", ct);
    }

    [HttpDelete("credentials/{id:long}")]
    public async Task<IActionResult> DeleteCredential(long id, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56004", "DELETE", ct) is { } denied) return denied;
        var changed = await PatrolDb.Execute(db, null, "UPDATE dbo.TDPCCredential SET IsActive=0,RevokedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND CredentialID=@id AND IsActive=1", ct, ("@co", Company), ("@id", id));
        if (changed == 0) return NotFound(new { message = "ไม่พบข้อมูลบัตร", description = "โหลดรายการใหม่แล้วลองอีกครั้ง" });
        await Audit(db, null, "REVOKE", "CREDENTIAL", id, null, ct); return Ok(new { revoked = true });
    }

    [HttpGet("checklists")]
    public async Task<IActionResult> Checklists(CancellationToken ct) => await List("56005", "SELECT T.TemplateID id,T.TemplateCode code,T.TemplateName name,T.WorkType workType,T.IsActive isActive,(SELECT STRING_AGG(I.ItemText,CHAR(10)) FROM dbo.TDPCChecklistItem I WHERE I.CompanyID=T.CompanyID AND I.TemplateID=T.TemplateID) items FROM dbo.TDPCChecklistTemplate T WHERE T.CompanyID=@co ORDER BY T.TemplateID DESC", ct);

    [HttpPost("checklists")]
    public async Task<IActionResult> AddChecklist(ChecklistInput x, CancellationToken ct)
    {
        if (!ValidChecklist(x)) return Invalid("กรุณากรอกรหัส ชื่อ ประเภทงาน และรายการตรวจอย่างน้อยหนึ่งข้อ");
        await using var db = await Open(ct); if (await Guard(db, "56005", "CREATE", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var id = await InsertChecklist(db, tx, x, ct); await Audit(db, tx, "CREATE", "CHECKLIST", id, x.Code, ct); await tx.CommitAsync(ct); return Ok(new { id });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { await tx.RollbackAsync(ct); return Conflict(new { message = "รหัส Checklist ซ้ำ", description = "เปลี่ยนรหัสให้ไม่ซ้ำในบริษัท" }); }
        catch { await tx.RollbackAsync(ct); throw; }
    }

    [HttpPut("checklists/{id:long}")]
    public async Task<IActionResult> EditChecklist(long id, ChecklistInput x, CancellationToken ct)
    {
        if (!ValidChecklist(x)) return Invalid("กรุณากรอกรหัส ชื่อ ประเภทงาน และรายการตรวจอย่างน้อยหนึ่งข้อ");
        await using var db = await Open(ct); if (await Guard(db, "56005", "EDIT", ct) is { } denied) return denied;
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDPCRouteCheckpoint WHERE CompanyID=@co AND ChecklistTemplateID=@id", ct, ("@co", Company), ("@id", id)) > 0) return Conflict(new { message = "Checklist ถูกใช้อยู่ในเส้นทาง", description = "สร้าง Checklist ฉบับใหม่แทน เพื่อไม่เปลี่ยนเกณฑ์ที่ใช้กับแผนตรวจเดิม" });
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            var changed = await PatrolDb.Execute(db, tx, "UPDATE dbo.TDPCChecklistTemplate SET TemplateCode=@code,TemplateName=@name,WorkType=@work,IsActive=@active WHERE CompanyID=@co AND TemplateID=@id", ct, ("@co", Company), ("@id", id), ("@code", x.Code.Trim()), ("@name", x.Name.Trim()), ("@work", x.WorkType), ("@active", x.Active));
            if (changed == 0) return NotFound(new { message = "ไม่พบ Checklist", description = "โหลดรายการใหม่แล้วลองอีกครั้ง" });
            await PatrolDb.Execute(db, tx, "DELETE dbo.TDPCChecklistItem WHERE CompanyID=@co AND TemplateID=@id", ct, ("@co", Company), ("@id", id));
            for (var i = 0; i < x.Items.Count; i++) await PatrolDb.Execute(db, tx, "INSERT dbo.TDPCChecklistItem(CompanyID,TemplateID,SequenceNo,ItemText,ResponseType,IsRequired) VALUES(@co,@id,@seq,@text,N'PASS_FAIL',1)", ct, ("@co", Company), ("@id", id), ("@seq", i + 1), ("@text", x.Items[i].Trim()));
            await Audit(db, tx, "EDIT", "CHECKLIST", id, x.Code, ct); await tx.CommitAsync(ct); return Ok(new { saved = true });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { await tx.RollbackAsync(ct); return Conflict(new { message = "รหัส Checklist ซ้ำ", description = "เปลี่ยนรหัสให้ไม่ซ้ำในบริษัท" }); }
        catch { await tx.RollbackAsync(ct); throw; }
    }

    [HttpDelete("checklists/{id:long}")]
    public async Task<IActionResult> DeleteChecklist(long id, CancellationToken ct)
    {
        await using var db = await Open(ct); if (await Guard(db, "56005", "DELETE", ct) is { } denied) return denied;
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDPCRouteCheckpoint WHERE CompanyID=@co AND ChecklistTemplateID=@id", ct, ("@co", Company), ("@id", id)) > 0) return Conflict(new { message = "Checklist ยังถูกใช้งาน", description = "นำ Checklist ออกจากเส้นทางที่อ้างอิงก่อน" });
        var changed = await PatrolDb.Execute(db, null, "UPDATE dbo.TDPCChecklistTemplate SET IsActive=0 WHERE CompanyID=@co AND TemplateID=@id AND IsActive=1", ct, ("@co", Company), ("@id", id));
        if (changed == 0) return NotFound(new { message = "ไม่พบ Checklist", description = "โหลดรายการใหม่แล้วลองอีกครั้ง" });
        await Audit(db, null, "DEACTIVATE", "CHECKLIST", id, null, ct); return Ok(new { deactivated = true });
    }

    private bool ValidCheckpoint(CheckpointInput x) => !string.IsNullOrWhiteSpace(x.Code) && x.Code.Length <= 30 && !string.IsNullOrWhiteSpace(x.Name) && x.Name.Length <= 150 && x.TimeMode is "TIME_WINDOW" or "ANYTIME_IN_RUN" && x.Methods is { Count: > 0 } && (!x.RequireGps || x.Latitude is not null && x.Longitude is not null && x.GpsRadius is not null) && x.Latitude is not (< -90 or > 90) && x.Longitude is not (< -180 or > 180) && x.GpsRadius is not (< 5 or > 5000);
    private static bool ValidDevice(DeviceInput x) => !string.IsNullOrWhiteSpace(x.Code) && x.Code.Length <= 50 && !string.IsNullOrWhiteSpace(x.Name) && x.Name.Length <= 150 && x.Adapter.Trim().ToUpperInvariant() is "SIMULATOR" or "CARD" or "BIOMETRIC";
    private static bool ValidCredential(CredentialInput x) => !string.IsNullOrWhiteSpace(x.Reference) && x.Reference.Length <= 300 && x.Type is "CARD" or "QR" or "NFC" or "FINGERPRINT" or "FACE";
    private static bool ValidChecklist(ChecklistInput x) => !string.IsNullOrWhiteSpace(x.Code) && x.Code.Length <= 30 && !string.IsNullOrWhiteSpace(x.Name) && x.Name.Length <= 150 && x.WorkType is "SECURITY" or "HOUSEKEEPING" && x.Items is { Count: > 0 } && x.Items.All(i => !string.IsNullOrWhiteSpace(i) && i.Length <= 300);
    private async Task<bool> ValidCheckpointLocation(SqlConnection db, CheckpointInput x, CancellationToken ct)
    {
        if (x.BuildingId is null) return x.FloorId is null && x.RoomId is null;
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDADBuilding WHERE CompanyID=@co AND BranchID=@branch AND BuildingID=@id AND IsActive=1", ct, ("@co", Company), ("@branch", x.BranchId), ("@id", x.BuildingId)) == 0) return false;
        if (x.FloorId is null) return x.RoomId is null;
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDADFloor F JOIN dbo.TDADBuilding B ON B.CompanyID=@co AND B.BuildingID=F.BuildingID WHERE F.BuildingID=@building AND F.FloorID=@id AND F.IsActive=1", ct, ("@building", x.BuildingId), ("@id", x.FloorId), ("@co", Company)) == 0) return false;
        return x.RoomId is null || await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDADRoom WHERE CompanyID=@co AND BuildingID=@building AND FloorID=@floor AND RoomID=@id AND IsActive=1", ct, ("@co", Company), ("@building", x.BuildingId), ("@floor", x.FloorId), ("@id", x.RoomId)) > 0;
    }
    private async Task<bool> ValidCheckpointReference(SqlConnection db, long? id, CancellationToken ct) => id is null || await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDPCCheckpoint WHERE CompanyID=@co AND CheckpointID=@id AND IsActive=1", ct, ("@co", Company), ("@id", id)) > 0;
    private async Task<bool> ValidEmployeeAndDevice(SqlConnection db, long employee, long? device, CancellationToken ct)
    {
        if (await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDADEmployee WHERE CompanyID=@co AND EmployeeID=@id AND IsActive=1", ct, ("@co", Company), ("@id", employee)) == 0) return false;
        return device is null || await PatrolDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDPCDevice WHERE CompanyID=@co AND DeviceID=@id AND IsActive=1", ct, ("@co", Company), ("@id", device)) > 0;
    }
    private async Task<long> InsertCheckpoint(SqlConnection db, SqlTransaction? tx, CheckpointInput x, CancellationToken ct) => await PatrolDb.Id(db, tx, "INSERT dbo.TDPCCheckpoint(CompanyID,BranchID,BuildingID,FloorID,RoomID,CheckpointCode,CheckpointName,TimeMode,Latitude,Longitude,GpsRadiusMeters,RequireGps,RequirePhoto,RequireChecklist,AllowedMethods) OUTPUT INSERTED.CheckpointID VALUES(@co,@branch,@building,@floor,@room,@code,@name,@mode,@lat,@lng,@radius,@gps,@photo,@list,@methods)", ct, ("@co", Company), ("@branch", x.BranchId), ("@building", x.BuildingId), ("@floor", x.FloorId), ("@room", x.RoomId), ("@code", x.Code.Trim()), ("@name", x.Name.Trim()), ("@mode", x.TimeMode), ("@lat", x.Latitude), ("@lng", x.Longitude), ("@radius", x.GpsRadius), ("@gps", x.RequireGps), ("@photo", x.RequirePhoto), ("@list", x.RequireChecklist), ("@methods", string.Join(',', x.Methods.Distinct())));
    private async Task<long> InsertChecklist(SqlConnection db, SqlTransaction tx, ChecklistInput x, CancellationToken ct)
    {
        var id = await PatrolDb.Id(db, tx, "INSERT dbo.TDPCChecklistTemplate(CompanyID,TemplateCode,TemplateName,WorkType) OUTPUT INSERTED.TemplateID VALUES(@co,@code,@name,@type)", ct, ("@co", Company), ("@code", x.Code.Trim()), ("@name", x.Name.Trim()), ("@type", x.WorkType));
        for (var i = 0; i < x.Items.Count; i++) await PatrolDb.Execute(db, tx, "INSERT dbo.TDPCChecklistItem(CompanyID,TemplateID,SequenceNo,ItemText,ResponseType,IsRequired) VALUES(@co,@id,@seq,@text,N'PASS_FAIL',1)", ct, ("@co", Company), ("@id", id), ("@seq", i + 1), ("@text", x.Items[i].Trim()));
        return id;
    }
    private async Task<IActionResult> SaveCredential(SqlConnection db, SqlTransaction? tx, CredentialInput x, long? id, string action, CancellationToken ct)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(x.Reference.Trim()));
        try
        {
            if (id is null) id = await PatrolDb.Id(db, tx, "INSERT dbo.TDPCCredential(CompanyID,EmployeeID,CredentialType,CredentialRefHash,CredentialHint,DeviceID) OUTPUT INSERTED.CredentialID VALUES(@co,@employee,@type,@hash,@hint,@device)", ct, ("@co", Company), ("@employee", x.EmployeeId), ("@type", x.Type), ("@hash", hash), ("@hint", x.Hint), ("@device", x.DeviceId));
            else if (await PatrolDb.Execute(db, tx, "UPDATE dbo.TDPCCredential SET EmployeeID=@employee,CredentialType=@type,CredentialRefHash=@hash,CredentialHint=@hint,DeviceID=@device,RevokedAt=NULL,IsActive=1 WHERE CompanyID=@co AND CredentialID=@id", ct, ("@co", Company), ("@id", id), ("@employee", x.EmployeeId), ("@type", x.Type), ("@hash", hash), ("@hint", x.Hint), ("@device", x.DeviceId)) == 0) return NotFound(new { message = "ไม่พบข้อมูลบัตร", description = "โหลดรายการใหม่แล้วลองอีกครั้ง" });
            await Audit(db, tx, action, "CREDENTIAL", id.Value, x.Type, ct); return Ok(new { id, saved = true });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { return Conflict(new { message = "ข้อมูลบัตรซ้ำ", description = "ข้อมูลอ้างอิงนี้ลงทะเบียนอยู่แล้วในบริษัท" }); }
    }
}
