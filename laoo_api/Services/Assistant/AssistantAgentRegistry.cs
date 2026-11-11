namespace LaooApi.Services.Assistant;

/// <summary>Server-owned agent definitions; registration never grants access to a capability.</summary>
public sealed record AssistantAgent(string Id, string Name, string Greeting, IReadOnlyList<string> CapabilityIds);

public static class AssistantAgentRegistry
{
    public static readonly AssistantAgent Service = ServiceAssistantAgent.Definition;
    public static readonly AssistantAgent Stock = StockAssistantAgent.Definition;
    public static readonly AssistantAgent Meeting = MeetingAssistantAgent.Definition;
    public static readonly AssistantAgent Travel = TravelAssistantAgent.Definition;

    public static IReadOnlyList<AssistantAgent> All { get; } = Array.AsReadOnly(new[] { Service, Stock, Meeting, Travel });

    public static IEnumerable<object> AvailableTo(IReadOnlyCollection<string> allowedCapabilities) =>
        All.Select(agent => new
        {
            id = agent.Id,
            name = agent.Name,
            greeting = agent.Greeting,
            capabilities = agent.CapabilityIds.Where(allowedCapabilities.Contains).ToArray(),
        }).Where(agent => agent.capabilities.Length > 0);
}
