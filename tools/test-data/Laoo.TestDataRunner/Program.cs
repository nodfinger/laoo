using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

string? Value(string name)
{
    var index = Array.IndexOf(args, name);
    return index >= 0 && index + 1 < args.Length ? args[index + 1] : null;
}

var root = Path.GetFullPath(Value("--root") ?? Directory.GetCurrentDirectory());
var file = Path.GetFullPath(Value("--file") ?? throw new ArgumentException("--file is required"));
var allowedRoot = Path.Combine(root, "projects") + Path.DirectorySeparatorChar;
if (!file.StartsWith(allowedRoot, StringComparison.OrdinalIgnoreCase)
    || !file.Contains($"{Path.DirectorySeparatorChar}database{Path.DirectorySeparatorChar}test-data{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase)
    || !file.EndsWith(".sql", StringComparison.OrdinalIgnoreCase))
    throw new InvalidOperationException("Test-data file must be under projects/<project>/database/test-data.");
if (!File.Exists(file)) throw new FileNotFoundException("Test-data file not found.", file);

var local = Path.Combine(root, "laoo_api", "local.json");
using var json = JsonDocument.Parse(await File.ReadAllTextAsync(local));
var connectionString = json.RootElement.GetProperty("ConnectionStrings").GetProperty("LaooDatabase").GetString();
if (string.IsNullOrWhiteSpace(connectionString)) throw new InvalidOperationException("LaooDatabase connection is missing.");

await using var connection = new SqlConnection(connectionString);
await connection.OpenAsync();
await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();
try
{
    var sql = await File.ReadAllTextAsync(file, Encoding.UTF8);
    foreach (var batch in Regex.Split(sql, @"^\s*GO\s*;?\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase))
    {
        if (string.IsNullOrWhiteSpace(batch)) continue;
        await using var command = new SqlCommand(batch, connection, transaction) { CommandTimeout = 300 };
        await command.ExecuteNonQueryAsync();
    }
    await transaction.CommitAsync();
    Console.WriteLine($"APPLY TEST-DATA {Path.GetFileName(file)}");
}
catch
{
    await transaction.RollbackAsync();
    throw;
}
