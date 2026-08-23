using System.Data;
using System.Security.Claims;
using LaooApi.Models.Support;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/partner/employees")]
[Route("api/partner/customer-employees")]
[Route("api/company/employees")]
public sealed class EmployeeController(IConfiguration configuration, PasswordService passwordService) : ControllerBase
{
    private string ScreenCode => Request.Path.Value?.Contains("/api/company/", StringComparison.OrdinalIgnoreCase) == true ? "10001" : Request.Path.Value?.Contains("customer-employees", StringComparison.OrdinalIgnoreCase) == true ? "12001" : "11001";

    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] string? search, [FromQuery] long? divisionId, [FromQuery] long? departmentId, [FromQuery] bool? isActive, [FromQuery] long? companyId,
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
                   E.StartWorkDate,CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADEmployeeImage EI WHERE EI.EmployeeID=E.EmployeeID AND EI.ImageType=N'FORMAL' AND ISNULL(EI.IsActive,1)=1 AND DATALENGTH(EI.ImageData)>0) THEN 1 ELSE 0 END,E.IsActive
                   ,E.CarID1,E.CarColor1,E.CarTypeCode1,E.CarOilType1,E.CarID2,E.CarColor2,E.CarTypeCode2,E.CarOilType2
            FROM dbo.TDADEmployee E
            LEFT JOIN dbo.TDADOrganizationUnit DV ON DV.OrgUnitID=E.DivisionOrgUnitID
            LEFT JOIN dbo.TDADOrganizationUnit DP ON DP.OrgUnitID=E.DepartmentOrgUnitID
            WHERE E.PartnerID=@partner AND ((@company IS NULL AND E.CompanyID IS NULL) OR E.CompanyID=@company)
              AND (@q=N'' OR E.EmployeeCode LIKE @like OR E.FullName LIKE @like OR E.NickName LIKE @like OR E.Email LIKE @like)
              AND (@division IS NULL OR E.DivisionOrgUnitID=@division)
              AND (@department IS NULL OR E.DepartmentOrgUnitID=@department)
              AND (@isActive IS NULL OR E.IsActive=@isActive)
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
        cmd.Parameters.Add("@isActive", SqlDbType.Bit).Value = isActive ?? (object)DBNull.Value;
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

    [HttpGet("actions")]
    public async Task<ActionResult<object>> Actions(CancellationToken token)
    {
        await using var connection = await Open(token);
        return Ok(new { view = await Allowed(connection, "VIEW", token), create = await Allowed(connection, "CREATE", token), edit = await Allowed(connection, "EDIT", token), delete = await Allowed(connection, "DELETE", token) });
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
            return BadRequest(new { message = "เธเธฃเธธเธ“เธฒเธเธฃเธญเธเธฃเธซเธฑเธชเธเธเธฑเธเธเธฒเธเนเธฅเธฐเธเธทเนเธญ-เธเธฒเธกเธชเธเธธเธฅ" });
        await using var c = await Open(token);
        if (!await Allowed(c, id is null ? "CREATE" : "EDIT", token)) return Forbid();
        const string sql = """
            IF EXISTS(SELECT 1 FROM dbo.TDADEmployee WHERE PartnerID=@partner AND ((@company IS NULL AND CompanyID IS NULL) OR CompanyID=@company) AND EmployeeCode=@code AND (@id IS NULL OR EmployeeID<>@id)) THROW 50001,'DUPLICATE_EMPLOYEE_CODE',1;
            IF @division IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE OrgUnitID=@division AND UnitType='DIV' AND IsActive=1 AND ((@company IS NULL AND OwnerType='P' AND PartnerID=@partner) OR (@company IS NOT NULL AND OwnerType='C' AND CompanyID=@company))) THROW 50002,'INVALID_DIVISION',1;
            IF @department IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit WHERE OrgUnitID=@department AND UnitType='DEP' AND IsActive=1 AND ((@company IS NULL AND OwnerType='P' AND PartnerID=@partner) OR (@company IS NOT NULL AND OwnerType='C' AND CompanyID=@company))) THROW 50003,'INVALID_DEPARTMENT',1;
            IF @id IS NULL INSERT dbo.TDADEmployee(PartnerID,CompanyID,DivisionOrgUnitID,DepartmentOrgUnitID,EmployeeCode,FullName,NickName,PositionCode,Email,Telephone,PersonalTelephone,ContName1,ContRelation1,ContPhone1,ContName2,ContRelation2,ContPhone2,StartWorkDate,CarID1,CarColor1,CarTypeCode1,CarOilType1,CarID2,CarColor2,CarTypeCode2,CarOilType2,IsActive) VALUES(@partner,@company,@division,@department,@code,@name,@nick,@position,@email,@tel,@personal,@contName1,@contRelation1,@contPhone1,@contName2,@contRelation2,@contPhone2,@start,@carId1,@carColor1,@carType1,@carOil1,@carId2,@carColor2,@carType2,@carOil2,@active);
            ELSE UPDATE dbo.TDADEmployee SET PartnerID=@partner,CompanyID=@company,DivisionOrgUnitID=@division,DepartmentOrgUnitID=@department,EmployeeCode=@code,FullName=@name,NickName=@nick,PositionCode=@position,Email=@email,Telephone=@tel,PersonalTelephone=@personal,ContName1=@contName1,ContRelation1=@contRelation1,ContPhone1=@contPhone1,ContName2=@contName2,ContRelation2=@contRelation2,ContPhone2=@contPhone2,StartWorkDate=@start,CarID1=@carId1,CarColor1=@carColor1,CarTypeCode1=@carType1,CarOilType1=@carOil1,CarID2=@carId2,CarColor2=@carColor2,CarTypeCode2=@carType2,CarOilType2=@carOil2,IsActive=@active,UpdateDate=SYSUTCDATETIME() WHERE EmployeeID=@id AND PartnerID=@partner AND ((@company IS NULL AND CompanyID IS NULL) OR CompanyID=@company);
            SELECT CAST(CASE WHEN @id IS NULL THEN SCOPE_IDENTITY() ELSE @id END AS BIGINT);
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
        try { var savedId = Convert.ToInt64(await cmd.ExecuteScalarAsync(token)); return Ok(new { employeeId = savedId }); }
        catch (SqlException ex) when (ex.Number == 50001) { return Conflict(new { message = "เธฃเธซเธฑเธชเธเธเธฑเธเธเธฒเธเธเนเธณ" }); }
        catch (SqlException ex) when (ex.Number is 50002 or 50003) { return BadRequest(new { message = "เธเนเธฒเธขเธซเธฃเธทเธญเนเธเธเธเนเธกเนเธ–เธนเธเธ•เนเธญเธ" }); }
    }

    [HttpGet("{id:long}/image")]
    public async Task<IActionResult> GetImage(long id, [FromQuery] long? companyId, CancellationToken token)
    {
        var scope = ResolveScope(companyId); if (scope is null) return Forbid();
        await using var c = await Open(token);
        const string sql = "SELECT TOP 1 I.ImageData,I.ContentType,I.FileName,I.ImageWidth,I.ImageHeight FROM dbo.TDADEmployeeImage I INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=I.EmployeeID WHERE I.EmployeeID=@id AND I.ImageType=N'FORMAL' AND ISNULL(I.IsActive,1)=1 AND DATALENGTH(I.ImageData)>0 AND E.EmployeeID=@id AND E.PartnerID=@partner AND ((@company IS NULL AND E.CompanyID IS NULL) OR E.CompanyID=@company)";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
        cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId;
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
        await using var r = await cmd.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound();
        return Ok(new { imageDataBase64 = Convert.ToBase64String((byte[])r[0]), contentType = r.IsDBNull(1) ? "image/jpeg" : r.GetString(1), fileName = r.IsDBNull(2) ? null : r.GetString(2), imageWidth = r.IsDBNull(3) ? 0 : r.GetInt32(3), imageHeight = r.IsDBNull(4) ? 0 : r.GetInt32(4) });
    }

    [HttpPut("{id:long}/image")]
    public async Task<IActionResult> SaveImage(long id, EmployeeImageUpsertRequest request, CancellationToken token)
    {
        var scope = ResolveScope(request.CompanyId); if (scope is null) return Forbid();
        if (!string.Equals(request.ImageType, "FORMAL", StringComparison.OrdinalIgnoreCase)) return BadRequest(new { message = "เธฃเธญเธเธฃเธฑเธเน€เธเธเธฒเธฐเธฃเธนเธเนเธเธเน€เธเนเธเธ—เธฒเธเธเธฒเธฃ" });
        byte[] bytes;
        try { bytes = Convert.FromBase64String(request.ImageDataBase64); } catch (FormatException) { return BadRequest(new { message = "เธเนเธญเธกเธนเธฅเธฃเธนเธเธ เธฒเธเนเธกเนเธ–เธนเธเธ•เนเธญเธ" }); }
        if (bytes.Length == 0 || bytes.Length > 102400) return BadRequest(new { message = "เธฃเธนเธเธ เธฒเธเธ•เนเธญเธเธกเธตเธเธเธฒเธ”เนเธกเนเน€เธเธดเธ 100 KB" });
        await using var c = await Open(token); if (!await Allowed(c, "EDIT", token)) return Forbid();
        const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDADEmployee WHERE EmployeeID=@id AND PartnerID=@partner AND ((@company IS NULL AND CompanyID IS NULL) OR CompanyID=@company)) THROW 50006,'EMPLOYEE_NOT_FOUND',1;
UPDATE dbo.TDADEmployeeImage SET ImageData=@data,ContentType=@type,FileName=@name,FileSize=@size,ImageWidth=@width,ImageHeight=@height,IsActive=1,UpdateDate=SYSUTCDATETIME()
WHERE EmployeeID=@id AND ImageType=N'FORMAL';
IF @@ROWCOUNT=0 INSERT dbo.TDADEmployeeImage(EmployeeID,ImageType,ImageData,ContentType,FileName,FileSize,ImageWidth,ImageHeight,IsActive,CreateDate)
VALUES(@id,N'FORMAL',@data,@type,@name,@size,@width,@height,1,SYSUTCDATETIME());
""";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id; cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId; cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
        cmd.Parameters.Add("@data", SqlDbType.VarBinary, -1).Value = bytes; cmd.Parameters.Add("@type", SqlDbType.NVarChar, 100).Value = request.ContentType; cmd.Parameters.Add("@name", SqlDbType.NVarChar, 250).Value = (object?)request.FileName ?? DBNull.Value; cmd.Parameters.Add("@size", SqlDbType.Int).Value = bytes.Length; cmd.Parameters.Add("@width", SqlDbType.Int).Value = request.ImageWidth; cmd.Parameters.Add("@height", SqlDbType.Int).Value = request.ImageHeight;
        try { await cmd.ExecuteNonQueryAsync(token); return NoContent(); } catch (SqlException ex) when (ex.Number == 50006) { return NotFound(); }
    }

    [HttpGet("{id:long}/car-image/{carNo:int}")]
    public async Task<IActionResult> GetCarImage(long id, int carNo, [FromQuery] long? companyId, CancellationToken token)
    {
        if (carNo is < 1 or > 2) return BadRequest(new { message = "CarNo เธ•เนเธญเธเน€เธเนเธ 1 เธซเธฃเธทเธญ 2" });
        var scope = ResolveScope(companyId); if (scope is null) return Forbid();
        await using var c = await Open(token);
        const string sql = "SELECT TOP 1 I.ImageData,I.ContentType,I.FileName,I.ImageWidth,I.ImageHeight FROM dbo.TDADEmployeeCarImage I INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=I.EmployeeID WHERE I.EmployeeID=@id AND I.CarNo=@carNo AND ISNULL(I.IsActive,1)=1 AND DATALENGTH(I.ImageData)>0 AND E.PartnerID=@partner AND ((@company IS NULL AND E.CompanyID IS NULL) OR E.CompanyID=@company)";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
        cmd.Parameters.Add("@carNo", SqlDbType.TinyInt).Value = carNo;
        cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId;
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
        await using var r = await cmd.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound();
        return Ok(new { imageDataBase64 = Convert.ToBase64String((byte[])r[0]), contentType = r.IsDBNull(1) ? "image/jpeg" : r.GetString(1), fileName = r.IsDBNull(2) ? null : r.GetString(2), imageWidth = r.IsDBNull(3) ? 0 : r.GetInt32(3), imageHeight = r.IsDBNull(4) ? 0 : r.GetInt32(4) });
    }

    [HttpPut("{id:long}/car-image/{carNo:int}")]
    public async Task<IActionResult> SaveCarImage(long id, int carNo, EmployeeCarImageUpsertRequest request, CancellationToken token)
    {
        if (carNo is < 1 or > 2 || request.CarNo != carNo) return BadRequest(new { message = "CarNo เธ•เนเธญเธเน€เธเนเธ 1 เธซเธฃเธทเธญ 2" });
        var scope = ResolveScope(request.CompanyId); if (scope is null) return Forbid();
        byte[] bytes;
        try { bytes = Convert.FromBase64String(request.ImageDataBase64); } catch (FormatException) { return BadRequest(new { message = "เธเนเธญเธกเธนเธฅเธฃเธนเธเธฃเธ–เนเธกเนเธ–เธนเธเธ•เนเธญเธ" }); }
        if (bytes.Length == 0 || bytes.Length > 102400) return BadRequest(new { message = "เธฃเธนเธเธฃเธ–เธ•เนเธญเธเธกเธตเธเธเธฒเธ”เนเธกเนเน€เธเธดเธ 100 KB" });
        await using var c = await Open(token); if (!await Allowed(c, "EDIT", token)) return Forbid();
        const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDADEmployee WHERE EmployeeID=@id AND PartnerID=@partner AND ((@company IS NULL AND CompanyID IS NULL) OR CompanyID=@company)) THROW 50006,'EMPLOYEE_NOT_FOUND',1;
