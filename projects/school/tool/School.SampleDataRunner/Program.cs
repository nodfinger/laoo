using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;

var root = args.Length > 0 ? Path.GetFullPath(args[0]) : Directory.GetCurrentDirectory();
var configPath = Path.Combine(root, "laoo_api", "local.json");
if (!File.Exists(configPath))
{
    throw new FileNotFoundException("laoo_api/local.json was not found.", configPath);
}

using var config = JsonDocument.Parse(await File.ReadAllTextAsync(configPath));
var connectionString = config.RootElement
    .GetProperty("ConnectionStrings")
    .GetProperty("LaooDatabase")
    .GetString();
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException("LaooDatabase connection string is missing.");
}

const string email = "waraporn.school@example.com";
var samplePassword = Environment.GetEnvironmentVariable(
    "LAOO_SCHOOL_SAMPLE_PASSWORD");
if (string.IsNullOrWhiteSpace(samplePassword))
{
    throw new InvalidOperationException(
        "LAOO_SCHOOL_SAMPLE_PASSWORD environment variable is required.");
}
var hash = new PasswordHasher<string>().HashPassword(email, samplePassword);

await using var connection = new SqlConnection(connectionString);
await connection.OpenAsync();
await using var command = new SqlCommand("""
UPDATE dbo.TDSCGuardian
SET PasswordHash=@Hash,FailedLoginCount=0,LockedUntil=NULL
WHERE CompanyID=1 AND GuardianCode=N'G-001' AND Email=@Email;
""", connection);
command.Parameters.AddWithValue("@Hash", hash);
command.Parameters.AddWithValue("@Email", email);
if (await command.ExecuteNonQueryAsync() != 1)
{
    throw new InvalidOperationException("Sample guardian G-001 was not found.");
}

Console.WriteLine("SCHOOL_SAMPLE_GUARDIAN_READY");
