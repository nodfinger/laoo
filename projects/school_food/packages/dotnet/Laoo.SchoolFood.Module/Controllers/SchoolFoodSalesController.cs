using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;

namespace Laoo.SchoolFood.Controllers;

public sealed partial class SchoolFoodController
{
    [HttpGet("shops/{shop:long}/products")]
    public async Task<IActionResult> Products(long shop,[FromQuery]int page=1,[FromQuery]int pageSize=24,
        [FromQuery]string? search=null,CancellationToken ct=default)
    {
        await using var db=await Open(ct);if(await Guard(db,"53008","VIEW",ct,shop) is {} f)return f;
        page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        const string from="""
 FROM dbo.TDSFShopItem SI
 JOIN dbo.TDSFShop S ON S.CompanyID=SI.CompanyID AND S.ShopID=SI.ShopID AND S.IsActive=1
 JOIN dbo.TDIVItem I ON I.CompanyID=SI.CompanyID AND I.ItemID=SI.ItemID AND I.IsActive=1
 LEFT JOIN dbo.TDIVStockBalance B ON B.CompanyID=SI.CompanyID AND B.WarehouseID=S.WarehouseID AND B.ItemID=SI.ItemID
 WHERE SI.CompanyID=@co AND SI.ShopID=@shop AND SI.IsSellable=1
 AND (@q IS NULL OR I.ItemCode LIKE N'%'+@q+N'%' OR I.ItemName LIKE N'%'+@q+N'%')
""";
        var rows=await FoodDb.Rows(db,null,"SELECT I.ItemID id,I.ItemCode code,I.ItemName name,I.ItemTypeCode category,SI.SalePrice price,S.TrackStock trackStock,COALESCE(B.Quantity,0) stock"+from+" ORDER BY I.ItemCode OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,
            ("@co",Company),("@shop",shop),("@q",search),("@offset",(page-1)*pageSize),("@size",pageSize));
        var total=await FoodDb.Id(db,null,"SELECT COUNT(*)"+from,ct,("@co",Company),("@shop",shop),("@q",search));
        return Ok(new{rows,total,page,pageSize});
    }

