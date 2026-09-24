namespace Laoo.Shared.Contracts.Visitors;

public sealed record TenantContactIdentity(long TenantContactId, long TenantId);

public sealed record HostIdentityResponse(
    IReadOnlyList<long> EmployeeIds,
    IReadOnlyList<long> ResidentIds,
    IReadOnlyList<long> ServiceCustomerIds,
    IReadOnlyList<long> TenantContactIds,
    IReadOnlyList<TenantContactIdentity> TenantContacts)
{
    public static HostIdentityResponse Empty { get; } = new(
        Array.Empty<long>(),
        Array.Empty<long>(),
        Array.Empty<long>(),
        Array.Empty<long>(),
        Array.Empty<TenantContactIdentity>());
}
