namespace Laoo.Shared.Contracts.Visitors;

public sealed record BusinessLocationHostItem(
    string HostType,
    long EmployeeId,
    long? PersonId,
    string DisplayName,
    string? Phone,
    long? BranchId,
    string? BranchName);

public sealed record BusinessLocationHostResponse(
    string BusinessTypeCode,
    IReadOnlyList<BusinessLocationHostItem> Items);
