using System.Security.Claims;
using LaooMeetingApi.Data;
using LaooMeetingApi.Models.DatabaseRouting;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LaooMeetingApi.Controllers;

[ApiController]
[Route("api/database-routing")]
[Authorize]
public sealed class DatabaseRoutingController : ControllerBase
{
    private readonly DatabaseRouteResolver _resolver;

    public DatabaseRoutingController(DatabaseRouteResolver resolver)
    {
        _resolver = resolver;
    }

    [HttpGet("current")]
    public async Task<ActionResult<DatabaseRouteStatusResponse>> Current(
        [FromQuery] long? companyId,
        [FromQuery] long? partnerId,
        CancellationToken cancellationToken)
    {
        // Company users may only resolve their own company. Support users may
        // pass a company/partner while selecting support context.
        var loginMode = User.FindFirstValue("login_mode");
        var claimCompanyId = ParseLong(User.FindFirstValue("company_id"));
        var projectId = ParseLong(User.FindFirstValue("project_id"));
        if (!projectId.HasValue)
        {
            return Unauthorized(new DatabaseRouteStatusResponse(
                false, "Token ไม่มี Project context", null));
        }
        if (!string.Equals(loginMode, "LAOO", StringComparison.OrdinalIgnoreCase))
        {
            companyId = claimCompanyId;
            partnerId = null;
        }

        try
        {
            var route = await _resolver.ResolveAsync(
                projectId.Value,
                companyId ?? claimCompanyId,
                partnerId,
                cancellationToken);
            await using var connection = _resolver.CreateBusinessConnection(route);
            await connection.OpenAsync(cancellationToken);

            return Ok(new DatabaseRouteStatusResponse(
                true,
                "เชื่อมต่อฐานข้อมูลปลายทางสำเร็จ",
                route));
        }
        catch (Exception exception) when (
            exception is InvalidOperationException ||
            exception is Microsoft.Data.SqlClient.SqlException)
        {
            return StatusCode(503, new DatabaseRouteStatusResponse(
                false,
                exception.Message,
                null));
        }
    }

    private static long? ParseLong(string? value) =>
        long.TryParse(value, out var result) ? result : null;
}
