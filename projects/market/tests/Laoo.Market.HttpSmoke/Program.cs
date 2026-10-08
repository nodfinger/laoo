using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Globalization;
using System.Text.Json;
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
    await using var command = new SqlCommand(sql, db);
    return Convert.ToInt64(await command.ExecuteScalarAsync());
}
var company = await Number("SELECT CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1");
var actor = await Number($"SELECT UserID FROM dbo.TDADUser WHERE CompanyID={company} AND Username=N'c111'");
var partner = await Number($"SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID={company}");
var project = await Number("SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO'");
var jwtOptions = config.GetSection("Jwt").Get<JwtOptions>() ?? throw new Exception("JWT options missing");
var signer = new JwtTokenService(Options.Create(jwtOptions));
string Token(long co, long user) => signer.CreateToken(new AuthenticatedUser(
    $"company:{user}", "COMPANY_USER", "COMPANY", null, null, partner, user,
    co, null, project, "LAOO", "market-smoke", "market-smoke", false)).AccessToken;
var jwt = Token(company, actor);
using var http = new HttpClient { BaseAddress = url, Timeout = TimeSpan.FromSeconds(30) };
var passed = 0;
async Task<(HttpStatusCode Code, string Body)> Request(HttpMethod method, string path,
    object? body = null, string? token = null)
{
    using var request = new HttpRequestMessage(method, path);
    if (token != null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
    if (body != null) request.Content = JsonContent.Create(body);
    using var response = await http.SendAsync(request);
    return (response.StatusCode, await response.Content.ReadAsStringAsync());
}
void Assert(string name, HttpStatusCode actual, HttpStatusCode expected, string detail)
{
    if (actual != expected) throw new Exception($"{name}: expected {(int)expected}, got {(int)actual}: {detail[..Math.Min(400, detail.Length)]}");
    passed++; Console.WriteLine("PASS " + name);
}
var unauthenticated = await Request(HttpMethod.Get, "api/company/market/markets");
Assert("anonymous denied", unauthenticated.Code, HttpStatusCode.Unauthorized, unauthenticated.Body);
var deniedCompany = await Request(HttpMethod.Get, "api/company/market/markets", token: Token(99999999, actor));
Assert("wrong company denied", deniedCompany.Code, HttpStatusCode.Forbidden, deniedCompany.Body);
var deniedUser = await Request(HttpMethod.Get, "api/company/market/markets", token: Token(company, 99999999));
Assert("unpermitted user denied", deniedUser.Code, HttpStatusCode.Forbidden, deniedUser.Body);
var access = await Request(HttpMethod.Get, "api/company/market/actions/59003", token: jwt);
Assert("stall menu access", access.Code, HttpStatusCode.OK, access.Body);
var markets = await Request(HttpMethod.Get, "api/company/market/markets", token: jwt);
Assert("market list", markets.Code, HttpStatusCode.OK, markets.Body);
var traders = await Request(HttpMethod.Get, "api/company/market/traders", token: jwt);
Assert("demo trader choices", traders.Code, HttpStatusCode.OK, traders.Body);
using (var tradersJson = JsonDocument.Parse(traders.Body))
{
    if (!tradersJson.RootElement.EnumerateArray().Any(x => x.GetProperty("name").GetString() == "ผู้ค้าเก่า ตัวอย่างตลาด"))
        throw new Exception("Sample old trader missing");
}
passed++; Console.WriteLine("PASS sample trader visible");
using var marketJson = JsonDocument.Parse(markets.Body);
var marketRow = marketJson.RootElement.EnumerateArray()
    .FirstOrDefault(x => x.GetProperty("code").GetString() == "MK261008");
if (marketRow.ValueKind == JsonValueKind.Undefined) throw new Exception("DEMO market missing");
var marketId = marketRow.GetProperty("id").GetInt64();
var today = DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7));
var tomorrow = today.AddDays(1);
var map = await Request(HttpMethod.Get,
    $"api/company/market/markets/{marketId}/map?on={tomorrow.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)}", token: jwt);
Assert("date-aware stall map", map.Code, HttpStatusCode.OK, map.Body);
using var mapJson = JsonDocument.Parse(map.Body);
var stallRows = mapJson.RootElement.EnumerateArray().ToDictionary(
    x => x.GetProperty("code").GetString()!, x => x);
foreach (var (code, expected) in new[] {
    ("A01", "VACANT"), ("A02", "RESERVED"), ("A03", "OCCUPIED"),
    ("B01", "CLOSED"), ("B02", "RENOVATION") })
    if (stallRows[code].GetProperty("status").GetString() != expected)
        throw new Exception($"{code} should be {expected}");
passed++; Console.WriteLine("PASS mapped vacancy and all status colors");
var oldTrader = await Number($"SELECT TraderID FROM dbo.TDMKTrader WHERE CompanyID={company} AND Phone=N'0800005901'");
var newTrader = await Number($"SELECT TraderID FROM dbo.TDMKTrader WHERE CompanyID={company} AND Phone=N'0800005902'");
var stall = stallRows["A01"].GetProperty("id").GetInt64();
var blocked = stallRows["B01"].GetProperty("id").GetInt64();
var key = Guid.NewGuid();
var bookingBody = new { stallID = stall, traderID = oldTrader,
    startsOn = tomorrow, endsOn = tomorrow, idempotencyKey = key };
