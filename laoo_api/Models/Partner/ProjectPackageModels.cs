namespace LaooApi.Models.Partner;

public sealed record ProjectPackageFeatureInput(string FeatureCode, bool IsEnabled = true);

public sealed record ProjectPackageQuotaInput(
    string QuotaCode,
    string QuotaNameTh,
    decimal LimitValue,
    string UnitCode);

public sealed record ProjectPackageUpsertRequest(
    long ProjectId,
    string PackageCode,
    string PackageNameTh,
    string? PackageNameEn,
    string TierCode,
    string BillingCycle,
    decimal Price,
    string CurrencyCode,
    int TrialDays,
    int SortOrder,
    bool IsActive,
    List<ProjectPackageFeatureInput> Features,
    List<ProjectPackageQuotaInput> Quotas);

public sealed record CompanySubscriptionUpdateRequest(
    long PackageId,
    string StatusCode,
    DateOnly StartDate,
    DateOnly? ExpireDate,
    string? Reason);
