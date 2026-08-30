namespace Laoo.Api.Contracts.SystemInfo;

public sealed record SystemInfoResponse(
    string SystemName,
    string Version,
    DateTimeOffset ServerTime,
    string DatabaseStatus
);
