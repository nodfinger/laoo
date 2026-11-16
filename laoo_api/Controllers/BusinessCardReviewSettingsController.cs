using System.Data;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/ocr/business-cards/review-settings")]
public sealed class BusinessCardReviewSettingsController(IConfiguration configuration) : ControllerBase
{
    private long Company => long.TryParse(User.FindFirst("company_id")?.Value, out var value) ? value : 0;
    private long Actor => long.TryParse(User.FindFirst("user_id")?.Value, out var value) ? value : 0;
    private async Task<SqlConnection> Open(CancellationToken token) { var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await db.OpenAsync(token); return db; }
    private async Task<bool> Allowed(SqlConnection db, string action, CancellationToken token)
    {
        if (!await CompanyMenuAccess.IsAllowedAsync(db, User, "55001", action, token)) return false;
        await using var q = new SqlCommand("SELECT ScreenType FROM dbo.TDADMainMenu WHERE MenuCode=N'55001' AND IsActive=1", db);
        return Convert.ToInt32(await q.ExecuteScalarAsync(token)) == 2;
    }

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        await using var db = await Open(token);
        if (!await Allowed(db, "VIEW", token)) return Forbid();
        await using var q = new SqlCommand("""
SELECT OrgStructureType, EmployeeNameDisplay FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND OwnerType='C' AND IsActive=1;
SELECT TargetType,ReviewMode,OrgLevel FROM dbo.TDSTBusinessCardReviewSetting WHERE CompanyID=@company;
SELECT TargetType,EmployeeID FROM dbo.TDSTBusinessCardReviewer WHERE CompanyID=@company;
SELECT e.EmployeeID,e.FullName,e.NickName,e.DepartmentOrgUnitID,d.NameTH
FROM dbo.TDADEmployee e LEFT JOIN dbo.TDADOrganizationUnit d ON d.CompanyID=e.CompanyID AND d.OrgUnitID=e.DepartmentOrgUnitID
WHERE e.CompanyID=@company AND e.IsActive=1 AND EXISTS
 (SELECT 1 FROM dbo.TDADUserEmployee ue JOIN dbo.TDADUser u ON u.UserID=ue.UserID AND u.CompanyID=ue.CompanyID AND u.IsActive=1
  WHERE ue.CompanyID=e.CompanyID AND ue.EmployeeID=e.EmployeeID AND ue.IsActive=1)
ORDER BY e.FullName,e.EmployeeID;
SELECT OrgUnitID,NameTH FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND UnitType='DEP' AND IsActive=1 ORDER BY NameTH;
""", db);
        q.Parameters.AddWithValue("@company", Company);
        await using var r = await q.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound();
        var hasDivision = !r.IsDBNull(0) && Convert.ToInt32(r.GetValue(0)) == 2;
        var display = r.IsDBNull(1) ? "FULL" : r.GetString(1).ToUpperInvariant();
        var settings = new Dictionary<string, ReviewSettingResponse> {
            ["CUSTOMER"] = new("ORG", "DEP", []), ["SUPPLIER"] = new("ORG", "DEP", []) };
        await r.NextResultAsync(token);
        while (await r.ReadAsync(token)) settings[r.GetString(0)] = new(r.GetString(1), r.GetString(2), []);
        await r.NextResultAsync(token);
        while (await r.ReadAsync(token)) if (settings.TryGetValue(r.GetString(0), out var setting)) setting.EmployeeIds.Add(r.GetInt64(1));
        var employees = new List<object>(); await r.NextResultAsync(token);
        while (await r.ReadAsync(token)) {
            var full = r.IsDBNull(1) ? "" : r.GetString(1); var nick = r.IsDBNull(2) ? "" : r.GetString(2);
            var name = display == "NICK" && nick.Length > 0 ? nick : display == "BOTH" && nick.Length > 0 ? $"{full} ({nick})" : full;
            employees.Add(new { id=r.GetInt64(0), name, departmentId=r.IsDBNull(3) ? (long?)null : r.GetInt64(3), department=r.IsDBNull(4) ? "" : r.GetString(4) });
        }
        var departments = new List<object>(); await r.NextResultAsync(token);
        while (await r.ReadAsync(token)) departments.Add(new { id=r.GetInt64(0), name=r.GetString(1) });
        return Ok(new { hasDivision, customer=settings["CUSTOMER"], supplier=settings["SUPPLIER"], employees, departments });
    }

    [HttpPut]
    public async Task<IActionResult> Save([FromBody] ReviewSettingsRequest input, CancellationToken token)
    {
        await using var db = await Open(token);
        if (!await Allowed(db, "EDIT", token)) return Forbid();
        if (input.Customer is null || input.Supplier is null) return BadRequest(new { message="ข้อมูลการตั้งค่าไม่ครบ" });
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        await using var org = new SqlCommand("SELECT OrgStructureType FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND OwnerType='C' AND IsActive=1", db, tx);
        org.Parameters.AddWithValue("@company", Company);
        var orgValue = await org.ExecuteScalarAsync(token);
        if (orgValue is null) return NotFound();
        foreach (var (target, value) in new[] { ("CUSTOMER", input.Customer), ("SUPPLIER", input.Supplier) }) {
            var ids = value.EmployeeIds ?? [];
            if (value.Mode is not ("ORG" or "EMPLOYEE") || value.Level is not ("DIV" or "DEP") || (value.Level == "DIV" && Convert.ToInt32(orgValue) != 2) || ids.Count != ids.Distinct().Count() || ids.Count > 500 || (value.Mode == "EMPLOYEE" && ids.Count == 0))
                return BadRequest(new { message="ข้อมูลผู้ตรวจสอบไม่ถูกต้อง", description="ตรวจรูปแบบองค์กรและเลือกพนักงานที่มีบัญชีเข้าใช้งาน" });
            foreach (var id in ids) {
                await using var check = new SqlCommand("SELECT COUNT(1) FROM dbo.TDADEmployee e WHERE e.EmployeeID=@id AND e.CompanyID=@company AND e.IsActive=1 AND EXISTS (SELECT 1 FROM dbo.TDADUserEmployee ue JOIN dbo.TDADUser u ON u.UserID=ue.UserID AND u.CompanyID=ue.CompanyID AND u.IsActive=1 WHERE ue.EmployeeID=e.EmployeeID AND ue.CompanyID=e.CompanyID AND ue.IsActive=1)", db, tx);
                check.Parameters.AddWithValue("@id", id); check.Parameters.AddWithValue("@company", Company);
                if (Convert.ToInt32(await check.ExecuteScalarAsync(token)) != 1) return BadRequest(new { message="พบพนักงานที่ไม่มีสิทธิ์เลือกหรือไม่ใช้งาน" });
            }
            await using var update = new SqlCommand("""
UPDATE dbo.TDSTBusinessCardReviewSetting SET ReviewMode=@mode,OrgLevel=@level,UpdateBy=@actor,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND TargetType=@target;
IF @@ROWCOUNT=0 INSERT dbo.TDSTBusinessCardReviewSetting(CompanyID,TargetType,ReviewMode,OrgLevel,UpdateBy) VALUES(@company,@target,@mode,@level,@actor);
DELETE dbo.TDSTBusinessCardReviewer WHERE CompanyID=@company AND TargetType=@target;
""", db, tx);
            update.Parameters.AddWithValue("@company", Company); update.Parameters.AddWithValue("@target", target); update.Parameters.AddWithValue("@mode", value.Mode); update.Parameters.AddWithValue("@level", value.Level); update.Parameters.AddWithValue("@actor", Actor); await update.ExecuteNonQueryAsync(token);
            foreach (var id in ids) { await using var add = new SqlCommand("INSERT dbo.TDSTBusinessCardReviewer(CompanyID,TargetType,EmployeeID) VALUES(@company,@target,@id)",db,tx); add.Parameters.AddWithValue("@company",Company);add.Parameters.AddWithValue("@target",target);add.Parameters.AddWithValue("@id",id);await add.ExecuteNonQueryAsync(token); }
        }
        await tx.CommitAsync(token); return Ok(new { message="บันทึกการตั้งค่าแล้ว" });
    }
}

public sealed record ReviewSettingResponse(string Mode, string Level, List<long> EmployeeIds);
public sealed record ReviewSettingInput(string Mode, string Level, List<long>? EmployeeIds);
public sealed record ReviewSettingsRequest(ReviewSettingInput? Customer, ReviewSettingInput? Supplier);
