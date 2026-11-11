using LaooApi.Services.Assistant;
using Microsoft.Extensions.Configuration;
using System.Security.Claims;

static IConfiguration Config(string? model = null, string? endpoint = null) =>
    new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
    {
        ["Assistant:Model"] = model,
        ["Assistant:Endpoint"] = endpoint
    }).Build();

static void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

Check(AssistantCapabilities.All.Select(x => x.Id).Distinct().Count() == AssistantCapabilities.All.Count, "Registered capability identifiers must be unique.");
Check(AssistantCapabilities.Find("core.menu_guide") is not null, "Menu guidance must be registered by the server.");
Check(AssistantCapabilities.Find("repair.create_own")?.MenuCode == "20001", "Create must use self-service permission.");
Check(AssistantCapabilities.Find("repair.track_own")?.MenuCode == "20002", "Track must use self-service permission.");
Check(AssistantCapabilities.Find("repair.parts_cost")?.MenuCode == "19002", "Cost summary requires repair history permission.");
Check(AssistantCapabilities.Find("sql.execute") is null, "Unknown capabilities must not be accepted.");
Check(AssistantAgentRegistry.All.Count == 3 && AssistantAgentRegistry.Service.Id == "service" && AssistantAgentRegistry.Stock.CapabilityIds.SequenceEqual(new[] { "stock.serial_lookup" }), "Stock exposes only its registered lookup capability.");
Check(!AssistantAgentRegistry.AvailableTo(Array.Empty<string>()).Any(), "An agent without permitted capabilities must be hidden.");
Check(AssistantAgentRegistry.AvailableTo(new[] { "repair.track_own" }).Count() == 1, "The Service agent is visible for permitted capabilities.");
var visibleAgent = System.Text.Json.JsonSerializer.Serialize(AssistantAgentRegistry.AvailableTo(new[] { "repair.track_own" }));
Check(visibleAgent.Contains("repair.track_own") && !visibleAgent.Contains("repair.create_own") && !visibleAgent.Contains("repair.parts_cost"), "Agent discovery must not reveal or grant unavailable capabilities.");
Check(AssistantIntentClassifier.Parse(" CREATE ") == "repair.create_own", "Create intent must map to the approved capability.");
Check(AssistantIntentClassifier.Parse("GUIDE") == "core.menu_guide", "Menu guidance intent must map to its registered capability.");
Check(AssistantIntentClassifier.IsMenuGuideRequest("จะใช้งาน") && AssistantIntentClassifier.IsMenuGuideRequest("คีย์ข้อมูล") && AssistantIntentClassifier.IsMenuGuideRequest("ทำงาน"), "Common general phrases must request menu guidance.");
Check(AssistantIntentClassifier.IsSmartHelpRequest("ช่วยหน่อย") && AssistantIntentClassifier.IsSmartHelpRequest("จำ ไม่ได้") && AssistantIntentClassifier.IsSmartHelpRequest("เข้าไม่ได้"), "Short help requests work without a model.");
Check(AssistantIntentClassifier.IsGreeting("สวัสดี") && AssistantIntentClassifier.IsGreeting("Hi AI") && AssistantIntentClassifier.IsGreeting("พร้อมยัง"), "Common greetings are handled centrally.");
Check(!AssistantIntentClassifier.IsGreeting("สวัสดี ช่วยแจ้งซ่อมคอม") && AssistantIntentClassifier.StripGreetingPrefix("สวัสดี ช่วยแจ้งซ่อมคอม") == "ช่วยแจ้งซ่อมคอม", "Greeting with a task keeps the task for routing.");
Check(AssistantIntentClassifier.StripGreetingPrefix("Hello ขอเช็ค PO") == "ขอเช็ค PO" && AssistantIntentClassifier.StripGreetingPrefix("ช่วยแจ้งซ่อม") == "ช่วยแจ้งซ่อม", "Prefix removal preserves task requests.");
Check(MenuGuideSearch.Score("จะเพิ่มคนใหม่", "พนักงาน") > 0 && MenuGuideSearch.Score("หา PR", "คำขอจัดซื้อ") > 0, "Known synonyms match actual menu names.");
Check(MenuGuideSearch.Score("หา PO", "คำขอจัดซื้อ") == 0 && MenuGuideSearch.Score("report", "คำขอจัดซื้อ") == 0, "Aliases do not match unrelated or partial English words.");
Check(!AssistantIntentClassifier.IsSmartHelpRequest("ช่วยซ่อมเครื่องพิมพ์") && !AssistantIntentClassifier.IsSmartHelpRequest("ลบรายการนี้"), "Concrete requests must not be captured as generic help.");
Check(!AssistantIntentClassifier.IsMenuGuideRequest("ติดตามงานซ่อมของฉัน"), "Tracking must not be mistaken for menu guidance.");
Check(AssistantIntentClassifier.ResolveAuthorizedIntent("core.menu_guide", Array.Empty<string>()) == "denied", "Menu guidance must not bypass capability access.");
Check(AssistantIntentClassifier.Parse("track") == "repair.track_own", "Track intent must map to the approved capability.");
Check(AssistantIntentClassifier.Parse("COST") == "repair.parts_cost", "Cost intent must map to the approved capability.");
Check(AssistantIntentClassifier.Parse("CREATE; DROP TABLE") == "unknown", "Unexpected model output must not execute an action.");
Check(AssistantIntentClassifier.Parse(null) == "unknown", "Missing model output must not map to an action.");
Check(ChatReviewPolicy.QuestionKey(" Serial  ABC ") == ChatReviewPolicy.QuestionKey("serialabc"), "Duplicate detection ignores whitespace and letter case.");
Check(AssistantIntentClassifier.ResolveAuthorizedIntent("repair.serial_combined", new[] { "repair.serial_history" }) == "repair.serial_history", "Combined serial query falls back to service history without stock access.");
Check(AssistantIntentClassifier.ResolveAuthorizedIntent("repair.serial_combined", new[] { "stock.serial_lookup" }) == "stock.serial_lookup", "Combined serial query falls back to stock without service access.");
Check(AssistantIntentClassifier.ResolveAuthorizedIntent("stock.serial_lookup", new[] { "repair.serial_history" }) == "repair.serial_history", "Serial lookup falls back to service when only service is allowed.");
Check(AssistantIntentClassifier.ResolveAuthorizedIntent("repair.serial_history", new[] { "stock.serial_lookup" }) == "stock.serial_lookup", "Serial history falls back to stock when only stock is allowed.");
Check(AssistantIntentClassifier.ResolveAuthorizedIntent("repair.serial_combined", Array.Empty<string>()) == "denied", "Serial access is denied when neither capability is allowed.");
Check(AssistantIntentClassifier.ResolveAuthorizedIntent("repair.serial_combined", new[] { "repair.serial_history", "stock.serial_lookup" }) == "repair.serial_combined", "Both authorized serial capabilities remain combined.");
var permitted = new[] { "repair.create_own", "repair.track_own" };
Check(IntentTestProofs.ValidateExpected(permitted, permitted)!.SequenceEqual(permitted), "An administrator can select multiple permitted expected capabilities even when the model returns one.");
Check(IntentTestProofs.ValidateExpected(new[] { "repair.create_own", "sql.execute" }, permitted) is null, "Unknown or unauthorized expected capabilities are rejected.");
Check(IntentTestProofs.ValidateExpected(Enumerable.Repeat("repair.track_own", 2), permitted)!.Length == 1, "Repeated expected capabilities are deduplicated.");
Check(AssistantIntentClassifier.ParseMulti("[\"repair.create_own\",\"repair.track_own\"]", permitted).SequenceEqual(permitted), "Multi-intent accepts multiple permitted capabilities.");
Check(AssistantIntentClassifier.ParseMulti("[\"repair.create_own\",\"sql.execute\"]", permitted).Length == 0, "A fabricated capability rejects the entire response.");
Check(AssistantIntentClassifier.ParseMulti("[\"repair.create_own\",12]", permitted).Length == 0, "Malformed output is rejected.");
Check(AssistantIntentClassifier.ParseMulti("CREATE", permitted).Length == 0, "Non-JSON output cannot become a capability.");
var provider = new Microsoft.AspNetCore.DataProtection.EphemeralDataProtectionProvider();
var proof = IntentTestProofs.Create(provider, 1, 2, "test", permitted);
var decoded = IntentTestProofs.Read(provider, proof);
Check(decoded is not null && decoded.CompanyId == 1 && decoded.UserId == 2 && decoded.Text == "test" && decoded.Codes.SequenceEqual(permitted), "Approval proof binds company, user, question and results.");
Check(IntentTestProofs.Read(new Microsoft.AspNetCore.DataProtection.EphemeralDataProtectionProvider(), proof) is null, "Proof from another key is rejected.");
static ClaimsPrincipal User(string type, string? company) => new(new ClaimsIdentity(
    company is null ? [new Claim("user_type", type)] : [new Claim("user_type", type), new Claim("company_id", company)]));
