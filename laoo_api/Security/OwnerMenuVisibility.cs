namespace LaooApi.Security;

internal static class OwnerMenuVisibility
{
    private static readonly HashSet<string> HiddenForLaooAndPartner =
        new(StringComparer.OrdinalIgnoreCase) { "05002", "05003", "01005" };

    public static bool IsHidden(string? userType, string? menuCode, string? menuGroupCode = null) =>
        (string.Equals(userType, "PARTNER_USER", StringComparison.OrdinalIgnoreCase)
         && string.Equals(menuGroupCode?.Trim(), "11", StringComparison.OrdinalIgnoreCase))
        || ((string.Equals(userType, "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase)
         || string.Equals(userType, "PARTNER_USER", StringComparison.OrdinalIgnoreCase))
        && HiddenForLaooAndPartner.Contains(menuCode?.Trim() ?? string.Empty));
}
