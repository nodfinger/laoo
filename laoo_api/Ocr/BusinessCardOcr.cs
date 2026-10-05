using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using SkiaSharp;
using TesseractOCR;
using TesseractOCR.Enums;

namespace LaooApi.Ocr;

public sealed record OcrWord(string Text, double Confidence, int Left, int Top, int Width, int Height, string Line);
public sealed record OcrSuggestion(string Field, string? Value, string[] Candidates, bool NeedsReview = true);
public sealed record OcrResult(string Text, IReadOnlyList<OcrWord> Words, IReadOnlyList<OcrSuggestion> Suggestions);
public sealed class OcrFailure(string code, string message, string description) : Exception(message)
{
    public string Code { get; } = code;
    public string Description { get; } = description;
}
public interface IBusinessCardOcr
{
    bool IsAvailable { get; }
    Task<OcrResult> ReadAsync(byte[] image, int timeoutSeconds, CancellationToken token);
}
public static class BusinessCardImage
{
    public static byte[] Normalize(byte[] input)
    {
        using var stream = new SKMemoryStream(input);
        using var codec = SKCodec.Create(stream);
        if (codec is null || codec.EncodedFormat is not (SKEncodedImageFormat.Jpeg or SKEncodedImageFormat.Png or SKEncodedImageFormat.Webp))
            throw new OcrFailure("INVALID_IMAGE", "อ่านรูปนามบัตรไม่ได้", "ใช้ภาพ JPG, PNG หรือ WebP ที่เปิดดูได้");
        var info = codec.Info;
        if (info.Width < 32 || info.Height < 32 || (long)info.Width * info.Height > 20_000_000)
            throw new OcrFailure("IMAGE_DIMENSIONS", "ขนาดภาพไม่เหมาะสม", "ใช้ภาพอย่างน้อย 32 พิกเซล และไม่เกิน 20 ล้านพิกเซล");
        using var bitmap = SKBitmap.Decode(codec);
        if (bitmap is null) throw new OcrFailure("INVALID_IMAGE", "ภาพเสียหาย", "เลือกภาพใหม่แล้วลองอีกครั้ง");
        var origin = codec.EncodedOrigin;
        var swap = origin is SKEncodedOrigin.LeftTop or SKEncodedOrigin.RightTop or SKEncodedOrigin.RightBottom or SKEncodedOrigin.LeftBottom;
        using var oriented = new SKBitmap(swap ? info.Height : info.Width, swap ? info.Width : info.Height);
        using (var canvas = new SKCanvas(oriented))
        {
            var matrix = origin switch
            {
                SKEncodedOrigin.TopRight => Matrix(-1, 0, info.Width, 0, 1, 0),
                SKEncodedOrigin.BottomRight => Matrix(-1, 0, info.Width, 0, -1, info.Height),
                SKEncodedOrigin.BottomLeft => Matrix(1, 0, 0, 0, -1, info.Height),
                SKEncodedOrigin.LeftTop => Matrix(0, 1, 0, 1, 0, 0),
                SKEncodedOrigin.RightTop => Matrix(0, -1, info.Height, 1, 0, 0),
                SKEncodedOrigin.RightBottom => Matrix(0, -1, info.Height, -1, 0, info.Width),
                SKEncodedOrigin.LeftBottom => Matrix(0, 1, 0, -1, 0, info.Width),
                _ => SKMatrix.Identity
            };
            canvas.SetMatrix(matrix);
            canvas.DrawBitmap(bitmap, 0, 0, new SKSamplingOptions(SKFilterMode.Nearest));
        }
        using var image = SKImage.FromBitmap(oriented);
        using var data = image.Encode(SKEncodedImageFormat.Png, 100);
        return data.ToArray();
    }
    private static SKMatrix Matrix(float xx,float xy,float x,float yx,float yy,float y) =>
        new() { ScaleX=xx,SkewX=xy,TransX=x,SkewY=yx,ScaleY=yy,TransY=y,Persp2=1 };
}
public sealed class TesseractBusinessCardOcr(IConfiguration configuration, IWebHostEnvironment environment,
    ILogger<TesseractBusinessCardOcr> logger) : IBusinessCardOcr
{
    private static readonly SemaphoreSlim Slots = new(2, 2);
    private string DataPath => configuration["Ocr:TessdataPath"] ??
        Path.Combine(environment.ContentRootPath, "App_Data", "tessdata");
    public bool IsAvailable => File.Exists(Path.Combine(DataPath,"tha.traineddata")) &&
        File.Exists(Path.Combine(DataPath,"eng.traineddata"));

    public async Task<OcrResult> ReadAsync(byte[] image, int timeoutSeconds, CancellationToken token)
    {
        if (!IsAvailable) throw new OcrFailure("ENGINE_UNAVAILABLE", "เครื่องมือ OCR ยังไม่พร้อม", "ให้ผู้ดูแลตรวจการติดตั้ง Tesseract และโมเดลภาษาไทย/อังกฤษ");
        if (!await Slots.WaitAsync(0, token))
            throw new OcrFailure("BUSY", "กำลังอ่านนามบัตรรายการอื่น", "รอสักครู่แล้วลองใหม่");
        var releaseInContinuation=false;
        try
        {
            var job=Task.Run(()=>Read(image),CancellationToken.None);
            var deadline=Task.Delay(TimeSpan.FromSeconds(Math.Clamp(timeoutSeconds,5,120)),token);
            if(await Task.WhenAny(job,deadline)!=job)
            {
                if (token.IsCancellationRequested) throw new OperationCanceledException(token);
                releaseInContinuation=true;
                _=job.ContinueWith(completed=>
                {
                    if(completed.IsFaulted)logger.LogWarning(completed.Exception,"Timed-out OCR job completed with an error");
                    Slots.Release();
                },CancellationToken.None,TaskContinuationOptions.ExecuteSynchronously,TaskScheduler.Default);
                throw new OcrFailure("TIMEOUT", "อ่านนามบัตรไม่ทันเวลาที่กำหนด", "ลองใช้ภาพที่ครอบเฉพาะนามบัตร หรือเพิ่มเวลาในหน้าตั้งค่า");
            }
            return await job;
        }
        finally
        {
            if(!releaseInContinuation)Slots.Release();
        }
    }
    private OcrResult Read(byte[] image)
    {
        try
        {
            using var engine=new Engine(DataPath,"tha+eng",EngineMode.LstmOnly);
            using var source=TesseractOCR.Pix.Image.LoadFromMemory(image);
            using var page=engine.Process(source,PageSegMode.SparseText);
            var tsv=new StringBuilder("level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n");
            var blockNumber=0;
            foreach(var block in page.Layout)
            {
                blockNumber++;var paragraphNumber=0;
                foreach(var paragraph in block.Paragraphs)
                {
                    paragraphNumber++;var lineNumber=0;
                    foreach(var line in paragraph.TextLines)
                    {
                        lineNumber++;var wordNumber=0;
                        foreach(var word in line.Words)
                        {
                            wordNumber++;var box=word.BoundingBox;
                            if(box is null||string.IsNullOrWhiteSpace(word.Text))continue;
                            tsv.Append("5\t1\t").Append(blockNumber).Append('\t').Append(paragraphNumber).Append('\t')
                                .Append(lineNumber).Append('\t').Append(wordNumber).Append('\t')
                                .Append(box.Value.X1).Append('\t').Append(box.Value.Y1).Append('\t')
                                .Append(box.Value.Width).Append('\t').Append(box.Value.Height).Append('\t')
                                .Append(word.Confidence.ToString(CultureInfo.InvariantCulture)).Append('\t')
                                .AppendLine(word.Text.Replace('\t',' ').Replace('\r',' ').Replace('\n',' '));
                        }
                    }
                }
            }
            return BusinessCardParser.Parse(tsv.ToString());
        }
        catch(OcrFailure){throw;}
        catch(Exception error)
        {
            logger.LogError(error,"Embedded Tesseract failed");
            throw new OcrFailure("ENGINE_ERROR","อ่านนามบัตรไม่สำเร็จ","ตรวจภาพและโมเดลภาษาไทย/อังกฤษ แล้วลองใหม่");
        }
    }
}
public static class BusinessCardParser
{
    private static Regex Pattern(string value) => new(value, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant, TimeSpan.FromMilliseconds(200));
    public static OcrResult Parse(string tsv)
    {
        var words = new List<OcrWord>();
        foreach (var row in tsv.Split('\n').Skip(1))
        {
            var c = row.TrimEnd('\r').Split('\t', 12);
            if (c.Length != 12 || c[0] != "5" || string.IsNullOrWhiteSpace(c[11])) continue;
            if (!int.TryParse(c[6], out var x) || !int.TryParse(c[7], out var y) ||
                !int.TryParse(c[8], out var w) || !int.TryParse(c[9], out var h) ||
                !double.TryParse(c[10], NumberStyles.Float, CultureInfo.InvariantCulture, out var confidence)) continue;
            words.Add(new(c[11].Trim(), confidence, x, y, w, h, string.Join("-", c.Skip(1).Take(4))));
        }
        var rawLines = words.GroupBy(x => x.Line).Select(g => string.Join(" ", g.Select(w => w.Text))).ToArray();
        var text = string.Join("\n", rawLines);
        var thaiGlyphSpacing = Pattern(@"(?:[\u0E00-\u0E7F]\s+){3,}");
        var thaiGap = Pattern(@"(?<=[\u0E00-\u0E7F])\s+(?=[\u0E00-\u0E7F])");
        var lines = rawLines.Select(line => thaiGlyphSpacing.IsMatch(line) ? thaiGap.Replace(line, "") : line).ToArray();
        var email = Pattern(@"[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}");
        var phone = Pattern(@"(?<!\d)(?:\+66[\s.\-]?[1-9]|0[1-9])(?:[\s().\-]?\d){7,8}(?!\d)");
        var company = Pattern(@"บริษัท|บ\s*ริ\s*ษั\s*ท|ห้างหุ้นส่วน|จำกัด|จำ\s*กัด|\b(?:co\.?|ltd\.?|limited|inc\.?|corporation|company)\b");
        var position = Pattern(@"ผู้จัดการ|กรรมการ|ฝ่ายขาย|วิศวกร|\b(?:manager|director|engineer|sales|chief|president|officer)\b");
        var address = Pattern(@"ถนน|แขวง|ตำบล|อำเภอ|จังหวัด|กรุงเทพ|ถ\.|ต\.|อ\.|\b(?:road|street|avenue|bangkok)\b|\b\d{5}\b");
        var website = Pattern(@"(?:https?://|www\.)[a-z0-9.\-]+\.[a-z]{2,}(?:/[^\s]*)?");
        var line = Pattern(@"(?:LINE|ไลน์)\s*(?:ID)?\s*[:：]\s*(@?[a-z0-9._\-]+)");
        string[] Find(Regex regex) => regex.Matches(text).Select(m => m.Value.Trim()).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        var companyLines = lines.Where(l => company.IsMatch(l)).ToArray();
        var positionLines = lines.Where(l => position.IsMatch(l) && !company.IsMatch(l)).ToArray();
        var addressLines = lines.Where(l => address.IsMatch(l) && !email.IsMatch(l) && !website.IsMatch(l) && !company.IsMatch(l)).ToArray();
        var names = lines.Where(l => !company.IsMatch(l) && !position.IsMatch(l) && !address.IsMatch(l) &&
            !email.IsMatch(l) && !phone.IsMatch(l) && !website.IsMatch(l) && !line.IsMatch(l) &&
            !Pattern(@"\d|www\.|https?://|@").IsMatch(l) &&
            (Pattern(@"^(นาย|นางสาว|นาง|Mr\.?|Ms\.?|Mrs\.?|Dr\.?)\s*").IsMatch(l) ||
             Pattern(@"^[\p{L}\p{M}.'\-]+\s+[\p{L}\p{M}.'\-\s]+$").IsMatch(l))).ToArray();
        var lineIds = line.Matches(text).Select(m => m.Groups[1].Value).Distinct().ToArray();
        OcrSuggestion Suggest(string field, string[] candidates) => new(field, candidates.FirstOrDefault(), candidates);
        return new(text, words, new[] {
            Suggest("name", names), Suggest("company", companyLines), Suggest("position", positionLines),
            Suggest("phone", Find(phone)), Suggest("email", Find(email)), Suggest("website", Find(website)),
            Suggest("line", lineIds), Suggest("address", addressLines.Length == 0 ? [] : [string.Join(" ", addressLines)])
        });
    }
}
