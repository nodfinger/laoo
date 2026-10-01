using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooPosModule.Controllers;

[ApiController, Authorize, Route("api/company/pos")]
public sealed class PosController(IConfiguration config) : ControllerBase
{
    static readonly string[] Menus=["46001","46002","46003","46004","46005","46006","46007"];

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu,CancellationToken t)
    {
        if(!Menus.Contains(menu)||!Scope(out _,out _))return Forbid();
        await using var c=await Open(t);if(!await Can(c,menu,"VIEW",t))return Forbid();
        return Ok(new{create=await Can(c,menu,"CREATE",t),edit=await Can(c,menu,"EDIT",t),delete=await Can(c,menu,"DELETE",t),finalize=await Can(c,menu,"FINALIZE",t),cancel=await Can(c,menu,"CANCEL",t),discount=await Can(c,menu,"DISCOUNT",t),print=await Can(c,menu,"PRINT",t),download=await Can(c,menu,"DOWNLOAD",t)});
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken t)
    {
        if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46001","VIEW",t))return Forbid();await EnsureSettings(c,co,user,t);
        return Ok((await Rows(c,"SELECT IsEnabled,RequireOpenShift,AllowNegativeStock,TaxPercent,ReceiptPrefix,DefaultPaymentCode FROM dbo.TDSTCompanySetupSystemPOS WHERE CompanyID=@co",co,t)).First());
    }

    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(PosSettingsInput x,CancellationToken t)
    {
        if(x.TaxPercent is <0 or >100||string.IsNullOrWhiteSpace(x.ReceiptPrefix)||x.ReceiptPrefix.Length>10||!new[]{"CASH","CARD","TRANSFER"}.Contains(x.DefaultPaymentCode.ToUpperInvariant()))return Bad("ข้อมูลตั้งค่าไม่ถูกต้อง","ภาษีต้องอยู่ระหว่าง 0-100 และระบุ Prefix/วิธีชำระเงินที่รองรับ");
        if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46001","EDIT",t))return Forbid();await EnsureSettings(c,co,user,t);
        await using var q=new SqlCommand("UPDATE dbo.TDSTCompanySetupSystemPOS SET IsEnabled=@enabled,RequireOpenShift=@shift,AllowNegativeStock=@negative,TaxPercent=@tax,ReceiptPrefix=@prefix,DefaultPaymentCode=@payment,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co",c);
        P(q,"@enabled",SqlDbType.Bit,x.IsEnabled);P(q,"@shift",SqlDbType.Bit,x.RequireOpenShift);P(q,"@negative",SqlDbType.Bit,x.AllowNegativeStock);P(q,"@tax",SqlDbType.Decimal,x.TaxPercent);P(q,"@prefix",SqlDbType.NVarChar,x.ReceiptPrefix.Trim().ToUpperInvariant(),10);P(q,"@payment",SqlDbType.NVarChar,x.DefaultPaymentCode.Trim().ToUpperInvariant(),20);P(q,"@user",SqlDbType.BigInt,user);P(q,"@co",SqlDbType.BigInt,co);await q.ExecuteNonQueryAsync(t);return NoContent();
    }

    [HttpGet("options")]
    public async Task<IActionResult> Options(CancellationToken t)
    {
        if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await HasAnyView(c,t))return Forbid();
        const string sql=@"
SELECT BranchID id,BranchCode code,BranchNameTH name FROM dbo.TDADBranch WHERE CompanyID=@co AND IsActive=1 ORDER BY BranchCode;
SELECT WarehouseID id,WarehouseCode code,WarehouseName name,BranchID branchId FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND IsActive=1 ORDER BY WarehouseCode;
SELECT ItemID id,ItemCode code,ItemName name,UnitPrice price,StockBalance stock FROM dbo.TDIVItem WHERE CompanyID=@co AND IsActive=1 ORDER BY ItemCode;
SELECT DISTINCT PriceLevelCode code FROM dbo.TDIVItemPriceLevel WHERE CompanyID=@co ORDER BY PriceLevelCode;
";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);return Ok(await Multi(q,t,["branches","warehouses","items","priceLevels"]));
    }

    [HttpGet("outlets")]
    public async Task<IActionResult> Outlets(CancellationToken t)
    {
        if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,"46002","VIEW",t))return Forbid();
        const string sql=@"SELECT o.OutletID id,o.OutletCode code,o.OutletName name,o.BranchID,b.BranchNameTH branch,o.WarehouseID,w.WarehouseName warehouse,o.PriceLevelCode priceLevel,o.IsActive active,
