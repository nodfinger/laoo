using System.Text.RegularExpressions;

namespace LaooApi.Services.Assistant;

/// <summary>Rules for the review queue; it never changes the capability registry.</summary>
public static partial class ChatReviewPolicy
{
    // null means classification has not completed; ambiguous means choices were found.
    public static bool? InterpretationFailed(string? intent) => intent switch
    {
        null or "" => null,
        "unknown" or "none" or "denied" or "unavailable" => true,
        _ => false
    };

    // Compare captured questions without whitespace or case differences.
    public static string QuestionKey(string text) =>
        Regex.Replace(text.Normalize(System.Text.NormalizationForm.FormC), @"\s+", "")
            .ToUpperInvariant();

    public const string Pending = "PENDING";
    public const string Preparing = "PREPARING";
    public const string Testing = "TESTING";
    public const string AwaitingApproval = "AWAITING_APPROVAL";
    public const string Active = "ACTIVE";
    public const string Rejected = "REJECTED";

    public static string[] PreviewMatches(string text, IReadOnlyList<string> selected,
        IEnumerable<(string Code, IReadOnlyList<string> Examples)> existing)
    {
        var preview = existing.ToList();
        foreach (var code in selected) preview.Add((code, new[] { text }));
        return AssistantIntentClassifier.FindExactMatches(text, preview);
    }

    public static List<string>? AddExample(IReadOnlyList<string> existing, string text)
    {
        var result = existing.ToList();
        if (!result.Any(x => string.Equals(AssistantIntentClassifier.Normalize(x), AssistantIntentClassifier.Normalize(text), StringComparison.OrdinalIgnoreCase)))
            result.Add(text);
        return result.Count <= 20 ? result : null;
    }

    public static bool ShouldCaptureQuestion(string text)
    {
        var value = text.Trim();
        return value.Length > 0 &&
            !Regex.IsMatch(value, @"^\d+\s*[.)-]?$") &&
            !new[] { "ใช่", "ไม่ใช่", "ไม่มี", "ไม่ระบุ", "ยืนยัน", "ยกเลิก", "ตกลง", "ได้", "ไม่", "ok" }.Contains(value, StringComparer.OrdinalIgnoreCase);
    }

    public static bool CanTransition(string from, string to) => (from, to) switch
    {
        (Pending, Preparing or Rejected) => true,
        (Preparing, Testing or Rejected) => true,
        (Testing, Preparing or AwaitingApproval or Rejected) => true,
        (AwaitingApproval, Preparing or Active or Rejected) => true,
        _ => false,
    };

    // Redaction is a safeguard, not a guarantee that every sensitive value is detected.
    public static string Redact(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        var value = SecretPattern().Replace(text, "[ปกปิดข้อมูลลับ]");
        value = BearerPattern().Replace(value, "[ปกปิดข้อมูลลับ]");
        value = EmailPattern().Replace(value, "[ปกปิดอีเมล]");
        value = PhonePattern().Replace(value, "[ปกปิดเบอร์โทร]");
        value = IdentityPattern().Replace(value, "[ปกปิดเลขประจำตัว]");
        return value;
    }

    [GeneratedRegex(@"(?i)\b(?:password|passwd|pwd|token|api[_ -]?key|secret)(?:\s*[:=]\s*|\s+)\S+|(?:รหัสผ่าน|รหัสลับ)(?:\s*[:=：]\s*|\s+)\S+", RegexOptions.CultureInvariant, 100)]
    private static partial Regex RawSecretPattern();

    // Preserve only a neutral marker; the original matching text must never be returned.
    private static Regex SecretPattern() => RawSecretPattern();

    [GeneratedRegex(@"(?i)\bBearer\s+[A-Za-z0-9._~+/\-]+=*", RegexOptions.CultureInvariant, 100)]
    private static partial Regex BearerPattern();

    [GeneratedRegex(@"(?i)\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b", RegexOptions.CultureInvariant, 100)]
    private static partial Regex EmailPattern();

    [GeneratedRegex(@"(?<!\d)(?:\+66[\s-]?|0)[1-9](?:[\s-]?\d){7,8}(?!\d)", RegexOptions.CultureInvariant, 100)]
    private static partial Regex PhonePattern();

    [GeneratedRegex(@"(?<!\d)\d{13}(?!\d)", RegexOptions.CultureInvariant, 100)]
    private static partial Regex IdentityPattern();
}
