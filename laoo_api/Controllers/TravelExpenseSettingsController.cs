using System.Data;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/travel-settings")]
public sealed class TravelExpenseSettingsController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");

    [HttpGet("position-levels")]
    public async Task<IActionResult> PositionLevels(CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "VIEW", token)) return Forbid();
        var canEdit = await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "EDIT", token);
        const string sql = """
SELECT m.MasterCode,m.Name,p.PositionLevelCode FROM dbo.TDSTMaster m
LEFT JOIN dbo.TDSTTravelPositionLevel p ON p.CompanyID=@company AND p.PositionCode=m.MasterCode
WHERE m.MasterGroupCode=N'008' AND m.OwnerType=N'C' AND ISNULL(m.OwnerPartnerID,0)=0 AND m.OwnerCompanyID=@company ORDER BY m.Seq,m.Name,m.MasterCode;
SELECT MasterCode,Name FROM dbo.TDSTMaster WHERE MasterGroupCode=N'016' AND OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company ORDER BY Seq,Name,MasterCode;
""";
        await using var q = new SqlCommand(sql, c);
        q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        await using var r = await q.ExecuteReaderAsync(token);
        var positions = new List<object>();
        while (await r.ReadAsync(token)) positions.Add(new { code = r.GetString(0), name = r.GetString(1), level = r.IsDBNull(2) ? null : r.GetString(2) });
        await r.NextResultAsync(token);
        var levels = new List<object>();
        while (await r.ReadAsync(token)) levels.Add(new { code = r.GetString(0), name = r.GetString(1) });
        return Ok(new { canEdit, positions, levels });
    }

    [HttpPut("position-levels")]
    public async Task<IActionResult> SavePositionLevels([FromBody] TravelPositionLevelsRequest request, CancellationToken token)
    {
        if (request.Items is null || request.Items.Any(x => string.IsNullOrWhiteSpace(x.Code) || x.Code.Length > 10 || x.Level?.Length > 10) ||
            request.Items.Select(x => x.Code).Distinct(StringComparer.OrdinalIgnoreCase).Count() != request.Items.Count)
            return BadRequest(new { message = "กรุณาตรวจสอบตำแหน่งงานและระดับตำแหน่ง" });
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            foreach (var item in request.Items)
            {
                const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'008' AND OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterCode=@code) THROW 54072,N'Invalid position',1;
IF @level IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'016' AND OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterCode=@level) THROW 54072,N'Invalid position level',1;
IF @level IS NULL DELETE dbo.TDSTTravelPositionLevel WHERE CompanyID=@company AND PositionCode=@code;
ELSE BEGIN
 UPDATE dbo.TDSTTravelPositionLevel SET PositionLevelCode=@level,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND PositionCode=@code;
 IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelPositionLevel(CompanyID,PositionCode,PositionLevelCode,UpdateBy) VALUES(@company,@code,@level,@user);
END;
""";
                await using var q = new SqlCommand(sql, c, tx);
                q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
                q.Parameters.Add("@user", SqlDbType.BigInt).Value = UserId;
                q.Parameters.Add("@code", SqlDbType.NVarChar, 10).Value = item.Code;
                q.Parameters.Add("@level", SqlDbType.NVarChar, 10).Value = string.IsNullOrWhiteSpace(item.Level) ? DBNull.Value : item.Level;
                await q.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return Ok(new { saved = true });
        }
        catch (SqlException ex) when (ex.Number == 54072)
        {
            await tx.RollbackAsync(token);
            return BadRequest(new { message = "ไม่พบตำแหน่งงานหรือระดับตำแหน่งของบริษัท กรุณาโหลดข้อมูลใหม่" });
        }
    }

    [HttpGet("lodging-rates")]
    public async Task<IActionResult> LodgingRates(CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "VIEW", token)) return Forbid();
        var canEdit = await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "EDIT", token);
        const string sql = """