(SELECT COUNT(*) FROM dbo.TDPOTerminal x WHERE x.CompanyID=o.CompanyID AND x.OutletID=o.OutletID) terminalCount
FROM dbo.TDPOOutlet o JOIN dbo.TDADBranch b ON b.CompanyID=o.CompanyID AND b.BranchID=o.BranchID JOIN dbo.TDIVWarehouse w ON w.CompanyID=o.CompanyID AND w.WarehouseID=o.WarehouseID WHERE o.CompanyID=@co ORDER BY o.OutletCode";
        return Ok(await Rows(c,sql,co,t));
    }

    [HttpPost("outlets")]
    public Task<IActionResult> CreateOutlet(OutletInput x,CancellationToken t)=>SaveOutlet(null,x,"CREATE",t);
    [HttpPut("outlets/{id:long}")]
    public Task<IActionResult> UpdateOutlet(long id,OutletInput x,CancellationToken t)=>SaveOutlet(id,x,"EDIT",t);
    async Task<IActionResult> SaveOutlet(long? id,OutletInput x,string action,CancellationToken t)
    {
        if(string.IsNullOrWhiteSpace(x.Code)||string.IsNullOrWhiteSpace(x.Name))return Bad("ข้อมูลจุดขายไม่ครบ","ระบุรหัสและชื่อจุดขาย");
        if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46002",action,t))return Forbid();
        await using var valid=new SqlCommand("SELECT COUNT(*) FROM dbo.TDIVWarehouse w JOIN dbo.TDADBranch b ON b.CompanyID=w.CompanyID AND b.BranchID=w.BranchID WHERE w.CompanyID=@co AND w.WarehouseID=@warehouse AND w.BranchID=@branch AND w.IsActive=1 AND b.IsActive=1",c);P(valid,"@co",SqlDbType.BigInt,co);P(valid,"@warehouse",SqlDbType.BigInt,x.WarehouseID);P(valid,"@branch",SqlDbType.BigInt,x.BranchID);if(Convert.ToInt32(await valid.ExecuteScalarAsync(t))!=1)return Bad("สาขาหรือคลังไม่ถูกต้อง","คลังต้องเปิดใช้งานและอยู่ในสาขาเดียวกัน");
        var sql=id is null?"INSERT dbo.TDPOOutlet(CompanyID,ProjectID,OutletCode,OutletName,BranchID,WarehouseID,PriceLevelCode,IsActive,CreateBy) OUTPUT INSERTED.OutletID SELECT @co,ProjectID,@code,@name,@branch,@warehouse,@price,@active,@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_POS'":"UPDATE dbo.TDPOOutlet SET OutletCode=@code,OutletName=@name,BranchID=@branch,WarehouseID=@warehouse,PriceLevelCode=@price,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND OutletID=@id;SELECT @id";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);P(q,"@code",SqlDbType.NVarChar,x.Code.Trim().ToUpperInvariant(),30);P(q,"@name",SqlDbType.NVarChar,x.Name.Trim(),150);P(q,"@branch",SqlDbType.BigInt,x.BranchID);P(q,"@warehouse",SqlDbType.BigInt,x.WarehouseID);P(q,"@price",SqlDbType.NVarChar,Clean(x.PriceLevelCode),30);P(q,"@active",SqlDbType.Bit,x.IsActive);P(q,"@user",SqlDbType.BigInt,user);
        try{return Ok(new{id=Convert.ToInt64(await q.ExecuteScalarAsync(t))});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสจุดขายซ้ำ",description="ใช้รหัสอื่นภายในบริษัท"});}
    }

    [HttpDelete("outlets/{id:long}")]
    public async Task<IActionResult> DeleteOutlet(long id,CancellationToken t)
    {
        if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,"46002","DELETE",t))return Forbid();await using var q=new SqlCommand("DELETE dbo.TDPOOutlet WHERE CompanyID=@co AND OutletID=@id",c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);try{return await q.ExecuteNonQueryAsync(t)==1?NoContent():NotFound();}catch(SqlException e)when(e.Number==547){return Conflict(new{message="ลบจุดขายไม่ได้",description="จุดขายมีเครื่องขาย สินค้า กะ หรือเอกสารขายอ้างอิงอยู่"});}
    }

    [HttpGet("terminals")]
    public async Task<IActionResult> Terminals(CancellationToken t)
    {
        if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,"46002","VIEW",t))return Forbid();
        return Ok(await Rows(c,"SELECT x.TerminalID id,x.TerminalCode code,x.TerminalName name,x.ActivationID activationId,x.OutletID,o.OutletName outlet,b.BranchNameTH branch,x.IsActive active,x.LastSeenAt FROM dbo.TDPOTerminal x JOIN dbo.TDPOOutlet o ON o.CompanyID=x.CompanyID AND o.OutletID=x.OutletID JOIN dbo.TDADBranch b ON b.CompanyID=o.CompanyID AND b.BranchID=o.BranchID WHERE x.CompanyID=@co ORDER BY x.TerminalCode",co,t));
    }
    [HttpPost("terminals")]
    public Task<IActionResult> CreateTerminal(TerminalInput x,CancellationToken t)=>SaveTerminal(null,x,"CREATE",t);
    [HttpPut("terminals/{id:long}")]
    public Task<IActionResult> UpdateTerminal(long id,TerminalInput x,CancellationToken t)=>SaveTerminal(id,x,"EDIT",t);
    async Task<IActionResult> SaveTerminal(long? id,TerminalInput x,string action,CancellationToken t)
    {
        if(string.IsNullOrWhiteSpace(x.Code)||string.IsNullOrWhiteSpace(x.Name))return Bad("ข้อมูลเครื่องขายไม่ครบ","ระบุรหัสและชื่อเครื่องขาย");
        if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46002",action,t))return Forbid();
        await using var v=new SqlCommand("SELECT COUNT(*) FROM dbo.TDPOOutlet WHERE CompanyID=@co AND OutletID=@outlet AND IsActive=1",c);P(v,"@co",SqlDbType.BigInt,co);P(v,"@outlet",SqlDbType.BigInt,x.OutletID);if(Convert.ToInt32(await v.ExecuteScalarAsync(t))!=1)return Bad("จุดขายไม่ถูกต้อง","เลือกจุดขายที่เปิดใช้งานในบริษัทเดียวกัน");
        var sql=id is null?"INSERT dbo.TDPOTerminal(CompanyID,OutletID,TerminalCode,TerminalName,IsActive,CreateBy) OUTPUT INSERTED.TerminalID VALUES(@co,@outlet,@code,@name,@active,@user)":"UPDATE dbo.TDPOTerminal SET OutletID=@outlet,TerminalCode=@code,TerminalName=@name,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND TerminalID=@id;SELECT @id";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);P(q,"@outlet",SqlDbType.BigInt,x.OutletID);P(q,"@code",SqlDbType.NVarChar,x.Code.Trim().ToUpperInvariant(),30);P(q,"@name",SqlDbType.NVarChar,x.Name.Trim(),150);P(q,"@active",SqlDbType.Bit,x.IsActive);P(q,"@user",SqlDbType.BigInt,user);
        try{var terminal=Convert.ToInt64(await q.ExecuteScalarAsync(t));await using var a=new SqlCommand("SELECT ActivationID FROM dbo.TDPOTerminal WHERE CompanyID=@co AND TerminalID=@id",c);P(a,"@co",SqlDbType.BigInt,co);P(a,"@id",SqlDbType.BigInt,terminal);return Ok(new{id=terminal,activationId=await a.ExecuteScalarAsync(t)});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสเครื่องขายซ้ำ",description="ใช้รหัสอื่นภายในบริษัท"});}
    }
    [HttpDelete("terminals/{id:long}")]
    public Task<IActionResult> DeleteTerminal(long id,CancellationToken t)=>Delete("46002","dbo.TDPOTerminal","TerminalID",id,"เครื่องขายมีกะหรือเอกสารขายอ้างอิงอยู่",t);

    [HttpGet("outlet-items")]
    public async Task<IActionResult> OutletItems(CancellationToken t)
    {
        if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,"46003","VIEW",t))return Forbid();
        const string sql="SELECT x.OutletItemID id,x.OutletID,o.OutletName outlet,x.ItemID,i.ItemCode code,i.ItemName name,x.Barcode,COALESCE(x.SalePriceOverride,p.SalePrice,i.UnitPrice) price,s.Quantity stock,x.IsSellable sellable,x.ShowStock showStock FROM dbo.TDPOOutletItem x JOIN dbo.TDPOOutlet o ON o.CompanyID=x.CompanyID AND o.OutletID=x.OutletID JOIN dbo.TDIVItem i ON i.CompanyID=x.CompanyID AND i.ItemID=x.ItemID LEFT JOIN dbo.TDIVItemPriceLevel p ON p.CompanyID=x.CompanyID AND p.ItemID=x.ItemID AND p.PriceLevelCode=o.PriceLevelCode LEFT JOIN dbo.TDIVStockBalance s ON s.CompanyID=x.CompanyID AND s.WarehouseID=o.WarehouseID AND s.ItemID=x.ItemID WHERE x.CompanyID=@co ORDER BY o.OutletCode,i.ItemCode";
        return Ok(await Rows(c,sql,co,t));
    }
    [HttpPost("outlet-items")]
    public Task<IActionResult> CreateOutletItem(OutletItemInput x,CancellationToken t)=>SaveOutletItem(null,x,"CREATE",t);
    [HttpPut("outlet-items/{id:long}")]
    public Task<IActionResult> UpdateOutletItem(long id,OutletItemInput x,CancellationToken t)=>SaveOutletItem(id,x,"EDIT",t);
    async Task<IActionResult> SaveOutletItem(long? id,OutletItemInput x,string action,CancellationToken t)
    {
        if(x.SalePriceOverride<0)return Bad("ราคาขายไม่ถูกต้อง","ราคาขายต้องไม่ติดลบ");if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46003",action,t))return Forbid();
        await using var v=new SqlCommand("SELECT (SELECT COUNT(*) FROM dbo.TDPOOutlet WHERE CompanyID=@co AND OutletID=@outlet AND IsActive=1)+(SELECT COUNT(*) FROM dbo.TDIVItem WHERE CompanyID=@co AND ItemID=@item AND IsActive=1)",c);P(v,"@co",SqlDbType.BigInt,co);P(v,"@outlet",SqlDbType.BigInt,x.OutletID);P(v,"@item",SqlDbType.BigInt,x.ItemID);if(Convert.ToInt32(await v.ExecuteScalarAsync(t))!=2)return Bad("ข้อมูลอ้างอิงไม่ถูกต้อง","เลือกจุดขายและสินค้าที่เปิดใช้งานในบริษัทเดียวกัน");
        var sql=id is null?"INSERT dbo.TDPOOutletItem(CompanyID,OutletID,ItemID,Barcode,SalePriceOverride,IsSellable,ShowStock,CreateBy) OUTPUT INSERTED.OutletItemID VALUES(@co,@outlet,@item,@barcode,@price,@sellable,@show,@user)":"UPDATE dbo.TDPOOutletItem SET OutletID=@outlet,ItemID=@item,Barcode=@barcode,SalePriceOverride=@price,IsSellable=@sellable,ShowStock=@show,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND OutletItemID=@id;SELECT @id";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);P(q,"@outlet",SqlDbType.BigInt,x.OutletID);P(q,"@item",SqlDbType.BigInt,x.ItemID);P(q,"@barcode",SqlDbType.NVarChar,Clean(x.Barcode),100);P(q,"@price",SqlDbType.Decimal,x.SalePriceOverride);P(q,"@sellable",SqlDbType.Bit,x.IsSellable);P(q,"@show",SqlDbType.Bit,x.ShowStock);P(q,"@user",SqlDbType.BigInt,user);try{return Ok(new{id=Convert.ToInt64(await q.ExecuteScalarAsync(t))});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="สินค้าซ้ำในจุดขาย",description="สินค้าหนึ่งรายการกำหนดได้ครั้งเดียวต่อจุดขาย"});}
    }
    [HttpDelete("outlet-items/{id:long}")]
    public Task<IActionResult> DeleteOutletItem(long id,CancellationToken t)=>Delete("46003","dbo.TDPOOutletItem","OutletItemID",id,"ไม่พบสินค้าตามจุดขาย",t);

    [HttpGet("bootstrap/{activationId:guid}")]
    public async Task<IActionResult> Bootstrap(Guid activationId,CancellationToken t)
    {
        if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46004","VIEW",t))return Forbid();await EnsureSettings(c,co,user,t);
        const string sql=@"SELECT TOP 1 x.TerminalID,x.TerminalCode,x.TerminalName,o.OutletID,o.OutletName,o.BranchID,b.BranchCode,b.BranchNameTH,o.WarehouseID,w.WarehouseCode,w.WarehouseName,s.RequireOpenShift,s.AllowNegativeStock,s.TaxPercent,s.DefaultPaymentCode,
(SELECT TOP 1 ShiftID FROM dbo.TDPOShift z WHERE z.CompanyID=x.CompanyID AND z.TerminalID=x.TerminalID AND z.StatusCode=N'OPEN') shiftId
FROM dbo.TDPOTerminal x JOIN dbo.TDPOOutlet o ON o.CompanyID=x.CompanyID AND o.OutletID=x.OutletID JOIN dbo.TDADBranch b ON b.CompanyID=o.CompanyID AND b.BranchID=o.BranchID JOIN dbo.TDIVWarehouse w ON w.CompanyID=o.CompanyID AND w.WarehouseID=o.WarehouseID JOIN dbo.TDSTCompanySetupSystemPOS s ON s.CompanyID=x.CompanyID
WHERE x.CompanyID=@co AND x.ActivationID=@activation AND x.IsActive=1 AND o.IsActive=1 AND EXISTS(SELECT 1 FROM dbo.TDADUserBranch ub WHERE ub.CompanyID=@co AND ub.UserID=@user AND ub.BranchID=o.BranchID AND ub.IsActive=1)";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@user",SqlDbType.BigInt,user);P(q,"@activation",SqlDbType.UniqueIdentifier,activationId);var rows=await ReadRows(q,t);if(rows.Count==0)return Forbid();await using var seen=new SqlCommand("UPDATE dbo.TDPOTerminal SET LastSeenAt=SYSUTCDATETIME() WHERE CompanyID=@co AND ActivationID=@activation",c);P(seen,"@co",SqlDbType.BigInt,co);P(seen,"@activation",SqlDbType.UniqueIdentifier,activationId);await seen.ExecuteNonQueryAsync(t);return Ok(rows[0]);
    }

    [HttpGet("products/{activationId:guid}")]
    public async Task<IActionResult> Products(Guid activationId,[FromQuery]string? search,CancellationToken t)
    {
        if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46004","VIEW",t))return Forbid();var terminal=await Terminal(c,co,user,activationId,t);if(terminal is null)return Forbid();
        const string sql=@"SELECT x.ItemID id,i.ItemCode code,i.ItemName name,x.Barcode,COALESCE(x.SalePriceOverride,p.SalePrice,i.UnitPrice) price,COALESCE(s.Quantity,0) stock,x.ShowStock showStock
FROM dbo.TDPOOutletItem x JOIN dbo.TDIVItem i ON i.CompanyID=x.CompanyID AND i.ItemID=x.ItemID JOIN dbo.TDPOOutlet o ON o.CompanyID=x.CompanyID AND o.OutletID=x.OutletID
LEFT JOIN dbo.TDIVItemPriceLevel p ON p.CompanyID=x.CompanyID AND p.ItemID=x.ItemID AND p.PriceLevelCode=o.PriceLevelCode LEFT JOIN dbo.TDIVStockBalance s ON s.CompanyID=x.CompanyID AND s.WarehouseID=o.WarehouseID AND s.ItemID=x.ItemID
WHERE x.CompanyID=@co AND x.OutletID=@outlet AND x.IsSellable=1 AND i.IsActive=1 AND (@search IS NULL OR i.ItemCode LIKE N'%'+@search+N'%' OR i.ItemName LIKE N'%'+@search+N'%' OR x.Barcode=@search) ORDER BY i.ItemCode";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@outlet",SqlDbType.BigInt,terminal.OutletID);P(q,"@search",SqlDbType.NVarChar,Clean(search),250);return Ok(await ReadRows(q,t));
    }

    [HttpGet("shifts")]
    public async Task<IActionResult> Shifts(CancellationToken t)
    {
        if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,"46005","VIEW",t))return Forbid();
        return Ok(await Rows(c,"SELECT s.ShiftID id,s.ShiftCode code,x.TerminalCode terminal,o.OutletName outlet,s.OpenedAt,s.OpeningCash,s.ClosedAt,s.ExpectedCash,s.CountedCash,s.VarianceAmount variance,s.StatusCode status FROM dbo.TDPOShift s JOIN dbo.TDPOTerminal x ON x.CompanyID=s.CompanyID AND x.TerminalID=s.TerminalID JOIN dbo.TDPOOutlet o ON o.CompanyID=s.CompanyID AND o.OutletID=x.OutletID WHERE s.CompanyID=@co ORDER BY s.OpenedAt DESC",co,t));
    }
    [HttpPost("shifts/open")]
    public async Task<IActionResult> OpenShift(OpenShiftInput x,CancellationToken t)
    {
        if(x.OpeningCash<0)return Bad("เงินเปิดกะไม่ถูกต้อง","จำนวนเงินต้องไม่ติดลบ");if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46005","CREATE",t))return Forbid();var terminal=await Terminal(c,co,user,x.ActivationID,t);if(terminal is null)return Forbid();
        var code=$"SHIFT-{DateTime.UtcNow:yyyyMMddHHmmss}-{terminal.TerminalID}";await using var q=new SqlCommand("INSERT dbo.TDPOShift(CompanyID,TerminalID,ShiftCode,OpenedBy,OpeningCash) OUTPUT INSERTED.ShiftID VALUES(@co,@terminal,@code,@user,@cash)",c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@terminal",SqlDbType.BigInt,terminal.TerminalID);P(q,"@code",SqlDbType.NVarChar,code,40);P(q,"@user",SqlDbType.BigInt,user);P(q,"@cash",SqlDbType.Decimal,x.OpeningCash);try{return Ok(new{id=Convert.ToInt64(await q.ExecuteScalarAsync(t)),code});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="เครื่องนี้มีกะเปิดอยู่",description="ปิดกะเดิมก่อนเปิดกะใหม่"});}
    }
    [HttpPost("shifts/{id:long}/close")]
    public async Task<IActionResult> CloseShift(long id,CloseShiftInput x,CancellationToken t)
    {
        if(x.CountedCash<0)return Bad("ยอดนับเงินจริงไม่ถูกต้อง","จำนวนเงินต้องไม่ติดลบ");if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46005","FINALIZE",t))return Forbid();
        const string sql=@"DECLARE @expected decimal(18,4)=(SELECT s.OpeningCash+COALESCE(SUM(CASE WHEN p.PaymentCode=N'CASH' AND h.StatusCode<>N'CANCELLED' THEN p.Amount-p.ChangeAmount ELSE 0 END),0) FROM dbo.TDPOShift s LEFT JOIN dbo.TDPOSale h ON h.CompanyID=s.CompanyID AND h.ShiftID=s.ShiftID LEFT JOIN dbo.TDPOSalePayment p ON p.CompanyID=h.CompanyID AND p.SaleID=h.SaleID WHERE s.CompanyID=@co AND s.ShiftID=@id AND s.StatusCode=N'OPEN' GROUP BY s.OpeningCash);
UPDATE dbo.TDPOShift SET ClosedBy=@user,ClosedAt=SYSUTCDATETIME(),ExpectedCash=@expected,CountedCash=@counted,VarianceAmount=@counted-@expected,StatusCode=N'CLOSED',Remark=@remark WHERE CompanyID=@co AND ShiftID=@id AND StatusCode=N'OPEN';SELECT @@ROWCOUNT";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);P(q,"@user",SqlDbType.BigInt,user);P(q,"@counted",SqlDbType.Decimal,x.CountedCash);P(q,"@remark",SqlDbType.NVarChar,Clean(x.Remark),1000);return Convert.ToInt32(await q.ExecuteScalarAsync(t))==1?NoContent():Conflict(new{message="ปิดกะไม่ได้",description="ไม่พบกะที่เปิดอยู่หรือกะถูกปิดแล้ว"});
    }

    [HttpGet("sales")]
    public async Task<IActionResult> Sales([FromQuery]string? search,CancellationToken t)
    {
        if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,"46006","VIEW",t)&&!await Can(c,"46004","VIEW",t))return Forbid();
        const string sql="SELECT TOP(100) h.SaleID id,h.ReceiptNo receipt,h.SaleDate,h.NetAmount net,h.StatusCode status,b.BranchNameTH branch,o.OutletName outlet,x.TerminalCode terminal FROM dbo.TDPOSale h JOIN dbo.TDADBranch b ON b.CompanyID=h.CompanyID AND b.BranchID=h.BranchID JOIN dbo.TDPOOutlet o ON o.CompanyID=h.CompanyID AND o.OutletID=h.OutletID JOIN dbo.TDPOTerminal x ON x.CompanyID=h.CompanyID AND x.TerminalID=h.TerminalID WHERE h.CompanyID=@co AND (@search IS NULL OR h.ReceiptNo LIKE N'%'+@search+N'%') ORDER BY h.SaleDate DESC";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@search",SqlDbType.NVarChar,Clean(search),100);return Ok(await ReadRows(q,t));
    }

    [HttpPost("sales/finalize")]
    public async Task<IActionResult> FinalizeSale(SaleInput x,CancellationToken t)
    {
        if(x.Items.Count==0||x.Items.Any(i=>i.Quantity<=0)||x.DiscountAmount<0||x.ReceivedAmount<0)return Bad("ข้อมูลขายไม่ครบ","ต้องมีสินค้า จำนวนมากกว่า 0 และยอดเงินไม่ติดลบ");
        if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46004","CREATE",t)||!await Can(c,"46004","FINALIZE",t))return Forbid();var terminal=await Terminal(c,co,user,x.ActivationID,t);if(terminal is null)return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,t);
        try{
            await using var setting=new SqlCommand("SELECT IsEnabled,RequireOpenShift,AllowNegativeStock,TaxPercent,ReceiptPrefix,DefaultPaymentCode FROM dbo.TDSTCompanySetupSystemPOS WHERE CompanyID=@co",c,tx);P(setting,"@co",SqlDbType.BigInt,co);await using var sr=await setting.ExecuteReaderAsync(t);if(!await sr.ReadAsync(t)){await sr.CloseAsync();await tx.RollbackAsync(t);return Bad("ยังไม่ได้ตั้งค่าระบบ","บันทึกหน้าตั้งค่า POS ก่อนขาย");}var enabled=sr.GetBoolean(0);var requireShift=sr.GetBoolean(1);var allowNegative=sr.GetBoolean(2);var taxRate=sr.GetDecimal(3);var prefix=sr.GetString(4);var payment=string.IsNullOrWhiteSpace(x.PaymentCode)?sr.GetString(5):x.PaymentCode.Trim().ToUpperInvariant();await sr.CloseAsync();if(!enabled){await tx.RollbackAsync(t);return Conflict(new{message="ระบบ POS ปิดใช้งาน",description="เปิดใช้งานจากหน้าตั้งค่าระบบ POS"});}
            long? shift=null;await using(var sq=new SqlCommand("SELECT TOP 1 ShiftID FROM dbo.TDPOShift WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND TerminalID=@terminal AND StatusCode=N'OPEN'",c,tx)){P(sq,"@co",SqlDbType.BigInt,co);P(sq,"@terminal",SqlDbType.BigInt,terminal.TerminalID);var value=await sq.ExecuteScalarAsync(t);if(value is not null)shift=Convert.ToInt64(value);}if(requireShift&&shift is null){await tx.RollbackAsync(t);return Conflict(new{message="ยังไม่ได้เปิดกะ",description="เปิดกะเงินสดของเครื่องนี้ก่อนเริ่มขาย"});}
            var lines=new List<SaleLine>();decimal subtotal=0;foreach(var input in x.Items.GroupBy(i=>i.ItemID).Select(g=>new SaleItemInput(g.Key,g.Sum(v=>v.Quantity)))){
                await using var iq=new SqlCommand("SELECT i.ItemCode,i.ItemName,COALESCE(oi.SalePriceOverride,p.SalePrice,i.UnitPrice),COALESCE(s.Quantity,0) FROM dbo.TDPOOutletItem oi JOIN dbo.TDIVItem i ON i.CompanyID=oi.CompanyID AND i.ItemID=oi.ItemID JOIN dbo.TDPOOutlet o ON o.CompanyID=oi.CompanyID AND o.OutletID=oi.OutletID LEFT JOIN dbo.TDIVItemPriceLevel p ON p.CompanyID=oi.CompanyID AND p.ItemID=oi.ItemID AND p.PriceLevelCode=o.PriceLevelCode LEFT JOIN dbo.TDIVStockBalance s WITH(UPDLOCK,HOLDLOCK) ON s.CompanyID=oi.CompanyID AND s.WarehouseID=o.WarehouseID AND s.ItemID=oi.ItemID WHERE oi.CompanyID=@co AND oi.OutletID=@outlet AND oi.ItemID=@item AND oi.IsSellable=1 AND i.IsActive=1",c,tx);P(iq,"@co",SqlDbType.BigInt,co);P(iq,"@outlet",SqlDbType.BigInt,terminal.OutletID);P(iq,"@item",SqlDbType.BigInt,input.ItemID);await using var ir=await iq.ExecuteReaderAsync(t);if(!await ir.ReadAsync(t)){await ir.CloseAsync();await tx.RollbackAsync(t);return Bad("สินค้าไม่พร้อมขาย",$"สินค้า {input.ItemID} ไม่อยู่ในจุดขายหรือปิดใช้งาน");}var code=ir.GetString(0);var name=ir.GetString(1);var price=ir.GetDecimal(2);var stock=ir.GetDecimal(3);await ir.CloseAsync();if(price<=0){await tx.RollbackAsync(t);return Bad("สินค้ายังไม่มีราคา",$"{code} - {name} ต้องกำหนดราคาก่อนขาย");}if(!allowNegative&&stock<input.Quantity){await tx.RollbackAsync(t);return Conflict(new{message="สต็อกไม่พอ",description=$"{code} - {name} คงเหลือ {stock:N2}"});}var amount=price*input.Quantity;subtotal+=amount;lines.Add(new(input.ItemID,code,name,input.Quantity,price,amount));}
            if(x.DiscountAmount>subtotal){await tx.RollbackAsync(t);return Bad("ส่วนลดไม่ถูกต้อง","ส่วนลดต้องไม่เกินยอดสินค้า");}var taxable=subtotal-x.DiscountAmount;var tax=Math.Round(taxable*taxRate/100,2,MidpointRounding.AwayFromZero);var net=taxable+tax;if(x.ReceivedAmount<net){await tx.RollbackAsync(t);return Bad("ยอดรับชำระไม่ครบ",$"ต้องรับชำระอย่างน้อย {net:N2}");}var change=x.ReceivedAmount-net;
            var receipt=$"{prefix}-{DateTime.UtcNow:yyyyMMdd}-{DateTime.UtcNow:HHmmssfff}";await using var h=new SqlCommand("INSERT dbo.TDPOSale(CompanyID,ProjectID,BranchID,OutletID,TerminalID,ShiftID,ReceiptNo,CustomerID,CashierUserID,Subtotal,DiscountAmount,TaxAmount,NetAmount,IdempotencyKey) OUTPUT INSERTED.SaleID SELECT @co,ProjectID,@branch,@outlet,@terminal,@shift,@receipt,@customer,@user,@subtotal,@discount,@tax,@net,@key FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_POS'",c,tx);P(h,"@co",SqlDbType.BigInt,co);P(h,"@branch",SqlDbType.BigInt,terminal.BranchID);P(h,"@outlet",SqlDbType.BigInt,terminal.OutletID);P(h,"@terminal",SqlDbType.BigInt,terminal.TerminalID);P(h,"@shift",SqlDbType.BigInt,shift);P(h,"@receipt",SqlDbType.NVarChar,receipt,50);P(h,"@customer",SqlDbType.BigInt,x.CustomerID);P(h,"@user",SqlDbType.BigInt,user);P(h,"@subtotal",SqlDbType.Decimal,subtotal);P(h,"@discount",SqlDbType.Decimal,x.DiscountAmount);P(h,"@tax",SqlDbType.Decimal,tax);P(h,"@net",SqlDbType.Decimal,net);P(h,"@key",SqlDbType.UniqueIdentifier,x.IdempotencyKey);var sale=Convert.ToInt64(await h.ExecuteScalarAsync(t));
            foreach(var line in lines){var lineDiscount=subtotal==0?0:Math.Round(x.DiscountAmount*line.Amount/subtotal,2);var lineTax=Math.Round((line.Amount-lineDiscount)*taxRate/100,2);await using var d=new SqlCommand("INSERT dbo.TDPOSaleItem(CompanyID,SaleID,ItemID,ItemCodeSnapshot,ItemNameSnapshot,Quantity,UnitPrice,DiscountAmount,TaxAmount,LineNetAmount) OUTPUT INSERTED.SaleItemID VALUES(@co,@sale,@item,@code,@name,@qty,@price,@discount,@tax,@net)",c,tx);P(d,"@co",SqlDbType.BigInt,co);P(d,"@sale",SqlDbType.BigInt,sale);P(d,"@item",SqlDbType.BigInt,line.ItemID);P(d,"@code",SqlDbType.NVarChar,line.Code,50);P(d,"@name",SqlDbType.NVarChar,line.Name,250);P(d,"@qty",SqlDbType.Decimal,line.Quantity);P(d,"@price",SqlDbType.Decimal,line.Price);P(d,"@discount",SqlDbType.Decimal,lineDiscount);P(d,"@tax",SqlDbType.Decimal,lineTax);P(d,"@net",SqlDbType.Decimal,line.Amount-lineDiscount+lineTax);var detail=Convert.ToInt64(await d.ExecuteScalarAsync(t));await Stock(c,tx,co,terminal.WarehouseID,line.ItemID,-line.Quantity,"POS_SALE",sale,detail,user,null,t);}
            await using var pay=new SqlCommand("INSERT dbo.TDPOSalePayment(CompanyID,SaleID,PaymentCode,Amount,ReceivedAmount,ChangeAmount,ReferenceNo) VALUES(@co,@sale,@payment,@net,@received,@change,@reference)",c,tx);P(pay,"@co",SqlDbType.BigInt,co);P(pay,"@sale",SqlDbType.BigInt,sale);P(pay,"@payment",SqlDbType.NVarChar,payment,20);P(pay,"@net",SqlDbType.Decimal,net);P(pay,"@received",SqlDbType.Decimal,x.ReceivedAmount);P(pay,"@change",SqlDbType.Decimal,change);P(pay,"@reference",SqlDbType.NVarChar,Clean(x.PaymentReference),100);await pay.ExecuteNonQueryAsync(t);await tx.CommitAsync(t);return Ok(new{id=sale,receipt,subtotal,discount=x.DiscountAmount,tax,net,received=x.ReceivedAmount,change});
        }catch(SqlException e)when(e.Number is 2601 or 2627){await tx.RollbackAsync(t);return Conflict(new{message="รายการขายถูกส่งซ้ำ",description="ระบบไม่สร้างใบขายหรือสต็อกซ้ำจากคำขอเดิม"});}catch{await tx.RollbackAsync(t);throw;}
    }

    [HttpGet("sales/{id:long}")]
    public async Task<IActionResult> Sale(long id,CancellationToken t)
    {
        if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,"46006","VIEW",t))return Forbid();
        await using var q=new SqlCommand("SELECT SaleID id,ReceiptNo receipt,SaleDate,NetAmount net,StatusCode status FROM dbo.TDPOSale WHERE CompanyID=@co AND SaleID=@id;SELECT SaleItemID id,ItemID,ItemCodeSnapshot code,ItemNameSnapshot name,Quantity,ReturnedQuantity,UnitPrice,LineNetAmount net FROM dbo.TDPOSaleItem WHERE CompanyID=@co AND SaleID=@id ORDER BY SaleItemID",c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);var data=await Multi(q,t,["header","items"]);if(!data.TryGetValue("header",out var value)||value is not List<Dictionary<string,object?>> header||header.Count==0)return NotFound();return Ok(data);
    }

    [HttpPost("returns")]
    public async Task<IActionResult> CreateReturn(ReturnInput x,CancellationToken t)
    {
        if(x.Items.Count==0||x.Items.Any(i=>i.Quantity<=0)||string.IsNullOrWhiteSpace(x.Reason))return Bad("ข้อมูลคืนสินค้าไม่ครบ","ระบุรายการ จำนวน และเหตุผลคืนสินค้า");
        if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46006","CREATE",t)||!await Can(c,"46006","FINALIZE",t))return Forbid();await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,t);
        try{
            await using var h=new SqlCommand("SELECT BranchID,OutletID,TerminalID,ShiftID,StatusCode FROM dbo.TDPOSale WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND SaleID=@sale",c,tx);P(h,"@co",SqlDbType.BigInt,co);P(h,"@sale",SqlDbType.BigInt,x.SaleID);await using var hr=await h.ExecuteReaderAsync(t);if(!await hr.ReadAsync(t)){await hr.CloseAsync();await tx.RollbackAsync(t);return NotFound();}var branch=hr.GetInt64(0);var outlet=hr.GetInt64(1);var terminal=hr.GetInt64(2);var shift=hr.IsDBNull(3)?(long?)null:hr.GetInt64(3);var status=hr.GetString(4);await hr.CloseAsync();if(status is "CANCELLED" or "RETURNED"){await tx.RollbackAsync(t);return Conflict(new{message="คืนสินค้าไม่ได้",description="ใบขายถูกยกเลิกหรือคืนครบแล้ว"});}
            await using var warehouseQ=new SqlCommand("SELECT WarehouseID FROM dbo.TDPOOutlet WHERE CompanyID=@co AND OutletID=@outlet",c,tx);P(warehouseQ,"@co",SqlDbType.BigInt,co);P(warehouseQ,"@outlet",SqlDbType.BigInt,outlet);var warehouse=Convert.ToInt64(await warehouseQ.ExecuteScalarAsync(t));var lines=new List<ReturnLine>();decimal refund=0;
            foreach(var input in x.Items){await using var iq=new SqlCommand("SELECT ItemID,Quantity,ReturnedQuantity,LineNetAmount FROM dbo.TDPOSaleItem WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND SaleID=@sale AND SaleItemID=@line",c,tx);P(iq,"@co",SqlDbType.BigInt,co);P(iq,"@sale",SqlDbType.BigInt,x.SaleID);P(iq,"@line",SqlDbType.BigInt,input.SaleItemID);await using var ir=await iq.ExecuteReaderAsync(t);if(!await ir.ReadAsync(t)){await ir.CloseAsync();await tx.RollbackAsync(t);return Bad("รายการคืนไม่ถูกต้อง","รายการสินค้าไม่ได้อยู่ในใบขายนี้");}var item=ir.GetInt64(0);var sold=ir.GetDecimal(1);var returned=ir.GetDecimal(2);var lineNet=ir.GetDecimal(3);await ir.CloseAsync();if(input.Quantity>sold-returned){await tx.RollbackAsync(t);return Bad("จำนวนคืนเกินรายการขาย","จำนวนคืนรวมต้องไม่เกินจำนวนที่ซื้อ");}var amount=Math.Round(lineNet*input.Quantity/sold,2);refund+=amount;lines.Add(new(input.SaleItemID,item,input.Quantity,amount));}
            var number=$"RT-{DateTime.UtcNow:yyyyMMddHHmmssfff}";await using var rh=new SqlCommand("INSERT dbo.TDPOReturn(CompanyID,ProjectID,BranchID,OutletID,TerminalID,ShiftID,SaleID,ReturnNo,RefundAmount,RefundPaymentCode,ReasonText,CreateBy) OUTPUT INSERTED.ReturnID SELECT @co,ProjectID,@branch,@outlet,@terminal,@shift,@sale,@number,@refund,@payment,@reason,@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_POS'",c,tx);P(rh,"@co",SqlDbType.BigInt,co);P(rh,"@branch",SqlDbType.BigInt,branch);P(rh,"@outlet",SqlDbType.BigInt,outlet);P(rh,"@terminal",SqlDbType.BigInt,terminal);P(rh,"@shift",SqlDbType.BigInt,shift);P(rh,"@sale",SqlDbType.BigInt,x.SaleID);P(rh,"@number",SqlDbType.NVarChar,number,50);P(rh,"@refund",SqlDbType.Decimal,refund);P(rh,"@payment",SqlDbType.NVarChar,x.PaymentCode.Trim().ToUpperInvariant(),20);P(rh,"@reason",SqlDbType.NVarChar,x.Reason.Trim(),1000);P(rh,"@user",SqlDbType.BigInt,user);var returnId=Convert.ToInt64(await rh.ExecuteScalarAsync(t));
            foreach(var line in lines){await using var d=new SqlCommand("INSERT dbo.TDPOReturnItem(CompanyID,ReturnID,SaleItemID,ItemID,Quantity,RefundAmount) OUTPUT INSERTED.ReturnItemID VALUES(@co,@return,@saleItem,@item,@qty,@amount);UPDATE dbo.TDPOSaleItem SET ReturnedQuantity=ReturnedQuantity+@qty WHERE CompanyID=@co AND SaleItemID=@saleItem",c,tx);P(d,"@co",SqlDbType.BigInt,co);P(d,"@return",SqlDbType.BigInt,returnId);P(d,"@saleItem",SqlDbType.BigInt,line.SaleItemID);P(d,"@item",SqlDbType.BigInt,line.ItemID);P(d,"@qty",SqlDbType.Decimal,line.Quantity);P(d,"@amount",SqlDbType.Decimal,line.Amount);var detail=Convert.ToInt64(await d.ExecuteScalarAsync(t));await Stock(c,tx,co,warehouse,line.ItemID,line.Quantity,"POS_RETURN",returnId,detail,user,null,t);}
            await using var state=new SqlCommand("UPDATE dbo.TDPOSale SET StatusCode=CASE WHEN NOT EXISTS(SELECT 1 FROM dbo.TDPOSaleItem WHERE CompanyID=@co AND SaleID=@sale AND ReturnedQuantity<Quantity) THEN N'RETURNED' ELSE N'PARTIAL_RETURN' END WHERE CompanyID=@co AND SaleID=@sale",c,tx);P(state,"@co",SqlDbType.BigInt,co);P(state,"@sale",SqlDbType.BigInt,x.SaleID);await state.ExecuteNonQueryAsync(t);await tx.CommitAsync(t);return Ok(new{id=returnId,number,refund});
        }catch{await tx.RollbackAsync(t);throw;}
    }

    [HttpPost("sales/{id:long}/cancel")]
    public async Task<IActionResult> CancelSale(long id,CancelInput x,CancellationToken t)
    {
        if(string.IsNullOrWhiteSpace(x.Reason))return Bad("กรุณาระบุเหตุผล","เหตุผลยกเลิกเป็นข้อมูลบังคับ");if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"46004","CANCEL",t))return Forbid();await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,t);
        try{await using var h=new SqlCommand("SELECT o.WarehouseID FROM dbo.TDPOSale s JOIN dbo.TDPOOutlet o ON o.CompanyID=s.CompanyID AND o.OutletID=s.OutletID WHERE s.CompanyID=@co AND s.SaleID=@id AND s.StatusCode=N'COMPLETED'",c,tx);P(h,"@co",SqlDbType.BigInt,co);P(h,"@id",SqlDbType.BigInt,id);var value=await h.ExecuteScalarAsync(t);if(value is null){await tx.RollbackAsync(t);return Conflict(new{message="ยกเลิกใบขายไม่ได้",description="ยกเลิกได้เฉพาะใบขายที่เสร็จสมบูรณ์และยังไม่คืนสินค้า"});}var warehouse=Convert.ToInt64(value);await using var q=new SqlCommand("SELECT SaleItemID,ItemID,Quantity FROM dbo.TDPOSaleItem WHERE CompanyID=@co AND SaleID=@id",c,tx);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);await using var r=await q.ExecuteReaderAsync(t);var lines=new List<(long Detail,long Item,decimal Qty)>();while(await r.ReadAsync(t))lines.Add((r.GetInt64(0),r.GetInt64(1),r.GetDecimal(2)));await r.CloseAsync();foreach(var line in lines)await Stock(c,tx,co,warehouse,line.Item,line.Qty,"POS_CANCEL",id,line.Detail,user,null,t);await using var u=new SqlCommand("UPDATE dbo.TDPOSale SET StatusCode=N'CANCELLED',CancelReason=@reason,CancelledAt=SYSUTCDATETIME(),CancelledBy=@user WHERE CompanyID=@co AND SaleID=@id",c,tx);P(u,"@reason",SqlDbType.NVarChar,x.Reason.Trim(),1000);P(u,"@user",SqlDbType.BigInt,user);P(u,"@co",SqlDbType.BigInt,co);P(u,"@id",SqlDbType.BigInt,id);await u.ExecuteNonQueryAsync(t);await tx.CommitAsync(t);return NoContent();}catch{await tx.RollbackAsync(t);throw;}
    }

    [HttpGet("reports")]
    public async Task<IActionResult> Reports([FromQuery]DateTime? from,[FromQuery]DateTime? to,CancellationToken t)
    {
        if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,"46007","VIEW",t))return Forbid();var start=(from??DateTime.UtcNow.Date.AddDays(-30)).Date;var end=(to??DateTime.UtcNow.Date).Date.AddDays(1);
        const string sql=@"SELECT COUNT(*) receiptCount,COALESCE(SUM(CASE WHEN StatusCode<>N'CANCELLED' THEN NetAmount ELSE 0 END),0) netSales,COALESCE(SUM(CASE WHEN StatusCode=N'CANCELLED' THEN 1 ELSE 0 END),0) cancelledCount,(SELECT COALESCE(SUM(RefundAmount),0) FROM dbo.TDPOReturn WHERE CompanyID=@co AND ReturnDate>=@from AND ReturnDate<@to) refundAmount FROM dbo.TDPOSale WHERE CompanyID=@co AND SaleDate>=@from AND SaleDate<@to;
