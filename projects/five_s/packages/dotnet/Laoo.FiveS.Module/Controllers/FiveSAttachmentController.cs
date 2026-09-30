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

namespace LaooFiveSModule.Controllers;

[ApiController,Authorize,Route("api/company/five-s/attachments")]
public sealed class FiveSAttachmentController(IConfiguration config,IWebHostEnvironment environment):ControllerBase
{
 [HttpGet]
 public async Task<IActionResult> List([FromQuery]long? detailId,[FromQuery]long? findingId,CancellationToken t)
 {
  if(!Scope(out var co,out _))return Forbid();if(detailId is null&&findingId is null)return BadRequest();
  await using var c=await Open(t);if(!await AnyView(c,t))return Forbid();
  await using var q=new SqlCommand("SELECT AttachmentID id,StageCode stage,OriginalFileName fileName,StoredPath path,ContentType contentType,FileSizeBytes fileSizeBytes,Width width,Height height,CreateDate createDate FROM dbo.TDFSAttachment WHERE CompanyID=@co AND ((@detail IS NOT NULL AND InspectionDetailID=@detail) OR (@finding IS NOT NULL AND FindingID=@finding)) ORDER BY CreateDate",c);
  Add(q,"@co",SqlDbType.BigInt,co);Add(q,"@detail",SqlDbType.BigInt,detailId);Add(q,"@finding",SqlDbType.BigInt,findingId);await using var r=await q.ExecuteReaderAsync(t);var rows=new List<object>();while(await r.ReadAsync(t))rows.Add(new{id=r.GetInt64(0),stage=r.GetString(1),fileName=r.GetString(2),path=r.GetString(3),contentType=r.GetString(4),fileSizeBytes=r.GetInt64(5),width=r.IsDBNull(6)?null:(int?)r.GetInt32(6),height=r.IsDBNull(7)?null:(int?)r.GetInt32(7),createDate=r.GetDateTime(8)});return Ok(rows);
 }

