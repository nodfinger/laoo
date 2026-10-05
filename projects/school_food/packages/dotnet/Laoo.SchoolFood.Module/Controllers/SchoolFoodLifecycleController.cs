using Microsoft.AspNetCore.Mvc;

namespace Laoo.SchoolFood.Controllers;

public sealed partial class SchoolFoodController
{
    [HttpDelete("shops/{id:long}")]
    public async Task<IActionResult> DeleteShop(long id,[FromQuery]Guid requestKey,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"53002","DELETE",ct,schoolOnly:true) is {} f)return f;
        return await Transact(db,requestKey,"SHOP_DELETE",new{id},async(tx,op)=>{
            if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDSFShop WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND ShopID=@id",ct,("@co",Company),("@id",id))!=1)
                throw new FoodBusinessException("ไม่พบร้านค้าในโรงเรียนนี้");
            if(await FoodDb.Id(db,tx,"SELECT (SELECT COUNT(*) FROM dbo.TDSFSale WHERE CompanyID=@co AND ShopID=@id)+(SELECT COUNT(*) FROM dbo.TDSFTransfer WHERE CompanyID=@co AND ShopID=@id)+(SELECT COUNT(*) FROM dbo.TDSFShopUser WHERE CompanyID=@co AND ShopID=@id)+(SELECT COUNT(*) FROM dbo.TDSFDevice WHERE CompanyID=@co AND ShopID=@id)+(SELECT COUNT(*) FROM dbo.TDSFSettlement WHERE CompanyID=@co AND ShopID=@id)",ct,("@co",Company),("@id",id))>0)
                throw new FoodBusinessException("ร้านค้ามีประวัติหรือผู้ใช้งานผูกอยู่ ให้ปิดใช้งานแทนการลบ");
            await FoodDb.Execute(db,tx,"DELETE dbo.TDSFCommissionRule WHERE CompanyID=@co AND ShopID=@id; DELETE dbo.TDSFShopItem WHERE CompanyID=@co AND ShopID=@id; DELETE dbo.TDSFShop WHERE CompanyID=@co AND ShopID=@id",ct,("@co",Company),("@id",id));
            return new{deleted=true,id};
        },ct);
    }

    // Revoke rather than release a previously registered identifier to another student.
    [HttpDelete("identifiers/{id:long}")]
    public async Task<IActionResult> RevokeIdentifier(long id,[FromQuery]Guid requestKey,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"53005","DELETE",ct,schoolOnly:true) is {} f)return f;
        return await Transact(db,requestKey,"IDENTIFIER_REVOKE",new{id},async(tx,op)=>{
            if(await FoodDb.Execute(db,tx,"UPDATE dbo.TDSFStudentIdentifier SET IsActive=0 WHERE CompanyID=@co AND IdentifierID=@id",ct,("@co",Company),("@id",id))!=1)
                throw new FoodBusinessException("ไม่พบรหัสนักเรียนที่ต้องการระงับ");
            return new{id,revoked=true};
        },ct);
    }

    [HttpGet("transfers/{id:long}")]
    public async Task<IActionResult> TransferDetail(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"53006","VIEW",ct) is {} f)return f;
        var scope=await SchoolFoodAccess.ShopScope(db,Company,Actor,ct);
        var header=await FoodDb.Rows(db,null,"SELECT * FROM dbo.TDSFTransfer WHERE CompanyID=@co AND TransferID=@id AND (@shop IS NULL OR ShopID=@shop)",ct,("@co",Company),("@id",id),("@shop",scope));
        if(header.Count!=1)return NotFound(new{message="ไม่พบใบโอน",description="ตรวจสอบเลขที่หรือสิทธิ์ร้านค้า"});
        var items=await FoodDb.Rows(db,null,"SELECT T.ItemID,I.ItemCode code,I.ItemName name,T.Quantity FROM dbo.TDSFTransferItem T JOIN dbo.TDIVItem I ON I.CompanyID=T.CompanyID AND I.ItemID=T.ItemID WHERE T.CompanyID=@co AND T.TransferID=@id ORDER BY T.TransferItemID",ct,("@co",Company),("@id",id));
        return Ok(new{header=header[0],items});
    }

    [HttpPut("transfers/{id:long}")]
    public async Task<IActionResult> EditTransfer(long id,TransferInput input,CancellationToken ct)
    {
        if(input.Items is null||input.Items.Count is <1 or >100||input.Items.Any(i=>i.Quantity<=0||i.Quantity>1000000||decimal.Round(i.Quantity,4)!=i.Quantity)
            ||input.Items.Select(i=>i.ItemID).Distinct().Count()!=input.Items.Count||string.IsNullOrWhiteSpace(input.ReferenceNo)||input.ReferenceNo.Length>100)
            return Bad("ระบุเลขอ้างอิงและสินค้าที่ไม่ซ้ำ จำนวนมากกว่า 0 ทศนิยมไม่เกิน 4 ตำแหน่ง");
        await using var db=await Open(ct);
        if(await Guard(db,"53006","EDIT",ct,schoolOnly:true) is {} f)return f;
        return await Transact(db,input.RequestKey,"TRANSFER_EDIT",new{id,input},async(tx,op)=>{
            if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDSFTransfer WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND TransferID=@id AND StatusCode=N'DRAFT'",ct,("@co",Company),("@id",id))!=1)
                throw new FoodBusinessException("แก้ไขได้เฉพาะใบโอนร่าง");
            var target=await FoodDb.Id(db,tx,"SELECT COALESCE(MAX(WarehouseID),0) FROM dbo.TDSFShop WHERE CompanyID=@co AND ShopID=@shop AND IsActive=1 AND TrackStock=1",ct,("@co",Company),("@shop",input.ShopID));
            if(target==0||target==input.SourceWarehouseID||await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND WarehouseID=@wh AND IsActive=1",ct,("@co",Company),("@wh",input.SourceWarehouseID))!=1)
                throw new FoodBusinessException("เลือกคลังต้นทางและร้านเก็บสต๊อกในโรงเรียน โดยคลังต้องไม่ซ้ำกัน");
            await FoodDb.Execute(db,tx,"UPDATE dbo.TDSFTransfer SET ShopID=@shop,SourceWarehouseID=@source,TargetWarehouseID=@target,ReferenceNo=@ref WHERE CompanyID=@co AND TransferID=@id; DELETE dbo.TDSFTransferItem WHERE CompanyID=@co AND TransferID=@id",ct,("@shop",input.ShopID),("@source",input.SourceWarehouseID),("@target",target),("@ref",input.ReferenceNo.Trim()),("@co",Company),("@id",id));
            foreach(var item in input.Items.OrderBy(i=>i.ItemID))
            {
                if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDIVItem WHERE CompanyID=@co AND ItemID=@item AND IsActive=1 AND StockTrackingCode=N'QUANTITY'",ct,("@co",Company),("@item",item.ItemID))!=1)
                    throw new FoodBusinessException("สินค้าไม่พร้อมโอนหรือไม่อยู่ในโรงเรียน");
                await FoodDb.Execute(db,tx,"INSERT dbo.TDSFTransferItem(CompanyID,TransferID,ItemID,Quantity) VALUES(@co,@id,@item,@qty)",ct,("@co",Company),("@id",id),("@item",item.ItemID),("@qty",item.Quantity));
            }
            return new{id,saved=true};
        },ct);
    }

    [HttpDelete("transfers/{id:long}")]
    public async Task<IActionResult> CancelTransfer(long id,[FromQuery]Guid requestKey,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"53006","DELETE",ct,schoolOnly:true) is {} f)return f;
        return await Transact(db,requestKey,"TRANSFER_CANCEL",new{id},async(tx,op)=>{
            if(await FoodDb.Execute(db,tx,"UPDATE dbo.TDSFTransfer WITH(UPDLOCK,HOLDLOCK) SET StatusCode=N'CANCELLED' WHERE CompanyID=@co AND TransferID=@id AND StatusCode IN(N'DRAFT',N'SENT')",ct,("@co",Company),("@id",id))!=1)
                throw new FoodBusinessException("ไม่พบใบโอน หรือรับสินค้า/ยกเลิกไปแล้ว");
            return new{id,status="CANCELLED"};
        },ct);
    }
}
