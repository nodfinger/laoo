using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Laoo.SchoolFood.Controllers;

[ApiController,Authorize,Route("api/school/guardian/food")]
public sealed class SchoolFoodGuardianController(IConfiguration configuration):ControllerBase
{
    private bool Scope(out long company,out long guardian)
    {
        company=guardian=0;
        return User.FindFirstValue("user_type")=="SCHOOL_GUARDIAN"
            && long.TryParse(User.FindFirstValue("company_id"),out company)&&company>0
            && long.TryParse(User.FindFirstValue("guardian_id"),out guardian)&&guardian>0;
    }
    private IActionResult Denied()=>StatusCode(403,new{message="ไม่สามารถเปิดข้อมูลอาหารของนักเรียนนี้",description="ตรวจสอบบัญชีผู้ปกครอง การผูกบุตรหลาน และสิทธิ์ระบบกับโรงเรียน"});
    private const string AllowedChildren="""
 FROM dbo.TDSCStudentGuardian SG
 JOIN dbo.TDSCGuardian G ON G.GuardianID=SG.GuardianID AND G.CompanyID=@co AND G.IsActive=1
 JOIN dbo.TDSCStudent S ON S.StudentID=SG.StudentID AND S.CompanyID=@co AND S.IsActive=1
 LEFT JOIN dbo.TDSFGuardianAccess A ON A.CompanyID=@co AND A.GuardianID=G.GuardianID AND A.StudentID=S.StudentID
 WHERE G.GuardianID=@guardian AND COALESCE(A.CanViewPurchases,1)=1
""";
    [HttpGet("children")]
    public async Task<IActionResult> Children(CancellationToken ct)
    {
        if(!Scope(out var company,out var guardian))return Denied();
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        if(!await SchoolFoodAccess.HasSubscriptions(db,company,false,ct))return Denied();
        var children=await FoodDb.Rows(db,null,"SELECT S.StudentID id,S.StudentCode code,CONCAT(S.FirstName,N' ',S.LastName) name"+AllowedChildren+" ORDER BY S.StudentCode",ct,("@co",company),("@guardian",guardian));
        return Ok(new{children});
    }
    [HttpGet("students/{student:long}")]
    public async Task<IActionResult> Purchases(long student,[FromQuery]DateTime? from=null,[FromQuery]DateTime? to=null,
        [FromQuery]int page=1,[FromQuery]int pageSize=20,CancellationToken ct=default)
    {
        if(!Scope(out var company,out var guardian))return Denied();
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        if(!await SchoolFoodAccess.HasSubscriptions(db,company,false,ct)
            ||await FoodDb.Id(db,null,"SELECT COUNT(*)"+AllowedChildren+" AND S.StudentID=@student",ct,("@co",company),("@guardian",guardian),("@student",student))!=1)return Denied();
        return await PurchaseHistory(db,company,student,from,to,page,pageSize,ct);
    }
    internal static async Task<IActionResult> PurchaseHistory(SqlConnection db,long company,long student,DateTime? from,DateTime? to,int page,int pageSize,CancellationToken ct)
    {
        var begin=(from??DateTime.UtcNow.AddHours(7).Date.AddDays(-30)).Date;
        var end=(to??DateTime.UtcNow.AddHours(7).Date).Date;
        if(end<begin||end>begin.AddYears(5))return new BadRequestObjectResult(new{message="ช่วงวันที่ไม่ถูกต้อง",description="เลือกวันเริ่มก่อนวันสิ้นสุดและช่วงไม่เกิน 5 ปี"});
        page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        var values=new (string,object?)[]{("@co",company),("@student",student),("@from",begin.AddHours(-7)),("@to",end.AddDays(1).AddHours(-7))};
        const string source="""
 FROM dbo.TDSFSale S JOIN dbo.TDSFSaleItem I ON I.CompanyID=S.CompanyID AND I.SaleID=S.SaleID
 JOIN dbo.TDSFShop H ON H.CompanyID=S.CompanyID AND H.ShopID=S.ShopID
 WHERE S.CompanyID=@co AND S.StudentID=@student AND S.CreatedAt>=@from AND S.CreatedAt<@to
""";
        var rows=await FoodDb.Rows(db,null,"SELECT S.ReceiptNo receipt,S.CreatedAt date,H.ShopName shop,I.ItemNameSnapshot item,I.Quantity quantity,I.ReturnedQuantity returned,I.NetAmount amount,I.NetAmount-ROUND(I.NetAmount*I.ReturnedQuantity/I.Quantity,2) net"+source+" ORDER BY S.SaleID DESC,I.SaleItemID OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,[..values,("@offset",(page-1)*pageSize),("@size",pageSize)]);
        var total=await FoodDb.Id(db,null,"SELECT COUNT(*)"+source,ct,values);
        var wallet=await FoodDb.Rows(db,null,"SELECT Balance balance FROM dbo.TDSFWallet WHERE CompanyID=@co AND StudentID=@student",ct,("@co",company),("@student",student));
        var summary=await FoodDb.Rows(db,null,"SELECT I.ItemTypeSnapshot category,SUM(I.Quantity-I.ReturnedQuantity) quantity,SUM(I.NetAmount-ROUND(I.NetAmount*I.ReturnedQuantity/I.Quantity,2)) net"+source+" GROUP BY I.ItemTypeSnapshot",ct,values);
        return new OkObjectResult(new{balance=wallet.Count==0?0:wallet[0].Decimal("balance"),rows,total,page,pageSize,summary,from=begin,to=end,refundAttribution="ORIGINAL_SALE_DATE"});
    }
}
