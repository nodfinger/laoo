using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Route("api/support/organization-structure"), Authorize]
public sealed class OrganizationStructureController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "ORGANIZATION_STRUCTURE";

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] long? companyId, CancellationToken token)
    {
        if (IsPartner() && long.TryParse(User.FindFirstValue("partner_id"), out var partnerScope))
        {
            await using var pc = await Open(token);
            if (!await Allowed(pc, "VIEW", token)) return Forbid();
            const string partnerSql = "SELECT COALESCE(OrgStructureType,1) FROM dbo.TDSTCompanySetUp WHERE OwnerType='P' AND PartnerID=@partner; SELECT OrgUnitID,CompanyID,UnitType,ParentOrgUnitID,UnitCode,NameTH,NameEN,IsActive,CAST(NULL AS nvarchar(200)) FROM dbo.TDADOrganizationUnit WHERE OwnerType='P' AND PartnerID=@partner ORDER BY UnitType,UnitCode;";
            await using var pcmd = new SqlCommand(partnerSql, pc); pcmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = partnerScope;
            await using var pr = await pcmd.ExecuteReaderAsync(token); var pmodes = new List<int>();
            while (await pr.ReadAsync(token)) pmodes.Add(pr.GetInt32(0));
            await pr.NextResultAsync(token); var punits = new List<object>();
            while (await pr.ReadAsync(token)) punits.Add(new { orgUnitId=pr.GetInt64(0), companyId=(long?)null, unitType=pr.GetString(2), parentOrgUnitId=pr.IsDBNull(3)?(long?)null:pr.GetInt64(3), unitCode=pr.GetString(4), nameTh=pr.GetString(5), nameEn=N(pr,6), isActive=pr.GetBoolean(7), companyName=(string?)null });
            return Ok(new { orgStructureType = pmodes.Count == 1 ? pmodes[0] : 1, units = punits });
        }
        companyId = ResolveCompany(companyId);
        if (companyId is null) return Forbid();
        await using var c = await Open(token);
        if (!await Allowed(c, "VIEW", token)) return Forbid();
        const string sql = "SELECT OrgStructureType FROM dbo.TDSTCompanySetUp WHERE OwnerType='C' AND CompanyID=@companyId; SELECT U.OrgUnitID,U.CompanyID,U.UnitType,U.ParentOrgUnitID,U.UnitCode,U.NameTH,U.NameEN,U.IsActive,C.CompanyNameTH FROM dbo.TDADOrganizationUnit U INNER JOIN dbo.TDADCompany C ON C.CompanyID=U.CompanyID WHERE U.OwnerType='C' AND U.CompanyID=@companyId ORDER BY U.UnitType,U.UnitCode;";
        await using var cmd = new SqlCommand(sql, c); cmd.Parameters.Add("@companyId", SqlDbType.BigInt).Value = companyId ?? (object)DBNull.Value;
        await using var r = await cmd.ExecuteReaderAsync(token); var modes = new List<int>();
        while (await r.ReadAsync(token)) modes.Add(r.GetInt32(0));
        await r.NextResultAsync(token); var units = new List<object>();
        while (await r.ReadAsync(token)) units.Add(new { orgUnitId=r.GetInt64(0), companyId=r.GetInt64(1), unitType=r.GetString(2), parentOrgUnitId=r.IsDBNull(3)?(long?)null:r.GetInt64(3), unitCode=r.GetString(4), nameTh=r.GetString(5), nameEn=N(r,6), isActive=r.GetBoolean(7), companyName=r.GetString(8) });
        return Ok(new { orgStructureType = modes.Count == 1 ? modes[0] : 1, units });
    }

    [HttpGet("actions")]
    public async Task<ActionResult<object>> Actions(CancellationToken token)
    {
        await using var connection = await Open(token);
        return Ok(new { view = await Allowed(connection, "VIEW", token), create = await Allowed(connection, "CREATE", token), edit = await Allowed(connection, "EDIT", token), delete = await Allowed(connection, "DELETE", token) });
    }

    [HttpPost]
    public Task<IActionResult> Create(UnitRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("mode")]
    public async Task<IActionResult> UpdateMode(OrganizationModeRequest request, CancellationToken token)
    {
        if (IsPartner() && long.TryParse(User.FindFirstValue("partner_id"), out var partnerId))
        {
            if (request.OrgStructureType is not (1 or 2))
                return BadRequest(new { message = "รูปแบบโครงสร้างองค์กรไม่ถูกต้อง" });
            await using var pc = await Open(token);
            if (!await Allowed(pc, "EDIT", token)) return Forbid();
            await using var mode = new SqlCommand("UPDATE dbo.TDSTCompanySetUp SET OrgStructureType=@mode,UpdateDate=SYSUTCDATETIME() WHERE OwnerType='P' AND PartnerID=@partner", pc);
            mode.Parameters.Add("@mode", SqlDbType.Int).Value = request.OrgStructureType;
            mode.Parameters.Add("@partner", SqlDbType.BigInt).Value = partnerId;
            return await mode.ExecuteNonQueryAsync(token) == 0 ? NotFound() : NoContent();
        }
        var companyId = ResolveCompany(request.CompanyId);
        if (companyId is null || request.OrgStructureType is not (1 or 2))
            return BadRequest(new { message = "รูปแบบโครงสร้างองค์กรไม่ถูกต้อง" });
        await using var c = await Open(token);
        if (!await Allowed(c, "EDIT", token)) return Forbid();
        if (request.OrgStructureType == 1)
        {
            await using var check = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND UnitType=N'DIV') THEN 1 ELSE 0 END", c);
            check.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId.Value;
            if (Convert.ToBoolean(await check.ExecuteScalarAsync(token)))
                return Conflict(new { message = "ไม่สามารถเปลี่ยนเป็นแผนกเท่านั้นได้ เนื่องจากมีข้อมูลฝ่ายอยู่แล้ว" });
        }
        if (request.OrgStructureType == 2)
        {
            await using var check = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND UnitType=N'DEP' AND ParentOrgUnitID IS NULL) THEN 1 ELSE 0 END", c);
            check.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId.Value;
            if (Convert.ToBoolean(await check.ExecuteScalarAsync(token)))
                return Conflict(new { message = "ไม่สามารถเปลี่ยนเป็นฝ่าย > แผนกได้ เนื่องจากมีแผนกที่ยังไม่ได้กำหนดฝ่าย" });
        }
        await using var cmd = new SqlCommand("UPDATE dbo.TDADCompany SET OrgStructureType=@mode,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company", c);
        cmd.Parameters.Add("@mode", SqlDbType.Int).Value = request.OrgStructureType;
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId.Value;
        return await cmd.ExecuteNonQueryAsync(token) == 0 ? NotFound() : NoContent();
    }
    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, UnitRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, [FromQuery] long? companyId, CancellationToken token)
    {
        if (IsPartner() && long.TryParse(User.FindFirstValue("partner_id"), out var partnerId))
        {
            await using var pc = await Open(token); if (!await Allowed(pc,"DELETE",token)) return Forbid();
            await using var pdel = new SqlCommand("IF EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE ParentOrgUnitID=@id AND OwnerType='P' AND PartnerID=@partner) THROW 50001,'HAS_CHILDREN',1; DELETE dbo.TDADOrganizationUnit WHERE OrgUnitID=@id AND OwnerType='P' AND PartnerID=@partner;", pc);
            pdel.Parameters.Add("@id",SqlDbType.BigInt).Value=id; pdel.Parameters.Add("@partner",SqlDbType.BigInt).Value=partnerId;
            try { return await pdel.ExecuteNonQueryAsync(token)==0 ? NotFound() : NoContent(); } catch(SqlException ex) when(ex.Number==50001){return Conflict(new {message="ไม่สามารถลบฝ่ายที่มีแผนกย่อยได้"});}
        }
        companyId = ResolveCompany(companyId);
        if (companyId is null) return Forbid();
        await using var c = await Open(token); if (!await Allowed(c,"DELETE",token)) return Forbid();
        await using var cmd = new SqlCommand("IF EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE ParentOrgUnitID=@id AND CompanyID=@company) THROW 50001,'ORGANIZATION_UNIT_HAS_CHILDREN',1; DELETE dbo.TDADOrganizationUnit WHERE OrgUnitID=@id AND CompanyID=@company;", c); cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id; cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=companyId.Value;
        try { if (await cmd.ExecuteNonQueryAsync(token)==0) return NotFound(); } catch(SqlException ex) when(ex.Number==50001){return Conflict(new {message="ไม่สามารถลบฝ่ายที่มีแผนกย่อยได้"});} return NoContent();
    }

    private async Task<IActionResult> Save(long? id, UnitRequest x, CancellationToken token)
    {
        if (IsPartner() && long.TryParse(User.FindFirstValue("partner_id"), out var partnerId))
            return await SavePartner(id, x, partnerId, token);
        var companyId = ResolveCompany(x.CompanyId);
        var normalizedCode = x.UnitCode.Trim().ToUpperInvariant();
        if (companyId is null || (x.UnitType!="DIV" && x.UnitType!="DEP") || string.IsNullOrWhiteSpace(x.UnitCode) || string.IsNullOrWhiteSpace(x.NameTh)) return BadRequest(new {message="กรุณากรอกข้อมูลหน่วยงานให้ครบ"});
        await using var c=await Open(token); var action=id is null?"CREATE":"EDIT"; if(!await Allowed(c,action,token)) return Forbid();
        const string sql="DECLARE @mode int=(SELECT OrgStructureType FROM dbo.TDSTCompanySetUp WHERE OwnerType='C' AND CompanyID=@company); IF @mode IS NULL THROW 50002,'COMPANY_NOT_FOUND',1; IF EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND UnitType=@unitType AND LOWER(REPLACE(REPLACE(UnitCode,N' ',N''),CHAR(9),N''))=LOWER(REPLACE(REPLACE(@code,N' ',N''),CHAR(9),N'')) COLLATE Latin1_General_100_CI_AI AND (@id IS NULL OR OrgUnitID<>@id)) THROW 50007,'DUPLICATE_CODE',1; IF @code LIKE N'% %' OR @code LIKE N'%'+CHAR(9)+N'%' THROW 50008,'CODE_WHITESPACE',1; IF @unitType='DIV' AND @parent IS NOT NULL THROW 50003,'DIVISION_PARENT_INVALID',1; IF @unitType='DEP' AND @mode=1 AND @parent IS NOT NULL THROW 50004,'DEPARTMENT_PARENT_INVALID',1; IF @unitType='DEP' AND @mode=2 AND NOT EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE OrgUnitID=@parent AND CompanyID=@company AND UnitType='DIV' AND IsActive=1) THROW 50005,'DEPARTMENT_PARENT_REQUIRED',1; IF EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND UnitType=@unitType AND ISNULL(ParentOrgUnitID,0)=ISNULL(@parent,0) AND LOWER(REPLACE(REPLACE(NameTH,N' ',N''),CHAR(9),N''))=LOWER(REPLACE(REPLACE(@name,N' ',N''),CHAR(9),N'')) COLLATE Thai_100_CI_AI AND (@id IS NULL OR OrgUnitID<>@id)) THROW 50006,'DUPLICATE_NAME',1; IF @id IS NULL INSERT dbo.TDADOrganizationUnit(CompanyID,UnitType,ParentOrgUnitID,UnitCode,NameTH,NameEN,IsActive) VALUES(@company,@unitType,@parent,@code,@name,@nameEn,@active); ELSE UPDATE dbo.TDADOrganizationUnit SET UnitType=@unitType,ParentOrgUnitID=@parent,UnitCode=@code,NameTH=@name,NameEN=@nameEn,IsActive=@active,UpdateDate=SYSUTCDATETIME() WHERE OrgUnitID=@id AND CompanyID=@company;";
        await using var cmd=new SqlCommand(sql,c); cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id??(object)DBNull.Value; cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=companyId; cmd.Parameters.Add("@unitType",SqlDbType.NVarChar,10).Value=x.UnitType; cmd.Parameters.Add("@parent",SqlDbType.BigInt).Value=x.ParentOrgUnitId??(object)DBNull.Value; cmd.Parameters.Add("@code",SqlDbType.NVarChar,50).Value=normalizedCode; cmd.Parameters.Add("@name",SqlDbType.NVarChar,200).Value=x.NameTh.Trim(); cmd.Parameters.Add("@nameEn",SqlDbType.NVarChar,200).Value=(object?)x.NameEn?.Trim()??DBNull.Value; cmd.Parameters.Add("@active",SqlDbType.Bit).Value=x.IsActive;
        try
        {
            await cmd.ExecuteNonQueryAsync(token);
        }
        catch (SqlException ex) when (ex.Number == 50002)
        {
            return Conflict(new { message = "ไม่พบค่ากลางโครงสร้างองค์กรของบริษัท" });
        }
        catch (SqlException ex) when (ex.Number == 50003)
        {
            return Conflict(new { message = "ฝ่ายไม่สามารถมีฝ่ายแม่ได้" });
        }
        catch (SqlException ex) when (ex.Number == 50004)
        {
            return Conflict(new { message = "โหมดแผนกเท่านั้นไม่อนุญาตให้เลือกฝ่าย" });
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            return Conflict(new { message = "กรุณาเลือกฝ่ายที่มีอยู่ก่อนบันทึกแผนก" });
        }
        catch (SqlException ex) when (ex.Number == 50006)
        {
            return Conflict(new { message = "ชื่อซ้ำ" });
        }
        catch (SqlException ex) when (ex.Number == 50007)
        {
            return Conflict(new { message = "รหัสซ้ำ" });
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            return Conflict(new { message = "รหัสย่อห้ามมีช่องว่าง" });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627)
        {
            return Conflict(new { message = "รหัสซ้ำ" });
        }
        return NoContent();
    }

    private async Task<IActionResult> SavePartner(long? id, UnitRequest x, long partnerId, CancellationToken token)
    {
        if ((x.UnitType != "DIV" && x.UnitType != "DEP") || string.IsNullOrWhiteSpace(x.UnitCode) || string.IsNullOrWhiteSpace(x.NameTh))
            return BadRequest(new { message = "กรุณากรอกรหัสและชื่อฝ่าย/แผนกให้ครบ และรหัสย่อห้ามมีช่องว่าง" });
        var code = x.UnitCode.Trim().ToUpperInvariant();
        if (code.Any(char.IsWhiteSpace))
            return BadRequest(new { message = "รหัสย่อห้ามมีช่องว่าง" });
        await using var c = await Open(token);
        if (!await Allowed(c, id is null ? "CREATE" : "EDIT", token)) return Forbid();
        const string sql = "DECLARE @mode int=(SELECT OrgStructureType FROM dbo.TDSTCompanySetUp WHERE OwnerType='P' AND PartnerID=@partner); IF @mode IS NULL SET @mode=1; IF EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE OwnerType='P' AND PartnerID=@partner AND UnitType=@type AND LOWER(REPLACE(UnitCode,N' ',N''))=LOWER(REPLACE(@code,N' ',N'')) AND (@id IS NULL OR OrgUnitID<>@id)) THROW 50007,'DUPLICATE_CODE',1; IF @type='DIV' AND @parent IS NOT NULL THROW 50003,'DIVISION_PARENT_INVALID',1; IF @type='DEP' AND @mode=1 AND @parent IS NOT NULL THROW 50004,'DEPARTMENT_PARENT_INVALID',1; IF @type='DEP' AND @mode=2 AND NOT EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE OrgUnitID=@parent AND OwnerType='P' AND PartnerID=@partner AND UnitType='DIV' AND IsActive=1) THROW 50005,'DEPARTMENT_PARENT_REQUIRED',1; IF @id IS NULL INSERT dbo.TDADOrganizationUnit(OwnerType,PartnerID,CompanyID,UnitType,ParentOrgUnitID,UnitCode,NameTH,NameEN,IsActive) VALUES('P',@partner,NULL,@type,@parent,@code,@name,@nameEn,@active); ELSE UPDATE dbo.TDADOrganizationUnit SET UnitType=@type,ParentOrgUnitID=@parent,UnitCode=@code,NameTH=@name,NameEN=@nameEn,IsActive=@active,UpdateDate=SYSUTCDATETIME() WHERE OrgUnitID=@id AND OwnerType='P' AND PartnerID=@partner;";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id??(object)DBNull.Value; cmd.Parameters.Add("@partner",SqlDbType.BigInt).Value=partnerId; cmd.Parameters.Add("@type",SqlDbType.NVarChar,10).Value=x.UnitType; cmd.Parameters.Add("@parent",SqlDbType.BigInt).Value=x.ParentOrgUnitId??(object)DBNull.Value; cmd.Parameters.Add("@code",SqlDbType.NVarChar,50).Value=code; cmd.Parameters.Add("@name",SqlDbType.NVarChar,200).Value=x.NameTh.Trim(); cmd.Parameters.Add("@nameEn",SqlDbType.NVarChar,200).Value=(object?)x.NameEn?.Trim()??DBNull.Value; cmd.Parameters.Add("@active",SqlDbType.Bit).Value=x.IsActive;
        try
        {
            var affected = await cmd.ExecuteNonQueryAsync(token);
            return affected == 0 ? NotFound(new { message = "ไม่พบข้อมูลโครงสร้างองค์กรของ Partner" }) : NoContent();
        }
        catch(SqlException ex) when(ex.Number==50007){return Conflict(new {message="รหัสซ้ำ"});}
        catch(SqlException ex) when(ex.Number==50003){return Conflict(new {message="ฝ่ายไม่สามารถมีฝ่ายแม่ได้"});}
        catch(SqlException ex) when(ex.Number==50004){return Conflict(new {message="โหมดแผนกเท่านั้นไม่อนุญาตให้เลือกฝ่าย"});}
        catch(SqlException ex) when(ex.Number==50005){return Conflict(new {message="กรุณาเลือกฝ่ายก่อนบันทึกแผนก"});}
    }
    private async Task<bool> Allowed(SqlConnection c, string action, CancellationToken t)
    {
        if (!long.TryParse(User.FindFirstValue("project_id"), out var pid)) return false;
        await using var cmd = new SqlCommand { Connection = c };
        string sql;
        var menuCode = IsPartner() ? "11005" : User.FindFirstValue("laoo_user_id") is not null ? "12005" : "10005";
        cmd.Parameters.Add("@pid", SqlDbType.BigInt).Value = pid;
        cmd.Parameters.Add("@screen", SqlDbType.NVarChar, 100).Value = ScreenCode;
        cmd.Parameters.Add("@menuCode", SqlDbType.NVarChar, 20).Value = menuCode;
        cmd.Parameters.Add("@action", SqlDbType.NVarChar, 50).Value = action;
        if (IsPartner())
        {
            if (!long.TryParse(User.FindFirstValue("partner_id"), out var partnerId)) return false;
            cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = partnerId;
            cmd.Parameters.Add("@username", SqlDbType.NVarChar, 100).Value = Username().ToUpperInvariant();
            sql = """
                SELECT CASE WHEN EXISTS(
                    SELECT 1 FROM dbo.TDADPartnerUser U
                    WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND U.IsPartnerAdmin=1 AND U.IsActive=1)
                  OR EXISTS(
                    SELECT 1 FROM dbo.TDADPartnerUser U
                    INNER JOIN dbo.TDADPartnerUserPermission UP ON UP.PartnerUserID=U.PartnerUserID
                    INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
                    WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND U.IsActive=1
                      AND UP.ProjectID=@pid AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1
                      AND P.ScreenCode IN (@screen,N'ORGANIZATION_STRUCTURE',@menuCode) AND P.ActionCode=@action)
                  OR EXISTS(
                    SELECT 1 FROM dbo.TDADPartnerUser U
                    INNER JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.PartnerUserID=U.PartnerUserID
                    INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=PUE.EmployeeID
                    INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='P'
                      AND RG.PartnerID=U.PartnerID AND RG.ProjectID=@pid
                    INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@pid
                      AND RP.MenuCode IN (@screen,@menuCode) AND RP.ActionCode=@action AND RP.IsAllowed=1
                    WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND U.IsActive=1
                      AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
                      AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))
                THEN 1 ELSE 0 END;
                """;
        }
        else
        {
            var isLaoo = User.FindFirstValue("laoo_user_id") is not null;
            if (!long.TryParse(User.FindFirstValue(isLaoo ? "laoo_user_id" : "user_id"), out var uid)) return false;
            cmd.Parameters.Add("@uid", SqlDbType.BigInt).Value = uid;
            var table = isLaoo ? "TDADLaooUserPermission" : "TDADUserPermission";
            var key = isLaoo ? "LaooUserID" : "UserID";
            sql = isLaoo
                ? $"SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.{table} UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.{key}=@uid AND UP.ProjectID=@pid AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.ScreenCode IN (@screen,N'ORGANIZATION_STRUCTURE',@menuCode) AND P.ActionCode=@action AND P.IsActive=1) THEN 1 ELSE 0 END"
                : $"SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@uid AND U.IsActive=1 AND U.IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.{table} UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.{key}=@uid AND UP.ProjectID=@pid AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.ScreenCode IN (@screen,N'ORGANIZATION_STRUCTURE',@menuCode) AND P.ActionCode=@action AND P.IsActive=1) OR EXISTS(SELECT 1 FROM dbo.TDADUser U INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@pid INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@pid AND RP.MenuCode IN (@screen,@menuCode) AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.UserID=@uid AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END";
        }
        cmd.CommandText = sql;
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(t));
    }
    private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private bool IsPartner()=>string.Equals(User.FindFirstValue("user_type"),"PARTNER_USER",StringComparison.OrdinalIgnoreCase);
    private string Username() => (User.Identity?.Name ?? User.FindFirstValue("unique_name") ?? string.Empty).Trim();
    private long? ResolveCompany(long? _) =>
        long.TryParse(User.FindFirstValue("company_id"), out var company)
            ? company
            : null;
    private static string? N(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i);
}
public sealed record UnitRequest(long? CompanyId,string UnitType,long? ParentOrgUnitId,string UnitCode,string NameTh,string? NameEn,bool IsActive=true);
public sealed record OrganizationModeRequest(long? CompanyId, int OrgStructureType);
