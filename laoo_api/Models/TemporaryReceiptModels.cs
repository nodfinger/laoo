namespace LaooApi.Models;

public sealed class TemporaryReceiptUpsertRequest
{
    public DateTime? ReceiptDate { get; init; }
    public long? QuotationId { get; init; }
    public long? PreOrderId { get; init; }
    public long CustomerId { get; init; }
    public string? ContactName { get; init; }
    public string? ReceivedFrom { get; init; }
    public string? StatusCode { get; init; }
    public string? Remark { get; init; }
    public IReadOnlyList<TemporaryReceiptPaymentRequest> Payments { get; init; } = [];
}

public sealed class TemporaryReceiptPaymentRequest
{
    public string? PaymentMethodCode { get; init; }
    public decimal Amount { get; init; }
    public string? BankCode { get; init; }
    public string? BankAccountName { get; init; }
    public string? ReferenceNo { get; init; }
    public string? ChequeNo { get; init; }
    public DateTime? ChequeDate { get; init; }
    public string? Remark { get; init; }
}
