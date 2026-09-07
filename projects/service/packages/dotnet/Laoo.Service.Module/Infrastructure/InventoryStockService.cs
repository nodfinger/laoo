using System.Data;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Infrastructure;

internal sealed record InventoryIssueResult(bool Success, bool AlreadyFulfilled, string? Error)
{
    internal static InventoryIssueResult Ok(bool alreadyFulfilled = false) => new(true, alreadyFulfilled, null);
    internal static InventoryIssueResult Fail(string error) => new(false, false, error);
}

internal static class InventoryStockService
{
    internal static async Task<InventoryIssueResult> IssueSaleAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long companyId,
        long userId,
        string documentType,
        long documentId,
        long documentDetailId,
        long itemId,
        decimal quantity,
        long? warehouseId,
        string? sourceDocumentType,
        long? sourceDocumentDetailId,
        IReadOnlyCollection<long>? serialInstanceIds,
        CancellationToken token)
    {
        const string itemSql = "SELECT ItemKindCode,StockTrackingCode FROM dbo.TDIVItem WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND ItemID=@item AND IsActive=1";
        await using var itemCommand = new SqlCommand(itemSql, connection, transaction);
        Add(itemCommand, "@company", SqlDbType.BigInt, companyId);
        Add(itemCommand, "@item", SqlDbType.BigInt, itemId);
        string? kind = null;
        string? tracking = null;
        await using (var reader = await itemCommand.ExecuteReaderAsync(token))
        {
            if (await reader.ReadAsync(token))
            {
                kind = reader.GetString(0);
                tracking = reader.GetString(1);
            }
        }
        if (kind is null) return InventoryIssueResult.Fail($"ItemID {itemId} was not found in this company.");
        if (kind == "SERVICE" || tracking == "NONE") return InventoryIssueResult.Ok();
        if (quantity <= 0) return InventoryIssueResult.Fail("Stock issue quantity must be greater than zero.");

        var warehouse = warehouseId ?? await DefaultWarehouse(connection, transaction, companyId, token);
        if (!warehouse.HasValue) return InventoryIssueResult.Fail("This company has no active default warehouse.");
        if (!await WarehouseBelongsToCompany(connection, transaction, companyId, warehouse.Value, token))
            return InventoryIssueResult.Fail("The selected warehouse is not active in this company.");

        var sourceType = string.IsNullOrWhiteSpace(sourceDocumentType)
            ? documentType
            : sourceDocumentType.Trim().ToUpperInvariant();
        var sourceDetail = sourceDocumentDetailId ?? documentDetailId;
        const string existingSql = "SELECT 1 FROM dbo.TDIVInventoryFulfillment WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND SourceDocumentType=@sourceType AND SourceDocumentDetailID=@sourceDetail AND ReversedDate IS NULL";
        await using (var existing = new SqlCommand(existingSql, connection, transaction))
        {
            Add(existing, "@company", SqlDbType.BigInt, companyId);
            Add(existing, "@sourceType", SqlDbType.NVarChar, sourceType, 30);
            Add(existing, "@sourceDetail", SqlDbType.BigInt, sourceDetail);
            if (await existing.ExecuteScalarAsync(token) is not null) return InventoryIssueResult.Ok(true);
        }

        var serials = (serialInstanceIds ?? Array.Empty<long>()).Distinct().ToArray();
        if (tracking == "SERIAL")
        {
            if (quantity != decimal.Truncate(quantity) || serials.Length != (int)quantity)
                return InventoryIssueResult.Fail($"ItemID {itemId} requires exactly {quantity:0} serial numbers.");
            foreach (var instanceId in serials)
            {
                const string serialSql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDIVItemInstance WITH(UPDLOCK,HOLDLOCK) WHERE ItemInstanceID=@instance AND CompanyID=@company AND ItemID=@item AND WarehouseID=@warehouse AND StatusCode=N'IN_STOCK') THEN 1 ELSE 0 END";
                await using var serial = new SqlCommand(serialSql, connection, transaction);
                Add(serial, "@instance", SqlDbType.BigInt, instanceId);
                Add(serial, "@company", SqlDbType.BigInt, companyId);
                Add(serial, "@item", SqlDbType.BigInt, itemId);
                Add(serial, "@warehouse", SqlDbType.BigInt, warehouse.Value);
                if (Convert.ToInt32(await serial.ExecuteScalarAsync(token)) != 1)
                    return InventoryIssueResult.Fail($"Serial ID {instanceId} is not available in the selected warehouse.");
            }
        }
        else if (serials.Length > 0)
        {
            return InventoryIssueResult.Fail($"ItemID {itemId} does not use SERIAL tracking.");
        }

        const string fulfillmentSql = "INSERT dbo.TDIVInventoryFulfillment(CompanyID,SourceDocumentType,SourceDocumentDetailID,ItemID,WarehouseID,Quantity,FulfilledByDocumentType,FulfilledByDocumentID,FulfilledByDocumentDetailID,CreatedBy) VALUES(@company,@sourceType,@sourceDetail,@item,@warehouse,@qty,@documentType,@document,@detail,@user)";
        await using (var fulfillment = new SqlCommand(fulfillmentSql, connection, transaction))
        {
            Bind(fulfillment, companyId, userId, documentType, documentId, documentDetailId, itemId, quantity, warehouse.Value);
            Add(fulfillment, "@sourceType", SqlDbType.NVarChar, sourceType, 30);
            Add(fulfillment, "@sourceDetail", SqlDbType.BigInt, sourceDetail);
            await fulfillment.ExecuteNonQueryAsync(token);
        }

        const string balanceSql = "UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK) SET Quantity=Quantity-@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND WarehouseID=@warehouse AND ItemID=@item AND Quantity>=@qty; IF @@ROWCOUNT=0 THROW 52320,N'Insufficient warehouse stock',1; UPDATE dbo.TDIVItem SET StockBalance=StockBalance-@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ItemID=@item AND StockBalance>=@qty";
        await using (var balance = new SqlCommand(balanceSql, connection, transaction))
        {
            Add(balance, "@qty", SqlDbType.Decimal, quantity);
            Add(balance, "@company", SqlDbType.BigInt, companyId);
            Add(balance, "@warehouse", SqlDbType.BigInt, warehouse.Value);
            Add(balance, "@item", SqlDbType.BigInt, itemId);
            await balance.ExecuteNonQueryAsync(token);
        }

        const string movementSql = "INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@warehouse,@item,@documentType,@document,@detail,N'SALE_OUT',-@qty,N'Sale issue',@user)";
        await using (var movement = new SqlCommand(movementSql, connection, transaction))
        {
            Bind(movement, companyId, userId, documentType, documentId, documentDetailId, itemId, quantity, warehouse.Value);
            await movement.ExecuteNonQueryAsync(token);
        }

        foreach (var instanceId in serials)
        {
            const string updateSql = "UPDATE dbo.TDIVItemInstance SET StatusCode=N'SOLD',WarehouseID=NULL,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE ItemInstanceID=@instance AND CompanyID=@company; INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy) VALUES(@company,@instance,N'IN_STOCK',N'SOLD',@documentType,@document,@detail,N'Sold from warehouse',@user)";
            await using var update = new SqlCommand(updateSql, connection, transaction);
            Add(update, "@company", SqlDbType.BigInt, companyId);
            Add(update, "@documentType", SqlDbType.NVarChar, documentType, 30);
            Add(update, "@document", SqlDbType.BigInt, documentId);
            Add(update, "@detail", SqlDbType.BigInt, documentDetailId);
            Add(update, "@instance", SqlDbType.BigInt, instanceId);
            Add(update, "@user", SqlDbType.BigInt, userId);
            await update.ExecuteNonQueryAsync(token);
        }
        return InventoryIssueResult.Ok();
    }

    internal static async Task ReverseDocumentAsync(SqlConnection connection, SqlTransaction transaction, long companyId, long userId, string documentType, long documentId, CancellationToken token)
    {
        const string sql = "SELECT InventoryFulfillmentID,WarehouseID,ItemID,Quantity,FulfilledByDocumentDetailID FROM dbo.TDIVInventoryFulfillment WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND FulfilledByDocumentType=@type AND FulfilledByDocumentID=@id AND ReversedDate IS NULL";
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@company", SqlDbType.BigInt, companyId);
        Add(command, "@type", SqlDbType.NVarChar, documentType, 30);
        Add(command, "@id", SqlDbType.BigInt, documentId);
        var rows = new List<(long Fulfillment, long Warehouse, long Item, decimal Qty, long Detail)>();
        await using (var reader = await command.ExecuteReaderAsync(token))
        {
            while (await reader.ReadAsync(token)) rows.Add((reader.GetInt64(0), reader.GetInt64(1), reader.GetInt64(2), reader.GetDecimal(3), reader.GetInt64(4)));
        }
        foreach (var row in rows)
        {
            const string reverseSql = "UPDATE dbo.TDIVStockBalance WITH(UPDLOCK,HOLDLOCK) SET Quantity=Quantity+@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND WarehouseID=@warehouse AND ItemID=@item; UPDATE dbo.TDIVItem SET StockBalance=StockBalance+@qty,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ItemID=@item; INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy) VALUES(@company,@warehouse,@item,@documentType,@document,@detail,N'REVERSAL',@qty,N'Sale reversal',@user); UPDATE dbo.TDIVInventoryFulfillment SET ReversedDate=SYSUTCDATETIME() WHERE InventoryFulfillmentID=@fulfillment";
            await using var reverse = new SqlCommand(reverseSql, connection, transaction);
            Bind(reverse, companyId, userId, documentType, documentId, row.Detail, row.Item, row.Qty, row.Warehouse);
            Add(reverse, "@fulfillment", SqlDbType.BigInt, row.Fulfillment);
            await reverse.ExecuteNonQueryAsync(token);

            const string serialSql = "UPDATE I SET StatusCode=N'IN_STOCK',WarehouseID=@warehouse,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user FROM dbo.TDIVItemInstance I JOIN dbo.TDIVDocumentSerialSelection S ON S.ItemInstanceID=I.ItemInstanceID WHERE S.CompanyID=@company AND S.DocumentType=@documentType AND S.DocumentDetailID=@detail AND I.StatusCode=N'SOLD'; INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,WarehouseID,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy) SELECT @company,S.ItemInstanceID,N'SOLD',N'IN_STOCK',@warehouse,@documentType,@document,@detail,N'Sale reversal',@user FROM dbo.TDIVDocumentSerialSelection S WHERE S.CompanyID=@company AND S.DocumentType=@documentType AND S.DocumentDetailID=@detail";
            await using var serials = new SqlCommand(serialSql, connection, transaction);
            Add(serials, "@company", SqlDbType.BigInt, companyId);
            Add(serials, "@warehouse", SqlDbType.BigInt, row.Warehouse);
            Add(serials, "@documentType", SqlDbType.NVarChar, documentType, 30);
            Add(serials, "@document", SqlDbType.BigInt, documentId);
            Add(serials, "@detail", SqlDbType.BigInt, row.Detail);
            Add(serials, "@user", SqlDbType.BigInt, userId);
            await serials.ExecuteNonQueryAsync(token);
        }
    }

    private static async Task<long?> DefaultWarehouse(SqlConnection c, SqlTransaction tx, long company, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT WarehouseID FROM dbo.TDIVWarehouse WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND IsDefault=1 AND IsActive=1", c, tx);
        Add(command, "@company", SqlDbType.BigInt, company);
        var value = await command.ExecuteScalarAsync(token);
        return value is null or DBNull ? null : Convert.ToInt64(value);
    }

    private static async Task<bool> WarehouseBelongsToCompany(SqlConnection c, SqlTransaction tx, long company, long warehouse, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDIVWarehouse WHERE CompanyID=@company AND WarehouseID=@warehouse AND IsActive=1) THEN 1 ELSE 0 END", c, tx);
        Add(command, "@company", SqlDbType.BigInt, company);
        Add(command, "@warehouse", SqlDbType.BigInt, warehouse);
        return Convert.ToInt32(await command.ExecuteScalarAsync(token)) == 1;
    }

    private static void Bind(SqlCommand c, long company, long user, string documentType, long document, long detail, long item, decimal qty, long warehouse)
    {
        Add(c, "@company", SqlDbType.BigInt, company);
        Add(c, "@user", SqlDbType.BigInt, user);
        Add(c, "@documentType", SqlDbType.NVarChar, documentType, 30);
        Add(c, "@document", SqlDbType.BigInt, document);
        Add(c, "@detail", SqlDbType.BigInt, detail);
        Add(c, "@item", SqlDbType.BigInt, item);
        Add(c, "@qty", SqlDbType.Decimal, qty);
        Add(c, "@warehouse", SqlDbType.BigInt, warehouse);
    }

    private static void Add(SqlCommand c, string name, SqlDbType type, object? value, int size = 0) =>
        InventoryControllerSupport.Add(c, name, type, value, size);
}
