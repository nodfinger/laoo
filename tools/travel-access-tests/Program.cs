using System.Security.Claims;
using LaooApi.Controllers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

// Read-only access checks against the current account; no records are created or changed.
var root=Path.GetFullPath(args[0]);
var config=new ConfigurationBuilder().AddJsonFile(Path.Combine(root,"laoo_api/appsettings.json"))
    .AddJsonFile(Path.Combine(root,"laoo_api/local.json")).Build();
await using var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));await db.OpenAsync();
await using var q=new SqlCommand("SELECT TOP 1 U.UserID,U.CompanyID,C.PartnerID FROM dbo.TDADUser U JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID WHERE U.NormalizedUsername=N'IT#P' AND U.IsActive=1 AND C.IsActive=1",db);
await using var reader=await q.ExecuteReaderAsync();if(!await reader.ReadAsync()) throw new Exception("Test user not found.");
var user=reader.GetInt64(0);var company=reader.GetInt64(1);var partner=reader.GetInt64(2);await reader.CloseAsync();
TravelClaimController Controller(long companyId) {
    var principal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",user.ToString()),new Claim("company_id",companyId.ToString()),new Claim("partner_id",partner.ToString())],"test"));
    return new TravelClaimController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=principal } } };
}
var result=await Controller(company).List(CancellationToken.None);
if(result is not OkObjectResult) throw new Exception($"The test account cannot read the travel menu: {result.GetType().Name}");
var isolated=await Controller(long.MaxValue).List(CancellationToken.None);
if(isolated is not ForbidResult) throw new Exception("Cross-company read was not rejected.");
var invalid=await Controller(company).Detail(long.MaxValue,CancellationToken.None);
if(invalid is not NotFoundObjectResult) throw new Exception("An unknown document was not rejected.");
var sample=new TravelClaimController.ClaimInput(new DateOnly(2026,11,10),null,"A","B","Test","Test",null,10,new DateOnly(2026,11,10),new DateOnly(2026,11,10),"V","TEST",0,0,0,0,false,null,Guid.NewGuid());
if(await Controller(long.MaxValue).Create(sample,CancellationToken.None) is not ForbidResult) throw new Exception("Cross-company create was not rejected.");
await using(var tx=(SqlTransaction)await db.BeginTransactionAsync()) {
    await using(var test=new SqlCommand("""
INSERT dbo.TDSTTravelClaim(CompanyID,UserID,ClaimNo,RequestKey,ClaimDate,Origin,Destination,Purpose,WorkPlace,DistanceKm,StartDate,EndDate,VehicleTypeCode,VehicleRegistration,LodgingRate,Nights,Toll,Parking,PublicTransport,FuelAmount,LodgingAmount,TotalAmount)
OUTPUT INSERTED.Id VALUES(@company,@user,@number,@key,'2026-11-10',N'A',N'B',N'test',N'test',10,'2026-11-10','2026-11-10',N'V',N'TEST',0,0,0,0,0,5,0,5);
""",db,tx)) {
        test.Parameters.AddWithValue("@company",company);test.Parameters.AddWithValue("@user",user);test.Parameters.AddWithValue("@number","TEST-"+Guid.NewGuid().ToString("N")[..16]);test.Parameters.AddWithValue("@key",Guid.NewGuid());
        var id=Convert.ToInt64(await test.ExecuteScalarAsync());
        await using var file=new SqlCommand("INSERT dbo.TDSTTravelClaimAttachment(ClaimID,CompanyID,FileName,ContentType,FileData) VALUES(@id,@company,N'test.pdf','application/pdf',0x25504446)",db,tx);
        file.Parameters.AddWithValue("@id",id);file.Parameters.AddWithValue("@company",company);await file.ExecuteNonQueryAsync();
    }
    await tx.RollbackAsync();
}
Console.WriteLine("Travel access, company isolation and schema transaction rollback checks passed.");
