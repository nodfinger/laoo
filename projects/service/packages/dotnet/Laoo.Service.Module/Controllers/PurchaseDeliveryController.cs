using System.Data;
using System.Security.Claims;
using LaooServiceModule.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;
public sealed record PurchaseDeliveryLine(long? ItemId,string Description,decimal Quantity,decimal UnitPrice);
public sealed record PurchaseDeliverySave(long? PurchaseDeliveryId,long VendorId,long? BranchId,string? SupplierDocumentCode,
    DateTime DeliveryDate,string PaymentType,int CreditDays,string? Remark,List<PurchaseDeliveryLine> Lines);
[ApiController,Authorize,LaooServiceModule.Security.RequireCompanyFeature("SALES")]
[LaooServiceModule.Security.RequireCompanyProject("LAOO")]
[TypeFilter(typeof(ItemProjectExceptionFilter))]
[Route("api/company/purchase-deliveries")]
public sealed partial class PurchaseDeliveryController(IConfiguration configuration):ControllerBase
{
    private readonly IConfiguration _configuration=configuration;
    private long CompanyId=>long.TryParse(User.FindFirstValue("company_id"),out var n)?n:0;
    private long UserId=>long.TryParse(User.FindFirstValue("user_id"),out var n)?n:0;
    private static Task<bool> Can(SqlConnection c,ClaimsPrincipal u,string a,CancellationToken ct)=>
        Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedAsync(c,u,"09009",a,ct);
    private async Task<SqlConnection> Open(CancellationToken ct)
    {var c=new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(ct);return c;}
    private static void P(SqlCommand c,string n,SqlDbType t,object? v,int size=0)
    {var p=size>0?c.Parameters.Add(n,t,size):c.Parameters.Add(n,t);if(t==SqlDbType.Decimal){p.Precision=18;p.Scale=4;}p.Value=v??DBNull.Value;}
    private async Task Audit(SqlConnection c,SqlTransaction tx,long id,string action,CancellationToken ct)
    {await using var q=new SqlCommand("INSERT dbo.TDADFinanceAudit(CompanyID,EntityType,EntityID,ActionCode,ActorUserID,OccurredAt) VALUES(@c,N'PURCHASE_DELIVERY',@id,@a,@u,SYSUTCDATETIME())",c,tx);P(q,"@c",SqlDbType.BigInt,CompanyId);P(q,"@id",SqlDbType.BigInt,id);P(q,"@a",SqlDbType.NVarChar,action,30);P(q,"@u",SqlDbType.BigInt,UserId);await q.ExecuteNonQueryAsync(ct);}
    private static async Task<IActionResult> Reject(SqlTransaction tx,CancellationToken ct,string message)
    {await tx.RollbackAsync(ct);return new BadRequestObjectResult(new{message,description="Review the document information and current status, then try again"});}
    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken ct)
    {await using var c=await Open(ct);return Ok(new{view=await Can(c,User,"VIEW",ct),create=await Can(c,User,"CREATE",ct),edit=await Can(c,User,"EDIT",ct),delete=await Can(c,User,"DELETE",ct),confirm=await Can(c,User,"CONFIRM",ct)});}
}