    [HttpPost("sales")]
    public async Task<IActionResult> Sale(SaleInput input,CancellationToken ct)
    {
        if(input.Items is null||input.Items.Count is <1 or >100||input.Items.Any(x=>x.Quantity is <1 or >1000||x.ItemID<=0||x.DiscountAmount<0)
            ||input.Items.Select(x=>x.ItemID).Distinct().Count()!=input.Items.Count
            ||input.IdentifierKind is not ("CARD" or "QR")||string.IsNullOrWhiteSpace(input.Identifier)||input.Identifier.Length>256)
            return Bad("ระบุบัตรนักเรียนและสินค้าไม่ซ้ำ จำนวน 1–1000 ต่อรายการ");
        await using var db=await Open(ct);if(await Guard(db,"53008","SALE",ct,input.ShopID) is {} f)return f;
        return await Transact(db,input.RequestKey,"SALE",input,async(tx,op)=>{
            var settings=await FoodDb.Rows(db,tx,"SELECT IsEnabled,CommissionEnabled,DefaultCommissionRate FROM dbo.TDSFSetting WITH(HOLDLOCK) WHERE CompanyID=@co",ct,("@co",Company));
            if(settings.Count!=1||!settings[0].Bool("IsEnabled"))throw new FoodBusinessException("โรงเรียนยังไม่ได้เปิดใช้ระบบขายอาหาร");
            var shops=await FoodDb.Rows(db,tx,"SELECT TrackStock,WarehouseID,CommissionRate FROM dbo.TDSFShop WITH(HOLDLOCK) WHERE CompanyID=@co AND ShopID=@shop AND IsActive=1",ct,("@co",Company),("@shop",input.ShopID));
            if(shops.Count!=1)throw new FoodBusinessException("ร้านค้าปิดใช้งานหรือไม่มีในโรงเรียนนี้");
            var hash=SHA256.HashData(Encoding.UTF8.GetBytes(input.Identifier.Trim()));
            var students=await FoodDb.Rows(db,tx,"SELECT S.StudentID,S.ClassroomID,C.LevelID,C.RoomName FROM dbo.TDSFStudentIdentifier I WITH(HOLDLOCK) JOIN dbo.TDSCStudent S ON S.CompanyID=I.CompanyID AND S.StudentID=I.StudentID AND S.IsActive=1 JOIN dbo.TDSCClassroom C ON C.CompanyID=S.CompanyID AND C.ClassroomID=S.ClassroomID WHERE I.CompanyID=@co AND I.Kind=@kind AND I.IdentifierHash=@hash AND I.IsActive=1",ct,("@co",Company),("@kind",input.IdentifierKind),("@hash",hash));
            if(students.Count!=1)throw new FoodBusinessException("บัตรไม่พร้อมใช้งานหรือไม่พบนักเรียน");
            var student=students[0];var shop=shops[0];var setting=settings[0];
            var lines=new List<SaleLine>();decimal total=0,commission=0;
            foreach(var item in input.Items.OrderBy(x=>x.ItemID))
            {
                var rows=await FoodDb.Rows(db,tx,"""
SELECT I.ItemName,I.ItemTypeCode,I.StockTrackingCode,SI.SalePrice,
 (SELECT R.Rate FROM dbo.TDSFCommissionRule R WHERE R.CompanyID=SI.CompanyID AND R.ShopID=SI.ShopID AND R.ItemID=SI.ItemID) ItemRate,
 (SELECT R.Rate FROM dbo.TDSFCommissionRule R WHERE R.CompanyID=SI.CompanyID AND R.ShopID=SI.ShopID AND R.ItemID IS NULL AND R.ItemTypeCode=I.ItemTypeCode) TypeRate
FROM dbo.TDSFShopItem SI WITH(HOLDLOCK)
JOIN dbo.TDIVItem I ON I.CompanyID=SI.CompanyID AND I.ItemID=SI.ItemID AND I.IsActive=1
WHERE SI.CompanyID=@co AND SI.ShopID=@shop AND SI.ItemID=@item AND SI.IsSellable=1
""",ct,("@co",Company),("@shop",input.ShopID),("@item",item.ItemID));
                if(rows.Count!=1)throw new FoodBusinessException("สินค้าไม่เปิดขายในร้านนี้");
                var row=rows[0];
                if(shop.Bool("TrackStock")&&Convert.ToString(row["StockTrackingCode"])!="QUANTITY")
                    throw new FoodBusinessException("ร้านเก็บสต๊อกรองรับสินค้าติดตามจำนวนเท่านั้น");
                var price=row.Decimal("SalePrice");var net=price*item.Quantity-item.DiscountAmount;
                if(net<=0||item.DiscountAmount!=SchoolFoodRules.Money(item.DiscountAmount))
                    throw new FoodBusinessException("ส่วนลดต้องน้อยกว่ายอดสินค้าและมีทศนิยมไม่เกินสองตำแหน่ง");
                var rate=SchoolFoodRules.CommissionRate(setting.Bool("CommissionEnabled"),setting.Decimal("DefaultCommissionRate"),
                    shop["CommissionRate"] as decimal?,row["TypeRate"] as decimal?,row["ItemRate"] as decimal?);
                var cut=SchoolFoodRules.Money(net*rate/100);
                lines.Add(new(item.ItemID,Convert.ToString(row["ItemName"])!,Convert.ToString(row["ItemTypeCode"]),item.Quantity,price,item.DiscountAmount,net,rate,cut));
                total+=net;commission+=cut;
            }
            var receipt="SF-"+op;
            var balance=await FoodTransaction.Wallet(db,tx,Company,student.Long("StudentID"),op,Actor,-total,"SALE",receipt,null,null,ct);
            var sale=await FoodDb.Id(db,tx,"""
INSERT dbo.TDSFSale(CompanyID,ShopID,StudentID,OperationID,ReceiptNo,ClassroomID,LevelID,ClassroomSnapshot,TrackStock,WarehouseID,TotalAmount,CommissionAmount,CreatedBy)
OUTPUT INSERTED.SaleID VALUES(@co,@shop,@student,@op,@receipt,@class,@level,@room,@track,@wh,@total,@cut,@actor)
""",ct,("@co",Company),("@shop",input.ShopID),("@student",student.Long("StudentID")),("@op",op),("@receipt",receipt),("@class",student.Long("ClassroomID")),("@level",student.Long("LevelID")),("@room",student["RoomName"]),("@track",shop.Bool("TrackStock")),("@wh",shop["WarehouseID"]),("@total",total),("@cut",commission),("@actor",Actor));
            foreach(var line in lines)
            {
                var detail=await FoodDb.Id(db,tx,"INSERT dbo.TDSFSaleItem(CompanyID,SaleID,ItemID,ItemNameSnapshot,ItemTypeSnapshot,Quantity,UnitPrice,DiscountAmount,NetAmount,CommissionRate,CommissionAmount) OUTPUT INSERTED.SaleItemID VALUES(@co,@sale,@item,@name,@type,@qty,@price,@discount,@net,@rate,@cut)",ct,
                    ("@co",Company),("@sale",sale),("@item",line.ItemID),("@name",line.Name),("@type",line.Type),("@qty",line.Quantity),("@price",line.Price),("@discount",line.Discount),("@net",line.Net),("@rate",line.Rate),("@cut",line.Commission));
                if(shop.Bool("TrackStock"))await FoodTransaction.Stock(db,tx,Company,shop.Long("WarehouseID"),line.ItemID,-line.Quantity,"SALE_OUT",sale,detail,Actor,ct);
            }
            return new{id=sale,receipt,total,commission,balance};
        },ct);
    }

