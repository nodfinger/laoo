using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/document-number-formats")]
public sealed class DocumentNumberFormatController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => long.TryParse(User.FindFirstValue("company_id"), out var id) ? id : 0;
    private static readonly HashSet<string> Supported = ["08003", "08005", "09003", "09004", "09005", "09006", "09007", "09009", "09010", "09015", "20001"];
    private static readonly HashSet<string> DateFormats = ["NONE", "yy", "yyyy", "MM", "dd", "MMdd", "yyMM", "yydd", "yyMMdd", "yyyyMM", "yyyydd", "yyyyMMdd"];
    public sealed record FormatUpdate(string MenuCode, string Prefix, string DateFormat, int Digits, string? AfterPrefix, string? BeforeSequence);

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (CompanyId <= 0 || !await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, "LAOO", "05004", "VIEW", token)) return Forbid();
        var canEdit = await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, "LAOO", "05004", "EDIT", token);
        var rows = new List<object>();
        foreach (var code in Supported)
        {
            if (!await CanViewDocument(db, code, token)) continue;
            await using var cmd = new SqlCommand("""
SELECT M.MenuCode,M.MenuName,G.MenuGroupName,COALESCE(F.Prefix,CASE M.MenuCode WHEN N'20001' THEN N'SR' WHEN N'08003' THEN N'IS' WHEN N'08005' THEN N'SR' WHEN N'09004' THEN N'PO' WHEN N'09005' THEN N'TR' WHEN N'09006' THEN N'DN' WHEN N'09007' THEN N'TI' WHEN N'09009' THEN N'PD' WHEN N'09010' THEN N'PI' WHEN N'09015' THEN N'PP' ELSE N'QT' END),COALESCE(F.DateFormat,CASE WHEN M.MenuCode=N'20001' THEN 'yyyyMMdd' ELSE 'NONE' END),COALESCE(F.Digits,3),COALESCE(F.AfterPrefix,N''),COALESCE(F.BeforeSequence,N''),CAST(CASE WHEN F.CompanyID IS NULL THEN 0 ELSE 1 END AS bit)
FROM dbo.TDADMainMenu M JOIN dbo.TDADMenuGroup G ON G.MenuGroupCode=M.MenuGroupCode AND G.IsActive=1
LEFT JOIN dbo.TDADDocumentNumberFormat F ON F.CompanyID=@company AND F.MenuCode=M.MenuCode
WHERE M.MenuCode=@menu AND (M.ScreenType=4 OR (M.MenuCode=N'20001' AND M.ScreenType=1)) AND M.RunData=1 AND M.IsActive=1
""", db);
            cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=CompanyId;
            cmd.Parameters.Add("@menu",SqlDbType.NVarChar,20).Value=code;
            await using var r=await cmd.ExecuteReaderAsync(token);
            if(await r.ReadAsync(token)) rows.Add(new { menuCode=r.GetString(0), name=r.GetString(1), group=r.GetString(2), prefix=r.GetString(3), dateFormat=r.GetString(4), digits=r.GetInt32(5), afterPrefix=r.GetString(6), beforeSequence=r.GetString(7), hasConfig=r.GetBoolean(8) });
        }
        return Ok(new { canEdit, rows });
    }

    [HttpPut]
    public async Task<IActionResult> Save([FromBody] List<FormatUpdate> formats,CancellationToken token)
    {
        if (formats is null || formats.Count>Supported.Count || formats.Select(x=>x.MenuCode).Distinct().Count()!=formats.Count ||
            formats.Any(x=>!Supported.Contains(x.MenuCode) || x.Prefix is null || x.Prefix.Length>12 ||
                x.Prefix.Any(c=>!char.IsAsciiLetterOrDigit(c) && c!='-' && c!='_') ||
                !DateFormats.Contains(x.DateFormat) || x.Digits is <1 or >9 ||
                (x.AfterPrefix?.Length ?? 0)>2 || (x.BeforeSequence?.Length ?? 0)>2 ||
                (x.AfterPrefix ?? "").Any(c=>!"-_/.".Contains(c)) || (x.BeforeSequence ?? "").Any(c=>!"-_/.".Contains(c)) ||
                x.Prefix.Length+(x.AfterPrefix?.Length ?? 0)+(x.DateFormat=="NONE" ? 0 : x.DateFormat.Length)+(x.BeforeSequence?.Length ?? 0)+x.Digits>30))
            return BadRequest(new {message="ไม่สามารถบันทึกรูปแบบเลขที่เอกสาร",description="ตรวจสอบ Prefix รูปแบบวันที่ และจำนวนหลัก แล้วลองใหม่"});
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if(CompanyId<=0 || !await CompanyMenuAccess.IsAllowedForProjectAsync(db,User,"LAOO","05004","EDIT",token)) return Forbid();
        foreach(var row in formats)
            if(!await CanViewDocument(db,row.MenuCode,token)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        foreach(var row in formats)
        {
            await using var cmd=new SqlCommand("""
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND (ScreenType=4 OR (MenuCode=N'20001' AND ScreenType=1)) AND RunData=1 AND IsActive=1) THROW 53925,N'Unsupported document menu.',1;
UPDATE dbo.TDADDocumentNumberFormat WITH (UPDLOCK,SERIALIZABLE) SET Prefix=@prefix,DateFormat=@date,Digits=@digits,AfterPrefix=@after,BeforeSequence=@before,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND MenuCode=@menu;
IF @@ROWCOUNT=0 INSERT dbo.TDADDocumentNumberFormat(CompanyID,MenuCode,Prefix,DateFormat,Digits,AfterPrefix,BeforeSequence) VALUES(@company,@menu,@prefix,@date,@digits,@after,@before);
""",db,tx);
            cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=CompanyId;
            cmd.Parameters.Add("@menu",SqlDbType.NVarChar,20).Value=row.MenuCode;
            cmd.Parameters.Add("@prefix",SqlDbType.NVarChar,12).Value=row.Prefix.ToUpperInvariant();
            cmd.Parameters.Add("@date",SqlDbType.VarChar,8).Value=row.DateFormat;
            cmd.Parameters.Add("@digits",SqlDbType.Int).Value=row.Digits;
            cmd.Parameters.Add("@after",SqlDbType.NVarChar,2).Value=row.AfterPrefix ?? "";
            cmd.Parameters.Add("@before",SqlDbType.NVarChar,2).Value=row.BeforeSequence ?? "";
            await cmd.ExecuteNonQueryAsync(token);
        }
        await tx.CommitAsync(token);
        return NoContent();
    }

    private async Task<bool> CanViewDocument(SqlConnection db,string code,CancellationToken token) =>
        await CompanyMenuAccess.IsAllowedAsync(db,User,code,"VIEW",token) ||
        (code=="20001" && await CompanyMenuAccess.IsAllowedAsync(db,User,"15001","VIEW",token));
}
