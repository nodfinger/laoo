using System.Data;
using LaooServiceModule.Infrastructure;
using LaooServiceModule.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace LaooServiceModule.Controllers;

[ApiController, Authorize]
[LaooServiceModule.Security.RequireCompanyProject("LAOO")]
[TypeFilter(typeof(ItemProjectExceptionFilter))]
[Route("api/company/stock-receipts")]
public sealed partial class StockReceiptController(IConfiguration configuration, IWebHostEnvironment environment, ILogger<StockReceiptController>? logger = null) : ControllerBase
{
    private const string ScreenCode="08005";
    private sealed record ReceiptPackRow(long ItemID, string UnitCode, string? ParentUnitCode, decimal ConversionQuantity, decimal BaseQuantity, string? ParentUnitName);

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token){await using var c=await Open(token);return Ok(new{view=await Can(c,"VIEW",token),create=await Can(c,"CREATE",token),edit=await Can(c,"EDIT",token),delete=await Can(c,"DELETE",token)});}

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken token)
    {
        await using var c=await Open(token); if(!await Can(c,"VIEW",token))return Forbid();
        var warehouses=await Rows(c,$"SELECT W.WarehouseID,W.WarehouseCode,W.WarehouseName,W.IsDefault FROM dbo.TDIVWarehouse W INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE W.CompanyID=@company AND W.IsActive=1 AND {WarehouseAccessService.WarehouseAliasPredicate} ORDER BY W.IsDefault DESC,W.WarehouseCode",token,r=>new{warehouseID=r.GetInt64(0),warehouseCode=r.GetString(1),warehouseName=r.GetString(2),isDefault=r.GetBoolean(3)});
        var itemRows=new List<(long Id,string Code,string Name,string Tracking,string Unit,string UnitName,string TypeCode,string TypeName,string? FilePath,byte[]? LegacyImage)>();
        await using(var itemCommand=new SqlCommand($"""
            SELECT I.ItemID,I.ItemCode,I.ItemName,I.StockTrackingCode,I.UnitCode,I.ItemTypeCode,
                   COALESCE(T.Name,I.ItemTypeCode),X.FilePath,X.ImageData,COALESCE(U.Name,I.UnitCode)
            FROM dbo.TDIVItem I
            LEFT JOIN dbo.TDSTMaster T ON T.MasterGroupCode=N'007' AND T.MasterCode=I.ItemTypeCode
              AND T.OwnerType=N'C' AND T.OwnerCompanyID=I.CompanyID AND T.IsActive=1
            LEFT JOIN dbo.TDSTMaster U ON U.MasterGroupCode=@unitGroup AND U.MasterCode=I.UnitCode
              AND U.OwnerType=N'C' AND U.OwnerCompanyID=I.CompanyID AND U.IsActive=1
            OUTER APPLY(SELECT TOP 1 IMG.FilePath,IMG.ImageData FROM dbo.TDIVItemImage IMG
              WHERE IMG.ItemID=I.ItemID AND IMG.IsCover=1 AND IMG.IsActive=1 ORDER BY IMG.SortOrder,IMG.ItemImageID) X
            WHERE I.CompanyID=@company AND I.IsActive=1 AND I.ItemKindCode=N'GOODS'
              AND I.StockTrackingCode<>N'NONE' AND {ItemProjectAccess.ItemAliasPredicate}
            ORDER BY I.ItemCode
            """,c))
        {
            Add(itemCommand,"@company",SqlDbType.BigInt,CompanyId());Add(itemCommand,"@user",SqlDbType.BigInt,UserId());Add(itemCommand,"@unitGroup",SqlDbType.NVarChar,MasterConstCodes.cmsUnit,10);
            await using var reader=await itemCommand.ExecuteReaderAsync(token);
            while(await reader.ReadAsync(token))itemRows.Add((reader.GetInt64(0),reader.GetString(1),reader.GetString(2),reader.GetString(3),reader.GetString(4),reader.GetString(9),reader.GetString(5),reader.GetString(6),Text(reader,7),reader.IsDBNull(8)?null:(byte[])reader[8]));
        }
        var packRows=new List<ReceiptPackRow>();
        await using(var packCommand=new SqlCommand("""
            SELECT P.ItemID,P.UnitCode,P.ParentUnitCode,P.ConversionQuantity,P.BaseQuantity,
                   COALESCE(U.Name,P.ParentUnitCode)
            FROM dbo.TDIVItemPackUnit P
            INNER JOIN dbo.TDIVItem I ON I.ItemID=P.ItemID AND I.CompanyID=@company AND I.IsActive=1
            LEFT JOIN dbo.TDSTMaster U ON U.MasterGroupCode=N'002' AND U.MasterCode=P.ParentUnitCode
              AND U.OwnerType=N'C' AND U.OwnerCompanyID=I.CompanyID AND U.IsActive=1
            ORDER BY P.ItemID,P.SortOrder,P.ItemPackUnitID
            """,c))
        {
            Add(packCommand,"@company",SqlDbType.BigInt,CompanyId());
            await using var reader=await packCommand.ExecuteReaderAsync(token);
            while(await reader.ReadAsync(token))packRows.Add(new ReceiptPackRow(reader.GetInt64(0),reader.GetString(1),Text(reader,2),reader.GetDecimal(3),reader.GetDecimal(4),Text(reader,5)));
        }
        var items=new List<object>();
        foreach(var item in itemRows)items.Add(new{itemID=item.Id,itemCode=item.Code,itemName=item.Name,stockTrackingCode=item.Tracking,unitCode=item.Unit,unitName=item.UnitName,itemTypeCode=item.TypeCode,itemTypeName=item.TypeName,receiptUnits=BuildReceiptUnits(item.Unit,item.UnitName,packRows.Where(x=>x.ItemID==item.Id)),coverImageBase64=await ReadImageBase64Async(item.FilePath,item.LegacyImage,token)});
        var vendors=await Rows(c,"SELECT VendorID,VendorCode,VendorName FROM dbo.TDAPVendor WHERE CompanyID=@company AND IsActive=1 ORDER BY VendorCode",token,r=>new{vendorID=r.GetInt64(0),vendorCode=r.GetString(1),vendorName=r.GetString(2)});
        return Ok(new{warehouses,items,vendors,canCreateVendor=await InventoryControllerSupport.CanAsync(c,User,"08007","CREATE",token),receiptTypes=new[]{"RECEIPT","OPENING"}});
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery]string? search,[FromQuery]string? status,[FromQuery]long? vendorId,[FromQuery]long? warehouseId,CancellationToken token)
    {
        await using var c=await Open(token); if(!await Can(c,"VIEW",token))return Forbid();
        var sql=$"SELECT R.StockReceiptID,R.ReceiptCode,R.ReceiptDate,R.VendorName,R.ReceiptType,R.StatusCode,R.ReferenceNo,W.WarehouseCode,W.WarehouseName,COALESCE(SUM(D.Quantity),0) TotalQuantity FROM dbo.TDIVStockReceipt R JOIN dbo.TDIVWarehouse W ON W.WarehouseID=R.WarehouseID AND W.CompanyID=R.CompanyID INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 LEFT JOIN dbo.TDIVStockReceiptDetail D ON D.StockReceiptID=R.StockReceiptID WHERE R.CompanyID=@company AND R.IsActive=1 AND {WarehouseAccessService.WarehouseAliasPredicate} AND (@status=N'' OR R.StatusCode=@status) AND (@vendorId IS NULL OR R.VendorID=@vendorId) AND (@warehouseId IS NULL OR R.WarehouseID=@warehouseId) AND (@search=N'' OR R.ReceiptCode LIKE @like OR R.ReferenceNo LIKE @like OR R.Remark LIKE @like OR R.DeliveredBy LIKE @like) GROUP BY R.StockReceiptID,R.ReceiptCode,R.ReceiptDate,R.VendorName,R.ReceiptType,R.StatusCode,R.ReferenceNo,W.WarehouseCode,W.WarehouseName ORDER BY R.ReceiptDate DESC,R.StockReceiptID DESC";
        await using var cmd=new SqlCommand(sql,c);var q=search?.Trim()??"";Add(cmd,"@company",SqlDbType.BigInt,CompanyId());Add(cmd,"@user",SqlDbType.BigInt,UserId());Add(cmd,"@status",SqlDbType.NVarChar,status?.Trim().ToUpperInvariant()??"",20);Add(cmd,"@vendorId",SqlDbType.BigInt,vendorId);Add(cmd,"@warehouseId",SqlDbType.BigInt,warehouseId);Add(cmd,"@search",SqlDbType.NVarChar,q,200);Add(cmd,"@like",SqlDbType.NVarChar,$"%{q}%",210);
        var rows=new List<object>();await using var reader=await cmd.ExecuteReaderAsync(token);while(await reader.ReadAsync(token))rows.Add(new{stockReceiptID=reader.GetInt64(0),receiptCode=reader.GetString(1),receiptDate=reader.GetDateTime(2),vendorName=Text(reader,3),receiptType=reader.GetString(4),statusCode=reader.GetString(5),referenceNo=Text(reader,6),warehouseCode=reader.GetString(7),warehouseName=reader.GetString(8),totalQuantity=reader.GetDecimal(9)});return Ok(rows);
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id,CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"VIEW",token))return Forbid();
        const string headerSql="SELECT StockReceiptID,WarehouseID,ReceiptCode,ReceiptDate,ReceiptType,StatusCode,ReferenceNo,Remark,VendorID,VendorCode,VendorName,DeliveredBy FROM dbo.TDIVStockReceipt WHERE StockReceiptID=@id AND CompanyID=@company AND IsActive=1";
        await using var header=new SqlCommand(headerSql,c);Add(header,"@id",SqlDbType.BigInt,id);Add(header,"@company",SqlDbType.BigInt,CompanyId());await using var hr=await header.ExecuteReaderAsync(token);if(!await hr.ReadAsync(token))return NotFound();var warehouseId=hr.GetInt64(1);var result=new{stockReceiptID=hr.GetInt64(0),warehouseID=warehouseId,receiptCode=hr.GetString(2),receiptDate=hr.GetDateTime(3),receiptType=hr.GetString(4),statusCode=hr.GetString(5),referenceNo=Text(hr,6),remark=Text(hr,7),vendorID=hr.IsDBNull(8)?(long?)null:hr.GetInt64(8),vendorCode=Text(hr,9),vendorName=Text(hr,10),deliveredBy=Text(hr,11)};await hr.DisposeAsync();if(!await WarehouseAccessService.CanAccessAsync(c,null,CompanyId(),UserId(),warehouseId,token))return StatusCode(403,new{message="ไม่มีสิทธิ์เข้าถึงคลัง",description="เอกสารนี้อยู่ในคลังที่ผู้ใช้ไม่ได้รับสิทธิ์"});
        const string detailSql="SELECT D.StockReceiptDetailID,D.[LineNo],D.ItemID,I.ItemCode,I.ItemName,I.StockTrackingCode,COALESCE(D.ReceiptQuantity,D.Quantity),D.UnitCost,D.Remark,D.SerialSourceCode,COALESCE(D.ReceiptUnitCode,I.UnitCode),D.Quantity,COALESCE(D.BaseUnitCode,I.UnitCode),COALESCE(D.UnitConversionFactor,1) FROM dbo.TDIVStockReceiptDetail D JOIN dbo.TDIVItem I ON I.ItemID=D.ItemID WHERE D.StockReceiptID=@id AND I.CompanyID=@company ORDER BY D.[LineNo]";
        await using var detail=new SqlCommand(detailSql,c);Add(detail,"@id",SqlDbType.BigInt,id);Add(detail,"@company",SqlDbType.BigInt,CompanyId());var items=new List<object>();await using var dr=await detail.ExecuteReaderAsync(token);while(await dr.ReadAsync(token))items.Add(new{stockReceiptDetailID=dr.GetInt64(0),lineNo=dr.GetInt32(1),itemID=dr.GetInt64(2),itemCode=dr.GetString(3),itemName=dr.GetString(4),stockTrackingCode=dr.GetString(5),quantity=dr.GetDecimal(6),unitCost=dr.GetDecimal(7),remark=Text(dr,8),serialSourceCode=dr.GetString(9),unitCode=dr.GetString(10),baseQuantity=dr.GetDecimal(11),baseUnitCode=dr.GetString(12),conversionFactor=dr.GetDecimal(13)});await dr.DisposeAsync();
        var serials=await RowsById(c,"SELECT S.StockReceiptDetailID,S.SerialNo FROM dbo.TDIVStockReceiptSerial S JOIN dbo.TDIVStockReceiptDetail D ON D.StockReceiptDetailID=S.StockReceiptDetailID WHERE D.StockReceiptID=@id ORDER BY S.StockReceiptSerialID",id,token,r=>new{stockReceiptDetailID=r.GetInt64(0),serialNo=r.GetString(1)});
        return Ok(new{header=result,items,serials});
    }

    private static List<object> BuildReceiptUnits(string baseUnitCode,string baseUnitName,IEnumerable<ReceiptPackRow> rows)
    {
        var result=new List<object>{new{unitCode=baseUnitCode,unitName=baseUnitName,conversionFactor=1m,isBaseUnit=true}};
        var byChild=rows.Where(x=>x.ConversionQuantity>0&&x.BaseQuantity>0).GroupBy(x=>x.UnitCode,StringComparer.OrdinalIgnoreCase).ToDictionary(x=>x.Key,x=>x.First(),StringComparer.OrdinalIgnoreCase);
        var visited=new HashSet<string>(StringComparer.OrdinalIgnoreCase){baseUnitCode};
        var current=baseUnitCode;var factor=1m;
        for(var depth=0;depth<20&&byChild.TryGetValue(current,out var row);depth++)
        {
            if(string.IsNullOrWhiteSpace(row.ParentUnitCode)||!visited.Add(row.ParentUnitCode))break;
            factor*=row.ConversionQuantity/row.BaseQuantity;
            if(factor<=0)break;
            result.Add(new{unitCode=row.ParentUnitCode,unitName=row.ParentUnitName??row.ParentUnitCode,conversionFactor=factor,isBaseUnit=false});
            current=row.ParentUnitCode;
        }
        return result;
    }

    [HttpPost]
    public Task<IActionResult> Create(StockReceiptUpsertRequest request,CancellationToken token)=>SaveIntegrated(null,request,token);
    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id,StockReceiptUpsertRequest request,CancellationToken token)=>SaveIntegrated(id,request,token);

    [HttpPost("{id:long}/confirm")]
    public async Task<IActionResult> Confirm(long id,CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"EDIT",token))return Forbid();await using var tx=(SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            await LockReceiptSerials(c,tx,token);
            var warehouse=await ScalarLong(c,tx,"SELECT WarehouseID FROM dbo.TDIVStockReceipt WITH(UPDLOCK,HOLDLOCK) WHERE StockReceiptID=@id AND CompanyID=@company AND StatusCode=N'DRAFT' AND IsActive=1",id,token);if(!warehouse.HasValue)return BadRequest(new{message="ยืนยันรับสินค้าไม่ได้",description="เอกสารไม่อยู่ในสถานะ DRAFT หรืออยู่นอก Company"});if(!await WarehouseAccessService.CanAccessAsync(c,tx,CompanyId(),UserId(),warehouse.Value,token))return StatusCode(403,new{message="ไม่มีสิทธิ์เข้าถึงคลัง",description="ผู้ใช้ไม่มีสิทธิ์ยืนยันรายการของคลังนี้"});
            await using var receiptDateCommand=new SqlCommand("SELECT ReceiptDate FROM dbo.TDIVStockReceipt WHERE StockReceiptID=@id AND CompanyID=@company",c,tx);Add(receiptDateCommand,"@id",SqlDbType.BigInt,id);Add(receiptDateCommand,"@company",SqlDbType.BigInt,CompanyId());var receiptDate=DateOnly.FromDateTime(Convert.ToDateTime(await receiptDateCommand.ExecuteScalarAsync(token)));
            const string lineSql="SELECT D.StockReceiptDetailID,D.ItemID,D.Quantity,I.StockTrackingCode FROM dbo.TDIVStockReceiptDetail D JOIN dbo.TDIVItem I ON I.ItemID=D.ItemID AND I.CompanyID=@company WHERE D.StockReceiptID=@id ORDER BY D.[LineNo]";
            await using var lineCommand=new SqlCommand(lineSql,c,tx);Add(lineCommand,"@id",SqlDbType.BigInt,id);Add(lineCommand,"@company",SqlDbType.BigInt,CompanyId());var lines=new List<(long Detail,long Item,decimal Qty,string Tracking)>();await using(var reader=await lineCommand.ExecuteReaderAsync(token)){while(await reader.ReadAsync(token))lines.Add((reader.GetInt64(0),reader.GetInt64(1),reader.GetDecimal(2),reader.GetString(3)));}
            if(lines.Count==0)return BadRequest(new{message="ยืนยันรับสินค้าไม่ได้",description="เอกสารต้องมีรายการอย่างน้อยหนึ่งรายการ"});
            foreach(var line in lines)
            {
                await ItemProjectAccess.EnsureAsync(c,tx,CompanyId(),line.Item,token);
                var serials=await SerialNumbers(c,tx,line.Detail,token);
                if(line.Tracking=="SERIAL"&&(line.Qty!=decimal.Truncate(line.Qty)||serials.Count!=(int)line.Qty))return BadRequest(new{message="Serial ไม่ครบ",description=$"ItemID {line.Item} ต้องระบุ Serial ให้ครบ {line.Qty:0} รายการ"});
                if(line.Tracking!="SERIAL"&&serials.Count>0)return BadRequest(new{message="ไม่สามารถระบุ Serial ได้",description=$"ItemID {line.Item} ไม่ได้ควบคุมแบบ SERIAL"});
                await IncreaseBalance(c,tx,warehouse.Value,line.Item,line.Qty,id,line.Detail,"RECEIPT",token);
                foreach(var serial in serials)await CreateInstance(c,tx,warehouse.Value,line.Item,serial,id,line.Detail,receiptDate,token);
            }
            await using var confirm=new SqlCommand("UPDATE dbo.TDIVStockReceipt SET StatusCode=N'CONFIRMED',ConfirmDate=SYSUTCDATETIME(),ConfirmedBy=@user,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE StockReceiptID=@id AND CompanyID=@company",c,tx);Add(confirm,"@user",SqlDbType.BigInt,UserId());Add(confirm,"@id",SqlDbType.BigInt,id);Add(confirm,"@company",SqlDbType.BigInt,CompanyId());await confirm.ExecuteNonQueryAsync(token);await tx.CommitAsync(token);return Ok(new{message="ยืนยันรับสินค้าแล้ว"});
        }
        catch(SqlException ex){logger?.LogError(ex,"Receipt confirmation failed for Company {CompanyID}, document {ReceiptID}",CompanyId(),id);try{await tx.RollbackAsync(token);}catch{}return BadRequest(new{message="ยืนยันรับสินค้าไม่สำเร็จ",description=ex.Number is 2601 or 2627?"พบ Serial ซ้ำภายใน Company":"กรุณาลองยืนยันใหม่ หากยังไม่สำเร็จให้ติดต่อผู้ดูแลระบบ"});}
    }

    [HttpPost("{id:long}/void")]
    public async Task<IActionResult> Void(long id,CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"DELETE",token))return Forbid();await using var tx=(SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            var warehouse=await ScalarLong(c,tx,"SELECT WarehouseID FROM dbo.TDIVStockReceipt WITH(UPDLOCK,HOLDLOCK) WHERE StockReceiptID=@id AND CompanyID=@company AND StatusCode=N'CONFIRMED'",id,token);if(!warehouse.HasValue)return BadRequest(new{message="ยกเลิกรับสินค้าไม่ได้",description="เอกสารไม่อยู่ในสถานะ CONFIRMED"});if(!await WarehouseAccessService.CanAccessAsync(c,tx,CompanyId(),UserId(),warehouse.Value,token))return StatusCode(403,new{message="ไม่มีสิทธิ์เข้าถึงคลัง",description="ผู้ใช้ไม่มีสิทธิ์ยกเลิกรายการของคลังนี้"});
            const string sql="SELECT D.StockReceiptDetailID,D.ItemID,D.Quantity FROM dbo.TDIVStockReceiptDetail D WHERE D.StockReceiptID=@id";await using var command=new SqlCommand(sql,c,tx);Add(command,"@id",SqlDbType.BigInt,id);var lines=new List<(long Detail,long Item,decimal Qty)>();await using(var reader=await command.ExecuteReaderAsync(token)){while(await reader.ReadAsync(token))lines.Add((reader.GetInt64(0),reader.GetInt64(1),reader.GetDecimal(2)));}
            foreach(var line in lines)
            {
                await DecreaseBalance(c,tx,warehouse.Value,line.Item,line.Qty,id,line.Detail,token);
                await using var serialCheck=new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDIVItemInstanceHistory H JOIN dbo.TDIVItemInstance I ON I.ItemInstanceID=H.ItemInstanceID WHERE H.CompanyID=@company AND H.DocumentType=N'STOCK_RECEIPT' AND H.DocumentDetailID=@detail AND I.StatusCode<>N'IN_STOCK') THEN 1 ELSE 0 END",c,tx);Add(serialCheck,"@company",SqlDbType.BigInt,CompanyId());Add(serialCheck,"@detail",SqlDbType.BigInt,line.Detail);if(Convert.ToInt32(await serialCheck.ExecuteScalarAsync(token))==1)return BadRequest(new{message="ยกเลิกรับสินค้าไม่ได้",description="มี Serial จากเอกสารนี้ถูกจ่าย ขาย หรือติดตั้งแล้ว"});
                await using var retire=new SqlCommand("UPDATE I SET StatusCode=N'RETIRED',WarehouseID=NULL,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user FROM dbo.TDIVItemInstance I JOIN dbo.TDIVItemInstanceHistory H ON H.ItemInstanceID=I.ItemInstanceID WHERE H.CompanyID=@company AND H.DocumentType=N'STOCK_RECEIPT' AND H.DocumentDetailID=@detail AND I.StatusCode=N'IN_STOCK'; INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy) SELECT @company,I.ItemInstanceID,N'IN_STOCK',N'RETIRED',N'STOCK_RECEIPT',@id,@detail,N'ยกเลิกรับสินค้า',@user FROM dbo.TDIVItemInstance I JOIN dbo.TDIVItemInstanceHistory H ON H.ItemInstanceID=I.ItemInstanceID WHERE H.CompanyID=@company AND H.DocumentType=N'STOCK_RECEIPT' AND H.DocumentDetailID=@detail AND I.StatusCode=N'RETIRED' AND NOT EXISTS(SELECT 1 FROM dbo.TDIVItemInstanceHistory X WHERE X.CompanyID=@company AND X.ItemInstanceID=I.ItemInstanceID AND X.DocumentType=N'STOCK_RECEIPT_VOID' AND X.DocumentDetailID=@detail)",c,tx);Add(retire,"@company",SqlDbType.BigInt,CompanyId());Add(retire,"@detail",SqlDbType.BigInt,line.Detail);Add(retire,"@id",SqlDbType.BigInt,id);Add(retire,"@user",SqlDbType.BigInt,UserId());await retire.ExecuteNonQueryAsync(token);
            }
            await ItemWarrantyService.VoidBySourceAsync(c,tx,CompanyId(),UserId(),"STOCK_RECEIPT",id,"ยกเลิกใบรับสินค้า",token);
            await using var update=new SqlCommand("UPDATE dbo.TDIVStockReceipt SET StatusCode=N'VOID',VoidDate=SYSUTCDATETIME(),VoidedBy=@user,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE StockReceiptID=@id AND CompanyID=@company",c,tx);Add(update,"@user",SqlDbType.BigInt,UserId());Add(update,"@id",SqlDbType.BigInt,id);Add(update,"@company",SqlDbType.BigInt,CompanyId());await update.ExecuteNonQueryAsync(token);await tx.CommitAsync(token);return Ok(new{message="ยกเลิกรับสินค้าแล้ว"});
        }
        catch(Exception ex) when (ex is not ItemProjectDeniedException){try{await tx.RollbackAsync(token);}catch{}return BadRequest(new{message="ยกเลิกรับสินค้าไม่สำเร็จ",description=ex.Message});}
    }


    private async Task IncreaseBalance(SqlConnection c,SqlTransaction tx,long warehouse,long item,decimal qty,long document,long detail,string movement,CancellationToken token){await using var balance=new SqlCommand("UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK) SET Quantity=Quantity+@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND WarehouseID=@warehouse AND ItemID=@item; IF @@ROWCOUNT=0 INSERT dbo.TDIVStockBalance(CompanyID,WarehouseID,ItemID,Quantity) VALUES(@company,@warehouse,@item,@qty); UPDATE dbo.TDIVItem SET StockBalance=StockBalance+@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ItemID=@item; INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@warehouse,@item,N'STOCK_RECEIPT',@document,@detail,@movement,@qty,N'รับสินค้าเข้าคลัง',@user)",c,tx);BindMovement(balance,warehouse,item,qty,document,detail,token);Add(balance,"@movement",SqlDbType.NVarChar,movement,30);await balance.ExecuteNonQueryAsync(token);}
    private async Task DecreaseBalance(SqlConnection c,SqlTransaction tx,long warehouse,long item,decimal qty,long document,long detail,CancellationToken token){await using var balance=new SqlCommand("UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK) SET Quantity=Quantity-@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND WarehouseID=@warehouse AND ItemID=@item AND Quantity>=@qty; IF @@ROWCOUNT=0 THROW 52310,N'ยอดคงเหลือในคลังไม่เพียงพอสำหรับการย้อนรายการ',1; UPDATE dbo.TDIVItem SET StockBalance=StockBalance-@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ItemID=@item AND StockBalance>=@qty; INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@warehouse,@item,N'STOCK_RECEIPT',@document,@detail,N'REVERSAL',-@qty,N'ยกเลิกรับสินค้า',@user)",c,tx);BindMovement(balance,warehouse,item,qty,document,detail,token);await balance.ExecuteNonQueryAsync(token);}
    private void BindMovement(SqlCommand c,long warehouse,long item,decimal qty,long document,long detail,CancellationToken _){Add(c,"@company",SqlDbType.BigInt,CompanyId());Add(c,"@warehouse",SqlDbType.BigInt,warehouse);Add(c,"@item",SqlDbType.BigInt,item);Add(c,"@qty",SqlDbType.Decimal,qty);Add(c,"@document",SqlDbType.BigInt,document);Add(c,"@detail",SqlDbType.BigInt,detail);Add(c,"@user",SqlDbType.BigInt,UserId());}
    private async Task CreateInstance(SqlConnection c,SqlTransaction tx,long warehouse,long item,string serial,long document,long detail,DateOnly receiptDate,CancellationToken token){await using var command=new SqlCommand("INSERT dbo.TDIVItemInstance(CompanyID,ItemID,SerialNo,StatusCode,WarehouseID,CreatedBy) OUTPUT INSERTED.ItemInstanceID VALUES(@company,@item,@serial,N'IN_STOCK',@warehouse,@user)",c,tx);Add(command,"@company",SqlDbType.BigInt,CompanyId());Add(command,"@item",SqlDbType.BigInt,item);Add(command,"@serial",SqlDbType.NVarChar,serial,200);Add(command,"@warehouse",SqlDbType.BigInt,warehouse);Add(command,"@user",SqlDbType.BigInt,UserId());var instance=Convert.ToInt64(await command.ExecuteScalarAsync(token));await ItemWarrantyService.CreateSnapshotAsync(c,tx,CompanyId(),UserId(),item,instance,"SUPPLIER","RECEIPT",receiptDate,"STOCK_RECEIPT",document,detail,token);await using var history=new SqlCommand("INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,ToStatusCode,WarehouseID,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy) VALUES(@company,@instance,N'IN_STOCK',@warehouse,N'STOCK_RECEIPT',@document,@detail,N'รับ Serial เข้าคลัง',@user)",c,tx);Add(history,"@company",SqlDbType.BigInt,CompanyId());Add(history,"@instance",SqlDbType.BigInt,instance);Add(history,"@warehouse",SqlDbType.BigInt,warehouse);Add(history,"@document",SqlDbType.BigInt,document);Add(history,"@detail",SqlDbType.BigInt,detail);Add(history,"@user",SqlDbType.BigInt,UserId());await history.ExecuteNonQueryAsync(token);}
    private async Task<List<string>> SerialNumbers(SqlConnection c,SqlTransaction tx,long detail,CancellationToken token){await using var command=new SqlCommand("SELECT SerialNo FROM dbo.TDIVStockReceiptSerial WHERE StockReceiptDetailID=@detail ORDER BY StockReceiptSerialID",c,tx);Add(command,"@detail",SqlDbType.BigInt,detail);var values=new List<string>();await using var reader=await command.ExecuteReaderAsync(token);while(await reader.ReadAsync(token))values.Add(reader.GetString(0));return values;}
    private async Task<string?> ReadImageBase64Async(string? relativePath,byte[]? legacyBytes,CancellationToken token)
    {
        if(!string.IsNullOrWhiteSpace(relativePath))
        {
            var root=environment.WebRootPath;
            if(string.IsNullOrWhiteSpace(root))root=Path.Combine(environment.ContentRootPath,"wwwroot");
            var fullPath=Path.GetFullPath(Path.Combine(root,relativePath.Replace('/',Path.DirectorySeparatorChar)));
            var rootPath=Path.GetFullPath(root)+Path.DirectorySeparatorChar;
            if(fullPath.StartsWith(rootPath,StringComparison.OrdinalIgnoreCase)&&System.IO.File.Exists(fullPath))return Convert.ToBase64String(await System.IO.File.ReadAllBytesAsync(fullPath,token));
        }
        return legacyBytes is null?null:Convert.ToBase64String(legacyBytes);
    }
    private async Task<string?> ItemTracking(SqlConnection c,SqlTransaction tx,long id,CancellationToken token){await ItemProjectAccess.EnsureAsync(c,tx,CompanyId(),id,token);await using var command=new SqlCommand("SELECT StockTrackingCode FROM dbo.TDIVItem WHERE ItemID=@id AND CompanyID=@company AND IsActive=1 AND ItemKindCode=N'GOODS' AND StockTrackingCode<>N'NONE'",c,tx);Add(command,"@id",SqlDbType.BigInt,id);Add(command,"@company",SqlDbType.BigInt,CompanyId());return Convert.ToString(await command.ExecuteScalarAsync(token));}
    private async Task<long?> ScalarLong(SqlConnection c,SqlTransaction tx,string sql,long id,CancellationToken token){await using var command=new SqlCommand(sql,c,tx);Add(command,"@id",SqlDbType.BigInt,id);Add(command,"@company",SqlDbType.BigInt,CompanyId());var value=await command.ExecuteScalarAsync(token);return value is null or DBNull?null:Convert.ToInt64(value);}
    private async Task<string> NextCode(SqlConnection c,SqlTransaction tx,CancellationToken token){await using var command=new SqlCommand("SELECT ISNULL(MAX(TRY_CONVERT(int,RIGHT(ReceiptCode,6))),0)+1 FROM dbo.TDIVStockReceipt WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND ReceiptCode LIKE N'SR%'",c,tx);Add(command,"@company",SqlDbType.BigInt,CompanyId());return $"SR{Convert.ToInt32(await command.ExecuteScalarAsync(token)):D6}";}
    private void BindHeader(SqlCommand c,StockReceiptUpsertRequest r,string type){Add(c,"@company",SqlDbType.BigInt,CompanyId());Add(c,"@warehouse",SqlDbType.BigInt,r.WarehouseID);Add(c,"@date",SqlDbType.Date,r.ReceiptDate.ToDateTime(TimeOnly.MinValue));Add(c,"@type",SqlDbType.NVarChar,type,20);Add(c,"@reference",SqlDbType.NVarChar,r.ReferenceNo?.Trim(),100);Add(c,"@remark",SqlDbType.NVarChar,r.Remark?.Trim(),1000);Add(c,"@user",SqlDbType.BigInt,UserId());}
    private async Task<List<object>> Rows<T>(SqlConnection c,string sql,CancellationToken token,Func<SqlDataReader,T> map) where T:class{await using var command=new SqlCommand(sql,c);Add(command,"@company",SqlDbType.BigInt,CompanyId());Add(command,"@user",SqlDbType.BigInt,UserId());var rows=new List<object>();await using var reader=await command.ExecuteReaderAsync(token);while(await reader.ReadAsync(token))rows.Add(map(reader));return rows;}
    private static async Task<List<object>> RowsById<T>(SqlConnection c,string sql,long id,CancellationToken token,Func<SqlDataReader,T> map) where T:class{await using var command=new SqlCommand(sql,c);Add(command,"@id",SqlDbType.BigInt,id);var rows=new List<object>();await using var reader=await command.ExecuteReaderAsync(token);while(await reader.ReadAsync(token))rows.Add(map(reader));return rows;}
    private Task<bool> Can(SqlConnection c,string action,CancellationToken t)=>InventoryControllerSupport.CanAsync(c,User,ScreenCode,action,t);private Task<SqlConnection> Open(CancellationToken t)=>InventoryControllerSupport.OpenAsync(configuration,t);private long CompanyId()=>InventoryControllerSupport.ClaimId(User,"company_id");private long UserId()=>InventoryControllerSupport.ClaimId(User,"user_id");private static void Add(SqlCommand c,string n,SqlDbType t,object? v,int s=0)=>InventoryControllerSupport.Add(c,n,t,v,s);private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i);
}