UPDATE dbo.TDADEmployeeCarImage SET ImageData=@data,ContentType=@type,FileName=@name,FileSize=@size,ImageWidth=@width,ImageHeight=@height,IsActive=1,UpdateDate=SYSUTCDATETIME()
WHERE EmployeeID=@id AND CarNo=@carNo;
IF @@ROWCOUNT=0 INSERT dbo.TDADEmployeeCarImage(EmployeeID,CarNo,ImageData,ContentType,FileName,FileSize,ImageWidth,ImageHeight,IsActive,CreateDate)
VALUES(@id,@carNo,@data,@type,@name,@size,@width,@height,1,SYSUTCDATETIME());
""";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id; cmd.Parameters.Add("@carNo", SqlDbType.TinyInt).Value = carNo; cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId; cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
        cmd.Parameters.Add("@data", SqlDbType.VarBinary, -1).Value = bytes; cmd.Parameters.Add("@type", SqlDbType.NVarChar, 100).Value = request.ContentType; cmd.Parameters.Add("@name", SqlDbType.NVarChar, 250).Value = (object?)request.FileName ?? DBNull.Value; cmd.Parameters.Add("@size", SqlDbType.Int).Value = bytes.Length; cmd.Parameters.Add("@width", SqlDbType.Int).Value = request.ImageWidth; cmd.Parameters.Add("@height", SqlDbType.Int).Value = request.ImageHeight;
        try { await cmd.ExecuteNonQueryAsync(token); return NoContent(); } catch (SqlException ex) when (ex.Number == 50006) { return NotFound(); }
    }

    [HttpDelete("{id:long}/car-image/{carNo:int}")]
    public async Task<IActionResult> DeleteCarImage(long id, int carNo, [FromQuery] long? companyId, CancellationToken token)
    {
        if (carNo is < 1 or > 2) return BadRequest(new { message = "CarNo เธ•เนเธญเธเน€เธเนเธ 1 เธซเธฃเธทเธญ 2" });
        var scope = ResolveScope(companyId); if (scope is null) return Forbid();
        await using var c = await Open(token); if (!await Allowed(c, "EDIT", token)) return Forbid();
        const string sql = "DELETE I FROM dbo.TDADEmployeeCarImage I INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=I.EmployeeID WHERE I.EmployeeID=@id AND I.CarNo=@carNo AND E.PartnerID=@partner AND ((@company IS NULL AND E.CompanyID IS NULL) OR E.CompanyID=@company)";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id; cmd.Parameters.Add("@carNo", SqlDbType.TinyInt).Value = carNo; cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId; cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
        await cmd.ExecuteNonQueryAsync(token);
        return NoContent();
    }

    [HttpGet("{id:long}/user")]
    public async Task<IActionResult> GetEmployeeUser(long id, [FromQuery] long? companyId, CancellationToken token)
    {
        var scope = ResolveScope(companyId); if (scope is null) return Forbid();
        await using var c = await Open(token); if (!await Allowed(c, "VIEW", token)) return Forbid();
        const string sql = """
