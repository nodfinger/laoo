using System.Security.Claims;
using System.Security.Cryptography;
using Laoo.Site;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Data.SqlClient;
namespace Laoo.Site.Controllers;

[ApiController,Authorize,Route("api/company/site/files")]
public sealed class SiteFilesController(IConfiguration config,IWebHostEnvironment env) : SiteControllerBase(config)
{
    static readonly Dictionary<string,(string Extension,string Mime)> Formats = new(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"]=(".jpg","image/jpeg"),[".jpeg"]=(".jpg","image/jpeg"),
        [".png"]=(".png","image/png"),[".webp"]=(".webp","image/webp")
    };
    string Root => Path.GetFullPath(Path.Combine(env.ContentRootPath,"uploads","site"));
    string? SafePath(string stored)
    {
        var full=Path.GetFullPath(Path.Combine(env.ContentRootPath,stored.Replace('/',Path.DirectorySeparatorChar)));
        return full.StartsWith(Root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)?full:null;
    }
    static bool ValidImage(byte[] bytes,string ext)=>ext switch
    {
        ".jpg"=>bytes.Length>=3&&bytes[0]==0xFF&&bytes[1]==0xD8&&bytes[2]==0xFF,
        ".png"=>bytes.Length>=8&&bytes.AsSpan(0,8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10}),
        ".webp"=>bytes.Length>=12&&System.Text.Encoding.ASCII.GetString(bytes,0,4)=="RIFF"
            &&System.Text.Encoding.ASCII.GetString(bytes,8,4)=="WEBP",
        _=>false
    };
    static string? Menu(string owner)=>owner.ToUpperInvariant() switch
    {
        "REPORT"=>"63003","ISSUE"=>"63005","HANDOVER"=>"63006",_=>null
    };
    static string? OwnerColumn(string owner)=>owner.ToUpperInvariant() switch
    {
        "REPORT"=>"ReportID","ISSUE"=>"IssueID","HANDOVER"=>"HandoverID",_=>null
    };
    static string? OwnerTable(string owner)=>owner.ToUpperInvariant() switch
    {
        "REPORT"=>"TDSIDailyReport","ISSUE"=>"TDSIIssue","HANDOVER"=>"TDSIHandover",_=>null
    };
    static string[] EditableStatus(string owner)=>owner.ToUpperInvariant() switch
    {
        "REPORT"=>["DRAFT","RETURNED"],"ISSUE"=>["OPEN","IN_PROGRESS","RESOLVED"],
        "HANDOVER"=>["DRAFT","RETURNED"],_=>[]
    };

    [HttpPost]
    [RequestSizeLimit(22_000_000)]
    public async Task<IActionResult> Upload([FromForm] long projectId,[FromForm] string ownerType,
        [FromForm] long ownerId,[FromForm] IFormFile file,CancellationToken ct)
    {
        if(projectId<=0||ownerId<=0||file is null||file.Length<=0)return Invalid("กรุณาเลือกไฟล์ภาพ");
        var menu=Menu(ownerType);var column=OwnerColumn(ownerType);var table=OwnerTable(ownerType);
        if(menu is null||column is null||table is null)return Invalid("ประเภทไฟล์ไม่ถูกต้อง");
        var extension=Path.GetExtension(file.FileName).ToLowerInvariant();
        if(!Formats.TryGetValue(extension,out var format))return Invalid("รองรับ JPG, PNG และ WebP เท่านั้น");
        await using var db=await Open(ct);
        if(await Guard(db,menu,"UPLOAD",ct) is { } no)return no;
        if(!await ProjectInScope(db,projectId,ct))return Missing();
        var max=await SiteDb.Scalar(db,null,"SELECT COALESCE(MAX(MaxPhotoMB),10) FROM dbo.TDSISetting WHERE CompanyID=@c",ct,("@c",Company));
        if(file.Length>max*1024*1024)return Invalid($"ไฟล์เกิน {max} MB");
        // The table/column names are from the fixed server-side allowlist above.
        var count=await SiteDb.Scalar(db,null,$"SELECT COUNT(*) FROM dbo.{table} WHERE CompanyID=@c AND SiteProjectID=@project AND {column}=@id AND StatusCode IN ({string.Join(',',EditableStatus(ownerType).Select((_,i)=>$"@s{i}"))})",
            ct,[("@c",Company),("@project",projectId),("@id",ownerId),.. EditableStatus(ownerType).Select((v,i)=>( $"@s{i}",(object?)v))]);
        if(count==0)return Invalid("รายการไม่อยู่ในสถานะที่แนบภาพได้");
        await using var stream=file.OpenReadStream();
        using var buffer=new MemoryStream();
        await stream.CopyToAsync(buffer,ct);
        var bytes=buffer.ToArray();
        if(bytes.Length>max*1024*1024||!ValidImage(bytes,format.Extension))
            return Invalid("ชนิดหรือขนาดไฟล์ไม่ถูกต้อง");
        var relative=$"uploads/site/{Company}/{projectId}/{Guid.NewGuid():N}{format.Extension}";
        var path=SafePath(relative)!;
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        await System.IO.File.WriteAllBytesAsync(path,bytes,ct);
        try
        {
            var id=await SiteDb.Scalar(db,null,$@"INSERT dbo.TDSIAttachment(CompanyID,SiteProjectID,{column},FileName,StoredPath,MimeType,FileBytes,Sha256,CreatedBy)
VALUES(@c,@project,@owner,@name,@path,@mime,@bytes,@sha,@actor);SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,
                ("@c",Company),("@project",projectId),("@owner",ownerId),
                ("@name",Path.GetFileName(file.FileName)),("@path",relative),("@mime",format.Mime),
                ("@bytes",bytes.LongLength),("@sha",Convert.ToHexString(SHA256.HashData(bytes))),("@actor",Actor));
            return Created($"/api/company/site/files/{id}",new{id,fileName=Path.GetFileName(file.FileName)});
        }
        catch
        {
            System.IO.File.Delete(path);
            throw;
        }
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Download(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(!SiteAccess.Scope(User,out _,out _))return Forbid();
        var rows=await SiteDb.Rows(db,null,@"SELECT SiteProjectID projectId,ReportID reportId,IssueID issueId,
HandoverID handoverId,StoredPath path,MimeType mime,FileName fileName FROM dbo.TDSIAttachment
WHERE CompanyID=@c AND AttachmentID=@id",ct,("@c",Company),("@id",id));
        if(rows.Count==0)return Missing();
        var row=rows[0];var project=Convert.ToInt64(row["projectId"]);
        if(!await ProjectInScope(db,project,ct))return Missing();
        var menu=row["reportId"] is not null?"63003":row["issueId"] is not null?"63005":"63006";
        if(await Guard(db,menu,"DOWNLOAD",ct) is { } no)return no;
        var path=SafePath(Convert.ToString(row["path"])!);
        if(path is null||!System.IO.File.Exists(path))return Missing();
        return File(await System.IO.File.ReadAllBytesAsync(path,ct),Convert.ToString(row["mime"])!,Convert.ToString(row["fileName"])!);
    }
}
