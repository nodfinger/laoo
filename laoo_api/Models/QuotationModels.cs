namespace LaooApi.Models;

public sealed class QuotationUpsertRequest
{
    public long CustomerId { get; init; }
    public DateTime? QuoteDate { get; init; }
    public long? SalespersonEmployeeId { get; init; }
    public string? ContactName { get; init; }
    public int? ValidDays { get; init; }
    public string? SalesType { get; init; }
    public string? PaymentType { get; init; }
    public int? CreditDays { get; init; }
    public decimal VATPercent { get; init; } = 7m;
    public decimal? TotalAmount { get; init; }
    public decimal? DiscountPercent { get; init; }
    public decimal? DiscountAmount { get; init; }
    public decimal? AmountAfterDiscount { get; init; }
    public decimal? TaxPercent { get; init; }
    public decimal? TaxAmount { get; init; }
    public decimal? NetAmount { get; init; }
    public string? StatusCode { get; init; }
    public string? Remark { get; init; }
    public IReadOnlyList<QuotationLineRequest> Items { get; init; } = [];
}

public sealed class QuotationLineRequest
{
    public long ItemId { get; init; }
    public decimal Quantity { get; init; }
    public decimal UnitPrice { get; init; }
    public string? DiscountType { get; init; }
    public decimal DiscountValue { get; init; }
    public decimal DiscountPercent { get; init; }
    public decimal DiscountAmount { get; init; }
}
