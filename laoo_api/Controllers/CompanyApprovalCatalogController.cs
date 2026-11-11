using System.Data;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/approval-catalog")]
public sealed class CompanyApprovalCatalogController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");
    private async Task<bool> Can(SqlConnection db,string action,CancellationToken ct) => CompanyId>0 && UserId>0 && await CompanyProjectPermission.IsAllowedAsync(db,User,"10011",action,ct);
    public sealed record CatalogInput(string Code,string Name);
    public sealed record PositionInput(string Code,string UnitScope);
    public sealed record StepInput(string Condition,List<PositionInput> Positions);
    public sealed record ConfigInput(string Type,int? LevelsUp,List<StepInput> Steps,string? LevelOrderMethod);

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,ct);
        if(!await Can(db,"VIEW",ct))return Forbid();
        var canCreate=await Can(db,"CREATE",ct);var canEdit=await Can(db,"EDIT",ct);var canDelete=await Can(db,"DELETE",ct);
        await using var q=new SqlCommand("SELECT PatternCode,PatternName,PatternType,LevelsUp FROM dbo.TDSTApprovalPatternCatalog WHERE CompanyID=@company ORDER BY PatternCode",db);
        q.Parameters.AddWithValue("@company",CompanyId);await using var r=await q.ExecuteReaderAsync(ct);
        var items=new List<object>();while(await r.ReadAsync(ct))items.Add(new {code=r.GetString(0),name=r.GetString(1),type=r.GetString(2),levelsUp=r.IsDBNull(3)?(int?)null:r.GetInt32(3)});
        return Ok(new {items,canCreate,canEdit,canDelete});
    }

    [HttpPost]
    public async Task<IActionResult> Create(CatalogInput input,CancellationToken ct)
    {
        var code=input?.Code?.Trim();var name=input?.Name?.Trim();
        if(string.IsNullOrEmpty(code)||code.Length>50||string.IsNullOrEmpty(name)||name.Length>200)return BadRequest(new {message="กรุณาระบุรหัสและชื่อการอนุมัติให้ครบถ้วน"});
        await using var db=await RegistryControllerSupport.Open(configuration,ct);if(!await Can(db,"CREATE",ct))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        await using var q=new SqlCommand("IF EXISTS(SELECT 1 FROM dbo.TDSTApprovalPatternCatalog WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND PatternCode=@code) SELECT 0 ELSE BEGIN INSERT dbo.TDSTApprovalPatternCatalog(CompanyID,PatternCode,PatternName,UpdateBy) VALUES(@company,@code,@name,@user); SELECT 1 END",db,tx);
        q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@code",code);q.Parameters.AddWithValue("@name",name);q.Parameters.AddWithValue("@user",UserId);
        if(Convert.ToInt32(await q.ExecuteScalarAsync(ct))==0)return Conflict(new {message="รหัสนี้มีอยู่แล้ว"});
        await tx.CommitAsync(ct);return Ok(new {saved=true});
    }

    [HttpPut("{code}")]
    public async Task<IActionResult> Rename(string code,CatalogInput input,CancellationToken ct)
    {
        var name=input?.Name?.Trim();if(string.IsNullOrEmpty(name)||name.Length>200)return BadRequest(new {message="กรุณาระบุชื่อการอนุมัติ"});
        await using var db=await RegistryControllerSupport.Open(configuration,ct);if(!await Can(db,"EDIT",ct))return Forbid();
        await using var q=new SqlCommand("UPDATE dbo.TDSTApprovalPatternCatalog SET PatternName=@name,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND PatternCode=@code",db);
        q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@code",code);q.Parameters.AddWithValue("@name",name);q.Parameters.AddWithValue("@user",UserId);
        return await q.ExecuteNonQueryAsync(ct)==1?Ok(new {saved=true}):NotFound();
    }

    [HttpDelete("{code}")]
    public async Task<IActionResult> Delete(string code,CancellationToken ct)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,ct);if(!await Can(db,"DELETE",ct))return Forbid();
        await using var q=new SqlCommand("DELETE dbo.TDSTApprovalPatternCatalog WHERE CompanyID=@company AND PatternCode=@code",db);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@code",code);
        try { return await q.ExecuteNonQueryAsync(ct)==1?Ok(new {deleted=true}):NotFound(); }
        catch(SqlException ex) when(ex.Number==547) { return Conflict(new {message="ลบไม่ได้ รูปแบบนี้ถูกกำหนดใช้งานกับเมนูแล้ว กรุณาเปลี่ยนรูปแบบของเมนูก่อน"}); }
    }

    [HttpGet("{code}/configuration")]
    public async Task<IActionResult> GetConfig(string code,CancellationToken ct)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,ct);if(!await Can(db,"VIEW",ct))return Forbid();
        const string sql="SELECT PatternType,LevelsUp,LevelOrderMethod,COALESCE((SELECT OrderMethod FROM dbo.TDSTCompanyApprovalLevelOrder WHERE CompanyID=@company),'SEQUENCE') FROM dbo.TDSTApprovalPatternCatalog WHERE CompanyID=@company AND PatternCode=@code; SELECT MasterCode,Name FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterGroupCode=N'008' ORDER BY Seq,Name,MasterCode; SELECT S.StepNo,S.ApprovalCondition,P.PositionCode,P.UnitScope FROM dbo.TDSTApprovalPatternCatalogStep S LEFT JOIN dbo.TDSTApprovalPatternCatalogPosition P ON P.CompanyID=S.CompanyID AND P.PatternCode=S.PatternCode AND P.StepNo=S.StepNo WHERE S.CompanyID=@company AND S.PatternCode=@code ORDER BY S.StepNo,P.PositionCode";
        await using var q=new SqlCommand(sql,db);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@code",code);await using var r=await q.ExecuteReaderAsync(ct);
        if(!await r.ReadAsync(ct))return NotFound();var type=r.GetString(0);var levels=r.IsDBNull(1)?(int?)null:r.GetInt32(1);var orderMethod=r.IsDBNull(2)?r.GetString(3):r.GetString(2);
        await r.NextResultAsync(ct);var positions=new List<object>();while(await r.ReadAsync(ct))positions.Add(new {code=r.GetString(0),name=r.GetString(1)});
        await r.NextResultAsync(ct);var steps=new List<StepResult>();while(await r.ReadAsync(ct)){var n=r.GetInt32(0);if(steps.Count==0||steps[^1].StepNo!=n)steps.Add(new(n,r.GetString(1),[]));if(!r.IsDBNull(2))steps[^1].Positions.Add(new(r.GetString(2),r.GetString(3)));}
        return Ok(new {type,levelsUp=levels,levelOrderMethod=orderMethod,positions,steps});
    }
    public sealed record StepResult(int StepNo,string Condition,List<PositionInput> Positions);

    [HttpPut("{code}/configuration")]
    public async Task<IActionResult> SaveConfig(string code,ConfigInput input,CancellationToken ct)
    {
        if(input is null || (input.LevelOrderMethod is not null && input.LevelOrderMethod is not ("NAME" or "SHORTCODE" or "SEQUENCE")) || input.Type is not ("MANUAL" or "LEVEL" or "POSITION" or "SPECIFIC") || (input.Type=="LEVEL" && (input.LevelsUp is null or <=0)) || input.Steps is null || (input.Type is "POSITION" or "SPECIFIC" && (input.Steps.Count==0 || input.Steps.Any(s=>s is null || s.Condition is not ("ANY" or "ALL") || s.Positions is null || s.Positions.Count==0 || s.Positions.Any(p=>p is null || string.IsNullOrWhiteSpace(p.Code) || p.Code.Length>20 || p.UnitScope is not ("ANY" or "DEPARTMENT" or "DIVISION") || (input.Type=="SPECIFIC" && p.UnitScope!="ANY"))))))
            return BadRequest(new {message="กรุณาระบุรูปแบบและข้อมูลให้ครบถ้วน"});
        var steps=input.Type is "POSITION" or "SPECIFIC" ? input.Steps : [];var codes=steps.SelectMany(s=>s.Positions).Select(p=>p.Code.Trim()).ToList();
        if(codes.Distinct(StringComparer.OrdinalIgnoreCase).Count()!=codes.Count)return BadRequest(new {message="ตำแหน่งงานห้ามซ้ำกันในทุกลำดับ"});
        await using var db=await RegistryControllerSupport.Open(configuration,ct);if(!await Can(db,"EDIT",ct))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        foreach(var position in codes){await using var v=new SqlCommand("SELECT COUNT(*) FROM dbo.TDSTMaster WITH(HOLDLOCK) WHERE OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterGroupCode=N'008' AND MasterCode=@position",db,tx);v.Parameters.AddWithValue("@company",CompanyId);v.Parameters.AddWithValue("@position",position);if(Convert.ToInt32(await v.ExecuteScalarAsync(ct))!=1)return BadRequest(new {message="ไม่พบตำแหน่งงานของบริษัท"});}
        await using(var q=new SqlCommand("UPDATE dbo.TDSTApprovalPatternCatalog SET PatternType=@type,LevelsUp=@levels,LevelOrderMethod=@order,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND PatternCode=@code",db,tx)){q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@code",code);q.Parameters.AddWithValue("@type",input.Type);q.Parameters.AddWithValue("@levels",input.Type=="LEVEL"?input.LevelsUp!.Value:DBNull.Value);q.Parameters.AddWithValue("@order",input.Type=="LEVEL"?(object?)input.LevelOrderMethod ?? DBNull.Value:DBNull.Value);q.Parameters.AddWithValue("@user",UserId);if(await q.ExecuteNonQueryAsync(ct)!=1)return NotFound();}
        await using(var q=new SqlCommand("DELETE dbo.TDSTApprovalPatternCatalogStep WHERE CompanyID=@company AND PatternCode=@code",db,tx)){q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@code",code);await q.ExecuteNonQueryAsync(ct);}
        for(var i=0;i<steps.Count;i++){var step=steps[i];await using(var q=new SqlCommand("INSERT dbo.TDSTApprovalPatternCatalogStep(CompanyID,PatternCode,StepNo,ApprovalCondition) VALUES(@company,@code,@step,@condition)",db,tx)){q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@code",code);q.Parameters.AddWithValue("@step",i+1);q.Parameters.AddWithValue("@condition",step.Condition);await q.ExecuteNonQueryAsync(ct);}foreach(var p in step.Positions){await using var q=new SqlCommand("INSERT dbo.TDSTApprovalPatternCatalogPosition(CompanyID,PatternCode,StepNo,PositionCode,UnitScope) VALUES(@company,@code,@step,@position,@scope)",db,tx);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@code",code);q.Parameters.AddWithValue("@step",i+1);q.Parameters.AddWithValue("@position",p.Code.Trim());q.Parameters.AddWithValue("@scope",p.UnitScope);await q.ExecuteNonQueryAsync(ct);}}
        await tx.CommitAsync(ct);return Ok(new {saved=true});
    }
}
