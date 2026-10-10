using System.Data;
using System.Security.Claims;
using LaooServiceModule.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;

[ApiController, Authorize, LaooServiceModule.Security.RequireCompanyFeature("SALES")]
[LaooServiceModule.Security.RequireCompanyProject("LAOO")]
[TypeFilter(typeof(ItemProjectExceptionFilter))]
[Route("api/company/tax-reports")]
public sealed class TaxReportController(IConfiguration configuration) : ControllerBase
{
    private readonly IConfiguration _configuration = configuration;

    [HttpGet("branches")]
    public async Task<IActionResult> Branches(CancellationToken token)
    {
        await using var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(token);
        if (!await Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedAsync(c, User, "09019", "VIEW", token)
            && !await Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedAsync(c, User, "09020", "VIEW", token)) return Forbid();
        var companyId = long.TryParse(User.FindFirstValue("company_id"), out var id) ? id : 0;
        await using var cmd = new SqlCommand("SELECT BranchID,BranchNameTH,TaxBranchCode FROM dbo.TDADBranch WHERE CompanyID=@company AND IsActive=1 ORDER BY BranchCode", c);
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId;
        var rows = new List<object>();
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
            rows.Add(new { branchId=r.GetInt64(0), name=r.GetString(1), taxBranchCode=r.IsDBNull(2)?null:r.GetString(2) });
        return Ok(rows);
    }

