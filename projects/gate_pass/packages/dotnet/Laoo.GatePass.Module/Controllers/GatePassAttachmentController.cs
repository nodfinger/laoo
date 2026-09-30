using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using SkiaSharp;

namespace LaooGatePassModule.Controllers;

[ApiController,Authorize,Route("api/company/gate-pass/requests/{id:long}/attachments")]
public sealed class GatePassAttachmentController(
    IConfiguration config,
    IWebHostEnvironment environment) : ControllerBase
{
    private static readonly Dictionary<string,(string Menu,string Action,string Status)> Stages=
        new(StringComparer.OrdinalIgnoreCase){
            ["REQUEST"]=("38003","EDIT","DRAFT"),
            ["HANDOVER"]=("38003","EDIT","APPROVED"),
            ["EXIT"]=("38005","CONFIRM_EXIT","HANDED_OVER"),
            ["RETURN"]=("38006","CONFIRM_RETURN","HANDED_OVER")};

    [HttpGet]
    public async Task<IActionResult> List(long id,CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();
        await using var db=await Open(token);
        if(!await HasAnyView(db,token))return Forbid();
        await using var cmd=new SqlCommand("SELECT GatePassAttachmentID Id,StageCode Stage,OriginalFileName FileName,StoredPath Path,ContentType,FileSizeBytes,Width,Height,CreateDate FROM dbo.TDGPGatePassAttachment WHERE CompanyID=@company AND GatePassID=@id ORDER BY CreateDate",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;
        await using var reader=await cmd.ExecuteReaderAsync(token);var items=new List<object>();
        while(await reader.ReadAsync(token))items.Add(new{id=reader.GetInt64(0),stage=reader.GetString(1),fileName=reader.GetString(2),path=reader.GetString(3),contentType=reader.GetString(4),fileSizeBytes=reader.GetInt64(5),width=reader.IsDBNull(6)?null:(int?)reader.GetInt32(6),height=reader.IsDBNull(7)?null:(int?)reader.GetInt32(7),createDate=reader.GetDateTime(8)});
        return Ok(new{items});
    }

    [HttpDelete("{attachmentId:long}")]
    public async Task<IActionResult> Delete(long id,long attachmentId,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();
        await using var db=await Open(token);
        await using var lookup=new SqlCommand("SELECT a.StageCode,a.StoredPath,g.StatusCode,g.RequesterUserID FROM dbo.TDGPGatePassAttachment a INNER JOIN dbo.TDGPGatePass g ON g.CompanyID=a.CompanyID AND g.GatePassID=a.GatePassID WHERE a.CompanyID=@company AND a.GatePassID=@id AND a.GatePassAttachmentID=@attachment",db);
        lookup.Parameters.Add("@company",SqlDbType.BigInt).Value=company;lookup.Parameters.Add("@id",SqlDbType.BigInt).Value=id;lookup.Parameters.Add("@attachment",SqlDbType.BigInt).Value=attachmentId;
        await using var reader=await lookup.ExecuteReaderAsync(token);
        if(!await reader.ReadAsync(token))return NotFound(Problem("ไม่พบรูปภาพ","ไม่พบไฟล์แนบในใบขอนี้"));
        var stage=reader.GetString(0);var relative=reader.GetString(1);var status=reader.GetString(2);var requester=reader.GetInt64(3);await reader.CloseAsync();
        if(!Stages.TryGetValue(stage,out var rule)||!await CompanyMenuAccess.IsAllowedAsync(db,User,rule.Menu,rule.Action,token))return Forbid();
        if(status!=rule.Status||(stage=="REQUEST"&&requester!=user))return Conflict(Problem("ลบรูปไม่ได้","สถานะเอกสารเปลี่ยนไปแล้ว จึงไม่สามารถลบรูปในขั้นตอนนี้ได้"));
        await using var remove=new SqlCommand("DELETE dbo.TDGPGatePassAttachment WHERE CompanyID=@company AND GatePassID=@id AND GatePassAttachmentID=@attachment",db);
        remove.Parameters.Add("@company",SqlDbType.BigInt).Value=company;remove.Parameters.Add("@id",SqlDbType.BigInt).Value=id;remove.Parameters.Add("@attachment",SqlDbType.BigInt).Value=attachmentId;
        if(await remove.ExecuteNonQueryAsync(token)!=1)return Conflict(Problem("ลบรูปไม่ได้","ข้อมูลไฟล์แนบถูกเปลี่ยนแปลง กรุณาลองใหม่"));
        var full=SafePath(relative);if(full is not null&&System.IO.File.Exists(full))System.IO.File.Delete(full);
        return NoContent();
    }

    [HttpPost("{stage}")]
    [RequestSizeLimit(26_214_400)]
    public async Task<IActionResult> Upload(long id,string stage,IFormFile? file,CancellationToken token)
    {
        if(file is null||file.Length==0)return BadRequest(Problem("ไม่พบรูปภาพ","กรุณาเลือกรูป JPG, PNG หรือ WEBP"));
        if(file.Length>25*1024*1024)return BadRequest(Problem("ไฟล์ต้นฉบับใหญ่เกินไป","ไฟล์ก่อนย่อต้องไม่เกิน 25 MB"));
        if(!Stages.TryGetValue(stage,out var rule))return BadRequest(Problem("ประเภทเอกสารไม่ถูกต้อง","รองรับ REQUEST, HANDOVER, EXIT และ RETURN"));
        stage=stage.ToUpperInvariant();
        if(!Scope(out var company,out var user))return Forbid();
        await using var db=await Open(token);
        if(!await CompanyMenuAccess.IsAllowedAsync(db,User,rule.Menu,rule.Action,token))return Forbid();
        await using var access=new SqlCommand("SELECT g.StatusCode,g.RequesterUserID,COALESCE(s.IsEnabled,CONVERT(bit,1)),COALESCE(s.MaxAttachmentSizeMB,CONVERT(decimal(6,2),1)),COALESCE(s.MaxAttachmentsPerStage,5),(SELECT COUNT(*) FROM dbo.TDGPGatePassAttachment a WHERE a.CompanyID=g.CompanyID AND a.GatePassID=g.GatePassID AND a.StageCode=@stage) FileCount FROM dbo.TDGPGatePass g LEFT JOIN dbo.TDGPSetting s ON s.CompanyID=g.CompanyID WHERE g.CompanyID=@company AND g.GatePassID=@id",db);
        access.Parameters.Add("@company",SqlDbType.BigInt).Value=company;access.Parameters.Add("@id",SqlDbType.BigInt).Value=id;access.Parameters.Add("@stage",SqlDbType.NVarChar,20).Value=stage;
        await using var reader=await access.ExecuteReaderAsync(token);
        if(!await reader.ReadAsync(token))return NotFound(Problem("ไม่พบเอกสาร","ไม่พบใบขอในบริษัทนี้"));
        var status=reader.GetString(0);var requester=reader.GetInt64(1);var enabled=reader.GetBoolean(2);var maxMb=reader.GetDecimal(3);var maxCount=reader.GetInt32(4);var count=reader.GetInt32(5);await reader.CloseAsync();
        if(!enabled)return Conflict(Problem("ระบบปิดใช้งาน","ไม่สามารถแนบรูปได้ในขณะนี้"));
        if(status!=rule.Status||(stage=="REQUEST"&&requester!=user))return Conflict(Problem("แนบรูปไม่ได้","สถานะเอกสารหรือผู้ดำเนินการไม่ตรงกับขั้นตอน"));
        if(count>=maxCount)return Conflict(Problem("จำนวนรูปครบแล้ว",$"แนบได้ไม่เกิน {maxCount} รูปต่อขั้นตอน"));
        var processed=await Process(file,(long)(maxMb*1024*1024),token);
        if(processed.Error is not null)return BadRequest(Problem("รูปภาพไม่ถูกต้อง",processed.Error));
        var relative=$"uploads/gate-pass/{company}/{id}/{stage.ToLowerInvariant()}-{Guid.NewGuid():N}{processed.Extension}";
        var full=SafePath(relative);if(full is null)return StatusCode(500,Problem("บันทึกรูปไม่ได้","ตำแหน่งจัดเก็บไฟล์ไม่ถูกต้อง"));
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);await System.IO.File.WriteAllBytesAsync(full,processed.Bytes,token);
        try{
            await using var insert=new SqlCommand("INSERT dbo.TDGPGatePassAttachment(CompanyID,GatePassID,StageCode,OriginalFileName,StoredPath,ContentType,FileSizeBytes,Width,Height,CreateBy) OUTPUT INSERTED.GatePassAttachmentID VALUES(@company,@id,@stage,@name,@path,@type,@size,@width,@height,@user)",db);
            insert.Parameters.Add("@company",SqlDbType.BigInt).Value=company;insert.Parameters.Add("@id",SqlDbType.BigInt).Value=id;insert.Parameters.Add("@stage",SqlDbType.NVarChar,20).Value=stage;insert.Parameters.Add("@name",SqlDbType.NVarChar,255).Value=Path.GetFileName(file.FileName);insert.Parameters.Add("@path",SqlDbType.NVarChar,1000).Value=relative;insert.Parameters.Add("@type",SqlDbType.NVarChar,100).Value=processed.ContentType;insert.Parameters.Add("@size",SqlDbType.BigInt).Value=processed.Bytes.LongLength;insert.Parameters.Add("@width",SqlDbType.Int).Value=processed.Width;insert.Parameters.Add("@height",SqlDbType.Int).Value=processed.Height;insert.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
            return Ok(new{id=Convert.ToInt64(await insert.ExecuteScalarAsync(token)),path=relative,fileSizeBytes=processed.Bytes.LongLength});
        }catch{try{System.IO.File.Delete(full);}catch{}throw;}
    }

    private static async Task<Processed> Process(IFormFile file,long maxBytes,CancellationToken token)
    {
        await using var input=new MemoryStream();await file.CopyToAsync(input,token);input.Position=0;
        try{
            var extension=Path.GetExtension(file.FileName).ToLowerInvariant();if(extension is not(".jpg" or ".jpeg" or ".png" or ".webp"))return Processed.Fail("รองรับเฉพาะ JPG, PNG และ WEBP");
            using var encoded=SKData.CreateCopy(input.ToArray());using var codec=SKCodec.Create(encoded);if(codec is null)return Processed.Fail("ไฟล์รูปเสียหรือไม่ใช่รูปภาพที่รองรับ");
            var info=codec.Info;if(info.Width<=0||info.Height<=0||(long)info.Width*info.Height>50_000_000)return Processed.Fail("ความละเอียดรูปสูงเกินกำหนด");
            using var image=new SKBitmap(new SKImageInfo(info.Width,info.Height,SKColorType.Rgba8888,SKAlphaType.Premul));var decode=codec.GetPixels(image.Info,image.GetPixels());if(decode is not(SKCodecResult.Success or SKCodecResult.IncompleteInput))return Processed.Fail("ไฟล์รูปเสียหรือไม่ใช่รูปภาพที่รองรับ");
            if(input.Length<=maxBytes){var type=extension is ".jpg" or ".jpeg"?"image/jpeg":extension==".png"?"image/png":"image/webp";return new(input.ToArray(),type,extension,image.Width,image.Height,null);}
            foreach(var dimension in new[]{2400,2000,1600,1200,900,700,500})
            {
                var scale=Math.Min(1d,Math.Min((double)dimension/image.Width,(double)dimension/image.Height));var width=Math.Max(1,(int)Math.Round(image.Width*scale));var height=Math.Max(1,(int)Math.Round(image.Height*scale));
                using var candidate=image.Resize(new SKImageInfo(width,height,SKColorType.Rgba8888,SKAlphaType.Premul),new SKSamplingOptions(SKFilterMode.Linear,SKMipmapMode.Linear));if(candidate is null)continue;
                foreach(var quality in new[]{88,78,68,58,48,38,30}){using var rendered=SKImage.FromBitmap(candidate);using var output=rendered.Encode(SKEncodedImageFormat.Jpeg,quality);var bytes=output.ToArray();if(bytes.LongLength<=maxBytes)return new(bytes,"image/jpeg",".jpg",candidate.Width,candidate.Height,null);}
            }
            return Processed.Fail($"ระบบย่อรูปแล้วแต่ยังเกิน {maxBytes/1024/1024m:0.##} MB");
        }catch{return Processed.Fail("ไฟล์รูปเสียหรือไม่ใช่รูปภาพที่รองรับ");}
    }
    private string? SafePath(string relative){var root=environment.WebRootPath;if(string.IsNullOrWhiteSpace(root))root=Path.Combine(environment.ContentRootPath,"wwwroot");var prefix=Path.GetFullPath(root)+Path.DirectorySeparatorChar;var full=Path.GetFullPath(Path.Combine(root,relative.Replace('/',Path.DirectorySeparatorChar)));return full.StartsWith(prefix,StringComparison.OrdinalIgnoreCase)?full:null;}
    private async Task<bool> HasAnyView(SqlConnection db,CancellationToken token)
    {
        foreach(var menu in new[]{"38003","38004","38005","38006","38007","38008"})
            if(await CompanyMenuAccess.IsAllowedAsync(db,User,menu,"VIEW",token))return true;
        return false;
    }
    private bool Scope(out long company,out long user){company=0;user=0;return long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&User.FindFirstValue("user_type")=="COMPANY_USER";}
    private async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    private static object Problem(string message,string description)=>new{message,description};
    private sealed record Processed(byte[] Bytes,string ContentType,string Extension,int Width,int Height,string? Error){public static Processed Fail(string error)=>new([],string.Empty,string.Empty,0,0,error);}
}
