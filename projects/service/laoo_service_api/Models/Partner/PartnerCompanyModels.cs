namespace LaooServiceApi.Models.Partner;

public sealed class PartnerCompanyResponse
{
    public long CompanyId { get; init; }
    public long PartnerId { get; init; }
    public string? PartnerNameTh { get; init; }
    public string CompanyCode { get; init; } = string.Empty;
    public string CompanyNameTh { get; init; } = string.Empty;
    public string? CompanyNameEn { get; init; }
    public string? TaxId { get; init; }
    public string? Email { get; init; }
    public string? Telephone { get; init; }
    public string? AddressText { get; init; }
    public bool IsActive { get; init; }
    public DateTime CreateDate { get; init; }
    public long? CreateBy { get; init; }
    public DateTime? UpdateDate { get; init; }
    public long? UpdateBy { get; init; }
    public string? ThemeName { get; init; }
    public string? AdminUsername { get; init; }
}

public sealed class PartnerCompanyUpsertRequest
{
    public bool IsActive { get; init; } = true;
    public string CompanyNameTh { get; init; } = string.Empty;
    public string? CompanyNameEn { get; init; }
    public string? TaxId { get; init; }
    public string? Email { get; init; }
    public string? Telephone { get; init; }
    public string? AddressText { get; init; }
    public string? ThemeName { get; init; }
    public string? AdminUsername { get; init; }
    public string? AdminPassword { get; init; }
}

public sealed class PartnerCompanyAdminUpsertRequest
{
    public string Username { get; init; } = string.Empty;
    public string Password { get; init; } = string.Empty;
}

public sealed class PartnerCompanyFeatureResponse
{
    public string FeatureCode { get; init; } = string.Empty;
    public string FeatureName { get; init; } = string.Empty;
    public string? FeatureDescription { get; init; }
    public bool IsEnabled { get; init; }
    public int SortOrder { get; init; }
}

public sealed class PartnerCompanyFeatureUpdateRequest
{
    public List<PartnerCompanyFeatureUpdateItem> Features { get; init; } = [];
}

public sealed class PartnerCompanyFeatureUpdateItem
{
    public string FeatureCode { get; init; } = string.Empty;
    public bool IsEnabled { get; init; }
}
