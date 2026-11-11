using System.Text.Json;
using System.Text.Encodings.Web;
using System.Text;
using System.Text.RegularExpressions;

namespace LaooApi.Services.Assistant;

/// <summary>Shared classification rules; no actions, database mutations or external endpoints.</summary>
public static class AssistantIntentClassifier
{
    public static bool IsMenuGuideRequest(string text)
    {
        var normalized = Normalize(text);
        return normalized.Contains("คีย์", StringComparison.Ordinal) ||
            normalized.StartsWith("จะใช้งาน", StringComparison.Ordinal) ||
            normalized.StartsWith("ใช้งานระบบ", StringComparison.Ordinal) ||
            normalized == "ทำงาน" || normalized.StartsWith("ทำงานระบบ", StringComparison.Ordinal) ||
            ((normalized.Contains("เมนู", StringComparison.Ordinal) || normalized.Contains("ไปที่ไหน", StringComparison.Ordinal)) &&
             (normalized.Contains("เพิ่ม", StringComparison.Ordinal) || normalized.Contains("บันทึก", StringComparison.Ordinal) || normalized.Contains("ไป", StringComparison.Ordinal)));
    }
    private static readonly JsonSerializerOptions PromptJson = new()
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    };

    public static string BuildPrompt(string text, IEnumerable<object> examples) =>
        "Classify the user's Thai request. Return exactly one word: GUIDE for asking which menu to use to enter data, TRACK for checking their own repair status, PENDING for repair requests awaiting acceptance, COST for repair parts expenses, CREATE for submitting a repair request, COMBINED for asking both repair history and warranty of a serial, HISTORY for repair history of a serial, SERIAL for looking up an equipment serial number or its warranty, MEETING_AVAILABILITY for finding an available meeting room, MEETING_BOOKINGS for the user?s own meeting bookings, MEETING_INVITATIONS for their meeting invitations, or UNKNOWN for anything else. No explanation. Additional examples by capability code: "
        + JsonSerializer.Serialize(examples, PromptJson) + ". User text: " + JsonSerializer.Serialize(text, PromptJson);

    public static string BuildMultiPrompt(string text, IEnumerable<object> capabilities) =>
        "Classify the Thai request using only the permitted capability codes below. Return a JSON array of every plausibly matching code, or [] if none. Do not invent codes, explain, or execute anything. Capabilities: " +
        JsonSerializer.Serialize(capabilities, PromptJson) + ". Request: " + JsonSerializer.Serialize(text, PromptJson);

    public static string[] ParseMulti(string? response, IEnumerable<string> allowed)
    {
        if (string.IsNullOrWhiteSpace(response)) return [];
        try
        {
            using var json = JsonDocument.Parse(response.Trim());
            if (json.RootElement.ValueKind != JsonValueKind.Array) return [];
            var allowedSet = allowed.ToHashSet(StringComparer.Ordinal);
            var result = new List<string>();
            foreach (var item in json.RootElement.EnumerateArray())
            {
                if (item.ValueKind != JsonValueKind.String) return [];
                var code = item.GetString();
                if (code is null || !allowedSet.Contains(code)) return [];
                if (!result.Contains(code, StringComparer.Ordinal)) result.Add(code);
            }
            return result.ToArray();
        }
        catch (JsonException) { return []; }
    }

    public static string? FindExact(string text, IEnumerable<(string Code, IReadOnlyList<string> Examples)> examples)
    {
        var matches = FindExactMatches(text, examples);
        return matches.Length switch { 0 => null, 1 => matches[0], _ => "ambiguous" };
    }

    public static string[] FindExactMatches(string text, IEnumerable<(string Code, IReadOnlyList<string> Examples)> examples)
    {
        var target = Normalize(text);
        return examples.Where(group => group.Examples.Any(example =>
                string.Equals(Normalize(example), target, StringComparison.OrdinalIgnoreCase)))
            .Select(group => group.Code).Distinct(StringComparer.Ordinal).ToArray();
    }

    public static string Normalize(string value) => Regex.Replace(value.Normalize(NormalizationForm.FormC).Trim(), @"\s+", " ");

    public static string ResolveAuthorizedIntent(string intent, IReadOnlyCollection<string> allowed)
    {
        const string history = "repair.serial_history", stock = "stock.serial_lookup", combined = "repair.serial_combined";
        if (intent is history or stock or combined)
        {
            var canHistory = allowed.Contains(history);
            var canStock = allowed.Contains(stock);
            if (intent == combined && canHistory && canStock) return combined;
            if (intent == history && canHistory || intent == stock && canStock) return intent;
            if (canHistory && !canStock) return history;
            if (canStock && !canHistory) return stock;
            return "denied";
        }
        return allowed.Contains(intent) ? intent : intent == "unknown" ? "unknown" : "denied";
    }

    public static string Parse(string? response) => response?.Trim().ToUpperInvariant() switch
    {
        "GUIDE" => "core.menu_guide",
        "MEETING_AVAILABILITY" => "meeting.availability",
        "MEETING_BOOKINGS" => "meeting.own_bookings",
        "MEETING_INVITATIONS" => "meeting.invitations",
        "TRACK" => "repair.track_own",
        "PENDING" => "repair.pending",
        "SERIAL" => "stock.serial_lookup",
        "HISTORY" => "repair.serial_history",
        "COMBINED" => "repair.serial_combined",
        "CREATE" => "repair.create_own",
        "COST" => "repair.parts_cost",
        _ => "unknown"
    };
}
