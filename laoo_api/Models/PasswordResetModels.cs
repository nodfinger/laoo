namespace LaooApi.Models;

public sealed record PasswordResetRequest(string Username, string? ProjectCode);
public sealed record PasswordResetConfirmRequest(string Token, string NewPassword);
