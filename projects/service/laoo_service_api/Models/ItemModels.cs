namespace LaooServiceApi.Models;

public sealed record ItemListRow(
    long ItemID,
    string ItemCode,
    string ItemName,
    string ItemGroupCode,
    string ItemTypeCode,
    decimal UnitPrice,
    string UnitCode,
    decimal StockBalance,
    decimal MinStock,
    decimal PurchaseQuantity,
    string? OrderCode,
    string? OrderLink1,
    string? OrderLink2,
    bool IsActive,
    bool ShowShop,
    long? CoverImageID,
    string? CoverImageBase64);

public sealed record ItemPackUnitRow(
    long? ItemPackUnitID,
    string UnitCode,
    string? ParentUnitCode,
    decimal ConversionQuantity,
    decimal BaseQuantity,
    bool IsDefault,
    int SortOrder,
    string? UnitName = null,
    string? ParentUnitName = null);

public sealed record ItemImageRow(
    long ItemImageID,
    string ContentType,
    string? FileName,
    bool IsCover,
    int SortOrder,
    string ImageDataBase64);

public sealed record ItemDetail(
    long ItemID,
    string ItemCode,
    string ItemName,
    string ItemGroupCode,
    string ItemTypeCode,
    decimal UnitPrice,
    string UnitCode,
    decimal CostPrice,
    decimal StockBalance,
    decimal MinStock,
    decimal PurchaseQuantity,
    string? RemarkItem1,
    string? Note1,
    string? Note2,
    string? Note3,
    string? Note4,
    string? Note5,
    string? OrderCode,
    string? OrderLink1,
    string? OrderLink2,
    bool IsActive,
    bool ShowShop,
    IReadOnlyList<ItemPackUnitRow> PackUnits,
    IReadOnlyList<ItemImageRow> Images);

public sealed record ItemUpsertRequest(
    string ItemCode,
    string ItemName,
    string ItemGroupCode,
    string ItemTypeCode,
    decimal UnitPrice,
    string UnitCode,
    decimal CostPrice,
    decimal MinStock,
    decimal PurchaseQuantity,
    string? RemarkItem1,
    string? Note1,
    string? Note2,
    string? Note3,
    string? Note4,
    string? Note5,
    string? OrderCode,
    string? OrderLink1,
    string? OrderLink2,
    bool IsActive,
    bool ShowShop,
    IReadOnlyList<ItemPackUnitRow>? PackUnits,
    IReadOnlyList<ItemImageUpload>? Images);

public sealed record ItemImageUpload(
    string ContentType,
    string? FileName,
    bool IsCover,
    int SortOrder,
    string ImageDataBase64);

public sealed record ItemVisibilityRequest(bool IsActive, bool ShowShop);

public sealed record ItemCodePreviewRequest(string? ItemGroupCode, string? ItemTypeCode);

public sealed record ItemPackUnitsRequest(IReadOnlyList<ItemPackUnitRow> Items);

public sealed record ItemPriceRow(
    string PriceLevelCode,
    string PriceLevelName,
    decimal? SalePrice);

public sealed record ItemPricesRequest(IReadOnlyList<ItemPriceInput> Items);

public sealed record ItemPriceInput(string PriceLevelCode, decimal SalePrice);
