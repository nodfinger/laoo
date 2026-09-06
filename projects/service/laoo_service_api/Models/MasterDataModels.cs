namespace LaooServiceApi.Models;

public sealed record MasterGroupResponse(string Code, string Name);

public sealed record MasterDataResponse(
    string Code,
    string Name,
    int Seq,
    string? ShortCode);

public sealed record MasterDataRequest(
    string Code,
    string Name,
    int Seq,
    string? ShortCode);
