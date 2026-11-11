namespace LaooApi.Services.Assistant;

/// <summary>Ranks only menu names already filtered by the caller's permissions.</summary>
public static class MenuGuideSearch
{
    private static readonly (string[] Phrases, string[] MenuTerms)[] Aliases = [
        (["เพิ่มคน", "เพิ่มพนักงาน", "พนักงานใหม่"], ["พนักงาน"]),
        (["เพิ่มผู้ใช้", "เมนูผู้ใช้"], ["พนักงาน", "ผู้ใช้งาน"]),
        (["สินค้า", "ของในคลัง"], ["สินค้า"]),
        (["pr", "ขอซื้อ"], ["คำขอจัดซื้อ", "ใบขอซื้อ", "ขอซื้อ"]),
        (["po", "สั่งซื้อ"], ["ใบสั่งซื้อ", "สั่งซื้อ"]),
        (["gr", "รับสินค้า"], ["รับสินค้า", "รับสต๊อก"]),
        (["แจ้งซ่อม", "งานซ่อม"], ["แจ้งซ่อม"]),
    ];

    public static int Score(string query, string menuName)
    {
        var input = AssistantIntentClassifier.Normalize(query);
        var name = AssistantIntentClassifier.Normalize(menuName);
        if (name.Length < 2) return 0;
        if (input.Contains(name, StringComparison.OrdinalIgnoreCase)) return 100 + Math.Min(name.Length, 50);
        var subject = name;
        foreach (var prefix in new[] { "ข้อมูล", "ทะเบียน", "รายการ", "จัดการ", "บันทึก", "ระบบ" })
            if (subject.StartsWith(prefix, StringComparison.Ordinal) && subject.Length > prefix.Length) { subject = subject[prefix.Length..].Trim(); break; }
        if (subject.Length >= 2 && input.Contains(subject, StringComparison.OrdinalIgnoreCase)) return 70 + Math.Min(subject.Length, 20);
        foreach (var (phrases, terms) in Aliases) {
            var hasPhrase = phrases.Any(p => p.Length <= 2 && p.All(char.IsAsciiLetter)
                ? System.Text.RegularExpressions.Regex.IsMatch(input, $@"(?<![A-Za-z]){p}(?![A-Za-z])", System.Text.RegularExpressions.RegexOptions.IgnoreCase)
                : input.Contains(p, StringComparison.OrdinalIgnoreCase));
            if (hasPhrase && terms.Any(t => name.Contains(t, StringComparison.OrdinalIgnoreCase))) return 40;
        }
        return 0;
    }
}
