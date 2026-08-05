using Laoo.Api.Endpoints;
using Laoo.Api.Infrastructure.Database;

var builder = WebApplication.CreateBuilder(args);

// หลังจาก CreateBuilder()

builder.Configuration.AddJsonFile(
    "appsettings.Local.json",
    optional: true,
    reloadOnChange: true
);


builder.Services.AddSingleton<ISqlConnectionChecker, SqlConnectionChecker>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("DevelopmentCors", policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();
 

if (app.Environment.IsDevelopment())
{
    app.UseCors("DevelopmentCors");
}

app.MapGet("/", () => Results.Ok(new
{
    name = "Laoo API",
    status = "Running"
}));

app.MapSystemInfoEndpoints();

app.Run();
