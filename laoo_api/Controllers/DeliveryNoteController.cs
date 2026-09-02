using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, LaooApi.Security.RequireCompanyFeature("SALES")]
[Route("api/company/delivery-notes")]
public sealed class DeliveryNoteController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "09006";
    private readonly IConfiguration _configuration = configuration;

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        return Ok(new { view = await Can(c, "VIEW", token), create = await Can(c, "CREATE", token), edit = await Can(c, "EDIT", token), delete = await Can(c, "DELETE", token) });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? status, [FromQuery] string? referenceType, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "VIEW", token)) return Forbid();
        const string sql = """
        SELECT D.DeliveryNoteID,D.DeliveryCode,D.DeliveryDate,D.CusCode,D.CusName,D.TotalAmount,D.StatusCode,D.ReferenceType,
               COALESCE(Q.QuoteCode,P.PreOrderCode,R.ReceiptCode,PD.DeliveryCode,N'') ReferenceCode
        FROM dbo.TDARDeliveryNote D
        LEFT JOIN dbo.TDARQuotation Q ON Q.QuotationID=D.QuotationID
        LEFT JOIN dbo.TDARPreOrder P ON P.PreOrderID=D.PreOrderID
        LEFT JOIN dbo.TDARTemporaryReceipt R ON R.TemporaryReceiptID=D.TemporaryReceiptID
        LEFT JOIN dbo.TDARDeliveryNote PD ON PD.DeliveryNoteID=D.ParentDeliveryNoteID
        WHERE D.CompanyID=@company AND D.IsActive=1
          AND (@search IS NULL OR D.DeliveryCode LIKE N'%'+@search+N'%' OR D.CusCode LIKE N'%'+@search+N'%' OR D.CusName LIKE N'%'+@search+N'%')
          AND (@status IS NULL OR D.StatusCode=@status)
          AND (@reference IS NULL OR D.ReferenceType=@reference)
        ORDER BY D.DeliveryDate DESC,D.DeliveryNoteID DESC;
        """;
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); Add(cmd, "@search", SqlDbType.NVarChar, Filter(search), 200); Add(cmd, "@status", SqlDbType.NVarChar, Filter(status), 30); Add(cmd, "@reference", SqlDbType.NVarChar, Filter(referenceType), 30);
        var rows = new List<object>(); await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) rows.Add(new { deliveryNoteId = r.GetInt64(0), deliveryCode = r.GetString(1), deliveryDate = r.GetDateTime(2), customerCode = r.GetString(3), customerName = r.GetString(4), totalAmount = r.GetDecimal(5), statusCode = r.GetString(6), referenceType = r.GetString(7), referenceCode = Text(r, 8) });
        return Ok(rows);
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken token)
    {
        await using var c = await Open(token); if (!await Can(c, "VIEW", token)) return Forbid();
        return Ok(new
        {
            customers = await Rows(c, "SELECT CustomerID,CusCode,CusName,CusAddress,TaxID,ContName1,Phone1,Email1,ContName2,Phone2,Email2 FROM dbo.TDARCustomer WHERE CompanyID=@company AND IsActive=1 ORDER BY CusCode", token, r => new { customerId = r.GetInt64(0), customerCode = r.GetString(1), customerName = r.GetString(2), address = Text(r, 3), taxId = Text(r, 4), contactName1 = Text(r, 5), phone1 = Text(r, 6), email1 = Text(r, 7), contactName2 = Text(r, 8), phone2 = Text(r, 9), email2 = Text(r, 10) }),
            items = await Rows(c, """
              SELECT I.ItemID,I.ItemCode,I.ItemName,I.UnitCode,I.UnitPrice,I.StockBalance,COALESCE(M.Name,I.UnitCode)
              FROM dbo.TDIVItem I LEFT JOIN dbo.TDSTMaster M ON M.OwnerType=N'C' AND M.OwnerCompanyID=I.CompanyID AND M.MasterGroupCode=@unitGroup AND M.MasterCode=I.UnitCode AND M.IsActive=1
              WHERE I.CompanyID=@company AND I.IsActive=1 ORDER BY I.ItemCode
            """, token, r => new { itemId = r.GetInt64(0), itemCode = r.GetString(1), itemName = r.GetString(2), unitCode = Text(r, 3), unitPrice = r.GetDecimal(4), stockBalance = r.GetDecimal(5), unitName = Text(r, 6) }, unitGroup: MasterConstCodes.cmsUnit),
            quotations = await Rows(c, "SELECT QuotationID,QuoteCode,QuoteDate,CustomerID,CusCode,CusName,COALESCE(NetAmount,0) FROM dbo.TDARQuotation WHERE CompanyID=@company AND IsActive=1 AND StatusCode<>N'CANCELLED' ORDER BY QuoteDate DESC", token, r => new { id = r.GetInt64(0), code = r.GetString(1), date = r.GetDateTime(2), customerId = r.GetInt64(3), customerCode = r.GetString(4), customerName = r.GetString(5), amount = r.GetDecimal(6) }),
            preOrders = await Rows(c, "SELECT PreOrderID,PreOrderCode,PreOrderDate,CustomerID,CusCode,CusName,TotalAmount FROM dbo.TDARPreOrder WHERE CompanyID=@company AND IsActive=1 AND StatusCode<>N'CANCELLED' ORDER BY PreOrderDate DESC", token, r => new { id = r.GetInt64(0), code = r.GetString(1), date = r.GetDateTime(2), customerId = r.GetInt64(3), customerCode = r.GetString(4), customerName = r.GetString(5), amount = r.GetDecimal(6) }),
            receipts = await Rows(c, "SELECT TemporaryReceiptID,ReceiptCode,ReceiptDate,CustomerID,CusCode,CusName,ReceivedAmount FROM dbo.TDARTemporaryReceipt WHERE CompanyID=@company AND IsActive=1 AND StatusCode<>N'VOID' ORDER BY ReceiptDate DESC", token, r => new { id = r.GetInt64(0), code = r.GetString(1), date = r.GetDateTime(2), customerId = r.GetInt64(3), customerCode = r.GetString(4), customerName = r.GetString(5), amount = r.GetDecimal(6) }),
            deliveryNotes = await Rows(c, "SELECT DeliveryNoteID,DeliveryCode,DeliveryDate,CustomerID,CusCode,CusName,TotalAmount FROM dbo.TDARDeliveryNote WHERE CompanyID=@company AND IsActive=1 AND StatusCode=N'CONFIRMED' ORDER BY DeliveryDate DESC", token, r => new { id = r.GetInt64(0), code = r.GetString(1), date = r.GetDateTime(2), customerId = r.GetInt64(3), customerCode = r.GetString(4), customerName = r.GetString(5), amount = r.GetDecimal(6) })
        });
    }

    [HttpGet("source/{type}/{id:long}")]
    public async Task<IActionResult> Source(string type, long id, CancellationToken token)
    {
        await using var c = await Open(token); if (!await Can(c, "VIEW", token)) return Forbid();
        var source = type.Trim().ToUpperInvariant();
        var result = source switch
        {
            "QUOTATION" => await ReadQuotationSource(c, id, token),
            "PREORDER" => await ReadPreOrderSource(c, id, token),
            "TEMP_RECEIPT" => await ReadReceiptSource(c, id, token),
            "DELIVERY_NOTE" => await ReadDeliverySource(c, id, token),
            _ => null
        };
        return result is null ? NotFound(new { message = "ไม่พบเอกสารอ้างอิง", description = "เอกสารอาจถูกลบหรือไม่อยู่ในบริษัทนี้" }) : Ok(result);
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token)
    {
        await using var c = await Open(token); if (!await Can(c, "VIEW", token)) return Forbid();
        const string h = "SELECT DeliveryNoteID,DeliveryCode,DeliveryDate,ReferenceType,COALESCE(QuotationID,PreOrderID,TemporaryReceiptID,ParentDeliveryNoteID),CustomerID,CusCode,CusName,CusAddress,TaxID,ContactName,ContactPhone,DeliveryAddress,TransportBy,TrackingNo,TotalAmount,StatusCode,Remark FROM dbo.TDARDeliveryNote WHERE DeliveryNoteID=@id AND CompanyID=@company AND IsActive=1";
        object? header = null; await using (var cmd = new SqlCommand(h, c)) { Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(token); if (await r.ReadAsync(token)) header = new { deliveryNoteId = r.GetInt64(0), deliveryCode = r.GetString(1), deliveryDate = r.GetDateTime(2), referenceType = r.GetString(3), referenceId = Long(r, 4), customerId = r.GetInt64(5), customerCode = r.GetString(6), customerName = r.GetString(7), customerAddress = Text(r, 8), taxId = Text(r, 9), contactName = Text(r, 10), contactPhone = Text(r, 11), deliveryAddress = Text(r, 12), transportBy = Text(r, 13), trackingNo = Text(r, 14), totalAmount = r.GetDecimal(15), statusCode = r.GetString(16), remark = Text(r, 17) }; }
        if (header is null) return NotFound(new { message = "ไม่พบใบส่งของ", description = "เอกสารอาจถูกลบหรือไม่อยู่ในบริษัทนี้" });
        var items = await RowsById(c, "SELECT DeliveryNoteDetailID,[LineNo],QuotationDetailID,PreOrderDetailID,ParentDeliveryNoteDetailID,ItemID,ItemCode,ItemName,UnitCode,OrderedQty,PreviouslyDeliveredQty,DeliveryQty,UnitPrice,Amount,Remark FROM dbo.TDARDeliveryNoteDetail WHERE DeliveryNoteID=@id ORDER BY [LineNo]", id, token, r => new { deliveryNoteDetailId = r.GetInt64(0), lineNo = r.GetInt32(1), quotationDetailId = Long(r, 2), preOrderDetailId = Long(r, 3), parentDeliveryNoteDetailId = Long(r, 4), itemId = r.GetInt64(5), itemCode = r.GetString(6), itemName = r.GetString(7), unitCode = r.GetString(8), orderedQty = r.GetDecimal(9), previouslyDeliveredQty = r.GetDecimal(10), deliveryQty = r.GetDecimal(11), unitPrice = r.GetDecimal(12), amount = r.GetDecimal(13), remark = Text(r, 14) });
        return Ok(new { header, items });
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] DeliveryNoteUpsertRequest request, CancellationToken token) => await Save(null, request, token);
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromBody] DeliveryNoteUpsertRequest request, CancellationToken token) => await Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        await using var c = await Open(token); if (!await Can(c, "DELETE", token)) return Forbid();
        await using var cmd = new SqlCommand("DELETE dbo.TDARDeliveryNote WHERE DeliveryNoteID=@id AND CompanyID=@company AND StatusCode=N'DRAFT'", c); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
        return await cmd.ExecuteNonQueryAsync(token) > 0 ? NoContent() : Conflict(new { message = "ลบใบส่งของไม่ได้", description = "ลบได้เฉพาะเอกสารสถานะร่าง เอกสารที่ยืนยันแล้วให้ใช้คำสั่งยกเลิก" });
    }

    [HttpPost("{id:long}/confirm")]
    public async Task<IActionResult> Confirm(long id, CancellationToken token)
    {
        await using var c = await Open(token); if (!await Can(c, "EDIT", token)) return Forbid(); await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var status = await ScalarString(c, tx, "SELECT StatusCode FROM dbo.TDARDeliveryNote WITH(UPDLOCK,HOLDLOCK) WHERE DeliveryNoteID=@id AND CompanyID=@company AND IsActive=1", id, token);
            if (status is null) { await tx.RollbackAsync(token); return NotFound(); }
            if (status != "DRAFT") { await tx.RollbackAsync(token); return Conflict(new { message = "ยืนยันใบส่งของไม่ได้", description = "ยืนยันได้เฉพาะเอกสารสถานะร่าง" }); }
            const string q = "SELECT DeliveryNoteDetailID,ItemID,DeliveryQty,PreOrderDetailID,QuotationDetailID,ParentDeliveryNoteDetailID FROM dbo.TDARDeliveryNoteDetail WHERE DeliveryNoteID=@id ORDER BY [LineNo]";
            var lines = new List<(long Detail, long Item, decimal Qty, long? Pre, long? Quote, long? Parent)>(); await using (var cmd = new SqlCommand(q, c, tx)) { Add(cmd, "@id", SqlDbType.BigInt, id); await using var r = await cmd.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) lines.Add((r.GetInt64(0), r.GetInt64(1), r.GetDecimal(2), Long(r, 3), Long(r, 4), Long(r, 5))); }
            if (lines.Count == 0) { await tx.RollbackAsync(token); return BadRequest(new { message = "ยืนยันใบส่งของไม่ได้", description = "กรุณาเพิ่มสินค้าอย่างน้อย 1 รายการ" }); }
            foreach (var line in lines)
            {
                await using var stock = new SqlCommand("UPDATE dbo.TDIVItem WITH(UPDLOCK,HOLDLOCK) SET StockBalance=StockBalance-@qty,UpdateDate=SYSUTCDATETIME() WHERE ItemID=@item AND CompanyID=@company AND StockBalance>=@qty", c, tx); Add(stock, "@qty", SqlDbType.Decimal, line.Qty); Add(stock, "@item", SqlDbType.BigInt, line.Item); Add(stock, "@company", SqlDbType.BigInt, CompanyId());
                if (await stock.ExecuteNonQueryAsync(token) == 0) { await tx.RollbackAsync(token); return Conflict(new { message = "สต๊อกสินค้าไม่เพียงพอ", description = $"สินค้า ItemID {line.Item} มีจำนวนคงเหลือน้อยกว่าจำนวนที่ต้องการส่ง" }); }
                await using var movement = new SqlCommand("INSERT dbo.TDIVStockMovement(CompanyID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@item,N'DELIVERY_NOTE',@id,@detail,N'OUT',-@qty,N'ยืนยันใบส่งของ',@user)", c, tx); Add(movement, "@company", SqlDbType.BigInt, CompanyId()); Add(movement, "@item", SqlDbType.BigInt, line.Item); Add(movement, "@id", SqlDbType.BigInt, id); Add(movement, "@detail", SqlDbType.BigInt, line.Detail); Add(movement, "@qty", SqlDbType.Decimal, line.Qty); Add(movement, "@user", SqlDbType.BigInt, UserId()); await movement.ExecuteNonQueryAsync(token);
                if (line.Pre.HasValue) { await using var pre = new SqlCommand("UPDATE dbo.TDARPreOrderDetail SET DeliveredQty=DeliveredQty+@qty WHERE PreOrderDetailID=@pre AND DeliveredQty+@qty<=AllocatedQty", c, tx); Add(pre, "@qty", SqlDbType.Decimal, line.Qty); Add(pre, "@pre", SqlDbType.BigInt, line.Pre.Value); if (await pre.ExecuteNonQueryAsync(token) == 0) { await tx.RollbackAsync(token); return Conflict(new { message = "จำนวนส่งเกินใบจอง", description = "จำนวนส่งสะสมต้องไม่เกินจำนวนที่จัดสรรในใบจอง" }); } }
                if (line.Quote.HasValue && !await WithinSourceQuantity(c, tx, "QUOTATION", line.Quote.Value, line.Detail, line.Qty, token)) { await tx.RollbackAsync(token); return Conflict(new { message = "จำนวนส่งเกินใบเสนอราคา", description = "จำนวนส่งสะสมต้องไม่เกินจำนวนในใบเสนอราคา" }); }
                if (line.Parent.HasValue && !await WithinSourceQuantity(c, tx, "DELIVERY_NOTE", line.Parent.Value, line.Detail, line.Qty, token)) { await tx.RollbackAsync(token); return Conflict(new { message = "จำนวนส่งเกินใบส่งของอ้างอิง", description = "จำนวนส่งสะสมต้องไม่เกินจำนวนในใบส่งของเดิม" }); }
            }
            await using (var done = new SqlCommand("UPDATE dbo.TDARDeliveryNote SET StatusCode=N'CONFIRMED',ConfirmDate=SYSUTCDATETIME(),ConfirmedBy=@user,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE DeliveryNoteID=@id", c, tx)) { Add(done, "@user", SqlDbType.BigInt, UserId()); Add(done, "@id", SqlDbType.BigInt, id); await done.ExecuteNonQueryAsync(token); }
            await tx.CommitAsync(token); return Ok(new { message = "ยืนยันใบส่งของสำเร็จ" });
        }
        catch (Exception ex) { await tx.RollbackAsync(token); return StatusCode(500, new { message = "ยืนยันใบส่งของไม่สำเร็จ", description = ex.Message }); }
    }

    [HttpPost("{id:long}/void")]
    public async Task<IActionResult> Void(long id, CancellationToken token)
    {
        await using var c = await Open(token); if (!await Can(c, "EDIT", token)) return Forbid(); await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var status = await ScalarString(c, tx, "SELECT StatusCode FROM dbo.TDARDeliveryNote WITH(UPDLOCK,HOLDLOCK) WHERE DeliveryNoteID=@id AND CompanyID=@company AND IsActive=1", id, token); if (status != "CONFIRMED") { await tx.RollbackAsync(token); return Conflict(new { message = "ยกเลิกใบส่งของไม่ได้", description = "ยกเลิกได้เฉพาะเอกสารที่ยืนยันแล้ว" }); }
            const string q = "SELECT D.DeliveryNoteDetailID,D.ItemID,D.DeliveryQty,D.PreOrderDetailID FROM dbo.TDARDeliveryNoteDetail D WHERE D.DeliveryNoteID=@id"; var lines = new List<(long Detail, long Item, decimal Qty, long? Pre)>(); await using (var cmd = new SqlCommand(q, c, tx)) { Add(cmd, "@id", SqlDbType.BigInt, id); await using var r = await cmd.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) lines.Add((r.GetInt64(0), r.GetInt64(1), r.GetDecimal(2), Long(r, 3))); }
            foreach (var line in lines)
            {
                await using (var stock = new SqlCommand("UPDATE dbo.TDIVItem SET StockBalance=StockBalance+@qty,UpdateDate=SYSUTCDATETIME() WHERE ItemID=@item AND CompanyID=@company", c, tx)) { Add(stock, "@qty", SqlDbType.Decimal, line.Qty); Add(stock, "@item", SqlDbType.BigInt, line.Item); Add(stock, "@company", SqlDbType.BigInt, CompanyId()); await stock.ExecuteNonQueryAsync(token); }
                await using (var movement = new SqlCommand("INSERT dbo.TDIVStockMovement(CompanyID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@item,N'DELIVERY_NOTE',@id,@detail,N'REVERSAL',@qty,N'ยกเลิกใบส่งของ',@user)", c, tx)) { Add(movement, "@company", SqlDbType.BigInt, CompanyId()); Add(movement, "@item", SqlDbType.BigInt, line.Item); Add(movement, "@id", SqlDbType.BigInt, id); Add(movement, "@detail", SqlDbType.BigInt, line.Detail); Add(movement, "@qty", SqlDbType.Decimal, line.Qty); Add(movement, "@user", SqlDbType.BigInt, UserId()); await movement.ExecuteNonQueryAsync(token); }
                if (line.Pre.HasValue) { await using var pre = new SqlCommand("UPDATE dbo.TDARPreOrderDetail SET DeliveredQty=CASE WHEN DeliveredQty>=@qty THEN DeliveredQty-@qty ELSE 0 END WHERE PreOrderDetailID=@pre", c, tx); Add(pre, "@qty", SqlDbType.Decimal, line.Qty); Add(pre, "@pre", SqlDbType.BigInt, line.Pre.Value); await pre.ExecuteNonQueryAsync(token); }
            }
            await using (var done = new SqlCommand("UPDATE dbo.TDARDeliveryNote SET StatusCode=N'VOID',VoidDate=SYSUTCDATETIME(),VoidedBy=@user,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE DeliveryNoteID=@id", c, tx)) { Add(done, "@user", SqlDbType.BigInt, UserId()); Add(done, "@id", SqlDbType.BigInt, id); await done.ExecuteNonQueryAsync(token); }
            await tx.CommitAsync(token); return Ok(new { message = "ยกเลิกใบส่งของและคืนสต๊อกสำเร็จ" });
        }
        catch (Exception ex) { await tx.RollbackAsync(token); return StatusCode(500, new { message = "ยกเลิกใบส่งของไม่สำเร็จ", description = ex.Message }); }
    }

    private async Task<IActionResult> Save(long? id, DeliveryNoteUpsertRequest request, CancellationToken token)
    {
        await using var c = await Open(token); if (!await Can(c, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        if (request.CustomerId <= 0 || request.Items.Count == 0) return BadRequest(new { message = "ข้อมูลไม่ครบ", description = "กรุณาเลือกลูกค้าและเพิ่มสินค้าอย่างน้อย 1 รายการ" });
        if (request.Items.Any(x => x.ItemId <= 0 || x.DeliveryQty <= 0 || x.UnitPrice < 0)) return BadRequest(new { message = "รายการสินค้าไม่ถูกต้อง", description = "สินค้า จำนวนส่ง และราคาต้องถูกต้อง" });
        var type = NormalizeReference(request.ReferenceType); if (type is null) return BadRequest(new { message = "ประเภทเอกสารอ้างอิงไม่ถูกต้อง", description = "รองรับ NONE, QUOTATION, PREORDER, TEMP_RECEIPT และ DELIVERY_NOTE" });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var customer = await Customer(c, tx, request.CustomerId, token); if (customer is null) { await tx.RollbackAsync(token); return BadRequest(new { message = "ไม่พบลูกค้า", description = "ลูกค้าอาจถูกลบหรือไม่อยู่ในบริษัทนี้" }); }
            var referenceError = await ValidateReference(c, tx, type, request.ReferenceId, request.CustomerId, token); if (referenceError is not null) { await tx.RollbackAsync(token); return BadRequest(new { message = "เอกสารอ้างอิงไม่ถูกต้อง", description = referenceError }); }
            long deliveryId; string code;
            if (id.HasValue)
            {
                var current = await ScalarString(c, tx, "SELECT StatusCode FROM dbo.TDARDeliveryNote WITH(UPDLOCK,HOLDLOCK) WHERE DeliveryNoteID=@id AND CompanyID=@company AND IsActive=1", id.Value, token); if (current is null) { await tx.RollbackAsync(token); return NotFound(); }
                if (current != "DRAFT") { await tx.RollbackAsync(token); return Conflict(new { message = "แก้ไขใบส่งของไม่ได้", description = "แก้ไขได้เฉพาะเอกสารสถานะร่าง" }); }
                deliveryId = id.Value; code = await ScalarString(c, tx, "SELECT DeliveryCode FROM dbo.TDARDeliveryNote WHERE DeliveryNoteID=@id AND CompanyID=@company", id.Value, token) ?? "";
                await using var update = new SqlCommand("""
                 UPDATE dbo.TDARDeliveryNote SET DeliveryDate=@date,ReferenceType=@type,QuotationID=@quotation,PreOrderID=@preorder,TemporaryReceiptID=@receipt,ParentDeliveryNoteID=@parent,CustomerID=@customer,CusCode=@cusCode,CusName=@cusName,CusAddress=@address,TaxID=@tax,ContactName=@contact,ContactPhone=@phone,DeliveryAddress=@deliveryAddress,TransportBy=@transport,TrackingNo=@tracking,TotalAmount=@total,Remark=@remark,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE DeliveryNoteID=@id AND CompanyID=@company;
                 DELETE dbo.TDARDeliveryNoteDetail WHERE DeliveryNoteID=@id;
                """, c, tx); BindHeader(update, request, type, customer, deliveryId); await update.ExecuteNonQueryAsync(token);
            }
            else
            {
                code = await NextCode(c, tx, token); await using var insert = new SqlCommand("""
                 INSERT dbo.TDARDeliveryNote(CompanyID,DeliveryCode,DeliveryDate,ReferenceType,QuotationID,PreOrderID,TemporaryReceiptID,ParentDeliveryNoteID,CustomerID,CusCode,CusName,CusAddress,TaxID,ContactName,ContactPhone,DeliveryAddress,TransportBy,TrackingNo,TotalAmount,StatusCode,Remark,IsActive,CreatedBy)
                 OUTPUT INSERTED.DeliveryNoteID VALUES(@company,@code,@date,@type,@quotation,@preorder,@receipt,@parent,@customer,@cusCode,@cusName,@address,@tax,@contact,@phone,@deliveryAddress,@transport,@tracking,@total,N'DRAFT',@remark,1,@user)
                """, c, tx); BindHeader(insert, request, type, customer, null); Add(insert, "@code", SqlDbType.NVarChar, code, 30); deliveryId = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            }
            var lineNo = 0; foreach (var line in request.Items) { lineNo++; var item = await Item(c, tx, line.ItemId, token); if (item is null) { await tx.RollbackAsync(token); return BadRequest(new { message = "ไม่พบสินค้า", description = $"ItemID {line.ItemId} ไม่อยู่ในบริษัทนี้" }); } var amount = Math.Round(line.DeliveryQty * line.UnitPrice, 4); await using var detail = new SqlCommand("INSERT dbo.TDARDeliveryNoteDetail(DeliveryNoteID,[LineNo],QuotationDetailID,PreOrderDetailID,ParentDeliveryNoteDetailID,ItemID,ItemCode,ItemName,UnitCode,OrderedQty,PreviouslyDeliveredQty,DeliveryQty,UnitPrice,Amount,Remark) VALUES(@id,@line,@quotationDetail,@preDetail,@parentDetail,@item,@itemCode,@itemName,@unit,@ordered,@previous,@qty,@price,@amount,@remark)", c, tx); Add(detail, "@id", SqlDbType.BigInt, deliveryId); Add(detail, "@line", SqlDbType.Int, lineNo); Add(detail, "@quotationDetail", SqlDbType.BigInt, line.QuotationDetailId); Add(detail, "@preDetail", SqlDbType.BigInt, line.PreOrderDetailId); Add(detail, "@parentDetail", SqlDbType.BigInt, line.ParentDeliveryNoteDetailId); Add(detail, "@item", SqlDbType.BigInt, line.ItemId); Add(detail, "@itemCode", SqlDbType.NVarChar, item.Value.Code, 50); Add(detail, "@itemName", SqlDbType.NVarChar, item.Value.Name, 200); Add(detail, "@unit", SqlDbType.NVarChar, item.Value.Unit, 50); Add(detail, "@ordered", SqlDbType.Decimal, line.OrderedQty); Add(detail, "@previous", SqlDbType.Decimal, line.PreviouslyDeliveredQty); Add(detail, "@qty", SqlDbType.Decimal, line.DeliveryQty); Add(detail, "@price", SqlDbType.Decimal, line.UnitPrice); Add(detail, "@amount", SqlDbType.Decimal, amount); Add(detail, "@remark", SqlDbType.NVarChar, Filter(line.Remark), 500); await detail.ExecuteNonQueryAsync(token); }
            await using (var clear = new SqlCommand("DELETE dbo.TDARDocumentLink WHERE CompanyID=@company AND FromDocumentType=N'DELIVERY_NOTE' AND FromDocumentID=@id", c, tx)) { Add(clear, "@company", SqlDbType.BigInt, CompanyId()); Add(clear, "@id", SqlDbType.BigInt, deliveryId); await clear.ExecuteNonQueryAsync(token); }
            if (type != "NONE" && request.ReferenceId.HasValue) { await using var link = new SqlCommand("INSERT dbo.TDARDocumentLink(CompanyID,FromDocumentType,FromDocumentID,ToDocumentType,ToDocumentID,LinkType,LinkDescription,CreatedBy) VALUES(@company,N'DELIVERY_NOTE',@id,@type,@target,N'REFERENCE',N'เอกสารอ้างอิงใบส่งของ',@user)", c, tx); Add(link, "@company", SqlDbType.BigInt, CompanyId()); Add(link, "@id", SqlDbType.BigInt, deliveryId); Add(link, "@type", SqlDbType.NVarChar, type, 30); Add(link, "@target", SqlDbType.BigInt, request.ReferenceId); Add(link, "@user", SqlDbType.BigInt, UserId()); await link.ExecuteNonQueryAsync(token); }
            await tx.CommitAsync(token); return Ok(new { deliveryNoteId = deliveryId, deliveryCode = code, statusCode = "DRAFT" });
        }
        catch (Exception ex) { await tx.RollbackAsync(token); return StatusCode(500, new { message = "บันทึกใบส่งของไม่สำเร็จ", description = ex.Message }); }
    }

    private void BindHeader(SqlCommand cmd, DeliveryNoteUpsertRequest request, string type, CustomerRow customer, long? id) { Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); Add(cmd, "@date", SqlDbType.Date, request.DeliveryDate?.Date ?? DateTime.Today); Add(cmd, "@type", SqlDbType.NVarChar, type, 30); Add(cmd, "@quotation", SqlDbType.BigInt, type == "QUOTATION" ? request.ReferenceId : null); Add(cmd, "@preorder", SqlDbType.BigInt, type == "PREORDER" ? request.ReferenceId : null); Add(cmd, "@receipt", SqlDbType.BigInt, type == "TEMP_RECEIPT" ? request.ReferenceId : null); Add(cmd, "@parent", SqlDbType.BigInt, type == "DELIVERY_NOTE" ? request.ReferenceId : null); Add(cmd, "@customer", SqlDbType.BigInt, customer.Id); Add(cmd, "@cusCode", SqlDbType.NVarChar, customer.Code, 50); Add(cmd, "@cusName", SqlDbType.NVarChar, customer.Name, 200); Add(cmd, "@address", SqlDbType.NVarChar, customer.Address, 1000); Add(cmd, "@tax", SqlDbType.NVarChar, customer.TaxId, 30); Add(cmd, "@contact", SqlDbType.NVarChar, Filter(request.ContactName), 200); Add(cmd, "@phone", SqlDbType.NVarChar, Filter(request.ContactPhone), 100); Add(cmd, "@deliveryAddress", SqlDbType.NVarChar, Filter(request.DeliveryAddress) ?? customer.Address, 1000); Add(cmd, "@transport", SqlDbType.NVarChar, Filter(request.TransportBy), 200); Add(cmd, "@tracking", SqlDbType.NVarChar, Filter(request.TrackingNo), 100); Add(cmd, "@total", SqlDbType.Decimal, request.Items.Sum(x => Math.Round(x.DeliveryQty * x.UnitPrice, 4))); Add(cmd, "@remark", SqlDbType.NVarChar, Filter(request.Remark), 1000); Add(cmd, "@user", SqlDbType.BigInt, UserId()); if (id.HasValue) Add(cmd, "@id", SqlDbType.BigInt, id.Value); }
    private async Task<object?> ReadQuotationSource(SqlConnection c, long id, CancellationToken t) => await ReadSource(c, "QUOTATION", id, "SELECT Q.QuotationID,Q.CustomerID,Q.CusCode,Q.CusName,C.CusAddress,C.TaxID,Q.ContactName,COALESCE(NULLIF(C.Phone1,N''),C.Phone) FROM dbo.TDARQuotation Q LEFT JOIN dbo.TDARCustomer C ON C.CustomerID=Q.CustomerID AND C.CompanyID=Q.CompanyID WHERE Q.QuotationID=@id AND Q.CompanyID=@company AND Q.IsActive=1", "SELECT D.QuotationDetailID,D.ItemID,D.ItemCode,D.ItemName,D.UnitCode,D.Quantity,COALESCE((SELECT SUM(X.DeliveryQty) FROM dbo.TDARDeliveryNoteDetail X JOIN dbo.TDARDeliveryNote H ON H.DeliveryNoteID=X.DeliveryNoteID WHERE X.QuotationDetailID=D.QuotationDetailID AND H.StatusCode=N'CONFIRMED'),0),D.UnitPrice FROM dbo.TDARQuotationDetail D WHERE D.QuotationID=@id ORDER BY D.[LineNo]", id, t);
    private async Task<object?> ReadPreOrderSource(SqlConnection c, long id, CancellationToken t) => await ReadSource(c, "PREORDER", id, "SELECT P.PreOrderID,P.CustomerID,P.CusCode,P.CusName,C.CusAddress,C.TaxID,P.ContactName,P.ContactPhone FROM dbo.TDARPreOrder P LEFT JOIN dbo.TDARCustomer C ON C.CustomerID=P.CustomerID AND C.CompanyID=P.CompanyID WHERE P.PreOrderID=@id AND P.CompanyID=@company AND P.IsActive=1", "SELECT D.PreOrderDetailID,D.ItemID,D.ItemCode,D.ItemName,D.UnitCode,D.AllocatedQty,D.DeliveredQty,D.UnitPrice FROM dbo.TDARPreOrderDetail D WHERE D.PreOrderID=@id ORDER BY D.[LineNo]", id, t);
    private async Task<object?> ReadDeliverySource(SqlConnection c, long id, CancellationToken t) => await ReadSource(c, "DELIVERY_NOTE", id, "SELECT DeliveryNoteID,CustomerID,CusCode,CusName,CusAddress,TaxID,ContactName,ContactPhone FROM dbo.TDARDeliveryNote WHERE DeliveryNoteID=@id AND CompanyID=@company AND IsActive=1 AND StatusCode=N'CONFIRMED'", "SELECT D.DeliveryNoteDetailID,D.ItemID,D.ItemCode,D.ItemName,D.UnitCode,D.DeliveryQty,COALESCE((SELECT SUM(X.DeliveryQty) FROM dbo.TDARDeliveryNoteDetail X JOIN dbo.TDARDeliveryNote H ON H.DeliveryNoteID=X.DeliveryNoteID WHERE X.ParentDeliveryNoteDetailID=D.DeliveryNoteDetailID AND H.StatusCode=N'CONFIRMED'),0),D.UnitPrice FROM dbo.TDARDeliveryNoteDetail D WHERE D.DeliveryNoteID=@id ORDER BY D.[LineNo]", id, t);
    private async Task<object?> ReadReceiptSource(SqlConnection c, long id, CancellationToken t) { long? pre = null, quote = null; await using (var cmd = new SqlCommand("SELECT PreOrderID,QuotationID FROM dbo.TDARTemporaryReceipt WHERE TemporaryReceiptID=@id AND CompanyID=@company AND IsActive=1", c)) { Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(t); if (!await r.ReadAsync(t)) return null; pre = Long(r, 0); quote = Long(r, 1); } var value = pre.HasValue ? await ReadPreOrderSource(c, pre.Value, t) : quote.HasValue ? await ReadQuotationSource(c, quote.Value, t) : null; return value is null ? new { referenceType = "TEMP_RECEIPT", referenceId = id, items = Array.Empty<object>() } : value; }
    private async Task<object?> ReadSource(SqlConnection c, string type, long id, string headerSql, string detailSql, long sourceId, CancellationToken token) { CustomerRow? customer = null; await using (var cmd = new SqlCommand(headerSql, c)) { Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(token); if (!await r.ReadAsync(token)) return null; customer = new(r.GetInt64(1), r.GetString(2), r.GetString(3), Text(r, 4), Text(r, 5), Text(r, 6), Text(r, 7)); } var items = await RowsById(c, detailSql, id, token, r => new { sourceDetailId = r.GetInt64(0), itemId = r.GetInt64(1), itemCode = r.GetString(2), itemName = r.GetString(3), unitCode = r.GetString(4), orderedQty = r.GetDecimal(5), previouslyDeliveredQty = r.GetDecimal(6), deliveryQty = Math.Max(0, r.GetDecimal(5) - r.GetDecimal(6)), unitPrice = r.GetDecimal(7) }); return new { referenceType = type, referenceId = sourceId, customer = new { customerId = customer.Id, customerCode = customer.Code, customerName = customer.Name, address = customer.Address, taxId = customer.TaxId, contactName = customer.Contact, contactPhone = customer.Phone }, items }; }
    private async Task<CustomerRow?> Customer(SqlConnection c, SqlTransaction tx, long id, CancellationToken t) { await using var cmd = new SqlCommand("SELECT CustomerID,CusCode,CusName,CusAddress,TaxID,ContName1,Phone1 FROM dbo.TDARCustomer WHERE CustomerID=@id AND CompanyID=@company AND IsActive=1", c, tx); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(t); return await r.ReadAsync(t) ? new(r.GetInt64(0), r.GetString(1), r.GetString(2), Text(r, 3), Text(r, 4), Text(r, 5), Text(r, 6)) : null; }
    private async Task<(string Code, string Name, string Unit)?> Item(SqlConnection c, SqlTransaction tx, long id, CancellationToken t) { await using var cmd = new SqlCommand("SELECT ItemCode,ItemName,UnitCode FROM dbo.TDIVItem WHERE ItemID=@id AND CompanyID=@company AND IsActive=1", c, tx); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(t); return await r.ReadAsync(t) ? (r.GetString(0), r.GetString(1), Text(r, 2) ?? "") : null; }
    private async Task<string> NextCode(SqlConnection c, SqlTransaction tx, CancellationToken t) { await using var cmd = new SqlCommand("SELECT ISNULL(MAX(TRY_CONVERT(int,RIGHT(DeliveryCode,6))),0)+1 FROM dbo.TDARDeliveryNote WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND DeliveryCode LIKE N'DN%'", c, tx); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); return $"DN{Convert.ToInt32(await cmd.ExecuteScalarAsync(t)):D6}"; }
    private async Task<string?> ValidateReference(SqlConnection c, SqlTransaction tx, string type, long? id, long customerId, CancellationToken token)
    {
        if (type == "NONE") return id.HasValue ? "ประเภทไม่อ้างอิงเอกสารต้องไม่มี ReferenceId" : null;
        if (!id.HasValue) return "กรุณาเลือกเอกสารอ้างอิง";
        var sql = type switch
        {
            "QUOTATION" => "SELECT CustomerID FROM dbo.TDARQuotation WHERE QuotationID=@id AND CompanyID=@company AND IsActive=1",
            "PREORDER" => "SELECT CustomerID FROM dbo.TDARPreOrder WHERE PreOrderID=@id AND CompanyID=@company AND IsActive=1",
            "TEMP_RECEIPT" => "SELECT CustomerID FROM dbo.TDARTemporaryReceipt WHERE TemporaryReceiptID=@id AND CompanyID=@company AND IsActive=1",
            "DELIVERY_NOTE" => "SELECT CustomerID FROM dbo.TDARDeliveryNote WHERE DeliveryNoteID=@id AND CompanyID=@company AND IsActive=1 AND StatusCode=N'CONFIRMED'",
            _ => null
        };
        if (sql is null) return "ไม่รองรับประเภทเอกสารอ้างอิงนี้";
        await using var cmd = new SqlCommand(sql, c, tx); Add(cmd, "@id", SqlDbType.BigInt, id.Value); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); var value = await cmd.ExecuteScalarAsync(token);
        if (value is null || value == DBNull.Value) return "ไม่พบเอกสารอ้างอิงในบริษัทนี้";
        return Convert.ToInt64(value) == customerId ? null : "ลูกค้าในใบส่งของไม่ตรงกับลูกค้าของเอกสารอ้างอิง";
    }
    private async Task<bool> WithinSourceQuantity(SqlConnection c, SqlTransaction tx, string type, long sourceDetailId, long currentDetailId, decimal quantity, CancellationToken token)
    {
        var source = type == "QUOTATION" ? "SELECT Quantity FROM dbo.TDARQuotationDetail WHERE QuotationDetailID=@source" : "SELECT DeliveryQty FROM dbo.TDARDeliveryNoteDetail WHERE DeliveryNoteDetailID=@source";
        decimal allowed; await using (var cmd = new SqlCommand(source, c, tx)) { Add(cmd, "@source", SqlDbType.BigInt, sourceDetailId); var value = await cmd.ExecuteScalarAsync(token); if (value is null || value == DBNull.Value) return false; allowed = Convert.ToDecimal(value); }
        const string usedSql = "SELECT COALESCE(SUM(D.DeliveryQty),0) FROM dbo.TDARDeliveryNoteDetail D JOIN dbo.TDARDeliveryNote H ON H.DeliveryNoteID=D.DeliveryNoteID WHERE H.CompanyID=@company AND H.StatusCode=N'CONFIRMED' AND D.DeliveryNoteDetailID<>@current AND ((@type=N'QUOTATION' AND D.QuotationDetailID=@source) OR (@type=N'DELIVERY_NOTE' AND D.ParentDeliveryNoteDetailID=@source))";
        await using var used = new SqlCommand(usedSql, c, tx); Add(used, "@company", SqlDbType.BigInt, CompanyId()); Add(used, "@current", SqlDbType.BigInt, currentDetailId); Add(used, "@type", SqlDbType.NVarChar, type, 30); Add(used, "@source", SqlDbType.BigInt, sourceDetailId); return Convert.ToDecimal(await used.ExecuteScalarAsync(token)) + quantity <= allowed;
    }
    private async Task<string?> ScalarString(SqlConnection c, SqlTransaction tx, string sql, long id, CancellationToken t) { await using var cmd = new SqlCommand(sql, c, tx); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); return (await cmd.ExecuteScalarAsync(t))?.ToString(); }
    private async Task<List<object>> Rows<T>(SqlConnection c, string sql, CancellationToken t, Func<SqlDataReader, T> map, string? unitGroup = null) where T : class { await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); if (unitGroup is not null) Add(cmd, "@unitGroup", SqlDbType.NVarChar, unitGroup, 20); var list = new List<object>(); await using var r = await cmd.ExecuteReaderAsync(t); while (await r.ReadAsync(t)) list.Add(map(r)); return list; }
    private static async Task<List<object>> RowsById<T>(SqlConnection c, string sql, long id, CancellationToken t, Func<SqlDataReader, T> map) where T : class { await using var cmd = new SqlCommand(sql, c); Add(cmd, "@id", SqlDbType.BigInt, id); var list = new List<object>(); await using var r = await cmd.ExecuteReaderAsync(t); while (await r.ReadAsync(t)) list.Add(map(r)); return list; }
    private async Task<bool> Can(SqlConnection c, string action, CancellationToken t) { const string sql = """
      SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1)
      OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode=@action AND P.ScreenCode=@screen)
      OR EXISTS(SELECT 1 FROM dbo.TDADUser U JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND(ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END
    """; await using var cmd = new SqlCommand(sql, c); Add(cmd, "@user", SqlDbType.BigInt, UserId()); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); Add(cmd, "@project", SqlDbType.BigInt, ProjectId()); Add(cmd, "@action", SqlDbType.NVarChar, action, 20); Add(cmd, "@screen", SqlDbType.NVarChar, ScreenCode, 20); return (bool)(await cmd.ExecuteScalarAsync(t) ?? false); }
    private async Task<SqlConnection> Open(CancellationToken t) { var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(t); return c; }
    private long UserId() => long.TryParse(User.FindFirstValue("user_id"), out var v) ? v : 0; private long CompanyId() => long.TryParse(User.FindFirstValue("company_id"), out var v) ? v : 0; private long ProjectId() => long.TryParse(User.FindFirstValue("project_id"), out var v) ? v : 0;
    private static string? NormalizeReference(string? v) { var s = (v ?? "NONE").Trim().ToUpperInvariant(); return s is "NONE" or "QUOTATION" or "PREORDER" or "TEMP_RECEIPT" or "DELIVERY_NOTE" ? s : null; }
    private static string? Filter(string? v) => string.IsNullOrWhiteSpace(v) || v.Equals("ALL", StringComparison.OrdinalIgnoreCase) ? null : v.Trim(); private static string? Text(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetValue(i)?.ToString(); private static long? Long(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static void Add(SqlCommand c, string n, SqlDbType t, object? v, int size = 0) { var p = c.Parameters.Add(n, t); if (size > 0) p.Size = size; if (t == SqlDbType.Decimal) { p.Precision = 18; p.Scale = 4; } p.Value = v ?? DBNull.Value; }
    private sealed record CustomerRow(long Id, string Code, string Name, string? Address, string? TaxId, string? Contact, string? Phone);
}
