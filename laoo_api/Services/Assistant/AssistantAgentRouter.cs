namespace LaooApi.Services.Assistant;

/// <summary>
/// Server-owned coordinator: maps approved capability identifiers to agents.
/// It never grants permissions, calls an action, or accepts routes or SQL from a model.
/// </summary>
public static class AssistantAgentRouter
{
    public static IReadOnlyList<AssistantAgent> Resolve(
        IEnumerable<string> requestedCapabilities,
        IReadOnlyCollection<string> allowedCapabilities)
    {
        var requested = requestedCapabilities
            .Where(code => AssistantCapabilities.Find(code) is not null && allowedCapabilities.Contains(code))
            .ToHashSet(StringComparer.Ordinal);
        return AssistantAgentRegistry.All
            .Where(agent => agent.CapabilityIds.Any(requested.Contains))
            .ToArray();
    }
}
