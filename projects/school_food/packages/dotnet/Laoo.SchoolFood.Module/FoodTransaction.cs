using System.Data;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Data.SqlClient;

namespace Laoo.SchoolFood;

public sealed class FoodBusinessException(string message) : Exception(message);

internal static class FoodTransaction
{
    public static async Task<string> Run(SqlConnection db,long company,long actor,Guid key,
        string action,object request, Func<SqlTransaction,long,Task<object>> work,CancellationToken ct)
    {
        if(key==Guid.Empty) throw new FoodBusinessException("ต้องระบุรหัสคำขอเพื่อป้องกันการบันทึกซ้ำ");
        var hash=SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(request));
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        try
        {
            var existing=await FoodDb.Rows(db,tx,"SELECT RequestHash,ActionCode,ActorID,ResultJson FROM dbo.TDSFOperation WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND RequestKey=@key",ct,("@co",company),("@key",key));
            if(existing.Count>0)
            {
                var row=existing[0];
                if(row.Long("ActorID")!=actor || Convert.ToString(row["ActionCode"])!=action ||
                    !CryptographicOperations.FixedTimeEquals((byte[])row["RequestHash"]!,hash))
                    throw new FoodBusinessException("รหัสคำขอถูกใช้กับรายการอื่นแล้ว");
                var result=Convert.ToString(row["ResultJson"]);
                if(string.IsNullOrEmpty(result)) throw new FoodBusinessException("คำขอเดิมยังไม่สำเร็จ กรุณาลองใหม่");
                await tx.CommitAsync(ct);
                return result;
            }
            var id=await FoodDb.Id(db,tx,"INSERT dbo.TDSFOperation(CompanyID,RequestKey,RequestHash,ActionCode,ActorID) OUTPUT INSERTED.OperationID VALUES(@co,@key,@hash,@action,@actor)",ct,
                ("@co",company),("@key",key),("@hash",hash),("@action",action),("@actor",actor));
            var json=JsonSerializer.Serialize(await work(tx,id));
            await FoodDb.Execute(db,tx,"UPDATE dbo.TDSFOperation SET ResultJson=@result WHERE OperationID=@id; INSERT dbo.TDSFAudit(CompanyID,UserID,ActionCode,EntityType,EntityID,DetailJson) VALUES(@co,@actor,@action,N'OPERATION',@id,@result)",ct,
                ("@result",json),("@id",id),("@co",company),("@actor",actor),("@action",action));
            await tx.CommitAsync(ct);
            return json;
        }
        catch { await tx.RollbackAsync(CancellationToken.None); throw; }
    }

    public static async Task<decimal> Wallet(SqlConnection db,SqlTransaction tx,long company,
        long student,long operation,long actor,decimal delta,string type,string reference,string? reason,
        string? method,CancellationToken ct)
    {
        if(delta==0 || delta!=SchoolFoodRules.Money(delta))
            throw new FoodBusinessException("ยอดเงินต้องไม่เป็นศูนย์และมีทศนิยมไม่เกินสองตำแหน่ง");
        if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDSCStudent WHERE CompanyID=@co AND StudentID=@student",
            ct,("@co",company),("@student",student))!=1) throw new FoodBusinessException("ไม่พบนักเรียนในโรงเรียนนี้");
        await FoodDb.Execute(db,tx,"IF NOT EXISTS(SELECT 1 FROM dbo.TDSFWallet WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND StudentID=@student) INSERT dbo.TDSFWallet(CompanyID,StudentID,Balance) VALUES(@co,@student,0)",ct,("@co",company),("@student",student));
        var rows=await FoodDb.Rows(db,tx,"UPDATE dbo.TDSFWallet WITH(UPDLOCK) SET Balance=Balance+@delta OUTPUT INSERTED.Balance WHERE CompanyID=@co AND StudentID=@student AND Balance+@delta>=0",ct,
            ("@delta",delta),("@co",company),("@student",student));
        if(rows.Count!=1) throw new FoodBusinessException("ยอด Wallet ไม่เพียงพอ");
        var balance=rows[0].Decimal("Balance");
        await FoodDb.Execute(db,tx,"INSERT dbo.TDSFWalletLedger(CompanyID,StudentID,OperationID,EntryType,Amount,BalanceAfter,ReferenceNo,Reason,PaymentMethod,CreatedBy) VALUES(@co,@student,@op,@type,@delta,@balance,@ref,@reason,@method,@actor)",ct,
            ("@co",company),("@student",student),("@op",operation),("@type",type),("@delta",delta),("@balance",balance),("@ref",reference),("@reason",reason),("@method",method),("@actor",actor));
        return balance;
    }

    public static async Task Stock(SqlConnection db,SqlTransaction tx,long company,long warehouse,
        long item,decimal delta,string type,long document,long detail,long actor,CancellationToken ct)
    {
        if(await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND WarehouseID=@wh AND IsActive=1",ct,("@co",company),("@wh",warehouse))!=1)
            throw new FoodBusinessException("คลังสินค้าไม่อยู่ในโรงเรียนนี้หรือปิดใช้งาน");
        await FoodDb.Execute(db,tx,"IF NOT EXISTS(SELECT 1 FROM dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND WarehouseID=@wh AND ItemID=@item) INSERT dbo.TDIVStockBalance(CompanyID,WarehouseID,ItemID,Quantity) VALUES(@co,@wh,@item,0)",ct,("@co",company),("@wh",warehouse),("@item",item));
        if(await FoodDb.Execute(db,tx,"UPDATE dbo.TDIVStockBalance WITH(UPDLOCK) SET Quantity=Quantity+@delta,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND WarehouseID=@wh AND ItemID=@item AND Quantity+@delta>=0",ct,("@delta",delta),("@co",company),("@wh",warehouse),("@item",item))!=1)
            throw new FoodBusinessException("สต๊อกไม่เพียงพอ กรุณาลดจำนวนหรือรับสินค้าเพิ่ม");
        await FoodDb.Execute(db,tx,"INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@co,@wh,@item,N'SCHOOL_FOOD',@doc,@detail,@type,@qty,N'School Food',@actor)",ct,
            ("@co",company),("@wh",warehouse),("@item",item),("@doc",document),("@detail",detail),("@type",type),("@qty",delta),("@actor",actor));
    }
}