 [HttpPost("{stage}")]
 [RequestSizeLimit(26_214_400)]
 public async Task<IActionResult> Upload(string stage,[FromForm]long? inspectionDetailId,[FromForm]long? findingId,IFormFile? file,CancellationToken t)
 {
  stage=stage.ToUpperInvariant();if(stage is not("INSPECTION" or "FINDING_BEFORE" or "FINDING_AFTER"))return BadRequest(Problem("ประเภทไฟล์ไม่ถูกต้อง","รองรับรูปผลตรวจ รูปก่อนแก้ และรูปหลังแก้"));
  if(file is null||file.Length==0)return BadRequest(Problem("ไม่พบรูปภาพ","เลือกไฟล์ JPG, PNG หรือ WEBP"));
  if(file.Length>25*1024*1024)return BadRequest(Problem("ไฟล์ต้นฉบับใหญ่เกินไป","ไฟล์ก่อนลดขนาดต้องไม่เกิน 25 MB"));
  if(stage=="INSPECTION"&&inspectionDetailId is null||stage!="INSPECTION"&&findingId is null)return BadRequest(Problem("ข้อมูลอ้างอิงไม่ครบ","ระบุรายการตรวจหรือข้อบกพร่องให้ตรงกับขั้นตอน"));
  if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);var menu=stage=="INSPECTION"?"39005":"39007";if(!await CompanyMenuAccess.IsAllowedAsync(c,User,menu,"EDIT",t))return Forbid();
  await using var access=new SqlCommand("SELECT COALESCE(s.MaxAttachmentSizeMB,1),COALESCE(s.MaxAttachmentsPerItem,5),CASE WHEN @stage=N'INSPECTION' THEN (SELECT COUNT(*) FROM dbo.TDFSInspectionDetail d JOIN dbo.TDFSInspection i ON i.InspectionID=d.InspectionID WHERE d.CompanyID=@co AND d.InspectionDetailID=@detail AND i.StatusCode IN(N'DRAFT',N'IN_PROGRESS',N'RETURNED')) ELSE (SELECT COUNT(*) FROM dbo.TDFSFinding f WHERE f.CompanyID=@co AND f.FindingID=@finding AND f.StatusCode<>N'CLOSED') END,(SELECT COUNT(*) FROM dbo.TDFSAttachment a WHERE a.CompanyID=@co AND a.StageCode=@stage AND ((@detail IS NOT NULL AND a.InspectionDetailID=@detail) OR (@finding IS NOT NULL AND a.FindingID=@finding))) FROM dbo.TDFSSetting s WHERE s.CompanyID=@co",c);
  Add(access,"@co",SqlDbType.BigInt,co);Add(access,"@stage",SqlDbType.NVarChar,stage,20);Add(access,"@detail",SqlDbType.BigInt,inspectionDetailId);Add(access,"@finding",SqlDbType.BigInt,findingId);await using var ar=await access.ExecuteReaderAsync(t);if(!await ar.ReadAsync(t))return Conflict(Problem("ยังไม่ได้ตั้งค่าระบบ","บันทึกค่าระบบ 5ส ก่อนแนบรูป"));var maxMb=ar.GetDecimal(0);var maxCount=ar.GetInt32(1);var valid=ar.GetInt32(2);var count=ar.GetInt32(3);await ar.CloseAsync();if(valid==0)return Conflict(Problem("แนบรูปไม่ได้","รายการไม่อยู่ในบริษัทหรือสถานะไม่อนุญาต"));if(count>=maxCount)return Conflict(Problem("จำนวนรูปครบแล้ว","ลบรูปเดิมก่อนแนบรูปเพิ่ม"));
  var processed=await Process(file,(long)(maxMb*1024*1024),t);if(processed.Error is not null)return BadRequest(Problem("รูปภาพไม่ถูกต้อง",processed.Error));
  var owner=inspectionDetailId??findingId!.Value;var relative=string.Concat("uploads/five-s/",co.ToString(),"/",owner.ToString(),"/",stage.ToLowerInvariant(),"-",Guid.NewGuid().ToString("N"),processed.Extension);var full=SafePath(relative);if(full is null)return StatusCode(500);Directory.CreateDirectory(Path.GetDirectoryName(full)!);await System.IO.File.WriteAllBytesAsync(full,processed.Bytes,t);
  try{await using var q=new SqlCommand("INSERT dbo.TDFSAttachment(CompanyID,InspectionID,InspectionDetailID,FindingID,StageCode,OriginalFileName,StoredPath,ContentType,FileSizeBytes,Width,Height,CreateBy) OUTPUT INSERTED.AttachmentID VALUES(@co,(SELECT InspectionID FROM dbo.TDFSInspectionDetail WHERE CompanyID=@co AND InspectionDetailID=@detail),@detail,@finding,@stage,@name,@path,@type,@size,@width,@height,@user)",c);Add(q,"@co",SqlDbType.BigInt,co);Add(q,"@detail",SqlDbType.BigInt,inspectionDetailId);Add(q,"@finding",SqlDbType.BigInt,findingId);Add(q,"@stage",SqlDbType.NVarChar,stage,20);Add(q,"@name",SqlDbType.NVarChar,Path.GetFileName(file.FileName),255);Add(q,"@path",SqlDbType.NVarChar,relative,1000);Add(q,"@type",SqlDbType.NVarChar,processed.ContentType,100);Add(q,"@size",SqlDbType.BigInt,processed.Bytes.LongLength);Add(q,"@width",SqlDbType.Int,processed.Width);Add(q,"@height",SqlDbType.Int,processed.Height);Add(q,"@user",SqlDbType.BigInt,user);return Ok(new{id=Convert.ToInt64(await q.ExecuteScalarAsync(t)),path=relative,fileSizeBytes=processed.Bytes.LongLength});}catch{try{System.IO.File.Delete(full);}catch{}throw;}
 }

 static async Task<Processed> Process(IFormFile file,long maxBytes,CancellationToken t)
 {
  await using var input=new MemoryStream();await file.CopyToAsync(input,t);var ext=Path.GetExtension(file.FileName).ToLowerInvariant();if(ext is not(".jpg" or ".jpeg" or ".png" or ".webp"))return Processed.Fail("รองรับเฉพาะ JPG, PNG และ WEBP");
  try{var original=input.ToArray();using var encoded=SKData.CreateCopy(original);using var codec=SKCodec.Create(encoded);if(codec is null)return Processed.Fail("ไฟล์เสียหรือไม่ใช่รูปภาพ");var info=codec.Info;if(info.Width<=0||info.Height<=0||(long)info.Width*info.Height>50_000_000)return Processed.Fail("ความละเอียดรูปสูงเกินกำหนด");using var bitmap=new SKBitmap(new SKImageInfo(info.Width,info.Height,SKColorType.Rgba8888,SKAlphaType.Premul));if(codec.GetPixels(bitmap.Info,bitmap.GetPixels()) is not(SKCodecResult.Success or SKCodecResult.IncompleteInput))return Processed.Fail("อ่านรูปภาพไม่ได้");if(original.LongLength<=maxBytes)return new(original,ext is ".jpg" or ".jpeg"?"image/jpeg":ext==".png"?"image/png":"image/webp",ext,bitmap.Width,bitmap.Height,null);foreach(var dimension in new[]{2400,2000,1600,1200,900,700,500}){var scale=Math.Min(1d,Math.Min((double)dimension/bitmap.Width,(double)dimension/bitmap.Height));using var resized=bitmap.Resize(new SKImageInfo(Math.Max(1,(int)(bitmap.Width*scale)),Math.Max(1,(int)(bitmap.Height*scale))),new SKSamplingOptions(SKFilterMode.Linear,SKMipmapMode.Linear));if(resized is null)continue;foreach(var quality in new[]{88,78,68,58,48,38,30}){using var image=SKImage.FromBitmap(resized);using var output=image.Encode(SKEncodedImageFormat.Jpeg,quality);var bytes=output.ToArray();if(bytes.LongLength<=maxBytes)return new(bytes,"image/jpeg",".jpg",resized.Width,resized.Height,null);}}return Processed.Fail("ลดขนาดแล้วแต่ไฟล์ยังเกินค่าที่กำหนด");}catch{return Processed.Fail("ไฟล์เสียหรือไม่ใช่รูปภาพ");}
 }
 string? SafePath(string relative){var root=environment.WebRootPath;if(string.IsNullOrWhiteSpace(root))root=Path.Combine(environment.ContentRootPath,"wwwroot");var prefix=Path.GetFullPath(root)+Path.DirectorySeparatorChar;var full=Path.GetFullPath(Path.Combine(root,relative.Replace('/',Path.DirectorySeparatorChar)));return full.StartsWith(prefix,StringComparison.OrdinalIgnoreCase)?full:null;}
 async Task<bool> AnyView(SqlConnection c,CancellationToken t)=>await CompanyMenuAccess.IsAllowedAsync(c,User,"39005","VIEW",t)||await CompanyMenuAccess.IsAllowedAsync(c,User,"39007","VIEW",t)||await CompanyMenuAccess.IsAllowedAsync(c,User,"39008","VIEW",t);
 bool Scope(out long co,out long user){co=0;user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out co)&&long.TryParse(User.FindFirstValue("user_id"),out user);}
 async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(config.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
 static void Add(SqlCommand q,string name,SqlDbType type,object? value,int size=0){var p=size>0?q.Parameters.Add(name,type,size):q.Parameters.Add(name,type);p.Value=value??DBNull.Value;}
 static object Problem(string message,string description)=>new{message,description};
 sealed record Processed(byte[] Bytes,string ContentType,string Extension,int Width,int Height,string? Error){public static Processed Fail(string error)=>new([],string.Empty,string.Empty,0,0,error);}
}
