using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile(
        $"appsettings.{builder.Environment.EnvironmentName}.json",
        optional: true,
        reloadOnChange: true)
    .AddJsonFile("local.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables();

builder.Services.AddCors(options =>
{
    options.AddPolicy("LocalDevelopment", policy =>
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseCors("LocalDevelopment");
}

app.MapGet("/api/project", () => Results.Ok(new
{
    projectCode = "LAOO_VISITOR",
    projectName = "ระบบผู้มาติดต่อ",
    status = "BOOTSTRAP"
}));

app.MapGet("/api/health", async (IConfiguration configuration) =>
{
    var connectionString = configuration.GetConnectionString("LaooDatabase");
    if (string.IsNullOrWhiteSpace(connectionString))
    {
        return Results.Problem(
            title: "Database configuration is missing",
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    try
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(
            "SELECT COUNT_BIG(1) FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_VISITOR' AND IsActive = 1",
            connection);
        var projectCount = Convert.ToInt64(await command.ExecuteScalarAsync());

        return projectCount == 1
            ? Results.Ok(new { status = "Healthy", projectCode = "LAOO_VISITOR" })
            : Results.Problem(
                title: "LAOO_VISITOR project is not active",
                statusCode: StatusCodes.Status503ServiceUnavailable);
    }
    catch (SqlException)
    {
        return Results.Problem(
            title: "Database connection is unavailable",
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }
});

app.Run();
