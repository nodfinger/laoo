using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Route("api/time")]
[Authorize]
public sealed class TimeStatusController(IConfiguration configuration)
    : ControllerBase
{
    [HttpGet("project")]
    public IActionResult Project() => Ok(new
    {
        projectCode = "LAOO_TIME",
        projectName = "ระบบบริหารเวลา",
        status = "BOOTSTRAP",
        runtimeHost = "LAOO",
    });

    [HttpGet("health")]
    [AllowAnonymous]
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
                "WHERE ProjectCode=N'LAOO_TIME' AND IsActive=1",
                connection);
            var count = Convert.ToInt64(await command.ExecuteScalarAsync(token));
            return count == 1
                ? Ok(new
                {
                    status = "Healthy",
                    projectCode = "LAOO_TIME",
                    runtimeHost = "LAOO",
                })
                : Problem(
                    title: "LAOO_TIME project is not active",
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
