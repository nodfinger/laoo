namespace LaooMeetingApi.Infrastructure.Database;

public interface ISqlConnectionChecker
{
    Task<bool> CanConnectAsync(CancellationToken cancellationToken);
}
