using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Globalization;
using System.Security.Claims;

namespace LaooSapPmsModule;

public sealed class SapPmsModuleMarker { }

[ApiController, Authorize, Route("api/sap-pms")]
public sealed class SapPmsController(IConfiguration configuration) : ControllerBase
{
    [HttpGet("permissions")]
    public async Task<IActionResult> Permissions(CancellationToken token)
    {
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await CompanyMenuAccess.IsAllowedAsync(db, User, "65002", "VIEW", token)) return Forbid();
        await using var command = new SqlCommand("SELECT AllowExport FROM dbo.TDADMainMenu WHERE MenuCode=N'65002' AND ScreenType=3 AND IsActive=1", db);
        var allowed = await command.ExecuteScalarAsync(token);
        var canExport = allowed is bool enabled && enabled && await CompanyMenuAccess.IsAllowedAsync(db, User, "65002", "EXPORT", token);
        return Ok(new { canExport });
    }

    private bool TryScope(out long company, out long user)
    {
        company=0; user=0;
        return User.FindFirstValue("user_type")=="COMPANY_USER" && long.TryParse(User.FindFirstValue("company_id"),out company) && company>0 && long.TryParse(User.FindFirstValue("user_id"),out user) && user>0;
    }

    [HttpPost("history"), RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> SaveHistory([FromBody] SapPmsHistoryInput input, CancellationToken token)
    {
        if(!TryScope(out var company,out var user)) return Forbid();
        var pmsName=Path.GetFileName(input.PmsFileName?.Trim() ?? "");var sapName=Path.GetFileName(input.SapFileName?.Trim() ?? "");
        if(string.IsNullOrWhiteSpace(pmsName)||string.IsNullOrWhiteSpace(sapName)||pmsName.Length>255||sapName.Length>255||input.PmsRecordCount<0||input.SapRecordCount<0||input.TotalCount<0||input.NormalCount<0||input.ProblemCount<0||input.WaitingCount<0||(long)input.NormalCount+input.ProblemCount+input.WaitingCount!=input.TotalCount)
            return BadRequest(new {message="ข้อมูลสรุปไม่ถูกต้อง"});
        if(!TryDate(input.DateFrom,out var from)||!TryDate(input.DateTo,out var to)||(from.HasValue&&to.HasValue&&from>to)) return BadRequest(new {message="ช่วงวันที่ไม่ถูกต้อง"});
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);
        if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"65002","VIEW",token))return Forbid();
        await using var command=new SqlCommand("""
INSERT dbo.TDPSComparisonHistory(CompanyID,PmsFileName,PmsRecordCount,SapFileName,SapRecordCount,DateFrom,DateTo,ComparedByUserID,ComparedByEmployeeID,TotalCount,NormalCount,ProblemCount,WaitingCount,ProblemDocumentNumbers)
OUTPUT INSERTED.ComparisonHistoryID
VALUES(@company,@pms,@pmsCount,@sap,@sapCount,@from,@to,@user,(SELECT TOP(1) ue.EmployeeID FROM dbo.TDADUserEmployee ue WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1 ORDER BY ue.UserEmployeeID),@total,@normal,@problem,@waiting,@numbers)
""",db);
        command.Parameters.Add("@company",SqlDbType.BigInt).Value=company;command.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
        command.Parameters.Add("@pms",SqlDbType.NVarChar,255).Value=pmsName;command.Parameters.Add("@sap",SqlDbType.NVarChar,255).Value=sapName;
        command.Parameters.Add("@pmsCount",SqlDbType.Int).Value=input.PmsRecordCount;command.Parameters.Add("@sapCount",SqlDbType.Int).Value=input.SapRecordCount;
        command.Parameters.Add("@from",SqlDbType.Date).Value=from is null?DBNull.Value:from.Value;command.Parameters.Add("@to",SqlDbType.Date).Value=to is null?DBNull.Value:to.Value;
        command.Parameters.Add("@total",SqlDbType.Int).Value=input.TotalCount;command.Parameters.Add("@normal",SqlDbType.Int).Value=input.NormalCount;command.Parameters.Add("@problem",SqlDbType.Int).Value=input.ProblemCount;command.Parameters.Add("@waiting",SqlDbType.Int).Value=input.WaitingCount;
        command.Parameters.Add("@numbers",SqlDbType.NVarChar,-1).Value=string.IsNullOrWhiteSpace(input.ProblemDocumentNumbers)?DBNull.Value:input.ProblemDocumentNumbers.Trim();
        var id=Convert.ToInt64(await command.ExecuteScalarAsync(token));return Ok(new {historyId=id});
    }

    [HttpGet("history")]
    public async Task<IActionResult> History([FromQuery] int page=1, [FromQuery] int pageSize=30, CancellationToken token=default)
    {
        if(!TryScope(out var company,out var user))return Forbid();
        page=Math.Clamp(page,1,10000000);pageSize=Math.Clamp(pageSize,1,100);
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);
        if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"65002","VIEW",token))return Forbid();
        const string scope="h.CompanyID=@company AND (NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'65002' AND AllowDataAccessSettings=1) OR dbo.LaooMenuDataAccessAllowed(@company,@user,h.ComparedByUserID,N'65002',N'VIEW')=1)";
        await using var command=new SqlCommand($"""
SELECT h.ComparisonHistoryID,h.PmsFileName,h.PmsRecordCount,h.SapFileName,h.SapRecordCount,h.DateFrom,h.DateTo,h.ComparedAt,h.TotalCount,h.NormalCount,h.ProblemCount,h.WaitingCount,h.ProblemDocumentNumbers,e.FullName,e.NickName,u.DisplayName,u.Username,s.EmployeeNameDisplay
FROM dbo.TDPSComparisonHistory h
LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=h.CompanyID AND e.EmployeeID=h.ComparedByEmployeeID
LEFT JOIN dbo.TDADUser u ON u.CompanyID=h.CompanyID AND u.UserID=h.ComparedByUserID
OUTER APPLY (SELECT TOP(1) EmployeeNameDisplay FROM dbo.TDSTCompanySetUp WHERE CompanyID=h.CompanyID AND OwnerType='C' AND IsActive=1) s
WHERE {scope} ORDER BY h.ComparedAt DESC,h.ComparisonHistoryID DESC OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;
SELECT COUNT_BIG(1) FROM dbo.TDPSComparisonHistory h WHERE {scope};
""",db);
        command.Parameters.Add("@company",SqlDbType.BigInt).Value=company;command.Parameters.Add("@user",SqlDbType.BigInt).Value=user;command.Parameters.Add("@skip",SqlDbType.Int).Value=(page-1)*pageSize;command.Parameters.Add("@take",SqlDbType.Int).Value=pageSize;
        var items=new List<object>();long total=0;await using var r=await command.ExecuteReaderAsync(token);
        while(await r.ReadAsync(token)) {
            string Read(int index)=>r.IsDBNull(index)?"":r.GetString(index).Trim();
            var full=Read(13);var nick=Read(14);var mode=Read(17).ToUpperInvariant();
            var name=mode=="NICK"&&nick.Length>0?nick:mode=="BOTH"&&full.Length>0&&nick.Length>0?$"{full} ({nick})":full.Length>0?full:nick.Length>0?nick:Read(15).Length>0?Read(15):Read(16).Length>0?Read(16):"-";
            items.Add(new {historyId=r.GetInt64(0),pmsFileName=r.GetString(1),pmsRecordCount=r.GetInt32(2),sapFileName=r.GetString(3),sapRecordCount=r.GetInt32(4),dateFrom=r.IsDBNull(5)?null:r.GetDateTime(5).ToString("yyyy-MM-dd",CultureInfo.InvariantCulture),dateTo=r.IsDBNull(6)?null:r.GetDateTime(6).ToString("yyyy-MM-dd",CultureInfo.InvariantCulture),comparedAt=DateTime.SpecifyKind(r.GetDateTime(7),DateTimeKind.Utc),totalCount=r.GetInt32(8),normalCount=r.GetInt32(9),problemCount=r.GetInt32(10),waitingCount=r.GetInt32(11),problemDocumentNumbers=Read(12),employeeName=name});
        }
        if(await r.NextResultAsync(token)&&await r.ReadAsync(token))total=r.GetInt64(0);
        return Ok(new {items,total,page,pageSize});
    }

    private static bool TryDate(string? raw,out DateTime? value)
    {
        value=null;if(string.IsNullOrWhiteSpace(raw))return true;
        if(!DateTime.TryParseExact(raw,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out var date)||date.Year is <1900 or >2100)return false;
        value=date.Date;return true;
    }
}

public sealed class SapPmsHistoryInput
{
    public string? PmsFileName { get; init; }
    public int PmsRecordCount { get; init; }
    public string? SapFileName { get; init; }
    public int SapRecordCount { get; init; }
    public string? DateFrom { get; init; }
    public string? DateTo { get; init; }
    public int TotalCount { get; init; }
    public int NormalCount { get; init; }
    public int ProblemCount { get; init; }
    public int WaitingCount { get; init; }
    public string? ProblemDocumentNumbers { get; init; }
}