SELECT TOP 1 CASE WHEN E.CompanyID IS NULL THEN PU.Username ELSE U.Username END,
  RG.RoleGroupID
FROM dbo.TDADEmployee E
LEFT JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=E.EmployeeID
LEFT JOIN dbo.TDADUser U ON U.UserID=UE.UserID
LEFT JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.EmployeeID=E.EmployeeID
LEFT JOIN dbo.TDADPartnerUser PU ON PU.PartnerUserID=PUE.PartnerUserID
OUTER APPLY (SELECT TOP 1 ERG.RoleGroupID FROM dbo.TDADEmployeeRoleGroup ERG WHERE ERG.EmployeeID=E.EmployeeID AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())) ORDER BY ERG.EffectiveFrom DESC,ERG.EmployeeRoleGroupID DESC) RG
WHERE E.EmployeeID=@id AND E.PartnerID=@partner AND ((@company IS NULL AND E.CompanyID IS NULL) OR E.CompanyID=@company)
""";
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
        cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId;
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
        await using var reader = await cmd.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return Ok(new { username = (string?)null, roleGroupId = (long?)null });
        return Ok(new { username = reader.IsDBNull(0) ? null : reader.GetString(0), roleGroupId = reader.IsDBNull(1) ? (long?)null : reader.GetInt64(1) });
    }

    [HttpPut("{id:long}/user")]
    public async Task<IActionResult> UpsertEmployeeUser(long id, EmployeeUserUpsertRequest request, CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(request.Username)) return BadRequest(new { message = "เธเธฃเธธเธ“เธฒเธฃเธฐเธเธธ Username" });
        var username = request.Username.Trim();
        if (username.Length > 100) return BadRequest(new { message = "Username เธ•เนเธญเธเนเธกเนเน€เธเธดเธ 100 เธ•เธฑเธงเธญเธฑเธเธฉเธฃ" });
        var scope = ResolveScope(request.CompanyId); if (scope is null) return Forbid();
        if (!long.TryParse(User.FindFirstValue("project_id"), out var projectId)) return Forbid();
        await using var c = await Open(token); if (!await Allowed(c, "EDIT", token)) return Forbid();
        var policyCode = await passwordService.GetPolicyAsync(c, scope.Value.CompanyId is null ? "P" : "C", scope.Value.PartnerId, scope.Value.CompanyId, token);
        if (!string.IsNullOrWhiteSpace(request.Password) && !PasswordService.MeetsPolicy(username, request.Password, policyCode))
            return BadRequest(new { message = PasswordService.GetPolicyMessage(policyCode) });
        await using var transaction = await c.BeginTransactionAsync(token);
        try
        {
            long? employeeCompany;
            string employeeName;
            await using (var employee = new SqlCommand("SELECT CompanyID,FullName FROM dbo.TDADEmployee WHERE EmployeeID=@id AND PartnerID=@partner AND ((@company IS NULL AND CompanyID IS NULL) OR CompanyID=@company)", c, (SqlTransaction)transaction))
            {
                employee.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                employee.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId;
                employee.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
                await using var reader = await employee.ExecuteReaderAsync(token);
                if (!await reader.ReadAsync(token)) return NotFound();
                employeeCompany = reader.IsDBNull(0) ? null : reader.GetInt64(0);
                employeeName = reader.GetString(1);
            }
            var normalized = username.ToUpperInvariant();
            var hasPassword = !string.IsNullOrEmpty(request.Password);
            var hash = hasPassword ? passwordService.HashPassword(username, request.Password!) : string.Empty;
            var actor = (User.Identity?.Name ?? User.FindFirstValue("unique_name") ?? string.Empty).Trim();
            if (employeeCompany is null)
            {
                long? userId;
                await using (var find = new SqlCommand("SELECT TOP 1 PartnerUserID FROM dbo.TDADPartnerUserEmployee WHERE EmployeeID=@employee AND PartnerID=@partner", c, (SqlTransaction)transaction))
                {
                    find.Parameters.Add("@employee", SqlDbType.BigInt).Value = id; find.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId;
                    var result = await find.ExecuteScalarAsync(token); userId = result is null or DBNull ? null : Convert.ToInt64(result);
                }
                const string sql = """
