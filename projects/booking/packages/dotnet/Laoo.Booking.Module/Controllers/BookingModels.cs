namespace Laoo.Booking.Controllers;
public sealed record CreateBookingRequest(long? MemberId, string? GuestName, string? GuestPhone, long? BranchId, DateTimeOffset StartsAt, DateTimeOffset EndsAt, IReadOnlyList<BookingServiceRequest> Services, string? Note);
public sealed record BookingServiceRequest(long ServiceId, long? ProviderId, long? ResourceId);
internal sealed record BookingPrice(BookingServiceRequest Item, decimal Price, decimal Discount, long? PromotionId)
{
    public decimal Net => Price - Discount;
}
public sealed record CreateMemberRequest(long PersonId, string MemberCode, string TierCode, DateOnly StartsOn, DateOnly? ExpiresOn);
public sealed record CreateServiceRequest(string ServiceCode, string ServiceName, int DurationMinutes, decimal Price, bool RequiresProvider, bool RequiresResource);
public sealed record UpdateServiceRequest(string ServiceName, int DurationMinutes, decimal Price, bool RequiresProvider, bool RequiresResource);
public sealed record CreateProviderRequest(long PersonId);
public sealed record CreateResourceRequest(long? BranchId, string ResourceName, string ResourceType);
public sealed record UpdateResourceRequest(long? BranchId, string ResourceName, string ResourceType, bool IsActive);
public sealed record UpdateMemberRequest(string TierCode, DateOnly StartsOn, DateOnly? ExpiresOn, bool IsActive);
