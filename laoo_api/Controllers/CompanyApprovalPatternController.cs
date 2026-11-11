using System.Data;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[NonController]
[ApiController, Authorize, Route("api/company/approval-pattern")]
public sealed class CompanyApprovalPatternController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");
    public sealed record PositionRequest(string Code, string UnitScope);
    public sealed record StepRequest(string Condition, List<PositionRequest> Positions);
    public sealed record PatternRequest(int LevelsUp, List<StepRequest> Steps);
    public sealed record LevelsRequest(int LevelsUp);
    public sealed record StepsRequest(List<StepRequest> Steps);

    private Task<bool> Can(SqlConnection c,string menu,string action,CancellationToken t) =>
        CompanyProjectPermission.IsAllowedAsync(c,User,menu,action,t);

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        await using var c=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Can(c,"10011","VIEW",token)) return Forbid();
        var canEdit=await Can(c,"10004","EDIT",token);
        const string sql="""
SELECT LevelsUp FROM dbo.TDSTCompanyApprovalPattern WHERE CompanyID=@company;
SELECT MasterCode,Name FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterGroupCode=N'008' ORDER BY Seq,Name,MasterCode;
SELECT S.StepNo,S.ApprovalCondition,P.PositionCode,P.UnitScope FROM dbo.TDSTCompanyApprovalStep S
LEFT JOIN dbo.TDSTCompanyApprovalPosition P ON P.CompanyID=S.CompanyID AND P.StepNo=S.StepNo
WHERE S.CompanyID=@company ORDER BY S.StepNo,P.PositionCode;
""";
        await using var q=new SqlCommand(sql,c);q.Parameters.AddWithValue("@company",CompanyId);
        await using var r=await q.ExecuteReaderAsync(token);
        var levelsUp=await r.ReadAsync(token)?r.GetInt32(0):1;
        await r.NextResultAsync(token);var positions=new List<object>();
        while(await r.ReadAsync(token))positions.Add(new {code=r.GetString(0),name=r.GetString(1)});
        await r.NextResultAsync(token);var steps=new List<StepResponse>();
        while(await r.ReadAsync(token)) {
            var stepNo=r.GetInt32(0);
            if(steps.Count==0 || steps[^1].StepNo!=stepNo) steps.Add(new(stepNo,r.GetString(1),[]));
            if(!r.IsDBNull(2))steps[^1].Positions.Add(new(r.GetString(2),r.GetString(3)));
        }
        return Ok(new {levelsUp,steps,positions,canEdit});
    }
    public sealed record StepResponse(int StepNo,string Condition,List<PositionRequest> Positions);

    [HttpPut("levels")]
    public async Task<IActionResult> SaveLevels(LevelsRequest request,CancellationToken token)
    {
        if(request is null || request.LevelsUp<=0) return BadRequest(new {message="กรุณาระบุจำนวนระดับเป็นจำนวนเต็มมากกว่า 0"});
        await using var c=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Can(c,"10011","VIEW",token) || !await Can(c,"10004","EDIT",token)) return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        await using var q=new SqlCommand("UPDATE dbo.TDSTCompanyApprovalPattern SET LevelsUp=@levels,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company; IF @@ROWCOUNT=0 INSERT dbo.TDSTCompanyApprovalPattern(CompanyID,LevelsUp,UpdateBy) VALUES(@company,@levels,@user)",c,tx);
        q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);q.Parameters.AddWithValue("@levels",request.LevelsUp);
        await q.ExecuteNonQueryAsync(token);await tx.CommitAsync(token);return Ok(new {saved=true});
    }

    [HttpPut("steps")]
    public async Task<IActionResult> SaveSteps(StepsRequest request,CancellationToken token)
    {
        if(request?.Steps is null || request.Steps.Any(s=>s is null || s.Condition is not ("ANY" or "ALL") || s.Positions is null || s.Positions.Count==0 || s.Positions.Any(p=>p is null || string.IsNullOrWhiteSpace(p.Code) || p.Code.Length>20 || p.UnitScope is not ("ANY" or "DEPARTMENT" or "DIVISION"))))
            return BadRequest(new {message="กรุณาระบุลำดับและตำแหน่งให้ครบถ้วน"});
        var codes=request.Steps.SelectMany(s=>s.Positions).Select(p=>p.Code.Trim()).ToList();
        if(codes.Distinct(StringComparer.OrdinalIgnoreCase).Count()!=codes.Count) return BadRequest(new {message="ตำแหน่งงานซ้ำกัน กรุณาเลือกตำแหน่งไม่ซ้ำในทุกลำดับ"});
        await using var c=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Can(c,"10011","VIEW",token) || !await Can(c,"10004","EDIT",token)) return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        foreach(var code in codes) {
            await using var valid=new SqlCommand("SELECT COUNT(*) FROM dbo.TDSTMaster WITH(HOLDLOCK) WHERE OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterGroupCode=N'008' AND MasterCode=@code",c,tx);
            valid.Parameters.AddWithValue("@company",CompanyId);valid.Parameters.AddWithValue("@code",code);
            if(Convert.ToInt32(await valid.ExecuteScalarAsync(token))!=1)return BadRequest(new {message="ไม่พบตำแหน่งงานของบริษัท กรุณาโหลดข้อมูลใหม่"});
        }
        await using(var q=new SqlCommand("IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanyApprovalPattern WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company) INSERT dbo.TDSTCompanyApprovalPattern(CompanyID,LevelsUp,UpdateBy) VALUES(@company,1,@user); DELETE dbo.TDSTCompanyApprovalStep WHERE CompanyID=@company",c,tx)) {q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);await q.ExecuteNonQueryAsync(token);}
        for(var i=0;i<request.Steps.Count;i++) {
            var step=request.Steps[i];
            await using(var q=new SqlCommand("INSERT dbo.TDSTCompanyApprovalStep(CompanyID,StepNo,ApprovalCondition) VALUES(@company,@step,@condition)",c,tx)) {q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@step",i+1);q.Parameters.AddWithValue("@condition",step.Condition);await q.ExecuteNonQueryAsync(token);}
            foreach(var position in step.Positions) {
                await using var q=new SqlCommand("INSERT dbo.TDSTCompanyApprovalPosition(CompanyID,StepNo,PositionCode,UnitScope) VALUES(@company,@step,@code,@scope)",c,tx);
                q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@step",i+1);q.Parameters.AddWithValue("@code",position.Code.Trim());q.Parameters.AddWithValue("@scope",position.UnitScope);await q.ExecuteNonQueryAsync(token);
            }
        }
        await tx.CommitAsync(token);return Ok(new {saved=true});
    }

    [HttpPut]
    public async Task<IActionResult> Save(PatternRequest request,CancellationToken token)
    {
        if(request is null || request.LevelsUp<=0 || request.Steps is null ||
           request.Steps.Any(s=>s is null || s.Condition is not ("ANY" or "ALL") || s.Positions is null || s.Positions.Count==0 ||
             s.Positions.Any(p=>p is null || string.IsNullOrWhiteSpace(p.Code) || p.Code.Length>20 || p.UnitScope is not ("ANY" or "DEPARTMENT" or "DIVISION"))))
            return BadRequest(new {message="กรุณาระบุจำนวนระดับ ลำดับ และตำแหน่งให้ครบถ้วน"});
        var codes=request.Steps.SelectMany(s=>s.Positions).Select(p=>p.Code.Trim()).ToList();
        if(codes.Distinct(StringComparer.OrdinalIgnoreCase).Count()!=codes.Count)
            return BadRequest(new {message="ตำแหน่งงานซ้ำกัน กรุณาเลือกตำแหน่งไม่ซ้ำในทุกลำดับ"});
        await using var c=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Can(c,"10011","VIEW",token) || !await Can(c,"10004","EDIT",token))return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        foreach(var code in codes) {
            await using var valid=new SqlCommand("SELECT COUNT(*) FROM dbo.TDSTMaster WITH(HOLDLOCK) WHERE OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterGroupCode=N'008' AND MasterCode=@code",c,tx);
            valid.Parameters.AddWithValue("@company",CompanyId);valid.Parameters.AddWithValue("@code",code);
            if(Convert.ToInt32(await valid.ExecuteScalarAsync(token))!=1)return BadRequest(new {message="ไม่พบตำแหน่งงานของบริษัท กรุณาโหลดข้อมูลใหม่"});
        }
        await using(var q=new SqlCommand("UPDATE dbo.TDSTCompanyApprovalPattern SET LevelsUp=@levels,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company; IF @@ROWCOUNT=0 INSERT dbo.TDSTCompanyApprovalPattern(CompanyID,LevelsUp,UpdateBy) VALUES(@company,@levels,@user); DELETE dbo.TDSTCompanyApprovalStep WHERE CompanyID=@company",c,tx)) {
            q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);q.Parameters.AddWithValue("@levels",request.LevelsUp);await q.ExecuteNonQueryAsync(token);
        }
        for(var i=0;i<request.Steps.Count;i++) {
            var step=request.Steps[i];
            await using(var q=new SqlCommand("INSERT dbo.TDSTCompanyApprovalStep(CompanyID,StepNo,ApprovalCondition) VALUES(@company,@step,@condition)",c,tx)) {
                q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@step",i+1);q.Parameters.AddWithValue("@condition",step.Condition);await q.ExecuteNonQueryAsync(token);
            }
            foreach(var position in step.Positions) {
                await using var q=new SqlCommand("INSERT dbo.TDSTCompanyApprovalPosition(CompanyID,StepNo,PositionCode,UnitScope) VALUES(@company,@step,@code,@scope)",c,tx);
                q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@step",i+1);q.Parameters.AddWithValue("@code",position.Code.Trim());q.Parameters.AddWithValue("@scope",position.UnitScope);await q.ExecuteNonQueryAsync(token);
            }
        }
        await tx.CommitAsync(token);return Ok(new {saved=true});
    }
}