IF EXISTS (SELECT 1 FROM dbo.TDADPartnerUser WHERE NormalizedUsername=@normalized AND PartnerID=@partner AND (@userId IS NULL OR PartnerUserID<>@userId)) THROW 50008,'USERNAME_EXISTS',1;
IF @userId IS NULL
BEGIN
 INSERT dbo.TDADPartnerUser(PartnerID,Username,NormalizedUsername,PasswordHash,DisplayName,Email,MobileNumber,IsPartnerAdmin,IsActive,FailedLoginCount,CreatedUtc,CreatedBy)
 VALUES(@partner,@username,@normalized,@hash,@displayName,NULL,NULL,0,1,0,SYSUTCDATETIME(),@actor);
 SET @userId=CONVERT(BIGINT,SCOPE_IDENTITY());
 INSERT dbo.TDADPartnerUserEmployee(PartnerUserID,EmployeeID,PartnerID) VALUES(@userId,@employee,@partner);
END
ELSE UPDATE dbo.TDADPartnerUser SET Username=@username,NormalizedUsername=@normalized,PasswordHash=CASE WHEN @hasPassword=1 THEN @hash ELSE PasswordHash END WHERE PartnerUserID=@userId AND PartnerID=@partner;
""";
                await ExecuteEmployeeUserUpsert(c, (SqlTransaction)transaction, sql, username, normalized, hash, employeeName, actor, id, scope.Value.PartnerId, null, userId, hasPassword, projectId, token);
            }
            else
            {
                long? userId;
                await using (var find = new SqlCommand("SELECT TOP 1 UserID FROM dbo.TDADUserEmployee WHERE EmployeeID=@employee AND CompanyID=@company", c, (SqlTransaction)transaction))
                {
                    find.Parameters.Add("@employee", SqlDbType.BigInt).Value = id; find.Parameters.Add("@company", SqlDbType.BigInt).Value = employeeCompany.Value;
                    var result = await find.ExecuteScalarAsync(token); userId = result is null or DBNull ? null : Convert.ToInt64(result);
                }
                const string sql = """
