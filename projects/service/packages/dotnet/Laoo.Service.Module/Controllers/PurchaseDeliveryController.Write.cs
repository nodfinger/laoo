using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;
public sealed partial class PurchaseDeliveryController
{
    [HttpPost]
    public async Task<IActionResult> Save([FromBody]PurchaseDeliverySave x,CancellationToken ct)
    {
        var edit=x.PurchaseDeliveryId is >0;
        if(x.VendorId<=0||x.DeliveryDate.Year<2000||x.PaymentType is not("CASH" or "CREDIT")||
           x.CreditDays is <0 or >3650||(x.PaymentType=="CASH"&&x.CreditDays!=0)||(x.PaymentType=="CREDIT"&&x.CreditDays<1)||
           x.SupplierDocumentCode is{Length:>100}||x.Remark is{Length:>1000}||x.Lines is null||x.Lines.Count is <1 or >500||
           x.Lines.Any(l=>l.ItemId.HasValue||string.IsNullOrWhiteSpace(l.Description)||l.Description.Trim().Length>500||l.Quantity<=0||l.UnitPrice<0))
            return BadRequest(new{message="Invalid purchase document",description="Select a vendor, date and payment method; add at least one line. Credit purchases require at least one credit day."});
        await using var c=await Open(ct);if(!await Can(c,User,edit?"EDIT":"CREATE",ct))return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        try
        {
            await using(var v=new SqlCommand("SELECT COUNT(1) FROM dbo.TDAPVendor WHERE CompanyID=@c AND VendorID=@v AND IsActive=1",c,tx))
            {P(v,"@c",SqlDbType.BigInt,CompanyId);P(v,"@v",SqlDbType.BigInt,x.VendorId);if(Convert.ToInt32(await v.ExecuteScalarAsync(ct))!=1)return await Reject(tx,ct,"Vendor is not active for this company");}
            if(x.BranchId.HasValue)
            {await using var b=new SqlCommand("SELECT COUNT(1) FROM dbo.TDADBranch WHERE CompanyID=@c AND BranchID=@b AND IsActive=1",c,tx);P(b,"@c",SqlDbType.BigInt,CompanyId);P(b,"@b",SqlDbType.BigInt,x.BranchId);if(Convert.ToInt32(await b.ExecuteScalarAsync(ct))!=1)return await Reject(tx,ct,"Branch is not active for this company");}
            if(!string.IsNullOrWhiteSpace(x.SupplierDocumentCode))
            {
                await using var d=new SqlCommand("SELECT COUNT(1) FROM dbo.TDAPPurchaseDelivery WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND VendorID=@v AND SupplierDocumentCode=@s AND StatusCode<>N'VOID' AND (@id IS NULL OR PurchaseDeliveryID<>@id)",c,tx);
                P(d,"@c",SqlDbType.BigInt,CompanyId);P(d,"@v",SqlDbType.BigInt,x.VendorId);P(d,"@s",SqlDbType.NVarChar,x.SupplierDocumentCode.Trim(),100);P(d,"@id",SqlDbType.BigInt,x.PurchaseDeliveryId);
                if(Convert.ToInt32(await d.ExecuteScalarAsync(ct))>0)return await Reject(tx,ct,"Supplier document number already exists");
            }
            if(edit)
            {await using var s=new SqlCommand("SELECT StatusCode FROM dbo.TDAPPurchaseDelivery WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND PurchaseDeliveryID=@id",c,tx);P(s,"@c",SqlDbType.BigInt,CompanyId);P(s,"@id",SqlDbType.BigInt,x.PurchaseDeliveryId);if((await s.ExecuteScalarAsync(ct))?.ToString()!="DRAFT")return await Reject(tx,ct,"Only draft purchase documents can be edited");}
            var total=x.Lines.Sum(l=>Math.Round(l.Quantity*l.UnitPrice,2,MidpointRounding.AwayFromZero));
            if(total<=0)return await Reject(tx,ct,"Document total must be greater than zero");
            var due=x.PaymentType=="CASH"?x.DeliveryDate.Date:x.DeliveryDate.Date.AddDays(x.CreditDays);
            long id=x.PurchaseDeliveryId??0;string? code=null;
            if(!edit)
            {
                await using var n=new SqlCommand("SELECT ISNULL(MAX(TRY_CONVERT(int,SUBSTRING(DeliveryCode,3,20))),0)+1 FROM dbo.TDAPPurchaseDelivery WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND DeliveryCode LIKE N'PD%'",c,tx);
                P(n,"@c",SqlDbType.BigInt,CompanyId);code=$"PD{Convert.ToInt32(await n.ExecuteScalarAsync(ct)):D6}";
                await using var q=new SqlCommand("INSERT dbo.TDAPPurchaseDelivery(CompanyID,BranchID,VendorID,DeliveryCode,SupplierDocumentCode,DeliveryDate,PaymentType,CreditDays,DueDate,TotalAmount,StatusCode,Remark,CreatedBy) OUTPUT INSERTED.PurchaseDeliveryID VALUES(@c,@b,@v,@code,@supplier,@date,@type,@days,@due,@total,N'DRAFT',@remark,@user)",c,tx);
                Bind(q,x,total,due);P(q,"@c",SqlDbType.BigInt,CompanyId);P(q,"@v",SqlDbType.BigInt,x.VendorId);P(q,"@code",SqlDbType.NVarChar,code,30);P(q,"@user",SqlDbType.BigInt,UserId);id=Convert.ToInt64(await q.ExecuteScalarAsync(ct));
            }
            else
            {
                await using var q=new SqlCommand("UPDATE dbo.TDAPPurchaseDelivery SET BranchID=@b,VendorID=@v,SupplierDocumentCode=@supplier,DeliveryDate=@date,PaymentType=@type,CreditDays=@days,DueDate=@due,TotalAmount=@total,Remark=@remark,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE CompanyID=@c AND PurchaseDeliveryID=@id AND StatusCode=N'DRAFT'",c,tx);
                Bind(q,x,total,due);P(q,"@c",SqlDbType.BigInt,CompanyId);P(q,"@v",SqlDbType.BigInt,x.VendorId);P(q,"@id",SqlDbType.BigInt,id);P(q,"@user",SqlDbType.BigInt,UserId);if(await q.ExecuteNonQueryAsync(ct)!=1)return await Reject(tx,ct,"Could not save the purchase document");
                await using var d=new SqlCommand("DELETE dbo.TDAPPurchaseDeliveryDetail WHERE PurchaseDeliveryID=@id",c,tx);P(d,"@id",SqlDbType.BigInt,id);await d.ExecuteNonQueryAsync(ct);
            }
            for(var i=0;i<x.Lines.Count;i++)
            {var l=x.Lines[i];await using var q=new SqlCommand("INSERT dbo.TDAPPurchaseDeliveryDetail(PurchaseDeliveryID,ItemNo,Description,Quantity,UnitPrice,Amount) VALUES(@id,@no,@desc,@qty,@price,@amount)",c,tx);P(q,"@id",SqlDbType.BigInt,id);P(q,"@no",SqlDbType.Int,i+1);P(q,"@desc",SqlDbType.NVarChar,l.Description.Trim(),500);P(q,"@qty",SqlDbType.Decimal,l.Quantity);P(q,"@price",SqlDbType.Decimal,l.UnitPrice);P(q,"@amount",SqlDbType.Decimal,Math.Round(l.Quantity*l.UnitPrice,2,MidpointRounding.AwayFromZero));await q.ExecuteNonQueryAsync(ct);}
            await Audit(c,tx,id,edit?"UPDATE_DRAFT":"CREATE_DRAFT",ct);await tx.CommitAsync(ct);return Ok(new{purchaseDeliveryId=id,deliveryCode=code,totalAmount=total,statusCode="DRAFT"});
        }
        catch(SqlException ex) when(ex.Number is 2601 or 2627)
        {await tx.RollbackAsync(ct);return Conflict(new{message="Duplicate purchase document",description="Check the supplier and internal document numbers before trying again"});}
    }