var booked = await Request(HttpMethod.Post, "api/company/market/bookings", bookingBody, jwt);
Assert("old trader reserves future stall", booked.Code, HttpStatusCode.OK, booked.Body);
using var bookingJson = JsonDocument.Parse(booked.Body);
var bookingId = bookingJson.RootElement.GetProperty("id").GetInt64();
var repeat = await Request(HttpMethod.Post, "api/company/market/bookings", bookingBody, jwt);
Assert("reservation idempotent", repeat.Code, HttpStatusCode.OK, repeat.Body);
using var repeatJson = JsonDocument.Parse(repeat.Body);
if (repeatJson.RootElement.GetProperty("id").GetInt64() != bookingId) throw new Exception("Duplicate booking created");
var conflict = await Request(HttpMethod.Post, "api/company/market/bookings",
    new { stallID = stall, traderID = oldTrader, startsOn = tomorrow,
        endsOn = tomorrow, idempotencyKey = Guid.NewGuid() }, jwt);
Assert("overlap denied", conflict.Code, HttpStatusCode.Conflict, conflict.Body);
var newTraderFuture = await Request(HttpMethod.Post, "api/company/market/bookings",
    new { stallID = stallRows["A04"].GetProperty("id").GetInt64(), traderID = newTrader,
        startsOn = tomorrow, endsOn = tomorrow, idempotencyKey = Guid.NewGuid() }, jwt);
Assert("new trader advance denied", newTraderFuture.Code, HttpStatusCode.Conflict, newTraderFuture.Body);
var blockedBooking = await Request(HttpMethod.Post, "api/company/market/bookings",
    new { stallID = blocked, traderID = oldTrader, startsOn = tomorrow,
        endsOn = tomorrow, idempotencyKey = Guid.NewGuid() }, jwt);
Assert("closed stall denied", blockedBooking.Code, HttpStatusCode.Conflict, blockedBooking.Body);
var reservedBooking = await Request(HttpMethod.Post, "api/company/market/bookings",
    new { stallID = stallRows["A02"].GetProperty("id").GetInt64(), traderID = oldTrader,
        startsOn = tomorrow, endsOn = tomorrow, idempotencyKey = Guid.NewGuid() }, jwt);
Assert("sample reserved stall denied", reservedBooking.Code, HttpStatusCode.Conflict, reservedBooking.Body);
var occupiedBooking = await Request(HttpMethod.Post, "api/company/market/bookings",
    new { stallID = stallRows["A03"].GetProperty("id").GetInt64(), traderID = oldTrader,
        startsOn = tomorrow, endsOn = tomorrow, idempotencyKey = Guid.NewGuid() }, jwt);
Assert("occupied stall denied", occupiedBooking.Code, HttpStatusCode.Conflict, occupiedBooking.Body);
var cancelled = await Request(HttpMethod.Post, $"api/company/market/bookings/{bookingId}/cancel",
    new { reason = "MK_20261008_DEMO HTTP smoke" }, jwt);
Assert("cancel reservation", cancelled.Code, HttpStatusCode.OK, cancelled.Body);
var temporaryStall = stallRows["A01"].GetProperty("id").GetInt64();
var cleanup = await Request(HttpMethod.Post,
    $"api/company/market/stalls/{temporaryStall}/reopen", token: jwt);
if (cleanup.Code is not (HttpStatusCode.OK or HttpStatusCode.Conflict))
    throw new Exception($"A01 pre-test cleanup failed: {cleanup.Body}");
var closedToday = await Request(HttpMethod.Post,
    $"api/company/market/stalls/{temporaryStall}/periods",
    new { statusCode = "CLOSED", startsOn = today, endsOn = today,
        reason = "MK_20261008_DEMO HTTP smoke" }, jwt);
Assert("close vacant stall", closedToday.Code, HttpStatusCode.OK, closedToday.Body);
var todayMap = await Request(HttpMethod.Get,
    $"api/company/market/markets/{marketId}/map?on={today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)}", token: jwt);
Assert("closed stall map", todayMap.Code, HttpStatusCode.OK, todayMap.Body);
using (var closedJson = JsonDocument.Parse(todayMap.Body))
{
    var row = closedJson.RootElement.EnumerateArray().Single(x => x.GetProperty("code").GetString() == "A01");
    if (row.GetProperty("status").GetString() != "CLOSED") throw new Exception("A01 closure not reflected in map");
}
passed++; Console.WriteLine("PASS current-day closure status");
var reopened = await Request(HttpMethod.Post,
    $"api/company/market/stalls/{temporaryStall}/reopen", token: jwt);
Assert("reopen vacant stall", reopened.Code, HttpStatusCode.OK, reopened.Body);
var list = await Request(HttpMethod.Get, $"api/company/market/markets/{marketId}/bookings", token: jwt);
Assert("reservation history", list.Code, HttpStatusCode.OK, list.Body);
Console.WriteLine($"Market HTTP smoke passed: {passed}");
