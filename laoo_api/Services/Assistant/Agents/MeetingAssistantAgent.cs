namespace LaooApi.Services.Assistant;

/// <summary>Meeting agent configuration; read-only actions are registered explicitly.</summary>
public static class MeetingAssistantAgent
{
    public static readonly AssistantAgent Definition = new(
        "meeting", "น้องห้องประชุม", "น้องห้องประชุม พร้อมช่วยเหลือเรื่องห้องประชุม",
        [AssistantCapabilities.MeetingAvailability.Id, AssistantCapabilities.MeetingOwnBookings.Id, AssistantCapabilities.MeetingInvitations.Id]);
}
