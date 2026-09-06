using System.Data;
using System.Security.Claims;
using LaooServiceApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceApi.Controllers;

[ApiController, Authorize, LaooServiceApi.Security.RequireCompanyFeature("SALES")]
[Route("api/company/pre-orders")]
public sealed class PreOrderController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "09004";
    private static readonly HashSet<string> HeaderStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "DRAFT", "CONFIRMED", "WAITING_STOCK", "PARTIAL_STOCK",
        "READY", "DELIVERED", "CANCELLED", "CLOSED"
    };
    private static readonly HashSet<string> DetailStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "WAITING_STOCK", "PARTIAL_STOCK", "READY", "DELIVERED", "CANCELLED", "CLOSED"
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
        CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();

        const string sql = """
            SELECT P.PreOrderID,P.PreOrderCode,P.PreOrderDate,P.ExpectedDate,
                   P.CusCode,P.CusName,P.TotalAmount,P.DepositAmount,
                   P.PaidAmount,P.BalanceAmount,P.StatusCode,P.QuotationID,
                   Q.QuoteCode
            FROM dbo.TDARPreOrder P
            INNER JOIN dbo.TDARQuotation Q
              ON Q.QuotationID=P.QuotationID AND Q.CompanyID=P.CompanyID
            WHERE P.CompanyID=@company AND P.IsActive=1
              AND (@search IS NULL OR P.PreOrderCode LIKE N'%'+@search+N'%'
                   OR P.CusCode LIKE N'%'+@search+N'%'
                   OR P.CusName LIKE N'%'+@search+N'%'
                   OR Q.QuoteCode LIKE N'%'+@search+N'%')
              AND (@status IS NULL OR P.StatusCode=@status)
            ORDER BY P.PreOrderDate DESC,P.PreOrderID DESC;
            """;
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@company", SqlDbType.BigInt, CompanyId());
        Add(command, "@search", SqlDbType.NVarChar, NullIfEmpty(search), 200);
        Add(command, "@status", SqlDbType.NVarChar, NullIfEmpty(status)?.ToUpperInvariant(), 30);
        var result = new List<object>();
        await using var reader = await command.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
        {
            result.Add(new
            {
                preOrderId = reader.GetInt64(0),
                preOrderCode = reader.GetString(1),
                preOrderDate = reader.GetDateTime(2),
                expectedDate = reader.IsDBNull(3) ? (DateTime?)null : reader.GetDateTime(3),
                customerCode = reader.GetString(4),
                customerName = reader.GetString(5),
                totalAmount = reader.GetDecimal(6),
                depositAmount = reader.GetDecimal(7),
                paidAmount = reader.GetDecimal(8),
                balanceAmount = reader.GetDecimal(9),
                statusCode = reader.GetString(10),
                quotationId = reader.GetInt64(11),
                quoteCode = reader.GetString(12),
            });
        }
        return Ok(result);
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();

        var quotations = new List<object>();
        const string quotationSql = """
            SELECT Q.QuotationID,Q.QuoteCode,Q.QuoteDate,Q.CustomerID,
                   Q.CusCode,Q.CusName,Q.ContactName,Q.NetAmount
            FROM dbo.TDARQuotation Q
            WHERE Q.CompanyID=@company AND Q.IsActive=1
              AND UPPER(ISNULL(Q.StatusCode,N'DRAFT'))<>N'CANCELLED'
            ORDER BY Q.QuoteDate DESC,Q.QuotationID DESC;
            """;
        await using (var command = new SqlCommand(quotationSql, connection))
        {
            Add(command, "@company", SqlDbType.BigInt, CompanyId());
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token))
            {
                quotations.Add(new
                {
                    quotationId = reader.GetInt64(0),
                    quoteCode = reader.GetString(1),
                    quoteDate = reader.GetDateTime(2),
                    customerId = reader.GetInt64(3),
                    customerCode = reader.GetString(4),
                    customerName = reader.GetString(5),
                    contactName = Text(reader, 6),
                    netAmount = reader.IsDBNull(7) ? 0m : reader.GetDecimal(7),
                });
            }
        }

        var items = new List<object>();
        const string itemSql = """
            SELECT I.ItemID,I.ItemCode,I.ItemName,I.UnitCode,I.UnitPrice,
                   COALESCE(CONVERT(nvarchar(200),U.Name),CONVERT(nvarchar(200),I.UnitCode)) AS UnitName
            FROM dbo.TDIVItem I
            LEFT JOIN dbo.TDSTMaster U
              ON U.MasterGroupCode=@unitGroupCode
             AND U.MasterCode=I.UnitCode
             AND U.OwnerType=N'C'
             AND U.OwnerCompanyID=I.CompanyID
            WHERE I.CompanyID=@company AND I.IsActive=1
            ORDER BY I.ItemCode;
            """;
        await using (var command = new SqlCommand(itemSql, connection))
        {
            Add(command, "@company", SqlDbType.BigInt, CompanyId());
            Add(command, "@unitGroupCode", SqlDbType.NVarChar, MasterConstCodes.cmsUnit, 10);
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token))
            {
                items.Add(new
                {
                    itemId = reader.GetInt64(0),
                    itemCode = reader.GetString(1),
                    itemName = reader.GetString(2),
                    unitCode = Text(reader, 3),
                    unitPrice = reader.IsDBNull(4) ? 0m : reader.GetDecimal(4),
                    unitName = Text(reader, 5),
                });
            }
        }

        return Ok(new { quotations, items, statuses = HeaderStatuses.OrderBy(x => x) });
    }

    [HttpGet("quotation/{quotationId:long}")]
    public async Task<IActionResult> Quotation(long quotationId, CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();
        var header = await ReadQuotationHeader(connection, null, quotationId, token);
        if (header is null)
            return NotFound(new { message = "ไม่พบใบเสนอราคา", description = "ใบเสนอราคาอาจถูกลบหรือไม่ได้อยู่ในบริษัทของผู้ใช้งาน" });

        const string sql = """
            SELECT D.QuotationDetailID,D.ItemID,D.ItemCode,D.ItemName,D.UnitCode,
                   COALESCE(CONVERT(nvarchar(200),U.Name),CONVERT(nvarchar(200),D.UnitCode)) AS UnitName,
                   D.Quantity,D.UnitPrice,D.DiscountType,D.DiscountPercent,D.DiscountAmount,D.Amount
            FROM dbo.TDARQuotationDetail D
            INNER JOIN dbo.TDARQuotation Q ON Q.QuotationID=D.QuotationID
            LEFT JOIN dbo.TDSTMaster U
              ON U.MasterGroupCode=@unitGroupCode
             AND U.MasterCode=D.UnitCode
             AND U.OwnerType=N'C'
             AND U.OwnerCompanyID=Q.CompanyID
            WHERE D.QuotationID=@quotation AND Q.CompanyID=@company
            ORDER BY D.[LineNo],D.QuotationDetailID;
            """;
        var lines = new List<object>();
        await using (var command = new SqlCommand(sql, connection))
        {
            Add(command, "@quotation", SqlDbType.BigInt, quotationId);
            Add(command, "@company", SqlDbType.BigInt, CompanyId());
            Add(command, "@unitGroupCode", SqlDbType.NVarChar, MasterConstCodes.cmsUnit, 10);
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token)) lines.Add(ReadLine(reader, fromQuotation: true));
        }
        return Ok(new { quotation = header, items = lines });
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();
        const string sql = """
            SELECT P.PreOrderID,P.PreOrderCode,P.PreOrderDate,P.ExpectedDate,
                   P.QuotationID,Q.QuoteCode,P.CustomerID,P.CusCode,P.CusName,
                   C.CusAddress,C.Email,P.ContactName,P.ContactPhone,
                   P.TotalAmount,P.DepositAmount,P.PaidAmount,P.BalanceAmount,
                   P.StatusCode,P.Remark
            FROM dbo.TDARPreOrder P
            INNER JOIN dbo.TDARQuotation Q ON Q.QuotationID=P.QuotationID AND Q.CompanyID=P.CompanyID
            LEFT JOIN dbo.TDARCustomer C ON C.CustomerID=P.CustomerID AND C.CompanyID=P.CompanyID
            WHERE P.PreOrderID=@id AND P.CompanyID=@company AND P.IsActive=1;
            """;
        object? header = null;
        await using (var command = new SqlCommand(sql, connection))
        {
            Add(command, "@id", SqlDbType.BigInt, id);
            Add(command, "@company", SqlDbType.BigInt, CompanyId());
            await using var reader = await command.ExecuteReaderAsync(token);
            if (await reader.ReadAsync(token))
            {
                header = new
                {
                    preOrderId = reader.GetInt64(0), preOrderCode = reader.GetString(1),
                    preOrderDate = reader.GetDateTime(2), expectedDate = reader.IsDBNull(3) ? (DateTime?)null : reader.GetDateTime(3),
                    quotationId = reader.GetInt64(4), quoteCode = reader.GetString(5), customerId = reader.GetInt64(6),
                    customerCode = reader.GetString(7), customerName = reader.GetString(8), customerAddress = Text(reader, 9),
                    customerEmail = Text(reader, 10), contactName = Text(reader, 11), contactPhone = Text(reader, 12),
                    totalAmount = reader.GetDecimal(13), depositAmount = reader.GetDecimal(14), paidAmount = reader.GetDecimal(15),
                    balanceAmount = reader.GetDecimal(16), statusCode = reader.GetString(17), remark = Text(reader, 18),
                };
            }
        }
        if (header is null)
            return NotFound(new { message = "ไม่พบใบรับจองสินค้า", description = "รายการอาจถูกลบหรือไม่ได้อยู่ในบริษัทของผู้ใช้งาน" });

        const string detailSql = """
            SELECT D.PreOrderDetailID,D.ItemID,D.ItemCode,D.ItemName,D.UnitCode,
                   COALESCE(CONVERT(nvarchar(200),U.Name),CONVERT(nvarchar(200),D.UnitCode)) AS UnitName,
                   D.Quantity,D.UnitPrice,D.DiscountType,D.DiscountPercent,D.DiscountAmount,D.Amount,
                   D.AllocatedQty,D.DeliveredQty,D.StatusCode,D.Remark,D.QuotationDetailID
            FROM dbo.TDARPreOrderDetail D
            INNER JOIN dbo.TDARPreOrder P ON P.PreOrderID=D.PreOrderID
            LEFT JOIN dbo.TDSTMaster U
              ON U.MasterGroupCode=@unitGroupCode
             AND U.MasterCode=D.UnitCode
             AND U.OwnerType=N'C'
             AND U.OwnerCompanyID=P.CompanyID
            WHERE D.PreOrderID=@id AND P.CompanyID=@company
            ORDER BY D.[LineNo],D.PreOrderDetailID;
            """;
        var items = new List<object>();
        await using (var command = new SqlCommand(detailSql, connection))
        {
            Add(command, "@id", SqlDbType.BigInt, id);
            Add(command, "@company", SqlDbType.BigInt, CompanyId());
            Add(command, "@unitGroupCode", SqlDbType.NVarChar, MasterConstCodes.cmsUnit, 10);
            await using var reader = await command.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token)) items.Add(ReadLine(reader, fromQuotation: false));
        }
        return Ok(new { header, items });
    }

    [HttpPost]
    public Task<IActionResult> Create(PreOrderUpsertRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, PreOrderUpsertRequest request, CancellationToken token) => Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, "DELETE", token)) return Forbid();
        try
        {
            await using var command = new SqlCommand("DELETE dbo.TDARPreOrder WHERE PreOrderID=@id AND CompanyID=@company", connection);
            Add(command, "@id", SqlDbType.BigInt, id);
            Add(command, "@company", SqlDbType.BigInt, CompanyId());
            if (await command.ExecuteNonQueryAsync(token) == 0)
                return NotFound(new { message = "ไม่พบใบรับจองสินค้า", description = "ไม่พบข้อมูลที่ต้องการลบในบริษัทนี้" });
            return NoContent();
        }
        catch (SqlException exception) when (exception.Number == 547)
        {
            return Conflict(new { message = "ไม่สามารถลบใบรับจองสินค้าได้", description = "เอกสารนี้ถูกอ้างอิงโดยเอกสารอื่น กรุณายกเลิกเอกสารแทนการลบ" });
        }
    }

    private async Task<IActionResult> Save(long? id, PreOrderUpsertRequest request, CancellationToken token)
    {
        await using var connection = await Open(token);
        var action = id.HasValue ? "EDIT" : "CREATE";
        if (!await Can(connection, action, token)) return Forbid();
        if (request.QuotationId <= 0 || request.Items.Count == 0)
            return BadRequest(new { message = "ข้อมูลใบรับจองไม่ครบ", description = "กรุณาเลือกใบเสนอราคาและเพิ่มสินค้าอย่างน้อย 1 รายการ" });
        if (request.DepositAmount < 0 || request.PaidAmount < 0)
            return BadRequest(new { message = "ยอดเงินไม่ถูกต้อง", description = "เงินมัดจำและยอดชำระต้องไม่ติดลบ" });

        var status = string.IsNullOrWhiteSpace(request.StatusCode) ? "DRAFT" : request.StatusCode.Trim().ToUpperInvariant();
        if (!HeaderStatuses.Contains(status))
            return BadRequest(new { message = "สถานะเอกสารไม่ถูกต้อง", description = $"ไม่รองรับสถานะ {status}" });

        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var quotation = await ReadQuotationHeader(connection, transaction, request.QuotationId, token);
            if (quotation is null)
            {
                await transaction.RollbackAsync(token);
                return BadRequest(new { message = "ไม่พบใบเสนอราคา", description = "กรุณาเลือกใบเสนอราคาที่อยู่ในบริษัทเดียวกันและยังใช้งานอยู่" });
            }

            string preOrderCode;
            long preOrderId;
            if (id.HasValue)
            {
                const string currentSql = "SELECT PreOrderCode FROM dbo.TDARPreOrder WITH (UPDLOCK,HOLDLOCK) WHERE PreOrderID=@id AND CompanyID=@company AND IsActive=1";
                await using var current = new SqlCommand(currentSql, connection, transaction);
                Add(current, "@id", SqlDbType.BigInt, id.Value);
                Add(current, "@company", SqlDbType.BigInt, CompanyId());
                var value = await current.ExecuteScalarAsync(token);
                if (value is null)
                {
                    await transaction.RollbackAsync(token);
                    return NotFound(new { message = "ไม่พบใบรับจองสินค้า", description = "รายการอาจถูกลบหรือไม่ได้อยู่ในบริษัทของผู้ใช้งาน" });
                }
                preOrderId = id.Value;
                preOrderCode = Convert.ToString(value) ?? string.Empty;
            }
            else
            {
                preOrderCode = await NextCode(connection, transaction, token);
                const string insertSql = """
                    INSERT dbo.TDARPreOrder
                        (CompanyID,PreOrderCode,PreOrderDate,QuotationID,CustomerID,CusCode,CusName,
                         ContactName,ContactPhone,ExpectedDate,TotalAmount,DepositAmount,PaidAmount,
                         BalanceAmount,StatusCode,Remark,IsActive,CreatedBy)
                    OUTPUT INSERTED.PreOrderID
                    VALUES
                        (@company,@code,@date,@quotation,@customer,@cusCode,@cusName,
                         @contact,@phone,@expected,0,@deposit,@paid,0,@status,@remark,1,@user);
                    """;
                await using var insert = new SqlCommand(insertSql, connection, transaction);
                BindHeader(insert, request, quotation, preOrderCode, status);
                preOrderId = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            }

            if (id.HasValue)
            {
                const string updateSql = """
                    UPDATE dbo.TDARPreOrder
                       SET PreOrderDate=@date,QuotationID=@quotation,CustomerID=@customer,
                           CusCode=@cusCode,CusName=@cusName,ContactName=@contact,
                           ContactPhone=@phone,ExpectedDate=@expected,DepositAmount=@deposit,
                           PaidAmount=@paid,StatusCode=@status,Remark=@remark,
                           UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user
                     WHERE PreOrderID=@id AND CompanyID=@company AND IsActive=1;
                    DELETE dbo.TDARPreOrderDetail WHERE PreOrderID=@id;
                    """;
                await using var update = new SqlCommand(updateSql, connection, transaction);
                BindHeader(update, request, quotation, preOrderCode, status);
                Add(update, "@id", SqlDbType.BigInt, preOrderId);
                await update.ExecuteNonQueryAsync(token);
            }

            var total = 0m;
            var lineNo = 0;
            foreach (var line in request.Items)
            {
                var validation = await ValidateLine(connection, transaction, request.QuotationId, line, token);
                if (validation.Error is not null)
                {
                    await transaction.RollbackAsync(token);
                    return BadRequest(new { message = "รายการสินค้าไม่ถูกต้อง", description = validation.Error });
                }
                var values = CalculateLine(line);
                if (values.Error is not null)
                {
                    await transaction.RollbackAsync(token);
                    return BadRequest(new { message = "รายการสินค้าไม่ถูกต้อง", description = values.Error });
                }
                lineNo++;
                total += values.Amount;
                const string detailSql = """
                    INSERT dbo.TDARPreOrderDetail
                        (PreOrderID,[LineNo],QuotationDetailID,ItemID,ItemCode,ItemName,UnitCode,
                         Quantity,AllocatedQty,DeliveredQty,UnitPrice,DiscountType,BeforeDiscount,
                         DiscountPercent,DiscountAmount,Amount,StatusCode,Remark)
                    VALUES
                        (@preOrder,@line,@quotationDetail,@item,@itemCode,@itemName,@unit,
                         @quantity,@allocated,@delivered,@price,@discountType,@beforeDiscount,
                         @discountPercent,@discountAmount,@amount,@status,@remark);
                    """;
                await using var detail = new SqlCommand(detailSql, connection, transaction);
                Add(detail, "@preOrder", SqlDbType.BigInt, preOrderId);
                Add(detail, "@line", SqlDbType.Int, lineNo);
                Add(detail, "@quotationDetail", SqlDbType.BigInt, line.QuotationDetailId);
                Add(detail, "@item", SqlDbType.BigInt, line.ItemId);
                Add(detail, "@itemCode", SqlDbType.NVarChar, validation.Item!.Code, 50);
                Add(detail, "@itemName", SqlDbType.NVarChar, validation.Item.Name, 200);
                Add(detail, "@unit", SqlDbType.NVarChar, validation.Item.Unit, 50);
                Add(detail, "@quantity", SqlDbType.Decimal, line.Quantity);
                Add(detail, "@allocated", SqlDbType.Decimal, line.AllocatedQty);
                Add(detail, "@delivered", SqlDbType.Decimal, line.DeliveredQty);
                Add(detail, "@price", SqlDbType.Decimal, line.UnitPrice);
                Add(detail, "@discountType", SqlDbType.NVarChar, values.DiscountType, 1);
                Add(detail, "@beforeDiscount", SqlDbType.Decimal, values.BeforeDiscount);
                Add(detail, "@discountPercent", SqlDbType.Decimal, values.DiscountPercent);
                Add(detail, "@discountAmount", SqlDbType.Decimal, values.DiscountAmount);
                Add(detail, "@amount", SqlDbType.Decimal, values.Amount);
                Add(detail, "@status", SqlDbType.NVarChar, validation.Status, 30);
                Add(detail, "@remark", SqlDbType.NVarChar, NullIfEmpty(line.Remark), 500);
                await detail.ExecuteNonQueryAsync(token);
            }

            if (request.DepositAmount + request.PaidAmount > total)
            {
                await transaction.RollbackAsync(token);
                return BadRequest(new { message = "ยอดรับชำระเกินยอดเอกสาร", description = "ผลรวมเงินมัดจำและยอดชำระต้องไม่มากกว่ายอดรวมใบรับจอง" });
            }
            var balance = total - request.DepositAmount - request.PaidAmount;
            const string summarySql = """
                UPDATE dbo.TDARPreOrder
                   SET TotalAmount=@total,BalanceAmount=@balance,
                       UpdateDate=CASE WHEN @isEdit=1 THEN SYSUTCDATETIME() ELSE UpdateDate END,
                       UpdatedBy=CASE WHEN @isEdit=1 THEN @user ELSE UpdatedBy END
                 WHERE PreOrderID=@id AND CompanyID=@company;
                """;
            await using (var summary = new SqlCommand(summarySql, connection, transaction))
            {
                Add(summary, "@total", SqlDbType.Decimal, total);
                Add(summary, "@balance", SqlDbType.Decimal, balance);
                Add(summary, "@isEdit", SqlDbType.Bit, id.HasValue);
                Add(summary, "@user", SqlDbType.BigInt, UserId());
                Add(summary, "@id", SqlDbType.BigInt, preOrderId);
                Add(summary, "@company", SqlDbType.BigInt, CompanyId());
                await summary.ExecuteNonQueryAsync(token);
            }

            await transaction.CommitAsync(token);
            return Ok(new { preOrderId, preOrderCode, totalAmount = total, balanceAmount = balance });
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = "เลขที่ใบรับจองซ้ำ", description = "มีเอกสารเลขที่เดียวกันถูกบันทึกพร้อมกัน กรุณากดบันทึกใหม่อีกครั้ง" });
        }
        catch (SqlException exception)
        {
            await transaction.RollbackAsync(token);
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "บันทึกใบรับจองสินค้าไม่สำเร็จ",
                description = $"ฐานข้อมูลไม่สามารถบันทึกเอกสารได้: {exception.Message}"
            });
        }
        catch (Exception exception)
        {
            await transaction.RollbackAsync(token);
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "บันทึกใบรับจองสินค้าไม่สำเร็จ",
                description = $"ระบบไม่สามารถประมวลผลเอกสารได้: {exception.Message}"
            });
        }
    }

    private void BindHeader(SqlCommand command, PreOrderUpsertRequest request, QuotationHeader quotation, string code, string status)
    {
        Add(command, "@company", SqlDbType.BigInt, CompanyId());
        Add(command, "@code", SqlDbType.NVarChar, code, 30);
        Add(command, "@date", SqlDbType.Date, request.PreOrderDate?.Date ?? DateTime.UtcNow.Date);
        Add(command, "@quotation", SqlDbType.BigInt, request.QuotationId);
        Add(command, "@customer", SqlDbType.BigInt, quotation.CustomerId);
        Add(command, "@cusCode", SqlDbType.NVarChar, quotation.CustomerCode, 50);
        Add(command, "@cusName", SqlDbType.NVarChar, quotation.CustomerName, 200);
        Add(command, "@contact", SqlDbType.NVarChar, NullIfEmpty(request.ContactName) ?? quotation.ContactName, 200);
        Add(command, "@phone", SqlDbType.NVarChar, NullIfEmpty(request.ContactPhone) ?? quotation.ContactPhone, 50);
        Add(command, "@expected", SqlDbType.Date, request.ExpectedDate?.Date);
        Add(command, "@deposit", SqlDbType.Decimal, request.DepositAmount);
        Add(command, "@paid", SqlDbType.Decimal, request.PaidAmount);
        Add(command, "@status", SqlDbType.NVarChar, status, 30);
        Add(command, "@remark", SqlDbType.NVarChar, NullIfEmpty(request.Remark), 1000);
        Add(command, "@user", SqlDbType.BigInt, UserId());
    }

    private async Task<QuotationHeader?> ReadQuotationHeader(SqlConnection connection, SqlTransaction? transaction, long quotationId, CancellationToken token)
    {
        const string sql = """
            SELECT Q.QuotationID,Q.CustomerID,Q.CusCode,Q.CusName,Q.ContactName,
                   COALESCE(NULLIF(C.Phone1,N''),NULLIF(C.Phone2,N'')) AS ContactPhone,
                   C.CusAddress,C.Email,Q.QuoteCode,Q.QuoteDate
            FROM dbo.TDARQuotation Q
            LEFT JOIN dbo.TDARCustomer C ON C.CustomerID=Q.CustomerID AND C.CompanyID=Q.CompanyID
            WHERE Q.QuotationID=@quotation AND Q.CompanyID=@company AND Q.IsActive=1;
            """;
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@quotation", SqlDbType.BigInt, quotationId);
        Add(command, "@company", SqlDbType.BigInt, CompanyId());
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return null;
        return new QuotationHeader(
            reader.GetInt64(0), reader.GetInt64(1), reader.GetString(2), reader.GetString(3),
            Text(reader, 4), Text(reader, 5), Text(reader, 6), Text(reader, 7), reader.GetString(8), reader.GetDateTime(9));
    }

    private async Task<(ItemSnapshot? Item, string? Status, string? Error)> ValidateLine(
        SqlConnection connection, SqlTransaction transaction, long quotationId,
        PreOrderLineRequest line, CancellationToken token)
    {
        if (line.ItemId <= 0 || line.Quantity <= 0 || line.UnitPrice < 0)
            return (null, null, "กรุณาเลือกสินค้า ระบุจำนวนมากกว่า 0 และราคาไม่ติดลบ");
        if (line.AllocatedQty < 0 || line.DeliveredQty < 0 || line.AllocatedQty > line.Quantity || line.DeliveredQty > line.AllocatedQty)
            return (null, null, "จำนวนจัดสรรต้องไม่เกินจำนวนจอง และจำนวนส่งมอบต้องไม่เกินจำนวนจัดสรร");
        var status = string.IsNullOrWhiteSpace(line.StatusCode) ? "WAITING_STOCK" : line.StatusCode.Trim().ToUpperInvariant();
        if (!DetailStatuses.Contains(status)) return (null, null, $"ไม่รองรับสถานะรายการ {status}");

        const string itemSql = "SELECT ItemCode,ItemName,UnitCode FROM dbo.TDIVItem WHERE ItemID=@item AND CompanyID=@company AND IsActive=1";
        await using var itemCommand = new SqlCommand(itemSql, connection, transaction);
        Add(itemCommand, "@item", SqlDbType.BigInt, line.ItemId);
        Add(itemCommand, "@company", SqlDbType.BigInt, CompanyId());
        ItemSnapshot? item = null;
        await using (var reader = await itemCommand.ExecuteReaderAsync(token))
            if (await reader.ReadAsync(token)) item = new ItemSnapshot(reader.GetString(0), reader.GetString(1), Text(reader, 2));
        if (item is null) return (null, null, "พบสินค้าที่ไม่อยู่ในบริษัทนี้หรือเลิกใช้งานแล้ว");

        if (line.QuotationDetailId.HasValue)
        {
            const string detailSql = "SELECT COUNT(1) FROM dbo.TDARQuotationDetail D INNER JOIN dbo.TDARQuotation Q ON Q.QuotationID=D.QuotationID WHERE D.QuotationDetailID=@detail AND D.QuotationID=@quotation AND D.ItemID=@item AND Q.CompanyID=@company";
            await using var detailCommand = new SqlCommand(detailSql, connection, transaction);
            Add(detailCommand, "@detail", SqlDbType.BigInt, line.QuotationDetailId.Value);
            Add(detailCommand, "@quotation", SqlDbType.BigInt, quotationId);
            Add(detailCommand, "@item", SqlDbType.BigInt, line.ItemId);
            Add(detailCommand, "@company", SqlDbType.BigInt, CompanyId());
            if (Convert.ToInt32(await detailCommand.ExecuteScalarAsync(token)) == 0)
                return (null, null, "รายการสินค้าไม่ตรงกับใบเสนอราคาที่อ้างอิง");
        }
        return (item, status, null);
    }

    private static LineCalculation CalculateLine(PreOrderLineRequest line)
    {
        var type = string.IsNullOrWhiteSpace(line.DiscountType) ? "N" : line.DiscountType.Trim().ToUpperInvariant();
        if (type is not ("N" or "P" or "A")) return new("N", 0, 0, 0, 0, "รูปแบบส่วนลดต้องเป็น ไม่ลด เปอร์เซ็นต์ หรือจำนวนเงิน");
        var before = decimal.Round(line.Quantity * line.UnitPrice, 4, MidpointRounding.AwayFromZero);
        var percent = 0m;
        var discount = 0m;
        if (type == "P")
        {
            if (line.DiscountValue < 0 || line.DiscountValue > 100) return new(type, before, 0, 0, 0, "ส่วนลดเปอร์เซ็นต์ต้องอยู่ระหว่าง 0 ถึง 100");
            percent = line.DiscountValue;
            discount = decimal.Round(before * percent / 100m, 4, MidpointRounding.AwayFromZero);
        }
        else if (type == "A")
        {
            if (line.DiscountValue < 0 || line.DiscountValue > before) return new(type, before, 0, 0, 0, "ส่วนลดจำนวนเงินต้องไม่เกินยอดก่อนส่วนลด");
            discount = decimal.Round(line.DiscountValue, 4, MidpointRounding.AwayFromZero);
            percent = before == 0 ? 0 : decimal.Round(discount * 100m / before, 4, MidpointRounding.AwayFromZero);
        }
        return new(type, before, percent, discount, before - discount, null);
    }

    private static object ReadLine(SqlDataReader reader, bool fromQuotation)
    {
        if (fromQuotation)
        {
            return new
            {
                quotationDetailId = reader.GetInt64(0), itemId = reader.GetInt64(1), itemCode = reader.GetString(2),
                itemName = reader.GetString(3), unitCode = Text(reader, 4), unitName = Text(reader, 5),
                quantity = reader.GetDecimal(6), unitPrice = reader.GetDecimal(7), discountType = reader.GetString(8),
                discountPercent = reader.GetDecimal(9), discountAmount = reader.GetDecimal(10), amount = reader.GetDecimal(11),
                allocatedQty = 0m, deliveredQty = 0m, statusCode = "WAITING_STOCK", remark = (string?)null,
            };
        }
        return new
        {
            preOrderDetailId = reader.GetInt64(0), itemId = reader.GetInt64(1), itemCode = reader.GetString(2),
            itemName = reader.GetString(3), unitCode = Text(reader, 4), unitName = Text(reader, 5),
            quantity = reader.GetDecimal(6), unitPrice = reader.GetDecimal(7), discountType = reader.GetString(8),
            discountPercent = reader.GetDecimal(9), discountAmount = reader.GetDecimal(10), amount = reader.GetDecimal(11),
            allocatedQty = reader.GetDecimal(12), deliveredQty = reader.GetDecimal(13), statusCode = reader.GetString(14),
            remark = Text(reader, 15), quotationDetailId = reader.IsDBNull(16) ? (long?)null : reader.GetInt64(16),
        };
    }

    private async Task<string> NextCode(SqlConnection connection, SqlTransaction transaction, CancellationToken token)
    {
        const string sql = "SELECT ISNULL(MAX(TRY_CONVERT(int,RIGHT(PreOrderCode,6))),0)+1 FROM dbo.TDARPreOrder WITH (UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND PreOrderCode LIKE N'PO%';";
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@company", SqlDbType.BigInt, CompanyId());
        return $"PO{Convert.ToInt32(await command.ExecuteScalarAsync(token)):D6}";
    }

    private async Task<bool> Can(SqlConnection connection, string action, CancellationToken token)
    {
        const string sql = """
            SELECT CASE WHEN EXISTS
            (
                SELECT 1 FROM dbo.TDADUser U
                WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1
            ) OR EXISTS
            (
                SELECT 1 FROM dbo.TDADUserPermission UP
                INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
                WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1
                  AND P.IsActive=1 AND P.ActionCode=@action AND P.ScreenCode=@screen
            ) OR EXISTS
            (
                SELECT 1 FROM dbo.TDADUser U
                INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID
                INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID
                INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C'
                  AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project
                INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID
                  AND RP.ProjectID=@project AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1
                WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND ERG.IsActive=1
                  AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
                  AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
            ) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END;
            """;
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@user", SqlDbType.BigInt, UserId());
        Add(command, "@company", SqlDbType.BigInt, CompanyId());
        Add(command, "@project", SqlDbType.BigInt, ProjectId());
        Add(command, "@action", SqlDbType.NVarChar, action, 20);
        Add(command, "@screen", SqlDbType.NVarChar, ScreenCode, 20);
        return (bool)(await command.ExecuteScalarAsync(token) ?? false);
    }

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private long UserId() => long.TryParse(User.FindFirstValue("user_id"), out var value) ? value : 0;
    private long CompanyId() => long.TryParse(User.FindFirstValue("company_id"), out var value) ? value : 0;
    private long ProjectId() => long.TryParse(User.FindFirstValue("project_id"), out var value) ? value : 0;
    private static string? Text(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetValue(index)?.ToString();
    private static string? NullIfEmpty(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0)
    {
        var parameter = command.Parameters.Add(name, type);
        if (size > 0) parameter.Size = size;
        if (type == SqlDbType.Decimal) { parameter.Precision = 18; parameter.Scale = 4; }
        parameter.Value = value ?? DBNull.Value;
    }

    private sealed record QuotationHeader(long Id, long CustomerId, string CustomerCode, string CustomerName, string? ContactName, string? ContactPhone, string? Address, string? Email, string QuoteCode, DateTime QuoteDate);
    private sealed record ItemSnapshot(string Code, string Name, string? Unit);
    private sealed record LineCalculation(string DiscountType, decimal BeforeDiscount, decimal DiscountPercent, decimal DiscountAmount, decimal Amount, string? Error);
}
