namespace LaooApi.Services.Assistant;

/// <summary>Read-only summaries for travel claims within the caller's permitted scope.</summary>
public static class TravelAssistantAgent
{
    public static readonly AssistantAgent Definition = new(
        "travel", "น้องการเดินทาง", "น้องการเดินทาง พร้อมช่วยสรุปค่าเดินทาง",
        [AssistantCapabilities.TravelClaimSummary.Id]);
}