IF EXISTS (SELECT 1 FROM dbo.TDADUser WHERE NormalizedUsername=@normalized AND CompanyID=@company AND (@userId IS NULL OR UserID<>@userId)) THROW 50008,'USERNAME_EXISTS',1;
IF @userId IS NULL
BEGIN
 INSERT dbo.TDADUser(CompanyID,Username,NormalizedUsername,PasswordHash,DisplayName,IsCompanyAdmin,IsActive,FailedLoginCount,LastPasswordChangeDate,CreateDate)
 VALUES(@company,@username,@normalized,@hash,@displayName,0,1,0,SYSUTCDATETIME(),SYSUTCDATETIME());
 SET @userId=CONVERT(BIGINT,SCOPE_IDENTITY());
 INSERT dbo.TDADUserEmployee(UserID,EmployeeID,CompanyID) VALUES(@userId,@employee,@company);
END
ELSE UPDATE dbo.TDADUser SET Username=@username,NormalizedUsername=@normalized,PasswordHash=CASE WHEN @hasPassword=1 THEN @hash ELSE PasswordHash END WHERE UserID=@userId AND CompanyID=@company;
IF @company IS NOT NULL
INSERT INTO dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate)
SELECT @company,@userId,P.ProjectID,1,1,SYSUTCDATETIME()
FROM dbo.TDADProject P
WHERE P.ProjectID=@project AND P.IsActive=1
  AND NOT EXISTS (SELECT 1 FROM dbo.TDADUserProject UP WHERE UP.CompanyID=@company AND UP.UserID=@userId AND UP.ProjectID=P.ProjectID);
