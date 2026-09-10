using System.Data;
using System.Text.Json;
using LaooApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

public sealed partial class ItemController
{
    private const string EnabledItemProjects = """
SELECT P.ProjectID,P.ProjectCode,P.ProjectNameTH
FROM dbo.TDADProject P
WHERE P.IsActive=1 AND EXISTS (
 SELECT 1 FROM dbo.TDADCompanyProject CP
 JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=CP.CompanyID AND C.PartnerID=CP.PartnerID AND C.IsActive=1
 WHERE CP.ProjectID=P.ProjectID AND CP.CompanyID=@company AND CP.IsEnabled=1
 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
""";

    [HttpGet("project-options")]
    public async Task<IActionResult> ProjectOptions(CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "VIEW", token)) return ProjectDenied();
        await using var cmd = new SqlCommand(EnabledItemProjects + " ORDER BY P.ProjectID", c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
        await using var r = await cmd.ExecuteReaderAsync(token);
        var rows = new List<object>();
        while (await r.ReadAsync(token)) rows.Add(new { projectId = r.GetInt64(0), projectCode = r.GetString(1), projectName = r.GetString(2) });
        return Ok(rows);
    }

    private ObjectResult ProjectDenied() => StatusCode(403, new {
        message = "ไม่สามารถจัดการการใช้งานสินค้าได้",
        description = "กรุณาตรวจสอบสิทธิ์เมนูสินค้าและ Project ของบริษัท" });

    private async Task<ItemProjectAccess> ReadProjectAccess(SqlConnection c, long id, CancellationToken token)
    {
        await using var cmd = new SqlCommand("""
SELECT AccessModeCode FROM dbo.TDIVItemProjectPolicy WHERE CompanyID=@company AND ItemID=@id;
SELECT ProjectID FROM dbo.TDIVItemProject WHERE CompanyID=@company AND ItemID=@id ORDER BY ProjectID;
""", c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@id", SqlDbType.BigInt, id);
        await using var r = await cmd.ExecuteReaderAsync(token);
        var mode = await r.ReadAsync(token) ? r.GetString(0) : "ALL";
        await r.NextResultAsync(token);
        var ids = new List<long>();
        while (await r.ReadAsync(token)) ids.Add(r.GetInt64(0));
        return new(mode, ids);
    }

    private async Task<string?> ValidateProjectAccess(SqlConnection c, SqlTransaction tx, ItemProjectAccess access, CancellationToken token)
    {
        if (access.AccessModeCode is not ("ALL" or "SELECTED") || access.ProjectIds is null)
            return "กรุณาเลือกทุก Project หรือเฉพาะ Project และระบุรายการ Project";
        if (access.ProjectIds.Count > 100 || access.ProjectIds.Any(id => id <= 0) || access.ProjectIds.Distinct().Count() != access.ProjectIds.Count)
            return "รายการ Project ไม่ถูกต้องหรือซ้ำกัน";
        if (access.AccessModeCode == "ALL" && access.ProjectIds.Count != 0)
            return "โหมดทุก Project ต้องไม่มีรายการเฉพาะ Project";
        if (access.AccessModeCode == "SELECTED" && access.ProjectIds.Count == 0)
            return "กรุณาเลือก Project อย่างน้อยหนึ่งรายการ";
        await using var cmd = new SqlCommand(EnabledItemProjects, c, tx);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
        await using var r = await cmd.ExecuteReaderAsync(token);
        var enabled = new HashSet<long>();
        while (await r.ReadAsync(token)) enabled.Add(r.GetInt64(0));
        return access.ProjectIds.All(enabled.Contains) ? null : "มี Project ที่บริษัทไม่ได้เปิดใช้หรือหมดอายุ กรุณาโหลดรายการใหม่";
    }

    private async Task SaveProjectAccess(SqlConnection c, SqlTransaction tx, long id, ItemProjectAccess access, CancellationToken token)
    {
        await using var cmd = new SqlCommand("""
UPDATE dbo.TDIVItemProjectPolicy WITH (UPDLOCK,SERIALIZABLE)
SET AccessModeCode=@mode,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE CompanyID=@company AND ItemID=@id;
IF @@ROWCOUNT=0 INSERT dbo.TDIVItemProjectPolicy(CompanyID,ItemID,AccessModeCode,UpdatedBy) VALUES(@company,@id,@mode,@user);
DELETE FROM dbo.TDIVItemProject WHERE CompanyID=@company AND ItemID=@id;
INSERT dbo.TDIVItemProject(CompanyID,ItemID,ProjectID)
SELECT @company,@id,CONVERT(bigint,value) FROM OPENJSON(@ids);
""", c, tx);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@id", SqlDbType.BigInt, id);
        Add(cmd, "@mode", SqlDbType.NVarChar, access.AccessModeCode, 20); Add(cmd, "@user", SqlDbType.BigInt, UserId());
        Add(cmd, "@ids", SqlDbType.NVarChar, JsonSerializer.Serialize(access.ProjectIds), -1);
        await cmd.ExecuteNonQueryAsync(token);
    }

    [HttpGet("classification-defaults")]
    public async Task<IActionResult> ClassificationDefaults([FromQuery] string? groupCode, [FromQuery] string? typeCode, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "VIEW", token)) return ProjectDenied();
        await using var cmd = new SqlCommand("""
SELECT TOP(1) ScopeCode,ClassificationCode,ItemKindCode,StockTrackingCode,UsageCodesJson
FROM dbo.TDIVItemClassificationDefault WHERE CompanyID=@company
AND ((ScopeCode='TYPE' AND ClassificationCode=@type) OR (ScopeCode='GROUP' AND ClassificationCode=@group))
ORDER BY CASE ScopeCode WHEN 'TYPE' THEN 0 ELSE 1 END;
""", c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
        Add(cmd, "@group", SqlDbType.NVarChar, groupCode?.Trim() ?? "", 50); Add(cmd, "@type", SqlDbType.NVarChar, typeCode?.Trim() ?? "", 50);
        await using var r = await cmd.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return Ok(new { found = false });
        return Ok(new { found = true, scopeCode = r.GetString(0), classificationCode = r.GetString(1), itemKindCode = r.GetString(2), stockTrackingCode = r.GetString(3), usageCodes = JsonSerializer.Deserialize<string[]>(r.GetString(4)) });
    }

    [HttpPut("classification-defaults")]
    public async Task<IActionResult> SaveClassificationDefaults(ItemClassificationDefault request, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "EDIT", token)) return ProjectDenied();
        request = request with { ItemKindCode = request.ItemKindCode?.Trim().ToUpperInvariant() ?? "", StockTrackingCode = request.StockTrackingCode?.Trim().ToUpperInvariant() ?? "" };
        if (request.ScopeCode is not ("GROUP" or "TYPE") || string.IsNullOrWhiteSpace(request.ClassificationCode) || request.ClassificationCode.Length > 50
            || !ItemCatalogCodes.ItemKinds.Contains(request.ItemKindCode) || !ItemCatalogCodes.StockTracking.Contains(request.StockTrackingCode)
            || (request.ItemKindCode == "SERVICE" && request.StockTrackingCode != "NONE")
            || request.UsageCodes is null || request.UsageCodes.Count is < 1 or > 4 || request.UsageCodes.Any(x => !ItemCatalogCodes.Usages.Contains(x)))
            return BadRequest(new { message = "ค่าเริ่มต้นสินค้าไม่ถูกต้อง", description = "กรุณาเลือกกลุ่ม/ประเภท ชนิด วิธีควบคุมสต็อก และวัตถุประสงค์ให้ครบ" });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        // Match the existing item group's master source (006/007), within this Company.
        await using var valid = new SqlCommand("SELECT COUNT(*) FROM dbo.TDSTMaster WHERE OwnerType='C' AND OwnerCompanyID=@company AND MasterGroupCode=@master AND MasterCode=@code AND IsActive=1", c, tx);
        Add(valid, "@company", SqlDbType.BigInt, CompanyID()); Add(valid, "@master", SqlDbType.NVarChar, request.ScopeCode == "GROUP" ? "006" : "007", 10);
        Add(valid, "@code", SqlDbType.NVarChar, request.ClassificationCode.Trim(), 50);
        if (Convert.ToInt32(await valid.ExecuteScalarAsync(token)) == 0)
            return BadRequest(new { message = "ไม่พบกลุ่ม/ประเภทสินค้า", description = "รายการต้องเปิดใช้งานและอยู่ในบริษัทปัจจุบัน" });
        await using var cmd = new SqlCommand("""
UPDATE dbo.TDIVItemClassificationDefault WITH (UPDLOCK,SERIALIZABLE)
SET ItemKindCode=@kind,StockTrackingCode=@tracking,UsageCodesJson=@usages,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user
WHERE CompanyID=@company AND ScopeCode=@scope AND ClassificationCode=@code;
IF @@ROWCOUNT=0 INSERT dbo.TDIVItemClassificationDefault(CompanyID,ScopeCode,ClassificationCode,ItemKindCode,StockTrackingCode,UsageCodesJson,UpdatedBy)
VALUES(@company,@scope,@code,@kind,@tracking,@usages,@user);
""", c, tx);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@scope", SqlDbType.NVarChar, request.ScopeCode, 10);
        Add(cmd, "@code", SqlDbType.NVarChar, request.ClassificationCode.Trim(), 50); Add(cmd, "@kind", SqlDbType.NVarChar, request.ItemKindCode.ToUpperInvariant(), 20);
        Add(cmd, "@tracking", SqlDbType.NVarChar, request.StockTrackingCode.ToUpperInvariant(), 20);
        Add(cmd, "@usages", SqlDbType.NVarChar, JsonSerializer.Serialize(request.UsageCodes.Select(x => x.ToUpperInvariant()).Distinct()), 500);
        Add(cmd, "@user", SqlDbType.BigInt, UserId()); await cmd.ExecuteNonQueryAsync(token);
        await tx.CommitAsync(token);
        return Ok(new { message = "บันทึกค่าเริ่มต้นแล้ว ไม่มีการเปลี่ยนสินค้าเดิม" });
    }
}
