using Laoo.Api.Contracts.Common;
using Laoo.Api.Contracts.SystemInfo;
using Laoo.Api.Infrastructure.Database;

namespace Laoo.Api.Endpoints;

public static class SystemInfoEndpoints
{
    public static IEndpointRouteBuilder MapSystemInfoEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
            "/health",
            async (
                ISqlConnectionChecker connectionChecker,
                CancellationToken cancellationToken) =>
            {
                var canConnect =
                    await connectionChecker.CanConnectAsync(cancellationToken);

                return canConnect
                    ? Results.Ok(new { status = "Healthy" })
                    : Results.Json(
                        new { status = "Unhealthy" },
                        statusCode: StatusCodes.Status503ServiceUnavailable);
            })
            .AllowAnonymous();

        endpoints.MapGet(
            "/api/system/info",
            async (
                IConfiguration configuration,
                ISqlConnectionChecker connectionChecker,
                HttpContext httpContext,
                CancellationToken cancellationToken) =>
            {
                var canConnect =
                    await connectionChecker.CanConnectAsync(cancellationToken);

                if (!canConnect)
                {
                    return Results.Json(
                        new ApiErrorResponse(
                            "DATABASE_UNAVAILABLE",
                            "ไม่สามารถเชื่อมต่อฐานข้อมูลได้ในขณะนี้",
                            httpContext.TraceIdentifier),
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }

                var systemName =
                    configuration["SystemInfo:SystemName"] ?? "Laoo";

                var version =
                    configuration["SystemInfo:Version"] ?? "1.0.0";

                return Results.Ok(
                    new SystemInfoResponse(
                        systemName,
                        version,
                        DateTimeOffset.Now,
                        "Connected"));
            });

        return endpoints;
    }
}
