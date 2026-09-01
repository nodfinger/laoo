using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceApi.Controllers;

[ApiController, Authorize]
[Route("api/company/sub-permissions")]
public sealed class CompanySubPermissionController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "10006";

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "VIEW", token)) return Forbid();

        var caption = "สิทธิ์ระดับย่อย";
        await using (var title = new SqlCommand("SELECT TOP 1 MenuName FROM dbo.TDADMainMenu WHERE CONVERT(nvarchar(20),MenuCode)=@screen AND IsActive=1", c))
        {
            Add(title, "@screen", SqlDbType.NVarChar, ScreenCode, 20);
            caption = Convert.ToString(await title.ExecuteScalarAsync(token))?.Trim() ?? caption;
        }

        const string sql = """
SELECT G.MenuGroupCode,G.MenuGroupName,M.MenuCode,M.MenuName,
       N.PermissionPointCode,N.PermissionPointName,N.PermissionPointDescription,
       Assigned.EmployeeNames
FROM dbo.TDADMainMenu M
INNER JOIN dbo.TDADMenuGroup G ON G.MenuGroupCode=M.MenuGroupCode AND G.IsActive=1
INNER JOIN dbo.TDADUserPermissionPointName N
  ON N.MenuCode=CONVERT(nvarchar(20),M.MenuCode) AND N.IsActive=1
OUTER APPLY
(
    SELECT STRING_AGG(
        CONCAT(E.FullName, CASE WHEN NULLIF(LTRIM(RTRIM(E.NickName)), N'') IS NULL
                                THEN N''
                                ELSE CONCAT(N'-', LTRIM(RTRIM(E.NickName))) END),
        N' | '
    ) WITHIN GROUP (ORDER BY E.EmployeeCode) AS EmployeeNames
    FROM dbo.TDADUserPermissionPoint P
    INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=P.EmployeeID AND E.CompanyID=@company
    WHERE P.ProjectID=@project AND P.CompanyID=@company
      AND P.MenuCode=CONVERT(nvarchar(20),M.MenuCode)
      AND P.PermissionPointCode=N.PermissionPointCode
      AND P.IsActive=1 AND P.IsAllowed=1
) Assigned
WHERE M.IsActive=1 AND M.IsVisible=1 AND M.ShowPermissionPoint=1
ORDER BY G.SortOrder,M.SortOrder,M.MenuCode,N.SortOrder,N.PermissionPointName;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@project", SqlDbType.BigInt, ProjectID()); Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
        await using var r = await cmd.ExecuteReaderAsync(token);
        var rows = new List<object>();
        while (await r.ReadAsync(token)) rows.Add(new
        {
            menuGroupCode = r.GetValue(0)?.ToString()?.Trim(),
            menuGroupName = r.GetString(1),
            menuCode = r.GetValue(2)?.ToString()?.Trim(),
            menuName = r.GetString(3),
            permissionPointCode = r.GetString(4),
            permissionPointName = r.GetString(5),
            permissionPointDescription = r.IsDBNull(6) ? null : r.GetString(6),
            employeeNames = r.IsDBNull(7) ? null : r.GetString(7)
        });
        return Ok(new { caption, rows });
    }

    [HttpGet("current")]
    public async Task<IActionResult> Current([FromQuery] string menuCode, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        const string sql = """
SELECT N'*' AS PermissionPointCode
WHERE EXISTS
(
    SELECT 1
    FROM dbo.TDADUser U
    WHERE U.UserID=@user
      AND U.CompanyID=@company
      AND U.IsActive=1
      AND U.IsCompanyAdmin=1
)
UNION
SELECT DISTINCT P.PermissionPointCode
FROM dbo.TDADUserPermissionPoint P
INNER JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=P.EmployeeID
INNER JOIN dbo.TDADUser U ON U.UserID=UE.UserID AND U.CompanyID=P.CompanyID
WHERE UE.UserID=@user
  AND U.CompanyID=@company
  AND U.IsActive=1
  AND P.ProjectID=@project
  AND P.CompanyID=@company
  AND (P.MenuCode=@menu OR TRY_CONVERT(int,P.MenuCode)=TRY_CONVERT(int,@menu))
  AND P.IsActive=1
  AND P.IsAllowed=1
