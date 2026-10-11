using System.Data;
using LaooServiceModule.Infrastructure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;

public sealed partial class EmployeeBorrowController
{
    [HttpGet("requests")]
    public async Task<IActionResult> Requests([FromQuery] string menuCode = "08008", [FromQuery] string? status = null, CancellationToken token = default)
    {
        if (menuCode is not ("08008" or "08009" or "08010" or "08011")) return NotFound();
        await using var c = await Open(token);
        if (!await Can(c, menuCode, "VIEW", token)) return Denied();
        var rows = new List<object>();
        var sql = $"SELECT R.BorrowRequestID,R.RequestCode,R.RequestDate,R.DueDate,R.StatusCode,E.FullName,W.WarehouseName,R.RouteNameSnapshot,(SELECT COUNT(*) FROM dbo.TDIVBorrowRequestLine L WHERE L.BorrowRequestID=R.BorrowRequestID) AS ItemCount FROM dbo.TDIVBorrowRequest R JOIN dbo.TDADEmployee E ON E.EmployeeID=R.EmployeeID AND E.CompanyID=R.CompanyID JOIN dbo.TDIVWarehouse W ON W.WarehouseID=R.WarehouseID AND W.CompanyID=R.CompanyID JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE R.CompanyID=@company AND {WarehouseAccessService.WarehouseAliasPredicate} AND (@status IS NULL OR R.StatusCode=@status) AND (@menu<>N'08009' OR EXISTS(SELECT 1 FROM dbo.TDIVBorrowApproval A WHERE A.BorrowRequestID=R.BorrowRequestID AND A.CompanyID=R.CompanyID AND A.ApproverUserID=@user AND A.StatusCode=N'PENDING' AND NOT EXISTS(SELECT 1 FROM dbo.TDIVBorrowApproval P WHERE P.BorrowRequestID=A.BorrowRequestID AND P.StepNo<A.StepNo AND P.StatusCode<>N'APPROVED'))) AND (@menu<>N'08010' OR R.StatusCode IN(N'READY',N'ISSUED',N'PARTIAL_RETURN')) ORDER BY R.BorrowRequestID DESC";
        await using var cmd = new SqlCommand(sql, c);
        P(cmd, "@company", SqlDbType.BigInt, Company); P(cmd, "@user", SqlDbType.BigInt, UserId);
        P(cmd, "@menu", SqlDbType.NVarChar, menuCode, 5); P(cmd, "@status", SqlDbType.NVarChar, string.IsNullOrWhiteSpace(status) ? null : status.Trim().ToUpperInvariant(), 25);
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) rows.Add(new { requestID = r.GetInt64(0), requestCode = r.GetString(1), requestDate = r.GetDateTime(2), dueDate = r.GetDateTime(3), statusCode = r.GetString(4), employeeName = r.GetString(5), warehouseName = r.GetString(6), routeName = r.IsDBNull(7) ? null : r.GetString(7), itemCount = r.GetInt32(8) });
        return Ok(rows);
    }

    [HttpGet("requests/{id:long}")]
    public async Task<IActionResult> RequestDetail(long id, CancellationToken token)
    {
        await using var c = await Open(token);
        var generalView = await Can(c, "08008", "VIEW", token) || await Can(c, "08010", "VIEW", token) || await Can(c, "08011", "VIEW", token);
        if (!generalView)
        {
            if (!await Can(c, "08009", "VIEW", token)) return Denied();
            await using var assigned = new SqlCommand("SELECT 1 FROM dbo.TDIVBorrowApproval WHERE BorrowRequestID=@id AND CompanyID=@company AND ApproverUserID=@user", c);
            P(assigned, "@id", SqlDbType.BigInt, id); P(assigned, "@company", SqlDbType.BigInt, Company); P(assigned, "@user", SqlDbType.BigInt, UserId);
            if (await assigned.ExecuteScalarAsync(token) is null) return Denied();
        }
        await using var cmd = new SqlCommand($"SELECT R.RequestCode,R.StatusCode,R.EmployeeID,E.FullName,R.WarehouseID,W.WarehouseName,R.RequestDate,R.PlannedIssueDate,R.DueDate,R.Remark,R.RouteNameSnapshot FROM dbo.TDIVBorrowRequest R JOIN dbo.TDADEmployee E ON E.EmployeeID=R.EmployeeID AND E.CompanyID=R.CompanyID JOIN dbo.TDIVWarehouse W ON W.WarehouseID=R.WarehouseID AND W.CompanyID=R.CompanyID JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE R.BorrowRequestID=@id AND R.CompanyID=@company AND {WarehouseAccessService.WarehouseAliasPredicate}", c);
        P(cmd, "@id", SqlDbType.BigInt, id); P(cmd, "@company", SqlDbType.BigInt, Company); P(cmd, "@user", SqlDbType.BigInt, UserId);
        object? header = null;
        await using (var r = await cmd.ExecuteReaderAsync(token)) if (await r.ReadAsync(token)) header = new { requestID = id, requestCode = r.GetString(0), statusCode = r.GetString(1), employeeID = r.GetInt64(2), employeeName = r.GetString(3), warehouseID = r.GetInt64(4), warehouseName = r.GetString(5), requestDate = r.GetDateTime(6), plannedIssueDate = r.GetDateTime(7), dueDate = r.GetDateTime(8), remark = r.IsDBNull(9) ? null : r.GetString(9), routeName = r.IsDBNull(10) ? null : r.GetString(10) };
        if (header is null) return NotFound();
        var lines = new List<object>();
        await using (var line = new SqlCommand("SELECT L.BorrowRequestLineID,L.[LineNo],L.ItemID,I.ItemCode,I.ItemName,L.Quantity,L.IssuedQuantity,L.ReturnedQuantity,L.StockTrackingSnapshot,L.MaxDaysSnapshot FROM dbo.TDIVBorrowRequestLine L JOIN dbo.TDIVItem I ON I.ItemID=L.ItemID AND I.CompanyID=L.CompanyID WHERE L.BorrowRequestID=@id AND L.CompanyID=@company ORDER BY L.[LineNo]", c))
        {
            P(line, "@id", SqlDbType.BigInt, id); P(line, "@company", SqlDbType.BigInt, Company);
            await using var r = await line.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) lines.Add(new { lineID = r.GetInt64(0), lineNo = r.GetInt32(1), itemID = r.GetInt64(2), itemCode = r.GetString(3), itemName = r.GetString(4), quantity = r.GetDecimal(5), issuedQuantity = r.GetDecimal(6), returnedQuantity = r.GetDecimal(7), tracking = r.GetString(8), maxDays = r.GetInt32(9) });
        }
        var serials = new List<object>();
        await using (var sc = new SqlCommand("SELECT S.BorrowRequestLineID,S.ItemInstanceID,X.SerialNo,S.StatusCode FROM dbo.TDIVBorrowSerial S JOIN dbo.TDIVItemInstance X ON X.ItemInstanceID=S.ItemInstanceID AND X.CompanyID=S.CompanyID JOIN dbo.TDIVBorrowRequestLine L ON L.BorrowRequestLineID=S.BorrowRequestLineID WHERE L.BorrowRequestID=@id AND S.CompanyID=@company", c))
        {
            P(sc, "@id", SqlDbType.BigInt, id); P(sc, "@company", SqlDbType.BigInt, Company);
            await using var r = await sc.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) serials.Add(new { lineID = r.GetInt64(0), instanceID = r.GetInt64(1), serialNo = r.GetString(2), statusCode = r.GetString(3) });
        }
        var approvals = new List<object>();
        await using (var ac = new SqlCommand("SELECT StepNo,ApproverUserID,StatusCode,DecisionDate,Reason FROM dbo.TDIVBorrowApproval WHERE BorrowRequestID=@id AND CompanyID=@company ORDER BY StepNo", c))
        {
            P(ac, "@id", SqlDbType.BigInt, id); P(ac, "@company", SqlDbType.BigInt, Company);
            await using var r = await ac.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) approvals.Add(new { stepNo = r.GetInt32(0), approverUserID = r.GetInt64(1), statusCode = r.GetString(2), decisionDate = r.IsDBNull(3) ? (DateTime?)null : r.GetDateTime(3), reason = r.IsDBNull(4) ? null : r.GetString(4) });
        }
        var photos = new List<object>();
        await using (var pc = new SqlCommand("SELECT P.BorrowPhotoID,T.BorrowRequestLineID,T.TransferType,T.TransferDate,P.FileName FROM dbo.TDIVBorrowPhoto P JOIN dbo.TDIVBorrowTransfer T ON T.BorrowTransferID=P.BorrowTransferID AND T.CompanyID=P.CompanyID JOIN dbo.TDIVBorrowRequestLine L ON L.BorrowRequestLineID=T.BorrowRequestLineID AND L.CompanyID=T.CompanyID WHERE L.BorrowRequestID=@id AND L.CompanyID=@company ORDER BY T.TransferDate", c))
        {
            P(pc, "@id", SqlDbType.BigInt, id); P(pc, "@company", SqlDbType.BigInt, Company);
            await using var r = await pc.ExecuteReaderAsync(token);
            while (await r.ReadAsync(token)) photos.Add(new { photoID = r.GetInt64(0), lineID = r.GetInt64(1), transferType = r.GetString(2), transferDate = r.GetDateTime(3), fileName = r.GetString(4) });
        }
        return Ok(new { header, lines, serials, approvals, photos });
    }

    [HttpPost("requests")]
    public async Task<IActionResult> CreateRequest([FromBody] BorrowRequestInput input, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "08008", "CREATE", token)) return Denied();
        if (input.EmployeeID <= 0 || input.WarehouseID <= 0 || input.Lines is null || input.Lines.Count == 0 || input.PlannedIssueDate.Date < DateTime.UtcNow.Date || input.DueDate.Date < input.PlannedIssueDate.Date)
            return Invalid("ข้อมูลคำขอยืมไม่ครบ", "เลือกพนักงาน คลัง สินค้า และวันที่ยืม–คืนให้ถูกต้อง");
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            if (!await WarehouseAccessService.CanAccessAsync(c, tx, Company, UserId, input.WarehouseID, token)) throw new InvalidOperationException("ไม่มีสิทธิ์ใช้คลังนี้");
            await using (var employee = new SqlCommand("SELECT COUNT(*) FROM dbo.TDADEmployee WHERE EmployeeID=@employee AND CompanyID=@company AND IsActive=1", c, tx))
            {
                P(employee, "@employee", SqlDbType.BigInt, input.EmployeeID); P(employee, "@company", SqlDbType.BigInt, Company);
                if (Convert.ToInt32(await employee.ExecuteScalarAsync(token)) == 0) throw new InvalidOperationException("พนักงานไม่อยู่ในบริษัทหรือปิดใช้งาน");
            }
            var prepared = new List<PreparedBorrowLine>();
            var allSerials = new HashSet<long>();
            foreach (var line in input.Lines)
            {
                await ItemProjectAccess.EnsureAsync(c, tx, Company, line.ItemID, token);
                await using var item = new SqlCommand("SELECT StockTrackingCode,BorrowApprovalRequired,BorrowMaxDays,BorrowApprovalRouteID FROM dbo.TDIVItem WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND ItemID=@item AND IsBorrowable=1 AND IsActive=1", c, tx);
                P(item, "@company", SqlDbType.BigInt, Company); P(item, "@item", SqlDbType.BigInt, line.ItemID);
                string? tracking = null; bool approval = false; int maxDays = 0; long? routeID = null;
                await using (var r = await item.ExecuteReaderAsync(token)) if (await r.ReadAsync(token)) { tracking = r.GetString(0); approval = r.GetBoolean(1); maxDays = r.GetInt32(2); routeID = r.IsDBNull(3) ? null : r.GetInt64(3); }
                if (tracking is null || line.Quantity <= 0 || (input.DueDate.Date - input.PlannedIssueDate.Date).Days > maxDays) throw new InvalidOperationException("จำนวนหรือระยะเวลายืมเกินกติกาของสินค้า");
                if (approval && routeID is null)
                {
                    await using var route = new SqlCommand("SELECT TOP(1) BorrowApprovalRouteID FROM dbo.TDIVBorrowApprovalRoute WHERE CompanyID=@company AND IsActive=1 AND IsDefault=1", c, tx);
                    P(route, "@company", SqlDbType.BigInt, Company);
                    var value = await route.ExecuteScalarAsync(token);
                    routeID = value is null ? null : Convert.ToInt64(value);
                }
                if (approval && routeID is null) throw new InvalidOperationException("สินค้าต้องอนุมัติ แต่บริษัทยังไม่มีสายอนุมัติเริ่มต้น");
                if (approval)
                {
                    await using var checkRoute = new SqlCommand("SELECT COUNT(*) FROM dbo.TDIVBorrowApprovalRoute R WHERE R.BorrowApprovalRouteID=@route AND R.CompanyID=@company AND R.IsActive=1 AND EXISTS(SELECT 1 FROM dbo.TDIVBorrowApprovalRouteStep S WHERE S.BorrowApprovalRouteID=R.BorrowApprovalRouteID)", c, tx);
                    P(checkRoute, "@route", SqlDbType.BigInt, routeID); P(checkRoute, "@company", SqlDbType.BigInt, Company);
                    if (Convert.ToInt32(await checkRoute.ExecuteScalarAsync(token)) == 0) throw new InvalidOperationException("สายอนุมัติไม่พร้อมใช้งาน");
                }
                var serialIDs = line.SerialIDs ?? [];
                if (tracking == "SERIAL" && (line.Quantity != decimal.Truncate(line.Quantity) || serialIDs.Count != (int)line.Quantity || serialIDs.Any(x => !allSerials.Add(x)))) throw new InvalidOperationException("จำนวนและ SN ต้องตรงกันและไม่ซ้ำ");
                if (tracking != "SERIAL" && serialIDs.Count > 0) throw new InvalidOperationException("สินค้านับจำนวนไม่ต้องระบุ SN");
                if (tracking == "QUANTITY")
                {
                    await using var balance = new SqlCommand("SELECT Quantity FROM dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND WarehouseID=@warehouse AND ItemID=@item", c, tx);
                    P(balance, "@company", SqlDbType.BigInt, Company); P(balance, "@warehouse", SqlDbType.BigInt, input.WarehouseID); P(balance, "@item", SqlDbType.BigInt, line.ItemID);
                    var onHand = Convert.ToDecimal(await balance.ExecuteScalarAsync(token) ?? 0m);
                    await using var reserved = new SqlCommand("SELECT COALESCE(SUM(L.Quantity-L.IssuedQuantity),0) FROM dbo.TDIVBorrowRequestLine L JOIN dbo.TDIVBorrowRequest R ON R.BorrowRequestID=L.BorrowRequestID WHERE L.CompanyID=@company AND R.WarehouseID=@warehouse AND L.ItemID=@item AND R.StatusCode IN(N'WAIT_APPROVAL',N'READY')", c, tx);
                    P(reserved, "@company", SqlDbType.BigInt, Company); P(reserved, "@warehouse", SqlDbType.BigInt, input.WarehouseID); P(reserved, "@item", SqlDbType.BigInt, line.ItemID);
                    var held = Convert.ToDecimal(await reserved.ExecuteScalarAsync(token));
                    var earlier = prepared.Where(x => x.ItemID == line.ItemID).Sum(x => x.Quantity);
                    if (onHand - held - earlier < line.Quantity) throw new InvalidOperationException("สต๊อกที่พร้อมให้ยืมไม่พอ");
                }
                prepared.Add(new(line.ItemID, line.Quantity, serialIDs, tracking, approval, maxDays, approval ? routeID : null));
            }
            var created = new List<object>();
            foreach (var group in prepared.GroupBy(x => x.RouteID))
            {
                var routeID = group.Key;
                string? routeName = null;
                if (routeID is not null)
                {
                    await using var route = new SqlCommand("SELECT RouteName FROM dbo.TDIVBorrowApprovalRoute WHERE BorrowApprovalRouteID=@route AND CompanyID=@company", c, tx);
                    P(route, "@route", SqlDbType.BigInt, routeID); P(route, "@company", SqlDbType.BigInt, Company);
                    routeName = (await route.ExecuteScalarAsync(token))?.ToString();
                }
                await using var add = new SqlCommand("INSERT dbo.TDIVBorrowRequest(CompanyID,WarehouseID,EmployeeID,RequestCode,RequestDate,PlannedIssueDate,DueDate,BorrowApprovalRouteID,RouteNameSnapshot,StatusCode,Remark,RunID,CreatedBy) OUTPUT INSERTED.BorrowRequestID VALUES(@company,@warehouse,@employee,N'PENDING',CONVERT(date,SYSUTCDATETIME()),@planned,@due,@route,@routeName,@status,@remark,@run,@user)", c, tx);
                P(add, "@company", SqlDbType.BigInt, Company); P(add, "@warehouse", SqlDbType.BigInt, input.WarehouseID); P(add, "@employee", SqlDbType.BigInt, input.EmployeeID);
                P(add, "@planned", SqlDbType.Date, input.PlannedIssueDate.Date); P(add, "@due", SqlDbType.Date, input.DueDate.Date); P(add, "@route", SqlDbType.BigInt, routeID); P(add, "@routeName", SqlDbType.NVarChar, routeName, 200); P(add, "@status", SqlDbType.NVarChar, routeID is null ? "READY" : "WAIT_APPROVAL", 25); P(add, "@remark", SqlDbType.NVarChar, input.Remark?.Trim(), 1000); P(add, "@run", SqlDbType.NVarChar, input.RunID?.Trim(), 80); P(add, "@user", SqlDbType.BigInt, UserId);
                // A unique provisional code is needed because the identity is assigned by SQL Server.
                add.CommandText = add.CommandText.Replace("N'PENDING'", "CONVERT(nvarchar(40),NEWID())");
                var id = Convert.ToInt64(await add.ExecuteScalarAsync(token));
                var code = $"BR{DateTime.UtcNow:yyyy}-{id:000000}";
                await using (var number = new SqlCommand("UPDATE dbo.TDIVBorrowRequest SET RequestCode=@code WHERE BorrowRequestID=@id AND CompanyID=@company", c, tx))
                {
                    P(number, "@code", SqlDbType.NVarChar, code, 40); P(number, "@id", SqlDbType.BigInt, id); P(number, "@company", SqlDbType.BigInt, Company); await number.ExecuteNonQueryAsync(token);
                }
                var lineNo = 0;
                foreach (var line in group)
                {
                    await using var dl = new SqlCommand("INSERT dbo.TDIVBorrowRequestLine(CompanyID,BorrowRequestID,[LineNo],ItemID,Quantity,StockTrackingSnapshot,ApprovalRequiredSnapshot,MaxDaysSnapshot) OUTPUT INSERTED.BorrowRequestLineID VALUES(@company,@request,@line,@item,@qty,@tracking,@approval,@days)", c, tx);
                    P(dl, "@company", SqlDbType.BigInt, Company); P(dl, "@request", SqlDbType.BigInt, id); P(dl, "@line", SqlDbType.Int, ++lineNo); P(dl, "@item", SqlDbType.BigInt, line.ItemID); P(dl, "@qty", SqlDbType.Decimal, line.Quantity); P(dl, "@tracking", SqlDbType.NVarChar, line.Tracking, 20); P(dl, "@approval", SqlDbType.Bit, line.Approval); P(dl, "@days", SqlDbType.Int, line.MaxDays);
                    var lineID = Convert.ToInt64(await dl.ExecuteScalarAsync(token));
                    foreach (var serial in line.SerialIDs)
                    {
                        await using var reserve = new SqlCommand("UPDATE dbo.TDIVItemInstance SET StatusCode=N'RESERVED',UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE CompanyID=@company AND ItemInstanceID=@instance AND ItemID=@item AND WarehouseID=@warehouse AND StatusCode=N'IN_STOCK'; IF @@ROWCOUNT<>1 THROW 59210,N'Serial not available',1; INSERT dbo.TDIVBorrowSerial(CompanyID,BorrowRequestLineID,ItemInstanceID,StatusCode) VALUES(@company,@line,@instance,N'RESERVED'); INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,WarehouseID,DocumentType,DocumentID,DocumentDetailID,CreatedBy) VALUES(@company,@instance,N'IN_STOCK',N'RESERVED',@warehouse,N'BORROW',@request,@line,@user)", c, tx);
                        P(reserve, "@company", SqlDbType.BigInt, Company); P(reserve, "@instance", SqlDbType.BigInt, serial); P(reserve, "@item", SqlDbType.BigInt, line.ItemID); P(reserve, "@warehouse", SqlDbType.BigInt, input.WarehouseID); P(reserve, "@line", SqlDbType.BigInt, lineID); P(reserve, "@request", SqlDbType.BigInt, id); P(reserve, "@user", SqlDbType.BigInt, UserId);
                        await reserve.ExecuteNonQueryAsync(token);
                    }
                }
                if (routeID is not null)
                {
                    await using var steps = new SqlCommand("INSERT dbo.TDIVBorrowApproval(CompanyID,BorrowRequestID,StepNo,ApproverUserID) SELECT @company,@request,StepNo,ApproverUserID FROM dbo.TDIVBorrowApprovalRouteStep WHERE CompanyID=@company AND BorrowApprovalRouteID=@route", c, tx);
                    P(steps, "@company", SqlDbType.BigInt, Company); P(steps, "@request", SqlDbType.BigInt, id); P(steps, "@route", SqlDbType.BigInt, routeID);
                    await steps.ExecuteNonQueryAsync(token);
                }
                await Audit(c, tx, id, "CREATE", $"สร้างคำขอยืม {code}", token);
                created.Add(new { requestID = id, requestCode = code, statusCode = routeID is null ? "READY" : "WAIT_APPROVAL" });
            }
            await tx.CommitAsync(token);
            return Ok(new { requests = created });
        }
        catch (Exception ex) when (ex is InvalidOperationException or SqlException or ItemProjectDeniedException)
        {
            await tx.RollbackAsync(token);
            return ex is ItemProjectDeniedException ? Denied() : Invalid("บันทึกคำขอยืมไม่สำเร็จ", ex is InvalidOperationException ? ex.Message : "สินค้า/SN อาจถูกจองไปแล้ว โปรดตรวจสอบและลองใหม่");
        }
    }

    [HttpPost("requests/{id:long}/cancel")]
    public async Task<IActionResult> Cancel(long id, CancellationToken token)
    {
        await using var c = await Open(token); if (!await Can(c, "08008", "DELETE", token)) return Denied();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var row = await LockedRequest(c, tx, id, token);
            if (row is null) { await tx.RollbackAsync(token); return NotFound(); }
            if (!await WarehouseAccessService.CanAccessAsync(c, tx, Company, UserId, row.Value.WarehouseID, token) || row.Value.Status is not ("WAIT_APPROVAL" or "READY")) throw new InvalidOperationException("ยกเลิกได้เฉพาะคำขอที่ยังไม่ส่งมอบและอยู่ในคลังที่มีสิทธิ์");
            await ReleaseSerials(c, tx, id, row.Value.WarehouseID, token);
            await using var cmd = new SqlCommand("UPDATE dbo.TDIVBorrowRequest SET StatusCode=N'CANCELLED',UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE BorrowRequestID=@id AND CompanyID=@company", c, tx);
            P(cmd, "@id", SqlDbType.BigInt, id); P(cmd, "@company", SqlDbType.BigInt, Company); P(cmd, "@user", SqlDbType.BigInt, UserId); await cmd.ExecuteNonQueryAsync(token);
            await Audit(c, tx, id, "CANCEL", null, token); await tx.CommitAsync(token); return Ok(new { statusCode = "CANCELLED" });
        }
        catch (Exception ex) when (ex is InvalidOperationException or SqlException) { await tx.RollbackAsync(token); return Invalid("ยกเลิกคำขอไม่ได้", ex is InvalidOperationException ? ex.Message : "โปรดตรวจสอบสถานะและลองใหม่"); }
    }

    internal async Task<(string Status, long WarehouseID)?> LockedRequest(SqlConnection c, SqlTransaction tx, long id, CancellationToken token)
    {
        await using var cmd = new SqlCommand("SELECT StatusCode,WarehouseID FROM dbo.TDIVBorrowRequest WITH(UPDLOCK,HOLDLOCK) WHERE BorrowRequestID=@id AND CompanyID=@company", c, tx);
        P(cmd, "@id", SqlDbType.BigInt, id); P(cmd, "@company", SqlDbType.BigInt, Company);
        await using var r = await cmd.ExecuteReaderAsync(token);
        return await r.ReadAsync(token) ? (r.GetString(0), r.GetInt64(1)) : null;
    }
    internal async Task Audit(SqlConnection c, SqlTransaction tx, long id, string action, string? detail, CancellationToken token)
    {
        await using var cmd = new SqlCommand("INSERT dbo.TDIVBorrowAudit(CompanyID,BorrowRequestID,ActionCode,Detail,UserID) VALUES(@company,@request,@action,@detail,@user)", c, tx);
        P(cmd, "@company", SqlDbType.BigInt, Company); P(cmd, "@request", SqlDbType.BigInt, id); P(cmd, "@action", SqlDbType.NVarChar, action, 30); P(cmd, "@detail", SqlDbType.NVarChar, detail, 1000); P(cmd, "@user", SqlDbType.BigInt, UserId); await cmd.ExecuteNonQueryAsync(token);
    }
    internal async Task ReleaseSerials(SqlConnection c, SqlTransaction tx, long id, long warehouse, CancellationToken token)
    {
        await using var cmd = new SqlCommand("IF EXISTS(SELECT 1 FROM dbo.TDIVBorrowSerial S JOIN dbo.TDIVBorrowRequestLine L ON L.BorrowRequestLineID=S.BorrowRequestLineID JOIN dbo.TDIVItemInstance X ON X.ItemInstanceID=S.ItemInstanceID AND X.CompanyID=S.CompanyID WHERE L.BorrowRequestID=@request AND L.CompanyID=@company AND S.StatusCode=N'RESERVED' AND (X.StatusCode<>N'RESERVED' OR X.WarehouseID<>@warehouse)) THROW 59214,N'Borrow serial release conflict',1; UPDATE X SET StatusCode=N'IN_STOCK',UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user FROM dbo.TDIVItemInstance X JOIN dbo.TDIVBorrowSerial S ON S.ItemInstanceID=X.ItemInstanceID AND S.CompanyID=X.CompanyID JOIN dbo.TDIVBorrowRequestLine L ON L.BorrowRequestLineID=S.BorrowRequestLineID WHERE L.BorrowRequestID=@request AND L.CompanyID=@company AND S.StatusCode=N'RESERVED' AND X.StatusCode=N'RESERVED' AND X.WarehouseID=@warehouse; INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,WarehouseID,DocumentType,DocumentID,DocumentDetailID,CreatedBy) SELECT @company,S.ItemInstanceID,N'RESERVED',N'IN_STOCK',@warehouse,N'BORROW',@request,L.BorrowRequestLineID,@user FROM dbo.TDIVBorrowSerial S JOIN dbo.TDIVBorrowRequestLine L ON L.BorrowRequestLineID=S.BorrowRequestLineID WHERE L.BorrowRequestID=@request AND L.CompanyID=@company AND S.StatusCode=N'RESERVED'; UPDATE S SET StatusCode=N'RELEASED' FROM dbo.TDIVBorrowSerial S JOIN dbo.TDIVBorrowRequestLine L ON L.BorrowRequestLineID=S.BorrowRequestLineID WHERE L.BorrowRequestID=@request AND L.CompanyID=@company AND S.StatusCode=N'RESERVED'", c, tx);
        P(cmd, "@company", SqlDbType.BigInt, Company); P(cmd, "@request", SqlDbType.BigInt, id); P(cmd, "@warehouse", SqlDbType.BigInt, warehouse); P(cmd, "@user", SqlDbType.BigInt, UserId); await cmd.ExecuteNonQueryAsync(token);
    }
    private sealed record PreparedBorrowLine(long ItemID, decimal Quantity, List<long> SerialIDs, string Tracking, bool Approval, int MaxDays, long? RouteID);
}

public sealed record BorrowRequestInput(long EmployeeID, long WarehouseID, DateTime PlannedIssueDate, DateTime DueDate, List<BorrowLineInput> Lines, string? Remark, string? RunID);
public sealed record BorrowLineInput(long ItemID, decimal Quantity, List<long>? SerialIDs);
