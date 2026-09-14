using System.Data;
using System.Security.Claims;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/service/persons")]
[Route("api/service/customers")]
[Route("api/service/residents")]
public sealed partial class ServicePersonController(IConfiguration configuration) : ControllerBase
{
    private string ScreenCode => Request.Path.StartsWithSegments("/api/service/customers") ? "14005" : Request.Path.StartsWithSegments("/api/service/residents") ? "14006" : "14004";
    private long CompanyId => ClaimLong("company_id");

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await InServiceScope(c, token)) return Forbid();
        return Ok(new
        {
            view = await Allowed(c, "VIEW", token),
            create = await Allowed(c, "CREATE", token),
            edit = await Allowed(c, "EDIT", token),
            delete = false,
            personEdit = await CanEditPerson(c, null, token),
        });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] bool? isActive, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken token = default)
    {
        await using var c = await Open(token);
        if (!await InServiceScope(c, token) || !await Allowed(c, "VIEW", token)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 200);
        var query = search?.Trim() ?? string.Empty;
        const string sql = """
SELECT COUNT_BIG(1) OVER(),P.PersonID,P.FullName,P.NickName,P.Email,P.Mobile,P.IsActive,P.RowVersion,
 CAST(CASE WHEN SC.ServiceCustomerID IS NULL THEN 0 ELSE 1 END AS bit),
 CAST(CASE WHEN R.ResidentID IS NULL THEN 0 ELSE 1 END AS bit),SC.RowVersion,R.ResidentID,R.RoomID,R.StartDate,R.EndDate,R.RowVersion
FROM dbo.TDADPerson P
OUTER APPLY(SELECT TOP(1) ServiceCustomerID,RowVersion FROM dbo.TDADServiceCustomer WHERE CompanyID=P.CompanyID AND PersonID=P.PersonID AND IsActive=1) SC
OUTER APPLY(SELECT TOP(1) ResidentID,RoomID,StartDate,EndDate,RowVersion FROM dbo.TDADResident WHERE CompanyID=P.CompanyID AND PersonID=P.PersonID AND IsActive=1 ORDER BY StartDate DESC,ResidentID DESC) R
WHERE P.CompanyID=@company AND (@role=N'CUSTOMER' AND SC.ServiceCustomerID IS NOT NULL OR @role=N'RESIDENT' AND R.ResidentID IS NOT NULL OR @role=N'ANY' AND (SC.ServiceCustomerID IS NOT NULL OR R.ResidentID IS NOT NULL))
 AND (@active IS NULL OR P.IsActive=@active)
 AND (@search=N'' OR P.FullName LIKE @like OR P.NickName LIKE @like OR P.Email LIKE @like OR P.Mobile LIKE @like)
ORDER BY P.FullName,P.PersonID OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@role", SqlDbType.NVarChar, Request.Path.StartsWithSegments("/api/service/customers") ? "CUSTOMER" : Request.Path.StartsWithSegments("/api/service/residents") ? "RESIDENT" : "ANY", 20); Add(cmd, "@active", SqlDbType.Bit, isActive); Add(cmd, "@search", SqlDbType.NVarChar, query, 320); Add(cmd, "@like", SqlDbType.NVarChar, $"%{query}%", 330); Add(cmd, "@offset", SqlDbType.Int, (page - 1) * pageSize); Add(cmd, "@pageSize", SqlDbType.Int, pageSize);
        var items = new List<object>(); long total = 0;
        await using var reader = await cmd.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token)) { total = reader.GetInt64(0); items.Add(Row(reader)); }
        return Ok(new { items, total, page, pageSize });
    }

    private async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private Task<bool> Allowed(SqlConnection c, string action, CancellationToken token) => CompanyProjectPermission.IsAllowedAsync(c, User, ScreenCode, action, token);
    private async Task<bool> InServiceScope(SqlConnection c, CancellationToken token)
    {
        var partner = ClaimLong("partner_id");
        if (CompanyId <= 0 || partner <= 0 || User.FindFirstValue("user_type") != "COMPANY_USER") return false;
        const string sql = "SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDSTCompanySetUp C JOIN dbo.TDADProject P ON P.ProjectCode=N'LAOO_SERVICE' AND P.IsActive=1 JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=P.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1 WHERE C.CompanyID=@company AND C.PartnerID=@partner AND C.IsActive=1 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME())) AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END AS bit);";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", SqlDbType.BigInt, CompanyId); Add(cmd, "@partner", SqlDbType.BigInt, partner); return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }
    private long ClaimLong(string claim) => long.TryParse(User.FindFirstValue(claim), out var value) ? value : 0;
    private static object Row(SqlDataReader r)
    {
        var roles = new List<string>(); if (r.GetBoolean(8)) roles.Add("SERVICE_CUSTOMER"); if (r.GetBoolean(9)) roles.Add("RESIDENT");
        return new { personID = r.GetInt64(1), fullName = r.GetString(2), nickName = Text(r, 3), email = Text(r, 4), mobile = Text(r, 5), isActive = r.GetBoolean(6), personRowVersion = Convert.ToBase64String((byte[])r[7]), serviceRoles = roles, serviceCustomerRowVersion = Bytes(r, 10), residentID = Long(r, 11), roomID = Long(r, 12), startDate = Date(r, 13), endDate = Date(r, 14), residentRowVersion = Bytes(r, 15) };
    }
    private static string? Text(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static long? Long(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static DateTime? Date(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetDateTime(i);
    private static string? Bytes(SqlDataReader r, int i) => r.IsDBNull(i) ? null : Convert.ToBase64String((byte[])r[i]);
    private static void Add(SqlCommand c, string n, SqlDbType t, object? v, int size = 0) { var p = size == 0 ? c.Parameters.Add(n, t) : c.Parameters.Add(n, t, size); p.Value = v ?? DBNull.Value; }
}
