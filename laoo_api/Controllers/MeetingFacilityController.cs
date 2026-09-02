using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Route("api/company/meeting-facilities"), Authorize]
public sealed class MeetingFacilityController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "23003";

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long companyId) return Forbid();
        await using var c = await Open(token);
        if (!await Allowed(c, "VIEW", token)) return Forbid();
        const string sql = @"
SELECT F.FacilityID,F.FacilityCode,F.FacilityNameTH,F.Description,
       F.ResponsibleDepartmentOrgUnitID,D.NameTH
FROM dbo.TDADMeetingFacility F
LEFT JOIN dbo.TDADOrganizationUnit D
  ON D.OrgUnitID=F.ResponsibleDepartmentOrgUnitID
 AND D.CompanyID=F.CompanyID
 AND D.UnitType='DEP'
WHERE F.CompanyID=@company
ORDER BY F.FacilityCode";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", companyId);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        var result = new List<FacilityRow>();
        while (await reader.ReadAsync(token))
        {
            result.Add(new(reader.GetInt64(0), reader.GetString(1), reader.GetString(2), N(reader, 3), NLong(reader, 4), N(reader, 5)));
        }
        return Ok(result);
    }

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        return Ok(new { view = await Allowed(c, "VIEW", token), create = await Allowed(c, "CREATE", token), edit = await Allowed(c, "EDIT", token), delete = await Allowed(c, "DELETE", token) });
    }

    [HttpGet("departments")]
    public async Task<IActionResult> Departments(CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long companyId) return Forbid();
        await using var c = await Open(token);
        if (!await Allowed(c, "VIEW", token)) return Forbid();
        const string sql = "SELECT OrgUnitID,NameTH FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND UnitType='DEP' AND IsActive=1 ORDER BY NameTH";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", companyId);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        var result = new List<object>();
        while (await reader.ReadAsync(token)) result.Add(new { orgUnitId = reader.GetInt64(0), nameTh = reader.GetString(1) });
        return Ok(result);
    }

    [HttpPost]
    public Task<IActionResult> Create(FacilityRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, FacilityRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission("DELETE", token)) return Forbid();
        await using var c = await Open(token);
        await using var cmd = new SqlCommand("DELETE FROM dbo.TDADMeetingFacility WHERE FacilityID=@id AND CompanyID=@company", c);
        Add(cmd, "@id", id); Add(cmd, "@company", company);
        return await cmd.ExecuteNonQueryAsync(token) == 0 ? NotFound(new { message = "ไม่พบสิ่งอำนวยความสะดวกที่ต้องการลบ", description = $"FacilityID {id} ไม่อยู่ในขอบเขตบริษัทของผู้ใช้งาน" }) : NoContent();
    }

    private async Task<IActionResult> Save(long? id, FacilityRequest request, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is not long company || !await Permission(id is null ? "CREATE" : "EDIT", token)) return Forbid();
        await using var c = await Open(token);
        const string sql = @"
IF @department IS NULL OR NOT EXISTS
(
    SELECT 1 FROM dbo.TDADOrganizationUnit
    WHERE OrgUnitID=@department AND CompanyID=@company
      AND UnitType='DEP' AND IsActive=1
) THROW 50004,'INVALID_DEPARTMENT',1;
IF EXISTS
(
    SELECT 1 FROM dbo.TDADMeetingFacility
    WHERE CompanyID=@company AND FacilityCode=@code
      AND (@id IS NULL OR FacilityID<>@id)
) THROW 50003,'DUPLICATE_FACILITY',1;
IF @id IS NULL
BEGIN
    INSERT dbo.TDADMeetingFacility
    (
        CompanyID,FacilityCode,FacilityNameTH,Description,
        ResponsibleDepartmentOrgUnitID,CreateDate
    )
    VALUES
    (
        @company,@code,@name,@description,@department,SYSUTCDATETIME()
    );
    SELECT CAST(SCOPE_IDENTITY() AS BIGINT);
END
ELSE
BEGIN
    UPDATE dbo.TDADMeetingFacility
    SET FacilityCode=@code,FacilityNameTH=@name,Description=@description,
        ResponsibleDepartmentOrgUnitID=@department,UpdateDate=SYSUTCDATETIME()
    WHERE FacilityID=@id AND CompanyID=@company;
    SELECT @id;
END";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", company); Add(cmd, "@id", id); Add(cmd, "@code", request.Code.Trim().ToUpperInvariant()); Add(cmd, "@name", request.NameTh.Trim()); Add(cmd, "@description", request.Description); Add(cmd, "@department", request.ResponsibleDepartmentOrgUnitId);
        try { return Ok(new { facilityId = Convert.ToInt64(await cmd.ExecuteScalarAsync(token)) }); }
        catch (SqlException ex) when (ex.Number == 50003) { return Conflict(new { message = "รหัสสิ่งอำนวยความสะดวกซ้ำ", description = "กรุณาใช้รหัสอื่นที่ยังไม่ถูกใช้งานในบริษัทนี้" }); }
        catch (SqlException ex) when (ex.Number == 50004) { return BadRequest(new { message = "แผนกรับผิดชอบไม่ถูกต้อง", description = "กรุณาเลือกแผนกที่ยังใช้งานอยู่ภายในบริษัทของผู้ใช้" }); }
    }

    private async Task<bool> Permission(string action, CancellationToken token) { await using var c = await Open(token); return await Allowed(c, action, token); }
    private async Task<bool> Allowed(SqlConnection c, string action, CancellationToken token)
    {
        if (!IsCompany() || CompanyId() is null || !long.TryParse(User.FindFirstValue("project_id"), out var project) || !long.TryParse(User.FindFirstValue("user_id"), out var user)) return false;
        const string sql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action) THEN 1 ELSE 0 END";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@user", user); Add(cmd, "@company", CompanyId() ?? 0); Add(cmd, "@project", project); Add(cmd, "@screen", ScreenCode); Add(cmd, "@action", action);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }
    private async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private bool IsCompany() => string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase);
    private long? CompanyId() => long.TryParse(User.FindFirstValue("company_id"), out var id) && id > 0 ? id : null;
    private static string? N(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
    private static long? NLong(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetInt64(index);
    private static void Add(SqlCommand command, string name, object? value) => command.Parameters.AddWithValue(name, value ?? DBNull.Value);
}

public sealed record FacilityRequest(string Code, string NameTh, string? Description, long? ResponsibleDepartmentOrgUnitId);
public sealed record FacilityRow(long FacilityId, string Code, string NameTh, string? Description, long? ResponsibleDepartmentOrgUnitId, string? ResponsibleDepartmentName);
