using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Globalization;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;

if (args.Length != 1 || !Uri.TryCreate(args[0], UriKind.Absolute, out var url)
    || url.Host != "localhost") throw new Exception("Use local Center API URL");
var config = new ConfigurationBuilder()
    .SetBasePath(Path.Combine(Directory.GetCurrentDirectory(), "laoo_api"))
    .AddJsonFile("appsettings.json").AddJsonFile("local.json", optional: true).Build();
await using var db = new SqlConnection(config.GetConnectionString("LaooDatabase"));
await db.OpenAsync();
async Task<long> Number(string sql)
{
    await using var cmd = new SqlCommand(sql, db);
    return Convert.ToInt64(await cmd.ExecuteScalarAsync());
}
var company = await Number("SELECT CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1");
var actor = await Number($"SELECT UserID FROM dbo.TDADUser WHERE CompanyID={company} AND Username=N'c111'");
var partner = await Number($"SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID={company}");
var project = await Number("SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO'");
var sport = await Number("SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SPORT'");
if (company <= 0 || actor <= 0 || partner <= 0 || sport <= 0)
    throw new Exception("DEMO Sport identity missing");
var settings = config.GetSection("Jwt").Get<JwtOptions>() ?? throw new Exception("JWT settings missing");
var signer = new JwtTokenService(Options.Create(settings));
string Token(long co, long user, string code) => signer.CreateToken(new AuthenticatedUser(
    $"company:{user}", "COMPANY_USER", "COMPANY", null, null, partner, user, co, null,
    project, code, "sport-smoke", "sport-smoke", false)).AccessToken;
