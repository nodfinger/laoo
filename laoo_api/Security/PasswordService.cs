using Microsoft.AspNetCore.Identity;

namespace LaooApi.Security;

public sealed class PasswordService
{
    private readonly PasswordHasher<PasswordIdentity> _hasher = new();

    public string HashPassword(string username, string password)
    {
        var identity = new PasswordIdentity(NormalizeUsername(username));
        return _hasher.HashPassword(identity, NormalizePassword(password));
    }

    public bool VerifyPassword(
        string username,
        string passwordHash,
        string suppliedPassword)
    {
        var identity = new PasswordIdentity(NormalizeUsername(username));

        var normalizedResult = _hasher.VerifyHashedPassword(
            identity,
            passwordHash,
            NormalizePassword(suppliedPassword));

        if (IsSuccessful(normalizedResult)) return true;

        // Keep existing hashes usable until the user changes their password.
        var legacyResult = _hasher.VerifyHashedPassword(
            identity,
            passwordHash,
            suppliedPassword);
        return IsSuccessful(legacyResult);
    }

    private static string NormalizeUsername(string value) => value.Trim().ToUpperInvariant();

    private static string NormalizePassword(string value) => value.ToUpperInvariant();

    private static bool IsSuccessful(PasswordVerificationResult result) =>
        result is PasswordVerificationResult.Success
            or PasswordVerificationResult.SuccessRehashNeeded;

    private sealed record PasswordIdentity(string Username);
}
