using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooExpenseModule.Controllers;

[ApiController, Authorize, Route("api/company/expenses")]
public sealed class ExpenseController(IConfiguration configuration) : ControllerBase
{
    private const string ExpenseTypeGroup = "015";
    private static readonly string[] Menus = ["41001", "41002", "41003", "41004", "41005", "41006", "41007", "41008", "41009"];
    private static readonly string[] PaymentMethods = ["CASH", "BANK", "CARD", "OTHER"];

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken token)
    {
        if (!Menus.Contains(menu) || !Scope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, menu, "VIEW", token)) return Forbid();
        return Ok(new
        {
            create = await Can(connection, menu, "CREATE", token),
            edit = await Can(connection, menu, "EDIT", token),
            delete = await Can(connection, menu, "DELETE", token),
            submit = await Can(connection, menu, "SUBMIT", token),
            cancel = await Can(connection, menu, "CANCEL", token),
            approve = await Can(connection, menu, "APPROVE", token),
            selfApprove = await Can(connection, menu, "SELF_APPROVE", token),
            confirmPayment = await Can(connection, menu, "CONFIRM_PAYMENT", token),
            confirmSettlement = await Can(connection, menu, "CONFIRM_SETTLEMENT", token),
        });
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "41001", "VIEW", token)) return Forbid();
        await EnsureSetup(connection, companyId, token);
        return Ok(await Single(connection, "SELECT IsEnabled,AllowDirectEntry,DefaultCurrencyCode FROM dbo.TDSTCompanySetupSystemExpense WHERE CompanyID=@company", companyId, token));
    }

    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(ExpenseSettingInput input, CancellationToken token)
    {
        var currency = Clean(input.DefaultCurrencyCode)?.ToUpperInvariant();
        if (currency is null || currency.Length != 3) return Bad("ข้อมูลตั้งค่าไม่ถูกต้อง", "ระบุรหัสสกุลเงิน 3 ตัว เช่น THB");
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "41001", "EDIT", token)) return Forbid();
        await EnsureSetup(connection, companyId, token);
        await using var command = new SqlCommand("UPDATE dbo.TDSTCompanySetupSystemExpense SET IsEnabled=@enabled,AllowDirectEntry=@direct,DefaultCurrencyCode=@currency,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company", connection);
        P(command, "@enabled", SqlDbType.Bit, input.IsEnabled);
        P(command, "@direct", SqlDbType.Bit, input.AllowDirectEntry);
        P(command, "@currency", SqlDbType.NVarChar, currency, 3);
        P(command, "@user", SqlDbType.BigInt, userId);
        P(command, "@company", SqlDbType.BigInt, companyId);
        await command.ExecuteNonQueryAsync(token);
        return NoContent();
    }

    [HttpGet("categories")]
    public async Task<IActionResult> Categories(CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "41002", "VIEW", token)) return Forbid();
        await EnsureDefaultCategories(connection, companyId, token);
        await using var command = new SqlCommand("SELECT MasterID id,MasterCode code,Name name,ISNULL(Seq,0) sortOrder,IsActive active FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND MasterGroupCode=@group ORDER BY ISNULL(Seq,0),Name,MasterCode", connection);
        P(command, "@company", SqlDbType.BigInt, companyId);
        P(command, "@group", SqlDbType.NVarChar, ExpenseTypeGroup, 10);
        return Ok(await Rows(command, token));
    }

    [HttpPost("categories")]
    public Task<IActionResult> CreateCategory(ExpenseCategoryInput input, CancellationToken token) => SaveCategory(null, input, "CREATE", token);

    [HttpPut("categories/{code}")]
    public Task<IActionResult> UpdateCategory(string code, ExpenseCategoryInput input, CancellationToken token) => SaveCategory(code, input, "EDIT", token);

    [HttpDelete("categories/{code}")]
    public async Task<IActionResult> DeleteCategory(string code, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "41002", "DELETE", token)) return Forbid();
        var normalized = code.Trim().ToUpperInvariant();
        await using var used = new SqlCommand("SELECT (SELECT COUNT(*) FROM dbo.TDEXExpenseDetail WHERE CompanyID=@company AND ExpenseTypeCode=@code)+(SELECT COUNT(*) FROM dbo.TDEXExpenseDocumentDetail WHERE CompanyID=@company AND ExpenseTypeCode=@code)", connection);
        P(used, "@company", SqlDbType.BigInt, companyId);
        P(used, "@code", SqlDbType.NVarChar, normalized, 10);
        if (Convert.ToInt32(await used.ExecuteScalarAsync(token)) > 0)
            return Conflict(new { message = "ลบประเภทค่าใช้จ่ายไม่ได้", description = "ประเภทนี้ถูกใช้ในเอกสารค่าใช้จ่ายแล้ว" });
        await using var command = new SqlCommand("DELETE dbo.TDSTMaster WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND MasterGroupCode=@group AND MasterCode=@code", connection);
        P(command, "@company", SqlDbType.BigInt, companyId);
        P(command, "@group", SqlDbType.NVarChar, ExpenseTypeGroup, 10);
        P(command, "@code", SqlDbType.NVarChar, normalized, 10);
        return await command.ExecuteNonQueryAsync(token) > 0 ? NoContent() : NotFound();
    }

    [HttpGet("options")]
    public async Task<IActionResult> Options(CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "41009", "VIEW", token) && !await Can(connection, "41002", "VIEW", token)) return Forbid();
        await EnsureSetup(connection, companyId, token);
        await EnsureDefaultCategories(connection, companyId, token);
        const string sql = "SELECT MasterCode code,Name name FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND MasterGroupCode=@group AND IsActive=1 ORDER BY ISNULL(Seq,0),Name;SELECT DefaultCurrencyCode currency,IsEnabled enabled,AllowDirectEntry allowDirectEntry FROM dbo.TDSTCompanySetupSystemExpense WHERE CompanyID=@company;SELECT BusinessProjectID id,ProjectNo code,ProjectName name FROM dbo.TDPMProject WHERE CompanyID=@company AND StatusCode IN(N'DRAFT',N'ACTIVE') ORDER BY ProjectName";
        await using var command = new SqlCommand(sql, connection);
        P(command, "@company", SqlDbType.BigInt, companyId);
        P(command, "@group", SqlDbType.NVarChar, ExpenseTypeGroup, 10);
        return Ok(await Multi(command, token, ["categories", "settings", "projects"]));
    }

    [HttpGet("direct")]
    public async Task<IActionResult> DirectList([FromQuery] string? search, [FromQuery] string? categoryCode, [FromQuery] DateTime? dateFrom, [FromQuery] DateTime? dateTo, [FromQuery] int page = 1, [FromQuery] int pageSize = 10, CancellationToken token = default)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "41009", "VIEW", token)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        const string where = "FROM dbo.TDEXExpense e WHERE e.CompanyID=@company AND (@search IS NULL OR e.ExpenseNo LIKE N'%'+@search+N'%' OR e.PayeeName LIKE N'%'+@search+N'%' OR ISNULL(e.BillNo,N'') LIKE N'%'+@search+N'%') AND (@category IS NULL OR EXISTS(SELECT 1 FROM dbo.TDEXExpenseDetail d WHERE d.ExpenseID=e.ExpenseID AND d.CompanyID=e.CompanyID AND d.ExpenseTypeCode=@category)) AND (@from IS NULL OR e.ExpenseDate>=@from) AND (@to IS NULL OR e.ExpenseDate<=@to)";
        var sql = $"SELECT COUNT(*) {where};SELECT e.ExpenseID id,e.ExpenseNo code,e.ExpenseDate,e.PayeeName payee,e.BillNo,e.PaymentMethodCode paymentMethod,e.CurrencyCode currency,e.TotalAmount total,e.StatusCode status,e.BusinessProjectID projectId,(SELECT p.ProjectName FROM dbo.TDPMProject p WHERE p.CompanyID=e.CompanyID AND p.BusinessProjectID=e.BusinessProjectID) projectName,e.Remark {where} ORDER BY e.ExpenseDate DESC,e.ExpenseID DESC OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;";
        await using var command = new SqlCommand(sql, connection);
        P(command, "@company", SqlDbType.BigInt, companyId);
        P(command, "@search", SqlDbType.NVarChar, Clean(search), 250);
        P(command, "@category", SqlDbType.NVarChar, Clean(categoryCode)?.ToUpperInvariant(), 10);
        P(command, "@from", SqlDbType.Date, dateFrom?.Date);
        P(command, "@to", SqlDbType.Date, dateTo?.Date);
        P(command, "@offset", SqlDbType.Int, (page - 1) * pageSize);
        P(command, "@pageSize", SqlDbType.Int, pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var total = 0;
        if (await reader.ReadAsync(token)) total = reader.GetInt32(0);
        await reader.NextResultAsync(token);
        var items = await ReadRows(reader, token);
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("direct/{id:long}")]
    public async Task<IActionResult> Direct(long id, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "41009", "VIEW", token)) return Forbid();
        const string sql = "SELECT ExpenseID id,ExpenseNo code,ExpenseDate,PayeeName payee,BillNo,PaymentMethodCode paymentMethod,CurrencyCode currency,TotalAmount total,StatusCode status,BusinessProjectID projectId,Remark FROM dbo.TDEXExpense WHERE CompanyID=@company AND ExpenseID=@id;SELECT ExpenseDetailID id,LineSeq [lineNo],ExpenseTypeCode categoryCode,DescriptionText description,Amount FROM dbo.TDEXExpenseDetail WHERE CompanyID=@company AND ExpenseID=@id ORDER BY LineSeq";
        await using var command = new SqlCommand(sql, connection);
        P(command, "@company", SqlDbType.BigInt, companyId); P(command, "@id", SqlDbType.BigInt, id);
        var result = await Multi(command, token, ["header", "details"]);
        var headers = result["header"] as List<Dictionary<string, object?>> ?? [];
        if (headers.Count == 0) return NotFound();
        return Ok(new { header = headers[0], details = result["details"] });
    }

    [HttpPost("direct")]
    public Task<IActionResult> CreateDirect(DirectExpenseInput input, CancellationToken token) => SaveDirect(null, input, "CREATE", token);

    [HttpPut("direct/{id:long}")]
    public Task<IActionResult> UpdateDirect(long id, DirectExpenseInput input, CancellationToken token) => SaveDirect(id, input, "EDIT", token);

    [HttpDelete("direct/{id:long}")]
    public async Task<IActionResult> DeleteDirect(long id, CancellationToken token)
    {
        if (!Scope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "41009", "DELETE", token)) return Forbid();
        await using var command = new SqlCommand("DELETE dbo.TDEXExpense WHERE CompanyID=@company AND ExpenseID=@id AND StatusCode=N'RECORDED'", connection);
        P(command, "@company", SqlDbType.BigInt, companyId); P(command, "@id", SqlDbType.BigInt, id);
        return await command.ExecuteNonQueryAsync(token) == 1 ? NoContent() : Conflict(new { message = "ลบค่าใช้จ่ายไม่ได้", description = "ไม่พบรายการ หรือสถานะรายการไม่อนุญาตให้ลบ" });
    }

    private async Task<IActionResult> SaveCategory(string? existingCode, ExpenseCategoryInput input, string action, CancellationToken token)
    {
        var code = (existingCode ?? input.Code)?.Trim().ToUpperInvariant();
        var name = Clean(input.Name);
        if (string.IsNullOrWhiteSpace(code) || code.Length > 10 || name is null) return Bad("ข้อมูลประเภทค่าใช้จ่ายไม่ครบ", "ระบุรหัสไม่เกิน 10 ตัวและชื่อประเภทค่าใช้จ่าย");
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "41002", action, token)) return Forbid();
        var sql = existingCode is null
            ? "INSERT dbo.TDSTMaster(OwnerType,OwnerCompanyID,MasterGroupCode,MasterCode,Name,Seq,OrderBy,IsActive,CreateBy) SELECT N'C',@company,@group,@code,@name,@sort,N'Seq',@active,@user WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSTMaster WITH (UPDLOCK,HOLDLOCK) WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND MasterGroupCode=@group AND MasterCode=@code)"
            : "UPDATE dbo.TDSTMaster SET Name=@name,Seq=@sort,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND MasterGroupCode=@group AND MasterCode=@code";
        await using var command = new SqlCommand(sql, connection);
        P(command, "@company", SqlDbType.BigInt, companyId); P(command, "@group", SqlDbType.NVarChar, ExpenseTypeGroup, 10); P(command, "@code", SqlDbType.NVarChar, code, 10); P(command, "@name", SqlDbType.NVarChar, name, 250); P(command, "@sort", SqlDbType.Int, input.SortOrder); P(command, "@active", SqlDbType.Bit, input.IsActive); P(command, "@user", SqlDbType.BigInt, userId);
        try
        {
            var affected = await command.ExecuteNonQueryAsync(token);
            if (affected > 0) return Ok(new { code });
            return existingCode is null
                ? Conflict(new { message = "รหัสประเภทค่าใช้จ่ายซ้ำ", description = "ใช้รหัสอื่นภายในบริษัท" })
                : NotFound();
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            return Conflict(new { message = "รหัสประเภทค่าใช้จ่ายซ้ำ", description = "ใช้รหัสอื่นภายในบริษัท" });
        }
    }

    private async Task<IActionResult> SaveDirect(long? id, DirectExpenseInput input, string action, CancellationToken token)
    {
        var payee = Clean(input.PayeeName); var payment = Clean(input.PaymentMethodCode)?.ToUpperInvariant(); var currency = Clean(input.CurrencyCode)?.ToUpperInvariant();
        if (payee is null || payment is null || !PaymentMethods.Contains(payment) || currency is null || currency.Length != 3 || input.Details is null || input.Details.Count == 0)
            return Bad("ข้อมูลค่าใช้จ่ายไม่ครบ", "ระบุวันที่ ผู้รับเงิน วิธีชำระ สกุลเงิน และรายการค่าใช้จ่ายอย่างน้อย 1 รายการ");
        if (input.Details.Any(x => string.IsNullOrWhiteSpace(x.ExpenseTypeCode) || string.IsNullOrWhiteSpace(x.Description) || x.Amount <= 0))
            return Bad("รายละเอียดค่าใช้จ่ายไม่ถูกต้อง", "ทุกรายการต้องมีประเภท รายละเอียด และจำนวนเงินมากกว่า 0");
        if (!Scope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "41009", action, token)) return Forbid();
        await EnsureSetup(connection, companyId, token);
        if (!await DirectEntryEnabled(connection, companyId, token)) return Conflict(new { message = "บันทึกค่าใช้จ่ายโดยตรงไม่ได้", description = "ระบบค่าใช้จ่ายหรือการบันทึกโดยตรงถูกปิดใช้งาน" });
        var codes = input.Details.Select(x => x.ExpenseTypeCode.Trim().ToUpperInvariant()).Distinct().ToArray();
        if (!await ValidCategories(connection, companyId, codes, token)) return Bad("ประเภทค่าใช้จ่ายไม่ถูกต้อง", "เลือกประเภทที่เปิดใช้งานในบริษัทเดียวกันให้ครบทุกรายการ");
        var total = input.Details.Sum(x => decimal.Round(x.Amount, 2, MidpointRounding.AwayFromZero));
        if (input.BusinessProjectId is not null)
        {
            await using var project = new SqlCommand("SELECT COUNT(*) FROM dbo.TDPMProject WHERE CompanyID=@company AND BusinessProjectID=@project AND StatusCode<>N'CANCELLED'", connection);
            P(project, "@company", SqlDbType.BigInt, companyId);
            P(project, "@project", SqlDbType.BigInt, input.BusinessProjectId);
            if (Convert.ToInt32(await project.ExecuteScalarAsync(token)) != 1)
                return Bad("โครงการไม่ถูกต้อง", "เลือกโครงการในบริษัทเดียวกันที่ยังไม่ยกเลิก");
        }
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(token);
        try
        {
            long expenseId;
            if (id is null)
            {
                var code = string.IsNullOrWhiteSpace(input.ExpenseNo) ? $"EX{DateTime.UtcNow:yyyyMMddHHmmssfff}" : input.ExpenseNo.Trim().ToUpperInvariant();
                const string insert = "INSERT dbo.TDEXExpense(CompanyID,ProjectID,BusinessProjectID,ExpenseNo,ExpenseDate,PayeeName,BillNo,PaymentMethodCode,CurrencyCode,TotalAmount,StatusCode,Remark,CreateBy) OUTPUT INSERTED.ExpenseID SELECT @company,ProjectID,@businessProject,@code,@date,@payee,@bill,@payment,@currency,@total,N'RECORDED',@remark,@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_EXPENSE' AND IsActive=1";
                await using var command = new SqlCommand(insert, connection, transaction); BindHeader(command, companyId, null, code, input, payee, payment, currency, total, userId);
                expenseId = Convert.ToInt64(await command.ExecuteScalarAsync(token));
            }
            else
            {
                const string update = "UPDATE dbo.TDEXExpense SET BusinessProjectID=@businessProject,ExpenseDate=@date,PayeeName=@payee,BillNo=@bill,PaymentMethodCode=@payment,CurrencyCode=@currency,TotalAmount=@total,Remark=@remark,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ExpenseID=@id AND StatusCode=N'RECORDED'";
                await using var command = new SqlCommand(update, connection, transaction); BindHeader(command, companyId, id, null, input, payee, payment, currency, total, userId);
                if (await command.ExecuteNonQueryAsync(token) != 1)
                {
                    await transaction.RollbackAsync(token);
                    return Conflict(new { message = "แก้ไขค่าใช้จ่ายไม่ได้", description = "ไม่พบรายการ หรือสถานะรายการไม่อนุญาตให้แก้ไข" });
                }
                expenseId = id.Value;
                await using var clear = new SqlCommand("DELETE dbo.TDEXExpenseDetail WHERE CompanyID=@company AND ExpenseID=@id", connection, transaction); P(clear, "@company", SqlDbType.BigInt, companyId); P(clear, "@id", SqlDbType.BigInt, expenseId); await clear.ExecuteNonQueryAsync(token);
            }
            for (var index = 0; index < input.Details.Count; index++)
            {
                var line = input.Details[index];
                await using var detail = new SqlCommand("INSERT dbo.TDEXExpenseDetail(ExpenseID,CompanyID,LineSeq,ExpenseTypeCode,DescriptionText,Amount) VALUES(@id,@company,@line,@type,@description,@amount)", connection, transaction);
                P(detail, "@id", SqlDbType.BigInt, expenseId); P(detail, "@company", SqlDbType.BigInt, companyId); P(detail, "@line", SqlDbType.Int, index + 1); P(detail, "@type", SqlDbType.NVarChar, line.ExpenseTypeCode.Trim().ToUpperInvariant(), 10); P(detail, "@description", SqlDbType.NVarChar, line.Description.Trim(), 500); P(detail, "@amount", SqlDbType.Decimal, decimal.Round(line.Amount, 2, MidpointRounding.AwayFromZero));
                detail.Parameters["@amount"].Precision = 18; detail.Parameters["@amount"].Scale = 2;
                await detail.ExecuteNonQueryAsync(token);
            }
            await transaction.CommitAsync(token);
            return Ok(new { id = expenseId, status = "RECORDED", total });
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = "เลขที่ค่าใช้จ่ายซ้ำ", description = "ใช้เลขที่เอกสารอื่นภายในบริษัท" });
        }
        catch
        {
            await transaction.RollbackAsync(token); throw;
        }
    }

    private static void BindHeader(SqlCommand command, long companyId, long? id, string? code, DirectExpenseInput input, string payee, string payment, string currency, decimal total, long userId)
    {
        P(command, "@company", SqlDbType.BigInt, companyId); P(command, "@businessProject", SqlDbType.BigInt, input.BusinessProjectId); P(command, "@id", SqlDbType.BigInt, id); P(command, "@code", SqlDbType.NVarChar, code, 40); P(command, "@date", SqlDbType.Date, input.ExpenseDate.Date); P(command, "@payee", SqlDbType.NVarChar, payee, 250); P(command, "@bill", SqlDbType.NVarChar, Clean(input.BillNo), 100); P(command, "@payment", SqlDbType.NVarChar, payment, 20); P(command, "@currency", SqlDbType.NVarChar, currency, 3); P(command, "@total", SqlDbType.Decimal, total); command.Parameters["@total"].Precision = 18; command.Parameters["@total"].Scale = 2; P(command, "@remark", SqlDbType.NVarChar, Clean(input.Remark), 2000); P(command, "@user", SqlDbType.BigInt, userId);
    }

    private async Task<bool> ValidCategories(SqlConnection connection, long companyId, string[] codes, CancellationToken token)
    {
        if (codes.Length == 0) return false;
        var names = codes.Select((_, index) => $"@c{index}").ToArray();
        await using var command = new SqlCommand($"SELECT COUNT(*) FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND MasterGroupCode=@group AND IsActive=1 AND MasterCode IN({string.Join(',', names)})", connection);
        P(command, "@company", SqlDbType.BigInt, companyId); P(command, "@group", SqlDbType.NVarChar, ExpenseTypeGroup, 10);
        for (var index = 0; index < codes.Length; index++) P(command, names[index], SqlDbType.NVarChar, codes[index], 10);
        return Convert.ToInt32(await command.ExecuteScalarAsync(token)) == codes.Length;
    }

    private static async Task<bool> DirectEntryEnabled(SqlConnection connection, long companyId, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT CASE WHEN IsEnabled=1 AND AllowDirectEntry=1 THEN 1 ELSE 0 END FROM dbo.TDSTCompanySetupSystemExpense WHERE CompanyID=@company", connection);
        P(command, "@company", SqlDbType.BigInt, companyId);
        return Convert.ToInt32(await command.ExecuteScalarAsync(token)) == 1;
    }

    private static async Task EnsureSetup(SqlConnection connection, long companyId, CancellationToken token)
    {
        const string sql = "DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_EXPENSE' AND IsActive=1);IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanySetupSystemExpense WHERE CompanyID=@company AND ProjectID=@project) INSERT dbo.TDSTCompanySetupSystemExpense(CompanyID,ProjectID,CreateBy) VALUES(@company,@project,0)";
        await using var command = new SqlCommand(sql, connection); P(command, "@company", SqlDbType.BigInt, companyId); await command.ExecuteNonQueryAsync(token);
    }

    private static async Task EnsureDefaultCategories(SqlConnection connection, long companyId, CancellationToken token)
    {
        const string sql = "IF NOT EXISTS(SELECT 1 FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND MasterGroupCode=@group) INSERT dbo.TDSTMaster(OwnerType,OwnerCompanyID,MasterGroupCode,MasterCode,Name,Seq,OrderBy,IsActive,CreateBy) SELECT N'C',@company,@group,v.Code,v.Name,v.Seq,N'Seq',1,0 FROM (VALUES(N'UTIL',N'ค่าสาธารณูปโภค',10),(N'OFFICE',N'ค่าใช้จ่ายสำนักงาน',20),(N'TRAVEL',N'ค่าเดินทาง',30),(N'SERVICE',N'ค่าบริการ',40),(N'OTHER',N'อื่น ๆ',90))v(Code,Name,Seq)";
        await using var command = new SqlCommand(sql, connection); P(command, "@company", SqlDbType.BigInt, companyId); P(command, "@group", SqlDbType.NVarChar, ExpenseTypeGroup, 10); await command.ExecuteNonQueryAsync(token);
    }

    private async Task<Dictionary<string, object?>> Single(SqlConnection connection, string sql, long companyId, CancellationToken token)
    {
        await using var command = new SqlCommand(sql, connection); P(command, "@company", SqlDbType.BigInt, companyId); var rows = await Rows(command, token); return rows.FirstOrDefault() ?? [];
    }
    private static async Task<List<Dictionary<string, object?>>> Rows(SqlCommand command, CancellationToken token) { await using var reader = await command.ExecuteReaderAsync(token); return await ReadRows(reader, token); }
    private static async Task<List<Dictionary<string, object?>>> ReadRows(SqlDataReader reader, CancellationToken token) { var rows = new List<Dictionary<string, object?>>(); while (await reader.ReadAsync(token)) { var row = new Dictionary<string, object?>(); for (var i = 0; i < reader.FieldCount; i++) { var name = reader.GetName(i); row[char.ToLowerInvariant(name[0]) + name[1..]] = reader.IsDBNull(i) ? null : reader.GetValue(i); } rows.Add(row); } return rows; }
    private static async Task<Dictionary<string, object?>> Multi(SqlCommand command, CancellationToken token, string[] names) { await using var reader = await command.ExecuteReaderAsync(token); var result = new Dictionary<string, object?>(); var index = 0; do { result[names[index++]] = await ReadRows(reader, token); } while (index < names.Length && await reader.NextResultAsync(token)); return result; }
    private Task<bool> Can(SqlConnection connection, string menu, string action, CancellationToken token) => CompanyMenuAccess.IsAllowedAsync(connection, User, menu, action, token);
    private bool Scope(out long companyId, out long userId) { companyId = 0; userId = 0; return string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase) && string.Equals(User.FindFirstValue("project_code"), "LAOO_EXPENSE", StringComparison.OrdinalIgnoreCase) && long.TryParse(User.FindFirstValue("company_id"), out companyId) && long.TryParse(User.FindFirstValue("user_id"), out userId) && companyId > 0 && userId > 0; }
    private async Task<SqlConnection> Open(CancellationToken token) { var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await connection.OpenAsync(token); return connection; }
    private static void P(SqlCommand command, string name, SqlDbType type, object? value, int size = 0) { var parameter = size > 0 ? command.Parameters.Add(name, type, size) : command.Parameters.Add(name, type); parameter.Value = value ?? DBNull.Value; }
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private BadRequestObjectResult Bad(string message, string description) => BadRequest(new { message, description });
}

public sealed record ExpenseSettingInput(bool IsEnabled, bool AllowDirectEntry, string DefaultCurrencyCode);
public sealed record ExpenseCategoryInput(string? Code, string Name, int SortOrder, bool IsActive = true);
public sealed record DirectExpenseDetailInput(string ExpenseTypeCode, string Description, decimal Amount);
public sealed record DirectExpenseInput(string? ExpenseNo, DateTime ExpenseDate, string PayeeName, string? BillNo, string PaymentMethodCode, string CurrencyCode, long? BusinessProjectId, string? Remark, List<DirectExpenseDetailInput> Details);