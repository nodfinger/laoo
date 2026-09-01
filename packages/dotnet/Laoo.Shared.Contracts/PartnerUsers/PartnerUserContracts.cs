namespace Laoo.Shared.Contracts.PartnerUsers;

public sealed record PartnerUserScreenContract(
    string MenuCode,
    string RouteName,
    string ApiPath,
    int ScreenType,
    string LegacyPermissionCode,
    string RequiredUserType);

public static class PartnerUserScreenContracts
{
    public static readonly PartnerUserScreenContract Support =
        new("02002", "partnerUser", "/api/support/partner-users", 1, "PARTNER", "LAOO_SUPPORT");
}

public sealed class PartnerUserResponse
{
    public long PartnerUserId { get; init; }
    public long PartnerId { get; init; }
    public string Username { get; init; } = string.Empty;
    public string DisplayName { get; init; } = string.Empty;
    public string? Email { get; init; }
    public string? MobileNumber { get; init; }
    public bool IsPartnerAdmin { get; init; }
    public bool IsActive { get; init; }
}

public sealed class PartnerUserUpsertRequest
{
    public string Username { get; init; } = string.Empty;
    public string? Password { get; init; }
    public string DisplayName { get; init; } = string.Empty;
    public string? Email { get; init; }
    public string? MobileNumber { get; init; }
    public bool IsPartnerAdmin { get; init; }
    public bool IsActive { get; init; } = true;
}
