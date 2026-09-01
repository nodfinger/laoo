namespace Laoo.Shared.Contracts.Organizations;

public enum OrganizationOwnerScope
{
    Support,
    Partner,
    Company,
}

public sealed record OrganizationScreenContract(
    OrganizationOwnerScope Scope,
    string MenuCode,
    string RouteName,
    int ScreenType,
    string? LegacyPermissionCode = null);

public static class OrganizationScreenContracts
{
    public static readonly OrganizationScreenContract Support =
        new(OrganizationOwnerScope.Support, "12005", "organizationStructure", 1, "ORGANIZATION_STRUCTURE");

    public static readonly OrganizationScreenContract Partner =
        new(OrganizationOwnerScope.Partner, "11005", "organizationStructure", 1, "ORGANIZATION_STRUCTURE");

    public static readonly OrganizationScreenContract Company =
        new(OrganizationOwnerScope.Company, "10005", "organizationStructure", 1, "ORGANIZATION_STRUCTURE");

    public static OrganizationScreenContract FromRequestPath(string? path)
    {
        if (path?.Contains("/api/company/", StringComparison.OrdinalIgnoreCase) == true)
            return Company;
        if (path?.Contains("/api/partner/", StringComparison.OrdinalIgnoreCase) == true)
            return Partner;
        return Support;
    }
}

public sealed record OrganizationUnitRequest(
    long? CompanyId,
    string UnitType,
    long? ParentOrgUnitId,
    string UnitCode,
    string NameTh,
    string? NameEn,
    bool IsActive = true);

public sealed record OrganizationModeRequest(long? CompanyId, int OrgStructureType);
