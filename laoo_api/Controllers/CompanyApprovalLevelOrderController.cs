using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/approval-level-order")]
public sealed class CompanyApprovalLevelOrderController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");
    public sealed record Input(string Method);
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,ct);
        if(CompanyId<=0 || UserId<=0 || !await CompanyProjectPermission.IsAllowedAsync(db,User,"05001","VIEW",ct)) return Forbid();
        await using var q=new SqlCommand("SELECT OrderMethod FROM dbo.TDSTCompanyApprovalLevelOrder WHERE CompanyID=@company",db);
        q.Parameters.AddWithValue("@company",CompanyId);
        return Ok(new {method=(await q.ExecuteScalarAsync(ct) as string) ?? "SEQUENCE"});
    }
    [HttpPut]
    public async Task<IActionResult> Save(Input input,CancellationToken ct)
    {
        if(input?.Method is not ("NAME" or "SHORTCODE" or "SEQUENCE")) return BadRequest(new {message="กรุณาเลือกวิธีจัดระดับตำแหน่ง"});
        await using var db=await RegistryControllerSupport.Open(configuration,ct);
        if(CompanyId<=0 || UserId<=0 || !await CompanyProjectPermission.IsAllowedAsync(db,User,"05001","EDIT",ct)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(System.Data.IsolationLevel.Serializable,ct);
        await using var q=new SqlCommand("UPDATE dbo.TDSTCompanyApprovalLevelOrder WITH (UPDLOCK, HOLDLOCK) SET OrderMethod=@method,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company; IF @@ROWCOUNT=0 INSERT dbo.TDSTCompanyApprovalLevelOrder(CompanyID,OrderMethod,UpdateBy) VALUES(@company,@method,@user)",db,tx);
        q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);q.Parameters.AddWithValue("@method",input.Method);
        await q.ExecuteNonQueryAsync(ct); await tx.CommitAsync(ct);return Ok(new {saved=true});
    }
}
