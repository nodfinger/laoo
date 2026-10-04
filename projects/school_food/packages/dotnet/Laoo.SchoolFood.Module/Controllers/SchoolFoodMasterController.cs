using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;

namespace Laoo.SchoolFood.Controllers;

public sealed partial class SchoolFoodController
{
    [HttpGet("options/{menu}")]
    public async Task<IActionResult> Options(string menu,CancellationToken ct)
    {
        await using var db=await Open(ct);if(await Guard(db,menu,"VIEW",ct) is {} f)return f;
        var scope=await SchoolFoodAccess.ShopScope(db,Company,Actor,ct);
        var warehouses=scope.HasValue?[]:await FoodDb.Rows(db,null,"SELECT WarehouseID id,WarehouseCode code,WarehouseName name FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND IsActive=1 ORDER BY WarehouseCode",ct,("@co",Company));
        return Ok(new{warehouses,shopId=scope,schoolUser=!scope.HasValue});
    }

    [HttpGet("shops/{shop:long}/items")]
    public async Task<IActionResult> ShopItems(long shop,[FromQuery]int page=1,[FromQuery]int pageSize=20,[FromQuery]string? search=null,CancellationToken ct=default)
    {
        await using var db=await Open(ct);if(await Guard(db,"53003","VIEW",ct,shop) is {} f)return f;
        page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        const string from=" FROM dbo.TDIVItem I LEFT JOIN dbo.TDSFShopItem SI ON SI.CompanyID=I.CompanyID AND SI.ItemID=I.ItemID AND SI.ShopID=@shop WHERE I.CompanyID=@co AND I.IsActive=1 AND (@q IS NULL OR I.ItemName LIKE N'%'+@q+N'%' OR I.ItemCode LIKE N'%'+@q+N'%')";
        var rows=await FoodDb.Rows(db,null,"SELECT I.ItemID id,I.ItemCode code,I.ItemName name,COALESCE(SI.SalePrice,I.UnitPrice) price,COALESCE(SI.IsSellable,0) selected,I.StockTrackingCode tracking"+from+" ORDER BY I.ItemCode OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@co",Company),("@shop",shop),("@q",search),("@offset",(page-1)*pageSize),("@size",pageSize));
        var total=await FoodDb.Id(db,null,"SELECT COUNT(*)"+from,ct,("@co",Company),("@shop",shop),("@q",search));
        return Ok(new{rows,total,page,pageSize});
    }

    [HttpPut("shops/{shop:long}/items")]
    public async Task<IActionResult> ShopItems(long shop,ShopItemsInput input,CancellationToken ct)
    {
        if(input.Items is null||input.Items.Count is <1 or >100||input.Items.Select(i=>i.ItemID).Distinct().Count()!=input.Items.Count
            ||input.Items.Any(i=>i.Price<=0||i.Price!=SchoolFoodRules.Money(i.Price)))
            return Bad("รายการสินค้าต้องไม่ซ้ำ และราคามากกว่า 0 ทศนิยมไม่เกินสองตำแหน่ง");
        await using var db=await Open(ct);if(await Guard(db,"53003","EDIT",ct,shop) is {} f)return f;
        return await Transact(db,input.RequestKey,"SHOP_ITEMS",new{shop,input},async(tx,op)=>{
            var shops=await FoodDb.Rows(db,tx,"SELECT TrackStock FROM dbo.TDSFShop WHERE CompanyID=@co AND ShopID=@shop AND IsActive=1",ct,("@co",Company),("@shop",shop));
            if(shops.Count!=1)throw new FoodBusinessException("ไม่พบร้านค้าที่เปิดใช้งาน");
            foreach(var item in input.Items.OrderBy(i=>i.ItemID))
            {
                if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDIVItem WHERE CompanyID=@co AND ItemID=@item AND IsActive=1 AND (@track=0 OR StockTrackingCode=N'QUANTITY')",ct,("@co",Company),("@item",item.ItemID),("@track",shops[0].Bool("TrackStock")))!=1)
                    throw new FoodBusinessException("สินค้าต้องเป็นของโรงเรียนและรองรับการเก็บสต๊อกของร้าน");
                await FoodDb.Execute(db,tx,"MERGE dbo.TDSFShopItem WITH(HOLDLOCK) AS t USING(SELECT @co CompanyID,@shop ShopID,@item ItemID)s ON t.CompanyID=s.CompanyID AND t.ShopID=s.ShopID AND t.ItemID=s.ItemID WHEN MATCHED THEN UPDATE SET SalePrice=@price,IsSellable=@selected WHEN NOT MATCHED THEN INSERT(CompanyID,ShopID,ItemID,SalePrice,IsSellable) VALUES(@co,@shop,@item,@price,@selected);",ct,
                    ("@co",Company),("@shop",shop),("@item",item.ItemID),("@price",item.Price),("@selected",item.Selected));
            }
            return new{saved=input.Items.Count};
        },ct);
    }

    [HttpGet("shops/{shop:long}/commission")]
    public async Task<IActionResult> Commission(long shop,CancellationToken ct)
    {
        await using var db=await Open(ct);if(await Guard(db,"53004","VIEW",ct,shop) is {} f)return f;
        return Ok(await FoodDb.Rows(db,null,"SELECT R.RuleID id,R.ItemID,R.ItemTypeCode,R.Rate,I.ItemName FROM dbo.TDSFCommissionRule R LEFT JOIN dbo.TDIVItem I ON I.CompanyID=R.CompanyID AND I.ItemID=R.ItemID WHERE R.CompanyID=@co AND R.ShopID=@shop ORDER BY R.RuleID",ct,("@co",Company),("@shop",shop)));
    }

    [HttpPut("shops/{shop:long}/commission")]
    public async Task<IActionResult> Commission(long shop,CommissionInput input,CancellationToken ct)
    {
        if(input.Rate is <0 or >100||input.ItemID.HasValue==!string.IsNullOrWhiteSpace(input.ItemTypeCode)||input.ItemTypeCode?.Length>50)
            return Bad("เลือกระดับสินค้า หรือประเภทสินค้าอย่างใดอย่างหนึ่ง อัตรา 0–100; ล้างอัตราเพื่อใช้ค่าแม่");
        await using var db=await Open(ct);if(await Guard(db,"53004","EDIT",ct,shop,schoolOnly:true) is {} f)return f;
        return await Transact(db,input.RequestKey,"COMMISSION",new{shop,input},async(tx,op)=>{
            if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDSFShop WHERE CompanyID=@co AND ShopID=@shop",ct,("@co",Company),("@shop",shop))!=1)throw new FoodBusinessException("ไม่พบร้านค้า");
            if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDIVItem WHERE CompanyID=@co AND IsActive=1 AND ((@item IS NOT NULL AND ItemID=@item) OR (@item IS NULL AND ItemTypeCode=@type))",ct,("@co",Company),("@item",input.ItemID),("@type",input.ItemTypeCode))==0)throw new FoodBusinessException("ไม่พบสินค้าหรือประเภทสินค้าในโรงเรียน");
            await FoodDb.Execute(db,tx,"DELETE dbo.TDSFCommissionRule WHERE CompanyID=@co AND ShopID=@shop AND ((@item IS NOT NULL AND ItemID=@item) OR (@item IS NULL AND ItemTypeCode=@type)); IF @rate IS NOT NULL INSERT dbo.TDSFCommissionRule(CompanyID,ShopID,ItemID,ItemTypeCode,Rate) VALUES(@co,@shop,@item,@type,@rate)",ct,("@co",Company),("@shop",shop),("@item",input.ItemID),("@type",input.ItemTypeCode),("@rate",input.Rate));
            return new{saved=true};
        },ct);
    }

    [HttpGet("identifiers")]
    public async Task<IActionResult> Identifiers([FromQuery]int page=1,[FromQuery]int pageSize=10,CancellationToken ct=default)
    {
        await using var db=await Open(ct);if(await Guard(db,"53005","VIEW",ct,schoolOnly:true) is {} f)return f;
        page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        var rows=await FoodDb.Rows(db,null,"SELECT I.IdentifierID id,I.StudentID,S.StudentCode code,CONCAT(S.FirstName,N' ',S.LastName) name,I.Kind,I.DisplaySuffix,I.IsActive FROM dbo.TDSFStudentIdentifier I JOIN dbo.TDSCStudent S ON S.CompanyID=I.CompanyID AND S.StudentID=I.StudentID WHERE I.CompanyID=@co ORDER BY I.IdentifierID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@co",Company),("@offset",(page-1)*pageSize),("@size",pageSize));
        var total=await FoodDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDSFStudentIdentifier WHERE CompanyID=@co",ct,("@co",Company));
        return Ok(new{rows,total,page,pageSize});
    }

    [HttpPost("identifiers")]
    public async Task<IActionResult> Identifier(IdentifierInput input,CancellationToken ct)
    {
        if(input.Kind is not ("CARD" or "QR")||string.IsNullOrWhiteSpace(input.Value)||input.Value.Length>256)
            return Bad("ระบุรหัสบัตรหรือ QR ไม่เกิน 256 ตัวอักษร");
        await using var db=await Open(ct);if(await Guard(db,"53005","CREATE",ct,schoolOnly:true) is {} f)return f;
        return await Transact(db,input.RequestKey,"IDENTIFIER",input,async(tx,op)=>{
            if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDSCStudent WHERE CompanyID=@co AND StudentID=@student AND IsActive=1",ct,("@co",Company),("@student",input.StudentID))!=1)throw new FoodBusinessException("ไม่พบนักเรียนที่เปิดใช้งาน");
            var value=input.Value.Trim();var hash=SHA256.HashData(Encoding.UTF8.GetBytes(value));
            var id=await FoodDb.Id(db,tx,"INSERT dbo.TDSFStudentIdentifier(CompanyID,StudentID,Kind,IdentifierHash,DisplaySuffix,CreatedBy) OUTPUT INSERTED.IdentifierID VALUES(@co,@student,@kind,@hash,@suffix,@actor)",ct,
                ("@co",Company),("@student",input.StudentID),("@kind",input.Kind),("@hash",hash),("@suffix",value.Length>4?value[^4..]:value),("@actor",Actor));
            return new{id};
        },ct);
    }

    [HttpPut("identifiers/{id:long}/status")]
    public async Task<IActionResult> IdentifierStatus(long id,StatusInput input,CancellationToken ct)
    {
        await using var db=await Open(ct);if(await Guard(db,"53005","EDIT",ct,schoolOnly:true) is {} f)return f;
        return await Transact(db,input.RequestKey,"IDENTIFIER_STATUS",new{id,input},async(tx,op)=>{
            if(await FoodDb.Execute(db,tx,"UPDATE dbo.TDSFStudentIdentifier SET IsActive=@active WHERE CompanyID=@co AND IdentifierID=@id",ct,("@active",input.IsActive),("@co",Company),("@id",id))!=1)
                throw new FoodBusinessException("ไม่พบรายการบัตร");
            return new{saved=true};
        },ct);
    }

    [HttpGet("shops/{shop:long}/users")]
    public async Task<IActionResult> ShopUsers(long shop,[FromQuery]int page=1,[FromQuery]int pageSize=20,[FromQuery]string? search=null,CancellationToken ct=default)
    {
        await using var db=await Open(ct);if(await Guard(db,"53002","VIEW",ct,schoolOnly:true) is {} f)return f;
        if(await FoodDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDSFShop WHERE CompanyID=@co AND ShopID=@shop",ct,("@co",Company),("@shop",shop))!=1)
            return NotFound(new{message="ไม่พบร้านค้า",description="เลือกเฉพาะร้านของโรงเรียนนี้"});
        page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        const string source=" FROM dbo.TDADUser U LEFT JOIN dbo.TDSFShopUser SU ON SU.CompanyID=U.CompanyID AND SU.UserID=U.UserID WHERE U.CompanyID=@co AND U.IsActive=1 AND U.IsCompanyAdmin=0 AND (@q IS NULL OR U.Username LIKE N'%'+@q+N'%' OR U.DisplayName LIKE N'%'+@q+N'%')";
        var rows=await FoodDb.Rows(db,null,"SELECT U.UserID id,U.Username code,U.DisplayName name,SU.ShopID shopId,COALESCE(SU.IsActive,0) selected"+source+" ORDER BY U.Username OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,
            ("@co",Company),("@q",search),("@offset",(page-1)*pageSize),("@size",pageSize));
        var total=await FoodDb.Id(db,null,"SELECT COUNT(*)"+source,ct,("@co",Company),("@q",search));
        return Ok(new{rows,total,page,pageSize,shopId=shop});
    }

    [HttpPut("shops/{shop:long}/users/{user:long}")]
    public async Task<IActionResult> ShopUser(long shop,long user,StatusInput input,CancellationToken ct)
    {
        await using var db=await Open(ct);if(await Guard(db,"53002","EDIT",ct,schoolOnly:true) is {} f)return f;
        return await Transact(db,input.RequestKey,"SHOP_USER",new{shop,user,input},async(tx,op)=>{
            if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDADUser WHERE CompanyID=@co AND UserID=@user AND IsActive=1 AND IsCompanyAdmin=0",ct,("@co",Company),("@user",user))!=1
                ||await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDSFShop WHERE CompanyID=@co AND ShopID=@shop",ct,("@co",Company),("@shop",shop))!=1)
                throw new FoodBusinessException("เลือกร้านและผู้ใช้โรงเรียนที่ไม่ใช่ Company Admin");
            await FoodDb.Execute(db,tx,"MERGE dbo.TDSFShopUser WITH(HOLDLOCK) AS t USING(SELECT @co CompanyID,@user UserID)s ON t.CompanyID=s.CompanyID AND t.UserID=s.UserID WHEN MATCHED THEN UPDATE SET ShopID=@shop,IsActive=@active WHEN NOT MATCHED THEN INSERT(CompanyID,UserID,ShopID,IsActive) VALUES(@co,@user,@shop,@active);",ct,("@co",Company),("@user",user),("@shop",shop),("@active",input.IsActive));
            return new{saved=true};
        },ct);
    }
}

public sealed record ShopItemInput(long ItemID,decimal Price,bool Selected);
public sealed record ShopItemsInput(Guid RequestKey,List<ShopItemInput> Items);
public sealed record CommissionInput(Guid RequestKey,long? ItemID,string? ItemTypeCode,decimal? Rate);
public sealed record IdentifierInput(Guid RequestKey,long StudentID,string Kind,string Value);
public sealed record StatusInput(Guid RequestKey,bool IsActive);
