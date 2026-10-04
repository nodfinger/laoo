using Microsoft.AspNetCore.Mvc;

namespace Laoo.SchoolFood.Controllers;

public sealed partial class SchoolFoodController
{
    [HttpGet("sales")]
    public async Task<IActionResult> Sales([FromQuery]int page=1,[FromQuery]int pageSize=10,[FromQuery]long? shop=null,
        [FromQuery]long? student=null,[FromQuery]DateTime? from=null,[FromQuery]DateTime? to=null,CancellationToken ct=default)
    {
        await using var db=await Open(ct);if(await Guard(db,"53009","VIEW",ct,shop) is {} f)return f;
        var scope=await SchoolFoodAccess.ShopScope(db,Company,Actor,ct);shop=scope??shop;
        page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        const string source="""
 FROM dbo.TDSFSale S JOIN dbo.TDSFShop H ON H.CompanyID=S.CompanyID AND H.ShopID=S.ShopID
 JOIN dbo.TDSCStudent ST ON ST.CompanyID=S.CompanyID AND ST.StudentID=S.StudentID
 WHERE S.CompanyID=@co AND (@shop IS NULL OR S.ShopID=@shop) AND (@student IS NULL OR S.StudentID=@student)
 AND (@from IS NULL OR S.CreatedAt>=@from) AND (@to IS NULL OR S.CreatedAt<@to)
""";
        var values=new (string,object?)[]{("@co",Company),("@shop",shop),("@student",student),("@from",from?.Date.AddHours(-7)),("@to",to?.Date.AddDays(1).AddHours(-7))};
        var rows=await FoodDb.Rows(db,null,"SELECT S.SaleID id,S.ReceiptNo code,H.ShopName shop,CONCAT(ST.FirstName,N' ',ST.LastName) student,S.TotalAmount total,S.RefundedAmount refunded,S.CreatedAt date"+source+" ORDER BY S.SaleID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,[..values,("@offset",(page-1)*pageSize),("@size",pageSize)]);
        var total=await FoodDb.Id(db,null,"SELECT COUNT(*)"+source,ct,values);return Ok(new{rows,total,page,pageSize});
    }

    [HttpGet("sales/{id:long}")]
    public async Task<IActionResult> SaleDetail(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);if(await Guard(db,"53009","VIEW",ct) is {} f)return f;
        var scope=await SchoolFoodAccess.ShopScope(db,Company,Actor,ct);
        var header=await FoodDb.Rows(db,null,"SELECT * FROM dbo.TDSFSale WHERE CompanyID=@co AND SaleID=@id AND (@shop IS NULL OR ShopID=@shop)",ct,("@co",Company),("@id",id),("@shop",scope));
        if(header.Count!=1)return NotFound();
        var items=await FoodDb.Rows(db,null,"SELECT SaleItemID id,ItemID,ItemNameSnapshot name,Quantity,ReturnedQuantity,UnitPrice,NetAmount,CommissionRate,CommissionAmount FROM dbo.TDSFSaleItem WHERE CompanyID=@co AND SaleID=@id ORDER BY SaleItemID",ct,("@co",Company),("@id",id));
        return Ok(new{header=header[0],items});
    }

