using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;

namespace LaooApi.Services.Assistant;

/// <summary>Checks the compiled allowlist, Company setting, menu mapping and current user permissions.</summary>
public static class AssistantCapabilityAccess
{
    public static async Task<bool> IsAllowed(SqlConnection db, ClaimsPrincipal user, string code, CancellationToken token)
    {
        var capability = AssistantCapabilities.Find(code);
        var companyId = AiChatSettingsStore.CompanyId(user);
        if (capability is null || companyId is null || !await AiChatSettingsStore.IsEnabledAsync(db, user, token)) return false;
        // Keep the existing chat usable until the registry migration has been deployed.
        await using var schema = new SqlCommand("SELECT CASE WHEN OBJECT_ID(N'dbo.TDADAiCapability',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.TDADAiCapabilityCompany',N'U') IS NOT NULL THEN 1 ELSE 0 END", db);
        if (Convert.ToInt32(await schema.ExecuteScalarAsync(token)) == 0)
            return code is "repair.track_own" or "repair.create_own" && await CanUseMenu(db, user, capability, token);
        await using var setting = new SqlCommand("""
SELECT CASE WHEN EXISTS(
 SELECT 1 FROM dbo.TDADAiCapability C
 JOIN dbo.TDADAiCapabilityCompany CC ON CC.CapabilityCode=C.CapabilityCode AND CC.CompanyID=@company
 WHERE C.CapabilityCode=@code AND C.IsActive=1 AND CC.IsEnabled=1
) THEN 1 ELSE 0 END
""", db);
        setting.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId.Value;
        setting.Parameters.Add("@code", SqlDbType.NVarChar,100).Value = code;
        if (Convert.ToInt32(await setting.ExecuteScalarAsync(token)) != 1) return false;
        if (!await AiCapabilityRoleAccess.CanUse(db, user, code, token)) return false;
        if (await CanUseMenu(db, user, capability, token)) return true;
        if (code == AssistantCapabilities.SerialRepairHistory.Id && await CanUseMenu(db, user, capability with { MenuCode = "20002" }, token)) return true;
        return (code == AssistantCapabilities.RepairPartsCost.Id || code == AssistantCapabilities.SerialRepairHistory.Id) &&
            await CanUseMenu(db, user, capability with { MenuCode = "20003" }, token);
    }

    public static async Task<bool> CanUseMenu(SqlConnection db, ClaimsPrincipal user, AssistantCapability capability, CancellationToken token)
    {
        await using var query = new SqlCommand("""
SELECT COUNT_BIG(*) FROM dbo.TDADProjectMenu PM
JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.IsActive=1
JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode AND M.IsActive=1 AND M.IsVisible=1
WHERE P.ProjectCode=@project AND PM.IsActive=1 AND M.MenuCode=@menu AND M.ScreenType=@screenType
""", db);
        query.Parameters.Add("@project", SqlDbType.NVarChar,50).Value=capability.ProjectCode;
        query.Parameters.Add("@menu", SqlDbType.VarChar,20).Value=capability.MenuCode;
        query.Parameters.Add("@screenType", SqlDbType.Int).Value=capability.ScreenType;
        if (Convert.ToInt64(await query.ExecuteScalarAsync(token)) == 0) return false;
        return await CompanyMenuAccess.IsAllowedForProjectAsync(db,user,capability.ProjectCode,capability.MenuCode,capability.Action,token);
    }
}
