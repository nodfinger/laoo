using Microsoft.AspNetCore.Identity;

namespace LaooApi.Security;

public sealed class PasswordService
{
    private readonly PasswordHasher<PasswordIdentity> _hasher = new();

    public string HashPassword(string username, string password)
    {
        var identity = new PasswordIdentity(username);
        return _hasher.HashPassword(identity, password);
    }

    public bool VerifyPassword(
        string username,
        string passwordHash,
        string suppliedPassword)
    {
        var identity = new PasswordIdentity(username);

        var result = _hasher.VerifyHashedPassword(
            identity,
            passwordHash,
            suppliedPassword);

        return result is PasswordVerificationResult.Success
            or PasswordVerificationResult.SuccessRehashNeeded;
    }

    private sealed record PasswordIdentity(string Username);
}
