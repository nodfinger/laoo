using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Laoo.SchoolFood.Controllers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using LaooApi.Controllers;
using LaooApi.Security;
using Microsoft.Extensions.Options;
using System.IdentityModel.Tokens.Jwt;

// Explicit real-database test entry point. Never runs as part of a normal build.
if (!args.Contains("--apply-demo")) throw new Exception("Pass --apply-demo after authorized SF_20261004_DEMO seed.");
var root=Directory.GetCurrentDirectory();
var config=new ConfigurationBuilder().AddJsonFile(Path.Combine(root,"laoo_api","local.json")).Build();
await using var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));
await db.OpenAsync();
async Task<long> Id(string sql)
{
    await using var command=new SqlCommand(sql,db);
    return Convert.ToInt64(await command.ExecuteScalarAsync());
}
var company=await Id("SELECT CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1");
var actor=await Id($"SELECT UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID={company}");
var partner=await Id($"SELECT TOP 1 PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID={company} AND IsActive=1");
var student=await Id($"SELECT StudentID FROM dbo.TDSCStudent WHERE CompanyID={company} AND StudentCode=N'SFDEMO001'");
var poor=await Id($"SELECT StudentID FROM dbo.TDSCStudent WHERE CompanyID={company} AND StudentCode=N'SFDEMO002'");
var rice=await Id($"SELECT ItemID FROM dbo.TDIVItem WHERE CompanyID={company} AND ItemCode=N'SFDEMO-RICE'");
var water=await Id($"SELECT ItemID FROM dbo.TDIVItem WHERE CompanyID={company} AND ItemCode=N'SFDEMO-WATER'");
var central=await Id($"SELECT WarehouseID FROM dbo.TDIVWarehouse WHERE CompanyID={company} AND WarehouseCode=N'SFDEMO-CENTRAL'");
var warehouse=await Id($"SELECT WarehouseID FROM dbo.TDIVWarehouse WHERE CompanyID={company} AND WarehouseCode=N'SFDEMO-SHOP'");
if(new[]{company,actor,partner,student,poor,rice,water,central,warehouse}.Any(x=>x<=0))throw new Exception("Missing fixtures");
SchoolFoodController Controller(long co,long user,long partnerId,string type="COMPANY_USER") => new(config) {
    ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext {
        User=new ClaimsPrincipal(new ClaimsIdentity(new[]{
            new Claim("company_id",co.ToString()),new Claim("user_id",user.ToString()),
            new Claim("partner_id",partnerId.ToString()),new Claim("user_type",type),
            new Claim("project_code","LAOO")}, "IntegrationTest"))}}
};
var api=Controller(company,actor,partner);
var ct=CancellationToken.None;
var passed=0;
Guid Key(string action)=>new(SHA256.HashData(Encoding.UTF8.GetBytes("SF_20261004_DEMO:"+action))[..16]);
JsonElement Body(IActionResult result)
{
    return result switch {
        ContentResult c=>JsonDocument.Parse(c.Content!).RootElement.Clone(),
        ObjectResult o=>JsonSerializer.SerializeToElement(o.Value),
        _=>throw new Exception($"Unexpected response {result.GetType().Name}")
    };
}
async Task<JsonElement> Ok(string name,Task<IActionResult> task)
{
    var result=await task;
    var status=result switch {ContentResult c=>c.StatusCode??200,ObjectResult o=>o.StatusCode??200,_=>0};
    if(status!=200) throw new Exception($"{name}: {status} {JsonSerializer.Serialize(result)}");
    passed++;Console.WriteLine($"PASS {name}");return Body(result);
}
async Task Reject(string name,Task<IActionResult> task,int expected)
{
    var result=await task;
    var status=result switch {ForbidResult=>403,ObjectResult o=>o.StatusCode??200,_=>0};
    if(status!=expected)throw new Exception($"{name}: expected {expected}, got {status}");
    passed++;Console.WriteLine($"PASS {name}");
}
void Equal<T>(string name,T expected,T actual)
{
    if(!EqualityComparer<T>.Default.Equals(expected,actual))throw new Exception($"{name}: expected {expected}, got {actual}");
    passed++;Console.WriteLine($"PASS {name}");
}
foreach(var n in Enumerable.Range(53001,12)) await Ok($"menu {n} permission",api.Actions(n.ToString(),ct));
if(await Id($"SELECT COUNT(*) FROM dbo.TDSFSetting WHERE CompanyID={company}")==0)
    await Ok("enable demo system",api.Settings(new SettingInput(Key("settings"),true,true,5m),ct));
