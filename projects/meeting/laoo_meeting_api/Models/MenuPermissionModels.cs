namespace LaooMeetingApi.Models;

public sealed class MenuPermissionMatrixResponse
{
    public string MenuCode { get; init; } = string.Empty;
    public string MenuName { get; init; } = string.Empty;
    public string MenuGroupCode { get; init; } = string.Empty;
    public string MenuGroupName { get; init; } = string.Empty;
    public int ScreenType { get; init; }
    public bool CanView { get; init; }
    public bool CanCreate { get; init; }
    public bool CanEdit { get; init; }
    public bool CanDelete { get; init; }
}

public sealed class MenuPermissionSaveRequest
{
    public string MenuCode { get; init; } = string.Empty;
    public bool CanView { get; init; }
    public bool CanCreate { get; init; }
    public bool CanEdit { get; init; }
    public bool CanDelete { get; init; }
}
