using System.Text;
using LaooMeetingApi.Data;
using LaooMeetingApi.Security;
using LaooMeetingApi.Services;
using LaooMeetingApi.Endpoints;
using LaooMeetingApi.Infrastructure.Database;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile(
        $"appsettings.{builder.Environment.EnvironmentName}.json",
        optional: true,
        reloadOnChange: true)
    .AddJsonFile("local.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables();

// Plesk/IIS captures stdout. Avoid the Windows Event Log provider because
// application-pool identities commonly cannot create or write Event sources.
builder.Logging.ClearProviders();
builder.Logging.AddConfiguration(builder.Configuration.GetSection("Logging"));
builder.Logging.AddConsole();
builder.Logging.AddDebug();

builder.Services.AddControllers();
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = context =>
    {
        context.ProblemDetails.Extensions["traceId"] =
            context.HttpContext.TraceIdentifier;
    };
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSingleton<ISqlConnectionChecker, SqlConnectionChecker>();

var dataProtection = builder.Services
    .AddDataProtection()
    .SetApplicationName(
        builder.Configuration["DataProtection:ApplicationName"] ?? "LaooMeetingApi");
var keyRingPath = builder.Configuration["DataProtection:KeyRingPath"]?.Trim();
if (!string.IsNullOrWhiteSpace(keyRingPath))
{
    Directory.CreateDirectory(keyRingPath);
    dataProtection.PersistKeysToFileSystem(new DirectoryInfo(keyRingPath));
}
else if (builder.Environment.IsProduction())
{
    throw new InvalidOperationException(
        "DataProtection:KeyRingPath is required in the Production environment.");
}

builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition(
        "Bearer",
        new OpenApiSecurityScheme
        {
            Name = "Authorization",
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT",
            In = ParameterLocation.Header,
            Description = "ใส่ JWT Access Token สำหรับทดสอบ API ที่ต้อง Login"
        });

    options.AddSecurityRequirement(
        new OpenApiSecurityRequirement
        {
            {
                new OpenApiSecurityScheme
                {
                    Reference = new OpenApiReference
                    {
                        Type = ReferenceType.SecurityScheme,
                        Id = "Bearer"
                    }
                },
                Array.Empty<string>()
            }
        });
});

builder.Services.Configure<JwtOptions>(
    builder.Configuration.GetSection(JwtOptions.SectionName));

builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<DatabaseRouteResolver>();
builder.Services.AddSingleton<PasswordService>();
builder.Services.AddSingleton<CompanySetupSecretService>();
builder.Services.AddSingleton<JwtTokenService>();
builder.Services.AddScoped<DatabaseSeeder>();
builder.Services.AddScoped<AuthenticationService>();
builder.Services.AddScoped<PasswordResetService>();

var jwtOptions = builder.Configuration
    .GetSection(JwtOptions.SectionName)
    .Get<JwtOptions>()
    ?? throw new InvalidOperationException("ไม่พบการตั้งค่า Jwt");

if (string.IsNullOrWhiteSpace(jwtOptions.SecretKey) ||
    jwtOptions.SecretKey.Length < 32)
{
    throw new InvalidOperationException(
        "กรุณากำหนด Jwt:SecretKey ใน local.json อย่างน้อย 32 ตัวอักษร");
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidateAudience = true,
            ValidAudience = jwtOptions.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwtOptions.SecretKey)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1)
        };

        if (builder.Environment.IsDevelopment())
        {
            options.Events = new JwtBearerEvents
            {
                OnAuthenticationFailed = context =>
                {
                    Console.WriteLine(
                        $"JWT authentication failed: {context.Exception.GetType().Name}");
                    return Task.CompletedTask;
                },
                OnTokenValidated = _ =>
                {
                    Console.WriteLine("JWT token validated.");
                    return Task.CompletedTask;
                },
                OnChallenge = context =>
                {
                    Console.WriteLine($"JWT challenge: {context.Error}");
                    return Task.CompletedTask;
                }
            };
        }
    });

builder.Services.AddAuthorization();

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("authentication", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString()
                ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
});

var allowedCorsOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>()
    ?.Where(origin => !string.IsNullOrWhiteSpace(origin))
    .Select(origin => origin.Trim().TrimEnd('/'))
    .Distinct(StringComparer.OrdinalIgnoreCase)
    .ToArray() ?? [];

builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterDevelopment", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });

    options.AddPolicy("ConfiguredClients", policy =>
    {
        if (allowedCorsOrigins.Length > 0)
        {
            policy.WithOrigins(allowedCorsOrigins)
                  .AllowAnyHeader()
                  .AllowAnyMethod();
        }
    });
});

var seedEnabled = builder.Configuration.GetValue<bool>("SeedData:Enabled");
if (seedEnabled && builder.Environment.IsProduction())
{
    throw new InvalidOperationException(
        "SeedData cannot be enabled in the Production environment.");
}

if (seedEnabled)
{
    DatabaseSeeder.ValidateConfiguration(builder.Configuration);
}

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler();
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
    app.UseCors("FlutterDevelopment");
}
else
{
    app.UseCors("ConfiguredClients");
}

// Static building images are requested by Flutter Web from a different
// origin/port. Keep static files after CORS so image responses include the
// required Access-Control-Allow-Origin header.
app.UseStaticFiles();

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapSystemInfoEndpoints();

if (seedEnabled)
{
    using var scope = app.Services.CreateScope();
    var seeder = scope.ServiceProvider.GetRequiredService<DatabaseSeeder>();
    await seeder.SeedAsync();
}

app.Run();
