using System.Security.Claims;
using System.Text.Json;
using LaooServiceModule.Controllers;
using LaooServiceModule.Infrastructure;
using LaooServiceModule.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

var root=Path.GetFullPath(args.FirstOrDefault()??".");
var config=new ConfigurationBuilder().AddJsonFile(Path.Combine(root,"laoo_api/local.json")).Build();
var cs=config.GetConnectionString("LaooDatabase")!;
long user=0,company=0,partner=0,item=0,vendor=0,setup=0;
var tag="RECEIPT-TEST-"+Guid.NewGuid().ToString("N");
async Task<object?> Scalar(string sql,params (string,object?)[] values){
    await using var c=new SqlConnection(cs);await c.OpenAsync();
    await using var cmd=new SqlCommand(sql,c);
    foreach(var (key,value) in values)cmd.Parameters.AddWithValue(key,value??DBNull.Value);
    return await cmd.ExecuteScalarAsync();
}
await using(var c=new SqlConnection(cs)){
    await c.OpenAsync();
    await using var cmd=new SqlCommand("""
SELECT TOP(1) U.UserID,U.CompanyID,C.PartnerID,C.PKValue FROM dbo.TDADUser U
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.IsActive=1
JOIN dbo.TDADPartner P ON P.PartnerID=C.PartnerID AND P.IsActive=1
WHERE U.IsActive=1 AND U.IsCompanyAdmin=1
AND EXISTS(SELECT 1 FROM dbo.TDIVWarehouse W JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID
 WHERE W.CompanyID=U.CompanyID AND W.IsActive=1 AND B.IsActive=1)
AND EXISTS(SELECT 1 FROM dbo.TDIVItem I WHERE I.CompanyID=U.CompanyID)
ORDER BY U.UserID
""",c);
    await using var r=await cmd.ExecuteReaderAsync();
    if(!await r.ReadAsync())throw new Exception("No active fixture owner.");
    user=r.GetInt64(0);company=r.GetInt64(1);partner=r.GetInt64(2);setup=r.GetInt64(3);
}
using var logs=LoggerFactory.Create(b=>b.AddConsole());
StockReceiptController Controller(long? uid=null,long? cid=null,long? pid=null)=>new(config,logs.CreateLogger<StockReceiptController>()){
    ControllerContext=new ControllerContext{HttpContext=new DefaultHttpContext{
        User=new ClaimsPrincipal(new ClaimsIdentity(new[]{
            new Claim("user_type","COMPANY_USER"),new Claim("user_id",(uid??user).ToString()),
            new Claim("company_id",(cid??company).ToString()),new Claim("partner_id",(pid??partner).ToString()),
        },"Test"))
    }}
};
int Status(IActionResult r)=>r is ObjectResult o?o.StatusCode??200:r is StatusCodeResult s?s.StatusCode:r is ForbidResult?403:0;
JsonElement Data(IActionResult r)=>JsonSerializer.SerializeToElement(((ObjectResult)r).Value);
int checks=0;
void Check(string name,bool ok){if(!ok)throw new Exception("FAIL: "+name);Console.WriteLine("PASS: "+name);checks++;}
var controller=Controller();
var lookup=Data(await controller.Lookup(default));
var warehouse=lookup.GetProperty("warehouses")[0].GetProperty("warehouseID").GetInt64();
try{
    vendor=Convert.ToInt64(await Scalar("""
INSERT dbo.TDAPVendor(CompanyID,CompanySetupID,VendorCode,VendorName,EntityTypeCode,CreatedBy)
OUTPUT INSERTED.VendorID VALUES(@company,@setup,@code,N'Receipt test fixture','ORGANIZATION',@user)
""",("@company",company),("@setup",setup),("@code",tag),("@user",user)));
    item=Convert.ToInt64(await Scalar("""
INSERT dbo.TDIVItem(CompanyID,ItemGroupCode,ItemTypeCode,ItemCode,ItemName,UnitCode,ItemKindCode,StockTrackingCode)
OUTPUT INSERTED.ItemID
SELECT TOP(1) @company,ItemGroupCode,ItemTypeCode,@code,N'Receipt test fixture',UnitCode,N'GOODS',N'SERIAL'
FROM dbo.TDIVItem WHERE CompanyID=@company ORDER BY ItemID
""",("@company",company),("@code",tag)));
    Check("Dedicated zero-stock fixture",item>0);
    var line=new StockReceiptLineRequest(item,5,10,null,[],"INTERNAL");
    var body=new StockReceiptUpsertRequest(warehouse,DateOnly.FromDateTime(DateTime.Today),"RECEIPT",tag,"Test only",[line],vendor,"Test courier");
    Check("Missing vendor rejected",Status(await controller.Create(body with{VendorID=null},default))==400);
    Check("Invalid vendor rejected",Status(await controller.Create(body with{VendorID=long.MaxValue},default))==400);
    Check("Warehouse tampering denied",Status(await controller.Create(body with{WarehouseID=long.MaxValue},default))==403);
    Check("Cross-company denied",Status(await Controller(cid:-1).Create(body,default))==403);
    Check("Cross-partner denied",Status(await Controller(pid:-1).Create(body,default))==403);
    Check("Unknown user cannot save",Status(await Controller(uid:-1).Create(body,default))==403);
    Check("Negative quantity rejected",Status(await controller.Create(body with{Items=[line with{Quantity=-1}]},default))==400);
    Check("Fractional serial quantity rejected",Status(await controller.Create(body with{Items=[line with{Quantity=1.5m}]},default))==400);
    Check("Incomplete factory serials rejected",Status(await controller.Create(body with{Items=[line with{SerialSourceCode="FACTORY",Serials=[new("SN")]}]},default))==400);
    Check("Caller cannot mint internal serial",Status(await controller.Create(body with{Items=[line with{Quantity=1,Serials=[new("CALLER-GENERATED")]}]},default))==400);
    Check("Failure did not create header",Convert.ToInt32(await Scalar("SELECT COUNT(*) FROM dbo.TDIVStockReceipt WHERE CompanyID=@company AND ReferenceNo=@tag",("@company",company),("@tag",tag)))==0);
    await Scalar("UPDATE dbo.TDAPVendor SET IsActive=0 WHERE VendorID=@id AND CompanyID=@company",("@id",vendor),("@company",company));
    Check("Inactive vendor rejected",Status(await controller.Create(body,default))==400);
    await Scalar("UPDATE dbo.TDAPVendor SET IsActive=1 WHERE VendorID=@id AND CompanyID=@company",("@id",vendor),("@company",company));
    var saved=await controller.Create(body,default);
    Check("Create draft",Status(saved)==200);
    var data=Data(saved);var id=data.GetProperty("stockReceiptID").GetInt64();
    var numbers=data.GetProperty("items")[0].GetProperty("serials").EnumerateArray().Select(x=>new StockReceiptSerialInput(x.GetString()!)).ToArray();
    Check("Five unique internal serials",numbers.Length==5&&numbers.Select(x=>x.SerialNo).Distinct().Count()==5);
    Check("Draft does not increase stock",Convert.ToDecimal(await Scalar("SELECT StockBalance FROM dbo.TDIVItem WHERE ItemID=@item",("@item",item)))==0);
    Check("Draft does not create instances",Convert.ToInt32(await Scalar("SELECT COUNT(*) FROM dbo.TDIVItemInstance WHERE CompanyID=@company AND ItemID=@item",("@company",company),("@item",item)))==0);
    var detail=Data(await controller.Get(id,default));
    Check("Vendor and courier round-trip",detail.GetProperty("header").GetProperty("vendorID").GetInt64()==vendor&&detail.GetProperty("header").GetProperty("deliveredBy").GetString()=="Test courier");
    Check("Serial source round-trip",detail.GetProperty("items")[0].GetProperty("serialSourceCode").GetString()=="INTERNAL");
    var editBody=body with{Items=[line with{Serials=numbers}]};
    var edited=Data(await controller.Update(id,editBody,default));
    Check("Resave same id and serials",edited.GetProperty("stockReceiptID").GetInt64()==id&&edited.GetProperty("items")[0].GetProperty("serials")[0].GetString()==numbers[0].SerialNo);
    Check("Reserved serial rejected in second draft",Status(await controller.Create(body with{Items=[line with{SerialSourceCode="FACTORY",Serials=numbers}]},default))==400);
    Check("Invalid edit rolls back",Status(await controller.Update(id,editBody with{Items=[line with{SerialSourceCode="FACTORY",Serials=[new("DUP"),new("dup"),new("3"),new("4"),new("5")]}]},default))==400);
    Check("Original serials survived failure",Data(await controller.Get(id,default)).GetProperty("serials").GetArrayLength()==5);
    var confirmed=await Task.WhenAll(controller.Confirm(id,default),Controller().Confirm(id,default));
    Check("Concurrent confirmation only once",confirmed.Count(r=>Status(r)==200)==1&&confirmed.Count(r=>Status(r)==400)==1);
    Check("Stock added exactly once",Convert.ToDecimal(await Scalar("SELECT StockBalance FROM dbo.TDIVItem WHERE ItemID=@item",("@item",item)))==5);
    Check("Five instances created",Convert.ToInt32(await Scalar("SELECT COUNT(*) FROM dbo.TDIVItemInstance WHERE CompanyID=@company AND ItemID=@item",("@company",company),("@item",item)))==5);
    Check("Confirmed receipt cannot edit",Status(await controller.Update(id,editBody,default))==400);
    var opening=body with{ReceiptType="OPENING",VendorID=null,Items=[line with{Quantity=1,SerialSourceCode="FACTORY",Serials=[new(tag)]}]};
    Check("Opening without vendor",Status(await controller.Create(opening,default))==200);
    Check("Factory draft duplicate across lines",Status(await controller.Create(opening with{Items=[opening.Items[0],opening.Items[0]]},default))==400);
}
finally{
    // Delete only this run's explicitly captured fixture IDs. Never restore or touch a real product's stock.
    await Scalar("""
SET XACT_ABORT ON; BEGIN TRAN;
DELETE H FROM dbo.TDIVItemInstanceHistory H JOIN dbo.TDIVItemInstance I ON I.ItemInstanceID=H.ItemInstanceID WHERE I.ItemID=@item AND I.CompanyID=@company;
DELETE FROM dbo.TDIVStockMovement WHERE ItemID=@item AND CompanyID=@company;
DELETE FROM dbo.TDIVItemInstance WHERE ItemID=@item AND CompanyID=@company;
DELETE FROM dbo.TDIVStockBalance WHERE ItemID=@item AND CompanyID=@company;
DELETE R FROM dbo.TDIVStockReceipt R WHERE R.CompanyID=@company AND R.ReferenceNo=@tag
 AND EXISTS(SELECT 1 FROM dbo.TDIVStockReceiptDetail D WHERE D.StockReceiptID=R.StockReceiptID AND D.ItemID=@item);
DELETE FROM dbo.TDIVItem WHERE ItemID=@item AND CompanyID=@company AND ItemCode=@tag;
DELETE FROM dbo.TDAPVendor WHERE VendorID=@vendor AND CompanyID=@company AND VendorCode=@tag;
COMMIT;
""",("@item",item),("@company",company),("@vendor",vendor),("@tag",tag));
    Console.WriteLine("Dedicated test product, vendor, receipts, serials and stock rows removed.");
}
Console.WriteLine($"{checks} checks passed.");
