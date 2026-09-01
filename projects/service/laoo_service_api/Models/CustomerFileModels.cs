namespace LaooServiceApi.Models;

public sealed record CustomerFileRow(
    long CustomerFileID,
    long CustomerID,
    string FileType,
    string OriginalFileName,
    string Extension,
    string? ContentType,
    long FileSize,
    DateTime CreateDate,
    string? Description);

public sealed record CustomerFileUpdateRequest(string? Description);