var jwt = Token(company, actor, "LAOO");
using var http = new HttpClient { BaseAddress = url, Timeout = TimeSpan.FromSeconds(25) };
var passed = 0;
async Task Check(string name, HttpMethod method, string path, HttpStatusCode expected, string? token = null)
{
    using var request = new HttpRequestMessage(method, path);
    if (token != null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
    using var response = await http.SendAsync(request);
    if (response.StatusCode != expected)
        throw new Exception($"{name}: expected {(int)expected}, got {(int)response.StatusCode}: "
            + (await response.Content.ReadAsStringAsync())[..Math.Min(300,
                (await response.Content.ReadAsStringAsync()).Length)]);
    passed++;
    Console.WriteLine("PASS " + name);
}
await Check("anonymous denied", HttpMethod.Get, "api/company/sport/settings", HttpStatusCode.Unauthorized);
await Check("settings", HttpMethod.Get, "api/company/sport/settings", HttpStatusCode.OK, jwt);
await Check("actions", HttpMethod.Get, "api/company/sport/actions/54008", HttpStatusCode.OK, jwt);
await Check("sport types", HttpMethod.Get, "api/company/sport/sport-types", HttpStatusCode.OK, jwt);
await Check("facilities", HttpMethod.Get, "api/company/sport/facilities", HttpStatusCode.OK, jwt);
await Check("levels", HttpMethod.Get, "api/company/sport/levels", HttpStatusCode.OK, jwt);
await Check("packages", HttpMethod.Get, "api/company/sport/packages", HttpStatusCode.OK, jwt);
await Check("members", HttpMethod.Get, "api/company/sport/members?search=SP261004", HttpStatusCode.OK, jwt);
await Check("POS price rules", HttpMethod.Get, "api/company/sport/pos-pricing", HttpStatusCode.OK, jwt);
var today = DateOnly.FromDateTime(DateTime.UtcNow);
await Check("dashboard", HttpMethod.Get,
    $"api/company/sport/dashboard?from={today.ToString("yyyy-MM-dd",CultureInfo.InvariantCulture)}&to={today.AddDays(1).ToString("yyyy-MM-dd",CultureInfo.InvariantCulture)}",
    HttpStatusCode.OK, jwt);
await Check("wrong company denied", HttpMethod.Get, "api/company/sport/settings",
    HttpStatusCode.Forbidden, Token(99999999, actor, "LAOO"));
await Check("no user permission denied", HttpMethod.Get, "api/company/sport/settings",
    HttpStatusCode.Forbidden, Token(company, 99999999, "LAOO"));
async Task<(HttpStatusCode, JsonElement)> Post(string path, object body)
{
    using var request = new HttpRequestMessage(HttpMethod.Post, path);
    request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", jwt);
    request.Content = JsonContent.Create(body);
    using var response = await http.SendAsync(request);
    using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
    return (response.StatusCode, document.RootElement.Clone());
}
void Assert(string name, HttpStatusCode actual, HttpStatusCode expected)
{
    if (actual != expected) throw new Exception($"{name}: expected {(int)expected}, got {(int)actual}");
    passed++; Console.WriteLine("PASS " + name);
}
var memberA = await Number($"SELECT MemberID FROM dbo.TDSPMember WHERE CompanyID={company} AND MemberCode=N'SP261004_A'");
var memberB = await Number($"SELECT MemberID FROM dbo.TDSPMember WHERE CompanyID={company} AND MemberCode=N'SP261004_B'");
await Check("POS member lookup", HttpMethod.Get,
    "api/company/pos/sport-members/SP261004_A", HttpStatusCode.OK, jwt);
await Check("POS unknown member", HttpMethod.Get,
    "api/company/pos/sport-members/NOT-A-MEMBER", HttpStatusCode.NotFound, jwt);
await Check("POS invalid member preview", HttpMethod.Get,
    "api/company/pos/products/46004001-0000-4000-8000-000000000001?sportMemberId=99999999",
    HttpStatusCode.Conflict, jwt);
using (var previewRequest = new HttpRequestMessage(HttpMethod.Get,
    $"api/company/pos/products/46004001-0000-4000-8000-000000000001?sportMemberId={memberA}"))
{
    previewRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", jwt);
    using var previewResponse = await http.SendAsync(previewRequest);
    Assert("POS member price preview", previewResponse.StatusCode, HttpStatusCode.OK);
    using var preview = JsonDocument.Parse(await previewResponse.Content.ReadAsStringAsync());
    var priced = preview.RootElement.EnumerateArray()
        .FirstOrDefault(item => item.GetProperty("code").GetString() == "NM001");
    if (priced.ValueKind == JsonValueKind.Undefined || priced.GetProperty("price").GetDecimal() != 6.5m)
        throw new Exception("POS member preview price must be 6.50");
    passed++; Console.WriteLine("PASS POS member preview price 6.50");
}
var multi = await Number($"SELECT PackageID FROM dbo.TDSPPackage WHERE CompanyID={company} AND PackageCode=N'SP261004_MULTI'");
var daily = await Number($"SELECT PackageID FROM dbo.TDSPPackage WHERE CompanyID={company} AND PackageCode=N'SP261004_DAY'");
var court = await Number($"SELECT FacilityID FROM dbo.TDSPFacility WHERE CompanyID={company} AND FacilityCode=N'SP261004_B1'");
var (duplicateSportStatus, _) = await Post("api/company/sport/sport-types", new {
    code = "SP261004_BAS", name = "ทดสอบรหัสซ้ำ"
});
Assert("duplicate sport code rejected", duplicateSportStatus, HttpStatusCode.Conflict);
var (protectedPackageStatus, _) = await Post("api/company/sport/memberships", new {
    memberID = 99999999, packageID = multi, startsOn = DateOnly.FromDateTime(DateTime.UtcNow),
    renew = false, paymentCode = "CASH", idempotencyKey = Guid.NewGuid()
});
Assert("missing member rejected", protectedPackageStatus, HttpStatusCode.Conflict);
var day = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7)).Date.AddDays(1);
var start = new DateTimeOffset(day.AddHours(9), TimeSpan.FromHours(7));
var end = start.AddHours(1);
var enrollKey = Guid.Parse("a0c641a6-496e-49d0-b940-261004000001");
var (enrollStatus, enrollment) = await Post("api/company/sport/memberships", new {
    memberID = memberA, packageID = multi, startsOn = DateOnly.FromDateTime(DateTime.UtcNow),
    renew = false, paymentCode = "CASH", idempotencyKey = enrollKey
});
Assert("enroll and receive payment", enrollStatus, HttpStatusCode.OK);
var membership = enrollment.GetProperty("id").GetInt64();
var (enrollRepeatStatus, enrollRepeat) = await Post("api/company/sport/memberships", new {
    memberID = memberA, packageID = multi, startsOn = DateOnly.FromDateTime(DateTime.UtcNow),
    renew = false, paymentCode = "CASH", idempotencyKey = enrollKey
});
Assert("enrollment idempotent", enrollRepeatStatus, HttpStatusCode.OK);
if (membership != enrollRepeat.GetProperty("id").GetInt64()) throw new Exception("Duplicate membership");
var bookingKey = Guid.NewGuid();
var (bookingStatus, booking) = await Post("api/company/sport/bookings", new {
    facilityID = court, memberID = memberA, membershipID = membership,
    startsAt = start, endsAt = end, idempotencyKey = bookingKey
});
Assert("book with membership", bookingStatus, HttpStatusCode.OK);
var booked = booking.GetProperty("id").GetInt64();
var (repeatStatus, repeat) = await Post("api/company/sport/bookings", new {
    facilityID = court, memberID = memberA, membershipID = membership,
    startsAt = start, endsAt = end, idempotencyKey = bookingKey
});
Assert("booking idempotent", repeatStatus, HttpStatusCode.OK);
if (booked != repeat.GetProperty("id").GetInt64()) throw new Exception("Duplicate booking");
var (overlapStatus, _) = await Post("api/company/sport/bookings", new {
    facilityID = court, memberID = memberB, dropInPackageID = daily,
    startsAt = start.AddMinutes(30), endsAt = end.AddMinutes(30), idempotencyKey = Guid.NewGuid()
});
Assert("overlap rejected", overlapStatus, HttpStatusCode.Conflict);
var (cancelStatus, _) = await Post($"api/company/sport/bookings/{booked}/cancel", new { reason = "HTTP smoke SP261004" });
Assert("cancel releases reservation", cancelStatus, HttpStatusCode.OK);
var oldSale = await Number($"""
SELECT COUNT(*) FROM dbo.TDPOSale S
JOIN dbo.TDSPMember M ON M.CompanyID=S.CompanyID AND M.MemberID=S.SportMemberID
WHERE S.CompanyID={company} AND M.MemberCode=N'SP261004_A'
""");
if (oldSale == 0)
{
    var openShift = await Number($"""
SELECT COUNT(*) FROM dbo.TDPOShift WHERE CompanyID={company}
AND TerminalID=(SELECT TerminalID FROM dbo.TDPOTerminal
WHERE CompanyID={company} AND TerminalCode=N'POS-HO-01') AND StatusCode=N'OPEN'
""");
    if (openShift != 0) throw new Exception("POS terminal already has an open shift; no test sale created");
    var activation = Guid.Parse("46004001-0000-4000-8000-000000000001");
    var (shiftStatus, shift) = await Post("api/company/pos/shifts/open",
        new { activationID = activation, openingCash = 0 });
    Assert("open isolated POS shift", shiftStatus, HttpStatusCode.OK);
    var shiftId = shift.GetProperty("id").GetInt64();
    decimal counted = 0;
    try
    {
        var item = await Number($"SELECT ItemID FROM dbo.TDIVItem WHERE CompanyID={company} AND ItemCode=N'NM001'");
        var (saleStatus, sale) = await Post("api/company/pos/sales/finalize", new {
            activationID = activation, idempotencyKey = Guid.NewGuid(),
            items = new[] { new { itemID = item, quantity = 1 } },
            discountAmount = 0, paymentCode = "CASH", receivedAmount = 10,
            paymentReference = "SP261004_DEMO", customerID = (long?)null,
            sportMemberID = memberA
        });
        Assert("POS sale with sport member", saleStatus, HttpStatusCode.OK);
        counted = sale.GetProperty("net").GetDecimal();
    }
    finally
    {
        using var close = new HttpRequestMessage(HttpMethod.Post, $"api/company/pos/shifts/{shiftId}/close");
        close.Headers.Authorization = new AuthenticationHeaderValue("Bearer", jwt);
        close.Content = JsonContent.Create(new { countedCash = counted, remark = "SP261004_DEMO" });
        using var closed = await http.SendAsync(close);
        Assert("close isolated POS shift", closed.StatusCode, HttpStatusCode.NoContent);
    }
}
await using (var priceCheck = new SqlCommand($"""
SELECT TOP(1) I.UnitPrice FROM dbo.TDPOSale S
JOIN dbo.TDSPMember M ON M.CompanyID=S.CompanyID AND M.MemberID=S.SportMemberID
JOIN dbo.TDPOSaleItem I ON I.CompanyID=S.CompanyID AND I.SaleID=S.SaleID
WHERE S.CompanyID={company} AND M.MemberCode=N'SP261004_A'
 AND S.SportPriceLevelCodeSnapshot=N'00002'
ORDER BY S.SaleID DESC
""", db))
{
    var actual = await priceCheck.ExecuteScalarAsync();
    if (actual is null || Convert.ToDecimal(actual) != 6.5m)
        throw new Exception("POS sport member price was not snapshotted as 6.50");
    passed++; Console.WriteLine("PASS member price snapshot 6.50");
}
Console.WriteLine($"Sport HTTP smoke passed: {passed}");
