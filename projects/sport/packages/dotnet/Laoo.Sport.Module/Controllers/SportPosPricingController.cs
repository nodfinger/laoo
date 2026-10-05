using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpGet("pos-pricing")]
    public async Task<IActionResult> PosPricing(CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54010", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT L.LevelID levelId,L.LevelName level,R.PriceLevelCode priceLevel,
 COALESCE(R.IsActive,0) active
FROM dbo.TDSPMemberLevel L
LEFT JOIN dbo.TDSPPosPriceRule R ON R.CompanyID=L.CompanyID AND R.LevelID=L.LevelID
WHERE L.CompanyID=@co ORDER BY L.LevelName
""", ct, ("@co", Company)));
    }

    [HttpPut("pos-pricing/{levelId:long}")]
    public async Task<IActionResult> PutPosPricing(long levelId, SportPosPricingInput input, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(input.PriceLevelCode) || input.PriceLevelCode.Length > 30)
            return Invalid("ระบุรหัสระดับราคาสินค้าที่ไม่เกิน 30 ตัวอักษร");
        await using var db = await Open(ct);
        if (await Guard(db, "54010", "EDIT", ct) is { } denied) return denied;
        var valid = await SportDb.Id(db, null, """
SELECT COUNT(*) FROM dbo.TDSPMemberLevel
WHERE CompanyID=@co AND LevelID=@level AND IsActive=1
""", ct, ("@co", Company), ("@level", levelId));
        var available = await SportDb.Id(db, null, """
SELECT COUNT(*) FROM dbo.TDIVItemPriceLevel
WHERE CompanyID=@co AND PriceLevelCode=@code
""", ct, ("@co", Company), ("@code", input.PriceLevelCode.Trim().ToUpperInvariant()));
        if (valid != 1 || available == 0)
            return Conflict(new { message = "กำหนดกฎราคาไม่ได้",
                description = "ตรวจระดับสมาชิกและ Price Level ของสินค้าในบริษัทนี้" });
        await SportDb.Execute(db, null, """
MERGE dbo.TDSPPosPriceRule WITH(HOLDLOCK) AS T
USING(SELECT @co CompanyID,@level LevelID) AS S
 ON T.CompanyID=S.CompanyID AND T.LevelID=S.LevelID
WHEN MATCHED THEN UPDATE SET PriceLevelCode=@code,IsActive=@active,UpdatedAt=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(CompanyID,LevelID,PriceLevelCode,IsActive)
 VALUES(@co,@level,@code,@active);
""", ct, ("@co", Company), ("@level", levelId),
            ("@code", input.PriceLevelCode.Trim().ToUpperInvariant()),
            ("@active", input.Active));
        return Ok(new { saved = true });
    }
}

public sealed record SportPosPricingInput(string PriceLevelCode,bool Active = true);
