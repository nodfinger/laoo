using Microsoft.AspNetCore.Identity;
using System.Data;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Security;

public sealed class PasswordService
{
    public const int DefaultPolicyCode = 3;
    public const int MinimumPasswordLength = 12;
    public const string PolicyMessage =
        "Password เธ•เนเธญเธเธกเธตเธญเธขเนเธฒเธเธเนเธญเธข 12 เธ•เธฑเธง เนเธฅเธฐเธกเธตเธ•เธฑเธงเธเธดเธกเธเนเนเธซเธเน เธ•เธฑเธงเธเธดเธกเธเนเน€เธฅเนเธ เธ•เธฑเธงเน€เธฅเธ เนเธฅเธฐเธญเธฑเธเธเธฃเธฐเธเธดเน€เธจเธฉ เนเธ”เธขเธ•เนเธญเธเนเธกเนเน€เธซเธกเธทเธญเธ Username";

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

    public static string GetPartnerPolicyMessage(int policyCode) =>
        NormalizePolicyCode(policyCode) switch
        {
            1 => "รหัสผ่านต้องมีอย่างน้อย 1 ตัวอักษร",
            2 => "รหัสผ่านต้องมีอย่างน้อย 4 ตัวอักษร",
            _ => "รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร พร้อมตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก และอักขระพิเศษ",
        };

    public static bool MeetsPolicy(string username, string password, int policyCode = DefaultPolicyCode) =>
        !string.IsNullOrWhiteSpace(password) &&
        password.Length >= MinimumLength(policyCode) &&
        (policyCode == 1 || policyCode == 2 ||
         (password.Any(char.IsUpper) && password.Any(char.IsLower) && password.Any(character => !char.IsLetterOrDigit(character)))) &&
        (policyCode == 1 || !string.Equals(password, username, StringComparison.OrdinalIgnoreCase));

    public static int NormalizePolicyCode(int value) => value is 1 or 2 or 3 ? value : DefaultPolicyCode;

    public static int MinimumLength(int policyCode) => NormalizePolicyCode(policyCode) switch
    {
        1 => 1,
        2 => 4,
        _ => 6
    };

    public static string GetReadablePolicyMessage(int policyCode) =>
        NormalizePolicyCode(policyCode) switch
        {
            1 => "Password ต้องมีอย่างน้อย 1 ตัวอักษร",
            2 => "Password ต้องมีอย่างน้อย 4 ตัวอักษร",
            _ => "Password ต้องมีอย่างน้อย 6 ตัวอักษร พร้อมตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก และอักขระพิเศษ"
        };

    public static string GetReadablePartnerPolicyMessage(int policyCode) =>
        NormalizePolicyCode(policyCode) switch
        {
            1 => "รหัสผ่าน Partner ต้องมีอย่างน้อย 1 ตัวอักษร",
            2 => "รหัสผ่าน Partner ต้องมีอย่างน้อย 4 ตัวอักษร",
            _ => "รหัสผ่าน Partner ต้องมีอย่างน้อย 6 ตัวอักษร พร้อมตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก และอักขระพิเศษ"
        };

    public static string GetPolicyMessage(int policyCode) => NormalizePolicyCode(policyCode) switch
    {
        1 => "Password เธ•เนเธญเธเธกเธตเธญเธขเนเธฒเธเธเนเธญเธข 1 เธ•เธฑเธงเธญเธฑเธเธฉเธฃ",
        2 => "Password เธ•เนเธญเธเธกเธตเธญเธขเนเธฒเธเธเนเธญเธข 4 เธ•เธฑเธงเธญเธฑเธเธฉเธฃ",
        _ => "Password เธ•เนเธญเธเธกเธตเธญเธขเนเธฒเธเธเนเธญเธข 6 เธ•เธฑเธง เธเธฃเนเธญเธกเธ•เธฑเธงเธเธดเธกเธเนเนเธซเธเน เธ•เธฑเธงเธเธดเธกเธเนเน€เธฅเนเธ เนเธฅเธฐเธญเธฑเธเธเธฃเธฐเธเธดเน€เธจเธฉ"
    };

    public async Task<int> GetPolicyAsync(
        SqlConnection connection,
        string ownerType,
        long? partnerId,
        long? companyId,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
SELECT COALESCE((SELECT TOP (1) PasswordPolicyCode FROM dbo.TDSTCompanySetUp WHERE OwnerType=@OwnerType AND ((@OwnerType='L' AND PartnerID IS NULL AND CompanyID IS NULL) OR (@OwnerType='P' AND PartnerID=@PartnerID AND CompanyID IS NULL) OR (@OwnerType='C' AND CompanyID=@CompanyID))), @DefaultPolicy);
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@OwnerType", SqlDbType.Char, 1).Value = ownerType;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId ?? (object)DBNull.Value;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId ?? (object)DBNull.Value;
        command.Parameters.Add("@DefaultPolicy", SqlDbType.TinyInt).Value = DefaultPolicyCode;
        return NormalizePolicyCode(Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken)));
    }

    public async Task<int> GetPolicyForAccountAsync(
        SqlConnection connection,
        string userType,
        long subjectId,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
SELECT COALESCE(
    CASE @UserType
        WHEN 'COMPANY_USER' THEN (SELECT TOP (1) S.PasswordPolicyCode FROM dbo.TDADUser U INNER JOIN dbo.TDSTCompanySetUp S ON S.OwnerType='C' AND S.CompanyID=U.CompanyID WHERE U.UserID=@SubjectID)
        WHEN 'PARTNER_USER' THEN (SELECT TOP (1) S.PasswordPolicyCode FROM dbo.TDADPartnerUser U INNER JOIN dbo.TDSTCompanySetUp S ON S.OwnerType='P' AND S.PartnerID=U.PartnerID WHERE U.PartnerUserID=@SubjectID)
        WHEN 'LAOO_SUPPORT' THEN (SELECT TOP (1) S.PasswordPolicyCode FROM dbo.TDSTCompanySetUp S WHERE S.OwnerType='L' AND S.PartnerID IS NULL AND S.CompanyID IS NULL)
    END, @DefaultPolicy);
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@UserType", SqlDbType.NVarChar, 30).Value = userType;
        command.Parameters.Add("@SubjectID", SqlDbType.BigInt).Value = subjectId;
        command.Parameters.Add("@DefaultPolicy", SqlDbType.TinyInt).Value = DefaultPolicyCode;
        return NormalizePolicyCode(Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken)));
    }

    private static string NormalizeUsername(string value) => value.Trim().ToUpperInvariant();

    private static string NormalizeLegacyPassword(string value) =>
        value.ToUpperInvariant();

    private static bool IsSuccessful(PasswordVerificationResult result) =>
        result is PasswordVerificationResult.Success
            or PasswordVerificationResult.SuccessRehashNeeded;

    private sealed record PasswordIdentity(string Username);
}
