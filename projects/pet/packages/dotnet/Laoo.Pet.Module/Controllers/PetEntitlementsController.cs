using Laoo.Pet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
namespace Laoo.Pet.Controllers;
[ApiController,Authorize,Route("api/company/pet/entitlements")]
public sealed class PetEntitlementsController(IConfiguration config) : PetControllerBase(config)
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct,long? memberId=null,int page=1,int pageSize=20)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("เลขหน้าหรือจำนวนรายการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62005","VIEW",ct) is { } no)return no;
        var total=await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDPTEntitlement WHERE CompanyID=@c AND (@member IS NULL OR MemberID=@member)",ct,("@c",Company),("@member",memberId));
        var items=await PetDb.Rows(db,null,"SELECT E.EntitlementID id,E.MemberID memberId,E.PackageID packageId,P.PackageName packageName,E.StartsOn startsOn,E.ExpiresOn expiresOn,E.UnitsSnapshot units,E.RemainingUnits remaining,E.PriceSnapshot price,E.SaleID saleId,E.PaymentMethod paymentMethod,E.PaymentReference paymentReference FROM dbo.TDPTEntitlement E JOIN dbo.TDPTPackage P ON P.CompanyID=E.CompanyID AND P.PackageID=E.PackageID WHERE E.CompanyID=@c AND (@member IS NULL OR E.MemberID=@member) ORDER BY E.EntitlementID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@c",Company),("@member",memberId),("@offset",(page-1)*pageSize),("@size",pageSize));
        return Ok(new{items,total,page,pageSize});
    }
    [HttpPost]
    public async Task<IActionResult> Issue(PetEntitlementRequest input,CancellationToken ct)
    {
        if(input.MemberId<1||input.PackageId<1||((input.SaleId is null)==string.IsNullOrWhiteSpace(input.PaymentReference)))return Invalid("เลือกสมาชิก แพ็กเกจ และระบุใบขาย POS หรือเลขอ้างอิงรับเงินอย่างใดอย่างหนึ่ง");
        if(input.SaleId is null && input.PaymentMethod is not ("CASH" or "TRANSFER"))return Invalid("การรับเงินโดยเจ้าหน้าที่ต้องระบุเงินสดหรือโอน");
        await using var db=await Open(ct);
        if(await Guard(db,"62005","CREATE",ct) is { } no)return no;
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        try
        {
            if(await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDBKMember WHERE CompanyID=@c AND MemberID=@member AND IsActive=1",ct,("@c",Company),("@member",input.MemberId))==0)return Invalid("ไม่พบสมาชิกในบริษัทนี้");
            var package=await PetDb.Rows(db,tx,"SELECT Price,ValidDays,IncludedUnits,PosItemID FROM dbo.TDPTPackage WHERE CompanyID=@c AND PackageID=@id AND IsActive=1",ct,("@c",Company),("@id",input.PackageId));
            if(package.Count==0)return Invalid("ไม่พบแพ็กเกจที่เปิดใช้งานในบริษัทนี้");
            var price=Convert.ToDecimal(package[0]["Price"]);
            if(input.SaleId is { } sale)
            {
                if(package[0]["PosItemID"] is null)return Invalid("แพ็กเกจนี้ยังไม่ผูกสินค้าสำหรับ POS");
                var paid=await PetDb.Rows(db,tx,"SELECT I.LineNetAmount amount,I.Quantity quantity FROM dbo.TDPOSale S JOIN dbo.TDPOSaleItem I ON I.CompanyID=S.CompanyID AND I.SaleID=S.SaleID WHERE S.CompanyID=@c AND S.SaleID=@sale AND S.StatusCode=N'COMPLETED' AND I.ItemID=@item AND I.Quantity-I.ReturnedQuantity>=1",ct,("@c",Company),("@sale",sale),("@item",package[0]["PosItemID"]));
                if(paid.Count==0)return Invalid("ไม่พบใบขาย POS ที่ชำระแล้วและมีสินค้าแพ็กเกจนี้");
                price=Convert.ToDecimal(paid[0]["amount"])/Convert.ToDecimal(paid[0]["quantity"]);
            }
            var today=DateTime.UtcNow.Date;
            var id=await PetDb.Id(db,tx,"INSERT dbo.TDPTEntitlement(CompanyID,PackageID,MemberID,SaleID,StartsOn,ExpiresOn,UnitsSnapshot,RemainingUnits,PriceSnapshot,PaymentMethod,PaymentReference) VALUES(@c,@package,@member,@sale,@start,@end,@units,@units,@price,@method,@reference);SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,("@c",Company),("@package",input.PackageId),("@member",input.MemberId),("@sale",input.SaleId),("@start",today),("@end",today.AddDays(Convert.ToInt32(package[0]["ValidDays"]))),("@units",package[0]["IncludedUnits"]),("@price",price),("@method",input.SaleId is null?input.PaymentMethod:null),("@reference",input.SaleId is null?input.PaymentReference?.Trim():null));
            await PetDb.Exec(db,tx,"INSERT dbo.TDPTEntitlementLedger(CompanyID,EntitlementID,DeltaUnits,ReasonCode,CreatedBy) VALUES(@c,@id,@units,N'ISSUE',@actor);INSERT dbo.TDPTAudit(CompanyID,EntityCode,EntityID,ActionCode,ActorID) VALUES(@c,N'ENTITLEMENT',@id,N'ISSUE',@actor)",ct,("@c",Company),("@id",id),("@units",package[0]["IncludedUnits"]),("@actor",Actor));
            await tx.CommitAsync(ct);
            return Created($"/api/company/pet/entitlements/{id}",new{id});
        }
        catch(SqlException e) when(e.Number is 2601 or 2627){await tx.RollbackAsync(ct);return Conflict(new{message="รายการรับเงินซ้ำ",description="ใบขายหรือเลขอ้างอิงนี้ถูกใช้เพื่อออกสิทธิ์แล้ว"});}
        catch{await tx.RollbackAsync(ct);throw;}
    }
}
public sealed record PetEntitlementRequest(long MemberId,long PackageId,long? SaleId,string? PaymentMethod,string? PaymentReference);
