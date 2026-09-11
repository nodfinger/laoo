namespace LaooServiceModule.Models;

public sealed record WarehouseUpsertRequest(
    long BranchID,
    string WarehouseCode,
    string WarehouseName,
    bool IsDefault,
    bool IsActive);

public sealed record WarehouseAccessRequest(
    string AccessModeCode,
    IReadOnlyCollection<long>? UserIds);

public sealed record StockReceiptSerialInput(string SerialNo);

public sealed record StockReceiptLineRequest(
    long ItemID,
    decimal Quantity,
    decimal UnitCost,
    string? Remark,
    IReadOnlyList<StockReceiptSerialInput>? Serials,
    string SerialSourceCode = "FACTORY",
    string? UnitCode = null);

public sealed record StockReceiptUpsertRequest(
    long WarehouseID,
    DateOnly ReceiptDate,
    string ReceiptType,
    string? ReferenceNo,
    string? Remark,
    IReadOnlyList<StockReceiptLineRequest> Items,
    long? VendorID = null,
    string? DeliveredBy = null);

public sealed record ItemInstanceLocationRequest(
    string StatusCode,
    long? CustomerID,
    long? BranchID,
    long? BuildingID,
    long? FloorID,
    long? RoomID,
    string? Remark,
    bool StartCustomerWarranty = false,
    DateOnly? InstallationDate = null);

public sealed record ItemInstanceWarrantyOverrideRequest(
    string WarrantyModeCode,
    int? DurationMonths,
    DateOnly StartDate,
    string Remark);

public sealed record InventoryIssueSerialInput(long ItemInstanceID);

public sealed record InventoryIssueLineRequest(
    long ItemID,
    decimal Quantity,
    IReadOnlyList<InventoryIssueSerialInput>? Serials,
    string? Remark);

public sealed record InventoryIssueRequest(
    long WarehouseID,
    long WorkOrderID,
    string WorkOrderCode,
    IReadOnlyList<InventoryIssueLineRequest> Items);

public sealed record InventoryAllocationRequest(
    long? WarehouseId,
    IReadOnlyList<long>? SerialInstanceIds,
    IReadOnlyList<long>? StartCustomerWarrantySerialInstanceIds = null);
