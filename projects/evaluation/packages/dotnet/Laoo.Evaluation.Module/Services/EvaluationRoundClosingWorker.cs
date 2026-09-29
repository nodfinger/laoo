using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace LaooEvaluationModule.Services;

public sealed class EvaluationRoundClosingWorker(
    IConfiguration configuration,
    ILogger<EvaluationRoundClosingWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CloseExpiredRounds(stoppingToken);
            }
            catch (Exception exception) when (!stoppingToken.IsCancellationRequested)
            {
                logger.LogError(exception, "Unable to close expired evaluation rounds");
            }

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }

    private async Task CloseExpiredRounds(CancellationToken token)
    {
        await using var connection = new SqlConnection(
            configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);

        const string sql = """
UPDATE dbo.TDEVRound
SET StatusCode = N'CLOSED'
WHERE StatusCode = N'PUBLISHED'
  AND CloseDateTime <= SYSUTCDATETIME();
""";
        await using var command = new SqlCommand(sql, connection);
        var affected = await command.ExecuteNonQueryAsync(token);
        if (affected > 0)
            logger.LogInformation("Closed {RoundCount} expired evaluation rounds", affected);
    }
}