var shop=(await Ok("tracked shop",api.CreateShop(new ShopInput(Key("shop"),"SFDEMO-FOOD","ร้านอาหารทดสอบ [SF_20261004_DEMO]",true,warehouse,true,8m),ct))).GetProperty("id").GetInt64();
var untracked=(await Ok("untracked shop",api.CreateShop(new ShopInput(Key("untracked"),"SFDEMO-DRINK","ร้านเครื่องดื่มทดสอบ [SF_20261004_DEMO]",false,null,true,null),ct))).GetProperty("id").GetInt64();
await Ok("assign tracked products",api.ShopItems(shop,new ShopItemsInput(Key("items"),[new(rice,35,true),new(water,10,true)]),ct));
await Ok("assign untracked products",api.ShopItems(untracked,new ShopItemsInput(Key("items2"),[new(water,10,true)]),ct));
await Ok("category commission",api.Commission(shop,new CommissionInput(Key("category"),null,"SFDEMO-FOOD",12m),ct));
var categories=await Ok("category choices",api.Lookup("53004","categories",ct:ct));
Equal("demo category available",true,categories.GetProperty("rows").EnumerateArray().Any(x=>x.GetProperty("code").GetString()=="SFDEMO-FOOD"));
await Ok("item commission overrides category",api.Commission(shop,new CommissionInput(Key("item-cut"),rice,null,10m),ct));
var card=(await Ok("register card",api.Identifier(new IdentifierInput(Key("card"),student,"CARD","SFDEMO-CARD001"),ct))).GetProperty("id").GetInt64();
await Ok("register low balance card",api.Identifier(new IdentifierInput(Key("poorcard"),poor,"CARD","SFDEMO-CARD002"),ct));
var identified=await Ok("lookup sample card before sale",api.Identify(new IdentifyInput(shop,"CARD","SFDEMO-CARD001"),ct));
Equal("sample card resolves right student",student,identified.GetProperty("id").GetInt64());
await Reject("unknown card denied",api.Identify(new IdentifyInput(shop,"CARD","SFDEMO-UNKNOWN"),ct),404);
await Reject("wrong identifier kind denied",api.Identify(new IdentifyInput(shop,"QR","SFDEMO-CARD001"),ct),404);
await Reject("card cannot identify at another company",Controller(company+999999,actor,partner).Identify(new IdentifyInput(shop,"CARD","SFDEMO-CARD001"),ct),403);
try
{
    await Ok("temporarily suspend demo card",api.IdentifierStatus(card,new StatusInput(Guid.NewGuid(),false),ct));
    await Reject("suspended card denied",api.Identify(new IdentifyInput(shop,"CARD","SFDEMO-CARD001"),ct),404);
}
finally
{
    await Ok("restore demo card",api.IdentifierStatus(card,new StatusInput(Guid.NewGuid(),true),ct));
}
var topup=new WalletInput(Key("topup"),"TOPUP",500m,"SF_20261004_DEMO-CASH","CASH","ยอดจำลอง ไม่ใช่เงินจริง");
await Ok("top up sample wallet",api.WalletEntry(student,topup,ct));
await Ok("topup retry",api.WalletEntry(student,topup,ct));
Equal("one ledger for topup",1L,await Id($"SELECT COUNT(*) FROM dbo.TDSFWalletLedger L JOIN dbo.TDSFOperation O ON O.OperationID=L.OperationID WHERE O.CompanyID={company} AND O.RequestKey='{topup.RequestKey}'"));
await Reject("reject reused key with different amount",api.WalletEntry(student,topup with {Amount=501},ct),409);
var transfer=(await Ok("draft stock transfer",api.Transfer(new TransferInput(Key("transfer"),shop,central,"SF_20261004_DEMO-T01",[new(rice,20),new(water,20)]),ct))).GetProperty("id").GetInt64();
await Ok("send stock",api.TransferAction(transfer,"send",new OperationInput(Key("send")),ct));
await Ok("receive stock",api.TransferAction(transfer,"receive",new OperationInput(Key("receive")),ct));
await Ok("receive retry",api.TransferAction(transfer,"receive",new OperationInput(Key("receive")),ct));
await Reject("cannot receive twice with new key",api.TransferAction(transfer,"receive",new OperationInput(Key("receive-again")),ct),409);
var saleInput=new SaleInput(Key("sale"),shop,"CARD","SFDEMO-CARD001",[new(rice,2),new(water,1)]);
var sale=await Ok("wallet sale with stock",api.Sale(saleInput,ct));
await Ok("duplicate sale retry",api.Sale(saleInput,ct));
var balanceBeforeParallel=await Id($"SELECT Balance FROM dbo.TDSFWallet WHERE CompanyID={company} AND StudentID={student}");
var parallelRetry=await Task.WhenAll(api.Sale(saleInput,ct),api.Sale(saleInput,ct));
Equal("parallel same-key sale retry succeeds once",true,parallelRetry.All(r=>r switch {ObjectResult o=>(o.StatusCode??200)==200,ContentResult c=>(c.StatusCode??200)==200,_=>false}));
Equal("parallel retry did not debit wallet again",balanceBeforeParallel,await Id($"SELECT Balance FROM dbo.TDSFWallet WHERE CompanyID={company} AND StudentID={student}"));
Equal("sale total",80m,sale.GetProperty("total").GetDecimal());
Equal("commission snapshots",7.8m,sale.GetProperty("commission").GetDecimal());
var saleId=sale.GetProperty("id").GetInt64();
var detail=await Id($"SELECT SaleItemID FROM dbo.TDSFSaleItem WHERE CompanyID={company} AND SaleID={saleId} AND ItemID={rice}");
var refund=new RefundInput(Key("refund"),"คืนบางส่วน [SF_20261004_DEMO]",[new(detail,1)]);
Equal("partial refund amount",35m,(await Ok("partial refund",api.Refund(saleId,refund,ct))).GetProperty("total").GetDecimal());
await Ok("refund retry",api.Refund(saleId,refund,ct));
await Reject("over refund denied",api.Refund(saleId,new RefundInput(Key("over-refund"),"ทดสอบคืนเกิน",[new(detail,2)]),ct),409);
await Ok("sale without stock",api.Sale(new SaleInput(Key("no-stock"),untracked,"CARD","SFDEMO-CARD001",[new(water,1)]),ct));
await Reject("insufficient wallet",api.Sale(new SaleInput(Key("poor-sale"),shop,"CARD","SFDEMO-CARD002",[new(rice,1)]),ct),409);
await Reject("insufficient stock rolls back wallet",api.Sale(new SaleInput(Key("stock-fail"),shop,"CARD","SFDEMO-CARD001",[new(water,21)]),ct),409);
Equal("balance after successful operations only",445L,await Id($"SELECT Balance FROM dbo.TDSFWallet WHERE CompanyID={company} AND StudentID={student}"));
Equal("rice inventory restored by refund",19L,await Id($"SELECT Quantity FROM dbo.TDIVStockBalance WHERE CompanyID={company} AND WarehouseID={warehouse} AND ItemID={rice}"));
Equal("water inventory without untracked movement",19L,await Id($"SELECT Quantity FROM dbo.TDIVStockBalance WHERE CompanyID={company} AND WarehouseID={warehouse} AND ItemID={water}"));
await Reject("wrong company denied",Controller(company+999999,actor,partner).Settings(ct),403);
await Reject("wrong partner denied",Controller(company,actor,partner+999999).Settings(ct),403);
await Reject("non-company identity denied",Controller(company,actor,partner,"SCHOOL_STUDENT").Settings(ct),403);
await Reject("nonexistent user denied",Controller(company,actor+999999,partner).Settings(ct),403);
await Ok("sample wallet list",api.Wallets(search:"SFDEMO",ct:ct));
var entries=await Ok("sample wallet ledger",api.WalletEntries(student,ct:ct));
Equal("ledger contains payment history",true,entries.GetProperty("total").GetInt32()>=3);
await Reject("wallet ledger cross company denied",api.WalletEntries(999999999,ct:ct),404);
await Ok("eligible shop users",api.ShopUsers(shop,ct:ct));
await Reject("shop users wrong shop denied",api.ShopUsers(999999999,ct:ct),404);
await Ok("sales list",api.Sales(shop:shop,ct:ct));
foreach(var dimension in new[]{"shop","category","item","level","classroom","student","day","month","year"})
    await Ok($"report {dimension}",api.Report("53012",dimension,ct:ct));
