namespace LaooMeetingApi.Contracts.Common;

public sealed record ApiErrorResponse(
    string Code,
    string Message,
    string TraceId
);
