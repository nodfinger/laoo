using System.Security.Claims;
using System.Text.Json;
using System.Transactions;
using LaooApi.Controllers;
using LaooApi.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;

var root=Path.GetFullPath(args.FirstOrDefault()??".");
var config=new ConfigurationBuilder().AddJsonFile(Path.Combine(root,"laoo_api/local.json")).Build();
var connectionString=config.GetConnectionString("LaooDatabase")!;
long user,company,partner;
await using(var c=new SqlConnection(connectionString)) {
    await c.OpenAsync();
    await using var cmd=new SqlCommand("""
SELECT TOP(1) U.UserID,U.CompanyID,C.PartnerID FROM dbo.TDADUser U
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.IsActive=1
JOIN dbo.TDADPartner B ON B.PartnerID=C.PartnerID AND B.IsActive=1
JOIN dbo.TDADCompanyProject CP ON CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1
JOIN dbo.TDADProject P ON P.ProjectID=CP.ProjectID AND P.ProjectCode='LAOO' AND P.IsActive=1
WHERE U.IsActive=1 AND U.IsCompanyAdmin=1
AND (CP.StartDate IS NULL OR CP.StartDate<=GETUTCDATE()) AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,GETUTCDATE()))
ORDER BY U.UserID
""",c);
    await using var r=await cmd.ExecuteReaderAsync();
    if(!await r.ReadAsync())throw new Exception("No active Company Admin fixture available.");
    user=r.GetInt64(0);company=r.GetInt64(1);partner=r.GetInt64(2);
}
VendorController Controller(long companyId,long partnerId)=>new(config,NullLogger<VendorController>.Instance) {
    ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext {
        User=new ClaimsPrincipal(new ClaimsIdentity(new[]{
            new Claim("user_type","COMPANY_USER"),new Claim("user_id",user.ToString()),
            new Claim("company_id",companyId.ToString()),new Claim("partner_id",partnerId.ToString())
        },"Test"))
    }}
};
var controller=Controller(company,partner);
var checks=0;
void Check(string name,bool condition) {if(!condition)throw new Exception("FAIL: "+name);Console.WriteLine("PASS: "+name);checks++;}
int Status(IActionResult r)=>r is ObjectResult o?o.StatusCode??200:r is StatusCodeResult s?s.StatusCode:0;
JsonElement Data(IActionResult r)=>JsonSerializer.SerializeToElement(((ObjectResult)r).Value);
VendorResponse Vendor(IActionResult r)=>(VendorResponse)((OkObjectResult)r).Value!;
async Task Execute(string sql) {
    await using var c=new SqlConnection(connectionString);await c.OpenAsync();
    await using var cmd=new SqlCommand(sql,c);
    cmd.Parameters.AddWithValue("@user",user);cmd.Parameters.AddWithValue("@company",company);
    await cmd.ExecuteNonQueryAsync();
}
// Every test write, including actual controller saves/deletes, is rolled back.
using(var scope=new TransactionScope(TransactionScopeOption.RequiresNew,
    new TransactionOptions { IsolationLevel=IsolationLevel.ReadCommitted,Timeout=TimeSpan.FromMinutes(2) },
    TransactionScopeAsyncFlowOption.Enabled)) {
    var actions=Data(await controller.Actions(default));
    Check("Admin actions",actions.GetProperty("create").GetBoolean()&&actions.GetProperty("edit").GetBoolean()&&actions.GetProperty("delete").GetBoolean());
    var code="TEST-"+Guid.NewGuid().ToString("N");
    var body=new VendorRequest(code,"Vendor regression fixture","ORGANIZATION",null,"Address",null,"vendor@example.test",
        "Contact",null,null,30,null,true,null);
    var created=Vendor(await controller.Create(body,default));
    Check("Create and return version",created.VendorID>0&&Convert.FromBase64String(created.RowVersion).Length==8);
    Check("Read saved values",Vendor(await controller.Get(created.VendorID,default)).CreditDays==30);
    Check("Duplicate code rejected",Status(await controller.Create(body,default))==409);
    Check("Blank code rejected",Status(await controller.Create(body with {VendorCode=" "},default))==400);
    Check("Cross-company denied",Status(await Controller(-1,partner).Get(created.VendorID,default))==403);
    Check("Cross-partner denied",Status(await Controller(company,-1).Get(created.VendorID,default))==403);
    Check("Missing record",Status(await controller.Get(long.MaxValue,default))==404);
    Check("Filter and pagination",Data(await controller.List(code,true,"ORGANIZATION",1,1)).GetProperty("total").GetInt32()==1);
    Check("Inactive filter",Data(await controller.List(code,false,null,1,20)).GetProperty("total").GetInt32()==0);
    var updated=Vendor(await controller.Update(created.VendorID,body with {VendorName="Updated",RowVersion=created.RowVersion},default));
    Check("Update version advances",updated.VendorName=="Updated"&&updated.RowVersion!=created.RowVersion);
    Check("Stale update rejected",Status(await controller.Update(created.VendorID,body with {RowVersion=created.RowVersion},default))==409);
    Check("Stale delete rejected",Status(await controller.Delete(created.VendorID,created.RowVersion,default))==409);
    Check("Delete",Status(await controller.Delete(created.VendorID,updated.RowVersion,default))==200);
    Check("Deleted record absent",Status(await controller.Get(created.VendorID,default))==404);
    Check("Invalid page size",Status(await controller.List(null,null,null,1,201))==400);
    await Execute("UPDATE dbo.TDADUser SET IsCompanyAdmin=0 WHERE UserID=@user AND CompanyID=@company; UPDATE dbo.TDADUserProject SET IsActive=0 WHERE UserID=@user AND CompanyID=@company");
    Check("No membership cannot create",Status(await controller.Create(body,default))==403);
    Check("No membership cannot read",Status(await controller.List(null,null,null))==403);
    await Execute("UPDATE dbo.TDADUser SET IsCompanyAdmin=1,IsActive=0 WHERE UserID=@user AND CompanyID=@company");
    Check("Inactive admin denied",Status(await controller.Get(1,default))==403);
    // Intentionally no Complete().
}
Console.WriteLine($"{checks} checks passed; transaction rolled back. No vendor or permission fixtures remain.");
