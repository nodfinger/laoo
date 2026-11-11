using System.Data;
using Laoo.Shared.Contracts;
using LaooApi.Services.Assistant;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

/// <summary>Read-only discovery; execution must repeat the permission check.</summary>
[ApiController, Authorize, Route("api/assistant/capabilities")]
public sealed class AssistantCapabilitiesController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    [HttpGet("/api/assistant/settings")]
    public async Task<IActionResult> Settings(CancellationToken token)
    {
        var company = AiChatSettingsStore.CompanyId(User);
        if (company is null) return Forbid();
        long? userId = long.TryParse(User.FindFirst("user_id")?.Value, out var id) ? id : null;
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        var settings = await AiChatSettingsStore.ReadAsync(db, company.Value, userId, token);
        if (settings is null) return Forbid();
        // Never expose the server file path to the client.
        var hasImage = !string.IsNullOrEmpty(settings.ImagePath);
        settings.ImagePath = null;
        return Ok(new { settings, hasImage });
    }

    [HttpGet("/api/assistant/image")]
    public async Task<IActionResult> Image(CancellationToken token)
    {
        var company = AiChatSettingsStore.CompanyId(User);
        if (company is null) return Forbid();
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        var settings = await AiChatSettingsStore.ReadAsync(db, company.Value, null, token);
        if (settings is null || !settings.Enabled || string.IsNullOrEmpty(settings.ImagePath)) return NotFound();
        var directory = Path.GetFullPath(Path.Combine(environment.ContentRootPath, "uploads", "ai-chat", company.Value.ToString()));
        var file = Path.GetFullPath(Path.Combine(directory, Path.GetFileName(settings.ImagePath)));
        if (!file.StartsWith(directory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || !System.IO.File.Exists(file)) return NotFound();
        var mime = Path.GetExtension(file).ToLowerInvariant() switch { ".png" => "image/png", ".webp" => "image/webp", ".jpg" or ".jpeg" => "image/jpeg", _ => null };
        Response.Headers.CacheControl = "no-store";
        return mime is null ? NotFound() : PhysicalFile(file, mime);
    }

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        if (User.FindFirst("user_type")?.Value != "COMPANY_USER") return Forbid();
        return Ok(new { capabilities = await AllowedCapabilities(token) });
    }

    [HttpGet("/api/assistant/agents")]
    public async Task<IActionResult> Agents(CancellationToken token)
    {
        if (User.FindFirst("user_type")?.Value != "COMPANY_USER") return Forbid();
        var allowed = await AllowedCapabilities(token);
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        var settings = await AgentSettings(db, token);
        var agents = AssistantAgentRegistry.All.Select(agent => new
        {
            id = agent.Id,
            name = settings.TryGetValue(agent.Id, out var value) ? value.Name : agent.Name,
            greeting = settings.TryGetValue(agent.Id, out var greeting) ? greeting.Greeting : agent.Greeting,
            capabilities = agent.CapabilityIds.Where(allowed.Contains).ToArray()
        }).Where(agent => agent.capabilities.Length > 0);
        return Ok(new { agents });
    }

    public sealed record AgentSetting(string Id, string Name, string Greeting);

    private string AgentImagePath(long company, string agent) => Path.Combine(environment.ContentRootPath, "uploads", "ai-agents", company.ToString(), agent + ".image");

    [HttpGet("/api/assistant/agents/{agent}/image")]
    public async Task<IActionResult> AgentImage(string agent, CancellationToken token)
    {
        var definition = AssistantAgentRegistry.All.FirstOrDefault(a => a.Id == agent);
        var company = AiChatSettingsStore.CompanyId(User);
        if (definition is null || company is null) return NotFound();
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await AiChatSettingsStore.IsEnabledAsync(db, User, token)) return Forbid();
        var allowed = await AllowedCapabilities(token);
        if (!definition.CapabilityIds.Any(allowed.Contains) && !await AgentAdminAllowed(db, "VIEW", token)) return Forbid();
        var path = AgentImagePath(company.Value, agent);
        if (!System.IO.File.Exists(path)) return NotFound();
        var bytes = await System.IO.File.ReadAllBytesAsync(path, token);
        var mime = ImageMime(bytes);
        Response.Headers.CacheControl = "no-store";
        return mime is null ? NotFound() : File(bytes, mime);
    }

    [HttpPost("/api/assistant/agents/{agent}/image"), RequestSizeLimit(3 * 1024 * 1024 + 65536)]
    public async Task<IActionResult> UploadAgentImage(string agent, IFormFile file, CancellationToken token)
    {
        var company = AiChatSettingsStore.CompanyId(User);
        if (company is null || !AssistantAgentRegistry.All.Any(a => a.Id == agent)) return NotFound();
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await AgentAdminAllowed(db, "EDIT", token)) return Forbid();
        if (file is null || file.Length <= 0 || file.Length > 3 * 1024 * 1024) return BadRequest(new { message = "กรุณาเลือกรูปขนาดไม่เกิน 3 MB" });
        await using var stream = new MemoryStream();
        await file.CopyToAsync(stream, token);
        var bytes = stream.ToArray();
        if (ImageMime(bytes) is null) return BadRequest(new { message = "รองรับเฉพาะรูป JPG, PNG หรือ WEBP" });
        var path = AgentImagePath(company.Value, agent);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        await System.IO.File.WriteAllBytesAsync(path, bytes, token);
        return NoContent();
    }

    private static string? ImageMime(byte[] b) => b.Length >= 12 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e && b[3] == 0x47 ? "image/png"
        : b.Length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff ? "image/jpeg"
        : b.Length >= 12 && System.Text.Encoding.ASCII.GetString(b, 0, 4) == "RIFF" && System.Text.Encoding.ASCII.GetString(b, 8, 4) == "WEBP" ? "image/webp" : null;

    [HttpGet("/api/assistant/agents/configuration")]
    public async Task<IActionResult> AgentConfiguration(CancellationToken token)
    {
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await AgentAdminAllowed(db, "VIEW", token)) return Forbid();
        var settings = await AgentSettings(db, token);
        var agents = AssistantAgentRegistry.All.Select(agent => new {
            id = agent.Id,
            name = settings.TryGetValue(agent.Id, out var value) ? value.Name : agent.Name,
            greeting = settings.TryGetValue(agent.Id, out var greeting) ? greeting.Greeting : agent.Greeting,
            capabilities = agent.CapabilityIds,
            status = agent.CapabilityIds.Count == 0 ? "planned" : "ready"
        });
        return Ok(new { agents, canEdit = await AgentAdminAllowed(db, "EDIT", token) });
    }

    [HttpPut("/api/assistant/agents/configuration")]
    public async Task<IActionResult> SaveAgentConfiguration([FromBody] List<AgentSetting?>? rows, CancellationToken token)
    {
        if (rows is null || rows.Count == 0 || rows.Count > AssistantAgentRegistry.All.Count ||
            rows.Any(x => x is null) ||
            rows.Select(x => x!.Id).Distinct(StringComparer.Ordinal).Count() != rows.Count ||
            rows.Any(x => x is null || !AssistantAgentRegistry.All.Any(a => a.Id == x.Id) ||
                string.IsNullOrWhiteSpace(x.Name) || x.Name.Trim().Length > 100 ||
                string.IsNullOrWhiteSpace(x.Greeting) || x.Greeting.Trim().Length > 500))
            return BadRequest(new { message = "กรุณาตรวจสอบชื่อและข้อความแนะนำตัวของ Agent" });
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await AgentAdminAllowed(db, "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        foreach (var item in rows)
        {
            var row = item!;
            await using var cmd = new SqlCommand("""
UPDATE dbo.TDADAiAgentCompany WITH (UPDLOCK,SERIALIZABLE)
SET DisplayName=@name,Greeting=@greeting,UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@company AND AgentCode=@code;
IF @@ROWCOUNT=0 INSERT dbo.TDADAiAgentCompany(CompanyID,AgentCode,DisplayName,Greeting,UpdateBy)
VALUES(@company,@code,@name,@greeting,@user);
""", db, tx);
            cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = AiChatSettingsStore.CompanyId(User)!.Value;
            cmd.Parameters.Add("@user", SqlDbType.BigInt).Value = long.TryParse(User.FindFirst("user_id")?.Value, out var id) ? id : DBNull.Value;
            cmd.Parameters.Add("@code", SqlDbType.NVarChar, 50).Value = row.Id;
            cmd.Parameters.Add("@name", SqlDbType.NVarChar, 100).Value = row.Name.Trim();
            cmd.Parameters.Add("@greeting", SqlDbType.NVarChar, 500).Value = row.Greeting.Trim();
            await cmd.ExecuteNonQueryAsync(token);
        }
        await tx.CommitAsync(token);
        return NoContent();
    }

    private async Task<bool> AgentAdminAllowed(SqlConnection db, string action, CancellationToken token)
    {
        if (!await AiChatSettingsStore.IsEnabledAsync(db, User, token) ||
            !await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, "LAOO_AI", "64002", action, token)) return false;
        await using var menu = new SqlCommand("SELECT COUNT_BIG(*) FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.IsActive=1 JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.ProjectCode=N'LAOO_AI' AND P.IsActive=1 WHERE M.MenuCode=N'64002' AND M.ScreenType=2 AND M.IsActive=1 AND M.IsVisible=1", db);
        return Convert.ToInt64(await menu.ExecuteScalarAsync(token)) == 1;
    }

    private async Task<Dictionary<string, AgentSetting>> AgentSettings(SqlConnection db, CancellationToken token)
    {
        var result = new Dictionary<string, AgentSetting>(StringComparer.Ordinal);
        await using var exists = new SqlCommand("SELECT CASE WHEN OBJECT_ID(N'dbo.TDADAiAgentCompany',N'U') IS NULL THEN 0 ELSE 1 END", db);
        if (Convert.ToInt32(await exists.ExecuteScalarAsync(token)) == 0) return result;
        await using var cmd = new SqlCommand("SELECT AgentCode,DisplayName,Greeting FROM dbo.TDADAiAgentCompany WHERE CompanyID=@company", db);
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = AiChatSettingsStore.CompanyId(User)!.Value;
        await using var reader = await cmd.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
        {
            var row = new AgentSetting(reader.GetString(0), reader.GetString(1), reader.GetString(2));
            result[row.Id] = row;
        }
        return result;
    }

    private async Task<List<string>> AllowedCapabilities(CancellationToken token)
    {
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        var allowed = new List<string>();
        foreach (var capability in AssistantCapabilities.All)
        {
            if (await AssistantCapabilityAccess.IsAllowed(db, User, capability.Id, token))
                allowed.Add(capability.Id);
        }
        return allowed;
    }

    public sealed record AssistantMessage(string? Text, string? SelectedCapability = null, string[]? ExpectedCapabilities = null);

    [HttpPost("/api/assistant/intent-test")]
    public async Task<IActionResult> TestIntent(AssistantMessage request, CancellationToken token)
    {
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await AiChatSettingsStore.IsEnabledAsync(db, User, token) ||
            !await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, "LAOO_AI", "64001", "VIEW", token)) return Forbid();
        await using var menu = new SqlCommand("SELECT COUNT_BIG(*) FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.IsActive=1 JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.ProjectCode=N'LAOO_AI' AND P.IsActive=1 WHERE M.MenuCode=N'64001' AND M.ScreenType=3 AND M.IsActive=1 AND M.IsVisible=1", db);
        if (Convert.ToInt64(await menu.ExecuteScalarAsync(token)) != 1) return Forbid();
        var text = request.Text?.Trim();
        if (string.IsNullOrEmpty(text) || text.Length > 300) return BadRequest(new { message = "กรุณาระบุคำถามไม่เกิน 300 ตัวอักษร" });
        if (User.FindFirst("user_type")?.Value != "COMPANY_USER" || !long.TryParse(User.FindFirst("user_id")?.Value, out var userId)) return Forbid();
        var allowed = await AllowedCapabilities(token);
        var eligible = new List<(string Code, string Name, string Description, string[] Examples)>();
        var duplicate = false;
        await using (var examples = new SqlCommand("SELECT CC.CapabilityCode,CC.ExamplesJson,COALESCE(NULLIF(CC.DisplayName,N''),C.NameTH),COALESCE(CC.DescriptionTH,C.DescriptionTH),CC.IsEnabled FROM dbo.TDADAiCapabilityCompany CC JOIN dbo.TDADAiCapability C ON C.CapabilityCode=CC.CapabilityCode AND C.IsActive=1 WHERE CC.CompanyID=@company", db))
        {
            examples.Parameters.Add("@company", SqlDbType.BigInt).Value = AiChatSettingsStore.CompanyId(User)!.Value;
            await using var reader = await examples.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token))
            {
                var values = reader.IsDBNull(1) ? [] : System.Text.Json.JsonSerializer.Deserialize<string[]>(reader.GetString(1)) ?? [];
                if (values.Any(x => ChatReviewPolicy.QuestionKey(x) == ChatReviewPolicy.QuestionKey(text))) duplicate = true;
                var code = reader.GetString(0);
                if (reader.GetBoolean(4) && allowed.Contains(code)) eligible.Add((code, reader.GetString(2), reader.GetString(3), values));
            }
        }
        if (duplicate)
        {
            var existing = eligible.Where(x => x.Examples.Any(example => ChatReviewPolicy.QuestionKey(example) == ChatReviewPolicy.QuestionKey(text)))
                .Select(x => new { code = x.Code, name = x.Name }).ToArray();
            return Ok(new { intent = existing.Length switch { 0 => "unknown", 1 => existing[0].code, _ => "ambiguous" }, choices = existing, duplicate = true, approvalProof = (string?)null });
        }
        var expected = IntentTestProofs.ValidateExpected(request.ExpectedCapabilities, eligible.Select(x => x.Code));
        if (expected is null) return BadRequest(new { message = "ความสามารถที่เลือกไม่พร้อมใช้งานหรือไม่มีสิทธิ์" });
        var matches = AssistantIntentClassifier.FindExactMatches(text, eligible.Select(x => (x.Code, (IReadOnlyList<string>)x.Examples)));
        if (matches.Length == 0 && !duplicate && eligible.Count > 0)
        {
            var catalog = eligible.Select(x => (object)new { code = x.Code, name = x.Name, description = x.Description.Length > 120 ? x.Description[..120] : x.Description, examples = x.Examples.Take(2).Select(e => e.Length > 80 ? e[..80] : e).ToArray() }).ToArray();
            var prompt = AssistantIntentClassifier.BuildMultiPrompt(text, catalog);
            if (prompt.Length > 4000) return BadRequest(new { message = "รายการความสามารถมากเกินขนาดที่โมเดลรองรับ กรุณาลดจำนวนความสามารถที่เปิดใช้งาน" });
            try
            {
                var response = await new LocalAssistantModel(configuration).InterpretAsync(prompt, token);
                if (string.IsNullOrWhiteSpace(response)) return StatusCode(503, new { message = "บริการ AI ภายในยังไม่พร้อม" });
                matches = AssistantIntentClassifier.ParseMulti(response, eligible.Select(x => x.Code));
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or InvalidOperationException or ArgumentException)
            {
                if (token.IsCancellationRequested) throw;
                return StatusCode(503, new { message = "บริการ AI ภายในยังไม่พร้อม" });
            }
        }
        var choices = eligible.Where(x => matches.Contains(x.Code, StringComparer.Ordinal)).Select(x => new { code = x.Code, name = x.Name }).ToArray();
        var proofCodes = expected.Length > 0 ? expected : matches;
        var proof = proofCodes.Length > 0 ? IntentTestProofs.Create(HttpContext.RequestServices.GetRequiredService<Microsoft.AspNetCore.DataProtection.IDataProtectionProvider>(), AiChatSettingsStore.CompanyId(User)!.Value, userId, text, proofCodes) : null;
        return Ok(new { intent = matches.Length switch { 0 => "unknown", 1 => matches[0], _ => "ambiguous" }, choices, duplicate, approvalProof = proof });
    }

    [HttpPost("/api/assistant/message")]
    public async Task<IActionResult> Message(AssistantMessage request, CancellationToken token)
        => await ClassifyMessage(request, token, true);

    [HttpPost("/api/assistant/repair/unmatched-subject")]
    public async Task<IActionResult> CaptureUnmatchedRepairSubject(AssistantMessage request, CancellationToken token)
    {
        if (User.FindFirst("user_type")?.Value != "COMPANY_USER") return Forbid();
        var text = request.Text?.Trim();
        if (string.IsNullOrEmpty(text) || text.Length > 1000)
            return BadRequest(new { message = "กรุณาระบุอาการไม่เกิน 1,000 ตัวอักษร" });
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await AssistantCapabilityAccess.IsAllowed(db, User, AssistantCapabilities.CreateOwnRepair.Id, token)) return Forbid();
        var reviewId = await CaptureQuestion(text, token);
        await RecordQuestionIntent(reviewId, "unknown", token);
        return NoContent();
    }

    private async Task<IActionResult> ClassifyMessage(AssistantMessage request, CancellationToken token, bool capture)
    {
        if (User.FindFirst("user_type")?.Value != "COMPANY_USER") return Forbid();
        var text = request.Text?.Trim();
        if (string.IsNullOrEmpty(text) || text.Length > 1000) return BadRequest(new { message = "กรุณากรอกข้อความไม่เกิน 1,000 ตัวอักษร" });
        if (AssistantIntentClassifier.IsGreeting(text)) {
            await using var greetingDb = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
            await greetingDb.OpenAsync(token);
            if (!await AiChatSettingsStore.IsEnabledAsync(greetingDb, User, token)) return Forbid();
            return Ok(new { intent = "greeting" });
        }
        var reviewId = capture && request.SelectedCapability is null ? await CaptureQuestion(text, token) : null;
        text = AssistantIntentClassifier.StripGreetingPrefix(text);
        var allowed = await AllowedCapabilities(token);
        if (allowed.Count == 0)
        {
            var intent = AssistantIntentClassifier.IsSmartHelpRequest(text) || AssistantIntentClassifier.IsMenuGuideRequest(text)
                ? "guide_unavailable"
                : "none";
            await RecordQuestionIntent(reviewId, intent, token);
            return Ok(new { intent });
        }
        try
        {
            var examples = new List<(string Code, IReadOnlyList<string> Examples)>();
            var names = new Dictionary<string, string>(StringComparer.Ordinal);
            await using (var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase")))
            {
                await db.OpenAsync(token);
                await using var exists = new SqlCommand("SELECT CASE WHEN OBJECT_ID(N'dbo.TDADAiCapabilityCompany',N'U') IS NULL THEN 0 ELSE 1 END", db);
                if (Convert.ToInt32(await exists.ExecuteScalarAsync(token)) == 1)
                {
                    await using var query = new SqlCommand("SELECT CC.CapabilityCode,CC.ExamplesJson,COALESCE(NULLIF(CC.DisplayName,N''),C.NameTH) FROM dbo.TDADAiCapabilityCompany CC JOIN dbo.TDADAiCapability C ON C.CapabilityCode=CC.CapabilityCode WHERE CC.CompanyID=@company AND CC.IsEnabled=1 AND CC.ExamplesJson IS NOT NULL", db);
                    query.Parameters.AddWithValue("@company", AiChatSettingsStore.CompanyId(User)!.Value);
                    await using var reader = await query.ExecuteReaderAsync(token);
                    while (await reader.ReadAsync(token))
                    {
                        var code = reader.GetString(0);
                        if (allowed.Contains(code)) { examples.Add((code, System.Text.Json.JsonSerializer.Deserialize<string[]>(reader.GetString(1)) ?? [])); names[code] = reader.GetString(2); }
                    }
                }
            }
            var matches = AssistantIntentClassifier.FindExactMatches(text, examples);
            if (request.SelectedCapability is not null)
            {
                if (matches.Length < 2 || !matches.Contains(request.SelectedCapability, StringComparer.Ordinal) || !allowed.Contains(request.SelectedCapability)) return Forbid();
                return await IntentResult(request.SelectedCapability, allowed, token);
            }
            if (matches.Length > 1)
            {
                await RecordQuestionIntent(reviewId, "ambiguous", token);
                return Ok(new { intent = "ambiguous", choices = matches.Select(code => new { code, name = names[code] }) });
            }
            var exact = matches.FirstOrDefault();
            if (exact is not null) {
                await RecordQuestionIntent(reviewId, exact, token);
                if (exact == AssistantCapabilities.MenuGuide.Id && AssistantIntentClassifier.IsSmartHelpRequest(text))
                    return Ok(new { intent = exact, smartHelp = true });
                return await IntentResult(exact, allowed, token);
            }
            if (AssistantIntentClassifier.IsSmartHelpRequest(text) || AssistantIntentClassifier.IsMenuGuideRequest(text))
            {
                if (!allowed.Contains(AssistantCapabilities.MenuGuide.Id))
                {
                    await RecordQuestionIntent(reviewId, "guide_unavailable", token);
                    return Ok(new { intent = "guide_unavailable" });
                }
                await RecordQuestionIntent(reviewId, AssistantCapabilities.MenuGuide.Id, token);
                return AssistantIntentClassifier.IsSmartHelpRequest(text)
                    ? Ok(new { intent = AssistantCapabilities.MenuGuide.Id, smartHelp = true })
                    : await IntentResult(AssistantCapabilities.MenuGuide.Id, allowed, token);
            }
            // Model text is never executable and cannot provide credentials, IDs, routes, or SQL.
            var prompt = AssistantIntentClassifier.BuildPrompt(text, examples.Select(x => (object)new { code = x.Code, examples = x.Examples }));
            var result = await new LocalAssistantModel(configuration).InterpretAsync(prompt, token);
            if (string.IsNullOrWhiteSpace(result))
            {
                await RecordQuestionIntent(reviewId, "unavailable", token);
                return StatusCode(503, new { message = "บริการ AI ภายในยังไม่พร้อม กรุณาลองใหม่หรือใช้หน้าจอปกติ" });
            }
            var intent = AssistantIntentClassifier.Parse(result);
            var selected = AssistantIntentClassifier.ResolveAuthorizedIntent(intent, allowed);
            await RecordQuestionIntent(reviewId, selected, token);
            return await IntentResult(selected, allowed, token);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or InvalidOperationException or ArgumentException)
        {
            if (token.IsCancellationRequested) throw;
            await RecordQuestionIntent(reviewId, "unavailable", token);
            return StatusCode(503, new { message = "บริการ AI ภายในยังไม่พร้อม กรุณาลองใหม่หรือใช้หน้าจอปกติ" });
        }
    }

    private async Task<long?> CaptureQuestion(string text, CancellationToken token)
    {
        var normalized = text.Trim();
        if (!ChatReviewPolicy.ShouldCaptureQuestion(normalized)) return null;
        var company = AiChatSettingsStore.CompanyId(User);
        if (company is null || !long.TryParse(User.FindFirst("user_id")?.Value, out var user)) return null;
        try
        {
            await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
            await db.OpenAsync(token);
            if (!await AiChatSettingsStore.IsEnabledAsync(db, User, token)) return null;
            var storedText = ChatReviewPolicy.Redact(normalized);
            var key = ChatReviewPolicy.QuestionKey(storedText);
            await using var tx = (SqlTransaction)await db.BeginTransactionAsync(token);
            await using (var gate = new SqlCommand("DECLARE @result int; EXEC @result = sys.sp_getapplock @Resource=@resource, @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=5000; SELECT @result", db, tx))
            {
                gate.Parameters.Add("@resource", SqlDbType.NVarChar, 255).Value = $"ai-chat-review:{company.Value}";
                if (Convert.ToInt32(await gate.ExecuteScalarAsync(token)) < 0) return null;
            }
            await using (var existing = new SqlCommand("SELECT MessageText,ReviewText FROM dbo.TDADAiChatReview WHERE CompanyID=@company; SELECT ExamplesJson FROM dbo.TDADAiCapabilityCompany WHERE CompanyID=@company AND ExamplesJson IS NOT NULL", db, tx))
            {
                existing.Parameters.AddWithValue("@company", company.Value);
                await using var reader = await existing.ExecuteReaderAsync(token);
                while (await reader.ReadAsync(token))
                    for (var i = 0; i < 2; i++)
                        if (!reader.IsDBNull(i) && ChatReviewPolicy.QuestionKey(reader.GetString(i)) == key) return null;
                await reader.NextResultAsync(token);
                while (await reader.ReadAsync(token))
                {
                    var examples = System.Text.Json.JsonSerializer.Deserialize<string[]>(reader.GetString(0)) ?? [];
                    if (examples.Any(example => ChatReviewPolicy.QuestionKey(ChatReviewPolicy.Redact(example)) == key)) return null;
                }
            }
            await using var cmd = new SqlCommand("""
INSERT dbo.TDADAiChatReview(CompanyID, UserID, MessageKey, MessageText, DepartmentID, DepartmentName)
OUTPUT INSERTED.ReviewID
SELECT @company, @user, NEWID(), @text,
       CASE WHEN D.Cnt=1 THEN D.DepartmentID END, CASE WHEN D.Cnt=1 THEN D.DepartmentName END
FROM dbo.TDADUser U
OUTER APPLY (
 SELECT COUNT(DISTINCT E.DepartmentOrgUnitID) Cnt, MIN(E.DepartmentOrgUnitID) DepartmentID, MIN(O.NameTH) DepartmentName
 FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1
 LEFT JOIN dbo.TDADOrganizationUnit O ON O.OrgUnitID=E.DepartmentOrgUnitID AND O.CompanyID=E.CompanyID
 WHERE UE.UserID=U.UserID AND UE.CompanyID=U.CompanyID AND UE.IsActive=1
) D
WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1
""", db, tx);
            cmd.Parameters.AddWithValue("@company", company.Value);
            cmd.Parameters.AddWithValue("@user", user);
            cmd.Parameters.Add("@text", SqlDbType.NVarChar, 1000).Value = storedText;
            var result = await cmd.ExecuteScalarAsync(token);
            await tx.CommitAsync(token);
            return result is null ? null : Convert.ToInt64(result);
        }
        catch (Exception ex) when (ex is SqlException or System.Text.Json.JsonException) { return null; }
    }

    private async Task RecordQuestionIntent(long? id, string intent, CancellationToken token)
    {
        if (id is null) return;
        try
        {
            await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
            await db.OpenAsync(token);
            await using var cmd = new SqlCommand("UPDATE dbo.TDADAiChatReview SET DetectedCapability=@intent, AiInterpretationFailed=@failed WHERE ReviewID=@id AND CompanyID=@company AND UserID=@user AND StatusCode='PENDING'", db);
            cmd.Parameters.Add("@intent", SqlDbType.NVarChar, 100).Value = intent;
            cmd.Parameters.Add("@failed", SqlDbType.Bit).Value = (object?)ChatReviewPolicy.InterpretationFailed(intent) ?? DBNull.Value;
            cmd.Parameters.AddWithValue("@id", id.Value);
            cmd.Parameters.AddWithValue("@company", AiChatSettingsStore.CompanyId(User)!.Value);
            cmd.Parameters.AddWithValue("@user", long.Parse(User.FindFirst("user_id")!.Value));
            await cmd.ExecuteNonQueryAsync(token);
        }
        catch (SqlException) { }
    }

    private async Task<IActionResult> IntentResult(string intent, IReadOnlyCollection<string> allowed, CancellationToken token)
    {
        var agent = AssistantAgentRouter.Resolve([intent], allowed).FirstOrDefault();
        if (agent is null) return Ok(new { intent });
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        var settings = await AgentSettings(db, token);
        var name = settings.TryGetValue(agent.Id, out var value) ? value.Name : agent.Name;
        var greeting = settings.TryGetValue(agent.Id, out var configured) ? configured.Greeting : agent.Greeting;
        return Ok(new { intent, agent = new { id = agent.Id, name, greeting } });
    }
}