Check(AiChatSettingsStore.CompanyId(User("COMPANY_USER", "123")) == 123, "Company user uses its authenticated company.");
Check(AiChatSettingsStore.CompanyId(User("PARTNER_USER", "123")) is null, "Partner identity cannot impersonate a company.");
Check(AiChatSettingsStore.CompanyId(User("COMPANY_USER", null)) is null, "A missing company claim is denied.");
Check(AiChatSettingsStore.CompanyId(User("COMPANY_USER", "invalid")) is null, "An invalid company claim is denied.");
Check(await new LocalAssistantModel(Config()).InterpretAsync("test", CancellationToken.None) is null,
    "An unconfigured model must remain unavailable.");

foreach (var endpoint in new[] { "https://example.com", "http://localhost:11434", "http://127.0.0.1.evil:11434", "http://user@127.0.0.1:11434", "http://127.0.0.1:11434/path" })
{
    try
    {
        await new LocalAssistantModel(Config("local-model", endpoint)).InterpretAsync("test", CancellationToken.None);
        throw new InvalidOperationException("Unsafe endpoint was accepted.");
    }
    catch (InvalidOperationException error) when (error.Message.StartsWith("Local assistant endpoint")) { }
}
Console.WriteLine("Assistant capability registry and local endpoint restrictions passed.");

