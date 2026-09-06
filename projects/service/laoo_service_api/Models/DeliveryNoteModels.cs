namespace LaooServiceApi.Models;

public sealed class DeliveryNoteUpsertRequest
{
    public DateTime? DeliveryDate { get; init; }
    public string? ReferenceType { get; init; }
    public long? ReferenceId { get; init; }
    public long CustomerId { get; init; }
    public string? ContactName { get; init; }
    public string? ContactPhone { get; init; }
    public string? DeliveryAddress { get; init; }
    public string? TransportBy { get; init; }
    public string? TrackingNo { get; init; }
    public string? Remark { get; init; }
    public IReadOnlyList<DeliveryNoteLineRequest> Items { get; init; } = [];
}

public sealed class DeliveryNoteLineRequest
{
    public long ItemId { get; init; }
    public long? QuotationDetailId { get; init; }
    public long? PreOrderDetailId { get; init; }
    public long? ParentDeliveryNoteDetailId { get; init; }
    public decimal OrderedQty { get; init; }
    public decimal PreviouslyDeliveredQty { get; init; }
    public decimal DeliveryQty { get; init; }
    public decimal UnitPrice { get; init; }
    public string? Remark { get; init; }
}
