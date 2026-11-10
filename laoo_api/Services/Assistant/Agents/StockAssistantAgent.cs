namespace LaooApi.Services.Assistant;

/// <summary>Stock capabilities still require company, package and menu authorization.</summary>
public static class StockAssistantAgent
{
    public static readonly AssistantAgent Definition = new(
        "stock", "น้องสต๊อก", "น้องสต๊อก พร้อมช่วยเหลือ", Array.AsReadOnly(new[] { AssistantCapabilities.SerialLookup.Id }));
}
