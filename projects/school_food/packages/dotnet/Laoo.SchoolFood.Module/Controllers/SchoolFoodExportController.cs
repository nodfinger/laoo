using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
namespace Laoo.SchoolFood.Controllers;
public sealed partial class SchoolFoodController
{
    [HttpGet("reports/{menu}/export")]
    public async Task<IActionResult> ExportReport(string menu,[FromQuery]string dimension="shop",
        [FromQuery]DateTime? from=null,[FromQuery]DateTime? to=null,[FromQuery]long? shop=null,CancellationToken ct=default)
    {
        if(menu is not ("53010" or "53011" or "53012"))return NotFound();
        await using var db=await Open(ct);
        if(await Guard(db,menu,"EXPORT",ct,shop,schoolOnly:menu=="53010") is {} f)return f;
        var csv=new StringBuilder();
        csv.AppendLine("รายการ,ยอดขาย,คืนสินค้า,ยอดสุทธิ,ค่าหัก,ยอดจ่ายร้าน,สัดส่วน");
        for(var page=1;page<=100;page++)
        {
            var response=await Report(menu,dimension,from,to,shop,page,100,ct);
            if(response is not OkObjectResult ok)return response;
            var data=JsonSerializer.SerializeToElement(ok.Value);
            if(data.GetProperty("total").GetInt64()>10000)return StatusCode(413,new{message="ข้อมูลส่งออกมากเกินไป",description="ลดช่วงวันที่ให้ไม่เกิน 10,000 รายการแล้วลองใหม่"});
            foreach(var row in data.GetProperty("rows").EnumerateArray())
                csv.AppendLine(string.Join(",",new[]{"name","gross","refunds","net","commission","payable","percentage"}.Select(k=>CsvCell(row.GetProperty(k).ToString()))));
            if(page*100>=data.GetProperty("total").GetInt64())break;
        }
        var bytes=Encoding.UTF8.GetPreamble().Concat(Encoding.UTF8.GetBytes(csv.ToString())).ToArray();
        return File(bytes,"text/csv; charset=utf-8",$"school-food-{menu}-{DateTime.UtcNow:yyyyMMdd}.csv");
    }
    private static string CsvCell(string value)
    {
        if(value.Length>0&&("=+-@".Contains(value[0])||char.IsControl(value[0])))value="'"+value;
        var quote=((char)34).ToString();
        return quote+value.Replace(quote,quote+quote)+quote;
    }
}
