using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/company/customers")]
public sealed class CustomerController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "09001";
    private readonly IConfiguration _configuration = configuration;

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        var result = new Dictionary<string, bool>();
        foreach (var action in new[] { "VIEW", "CREATE", "EDIT", "DELETE" }) result[action.ToLowerInvariant()] = await CanAsync(c, action, token);
        return Ok(result);
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<CustomerListRow>>> List([FromQuery] string? groupCode, [FromQuery] string? businessTypeCode, [FromQuery] string? provCode, [FromQuery] string? search, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "VIEW", token)) return Forbid();
        const string sql = """
SELECT C.CustomerID,C.CusCode,C.CusShortCode,C.CusName,C.CusGroupCode,C.BusinessTypeCode,C.ProvCode,C.Phone,C.IsActive,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.TDARCustomerFile F WHERE F.CompanyID=C.CompanyID AND F.CustomerID=C.CustomerID AND F.FileType='BUSINESS_CARD' AND F.IsActive=1) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS HasBusinessCard,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.TDARCustomerFile F WHERE F.CompanyID=C.CompanyID AND F.CustomerID=C.CustomerID AND F.FileType='CUSTOMER_DOCUMENT' AND F.IsActive=1) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS HasCustomerDocument
FROM dbo.TDARCustomer C
WHERE C.CompanyID=@company AND (@group='' OR C.CusGroupCode=@group) AND (@business='' OR C.BusinessTypeCode=@business)
  AND (@prov='' OR C.ProvCode=@prov) AND (@search='' OR C.CusCode LIKE @like OR C.CusShortCode LIKE @like OR C.CusName LIKE @like)
ORDER BY C.CusCode;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@group", SqlDbType.NVarChar, groupCode?.Trim() ?? "", 50); Add(cmd, "@business", SqlDbType.NVarChar, businessTypeCode?.Trim() ?? "", 50); Add(cmd, "@prov", SqlDbType.NVarChar, provCode?.Trim() ?? "", 50); var q = search?.Trim() ?? ""; Add(cmd, "@search", SqlDbType.NVarChar, q, 200); Add(cmd, "@like", SqlDbType.NVarChar, $"%{q}%", 210);
        var list = new List<CustomerListRow>(); await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
            list.Add(new(r.GetInt64(0), r.GetString(1), Text(r, 2), r.GetString(3), Text(r, 4), Text(r, 5), Text(r, 6), Text(r, 7), r.GetBoolean(8), r.GetBoolean(9), r.GetBoolean(10)));
        return Ok(list);
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token)
    {
        await using var c = await OpenAsync(token); if (!await CanAsync(c, "VIEW", token)) return Forbid();
        const string sql = "SELECT * FROM dbo.TDARCustomer WHERE CustomerID=@id AND CompanyID=@company";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); await using var r = await cmd.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound();
        var result = new Dictionary<string, object?>(); for (var i = 0; i < r.FieldCount; i++) result[char.ToLowerInvariant(r.GetName(i)[0]) + r.GetName(i)[1..]] = r.IsDBNull(i) ? null : r.GetValue(i);
        return Ok(result);
    }

    [HttpGet("sales-lookups")]
    public async Task<IActionResult> SalesLookups(CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "VIEW", token)) return Forbid();

        var paymentTypes = new List<object>();
        await using (var cmd = new SqlCommand("SELECT Code,Name FROM dbo.TDSTMasterCont WHERE GroupCode=@group ORDER BY Seq,Code", c))
        {
            Add(cmd, "@group", SqlDbType.NVarChar, MasterConstCodes.CustomerPaymentType, 10);
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) paymentTypes.Add(new { code = r.GetString(0), name = r.GetString(1) });
        }

        var taxTypes = new List<object>();
        await using (var cmd = new SqlCommand("SELECT Code,Name FROM dbo.TDSTMasterCont WHERE GroupCode=@group ORDER BY Seq,Code", c))
        {
            Add(cmd, "@group", SqlDbType.NVarChar, MasterConstCodes.CustomerTaxType, 10);
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) taxTypes.Add(new { code = r.GetString(0), name = r.GetString(1) });
        }

        var departments = new List<object>();
        await using (var cmd = new SqlCommand("SELECT OrgUnitID,UnitCode,NameTH FROM dbo.TDADOrganizationUnit WHERE CompanyID=@company AND UnitType=N'DEP' AND IsActive=1 ORDER BY UnitCode,NameTH", c))
        {
            Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) departments.Add(new { departmentId = r.GetInt64(0), departmentCode = r.GetString(1), departmentName = r.GetString(2) });
        }

        var employees = new List<object>();
        await using (var cmd = new SqlCommand("""
            SELECT E.EmployeeID,E.EmployeeCode,E.FullName,E.NickName,E.DepartmentOrgUnitID,DP.NameTH
            FROM dbo.TDADEmployee E
            LEFT JOIN dbo.TDADOrganizationUnit DP ON DP.OrgUnitID=E.DepartmentOrgUnitID
            WHERE E.CompanyID=@company AND E.IsActive=1
            ORDER BY E.FullName,E.EmployeeID;
            """, c))
        {
            Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) employees.Add(new
            {
                employeeId = r.GetInt64(0), employeeCode = r.GetString(1), fullName = r.GetString(2),
                nickName = Text(r, 3), departmentId = r.IsDBNull(4) ? (long?)null : r.GetInt64(4), departmentName = Text(r, 5),
            });
        }
        return Ok(new { paymentTypes, taxTypes, departments, employees });
    }

    [HttpPost]
    public Task<IActionResult> Create(CustomerUpsertRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, CustomerUpsertRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        await using var c = await OpenAsync(token); if (!await CanAsync(c, "DELETE", token)) return Forbid();
        await using var cmd = new SqlCommand("DELETE FROM dbo.TDARCustomer WHERE CustomerID=@id AND CompanyID=@company", c); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); return await cmd.ExecuteNonQueryAsync(token) == 0 ? NotFound() : NoContent();
    }

    private async Task<IActionResult> Save(long? id, CustomerUpsertRequest r, CancellationToken token)
    {
        await using var c = await OpenAsync(token); var action = id.HasValue ? "EDIT" : "CREATE"; if (!await CanAsync(c, action, token)) return Forbid();
        if (string.IsNullOrWhiteSpace(r.CusCode) || string.IsNullOrWhiteSpace(r.CusName)) return BadRequest(new { message = "กรุณาระบุรหัสและชื่อลูกค้า" });
        const string sql = """