if (args.Contains("--verify-ai-project"))
{
    var root = Directory.GetCurrentDirectory();
    var config = new ConfigurationBuilder().AddJsonFile(Path.Combine(root, "laoo_api/appsettings.json"))
        .AddJsonFile(Path.Combine(root, "laoo_api/local.json"), optional: true).Build();
    await using var db = new Microsoft.Data.SqlClient.SqlConnection(config.GetConnectionString("LaooDatabase"));
    await db.OpenAsync();
    const string sql = """
SELECT
 (SELECT COUNT(*) FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_AI' AND IsActive=1),
 (SELECT COUNT(*) FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.IsActive=1 JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.ProjectCode=N'LAOO_AI' WHERE M.MenuCode=N'10008' AND M.IsActive=1),
 (SELECT COUNT(*) FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.IsActive=1 JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.ProjectCode=N'LAOO_AI' WHERE M.MenuCode=N'64001' AND M.ScreenType=3 AND M.IsActive=1),
 (SELECT COUNT(*) FROM dbo.TDSTCompanySetUp C WHERE C.OwnerType=N'C' AND C.IsActive=1 AND C.AiChatEnabled=1 AND C.PartnerID IS NOT NULL AND C.CompanyID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.TDADCompanyProjectSubscription S JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_AI' WHERE S.CompanyID=C.CompanyID AND S.PartnerID=C.PartnerID AND S.IsCurrent=1 AND S.StatusCode=N'ACTIVE')),
 (SELECT COUNT(*) FROM dbo.TDADRoleGroupPermission O JOIN dbo.TDADProject OP ON OP.ProjectID=O.ProjectID AND OP.ProjectCode=N'LAOO' WHERE O.MenuCode=N'10008' AND NOT EXISTS (SELECT 1 FROM dbo.TDADRoleGroupPermission N JOIN dbo.TDADProject NP ON NP.ProjectID=N.ProjectID AND NP.ProjectCode=N'LAOO_AI' WHERE N.RoleGroupID=O.RoleGroupID AND N.MenuCode=O.MenuCode AND N.ActionCode=O.ActionCode AND N.IsAllowed=O.IsAllowed))
""";
    await using var cmd = new Microsoft.Data.SqlClient.SqlCommand(sql, db);
    await using var reader = await cmd.ExecuteReaderAsync();
    if (!await reader.ReadAsync() || reader.GetInt32(0) != 1 || reader.GetInt32(1) != 1 || reader.GetInt32(2) != 1 || reader.GetInt32(3) != 0 || reader.GetInt32(4) != 0)
        throw new InvalidOperationException("AI project post-migration verification failed.");
    Console.WriteLine("AI project verification passed: project, menus, enabled-company subscriptions and role grants.");
}

