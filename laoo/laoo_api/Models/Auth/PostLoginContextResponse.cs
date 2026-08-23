namespace Laoo.Api.Models.Auth;

public static class AuthUserTypes
{
    public const string LaooSupport = "LAOO_SUPPORT";
    public const string PartnerUser = "PARTNER_USER";
    public const string CompanyUser = "COMPANY_USER";
}

public sealed class PostLoginContextResponse
{
    public string UserType { get; init; } = string.Empty;

    public long UserId { get; init; }

    public long? PartnerId { get; init; }

    public string Username { get; init; } = string.Empty;

    public string DisplayName { get; init; } = string.Empty;

    public bool IsSupportUser { get; init; }

    public bool CanLoginAsUser { get; init; }

    public List<AuthCompanyItem> Companies { get; init; } = [];

    public List<AuthBranchItem> Branches { get; init; } = [];

    public List<AuthProjectItem> Projects { get; init; } = [];
}

public sealed class AuthCompanyItem
{
    public long CompanyId { get; init; }

    public string CompanyCode { get; init; } = string.Empty;

    public string CompanyNameTh { get; init; } = string.Empty;

    public string? CompanyNameEn { get; init; }

    public bool IsDefault { get; init; }
}

public sealed class AuthBranchItem
{
    public long BranchId { get; init; }

    public long CompanyId { get; init; }

    public string BranchCode { get; init; } = string.Empty;

    public string BranchNameTh { get; init; } = string.Empty;

    public string? BranchNameEn { get; init; }

    public bool IsDefault { get; init; }
}

public sealed class AuthProjectItem
{
    public long ProjectId { get; init; }

    public string ProjectCode { get; init; } = string.Empty;

    public string ProjectNameTh { get; init; } = string.Empty;

    public string? ProjectNameEn { get; init; }

    public bool IsDefault { get; init; }

    public bool CanAccess { get; init; }

    public bool CanLoginAsUser { get; init; }
}
