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
        (["เบิกเดินทาง", "ค่าเดินทาง", "ขอเบิกเดินทาง", "เบิกค่าเดินทาง"], ["เบิกค่าเดินทาง"]),
        (["เช็คสต๊อก", "ตรวจสต๊อก", "คงเหลือ"], ["สต๊อก", "สินค้า"]),
        (["ห้องประชุม", "จองห้อง", "จองประชุม"], ["ประชุม", "ห้องประชุม"]),
        (["เอกสารกฎหมาย", "ขอเอกสาร", "เอกสารสำคัญ"], ["เอกสาร", "กฎหมาย"]),
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
        // A one-character typo in a short menu name should still find the menu.
        // Keep this behind exact and alias matches to avoid ranking fuzzy results too highly.
        var compactInput = new string(input.Where(char.IsLetterOrDigit).ToArray());
        if (compactInput.Length is >= 4 and <= 40)
        {
            var candidates = new[] { name, subject }
                .Select(value => new string(value.Where(char.IsLetterOrDigit).ToArray()))
                .Distinct(StringComparer.OrdinalIgnoreCase);
            var allowedDistance = compactInput.Length >= 10 ? 2 : 1;
            var distance = candidates.Select(value => NearSubstringDistance(compactInput, value, allowedDistance)).Min();
            if (distance > 0 && distance <= allowedDistance) return 20 - distance;
        }
        return 0;
    }

    private static int EditDistance(string left, string right)
    {
        var previous = Enumerable.Range(0, right.Length + 1).ToArray();
        for (var i = 1; i <= left.Length; i++)
        {
            var current = new int[right.Length + 1];
            current[0] = i;
            for (var j = 1; j <= right.Length; j++)
            {
                var cost = left[i - 1] == right[j - 1] ? 0 : 1;
                current[j] = Math.Min(
                    Math.Min(current[j - 1] + 1, previous[j] + 1),
                    previous[j - 1] + cost);
            }
            previous = current;
        }
        return previous[right.Length];
    }

    private static int NearSubstringDistance(string input, string candidate, int maxDistance)
    {
        var best = maxDistance + 1;
        var minLength = Math.Max(1, candidate.Length - maxDistance);
        var maxLength = candidate.Length + maxDistance;
        for (var start = 0; start < input.Length; start++)
        for (var length = minLength; length <= maxLength && start + length <= input.Length; length++)
        {
            var distance = EditDistance(candidate, input.Substring(start, length));
            if (distance < best) best = distance;
            if (best == 0) return 0;
        }
        return best;
    }
}
