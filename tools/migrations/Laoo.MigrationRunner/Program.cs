using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

var options = RunnerOptions.Parse(args);
var root = Path.GetFullPath(options.Root);
var migrationDirectory = ResolveMigrationDirectory(root, options.ProjectCode);
var files = Directory.Exists(migrationDirectory)
    ? Directory.GetFiles(migrationDirectory, "*.sql").Order().ToArray()
    : [];

ValidateFileNames(files, options.ProjectCode);
if (options.DryRun)
{
    Console.WriteLine($"Project: {options.ProjectCode}");
    Console.WriteLine($"Migration directory: {migrationDirectory}");
    foreach (var file in files) Console.WriteLine(Path.GetFileName(file));
    Console.WriteLine($"Pending candidates: {files.Length}");
    return;
}

var connectionString = Environment.GetEnvironmentVariable("LAOO_CONNECTION_STRING")
    ?? ReadConnectionString(Path.Combine(root, "laoo_api", "local.json"));
if (string.IsNullOrWhiteSpace(connectionString))
    throw new InvalidOperationException(
        "Set LAOO_CONNECTION_STRING or configure ConnectionStrings:LaooDatabase in laoo_api/local.json.");

await using var connection = new SqlConnection(connectionString);
await connection.OpenAsync();
await BootstrapLedger(connection, Path.Combine(root, "database", "MIGRATION_LEDGER_SCHEMA.sql"));

foreach (var file in files)
{
    var migrationId = Path.GetFileNameWithoutExtension(file);
    var sql = await File.ReadAllTextAsync(file, Encoding.UTF8);
    var checksum = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(sql)));
    await ApplyMigration(connection, migrationId, options.ProjectCode, checksum, sql, options.AppliedBy);
}

static string ResolveMigrationDirectory(string root, string projectCode) =>
    projectCode switch
    {
        "LAOO" => Path.Combine(root, "database", "migrations"),
        "LAOO_SERVICE" => Path.Combine(root, "projects", "service", "database", "migrations"),
        "LAOO_MEETING" => Path.Combine(root, "projects", "meeting", "database", "migrations"),
        "LAOO_VISITOR" => Path.Combine(root, "projects", "visitor", "database", "migrations"),
        _ => throw new ArgumentOutOfRangeException(nameof(projectCode), projectCode, "Unsupported ProjectCode"),
    };

static void ValidateFileNames(IEnumerable<string> files, string projectCode)
{
    var pattern = new Regex(
        $"^[0-9]{{14}}_{Regex.Escape(projectCode)}_[a-z0-9_]+\\.sql$",
        RegexOptions.CultureInvariant);
    foreach (var file in files)
        if (!pattern.IsMatch(Path.GetFileName(file)))
            throw new InvalidOperationException($"Invalid migration file name: {Path.GetFileName(file)}");
}

static string? ReadConnectionString(string path)
{
    if (!File.Exists(path)) return null;
    using var document = JsonDocument.Parse(File.ReadAllText(path));
    return document.RootElement.TryGetProperty("ConnectionStrings", out var section)
        && section.TryGetProperty("LaooDatabase", out var value)
            ? value.GetString()
            : null;
}

static async Task BootstrapLedger(SqlConnection connection, string path)
{
    if (!File.Exists(path))
        throw new FileNotFoundException("Migration ledger schema is missing.", path);
    await using var command = new SqlCommand(await File.ReadAllTextAsync(path), connection)
    {
        CommandTimeout = 120,
    };
    await command.ExecuteNonQueryAsync();
}

static async Task ApplyMigration(
    SqlConnection connection,
    string migrationId,
    string projectCode,
    string checksum,
    string sql,
    string appliedBy)
{
    await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();
    try
    {
        await using (var lockCommand = new SqlCommand(
            "DECLARE @result int; " +
            "EXEC @result=sys.sp_getapplock @Resource=N'LAOO_SCHEMA_MIGRATION'," +
            "@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=60000; " +
            "SELECT @result;",
            connection,
            transaction))
        {
            if (Convert.ToInt32(await lockCommand.ExecuteScalarAsync()) < 0)
                throw new InvalidOperationException("Cannot acquire the LAOO schema migration lock.");
        }

        await using (var existing = new SqlCommand(
            "SELECT Checksum FROM dbo.TDSTSchemaMigration WITH (UPDLOCK,HOLDLOCK) WHERE MigrationID=@id;",
            connection,
            transaction))
        {
            existing.Parameters.AddWithValue("@id", migrationId);
            var recorded = Convert.ToString(await existing.ExecuteScalarAsync());
            if (!string.IsNullOrEmpty(recorded))
            {
                if (!string.Equals(recorded, checksum, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException($"Checksum changed for applied migration {migrationId}.");
                await transaction.CommitAsync();
                Console.WriteLine($"SKIP {migrationId}");
                return;
            }
        }

        foreach (var batch in Regex.Split(sql, @"^\s*GO\s*;?\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase))
        {
            if (string.IsNullOrWhiteSpace(batch)) continue;
            await using var command = new SqlCommand(batch, connection, transaction)
            {
                CommandTimeout = 300,
            };
            await command.ExecuteNonQueryAsync();
        }

        await using (var record = new SqlCommand(
            "INSERT dbo.TDSTSchemaMigration(MigrationID,ProjectCode,Checksum,AppliedUtc,AppliedBy,SourceMachine) " +
            "VALUES(@id,@project,@checksum,SYSUTCDATETIME(),@by,@machine);",
            connection,
            transaction))
        {
            record.Parameters.AddWithValue("@id", migrationId);
            record.Parameters.AddWithValue("@project", projectCode);
            record.Parameters.AddWithValue("@checksum", checksum);
            record.Parameters.AddWithValue("@by", appliedBy);
            record.Parameters.AddWithValue("@machine", Environment.MachineName);
            await record.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();
        Console.WriteLine($"APPLY {migrationId}");
    }
    catch
    {
        await transaction.RollbackAsync();
        throw;
    }
}

internal sealed record RunnerOptions(
    string Root,
    string ProjectCode,
    string AppliedBy,
    bool DryRun)
{
    public static RunnerOptions Parse(string[] args)
    {
        string? Value(string name)
        {
            var index = Array.IndexOf(args, name);
            return index >= 0 && index + 1 < args.Length ? args[index + 1] : null;
        }

        var root = Value("--root") ?? Directory.GetCurrentDirectory();
        var project = (Value("--project") ?? throw new ArgumentException("--project is required"))
            .Trim().ToUpperInvariant();
        var appliedBy = Value("--applied-by")
            ?? Environment.UserName
            ?? "unknown";
        return new RunnerOptions(root, project, appliedBy, args.Contains("--dry-run"));
    }
}
