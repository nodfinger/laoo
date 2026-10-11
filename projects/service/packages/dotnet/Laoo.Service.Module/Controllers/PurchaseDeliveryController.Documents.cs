using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;
public sealed partial class PurchaseDeliveryController
{
    [HttpGet]
    public async Task<IActionResult> List([FromQuery]string? search,[FromQuery]string? status,[FromQuery]int page=1,[FromQuery]int pageSize=20,CancellationToken ct=default)
    {
        await using var c=await Open(ct);if(!await Can(c,User,"VIEW",ct))return Forbid();
        page=Math.Max(page,1);pageSize=Math.Clamp(pageSize,1,100);var filter=string.IsNullOrWhiteSpace(search)?null:$"%{search.Trim()}%";
        var state=string.IsNullOrWhiteSpace(status)||status=="ALL"?null:status;
        await using var q=new SqlCommand("""
            SELECT D.PurchaseDeliveryID,D.DeliveryCode,D.SupplierDocumentCode,D.DeliveryDate,D.PaymentType,D.CreditDays,D.DueDate,D.TotalAmount,D.StatusCode,V.VendorName
            FROM dbo.TDAPPurchaseDelivery D JOIN dbo.TDAPVendor V ON V.CompanyID=D.CompanyID AND V.VendorID=D.VendorID
            WHERE D.CompanyID=@c AND (@s IS NULL OR D.DeliveryCode LIKE @s OR D.SupplierDocumentCode LIKE @s OR V.VendorName LIKE @s) AND (@st IS NULL OR D.StatusCode=@st)
            ORDER BY D.DeliveryDate DESC,D.PurchaseDeliveryID DESC OFFSET @o ROWS FETCH NEXT @n ROWS ONLY;
            SELECT COUNT_BIG(1) FROM dbo.TDAPPurchaseDelivery D JOIN dbo.TDAPVendor V ON V.CompanyID=D.CompanyID AND V.VendorID=D.VendorID
            WHERE D.CompanyID=@c AND (@s IS NULL OR D.DeliveryCode LIKE @s OR D.SupplierDocumentCode LIKE @s OR V.VendorName LIKE @s) AND (@st IS NULL OR D.StatusCode=@st);
            """,c);
        P(q,"@c",SqlDbType.BigInt,CompanyId);P(q,"@s",SqlDbType.NVarChar,filter,202);P(q,"@st",SqlDbType.NVarChar,state,20);P(q,"@o",SqlDbType.Int,(page-1)*pageSize);P(q,"@n",SqlDbType.Int,pageSize);
        var items=new List<object>();long total;
        await using(var r=await q.ExecuteReaderAsync(ct))
        {
            while(await r.ReadAsync(ct))items.Add(new{purchaseDeliveryId=r.GetInt64(0),deliveryCode=r.GetString(1),supplierDocumentCode=r.IsDBNull(2)?null:r.GetString(2),deliveryDate=r.GetDateTime(3),paymentType=r.GetString(4),creditDays=r.GetInt32(5),dueDate=r.IsDBNull(6)?(DateTime?)null:r.GetDateTime(6),totalAmount=r.GetDecimal(7),statusCode=r.GetString(8),vendorName=r.GetString(9)});
            await r.NextResultAsync(ct);await r.ReadAsync(ct);total=r.GetInt64(0);
        }
        return Ok(new{items,total,page,pageSize});
    }
    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken ct)
    {
        await using var c=await Open(ct);if(!await Can(c,User,"VIEW",ct))return Forbid();
        var vendors=new List<object>();var branches=new List<object>();
        await using(var q=new SqlCommand("SELECT VendorID,VendorCode,VendorName FROM dbo.TDAPVendor WHERE CompanyID=@c AND IsActive=1 ORDER BY VendorName",c)){P(q,"@c",SqlDbType.BigInt,CompanyId);await using var r=await q.ExecuteReaderAsync(ct);while(await r.ReadAsync(ct))vendors.Add(new{vendorId=r.GetInt64(0),code=r.GetString(1),name=r.GetString(2)});}
        await using(var q=new SqlCommand("SELECT BranchID,BranchCode,BranchNameTH FROM dbo.TDADBranch WHERE CompanyID=@c AND IsActive=1 ORDER BY BranchCode",c)){P(q,"@c",SqlDbType.BigInt,CompanyId);await using var r=await q.ExecuteReaderAsync(ct);while(await r.ReadAsync(ct))branches.Add(new{branchId=r.GetInt64(0),code=r.GetString(1),name=r.GetString(2)});}
        return Ok(new{vendors,branches});
    }
    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id,CancellationToken ct)
    {
        await using var c=await Open(ct);if(!await Can(c,User,"VIEW",ct))return Forbid();
        await using var q=new SqlCommand("""
            SELECT D.PurchaseDeliveryID,D.DeliveryCode,D.SupplierDocumentCode,D.DeliveryDate,D.PaymentType,D.CreditDays,D.DueDate,D.TotalAmount,D.StatusCode,D.VendorID,V.VendorName,D.BranchID,D.Remark,L.ItemNo,L.Description,L.Quantity,L.UnitPrice,L.Amount
            FROM dbo.TDAPPurchaseDelivery D JOIN dbo.TDAPVendor V ON V.CompanyID=D.CompanyID AND V.VendorID=D.VendorID
            JOIN dbo.TDAPPurchaseDeliveryDetail L ON L.PurchaseDeliveryID=D.PurchaseDeliveryID
            WHERE D.CompanyID=@c AND D.PurchaseDeliveryID=@id ORDER BY L.ItemNo
            """,c);P(q,"@c",SqlDbType.BigInt,CompanyId);P(q,"@id",SqlDbType.BigInt,id);
        object? h=null;var lines=new List<object>();await using var r=await q.ExecuteReaderAsync(ct);
        while(await r.ReadAsync(ct))
        {
            h??=new{purchaseDeliveryId=r.GetInt64(0),deliveryCode=r.GetString(1),supplierDocumentCode=r.IsDBNull(2)?null:r.GetString(2),deliveryDate=r.GetDateTime(3),paymentType=r.GetString(4),creditDays=r.GetInt32(5),dueDate=r.IsDBNull(6)?(DateTime?)null:r.GetDateTime(6),totalAmount=r.GetDecimal(7),statusCode=r.GetString(8),vendorId=r.GetInt64(9),vendorName=r.GetString(10),branchId=r.IsDBNull(11)?(long?)null:r.GetInt64(11),remark=r.IsDBNull(12)?null:r.GetString(12)};
            lines.Add(new{itemNo=r.GetInt32(13),description=r.GetString(14),quantity=r.GetDecimal(15),unitPrice=r.GetDecimal(16),amount=r.GetDecimal(17)});
        }
        return h is null?NotFound(new{message="Purchase document was not found",description="Check the document and active company"}):Ok(new{header=h,lines});
    }
}