IF @id IS NULL
BEGIN
 INSERT dbo.TDARCustomer(CompanyID,CusCode,CusShortCode,CusName,CusAddress,ProvCode,PostCode,StartDate,CusGroupCode,BusinessTypeCode,PriceLevelCode,Website,TaxID,Phone,Email,ContName1,PositionName1,Phone1,Email1,ContName2,PositionName2,Phone2,Email2,PaymentType,CreditDays,CreditLimit,SalespersonEmployeeID,TaxType,IsActive)
 VALUES(@company,@code,@short,@name,@address,@prov,@post,@start,@group,@business,@price,@website,@taxId,@phone,@email,@cont1,@pos1,@phone1,@email1,@cont2,@pos2,@phone2,@email2,@paymentType,@creditDays,@creditLimit,@salespersonEmployeeId,@taxType,@active);
 SELECT CONVERT(bigint,SCOPE_IDENTITY());
END
ELSE
BEGIN
 UPDATE dbo.TDARCustomer SET CusCode=@code,CusShortCode=@short,CusName=@name,CusAddress=@address,ProvCode=@prov,PostCode=@post,StartDate=@start,CusGroupCode=@group,BusinessTypeCode=@business,PriceLevelCode=@price,Website=@website,TaxID=@taxId,Phone=@phone,Email=@email,ContName1=@cont1,PositionName1=@pos1,Phone1=@phone1,Email1=@email1,ContName2=@cont2,PositionName2=@pos2,Phone2=@phone2,Email2=@email2,PaymentType=@paymentType,CreditDays=@creditDays,CreditLimit=@creditLimit,SalespersonEmployeeID=@salespersonEmployeeId,TaxType=@taxType,IsActive=@active WHERE CustomerID=@id AND CompanyID=@company;
 SELECT @id;
