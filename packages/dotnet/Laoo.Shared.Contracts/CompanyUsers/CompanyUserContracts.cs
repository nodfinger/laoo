namespace Laoo.Shared.Contracts.CompanyUsers;

public sealed record CompanyUserScreenContract(
    string MenuCode,
    string RouteName,
    string ApiPath,
    int ScreenType,
    string RequiredUserType);

public static class CompanyUserScreenContracts
{
    public static readonly CompanyUserScreenContract Partner =
        new("07001", "partnerUsers", "/api/partner/company-users", 2, "PARTNER_USER");
}

public sealed class CompanyUserResponse
{
    public long UserId { get; init; }
    public long CompanyId { get; init; }
    public string CompanyCode { get; init; } = string.Empty;
    public string CompanyName { get; init; } = string.Empty;
    public string Username { get; init; } = string.Empty;
    public string DisplayName { get; init; } = string.Empty;
    public string? Email { get; init; }
    public string? Mobile { get; init; }
    public bool IsCompanyAdmin { get; init; }
    public bool IsActive { get; init; }
}

public sealed class CompanyUserUpdateRequest
{
    public string Username { get; init; } = string.Empty;
    public string? Password { get; init; }
    public string DisplayName { get; init; } = string.Empty;
    public string? Email { get; init; }
    public string? Mobile { get; init; }
    public bool IsActive { get; init; } = true;
}
