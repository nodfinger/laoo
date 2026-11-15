using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using SkiaSharp;

namespace LaooGatePassModule.Controllers;

[ApiController, Authorize, Route("api/company/gate-pass/requests/{id:long}/request-files")]
public sealed class GatePassRequestFileController(IConfiguration config,IDataProtectionProvider protection) : ControllerBase
{
    private bool Scope(out long company,out long user){company=0;user=0;return long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&User.FindFirstValue("user_type")=="COMPANY_USER";}
    private async Task<SqlConnection> Open(CancellationToken t){var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));await db.OpenAsync(t);return db;}
    private async Task<bool> Allowed(SqlConnection db,long id,long company,long user,string action,CancellationToken t)
    {
        if (action == "VIEW")
        {
            foreach (var menu in new[] { "38003", "38004", "38005", "38006" })
            {
                if (!await CompanyMenuAccess.IsAllowedAsync(db, User, menu, "VIEW", t)) continue;
                await using var view = new SqlCommand("SELECT COUNT(*) FROM dbo.TDGPGatePass g WHERE g.CompanyID=@company AND g.GatePassID=@id AND (g.RequesterUserID=@user OR g.StatusCode<>N'DRAFT') AND dbo.LaooMenuDataAccessAllowed(@company,@user,g.RequesterUserID,@menu,'VIEW')=1", db);
                view.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
                view.Parameters.Add("@id",SqlDbType.BigInt).Value=id;
                view.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
                view.Parameters.Add("@menu",SqlDbType.NVarChar,20).Value=menu;
                if (Convert.ToInt32(await view.ExecuteScalarAsync(t))==1) return true;
            }
            return false;
        }
        if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"38003",action,t))return false;
        await using var cmd=new SqlCommand("SELECT COUNT(*) FROM dbo.TDGPGatePass WHERE CompanyID=@company AND GatePassID=@id AND RequesterUserID=@user AND (@edit=0 OR StatusCode=N'DRAFT')",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;cmd.Parameters.Add("@edit",SqlDbType.Bit).Value=action!="VIEW";
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(t))==1;
    }
    [HttpGet]
    public async Task<IActionResult> List(long id,CancellationToken t)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);if(!await Allowed(db,id,company,user,"VIEW",t))return Forbid();
        await using var cmd=new SqlCommand("SELECT RequestFileID,GatePassItemID,FileName,ContentType,DATALENGTH(FileData) FROM dbo.TDGPGatePassRequestFile WHERE CompanyID=@company AND GatePassID=@id ORDER BY RequestFileID",db);cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;
        await using var reader=await cmd.ExecuteReaderAsync(t);var files=new List<object>();while(await reader.ReadAsync(t))files.Add(new{id=reader.GetInt64(0),itemId=reader.IsDBNull(1)?null:(long?)reader.GetInt64(1),fileName=reader.GetString(2),contentType=reader.GetString(3),size=Convert.ToInt64(reader.GetValue(4))});return Ok(new{items=files});
    }
    [HttpGet("{fileId:long}")]
    public async Task<IActionResult> Get(long id,long fileId,CancellationToken t)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);if(!await Allowed(db,id,company,user,"VIEW",t))return Forbid();
        await using var cmd=new SqlCommand("SELECT FileData,ContentType,FileName FROM dbo.TDGPGatePassRequestFile WHERE CompanyID=@company AND GatePassID=@id AND RequestFileID=@file",db);cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@file",SqlDbType.BigInt).Value=fileId;await using var reader=await cmd.ExecuteReaderAsync(t);if(!await reader.ReadAsync(t))return NotFound();return Ok(new{base64=Convert.ToBase64String((byte[])reader[0]),contentType=reader.GetString(1),fileName=reader.GetString(2)});
    }
    [HttpPost, RequestSizeLimit(15_000_000)]
    public async Task<IActionResult> Add(long id,RequestFileInput input,CancellationToken t)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);
        var allowed=await Allowed(db,id,company,user,"EDIT",t);
        if(!allowed && !string.IsNullOrWhiteSpace(input.UploadToken) && await CompanyMenuAccess.IsAllowedAsync(db,User,"38003","CREATE",t))
        {
            try
            {
                var value=protection.CreateProtector("Laoo.GatePass.InitialUpload.v1").ToTimeLimitedDataProtector().Unprotect(input.UploadToken);
                if(value==$"{company}:{user}:{id}")
                {
                    await using var owner=new SqlCommand("SELECT COUNT(*) FROM dbo.TDGPGatePass WHERE CompanyID=@company AND GatePassID=@id AND RequesterUserID=@user AND StatusCode=N'DRAFT'",db);
                    owner.Parameters.Add("@company",SqlDbType.BigInt).Value=company;owner.Parameters.Add("@id",SqlDbType.BigInt).Value=id;owner.Parameters.Add("@user",SqlDbType.BigInt).Value=user;
                    allowed=Convert.ToInt32(await owner.ExecuteScalarAsync(t))==1;
                }
            }
            catch(System.Security.Cryptography.CryptographicException) { }
        }
        if(!allowed)return Forbid();
        byte[] bytes;try{bytes=Convert.FromBase64String(input.Base64??"");}catch(FormatException){return BadRequest(new{message="ไฟล์ไม่ถูกต้อง"});}
        if(bytes.Length==0||bytes.Length>10*1024*1024)return BadRequest(new{message="ไฟล์ต้องมีขนาดไม่เกิน 10 MB"});
        var ext=Path.GetExtension(input.FileName??"").ToLowerInvariant();string? type=null;
        if(ext is ".jpg" or ".jpeg" or ".png" or ".webp") { using var data=SKData.CreateCopy(bytes);using var codec=SKCodec.Create(data);if(codec is not null && (long)codec.Info.Width*codec.Info.Height<=50_000_000 && ((ext is ".jpg" or ".jpeg" && codec.EncodedFormat==SKEncodedImageFormat.Jpeg)||(ext==".png" && codec.EncodedFormat==SKEncodedImageFormat.Png)||(ext==".webp" && codec.EncodedFormat==SKEncodedImageFormat.Webp)))type=ext is ".jpg" or ".jpeg"?"image/jpeg":ext==".png"?"image/png":"image/webp"; }
        else if(ext==".pdf" && bytes.AsSpan().StartsWith("%PDF-"u8))type="application/pdf";
        else if(ext is ".docx" or ".xlsx" or ".pptx" && bytes.AsSpan().StartsWith(new byte[]{0x50,0x4b,0x03,0x04}))type="application/octet-stream";
        else if(ext is ".doc" or ".xls" or ".ppt" && bytes.AsSpan().StartsWith(new byte[]{0xd0,0xcf,0x11,0xe0,0xa1,0xb1,0x1a,0xe1}))type="application/octet-stream";
        if(type is null)return BadRequest(new{message="รองรับรูป JPG, PNG, WEBP หรือเอกสาร PDF และ Office ที่ถูกต้อง"});
        var name=Path.GetFileName(input.FileName??"");if(string.IsNullOrWhiteSpace(name)||name.Length>255)return BadRequest(new{message="ชื่อไฟล์ไม่ถูกต้อง"});
        await using var cmd=new SqlCommand("INSERT dbo.TDGPGatePassRequestFile(CompanyID,GatePassID,GatePassItemID,FileName,ContentType,FileData,CreateBy) OUTPUT INSERTED.RequestFileID SELECT @company,@id,@item,@name,@type,@data,@user WHERE @item IS NULL OR EXISTS(SELECT 1 FROM dbo.TDGPGatePassItem WHERE CompanyID=@company AND GatePassID=@id AND GatePassItemID=@item)",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@item",SqlDbType.BigInt).Value=(object?)input.ItemId??DBNull.Value;cmd.Parameters.Add("@name",SqlDbType.NVarChar,255).Value=name;cmd.Parameters.Add("@type",SqlDbType.NVarChar,100).Value=type;cmd.Parameters.Add("@data",SqlDbType.VarBinary,-1).Value=bytes;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=user;var inserted=await cmd.ExecuteScalarAsync(t);return inserted is null?BadRequest(new{message="ไม่พบรายการในใบขอ"}):Ok(new{id=Convert.ToInt64(inserted)});
    }
    [HttpDelete("{fileId:long}")]
    public async Task<IActionResult> Delete(long id,long fileId,CancellationToken t)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(t);if(!await Allowed(db,id,company,user,"EDIT",t))return Forbid();
        await using var cmd=new SqlCommand("DELETE dbo.TDGPGatePassRequestFile WHERE CompanyID=@company AND GatePassID=@id AND RequestFileID=@file",db);cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=company;cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@file",SqlDbType.BigInt).Value=fileId;return await cmd.ExecuteNonQueryAsync(t)==1?NoContent():NotFound();
    }
}
public sealed record RequestFileInput(string? FileName,string? Base64,long? ItemId,string? UploadToken);