    [HttpGet("{type}")]
    public async Task<IActionResult> Get(string type, [FromQuery] int year, [FromQuery] int month, [FromQuery] long? branchId, CancellationToken token)
    {
        var sale = type.Equals("sales", StringComparison.OrdinalIgnoreCase);
        if (!sale && !type.Equals("purchases", StringComparison.OrdinalIgnoreCase)) return NotFound();
        if (year is < 2000 or > 2200 || month is < 1 or > 12) return BadRequest(new { message = "เดือนภาษีไม่ถูกต้อง" });
        var companyId = long.TryParse(User.FindFirstValue("company_id"), out var id) ? id : 0;
        await using var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await c.OpenAsync(token);
        if (!await Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedAsync(c, User, sale ? "09019" : "09020", "VIEW", token)) return Forbid();
        if (branchId.HasValue)
        {
            await using var branch = new SqlCommand("SELECT COUNT(1) FROM dbo.TDADBranch WHERE CompanyID=@company AND BranchID=@branch AND IsActive=1", c);
            branch.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId;
            branch.Parameters.Add("@branch", SqlDbType.BigInt).Value = branchId.Value;
            if (Convert.ToInt32(await branch.ExecuteScalarAsync(token)) == 0) return BadRequest(new { message = "ไม่พบสาขาในบริษัทนี้" });
        }
        string companyName = "", companyTaxId = "", branchName = "", branchTaxCode = "";
        await using (var identity = new SqlCommand("""
            SELECT TOP 1 COALESCE(NULLIF(C.CustomerNameTH,N''),C.Name),COALESCE(C.TaxID,N''),
                   COALESCE(B.BranchNameTH,N''),COALESCE(B.TaxBranchCode,N'')
            FROM dbo.TDSTCompanySetUp C
            LEFT JOIN dbo.TDADBranch B ON B.CompanyID=C.CompanyID AND B.BranchID=@branch
            WHERE C.CompanyID=@company AND C.IsActive=1
            """,c))
        {
            identity.Parameters.Add("@company",SqlDbType.BigInt).Value=companyId;
            identity.Parameters.Add("@branch",SqlDbType.BigInt).Value=(object?)branchId??DBNull.Value;
            await using var identityReader=await identity.ExecuteReaderAsync(token);
            if(await identityReader.ReadAsync(token))
            {
                companyName=identityReader.GetString(0);companyTaxId=identityReader.GetString(1);
                branchName=identityReader.GetString(2);branchTaxCode=identityReader.GetString(3);
            }
        }
        var sql = sale ? """
            SELECT T.TaxInvoiceID,T.TaxInvoiceCode,T.TaxInvoiceDate,T.CusName,T.TaxID,
                   T.BranchID,B.TaxBranchCode,T.CustomerTaxBranchCode,T.AmountAfterDiscount,T.TaxPercent,T.TaxAmount,
                   CAST(NULL AS nvarchar(20)) ClaimStatus,CAST(NULL AS date) ReceivedDate
            FROM dbo.TDARTaxInvoice T
            LEFT JOIN dbo.TDADBranch B ON B.BranchID=T.BranchID AND B.CompanyID=T.CompanyID
            WHERE T.CompanyID=@company AND T.IsActive=1 AND T.StatusCode=N'ISSUED'
              AND T.TaxInvoiceDate>=@start AND T.TaxInvoiceDate<@end
              AND (@branch IS NULL OR T.BranchID=@branch)
            ORDER BY T.TaxInvoiceDate,T.TaxInvoiceCode,T.TaxInvoiceID
            """ : """
            SELECT P.PurchaseTaxInvoiceID,P.SupplierInvoiceCode,P.InvoiceDate,P.VendorNameSnapshot,P.VendorTaxIDSnapshot,
                   P.BranchID,B.TaxBranchCode,P.VendorTaxBranchCode,P.TaxBase,P.TaxRate,P.TaxAmount,
                   P.ClaimStatus,P.ReceivedDate
            FROM dbo.TDAPTaxInvoice P
            LEFT JOIN dbo.TDADBranch B ON B.BranchID=P.BranchID AND B.CompanyID=P.CompanyID
            WHERE P.CompanyID=@company AND P.StatusCode=N'CONFIRMED'
              AND P.TaxYear=@year AND P.TaxMonth=@month
              AND (@branch IS NULL OR P.BranchID=@branch)
            ORDER BY P.InvoiceDate,P.SupplierInvoiceCode,P.PurchaseTaxInvoiceID
            """;
        await using var cmd = new SqlCommand(sql, c);
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId;
        cmd.Parameters.Add("@branch", SqlDbType.BigInt).Value = (object?)branchId ?? DBNull.Value;
        if (sale)
        {
            cmd.Parameters.Add("@start", SqlDbType.Date).Value = new DateTime(year, month, 1);
            cmd.Parameters.Add("@end", SqlDbType.Date).Value = new DateTime(year, month, 1).AddMonths(1);
        }
        else
        {
            cmd.Parameters.Add("@year", SqlDbType.Int).Value = year;
            cmd.Parameters.Add("@month", SqlDbType.TinyInt).Value = month;
        }
        var rows = new List<object>();
        decimal baseTotal = 0, taxTotal = 0, eligibleTax = 0;
        decimal ratedTaxBase = 0, zeroRatedTaxBase = 0;
        var unassigned = 0;
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
        {
            var taxBase = r.GetDecimal(8);
            var tax = r.GetDecimal(10);
            var claim = r.IsDBNull(11) ? null : r.GetString(11);
            var missingBranch = r.IsDBNull(5) || r.IsDBNull(6);
            if (missingBranch) unassigned++;
            baseTotal += taxBase;
            taxTotal += tax;
            if (sale)
            {
                if (r.GetDecimal(9) == 0) zeroRatedTaxBase += taxBase;
                else ratedTaxBase += taxBase;
            }
            if (sale || claim == "ELIGIBLE") eligibleTax += tax;
            rows.Add(new
            {
                sourceId = r.GetInt64(0), invoiceCode = r.GetString(1), invoiceDate = r.GetDateTime(2),
                counterparty = r.GetString(3), taxId = r.IsDBNull(4) ? null : r.GetString(4),
                branchId = r.IsDBNull(5) ? (long?)null : r.GetInt64(5),
                branchTaxCode = r.IsDBNull(6) ? null : r.GetString(6),
                counterpartyTaxBranchCode = r.IsDBNull(7) ? null : r.GetString(7),
                taxBase, taxRate = r.GetDecimal(9), taxAmount = tax,
                claimStatus = claim, receivedDate = r.IsDBNull(12) ? (DateTime?)null : r.GetDateTime(12),
                needsReview = missingBranch || string.IsNullOrWhiteSpace(r.IsDBNull(4) ? null : r.GetString(4)) || (!sale && claim == "REVIEW")
            });
        }
        return Ok(new { type = sale ? "SALE" : "PURCHASE", year, month, branchId,
            companyName, companyTaxId, branchName, branchTaxCode, rows,
            summary = new { count = rows.Count, taxBase = baseTotal, ratedTaxBase, zeroRatedTaxBase,
                taxAmount = taxTotal, eligibleTaxAmount = eligibleTax, unassignedBranchCount = unassigned },
            note = "รายงานตรวจสอบจากใบกำกับภาษีส่วนกลางเท่านั้น ยังไม่รวม POS, School Food, Rental หรือใบเพิ่ม–ลดหนี้ ไม่ใช่แบบ ภ.พ.30 และไม่ยื่นอัตโนมัติ" });
    }
}
