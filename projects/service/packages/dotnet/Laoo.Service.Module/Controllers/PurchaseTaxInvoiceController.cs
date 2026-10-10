using System.Data;
using System.Security.Claims;
using LaooServiceModule.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;

public sealed record PurchaseTaxLine(string Description, decimal Quantity, decimal UnitPrice);
public sealed record PurchaseTaxSave(
    long? PurchaseTaxInvoiceId, long VendorId, long? BranchId, string? VendorTaxBranchCode,
    string SupplierInvoiceCode, DateTime InvoiceDate, DateTime ReceivedDate, int TaxYear, int TaxMonth,
    decimal TaxRate, string ClaimStatus, string? ClaimReason, List<PurchaseTaxLine> Lines);

[ApiController, Authorize, LaooServiceModule.Security.RequireCompanyFeature("SALES")]
[LaooServiceModule.Security.RequireCompanyProject("LAOO")]
[TypeFilter(typeof(ItemProjectExceptionFilter))]
[Route("api/company/purchase-tax-invoices")]
public sealed class PurchaseTaxInvoiceController(IConfiguration configuration) : ControllerBase
{
    private readonly IConfiguration _configuration = configuration;
    private long CompanyId => long.TryParse(User.FindFirstValue("company_id"), out var n) ? n : 0;
    private long UserId => long.TryParse(User.FindFirstValue("user_id"), out var n) ? n : 0;
    private static Task<bool> Can(SqlConnection c, ClaimsPrincipal user, string action, CancellationToken ct) =>
        Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedAsync(c, user, "09010", action, ct);
    private async Task<SqlConnection> Open(CancellationToken ct)
    {
        var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(ct);
        return c;
    }
    private static void P(SqlCommand c, string key, SqlDbType type, object? value)
    {
        var p = c.Parameters.Add(key, type);
        if (type == SqlDbType.Decimal) { p.Precision = 18; p.Scale = 4; }
        p.Value = value ?? DBNull.Value;
    }

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken ct)
    {
        await using var c = await Open(ct);
        return Ok(new { view = await Can(c, User, "VIEW", ct), create = await Can(c, User, "CREATE", ct),
            edit = await Can(c, User, "EDIT", ct), delete = await Can(c, User, "DELETE", ct) });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] int? year, [FromQuery] int? month, CancellationToken ct)
    {
        await using var c = await Open(ct);
        if (!await Can(c, User, "VIEW", ct)) return Forbid();
        await using var cmd = new SqlCommand("""
            SELECT PurchaseTaxInvoiceID,InternalCode,SupplierInvoiceCode,InvoiceDate,ReceivedDate,
                   VendorNameSnapshot,TaxBase,TaxAmount,ClaimStatus,StatusCode,TaxYear,TaxMonth
            FROM dbo.TDAPTaxInvoice
            WHERE CompanyID=@company AND (@year IS NULL OR TaxYear=@year) AND (@month IS NULL OR TaxMonth=@month)
            ORDER BY InvoiceDate DESC,PurchaseTaxInvoiceID DESC
            """, c);
        P(cmd, "@company", SqlDbType.BigInt, CompanyId);
        P(cmd, "@year", SqlDbType.Int, year);
        P(cmd, "@month", SqlDbType.TinyInt, month);
        var rows = new List<object>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct)) rows.Add(new {
            purchaseTaxInvoiceId=r.GetInt64(0), internalCode=r.GetString(1), supplierInvoiceCode=r.GetString(2),
            invoiceDate=r.GetDateTime(3), receivedDate=r.GetDateTime(4), vendorName=r.GetString(5),
            taxBase=r.GetDecimal(6), taxAmount=r.GetDecimal(7), claimStatus=r.GetString(8),
            statusCode=r.GetString(9), taxYear=r.GetInt32(10), taxMonth=r.GetByte(11) });
        return Ok(rows);
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken ct)
    {
        await using var c = await Open(ct);
        if (!await Can(c, User, "VIEW", ct)) return Forbid();
        await using var cmd = new SqlCommand("""
            SELECT P.PurchaseTaxInvoiceID,P.InternalCode,P.SupplierInvoiceCode,P.InvoiceDate,P.ReceivedDate,
                   P.VendorID,P.VendorNameSnapshot,P.VendorTaxIDSnapshot,P.VendorTaxBranchCode,
                   P.BranchID,P.TaxYear,P.TaxMonth,P.TaxBase,P.TaxRate,P.TaxAmount,P.ClaimStatus,P.ClaimReason,P.StatusCode,
                   D.ItemNo,D.Description,D.Quantity,D.UnitPrice,D.TaxBase
            FROM dbo.TDAPTaxInvoice P
            JOIN dbo.TDAPTaxInvoiceDetail D ON D.PurchaseTaxInvoiceID=P.PurchaseTaxInvoiceID
            WHERE P.CompanyID=@company AND P.PurchaseTaxInvoiceID=@id ORDER BY D.ItemNo
            """, c);
        P(cmd,"@company",SqlDbType.BigInt,CompanyId); P(cmd,"@id",SqlDbType.BigInt,id);
        object? header=null; var lines=new List<object>();
        await using var r=await cmd.ExecuteReaderAsync(ct);
        while(await r.ReadAsync(ct))
        {
            header ??= new { purchaseTaxInvoiceId=r.GetInt64(0),internalCode=r.GetString(1),supplierInvoiceCode=r.GetString(2),
                invoiceDate=r.GetDateTime(3),receivedDate=r.GetDateTime(4),vendorId=r.GetInt64(5),vendorName=r.GetString(6),
                vendorTaxId=r.IsDBNull(7)?null:r.GetString(7),vendorTaxBranchCode=r.IsDBNull(8)?null:r.GetString(8),
                branchId=r.IsDBNull(9)?(long?)null:r.GetInt64(9),taxYear=r.GetInt32(10),taxMonth=r.GetByte(11),
                taxBase=r.GetDecimal(12),taxRate=r.GetDecimal(13),taxAmount=r.GetDecimal(14),
                claimStatus=r.GetString(15),claimReason=r.IsDBNull(16)?null:r.GetString(16),statusCode=r.GetString(17) };
            lines.Add(new {itemNo=r.GetInt32(18),description=r.GetString(19),quantity=r.GetDecimal(20),
                unitPrice=r.GetDecimal(21),taxBase=r.GetDecimal(22)});
        }
        return header is null ? NotFound() : Ok(new { header, lines });
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken ct)
    {
        await using var c=await Open(ct);
        if(!await Can(c,User,"VIEW",ct)) return Forbid();
        var vendors=new List<object>(); var branches=new List<object>();
        await using(var cmd=new SqlCommand("SELECT VendorID,VendorCode,VendorName,TaxID FROM dbo.TDAPVendor WHERE CompanyID=@company AND IsActive=1 ORDER BY VendorName",c))
        {
            P(cmd,"@company",SqlDbType.BigInt,CompanyId);
            await using var r=await cmd.ExecuteReaderAsync(ct);
            while(await r.ReadAsync(ct)) vendors.Add(new {vendorId=r.GetInt64(0),code=r.GetString(1),name=r.GetString(2),taxId=r.IsDBNull(3)?null:r.GetString(3)});
        }
        await using(var cmd=new SqlCommand("SELECT BranchID,BranchCode,BranchNameTH,TaxBranchCode FROM dbo.TDADBranch WHERE CompanyID=@company AND IsActive=1 ORDER BY BranchCode",c))
        {
            P(cmd,"@company",SqlDbType.BigInt,CompanyId);
            await using var r=await cmd.ExecuteReaderAsync(ct);
            while(await r.ReadAsync(ct)) branches.Add(new {branchId=r.GetInt64(0),code=r.GetString(1),name=r.GetString(2),taxBranchCode=r.IsDBNull(3)?null:r.GetString(3)});
        }
        return Ok(new {vendors,branches});
    }

    [HttpPost]
    public async Task<IActionResult> Save([FromBody] PurchaseTaxSave input, CancellationToken ct)
    {
        var editing=input.PurchaseTaxInvoiceId is >0;
        if(input.VendorId<=0 || string.IsNullOrWhiteSpace(input.SupplierInvoiceCode) || input.SupplierInvoiceCode.Trim().Length>100 ||
           (input.VendorTaxBranchCode is { Length: >0 } && (input.VendorTaxBranchCode.Length!=5 || !input.VendorTaxBranchCode.All(char.IsDigit))) ||
           input.InvoiceDate.Year<2000 || input.ReceivedDate.Year<2000 || input.TaxYear is <2000 or >2200 ||
           input.TaxMonth is <1 or >12 || input.TaxRate is <0 or >100 ||
           input.ClaimStatus is not ("ELIGIBLE" or "INELIGIBLE" or "REVIEW") ||
           input.Lines is null || input.Lines.Count==0 || input.Lines.Count>500 ||
           input.Lines.Any(x=>string.IsNullOrWhiteSpace(x.Description)||x.Description.Length>500||x.Quantity<=0||x.UnitPrice<0) ||
           (input.ClaimStatus!="ELIGIBLE" && string.IsNullOrWhiteSpace(input.ClaimReason)))
            return BadRequest(new {message="ข้อมูลใบกำกับภาษีซื้อไม่ครบหรือไม่ถูกต้อง"});
        await using var c=await Open(ct);
        if(!await Can(c,User,editing?"EDIT":"CREATE",ct)) return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        try
        {
            string vendorName; string? vendorTaxId;
            await using(var cmd=new SqlCommand("SELECT VendorName,TaxID FROM dbo.TDAPVendor WHERE CompanyID=@company AND VendorID=@vendor AND IsActive=1",c,tx))
            {
                P(cmd,"@company",SqlDbType.BigInt,CompanyId);P(cmd,"@vendor",SqlDbType.BigInt,input.VendorId);
                await using var r=await cmd.ExecuteReaderAsync(ct);
                if(!await r.ReadAsync(ct)) return await Reject(tx,ct,"ไม่พบผู้ขายในบริษัทนี้");
                vendorName=r.GetString(0); vendorTaxId=r.IsDBNull(1)?null:r.GetString(1);
            }
            if(input.BranchId.HasValue)
            {
                await using var cmd=new SqlCommand("SELECT COUNT(1) FROM dbo.TDADBranch WHERE CompanyID=@company AND BranchID=@branch AND IsActive=1",c,tx);
                P(cmd,"@company",SqlDbType.BigInt,CompanyId);P(cmd,"@branch",SqlDbType.BigInt,input.BranchId);
                if(Convert.ToInt32(await cmd.ExecuteScalarAsync(ct))==0) return await Reject(tx,ct,"ไม่พบสาขาในบริษัทนี้");
            }
            await using(var duplicate=new SqlCommand("""
                SELECT COUNT(1) FROM dbo.TDAPTaxInvoice WITH(UPDLOCK,HOLDLOCK)
                WHERE CompanyID=@company AND VendorID=@vendor AND SupplierInvoiceCode=@supplier
                  AND StatusCode<>N'VOID' AND (@id IS NULL OR PurchaseTaxInvoiceID<>@id)
                """,c,tx))
            {
                P(duplicate,"@company",SqlDbType.BigInt,CompanyId);P(duplicate,"@vendor",SqlDbType.BigInt,input.VendorId);
                P(duplicate,"@supplier",SqlDbType.NVarChar,input.SupplierInvoiceCode.Trim());
                P(duplicate,"@id",SqlDbType.BigInt,input.PurchaseTaxInvoiceId);
                if(Convert.ToInt32(await duplicate.ExecuteScalarAsync(ct))>0)
                    return await Reject(tx,ct,"เลขใบกำกับภาษีของผู้ขายรายนี้ซ้ำ");
            }
            if(editing)
            {
                await using var cmd=new SqlCommand("SELECT StatusCode FROM dbo.TDAPTaxInvoice WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND PurchaseTaxInvoiceID=@id",c,tx);
                P(cmd,"@company",SqlDbType.BigInt,CompanyId);P(cmd,"@id",SqlDbType.BigInt,input.PurchaseTaxInvoiceId);
                if((await cmd.ExecuteScalarAsync(ct))?.ToString()!="DRAFT") return await Reject(tx,ct,"แก้ไขได้เฉพาะเอกสารร่าง");
            }
            decimal taxBase=input.Lines.Sum(x=>Math.Round(x.Quantity*x.UnitPrice,2,MidpointRounding.AwayFromZero));
            decimal taxAmount=Math.Round(taxBase*input.TaxRate/100,2,MidpointRounding.AwayFromZero);
            var id=input.PurchaseTaxInvoiceId??0;
            if(!editing)
            {
                await using var number=new SqlCommand("SELECT ISNULL(MAX(TRY_CONVERT(int,SUBSTRING(InternalCode,3,20))),0)+1 FROM dbo.TDAPTaxInvoice WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND InternalCode LIKE N'PI%'",c,tx);
                P(number,"@company",SqlDbType.BigInt,CompanyId);
                var code=$"PI{Convert.ToInt32(await number.ExecuteScalarAsync(ct)):D6}";
                await using var cmd=new SqlCommand("""
                    INSERT dbo.TDAPTaxInvoice(CompanyID,BranchID,VendorID,VendorNameSnapshot,VendorTaxIDSnapshot,VendorTaxBranchCode,
                    InternalCode,SupplierInvoiceCode,InvoiceDate,ReceivedDate,TaxYear,TaxMonth,TaxBase,TaxRate,TaxAmount,
                    ClaimStatus,ClaimReason,StatusCode,CreateBy)
                    OUTPUT INSERTED.PurchaseTaxInvoiceID
                    VALUES(@company,@branch,@vendor,@name,@taxId,@taxBranch,@code,@supplier,@invoiceDate,@receivedDate,
                    @year,@month,@base,@rate,@tax,@claim,@reason,N'DRAFT',@user)
                    """,c,tx);
                Bind(cmd,input,vendorName,vendorTaxId,taxBase,taxAmount);
                P(cmd,"@code",SqlDbType.NVarChar,code);
                id=Convert.ToInt64(await cmd.ExecuteScalarAsync(ct));
            }
            else
            {
                await using var cmd=new SqlCommand("""
                    UPDATE dbo.TDAPTaxInvoice SET BranchID=@branch,VendorID=@vendor,VendorNameSnapshot=@name,
                    VendorTaxIDSnapshot=@taxId,VendorTaxBranchCode=@taxBranch,SupplierInvoiceCode=@supplier,
                    InvoiceDate=@invoiceDate,ReceivedDate=@receivedDate,TaxYear=@year,TaxMonth=@month,
                    TaxBase=@base,TaxRate=@rate,TaxAmount=@tax,ClaimStatus=@claim,ClaimReason=@reason,
                    UpdateDate=SYSUTCDATETIME(),UpdateBy=@user
                    WHERE CompanyID=@company AND PurchaseTaxInvoiceID=@id AND StatusCode=N'DRAFT'
                    """,c,tx);
                Bind(cmd,input,vendorName,vendorTaxId,taxBase,taxAmount);
                P(cmd,"@id",SqlDbType.BigInt,id);
                if(await cmd.ExecuteNonQueryAsync(ct)!=1) return await Reject(tx,ct,"แก้ไขเอกสารไม่สำเร็จ");
                await using var del=new SqlCommand("DELETE dbo.TDAPTaxInvoiceDetail WHERE PurchaseTaxInvoiceID=@id",c,tx);
                P(del,"@id",SqlDbType.BigInt,id);await del.ExecuteNonQueryAsync(ct);
            }
            for(var i=0;i<input.Lines.Count;i++)
            {
                var line=input.Lines[i];
                await using var cmd=new SqlCommand("""
                    INSERT dbo.TDAPTaxInvoiceDetail(PurchaseTaxInvoiceID,ItemNo,Description,Quantity,UnitPrice,TaxBase)
                    VALUES(@id,@no,@desc,@qty,@price,@base)
                    """,c,tx);
                P(cmd,"@id",SqlDbType.BigInt,id);P(cmd,"@no",SqlDbType.Int,i+1);
                P(cmd,"@desc",SqlDbType.NVarChar,line.Description.Trim());P(cmd,"@qty",SqlDbType.Decimal,line.Quantity);
                P(cmd,"@price",SqlDbType.Decimal,line.UnitPrice);
                P(cmd,"@base",SqlDbType.Decimal,Math.Round(line.Quantity*line.UnitPrice,2,MidpointRounding.AwayFromZero));
                await cmd.ExecuteNonQueryAsync(ct);
            }
            await tx.CommitAsync(ct);
            return Ok(new {purchaseTaxInvoiceId=id,statusCode="DRAFT",taxBase,taxAmount});
        }
        catch(SqlException ex) when(ex.Number is 2601 or 2627)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new {message="เลขที่เอกสารซ้ำ กรุณาตรวจสอบอีกครั้ง"});
        }
    }

    [HttpPost("{id:long}/confirm")]
    public async Task<IActionResult> Confirm(long id,CancellationToken ct)
    {
        await using var c=await Open(ct);
        if(!await Can(c,User,"EDIT",ct)) return Forbid();
        await using var cmd=new SqlCommand("""
            UPDATE P SET StatusCode=N'CONFIRMED',UpdateDate=SYSUTCDATETIME(),UpdateBy=@user
            FROM dbo.TDAPTaxInvoice P
            JOIN dbo.TDADBranch B ON B.CompanyID=P.CompanyID AND B.BranchID=P.BranchID AND B.IsActive=1
            WHERE P.CompanyID=@company AND P.PurchaseTaxInvoiceID=@id AND P.StatusCode=N'DRAFT'
              AND LEN(B.TaxBranchCode)=5 AND LEN(P.VendorTaxIDSnapshot)=13
              AND LEN(P.VendorTaxBranchCode)=5
            """,c);
        P(cmd,"@company",SqlDbType.BigInt,CompanyId);P(cmd,"@id",SqlDbType.BigInt,id);P(cmd,"@user",SqlDbType.BigInt,UserId);
        return await cmd.ExecuteNonQueryAsync(ct)==1 ? Ok(new {statusCode="CONFIRMED"}) :
            BadRequest(new {message="ยังยืนยันไม่ได้",description="ตรวจสาขาภาษีของบริษัท เลขภาษีและสาขาผู้ขาย"});
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,CancellationToken ct)
    {
        await using var c=await Open(ct);
        if(!await Can(c,User,"DELETE",ct)) return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        await using(var state=new SqlCommand("SELECT StatusCode FROM dbo.TDAPTaxInvoice WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND PurchaseTaxInvoiceID=@id",c,tx))
        {
            P(state,"@company",SqlDbType.BigInt,CompanyId);P(state,"@id",SqlDbType.BigInt,id);
            if((await state.ExecuteScalarAsync(ct))?.ToString()!="DRAFT")
                return await Reject(tx,ct,"ลบได้เฉพาะใบกำกับภาษีซื้อสถานะร่าง");
        }
        await using(var details=new SqlCommand("DELETE dbo.TDAPTaxInvoiceDetail WHERE PurchaseTaxInvoiceID=@id",c,tx))
        {P(details,"@id",SqlDbType.BigInt,id);await details.ExecuteNonQueryAsync(ct);}
        await using(var header=new SqlCommand("DELETE dbo.TDAPTaxInvoice WHERE CompanyID=@company AND PurchaseTaxInvoiceID=@id AND StatusCode=N'DRAFT'",c,tx))
        {P(header,"@company",SqlDbType.BigInt,CompanyId);P(header,"@id",SqlDbType.BigInt,id);await header.ExecuteNonQueryAsync(ct);}
        await tx.CommitAsync(ct);
        return NoContent();
    }

    private void Bind(SqlCommand cmd,PurchaseTaxSave x,string vendorName,string? vendorTaxId,decimal taxBase,decimal tax)
    {
        P(cmd,"@company",SqlDbType.BigInt,CompanyId);P(cmd,"@branch",SqlDbType.BigInt,x.BranchId);
        P(cmd,"@vendor",SqlDbType.BigInt,x.VendorId);P(cmd,"@name",SqlDbType.NVarChar,vendorName);
        P(cmd,"@taxId",SqlDbType.NVarChar,vendorTaxId);P(cmd,"@taxBranch",SqlDbType.NVarChar,x.VendorTaxBranchCode?.Trim());
        P(cmd,"@supplier",SqlDbType.NVarChar,x.SupplierInvoiceCode.Trim());
        P(cmd,"@invoiceDate",SqlDbType.Date,x.InvoiceDate.Date);P(cmd,"@receivedDate",SqlDbType.Date,x.ReceivedDate.Date);
        P(cmd,"@year",SqlDbType.Int,x.TaxYear);P(cmd,"@month",SqlDbType.TinyInt,x.TaxMonth);
        P(cmd,"@base",SqlDbType.Decimal,taxBase);P(cmd,"@rate",SqlDbType.Decimal,x.TaxRate);
        P(cmd,"@tax",SqlDbType.Decimal,tax);P(cmd,"@claim",SqlDbType.NVarChar,x.ClaimStatus);
        P(cmd,"@reason",SqlDbType.NVarChar,x.ClaimReason?.Trim());P(cmd,"@user",SqlDbType.BigInt,UserId);
    }
    private static async Task<IActionResult> Reject(SqlTransaction tx,CancellationToken ct,string message)
    {
        await tx.RollbackAsync(ct);return new BadRequestObjectResult(new {message});
    }
}
