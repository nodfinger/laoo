using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Laoo.Shared.Contracts;
using LaooApi.Services.Assistant;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/assistant/chat-review")]
public sealed class AssistantChatReviewController(IConfiguration configuration) : ControllerBase
{
    public sealed record Capture(Guid MessageKey, string? Text);
    public sealed record Preparation(string? Text, string? Capability, string[]? Capabilities = null);
    public sealed record Detection(string? Capability);
    public sealed record ConfirmTestMatches(string? Text, string[]? Capabilities, string? ApprovalProof);

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        return db;
    }
    private long? Company => AiChatSettingsStore.CompanyId(User);
    private long? UserId => long.TryParse(User.FindFirstValue("user_id"), out var value) ? value : null;
    private long? Partner => long.TryParse(User.FindFirstValue("partner_id"), out var value) ? value : null;
    private async Task<bool> ActiveMember(SqlConnection db,CancellationToken token)
    {
        if(Company is null || UserId is null || Partner is null)return false;
        await using var member = new SqlCommand("SELECT COUNT_BIG(*) FROM dbo.TDADUser U JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.PartnerID=@partner AND C.OwnerType='C' AND C.IsActive=1 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1",db);
        member.Parameters.Add("@company",SqlDbType.BigInt).Value=Company.Value;
        member.Parameters.Add("@user",SqlDbType.BigInt).Value=UserId.Value;
        member.Parameters.Add("@partner",SqlDbType.BigInt).Value=Partner.Value;
        return Convert.ToInt64(await member.ExecuteScalarAsync(token))==1;
    }
    private async Task<bool> Admin(SqlConnection db, string action, CancellationToken token) =>
        Company is not null && UserId is not null && await AiChatSettingsStore.IsEnabledAsync(db, User, token) &&
        await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, "LAOO_AI", "10008", action, token);
    private async Task<bool> TargetAllowed(SqlConnection db, AssistantCapability capability, CancellationToken token) =>
        await AssistantCapabilityAccess.CanUseMenu(db,User,capability,token) ||
        (capability.Id==AssistantCapabilities.RepairPartsCost.Id &&
         await AssistantCapabilityAccess.CanUseMenu(db,User,capability with {MenuCode="20003"},token));

    private static string[] ReadCodes(string? json, string? legacy)
    {
        if (!string.IsNullOrWhiteSpace(json)) return JsonSerializer.Deserialize<string[]>(json) ?? [];
        return string.IsNullOrWhiteSpace(legacy) ? [] : [legacy];
    }
    private static string[] NormalizeCodes(IEnumerable<string> codes) =>
        codes.Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x.Trim()).Distinct(StringComparer.Ordinal).OrderBy(x => x, StringComparer.Ordinal).ToArray();

    [HttpPost("confirm-test-matches")]
    public async Task<IActionResult> ConfirmMatches(ConfirmTestMatches input, CancellationToken token)
    {
        var text = input.Text?.Trim() ?? "";
        var codes = NormalizeCodes(input.Capabilities ?? []);
        if (text.Length is < 1 or > 300 || codes.Length is < 1 or > 50 || codes.Any(c => AssistantCapabilities.Find(c) is null))
            return BadRequest(new { message = "กรุณาเลือกความสามารถและระบุคำถามไม่เกิน 300 ตัวอักษร" });
        if (ChatReviewPolicy.Redact(text) != text)
            return BadRequest(new { message = "คำถามอาจมีข้อมูลส่วนตัวหรือข้อมูลลับ", description = "กรุณาลบข้อมูลดังกล่าวและทดลองใหม่" });
        await using var db = await Open(token);
        if (!await Admin(db, "EDIT", token) || !await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, "LAOO_AI", "64001", "VIEW", token)) return Forbid();
        foreach (var code in codes)
            if (!await AssistantCapabilityAccess.IsAllowed(db, User, code, token)) return Forbid();
        var proof = IntentTestProofs.Read(HttpContext.RequestServices.GetRequiredService<Microsoft.AspNetCore.DataProtection.IDataProtectionProvider>(), input.ApprovalProof);
        if (proof is null || proof.CompanyId != Company || proof.UserId != UserId || proof.Text != text || codes.Any(code => !proof.Codes.Contains(code, StringComparer.Ordinal)))
            return Conflict(new { message = "ผลทดลองหมดอายุหรือข้อมูลเปลี่ยน กรุณาทดลองใหม่ก่อนอนุมัติ" });
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        await using (var all = new SqlCommand("SELECT ExamplesJson FROM dbo.TDADAiCapabilityCompany WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND ExamplesJson IS NOT NULL", db, tx))
        {
            all.Parameters.Add("@company", SqlDbType.BigInt).Value = Company!.Value;
            await using var reader = await all.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token))
                if ((JsonSerializer.Deserialize<string[]>(reader.GetString(0)) ?? []).Any(x => ChatReviewPolicy.QuestionKey(x) == ChatReviewPolicy.QuestionKey(text)))
                    return Conflict(new { message = "คำถามนี้ซ้ำกับตัวอย่างที่มีอยู่แล้ว" });
        }
        foreach (var code in codes)
        {
            await using var query = new SqlCommand("SELECT CC.ExamplesJson FROM dbo.TDADAiCapabilityCompany CC JOIN dbo.TDADAiCapability C ON C.CapabilityCode=CC.CapabilityCode AND C.IsActive=1 WHERE CC.CompanyID=@company AND CC.CapabilityCode=@code AND CC.IsEnabled=1", db, tx);
            query.Parameters.AddWithValue("@company", Company!.Value); query.Parameters.AddWithValue("@code", code);
            var raw = await query.ExecuteScalarAsync(token);
            if (raw is null) return Conflict(new { message = "ความสามารถถูกปิดหรือไม่พร้อมใช้งาน: " + code });
            var existing = raw is DBNull ? new List<string>() : new List<string>(JsonSerializer.Deserialize<string[]>((string)raw) ?? []);
            var values = ChatReviewPolicy.AddExample(existing, text);
            if (values is null) return Conflict(new { message = "ตัวอย่างครบ 20 รายการ: " + code });
            await using var save = new SqlCommand("UPDATE dbo.TDADAiCapabilityCompany SET ExamplesJson=@examples,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user,LastApprovedAt=SYSUTCDATETIME(),LastApprovedByUsername=(SELECT U.Username FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company) WHERE CompanyID=@company AND CapabilityCode=@code AND IsEnabled=1", db, tx);
            save.Parameters.Add("@examples", SqlDbType.NVarChar, -1).Value = JsonSerializer.Serialize(values);
            save.Parameters.AddWithValue("@user", UserId!.Value); save.Parameters.AddWithValue("@company", Company.Value); save.Parameters.AddWithValue("@code", code);
            if (await save.ExecuteNonQueryAsync(token) != 1) return Conflict(new { message = "ข้อมูลเปลี่ยน กรุณาทดลองใหม่" });
        }
        await tx.CommitAsync(token);
        return Ok(new { count = codes.Length, message = "อนุมัติและเพิ่มตัวอย่างคำถามแล้ว" });
    }

    // Retain the route for older clients, but never persist new chat messages.
    [HttpPost("capture")]
    public IActionResult CaptureMessage(Capture input) => StatusCode(StatusCodes.Status410Gone);

    [HttpPut("{id:long}/detection")]
    public async Task<IActionResult> RecordDetection(long id, Detection input, CancellationToken token)
    {
        if (Company is null || UserId is null) return Forbid();
        var capability = AssistantCapabilities.Find(input.Capability);
        if (capability is null && input.Capability is not ("unknown" or "ambiguous" or "none" or "denied" or "unavailable")) return NoContent();
        await using var db = await Open(token);
        if (!await AiChatSettingsStore.IsEnabledAsync(db, User, token) || !await ActiveMember(db,token) ||
            (capability is not null && !await AssistantCapabilityAccess.IsAllowed(db, User, capability.Id, token))) return Forbid();
        await using var cmd = new SqlCommand("UPDATE dbo.TDADAiChatReview SET DetectedCapability=@code,AiInterpretationFailed=@failed WHERE ReviewID=@id AND CompanyID=@company AND UserID=@user AND StatusCode='PENDING'", db);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id; cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=Company.Value;
        cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=UserId.Value; cmd.Parameters.Add("@code",SqlDbType.NVarChar,100).Value=capability?.Id ?? input.Capability!;
        cmd.Parameters.Add("@failed",SqlDbType.Bit).Value=(object?)ChatReviewPolicy.InterpretationFailed(input.Capability) ?? DBNull.Value;
        await cmd.ExecuteNonQueryAsync(token); return NoContent();
    }

    [HttpGet]
    public async Task<IActionResult> List(string? search, string? status, long? department, long? branch, bool? interpretationFailed, int page=1, CancellationToken token=default)
    {
        await using var db = await Open(token);
        if (!await Admin(db,"VIEW",token)) return Forbid();
        page=Math.Clamp(page,1,100000);
        await using var cmd = new SqlCommand("""
SELECT ReviewID,MessageText,DepartmentID,DepartmentName,BranchID,BranchName,DetectedCapability,SelectedCapability,ReviewText,StatusCode,CreatedAt,
 COUNT_BIG(*) OVER(),SelectedCapabilitiesJson,AiInterpretationFailed FROM dbo.TDADAiChatReview
WHERE CompanyID=@company AND (@search=N'' OR MessageText LIKE @like OR ReviewText LIKE @like)
 AND (@status='' OR StatusCode=@status) AND (@department IS NULL OR DepartmentID=@department) AND (@branch IS NULL OR BranchID=@branch)
 AND (@failed IS NULL OR AiInterpretationFailed=@failed)
ORDER BY CreatedAt DESC,ReviewID DESC OFFSET @skip ROWS FETCH NEXT 30 ROWS ONLY
""", db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=Company!.Value; var q=(search??"").Trim(); if(q.Length>200) return BadRequest();
        cmd.Parameters.Add("@search",SqlDbType.NVarChar,200).Value=q; cmd.Parameters.Add("@like",SqlDbType.NVarChar,210).Value="%"+q+"%";
        cmd.Parameters.Add("@status",SqlDbType.VarChar,25).Value=status??""; cmd.Parameters.Add("@department",SqlDbType.BigInt).Value=(object?)department??DBNull.Value;
        cmd.Parameters.Add("@branch",SqlDbType.BigInt).Value=(object?)branch??DBNull.Value; cmd.Parameters.Add("@skip",SqlDbType.Int).Value=(page-1)*30;
        cmd.Parameters.Add("@failed",SqlDbType.Bit).Value=(object?)interpretationFailed??DBNull.Value;
        var rows=new List<object>(); long total=0; await using var r=await cmd.ExecuteReaderAsync(token);
        while(await r.ReadAsync(token)) { total=r.GetInt64(11); rows.Add(new { id=r.GetInt64(0), text=r.GetString(1), departmentId=r.IsDBNull(2)?(long?)null:r.GetInt64(2), department=r.IsDBNull(3)?null:r.GetString(3), branchId=r.IsDBNull(4)?(long?)null:r.GetInt64(4), branch=r.IsDBNull(5)?null:r.GetString(5), detected=r.IsDBNull(6)?null:r.GetString(6), capability=r.IsDBNull(7)?null:r.GetString(7), reviewText=r.IsDBNull(8)?null:r.GetString(8), capabilities=ReadCodes(r.IsDBNull(12)?null:r.GetString(12),r.IsDBNull(7)?null:r.GetString(7)), status=r.GetString(9), createdAt=r.GetDateTime(10), interpretationFailed=r.IsDBNull(13)?(bool?)null:r.GetBoolean(13) }); }
        await r.DisposeAsync(); return Ok(new { rows,total,canEdit=await Admin(db,"EDIT",token) });
    }

    [HttpGet("filters")]
    public async Task<IActionResult> Filters(CancellationToken token)
    {
        await using var db=await Open(token);if(!await Admin(db,"VIEW",token))return Forbid();
        await using var cmd=new SqlCommand("SELECT DepartmentID,MAX(DepartmentName) FROM dbo.TDADAiChatReview WHERE CompanyID=@company AND DepartmentID IS NOT NULL AND DepartmentName IS NOT NULL GROUP BY DepartmentID ORDER BY MAX(DepartmentName); SELECT BranchID,MAX(BranchName) FROM dbo.TDADAiChatReview WHERE CompanyID=@company AND BranchID IS NOT NULL AND BranchName IS NOT NULL GROUP BY BranchID ORDER BY MAX(BranchName)",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=Company!.Value;
        var departments=new List<object>();var branches=new List<object>();await using var r=await cmd.ExecuteReaderAsync(token);
        while(await r.ReadAsync(token))departments.Add(new {id=r.GetInt64(0),name=r.GetString(1)});
        await r.NextResultAsync(token);while(await r.ReadAsync(token))branches.Add(new {id=r.GetInt64(0),name=r.GetString(1)});
        return Ok(new {departments,branches});
    }

    [HttpPut("{id:long}/prepare")]
    public async Task<IActionResult> Prepare(long id, Preparation input, CancellationToken token)
    {
        var codes=NormalizeCodes(input.Capabilities ?? (input.Capability is null ? [] : [input.Capability]));
        if(codes.Length is < 1 or > 50 || codes.Any(code => AssistantCapabilities.Find(code) is null) || string.IsNullOrWhiteSpace(input.Text) || input.Text.Trim().Length>300)
            return BadRequest(new {message="กรุณาเลือกความสามารถและระบุคำถามไม่เกิน 300 ตัวอักษร"});
        var safe=ChatReviewPolicy.Redact(input.Text.Trim());
        await using var db=await Open(token); if(!await Admin(db,"EDIT",token))return Forbid();
        foreach(var code in codes) if(!await AssistantCapabilityAccess.IsAllowed(db,User,code,token)) return Forbid();
        await using var cmd=new SqlCommand("UPDATE dbo.TDADAiChatReview SET ReviewText=@text,SelectedCapability=@first,SelectedCapabilitiesJson=@codes,StatusCode='PREPARING',TestedText=NULL,TestedCapability=NULL,TestedCapabilitiesJson=NULL,UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@user WHERE ReviewID=@id AND CompanyID=@company AND StatusCode IN ('PENDING','PREPARING','TESTING','AWAITING_APPROVAL')",db);
        cmd.Parameters.Add("@text",SqlDbType.NVarChar,1000).Value=safe;cmd.Parameters.Add("@first",SqlDbType.NVarChar,100).Value=codes[0];
        cmd.Parameters.Add("@codes",SqlDbType.NVarChar,-1).Value=JsonSerializer.Serialize(codes);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=Company!.Value;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=UserId!.Value;
        return await cmd.ExecuteNonQueryAsync(token)==1?NoContent():Conflict(new {message="สถานะเปลี่ยนไป กรุณาโหลดใหม่"});
    }

    [HttpPost("{id:long}/reject")]
    public async Task<IActionResult> Reject(long id,CancellationToken token)
    {
        await using var db=await Open(token);if(!await Admin(db,"EDIT",token))return Forbid();
        await using var cmd=new SqlCommand("UPDATE dbo.TDADAiChatReview SET StatusCode='REJECTED',UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@user WHERE ReviewID=@id AND CompanyID=@company AND StatusCode IN ('PENDING','PREPARING','TESTING','AWAITING_APPROVAL')",db);
        cmd.Parameters.Add("@id",SqlDbType.BigInt).Value=id;cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=Company!.Value;cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=UserId!.Value;
        return await cmd.ExecuteNonQueryAsync(token)==1?NoContent():Conflict(new {message="สถานะเปลี่ยนไป กรุณาโหลดใหม่"});
    }

    [HttpPost("{id:long}/test")]
    public async Task<IActionResult> Test(long id,CancellationToken token)
    {
        await using var db=await Open(token); if(!await Admin(db,"EDIT",token))return Forbid();
        string text, legacy; string? codesJson;
        await using(var read=new SqlCommand("SELECT ReviewText,SelectedCapability,SelectedCapabilitiesJson FROM dbo.TDADAiChatReview WHERE ReviewID=@id AND CompanyID=@company AND StatusCode IN ('PREPARING','TESTING')",db))
        {
            read.Parameters.AddWithValue("@id",id);read.Parameters.AddWithValue("@company",Company!.Value);
            await using var r=await read.ExecuteReaderAsync(token);if(!await r.ReadAsync(token)||r.IsDBNull(0)||r.IsDBNull(1))return Conflict(new {message="กรุณาเตรียมคำถามก่อนทดลอง"});
            text=r.GetString(0);legacy=r.GetString(1);codesJson=r.IsDBNull(2)?null:r.GetString(2);
        }
        var codes=NormalizeCodes(ReadCodes(codesJson,legacy));
        if(codes.Length==0)return Conflict(new {message="กรุณาเลือกความสามารถก่อนทดลอง"});
        foreach(var code in codes) if(!await AssistantCapabilityAccess.IsAllowed(db,User,code,token))return Forbid();
        var examples=new List<(string Code,IReadOnlyList<string> Examples)>();
        await using(var query=new SqlCommand("SELECT CapabilityCode,ExamplesJson FROM dbo.TDADAiCapabilityCompany WHERE CompanyID=@company AND IsEnabled=1 AND ExamplesJson IS NOT NULL",db))
        {
            query.Parameters.AddWithValue("@company",Company!.Value);await using var r=await query.ExecuteReaderAsync(token);
            while(await r.ReadAsync(token)) examples.Add((r.GetString(0),JsonSerializer.Deserialize<string[]>(r.GetString(1))??[]));
        }
        var visible=new List<(string Code,IReadOnlyList<string> Examples)>();
        foreach(var entry in examples) if(await AssistantCapabilityAccess.IsAllowed(db,User,entry.Code,token)) visible.Add(entry);
        var matches=ChatReviewPolicy.PreviewMatches(text,codes,visible);
        var passed=codes.All(matches.Contains);
        var expected=JsonSerializer.Serialize(codes);
        await using var update=new SqlCommand("""
UPDATE dbo.TDADAiChatReview SET StatusCode=@status,TestedText=@tested,TestedCapability=@first,TestedCapabilitiesJson=@testedCodes,UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@user
WHERE ReviewID=@id AND CompanyID=@company AND ReviewText=@text AND SelectedCapability=@legacy AND ((SelectedCapabilitiesJson IS NULL AND @original IS NULL) OR SelectedCapabilitiesJson=@original) AND StatusCode IN ('PREPARING','TESTING')
""",db);
        update.Parameters.AddWithValue("@status",passed?"AWAITING_APPROVAL":"TESTING");update.Parameters.AddWithValue("@tested",passed?text:DBNull.Value);
        update.Parameters.AddWithValue("@first",passed?codes[0]:DBNull.Value);update.Parameters.AddWithValue("@testedCodes",passed?expected:DBNull.Value);
        update.Parameters.AddWithValue("@user",UserId!.Value);update.Parameters.AddWithValue("@id",id);update.Parameters.AddWithValue("@company",Company!.Value);
        update.Parameters.AddWithValue("@text",text);update.Parameters.AddWithValue("@legacy",legacy);update.Parameters.Add("@original",SqlDbType.NVarChar,-1).Value=(object?)codesJson??DBNull.Value;
        if(await update.ExecuteNonQueryAsync(token)!=1)return Conflict(new {message="ข้อมูลเปลี่ยนระหว่างทดลอง กรุณาลองใหม่"});
        return Ok(new {intent=matches.Length==1?matches[0]:"ambiguous",matches,expected=codes,passed,simulated=true});
    }

    [HttpPost("{id:long}/approve")]
    public async Task<IActionResult> Approve(long id,CancellationToken token)
    {
        await using var db=await Open(token);if(!await Admin(db,"EDIT",token))return Forbid();
        string text,legacy; string? selectedJson,testedJson,testedLegacy;
        await using(var read=new SqlCommand("SELECT ReviewText,SelectedCapability,SelectedCapabilitiesJson,TestedCapabilitiesJson,TestedCapability FROM dbo.TDADAiChatReview WHERE ReviewID=@id AND CompanyID=@company AND StatusCode='AWAITING_APPROVAL' AND ReviewText=TestedText",db))
        {
            read.Parameters.AddWithValue("@id",id);read.Parameters.AddWithValue("@company",Company!.Value);await using var r=await read.ExecuteReaderAsync(token);
            if(!await r.ReadAsync(token)||r.IsDBNull(0)||r.IsDBNull(1))return Conflict(new {message="ต้องทดลองผ่านก่อนอนุมัติ"});
            text=r.GetString(0);legacy=r.GetString(1);selectedJson=r.IsDBNull(2)?null:r.GetString(2);testedJson=r.IsDBNull(3)?null:r.GetString(3);testedLegacy=r.IsDBNull(4)?null:r.GetString(4);
        }
        var codes=NormalizeCodes(ReadCodes(selectedJson,legacy));
        if(codes.Length==0 || !codes.SequenceEqual(NormalizeCodes(ReadCodes(testedJson,testedLegacy))))return Conflict(new {message="ข้อมูลเปลี่ยน กรุณาทดลองอีกครั้ง"});
        foreach(var code in codes) if(!await AssistantCapabilityAccess.IsAllowed(db,User,code,token))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        await using(var claim=new SqlCommand("""
UPDATE dbo.TDADAiChatReview WITH(UPDLOCK,HOLDLOCK) SET StatusCode='ACTIVE',UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@user
WHERE ReviewID=@id AND CompanyID=@company AND StatusCode='AWAITING_APPROVAL' AND ReviewText=@text AND TestedText=@text AND SelectedCapability=@legacy
AND ((SelectedCapabilitiesJson IS NULL AND @original IS NULL) OR SelectedCapabilitiesJson=@original)
AND ((TestedCapabilitiesJson IS NULL AND @tested IS NULL AND TestedCapability=@testedLegacy) OR TestedCapabilitiesJson=@tested)
""",db,tx))
        {
            claim.Parameters.AddWithValue("@user",UserId!.Value);claim.Parameters.AddWithValue("@id",id);claim.Parameters.AddWithValue("@company",Company!.Value);claim.Parameters.AddWithValue("@text",text);claim.Parameters.AddWithValue("@legacy",legacy);
            claim.Parameters.Add("@original",SqlDbType.NVarChar,-1).Value=(object?)selectedJson??DBNull.Value;claim.Parameters.Add("@tested",SqlDbType.NVarChar,-1).Value=(object?)testedJson??DBNull.Value;claim.Parameters.Add("@testedLegacy",SqlDbType.NVarChar,100).Value=(object?)testedLegacy??DBNull.Value;
            if(await claim.ExecuteNonQueryAsync(token)!=1)return Conflict(new {message="ข้อมูลเปลี่ยน กรุณาทดลองอีกครั้ง"});
        }
        foreach(var code in codes)
        {
            string? json;
            await using(var query=new SqlCommand("SELECT CC.ExamplesJson FROM dbo.TDADAiCapabilityCompany CC WITH(UPDLOCK,HOLDLOCK) JOIN dbo.TDADAiCapability C ON C.CapabilityCode=CC.CapabilityCode AND C.IsActive=1 WHERE CC.CompanyID=@company AND CC.CapabilityCode=@code AND CC.IsEnabled=1",db,tx))
            {
                query.Parameters.AddWithValue("@company",Company!.Value);query.Parameters.AddWithValue("@code",code);var value=await query.ExecuteScalarAsync(token);
                if(value is null)return Conflict(new {message="ความสามารถถูกปิดหรือไม่พร้อมใช้งาน: "+code});json=value is DBNull?null:(string)value;
            }
            var existing=string.IsNullOrWhiteSpace(json)?new List<string>():new List<string>(JsonSerializer.Deserialize<string[]>(json)??[]);
            var values=ChatReviewPolicy.AddExample(existing,text);
            if(values is null)return Conflict(new {message="ตัวอย่างครบ 20 รายการ: "+code});
            await using var save=new SqlCommand("UPDATE dbo.TDADAiCapabilityCompany SET ExamplesJson=@examples,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user,LastApprovedAt=SYSUTCDATETIME(),LastApprovedByUsername=(SELECT U.Username FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company) WHERE CompanyID=@company AND CapabilityCode=@code",db,tx);
            save.Parameters.Add("@examples",SqlDbType.NVarChar,-1).Value=JsonSerializer.Serialize(values);save.Parameters.AddWithValue("@user",UserId!.Value);save.Parameters.AddWithValue("@company",Company!.Value);save.Parameters.AddWithValue("@code",code);
            await save.ExecuteNonQueryAsync(token);
        }
        await tx.CommitAsync(token);return NoContent();
    }
}
