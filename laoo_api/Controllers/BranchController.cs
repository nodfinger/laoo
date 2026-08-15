using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Route("api/support/branches"), Route("api/partner/branches"), Authorize]
public sealed class BranchController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "06002";
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] string? search, [FromQuery] long? companyId, CancellationToken token)
    {
        if (!IsSupport() && !IsPartner()) return Forbid();
        await using var c = await Open(token);
        if (IsPartner() && !await Allowed(c, "VIEW", token)) return Forbid();
        const string sql = "SELECT B.BranchID,B.CompanyID,C.CompanyNameTH,B.BranchCode,B.BranchNameTH,B.BranchNameEN,B.Email,B.Telephone,B.AddressText,B.ContName,B.ContPhone,B.ContPositionName,B.IsActive FROM dbo.TDADBranch B INNER JOIN dbo.TDADCompany C ON C.CompanyID=B.CompanyID WHERE (@q='' OR B.BranchCode LIKE @like OR B.BranchNameTH LIKE @like OR B.BranchNameEN LIKE @like) AND (@companyId IS NULL OR B.CompanyID=@companyId) AND (@partnerId IS NULL OR C.PartnerID=@partnerId) ORDER BY B.BranchCode";
        await using var cmd = new SqlCommand(sql, c); cmd.Parameters.AddWithValue("@q", search?.Trim() ?? string.Empty); cmd.Parameters.AddWithValue("@like", $"%{search?.Trim() ?? string.Empty}%"); cmd.Parameters.Add("@companyId", SqlDbType.BigInt).Value = companyId ?? (object)DBNull.Value; cmd.Parameters.Add("@partnerId", SqlDbType.BigInt).Value = IsPartner() && long.TryParse(User.FindFirstValue("partner_id"), out var partnerId) ? partnerId : DBNull.Value;
        await using var r = await cmd.ExecuteReaderAsync(token); var result = new List<object>();
        while (await r.ReadAsync(token)) result.Add(new { branchId=r.GetInt64(0), companyId=r.GetInt64(1), companyName=r.GetString(2), branchCode=r.GetString(3), branchNameTh=r.GetString(4), branchNameEn=N(r,5), email=N(r,6), telephone=N(r,7), addressText=N(r,8), contName=N(r,9), contPhone=N(r,10), contPositionName=N(r,11), isActive=r.GetBoolean(12) });
        return Ok(result);
    }

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        return Ok(new
        {
            view = IsSupport() || await Allowed(c, "VIEW", token),
            create = IsSupport() || await Allowed(c, "CREATE", token),
            edit = IsSupport() || await Allowed(c, "EDIT", token),
            delete = IsSupport() || await Allowed(c, "DELETE", token),
        });
    }

    [HttpPost]
    public async Task<IActionResult> Create(BranchRequest request, CancellationToken token) => await Save(null, request, token);
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, BranchRequest request, CancellationToken token) => await Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        if (!IsSupport() && !IsPartner()) return Forbid();
        await using var c = await Open(token);
        if (IsPartner() && !await Allowed(c, "DELETE", token)) return Forbid();
        if (IsPartner())
        {
            await using var access = new SqlCommand("SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADBranch B INNER JOIN dbo.TDADCompany C ON C.CompanyID=B.CompanyID WHERE B.BranchID=@id AND C.PartnerID=@partnerId) THEN 1 ELSE 0 END", c);
            access.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
            access.Parameters.Add("@partnerId", SqlDbType.BigInt).Value = long.TryParse(User.FindFirstValue("partner_id"), out var partnerId) ? partnerId : 0;
            if (Convert.ToInt32(await access.ExecuteScalarAsync(token)) != 1) return Forbid();
        }
        await using var check = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUserBranch WHERE BranchID=@id) THEN 1 ELSE 0 END", c); check.Parameters.AddWithValue("@id", id);
        if (Convert.ToInt32(await check.ExecuteScalarAsync(token)) == 1) return Conflict(new { message="ไม่สามารถลบสาขาที่มีผู้ใช้งานผูกอยู่ได้" });
        await using var cmd = new SqlCommand("DELETE FROM dbo.TDADBranch WHERE BranchID=@id", c); cmd.Parameters.AddWithValue("@id", id); return await cmd.ExecuteNonQueryAsync(token) == 0 ? NotFound() : NoContent();
    }

    private async Task<IActionResult> Save(long? id, BranchRequest x, CancellationToken token)
    {
        if (!IsSupport() && !IsPartner()) return Forbid();
        if (x.CompanyId <= 0 || string.IsNullOrWhiteSpace(x.BranchCode) || string.IsNullOrWhiteSpace(x.BranchNameTh)) return BadRequest(new { message="กรุณากรอกผู้ใช้บริการ รหัสสาขา และชื่อสาขา" });
        await using var c = await Open(token);
        if (IsPartner() && !await Allowed(c, id is null ? "CREATE" : "EDIT", token)) return Forbid();
        if (IsPartner())
        {
            await using var access = new SqlCommand("SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADCompany WHERE CompanyID=@company AND PartnerID=@partnerId) THEN 1 ELSE 0 END", c);
            access.Parameters.Add("@company", SqlDbType.BigInt).Value = x.CompanyId;
            access.Parameters.Add("@partnerId", SqlDbType.BigInt).Value = long.TryParse(User.FindFirstValue("partner_id"), out var partnerId) ? partnerId : 0;
            if (Convert.ToInt32(await access.ExecuteScalarAsync(token)) != 1) return Forbid();
        }
        const string sql = "IF EXISTS(SELECT 1 FROM dbo.TDADBranch WHERE BranchCode=@code AND CompanyID=COALESCE((SELECT CompanyID FROM dbo.TDADBranch WHERE BranchID=@id),@company) AND (@id IS NULL OR BranchID<>@id)) THROW 50001, 'รหัสสาขาซ้ำ', 1; IF @id IS NULL INSERT dbo.TDADBranch(CompanyID,BranchCode,BranchNameTH,BranchNameEN,Email,Telephone,AddressText,ContName,ContPhone,ContPositionName,IsActive,CreateDate) VALUES(@company,@code,@th,@en,@email,@tel,@address,@contName,@contPhone,@contPosition,@active,SYSUTCDATETIME()); ELSE UPDATE dbo.TDADBranch SET BranchCode=@code,BranchNameTH=@th,BranchNameEN=@en,Email=@email,Telephone=@tel,AddressText=@address,ContName=@contName,ContPhone=@contPhone,ContPositionName=@contPosition,IsActive=@active,UpdateDate=SYSUTCDATETIME() WHERE BranchID=@id;";
        await using var cmd = new SqlCommand(sql,c); cmd.Parameters.AddWithValue("@company",x.CompanyId); cmd.Parameters.AddWithValue("@code",x.BranchCode.Trim()); cmd.Parameters.AddWithValue("@th",x.BranchNameTh.Trim()); Add(cmd,"@en",x.BranchNameEn); Add(cmd,"@email",x.Email); Add(cmd,"@tel",x.Telephone); Add(cmd,"@address",x.AddressText); Add(cmd,"@contName",x.ContName); Add(cmd,"@contPhone",x.ContPhone); Add(cmd,"@contPosition",x.ContPositionName); cmd.Parameters.AddWithValue("@active",x.IsActive); cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id??(object)DBNull.Value;
        try { await cmd.ExecuteNonQueryAsync(token); }
        catch (SqlException ex) when (ex.Number == 547) { return Conflict(new { message = "ไม่สามารถแก้ไขสาขาได้ เนื่องจากมีข้อมูลอื่นอ้างอิงอยู่" }); }
        return NoContent();
    }
    private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private static string? N(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i);
    private static void Add(SqlCommand c,string n,string? v)=>c.Parameters.Add(n,SqlDbType.NVarChar,200).Value=(object?)v?.Trim()??DBNull.Value;
    private bool IsSupport() => string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase);
    private bool IsPartner() => string.Equals(User.FindFirstValue("user_type"), "PARTNER_USER", StringComparison.OrdinalIgnoreCase);

    private async Task<bool> Allowed(SqlConnection connection, string action, CancellationToken token)
    {
        var partnerId = long.TryParse(User.FindFirstValue("partner_id"), out var parsedPartner) ? parsedPartner : 0;
        var projectId = long.TryParse(User.FindFirstValue("project_id"), out var parsedProject) ? parsedProject : 0;
        if (partnerId == 0 || projectId == 0) return false;
        const string sql = "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADPartnerUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID INNER JOIN dbo.TDADPartnerUser U ON U.PartnerUserID=UP.PartnerUserID WHERE U.PartnerID=@PartnerID AND U.NormalizedUsername=@Username AND U.IsActive=1 AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@ScreenCode AND P.ActionCode=@Action) OR EXISTS (SELECT 1 FROM dbo.TDADPartnerUser U INNER JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.PartnerUserID=U.PartnerUserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=PUE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='P' AND RG.PartnerID=U.PartnerID AND RG.ProjectID=@ProjectID INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@ProjectID AND RP.MenuCode=@ScreenCode AND RP.ActionCode=@Action AND RP.IsAllowed=1 WHERE U.PartnerID=@PartnerID AND U.NormalizedUsername=@Username AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId;
        command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
        command.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = (User.Identity?.Name ?? User.FindFirstValue("unique_name") ?? string.Empty).Trim().ToUpperInvariant();
        command.Parameters.Add("@ScreenCode", SqlDbType.NVarChar, 100).Value = ScreenCode;
        command.Parameters.Add("@Action", SqlDbType.NVarChar, 50).Value = action;
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }
}
public sealed record BranchRequest(long CompanyId,string BranchCode,string BranchNameTh,string? BranchNameEn,string? Email,string? Telephone,string? AddressText,string? ContName,string? ContPhone,string? ContPositionName,bool IsActive=true);
