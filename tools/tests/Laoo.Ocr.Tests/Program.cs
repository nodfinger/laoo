using LaooApi.Ocr;
using SkiaSharp;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Logging.Abstractions;

var passed=0;
void Check(bool condition,string name)
{ if(!condition)throw new InvalidOperationException("FAIL: "+name); Console.WriteLine("PASS: "+name);passed++; }
string Tsv(params string[] lines)=>"level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n"+
    string.Join("\n",lines.Select((line,i)=>$"5\t1\t1\t1\t{i+1}\t1\t10\t{i*25}\t200\t20\t94.5\t{line}"));
string? Value(OcrResult result,string field)=>result.Suggestions.Single(x=>x.Field==field).Value;

var english=BusinessCardParser.Parse(Tsv("John Smith","LAOO Example Co., Ltd.","Sales Manager",
    "Mobile: 081-234-5678","Email: john@example.test","https://example.test","LINE ID: john.test","99 Example Road Bangkok 10110"));
Check(Value(english,"name")=="John Smith","English contact name");
Check(Value(english,"company")=="LAOO Example Co., Ltd.","Company distinct from contact");
Check(Value(english,"position")=="Sales Manager","Position mapping");
Check(Value(english,"phone")=="081-234-5678","Thai telephone with separators");
Check(Value(english,"email")=="john@example.test","Email mapping");
Check(Value(english,"line")=="john.test","LINE mapping");
Check(Value(english,"website")=="https://example.test","Website mapping");
Check(Value(english,"address")!.Contains("10110"),"Address mapping");
Check(english.Words.Count==8&&english.Words[0].Left==10&&english.Words[0].Confidence==94.5,"Word position and confidence preserved");
Check(english.Suggestions.All(x=>x.NeedsReview),"Every suggestion requires human review");
var thai=BusinessCardParser.Parse(Tsv("นาย สมชาย ใจดี","บริษัท ตัวอย่าง จำกัด","ผู้จัดการ",
    "โทร 081 234 5678 / 02-123-4567","อีเมล somchai@example.test","99 ถนนพระราม 9 กรุงเทพ 10310"));
Check(Value(thai,"name")=="นาย สมชาย ใจดี","Thai name");
Check(Value(thai,"company")=="บริษัท ตัวอย่าง จำกัด","Thai company");
Check(thai.Suggestions.Single(x=>x.Field=="phone").Candidates.Length==2,"Multiple phones stay alternatives");
Check(BusinessCardParser.Parse("bad\tinput").Words.Count==0,"Malformed TSV ignored");
Check(BusinessCardParser.Parse(Tsv()).Suggestions.All(x=>x.Value==null),"No invented fields for empty OCR");
Check(Value(BusinessCardParser.Parse(Tsv("javascript:alert(1)")),"website")==null,"Script URL never suggested");
Check(Value(BusinessCardParser.Parse(Tsv("data:image/png;base64,ABC")),"website")==null,"Data URI never suggested");
try { BusinessCardImage.Normalize("not an image"u8.ToArray()); Check(false,"Invalid bytes"); }
catch(OcrFailure e){Check(e.Code=="INVALID_IMAGE","Invalid image rejected by content");}
using(var small=new SKBitmap(16,16)){
  using var image=SKImage.FromBitmap(small);using var data=image.Encode(SKEncodedImageFormat.Png,100);
  try{BusinessCardImage.Normalize(data.ToArray());Check(false,"Small image");}
  catch(OcrFailure e){Check(e.Code=="IMAGE_DIMENSIONS","Tiny image rejected");}
}
using(var bitmap=new SKBitmap(96,64)){
  bitmap.Erase(SKColors.White);
  using var image=SKImage.FromBitmap(bitmap);using var data=image.Encode(SKEncodedImageFormat.Jpeg,90);
  var normalized=BusinessCardImage.Normalize(data.ToArray());
  using var decoded=SKBitmap.Decode(normalized);
  Check(decoded.Width==96&&decoded.Height==64,"Valid JPEG normalized without dimensions change");
  Check(normalized.AsSpan(0,8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10}),"Normalized output is PNG");
}
var config=new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>{
  ["Ocr:TesseractPath"]=Path.Combine(Path.GetTempPath(),Guid.NewGuid()+".exe")}).Build();
