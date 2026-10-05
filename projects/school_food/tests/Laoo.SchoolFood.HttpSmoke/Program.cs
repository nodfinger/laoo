using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text.Json;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;

// Uses an isolated demo account and an already running Center host. Never prints tokens or passwords.
if(args.Length!=1 || !Uri.TryCreate(args[0],UriKind.Absolute,out var url) || url.Host!="localhost")
    throw new Exception("Specify the local Center API base URL, for example http://localhost:5081");
var config=new ConfigurationBuilder().SetBasePath(Path.Combine(Directory.GetCurrentDirectory(),"laoo_api"))
    .AddJsonFile("appsettings.json").AddJsonFile("local.json",optional:true).Build();
await using var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));
await db.OpenAsync();
async Task<long> Number(string sql)
{
    await using var cmd=new SqlCommand(sql,db);
    return Convert.ToInt64(await cmd.ExecuteScalarAsync());
}
var company=await Number("SELECT CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1");
var actor=await Number($"SELECT UserID FROM dbo.TDADUser WHERE CompanyID={company} AND Username=N'c111'");
var partner=await Number($"SELECT TOP 1 PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID={company} AND IsActive=1");
var project=await Number("SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1");
var child=await Number($"SELECT StudentID FROM dbo.TDSCStudent WHERE CompanyID={company} AND StudentCode=N'SFDEMO001' AND IsActive=1");
var other=await Number($"SELECT StudentID FROM dbo.TDSCStudent WHERE CompanyID={company} AND StudentCode=N'SFDEMO002' AND IsActive=1");
var shop=await Number($"SELECT ShopID FROM dbo.TDSFShop WHERE CompanyID={company} AND ShopCode=N'SFDEMO-FOOD' AND IsActive=1");
var guardian=await Number($"SELECT GuardianID FROM dbo.TDSCGuardian WHERE CompanyID={company} AND GuardianCode=N'SFDEMO-G' AND IsActive=1");
var existing=await Number($"SELECT COUNT(*) FROM dbo.TDSFStudentCredential WHERE CompanyID={company} AND StudentID={other}");
if(new[]{company,actor,partner,project,child,other,guardian,shop}.Any(x=>x<=0)||existing!=0)
    throw new Exception("Isolated School Food demo identity is unavailable");
