using System.Text.Json;
using LaooApi.Services.Assistant;

if (ChatReviewPolicy.InterpretationFailed("unknown") != true ||
    ChatReviewPolicy.InterpretationFailed("denied") != true ||
    ChatReviewPolicy.InterpretationFailed("none") != true ||
    ChatReviewPolicy.InterpretationFailed("unavailable") != true ||
    ChatReviewPolicy.InterpretationFailed("repair.track_own") != false ||
    ChatReviewPolicy.InterpretationFailed("ambiguous") != false ||
    ChatReviewPolicy.InterpretationFailed(null) != null)
    throw new Exception("Interpretation outcome must distinguish failures, choices, and unfinished classifications.");

if (ChatReviewPolicy.QuestionKey("  แจ้ง ซ่อม  PC ") != ChatReviewPolicy.QuestionKey("แจ้งซ่อมpc") ||
    ChatReviewPolicy.QuestionKey("แจ้งซ่อมเครื่องพิมพ์") == ChatReviewPolicy.QuestionKey("แจ้งซ่อมเครื่องถ่ายเอกสาร"))
    throw new Exception("Chat question duplicate normalization failed");

if (!ChatReviewPolicy.ShouldCaptureQuestion("คอมเปิดไม่ติด") ||
    !ChatReviewPolicy.ShouldCaptureQuestion("คีย์บอร์ดใช้ไม่ได้") ||
    !ChatReviewPolicy.ShouldCaptureQuestion("ติดตามงาน 123") ||
    ChatReviewPolicy.ShouldCaptureQuestion(" 2. ") ||
    ChatReviewPolicy.ShouldCaptureQuestion("ไม่ระบุ"))
    throw new Exception("Capture policy must keep questions and exclude selection replies.");

if (AssistantAgentRegistry.All.Count != 3 || AssistantAgentRegistry.Service.Id != "service" || AssistantAgentRegistry.Stock.Id != "stock" || AssistantAgentRegistry.Meeting.Id != "meeting" || AssistantAgentRegistry.Meeting.CapabilityIds.Count != 3)
    throw new Exception("Unexpected agent registration.");
if (AssistantAgentRegistry.AvailableTo(Array.Empty<string>()).Any())
    throw new Exception("An agent without accessible capabilities must be hidden.");
var visible = JsonSerializer.Serialize(AssistantAgentRegistry.AvailableTo(new[] { "repair.track_own" }));
if (!visible.Contains("repair.track_own") || visible.Contains("repair.create_own") || visible.Contains("repair.parts_cost"))
    throw new Exception("Agent discovery must only expose permitted capabilities.");
if (AssistantAgentRegistry.Service.CapabilityIds.Any(id => AssistantCapabilities.Find(id) is null))
    throw new Exception("Agents must reference registered capabilities only.");
if (AssistantAgentRouter.Resolve(new[] { "repair.track_own", "sql.execute" }, new[] { "repair.track_own", "sql.execute" }).Single().Id != "service")
    throw new Exception("The router must select only the registered agent for allowed capabilities.");
if (AssistantAgentRouter.Resolve(new[] { "repair.create_own" }, new[] { "repair.track_own" }).Count != 0 ||
    AssistantAgentRouter.Resolve(new[] { "sql.execute" }, new[] { "sql.execute" }).Count != 0)
    throw new Exception("The router must reject unpermitted and unregistered capabilities.");
var examples = new (string Code, IReadOnlyList<string> Examples)[]
{
    ("repair.create_own", new[] { "ดูเครื่องให้หน่อย", "แจ้งซ่อม" }),
    ("repair.track_own", new[] { "ติดตามงาน", "ซ้ำ" }),
    ("repair.parts_cost", new[] { "ซ้ำ" }),
};
if (AssistantIntentClassifier.FindExact("  ดูเครื่องให้หน่อย  ", examples) != "repair.create_own")
    throw new Exception("Exact company example must select the matching capability.");
if (AssistantIntentClassifier.FindExact("ซ้ำ", examples) != "ambiguous")
    throw new Exception("Examples shared by multiple capabilities must ask for clarification.");
if (AssistantIntentClassifier.FindExactMatches("ซ้ำ", examples).Length != 2 ||
    AssistantIntentClassifier.FindExactMatches("ดูเครื่องให้หน่อย", examples).Single() != "repair.create_own")
    throw new Exception("Exact choices must contain every matching capability, without unrelated entries.");
var preview = ChatReviewPolicy.PreviewMatches("new question", new[] { "repair.create_own", "repair.track_own" }, examples);
if (preview.Length != 2 || !preview.Contains("repair.create_own") || !preview.Contains("repair.track_own"))
    throw new Exception("Simulation must find all selected capabilities.");
