namespace Laoo.Service.Api.Models;

public sealed record LoginRequest(
    string Username,
    string Password,
    string? ProjectCode);

public sealed record LoginResponse(
    bool Success,
    string Message,
    string? AccessToken,
    DateTime? ExpiresAt,
    LoginUserResponse? User);

public sealed record LoginUserResponse(
    string LoginMode,
    long? LaooUserId,
    long? UserId,
    long? CompanyId,
    long? BranchId,
    long ProjectId,
    string ProjectCode,
    string Username,
    string DisplayName,
    bool CanLoginAsUser,
    bool ShowSupportBanner);

public sealed record AuthenticatedUser(
    string SubjectId,
    string LoginMode,
    long? LaooUserId,
    long? UserId,
    long? CompanyId,
    long? BranchId,
    long ProjectId,
    string ProjectCode,
    string Username,
    string DisplayName,
    bool CanLoginAsUser);

public sealed record TokenResult(
    string AccessToken,
    DateTime ExpiresAt);
