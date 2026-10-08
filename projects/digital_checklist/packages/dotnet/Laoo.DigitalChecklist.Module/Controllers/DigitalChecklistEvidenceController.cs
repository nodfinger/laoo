using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;
namespace Laoo.DigitalChecklist.Controllers;
public sealed partial class DigitalChecklistController
{
    [HttpGet("approver-directory")]
    public async Task<IActionResult> ApproverDirectory(CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "58004", "VIEW", ct) is { } denied) return denied;
        return Ok(await DigitalChecklistDb.Rows(db, "SELECT U.UserID id,E.FullName name,E.EmployeeCode code,O.NameTH department FROM dbo.TDADUserEmployee U JOIN dbo.TDADEmployee E ON E.CompanyID=U.CompanyID AND E.EmployeeID=U.EmployeeID JOIN dbo.TDADEmployeeOrganizationAssignment A ON A.CompanyID=E.CompanyID AND A.EmployeeID=E.EmployeeID AND A.IsActive=1 AND A.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (A.EffectiveTo IS NULL OR A.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())) JOIN dbo.TDADOrganizationUnit O ON O.CompanyID=A.CompanyID AND O.OrgUnitID=A.DepartmentOrgUnitID AND O.UnitType=N'DEP' AND O.IsActive=1 WHERE U.CompanyID=@co AND U.IsActive=1 AND E.IsActive=1 GROUP BY U.UserID,E.FullName,E.EmployeeCode,O.NameTH ORDER BY E.FullName", ct, ("@co", Company)));
    }

    [HttpGet("notifications")]
    public async Task<IActionResult> Notifications(CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "58006", "VIEW", ct) is { } denied) return denied;
        return Ok(await DigitalChecklistDb.Rows(db, "SELECT TOP(30) N.NotificationID id,N.NoticeCode code,N.Message message,N.CreatedAt createdAt,N.SentAt sentAt FROM dbo.TDCLNotification N WHERE N.CompanyID=@co AND N.UserID=@user AND (NOT EXISTS(SELECT 1 FROM dbo.TDCLSetting WHERE CompanyID=@co) OR EXISTS(SELECT 1 FROM dbo.TDCLSetting WHERE CompanyID=@co AND NotifyInApp=1)) ORDER BY N.CreatedAt DESC", ct, ("@co", Company), ("@user", Actor)));
    }

    [HttpGet("inspections/{inspectionId:long}/items")]
    public async Task<IActionResult> InspectionItems(long inspectionId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "58006", "VIEW", ct) is { } denied) return denied;
        var department = await Department(db, ct);
        var admin = await Admin(db, ct);
        var rows = await DigitalChecklistDb.Rows(db, "SELECT X.InspectionItemID id,X.TemplateItemID templateItemId,X.ResultCode resultCode,X.Detail detail,A.AttachmentID attachmentId,A.ContentType contentType,A.ByteSize size FROM dbo.TDCLInspection I JOIN dbo.TDCLInspectionItem X ON X.CompanyID=I.CompanyID AND X.InspectionID=I.InspectionID AND X.VersionNo=I.VersionNo LEFT JOIN dbo.TDCLAttachment A ON A.CompanyID=X.CompanyID AND A.InspectionItemID=X.InspectionItemID WHERE I.CompanyID=@co AND I.InspectionID=@id AND (@admin=1 OR I.DepartmentOrgUnitID=@dep OR EXISTS(SELECT 1 FROM dbo.TDCLApproval P WHERE P.CompanyID=I.CompanyID AND P.InspectionID=I.InspectionID AND P.VersionNo=I.VersionNo AND P.ApproverUserID=@user)) ORDER BY X.InspectionItemID", ct, ("@co", Company), ("@id", inspectionId), ("@admin", admin), ("@dep", department), ("@user", Actor));
        return rows.Count == 0 ? NotFound() : Ok(rows);
    }

    [HttpPost("inspections/{inspectionId:long}/items/{itemId:long}/evidence")]
    [RequestSizeLimit(10485760)]
    public async Task<IActionResult> UploadEvidence(long inspectionId, long itemId, IFormFile file, CancellationToken ct)
    {
        if (file is null || file.Length is <= 0 or > 10485760) return BadRequest(new { message = "ไฟล์ภาพต้องมีขนาดไม่เกิน 10 MB" });
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant(); if (ext is not (".jpg" or ".jpeg" or ".png" or ".webp")) return BadRequest(new { message = "รองรับเฉพาะ JPG, PNG และ WebP" });
        await using var d = await Open(ct); if (await Guard(d, "58006", "CREATE", ct) is { } denied) return denied;
        var dep = await Department(d, ct); var admin = await Admin(d, ct);
        var allowed = await DigitalChecklistDb.Id(d, "SELECT COUNT(*) FROM dbo.TDCLInspection I JOIN dbo.TDCLInspectionItem X ON X.CompanyID=I.CompanyID AND X.InspectionID=I.InspectionID AND X.VersionNo=I.VersionNo WHERE I.CompanyID=@co AND I.InspectionID=@inspection AND X.InspectionItemID=@item AND (I.StatusCode IN('DUE','OVERDUE','RETURNED','IN_PROGRESS') OR (I.StatusCode='IN_APPROVAL' AND NOT EXISTS(SELECT 1 FROM dbo.TDCLApproval P WHERE P.CompanyID=I.CompanyID AND P.InspectionID=I.InspectionID AND P.VersionNo=I.VersionNo AND P.StatusCode='APPROVED'))) AND (@admin=1 OR I.DepartmentOrgUnitID=@dep) AND (I.CreatedBy=@actor OR @admin=1)", ct, ("@co", Company), ("@inspection", inspectionId), ("@item", itemId), ("@admin", admin), ("@dep", dep), ("@actor", Actor));
        if (allowed == 0) return Forbid(); var root = Path.GetFullPath(Path.Combine(environment.ContentRootPath, "App_Data", "uploads", "digital-checklist", Company.ToString(), inspectionId.ToString())); Directory.CreateDirectory(root); var name = Guid.NewGuid().ToString("N") + ext; var path = Path.Combine(root, name); string mime;
        await using (var input = file.OpenReadStream()) { var head = new byte[12]; var read = await input.ReadAsync(head, ct); mime = ext switch { ".jpg" or ".jpeg" => read >= 3 && head[0] == 0xff && head[1] == 0xd8 && head[2] == 0xff ? "image/jpeg" : "", ".png" => read >= 8 && head.Take(8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }) ? "image/png" : "", _ => read >= 12 && head[0] == 0x52 && head[1] == 0x49 && head[2] == 0x46 && head[3] == 0x46 && head[8] == 0x57 && head[9] == 0x45 && head[10] == 0x42 && head[11] == 0x50 ? "image/webp" : "" }; if (mime.Length == 0) return BadRequest(new { message = "เนื้อหาไฟล์ไม่ตรงกับชนิดภาพ" }); }
        try { await using (var output = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, FileOptions.Asynchronous | FileOptions.SequentialScan)) { await file.CopyToAsync(output, ct); } string hash; await using (var stored = System.IO.File.OpenRead(path)) { hash = Convert.ToHexString(await SHA256.HashDataAsync(stored, ct)); } var relative = Path.GetRelativePath(environment.ContentRootPath, path); var id = await DigitalChecklistDb.Id(d, "INSERT dbo.TDCLAttachment(CompanyID,InspectionID,InspectionItemID,StoragePath,ContentType,ByteSize,Sha256,CreatedBy) OUTPUT INSERTED.AttachmentID VALUES(@co,@inspection,@item,@path,@mime,@size,@hash,@actor)", ct, ("@co", Company), ("@inspection", inspectionId), ("@item", itemId), ("@path", relative), ("@mime", mime), ("@size", file.Length), ("@hash", hash), ("@actor", Actor)); return Ok(new { attachmentId = id, contentType = mime, size = file.Length }); }
        catch { if (System.IO.File.Exists(path)) System.IO.File.Delete(path); throw; }
    }
    [HttpGet("evidence/{attachmentId:long}")]
    public async Task<IActionResult> Evidence(long attachmentId, CancellationToken ct) { await using var d = await Open(ct); if (await Guard(d, "58006", "VIEW", ct) is { } denied) return denied; var dep = await Department(d, ct); var admin = await Admin(d, ct); var rows = await DigitalChecklistDb.Rows(d, "SELECT A.StoragePath,A.ContentType,I.DepartmentOrgUnitID,I.CreatedBy FROM dbo.TDCLAttachment A JOIN dbo.TDCLInspection I ON I.CompanyID=A.CompanyID AND I.InspectionID=A.InspectionID WHERE A.CompanyID=@co AND A.AttachmentID=@id AND (@admin=1 OR I.DepartmentOrgUnitID=@dep OR EXISTS(SELECT 1 FROM dbo.TDCLApproval P WHERE P.CompanyID=I.CompanyID AND P.InspectionID=I.InspectionID AND P.ApproverUserID=@user))", ct, ("@co", Company), ("@id", attachmentId), ("@admin", admin), ("@dep", dep), ("@user", Actor)); if (rows.Count == 0) return NotFound(); var root = Path.GetFullPath(Path.Combine(environment.ContentRootPath, "App_Data", "uploads", "digital-checklist")); var path = Path.GetFullPath(Path.Combine(environment.ContentRootPath, Convert.ToString(rows[0]["StoragePath"])!)); if (!path.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || !System.IO.File.Exists(path)) return NotFound(); return PhysicalFile(path, Convert.ToString(rows[0]["ContentType"])!, enableRangeProcessing: true); }
}