if (args.Contains("--database"))
{
    var root = Directory.GetCurrentDirectory();
    var config = new ConfigurationBuilder().AddJsonFile(Path.Combine(root,"laoo_api/appsettings.json"))
        .AddJsonFile(Path.Combine(root,"laoo_api/local.json"), optional: true).Build();
    await using var db = new Microsoft.Data.SqlClient.SqlConnection(config.GetConnectionString("LaooDatabase"));
    await db.OpenAsync();
    await using var query = new Microsoft.Data.SqlClient.SqlCommand("SELECT TOP(1) U.UserID,U.CompanyID,C.PartnerID FROM dbo.TDADUser U JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID WHERE U.NormalizedUsername=N'M' AND U.IsActive=1 AND C.IsActive=1", db);
    await using var reader = await query.ExecuteReaderAsync();
    if (!await reader.ReadAsync()) throw new Exception("Read-only employee fixture missing.");
    var userId=reader.GetInt64(0); var companyId=reader.GetInt64(1); var partnerId=reader.GetInt64(2);
    await reader.DisposeAsync();
    ClaimsPrincipal Principal(long company) => new(new ClaimsIdentity(new[] {
        new Claim("user_type","COMPANY_USER"), new Claim("user_id",userId.ToString()),
        new Claim("company_id",company.ToString()), new Claim("partner_id",partnerId.ToString()) }, "test"));
    foreach (var capability in AssistantCapabilities.All)
    {
        Check(!await AssistantCapabilityAccess.IsAllowed(db,Principal(-1),capability.Id,default), "Cross-company AI capability access denied.");
        await using var setting = new Microsoft.Data.SqlClient.SqlCommand("SELECT IsEnabled FROM dbo.TDADAiCapabilityCompany WHERE CompanyID=@company AND CapabilityCode=@code", db);
        setting.Parameters.AddWithValue("@company", companyId); setting.Parameters.AddWithValue("@code", capability.Id);
        var enabled = Convert.ToBoolean(await setting.ExecuteScalarAsync() ?? false);
        if (!enabled)
            Check(!await AssistantCapabilityAccess.IsAllowed(db,Principal(companyId),capability.Id,default), "Disabled AI capability must be denied.");
    }
    Check(!await AssistantCapabilityAccess.IsAllowed(db,Principal(companyId),"sql.execute",default), "Unknown capability denied.");
    Console.WriteLine("Read-only database checks passed: company isolation, disabled capabilities, unknown capability.");
}
