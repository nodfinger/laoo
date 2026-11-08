using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/public/home-page")]
public sealed class PublicHomePageController(IConfiguration configuration) : ControllerBase
{
    [AllowAnonymous]
    [HttpGet]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public IActionResult Get()
    {
        var configuredMode = configuration["HomePage:DefaultMode"];
        var mode = string.IsNullOrWhiteSpace(configuredMode)
            ? 3
            : int.TryParse(configuredMode, out var parsed) ? parsed : 0;
        return Ok(new
        {
            defaultMode = mode,
            externalUrl = configuration["HomePage:Options:2:Url"] ?? string.Empty,
            loginReturnUrl = configuration["HomePage:Options:1:Url"] ?? string.Empty,
            showLoginButton = bool.TryParse(configuration["HomePage:Options:2:ShowLoginButton"], out var showLogin) && showLogin,
        });
    }
}
