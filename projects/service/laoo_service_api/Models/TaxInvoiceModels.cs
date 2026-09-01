namespace LaooServiceApi.Models;

public sealed class TaxInvoiceUpsertRequest
{
    public DateTime? TaxInvoiceDate { get; init; }
    public string? ReferenceType { get; init; }
    public long? ReferenceId { get; init; }
    public long CustomerId { get; init; }
    public string? ContactName { get; init; }
    public string? ContactPhone { get; init; }
    public string? ContactEmail { get; init; }
    public string? PaymentType { get; init; }
    public int CreditDays { get; init; }
    public decimal DiscountPercent { get; init; }
    public decimal DiscountAmount { get; init; }
    public decimal TaxPercent { get; init; } = 7;
    public string? Remark { get; init; }
    public IReadOnlyList<TaxInvoiceLineRequest> Items { get; init; } = [];
}

public sealed class TaxInvoiceLineRequest
{
    public long ItemId { get; init; }
    public long? QuotationDetailId { get; init; }
    public long? PreOrderDetailId { get; init; }
    public decimal Quantity { get; init; }
    public decimal UnitPrice { get; init; }
    public string? DiscountType { get; init; }
    public decimal DiscountPercent { get; init; }
    public decimal DiscountAmount { get; init; }
    public string? Remark { get; init; }
}