END
""";
        await using var cmd = new SqlCommand(sql, c); Add(cmd,"@id",SqlDbType.BigInt,(object?)id??DBNull.Value); Add(cmd,"@company",SqlDbType.BigInt,CompanyID()); Add(cmd,"@code",SqlDbType.NVarChar,r.CusCode.Trim().ToUpperInvariant(),50); Add(cmd,"@short",SqlDbType.NVarChar,Null(r.CusShortCode),50); Add(cmd,"@name",SqlDbType.NVarChar,r.CusName.Trim(),200); Add(cmd,"@address",SqlDbType.NVarChar,Null(r.CusAddress),1000); Add(cmd,"@prov",SqlDbType.NVarChar,Null(r.ProvCode),50); Add(cmd,"@post",SqlDbType.NVarChar,Null(r.PostCode),20); Add(cmd,"@start",SqlDbType.Date,(object?)r.StartDate??DBNull.Value); Add(cmd,"@group",SqlDbType.NVarChar,Null(r.CusGroupCode),50); Add(cmd,"@business",SqlDbType.NVarChar,Null(r.BusinessTypeCode),50); Add(cmd,"@price",SqlDbType.NVarChar,Null(r.PriceLevelCode),50); Add(cmd,"@website",SqlDbType.NVarChar,Null(r.Website),320); Add(cmd,"@taxId",SqlDbType.NVarChar,Null(r.TaxID),50); Add(cmd,"@phone",SqlDbType.NVarChar,Null(r.Phone),50); Add(cmd,"@email",SqlDbType.NVarChar,Null(r.Email),320); Add(cmd,"@cont1",SqlDbType.NVarChar,Null(r.ContName1),200); Add(cmd,"@pos1",SqlDbType.NVarChar,Null(r.PositionName1),200); Add(cmd,"@phone1",SqlDbType.NVarChar,Null(r.Phone1),50); Add(cmd,"@email1",SqlDbType.NVarChar,Null(r.Email1),320); Add(cmd,"@cont2",SqlDbType.NVarChar,Null(r.ContName2),200); Add(cmd,"@pos2",SqlDbType.NVarChar,Null(r.PositionName2),200); Add(cmd,"@phone2",SqlDbType.NVarChar,Null(r.Phone2),50); Add(cmd,"@email2",SqlDbType.NVarChar,Null(r.Email2),320); Add(cmd,"@paymentType",SqlDbType.NVarChar,Null(r.PaymentType),50); Add(cmd,"@creditDays",SqlDbType.Int,(object?)r.CreditDays??DBNull.Value); Add(cmd,"@creditLimit",SqlDbType.Decimal,(object?)r.CreditLimit??DBNull.Value); Add(cmd,"@salespersonEmployeeId",SqlDbType.BigInt,(object?)r.SalespersonEmployeeID??DBNull.Value); Add(cmd,"@taxType",SqlDbType.NVarChar,Null(r.TaxType),50); Add(cmd,"@active",SqlDbType.Bit,r.IsActive); return Ok(new { customerId = await cmd.ExecuteScalarAsync(token) });
    }

    private async Task<bool> CanAsync(SqlConnection c,string action,CancellationToken token){const string sql="""
SELECT CASE WHEN
    EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode=@action AND P.ScreenCode=@screen)
 OR EXISTS(SELECT 1 FROM dbo.TDADUser U INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))
 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END
"""; await using var cmd=new SqlCommand(sql,c); Add(cmd,"@user",SqlDbType.BigInt,UserID());Add(cmd,"@company",SqlDbType.BigInt,CompanyID());Add(cmd,"@project",SqlDbType.BigInt,ProjectID());Add(cmd,"@action",SqlDbType.NVarChar,action,20);Add(cmd,"@screen",SqlDbType.NVarChar,ScreenCode,20);return (bool)(await cmd.ExecuteScalarAsync(token)??false);}
    private long UserID()=>long.TryParse(User.FindFirstValue("user_id"),out var v)?v:0; private long CompanyID()=>long.TryParse(User.FindFirstValue("company_id"),out var v)?v:0; private long ProjectID()=>long.TryParse(User.FindFirstValue("project_id"),out var v)?v:0;
    private async Task<SqlConnection> OpenAsync(CancellationToken t){var c=new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetValue(i)?.ToString(); private static object Null(string? v)=>string.IsNullOrWhiteSpace(v)?DBNull.Value:v.Trim(); private static void Add(SqlCommand c,string n,SqlDbType t,object v,int size=0){var p=c.Parameters.Add(n,t);if(size>0)p.Size=size;p.Value=v??DBNull.Value;}
}
