namespace LaooApi.Models;

public sealed record CompanyContextCompany(
    long CompanyID,
    string CompanyCode,
    string CompanyName);

public sealed record CompanyContextResponse(
    bool Success,
    long? CompanyID,
    string? CompanyCode,
    string? CompanyName,
    string AccessToken,
    DateTime ExpiresAt);

public sealed class SelectCompanyContextRequest
{
    public long CompanyID { get; init; }
}
