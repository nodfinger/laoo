using System.Security.Claims;
using System.Text.Json;
using LaooMeetingApi.Controllers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;

var jsonOptions = new JsonSerializerOptions(JsonSerializerDefaults.Web);
var request = JsonSerializer.Deserialize<FoodPlanRequest>(
    """{"orderCutoffDateTime":"2030-01-01T10:00:00","foodIds":[11,12],"isActive":true,"foodQuantities":{"11":3,"12":1}}""",
    jsonOptions)!;
Check(request.FoodQuantities![11] == 3 && request.FoodQuantities[12] == 1,
    "JSON quantity keys and values deserialize");
var legacy = JsonSerializer.Deserialize<FoodPlanRequest>(
    """{"orderCutoffDateTime":"2030-01-01T10:00:00","foodIds":[11],"isActive":true}""",
    jsonOptions)!;
Check(legacy.FoodQuantities is null, "Legacy clients may omit quantities (default 1)");

var controller = new MeetingFoodPlanController(new ConfigurationBuilder().Build())
{
    ControllerContext = new ControllerContext
    {
        HttpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim("company_id", "1"),
                new Claim("user_id", "1"),
                new Claim("user_type", "COMPANY_USER"),
            }, "test")),
        },
    },
};
foreach (var (label, quantities) in new[]
{
    ("zero", new Dictionary<long, int> { [11] = 0, [12] = 1 }),
    ("negative", new Dictionary<long, int> { [11] = -1, [12] = 1 }),
    ("missing food", new Dictionary<long, int> { [11] = 1 }),
    ("unselected food", new Dictionary<long, int> { [11] = 1, [12] = 1, [13] = 1 }),
})
{
    var result = await controller.Save(1, request with { FoodQuantities = quantities }, default);
    Check(result is BadRequestObjectResult, $"API rejects {label} before writing");
}
foreach (var invalid in new[] { "1.5", "2147483648", "null" })
{
    var rejected = false;
    try
    {
        JsonSerializer.Deserialize<FoodPlanRequest>(
            """{"orderCutoffDateTime":"2030-01-01T10:00:00","foodIds":[11],"foodQuantities":{"11":"""
            + invalid + "}}", jsonOptions);
    }
    catch (JsonException) { rejected = true; }
    Check(rejected, $"JSON rejects non-integer/out-of-range quantity {invalid}");
}

static void Check(bool result, string name)
{
    if (!result) throw new InvalidOperationException(name);
    Console.WriteLine($"PASS {name}");
}
