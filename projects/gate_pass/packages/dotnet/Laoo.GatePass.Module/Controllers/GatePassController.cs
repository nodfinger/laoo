using Microsoft.AspNetCore.Mvc;
namespace LaooGatePassModule.Controllers;
[ApiController, Route("api/company/gate-passes")]
public sealed class GatePassController : ControllerBase
{
 [HttpGet("health")]
 public IActionResult Health()=>Ok();
}