await using var schoolCmd=new SqlCommand("SELECT TOP 1 CompanyCode FROM dbo.TDSTCompanySetUp WHERE CompanyID=@co AND IsActive=1",db);
schoolCmd.Parameters.AddWithValue("@co",company);
var schoolCode=(string)(await schoolCmd.ExecuteScalarAsync())!;
var settings=config.GetSection("Jwt").Get<JwtOptions>()??throw new Exception("JWT configuration missing");
var tokens=new JwtTokenService(Options.Create(settings));
string Sign(AuthenticatedUser user)=>tokens.CreateToken(user).AccessToken;
var companyJwt=Sign(new AuthenticatedUser($"company:{actor}","COMPANY_USER","COMPANY",null,null,partner,actor,company,null,project,"LAOO","c111","c111",false));
var guardianJwt=Sign(new AuthenticatedUser($"school-guardian:{guardian}","SCHOOL_GUARDIAN","SCHOOL_GUARDIAN",null,null,null,null,company,null,project,"LAOO_SCHOOL","SFDEMO-G","SFDEMO-G",false,GuardianId:guardian));
using var http=new HttpClient{BaseAddress=url,Timeout=TimeSpan.FromSeconds(25)};
var passed=0;
async Task<(HttpStatusCode,JsonElement?)> Call(HttpMethod method,string path,string? jwt=null,object? payload=null)
{
    using var request=new HttpRequestMessage(method,path);
    if(jwt!=null)request.Headers.Authorization=new AuthenticationHeaderValue("Bearer",jwt);
    if(payload!=null)request.Content=JsonContent.Create(payload);
    using var response=await http.SendAsync(request);
    var body=await response.Content.ReadAsStringAsync();
    if(!body.TrimStart().StartsWith('{'))return(response.StatusCode,null);
    using var parsed=JsonDocument.Parse(body);
    return(response.StatusCode,parsed.RootElement.Clone());
}
async Task<JsonElement> Expect(string name,HttpMethod method,string path,HttpStatusCode status,string? jwt=null,object? payload=null)
{
    var (actual,body)=await Call(method,path,jwt,payload);
    if(actual!=status)throw new Exception($"{name}: expected {(int)status}, got {(int)actual}");
    passed++;Console.WriteLine("PASS "+name);
    return body??default;
}
await Expect("anonymous company denied",HttpMethod.Get,"api/company/school-food/settings",HttpStatusCode.Unauthorized);
await Expect("anonymous student denied",HttpMethod.Get,"api/school/student/food",HttpStatusCode.Unauthorized);
await Expect("anonymous card scan denied",HttpMethod.Post,"api/company/school-food/identify",HttpStatusCode.Unauthorized,payload:new{shopID=shop,kind="CARD",value="SFDEMO-CARD001"});
await Expect("guardian card scan denied",HttpMethod.Post,"api/company/school-food/identify",HttpStatusCode.Forbidden,guardianJwt,new{shopID=shop,kind="CARD",value="SFDEMO-CARD001"});
await Expect("company actions with JWT",HttpMethod.Get,"api/company/school-food/actions/53007",HttpStatusCode.OK,companyJwt);
var scan=await Expect("card number resolves student before sale",HttpMethod.Post,"api/company/school-food/identify",HttpStatusCode.OK,companyJwt,new{shopID=shop,kind="CARD",value="SFDEMO-CARD001"});
if(scan.GetProperty("id").GetInt64()!=child)throw new Exception("Card resolved to wrong student");
await Expect("unknown card hidden",HttpMethod.Post,"api/company/school-food/identify",HttpStatusCode.NotFound,companyJwt,new{shopID=shop,kind="CARD",value="SFDEMO-UNKNOWN"});
await Expect("card number not a QR code",HttpMethod.Post,"api/company/school-food/identify",HttpStatusCode.NotFound,companyJwt,new{shopID=shop,kind="QR",value="SFDEMO-CARD001"});
await Expect("real wallet records",HttpMethod.Get,"api/company/school-food/wallets?search=SFDEMO",HttpStatusCode.OK,companyJwt);
var ledger=await Expect("student wallet ledger",HttpMethod.Get,$"api/company/school-food/wallets/{child}/entries",HttpStatusCode.OK,companyJwt);
if(ledger.GetProperty("total").GetInt32()<3)throw new Exception("Demo wallet history is incomplete");
await Expect("wallet cross-company student hidden",HttpMethod.Get,"api/company/school-food/wallets/999999999/entries",HttpStatusCode.NotFound,companyJwt);
await Expect("shop users list",HttpMethod.Get,$"api/company/school-food/shops/{shop}/users",HttpStatusCode.OK,companyJwt);
await Expect("wrong shop users hidden",HttpMethod.Get,"api/company/school-food/shops/999999999/users",HttpStatusCode.NotFound,companyJwt);
await Expect("commission category choices",HttpMethod.Get,"api/company/school-food/lookups/53004/categories",HttpStatusCode.OK,companyJwt);
await Expect("CSV export authorized",HttpMethod.Get,"api/company/school-food/reports/53012/export?dimension=shop",HttpStatusCode.OK,companyJwt);
var children=await Expect("guardian linked children",HttpMethod.Get,"api/school/guardian/food/children",HttpStatusCode.OK,guardianJwt);
if(!children.GetProperty("children").EnumerateArray().Any(x=>x.GetProperty("id").GetInt64()==child))throw new Exception("Guardian fixture missing linked child");
await Expect("guardian linked purchases",HttpMethod.Get,$"api/school/guardian/food/students/{child}",HttpStatusCode.OK,guardianJwt);
await Expect("guardian unlinked child denied",HttpMethod.Get,$"api/school/guardian/food/students/{other}",HttpStatusCode.Forbidden,guardianJwt);
var first="HttpTest!"+Convert.ToHexString(RandomNumberGenerator.GetBytes(16))+"a";
var changed="HttpChanged!"+Convert.ToHexString(RandomNumberGenerator.GetBytes(16))+"b";
var created=false;
try
{
    await Expect("create demo student credential",HttpMethod.Put,$"api/company/school-food/students/{other}/credential",HttpStatusCode.OK,companyJwt,new{newPassword=first,isActive=true});
    created=true;
    await Expect("wrong student password denied",HttpMethod.Post,"api/school/student/login",HttpStatusCode.Unauthorized,payload:new{companyCode=schoolCode,studentCode="SFDEMO002",password="wrong"});
    var login=await Expect("student login",HttpMethod.Post,"api/school/student/login",HttpStatusCode.OK,payload:new{companyCode=schoolCode,studentCode="SFDEMO002",password=first});
    var studentJwt=login.GetProperty("accessToken").GetString()!;
    await Expect("password change required",HttpMethod.Get,"api/school/student/food",HttpStatusCode.Forbidden,studentJwt);
    await Expect("student changes password",HttpMethod.Post,"api/school/student/change-password",HttpStatusCode.OK,studentJwt,new{currentPassword=first,newPassword=changed});
    await Expect("old student JWT revoked",HttpMethod.Get,"api/school/student/food",HttpStatusCode.Forbidden,studentJwt);
    var next=await Expect("student login with changed password",HttpMethod.Post,"api/school/student/login",HttpStatusCode.OK,payload:new{companyCode=schoolCode,studentCode="SFDEMO002",password=changed});
    var own=await Expect("student own history",HttpMethod.Get,"api/school/student/food",HttpStatusCode.OK,next.GetProperty("accessToken").GetString());
    if(own.GetProperty("total").GetInt32()!=0)throw new Exception("Student saw another student's purchases");
}
finally
{
    if(created)
    {
        await using var cleanup=new SqlCommand("DELETE dbo.TDSFStudentCredential WHERE CompanyID=@co AND StudentID=@id AND StudentID IN(SELECT StudentID FROM dbo.TDSCStudent WHERE CompanyID=@co AND StudentCode=N'SFDEMO002')",db);
        cleanup.Parameters.AddWithValue("@co",company);cleanup.Parameters.AddWithValue("@id",other);
        await cleanup.ExecuteNonQueryAsync();
    }
}
Console.WriteLine($"PASS {passed} real HTTP/JWT cases; School Food demo wallet unchanged");
