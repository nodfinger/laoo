using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Laoo.Shared.Contracts;
using LaooTrainingModule.Assessments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTrainingModule.Controllers;

[ApiController, Authorize]
[Route("api/company/training/test-templates")]
public sealed class TrainingTestTemplateController(IConfiguration configuration,IWebHostEnvironment environment) : ControllerBase
{
    const string Screen = "37003";
    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        if (!Scope(out _, out _)) return Forbid();
        await using var db=await Open(token);
        if (!await Allowed(db,"VIEW",token)) return Forbid();
        return Ok(new { caption="ชุดแบบทดสอบอบรม",screenType=1,view=true,
            create=await Allowed(db,"CREATE",token),edit=await Allowed(db,"EDIT",token),delete=await Allowed(db,"DELETE",token) });
    }
    [HttpGet]
    public async Task<IActionResult> List([FromQuery]string? search,[FromQuery]string? section,[FromQuery]bool? isActive,[FromQuery]int page=1,[FromQuery]int pageSize=30,CancellationToken token=default)
    {
        if (!Scope(out var company,out _)) return Forbid(); await using var db=await Open(token);
        if (!await Allowed(db,"VIEW",token)) return Forbid(); page=Math.Max(1,page);pageSize=Math.Clamp(pageSize,1,100);
        const string where="CompanyID=@company AND (@section IS NULL OR SectionCode=@section) AND (@active IS NULL OR IsActive=@active) AND (TrainingTestTemplateCode LIKE @search OR TrainingTestTemplateName LIKE @search)";
        await using var cmd=new SqlCommand($"""
SELECT TrainingTestTemplateID,TrainingTestTemplateCode,TrainingTestTemplateName,SectionCode,DefinitionJson,VersionNo,IsActive,RowVersion
FROM dbo.TDTRTrainingTestTemplate WHERE {where} ORDER BY TrainingTestTemplateName,TrainingTestTemplateID
OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;
SELECT COUNT_BIG(*) FROM dbo.TDTRTrainingTestTemplate WHERE {where};
""",db);
        Add(cmd,"@company",SqlDbType.BigInt,company);Add(cmd,"@section",SqlDbType.VarChar,Section(section));Add(cmd,"@active",SqlDbType.Bit,isActive);Add(cmd,"@search",SqlDbType.NVarChar,$"%{search?.Trim() ?? ""}%",202);Add(cmd,"@skip",SqlDbType.Int,(page-1)*pageSize);Add(cmd,"@take",SqlDbType.Int,pageSize);
        var items=new List<object>();await using var r=await cmd.ExecuteReaderAsync(token);
        while(await r.ReadAsync(token)){var d=JsonSerializer.Deserialize<ExamDefinition>(r.GetString(4),ExamRules.Json)!;items.Add(new{id=r.GetInt64(0),code=r.GetString(1),name=r.GetString(2),section=r.GetString(3),questionCount=d.QuestionCount,bankCount=d.Questions.Count,passingPercent=d.PassingPercent,isActive=r.GetBoolean(6),versionNo=r.GetInt32(5),rowVersion=Convert.ToBase64String((byte[])r.GetValue(7))});}
        await r.NextResultAsync(token);var total=await r.ReadAsync(token)?r.GetInt64(0):0;return Ok(new{items,total,page,pageSize});
    }
    [HttpGet("{id:long}")]
    public Task<IActionResult> Get(long id,CancellationToken token)=>Read(id,token);
    [HttpPost]
    public Task<IActionResult> Create(TemplateRequest request,CancellationToken token)=>Save(null,request,token);
    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id,TemplateRequest request,CancellationToken token)=>Save(id,request,token);
    [HttpPost("{id:long}/clone")]
    public async Task<IActionResult> Clone(long id,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var db=await Open(token);if(!await Allowed(db,"CREATE",token))return Forbid();
        await using var cmd=new SqlCommand("""
INSERT dbo.TDTRTrainingTestTemplate(CompanyID,TrainingTestTemplateCode,TrainingTestTemplateName,SectionCode,DefinitionJson,VersionNo,IsActive,CreateBy,UpdateBy)
SELECT CompanyID,TrainingTestTemplateCode+N'-COPY-'+CONVERT(nvarchar(10),TrainingTestTemplateID),TrainingTestTemplateName+N' (สำเนา)',SectionCode,DefinitionJson,VersionNo+1,0,@user,@user
FROM dbo.TDTRTrainingTestTemplate WHERE TrainingTestTemplateID=@id AND CompanyID=@company;SELECT SCOPE_IDENTITY();
""",db);
        Add(cmd,"@id",SqlDbType.BigInt,id);Add(cmd,"@company",SqlDbType.BigInt,company);Add(cmd,"@user",SqlDbType.BigInt,user);var result=await cmd.ExecuteScalarAsync(token);return result is null?NotFound():Ok(new{id=Convert.ToInt64(result)});
    }
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,[FromQuery]string? rowVersion,CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();if(!TryRowVersion(rowVersion,out var version))return BadRequest(new{message="ข้อมูลไม่ถูกต้อง",description="ไม่พบข้อมูลเวอร์ชันสำหรับลบรายการ"});await using var db=await Open(token);if(!await Allowed(db,"DELETE",token))return Forbid();
        var images=new List<Guid>();await using var transaction=await db.BeginTransactionAsync(token);
        try{await using(var read=new SqlCommand("SELECT ImageID FROM dbo.TDTRTrainingTestTemplateImage WHERE CompanyID=@company AND TrainingTestTemplateID=@id",db,(SqlTransaction)transaction)){Add(read,"@company",SqlDbType.BigInt,company);Add(read,"@id",SqlDbType.BigInt,id);await using var rows=await read.ExecuteReaderAsync(token);while(await rows.ReadAsync(token))images.Add(rows.GetGuid(0));}
            await using(var removeImages=new SqlCommand("DELETE dbo.TDTRTrainingTestTemplateImage WHERE CompanyID=@company AND TrainingTestTemplateID=@id",db,(SqlTransaction)transaction)){Add(removeImages,"@company",SqlDbType.BigInt,company);Add(removeImages,"@id",SqlDbType.BigInt,id);await removeImages.ExecuteNonQueryAsync(token);}
            await using(var remove=new SqlCommand("DELETE dbo.TDTRTrainingTestTemplate WHERE CompanyID=@company AND TrainingTestTemplateID=@id AND RowVersion=@version",db,(SqlTransaction)transaction)){Add(remove,"@company",SqlDbType.BigInt,company);Add(remove,"@id",SqlDbType.BigInt,id);Add(remove,"@version",SqlDbType.Timestamp,version!);if(await remove.ExecuteNonQueryAsync(token)!=1){await transaction.RollbackAsync(token);return Conflict(new{message="ข้อมูลถูกแก้ไขแล้ว",description="กรุณาโหลดรายการใหม่ก่อนลบ"});}}
            await transaction.CommitAsync(token);
        }catch{await transaction.RollbackAsync(token);throw;}
        foreach(var image in images){var file=ImagePath(company,id,image);if(System.IO.File.Exists(file))System.IO.File.Delete(file);}return NoContent();
    }
    async Task<IActionResult> Read(long id,CancellationToken token){if(!Scope(out var company,out _))return Forbid();await using var db=await Open(token);if(!await Allowed(db,"VIEW",token))return Forbid();await using var c=new SqlCommand("SELECT TrainingTestTemplateID,TrainingTestTemplateCode,TrainingTestTemplateName,SectionCode,DefinitionJson,VersionNo,IsActive,RowVersion FROM dbo.TDTRTrainingTestTemplate WHERE TrainingTestTemplateID=@id AND CompanyID=@company",db);Add(c,"@id",SqlDbType.BigInt,id);Add(c,"@company",SqlDbType.BigInt,company);await using var r=await c.ExecuteReaderAsync(token);if(!await r.ReadAsync(token))return NotFound();return Ok(new{id=r.GetInt64(0),code=r.GetString(1),name=r.GetString(2),section=r.GetString(3),definition=JsonSerializer.Deserialize<ExamDefinition>(r.GetString(4),ExamRules.Json),versionNo=r.GetInt32(5),isActive=r.GetBoolean(6),rowVersion=Convert.ToBase64String((byte[])r.GetValue(7))});}
    async Task<IActionResult> Save(long? id,TemplateRequest request,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();var error=ExamRules.Validate(request.Definition);if(error is not null)return BadRequest(new{message="ข้อมูลข้อสอบไม่ถูกต้อง",description=error});var sec=Section(request.Section);if(sec is null)return BadRequest(new{message="ข้อมูลไม่ถูกต้อง",description="ช่วงแบบทดสอบต้องเป็น PRE หรือ POST"});if(string.IsNullOrWhiteSpace(request.Name)||request.Name.Trim().Length>200)return BadRequest(new{message="ข้อมูลไม่ครบ",description="กรุณาระบุชื่อชุดแบบทดสอบ"});await using var db=await Open(token);if(!await Allowed(db,id is null?"CREATE":"EDIT",token))return Forbid();
        var code=string.IsNullOrWhiteSpace(request.Code)?null:request.Code.Trim().ToUpperInvariant();var json=JsonSerializer.Serialize(request.Definition,ExamRules.Json);
        var sql=id is null
            ? "DECLARE @new bigint;INSERT dbo.TDTRTrainingTestTemplate(CompanyID,TrainingTestTemplateCode,TrainingTestTemplateName,SectionCode,DefinitionJson,IsActive,CreateBy,UpdateBy) VALUES(@company,COALESCE(@code,N'__PENDING_'+CONVERT(nvarchar(36),NEWID())),@name,@section,@json,@active,@user,@user);SET @new=SCOPE_IDENTITY();IF @code IS NULL UPDATE dbo.TDTRTrainingTestTemplate SET TrainingTestTemplateCode=N'TST'+RIGHT(N'000000'+CONVERT(nvarchar(20),@new),6) WHERE TrainingTestTemplateID=@new;SELECT @new;"
            : "UPDATE dbo.TDTRTrainingTestTemplate SET TrainingTestTemplateCode=COALESCE(@code,TrainingTestTemplateCode),TrainingTestTemplateName=@name,SectionCode=@section,DefinitionJson=@json,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE TrainingTestTemplateID=@id AND CompanyID=@company;SELECT @@ROWCOUNT;";
        await using var c=new SqlCommand(sql,db);
        Add(c,"@id",SqlDbType.BigInt,id);Add(c,"@company",SqlDbType.BigInt,company);Add(c,"@user",SqlDbType.BigInt,user);Add(c,"@code",SqlDbType.NVarChar,code,30);Add(c,"@name",SqlDbType.NVarChar,request.Name.Trim(),200);Add(c,"@section",SqlDbType.VarChar,sec);Add(c,"@json",SqlDbType.NVarChar,json);Add(c,"@active",SqlDbType.Bit,request.IsActive);try{var saved=Convert.ToInt64(await c.ExecuteScalarAsync(token));return id is null?Ok(new{id=saved}):saved==1?Ok(new{id}):Conflict();}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสชุดแบบทดสอบซ้ำ",description="กรุณาระบุรหัสใหม่"});}
    }
    async Task<bool> Allowed(SqlConnection db,string action,CancellationToken token)=>await CompanyMenuAccess.IsAllowedAsync(db,User,Screen,action,token);
    async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    bool Scope(out long company,out long user){company=user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}
    static string? Section(string? value)=>value?.Trim().ToUpperInvariant() is "PRE" or "POST" ? value!.Trim().ToUpperInvariant():null;
    static bool TryRowVersion(string? value,out byte[]? version){try{version=string.IsNullOrWhiteSpace(value)?null:Convert.FromBase64String(value);return version is {Length:8};}catch(FormatException){version=null;return false;}}
    string ImagePath(long company,long template,Guid image)=>Path.Combine(environment.ContentRootPath,"App_Data","training-test-templates",company.ToString(),template.ToString(),image.ToString("N"));
    static void Add(SqlCommand c,string n,SqlDbType t,object? v,int s=0){var p=s>0?c.Parameters.Add(n,t,s):c.Parameters.Add(n,t);p.Value=v??DBNull.Value;}
}
public sealed record TemplateRequest(string? Code,string Name,string? Section,ExamDefinition? Definition,bool IsActive=true,string? RowVersion=null);
