using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace LaooApi.Services.Assistant;

/// <summary>Calls only an explicit IPv4 loopback address, never a remote model.</summary>
public sealed class LocalAssistantModel(IConfiguration configuration)
{
    public async Task<string?> InterpretAsync(string prompt, CancellationToken cancellationToken)
    {
        var model = configuration["Assistant:Model"]?.Trim();
        if (string.IsNullOrEmpty(model)) return null;
        var raw = configuration["Assistant:Endpoint"] ?? "http://127.0.0.1:11434";
        if (!Uri.TryCreate(raw, UriKind.Absolute, out var endpoint) ||
            endpoint.Scheme != Uri.UriSchemeHttp || endpoint.Host != "127.0.0.1" ||
            !string.IsNullOrEmpty(endpoint.UserInfo) || endpoint.AbsolutePath != "/" ||
            !string.IsNullOrEmpty(endpoint.Query) || !string.IsNullOrEmpty(endpoint.Fragment))
            throw new InvalidOperationException("Local assistant endpoint must be an HTTP IPv4 loopback origin.");
        if (string.IsNullOrWhiteSpace(prompt) || prompt.Length > 4000)
            throw new ArgumentException("Invalid assistant prompt.", nameof(prompt));

        using var handler = new HttpClientHandler { AllowAutoRedirect = false, UseProxy = false };
        using var client = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(90) };
        using var response = await client.PostAsJsonAsync(new Uri(endpoint, "/api/generate"), new
        {
            model,
            prompt,
            stream = false,
            think = false,
            options = new { num_predict = 128, num_ctx = 2048, temperature = 0 }
        }, cancellationToken);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var json = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        if (!json.RootElement.TryGetProperty("response", out var text) || text.ValueKind != JsonValueKind.String)
            return null;
        var result = text.GetString();
        return result is { Length: <= 8000 } ? result : null;
    }
}