""";
                await ExecuteEmployeeUserUpsert(c, (SqlTransaction)transaction, sql, username, normalized, hash, employeeName, actor, id, scope.Value.PartnerId, employeeCompany, userId, hasPassword, projectId, token);
            }
            if (request.RoleGroupId.HasValue) await AssignRoleGroupAsync(c, (SqlTransaction)transaction, id, employeeCompany, request.RoleGroupId.Value, scope.Value.PartnerId, token);
            await transaction.CommitAsync(token);
            return Ok(new { employeeId = id, username });
        }
        catch (SqlException ex) when (ex.Number is 50008 or 2601 or 2627) { await transaction.RollbackAsync(token); return Conflict(new { message = "Username เธเธตเนเธ–เธนเธเนเธเนเธเธฒเธเนเธฅเนเธง" }); }
    }

    private static async Task AssignRoleGroupAsync(SqlConnection c, SqlTransaction tx, long employeeId, long? companyId, long roleGroupId, long partnerId, CancellationToken token)
    {
        const string sql = """
            IF NOT EXISTS (SELECT 1 FROM dbo.TDADEmployee E INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=@RoleGroupID WHERE E.EmployeeID=@EmployeeID AND E.PartnerID=@PartnerID AND ((@CompanyID IS NULL AND E.CompanyID IS NULL AND RG.ScopeType='P' AND RG.PartnerID=@PartnerID) OR (@CompanyID IS NOT NULL AND E.CompanyID=@CompanyID AND RG.ScopeType='C' AND RG.CompanyID=@CompanyID))) THROW 50009,'ROLE_GROUP_SCOPE_INVALID',1;
            UPDATE dbo.TDADEmployeeRoleGroup SET IsActive=0,EffectiveTo=CONVERT(date,SYSUTCDATETIME()),UpdatedUtc=SYSUTCDATETIME(),UpdatedBy=N'api' WHERE EmployeeID=@EmployeeID AND IsActive=1;
            INSERT dbo.TDADEmployeeRoleGroup(EmployeeID,RoleGroupID,EffectiveFrom,IsActive,CreatedBy) VALUES(@EmployeeID,@RoleGroupID,CONVERT(date,SYSUTCDATETIME()),1,N'api');
            """;
        await using var command = new SqlCommand(sql, c, tx);
        command.Parameters.Add("@EmployeeID",SqlDbType.BigInt).Value=employeeId; command.Parameters.Add("@RoleGroupID",SqlDbType.BigInt).Value=roleGroupId; command.Parameters.Add("@PartnerID",SqlDbType.BigInt).Value=partnerId; command.Parameters.Add("@CompanyID",SqlDbType.BigInt).Value=companyId ?? (object)DBNull.Value;
        await command.ExecuteNonQueryAsync(token);
    }

    [HttpPost("{id:long}/user")]
    public async Task<IActionResult> CreateEmployeeUser(long id, EmployeeUserCreateRequest request, CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
            return BadRequest(new { message = "เธเธฃเธธเธ“เธฒเธฃเธฐเธเธธ Username เนเธฅเธฐ Password" });
        if (request.Username.Trim().Length > 100)
            return BadRequest(new { message = "Username เธ•เนเธญเธเนเธกเนเน€เธเธดเธ 100 เธ•เธฑเธงเธญเธฑเธเธฉเธฃ" });
        var scope = ResolveScope(request.CompanyId); if (scope is null) return Forbid();
        if (!long.TryParse(User.FindFirstValue("project_id"), out var projectId)) return Forbid();
        await using var c = await Open(token);
        if (!await Allowed(c, "EDIT", token)) return Forbid();
        var policyCode = await passwordService.GetPolicyAsync(c, scope.Value.CompanyId is null ? "P" : "C", scope.Value.PartnerId, scope.Value.CompanyId, token);
        if (!PasswordService.MeetsPolicy(request.Username.Trim(), request.Password, policyCode))
            return BadRequest(new { message = PasswordService.GetPolicyMessage(policyCode) });
        var username = request.Username.Trim();
        var normalized = username.ToUpperInvariant();
        var passwordHash = passwordService.HashPassword(username, request.Password);
        var actor = (User.Identity?.Name ?? User.FindFirstValue("unique_name") ?? string.Empty).Trim();
        await using var transaction = await c.BeginTransactionAsync(token);
        try
        {
            long? employeeCompany;
            string employeeName;
            await using (var employeeCommand = new SqlCommand("SELECT CompanyID,FullName FROM dbo.TDADEmployee WHERE EmployeeID=@id AND PartnerID=@partner AND ((@company IS NULL AND CompanyID IS NULL) OR CompanyID=@company)", c, (SqlTransaction)transaction))
            {
                employeeCommand.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
                employeeCommand.Parameters.Add("@partner", SqlDbType.BigInt).Value = scope.Value.PartnerId;
                employeeCommand.Parameters.Add("@company", SqlDbType.BigInt).Value = scope.Value.CompanyId ?? (object)DBNull.Value;
                await using var reader = await employeeCommand.ExecuteReaderAsync(token);
                if (!await reader.ReadAsync(token)) return NotFound();
                employeeCompany = reader.IsDBNull(0) ? null : reader.GetInt64(0);
                employeeName = reader.GetString(1);
            }
            if (employeeCompany is null)
            {
                const string sql = """
