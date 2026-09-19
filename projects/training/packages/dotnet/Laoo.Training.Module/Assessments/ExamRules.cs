using System.Security.Cryptography;
using System.Text.Json;

namespace LaooTrainingModule.Assessments;

// Persist this model server-side only. Never return IsCorrect to a participant.
public sealed record ExamOption(Guid Id, string? Text, Guid? ImageId, bool IsCorrect);
public sealed record ExamQuestion(Guid Id, string? Text, Guid? ImageId, List<ExamOption> Options);
public sealed record ExamDefinition(int QuestionCount, decimal PassingPercent, bool IsActive, List<ExamQuestion> Questions);
public sealed record ExamAnswer(Guid QuestionId, Guid OptionId);
public sealed record ExamSnapshot(decimal PassingPercent, List<ExamQuestion> Questions);
public sealed record ExamScore(int Score, int MaxScore, decimal Percent, bool Passed);

public static class ExamRules
{
    public const int MaxImageBytes = 1024 * 1024;
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public static string? Validate(ExamDefinition? definition)
    {
        if (definition is null || definition.Questions is null)
            return "กรุณาระบุชุดข้อสอบ";
        if (definition.Questions.Count is < 1 or > 200 ||
            definition.QuestionCount < 1 || definition.QuestionCount > definition.Questions.Count)
            return "จำนวนข้อสุ่มต้องอยู่ระหว่าง 1 ถึงจำนวนข้อสอบที่สร้างไว้ (สูงสุด 200 ข้อ)";
        if (definition.PassingPercent is < 0 or > 100)
            return "เกณฑ์ผ่านต้องอยู่ระหว่าง 0 ถึง 100 เปอร์เซ็นต์";
        var ids = new HashSet<Guid>();
        foreach (var question in definition.Questions)
        {
            if (question is null || question.Id == Guid.Empty || !ids.Add(question.Id) ||
                !Content(question.Text, question.ImageId, 2000))
                return "คำถามต้องมีรหัสไม่ซ้ำและมีข้อความหรือรูปภาพ";
            if (question.Options is null || question.Options.Count != 4 ||
                question.Options.Any(x => x is null) ||
                question.Options.Count(x => x.IsCorrect) != 1)
                return "แต่ละข้อต้องมี 4 ตัวเลือก และถูกต้องเพียง 1 ตัวเลือก";
            foreach (var option in question.Options)
                if (option.Id == Guid.Empty || !ids.Add(option.Id) ||
                    !Content(option.Text, option.ImageId, 1000))
                    return "ตัวเลือกต้องมีรหัสไม่ซ้ำและมีข้อความหรือรูปภาพ";
        }
        return null;
    }

    private static bool Content(string? text, Guid? image, int max) =>
        (text?.Length ?? 0) <= max &&
        (!string.IsNullOrWhiteSpace(text) || (image.HasValue && image != Guid.Empty));

    public static ExamSnapshot Sample(ExamDefinition definition)
    {
        var error = Validate(definition);
        if (error is not null) throw new ArgumentException(error);
        var questions = Shuffle(definition.Questions).Take(definition.QuestionCount)
            .Select(q => q with { Options = Shuffle(q.Options) }).ToList();
        return new(definition.PassingPercent, questions);
    }

    private static List<T> Shuffle<T>(IEnumerable<T> source)
    {
        var items = source.ToList();
        for (var i = items.Count - 1; i > 0; i--)
        {
            var j = RandomNumberGenerator.GetInt32(i + 1);
            (items[i], items[j]) = (items[j], items[i]);
        }
        return items;
    }

    public static string? ValidateAnswers(ExamSnapshot snapshot, List<ExamAnswer>? answers, bool submit)
    {
        if (answers is null || answers.Any(a => a is null) ||
            answers.Select(a => a.QuestionId).Distinct().Count() != answers.Count)
            return "คำตอบซ้ำหรือข้อมูลคำตอบไม่ครบ";
        foreach (var answer in answers)
        {
            var question = snapshot.Questions.SingleOrDefault(q => q.Id == answer.QuestionId);
            if (question is null || !question.Options.Any(o => o.Id == answer.OptionId))
                return "คำตอบไม่อยู่ในชุดข้อสอบนี้ กรุณาโหลดแบบทดสอบอีกครั้ง";
        }
        return submit && answers.Count != snapshot.Questions.Count
            ? "กรุณาตอบให้ครบทุกข้อก่อนส่ง" : null;
    }

    public static ExamScore Score(ExamSnapshot snapshot, List<ExamAnswer> answers)
    {
        var error = ValidateAnswers(snapshot, answers, true);
        if (error is not null) throw new ArgumentException(error);
        var score = snapshot.Questions.Count(q =>
            answers.Any(a => a.QuestionId == q.Id && q.Options.Any(o => o.Id == a.OptionId && o.IsCorrect)));
        var rawPercent = score * 100m / snapshot.Questions.Count;
        return new(score, snapshot.Questions.Count, decimal.Round(rawPercent, 2),
            rawPercent >= snapshot.PassingPercent);
    }

    public static IEnumerable<Guid> Images(IEnumerable<ExamQuestion> questions) =>
        questions.SelectMany(q => q.Options.Select(o => o.ImageId).Append(q.ImageId))
            .Where(id => id.HasValue).Select(id => id!.Value).Distinct();

    public static bool IsOpen(string section, DateTime now, DateTime firstStart, DateTime lastEnd) =>
        section == "PRE" ? now < firstStart :
        section == "POST" && now >= lastEnd && now < lastEnd.AddDays(7);

    public static string? ImageType(byte[] bytes)
    {
        if (bytes.Length is < 12 or > MaxImageBytes) return null;
        if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return "image/jpeg";
        if (bytes.AsSpan(0, 8).SequenceEqual(new byte[] {137,80,78,71,13,10,26,10})) return "image/png";
        if (bytes.AsSpan(0, 4).SequenceEqual("RIFF"u8) && bytes.AsSpan(8, 4).SequenceEqual("WEBP"u8)) return "image/webp";
        return null;
    }
}