SELECT m.MasterCode,m.Name,r.Amount FROM dbo.TDSTMaster m
LEFT JOIN dbo.TDSTTravelLodgingRate r ON r.CompanyID=@company AND r.PositionLevelCode=m.MasterCode
WHERE m.MasterGroupCode=N'016' AND m.OwnerType=N'C' AND ISNULL(m.OwnerPartnerID,0)=0 AND m.OwnerCompanyID=@company
ORDER BY m.Seq,m.Name,m.MasterCode;
""";
        await using var q = new SqlCommand(sql, c);
        q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        var items = new List<object>();
        await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
            items.Add(new { code = r.GetString(0), name = r.GetString(1), rate = r.IsDBNull(2) ? (decimal?)null : r.GetDecimal(2) });
        return Ok(new { canEdit, items });
    }

    [HttpPut("lodging-rates")]
    public async Task<IActionResult> SaveLodgingRates([FromBody] TravelRateRequest request, CancellationToken token)
    {
        if (request.Items is null || request.Items.Any(x => string.IsNullOrWhiteSpace(x.Code) || x.Code.Length > 10 ||
            (x.Rate is decimal rate && (rate < 0 || rate > 9999999999.99m || decimal.Round(rate, 2) != rate))) ||
            request.Items.Select(x => x.Code).Distinct(StringComparer.OrdinalIgnoreCase).Count() != request.Items.Count)
            return BadRequest(new { message = "กรุณาตรวจสอบอัตราค่าห้องพักให้เป็นตัวเลขไม่ติดลบและมีทศนิยมไม่เกิน 2 ตำแหน่ง" });
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        foreach (var item in request.Items)
        {
            const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'016' AND OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterCode=@code)
    THROW 54071,N'Invalid position level',1;
IF @rate IS NULL DELETE FROM dbo.TDSTTravelLodgingRate WHERE CompanyID=@company AND PositionLevelCode=@code;
ELSE BEGIN
 UPDATE dbo.TDSTTravelLodgingRate SET Amount=@rate,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND PositionLevelCode=@code;
 IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelLodgingRate(CompanyID,PositionLevelCode,Amount,UpdateBy) VALUES(@company,@code,@rate,@user);
END;
""";
            await using var q = new SqlCommand(sql, c, tx);
            q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
            q.Parameters.Add("@user", SqlDbType.BigInt).Value = UserId;
            q.Parameters.Add("@code", SqlDbType.NVarChar, 10).Value = item.Code;
            var p = q.Parameters.Add("@rate", SqlDbType.Decimal);
            p.Precision = 12; p.Scale = 2; p.Value = (object?)item.Rate ?? DBNull.Value;
            try { await q.ExecuteNonQueryAsync(token); }
            catch (SqlException ex) when (ex.Number == 54071)
            {
                await tx.RollbackAsync(token);
                return BadRequest(new { message = "ไม่พบระดับตำแหน่งงานของบริษัท กรุณาโหลดข้อมูลใหม่" });
            }
        }
        await tx.CommitAsync(token);
        return Ok(new { saved = true });
    }

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "VIEW", token)) return Forbid();
        var canEdit = await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "EDIT", token);
        const string sql = """
SELECT m.MasterCode,m.Name,r.RatePerKm FROM dbo.TDSTMaster m
LEFT JOIN dbo.TDSTTravelVehicleRate r ON r.CompanyID=@company AND r.VehicleTypeCode=m.MasterCode
WHERE m.MasterGroupCode=N'009' AND m.OwnerType=N'C' AND ISNULL(m.OwnerPartnerID,0)=0 AND m.OwnerCompanyID=@company
ORDER BY m.Seq,m.Name,m.MasterCode
""";
        await using var q = new SqlCommand(sql, c);
        q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        var rows = new List<object>();
        await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) rows.Add(new { code = r.GetString(0), name = r.GetString(1), rate = r.IsDBNull(2) ? (decimal?)null : r.GetDecimal(2) });
        return Ok(new { canEdit, items = rows });
    }

    [HttpPut]
    public async Task<IActionResult> Save([FromBody] TravelRateRequest request, CancellationToken token)
    {
        if (request.Items is null || request.Items.Any(x => string.IsNullOrWhiteSpace(x.Code) || x.Code.Length > 10 || (x.Rate is decimal rate && (rate < 0 || rate > 9999999999.99m || decimal.Round(rate, 2) != rate))) || request.Items.Select(x => x.Code).Distinct(StringComparer.OrdinalIgnoreCase).Count() != request.Items.Count)
            return BadRequest(new { message = "กรุณาตรวจสอบอัตราต่อกิโลเมตรให้เป็นตัวเลขไม่ติดลบและมีทศนิยมไม่เกิน 2 ตำแหน่ง" });
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        foreach (var item in request.Items)
        {
            const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'009' AND OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterCode=@code)
    THROW 54010,N'Invalid vehicle type',1;
IF @rate IS NULL DELETE FROM dbo.TDSTTravelVehicleRate WHERE CompanyID=@company AND VehicleTypeCode=@code;
ELSE BEGIN
 UPDATE dbo.TDSTTravelVehicleRate SET RatePerKm=@rate,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND VehicleTypeCode=@code;
 IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelVehicleRate(CompanyID,VehicleTypeCode,RatePerKm,UpdateBy) VALUES(@company,@code,@rate,@user);
END;
""";
            await using var q = new SqlCommand(sql, c, tx);
            q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
            q.Parameters.Add("@user", SqlDbType.BigInt).Value = UserId;
            q.Parameters.Add("@code", SqlDbType.NVarChar, 10).Value = item.Code;
            var p = q.Parameters.Add("@rate", SqlDbType.Decimal); p.Precision = 12; p.Scale = 2; p.Value = (object?)item.Rate ?? DBNull.Value;
            try { await q.ExecuteNonQueryAsync(token); }
            catch (SqlException ex) when (ex.Number == 54010) { return BadRequest(new { message = "ไม่พบประเภทรถของบริษัท กรุณาโหลดข้อมูลใหม่" }); }
        }
        await tx.CommitAsync(token);
        return Ok(new { saved = true });
    }
}

public sealed record TravelRateItem(string Code, decimal? Rate);
public sealed record TravelRateRequest(List<TravelRateItem> Items);
public sealed record TravelPositionLevelItem(string Code, string? Level);
public sealed record TravelPositionLevelsRequest(List<TravelPositionLevelItem> Items);