IF EXISTS (SELECT 1 FROM dbo.TDADPartnerUserEmployee WHERE EmployeeID=@employee) THROW 50007,'EMPLOYEE_USER_EXISTS',1;
IF EXISTS (SELECT 1 FROM dbo.TDADPartnerUser WHERE NormalizedUsername=@normalized AND PartnerID=@partner) THROW 50008,'USERNAME_EXISTS',1;
INSERT dbo.TDADPartnerUser(PartnerID,Username,NormalizedUsername,PasswordHash,DisplayName,Email,MobileNumber,IsPartnerAdmin,IsActive,FailedLoginCount,CreatedUtc,CreatedBy)
VALUES(@partner,@username,@normalized,@hash,@displayName,NULL,NULL,0,1,0,SYSUTCDATETIME(),@actor);
DECLARE @userId BIGINT = CONVERT(BIGINT,SCOPE_IDENTITY());
INSERT dbo.TDADPartnerUserEmployee(PartnerUserID,EmployeeID,PartnerID) VALUES(@userId,@employee,@partner);
""";
                await ExecuteUserCommand(c, (SqlTransaction)transaction, sql, username, normalized, passwordHash, employeeName, actor, id, scope.Value.PartnerId, null, projectId, token);
            }
            else
            {
                const string sql = """
IF EXISTS (SELECT 1 FROM dbo.TDADUserEmployee WHERE EmployeeID=@employee) THROW 50007,'EMPLOYEE_USER_EXISTS',1;
IF EXISTS (SELECT 1 FROM dbo.TDADUser WHERE NormalizedUsername=@normalized AND CompanyID=@company) THROW 50008,'USERNAME_EXISTS',1;
INSERT dbo.TDADUser(CompanyID,Username,NormalizedUsername,PasswordHash,DisplayName,IsCompanyAdmin,IsActive,FailedLoginCount,LastPasswordChangeDate,CreateDate)
VALUES(@company,@username,@normalized,@hash,@displayName,0,1,0,SYSUTCDATETIME(),SYSUTCDATETIME());
DECLARE @userId BIGINT = CONVERT(BIGINT,SCOPE_IDENTITY());
INSERT dbo.TDADUserEmployee(UserID,EmployeeID,CompanyID) VALUES(@userId,@employee,@company);
INSERT INTO dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate)
SELECT @company,@userId,P.ProjectID,1,1,SYSUTCDATETIME()
FROM dbo.TDADProject P
WHERE P.ProjectID=@project AND P.IsActive=1
  AND NOT EXISTS (SELECT 1 FROM dbo.TDADUserProject UP WHERE UP.CompanyID=@company AND UP.UserID=@userId AND UP.ProjectID=P.ProjectID);
