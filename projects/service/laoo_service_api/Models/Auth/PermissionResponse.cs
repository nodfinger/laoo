namespace LaooServiceApi.Models.Auth;

public sealed class PermissionResponse
{
    public string ProjectCode { get; init; } = string.Empty;
    public long ProjectId { get; init; }
    public string UserType { get; init; } = string.Empty;
    public List<PermissionScreenItem> Permissions { get; init; } = [];
}

public sealed class PermissionScreenItem
{
    public string ScreenCode { get; init; } = string.Empty;
    public string ScreenNameTh { get; init; } = string.Empty;
    public string? ScreenNameEn { get; init; }
    public bool CanView { get; init; }
    public List<string> Actions { get; init; } = [];
}

internal sealed class PermissionRow
{
    public string ScreenCode { get; init; } = string.Empty;
    public string ScreenNameTh { get; init; } = string.Empty;
    public string? ScreenNameEn { get; init; }
    public string ActionCode { get; init; } = string.Empty;
}
