namespace LaooApi.Models;

public sealed class PreOrderUpsertRequest
{
    public long QuotationId { get; init; }
    public DateTime? PreOrderDate { get; init; }
    public DateTime? ExpectedDate { get; init; }
    public string? ContactName { get; init; }
    public string? ContactPhone { get; init; }
    public decimal DepositAmount { get; init; }
    public decimal PaidAmount { get; init; }
    public string? StatusCode { get; init; }
    public string? Remark { get; init; }
    public IReadOnlyList<PreOrderLineRequest> Items { get; init; } = [];
}

public sealed class PreOrderLineRequest
{
    public long? QuotationDetailId { get; init; }
    public long ItemId { get; init; }
    public decimal Quantity { get; init; }
    public decimal AllocatedQty { get; init; }
    public decimal DeliveredQty { get; init; }
    public decimal UnitPrice { get; init; }
    public string? DiscountType { get; init; }
    public decimal DiscountValue { get; init; }
    public string? StatusCode { get; init; }
    public string? Remark { get; init; }
}
