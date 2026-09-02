using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, LaooApi.Security.RequireCompanyFeature("SALES")]
[Route("api/company/tax-invoices")]
public sealed class TaxInvoiceController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "09007";
    private readonly IConfiguration _configuration = configuration;

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        return Ok(new
        {
            view = await Can(c, "VIEW", token),
            create = await Can(c, "CREATE", token),
            edit = await Can(c, "EDIT", token),
            delete = await Can(c, "DELETE", token)
        });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? status, [FromQuery] string? referenceType, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "VIEW", token)) return Forbid();
        const string sql = """
        SELECT T.TaxInvoiceID,T.TaxInvoiceCode,T.TaxInvoiceDate,T.CusCode,T.CusName,T.NetAmount,T.StatusCode,T.ReferenceType,
               COALESCE(Q.QuoteCode,P.PreOrderCode,R.ReceiptCode,N'') ReferenceCode
        FROM dbo.TDARTaxInvoice T
        LEFT JOIN dbo.TDARQuotation Q ON Q.QuotationID=T.QuotationID
        LEFT JOIN dbo.TDARPreOrder P ON P.PreOrderID=T.PreOrderID
        LEFT JOIN dbo.TDARTemporaryReceipt R ON R.TemporaryReceiptID=T.TemporaryReceiptID
        WHERE T.CompanyID=@company AND T.IsActive=1
          AND (@search IS NULL OR T.TaxInvoiceCode LIKE N'%'+@search+N'%' OR T.CusCode LIKE N'%'+@search+N'%' OR T.CusName LIKE N'%'+@search+N'%')
          AND (@status IS NULL OR T.StatusCode=@status)
          AND (@reference IS NULL OR T.ReferenceType=@reference)
        ORDER BY T.TaxInvoiceDate DESC,T.TaxInvoiceID DESC;
        """;
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
        Add(cmd, "@search", SqlDbType.NVarChar, Filter(search), 200);
        Add(cmd, "@status", SqlDbType.NVarChar, Filter(status), 30);
        Add(cmd, "@reference", SqlDbType.NVarChar, Filter(referenceType), 30);
        var rows = new List<object>();
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
        {
            rows.Add(new
            {
                taxInvoiceId = r.GetInt64(0),
                taxInvoiceCode = r.GetString(1),
                taxInvoiceDate = r.GetDateTime(2),
                customerCode = r.GetString(3),
                customerName = r.GetString(4),
                netAmount = r.GetDecimal(5),
                statusCode = r.GetString(6),
                referenceType = r.GetString(7),
                referenceCode = Text(r, 8)
            });
        }
        return Ok(rows);
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "VIEW", token)) return Forbid();
        return Ok(new
        {
            customers = await Rows(c, """
              SELECT CustomerID,CusCode,CusName,CusAddress,TaxID,ContName1,Phone1,Email1,ContName2,Phone2,Email2,PaymentType,CreditDays
              FROM dbo.TDARCustomer WHERE CompanyID=@company AND IsActive=1 ORDER BY CusCode
            """, token, r => new
            {
                customerId = r.GetInt64(0), customerCode = Text(r, 1), customerName = Text(r, 2), address = Text(r, 3), taxId = Text(r, 4),
                contactName1 = Text(r, 5), phone1 = Text(r, 6), email1 = Text(r, 7), contactName2 = Text(r, 8), phone2 = Text(r, 9), email2 = Text(r, 10),
                paymentType = Text(r, 11), creditDays = r.IsDBNull(12) ? 0 : r.GetInt32(12)
            }),
            items = await Rows(c, """
              SELECT I.ItemID,I.ItemCode,I.ItemName,I.UnitCode,I.UnitPrice,I.StockBalance,COALESCE(M.Name,I.UnitCode)
              FROM dbo.TDIVItem I
              LEFT JOIN dbo.TDSTMaster M ON M.OwnerType=N'C' AND M.OwnerCompanyID=I.CompanyID AND M.MasterGroupCode=@unitGroup AND M.MasterCode=I.UnitCode AND M.IsActive=1
              WHERE I.CompanyID=@company AND I.IsActive=1 ORDER BY I.ItemCode
            """, token, r => new
            {
                itemId = r.GetInt64(0), itemCode = Text(r, 1), itemName = Text(r, 2), unitCode = Text(r, 3), unitPrice = r.GetDecimal(4), stockBalance = r.GetDecimal(5), unitName = Text(r, 6)
            }, MasterConstCodes.cmsUnit),
            quotations = await Rows(c, "SELECT QuotationID,QuoteCode,QuoteDate,CustomerID,CusCode,CusName,COALESCE(NetAmount,0) FROM dbo.TDARQuotation WHERE CompanyID=@company AND IsActive=1 AND StatusCode<>N'CANCELLED' ORDER BY QuoteDate DESC", token, r => new { id = r.GetInt64(0), code = r.GetString(1), date = r.GetDateTime(2), customerId = r.GetInt64(3), customerCode = r.GetString(4), customerName = r.GetString(5), amount = r.GetDecimal(6) }),
            preOrders = await Rows(c, "SELECT PreOrderID,PreOrderCode,PreOrderDate,CustomerID,CusCode,CusName,TotalAmount FROM dbo.TDARPreOrder WHERE CompanyID=@company AND IsActive=1 AND StatusCode<>N'CANCELLED' ORDER BY PreOrderDate DESC", token, r => new { id = r.GetInt64(0), code = r.GetString(1), date = r.GetDateTime(2), customerId = r.GetInt64(3), customerCode = r.GetString(4), customerName = r.GetString(5), amount = r.GetDecimal(6) }),
            receipts = await Rows(c, "SELECT TemporaryReceiptID,ReceiptCode,ReceiptDate,CustomerID,CusCode,CusName,ReceivedAmount FROM dbo.TDARTemporaryReceipt WHERE CompanyID=@company AND IsActive=1 AND StatusCode<>N'VOID' ORDER BY ReceiptDate DESC", token, r => new { id = r.GetInt64(0), code = r.GetString(1), date = r.GetDateTime(2), customerId = r.GetInt64(3), customerCode = r.GetString(4), customerName = r.GetString(5), amount = r.GetDecimal(6) })
        });
    }

    [HttpGet("source/{type}/{id:long}")]
    public async Task<IActionResult> Source(string type, long id, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "VIEW", token)) return Forbid();
        var normalized = NormalizeReference(type);
        object? result = normalized switch
        {
            "QUOTATION" => await QuotationSource(c, id, "QUOTATION", id, token),
            "PREORDER" => await PreOrderSource(c, id, "PREORDER", id, token),
            "TEMP_RECEIPT" => await ReceiptSource(c, id, token),
            _ => null
        };
        return result is null
            ? NotFound(new { message = "ไม่พบเอกสารอ้างอิง", description = "เอกสารอาจถูกลบ ไม่อยู่ในบริษัทนี้ หรือไม่รองรับเป็นต้นทางของใบกำกับภาษี" })
            : Ok(result);
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "VIEW", token)) return Forbid();
        const string sql = """
        SELECT TaxInvoiceID,TaxInvoiceCode,TaxInvoiceDate,ReferenceType,COALESCE(QuotationID,PreOrderID,TemporaryReceiptID),CustomerID,CusCode,CusName,CusAddress,TaxID,
               ContactName,ContactPhone,ContactEmail,PaymentType,CreditDays,DueDate,Subtotal,DiscountPercent,DiscountAmount,AmountAfterDiscount,TaxPercent,TaxAmount,NetAmount,StatusCode,Remark
        FROM dbo.TDARTaxInvoice WHERE TaxInvoiceID=@id AND CompanyID=@company AND IsActive=1
        """;
        object? header = null;
        await using (var cmd = new SqlCommand(sql, c))
        {
            Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
            await using var r = await cmd.ExecuteReaderAsync(token);
            if (await r.ReadAsync(token)) header = new
            {
                taxInvoiceId = r.GetInt64(0), taxInvoiceCode = r.GetString(1), taxInvoiceDate = r.GetDateTime(2), referenceType = r.GetString(3), referenceId = Long(r, 4),
                customerId = r.GetInt64(5), customerCode = r.GetString(6), customerName = r.GetString(7), customerAddress = Text(r, 8), taxId = Text(r, 9),
                contactName = Text(r, 10), contactPhone = Text(r, 11), contactEmail = Text(r, 12), paymentType = Text(r, 13), creditDays = r.GetInt32(14), dueDate = Date(r, 15),
                subtotal = r.GetDecimal(16), discountPercent = r.GetDecimal(17), discountAmount = r.GetDecimal(18), amountAfterDiscount = r.GetDecimal(19), taxPercent = r.GetDecimal(20), taxAmount = r.GetDecimal(21), netAmount = r.GetDecimal(22), statusCode = r.GetString(23), remark = Text(r, 24)
            };
        }
        if (header is null) return NotFound(new { message = "ไม่พบใบกำกับภาษี", description = "เอกสารอาจถูกลบหรือไม่อยู่ในบริษัทนี้" });
        var items = await RowsById(c, """
          SELECT TaxInvoiceDetailID,[LineNo],QuotationDetailID,PreOrderDetailID,ItemID,ItemCode,ItemName,UnitCode,Quantity,UnitPrice,DiscountType,BeforeDiscount,DiscountPercent,DiscountAmount,Amount,Remark
          FROM dbo.TDARTaxInvoiceDetail WHERE TaxInvoiceID=@id ORDER BY [LineNo]
        """, id, token, r => new
        {
            taxInvoiceDetailId = r.GetInt64(0), lineNo = r.GetInt32(1), quotationDetailId = Long(r, 2), preOrderDetailId = Long(r, 3), itemId = r.GetInt64(4), itemCode = r.GetString(5), itemName = r.GetString(6), unitCode = Text(r, 7), quantity = r.GetDecimal(8), unitPrice = r.GetDecimal(9), discountType = r.GetString(10), beforeDiscount = r.GetDecimal(11), discountPercent = r.GetDecimal(12), discountAmount = r.GetDecimal(13), amount = r.GetDecimal(14), remark = Text(r, 15)
        });
        return Ok(new { header, items });
    }

    [HttpPost]
    public Task<IActionResult> Create([FromBody] TaxInvoiceUpsertRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, [FromBody] TaxInvoiceUpsertRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "DELETE", token)) return Forbid();
        await using var cmd = new SqlCommand("DELETE dbo.TDARTaxInvoice WHERE TaxInvoiceID=@id AND CompanyID=@company AND StatusCode=N'DRAFT'", c);
        Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
        return await cmd.ExecuteNonQueryAsync(token) > 0
            ? NoContent()
            : Conflict(new { message = "ลบใบกำกับภาษีไม่ได้", description = "ลบได้เฉพาะเอกสารสถานะร่าง เอกสารที่ออกแล้วให้ใช้คำสั่งยกเลิก" });
    }

    [HttpPost("{id:long}/issue")]
    public async Task<IActionResult> Issue(long id, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var status = await Scalar(c, tx, "SELECT StatusCode FROM dbo.TDARTaxInvoice WITH(UPDLOCK,HOLDLOCK) WHERE TaxInvoiceID=@id AND CompanyID=@company AND IsActive=1", id, token);
            if (status != "DRAFT") return await RollbackConflict(tx, token, "ออกใบกำกับภาษีไม่ได้", "ออกเอกสารได้เฉพาะสถานะร่าง");
            var lines = new List<IssueLine>();
            await using (var cmd = new SqlCommand("SELECT TaxInvoiceDetailID,ItemID,Quantity,PreOrderDetailID,QuotationDetailID FROM dbo.TDARTaxInvoiceDetail WHERE TaxInvoiceID=@id", c, tx))
            {
                Add(cmd, "@id", SqlDbType.BigInt, id);
                await using var r = await cmd.ExecuteReaderAsync(token);
                while (await r.ReadAsync(token)) lines.Add(new(r.GetInt64(0), r.GetInt64(1), r.GetDecimal(2), Long(r, 3), Long(r, 4)));
            }
            if (lines.Count == 0) return await RollbackBadRequest(tx, token, "ออกใบกำกับภาษีไม่ได้", "กรุณาเพิ่มสินค้าอย่างน้อย 1 รายการ");
            foreach (var line in lines)
            {
                if (line.PreOrderDetailId.HasValue)
                {
                    await using var pre = new SqlCommand("UPDATE dbo.TDARPreOrderDetail WITH(UPDLOCK,HOLDLOCK) SET DeliveredQty=DeliveredQty+@qty WHERE PreOrderDetailID=@detail AND DeliveredQty+@qty<=AllocatedQty", c, tx);
                    Add(pre, "@qty", SqlDbType.Decimal, line.Quantity); Add(pre, "@detail", SqlDbType.BigInt, line.PreOrderDetailId.Value);
                    if (await pre.ExecuteNonQueryAsync(token) == 0) return await RollbackConflict(tx, token, "จำนวนสินค้าเกินใบจอง", $"รายการอ้างอิง {line.PreOrderDetailId} มีจำนวนคงเหลือไม่เพียงพอ");
                }
                if (line.QuotationDetailId.HasValue && !await QuotationQuantityAvailable(c, tx, id, line.QuotationDetailId.Value, line.Quantity, token))
                    return await RollbackConflict(tx, token, "จำนวนสินค้าเกินใบเสนอราคา", $"รายการอ้างอิง {line.QuotationDetailId} ถูกนำไปออกเอกสารปลายทางครบแล้ว");
                await using var stock = new SqlCommand("UPDATE dbo.TDIVItem WITH(UPDLOCK,HOLDLOCK) SET StockBalance=StockBalance-@qty,UpdateDate=SYSUTCDATETIME() WHERE ItemID=@item AND CompanyID=@company AND StockBalance>=@qty", c, tx);
                Add(stock, "@qty", SqlDbType.Decimal, line.Quantity); Add(stock, "@item", SqlDbType.BigInt, line.ItemId); Add(stock, "@company", SqlDbType.BigInt, CompanyId());
                if (await stock.ExecuteNonQueryAsync(token) == 0) return await RollbackConflict(tx, token, "สต๊อกสินค้าไม่เพียงพอ", $"สินค้า ItemID {line.ItemId} มีจำนวนคงเหลือน้อยกว่าจำนวนที่ออกใบกำกับภาษี");
                await using var movement = new SqlCommand("INSERT dbo.TDIVStockMovement(CompanyID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@item,N'TAX_INVOICE',@id,@detail,N'OUT',-@qty,N'ออกใบกำกับภาษี',@user)", c, tx);
                BindMovement(movement, id, line, -line.Quantity); await movement.ExecuteNonQueryAsync(token);
            }
            await using (var cmd = new SqlCommand("UPDATE dbo.TDARTaxInvoice SET StatusCode=N'ISSUED',UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE TaxInvoiceID=@id AND CompanyID=@company", c, tx))
            {
                Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); Add(cmd, "@user", SqlDbType.BigInt, UserId()); await cmd.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return Ok(new { taxInvoiceId = id, statusCode = "ISSUED" });
        }
        catch (Exception ex) { await tx.RollbackAsync(token); return StatusCode(500, new { message = "ออกใบกำกับภาษีไม่สำเร็จ", description = ex.Message }); }
    }

    [HttpPost("{id:long}/void")]
    public async Task<IActionResult> VoidDocument(long id, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var status = await Scalar(c, tx, "SELECT StatusCode FROM dbo.TDARTaxInvoice WITH(UPDLOCK,HOLDLOCK) WHERE TaxInvoiceID=@id AND CompanyID=@company AND IsActive=1", id, token);
            if (status != "ISSUED") return await RollbackConflict(tx, token, "ยกเลิกใบกำกับภาษีไม่ได้", "ยกเลิกได้เฉพาะเอกสารที่ออกแล้ว");
            var lines = new List<IssueLine>();
            await using (var cmd = new SqlCommand("SELECT TaxInvoiceDetailID,ItemID,Quantity,PreOrderDetailID,QuotationDetailID FROM dbo.TDARTaxInvoiceDetail WHERE TaxInvoiceID=@id", c, tx))
            {
                Add(cmd, "@id", SqlDbType.BigInt, id); await using var r = await cmd.ExecuteReaderAsync(token);
                while (await r.ReadAsync(token)) lines.Add(new(r.GetInt64(0), r.GetInt64(1), r.GetDecimal(2), Long(r, 3), Long(r, 4)));
            }
            foreach (var line in lines)
            {
                await using (var stock = new SqlCommand("UPDATE dbo.TDIVItem SET StockBalance=StockBalance+@qty,UpdateDate=SYSUTCDATETIME() WHERE ItemID=@item AND CompanyID=@company", c, tx))
                { Add(stock, "@qty", SqlDbType.Decimal, line.Quantity); Add(stock, "@item", SqlDbType.BigInt, line.ItemId); Add(stock, "@company", SqlDbType.BigInt, CompanyId()); await stock.ExecuteNonQueryAsync(token); }
                if (line.PreOrderDetailId.HasValue)
                {
                    await using var pre = new SqlCommand("UPDATE dbo.TDARPreOrderDetail SET DeliveredQty=CASE WHEN DeliveredQty>=@qty THEN DeliveredQty-@qty ELSE 0 END WHERE PreOrderDetailID=@detail", c, tx);
                    Add(pre, "@qty", SqlDbType.Decimal, line.Quantity); Add(pre, "@detail", SqlDbType.BigInt, line.PreOrderDetailId.Value); await pre.ExecuteNonQueryAsync(token);
                }
                await using var movement = new SqlCommand("INSERT dbo.TDIVStockMovement(CompanyID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@item,N'TAX_INVOICE',@id,@detail,N'REVERSAL',@qty,N'ยกเลิกใบกำกับภาษี',@user)", c, tx);
                BindMovement(movement, id, line, line.Quantity); await movement.ExecuteNonQueryAsync(token);
            }
            await using (var cmd = new SqlCommand("UPDATE dbo.TDARTaxInvoice SET StatusCode=N'VOID',UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE TaxInvoiceID=@id AND CompanyID=@company", c, tx))
            { Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); Add(cmd, "@user", SqlDbType.BigInt, UserId()); await cmd.ExecuteNonQueryAsync(token); }
            await tx.CommitAsync(token);
            return Ok(new { taxInvoiceId = id, statusCode = "VOID" });
        }
        catch (Exception ex) { await tx.RollbackAsync(token); return StatusCode(500, new { message = "ยกเลิกใบกำกับภาษีไม่สำเร็จ", description = ex.Message }); }
    }

    private async Task<IActionResult> Save(long? id, TaxInvoiceUpsertRequest request, CancellationToken token)
    {
        var action = id.HasValue ? "EDIT" : "CREATE";
        var type = NormalizeReference(request.ReferenceType);
        if (type is null) return BadRequest(new { message = "ประเภทเอกสารอ้างอิงไม่ถูกต้อง", description = "รองรับ NONE, QUOTATION, PREORDER และ TEMP_RECEIPT เท่านั้น" });
        if (request.CustomerId <= 0 || request.Items.Count == 0) return BadRequest(new { message = "ข้อมูลใบกำกับภาษีไม่ครบ", description = "กรุณาเลือกลูกค้าและเพิ่มสินค้าอย่างน้อย 1 รายการ" });
        if (request.CreditDays < 0 || request.TaxPercent is < 0 or > 100 || request.DiscountPercent is < 0 or > 100 || request.DiscountAmount < 0)
            return BadRequest(new { message = "ยอดเงินหรือเงื่อนไขเครดิตไม่ถูกต้อง", description = "จำนวนวันเครดิตต้องไม่ติดลบ และเปอร์เซ็นต์ต้องอยู่ระหว่าง 0 ถึง 100" });
        await using var c = await Open(token);
        if (!await Can(c, action, token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var customer = await Customer(c, tx, request.CustomerId, token);
            if (customer is null) return await RollbackBadRequest(tx, token, "เลือกลูกค้าไม่ได้", "ไม่พบลูกค้าในบริษัทที่กำลังใช้งาน");
            var referenceError = await ValidateReference(c, tx, type, request.ReferenceId, request.CustomerId, token);
            if (referenceError is not null) return await RollbackBadRequest(tx, token, "เอกสารอ้างอิงไม่ถูกต้อง", referenceError);
            var calculated = new List<CalculatedLine>();
            foreach (var line in request.Items)
            {
                if (line.ItemId <= 0 || line.Quantity <= 0 || line.UnitPrice < 0) return await RollbackBadRequest(tx, token, "รายการสินค้าไม่ถูกต้อง", "สินค้า จำนวน และราคาต้องถูกต้อง");
                var item = await Item(c, tx, line.ItemId, token);
                if (item is null) return await RollbackBadRequest(tx, token, "ไม่พบสินค้า", $"ItemID {line.ItemId} ไม่อยู่ในบริษัทนี้");
                var discountType = NormalizeDiscount(line.DiscountType);
                if (discountType is null) return await RollbackBadRequest(tx, token, "รูปแบบส่วนลดไม่ถูกต้อง", "ส่วนลดรายการรองรับ N, P หรือ A เท่านั้น");
                var before = Math.Round(line.Quantity * line.UnitPrice, 4);
                var discount = discountType == "P" ? Math.Round(before * line.DiscountPercent / 100m, 4) : discountType == "A" ? Math.Round(line.DiscountAmount, 4) : 0m;
                if (line.DiscountPercent is < 0 or > 100 || discount < 0 || discount > before) return await RollbackBadRequest(tx, token, "ส่วนลดรายการไม่ถูกต้อง", $"ส่วนลดสินค้า {item.Value.Code} เกินมูลค่ารายการ");
                calculated.Add(new(line, item.Value, discountType, before, discount, before - discount));
            }
            var subtotal = calculated.Sum(x => x.Amount);
            var headerDiscount = request.DiscountPercent > 0 ? Math.Round(subtotal * request.DiscountPercent / 100m, 4) : Math.Round(request.DiscountAmount, 4);
            if (headerDiscount > subtotal) return await RollbackBadRequest(tx, token, "ส่วนลดท้ายเอกสารไม่ถูกต้อง", "ส่วนลดต้องไม่เกินยอดรวมสินค้า");
            var afterDiscount = subtotal - headerDiscount;
            var taxAmount = Math.Round(afterDiscount * request.TaxPercent / 100m, 4);
            var net = afterDiscount + taxAmount;
            long invoiceId;
            string code;
            if (id.HasValue)
            {
                var state = await Scalar(c, tx, "SELECT StatusCode FROM dbo.TDARTaxInvoice WITH(UPDLOCK,HOLDLOCK) WHERE TaxInvoiceID=@id AND CompanyID=@company AND IsActive=1", id.Value, token);
                if (state != "DRAFT") return await RollbackConflict(tx, token, "แก้ไขใบกำกับภาษีไม่ได้", "แก้ไขได้เฉพาะเอกสารสถานะร่าง");
                invoiceId = id.Value;
                code = await Scalar(c, tx, "SELECT TaxInvoiceCode FROM dbo.TDARTaxInvoice WHERE TaxInvoiceID=@id AND CompanyID=@company", id.Value, token) ?? "";
                await using var update = new SqlCommand("""
                  UPDATE dbo.TDARTaxInvoice SET TaxInvoiceDate=@date,ReferenceType=@type,QuotationID=@quotation,PreOrderID=@preorder,TemporaryReceiptID=@receipt,
                    CustomerID=@customer,CusCode=@cusCode,CusName=@cusName,CusAddress=@address,TaxID=@tax,ContactName=@contact,ContactPhone=@phone,ContactEmail=@email,
                    PaymentType=@payment,CreditDays=@credit,DueDate=@due,Subtotal=@subtotal,DiscountPercent=@discountPercent,DiscountAmount=@discountAmount,
                    AmountAfterDiscount=@afterDiscount,TaxPercent=@taxPercent,TaxAmount=@taxAmount,NetAmount=@net,Remark=@remark,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user
                  WHERE TaxInvoiceID=@id AND CompanyID=@company;
                  DELETE dbo.TDARTaxInvoiceDetail WHERE TaxInvoiceID=@id;
                """, c, tx);
                BindHeader(update, request, type, customer, subtotal, headerDiscount, afterDiscount, taxAmount, net, id.Value); await update.ExecuteNonQueryAsync(token);
            }
            else
            {
                code = await NextCode(c, tx, token);
                await using var insert = new SqlCommand("""
                  INSERT dbo.TDARTaxInvoice(CompanyID,TaxInvoiceCode,TaxInvoiceDate,ReferenceType,QuotationID,PreOrderID,TemporaryReceiptID,CustomerID,CusCode,CusName,CusAddress,TaxID,
                    ContactName,ContactPhone,ContactEmail,PaymentType,CreditDays,DueDate,Subtotal,DiscountPercent,DiscountAmount,AmountAfterDiscount,TaxPercent,TaxAmount,NetAmount,StatusCode,Remark,IsActive,CreatedBy)
                  OUTPUT INSERTED.TaxInvoiceID
                  VALUES(@company,@code,@date,@type,@quotation,@preorder,@receipt,@customer,@cusCode,@cusName,@address,@tax,@contact,@phone,@email,@payment,@credit,@due,
                    @subtotal,@discountPercent,@discountAmount,@afterDiscount,@taxPercent,@taxAmount,@net,N'DRAFT',@remark,1,@user)
                """, c, tx);
                Add(insert, "@code", SqlDbType.NVarChar, code, 30); BindHeader(insert, request, type, customer, subtotal, headerDiscount, afterDiscount, taxAmount, net, null);
                invoiceId = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            }
            for (var i = 0; i < calculated.Count; i++)
            {
                var line = calculated[i];
                await using var detail = new SqlCommand("""
                  INSERT dbo.TDARTaxInvoiceDetail(TaxInvoiceID,[LineNo],QuotationDetailID,PreOrderDetailID,ItemID,ItemCode,ItemName,UnitCode,Quantity,UnitPrice,DiscountType,BeforeDiscount,DiscountPercent,DiscountAmount,Amount,Remark)
                  VALUES(@id,@line,@quotationDetail,@preOrderDetail,@item,@itemCode,@itemName,@unit,@qty,@price,@discountType,@before,@discountPercent,@discountAmount,@amount,@remark)
                """, c, tx);
                Add(detail, "@id", SqlDbType.BigInt, invoiceId); Add(detail, "@line", SqlDbType.Int, i + 1); Add(detail, "@quotationDetail", SqlDbType.BigInt, line.Request.QuotationDetailId);
                Add(detail, "@preOrderDetail", SqlDbType.BigInt, line.Request.PreOrderDetailId); Add(detail, "@item", SqlDbType.BigInt, line.Request.ItemId); Add(detail, "@itemCode", SqlDbType.NVarChar, line.Item.Code, 50);
                Add(detail, "@itemName", SqlDbType.NVarChar, line.Item.Name, 200); Add(detail, "@unit", SqlDbType.NVarChar, line.Item.Unit, 50); Add(detail, "@qty", SqlDbType.Decimal, line.Request.Quantity);
                Add(detail, "@price", SqlDbType.Decimal, line.Request.UnitPrice); Add(detail, "@discountType", SqlDbType.NVarChar, line.DiscountType, 1); Add(detail, "@before", SqlDbType.Decimal, line.BeforeDiscount);
                Add(detail, "@discountPercent", SqlDbType.Decimal, line.DiscountType == "P" ? line.Request.DiscountPercent : 0); Add(detail, "@discountAmount", SqlDbType.Decimal, line.DiscountAmount);
                Add(detail, "@amount", SqlDbType.Decimal, line.Amount); Add(detail, "@remark", SqlDbType.NVarChar, Filter(line.Request.Remark), 500); await detail.ExecuteNonQueryAsync(token);
            }
            await using (var clear = new SqlCommand("DELETE dbo.TDARDocumentLink WHERE CompanyID=@company AND FromDocumentType=N'TAX_INVOICE' AND FromDocumentID=@id", c, tx))
            { Add(clear, "@company", SqlDbType.BigInt, CompanyId()); Add(clear, "@id", SqlDbType.BigInt, invoiceId); await clear.ExecuteNonQueryAsync(token); }
            if (type != "NONE" && request.ReferenceId.HasValue)
            {
                await using var link = new SqlCommand("INSERT dbo.TDARDocumentLink(CompanyID,FromDocumentType,FromDocumentID,ToDocumentType,ToDocumentID,LinkType,LinkDescription,CreatedBy) VALUES(@company,N'TAX_INVOICE',@id,@type,@target,N'REFERENCE',N'เอกสารอ้างอิงใบกำกับภาษี',@user)", c, tx);
                Add(link, "@company", SqlDbType.BigInt, CompanyId()); Add(link, "@id", SqlDbType.BigInt, invoiceId); Add(link, "@type", SqlDbType.NVarChar, type, 30); Add(link, "@target", SqlDbType.BigInt, request.ReferenceId.Value); Add(link, "@user", SqlDbType.BigInt, UserId()); await link.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return Ok(new { taxInvoiceId = invoiceId, taxInvoiceCode = code, statusCode = "DRAFT", subtotal, discountAmount = headerDiscount, amountAfterDiscount = afterDiscount, taxAmount, netAmount = net });
        }
        catch (Exception ex) { await tx.RollbackAsync(token); return StatusCode(500, new { message = "บันทึกใบกำกับภาษีไม่สำเร็จ", description = ex.Message }); }
    }

    private void BindHeader(SqlCommand cmd, TaxInvoiceUpsertRequest request, string type, CustomerRow customer, decimal subtotal, decimal discount, decimal afterDiscount, decimal taxAmount, decimal net, long? id)
    {
        var date = request.TaxInvoiceDate?.Date ?? DateTime.Today;
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); Add(cmd, "@date", SqlDbType.Date, date); Add(cmd, "@type", SqlDbType.NVarChar, type, 30);
        Add(cmd, "@quotation", SqlDbType.BigInt, type == "QUOTATION" ? request.ReferenceId : null); Add(cmd, "@preorder", SqlDbType.BigInt, type == "PREORDER" ? request.ReferenceId : null); Add(cmd, "@receipt", SqlDbType.BigInt, type == "TEMP_RECEIPT" ? request.ReferenceId : null);
        Add(cmd, "@customer", SqlDbType.BigInt, customer.Id); Add(cmd, "@cusCode", SqlDbType.NVarChar, customer.Code, 50); Add(cmd, "@cusName", SqlDbType.NVarChar, customer.Name, 200); Add(cmd, "@address", SqlDbType.NVarChar, customer.Address, 1000); Add(cmd, "@tax", SqlDbType.NVarChar, customer.TaxId, 30);
        Add(cmd, "@contact", SqlDbType.NVarChar, Filter(request.ContactName), 200); Add(cmd, "@phone", SqlDbType.NVarChar, Filter(request.ContactPhone), 100); Add(cmd, "@email", SqlDbType.NVarChar, Filter(request.ContactEmail), 200);
        Add(cmd, "@payment", SqlDbType.NVarChar, Filter(request.PaymentType) ?? customer.PaymentType, 50); Add(cmd, "@credit", SqlDbType.Int, request.CreditDays); Add(cmd, "@due", SqlDbType.Date, date.AddDays(request.CreditDays));
        Add(cmd, "@subtotal", SqlDbType.Decimal, subtotal); Add(cmd, "@discountPercent", SqlDbType.Decimal, request.DiscountPercent); Add(cmd, "@discountAmount", SqlDbType.Decimal, discount); Add(cmd, "@afterDiscount", SqlDbType.Decimal, afterDiscount);
        Add(cmd, "@taxPercent", SqlDbType.Decimal, request.TaxPercent); Add(cmd, "@taxAmount", SqlDbType.Decimal, taxAmount); Add(cmd, "@net", SqlDbType.Decimal, net); Add(cmd, "@remark", SqlDbType.NVarChar, Filter(request.Remark), 1000); Add(cmd, "@user", SqlDbType.BigInt, UserId());
        if (id.HasValue) Add(cmd, "@id", SqlDbType.BigInt, id.Value);
    }

    private async Task<object?> QuotationSource(SqlConnection c, long id, string returnType, long returnId, CancellationToken token)
    {
        CustomerSource? customer = null;
        await using (var cmd = new SqlCommand("SELECT Q.CustomerID,Q.CusCode,Q.CusName,C.CusAddress,C.TaxID,Q.ContactName,COALESCE(NULLIF(C.Phone1,N''),C.Phone),COALESCE(NULLIF(C.Email1,N''),C.Email),Q.PaymentType,Q.CreditDays,Q.TaxPercent,Q.DiscountPercent,Q.DiscountAmount FROM dbo.TDARQuotation Q LEFT JOIN dbo.TDARCustomer C ON C.CustomerID=Q.CustomerID AND C.CompanyID=Q.CompanyID WHERE Q.QuotationID=@id AND Q.CompanyID=@company AND Q.IsActive=1", c))
        {
            Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(token);
            if (!await r.ReadAsync(token)) return null;
            customer = new(r.GetInt64(0), r.GetString(1), r.GetString(2), Text(r, 3), Text(r, 4), Text(r, 5), Text(r, 6), Text(r, 7), Text(r, 8), r.IsDBNull(9) ? 0 : r.GetInt32(9), r.IsDBNull(10) ? 7 : r.GetDecimal(10), r.IsDBNull(11) ? 0 : r.GetDecimal(11), r.IsDBNull(12) ? 0 : r.GetDecimal(12));
        }
        var items = await RowsById(c, "SELECT QuotationDetailID,ItemID,ItemCode,ItemName,UnitCode,Quantity,UnitPrice,DiscountType,DiscountPercent,DiscountAmount FROM dbo.TDARQuotationDetail WHERE QuotationID=@id ORDER BY [LineNo]", id, token, r => new { quotationDetailId = r.GetInt64(0), preOrderDetailId = (long?)null, itemId = r.GetInt64(1), itemCode = r.GetString(2), itemName = r.GetString(3), unitCode = Text(r, 4), quantity = r.GetDecimal(5), unitPrice = r.GetDecimal(6), discountType = r.GetString(7), discountPercent = r.GetDecimal(8), discountAmount = r.GetDecimal(9) });
        return SourceResult(returnType, returnId, customer, items);
    }

    private async Task<object?> PreOrderSource(SqlConnection c, long id, string returnType, long returnId, CancellationToken token)
    {
        CustomerSource? customer = null;
        await using (var cmd = new SqlCommand("SELECT P.CustomerID,P.CusCode,P.CusName,C.CusAddress,C.TaxID,P.ContactName,P.ContactPhone,COALESCE(NULLIF(C.Email1,N''),C.Email),C.PaymentType,C.CreditDays FROM dbo.TDARPreOrder P LEFT JOIN dbo.TDARCustomer C ON C.CustomerID=P.CustomerID AND C.CompanyID=P.CompanyID WHERE P.PreOrderID=@id AND P.CompanyID=@company AND P.IsActive=1", c))
        {
            Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(token);
            if (!await r.ReadAsync(token)) return null;
            customer = new(r.GetInt64(0), r.GetString(1), r.GetString(2), Text(r, 3), Text(r, 4), Text(r, 5), Text(r, 6), Text(r, 7), Text(r, 8), r.IsDBNull(9) ? 0 : r.GetInt32(9), 7, 0, 0);
        }
        var items = await RowsById(c, "SELECT PreOrderDetailID,QuotationDetailID,ItemID,ItemCode,ItemName,UnitCode,AllocatedQty-DeliveredQty,UnitPrice,DiscountType,DiscountPercent,DiscountAmount FROM dbo.TDARPreOrderDetail WHERE PreOrderID=@id AND AllocatedQty>DeliveredQty ORDER BY [LineNo]", id, token, r => new { preOrderDetailId = r.GetInt64(0), quotationDetailId = Long(r, 1), itemId = r.GetInt64(2), itemCode = r.GetString(3), itemName = r.GetString(4), unitCode = Text(r, 5), quantity = r.GetDecimal(6), unitPrice = r.GetDecimal(7), discountType = r.GetString(8), discountPercent = r.GetDecimal(9), discountAmount = r.GetDecimal(10) });
        return SourceResult(returnType, returnId, customer, items);
    }

    private async Task<object?> ReceiptSource(SqlConnection c, long id, CancellationToken token)
    {
        long? quotation = null, preorder = null;
        await using (var cmd = new SqlCommand("SELECT QuotationID,PreOrderID FROM dbo.TDARTemporaryReceipt WHERE TemporaryReceiptID=@id AND CompanyID=@company AND IsActive=1 AND StatusCode<>N'VOID'", c))
        {
            Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(token);
            if (!await r.ReadAsync(token)) return null; quotation = Long(r, 0); preorder = Long(r, 1);
        }
        if (preorder.HasValue) return await PreOrderSource(c, preorder.Value, "TEMP_RECEIPT", id, token);
        if (quotation.HasValue) return await QuotationSource(c, quotation.Value, "TEMP_RECEIPT", id, token);
        await using var customerCmd = new SqlCommand("SELECT R.CustomerID,R.CusCode,R.CusName,R.CusAddress,R.TaxID,R.ContactName,C.Phone,C.Email,C.PaymentType,C.CreditDays FROM dbo.TDARTemporaryReceipt R LEFT JOIN dbo.TDARCustomer C ON C.CustomerID=R.CustomerID AND C.CompanyID=R.CompanyID WHERE R.TemporaryReceiptID=@id AND R.CompanyID=@company", c);
        Add(customerCmd, "@id", SqlDbType.BigInt, id); Add(customerCmd, "@company", SqlDbType.BigInt, CompanyId()); await using var reader = await customerCmd.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return null;
        var customer = new CustomerSource(reader.GetInt64(0), reader.GetString(1), reader.GetString(2), Text(reader, 3), Text(reader, 4), Text(reader, 5), Text(reader, 6), Text(reader, 7), Text(reader, 8), reader.IsDBNull(9) ? 0 : reader.GetInt32(9), 7, 0, 0);
        return SourceResult("TEMP_RECEIPT", id, customer, []);
    }

    private static object SourceResult(string type, long id, CustomerSource c, List<object> items) => new
    {
        referenceType = type, referenceId = id,
        customer = new { customerId = c.Id, customerCode = c.Code, customerName = c.Name, address = c.Address, taxId = c.TaxId, contactName = c.Contact, contactPhone = c.Phone, contactEmail = c.Email, paymentType = c.PaymentType, creditDays = c.CreditDays },
        taxPercent = c.TaxPercent, discountPercent = c.DiscountPercent, discountAmount = c.DiscountAmount, items
    };

    private async Task<CustomerRow?> Customer(SqlConnection c, SqlTransaction tx, long id, CancellationToken token)
    {
        await using var cmd = new SqlCommand("SELECT CustomerID,CusCode,CusName,CusAddress,TaxID,PaymentType,CreditDays FROM dbo.TDARCustomer WHERE CustomerID=@id AND CompanyID=@company AND IsActive=1", c, tx);
        Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(token);
        return await r.ReadAsync(token) ? new(r.GetInt64(0), Text(r, 1) ?? "", Text(r, 2) ?? "", Text(r, 3), Text(r, 4), Text(r, 5), r.IsDBNull(6) ? 0 : r.GetInt32(6)) : null;
    }

    private async Task<(string Code, string Name, string Unit)?> Item(SqlConnection c, SqlTransaction tx, long id, CancellationToken token)
    {
        await using var cmd = new SqlCommand("SELECT ItemCode,ItemName,UnitCode FROM dbo.TDIVItem WHERE ItemID=@id AND CompanyID=@company AND IsActive=1", c, tx);
        Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(token);
        return await r.ReadAsync(token) ? (Text(r, 0) ?? "", Text(r, 1) ?? "", Text(r, 2) ?? "") : null;
    }

    private async Task<string?> ValidateReference(SqlConnection c, SqlTransaction tx, string type, long? id, long customerId, CancellationToken token)
    {
        if (type == "NONE") return id.HasValue ? "กรณีไม่อ้างอิงเอกสารต้องไม่มี ReferenceId" : null;
        if (!id.HasValue) return "กรุณาเลือกเอกสารอ้างอิง";
        var sql = type switch
        {
            "QUOTATION" => "SELECT CustomerID FROM dbo.TDARQuotation WHERE QuotationID=@id AND CompanyID=@company AND IsActive=1",
            "PREORDER" => "SELECT CustomerID FROM dbo.TDARPreOrder WHERE PreOrderID=@id AND CompanyID=@company AND IsActive=1",
            "TEMP_RECEIPT" => "SELECT CustomerID FROM dbo.TDARTemporaryReceipt WHERE TemporaryReceiptID=@id AND CompanyID=@company AND IsActive=1 AND StatusCode<>N'VOID'",
            _ => null
        };
        if (sql is null) return "ไม่รองรับเอกสารอ้างอิงประเภทนี้";
        await using var cmd = new SqlCommand(sql, c, tx); Add(cmd, "@id", SqlDbType.BigInt, id.Value); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); var value = await cmd.ExecuteScalarAsync(token);
        return value is null || value == DBNull.Value ? "ไม่พบเอกสารอ้างอิงในบริษัทนี้" : Convert.ToInt64(value) == customerId ? null : "ลูกค้าในเอกสารอ้างอิงไม่ตรงกับใบกำกับภาษี";
    }

    private async Task<bool> QuotationQuantityAvailable(SqlConnection c, SqlTransaction tx, long currentInvoiceId, long detailId, decimal quantity, CancellationToken token)
    {
        decimal allowed;
        await using (var source = new SqlCommand("SELECT Quantity FROM dbo.TDARQuotationDetail WHERE QuotationDetailID=@detail", c, tx))
        { Add(source, "@detail", SqlDbType.BigInt, detailId); var value = await source.ExecuteScalarAsync(token); if (value is null || value == DBNull.Value) return false; allowed = Convert.ToDecimal(value); }
        const string sql = """
        SELECT
          COALESCE((SELECT SUM(D.DeliveryQty) FROM dbo.TDARDeliveryNoteDetail D JOIN dbo.TDARDeliveryNote H ON H.DeliveryNoteID=D.DeliveryNoteID WHERE D.QuotationDetailID=@detail AND H.CompanyID=@company AND H.StatusCode=N'CONFIRMED'),0) +
          COALESCE((SELECT SUM(D.Quantity) FROM dbo.TDARTaxInvoiceDetail D JOIN dbo.TDARTaxInvoice H ON H.TaxInvoiceID=D.TaxInvoiceID WHERE D.QuotationDetailID=@detail AND H.CompanyID=@company AND H.StatusCode=N'ISSUED' AND H.TaxInvoiceID<>@current),0)
        """;
        await using var used = new SqlCommand(sql, c, tx); Add(used, "@detail", SqlDbType.BigInt, detailId); Add(used, "@company", SqlDbType.BigInt, CompanyId()); Add(used, "@current", SqlDbType.BigInt, currentInvoiceId);
        return Convert.ToDecimal(await used.ExecuteScalarAsync(token)) + quantity <= allowed;
    }

    private async Task<string> NextCode(SqlConnection c, SqlTransaction tx, CancellationToken token)
    {
        await using var cmd = new SqlCommand("SELECT ISNULL(MAX(TRY_CONVERT(int,RIGHT(TaxInvoiceCode,6))),0)+1 FROM dbo.TDARTaxInvoice WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND TaxInvoiceCode LIKE N'TI%'", c, tx);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); return $"TI{Convert.ToInt32(await cmd.ExecuteScalarAsync(token)):D6}";
    }

    private void BindMovement(SqlCommand cmd, long id, IssueLine line, decimal quantity)
    {
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); Add(cmd, "@item", SqlDbType.BigInt, line.ItemId); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@detail", SqlDbType.BigInt, line.DetailId); Add(cmd, "@qty", SqlDbType.Decimal, Math.Abs(quantity)); Add(cmd, "@user", SqlDbType.BigInt, UserId());
    }

    private async Task<IActionResult> RollbackBadRequest(SqlTransaction tx, CancellationToken token, string message, string description) { await tx.RollbackAsync(token); return BadRequest(new { message, description }); }
    private async Task<IActionResult> RollbackConflict(SqlTransaction tx, CancellationToken token, string message, string description) { await tx.RollbackAsync(token); return Conflict(new { message, description }); }
    private async Task<string?> Scalar(SqlConnection c, SqlTransaction tx, string sql, long id, CancellationToken token) { await using var cmd = new SqlCommand(sql, c, tx); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); return (await cmd.ExecuteScalarAsync(token))?.ToString(); }
    private async Task<List<object>> Rows<T>(SqlConnection c, string sql, CancellationToken token, Func<SqlDataReader, T> map, string? unitGroup = null) where T : class { await using var cmd = new SqlCommand(sql, c); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); if (unitGroup is not null) Add(cmd, "@unitGroup", SqlDbType.NVarChar, unitGroup, 20); var result = new List<object>(); await using var r = await cmd.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) result.Add(map(r)); return result; }
    private static async Task<List<object>> RowsById<T>(SqlConnection c, string sql, long id, CancellationToken token, Func<SqlDataReader, T> map) where T : class { await using var cmd = new SqlCommand(sql, c); Add(cmd, "@id", SqlDbType.BigInt, id); var result = new List<object>(); await using var r = await cmd.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) result.Add(map(r)); return result; }

    private async Task<bool> Can(SqlConnection c, string action, CancellationToken token)
    {
        const string adminSql = "SELECT TOP (1) 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1";
        await using (var admin = new SqlCommand(adminSql, c))
        {
            Add(admin, "@user", SqlDbType.BigInt, UserId());
            Add(admin, "@company", SqlDbType.BigInt, CompanyId());
            if (await admin.ExecuteScalarAsync(token) is not null) return true;
        }

        const string directSql = """
        SELECT TOP (1) 1
        FROM dbo.TDADUserPermission UP
        JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
        WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1
          AND P.IsActive=1 AND P.ActionCode=@action AND P.ScreenCode=@screen
        """;
        await using (var direct = new SqlCommand(directSql, c))
        {
            Add(direct, "@user", SqlDbType.BigInt, UserId()); Add(direct, "@project", SqlDbType.BigInt, ProjectId());
            Add(direct, "@action", SqlDbType.NVarChar, action, 20); Add(direct, "@screen", SqlDbType.NVarChar, ScreenCode, 20);
            if (await direct.ExecuteScalarAsync(token) is not null) return true;
        }

        const string roleSql = """
        SELECT TOP (1) 1
        FROM dbo.TDADUser U
        JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID
        JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID
        JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project
        JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1
        WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND ERG.IsActive=1
          AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
          AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
        """;
        await using var role = new SqlCommand(roleSql, c);
        Add(role, "@user", SqlDbType.BigInt, UserId()); Add(role, "@company", SqlDbType.BigInt, CompanyId());
        Add(role, "@project", SqlDbType.BigInt, ProjectId()); Add(role, "@action", SqlDbType.NVarChar, action, 20); Add(role, "@screen", SqlDbType.NVarChar, ScreenCode, 20);
        return await role.ExecuteScalarAsync(token) is not null;
    }

    private async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private long UserId() => long.TryParse(User.FindFirstValue("user_id"), out var value) ? value : 0;
    private long CompanyId() => long.TryParse(User.FindFirstValue("company_id"), out var value) ? value : 0;
    private long ProjectId() => long.TryParse(User.FindFirstValue("project_id"), out var value) ? value : 0;
    private static string? NormalizeReference(string? value) { var v = (value ?? "NONE").Trim().ToUpperInvariant(); return v is "NONE" or "QUOTATION" or "PREORDER" or "TEMP_RECEIPT" ? v : null; }
    private static string? NormalizeDiscount(string? value) { var v = (value ?? "N").Trim().ToUpperInvariant(); return v is "N" or "P" or "A" ? v : null; }
    private static string? Filter(string? value) => string.IsNullOrWhiteSpace(value) || value.Equals("ALL", StringComparison.OrdinalIgnoreCase) ? null : value.Trim();
    private static string? Text(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetValue(i)?.ToString();
    private static long? Long(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static DateTime? Date(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetDateTime(i);
    private static void Add(SqlCommand cmd, string name, SqlDbType type, object? value, int size = 0) { var p = cmd.Parameters.Add(name, type); if (size > 0) p.Size = size; if (type == SqlDbType.Decimal) { p.Precision = 18; p.Scale = 4; } p.Value = value ?? DBNull.Value; }

    private sealed record CustomerRow(long Id, string Code, string Name, string? Address, string? TaxId, string? PaymentType, int CreditDays);
    private sealed record CustomerSource(long Id, string Code, string Name, string? Address, string? TaxId, string? Contact, string? Phone, string? Email, string? PaymentType, int CreditDays, decimal TaxPercent, decimal DiscountPercent, decimal DiscountAmount);
    private sealed record CalculatedLine(TaxInvoiceLineRequest Request, (string Code, string Name, string Unit) Item, string DiscountType, decimal BeforeDiscount, decimal DiscountAmount, decimal Amount);
    private sealed record IssueLine(long DetailId, long ItemId, decimal Quantity, long? PreOrderDetailId, long? QuotationDetailId);
}
