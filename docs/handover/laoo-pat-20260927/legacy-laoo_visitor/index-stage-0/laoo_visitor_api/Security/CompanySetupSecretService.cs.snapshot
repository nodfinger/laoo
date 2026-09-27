using Microsoft.AspNetCore.DataProtection;

namespace LaooMeetingApi.Security;

public sealed class CompanySetupSecretService
{
    private const string ProtectorPurpose = "Laoo.CompanySetup.EmailPasswordCenter.v1";
    private readonly IDataProtector _protector;

    public CompanySetupSecretService(IDataProtectionProvider provider)
    {
        _protector = provider.CreateProtector(ProtectorPurpose);
    }

    public string? Protect(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : _protector.Protect(value.Trim());

    public string? Unprotect(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        try { return _protector.Unprotect(value); }
        catch (Exception) { return null; }
    }
}
