namespace LaooApi.Models;

public sealed class RoleGroupResponse
{
    public long RoleGroupId { get; init; }
    public string Scope { get; init; } = string.Empty;
    public string RoleCode { get; init; } = string.Empty;
    public string RoleNameTh { get; init; } = string.Empty;
    public string? Description { get; init; }
    public bool IsActive { get; init; }
}

public sealed class RoleGroupUpsertRequest
{
    public string RoleCode { get; init; } = string.Empty;
    public string RoleNameTh { get; init; } = string.Empty;
    public string? Description { get; init; }
    public bool IsActive { get; init; } = true;
}