""";
                await ExecuteUserCommand(c, (SqlTransaction)transaction, sql, username, normalized, passwordHash, employeeName, actor, id, scope.Value.PartnerId, employeeCompany, projectId, token);
            }
            await transaction.CommitAsync(token);
            return Ok(new { employeeId = id, username });
        }
        catch (SqlException ex) when (ex.Number == 50007) { await transaction.RollbackAsync(token); return Conflict(new { message = "เธเธเธฑเธเธเธฒเธเธเธตเนเธกเธต User เนเธฅเนเธง" }); }
        catch (SqlException ex) when (ex.Number is 50008 or 2601 or 2627) { await transaction.RollbackAsync(token); return Conflict(new { message = "Username เธเธตเนเธ–เธนเธเนเธเนเธเธฒเธเนเธฅเนเธง" }); }
    }

    private static async Task ExecuteEmployeeUserUpsert(SqlConnection c, SqlTransaction tx, string sql, string username, string normalized, string hash, string displayName, string actor, long employeeId, long partnerId, long? companyId, long? userId, bool hasPassword, long projectId, CancellationToken token)
    {
        await using var command = new SqlCommand(sql, c, tx);
        command.Parameters.Add("@employee", SqlDbType.BigInt).Value = employeeId;
        command.Parameters.Add("@partner", SqlDbType.BigInt).Value = partnerId;
        command.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId ?? (object)DBNull.Value;
        command.Parameters.Add("@userId", SqlDbType.BigInt).Value = userId ?? (object)DBNull.Value;
        command.Parameters.Add("@hasPassword", SqlDbType.Bit).Value = hasPassword;
        command.Parameters.Add("@project", SqlDbType.BigInt).Value = projectId;
        Add(command, "@username", SqlDbType.NVarChar, username, 100); Add(command, "@normalized", SqlDbType.NVarChar, normalized, 100); Add(command, "@hash", SqlDbType.NVarChar, hash, 500); Add(command, "@displayName", SqlDbType.NVarChar, displayName, 200); Add(command, "@actor", SqlDbType.NVarChar, actor, 100);
        await command.ExecuteNonQueryAsync(token);
    }

    private static async Task ExecuteUserCommand(SqlConnection c, SqlTransaction tx, string sql, string username, string normalized, string hash, string displayName, string actor, long employeeId, long partnerId, long? companyId, long projectId, CancellationToken token)
    {
        await using var command = new SqlCommand(sql, c, tx);
        command.Parameters.Add("@employee", SqlDbType.BigInt).Value = employeeId;
        command.Parameters.Add("@partner", SqlDbType.BigInt).Value = partnerId;
        command.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId ?? (object)DBNull.Value;
        command.Parameters.Add("@project", SqlDbType.BigInt).Value = projectId;
        Add(command, "@username", SqlDbType.NVarChar, username, 100); Add(command, "@normalized", SqlDbType.NVarChar, normalized, 100); Add(command, "@hash", SqlDbType.NVarChar, hash, 500); Add(command, "@displayName", SqlDbType.NVarChar, displayName, 200); Add(command, "@actor", SqlDbType.NVarChar, actor, 100);
        await command.ExecuteNonQueryAsync(token);
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
            ? "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.IsActive=1 AND U.IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action AND P.IsActive=1) OR EXISTS(SELECT 1 FROM dbo.TDADUser U INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.UserID=@user AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END"
            : "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADPartnerUser U WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND U.IsPartnerAdmin=1 AND U.IsActive=1) OR EXISTS(SELECT 1 FROM dbo.TDADPartnerUser U JOIN dbo.TDADPartnerUserPermission UP ON UP.PartnerUserID=U.PartnerUserID JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action AND P.IsActive=1) OR EXISTS(SELECT 1 FROM dbo.TDADPartnerUser U INNER JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.PartnerUserID=U.PartnerUserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=PUE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='P' AND RG.PartnerID=U.PartnerID AND RG.ProjectID=@project INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END";
        await using var cmd = new SqlCommand(sql, c);
        if (isCompanyUser) cmd.Parameters.Add("@user", SqlDbType.BigInt).Value = long.Parse(User.FindFirstValue("user_id")!);
        else { cmd.Parameters.Add("@partner", SqlDbType.BigInt).Value = long.Parse(User.FindFirstValue("partner_id")!); cmd.Parameters.Add("@username", SqlDbType.NVarChar, 100).Value = username; }
        cmd.Parameters.Add("@project", SqlDbType.BigInt).Value = projectId;
        cmd.Parameters.Add("@screen", SqlDbType.NVarChar, 100).Value = ScreenCode; cmd.Parameters.Add("@action", SqlDbType.NVarChar, 50).Value = action;
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(t));
    }
}