    [HttpPost("sales/{sale:long}/refunds")]
    public async Task<IActionResult> Refund(long sale,RefundInput input,CancellationToken ct)
    {
        if(input.Items is null||input.Items.Count is <1 or >100||input.Items.Any(x=>x.Quantity<=0)
            ||input.Items.Select(x=>x.SaleItemID).Distinct().Count()!=input.Items.Count
            ||string.IsNullOrWhiteSpace(input.Reason)||input.Reason.Length>500)return Bad("ระบุรายการ จำนวนคืน และเหตุผล");
        await using var db=await Open(ct);if(await Guard(db,"53009","REFUND",ct) is {} f)return f;
        var scope=await SchoolFoodAccess.ShopScope(db,Company,Actor,ct);
        return await Transact(db,input.RequestKey,"REFUND",new{sale,input},async(tx,op)=>{
            var headers=await FoodDb.Rows(db,tx,"SELECT * FROM dbo.TDSFSale WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND SaleID=@sale AND (@shop IS NULL OR ShopID=@shop)",ct,("@co",Company),("@sale",sale),("@shop",scope));
            if(headers.Count!=1)throw new FoodBusinessException("ไม่พบใบขายในร้านที่มีสิทธิ์");
            var header=headers[0];var lines=new List<(long Detail,long Item,int Qty,decimal Amount,decimal Commission)>();
            foreach(var item in input.Items.OrderBy(x=>x.SaleItemID))
            {
                var rows=await FoodDb.Rows(db,tx,"SELECT * FROM dbo.TDSFSaleItem WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND SaleID=@sale AND SaleItemID=@id",ct,("@co",Company),("@sale",sale),("@id",item.SaleItemID));
                if(rows.Count!=1)throw new FoodBusinessException("รายการคืนไม่อยู่ในใบขายนี้");
                var row=rows[0];var qty=row.Long("Quantity");var returned=row.Long("ReturnedQuantity");
                if(item.Quantity>qty-returned)throw new FoodBusinessException("จำนวนคืนเกินจำนวนคงเหลือในใบขาย");
                var amount=SchoolFoodRules.RefundCommission(row.Decimal("NetAmount"),qty,returned,item.Quantity);
                var cut=SchoolFoodRules.RefundCommission(row.Decimal("CommissionAmount"),qty,returned,item.Quantity);
                if(amount<=0)throw new FoodBusinessException("ยอดคืนหลังปัดเศษเป็นศูนย์ กรุณารวมจำนวนคืน");
                lines.Add((item.SaleItemID,row.Long("ItemID"),item.Quantity,amount,cut));
            }
            var total=lines.Sum(x=>x.Amount);var commission=lines.Sum(x=>x.Commission);
            var refund=await FoodDb.Id(db,tx,"INSERT dbo.TDSFRefund(CompanyID,SaleID,OperationID,Reason,Amount,CommissionAmount,CreatedBy) OUTPUT INSERTED.RefundID VALUES(@co,@sale,@op,@reason,@amount,@cut,@actor)",ct,("@co",Company),("@sale",sale),("@op",op),("@reason",input.Reason.Trim()),("@amount",total),("@cut",commission),("@actor",Actor));
            var balance=await FoodTransaction.Wallet(db,tx,Company,header.Long("StudentID"),op,Actor,total,"REFUND","SFR-"+refund,input.Reason,null,ct);
            foreach(var line in lines)
            {
                await FoodDb.Execute(db,tx,"INSERT dbo.TDSFRefundItem(CompanyID,RefundID,SaleItemID,Quantity,Amount,CommissionAmount) VALUES(@co,@refund,@detail,@qty,@amount,@cut); UPDATE dbo.TDSFSaleItem SET ReturnedQuantity=ReturnedQuantity+@qty WHERE CompanyID=@co AND SaleItemID=@detail",ct,("@co",Company),("@refund",refund),("@detail",line.Detail),("@qty",line.Qty),("@amount",line.Amount),("@cut",line.Commission));
                if(header.Bool("TrackStock"))await FoodTransaction.Stock(db,tx,Company,header.Long("WarehouseID"),line.Item,line.Qty,"REVERSAL",refund,line.Detail,Actor,ct);
            }
            await FoodDb.Execute(db,tx,"UPDATE dbo.TDSFSale SET RefundedAmount=RefundedAmount+@amount,RefundedCommission=RefundedCommission+@cut WHERE CompanyID=@co AND SaleID=@sale",ct,("@amount",total),("@cut",commission),("@co",Company),("@sale",sale));
            return new{id=refund,total,commission,balance};
        },ct);
    }
}

public sealed record SaleInput(Guid RequestKey,long ShopID,string IdentifierKind,string Identifier,List<SaleItemInput> Items);
public sealed record SaleItemInput(long ItemID,int Quantity,decimal DiscountAmount=0);
public sealed record RefundInput(Guid RequestKey,string Reason,List<RefundItemInput> Items);
public sealed record RefundItemInput(long SaleItemID,int Quantity);
internal sealed record SaleLine(long ItemID,string Name,string? Type,int Quantity,decimal Price,decimal Discount,decimal Net,decimal Rate,decimal Commission);
