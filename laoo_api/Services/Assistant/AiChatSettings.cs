using System.Data;
using System.Security.Claims;
using Microsoft.Data.SqlClient;

namespace LaooApi.Services.Assistant;

public sealed class AiChatSettings
{
    public bool Enabled { get; set; }
    public string Name { get; set; } = "ผู้ช่วย AI";
    public string Pronoun { get; set; } = "ผม";
    public int GreetingMode { get; set; } = 1;
    public string MorningStart { get; set; } = "06:00";
    public string MorningEnd { get; set; } = "09:00";
    public string MorningText { get; set; } = "สวัสดีตอนเช้า";
    public string LateMorningStart { get; set; } = "09:00";
    public string LateMorningEnd { get; set; } = "12:00";
    public string LateMorningText { get; set; } = "สวัสดีตอนสาย";
    public string AfternoonStart { get; set; } = "12:00";
    public string AfternoonEnd { get; set; } = "17:00";
    public string AfternoonText { get; set; } = "สวัสดีตอนบ่าย";
    public string EveningStart { get; set; } = "17:00";
    public string EveningEnd { get; set; } = "21:00";
    public string EveningText { get; set; } = "สวัสดีตอนเย็น";
    public string NightStart { get; set; } = "";
    public string NightEnd { get; set; } = "";
    public string NightText { get; set; } = "";
    public bool ShowUserImage { get; set; }
    public bool ShowAiImage { get; set; }
    public string? ImagePath { get; set; }
    public string? Nickname { get; set; }
    public int? RetentionDays { get; set; }
}

public static class AiChatSettingsStore
{
    public static long? CompanyId(ClaimsPrincipal user) =>
        user.FindFirst("user_type")?.Value == "COMPANY_USER" &&
        long.TryParse(user.FindFirst("company_id")?.Value, out var id) ? id : null;

    public static async Task<bool> IsEnabledAsync(SqlConnection db, ClaimsPrincipal user, CancellationToken ct)
    {
        var companyId = CompanyId(user);
        if (companyId is null) return false;
        return await IsCompanyEnabledAsync(db, companyId.Value, ct);
    }

    private static async Task<bool> IsCompanyEnabledAsync(SqlConnection db, long companyId, CancellationToken ct)
    {
        await using var command = new SqlCommand("""
SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_AI' AND IsActive=1)
 THEN CASE WHEN EXISTS(SELECT 1 FROM dbo.TDSTCompanySetUp C
 JOIN dbo.TDADCompanyProjectSubscription S ON S.CompanyID=C.CompanyID AND S.PartnerID=C.PartnerID AND S.IsCurrent=1
 JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_AI' AND P.IsActive=1
 JOIN dbo.TDADProjectPackage PK ON PK.PackageID=S.PackageID AND PK.ProjectID=P.ProjectID AND PK.IsActive=1
 JOIN dbo.TDADProjectPackageFeature PF ON PF.PackageID=PK.PackageID AND PF.FeatureCode=N'AI_ASSISTANT' AND PF.IsEnabled=1
 WHERE C.CompanyID=@company AND C.OwnerType='C' AND C.IsActive=1 AND S.StatusCode IN(N'ACTIVE',N'TRIAL')
 AND S.StartDate<=CONVERT(date,SYSUTCDATETIME()) AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END
 ELSE COALESCE((SELECT TOP(1) CONVERT(int,AiChatEnabled) FROM dbo.TDSTCompanySetUp WHERE OwnerType='C' AND CompanyID=@company AND IsActive=1),0) END AS bit)
""", db);
        command.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId;
        return (await command.ExecuteScalarAsync(ct)) is bool enabled && enabled;
    }

    public static async Task<AiChatSettings?> ReadAsync(SqlConnection db, long companyId, long? userId, CancellationToken ct)
    {
        const string sql = """
SELECT AiChatEnabled,AiChatName,AiChatPronoun,AiChatGreetingMode,
CONVERT(varchar(5),AiChatMorningStart,108),CONVERT(varchar(5),AiChatMorningEnd,108),AiChatMorningText,
CONVERT(varchar(5),AiChatLateMorningStart,108),CONVERT(varchar(5),AiChatLateMorningEnd,108),AiChatLateMorningText,
CONVERT(varchar(5),AiChatAfternoonStart,108),CONVERT(varchar(5),AiChatAfternoonEnd,108),AiChatAfternoonText,
CONVERT(varchar(5),AiChatEveningStart,108),CONVERT(varchar(5),AiChatEveningEnd,108),AiChatEveningText,
AiChatShowUserImage,AiChatShowAiImage,AiChatImagePath,
(SELECT TOP(1) E.NickName FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=@company WHERE UE.UserID=@user AND UE.CompanyID=@company AND UE.IsActive=1 AND E.IsActive=1),
CONVERT(varchar(5),AiChatNightStart,108),CONVERT(varchar(5),AiChatNightEnd,108),AiChatNightText,AiChatRetentionDays
FROM dbo.TDSTCompanySetUp WHERE OwnerType='C' AND CompanyID=@company AND IsActive=1
""";
        await using var cmd = new SqlCommand(sql, db);
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId;
        cmd.Parameters.Add("@user", SqlDbType.BigInt).Value = (object?)userId ?? DBNull.Value;
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;
        var s = new AiChatSettings { Enabled = r.GetBoolean(0) };
        string S(int i, string fallback) => r.IsDBNull(i) ? fallback : r.GetString(i);
        s.Name=S(1,s.Name); s.Pronoun=S(2,s.Pronoun); s.GreetingMode=r.IsDBNull(3)?1:Convert.ToInt32(r.GetValue(3));
        s.MorningStart=S(4,s.MorningStart); s.MorningEnd=S(5,s.MorningEnd); s.MorningText=S(6,s.MorningText);
        s.LateMorningStart=S(7,s.LateMorningStart); s.LateMorningEnd=S(8,s.LateMorningEnd); s.LateMorningText=S(9,s.LateMorningText);
        s.AfternoonStart=S(10,s.AfternoonStart); s.AfternoonEnd=S(11,s.AfternoonEnd); s.AfternoonText=S(12,s.AfternoonText);
        s.EveningStart=S(13,s.EveningStart); s.EveningEnd=S(14,s.EveningEnd); s.EveningText=S(15,s.EveningText);
        s.ShowUserImage=!r.IsDBNull(16)&&r.GetBoolean(16); s.ShowAiImage=!r.IsDBNull(17)&&r.GetBoolean(17);
        s.ImagePath=r.IsDBNull(18)?null:r.GetString(18); s.Nickname=r.IsDBNull(19)?null:r.GetString(19);
        s.NightStart=S(20,""); s.NightEnd=S(21,""); s.NightText=S(22,"");
        s.RetentionDays = r.IsDBNull(23) ? 90 : r.GetInt32(23);
        await r.DisposeAsync();
        s.Enabled = await IsCompanyEnabledAsync(db, companyId, ct);
        return s;
    }
}
