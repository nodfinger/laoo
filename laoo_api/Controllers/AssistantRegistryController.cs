using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Laoo.Shared.Contracts;
using LaooApi.Services.Assistant;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/assistant/registry")]
public sealed class AssistantRegistryController(IConfiguration configuration) : ControllerBase
{
    public sealed record UpdateCapability(bool IsEnabled, string? DisplayName, string? Description,
        List<string>? Examples, bool AllowPdf, bool AllowPng, bool AllowHtml, bool AllowEmail);

    [HttpGet("{code}/options")]
    public async Task<IActionResult> Options(string code, CancellationToken token)
    {
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await AssistantCapabilityAccess.IsAllowed(db, User, code, token)) return Forbid();
        await using var cmd = new SqlCommand("SELECT AllowPdf,AllowPng,AllowHtml,AllowEmail FROM dbo.TDADAiCapabilityCompany WHERE CompanyID=@company AND CapabilityCode=@code AND IsEnabled=1", db);
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = AiChatSettingsStore.CompanyId(User)!.Value;
        cmd.Parameters.Add("@code", SqlDbType.NVarChar, 100).Value = code;
        await using var reader = await cmd.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return Ok(new { allowPdf=false, allowPng=false, allowHtml=false, allowEmail=false });
        return Ok(new { allowPdf=reader.GetBoolean(0), allowPng=reader.GetBoolean(1), allowHtml=reader.GetBoolean(2), allowEmail=reader.GetBoolean(3) });
    }

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await Allowed(db,"VIEW",token)) return Forbid();
        const string sql="""
SELECT C.CapabilityCode,C.ProjectCode,COALESCE(NULLIF(CC.DisplayName,N''),C.NameTH),
 COALESCE(CC.DescriptionTH,C.DescriptionTH),ISNULL(CC.IsEnabled,0),CC.ExamplesJson,
 ISNULL(CC.AllowPdf,0),ISNULL(CC.AllowPng,0),ISNULL(CC.AllowHtml,0),ISNULL(CC.AllowEmail,0),
 (SELECT TOP (1) P.ProjectNameTH FROM dbo.TDADProject P WHERE P.ProjectCode=C.ProjectCode ORDER BY P.ProjectID),
 CC.LastApprovedByUsername,CC.LastApprovedAt
FROM dbo.TDADAiCapability C
LEFT JOIN dbo.TDADAiCapabilityCompany CC ON CC.CapabilityCode=C.CapabilityCode AND CC.CompanyID=@company
WHERE C.IsActive=1 ORDER BY C.CapabilityCode
""";
        await using var cmd=new SqlCommand(sql,db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=AiChatSettingsStore.CompanyId(User)!.Value;
        var result=new List<Dictionary<string,object?>>();
        await using var reader=await cmd.ExecuteReaderAsync(token);
        while(await reader.ReadAsync(token))
        {
            var code=reader.GetString(0);
            var capability=AssistantCapabilities.Find(code);
            if(capability is null) continue; // Database metadata can never install executable code.
            var examples=reader.IsDBNull(5) ? Array.Empty<string>() : JsonSerializer.Deserialize<string[]>(reader.GetString(5)) ?? [];
            result.Add(new Dictionary<string, object?> { ["code"]=code, ["projectCode"]=reader.GetString(1),
                ["name"]=reader.GetString(2), ["description"]=reader.GetString(3), ["isEnabled"]=reader.GetBoolean(4),
                ["projectNameTh"]=reader.IsDBNull(10) ? null : reader.GetString(10),
                ["lastApprovedByUsername"]=reader.IsDBNull(11) ? null : reader.GetString(11),
                ["lastApprovedAt"]=reader.IsDBNull(12) ? null : DateTime.SpecifyKind(reader.GetDateTime(12), DateTimeKind.Utc),
                ["examples"]=examples, ["allowPdf"]=reader.GetBoolean(6), ["allowPng"]=reader.GetBoolean(7),
                ["allowHtml"]=reader.GetBoolean(8), ["allowEmail"]=reader.GetBoolean(9), ["menuCode"]=capability.MenuCode,
                ["screenType"]=capability.ScreenType, ["action"]=capability.Action,
                ["agentId"]=AssistantAgentRegistry.All.FirstOrDefault(a=>a.CapabilityIds.Contains(code))?.Id });
        }
        await reader.DisposeAsync();
        foreach (var row in result)
        {
            await using var group = new SqlCommand("SELECT G.MenuGroupName FROM dbo.TDADMainMenu M JOIN dbo.TDADMenuGroup G ON G.MenuGroupCode=M.MenuGroupCode AND G.IsActive=1 WHERE M.MenuCode=@menu AND M.IsActive=1", db);
            group.Parameters.Add("@menu", SqlDbType.VarChar, 20).Value = row["menuCode"]!;
            row["systemName"] = Convert.ToString(await group.ExecuteScalarAsync(token)) ?? "";
        }
        await using var caption = new SqlCommand("SELECT MenuName FROM dbo.TDADMainMenu WHERE MenuCode=N'10008' AND IsActive=1", db);
        return Ok(new { caption = Convert.ToString(await caption.ExecuteScalarAsync(token)) ?? "", rows = result, canEdit = await Allowed(db, "EDIT", token), canManageAccess = await AiCapabilityRoleAccess.CanManage(db, User, token) });
    }

    public sealed record RoleAccessRequest(List<long>? RoleGroupIds, bool UseMenuPermissions = false);

    [HttpGet("{code}/role-access")]
    public async Task<IActionResult> GetRoleAccess(string code, CancellationToken token)
    {
        if (AssistantCapabilities.Find(code) is null) return NotFound();
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await Allowed(db,"VIEW",token) || !await AiCapabilityRoleAccess.CanManage(db,User,token)) return Forbid();
        await using var cmd = new SqlCommand("""
SELECT RG.RoleGroupID, RG.RoleNameTH,
 CAST(CASE WHEN P.CompanyID IS NULL OR A.RoleGroupID IS NOT NULL THEN 1 ELSE 0 END AS bit),
 CAST(CASE WHEN P.CompanyID IS NULL THEN 0 ELSE 1 END AS bit)
FROM dbo.TDADRoleGroup RG
LEFT JOIN dbo.TDADAiCapabilityRolePolicy P ON P.CompanyID=RG.CompanyID AND P.CapabilityCode=@code
LEFT JOIN dbo.TDADAiCapabilityRoleAccess A ON A.CompanyID=RG.CompanyID AND A.CapabilityCode=@code AND A.RoleGroupID=RG.RoleGroupID
WHERE RG.CompanyID=@company AND RG.ScopeType='C' AND RG.IsActive=1
ORDER BY RG.RoleNameTH, RG.RoleGroupID
""",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=AiChatSettingsStore.CompanyId(User)!.Value;
        cmd.Parameters.Add("@code",SqlDbType.NVarChar,100).Value=code;
        var roles=new List<object>();
        await using var reader=await cmd.ExecuteReaderAsync(token);
        while(await reader.ReadAsync(token)) roles.Add(new { id=reader.GetInt64(0), name=reader.GetString(1), allowed=reader.GetBoolean(2), configured=reader.GetBoolean(3) });
        await reader.DisposeAsync();
        await using var mode = new SqlCommand("SELECT UseMenuPermissions FROM dbo.TDADAiCapabilityRolePolicy WHERE CompanyID=@company AND CapabilityCode=@code",db);
        mode.Parameters.Add("@company",SqlDbType.BigInt).Value=AiChatSettingsStore.CompanyId(User)!.Value;
        mode.Parameters.Add("@code",SqlDbType.NVarChar,100).Value=code;
        var useMenuPermissions = await mode.ExecuteScalarAsync(token);
        return Ok(new { roles, useMenuPermissions = useMenuPermissions is null or DBNull || Convert.ToBoolean(useMenuPermissions) });
    }

    [HttpPut("{code}/role-access")]
    public async Task<IActionResult> SaveRoleAccess(string code, RoleAccessRequest request, CancellationToken token)
    {
        if (AssistantCapabilities.Find(code) is null) return NotFound();
        if (request.RoleGroupIds is null || request.RoleGroupIds.Count > 10000 || request.RoleGroupIds.Any(x=>x<=0)) return BadRequest();
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await Allowed(db,"VIEW",token) || !await AiCapabilityRoleAccess.CanManage(db,User,token)) return Forbid();
        var company=AiChatSettingsStore.CompanyId(User)!.Value;
        var roles=request.RoleGroupIds.Distinct().ToArray();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        foreach(var role in roles)
        {
            await using var check=new SqlCommand("SELECT COUNT_BIG(*) FROM dbo.TDADRoleGroup WITH (UPDLOCK,HOLDLOCK) WHERE RoleGroupID=@role AND CompanyID=@company AND ScopeType='C' AND IsActive=1",db,tx);
            check.Parameters.Add("@role",SqlDbType.BigInt).Value=role;
            check.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
            if(Convert.ToInt64(await check.ExecuteScalarAsync(token))!=1) return BadRequest(new {message="กลุ่มสิทธิ์ไม่ถูกต้องหรือไม่อยู่ในบริษัท"});
        }
        await using (var policy=new SqlCommand("""
IF NOT EXISTS(SELECT 1 FROM dbo.TDADAiCapabilityRolePolicy WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND CapabilityCode=@code)
 INSERT dbo.TDADAiCapabilityRolePolicy(CompanyID,CapabilityCode,UpdatedBy,UseMenuPermissions) VALUES(@company,@code,@user,@useMenu);
ELSE UPDATE dbo.TDADAiCapabilityRolePolicy SET UpdatedBy=@user,UpdatedAt=SYSUTCDATETIME(),UseMenuPermissions=@useMenu WHERE CompanyID=@company AND CapabilityCode=@code;
DELETE FROM dbo.TDADAiCapabilityRoleAccess WHERE CompanyID=@company AND CapabilityCode=@code;
""",db,tx))
        {
            policy.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
            policy.Parameters.Add("@code",SqlDbType.NVarChar,100).Value=code;
            policy.Parameters.Add("@user",SqlDbType.BigInt).Value=long.TryParse(User.FindFirstValue("user_id"),out var userId) ? userId : DBNull.Value;
            policy.Parameters.Add("@useMenu",SqlDbType.Bit).Value=request.UseMenuPermissions;
            await policy.ExecuteNonQueryAsync(token);
        }
        foreach(var role in roles)
        {
            await using var insert=new SqlCommand("INSERT dbo.TDADAiCapabilityRoleAccess(CompanyID,CapabilityCode,RoleGroupID) VALUES(@company,@code,@role)",db,tx);
            insert.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
            insert.Parameters.Add("@code",SqlDbType.NVarChar,100).Value=code;
            insert.Parameters.Add("@role",SqlDbType.BigInt).Value=role;
            await insert.ExecuteNonQueryAsync(token);
        }
        await tx.CommitAsync(token);
        return NoContent();
    }

    [HttpPut("{code}")]
    public async Task<IActionResult> Update(string code, [FromBody] UpdateCapability request, CancellationToken token)
    {
        if (AssistantCapabilities.Find(code) is null) return NotFound();
        var name=request.DisplayName?.Trim(); var description=request.Description?.Trim();
        var examples=(request.Examples ?? []).Select(x=>x?.Trim() ?? "").Where(x=>x.Length>0).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        if(string.IsNullOrEmpty(name) || name.Length>200 || description?.Length>1000 || examples.Length>20 || examples.Any(x=>x.Length>300))
            return BadRequest(new {message="ข้อมูลความสามารถหรือคำถามตัวอย่างไม่ถูกต้อง"});
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if(!await Allowed(db,"EDIT",token)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        await using (var prior = new SqlCommand("SELECT ExamplesJson FROM dbo.TDADAiCapabilityCompany WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND CapabilityCode=@code",db,tx))
        {
            prior.Parameters.Add("@company",SqlDbType.BigInt).Value=AiChatSettingsStore.CompanyId(User)!.Value;
            prior.Parameters.Add("@code",SqlDbType.NVarChar,100).Value=code;
            var json=await prior.ExecuteScalarAsync(token);
            var old=json is string s ? JsonSerializer.Deserialize<string[]>(s)??[] : [];
            if(examples.Any(value=>!old.Contains(value,StringComparer.OrdinalIgnoreCase)))
                return Conflict(new {message="ตัวอย่างใหม่ต้องผ่านการทดลองและอนุมัติในคำถามจาก Chat ก่อน"});
        }
        const string sql="""
IF NOT EXISTS(SELECT 1 FROM dbo.TDADAiCapability WHERE CapabilityCode=@code AND IsActive=1) THROW 53904,N'CAPABILITY_NOT_INSTALLED',1;
UPDATE dbo.TDADAiCapabilityCompany WITH (UPDLOCK,SERIALIZABLE)
SET IsEnabled=@enabled,DisplayName=@name,DescriptionTH=@description,ExamplesJson=@examples,
 AllowPdf=@pdf,AllowPng=@png,AllowHtml=@html,AllowEmail=@email,UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@company AND CapabilityCode=@code;
IF @@ROWCOUNT=0
 INSERT dbo.TDADAiCapabilityCompany(CompanyID,CapabilityCode,IsEnabled,DisplayName,DescriptionTH,ExamplesJson,AllowPdf,AllowPng,AllowHtml,AllowEmail,UpdateBy)
 VALUES(@company,@code,@enabled,@name,@description,@examples,@pdf,@png,@html,@email,@user);
""";
        await using var cmd=new SqlCommand(sql,db,tx);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=AiChatSettingsStore.CompanyId(User)!.Value;
        cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=long.TryParse(User.FindFirstValue("user_id"),out var id) ? id : DBNull.Value;
        cmd.Parameters.Add("@code",SqlDbType.NVarChar,100).Value=code;
        cmd.Parameters.Add("@name",SqlDbType.NVarChar,200).Value=name;
        cmd.Parameters.Add("@description",SqlDbType.NVarChar,1000).Value=(object?)description ?? DBNull.Value;
        cmd.Parameters.Add("@examples",SqlDbType.NVarChar,-1).Value=JsonSerializer.Serialize(examples);
        cmd.Parameters.Add("@enabled",SqlDbType.Bit).Value=request.IsEnabled;
        cmd.Parameters.Add("@pdf",SqlDbType.Bit).Value=request.AllowPdf;
        cmd.Parameters.Add("@png",SqlDbType.Bit).Value=request.AllowPng;
        cmd.Parameters.Add("@html",SqlDbType.Bit).Value=request.AllowHtml;
        cmd.Parameters.Add("@email",SqlDbType.Bit).Value=request.AllowEmail;
        await cmd.ExecuteNonQueryAsync(token); await tx.CommitAsync(token);
        return NoContent();
    }

    private async Task<bool> Allowed(SqlConnection db,string action,CancellationToken token) =>
        await AiChatSettingsStore.IsEnabledAsync(db,User,token) &&
        (await CompanyMenuAccess.IsAllowedForProjectAsync(db,User,"LAOO_AI","10008",action,token) ||
         await CompanyMenuAccess.IsAllowedForProjectAsync(db,User,"LAOO","10008",action,token));
}
