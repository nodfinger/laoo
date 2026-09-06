using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooVisitorModule.Controllers;

[ApiController]
[Route("api/visitor")]
[AllowAnonymous]
public sealed class VisitorStatusController(IConfiguration configuration)
    : ControllerBase
{
    [HttpGet("project")]
    public IActionResult Project() => Ok(new
    {
        projectCode = "LAOO_VISITOR",
        projectName = "ระบบผู้มาติดต่อ",
        status = "BOOTSTRAP",
        runtimeHost = "LAOO",
    });

    [HttpGet("health")]
    public async Task<IActionResult> Health(CancellationToken token)
    {
        var connectionString =
            configuration.GetConnectionString("LaooDatabase");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return Problem(
                title: "Database configuration is missing",
                statusCode: StatusCodes.Status503ServiceUnavailable);
        }

        try
        {
            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync(token);
            await using var command = new SqlCommand(
                "SELECT COUNT_BIG(1) FROM dbo.TDADProject " +
                "WHERE ProjectCode=N'LAOO_VISITOR' AND IsActive=1",
                connection);
            var count = Convert.ToInt64(await command.ExecuteScalarAsync(token));
            return count == 1
                ? Ok(new
                {
                    status = "Healthy",
                    projectCode = "LAOO_VISITOR",
                    runtimeHost = "LAOO",
                })
                : Problem(
                    title: "LAOO_VISITOR project is not active",
                    statusCode: StatusCodes.Status503ServiceUnavailable);
        }
        catch (SqlException)
        {
            return Problem(
                title: "Database connection is unavailable",
                statusCode: StatusCodes.Status503ServiceUnavailable);
        }
    }
}
