using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Infrastructure.Database;

public sealed class SqlConnectionChecker(
    IConfiguration configuration,
    ILogger<SqlConnectionChecker> logger) : ISqlConnectionChecker
{
    public async Task<bool> CanConnectAsync(CancellationToken cancellationToken)
    {
        var connectionString =
            configuration.GetConnectionString("LaooDatabase");

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            logger.LogError("LaooDatabase connection is not configured.");
            return false;
        }

        try
        {
            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync(cancellationToken);

            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT 1;";
            command.CommandTimeout = 10;

            var result = await command.ExecuteScalarAsync(cancellationToken);
            return Convert.ToInt32(result) == 1;
        }
        catch (Exception exception)
        {
            logger.LogError(
                exception,
                "Unable to connect to SQL Server.");
            return false;
        }
    }
}
