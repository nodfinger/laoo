using System.Data;
using System.Security.Cryptography;
using LaooServiceModule.Infrastructure;
using LaooServiceModule.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;

[ApiController, Authorize]
[RequireCompanyProject("LAOO")]
[Route("api/company/employee-borrow")]
public sealed partial class EmployeeBorrowController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private long Company => InventoryControllerSupport.ClaimId(User, "company_id");
    private long UserId => InventoryControllerSupport.ClaimId(User, "user_id");
    private Task<SqlConnection> Open(CancellationToken token) => InventoryControllerSupport.OpenAsync(configuration, token);
    private Task<bool> Can(SqlConnection c, string menu, string action, CancellationToken token) =>
        InventoryControllerSupport.CanAsync(c, User, menu, action, token);
    private static void P(SqlCommand c, string name, SqlDbType type, object? value, int size = 0) =>
        InventoryControllerSupport.Add(c, name, type, value, size);
    private static IActionResult Invalid(string message, string detail) => new BadRequestObjectResult(new { message, description = detail });
    private static IActionResult Denied() => new ObjectResult(new { message = "ไม่มีสิทธิ์ดำเนินการ", description = "โปรดติดต่อผู้ดูแลเพื่อรับสิทธิ์ของเมนูนี้" }) { StatusCode = 403 };

    [HttpGet("actions/{menuCode}")]
    public async Task<IActionResult> Actions(string menuCode, CancellationToken token)
    {
        if (menuCode is not ("08008" or "08009" or "08010" or "08011")) return NotFound();
        await using var c = await Open(token);
        var result = new Dictionary<string, bool>();
        foreach (var action in new[] { "VIEW", "CREATE", "EDIT", "DELETE", "APPROVE", "REJECT", "ISSUE", "RETURN", "EXPORT" })
            result[action.ToLowerInvariant()] = await Can(c, menuCode, action, token);
        return Ok(result);
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "08008", "VIEW", token)) return Denied();
        var employees = new List<object>();
        await using (var cmd = new SqlCommand("SELECT EmployeeID,FullName FROM dbo.TDADEmployee WHERE CompanyID=@company AND IsActive=1 ORDER BY FullName", c))
        {
            P(cmd, "@company", SqlDbType.BigInt, Company);
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) employees.Add(new { employeeID = r.GetInt64(0), fullName = r.GetString(1) });
        }
        var warehouses = new List<object>();
        await using (var cmd = new SqlCommand($"SELECT W.WarehouseID,W.WarehouseName FROM dbo.TDIVWarehouse W INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE W.CompanyID=@company AND W.IsActive=1 AND {WarehouseAccessService.WarehouseAliasPredicate} ORDER BY W.WarehouseName", c))
        {
            P(cmd, "@company", SqlDbType.BigInt, Company); P(cmd, "@user", SqlDbType.BigInt, UserId);
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) warehouses.Add(new { warehouseID = r.GetInt64(0), warehouseName = r.GetString(1) });
        }
        var items = new List<object>();
        await using (var cmd = new SqlCommand($"SELECT I.ItemID,I.ItemCode,I.ItemName,I.StockTrackingCode,I.BorrowApprovalRequired,I.BorrowMaxDays,I.BorrowApprovalRouteID FROM dbo.TDIVItem I WHERE I.CompanyID=@company AND I.IsActive=1 AND I.IsBorrowable=1 AND {ItemProjectAccess.ItemAliasPredicate} ORDER BY I.ItemCode", c))
        {
            P(cmd, "@company", SqlDbType.BigInt, Company);
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) items.Add(new { itemID = r.GetInt64(0), itemCode = r.GetString(1), itemName = r.GetString(2), tracking = r.GetString(3), approvalRequired = r.GetBoolean(4), maxDays = r.GetInt32(5), routeID = r.IsDBNull(6) ? (long?)null : r.GetInt64(6) });
        }
        var serials = new List<object>();
        await using (var cmd = new SqlCommand($"SELECT X.ItemInstanceID,X.ItemID,X.WarehouseID,X.SerialNo FROM dbo.TDIVItemInstance X INNER JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID INNER JOIN dbo.TDIVWarehouse W ON W.WarehouseID=X.WarehouseID AND W.CompanyID=X.CompanyID INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE X.CompanyID=@company AND X.StatusCode=N'IN_STOCK' AND I.IsBorrowable=1 AND {WarehouseAccessService.WarehouseAliasPredicate} AND {ItemProjectAccess.ItemAliasPredicate} ORDER BY X.SerialNo", c))
        {
            P(cmd, "@company", SqlDbType.BigInt, Company); P(cmd, "@user", SqlDbType.BigInt, UserId);
            await using var r = await cmd.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) serials.Add(new { instanceID = r.GetInt64(0), itemID = r.GetInt64(1), warehouseID = r.GetInt64(2), serialNo = r.GetString(3) });
        }
        var routes = await LoadRoutes(c, token);
        return Ok(new { employees, warehouses, items, serials, routes });
    }

    [HttpGet("routes")]
    public async Task<IActionResult> Routes(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "08001", "VIEW", token)) return Denied();
        return Ok(await LoadRoutes(c, token));
    }

    [HttpGet("approvers")]
    public async Task<IActionResult> Approvers(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "08001", "VIEW", token)) return Denied();
        var rows = new List<object>();
        await using var cmd = new SqlCommand("SELECT UserID,COALESCE(NULLIF(DisplayName,N''),Username) FROM dbo.TDADUser WHERE CompanyID=@company AND IsActive=1 ORDER BY COALESCE(NULLIF(DisplayName,N''),Username)", c);
        P(cmd, "@company", SqlDbType.BigInt, Company);
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) rows.Add(new { userID = r.GetInt64(0), name = r.GetString(1) });
        return Ok(rows);
    }

    private async Task<List<object>> LoadRoutes(SqlConnection c, CancellationToken token)
    {
        var result = new List<object>();
        await using var cmd = new SqlCommand("SELECT BorrowApprovalRouteID,RouteName,IsDefault FROM dbo.TDIVBorrowApprovalRoute WHERE CompanyID=@company AND IsActive=1 ORDER BY IsDefault DESC,RouteName", c);
        P(cmd, "@company", SqlDbType.BigInt, Company);
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) result.Add(new { routeID = r.GetInt64(0), routeName = r.GetString(1), isDefault = r.GetBoolean(2) });
        return result;
    }

    [HttpPost("routes")]
    public async Task<IActionResult> SaveRoute([FromBody] BorrowRouteInput input, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "08001", "EDIT", token)) return Denied();
        if (string.IsNullOrWhiteSpace(input.Name) || input.Steps is null || input.Steps.Count == 0 || input.Steps.Distinct().Count() != input.Steps.Count)
            return Invalid("สายอนุมัติไม่ครบ", "ระบุชื่อและผู้อนุมัติอย่างน้อยหนึ่งขั้นโดยไม่ซ้ำกัน");
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            foreach (var approver in input.Steps)
            {
                await using var check = new SqlCommand("SELECT COUNT(*) FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@user AND IsActive=1", c, tx);
                P(check, "@company", SqlDbType.BigInt, Company); P(check, "@user", SqlDbType.BigInt, approver);
                if (Convert.ToInt32(await check.ExecuteScalarAsync(token)) == 0) throw new InvalidOperationException("ผู้อนุมัติไม่ได้เป็นผู้ใช้ที่เปิดใช้งานในบริษัทนี้");
            }
            if (input.IsDefault)
            {
                await using var clear = new SqlCommand("UPDATE dbo.TDIVBorrowApprovalRoute SET IsDefault=0,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE CompanyID=@company AND IsDefault=1", c, tx);
                P(clear, "@company", SqlDbType.BigInt, Company); P(clear, "@user", SqlDbType.BigInt, UserId);
                await clear.ExecuteNonQueryAsync(token);
            }
            await using var add = new SqlCommand("INSERT dbo.TDIVBorrowApprovalRoute(CompanyID,RouteName,IsDefault,CreatedBy) OUTPUT INSERTED.BorrowApprovalRouteID VALUES(@company,@name,@default,@user)", c, tx);
            P(add, "@company", SqlDbType.BigInt, Company); P(add, "@name", SqlDbType.NVarChar, input.Name.Trim(), 200); P(add, "@default", SqlDbType.Bit, input.IsDefault); P(add, "@user", SqlDbType.BigInt, UserId);
            var route = Convert.ToInt64(await add.ExecuteScalarAsync(token));
            for (var i = 0; i < input.Steps.Count; i++)
            {
                await using var step = new SqlCommand("INSERT dbo.TDIVBorrowApprovalRouteStep(CompanyID,BorrowApprovalRouteID,StepNo,ApproverUserID) VALUES(@company,@route,@step,@approver)", c, tx);
                P(step, "@company", SqlDbType.BigInt, Company); P(step, "@route", SqlDbType.BigInt, route); P(step, "@step", SqlDbType.Int, i + 1); P(step, "@approver", SqlDbType.BigInt, input.Steps[i]);
                await step.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return Ok(new { routeID = route });
        }
        catch (Exception ex) when (ex is InvalidOperationException or SqlException)
        {
            await tx.RollbackAsync(token);
            return Invalid("บันทึกสายอนุมัติไม่สำเร็จ", ex is InvalidOperationException ? ex.Message : "ชื่อสายอนุมัติอาจซ้ำ โปรดตรวจสอบและลองใหม่");
        }
    }

    [HttpGet("item-policy/{itemId:long}")]
    public async Task<IActionResult> ItemPolicy(long itemId, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "08001", "VIEW", token)) return Denied();
        await using var cmd = new SqlCommand("SELECT IsBorrowable,BorrowApprovalRequired,BorrowMaxDays,BorrowApprovalRouteID FROM dbo.TDIVItem WHERE CompanyID=@company AND ItemID=@item", c);
        P(cmd, "@company", SqlDbType.BigInt, Company); P(cmd, "@item", SqlDbType.BigInt, itemId);
        await using var r = await cmd.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound();
        return Ok(new { isBorrowable = r.GetBoolean(0), approvalRequired = r.GetBoolean(1), maxDays = r.IsDBNull(2) ? (int?)null : r.GetInt32(2), routeID = r.IsDBNull(3) ? (long?)null : r.GetInt64(3) });
    }

    [HttpPut("item-policy/{itemId:long}")]
    public async Task<IActionResult> SaveItemPolicy(long itemId, [FromBody] BorrowItemPolicyInput input, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "08001", "EDIT", token)) return Denied();
        if (input.IsBorrowable && input.MaxDays is not > 0) return Invalid("จำนวนวันยืมไม่ถูกต้อง", "สินค้าที่เปิดให้ยืมต้องกำหนดจำนวนวันสูงสุดมากกว่า 0");
        await using var cmd = new SqlCommand("UPDATE I SET IsBorrowable=@enabled,BorrowApprovalRequired=@approval,BorrowMaxDays=@days,BorrowApprovalRouteID=@route,UpdateDate=SYSUTCDATETIME() FROM dbo.TDIVItem I WHERE I.CompanyID=@company AND I.ItemID=@item AND (@enabled=0 OR (I.IsActive=1 AND I.ItemKindCode=N'GOODS' AND I.StockTrackingCode IN(N'QUANTITY',N'SERIAL'))) AND (@route IS NULL OR EXISTS(SELECT 1 FROM dbo.TDIVBorrowApprovalRoute R WHERE R.BorrowApprovalRouteID=@route AND R.CompanyID=@company AND R.IsActive=1))", c);
        P(cmd, "@company", SqlDbType.BigInt, Company); P(cmd, "@item", SqlDbType.BigInt, itemId); P(cmd, "@enabled", SqlDbType.Bit, input.IsBorrowable); P(cmd, "@approval", SqlDbType.Bit, input.IsBorrowable && input.ApprovalRequired); P(cmd, "@days", SqlDbType.Int, input.IsBorrowable ? input.MaxDays : null); P(cmd, "@route", SqlDbType.BigInt, input.IsBorrowable && input.ApprovalRequired ? input.RouteID : null);
        return await cmd.ExecuteNonQueryAsync(token) == 1 ? Ok(new { saved = true }) : Invalid("บันทึกกติกายืมไม่ได้", "ตรวจสอบว่าสินค้าเปิดใช้งาน ติดตามสต๊อก และสายอนุมัติอยู่ในบริษัทนี้");
    }
}

public sealed record BorrowRouteInput(string Name, bool IsDefault, List<long> Steps);
public sealed record BorrowItemPolicyInput(bool IsBorrowable, bool ApprovalRequired, int? MaxDays, long? RouteID);
