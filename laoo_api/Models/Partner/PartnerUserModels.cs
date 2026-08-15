namespace LaooApi.Models.Partner;

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
