using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    [HttpGet("options/{menu}")]
    public async Task<IActionResult> Options(string menu, CancellationToken ct)
    {
        if (menu is not ("60002" or "60003" or "60004" or "60005" or "60006" or "60007" or "60008" or "60009" or "60010"))
            return NotFound();

        await using var db = await Open(ct);
        if (await Guard(db, menu, "VIEW", ct) is { } denied) return denied;

        var branches = await RentalDb.Rows(db, null, """
SELECT B.BranchID id,B.BranchCode code,B.BranchNameTH name
FROM dbo.TDADBranch B
WHERE B.CompanyID=@co AND B.IsActive=1
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=B.BranchID AND UB.IsActive=1))
ORDER BY B.BranchCode
""", ct, ("@co", Company), ("@actor", Actor));

        List<Dictionary<string, object?>> items = [];
        if (menu == "60002")
            items = await RentalDb.Rows(db, null, """
SELECT TOP(500) I.ItemID id,I.ItemCode code,I.ItemName name
FROM dbo.TDIVItem I WHERE I.CompanyID=@co AND I.IsActive=1
ORDER BY I.ItemCode
""", ct, ("@co", Company));

        List<Dictionary<string, object?>> customers = [];
        if (menu == "60004")
            customers = await RentalDb.Rows(db, null, """
SELECT TOP(500) C.CustomerID id,C.CusCode code,C.CusName name
FROM dbo.TDARCustomer C WHERE C.CompanyID=@co AND C.IsActive=1
ORDER BY C.CusCode
""", ct, ("@co", Company));

        List<Dictionary<string, object?>> warehouses = [];
        if (menu == "60002")
            warehouses = await RentalDb.Rows(db, null, """
SELECT W.WarehouseID id,W.BranchID branchId,W.WarehouseCode code,W.WarehouseName name,
W.IsDefault isDefault,CAST(CASE WHEN W.WarehouseCode LIKE N'RENTAL-%' THEN 1 ELSE 0 END AS bit) isRental
FROM dbo.TDIVWarehouse W
WHERE W.CompanyID=@co AND W.IsActive=1
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co
 AND UB.UserID=@actor AND UB.BranchID=W.BranchID AND UB.IsActive=1))
ORDER BY W.BranchID,W.IsDefault DESC,W.WarehouseCode
""", ct, ("@co", Company), ("@actor", Actor));

        return Ok(new { branches, items, customers, warehouses });
    }
}