var unavailableEnvironment=new TestEnvironment{ContentRootPath=Path.Combine(Path.GetTempPath(),Guid.NewGuid().ToString("N"))};
var engine=new TesseractBusinessCardOcr(config,unavailableEnvironment,NullLogger<TesseractBusinessCardOcr>.Instance);
Check(!engine.IsAvailable,"Missing engine unavailable");
try{await engine.ReadAsync([],30,CancellationToken.None);Check(false,"Missing engine");}
catch(OcrFailure e){Check(e.Code=="ENGINE_UNAVAILABLE","Missing engine returns actionable error");}
using(var bitmap=new SKBitmap(96,64))
{
    using(var canvas=new SKCanvas(bitmap))
    using(var paint=new SKPaint())
    {
        foreach(var (rect,color) in new[]{
            (new SKRect(0,0,48,32),SKColors.Red),(new SKRect(48,0,96,32),SKColors.Green),
            (new SKRect(0,32,48,64),SKColors.Blue),(new SKRect(48,32,96,64),SKColors.Yellow)})
        {paint.Color=color;canvas.DrawRect(rect,paint);}
    }
    using var image=SKImage.FromBitmap(bitmap);using var data=image.Encode(SKEncodedImageFormat.Jpeg,100);
    var jpeg=data.ToArray();
    SKColor[] expected=[SKColors.Red,SKColors.Green,SKColors.Yellow,SKColors.Blue,SKColors.Red,SKColors.Blue,SKColors.Yellow,SKColors.Green];
    for(byte origin=1;origin<=8;origin++)
    {
        // A minimal EXIF APP1 segment: little-endian TIFF with Orientation.
        byte[] exif=[0xff,0xe1,0,34,69,120,105,102,0,0,73,73,42,0,8,0,0,0,
            1,0,0x12,1,3,0,1,0,0,0,origin,0,0,0,0,0,0,0];
        var card=jpeg.Take(2).Concat(exif).Concat(jpeg.Skip(2)).ToArray();
        using var result=SKBitmap.Decode(BusinessCardImage.Normalize(card));
        var actual=result.GetPixel(5,5);var wanted=expected[origin-1];
        Check(result.Width==(origin>=5?64:96)&&result.Height==(origin>=5?96:64)
            &&Math.Abs(actual.Red-wanted.Red)<20&&Math.Abs(actual.Green-wanted.Green)<20&&Math.Abs(actual.Blue-wanted.Blue)<20,
            $"EXIF orientation {origin}");
    }
}
byte[] Card(params string[] lines)
{
    using var bitmap=new SKBitmap(1400,800);
    using var canvas=new SKCanvas(bitmap);
    canvas.Clear(SKColors.White);
    using var typeface=SKTypeface.FromFile(@"C:\Windows\Fonts\tahoma.ttf") ?? SKTypeface.Default;
    using var font=new SKFont(typeface,42);
    using var paint=new SKPaint{Color=SKColors.Black,IsAntialias=true};
    var y=80f;
    foreach(var line in lines){canvas.DrawText(line,60,y,SKTextAlign.Left,font,paint);y+=82;}
    using var encoded=SKImage.FromBitmap(bitmap).Encode(SKEncodedImageFormat.Png,100);
    return encoded.ToArray();
}
var runtimeEnvironment=new TestEnvironment{ContentRootPath=Path.Combine(Directory.GetCurrentDirectory(),"laoo_api")};
var liveEngine=new TesseractBusinessCardOcr(new ConfigurationBuilder().Build(),runtimeEnvironment,NullLogger<TesseractBusinessCardOcr>.Instance);
Check(liveEngine.IsAvailable,"Embedded Tesseract tha+eng runtime available");
var englishCard=Card("John Smith","LAOO Example Company Limited","Sales Manager","081-234-5678","john@example.com","www.example.com");
var samplePath=Environment.GetEnvironmentVariable("OCR_SAMPLE_PATH");
if(!string.IsNullOrWhiteSpace(samplePath))
{
    Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(samplePath))!);
    await File.WriteAllBytesAsync(samplePath,englishCard);
}
var realEnglish=await liveEngine.ReadAsync(englishCard,30,CancellationToken.None);
Check(Value(realEnglish,"name")?.Contains("John Smith",StringComparison.OrdinalIgnoreCase)==true,"Real OCR English name field");
Check(Value(realEnglish,"company")?.Contains("Company",StringComparison.OrdinalIgnoreCase)==true,"Real OCR English company field");
Check(Value(realEnglish,"phone")?.Replace(" ","")=="081-234-5678","Real OCR English phone field");
Check(Value(realEnglish,"email")?.Equals("john@example.com",StringComparison.OrdinalIgnoreCase)==true,"Real OCR English email field");
var realThai=await liveEngine.ReadAsync(Card("นาย สมชาย ใจดี","บริษัท ลาว ตัวอย่าง จำกัด","ผู้จัดการฝ่ายขาย","081-234-5678","somchai@example.com"),30,CancellationToken.None);
Check(Value(realThai,"name")?.Contains("สมชาย",StringComparison.Ordinal)==true,"Real OCR Thai name field");
Check(Value(realThai,"company")?.Contains("บริษัท",StringComparison.Ordinal)==true,"Real OCR Thai company field");
Check(Value(realThai,"phone")?.Replace(" ","")=="081-234-5678","Real OCR Thai phone field");
Check(Value(realThai,"email")?.Equals("somchai@example.com",StringComparison.OrdinalIgnoreCase)==true,"Real OCR Thai email field");
Console.WriteLine($"{passed} checks passed. Includes generated-image OCR; no database flow claim.");

sealed class TestEnvironment:IWebHostEnvironment {
  public string ApplicationName {get;set;}="Laoo.Ocr.Tests";
  public string EnvironmentName {get;set;}="Testing";
  public string ContentRootPath {get;set;}=Path.GetTempPath();
  public IFileProvider ContentRootFileProvider {get;set;}=new NullFileProvider();
  public string WebRootPath {get;set;}="";
  public IFileProvider WebRootFileProvider {get;set;}=new NullFileProvider();
}
