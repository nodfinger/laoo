namespace LaooServiceApi.Models.DatabaseRouting;

public sealed record DatabaseRouteResolution(
    long? DatabaseRouteId,
    string ScopeCode,
    long? PartnerId,
    long? CompanyId,
    string ConnectionKey,
    string DatabaseName,
    string SchemaName,
    string EnvironmentCode,
    string? RequiredSchemaVersion,
    bool UsedFallback);

public sealed record DatabaseRouteStatusResponse(
    bool Success,
    string Message,
    DatabaseRouteResolution? Route);
