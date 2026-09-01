namespace Laoo.Shared.Contracts.Branches;

public enum BranchOwnerScope
{
    Support,
    Partner,
    Company,
}

public sealed record BranchScreenContract(
    BranchOwnerScope Scope,
    string MenuCode,
    string RouteName,
    int ScreenType,
    string? LegacyPermissionCode = null);

public static class BranchScreenContracts
{
    public static readonly BranchScreenContract Support =
        new(BranchOwnerScope.Support, "01003", "branch", 1, "BRANCH");

    public static readonly BranchScreenContract Partner =
        new(BranchOwnerScope.Partner, "06002", "partnerBranches", 1, "PARTNER_BRANCH");

    public static readonly BranchScreenContract Company =
        new(BranchOwnerScope.Company, "09002", "companyBranches", 1);

    public static BranchScreenContract FromRequestPath(string? path)
    {
        if (path?.Contains("/api/company/", StringComparison.OrdinalIgnoreCase) == true)
            return Company;
        if (path?.Contains("/api/partner/", StringComparison.OrdinalIgnoreCase) == true)
            return Partner;
        return Support;
    }
}

public sealed record BranchRequest(
    long CompanyId,
    string BranchCode,
    string BranchNameTh,
    string? BranchNameEn,
    string? Email,
    string? Telephone,
    string? AddressText,
    string? ContName,
    string? ContPhone,
    string? ContPositionName,
    bool IsActive = true);
