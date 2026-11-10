using Microsoft.Data.SqlClient;

namespace LaooApi.Services.Assistant;

/// <summary>Removes expired, redacted queue records; approved examples are stored separately.</summary>
public sealed class ChatReviewRetentionWorker(IConfiguration configuration, ILogger<ChatReviewRetentionWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromHours(1));
        do
        {
            try
            {
                await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
                await db.OpenAsync(stoppingToken);
                await using var cmd = new SqlCommand("""
IF OBJECT_ID(N'dbo.TDADAiChatReview',N'U') IS NOT NULL AND COL_LENGTH(N'dbo.TDSTCompanySetUp',N'AiChatRetentionDays') IS NOT NULL
    DELETE R FROM dbo.TDADAiChatReview R
    WHERE EXISTS (SELECT 1 FROM dbo.TDSTCompanySetUp C WHERE C.CompanyID=R.CompanyID AND C.OwnerType='C'
      AND C.AiChatRetentionDays BETWEEN 1 AND 3650
      AND R.CreatedAt < DATEADD(day,-C.AiChatRetentionDays,SYSUTCDATETIME()));
""", db);
                await cmd.ExecuteNonQueryAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogWarning(ex, "AI chat review retention cleanup failed"); }
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
