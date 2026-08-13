using System.Data;
using System.Security.Claims;
using LaooApi.Models.Support;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/partner/employees")]
[Route("api/partner/customer-employees")]
[Route("api/company/employees")]
public sealed class EmployeeController(IConfiguration configuration) : ControllerBase
{
    private string ScreenCode => Request.Path.Value?.Contains("/api/company/", StringComparison.OrdinalIgnoreCase) == true ? "10001" : Request.Path.Value?.Contains("customer-employees", StringComparison.OrdinalIgnoreCase) == true ? "12001" : "11001";

    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] string? search, [FromQuery] long? divisionId, [FromQuery] long? departmentId, [FromQuery] long? companyId,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20,
        CancellationToken token = default)
    {
        var scope = ResolveScope(companyId);
        if (scope is null) return Forbid();
        await using var c = await Open(token);
        if (!await Allowed(c, "VIEW", token)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        var q = search?.Trim() ?? string.Empty;
        const string sql = """
            SELECT COUNT_BIG(1) OVER() AS TotalCount,
                   E.EmployeeID,E.PartnerID,E.CompanyID,E.DivisionOrgUnitID,DV.NameTH,
                   E.DepartmentOrgUnitID,DP.NameTH,E.EmployeeCode,E.FullName,
                   E.NickName,E.PositionCode,E.Email,E.Telephone,E.PersonalTelephone,
                   E.ContName1,E.ContRelation1,E.ContPhone1,E.ContName2,E.ContRelation2,E.ContPhone2,
                   E.StartWorkDate,CASE WHEN E.ImageData IS NULL THEN 0 ELSE 1 END,E.IsActive
                   ,E.CarID1,E.CarColor1,E.CarTypeCode1,E.CarOilType1,E.CarID2,E.CarColor2,E.CarTypeCode2,E.CarOilType2
            FROM dbo.TDADEmployee E
            LEFT JOIN dbo.TDADOrganizationUnit DV ON DV.OrgUnitID=E.DivisionOrgUnitID
            LEFT JOIN dbo.TDADOrganizationUnit DP ON DP.OrgUnitID=E.DepartmentOrgUnitID
            WHERE E.PartnerID=@partner AND ((@company IS NULL AND E.CompanyID IS NULL) OR E.CompanyID=@company)
              AND (@q=N'' OR E.EmployeeCode LIKE @like OR E.FullName LIKE @like OR E.NickName LIKE @like OR E.Email LIKE @like)
              AND (@division IS NULL OR E.DivisionOrgUnitID=@division)
              AND (@department IS NULL OR E.DepartmentOrgUnitID=@department)
            ORDER BY E.EmployeeID
            OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
            """;
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId;
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
        cmd.Parameters.Add("@q", SqlDbType.NVarChar, 200).Value = q;
        cmd.Parameters.Add("@like", SqlDbType.NVarChar, 210).Value = $"%{q}%";
        cmd.Parameters.Add("@division", SqlDbType.BigInt).Value = divisionId ?? (object)DBNull.Value;
        cmd.Parameters.Add("@department", SqlDbType.BigInt).Value = departmentId ?? (object)DBNull.Value;
        cmd.Parameters.Add("@offset", SqlDbType.Int).Value = (page - 1) * pageSize;
        cmd.Parameters.Add("@pageSize", SqlDbType.Int).Value = pageSize;
        await using var r = await cmd.ExecuteReaderAsync(token);
        var items = new List<EmployeeResponse>(); long total = 0;
        while (await r.ReadAsync(token))
        {
            total = r.GetInt64(0);
            items.Add(Read(r));
        }
        return Ok(new { items, totalCount = total, page, pageSize });
    }

    [HttpPost]
    public Task<IActionResult> Create(EmployeeUpsertRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, EmployeeUpsertRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, [FromQuery] long? companyId, CancellationToken token)
    {
        var scope = ResolveScope(companyId); if (scope is null) return Forbid();
        await using var c = await Open(token); if (!await Allowed(c, "DELETE", token)) return Forbid();
        await using var cmd = new SqlCommand("DELETE dbo.TDADEmployee WHERE EmployeeID=@id AND PartnerID=@partner AND ((@company IS NULL AND CompanyID IS NULL) OR CompanyID=@company)", c);
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
        cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId;
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
        return await cmd.ExecuteNonQueryAsync(token) == 0 ? NotFound() : NoContent();
    }

    private async Task<IActionResult> Save(long? id, EmployeeUpsertRequest x, CancellationToken token)
    {
        var scope = ResolveScope(x.CompanyId); if (scope is null) return Forbid();
        if (string.IsNullOrWhiteSpace(x.EmployeeCode) || string.IsNullOrWhiteSpace(x.FullName))
            return BadRequest(new { message = "กรุณากรอกรหัสพนักงานและชื่อ-นามสกุล" });
        await using var c = await Open(token);
        if (!await Allowed(c, id is null ? "CREATE" : "EDIT", token)) return Forbid();
        const string sql = """
            IF EXISTS(SELECT 1 FROM dbo.TDADEmployee WHERE PartnerID=@partner AND ((@company IS NULL AND CompanyID IS NULL) OR CompanyID=@company) AND EmployeeCode=@code AND (@id IS NULL OR EmployeeID<>@id)) THROW 50001,'DUPLICATE_EMPLOYEE_CODE',1;
            IF @division IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE OrgUnitID=@division AND UnitType='DIV' AND IsActive=1 AND ((@company IS NULL AND OwnerType='P' AND PartnerID=@partner) OR (@company IS NOT NULL AND OwnerType='C' AND CompanyID=@company))) THROW 50002,'INVALID_DIVISION',1;
            IF @department IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE OrgUnitID=@department AND UnitType='DEP' AND IsActive=1 AND ((@company IS NULL AND OwnerType='P' AND PartnerID=@partner) OR (@company IS NOT NULL AND OwnerType='C' AND CompanyID=@company))) THROW 50003,'INVALID_DEPARTMENT',1;
            IF @id IS NULL INSERT dbo.TDADEmployee(PartnerID,CompanyID,DivisionOrgUnitID,DepartmentOrgUnitID,EmployeeCode,FullName,NickName,PositionCode,Email,Telephone,PersonalTelephone,ContName1,ContRelation1,ContPhone1,ContName2,ContRelation2,ContPhone2,StartWorkDate,CarID1,CarColor1,CarTypeCode1,CarOilType1,CarID2,CarColor2,CarTypeCode2,CarOilType2,IsActive) VALUES(@partner,@company,@division,@department,@code,@name,@nick,@position,@email,@tel,@personal,@contName1,@contRelation1,@contPhone1,@contName2,@contRelation2,@contPhone2,@start,@carId1,@carColor1,@carType1,@carOil1,@carId2,@carColor2,@carType2,@carOil2,@active);
            ELSE UPDATE dbo.TDADEmployee SET PartnerID=@partner,CompanyID=@company,DivisionOrgUnitID=@division,DepartmentOrgUnitID=@department,EmployeeCode=@code,FullName=@name,NickName=@nick,PositionCode=@position,Email=@email,Telephone=@tel,PersonalTelephone=@personal,ContName1=@contName1,ContRelation1=@contRelation1,ContPhone1=@contPhone1,ContName2=@contName2,ContRelation2=@contRelation2,ContPhone2=@contPhone2,StartWorkDate=@start,CarID1=@carId1,CarColor1=@carColor1,CarTypeCode1=@carType1,CarOilType1=@carOil1,CarID2=@carId2,CarColor2=@carColor2,CarTypeCode2=@carType2,CarOilType2=@carOil2,IsActive=@active,UpdateDate=SYSUTCDATETIME() WHERE EmployeeID=@id AND PartnerID=@partner AND ((@company IS NULL AND CompanyID IS NULL) OR CompanyID=@company);
            """;
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id ?? (object)DBNull.Value;
        cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId;
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
        Add(cmd, "@division", SqlDbType.BigInt, x.DivisionOrgUnitId); Add(cmd, "@department", SqlDbType.BigInt, x.DepartmentOrgUnitId);
        Add(cmd, "@code", SqlDbType.NVarChar, x.EmployeeCode.Trim().ToUpperInvariant(), 50); Add(cmd, "@name", SqlDbType.NVarChar, x.FullName.Trim(), 200);
        Add(cmd, "@nick", SqlDbType.NVarChar, x.NickName, 100); Add(cmd, "@position", SqlDbType.NVarChar, x.PositionCode, 50); Add(cmd, "@email", SqlDbType.NVarChar, x.Email, 200);
        Add(cmd, "@tel", SqlDbType.NVarChar, x.Telephone, 50); Add(cmd, "@personal", SqlDbType.NVarChar, x.PersonalTelephone, 50); Add(cmd, "@start", SqlDbType.Date, x.StartWorkDate);
        Add(cmd, "@contName1", SqlDbType.NVarChar, x.ContName1, 250); Add(cmd, "@contRelation1", SqlDbType.NVarChar, x.ContRelation1, 250); Add(cmd, "@contPhone1", SqlDbType.NVarChar, x.ContPhone1, 250);
        Add(cmd, "@contName2", SqlDbType.NVarChar, x.ContName2, 250); Add(cmd, "@contRelation2", SqlDbType.NVarChar, x.ContRelation2, 250); Add(cmd, "@contPhone2", SqlDbType.NVarChar, x.ContPhone2, 250);
        Add(cmd, "@carId1", SqlDbType.NVarChar, x.CarID1, 50); Add(cmd, "@carColor1", SqlDbType.NVarChar, x.CarColor1, 100); Add(cmd, "@carType1", SqlDbType.NVarChar, x.CarTypeCode1, 50); Add(cmd, "@carOil1", SqlDbType.NVarChar, x.CarOilType1, 50);
        Add(cmd, "@carId2", SqlDbType.NVarChar, x.CarID2, 50); Add(cmd, "@carColor2", SqlDbType.NVarChar, x.CarColor2, 100); Add(cmd, "@carType2", SqlDbType.NVarChar, x.CarTypeCode2, 50); Add(cmd, "@carOil2", SqlDbType.NVarChar, x.CarOilType2, 50);
        cmd.Parameters.Add("@active", SqlDbType.Bit).Value = x.IsActive;
        try { await cmd.ExecuteNonQueryAsync(token); return NoContent(); }
        catch (SqlException ex) when (ex.Number == 50001) { return Conflict(new { message = "รหัสพนักงานซ้ำ" }); }
        catch (SqlException ex) when (ex.Number is 50002 or 50003) { return BadRequest(new { message = "ฝ่ายหรือแผนกไม่ถูกต้อง" }); }
    }

    private static EmployeeResponse Read(SqlDataReader r) => new()
    {
        EmployeeId = r.GetInt64(1), PartnerId = r.GetInt64(2), CompanyId = NLong(r, 3), DivisionOrgUnitId = NLong(r, 4), DivisionName = NString(r, 5),
        DepartmentOrgUnitId = NLong(r, 6), DepartmentName = NString(r, 7), EmployeeCode = r.GetString(8), FullName = r.GetString(9),
        NickName = NString(r, 10), PositionCode = NString(r, 11), Email = NString(r, 12), Telephone = NString(r, 13), PersonalTelephone = NString(r, 14),
        ContName1 = NString(r, 15), ContRelation1 = NString(r, 16), ContPhone1 = NString(r, 17), ContName2 = NString(r, 18), ContRelation2 = NString(r, 19), ContPhone2 = NString(r, 20),
        StartWorkDate = r.IsDBNull(21) ? null : r.GetDateTime(21), HasImage = r.GetInt32(22) != 0, IsActive = r.GetBoolean(23), CarID1 = NString(r, 24), CarColor1 = NString(r, 25), CarTypeCode1 = NString(r, 26), CarOilType1 = NString(r, 27), CarID2 = NString(r, 28), CarColor2 = NString(r, 29), CarTypeCode2 = NString(r, 30), CarOilType2 = NString(r, 31)
    };
    private static long? NLong(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static string? NString(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static void Add(SqlCommand c, string name, SqlDbType type, object? value, int size = 0) { var p = size > 0 ? c.Parameters.Add(name, type, size) : c.Parameters.Add(name, type); p.Value = value ?? DBNull.Value; }
    private async Task<SqlConnection> Open(CancellationToken t) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(t); return c; }
    private (long PartnerId, long? CompanyId)? ResolveScope(long? requestedCompany)
    {
        if (!long.TryParse(User.FindFirstValue("partner_id"), out var partnerId)) return null;
        if (Request.Path.Value?.Contains("/api/company/", StringComparison.OrdinalIgnoreCase) == true)
        {
            return long.TryParse(User.FindFirstValue("company_id"), out var companyScope)
                ? (partnerId, companyScope)
                : null;
        }
        var isCustomerRoute = Request.Path.Value?.Contains("customer-employees", StringComparison.OrdinalIgnoreCase) == true;
        if (!isCustomerRoute) return (partnerId, null);
        var companyId = requestedCompany ?? (long.TryParse(User.FindFirstValue("company_id"), out var ownCompany) ? ownCompany : null);
        return companyId is null ? null : (partnerId, companyId);
    }
    private async Task<bool> Allowed(SqlConnection c, string action, CancellationToken t)
    {
        if (!long.TryParse(User.FindFirstValue("project_id"), out var projectId)) return false;
        var username = (User.Identity?.Name ?? User.FindFirstValue("unique_name") ?? string.Empty).Trim().ToUpperInvariant();
        var isCompanyUser = string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase);
        var sql = isCompanyUser
            ? "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.IsActive=1 AND U.IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action AND P.IsActive=1) THEN 1 ELSE 0 END"
            : "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADPartnerUser U WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND U.IsPartnerAdmin=1 AND U.IsActive=1) OR EXISTS(SELECT 1 FROM dbo.TDADPartnerUser U JOIN dbo.TDADPartnerUserPermission UP ON UP.PartnerUserID=U.PartnerUserID JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action AND P.IsActive=1) THEN 1 ELSE 0 END";
        await using var cmd = new SqlCommand(sql, c);
        if (isCompanyUser) cmd.Parameters.Add("@user", SqlDbType.BigInt).Value = long.Parse(User.FindFirstValue("user_id")!);
        else { cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = long.Parse(User.FindFirstValue("partner_id")!); cmd.Parameters.Add("@username", SqlDbType.NVarChar, 100).Value = username; }
        cmd.Parameters.Add("@project", SqlDbType.BigInt).Value = projectId;
        cmd.Parameters.Add("@screen", SqlDbType.NVarChar, 100).Value = ScreenCode; cmd.Parameters.Add("@action", SqlDbType.NVarChar, 50).Value = action;
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(t));
    }
}
