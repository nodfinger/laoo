using Microsoft.Extensions.Configuration;
using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using LaooTrainingModule.Assessments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooTrainingModule.Controllers;

[ApiController, Authorize]
[Route("api/company/training/test-templates/{templateId:long}/images")]
public sealed class TrainingTestTemplateImageController(IConfiguration configuration,IWebHostEnvironment environment) : ControllerBase
{
    const string MenuCode="37003";

    [HttpPost,RequestSizeLimit(1_500_000)]
    public async Task<IActionResult> Upload(long templateId,TemplateImageUpload request,CancellationToken token)
    {
        if(!Scope(out var company,out var user)) return Forbid();
        await using var db=await Open(token); if(!await Can(db,"EDIT",token)) return Forbid();
        if(!await TemplateExists(db,company,templateId,token)) return NotFound();
        byte[] bytes; try { bytes=Convert.FromBase64String(request.Base64??""); }
        catch(FormatException) { return BadRequest(new { message="Invalid image file",description="Choose the image again and retry." }); }
        var type=ExamRules.ImageType(bytes);
        if(type is null) return BadRequest(new { message="Unsupported image file",description="Only JPG, PNG, or WebP up to 1 MB is allowed." });
        var id=Guid.NewGuid(); var file=PathFor(company,templateId,id);
        Directory.CreateDirectory(Path.GetDirectoryName(file)!); await System.IO.File.WriteAllBytesAsync(file,bytes,token);
        try { await using var q=new SqlCommand("INSERT dbo.TDTRTrainingTestTemplateImage(ImageID,CompanyID,TrainingTestTemplateID,ContentType,ByteLength,CreateBy) VALUES(@id,@company,@template,@type,@size,@user)",db);
            Add(q,"@id",SqlDbType.UniqueIdentifier,id); Add(q,"@company",SqlDbType.BigInt,company); Add(q,"@template",SqlDbType.BigInt,templateId); Add(q,"@type",SqlDbType.VarChar,type,20); Add(q,"@size",SqlDbType.Int,bytes.Length); Add(q,"@user",SqlDbType.BigInt,user); await q.ExecuteNonQueryAsync(token); }
        catch { if(System.IO.File.Exists(file)) System.IO.File.Delete(file); throw; }
        return Ok(new { id,contentType=type,byteLength=bytes.Length });
    }

    [HttpGet("{imageId:guid}")]
    public async Task<IActionResult> Get(long templateId,Guid imageId,CancellationToken token)
    {
        if(!Scope(out var company,out _)) return Forbid(); await using var db=await Open(token); if(!await Can(db,"VIEW",token)) return Forbid();
        await using var q=new SqlCommand("SELECT ContentType FROM dbo.TDTRTrainingTestTemplateImage WHERE CompanyID=@company AND TrainingTestTemplateID=@template AND ImageID=@id",db);
        Add(q,"@company",SqlDbType.BigInt,company); Add(q,"@template",SqlDbType.BigInt,templateId); Add(q,"@id",SqlDbType.UniqueIdentifier,imageId);
        var type=await q.ExecuteScalarAsync(token) as string; var file=PathFor(company,templateId,imageId);
        if(type is null||!System.IO.File.Exists(file)) return NotFound(); Response.Headers.CacheControl="no-store";
        return Ok(new { contentType=type,base64=Convert.ToBase64String(await System.IO.File.ReadAllBytesAsync(file,token)) });
    }

    [HttpDelete("{imageId:guid}")]
    public async Task<IActionResult> Delete(long templateId,Guid imageId,CancellationToken token)
    {
        if(!Scope(out var company,out _)) return Forbid(); await using var db=await Open(token); if(!await Can(db,"EDIT",token)) return Forbid();
        await using var q=new SqlCommand("DELETE dbo.TDTRTrainingTestTemplateImage WHERE CompanyID=@company AND TrainingTestTemplateID=@template AND ImageID=@id",db);
        Add(q,"@company",SqlDbType.BigInt,company); Add(q,"@template",SqlDbType.BigInt,templateId); Add(q,"@id",SqlDbType.UniqueIdentifier,imageId);
        if(await q.ExecuteNonQueryAsync(token)==0) return NotFound(); var file=PathFor(company,templateId,imageId); if(System.IO.File.Exists(file)) System.IO.File.Delete(file); return NoContent();
    }

    async Task<bool> TemplateExists(SqlConnection db,long company,long template,CancellationToken token)
    {
        await using var q=new SqlCommand("SELECT COUNT_BIG(*) FROM dbo.TDTRTrainingTestTemplate WHERE CompanyID=@company AND TrainingTestTemplateID=@template",db);
        Add(q,"@company",SqlDbType.BigInt,company); Add(q,"@template",SqlDbType.BigInt,template); return Convert.ToInt64(await q.ExecuteScalarAsync(token))==1;
    }
    Task<bool> Can(SqlConnection db,string action,CancellationToken token)=>CompanyMenuAccess.IsAllowedAsync(db,User,MenuCode,action,token);
    async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    bool Scope(out long company,out long user){company=user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}
    string PathFor(long company,long template,Guid image)=>Path.Combine(environment.ContentRootPath,"App_Data","training-test-templates",company.ToString(),template.ToString(),image.ToString("N"));
    static void Add(SqlCommand q,string name,SqlDbType type,object value,int size=0){var p=size>0?q.Parameters.Add(name,type,size):q.Parameters.Add(name,type);p.Value=value;}
}

public sealed record TemplateImageUpload(string? Base64);
