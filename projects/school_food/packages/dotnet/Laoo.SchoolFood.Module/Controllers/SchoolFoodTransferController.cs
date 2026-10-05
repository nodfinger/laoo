using Microsoft.AspNetCore.Mvc;

namespace Laoo.SchoolFood.Controllers;

public sealed partial class SchoolFoodController
{
    [HttpGet("transfers")]
    public async Task<IActionResult> Transfers([FromQuery]int page=1,[FromQuery]int pageSize=10,CancellationToken ct=default)
    {
        await using var db=await Open(ct);if(await Guard(db,"53006","VIEW",ct) is {} f)return f;
        var scope=await SchoolFoodAccess.ShopScope(db,Company,Actor,ct);page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        const string where=" FROM dbo.TDSFTransfer T JOIN dbo.TDSFShop S ON S.CompanyID=T.CompanyID AND S.ShopID=T.ShopID WHERE T.CompanyID=@co AND (@shop IS NULL OR T.ShopID=@shop)";
        var rows=await FoodDb.Rows(db,null,"SELECT T.TransferID id,T.ReferenceNo code,S.ShopName name,T.StatusCode status,T.CreatedAt date"+where+" ORDER BY T.TransferID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@co",Company),("@shop",scope),("@offset",(page-1)*pageSize),("@size",pageSize));
        var total=await FoodDb.Id(db,null,"SELECT COUNT(*)"+where,ct,("@co",Company),("@shop",scope));
        return Ok(new{rows,total,page,pageSize});
    }

    [HttpPost("transfers")]
    public async Task<IActionResult> Transfer(TransferInput input,CancellationToken ct)
    {
        if(input.Items is null||input.Items.Count is <1 or >100||input.Items.Any(i=>i.Quantity<=0||i.Quantity>1000000||decimal.Round(i.Quantity,4)!=i.Quantity)
            ||input.Items.Select(x=>x.ItemID).Distinct().Count()!=input.Items.Count||string.IsNullOrWhiteSpace(input.ReferenceNo)||input.ReferenceNo.Length>100)
            return Bad("ระบุเลขอ้างอิงและรายการโอนที่ไม่ซ้ำ จำนวนมากกว่า 0");
        await using var db=await Open(ct);if(await Guard(db,"53006","CREATE",ct,input.ShopID,schoolOnly:true) is {} f)return f;
        return await Transact(db,input.RequestKey,"TRANSFER_CREATE",input,async(tx,op)=>{
            var shops=await FoodDb.Rows(db,tx,"SELECT WarehouseID FROM dbo.TDSFShop WHERE CompanyID=@co AND ShopID=@shop AND TrackStock=1 AND IsActive=1",ct,("@co",Company),("@shop",input.ShopID));
            if(shops.Count!=1)throw new FoodBusinessException("เลือกร้านค้าที่เก็บสต๊อก");
            var target=shops[0].Long("WarehouseID");
            if(input.SourceWarehouseID==target||await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND WarehouseID=@wh AND IsActive=1",ct,("@co",Company),("@wh",input.SourceWarehouseID))!=1)
                throw new FoodBusinessException("เลือกคลังต้นทางภายในโรงเรียนที่ต่างจากคลังร้าน");
            var id=await FoodDb.Id(db,tx,"INSERT dbo.TDSFTransfer(CompanyID,ShopID,SourceWarehouseID,TargetWarehouseID,ReferenceNo,CreatedBy) OUTPUT INSERTED.TransferID VALUES(@co,@shop,@source,@target,@ref,@actor)",ct,
                ("@co",Company),("@shop",input.ShopID),("@source",input.SourceWarehouseID),("@target",target),("@ref",input.ReferenceNo.Trim()),("@actor",Actor));
            foreach(var item in input.Items.OrderBy(x=>x.ItemID))
            {
                if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDIVItem WHERE CompanyID=@co AND ItemID=@item AND IsActive=1 AND StockTrackingCode=N'QUANTITY'",ct,("@co",Company),("@item",item.ItemID))!=1)
                    throw new FoodBusinessException("สินค้าต้องอยู่ในโรงเรียนและเก็บสต๊อกแบบจำนวน");
                await FoodDb.Execute(db,tx,"INSERT dbo.TDSFTransferItem(CompanyID,TransferID,ItemID,Quantity) VALUES(@co,@id,@item,@qty)",ct,("@co",Company),("@id",id),("@item",item.ItemID),("@qty",item.Quantity));
            }
            return new{id,status="DRAFT"};
        },ct);
    }

    [HttpPost("transfers/{id:long}/{action}")]
    public async Task<IActionResult> TransferAction(long id,string action,OperationInput input,CancellationToken ct)
    {
        var permission=action switch{"send"=>"TRANSFER","receive"=>"RECEIVE",_=>null};
        if(permission is null)return NotFound();
        await using var db=await Open(ct);if(await Guard(db,"53006",permission,ct,schoolOnly:action=="send") is {} f)return f;
        var scope=await SchoolFoodAccess.ShopScope(db,Company,Actor,ct);
        return await Transact(db,input.RequestKey,"TRANSFER_"+permission,new{id,action},async(tx,op)=>{
            var rows=await FoodDb.Rows(db,tx,"SELECT * FROM dbo.TDSFTransfer WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND TransferID=@id AND (@shop IS NULL OR ShopID=@shop)",ct,("@co",Company),("@id",id),("@shop",scope));
            if(rows.Count!=1)throw new FoodBusinessException("ไม่พบใบโอนในร้านที่มีสิทธิ์");
            var row=rows[0];var status=Convert.ToString(row["StatusCode"]);
            if((action=="send"&&status!="DRAFT")||(action=="receive"&&status!="SENT"))
                throw new FoodBusinessException("สถานะใบโอนไม่อนุญาตให้ทำรายการนี้");
            if(action=="send")await FoodDb.Execute(db,tx,"UPDATE dbo.TDSFTransfer SET StatusCode=N'SENT',SentAt=SYSUTCDATETIME() WHERE CompanyID=@co AND TransferID=@id",ct,("@co",Company),("@id",id));
            else
            {
                var lines=await FoodDb.Rows(db,tx,"SELECT TransferItemID,ItemID,Quantity FROM dbo.TDSFTransferItem WHERE CompanyID=@co AND TransferID=@id ORDER BY ItemID",ct,("@co",Company),("@id",id));
                if(lines.Count==0)throw new FoodBusinessException("ใบโอนไม่มีรายการ");
                foreach(var line in lines)
                {
                    await FoodTransaction.Stock(db,tx,Company,row.Long("SourceWarehouseID"),line.Long("ItemID"),-line.Decimal("Quantity"),"TRANSFER_OUT",id,line.Long("TransferItemID"),Actor,ct);
                    await FoodTransaction.Stock(db,tx,Company,row.Long("TargetWarehouseID"),line.Long("ItemID"),line.Decimal("Quantity"),"TRANSFER_IN",id,line.Long("TransferItemID"),Actor,ct);
                }
                await FoodDb.Execute(db,tx,"UPDATE dbo.TDSFTransfer SET StatusCode=N'RECEIVED',ReceivedAt=SYSUTCDATETIME(),ReceivedBy=@actor WHERE CompanyID=@co AND TransferID=@id",ct,("@actor",Actor),("@co",Company),("@id",id));
            }
            return new{id,status=action=="send"?"SENT":"RECEIVED"};
        },ct);
    }
}

public sealed record TransferInput(Guid RequestKey,long ShopID,long SourceWarehouseID,string ReferenceNo,List<TransferItemInput> Items);
public sealed record TransferItemInput(long ItemID,decimal Quantity);
public sealed record OperationInput(Guid RequestKey);