var full = Enumerable.Range(1, 20).Select(i => $"example {i}").ToList();
if (ChatReviewPolicy.AddExample(full, "example 1")?.Count != 20 || ChatReviewPolicy.AddExample(full, "another") is not null || full.Count != 20)
    throw new Exception("Example limit and duplicate handling must not mutate existing examples.");
if (AssistantIntentClassifier.FindExact("ไม่ตรง", examples) is not null)
    throw new Exception("Unmatched examples must fall back to the local model.");
if (AssistantIntentClassifier.Parse("PENDING") != "repair.pending" ||
    AssistantCapabilities.PendingRepair.MenuCode != "17001" ||
    AssistantCapabilities.PendingRepair.Action != "VIEW" ||
    !AssistantAgentRegistry.Service.CapabilityIds.Contains("repair.pending") ||
    AssistantAgentRouter.Resolve(new[] { "repair.pending" }, Array.Empty<string>()).Count != 0)
    throw new Exception("Pending repairs must be registered, classified and filtered by permission.");
if (AssistantIntentClassifier.Parse("SERIAL") != "stock.serial_lookup" ||
    AssistantCapabilities.SerialLookup.ProjectCode != "LAOO_STOCK" ||
    AssistantCapabilities.SerialLookup.MenuCode != "08006" ||
    AssistantCapabilities.SerialLookup.ScreenType != 3 ||
    AssistantCapabilities.SerialLookup.Action != "VIEW" ||
    AssistantAgentRouter.Resolve(new[] { "stock.serial_lookup" }, Array.Empty<string>()).Any() ||
    AssistantAgentRouter.Resolve(new[] { "stock.serial_lookup" }, new[] { "stock.serial_lookup" }).Single().Id != "stock")
    throw new Exception("Serial lookup must be classified and available only through the authorized stock agent.");
if (AssistantIntentClassifier.Parse("HISTORY") != "repair.serial_history" ||
    AssistantIntentClassifier.Parse("COMBINED") != "repair.serial_combined" ||
    AssistantCapabilities.SerialRepairHistory.ProjectCode != "LAOO_SERVICE" ||
    AssistantCapabilities.SerialRepairHistory.MenuCode != "19002" ||
    AssistantCapabilities.SerialRepairHistory.Action != "VIEW" ||
    AssistantAgentRouter.Resolve(new[] { "repair.serial_history" }, Array.Empty<string>()).Any() ||
    AssistantAgentRouter.Resolve(new[] { "repair.serial_history" }, new[] { "repair.serial_history" }).Single().Id != "service")
    throw new Exception("Serial repair history must require its registered Service capability.");
var prompt = AssistantIntentClassifier.BuildPrompt("ดูเครื่องให้หน่อย", new object[] { new { code = "repair.create_own", examples = new[] { "แจ้งซ่อม" } } });
if (!prompt.Contains("ดูเครื่องให้หน่อย") || !prompt.Contains("แจ้งซ่อม"))
    throw new Exception("The local model must receive readable Thai.");
Console.WriteLine("PASS: Service agent registration and permission-filtered discovery");
Console.WriteLine("PASS: exact matching, ambiguity, fallback and readable Thai prompt");
var redacted = ChatReviewPolicy.Redact("ติดต่อ a@example.com โทร 098-123-4567 password=secret123 รหัสผ่าน:ทดสอบ Bearer abc.def 1234567890123");
if (redacted.Contains("a@example.com") || redacted.Contains("098-123-4567") || redacted.Contains("secret123") || redacted.Contains("ทดสอบ") || redacted.Contains("abc.def") || redacted.Contains("1234567890123"))
    throw new Exception("Known sensitive patterns must not survive redaction.");
if (!ChatReviewPolicy.CanTransition(ChatReviewPolicy.Testing, ChatReviewPolicy.AwaitingApproval) ||
    ChatReviewPolicy.CanTransition(ChatReviewPolicy.Pending, ChatReviewPolicy.Active) ||
    ChatReviewPolicy.CanTransition(ChatReviewPolicy.Rejected, ChatReviewPolicy.Active))
    throw new Exception("Review must follow the approved lifecycle before activation.");
Console.WriteLine("PASS: review transitions and sensitive-pattern redaction");

if (AssistantIntentClassifier.Parse("MEETING_AVAILABILITY") != "meeting.availability" ||
    AssistantAgentRouter.Resolve(new[] { "meeting.availability" }, Array.Empty<string>()).Any() ||
    AssistantAgentRouter.Resolve(new[] { "meeting.availability" }, new[] { "meeting.availability" }).Single().Id != "meeting")
    throw new Exception("Meeting capabilities must be classified and filtered by authorization.");
