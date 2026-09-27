namespace LaooMeetingApi.Models.Navigation;

public sealed class NavigationMenuGroupResponse
{
    public string MenuGroupCode { get; init; } = string.Empty;
    public string MenuGroupName { get; init; } = string.Empty;
    public string? IconName { get; init; }
    public int SortOrder { get; init; }
    public bool IsExpandedDefault { get; init; }
    public List<NavigationMenuItemResponse> Items { get; init; } = [];
}

public sealed class NavigationMenuItemResponse
{
    public string MenuCode { get; init; } = string.Empty;
    public string MenuName { get; init; } = string.Empty;
    public string? RouteName { get; init; }
    public string? RoutePath { get; init; }
    public string? FeatureCode { get; init; }
    public string? IconName { get; init; }
    public int SortOrder { get; init; }
    public bool IsFavoriteAllowed { get; init; }
}
