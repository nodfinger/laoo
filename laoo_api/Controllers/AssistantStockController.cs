using System.Text.Json;
using LaooApi.Services.Assistant;
using LaooServiceModule.Controllers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/assistant/stock")]
public sealed class AssistantStockController(IConfiguration configuration) : ControllerBase
{
    [HttpGet("serial")]
    public async Task<IActionResult> FindSerial([FromQuery] string? serial, CancellationToken token)
    {
        serial = serial?.Trim();
        if (string.IsNullOrWhiteSpace(serial) || serial.Length > 200)
            return BadRequest(new { message = "กรุณาระบุ Serial ไม่เกิน 200 ตัวอักษร" });
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await AssistantCapabilityAccess.IsAllowed(db, User, "stock.serial_lookup", token)) return Forbid();

        // The existing registry applies company, menu and warehouse access checks.
        var registry = new ItemInstanceController(configuration) { ControllerContext = ControllerContext };
        var found = await registry.List(serial, null, null, null, token);
        if (found is not OkObjectResult ok) return found;
        var rows = JsonSerializer.SerializeToElement(ok.Value);
        var results = new List<object>();
        foreach (var row in rows.EnumerateArray())
        {
            if (!string.Equals(row.GetProperty("serialNo").GetString(), serial, StringComparison.OrdinalIgnoreCase)) continue;
            var id = row.GetProperty("itemInstanceID").GetInt64();
            // Check again for each serial: warranties enforce the same warehouse scope.
            var warranties = await registry.Warranties(id, token);
            if (warranties is not OkObjectResult warrantyOk) return warranties;
            var history = await registry.History(id, token);
            if (history is not OkObjectResult historyOk) return history;
            var events = JsonSerializer.SerializeToElement(historyOk.Value).EnumerateArray()
                .Select(h => new { status = h.GetProperty("toStatusCode").GetString(), date = h.GetProperty("eventDate").GetDateTime() })
                .TakeLast(20).Reverse().ToArray();
            var active = JsonSerializer.SerializeToElement(warrantyOk.Value).EnumerateArray()
                .Where(w => w.GetProperty("voidedDate").ValueKind == JsonValueKind.Null)
                .Select(w => new { coverage = w.GetProperty("coverageTypeCode").GetString(),
                    mode = w.GetProperty("warrantyModeCode").GetString(),
                    start = w.GetProperty("startDate").GetDateTime(),
                    expires = w.GetProperty("expireDate").ValueKind == JsonValueKind.Null ? (DateTime?)null : w.GetProperty("expireDate").GetDateTime() }).ToArray();
            results.Add(new { serial = row.GetProperty("serialNo").GetString(), name = row.GetProperty("itemName").GetString(),
                status = row.GetProperty("statusCode").GetString(), warranties = active, history = events });
        }
        return Ok(new { items = results });
    }
}
