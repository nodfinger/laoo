using System.Text.Json;
using System.Text.Encodings.Web;
using System.Text;
using System.Text.RegularExpressions;

namespace LaooApi.Services.Assistant;

/// <summary>Shared classification rules; no actions, database mutations or external endpoints.</summary>
public static class AssistantIntentClassifier
{
    private static readonly HashSet<string> Greetings = new(StringComparer.OrdinalIgnoreCase) {
        "สวัสดี", "สวัสดีครับ", "สวัสดีค่ะ", "สวัสดีจ้า", "หวัดดี", "หวัดดีจ้า", "ดีจ้า", "ดีครับ", "ดีงับ", "ฮัลโหล", "ฮาย", "โหล", "hello", "hi", "hi ai", "hey", "good morning", "อยู่ไหม", "อยู่ปะ", "มีใครอยู่ไหม", "ai อยู่หรือเปล่า", "พร้อมไหม", "พร้อมยัง", "คุยด้วยหน่อย", "เริ่มกันเลย", "วันนี้เริ่มงานกัน", "กลับมาแล้ว", "มาแล้ว", "มาละ", "พร้อมทำงาน", "สวัสดีอีกครั้ง"
    };
    public static bool IsGreeting(string text) => Greetings.Contains(Normalize(text).TrimEnd('ๆ', '!', '.', ' '));
    public static string StripGreetingPrefix(string text)
    {
        var normalized = Normalize(text);
        foreach (var greeting in Greetings.OrderByDescending(x => x.Length)) {
            if (normalized.Length > greeting.Length && normalized.StartsWith(greeting, StringComparison.OrdinalIgnoreCase)
                && (char.IsWhiteSpace(normalized[greeting.Length]) || normalized[greeting.Length] is ',' or '!' or 'ๆ')) {
                var rest = normalized[greeting.Length..].TrimStart(' ', ',', '!', 'ๆ');
                if (rest.Length > 0) return rest;
            }
        }
        return normalized;
    }
    public static bool IsSmartHelpRequest(string text)
    {
        var normalized = Regex.Replace(Normalize(text), @"\s+", "");
        return normalized is "จำไม่ได้" or "ลืมแล้ว" or "นึกไม่ออก" or "ช่วยหน่อย" or "ช่วยด้วย" or "ขอความช่วยเหลือ" or "แนะนำหน่อย" or "ทำไม่เป็น" or "ไม่รู้ทำยังไง" or "สอนหน่อย" or "เริ่มตรงไหน" or "หาไม่เจอ" or "อยู่ไหน" or "เมนูหาย" or "หาเมนูให้หน่อย" or "ทำต่อ" or "งานเมื่อวาน" or "เปิดงานเดิม" or "กลับหน้าเก่า" or "เข้าไม่ได้" or "กดไม่ได้" or "ใช้ไม่ได้" or "มีปัญหา";
    }
    public static bool IsMenuGuideRequest(string text)
    {
        var normalized = Normalize(text);
        return normalized.Contains("คีย์", StringComparison.Ordinal) ||
            normalized.StartsWith("จะใช้งาน", StringComparison.Ordinal) ||
            normalized.StartsWith("ใช้งานระบบ", StringComparison.Ordinal) ||
            Regex.IsMatch(normalized, @"(?:เข้า|เปิด|หา|เช็ค|ตรวจ).{0,20}(?<![A-Za-z])(?:PR|PO|GR)(?![A-Za-z])", RegexOptions.IgnoreCase) ||
            normalized.Contains("เพิ่มคน", StringComparison.Ordinal) ||
            normalized == "ทำงาน" || normalized.StartsWith("ทำงานระบบ", StringComparison.Ordinal) ||
            ((normalized.Contains("เมนู", StringComparison.Ordinal) || normalized.Contains("ไปที่ไหน", StringComparison.Ordinal)) &&
             (normalized.Contains("เพิ่ม", StringComparison.Ordinal) || normalized.Contains("บันทึก", StringComparison.Ordinal) || normalized.Contains("เปิด", StringComparison.Ordinal) || normalized.Contains("ไป", StringComparison.Ordinal)));
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
