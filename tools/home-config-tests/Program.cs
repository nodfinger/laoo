using System.Text.Json;
using LaooApi.Controllers;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.Authorization;

var config = new ConfigurationBuilder()
    .AddInMemoryCollection(new Dictionary<string, string?> {
        ["HomePage:DefaultMode"] = "3",
        ["HomePage:Options:2:Url"] = "https://first.example",
        ["ConnectionStrings:LaooDatabase"] = "private-value",
    })
    .AddInMemoryCollection(new Dictionary<string, string?> {
        ["HomePage:DefaultMode"] = "2",
        ["HomePage:Options:2:Url"] = "https://override.example",
        ["HomePage:Options:1:Url"] = "https://login-return.example",
        ["HomePage:Options:2:ShowLoginButton"] = "true",
    }).Build();
var controller = new PublicHomePageController(config);
if (!Attribute.IsDefined(typeof(PublicHomePageController).GetMethod(nameof(PublicHomePageController.Get))!, typeof(AllowAnonymousAttribute)))
    throw new Exception("Home configuration must be accessible without login");
var value = (controller.Get() as OkObjectResult)?.Value ?? throw new Exception("Expected OK");
using var json = JsonDocument.Parse(JsonSerializer.Serialize(value));
if (json.RootElement.EnumerateObject().Count() != 4 ||
    json.RootElement.GetProperty("defaultMode").GetInt32() != 2 ||
    json.RootElement.GetProperty("externalUrl").GetString() != "https://override.example" ||
    json.RootElement.GetProperty("loginReturnUrl").GetString() != "https://login-return.example" ||
    !json.RootElement.GetProperty("showLoginButton").GetBoolean() ||
    json.RootElement.ToString().Contains("private-value"))
    throw new Exception("Public configuration or precedence is incorrect");
config["HomePage:DefaultMode"] = "invalid";
var invalid = (controller.Get() as OkObjectResult)?.Value ?? throw new Exception("Expected OK");
using var invalidJson = JsonDocument.Parse(JsonSerializer.Serialize(invalid));
if (invalidJson.RootElement.GetProperty("defaultMode").GetInt32() != 0)
    throw new Exception("Invalid setting must be reported without leaking configuration");
Console.WriteLine("Public home configuration exposes only intended values and honors overrides.");
