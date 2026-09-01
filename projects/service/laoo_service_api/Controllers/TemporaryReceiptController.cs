using System.Data;
using System.Security.Claims;
using LaooServiceApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceApi.Controllers;

[ApiController, Authorize, LaooServiceApi.Security.RequireCompanyFeature("SALES")]
[Route("api/company/temporary-receipts")]
public sealed class TemporaryReceiptController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "09005";
    private static readonly HashSet<string> Statuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "DRAFT", "CONFIRMED", "VOID"
    };
    private readonly IConfiguration _configuration = configuration;

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var connection = await Open(token);
        return Ok(new
        {
            view = await Can(connection, "VIEW", token),
            create = await Can(connection, "CREATE", token),
            edit = await Can(connection, "EDIT", token),
            delete = await Can(connection, "DELETE", token),
        });
    }

    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] string? search,
        [FromQuery] string? status,
        [FromQuery] string? referenceType,
        CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();
        const string sql = """
            SELECT R.TemporaryReceiptID,R.ReceiptCode,R.ReceiptDate,R.CusCode,R.CusName,
                   R.ReceivedAmount,R.StatusCode,
                   CASE WHEN R.PreOrderID IS NOT NULL THEN N'PREORDER'
                        WHEN R.QuotationID IS NOT NULL THEN N'QUOTATION' ELSE N'NONE' END,
                   COALESCE(P.PreOrderCode,Q.QuoteCode,N'') AS ReferenceCode,
                   COALESCE(M.PaymentNames,N'') AS PaymentNames
            FROM dbo.TDARTemporaryReceipt R
            LEFT JOIN dbo.TDARPreOrder P ON P.PreOrderID=R.PreOrderID AND P.CompanyID=R.CompanyID
            LEFT JOIN dbo.TDARQuotation Q ON Q.QuotationID=R.QuotationID AND Q.CompanyID=R.CompanyID
            OUTER APPLY
            (
                SELECT STRING_AGG(CONVERT(nvarchar(max),X.Name),N' | ') AS PaymentNames
                FROM
                (
                    SELECT DISTINCT COALESCE(C.Name,RP.PaymentMethodCode) AS Name
                    FROM dbo.TDARTemporaryReceiptPayment RP
                    LEFT JOIN dbo.TDSTMasterCont C
                      ON C.GroupCode=@paymentGroup AND C.Code=RP.PaymentMethodCode
                    WHERE RP.TemporaryReceiptID=R.TemporaryReceiptID
                ) X
            ) M
            WHERE R.CompanyID=@company AND R.IsActive=1
              AND (@search IS NULL OR R.ReceiptCode LIKE N'%'+@search+N'%'
                   OR R.CusCode LIKE N'%'+@search+N'%'
                   OR R.CusName LIKE N'%'+@search+N'%'
                   OR P.PreOrderCode LIKE N'%'+@search+N'%'
                   OR Q.QuoteCode LIKE N'%'+@search+N'%')
              AND (@status IS NULL OR R.StatusCode=@status)
              AND (@referenceType IS NULL
                   OR (@referenceType=N'NONE' AND R.QuotationID IS NULL AND R.PreOrderID IS NULL)
                   OR (@referenceType=N'QUOTATION' AND R.QuotationID IS NOT NULL)
                   OR (@referenceType=N'PREORDER' AND R.PreOrderID IS NOT NULL))
            ORDER BY R.ReceiptDate DESC,R.TemporaryReceiptID DESC;
            """;
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@company", SqlDbType.BigInt, CompanyId());
        Add(command, "@search", SqlDbType.NVarChar, NullIfEmpty(search), 200);
        Add(command, "@status", SqlDbType.NVarChar, Filter(status), 30);
        Add(command, "@referenceType", SqlDbType.NVarChar, Filter(referenceType), 30);
        Add(command, "@paymentGroup", SqlDbType.NVarChar, MasterConstCodes.ReceiptPaymentMethod, 10);
        var rows = new List<object>();
        await using var reader = await command.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
        {
            rows.Add(new
            {
                temporaryReceiptId = reader.GetInt64(0),
                receiptCode = reader.GetString(1),
                receiptDate = reader.GetDateTime(2),
                customerCode = reader.GetString(3),
                customerName = reader.GetString(4),
                receivedAmount = reader.GetDecimal(5),
                statusCode = reader.GetString(6),
                referenceType = reader.GetString(7),
                referenceCode = reader.GetString(8),
                paymentNames = reader.GetString(9),
            });
        }
        return Ok(rows);
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();
        var customers = await ReadRows(connection, """
            SELECT CustomerID,CusCode,CusName,CusAddress,TaxID,
                   COALESCE(NULLIF(ContName1,N''),NULLIF(ContName2,N''),CusName) AS ContactName
            FROM dbo.TDARCustomer
            WHERE CompanyID=@company AND IsActive=1 ORDER BY CusCode;
            """, token, (r) => new
        {
            customerId = r.GetInt64(0),
            customerCode = r.GetString(1),
            customerName = r.GetString(2),
            address = Text(r, 3),
            taxId = Text(r, 4),
            contactName = Text(r, 5),
        });
        var quotations = await ReadRows(connection, """
            SELECT Q.QuotationID,Q.QuoteCode,Q.QuoteDate,Q.CustomerID,Q.CusCode,Q.CusName,
                   COALESCE(Q.NetAmount,0),
                   COALESCE((SELECT SUM(R.ReceivedAmount) FROM dbo.TDARTemporaryReceipt R
                             WHERE R.CompanyID=Q.CompanyID AND R.QuotationID=Q.QuotationID
                               AND R.IsActive=1 AND R.StatusCode<>N'VOID'),0)
            FROM dbo.TDARQuotation Q
            WHERE Q.CompanyID=@company AND Q.IsActive=1 AND Q.StatusCode<>N'CANCELLED'
            ORDER BY Q.QuoteDate DESC,Q.QuotationID DESC;
            """, token, (r) => new
        {
            quotationId = r.GetInt64(0),
            code = r.GetString(1),
            date = r.GetDateTime(2),
            customerId = r.GetInt64(3),
            customerCode = r.GetString(4),
            customerName = r.GetString(5),
            referenceAmount = r.GetDecimal(6),
            previouslyReceivedAmount = r.GetDecimal(7),
        });
        var preOrders = await ReadRows(connection, """
            SELECT P.PreOrderID,P.PreOrderCode,P.PreOrderDate,P.CustomerID,P.CusCode,P.CusName,
                   P.TotalAmount,
                   COALESCE((SELECT SUM(R.ReceivedAmount) FROM dbo.TDARTemporaryReceipt R
                             WHERE R.CompanyID=P.CompanyID AND R.PreOrderID=P.PreOrderID
                               AND R.IsActive=1 AND R.StatusCode<>N'VOID'),0)
            FROM dbo.TDARPreOrder P
            WHERE P.CompanyID=@company AND P.IsActive=1 AND P.StatusCode<>N'CANCELLED'
            ORDER BY P.PreOrderDate DESC,P.PreOrderID DESC;
            """, token, (r) => new
        {
            preOrderId = r.GetInt64(0),
            code = r.GetString(1),
            date = r.GetDateTime(2),
            customerId = r.GetInt64(3),
            customerCode = r.GetString(4),
            customerName = r.GetString(5),
            referenceAmount = r.GetDecimal(6),
            previouslyReceivedAmount = r.GetDecimal(7),
        });
        var paymentMethods = new List<object>();
        await using (var command = new SqlCommand("SELECT Code,Name FROM dbo.TDSTMasterCont WHERE GroupCode=@group ORDER BY Seq,Code", connection))
        {
            Add(command, "@group", SqlDbType.NVarChar, MasterConstCodes.ReceiptPaymentMethod, 10);
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token)) paymentMethods.Add(new { code = reader.GetString(0), name = reader.GetString(1) });
        }
        return Ok(new { customers, quotations, preOrders, paymentMethods });
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();
        const string sql = """
            SELECT TemporaryReceiptID,ReceiptCode,ReceiptDate,QuotationID,PreOrderID,
                   CustomerID,CusCode,CusName,CusAddress,TaxID,ContactName,ReceivedFrom,
                   ReferenceAmount,PreviouslyReceivedAmount,ReceivedAmount,BalanceAmount,
                   StatusCode,Remark
            FROM dbo.TDARTemporaryReceipt
            WHERE TemporaryReceiptID=@id AND CompanyID=@company AND IsActive=1;
            """;
        object? header = null;
        await using (var command = new SqlCommand(sql, connection))
        {
            Add(command, "@id", SqlDbType.BigInt, id); Add(command, "@company", SqlDbType.BigInt, CompanyId());
            await using var reader = await command.ExecuteReaderAsync(token);
            if (await reader.ReadAsync(token)) header = new
            {
                temporaryReceiptId = reader.GetInt64(0),
                receiptCode = reader.GetString(1),
                receiptDate = reader.GetDateTime(2),
                quotationId = Long(reader, 3),
                preOrderId = Long(reader, 4),
                customerId = reader.GetInt64(5),
                customerCode = reader.GetString(6),
                customerName = reader.GetString(7),
                address = Text(reader, 8),
                taxId = Text(reader, 9),
                contactName = Text(reader, 10),
                receivedFrom = reader.GetString(11),
                referenceAmount = reader.GetDecimal(12),
                previouslyReceivedAmount = reader.GetDecimal(13),
                receivedAmount = reader.GetDecimal(14),
                balanceAmount = reader.GetDecimal(15),
                statusCode = reader.GetString(16),
                remark = Text(reader, 17),
            };
        }
        if (header is null) return NotFound(new { message = "ไม่พบใบเสร็จรับเงินชั่วคราว", description = "เอกสารอาจถูกลบหรือไม่ได้อยู่ในบริษัทของผู้ใช้งาน" });
        var payments = await ReadRows(connection, """
            SELECT TemporaryReceiptPaymentID,[LineNo],PaymentMethodCode,Amount,BankCode,
                   BankAccountName,ReferenceNo,ChequeNo,ChequeDate,Remark
            FROM dbo.TDARTemporaryReceiptPayment
            WHERE TemporaryReceiptID=@id ORDER BY [LineNo];
            """, token, (r) => new
        {
            temporaryReceiptPaymentId = r.GetInt64(0),
            lineNo = r.GetInt32(1),
            paymentMethodCode = r.GetString(2),
            amount = r.GetDecimal(3),
            bankCode = Text(r, 4),
            bankAccountName = Text(r, 5),
            referenceNo = Text(r, 6),
            chequeNo = Text(r, 7),
            chequeDate = r.IsDBNull(8) ? (DateTime?)null : r.GetDateTime(8),
            remark = Text(r, 9),
        }, id);
        return Ok(new { header, payments });
    }

    [HttpPost]
    public Task<IActionResult> Create(TemporaryReceiptUpsertRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, TemporaryReceiptUpsertRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, "DELETE", token)) return Forbid();
        await using var tx = (SqlTransaction)await connection.BeginTransactionAsync(token);
        try
        {
            await using var check = new SqlCommand("SELECT StatusCode FROM dbo.TDARTemporaryReceipt WHERE TemporaryReceiptID=@id AND CompanyID=@company AND IsActive=1", connection, tx);
            Add(check, "@id", SqlDbType.BigInt, id); Add(check, "@company", SqlDbType.BigInt, CompanyId());
            var status = Convert.ToString(await check.ExecuteScalarAsync(token));
            if (status is null) { await tx.RollbackAsync(token); return NotFound(); }
            if (!status.Equals("DRAFT", StringComparison.OrdinalIgnoreCase)) { await tx.RollbackAsync(token); return Conflict(new { message = "ไม่สามารถลบเอกสารได้", description = "ลบได้เฉพาะเอกสารสถานะร่าง เอกสารที่ยืนยันแล้วให้ใช้การยกเลิกเอกสาร" }); }
            await using var link = new SqlCommand("DELETE dbo.TDARDocumentLink WHERE CompanyID=@company AND FromDocumentType=N'TEMP_RECEIPT' AND FromDocumentID=@id", connection, tx);
            Add(link, "@company", SqlDbType.BigInt, CompanyId()); Add(link, "@id", SqlDbType.BigInt, id); await link.ExecuteNonQueryAsync(token);
            await using var delete = new SqlCommand("DELETE dbo.TDARTemporaryReceipt WHERE TemporaryReceiptID=@id AND CompanyID=@company", connection, tx);
            Add(delete, "@id", SqlDbType.BigInt, id); Add(delete, "@company", SqlDbType.BigInt, CompanyId()); await delete.ExecuteNonQueryAsync(token);
            await tx.CommitAsync(token); return NoContent();
        }
        catch (Exception ex) { await tx.RollbackAsync(token); return StatusCode(500, new { message = "ลบใบเสร็จรับเงินชั่วคราวไม่สำเร็จ", description = ex.Message }); }
    }

    private async Task<IActionResult> Save(long? id, TemporaryReceiptUpsertRequest request, CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, id.HasValue ? "EDIT" : "CREATE", token)) return Forbid();
        if (request.CustomerId <= 0) return BadRequest(new { message = "ข้อมูลลูกค้าไม่ครบ", description = "กรุณาเลือกลูกค้า" });
        if (request.QuotationId.HasValue && request.PreOrderId.HasValue) return BadRequest(new { message = "เอกสารอ้างอิงไม่ถูกต้อง", description = "เลือกอ้างอิงได้เพียงใบเสนอราคาหรือใบรับจองอย่างใดอย่างหนึ่ง" });
        if (request.Payments.Count == 0) return BadRequest(new { message = "ยังไม่มีรายการรับเงิน", description = "กรุณาเพิ่มช่องทางรับเงินอย่างน้อย 1 รายการ" });
        if (request.Payments.Any(x => x.Amount <= 0 || string.IsNullOrWhiteSpace(x.PaymentMethodCode))) return BadRequest(new { message = "รายการรับเงินไม่ถูกต้อง", description = "ช่องทางรับเงินต้องมีค่าและจำนวนเงินต้องมากกว่า 0" });
        var received = request.Payments.Sum(x => x.Amount);
        var status = string.IsNullOrWhiteSpace(request.StatusCode) ? "DRAFT" : request.StatusCode.Trim().ToUpperInvariant();
        if (!Statuses.Contains(status)) return BadRequest(new { message = "สถานะเอกสารไม่ถูกต้อง", description = $"ไม่รองรับสถานะ {status}" });

        await using var tx = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var customer = await ReadCustomer(connection, tx, request.CustomerId, token);
            if (customer is null) { await tx.RollbackAsync(token); return BadRequest(new { message = "ไม่พบลูกค้า", description = "ลูกค้าอาจถูกลบหรือไม่ได้อยู่ในบริษัทของผู้ใช้งาน" }); }
            var reference = await ReadReference(connection, tx, request.QuotationId, request.PreOrderId, request.CustomerId, id, token);
            if (reference.Error is not null) { await tx.RollbackAsync(token); return BadRequest(new { message = "เอกสารอ้างอิงไม่ถูกต้อง", description = reference.Error }); }
            if (reference.Amount > 0 && reference.Previous + received > reference.Amount) { await tx.RollbackAsync(token); return BadRequest(new { message = "ยอดรับเงินเกินยอดคงเหลือ", description = $"ยอดเอกสาร {reference.Amount:N2} รับแล้ว {reference.Previous:N2} และกำลังรับ {received:N2}" }); }
            var balance = Math.Max(0, reference.Amount - reference.Previous - received);
            string code; long receiptId;
            if (id.HasValue)
            {
                await using var current = new SqlCommand("SELECT ReceiptCode,StatusCode FROM dbo.TDARTemporaryReceipt WITH(UPDLOCK,HOLDLOCK) WHERE TemporaryReceiptID=@id AND CompanyID=@company AND IsActive=1", connection, tx);
                Add(current, "@id", SqlDbType.BigInt, id.Value); Add(current, "@company", SqlDbType.BigInt, CompanyId());
                await using var reader = await current.ExecuteReaderAsync(token);
                if (!await reader.ReadAsync(token)) { await reader.DisposeAsync(); await tx.RollbackAsync(token); return NotFound(new { message = "ไม่พบใบเสร็จรับเงินชั่วคราว", description = "เอกสารอาจถูกลบหรือไม่ได้อยู่ในบริษัทนี้" }); }
                code = reader.GetString(0); var oldStatus = reader.GetString(1); await reader.DisposeAsync();
                if (oldStatus == "VOID") { await tx.RollbackAsync(token); return Conflict(new { message = "แก้ไขเอกสารไม่ได้", description = "เอกสารถูกยกเลิกแล้ว" }); }
                receiptId = id.Value;
                const string updateSql = """
                    UPDATE dbo.TDARTemporaryReceipt SET ReceiptDate=@date,QuotationID=@quotation,PreOrderID=@preOrder,
                      CustomerID=@customer,CusCode=@cusCode,CusName=@cusName,CusAddress=@address,TaxID=@taxId,
                      ContactName=@contact,ReceivedFrom=@receivedFrom,ReferenceAmount=@referenceAmount,
                      PreviouslyReceivedAmount=@previous,ReceivedAmount=@received,BalanceAmount=@balance,
                      StatusCode=@status,Remark=@remark,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user
                    WHERE TemporaryReceiptID=@id AND CompanyID=@company;
                    DELETE dbo.TDARTemporaryReceiptPayment WHERE TemporaryReceiptID=@id;
                    """;
                await using var update = new SqlCommand(updateSql, connection, tx); BindHeader(update, request, customer, reference, received, balance, status); Add(update, "@id", SqlDbType.BigInt, receiptId); await update.ExecuteNonQueryAsync(token);
            }
            else
            {
                code = await NextCode(connection, tx, token);
                const string insertSql = """
                    INSERT dbo.TDARTemporaryReceipt
                    (CompanyID,ReceiptCode,ReceiptDate,QuotationID,PreOrderID,CustomerID,CusCode,CusName,CusAddress,TaxID,
                     ContactName,ReceivedFrom,ReferenceAmount,PreviouslyReceivedAmount,ReceivedAmount,BalanceAmount,
                     StatusCode,Remark,IsActive,CreatedBy)
                    OUTPUT INSERTED.TemporaryReceiptID
                    VALUES(@company,@code,@date,@quotation,@preOrder,@customer,@cusCode,@cusName,@address,@taxId,
                     @contact,@receivedFrom,@referenceAmount,@previous,@received,@balance,@status,@remark,1,@user);
                    """;
                await using var insert = new SqlCommand(insertSql, connection, tx); BindHeader(insert, request, customer, reference, received, balance, status); Add(insert, "@code", SqlDbType.NVarChar, code, 30); receiptId = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            }
            var line = 0;
            foreach (var payment in request.Payments)
            {
                line++;
                const string paymentSql = """
                    INSERT dbo.TDARTemporaryReceiptPayment
                    (TemporaryReceiptID,[LineNo],PaymentMethodCode,Amount,BankCode,BankAccountName,ReferenceNo,ChequeNo,ChequeDate,Remark)
                    VALUES(@id,@line,@method,@amount,@bank,@account,@reference,@cheque,@chequeDate,@remark);
                    """;
                await using var cmd = new SqlCommand(paymentSql, connection, tx);
                Add(cmd, "@id", SqlDbType.BigInt, receiptId); Add(cmd, "@line", SqlDbType.Int, line); Add(cmd, "@method", SqlDbType.NVarChar, payment.PaymentMethodCode!.Trim(), 30); Add(cmd, "@amount", SqlDbType.Decimal, payment.Amount);
                Add(cmd, "@bank", SqlDbType.NVarChar, NullIfEmpty(payment.BankCode), 30); Add(cmd, "@account", SqlDbType.NVarChar, NullIfEmpty(payment.BankAccountName), 200); Add(cmd, "@reference", SqlDbType.NVarChar, NullIfEmpty(payment.ReferenceNo), 100); Add(cmd, "@cheque", SqlDbType.NVarChar, NullIfEmpty(payment.ChequeNo), 100); Add(cmd, "@chequeDate", SqlDbType.Date, payment.ChequeDate?.Date); Add(cmd, "@remark", SqlDbType.NVarChar, NullIfEmpty(payment.Remark), 500); await cmd.ExecuteNonQueryAsync(token);
            }
            await using (var clear = new SqlCommand("DELETE dbo.TDARDocumentLink WHERE CompanyID=@company AND FromDocumentType=N'TEMP_RECEIPT' AND FromDocumentID=@id", connection, tx)) { Add(clear, "@company", SqlDbType.BigInt, CompanyId()); Add(clear, "@id", SqlDbType.BigInt, receiptId); await clear.ExecuteNonQueryAsync(token); }
            if (request.QuotationId.HasValue || request.PreOrderId.HasValue)
            {
                const string linkSql = """
                    INSERT dbo.TDARDocumentLink(CompanyID,FromDocumentType,FromDocumentID,ToDocumentType,ToDocumentID,LinkType,LinkDescription,CreatedBy)
                    VALUES(@company,N'TEMP_RECEIPT',@id,@type,@target,N'PAYMENT',N'รับเงินชั่วคราว',@user);
                    """;
                await using var link = new SqlCommand(linkSql, connection, tx); Add(link, "@company", SqlDbType.BigInt, CompanyId()); Add(link, "@id", SqlDbType.BigInt, receiptId); Add(link, "@type", SqlDbType.NVarChar, request.PreOrderId.HasValue ? "PREORDER" : "QUOTATION", 30); Add(link, "@target", SqlDbType.BigInt, (object?)request.PreOrderId ?? request.QuotationId); Add(link, "@user", SqlDbType.BigInt, UserId()); await link.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token); return Ok(new { temporaryReceiptId = receiptId, receiptCode = code, receivedAmount = received, balanceAmount = balance });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { await tx.RollbackAsync(token); return Conflict(new { message = "เลขที่เอกสารซ้ำ", description = "มีการสร้างเอกสารพร้อมกัน กรุณากดบันทึกใหม่" }); }
        catch (Exception ex) { await tx.RollbackAsync(token); return StatusCode(500, new { message = "บันทึกใบเสร็จรับเงินชั่วคราวไม่สำเร็จ", description = ex.Message }); }
    }

    private void BindHeader(SqlCommand command, TemporaryReceiptUpsertRequest request, CustomerSnapshot customer, ReferenceSnapshot reference, decimal received, decimal balance, string status)
    {
        Add(command, "@company", SqlDbType.BigInt, CompanyId()); Add(command, "@date", SqlDbType.Date, request.ReceiptDate?.Date ?? DateTime.UtcNow.Date); Add(command, "@quotation", SqlDbType.BigInt, request.QuotationId); Add(command, "@preOrder", SqlDbType.BigInt, request.PreOrderId); Add(command, "@customer", SqlDbType.BigInt, customer.Id); Add(command, "@cusCode", SqlDbType.NVarChar, customer.Code, 50); Add(command, "@cusName", SqlDbType.NVarChar, customer.Name, 200); Add(command, "@address", SqlDbType.NVarChar, customer.Address, 1000); Add(command, "@taxId", SqlDbType.NVarChar, customer.TaxId, 30); Add(command, "@contact", SqlDbType.NVarChar, NullIfEmpty(request.ContactName) ?? customer.ContactName, 200); Add(command, "@receivedFrom", SqlDbType.NVarChar, NullIfEmpty(request.ReceivedFrom) ?? customer.Name, 200); Add(command, "@referenceAmount", SqlDbType.Decimal, reference.Amount); Add(command, "@previous", SqlDbType.Decimal, reference.Previous); Add(command, "@received", SqlDbType.Decimal, received); Add(command, "@balance", SqlDbType.Decimal, balance); Add(command, "@status", SqlDbType.NVarChar, status, 30); Add(command, "@remark", SqlDbType.NVarChar, NullIfEmpty(request.Remark), 1000); Add(command, "@user", SqlDbType.BigInt, UserId());
    }

    private async Task<CustomerSnapshot?> ReadCustomer(SqlConnection c, SqlTransaction tx, long id, CancellationToken token)
    {
        await using var cmd = new SqlCommand("SELECT CustomerID,CusCode,CusName,CusAddress,TaxID,COALESCE(NULLIF(ContName1,N''),NULLIF(ContName2,N''),CusName) FROM dbo.TDARCustomer WHERE CustomerID=@id AND CompanyID=@company AND IsActive=1", c, tx); Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(token); return await r.ReadAsync(token) ? new(r.GetInt64(0), r.GetString(1), r.GetString(2), Text(r, 3), Text(r, 4), Text(r, 5)) : null;
    }

    private async Task<ReferenceSnapshot> ReadReference(SqlConnection c, SqlTransaction tx, long? quotationId, long? preOrderId, long customerId, long? currentId, CancellationToken token)
    {
        if (!quotationId.HasValue && !preOrderId.HasValue) return new(0, 0, null);
        var table = preOrderId.HasValue ? "TDARPreOrder" : "TDARQuotation"; var idColumn = preOrderId.HasValue ? "PreOrderID" : "QuotationID"; var amountColumn = preOrderId.HasValue ? "TotalAmount" : "COALESCE(NetAmount,0)"; var id = preOrderId ?? quotationId!.Value; var refColumn = preOrderId.HasValue ? "PreOrderID" : "QuotationID";
        var sql = $"SELECT CustomerID,{amountColumn} FROM dbo.{table} WHERE {idColumn}=@id AND CompanyID=@company AND IsActive=1";
        long sourceCustomer; decimal amount;
        await using (var cmd = new SqlCommand(sql, c, tx)) { Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); await using var r = await cmd.ExecuteReaderAsync(token); if (!await r.ReadAsync(token)) return new(0, 0, "ไม่พบเอกสารอ้างอิงในบริษัทนี้"); sourceCustomer = r.GetInt64(0); amount = r.IsDBNull(1) ? 0 : r.GetDecimal(1); }
        if (sourceCustomer != customerId) return new(0, 0, "ลูกค้าที่เลือกไม่ตรงกับเอกสารอ้างอิง");
        var sumSql = $"SELECT COALESCE(SUM(ReceivedAmount),0) FROM dbo.TDARTemporaryReceipt WHERE CompanyID=@company AND {refColumn}=@source AND IsActive=1 AND StatusCode<>N'VOID' AND (@current IS NULL OR TemporaryReceiptID<>@current)";
        await using var sum = new SqlCommand(sumSql, c, tx); Add(sum, "@company", SqlDbType.BigInt, CompanyId()); Add(sum, "@source", SqlDbType.BigInt, id); Add(sum, "@current", SqlDbType.BigInt, currentId); return new(amount, Convert.ToDecimal(await sum.ExecuteScalarAsync(token)), null);
    }

    private async Task<string> NextCode(SqlConnection c, SqlTransaction tx, CancellationToken token) { await using var cmd = new SqlCommand("SELECT ISNULL(MAX(TRY_CONVERT(int,RIGHT(ReceiptCode,6))),0)+1 FROM dbo.TDARTemporaryReceipt WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND ReceiptCode LIKE N'TR%'", c, tx); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); return $"TR{Convert.ToInt32(await cmd.ExecuteScalarAsync(token)):D6}"; }

    private async Task<List<object>> ReadRows<T>(SqlConnection c, string sql, CancellationToken token, Func<SqlDataReader, T> map, long? id = null) where T : class
    { await using var cmd = new SqlCommand(sql, c); Add(cmd, id.HasValue ? "@id" : "@company", SqlDbType.BigInt, id ?? CompanyId()); var rows = new List<object>(); await using var r = await cmd.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) rows.Add(map(r)); return rows; }

    private async Task<bool> Can(SqlConnection connection, string action, CancellationToken token)
    {
        const string sql = """
            SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1)
            OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode=@action AND P.ScreenCode=@screen)
            OR EXISTS(SELECT 1 FROM dbo.TDADUser U INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND(ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END;
            """;
        await using var cmd = new SqlCommand(sql, connection); Add(cmd, "@user", SqlDbType.BigInt, UserId()); Add(cmd, "@company", SqlDbType.BigInt, CompanyId()); Add(cmd, "@project", SqlDbType.BigInt, ProjectId()); Add(cmd, "@action", SqlDbType.NVarChar, action, 20); Add(cmd, "@screen", SqlDbType.NVarChar, ScreenCode, 20); return (bool)(await cmd.ExecuteScalarAsync(token) ?? false);
    }

    private async Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private long UserId() => long.TryParse(User.FindFirstValue("user_id"), out var v) ? v : 0;
    private long CompanyId() => long.TryParse(User.FindFirstValue("company_id"), out var v) ? v : 0;
    private long ProjectId() => long.TryParse(User.FindFirstValue("project_id"), out var v) ? v : 0;
    private static long? Long(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetInt64(i);
    private static string? Text(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetValue(i)?.ToString();
    private static string? NullIfEmpty(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static string? Filter(string? value) => string.IsNullOrWhiteSpace(value) || value.Equals("ALL", StringComparison.OrdinalIgnoreCase) ? null : value.Trim().ToUpperInvariant();
    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0) { var p = command.Parameters.Add(name, type); if (size > 0) p.Size = size; if (type == SqlDbType.Decimal) { p.Precision = 18; p.Scale = 4; } p.Value = value ?? DBNull.Value; }
    private sealed record CustomerSnapshot(long Id, string Code, string Name, string? Address, string? TaxId, string? ContactName);
    private sealed record ReferenceSnapshot(decimal Amount, decimal Previous, string? Error);
}
