using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/company/quotations")]
public sealed class QuotationController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private const string ScreenCode = "09003";
    private readonly IConfiguration _configuration = configuration;
    private readonly IWebHostEnvironment _environment = environment;

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        return Ok(new
        {
            view = await Can(c, "VIEW", token),
            create = await Can(c, "CREATE", token),
            edit = await Can(c, "EDIT", token),
            delete = await Can(c, "DELETE", token),
        });
    }

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "VIEW", token)) return Forbid();
        const string sql = """
            SELECT Q.QuotationID,Q.QuoteCode,Q.QuoteDate,Q.CusName,
                   COALESCE(SUM(D.Amount),0) AS TotalAmount,Q.StatusCode
            FROM dbo.TDARQuotation Q
            LEFT JOIN dbo.TDARQuotationDetail D ON D.QuotationID=Q.QuotationID
            WHERE Q.CompanyID=@company AND Q.IsActive=1
            GROUP BY Q.QuotationID,Q.QuoteCode,Q.QuoteDate,Q.CusName,Q.StatusCode
            ORDER BY Q.QuoteDate DESC,Q.QuotationID DESC;
            """;
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
        var rows = new List<object>();
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) rows.Add(new { quotationId = r.GetInt64(0), quoteCode = r.GetString(1), quoteDate = r.GetDateTime(2), customerName = r.GetString(3), totalAmount = r.GetDecimal(4), statusCode = r.GetString(5) });
        return Ok(rows);
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "VIEW", token)) return Forbid();
        var customers = new List<object>();
        await using (var cmd = new SqlCommand("SELECT CustomerID,CusCode,CusShortCode,CusName,CusAddress,Email,TaxID,ContName1,Phone1,Email1,ContName2,Phone2,Email2,PaymentType,CreditDays FROM dbo.TDARCustomer WHERE CompanyID=@company AND IsActive=1 ORDER BY CusCode", c))
        {
            Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) customers.Add(new { customerId = r.GetInt64(0), cusCode = r.GetString(1), shortCode = Text(r, 2), cusName = r.GetString(3), address = Text(r, 4), email = Text(r, 5), taxId = Text(r, 6), contactName1 = Text(r, 7), contactPhone1 = Text(r, 8), contactEmail1 = Text(r, 9), contactName2 = Text(r, 10), contactPhone2 = Text(r, 11), contactEmail2 = Text(r, 12), paymentType = Text(r, 13), creditDays = r.IsDBNull(14) ? (int?)null : r.GetInt32(14) });
        }

        var creditTypes = new List<object>();
        await using (var cmd = new SqlCommand("SELECT Code,Name FROM dbo.TDSTMasterCont WHERE GroupCode=@group ORDER BY Seq,Code", c))
        {
            Add(cmd, "@group", SqlDbType.NVarChar, MasterConstCodes.CustomerPaymentType, 10);
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) creditTypes.Add(new { code = r.GetString(0), name = Text(r, 1) });
        }

        var employees = new List<object>();
        await using (var cmd = new SqlCommand("""
            SELECT E.EmployeeID,E.EmployeeCode,E.FullName,E.NickName,
                   CASE WHEN UE.UserID IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END AS IsCurrent
            FROM dbo.TDADEmployee E
            LEFT JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=E.EmployeeID AND UE.CompanyID=E.CompanyID AND UE.UserID=@user
            WHERE E.CompanyID=@company AND E.IsActive=1
            ORDER BY E.FullName,E.EmployeeID
            """, c))
        {
            Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); Add(cmd, "@user", SqlDbType.BigInt, UserId());
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) employees.Add(new { employeeId = r.GetInt64(0), employeeCode = r.GetString(1), fullName = r.GetString(2), nickName = Text(r, 3), isCurrent = r.GetBoolean(4) });
        }

        var itemRows = new List<ItemLookupRow>();
        await using (var cmd = new SqlCommand("""
            SELECT I.ItemID,I.ItemCode,I.ItemName,
                   COALESCE(CONVERT(nvarchar(200), U.Name), CONVERT(nvarchar(200), I.UnitCode)) AS UnitCode,
                   I.UnitPrice,X.FilePath,X.ImageData
            FROM dbo.TDIVItem I
            OUTER APPLY
            (
                SELECT TOP 1 IMG.FilePath,IMG.ImageData
                FROM dbo.TDIVItemImage IMG
                WHERE IMG.ItemID=I.ItemID AND IMG.IsCover=1 AND IMG.IsActive=1
                ORDER BY IMG.SortOrder,IMG.ItemImageID
            ) X
            LEFT JOIN dbo.TDSTMaster U
              ON U.MasterGroupCode=@unitGroupCode
             AND U.MasterCode=I.UnitCode
             AND U.OwnerType=N'C'
             AND U.OwnerCompanyID=I.CompanyID
            WHERE I.CompanyID=@company AND I.IsActive=1
            ORDER BY I.ItemCode
            """, c))
        {
            Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
            Add(cmd, "@unitGroupCode", SqlDbType.NVarChar, MasterConstCodes.cmsUnit, 10);
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) itemRows.Add(new ItemLookupRow(r.GetInt64(0), r.GetString(1), r.GetString(2), Text(r, 3), r.IsDBNull(4) ? 0m : r.GetDecimal(4), Text(r, 5), r.IsDBNull(6) ? null : (byte[])r[6]));
        }

        var items = new List<object>();
        foreach (var item in itemRows)
            items.Add(new { itemId = item.Id, itemCode = item.Code, itemName = item.Name, unitCode = item.Unit, unitPrice = item.Price, coverImageBase64 = await ReadImageBase64Async(item.FilePath, item.LegacyImage, token) });

        return Ok(new { customers, creditTypes, employees, items });
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "VIEW", token)) return Forbid();

        object? header = null;
        const string headerSql = """
            SELECT QuotationID,QuoteCode,QuoteDate,CustomerID,
                   SalespersonEmployeeID,ContactName,ValidDays,SalesType,
                   PaymentType,CreditDays,VATPercent,DiscountPercent,
                   TaxPercent,StatusCode,Remark
            FROM dbo.TDARQuotation
            WHERE QuotationID=@id AND CompanyID=@company AND IsActive=1;
            """;
        await using (var cmd = new SqlCommand(headerSql, c))
        {
            Add(cmd, "@id", SqlDbType.BigInt, id);
            Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
            await using var r = await cmd.ExecuteReaderAsync(token);
            if (await r.ReadAsync(token))
            {
                header = new
                {
                    quotationId = r.GetInt64(0),
                    quoteCode = r.GetString(1),
                    quoteDate = r.GetDateTime(2),
                    customerId = r.GetInt64(3),
                    salespersonEmployeeId = r.IsDBNull(4) ? (long?)null : r.GetInt64(4),
                    contactName = Text(r, 5),
                    validDays = r.IsDBNull(6) ? 0 : r.GetInt32(6),
                    salesType = Text(r, 7),
                    paymentType = Text(r, 8),
                    creditDays = r.IsDBNull(9) ? 0 : r.GetInt32(9),
                    vatPercent = r.IsDBNull(10) ? 0m : r.GetDecimal(10),
                    discountPercent = r.IsDBNull(11) ? 0m : r.GetDecimal(11),
                    taxPercent = r.IsDBNull(12) ? 0m : r.GetDecimal(12),
                    statusCode = Text(r, 13),
                    remark = Text(r, 14),
                };
            }
        }
        if (header is null)
            return NotFound(new { message = "ไม่พบใบเสนอราคาที่ต้องการแก้ไขในบริษัทนี้" });

        var details = new List<object>();
        const string detailSql = """
            SELECT QuotationDetailID,ItemID,ItemCode,ItemName,UnitCode,
                   Quantity,UnitPrice,DiscountType,DiscountPercent,DiscountAmount
            FROM dbo.TDARQuotationDetail
            WHERE QuotationID=@id
            ORDER BY [LineNo],QuotationDetailID;
            """;
        await using (var cmd = new SqlCommand(detailSql, c))
        {
            Add(cmd, "@id", SqlDbType.BigInt, id);
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token))
            {
                details.Add(new
                {
                    quotationDetailId = r.GetInt64(0),
                    itemId = r.GetInt64(1),
                    itemCode = r.GetString(2),
                    itemName = r.GetString(3),
                    unitCode = Text(r, 4),
                    quantity = r.GetDecimal(5),
                    unitPrice = r.GetDecimal(6),
                    discountType = Text(r, 7) ?? "N",
                    discountPercent = r.IsDBNull(8) ? 0m : r.GetDecimal(8),
                    discountAmount = r.IsDBNull(9) ? 0m : r.GetDecimal(9),
                });
            }
        }
        return Ok(new { header, items = details });
    }

    [HttpPost]
    public async Task<IActionResult> Create(QuotationUpsertRequest request, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "CREATE", token)) return Forbid();
        if (request.CustomerId <= 0 || request.Items.Count == 0) return BadRequest(new { message = "กรุณาเลือกลูกค้าและเพิ่มรายการสินค้าอย่างน้อย 1 รายการ" });
        if (request.VATPercent < 0 || request.VATPercent > 100) return BadRequest(new { message = "VAT ต้องอยู่ระหว่าง 0 ถึง 100" });
        if ((request.DiscountPercent ?? 0) < 0 || (request.DiscountPercent ?? 0) > 100) return BadRequest(new { message = "ส่วนลดท้ายเอกสารต้องอยู่ระหว่าง 0 ถึง 100" });

        await using var tx = await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var customer = await ReadCustomer(c, (SqlTransaction)tx, request.CustomerId, token);
            if (customer is null) return NotFound(new { message = "ไม่พบลูกค้าใน Company นี้" });
            var employee = await ReadEmployee(c, (SqlTransaction)tx, request.SalespersonEmployeeId, token);
            var quoteCode = await NextCode(c, (SqlTransaction)tx, token);
            const string insert = """
                INSERT dbo.TDARQuotation(CompanyID,QuoteCode,QuoteDate,CustomerID,CusCode,CusName,SalespersonUserID,SalespersonEmployeeID,SalespersonName,ContactName,ValidDays,SalesType,PaymentType,CreditDays,VATPercent,TotalAmount,DiscountPercent,DiscountAmount,AmountAfterDiscount,TaxPercent,TaxAmount,NetAmount,StatusCode,Remark,CreatedBy)
                OUTPUT INSERTED.QuotationID
                VALUES(@company,@code,@date,@customer,@cusCode,@cusName,@salesUser,@salesEmployee,@salesName,@contact,@validDays,@salesType,@paymentType,@creditDays,@vat,@total,@discountPercent,@discountAmount,@afterDiscount,@taxPercent,@taxAmount,@netAmount,@status,@remark,@createdBy)
                """;
            long quotationId;
            await using (var cmd = new SqlCommand(insert, c, (SqlTransaction)tx))
            {
                Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); Add(cmd, "@code", SqlDbType.NVarChar, quoteCode, 30); Add(cmd, "@date", SqlDbType.Date, (object?)(request.QuoteDate?.Date) ?? DateTime.UtcNow.Date);
                Add(cmd, "@customer", SqlDbType.BigInt, request.CustomerId); Add(cmd, "@cusCode", SqlDbType.NVarChar, customer.Value.Code, 50); Add(cmd, "@cusName", SqlDbType.NVarChar, customer.Value.Name, 200);
                Add(cmd, "@salesUser", SqlDbType.BigInt, UserId()); Add(cmd, "@salesEmployee", SqlDbType.BigInt, employee?.Id); Add(cmd, "@salesName", SqlDbType.NVarChar, employee?.Name, 200);
                Add(cmd, "@contact", SqlDbType.NVarChar, request.ContactName, 200); Add(cmd, "@validDays", SqlDbType.Int, request.ValidDays); Add(cmd, "@salesType", SqlDbType.NVarChar, request.SalesType, 100); Add(cmd, "@paymentType", SqlDbType.NVarChar, request.PaymentType, 50); Add(cmd, "@creditDays", SqlDbType.Int, request.CreditDays);
                Add(cmd, "@total", SqlDbType.Decimal, request.TotalAmount); Add(cmd, "@discountPercent", SqlDbType.Decimal, request.DiscountPercent); Add(cmd, "@discountAmount", SqlDbType.Decimal, request.DiscountAmount); Add(cmd, "@afterDiscount", SqlDbType.Decimal, request.AmountAfterDiscount); Add(cmd, "@taxPercent", SqlDbType.Decimal, request.TaxPercent); Add(cmd, "@taxAmount", SqlDbType.Decimal, request.TaxAmount); Add(cmd, "@netAmount", SqlDbType.Decimal, request.NetAmount);
                Add(cmd, "@vat", SqlDbType.Decimal, request.VATPercent); Add(cmd, "@status", SqlDbType.NVarChar, string.IsNullOrWhiteSpace(request.StatusCode) ? "DRAFT" : request.StatusCode.Trim().ToUpperInvariant(), 30); Add(cmd, "@remark", SqlDbType.NVarChar, request.Remark, 1000); Add(cmd, "@createdBy", SqlDbType.BigInt, UserId());
                quotationId = Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
            }

            const string detailSql = """
                INSERT dbo.TDARQuotationDetail
                    (QuotationID,[LineNo],ItemID,ItemCode,ItemName,UnitCode,Quantity,UnitPrice,
                     DiscountType,BeforeDiscount,DiscountPercent,DiscountAmount,Amount)
                VALUES
                    (@quote,@line,@item,@code,@name,@unit,@qty,@price,
                     @discountType,@beforeDiscount,@discountPercent,@discountAmount,@amount)
                """;
            var line = 0;
            var calculatedTotal = 0m;
            foreach (var input in request.Items)
            {
                if (input.ItemId <= 0 || input.Quantity <= 0 || input.UnitPrice < 0)
                    return BadRequest(new { message = "ข้อมูลรายการสินค้าไม่ถูกต้อง: จำนวนต้องมากกว่า 0 และราคาต้องไม่ติดลบ" });
                var item = await ReadItem(c, (SqlTransaction)tx, input.ItemId, token);
                if (item is null) return BadRequest(new { message = "พบสินค้าที่ไม่อยู่ใน Company นี้" });

                var discountType = string.IsNullOrWhiteSpace(input.DiscountType)
                    ? (input.DiscountPercent > 0 ? "P" : input.DiscountAmount > 0 ? "A" : "N")
                    : input.DiscountType.Trim().ToUpperInvariant();
                if (discountType is not ("N" or "P" or "A"))
                    return BadRequest(new { message = "รูปแบบส่วนลดต้องเป็น ไม่ลด เปอร์เซ็นต์ หรือจำนวนเงินเท่านั้น" });

                var beforeDiscount = decimal.Round(input.Quantity * input.UnitPrice, 4, MidpointRounding.AwayFromZero);
                var discountPercent = 0m;
                var discountAmount = 0m;
                var discountValue = input.DiscountValue;
                if (discountType == "P")
                {
                    if (discountValue == 0 && input.DiscountPercent > 0) discountValue = input.DiscountPercent;
                    if (discountValue < 0 || discountValue > 100)
                        return BadRequest(new { message = "ส่วนลดเปอร์เซ็นต์ต้องอยู่ระหว่าง 0 ถึง 100" });
                    discountPercent = discountValue;
                    discountAmount = decimal.Round(beforeDiscount * discountPercent / 100m, 4, MidpointRounding.AwayFromZero);
                }
                else if (discountType == "A")
                {
                    if (discountValue == 0 && input.DiscountAmount > 0) discountValue = input.DiscountAmount;
                    if (discountValue < 0 || discountValue > beforeDiscount)
                        return BadRequest(new { message = "ส่วนลดจำนวนเงินต้องไม่ติดลบและต้องไม่เกินยอดก่อนส่วนลด" });
                    discountAmount = decimal.Round(discountValue, 4, MidpointRounding.AwayFromZero);
                    discountPercent = beforeDiscount == 0
                        ? 0
                        : decimal.Round(discountAmount * 100m / beforeDiscount, 4, MidpointRounding.AwayFromZero);
                }

                line++;
                var amount = beforeDiscount - discountAmount;
                calculatedTotal += amount;
                await using var cmd = new SqlCommand(detailSql, c, (SqlTransaction)tx);
                Add(cmd, "@quote", SqlDbType.BigInt, quotationId); Add(cmd, "@line", SqlDbType.Int, line); Add(cmd, "@item", SqlDbType.BigInt, input.ItemId); Add(cmd, "@code", SqlDbType.NVarChar, item.Value.Code, 50); Add(cmd, "@name", SqlDbType.NVarChar, item.Value.Name, 200); Add(cmd, "@unit", SqlDbType.NVarChar, item.Value.Unit, 50); Add(cmd, "@qty", SqlDbType.Decimal, input.Quantity); Add(cmd, "@price", SqlDbType.Decimal, input.UnitPrice);
                Add(cmd, "@discountType", SqlDbType.NVarChar, discountType, 1); Add(cmd, "@beforeDiscount", SqlDbType.Decimal, beforeDiscount); Add(cmd, "@discountPercent", SqlDbType.Decimal, discountPercent); Add(cmd, "@discountAmount", SqlDbType.Decimal, discountAmount); Add(cmd, "@amount", SqlDbType.Decimal, amount);
                await cmd.ExecuteNonQueryAsync(token);
            }

            var documentDiscountPercent = request.DiscountPercent ?? 0m;
            var documentDiscountAmount = decimal.Round(calculatedTotal * documentDiscountPercent / 100m, 4, MidpointRounding.AwayFromZero);
            var calculatedAfterDiscount = calculatedTotal - documentDiscountAmount;
            var calculatedTaxPercent = request.TaxPercent ?? request.VATPercent;
            if (calculatedTaxPercent < 0 || calculatedTaxPercent > 100)
                return BadRequest(new { message = "ภาษีต้องอยู่ระหว่าง 0 ถึง 100" });
            var calculatedTaxAmount = decimal.Round(calculatedAfterDiscount * calculatedTaxPercent / 100m, 4, MidpointRounding.AwayFromZero);
            var calculatedNetAmount = calculatedAfterDiscount + calculatedTaxAmount;

            const string updateSummarySql = """
                UPDATE dbo.TDARQuotation
                   SET TotalAmount=@total,
                       DiscountPercent=@discountPercent,
                       DiscountAmount=@discountAmount,
                       AmountAfterDiscount=@afterDiscount,
                       TaxPercent=@taxPercent,
                       TaxAmount=@taxAmount,
                       NetAmount=@netAmount
                 WHERE QuotationID=@quotationId AND CompanyID=@company
                """;
            await using (var summaryCmd = new SqlCommand(updateSummarySql, c, (SqlTransaction)tx))
            {
                Add(summaryCmd, "@total", SqlDbType.Decimal, calculatedTotal);
                Add(summaryCmd, "@discountPercent", SqlDbType.Decimal, documentDiscountPercent);
                Add(summaryCmd, "@discountAmount", SqlDbType.Decimal, documentDiscountAmount);
                Add(summaryCmd, "@afterDiscount", SqlDbType.Decimal, calculatedAfterDiscount);
                Add(summaryCmd, "@taxPercent", SqlDbType.Decimal, calculatedTaxPercent);
                Add(summaryCmd, "@taxAmount", SqlDbType.Decimal, calculatedTaxAmount);
                Add(summaryCmd, "@netAmount", SqlDbType.Decimal, calculatedNetAmount);
                Add(summaryCmd, "@quotationId", SqlDbType.BigInt, quotationId);
                Add(summaryCmd, "@company", SqlDbType.BigInt, CompanyId());
                await summaryCmd.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return Ok(new { quotationId, quoteCode });
        }
        catch { await tx.RollbackAsync(token); throw; }
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, QuotationUpsertRequest request, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "EDIT", token)) return Forbid();
        if (request.CustomerId <= 0 || request.Items.Count == 0)
            return BadRequest(new { message = "กรุณาเลือกลูกค้าและเพิ่มรายการสินค้าอย่างน้อย 1 รายการ" });
        if (request.VATPercent < 0 || request.VATPercent > 100)
            return BadRequest(new { message = "VAT ต้องอยู่ระหว่าง 0 ถึง 100" });
        if ((request.DiscountPercent ?? 0) < 0 || (request.DiscountPercent ?? 0) > 100)
            return BadRequest(new { message = "ส่วนลดท้ายเอกสารต้องอยู่ระหว่าง 0 ถึง 100" });

        await using var tx = await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            string? quoteCode;
            await using (var currentCmd = new SqlCommand("SELECT QuoteCode FROM dbo.TDARQuotation WITH (UPDLOCK,HOLDLOCK) WHERE QuotationID=@id AND CompanyID=@company AND IsActive=1", c, (SqlTransaction)tx))
            {
                Add(currentCmd, "@id", SqlDbType.BigInt, id);
                Add(currentCmd, "@company", SqlDbType.BigInt, CompanyId());
                quoteCode = (await currentCmd.ExecuteScalarAsync(token))?.ToString();
            }
            if (string.IsNullOrWhiteSpace(quoteCode))
            {
                await tx.RollbackAsync(token);
                return NotFound(new { message = "ไม่พบใบเสนอราคาที่ต้องการแก้ไขในบริษัทนี้" });
            }

            await using (var referenceCmd = new SqlCommand("SELECT COUNT(1) FROM dbo.TDARPreOrder WHERE QuotationID=@id AND CompanyID=@company AND IsActive=1", c, (SqlTransaction)tx))
            {
                Add(referenceCmd, "@id", SqlDbType.BigInt, id);
                Add(referenceCmd, "@company", SqlDbType.BigInt, CompanyId());
                if (Convert.ToInt32(await referenceCmd.ExecuteScalarAsync(token)) > 0)
                {
                    await tx.RollbackAsync(token);
                    return Conflict(new { message = "ใบเสนอราคานี้ถูกนำไปสร้างใบรับจองสินค้าแล้ว จึงไม่อนุญาตให้แก้ไข เพื่อป้องกันข้อมูลเอกสารอ้างอิงไม่ตรงกัน" });
                }
            }

            var customer = await ReadCustomer(c, (SqlTransaction)tx, request.CustomerId, token);
            if (customer is null)
            {
                await tx.RollbackAsync(token);
                return NotFound(new { message = "ไม่พบลูกค้าในบริษัทนี้" });
            }
            var employee = await ReadEmployee(c, (SqlTransaction)tx, request.SalespersonEmployeeId, token);

            const string updateHeaderSql = """
                UPDATE dbo.TDARQuotation
                   SET QuoteDate=@date,
                       CustomerID=@customer,CusCode=@cusCode,CusName=@cusName,
                       SalespersonEmployeeID=@salesEmployee,SalespersonName=@salesName,
                       ContactName=@contact,ValidDays=@validDays,SalesType=@salesType,
                       PaymentType=@paymentType,CreditDays=@creditDays,VATPercent=@vat,
                       StatusCode=CASE WHEN NULLIF(LTRIM(RTRIM(@status)),N'') IS NULL THEN StatusCode ELSE UPPER(@status) END,
                       Remark=@remark,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@updatedBy
                 WHERE QuotationID=@id AND CompanyID=@company AND IsActive=1;
                """;
            await using (var cmd = new SqlCommand(updateHeaderSql, c, (SqlTransaction)tx))
            {
                Add(cmd, "@date", SqlDbType.Date, (object?)(request.QuoteDate?.Date) ?? DateTime.UtcNow.Date);
                Add(cmd, "@customer", SqlDbType.BigInt, request.CustomerId);
                Add(cmd, "@cusCode", SqlDbType.NVarChar, customer.Value.Code, 50);
                Add(cmd, "@cusName", SqlDbType.NVarChar, customer.Value.Name, 200);
                Add(cmd, "@salesEmployee", SqlDbType.BigInt, employee?.Id);
                Add(cmd, "@salesName", SqlDbType.NVarChar, employee?.Name, 200);
                Add(cmd, "@contact", SqlDbType.NVarChar, request.ContactName, 200);
                Add(cmd, "@validDays", SqlDbType.Int, request.ValidDays);
                Add(cmd, "@salesType", SqlDbType.NVarChar, request.SalesType, 100);
                Add(cmd, "@paymentType", SqlDbType.NVarChar, request.PaymentType, 50);
                Add(cmd, "@creditDays", SqlDbType.Int, request.CreditDays);
                Add(cmd, "@vat", SqlDbType.Decimal, request.VATPercent);
                Add(cmd, "@status", SqlDbType.NVarChar, request.StatusCode, 30);
                Add(cmd, "@remark", SqlDbType.NVarChar, request.Remark, 1000);
                Add(cmd, "@updatedBy", SqlDbType.BigInt, UserId());
                Add(cmd, "@id", SqlDbType.BigInt, id);
                Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
                await cmd.ExecuteNonQueryAsync(token);
            }

            await using (var deleteCmd = new SqlCommand("DELETE dbo.TDARQuotationDetail WHERE QuotationID=@id", c, (SqlTransaction)tx))
            {
                Add(deleteCmd, "@id", SqlDbType.BigInt, id);
                await deleteCmd.ExecuteNonQueryAsync(token);
            }

            const string detailSql = """
                INSERT dbo.TDARQuotationDetail
                    (QuotationID,[LineNo],ItemID,ItemCode,ItemName,UnitCode,Quantity,UnitPrice,
                     DiscountType,BeforeDiscount,DiscountPercent,DiscountAmount,Amount)
                VALUES
                    (@quote,@line,@item,@code,@name,@unit,@qty,@price,
                     @discountType,@beforeDiscount,@discountPercent,@discountAmount,@amount)
                """;
            var line = 0;
            var calculatedTotal = 0m;
            foreach (var input in request.Items)
            {
                if (input.ItemId <= 0 || input.Quantity <= 0 || input.UnitPrice < 0)
                {
                    await tx.RollbackAsync(token);
                    return BadRequest(new { message = "ข้อมูลรายการสินค้าไม่ถูกต้อง: จำนวนต้องมากกว่า 0 และราคาต้องไม่ติดลบ" });
                }
                var item = await ReadItem(c, (SqlTransaction)tx, input.ItemId, token);
                if (item is null)
                {
                    await tx.RollbackAsync(token);
                    return BadRequest(new { message = "พบสินค้าที่ไม่ได้อยู่ในบริษัทนี้" });
                }

                var discountType = string.IsNullOrWhiteSpace(input.DiscountType)
                    ? (input.DiscountPercent > 0 ? "P" : input.DiscountAmount > 0 ? "A" : "N")
                    : input.DiscountType.Trim().ToUpperInvariant();
                if (discountType is not ("N" or "P" or "A"))
                {
                    await tx.RollbackAsync(token);
                    return BadRequest(new { message = "รูปแบบส่วนลดต้องเป็น ไม่ลด เปอร์เซ็นต์ หรือจำนวนเงินเท่านั้น" });
                }

                var beforeDiscount = decimal.Round(input.Quantity * input.UnitPrice, 4, MidpointRounding.AwayFromZero);
                var discountPercent = 0m;
                var discountAmount = 0m;
                var discountValue = input.DiscountValue;
                if (discountType == "P")
                {
                    if (discountValue == 0 && input.DiscountPercent > 0) discountValue = input.DiscountPercent;
                    if (discountValue < 0 || discountValue > 100)
                    {
                        await tx.RollbackAsync(token);
                        return BadRequest(new { message = "ส่วนลดเปอร์เซ็นต์ต้องอยู่ระหว่าง 0 ถึง 100" });
                    }
                    discountPercent = discountValue;
                    discountAmount = decimal.Round(beforeDiscount * discountPercent / 100m, 4, MidpointRounding.AwayFromZero);
                }
                else if (discountType == "A")
                {
                    if (discountValue == 0 && input.DiscountAmount > 0) discountValue = input.DiscountAmount;
                    if (discountValue < 0 || discountValue > beforeDiscount)
                    {
                        await tx.RollbackAsync(token);
                        return BadRequest(new { message = "ส่วนลดจำนวนเงินต้องไม่ติดลบและต้องไม่เกินยอดก่อนส่วนลด" });
                    }
                    discountAmount = decimal.Round(discountValue, 4, MidpointRounding.AwayFromZero);
                    discountPercent = beforeDiscount == 0 ? 0 : decimal.Round(discountAmount * 100m / beforeDiscount, 4, MidpointRounding.AwayFromZero);
                }

                line++;
                var amount = beforeDiscount - discountAmount;
                calculatedTotal += amount;
                await using var cmd = new SqlCommand(detailSql, c, (SqlTransaction)tx);
                Add(cmd, "@quote", SqlDbType.BigInt, id);
                Add(cmd, "@line", SqlDbType.Int, line);
                Add(cmd, "@item", SqlDbType.BigInt, input.ItemId);
                Add(cmd, "@code", SqlDbType.NVarChar, item.Value.Code, 50);
                Add(cmd, "@name", SqlDbType.NVarChar, item.Value.Name, 200);
                Add(cmd, "@unit", SqlDbType.NVarChar, item.Value.Unit, 50);
                Add(cmd, "@qty", SqlDbType.Decimal, input.Quantity);
                Add(cmd, "@price", SqlDbType.Decimal, input.UnitPrice);
                Add(cmd, "@discountType", SqlDbType.NVarChar, discountType, 1);
                Add(cmd, "@beforeDiscount", SqlDbType.Decimal, beforeDiscount);
                Add(cmd, "@discountPercent", SqlDbType.Decimal, discountPercent);
                Add(cmd, "@discountAmount", SqlDbType.Decimal, discountAmount);
                Add(cmd, "@amount", SqlDbType.Decimal, amount);
                await cmd.ExecuteNonQueryAsync(token);
            }

            var documentDiscountPercent = request.DiscountPercent ?? 0m;
            var documentDiscountAmount = decimal.Round(calculatedTotal * documentDiscountPercent / 100m, 4, MidpointRounding.AwayFromZero);
            var calculatedAfterDiscount = calculatedTotal - documentDiscountAmount;
            var calculatedTaxPercent = request.TaxPercent ?? request.VATPercent;
            if (calculatedTaxPercent < 0 || calculatedTaxPercent > 100)
            {
                await tx.RollbackAsync(token);
                return BadRequest(new { message = "ภาษีต้องอยู่ระหว่าง 0 ถึง 100" });
            }
            var calculatedTaxAmount = decimal.Round(calculatedAfterDiscount * calculatedTaxPercent / 100m, 4, MidpointRounding.AwayFromZero);
            var calculatedNetAmount = calculatedAfterDiscount + calculatedTaxAmount;

            const string summarySql = """
                UPDATE dbo.TDARQuotation
                   SET TotalAmount=@total,DiscountPercent=@discountPercent,
                       DiscountAmount=@discountAmount,AmountAfterDiscount=@afterDiscount,
                       TaxPercent=@taxPercent,TaxAmount=@taxAmount,NetAmount=@netAmount
                 WHERE QuotationID=@id AND CompanyID=@company;
                """;
            await using (var cmd = new SqlCommand(summarySql, c, (SqlTransaction)tx))
            {
                Add(cmd, "@total", SqlDbType.Decimal, calculatedTotal);
                Add(cmd, "@discountPercent", SqlDbType.Decimal, documentDiscountPercent);
                Add(cmd, "@discountAmount", SqlDbType.Decimal, documentDiscountAmount);
                Add(cmd, "@afterDiscount", SqlDbType.Decimal, calculatedAfterDiscount);
                Add(cmd, "@taxPercent", SqlDbType.Decimal, calculatedTaxPercent);
                Add(cmd, "@taxAmount", SqlDbType.Decimal, calculatedTaxAmount);
                Add(cmd, "@netAmount", SqlDbType.Decimal, calculatedNetAmount);
                Add(cmd, "@id", SqlDbType.BigInt, id);
                Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
                await cmd.ExecuteNonQueryAsync(token);
            }

            await tx.CommitAsync(token);
            return Ok(new { quotationId = id, quoteCode });
        }
        catch
        {
            await tx.RollbackAsync(token);
            throw;
        }
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "DELETE", token)) return Forbid();
        const string sql = "DELETE FROM dbo.TDARQuotation WHERE QuotationID=@id AND CompanyID=@company";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@id", SqlDbType.BigInt, id);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyId());
        if (await cmd.ExecuteNonQueryAsync(token) == 0)
            return NotFound(new { message = "ไม่พบใบเสนอราคาที่ต้องการลบ" });
        return NoContent();
    }

    private async Task<(string Code, string Name)?> ReadCustomer(SqlConnection c, SqlTransaction tx, long id, CancellationToken token)
    { await using var cmd = new SqlCommand("SELECT CusCode,CusName FROM dbo.TDARCustomer WHERE CustomerID=@id AND CompanyID=@company AND IsActive=1", c, tx); Add(cmd,"@id",SqlDbType.BigInt,id); Add(cmd,"@company",SqlDbType.BigInt,CompanyId()); await using var r=await cmd.ExecuteReaderAsync(token); return await r.ReadAsync(token)?(r.GetString(0),r.GetString(1)):null; }
    private async Task<(long Id, string Name)?> ReadEmployee(SqlConnection c, SqlTransaction tx, long? id, CancellationToken token)
    { if (id is null) return null; await using var cmd=new SqlCommand("SELECT EmployeeID,FullName FROM dbo.TDADEmployee WHERE EmployeeID=@id AND CompanyID=@company AND IsActive=1",c,tx); Add(cmd,"@id",SqlDbType.BigInt,id); Add(cmd,"@company",SqlDbType.BigInt,CompanyId()); await using var r=await cmd.ExecuteReaderAsync(token); return await r.ReadAsync(token)?(r.GetInt64(0),r.GetString(1)):null; }
    private async Task<(string Code, string Name, string? Unit)?> ReadItem(SqlConnection c, SqlTransaction tx, long id, CancellationToken token)
    { await using var cmd=new SqlCommand("SELECT ItemCode,ItemName,UnitCode FROM dbo.TDIVItem WHERE ItemID=@id AND CompanyID=@company AND IsActive=1",c,tx); Add(cmd,"@id",SqlDbType.BigInt,id); Add(cmd,"@company",SqlDbType.BigInt,CompanyId()); await using var r=await cmd.ExecuteReaderAsync(token); return await r.ReadAsync(token)?(r.GetString(0),r.GetString(1),Text(r,2)):null; }
    private async Task<string> NextCode(SqlConnection c, SqlTransaction tx, CancellationToken token)
    { await using var cmd=new SqlCommand("SELECT ISNULL(MAX(TRY_CONVERT(int,RIGHT(QuoteCode,6))),0)+1 FROM dbo.TDARQuotation WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND QuoteCode LIKE N'QT%';",c,tx); Add(cmd,"@company",SqlDbType.BigInt,CompanyId()); return $"QT{Convert.ToInt32(await cmd.ExecuteScalarAsync(token)):D6}"; }
    private async Task<bool> Can(SqlConnection c,string action,CancellationToken token){const string sql="SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode=@action AND P.ScreenCode=@screen) OR EXISTS(SELECT 1 FROM dbo.TDADUser U INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END"; await using var cmd=new SqlCommand(sql,c); Add(cmd,"@user",SqlDbType.BigInt,UserId());Add(cmd,"@company",SqlDbType.BigInt,CompanyId());Add(cmd,"@project",SqlDbType.BigInt,ProjectId());Add(cmd,"@action",SqlDbType.NVarChar,action,20);Add(cmd,"@screen",SqlDbType.NVarChar,ScreenCode,20);return (bool)(await cmd.ExecuteScalarAsync(token)??false);}
    private async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private async Task<string?> ReadImageBase64Async(string? relativePath, byte[]? legacyBytes, CancellationToken token)
    {
        if (!string.IsNullOrWhiteSpace(relativePath))
        {
            var root = _environment.WebRootPath;
            if (string.IsNullOrWhiteSpace(root)) root = Path.Combine(_environment.ContentRootPath, "wwwroot");
            var fullPath = Path.GetFullPath(Path.Combine(root, relativePath.Replace('/', Path.DirectorySeparatorChar)));
            var rootPath = Path.GetFullPath(root) + Path.DirectorySeparatorChar;
            if (fullPath.StartsWith(rootPath, StringComparison.OrdinalIgnoreCase) && System.IO.File.Exists(fullPath))
                return Convert.ToBase64String(await System.IO.File.ReadAllBytesAsync(fullPath, token));
        }
        return legacyBytes is null ? null : Convert.ToBase64String(legacyBytes);
    }
    private long UserId()=>long.TryParse(User.FindFirstValue("user_id"),out var v)?v:0; private long CompanyId()=>long.TryParse(User.FindFirstValue("company_id"),out var v)?v:0; private long ProjectId()=>long.TryParse(User.FindFirstValue("project_id"),out var v)?v:0;
    private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetValue(i)?.ToString(); private static void Add(SqlCommand c,string n,SqlDbType t,object? v,int size=0){var p=c.Parameters.Add(n,t);if(size>0)p.Size=size;if(t==SqlDbType.Decimal){p.Precision=18;p.Scale=4;}p.Value=v??DBNull.Value;}
    private sealed record ItemLookupRow(long Id, string Code, string Name, string? Unit, decimal Price, string? FilePath, byte[]? LegacyImage);
}
