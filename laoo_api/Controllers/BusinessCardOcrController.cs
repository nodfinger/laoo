using System.Data;
using System.Diagnostics;
using Laoo.Shared.Contracts;
using LaooApi.Ocr;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/ocr/business-cards")]
public sealed class BusinessCardOcrController(IConfiguration configuration, IBusinessCardOcr engine,
    ILogger<BusinessCardOcrController> logger) : ControllerBase
{
    private long Company => long.TryParse(User.FindFirst("company_id")?.Value, out var id) ? id : 0;
    private long Actor => long.TryParse(User.FindFirst("user_id")?.Value, out var id) ? id : 0;
    private async Task<SqlConnection> Open(CancellationToken token)
    { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private static string? Menu(string target) => target switch { "customers" => "09001", "contacts" => "55002", "visitors" => "31002", _ => null };
    private async Task<bool> Allowed(SqlConnection c, string menu, string action, CancellationToken token)
    {
        if (!await CompanyMenuAccess.IsAllowedAsync(c, User, menu, action, token)) return false;
        using var q = new SqlCommand("SELECT ScreenType FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1", c);
        q.Parameters.AddWithValue("@menu", menu);
        var type = Convert.ToInt32(await q.ExecuteScalarAsync(token));
        return action == "VIEW" || (action == "EDIT" ? type is 1 or 2 or 4 : type is 1 or 4);
    }
    private async Task<OcrSettings> Setting(SqlConnection c, CancellationToken token)
    {
        using var q = new SqlCommand("SELECT IsEnabled,MaxImageSizeMB,TimeoutSeconds FROM dbo.TDSTBusinessCardOcrSetting WHERE CompanyID=@company", c);
        q.Parameters.AddWithValue("@company", Company);
        using var r = await q.ExecuteReaderAsync(token);
        return await r.ReadAsync(token) ? new(r.GetBoolean(0),r.GetInt32(1),r.GetInt32(2)) : new(true,10,30);
    }
    [HttpGet("settings/actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        using var c=await Open(token);
        if(!await Allowed(c,"55001","VIEW",token)) return Forbid();
        return Ok(new { view=true, edit=await Allowed(c,"55001","EDIT",token) });
    }
    [HttpGet("settings")]
    public async Task<IActionResult> GetSettings(CancellationToken token)
    {
        using var c=await Open(token);
        if(!await Allowed(c,"55001","VIEW",token)) return Forbid();
        var s=await Setting(c,token);
        return Ok(new { s.IsEnabled,s.MaxImageSizeMB,s.TimeoutSeconds, engineAvailable=engine.IsAvailable });
    }
    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(OcrSettings settings,CancellationToken token)
    {
        using var c=await Open(token);
        if(!await Allowed(c,"55001","EDIT",token)) return Forbid();
        if(settings.MaxImageSizeMB is <1 or >10 || settings.TimeoutSeconds is <5 or >120)
            return BadRequest(new {message="ค่าตั้งค่า OCR ไม่ถูกต้อง",description="ขนาดภาพ 1–10 MB และเวลาประมวลผล 5–120 วินาที"});
        using var tx=c.BeginTransaction(IsolationLevel.Serializable);
        using var q=new SqlCommand("""
UPDATE dbo.TDSTBusinessCardOcrSetting WITH(UPDLOCK,HOLDLOCK)
SET IsEnabled=@enabled,MaxImageSizeMB=@size,TimeoutSeconds=@timeout,UpdateDate=SYSUTCDATETIME(),UpdateBy=@actor WHERE CompanyID=@company;
IF @@ROWCOUNT=0 INSERT dbo.TDSTBusinessCardOcrSetting(CompanyID,IsEnabled,MaxImageSizeMB,TimeoutSeconds,UpdateBy)
VALUES(@company,@enabled,@size,@timeout,@actor);
""",c,tx);
        q.Parameters.AddWithValue("@company",Company);q.Parameters.AddWithValue("@actor",Actor);
        q.Parameters.AddWithValue("@enabled",settings.IsEnabled);q.Parameters.AddWithValue("@size",settings.MaxImageSizeMB);q.Parameters.AddWithValue("@timeout",settings.TimeoutSeconds);
        await q.ExecuteNonQueryAsync(token);await tx.CommitAsync(token);return Ok(settings);
    }
    [HttpGet("capabilities")]
    public async Task<IActionResult> Capabilities(string target,string action="CREATE",CancellationToken token=default)
    {
        using var c=await Open(token);var menu=Menu(target);
        if(menu is null || action is not ("CREATE" or "EDIT") || !await Allowed(c,menu,action,token))return Forbid();
        var s=await Setting(c,token);return Ok(new{s.IsEnabled,s.MaxImageSizeMB,s.TimeoutSeconds,engineAvailable=engine.IsAvailable});
    }
    [HttpPost("analyze"),RequestSizeLimit(11*1024*1024)]
    public async Task<IActionResult> Analyze(IFormFile? file,[FromForm]string target,[FromForm]string action="CREATE",[FromForm]long? recordId=null,CancellationToken token=default)
    {
        using var c=await Open(token);var menu=Menu(target);
        if(menu is null || action is not ("CREATE" or "EDIT") || !await Allowed(c,menu,action,token))return Forbid();
        if(recordId.HasValue)
        {
            var scope=target switch{
                "customers"=>"SELECT COUNT(1) FROM dbo.TDARCustomer WHERE CompanyID=@company AND CustomerID=@id",
                "contacts"=>"SELECT COUNT(1) FROM dbo.TDADContact WHERE CompanyID=@company AND ContactID=@id AND IsDeleted=0",
                _=>"SELECT 0"};
            using var own=new SqlCommand(scope,c);own.Parameters.AddWithValue("@company",Company);own.Parameters.AddWithValue("@id",recordId.Value);
            if(Convert.ToInt32(await own.ExecuteScalarAsync(token))!=1)return Forbid();
        }
        var settings=await Setting(c,token);
        if(!settings.IsEnabled)return StatusCode(409,new{message="ปิดใช้งาน OCR อยู่",description="ให้ผู้ดูแลเปิดใช้งานในหน้าตั้งค่า OCR นามบัตร"});
        if(file is null || file.Length==0 || file.Length>settings.MaxImageSizeMB*1024L*1024)
            return BadRequest(new{message="รูปนามบัตรไม่ถูกต้อง",description=$"เลือกภาพขนาดไม่เกิน {settings.MaxImageSizeMB} MB"});
        var extension=Path.GetExtension(file.FileName).ToLowerInvariant();
        if(extension is not (".jpg" or ".jpeg" or ".png" or ".webp"))
            return BadRequest(new{message="ชนิดภาพไม่รองรับ",description="เลือก JPG, PNG หรือ WebP"});
        var watch=Stopwatch.StartNew();var code="SUCCESS";var words=0;
        try
        {
            using var memory=new MemoryStream();await file.CopyToAsync(memory,token);
            var png=BusinessCardImage.Normalize(memory.ToArray());
            var result=await engine.ReadAsync(png,settings.TimeoutSeconds,token);words=result.Words.Count;
            if(words==0)code="EMPTY";
            return Ok(new{result.Text,result.Words,result.Suggestions,needsReview=true,engine="Tesseract",empty=words==0});
        }
        catch(OcrFailure e)
        {
            code=e.Code;
            return StatusCode(e.Code=="BUSY"?429:e.Code=="TIMEOUT"?504:e.Code.StartsWith("ENGINE")?503:400,new{message=e.Message,description=e.Description,code=e.Code});
        }
        catch(OperationCanceledException){code="CANCELLED";throw;}
        catch(Exception e)
        {
            code="ERROR";
            logger.LogError(e,"Business card OCR failed for company {Company}",Company);
            return StatusCode(503,new{message="อ่านนามบัตรไม่สำเร็จ",description="เครื่องมือประมวลผลไม่พร้อม ให้ผู้ดูแลตรวจระบบ OCR แล้วลองใหม่"});
        }
        finally
        {
            // Audit stores no card image, full text, email or phone.
            using var audit=new SqlCommand("INSERT dbo.TDADBusinessCardOcrAudit(CompanyID,UserID,TargetType,ResultCode,DurationMilliseconds,WordCount) VALUES(@company,@user,@target,@code,@duration,@words)",c);
            audit.Parameters.AddWithValue("@company",Company);audit.Parameters.AddWithValue("@user",Actor);audit.Parameters.AddWithValue("@target",target);
            audit.Parameters.AddWithValue("@code",code);audit.Parameters.AddWithValue("@duration",(int)Math.Min(int.MaxValue,watch.ElapsedMilliseconds));audit.Parameters.AddWithValue("@words",words);
            using var deadline=new CancellationTokenSource(TimeSpan.FromSeconds(5));
            try { await audit.ExecuteNonQueryAsync(deadline.Token); }
            catch (Exception e) when (e is SqlException or OperationCanceledException)
            { logger.LogError(e,"Unable to record OCR audit for company {Company}; result {Result}",Company,code); }
        }
    }
    [HttpGet("duplicates")]
    public async Task<IActionResult> Duplicates(string target,string? name,string? phone,string? email,CancellationToken token)
    {
        using var c=await Open(token);var menu=Menu(target);
        if(menu is null || !await Allowed(c,menu,"VIEW",token))return Forbid();
        var sql=target switch
        {
        "customers"=>"""
SELECT TOP(20) CustomerID,CusName,COALESCE(ContName1,N''),COALESCE(Phone1,Phone,N''),COALESCE(Email1,Email,N'')
FROM dbo.TDARCustomer WHERE CompanyID=@company AND
((@name<>N'' AND (CusName=@name OR ContName1=@name OR ContName2=@name))
 OR (@email<>N'' AND (Email=@email OR Email1=@email OR Email2=@email))
 OR (@phone<>N'' AND (REPLACE(REPLACE(Phone1,N'-',N''),N' ',N'')=@phone OR REPLACE(REPLACE(Phone2,N'-',N''),N' ',N'')=@phone OR REPLACE(REPLACE(Phone,N'-',N''),N' ',N'')=@phone)))
ORDER BY CustomerID;
""",
        "contacts"=>"""
SELECT TOP(20) C.ContactID,COALESCE(C.CompanyName,N''),P.FullName,COALESCE(P.Mobile,N''),COALESCE(P.Email,N'')
FROM dbo.TDADContact C JOIN dbo.TDADPerson P ON P.PersonID=C.PersonID AND P.CompanyID=C.CompanyID
WHERE C.CompanyID=@company AND C.IsDeleted=0 AND
((@name<>N'' AND P.FullName=@name) OR (@email<>N'' AND P.Email=@email)
 OR (@phone<>N'' AND REPLACE(REPLACE(P.Mobile,N'-',N''),N' ',N'')=@phone))
ORDER BY C.ContactID;
""",
        _=>"""
SELECT TOP(20) V.VisitorVisitID,N'',V.VisitorName,COALESCE(V.Phone,N''),N''
FROM dbo.TDTMVisitorVisit V
JOIN dbo.TDADBranch B ON B.CompanyID=V.CompanyID AND B.BranchID=V.BranchID AND B.IsActive=1
WHERE V.CompanyID=@company
  AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@company AND U.UserID=@user AND U.IsActive=1 AND U.IsCompanyAdmin=1)
       OR B.AccessModeCode=N'ALL'
       OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@company AND UB.UserID=@user AND UB.BranchID=V.BranchID AND UB.IsActive=1))
  AND ((@name<>N'' AND V.VisitorName=@name)
       OR (@phone<>N'' AND REPLACE(REPLACE(V.Phone,N'-',N''),N' ',N'')=@phone))
ORDER BY V.CheckedInDate DESC,V.VisitorVisitID DESC;
"""
        };
        using var q=new SqlCommand(sql,c);q.Parameters.AddWithValue("@company",Company);
        q.Parameters.AddWithValue("@user",Actor);
        q.Parameters.Add("@name",SqlDbType.NVarChar,250).Value=(name??"").Trim();
        q.Parameters.Add("@email",SqlDbType.NVarChar,320).Value=(email??"").Trim();
        q.Parameters.Add("@phone",SqlDbType.NVarChar,50).Value=(phone??"").Replace("-","").Replace(" ","").Trim();
        var rows=new List<object>();using var r=await q.ExecuteReaderAsync(token);
        while(await r.ReadAsync(token))rows.Add(new{id=r.GetInt64(0),company=r.GetString(1),name=r.GetString(2),phone=r.GetString(3),email=r.GetString(4)});
        return Ok(rows);
    }
}
public sealed record OcrSettings(bool IsEnabled,int MaxImageSizeMB,int TimeoutSeconds);
