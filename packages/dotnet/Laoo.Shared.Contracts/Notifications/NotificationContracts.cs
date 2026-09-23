namespace Laoo.Shared.Contracts.Notifications;

public sealed record NotificationCreateRequest(
    long CompanyId,
    long? RecipientUserId,
    string SourceProject,
    string SourceType,
    long? SourceId,
    string Title,
    string Message,
    string? PayloadJson,
    string IdempotencyKey);

public sealed record NotificationPreferenceResponse(
    long CompanyId,
    long PersonId,
    long? UserId,
    bool NotifyInSystem,
    bool CanReceive);

public sealed record NotificationPreferenceUpdateRequest(long PersonId, bool NotifyInSystem);
