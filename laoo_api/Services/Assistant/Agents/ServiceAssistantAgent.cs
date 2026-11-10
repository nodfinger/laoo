namespace LaooApi.Services.Assistant;

/// <summary>Capabilities are identifiers only; executing them requires the normal authorization checks.</summary>
public static class ServiceAssistantAgent
{
    public static readonly AssistantAgent Definition = new(
        "service", "น้องบริการ", "น้องบริการ พร้อมช่วยเหลืองานซ่อม",
        Array.AsReadOnly(new[]
        {
            AssistantCapabilities.CreateOwnRepair.Id,
            AssistantCapabilities.TrackOwnRepair.Id,
            AssistantCapabilities.RepairPartsCost.Id,
            AssistantCapabilities.PendingRepair.Id,
            AssistantCapabilities.SerialRepairHistory.Id,
        }));
}
