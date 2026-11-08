using System.Data;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/service/request-subjects")]
public sealed class ServiceRequestSubjectController(IConfiguration configuration) : ControllerBase
{
    private const string Menu = "18002";
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        return Ok(new {
            view = await Allowed(db,"VIEW",token), create = await Allowed(db,"CREATE",token),
            edit = await Allowed(db,"EDIT",token), delete = await Allowed(db,"DELETE",token)
        });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] bool? requiresApproval, CancellationToken token)
    {
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (!await Allowed(db,"VIEW",token)) return Forbid();
        const string sql = """
SELECT SubjectID,SubjectCode,Name,Seq,ShortCode,OwnerType,IsActive,RequiresApproval
FROM dbo.TDADServiceRequestSubject
WHERE OwnerType=N'C' AND OwnerCompanyID=@company
  AND (@search=N'' OR Name LIKE N'%'+@search+N'%' OR ISNULL(ShortCode,N'') LIKE N'%'+@search+N'%')
  AND (@requiresApproval IS NULL OR RequiresApproval=@requiresApproval)
ORDER BY Seq,Name,SubjectID
""";
        await using var q = new SqlCommand(sql, db);
        q.Parameters.Add("@company",SqlDbType.BigInt).Value=CompanyId;
        q.Parameters.Add("@search",SqlDbType.NVarChar,250).Value=(search ?? "").Trim();
        q.Parameters.Add("@requiresApproval",SqlDbType.Bit).Value=requiresApproval.HasValue ? requiresApproval.Value : DBNull.Value;
        await using var reader=await q.ExecuteReaderAsync(token);
        var rows=new List<object>();
        while(await reader.ReadAsync(token)) rows.Add(new {
            id=reader.GetInt64(0),code=reader.GetString(1),name=reader.GetString(2),seq=reader.GetInt32(3),
            shortCode=reader.IsDBNull(4)?null:reader.GetString(4),isShared=reader.GetString(5).Trim()=="L",isActive=reader.GetBoolean(6),requiresApproval=reader.GetBoolean(7)
        });
        return Ok(rows);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] ServiceRequestSubjectInput input,CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(input.Name) || input.Name.Length>500 || input.ShortCode?.Length>100) return BadRequest();
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if (!await Allowed(db,"CREATE",token)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        const string sql="""
DECLARE @next int=(SELECT ISNULL(MAX(TRY_CONVERT(int,SubjectCode)),0)+1 FROM dbo.TDADServiceRequestSubject WITH(UPDLOCK,HOLDLOCK) WHERE OwnerType=N'C' AND OwnerCompanyID=@company);
IF @next>99999 THROW 53611,N'Subject code limit reached',1;
INSERT dbo.TDADServiceRequestSubject(OwnerType,OwnerCompanyID,SubjectCode,Name,Seq,ShortCode,IsActive,RequiresApproval,CreateBy)
VALUES(N'C',@company,RIGHT(N'00000'+CONVERT(nvarchar(5),@next),5),@name,@seq,@short,@active,@requiresApproval,@user);
SELECT CAST(SCOPE_IDENTITY() AS bigint);
""";
        await using var q=new SqlCommand(sql,db,tx); Bind(q,input);
        var id=Convert.ToInt64(await q.ExecuteScalarAsync(token)); await tx.CommitAsync(token);
        return Ok(new {id});
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id,[FromBody] ServiceRequestSubjectInput input,CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(input.Name) || input.Name.Length>500 || input.ShortCode?.Length>100) return BadRequest();
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if (!await Allowed(db,"EDIT",token)) return Forbid();
        const string sql="UPDATE dbo.TDADServiceRequestSubject SET Name=@name,Seq=@seq,ShortCode=@short,IsActive=@active,RequiresApproval=@requiresApproval,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE SubjectID=@id AND OwnerType=N'C' AND OwnerCompanyID=@company";
        await using var q=new SqlCommand(sql,db);Bind(q,input);q.Parameters.Add("@id",SqlDbType.BigInt).Value=id;
        return await q.ExecuteNonQueryAsync(token)==0 ? NotFound() : NoContent();
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if (!await Allowed(db,"DELETE",token)) return Forbid();
        await using var q=new SqlCommand("UPDATE dbo.TDADServiceRequestSubject SET IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE SubjectID=@id AND OwnerType=N'C' AND OwnerCompanyID=@company",db);
        q.Parameters.Add("@id",SqlDbType.BigInt).Value=id;q.Parameters.Add("@company",SqlDbType.BigInt).Value=CompanyId;q.Parameters.Add("@user",SqlDbType.BigInt).Value=UserId;
        return await q.ExecuteNonQueryAsync(token)==0 ? NotFound() : NoContent();
    }

    private Task<bool> Allowed(SqlConnection db,string action,CancellationToken token) => CompanyProjectPermission.IsAllowedAsync(db,User,Menu,action,token);
    private void Bind(SqlCommand q,ServiceRequestSubjectInput input)
    {
        q.Parameters.Add("@company",SqlDbType.BigInt).Value=CompanyId;q.Parameters.Add("@user",SqlDbType.BigInt).Value=UserId;
        q.Parameters.Add("@name",SqlDbType.NVarChar,500).Value=input.Name.Trim();q.Parameters.Add("@seq",SqlDbType.Int).Value=input.Seq;
        q.Parameters.Add("@short",SqlDbType.NVarChar,100).Value=string.IsNullOrWhiteSpace(input.ShortCode)?DBNull.Value:input.ShortCode.Trim();
        q.Parameters.Add("@active",SqlDbType.Bit).Value=input.IsActive;
        q.Parameters.Add("@requiresApproval",SqlDbType.Bit).Value=input.RequiresApproval;
    }
}

public sealed record ServiceRequestSubjectInput(string Name,int Seq,string? ShortCode,bool IsActive,bool RequiresApproval = false);
