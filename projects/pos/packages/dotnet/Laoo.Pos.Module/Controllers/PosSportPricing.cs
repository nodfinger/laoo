using Microsoft.Data.SqlClient;

namespace LaooPosModule.Controllers;

public sealed partial class PosController
{
    private sealed record SportPriceContext(long MemberID,long LevelID,string? PriceLevelCode);

    private static async Task<SportPriceContext?> ResolveSportPrice(
        SqlConnection connection, SqlTransaction? transaction, long company,
        long member, CancellationToken cancellation)
    {
        const string sql = """
SELECT TOP(1) M.MemberID,M.LevelID,R.PriceLevelCode
FROM dbo.TDSPMember M
JOIN dbo.TDADPerson Person ON Person.CompanyID=M.CompanyID AND Person.PersonID=M.PersonID AND Person.IsActive=1
JOIN dbo.TDSPMemberLevel L ON L.CompanyID=M.CompanyID AND L.LevelID=M.LevelID AND L.IsActive=1
JOIN dbo.TDSPMembership E ON E.CompanyID=M.CompanyID AND E.MemberID=M.MemberID
 AND E.StatusCode=N'ACTIVE' AND E.StartsOn<=CONVERT(date,SYSUTCDATETIME())
 AND E.EndsOn>=CONVERT(date,SYSUTCDATETIME())
JOIN dbo.TDADCompanyProjectSubscription S ON S.CompanyID=M.CompanyID AND S.IsCurrent=1
 AND S.StatusCode IN(N'ACTIVE',N'TRIAL') AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
 AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_SPORT' AND P.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
LEFT JOIN dbo.TDSPPosPriceRule R ON R.CompanyID=M.CompanyID AND R.LevelID=M.LevelID AND R.IsActive=1
WHERE M.CompanyID=@co AND M.MemberID=@member AND M.IsActive=1
ORDER BY E.EndsOn DESC
""";
        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("@co", company);
        command.Parameters.AddWithValue("@member", member);
        await using var reader = await command.ExecuteReaderAsync(cancellation);
        return await reader.ReadAsync(cancellation)
            ? new SportPriceContext(reader.GetInt64(0), reader.GetInt64(1),
                reader.IsDBNull(2) ? null : reader.GetString(2))
            : null;
    }

    [Microsoft.AspNetCore.Mvc.HttpGet("sport-members/{code}")]
    public async Task<Microsoft.AspNetCore.Mvc.IActionResult> FindSportMember(
        string code, CancellationToken cancellation)
    {
        if (string.IsNullOrWhiteSpace(code) || code.Length > 30)
            return Bad("รหัสสมาชิกไม่ถูกต้อง", "กรอกรหัสสมาชิกไม่เกิน 30 ตัวอักษร");
        if (!Scope(out var company, out _)) return Forbid();
        await using var db = await Open(cancellation);
        if (!await Can(db, "46004", "VIEW", cancellation)) return Forbid();
        await using var command = new SqlCommand("""
SELECT TOP(1) M.MemberID,P.FullName,M.MemberCode,L.LevelName
FROM dbo.TDSPMember M
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID AND P.IsActive=1
JOIN dbo.TDSPMemberLevel L ON L.CompanyID=M.CompanyID AND L.LevelID=M.LevelID
WHERE M.CompanyID=@co AND M.MemberCode=@code AND M.IsActive=1
""", db);
        command.Parameters.AddWithValue("@co", company);
        command.Parameters.AddWithValue("@code", code.Trim().ToUpperInvariant());
        await using var reader = await command.ExecuteReaderAsync(cancellation);
        if (!await reader.ReadAsync(cancellation))
            return NotFound(new { message = "ไม่พบสมาชิก", description = "ตรวจรหัสสมาชิกแล้วลองใหม่" });
        var member = reader.GetInt64(0);
        var name = reader.GetString(1);
        var number = reader.GetString(2);
        var level = reader.GetString(3);
        await reader.CloseAsync();
        var price = await ResolveSportPrice(db, null, company, member, cancellation);
        return price is null
            ? Conflict(new { message = "สมาชิกยังใช้ราคาพิเศษไม่ได้",
                description = "ตรวจแพ็กเกจสมาชิกและการเปิดใช้งานระบบกีฬา" })
            : Ok(new { id = member, code = number, name, level,
                priceLevel = price.PriceLevelCode });
    }
}
