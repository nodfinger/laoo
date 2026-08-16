using Microsoft.AspNetCore.Identity;

namespace LaooApi.Security;

public sealed class PasswordService
{
    public const int MinimumPasswordLength = 12;
    public const string PolicyMessage =
        "Password ต้องมีอย่างน้อย 12 ตัว และมีตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก ตัวเลข และอักขระพิเศษ โดยต้องไม่เหมือน Username";

    private readonly PasswordHasher<PasswordIdentity> _hasher = new();

    public string HashPassword(string username, string password)
    {
        var identity = new PasswordIdentity(NormalizeUsername(username));
        return _hasher.HashPassword(identity, password);
    }

    public bool VerifyPassword(
        string username,
        string passwordHash,
        string suppliedPassword)
    {
        var identity = new PasswordIdentity(NormalizeUsername(username));

        var exactResult = _hasher.VerifyHashedPassword(
            identity,
            passwordHash,
            suppliedPassword);

        if (IsSuccessful(exactResult)) return true;

        // Compatibility for hashes created before passwords became
        // case-sensitive. New and changed passwords are always hashed exactly.
        var legacyResult = _hasher.VerifyHashedPassword(
            identity,
            passwordHash,
            NormalizeLegacyPassword(suppliedPassword));
        return IsSuccessful(legacyResult);
    }

    public static bool MeetsPolicy(string username, string password) =>
        !string.IsNullOrWhiteSpace(password) &&
        password.Length >= MinimumPasswordLength &&
        !string.Equals(password, username, StringComparison.OrdinalIgnoreCase) &&
        password.Any(char.IsUpper) &&
        password.Any(char.IsLower) &&
        password.Any(char.IsDigit) &&
        password.Any(character => !char.IsLetterOrDigit(character));

    private static string NormalizeUsername(string value) => value.Trim().ToUpperInvariant();

    private static string NormalizeLegacyPassword(string value) =>
        value.ToUpperInvariant();

    private static bool IsSuccessful(PasswordVerificationResult result) =>
        result is PasswordVerificationResult.Success
            or PasswordVerificationResult.SuccessRehashNeeded;

    private sealed record PasswordIdentity(string Username);
}