SELECT b.BranchNameTH branch,COUNT(*) receiptCount,SUM(CASE WHEN s.StatusCode<>N'CANCELLED' THEN s.NetAmount ELSE 0 END) amount FROM dbo.TDPOSale s JOIN dbo.TDADBranch b ON b.CompanyID=s.CompanyID AND b.BranchID=s.BranchID WHERE s.CompanyID=@co AND s.SaleDate>=@from AND s.SaleDate<@to GROUP BY b.BranchNameTH ORDER BY amount DESC;
SELECT CONVERT(date,SaleDate) saleDate,SUM(CASE WHEN StatusCode<>N'CANCELLED' THEN NetAmount ELSE 0 END) amount FROM dbo.TDPOSale WHERE CompanyID=@co AND SaleDate>=@from AND SaleDate<@to GROUP BY CONVERT(date,SaleDate) ORDER BY saleDate";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@from",SqlDbType.DateTime2,start);P(q,"@to",SqlDbType.DateTime2,end);return Ok(await Multi(q,t,["summary","branches","daily"]));
    }

    async Task<TerminalScope?> Terminal(SqlConnection c,long co,long user,Guid activation,CancellationToken t)
    {
        const string sql="SELECT x.TerminalID,o.OutletID,o.BranchID,o.WarehouseID FROM dbo.TDPOTerminal x JOIN dbo.TDPOOutlet o ON o.CompanyID=x.CompanyID AND o.OutletID=x.OutletID WHERE x.CompanyID=@co AND x.ActivationID=@activation AND x.IsActive=1 AND o.IsActive=1 AND EXISTS(SELECT 1 FROM dbo.TDADUserBranch b WHERE b.CompanyID=@co AND b.UserID=@user AND b.BranchID=o.BranchID AND b.IsActive=1)";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@user",SqlDbType.BigInt,user);P(q,"@activation",SqlDbType.UniqueIdentifier,activation);await using var r=await q.ExecuteReaderAsync(t);return await r.ReadAsync(t)?new(r.GetInt64(0),r.GetInt64(1),r.GetInt64(2),r.GetInt64(3)):null;
    }
    static async Task Stock(SqlConnection c,SqlTransaction tx,long co,long warehouse,long item,decimal qty,string type,long document,long detail,long user,long? reversal,CancellationToken t)
    {
        await using var q=new SqlCommand("MERGE dbo.TDIVStockBalance WITH(HOLDLOCK) AS target USING(SELECT @co CompanyID,@warehouse WarehouseID,@item ItemID) source ON target.CompanyID=source.CompanyID AND target.WarehouseID=source.WarehouseID AND target.ItemID=source.ItemID WHEN MATCHED THEN UPDATE SET Quantity=target.Quantity+@qty,UpdateDate=SYSUTCDATETIME() WHEN NOT MATCHED THEN INSERT(CompanyID,WarehouseID,ItemID,Quantity) VALUES(@co,@warehouse,@item,@qty);INSERT dbo.TDIVStockMovement(CompanyID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy,WarehouseID,ReversalOfMovementID) VALUES(@co,@item,@type,@document,@detail,CASE WHEN @type=N'POS_SALE' THEN N'SALE_OUT' ELSE N'REVERSAL' END,ABS(@qty),@type,@user,@warehouse,@reversal)",c,tx);P(q,"@co",SqlDbType.BigInt,co);P(q,"@warehouse",SqlDbType.BigInt,warehouse);P(q,"@item",SqlDbType.BigInt,item);P(q,"@qty",SqlDbType.Decimal,qty);P(q,"@type",SqlDbType.NVarChar,type,30);P(q,"@document",SqlDbType.BigInt,document);P(q,"@detail",SqlDbType.BigInt,detail);P(q,"@user",SqlDbType.BigInt,user);P(q,"@reversal",SqlDbType.BigInt,reversal);await q.ExecuteNonQueryAsync(t);
    }
    async Task<IActionResult> Delete(string menu,string table,string key,long id,string detail,CancellationToken t){if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,menu,"DELETE",t))return Forbid();await using var q=new SqlCommand($"DELETE {table} WHERE CompanyID=@co AND {key}=@id",c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);try{return await q.ExecuteNonQueryAsync(t)==1?NoContent():NotFound();}catch(SqlException e)when(e.Number==547){return Conflict(new{message="ลบรายการไม่ได้",description=detail});}}
    async Task<bool> HasAnyView(SqlConnection c,CancellationToken t){foreach(var menu in Menus)if(await Can(c,menu,"VIEW",t))return true;return false;}
    Task<bool> Can(SqlConnection c,string menu,string action,CancellationToken t)=>CompanyMenuAccess.IsAllowedAsync(c,User,menu,action,t);
    bool Scope(out long co,out long user){co=0;user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out co)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&co>0&&user>0;}
    async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(config.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    static async Task EnsureSettings(SqlConnection c,long co,long user,CancellationToken t){await using var q=new SqlCommand("DECLARE @p bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_POS');IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanySetupSystemPOS WHERE CompanyID=@co AND ProjectID=@p) INSERT dbo.TDSTCompanySetupSystemPOS(CompanyID,ProjectID,CreateBy) VALUES(@co,@p,@user)",c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@user",SqlDbType.BigInt,user);await q.ExecuteNonQueryAsync(t);}
    static async Task<List<Dictionary<string,object?>>> Rows(SqlConnection c,string sql,long co,CancellationToken t){await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);return await ReadRows(q,t);}
    static async Task<List<Dictionary<string,object?>>> ReadRows(SqlCommand q,CancellationToken t){await using var r=await q.ExecuteReaderAsync(t);var result=new List<Dictionary<string,object?>>();while(await r.ReadAsync(t)){var row=new Dictionary<string,object?>();for(var i=0;i<r.FieldCount;i++){var key=r.GetName(i);row[char.ToLowerInvariant(key[0])+key[1..]]=r.IsDBNull(i)?null:r.GetValue(i);}result.Add(row);}return result;}
    static async Task<Dictionary<string,object?>> Multi(SqlCommand q,CancellationToken t,string[] names){await using var r=await q.ExecuteReaderAsync(t);var result=new Dictionary<string,object?>();var n=0;do{var rows=new List<Dictionary<string,object?>>();while(await r.ReadAsync(t)){var row=new Dictionary<string,object?>();for(var i=0;i<r.FieldCount;i++){var key=r.GetName(i);row[char.ToLowerInvariant(key[0])+key[1..]]=r.IsDBNull(i)?null:r.GetValue(i);}rows.Add(row);}result[names[n++]]=rows;}while(n<names.Length&&await r.NextResultAsync(t));return result;}
    static void P(SqlCommand q,string name,SqlDbType type,object? value,int size=0){var p=size>0?q.Parameters.Add(name,type,size):q.Parameters.Add(name,type);p.Value=value??DBNull.Value;}
    static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
    BadRequestObjectResult Bad(string message,string description)=>BadRequest(new{message,description});
}

public sealed record PosSettingsInput(bool IsEnabled,bool RequireOpenShift,bool AllowNegativeStock,decimal TaxPercent,string ReceiptPrefix,string DefaultPaymentCode);
public sealed record OutletInput(string Code,string Name,long BranchID,long WarehouseID,string? PriceLevelCode,bool IsActive=true);
public sealed record TerminalInput(string Code,string Name,long OutletID,bool IsActive=true);
public sealed record OutletItemInput(long OutletID,long ItemID,string? Barcode,decimal? SalePriceOverride,bool IsSellable=true,bool ShowStock=true);
public sealed record OpenShiftInput(Guid ActivationID,decimal OpeningCash);
public sealed record CloseShiftInput(decimal CountedCash,string? Remark);
public sealed record SaleItemInput(long ItemID,decimal Quantity);
public sealed record SaleInput(Guid ActivationID,Guid IdempotencyKey,List<SaleItemInput> Items,decimal DiscountAmount,string PaymentCode,decimal ReceivedAmount,string? PaymentReference,long? CustomerID);
public sealed record ReturnItemInput(long SaleItemID,decimal Quantity);
public sealed record ReturnInput(long SaleID,List<ReturnItemInput> Items,string PaymentCode,string Reason);
public sealed record CancelInput(string Reason);
sealed record TerminalScope(long TerminalID,long OutletID,long BranchID,long WarehouseID);
sealed record SaleLine(long ItemID,string Code,string Name,decimal Quantity,decimal Price,decimal Amount);
sealed record ReturnLine(long SaleItemID,long ItemID,decimal Quantity,decimal Amount);