    [HttpGet("reports/{menu}")]
    public async Task<IActionResult> Report(string menu,[FromQuery]string dimension="shop",[FromQuery]DateTime? from=null,
        [FromQuery]DateTime? to=null,[FromQuery]long? shop=null,[FromQuery]int page=1,[FromQuery]int pageSize=20,CancellationToken ct=default)
    {
        if(menu is not ("53010" or "53011" or "53012"))return NotFound();
        if(menu=="53010")dimension="student";
        if(menu=="53011")dimension="shop";
        var group=dimension switch{
            "shop"=>"CONCAT(S.ShopID,N' · ',H.ShopName)",
            "category"=>"COALESCE(I.ItemTypeSnapshot,N'ไม่ระบุ')",
            "item"=>"CONCAT(I.ItemID,N' · ',I.ItemNameSnapshot)",
            "level"=>"CONVERT(nvarchar(50),S.LevelID)",
            "student"=>"CONCAT(S.StudentID,N' · ',ST.FirstName,N' ',ST.LastName)",
            "classroom"=>"S.ClassroomSnapshot",
            "day"=>"CONVERT(nvarchar(10),DATEADD(hour,7,S.CreatedAt),23)",
            "month"=>"CONVERT(nvarchar(7),DATEADD(hour,7,S.CreatedAt),23)",
            "year"=>"CONVERT(nvarchar(4),DATEADD(hour,7,S.CreatedAt),23)",_=>null};
        if(group is null)return Bad("เลือกมิติร้านค้า ประเภท สินค้า ชั้นปี นักเรียน วัน เดือน หรือปี");
        var begin=(from??DateTime.UtcNow.AddHours(7).Date).Date;
        var end=(to??begin).Date;
        if(end<begin||end>begin.AddYears(5))return Bad("ช่วงวันที่ไม่ถูกต้อง หรือเกิน 5 ปี");
        await using var db=await Open(ct);if(await Guard(db,menu,"VIEW",ct,shop,schoolOnly:menu=="53010") is {} f)return f;
        var scope=await SchoolFoodAccess.ShopScope(db,Company,Actor,ct);shop=scope??shop;page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        // Sales-cohort report: refunds are attributed back to the original sale date.
        var cte=$"""
WITH Totals AS (
 SELECT {group} name,
 SUM(I.NetAmount) gross,
 SUM(ROUND(I.NetAmount*I.ReturnedQuantity/I.Quantity,2)) refunds,
 SUM(I.NetAmount-ROUND(I.NetAmount*I.ReturnedQuantity/I.Quantity,2)) net,
 SUM(I.CommissionAmount-ROUND(I.CommissionAmount*I.ReturnedQuantity/I.Quantity,2)) commission
 FROM dbo.TDSFSale S
 JOIN dbo.TDSFSaleItem I ON I.CompanyID=S.CompanyID AND I.SaleID=S.SaleID
 JOIN dbo.TDSFShop H ON H.CompanyID=S.CompanyID AND H.ShopID=S.ShopID
 JOIN dbo.TDSCStudent ST ON ST.CompanyID=S.CompanyID AND ST.StudentID=S.StudentID
 WHERE S.CompanyID=@co AND (@shop IS NULL OR S.ShopID=@shop) AND S.CreatedAt>=@from AND S.CreatedAt<@to
 GROUP BY {group}
)
""";
        // Settlement follows cash event dates, not the original sale cohort.
        if(menu=="53011")cte="""
WITH Events AS (
 SELECT S.ShopID,S.TotalAmount gross,CAST(0 AS decimal(18,2)) refunds,S.CommissionAmount commission
 FROM dbo.TDSFSale S WHERE S.CompanyID=@co AND (@shop IS NULL OR S.ShopID=@shop)
 AND S.CreatedAt>=@from AND S.CreatedAt<@to
 UNION ALL
 SELECT S.ShopID,CAST(0 AS decimal(18,2)),R.Amount,-R.CommissionAmount
 FROM dbo.TDSFRefund R JOIN dbo.TDSFSale S ON S.CompanyID=R.CompanyID AND S.SaleID=R.SaleID
 WHERE R.CompanyID=@co AND (@shop IS NULL OR S.ShopID=@shop) AND R.CreatedAt>=@from AND R.CreatedAt<@to
), Totals AS (
 SELECT CONCAT(E.ShopID,N' · ',H.ShopName) name,SUM(E.gross) gross,SUM(E.refunds) refunds,
 SUM(E.gross-E.refunds) net,SUM(E.commission) commission
 FROM Events E JOIN dbo.TDSFShop H ON H.CompanyID=@co AND H.ShopID=E.ShopID
 GROUP BY E.ShopID,H.ShopName
)
""";
        var values=new (string,object?)[]{("@co",Company),("@shop",shop),("@from",begin.AddHours(-7)),("@to",end.AddDays(1).AddHours(-7))};
        var rows=await FoodDb.Rows(db,null,cte+"SELECT name,gross,refunds,net,commission,net-commission payable,CASE WHEN SUM(net) OVER()=0 THEN 0 ELSE net*100/SUM(net) OVER() END percentage FROM Totals ORDER BY net DESC,name OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,[..values,("@offset",(page-1)*pageSize),("@size",pageSize)]);
        var total=await FoodDb.Id(db,null,cte+"SELECT COUNT(*) FROM Totals",ct,values);
        return Ok(new{rows,total,page,pageSize,from=begin,to=end,refundAttribution=menu=="53011"?"REFUND_EVENT_DATE":"ORIGINAL_SALE_DATE"});
    }
}
