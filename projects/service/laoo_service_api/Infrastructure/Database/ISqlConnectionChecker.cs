namespace Laoo.Service.Api.Infrastructure.Database;

public interface ISqlConnectionChecker
{
    Task<bool> CanConnectAsync(CancellationToken cancellationToken);
}