    private void Bind(SqlCommand q,PurchaseDeliverySave x,decimal total,DateTime due)
    {P(q,"@b",SqlDbType.BigInt,x.BranchId);P(q,"@v",SqlDbType.BigInt,x.VendorId);P(q,"@supplier",SqlDbType.NVarChar,string.IsNullOrWhiteSpace(x.SupplierDocumentCode)?null:x.SupplierDocumentCode.Trim(),100);P(q,"@date",SqlDbType.Date,x.DeliveryDate.Date);P(q,"@type",SqlDbType.NVarChar,x.PaymentType,10);P(q,"@days",SqlDbType.Int,x.PaymentType=="CASH"?0:x.CreditDays);P(q,"@due",SqlDbType.Date,due);P(q,"@total",SqlDbType.Decimal,total);P(q,"@remark",SqlDbType.NVarChar,string.IsNullOrWhiteSpace(x.Remark)?null:x.Remark.Trim(),1000);}

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> VoidDraft(long id,CancellationToken ct)
    {await using var c=await Open(ct);if(!await Can(c,User,"DELETE",ct))return Forbid();await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,ct);await using var q=new SqlCommand("UPDATE dbo.TDAPPurchaseDelivery SET StatusCode=N'VOID',UpdateDate=SYSUTCDATETIME(),UpdatedBy=@u WHERE CompanyID=@c AND PurchaseDeliveryID=@id AND StatusCode=N'DRAFT'",c,tx);P(q,"@u",SqlDbType.BigInt,UserId);P(q,"@c",SqlDbType.BigInt,CompanyId);P(q,"@id",SqlDbType.BigInt,id);if(await q.ExecuteNonQueryAsync(ct)!=1)return await Reject(tx,ct,"This company can cancel draft documents only.");await Audit(c,tx,id,"VOID_DRAFT",ct);await tx.CommitAsync(ct);return NoContent();}
}
