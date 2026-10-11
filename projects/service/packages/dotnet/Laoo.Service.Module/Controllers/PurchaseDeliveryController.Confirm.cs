using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;
public sealed partial class PurchaseDeliveryController
{
    [HttpPost("{id:long}/confirm")]
    public async Task<IActionResult> Confirm(long id,CancellationToken ct)
    {
        await using var c=await Open(ct);if(!await Can(c,User,"CONFIRM",ct))return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        try
        {
            long vendor;long? branch;DateTime date,due;decimal amount;string type,code;
            await using(var q=new SqlCommand("SELECT VendorID,BranchID,DeliveryDate,DueDate,TotalAmount,PaymentType,DeliveryCode FROM dbo.TDAPPurchaseDelivery WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND PurchaseDeliveryID=@id AND StatusCode=N'DRAFT'",c,tx))
            {
                P(q,"@c",SqlDbType.BigInt,CompanyId);P(q,"@id",SqlDbType.BigInt,id);await using var r=await q.ExecuteReaderAsync(ct);
                if(!await r.ReadAsync(ct))return await Reject(tx,ct,"Draft purchase document was not found or has already been confirmed");
                vendor=r.GetInt64(0);branch=r.IsDBNull(1)?null:r.GetInt64(1);date=r.GetDateTime(2);due=r.IsDBNull(3)?r.GetDateTime(2):r.GetDateTime(3);amount=r.GetDecimal(4);type=r.GetString(5);code=r.GetString(6);
            }
            await using(var count=new SqlCommand("SELECT COUNT(1) FROM dbo.TDAPPurchaseDeliveryDetail WHERE PurchaseDeliveryID=@id",c,tx))
            {P(count,"@id",SqlDbType.BigInt,id);if(Convert.ToInt32(await count.ExecuteScalarAsync(ct))<1)return await Reject(tx,ct,"Add at least one purchase line before confirmation");}
            var debtStatus=type=="CASH"?"SETTLED":"OPEN";long debt;
            await using(var q=new SqlCommand("INSERT dbo.TDAPPayable(CompanyID,BranchID,VendorID,SourceType,SourceID,SourceCode,DocumentDate,DueDate,OriginalAmount,StatusCode,CreatedBy) OUTPUT INSERTED.PayableID VALUES(@c,@b,@v,N'PURCHASE_DELIVERY',@id,@code,@date,@due,@amount,@status,@user)",c,tx))
            {P(q,"@c",SqlDbType.BigInt,CompanyId);P(q,"@b",SqlDbType.BigInt,branch);P(q,"@v",SqlDbType.BigInt,vendor);P(q,"@id",SqlDbType.BigInt,id);P(q,"@code",SqlDbType.NVarChar,code,100);P(q,"@date",SqlDbType.Date,date);P(q,"@due",SqlDbType.Date,due);P(q,"@amount",SqlDbType.Decimal,amount);P(q,"@status",SqlDbType.NVarChar,debtStatus,20);P(q,"@user",SqlDbType.BigInt,UserId);debt=Convert.ToInt64(await q.ExecuteScalarAsync(ct));}
            if(type=="CASH")
            {
                await using var n=new SqlCommand("SELECT ISNULL(MAX(TRY_CONVERT(int,SUBSTRING(PaymentCode,3,20))),0)+1 FROM dbo.TDAPPayment WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND PaymentCode LIKE N'PP%'",c,tx);P(n,"@c",SqlDbType.BigInt,CompanyId);var paymentCode=$"PP{Convert.ToInt32(await n.ExecuteScalarAsync(ct)):D6}";long paymentId;
                await using(var q=new SqlCommand("INSERT dbo.TDAPPayment(CompanyID,BranchID,VendorID,PaymentCode,PaymentDate,Amount,PaymentMethod,StatusCode,RunID,CreatedBy,PostedAt) OUTPUT INSERTED.PaymentID VALUES(@c,@b,@v,@code,@date,@amount,N'CASH',N'POSTED',@run,@user,SYSUTCDATETIME())",c,tx))
                {P(q,"@c",SqlDbType.BigInt,CompanyId);P(q,"@b",SqlDbType.BigInt,branch);P(q,"@v",SqlDbType.BigInt,vendor);P(q,"@code",SqlDbType.NVarChar,paymentCode,30);P(q,"@date",SqlDbType.Date,date);P(q,"@amount",SqlDbType.Decimal,amount);P(q,"@run",SqlDbType.NVarChar,$"PD-{id}",80);P(q,"@user",SqlDbType.BigInt,UserId);paymentId=Convert.ToInt64(await q.ExecuteScalarAsync(ct));}
                await using var a=new SqlCommand("INSERT dbo.TDAPPaymentAllocation(PaymentID,PayableID,Amount) VALUES(@p,@d,@a)",c,tx);P(a,"@p",SqlDbType.BigInt,paymentId);P(a,"@d",SqlDbType.BigInt,debt);P(a,"@a",SqlDbType.Decimal,amount);await a.ExecuteNonQueryAsync(ct);
            }
            await using(var q=new SqlCommand("UPDATE dbo.TDAPPurchaseDelivery SET StatusCode=N'CONFIRMED',ConfirmDate=SYSUTCDATETIME(),ConfirmedBy=@u WHERE CompanyID=@c AND PurchaseDeliveryID=@id AND StatusCode=N'DRAFT'",c,tx))
            {P(q,"@u",SqlDbType.BigInt,UserId);P(q,"@c",SqlDbType.BigInt,CompanyId);P(q,"@id",SqlDbType.BigInt,id);if(await q.ExecuteNonQueryAsync(ct)!=1)return await Reject(tx,ct,"Could not confirm the purchase document");}
            await Audit(c,tx,id,"CONFIRM",ct);await tx.CommitAsync(ct);return Ok(new{statusCode="CONFIRMED",payableStatus=debtStatus,payableId=debt});
        }
        catch(SqlException ex)when(ex.Number is 2601 or 2627)
        {await tx.RollbackAsync(ct);return Conflict(new{message="Purchase document was already processed",description="Refresh the list and verify its status and payable entry"});}
    }
}