var export=await api.ExportReport("53012",ct:ct);
var settlement=await Ok("settlement event date report",api.Report("53011",from:new DateTime(2026,10,1),to:new DateTime(2026,10,31),shop:shop,ct:ct));
Equal("settlement refund date basis","REFUND_EVENT_DATE",settlement.GetProperty("refundAttribution").GetString());
var settlementRow=settlement.GetProperty("rows").EnumerateArray().Single();
Equal("settlement gross",80m,settlementRow.GetProperty("gross").GetDecimal());
Equal("settlement refunds",35m,settlementRow.GetProperty("refunds").GetDecimal());
Equal("settlement payable",40.7m,settlementRow.GetProperty("payable").GetDecimal());
Equal("CSV export succeeds",true,export is FileContentResult csv && csv.FileContents.Length>3 && csv.ContentType.StartsWith("text/csv"));
await Reject("invalid report dimension rejected",api.Report("53012","injected",ct:ct),400);
await Reject("invalid report dates rejected",api.Report("53012",from:new DateTime(2026,10,4),to:new DateTime(2026,10,3),ct:ct),400);
var disposable=(await Ok("create disposable shop",api.CreateShop(new ShopInput(Key("delete-shop"),"SFDEMO-DELETE","ร้านทดสอบการลบ",false,null,true,null),ct))).GetProperty("id").GetInt64();
await Ok("delete unreferenced shop",api.DeleteShop(disposable,Key("delete-shop-action"),ct));
await Reject("cannot delete shop with sale history",api.DeleteShop(shop,Key("delete-used-shop"),ct),409);
await Ok("transfer detail",api.TransferDetail(transfer,ct));
await Reject("received transfer cannot cancel",api.CancelTransfer(transfer,Key("cancel-received"),ct),409);
await Reject("transfer quantity precision",api.Transfer(new TransferInput(Key("bad-precision"),shop,central,"SFDEMO precision",[new(rice,1.00001m)]),ct),400);
var guardianId=await Id($"SELECT GuardianID FROM dbo.TDSCGuardian WHERE CompanyID={company} AND GuardianCode=N'SFDEMO-G'");
SchoolFoodGuardianController Guardian(long co,long guardian,string type="SCHOOL_GUARDIAN")=>new(config){
    ControllerContext=new ControllerContext{HttpContext=new DefaultHttpContext{User=new ClaimsPrincipal(new ClaimsIdentity(new[]{
        new Claim("user_type",type),new Claim("company_id",co.ToString()),new Claim("guardian_id",guardian.ToString())},"IntegrationTest"))}}};
