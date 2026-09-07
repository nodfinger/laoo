using System.Data;
using LaooServiceModule.Infrastructure;
using LaooServiceModule.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;

[ApiController,Authorize,LaooServiceModule.Security.RequireCompanyFeature("INVENTORY")]
[LaooServiceModule.Security.RequireCompanyProject("LAOO_SERVICE")]
[Route("api/company/inventory-issues")]
public sealed class InventoryIssueController(IConfiguration configuration):ControllerBase
{
    private const string ScreenCode="08003";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token){await using var c=await Open(token);return Ok(new{view=await Can(c,"VIEW",token),create=await Can(c,"CREATE",token),edit=await Can(c,"EDIT",token),delete=await Can(c,"DELETE",token)});}

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"VIEW",token))return Forbid();
        await using var cmd=new SqlCommand("SELECT StockIssueID,IssueCode,IssueDate,WorkOrderCode,StatusCode,Remark FROM dbo.TDIVStockIssue WHERE CompanyID=@company AND IsActive=1 ORDER BY IssueDate DESC,StockIssueID DESC",c);Add(cmd,"@company",SqlDbType.BigInt,CompanyId());var rows=new List<object>();await using var r=await cmd.ExecuteReaderAsync(token);while(await r.ReadAsync(token))rows.Add(new{stockIssueID=r.GetInt64(0),issueCode=r.GetString(1),issueDate=r.GetDateTime(2),workOrderCode=r.GetString(3),statusCode=r.GetString(4),remark=Text(r,5)});return Ok(rows);
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"VIEW",token))return Forbid();var warehouses=new List<object>();var items=new List<object>();var serials=new List<object>();
        await using(var cmd=new SqlCommand("SELECT WarehouseID,WarehouseCode,WarehouseName,IsDefault FROM dbo.TDIVWarehouse WHERE CompanyID=@company AND IsActive=1 ORDER BY IsDefault DESC,WarehouseCode",c)){Add(cmd,"@company",SqlDbType.BigInt,CompanyId());await using var r=await cmd.ExecuteReaderAsync(token);while(await r.ReadAsync(token))warehouses.Add(new{warehouseID=r.GetInt64(0),warehouseCode=r.GetString(1),warehouseName=r.GetString(2),isDefault=r.GetBoolean(3)});}
        await using(var cmd=new SqlCommand("SELECT I.ItemID,I.ItemCode,I.ItemName,I.StockTrackingCode FROM dbo.TDIVItem I WHERE I.CompanyID=@company AND I.IsActive=1 AND I.ItemKindCode=N'GOODS' AND EXISTS(SELECT 1 FROM dbo.TDIVItemUsage U WHERE U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode IN(N'MATERIAL',N'SPARE_PART')) ORDER BY I.ItemCode",c)){Add(cmd,"@company",SqlDbType.BigInt,CompanyId());await using var r=await cmd.ExecuteReaderAsync(token);while(await r.ReadAsync(token))items.Add(new{itemID=r.GetInt64(0),itemCode=r.GetString(1),itemName=r.GetString(2),stockTrackingCode=r.GetString(3)});}
        await using(var cmd=new SqlCommand("SELECT ItemInstanceID,ItemID,WarehouseID,SerialNo FROM dbo.TDIVItemInstance WHERE CompanyID=@company AND StatusCode=N'IN_STOCK' ORDER BY SerialNo",c)){Add(cmd,"@company",SqlDbType.BigInt,CompanyId());await using var r=await cmd.ExecuteReaderAsync(token);while(await r.ReadAsync(token))serials.Add(new{itemInstanceID=r.GetInt64(0),itemID=r.GetInt64(1),warehouseID=r.GetInt64(2),serialNo=r.GetString(3)});}
        return Ok(new{warehouses,items,serials});
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody]InventoryIssueRequest request,CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"CREATE",token))return Forbid();if(request.WarehouseID<=0||request.WorkOrderID<=0||string.IsNullOrWhiteSpace(request.WorkOrderCode)||request.Items.Count==0)return BadRequest(new{message="ข้อมูลเบิกจ่ายไม่ครบ",description="กรุณาระบุคลัง ใบงาน และรายการอย่างน้อย 1 รายการ"});await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try
        {
            await using(var scope=new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDIVWarehouse WHERE WarehouseID=@warehouse AND CompanyID=@company AND IsActive=1) THEN 1 ELSE 0 END",c,tx)){Add(scope,"@warehouse",SqlDbType.BigInt,request.WarehouseID);Add(scope,"@company",SqlDbType.BigInt,CompanyId());if(Convert.ToInt32(await scope.ExecuteScalarAsync(token))!=1){await tx.RollbackAsync(token);return BadRequest(new{message="คลังไม่ถูกต้อง",description="คลังไม่อยู่ใน Company หรือปิดใช้งาน"});}}
            var code=$"IS{DateTime.UtcNow:yyyyMMddHHmmssfff}";await using var header=new SqlCommand("INSERT dbo.TDIVStockIssue(CompanyID,WarehouseID,IssueCode,IssueDate,WorkOrderID,WorkOrderCode,StatusCode,CreatedBy) OUTPUT INSERTED.StockIssueID VALUES(@company,@warehouse,@code,CONVERT(date,SYSUTCDATETIME()),@work,@workCode,N'DRAFT',@user)",c,tx);Add(header,"@company",SqlDbType.BigInt,CompanyId());Add(header,"@warehouse",SqlDbType.BigInt,request.WarehouseID);Add(header,"@code",SqlDbType.NVarChar,code,30);Add(header,"@work",SqlDbType.BigInt,request.WorkOrderID);Add(header,"@workCode",SqlDbType.NVarChar,request.WorkOrderCode.Trim(),50);Add(header,"@user",SqlDbType.BigInt,UserId());var id=Convert.ToInt64(await header.ExecuteScalarAsync(token));var lineNo=0;
            foreach(var line in request.Items)
            {
                lineNo++;await using var item=new SqlCommand("SELECT StockTrackingCode FROM dbo.TDIVItem I WHERE ItemID=@item AND CompanyID=@company AND IsActive=1 AND ItemKindCode=N'GOODS' AND EXISTS(SELECT 1 FROM dbo.TDIVItemUsage U WHERE U.CompanyID=I.CompanyID AND U.ItemID=I.ItemID AND U.UsageCode IN(N'MATERIAL',N'SPARE_PART'))",c,tx);Add(item,"@item",SqlDbType.BigInt,line.ItemID);Add(item,"@company",SqlDbType.BigInt,CompanyId());var tracking=(await item.ExecuteScalarAsync(token))?.ToString();if(tracking is null||line.Quantity<=0)throw new InvalidOperationException($"Invalid inventory item {line.ItemID}");var selected=(line.Serials??[]).Select(x=>x.ItemInstanceID).Distinct().ToArray();if(tracking=="SERIAL"&&(line.Quantity!=decimal.Truncate(line.Quantity)||selected.Length!=(int)line.Quantity))throw new InvalidOperationException($"ItemID {line.ItemID} requires exactly {line.Quantity:0} serial numbers");
                await using var detail=new SqlCommand("INSERT dbo.TDIVStockIssueDetail(StockIssueID,LineNo,ItemID,Quantity,Remark) OUTPUT INSERTED.StockIssueDetailID VALUES(@id,@line,@item,@qty,@remark)",c,tx);Add(detail,"@id",SqlDbType.BigInt,id);Add(detail,"@line",SqlDbType.Int,lineNo);Add(detail,"@item",SqlDbType.BigInt,line.ItemID);Add(detail,"@qty",SqlDbType.Decimal,line.Quantity);Add(detail,"@remark",SqlDbType.NVarChar,line.Remark,500);var detailId=Convert.ToInt64(await detail.ExecuteScalarAsync(token));
                foreach(var serial in selected){await using var add=new SqlCommand("INSERT dbo.TDIVStockIssueSerial(StockIssueDetailID,ItemInstanceID) SELECT @detail,I.ItemInstanceID FROM dbo.TDIVItemInstance I WHERE I.ItemInstanceID=@serial AND I.CompanyID=@company AND I.ItemID=@item AND I.WarehouseID=@warehouse AND I.StatusCode=N'IN_STOCK'; IF @@ROWCOUNT=0 THROW 52330,N'Invalid serial for inventory issue',1",c,tx);Add(add,"@detail",SqlDbType.BigInt,detailId);Add(add,"@serial",SqlDbType.BigInt,serial);Add(add,"@company",SqlDbType.BigInt,CompanyId());Add(add,"@item",SqlDbType.BigInt,line.ItemID);Add(add,"@warehouse",SqlDbType.BigInt,request.WarehouseID);await add.ExecuteNonQueryAsync(token);}
            }
            await tx.CommitAsync(token);return Ok(new{stockIssueID=id,issueCode=code,statusCode="DRAFT"});
        }
        catch(Exception ex){await tx.RollbackAsync(token);return BadRequest(new{message="บันทึกใบเบิกจ่ายไม่สำเร็จ",description=ex.Message});}
    }

    [HttpPost("{id:long}/confirm")]
    public Task<IActionResult> Confirm(long id,CancellationToken token)=>ChangeStatus(id,true,token);
    [HttpPost("{id:long}/void")]
    public Task<IActionResult> Void(long id,CancellationToken token)=>ChangeStatus(id,false,token);

    private async Task<IActionResult> ChangeStatus(long id,bool confirm,CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"EDIT",token))return Forbid();await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try
        {
            await using var status=new SqlCommand("SELECT StatusCode,WarehouseID,WorkOrderID FROM dbo.TDIVStockIssue WITH(UPDLOCK,HOLDLOCK) WHERE StockIssueID=@id AND CompanyID=@company AND IsActive=1",c,tx);Add(status,"@id",SqlDbType.BigInt,id);Add(status,"@company",SqlDbType.BigInt,CompanyId());string? current=null;long warehouse=0,work=0;await using(var r=await status.ExecuteReaderAsync(token)){if(await r.ReadAsync(token)){current=r.GetString(0);warehouse=r.GetInt64(1);work=r.GetInt64(2);}}if((confirm&&current!="DRAFT")||(!confirm&&current!="CONFIRMED")){await tx.RollbackAsync(token);return Conflict(new{message="เปลี่ยนสถานะไม่ได้",description=confirm?"ยืนยันได้เฉพาะเอกสารร่าง":"ยกเลิกได้เฉพาะเอกสารที่ยืนยันแล้ว"});}
            var lines=new List<(long Detail,long Item,decimal Qty)>();await using(var cmd=new SqlCommand("SELECT StockIssueDetailID,ItemID,Quantity FROM dbo.TDIVStockIssueDetail WHERE StockIssueID=@id",c,tx)){Add(cmd,"@id",SqlDbType.BigInt,id);await using var r=await cmd.ExecuteReaderAsync(token);while(await r.ReadAsync(token))lines.Add((r.GetInt64(0),r.GetInt64(1),r.GetDecimal(2)));}
            foreach(var line in lines)
            {
                var sign=confirm?-line.Qty:line.Qty;var movement=confirm?"ISSUE":"REVERSAL";await using var balance=new SqlCommand(confirm?"UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK) SET Quantity=Quantity-@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND WarehouseID=@warehouse AND ItemID=@item AND Quantity>=@qty; IF @@ROWCOUNT=0 THROW 52331,N'Insufficient warehouse stock',1; UPDATE dbo.TDIVItem SET StockBalance=StockBalance-@qty WHERE CompanyID=@company AND ItemID=@item":"UPDATE dbo.TDIVStockBalance SET Quantity=Quantity+@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND WarehouseID=@warehouse AND ItemID=@item; UPDATE dbo.TDIVItem SET StockBalance=StockBalance+@qty WHERE CompanyID=@company AND ItemID=@item",c,tx);Add(balance,"@qty",SqlDbType.Decimal,line.Qty);Add(balance,"@company",SqlDbType.BigInt,CompanyId());Add(balance,"@warehouse",SqlDbType.BigInt,warehouse);Add(balance,"@item",SqlDbType.BigInt,line.Item);await balance.ExecuteNonQueryAsync(token);
                await using var move=new SqlCommand("INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@warehouse,@item,N'WORK_ORDER',@work,@detail,@movement,@qty,N'Inventory issue by work order',@user)",c,tx);Add(move,"@company",SqlDbType.BigInt,CompanyId());Add(move,"@warehouse",SqlDbType.BigInt,warehouse);Add(move,"@item",SqlDbType.BigInt,line.Item);Add(move,"@work",SqlDbType.BigInt,work);Add(move,"@detail",SqlDbType.BigInt,line.Detail);Add(move,"@movement",SqlDbType.NVarChar,movement,30);Add(move,"@qty",SqlDbType.Decimal,sign);Add(move,"@user",SqlDbType.BigInt,UserId());await move.ExecuteNonQueryAsync(token);
                var from=confirm?"IN_STOCK":"ISSUED";var to=confirm?"ISSUED":"IN_STOCK";await using var serial=new SqlCommand("UPDATE I SET StatusCode=@to,WarehouseID=CASE WHEN @to=N'IN_STOCK' THEN @warehouse ELSE NULL END,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user FROM dbo.TDIVItemInstance I JOIN dbo.TDIVStockIssueSerial S ON S.ItemInstanceID=I.ItemInstanceID WHERE S.StockIssueDetailID=@detail AND I.CompanyID=@company AND I.StatusCode=@from; INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,WarehouseID,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy) SELECT @company,S.ItemInstanceID,@from,@to,CASE WHEN @to=N'IN_STOCK' THEN @warehouse ELSE NULL END,N'WORK_ORDER',@work,@detail,N'Work order stock issue',@user FROM dbo.TDIVStockIssueSerial S WHERE S.StockIssueDetailID=@detail",c,tx);Add(serial,"@to",SqlDbType.NVarChar,to,20);Add(serial,"@from",SqlDbType.NVarChar,from,20);Add(serial,"@warehouse",SqlDbType.BigInt,warehouse);Add(serial,"@user",SqlDbType.BigInt,UserId());Add(serial,"@detail",SqlDbType.BigInt,line.Detail);Add(serial,"@company",SqlDbType.BigInt,CompanyId());Add(serial,"@work",SqlDbType.BigInt,work);await serial.ExecuteNonQueryAsync(token);
            }
            await using var done=new SqlCommand(confirm?"UPDATE dbo.TDIVStockIssue SET StatusCode=N'CONFIRMED',ConfirmDate=SYSUTCDATETIME(),ConfirmedBy=@user WHERE StockIssueID=@id":"UPDATE dbo.TDIVStockIssue SET StatusCode=N'VOID',VoidDate=SYSUTCDATETIME(),VoidedBy=@user WHERE StockIssueID=@id",c,tx);Add(done,"@id",SqlDbType.BigInt,id);Add(done,"@user",SqlDbType.BigInt,UserId());await done.ExecuteNonQueryAsync(token);await tx.CommitAsync(token);return Ok(new{stockIssueID=id,statusCode=confirm?"CONFIRMED":"VOID"});
        }
        catch(Exception ex){await tx.RollbackAsync(token);return BadRequest(new{message="เปลี่ยนสถานะใบเบิกจ่ายไม่สำเร็จ",description=ex.Message});}
    }

    private async Task<SqlConnection> Open(CancellationToken token)=>await InventoryControllerSupport.OpenAsync(configuration,token);
    private Task<bool> Can(SqlConnection c,string action,CancellationToken token)=>InventoryControllerSupport.CanAsync(c,User,ScreenCode,action,token);
    private long CompanyId()=>InventoryControllerSupport.ClaimId(User,"company_id");private long UserId()=>InventoryControllerSupport.ClaimId(User,"user_id");
    private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetValue(i)?.ToString();private static void Add(SqlCommand c,string n,SqlDbType t,object? v,int s=0)=>InventoryControllerSupport.Add(c,n,t,v,s);
}
