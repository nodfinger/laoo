using System.Data;
using System.Security.Claims;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/service/dashboard")]
public sealed class ServiceDashboardController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] DateOnly? from, [FromQuery] DateOnly? to, CancellationToken token)
    {
        var companyId = ClaimLong("company_id");
        if (companyId <= 0) return Forbid();
        var end = to ?? DateOnly.FromDateTime(DateTime.UtcNow); var start = from ?? end.AddDays(-29);
        if (start > end || end.DayNumber - start.DayNumber > 366) return BadRequest(new { message = "ช่วงวันที่ไม่ถูกต้อง", description = "กรุณาเลือกช่วงเวลาไม่เกิน 366 วัน" });
        await using var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token);
        if (!await ServiceEnabled(c, companyId, token) || !await CompanyProjectPermission.IsAllowedAsync(c, User, "19001", "VIEW", token)) return Forbid();
        return Ok(new { from = start, to = end, statuses = await Statuses(c, companyId, start, end, token), locations = await Rankings(c, companyId, start, end, "COALESCE(NULLIF(LocationSnapshot,N''),N'-')", token), technicians = await Rankings(c, companyId, start, end, "COALESCE(NULLIF(AssignedEmployeeNameSnapshot,N''),N'ยังไม่มอบหมาย')", token) });
    }
    private static async Task<List<object>> Statuses(SqlConnection c,long company,DateOnly from,DateOnly to,CancellationToken t)
    {
        const string sql="SELECT StatusCode,COUNT_BIG(1) FROM dbo.TDADServiceRequest WHERE CompanyID=@company AND IsActive=1 AND RequestDate>=@from AND RequestDate<DATEADD(day,1,@to) GROUP BY StatusCode";
        await using var q=Command(c,sql,company,from,to); var rows=new List<object>(); await using var r=await q.ExecuteReaderAsync(t); while(await r.ReadAsync(t)) rows.Add(new { code=r.GetString(0),total=r.GetInt64(1)}); return rows;
    }
    private static async Task<List<object>> Rankings(SqlConnection c,long company,DateOnly from,DateOnly to,string field,CancellationToken t)
    {
        var sql=$"SELECT TOP(8) {field},COUNT_BIG(1) FROM dbo.TDADServiceRequest WHERE CompanyID=@company AND IsActive=1 AND RequestDate>=@from AND RequestDate<DATEADD(day,1,@to) GROUP BY {field} ORDER BY COUNT_BIG(1) DESC,{field}";
        await using var q=Command(c,sql,company,from,to); var rows=new List<object>(); await using var r=await q.ExecuteReaderAsync(t); while(await r.ReadAsync(t)) rows.Add(new { name=r.GetString(0),total=r.GetInt64(1)}); return rows;
    }
    private static SqlCommand Command(SqlConnection c,string sql,long company,DateOnly from,DateOnly to){var q=new SqlCommand(sql,c); q.Parameters.Add("@company",SqlDbType.BigInt).Value=company; q.Parameters.Add("@from",SqlDbType.Date).Value=from.ToDateTime(TimeOnly.MinValue); q.Parameters.Add("@to",SqlDbType.Date).Value=to.ToDateTime(TimeOnly.MinValue); return q;}
    private static async Task<bool> ServiceEnabled(SqlConnection c,long company,CancellationToken t){const string sql="SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADCompanyProject CP JOIN dbo.TDADProject P ON P.ProjectID=CP.ProjectID AND P.ProjectCode=N'LAOO_SERVICE' AND P.IsActive=1 WHERE CP.CompanyID=@company AND CP.IsActive=1) THEN 1 ELSE 0 END AS bit)"; await using var q=new SqlCommand(sql,c); q.Parameters.Add("@company",SqlDbType.BigInt).Value=company; return Convert.ToBoolean(await q.ExecuteScalarAsync(t));}
    private long ClaimLong(string name)=>long.TryParse(User.FindFirstValue(name),out var value)?value:0;
}