await Ok("guardian children",Guardian(company,guardianId).Children(ct));
await Ok("guardian linked child purchases",Guardian(company,guardianId).Purchases(student,ct:ct));
await Reject("guardian unlinked student denied",Guardian(company,guardianId).Purchases(poor,ct:ct),403);
await Reject("guardian wrong company denied",Guardian(company+999999,guardianId).Purchases(student,ct:ct),403);
await Reject("company identity cannot act as guardian",Guardian(company,guardianId,"COMPANY_USER").Purchases(student,ct:ct),403);
SchoolFoodStudentController Student(long co,long id,int version=1,string type="SCHOOL_STUDENT")=>new(config){
    ControllerContext=new ControllerContext{HttpContext=new DefaultHttpContext{User=new ClaimsPrincipal(new ClaimsIdentity(new[]{
        new Claim("user_type",type),new Claim("company_id",co.ToString()),new Claim("student_id",id.ToString()),
        new Claim("credential_version",version.ToString())},"IntegrationTest"))}}};
await Reject("student without credential denied",Student(company,poor).Purchases(ct:ct),403);
await Reject("company cannot use student portal",Student(company,student,type:"COMPANY_USER").Purchases(ct:ct),403);
var testHash="PORTAL-TEST-"+Guid.NewGuid().ToString("N");
await using(var insert=new SqlCommand("INSERT dbo.TDSFStudentCredential(CompanyID,StudentID,PasswordHash) VALUES(@co,@id,@hash)",db)){
    insert.Parameters.AddWithValue("@co",company);insert.Parameters.AddWithValue("@id",poor);insert.Parameters.AddWithValue("@hash",testHash);
    await insert.ExecuteNonQueryAsync(ct);
}
try{
    await Reject("student must change password",Student(company,poor).Purchases(ct:ct),403);
    await using(var enable=new SqlCommand("UPDATE dbo.TDSFStudentCredential SET MustChangePassword=0 WHERE CompanyID=@co AND StudentID=@id AND PasswordHash=@hash",db)){
        enable.Parameters.AddWithValue("@co",company);enable.Parameters.AddWithValue("@id",poor);enable.Parameters.AddWithValue("@hash",testHash);
        await enable.ExecuteNonQueryAsync(ct);
    }
    var own=await Ok("student own history",Student(company,poor).Purchases(ct:ct));
    Equal("student cannot see other student purchases",0,own.GetProperty("total").GetInt32());
    await Reject("student wrong company denied",Student(company+999999,poor).Purchases(ct:ct),403);
    await Reject("student stale credential version denied",Student(company,poor,2).Purchases(ct:ct),403);
    await Reject("student invalid date range",Student(company,poor).Purchases(from:new DateTime(2026,10,4),to:new DateTime(2026,10,3),ct:ct),400);
    await using(var disable=new SqlCommand("UPDATE dbo.TDSFStudentCredential SET IsActive=0 WHERE CompanyID=@co AND StudentID=@id AND PasswordHash=@hash",db)){
        disable.Parameters.AddWithValue("@co",company);disable.Parameters.AddWithValue("@id",poor);disable.Parameters.AddWithValue("@hash",testHash);
        await disable.ExecuteNonQueryAsync(ct);
    }
    await Reject("student disabled credential denied",Student(company,poor).Purchases(ct:ct),403);
}finally{
    await using var cleanup=new SqlCommand("DELETE dbo.TDSFStudentCredential WHERE CompanyID=@co AND StudentID=@id AND PasswordHash=@hash",db);
    cleanup.Parameters.AddWithValue("@co",company);cleanup.Parameters.AddWithValue("@id",poor);cleanup.Parameters.AddWithValue("@hash",testHash);
    await cleanup.ExecuteNonQueryAsync(ct);
}
var passwordService=new PasswordService();
var tokenService=new JwtTokenService(Options.Create(new JwtOptions{Issuer="food-integration",Audience="food-test",SecretKey=Convert.ToBase64String(RandomNumberGenerator.GetBytes(64)),AccessTokenMinutes=5}));
SchoolStudentAuthController Auth(ClaimsPrincipal? principal=null)=>new(config,passwordService,tokenService){ControllerContext=new ControllerContext{HttpContext=new DefaultHttpContext{User=principal??api.User}}};
var initialPassword="Test!"+Convert.ToHexString(RandomNumberGenerator.GetBytes(16))+"a";
var nextPassword="Changed!"+Convert.ToHexString(RandomNumberGenerator.GetBytes(16))+"b";
string schoolCode;
await using(var findSchool=new SqlCommand("SELECT TOP 1 CompanyCode FROM dbo.TDSTCompanySetUp WHERE CompanyID=@co AND IsActive=1",db)){
    findSchool.Parameters.AddWithValue("@co",company);schoolCode=(string)(await findSchool.ExecuteScalarAsync(ct))!;
}
try{
    await Ok("school creates student credential",Auth().SetCredential(poor,new StudentCredentialInput(initialPassword),ct));
    await Reject("weak credential rejected",Auth().SetCredential(poor,new StudentCredentialInput("short"),ct),400);
    await Reject("credential cross company rejected",Auth().SetCredential(poor+999999,new StudentCredentialInput(initialPassword),ct),404);
    await Reject("wrong student password",Auth().Login(new StudentLoginInput(schoolCode,"SFDEMO002","wrong"),ct),401);
    var login=await Ok("student login",Auth().Login(new StudentLoginInput(schoolCode,"SFDEMO002",initialPassword),ct));
    Equal("first login requires password change",true,login.GetProperty("mustChangePassword").GetBoolean());
    var jwt=new JwtSecurityTokenHandler().ReadJwtToken(login.GetProperty("accessToken").GetString());
    var principal=new ClaimsPrincipal(new ClaimsIdentity(jwt.Claims,"IntegrationTest"));
    await Ok("student changes password",Auth(principal).ChangePassword(new StudentPasswordInput(initialPassword,nextPassword),ct));
    await Reject("old token password change rejected",Auth(principal).ChangePassword(new StudentPasswordInput(nextPassword,initialPassword),ct),401);
    await Reject("old password rejected",Auth().Login(new StudentLoginInput(schoolCode,"SFDEMO002",initialPassword),ct),401);
    var renewed=await Ok("login with changed password",Auth().Login(new StudentLoginInput(schoolCode,"SFDEMO002",nextPassword),ct));
    Equal("password requirement cleared",false,renewed.GetProperty("mustChangePassword").GetBoolean());
    for(var attempt=0;attempt<5;attempt++)await Reject($"failed login {attempt+1}",Auth().Login(new StudentLoginInput(schoolCode,"SFDEMO002","wrong"),ct),401);
    await Reject("locked credential rejects correct password",Auth().Login(new StudentLoginInput(schoolCode,"SFDEMO002",nextPassword),ct),401);
}finally{
    // Fixture only; never removes an existing student's credentials or financial history.
    await using var cleanup=new SqlCommand("DELETE dbo.TDSFStudentCredential WHERE CompanyID=@co AND StudentID=@id AND StudentID IN(SELECT StudentID FROM dbo.TDSCStudent WHERE StudentCode=N'SFDEMO002' AND CompanyID=@co)",db);
    cleanup.Parameters.AddWithValue("@co",company);cleanup.Parameters.AddWithValue("@id",poor);await cleanup.ExecuteNonQueryAsync(ct);
}
Console.WriteLine($"Passed {passed} database/controller checks. RunID SF_20261004_DEMO; sample wallet balance 445. Same-key parallel retries covered; distinct-key concurrency, HTTP middleware, UI and physical hardware are separate checks.");
