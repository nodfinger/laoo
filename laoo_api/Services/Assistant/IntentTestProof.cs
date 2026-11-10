using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;

namespace LaooApi.Services.Assistant;

public sealed record IntentTestProof(long CompanyId, long UserId, string Text, string[] Codes, DateTime ExpiresAt);

public static class IntentTestProofs
{
    public static string[]? ValidateExpected(IEnumerable<string>? requested, IEnumerable<string> eligible)
    {
        var codes = requested?.Distinct(StringComparer.Ordinal).ToArray() ?? [];
        var permitted = eligible.ToHashSet(StringComparer.Ordinal);
        return codes.Length <= 50 && codes.All(code => !string.IsNullOrWhiteSpace(code) && permitted.Contains(code)) ? codes : null;
    }
    private const string Purpose = "Laoo.Assistant.IntentTestApproval.v1";
    public static string Create(IDataProtectionProvider provider, long company, long user, string text, string[] codes) =>
        provider.CreateProtector(Purpose).Protect(JsonSerializer.Serialize(new IntentTestProof(company, user, text, codes, DateTime.UtcNow.AddMinutes(10))));

    public static IntentTestProof? Read(IDataProtectionProvider provider, string? token)
    {
        if (string.IsNullOrWhiteSpace(token) || token.Length > 10000) return null;
        try
        {
            var proof = JsonSerializer.Deserialize<IntentTestProof>(provider.CreateProtector(Purpose).Unprotect(token));
            return proof is not null && proof.ExpiresAt > DateTime.UtcNow ? proof : null;
        }
        catch (Exception ex) when (ex is System.Security.Cryptography.CryptographicException or JsonException or FormatException or ArgumentException) { return null; }
    }
}