ORDER BY PermissionPointCode;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@user", SqlDbType.BigInt, UserID());
        Add(cmd, "@project", SqlDbType.BigInt, ProjectID());
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
        Add(cmd, "@menu", SqlDbType.NVarChar, menuCode.Trim(), 20);
        await using var r = await cmd.ExecuteReaderAsync(token);
        var codes = new List<string>();
        while (await r.ReadAsync(token))
            if (!r.IsDBNull(0)) codes.Add(r.GetString(0).Trim());
        return Ok(codes);
    }

    [HttpGet("employees")]
    public async Task<IActionResult> Employees([FromQuery] string menuCode, [FromQuery] string permissionPointCode, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "VIEW", token)) return Forbid();
        const string sql = """
SELECT E.EmployeeID,E.EmployeeCode,E.FullName,E.NickName,DP.NameTH,
       CAST(CASE WHEN P.PermissionPointID IS NULL THEN 0 ELSE 1 END AS bit) IsSelected
FROM dbo.TDADEmployee E
LEFT JOIN dbo.TDADOrganizationUnit DP ON DP.OrgUnitID=E.DepartmentOrgUnitID
LEFT JOIN dbo.TDADUserPermissionPoint P
  ON P.EmployeeID=E.EmployeeID AND P.ProjectID=@project AND P.CompanyID=@company
 AND P.MenuCode=@menu AND P.PermissionPointCode=@point AND P.IsActive=1 AND P.IsAllowed=1
WHERE E.CompanyID=@company AND E.IsActive=1
ORDER BY E.EmployeeCode,E.FullName;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@project", SqlDbType.BigInt, ProjectID()); Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
        Add(cmd, "@menu", SqlDbType.NVarChar, menuCode.Trim(), 20); Add(cmd, "@point", SqlDbType.NVarChar, permissionPointCode.Trim(), 80);
        await using var r = await cmd.ExecuteReaderAsync(token);
        var rows = new List<object>();
        while (await r.ReadAsync(token)) rows.Add(new { employeeId=r.GetInt64(0), employeeCode=r.GetString(1), fullName=r.GetString(2), nickName=r.IsDBNull(3)?null:r.GetString(3), departmentName=r.IsDBNull(4)?null:r.GetString(4), isSelected=r.GetBoolean(5) });
        return Ok(rows);
    }

    public sealed record SaveRequest(string MenuCode, string PermissionPointCode, List<long> EmployeeIds);

    [HttpPut("employees")]
    public async Task<IActionResult> SaveEmployees(SaveRequest request, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            await using (var clear = new SqlCommand("DELETE FROM dbo.TDADUserPermissionPoint WHERE ProjectID=@project AND CompanyID=@company AND MenuCode=@menu AND PermissionPointCode=@point", c, tx))
            {
                Add(clear, "@project", SqlDbType.BigInt, ProjectID()); Add(clear, "@company", SqlDbType.BigInt, CompanyID());
                Add(clear, "@menu", SqlDbType.NVarChar, request.MenuCode.Trim(), 20); Add(clear, "@point", SqlDbType.NVarChar, request.PermissionPointCode.Trim(), 80);
                await clear.ExecuteNonQueryAsync(token);
            }
            foreach (var employeeId in request.EmployeeIds.Distinct())
            {
                const string sql = """
INSERT dbo.TDADUserPermissionPoint(ProjectID,PartnerID,CompanyID,EmployeeID,MenuCode,PermissionPointCode,IsAllowed,IsActive,CreatedBy)
SELECT @project,E.PartnerID,@company,E.EmployeeID,@menu,@point,1,1,@user
FROM dbo.TDADEmployee E WHERE E.EmployeeID=@employee AND E.CompanyID=@company AND E.IsActive=1;
""";
                await using var cmd = new SqlCommand(sql, c, tx);
                Add(cmd, "@project", SqlDbType.BigInt, ProjectID()); Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@employee", SqlDbType.BigInt, employeeId);
                Add(cmd, "@menu", SqlDbType.NVarChar, request.MenuCode.Trim(), 20); Add(cmd, "@point", SqlDbType.NVarChar, request.PermissionPointCode.Trim(), 80); Add(cmd, "@user", SqlDbType.BigInt, UserID());
                await cmd.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return NoContent();
        }
        catch { await tx.RollbackAsync(token); throw; }
    }

    private async Task<bool> CanAsync(SqlConnection c, string action, CancellationToken token)
    {
        const string sql = "SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@screen AND P.ActionCode=@action) THEN 1 ELSE 0 END AS bit)";
        await using var cmd = new SqlCommand(sql, c); Add(cmd,"@user",SqlDbType.BigInt,UserID()); Add(cmd,"@company",SqlDbType.BigInt,CompanyID()); Add(cmd,"@project",SqlDbType.BigInt,ProjectID()); Add(cmd,"@screen",SqlDbType.NVarChar,ScreenCode,20); Add(cmd,"@action",SqlDbType.NVarChar,action,20);
        return (bool)(await cmd.ExecuteScalarAsync(token) ?? false);
    }
    private long UserID()=>long.TryParse(User.FindFirstValue("user_id"),out var x)?x:0;
    private long CompanyID()=>long.TryParse(User.FindFirstValue("company_id"),out var x)?x:0;
    private long ProjectID()=>long.TryParse(User.FindFirstValue("project_id"),out var x)?x:0;
    private async Task<SqlConnection> OpenAsync(CancellationToken token){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(token);return c;}
    private static void Add(SqlCommand c,string name,SqlDbType type,object value,int size=0){var p=size>0?c.Parameters.Add(name,type,size):c.Parameters.Add(name,type);p.Value=value;}
}
