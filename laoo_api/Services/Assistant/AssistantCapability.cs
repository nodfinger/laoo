namespace LaooApi.Services.Assistant;

// Capabilities are server-owned: a model response can select an identifier,
// but it cannot supply a route, company, menu, action, or SQL statement.
public sealed record AssistantCapability(string Id, string ProjectCode, string MenuCode, int ScreenType, string Action);

public static class AssistantCapabilities
{
    public static readonly AssistantCapability CreateOwnRepair = new("repair.create_own", "LAOO_SERVICE", "20001", 1, "CREATE");
    public static readonly AssistantCapability TrackOwnRepair = new("repair.track_own", "LAOO_SERVICE", "20002", 3, "VIEW");
    public static readonly AssistantCapability RepairPartsCost = new("repair.parts_cost", "LAOO_SERVICE", "19002", 3, "VIEW");
    public static readonly AssistantCapability PendingRepair = new("repair.pending", "LAOO_SERVICE", "17001", 2, "VIEW");
    public static readonly AssistantCapability SerialLookup = new("stock.serial_lookup", "LAOO_STOCK", "08006", 3, "VIEW");
    public static readonly AssistantCapability SerialRepairHistory = new("repair.serial_history", "LAOO_SERVICE", "19002", 3, "VIEW");
    public static readonly AssistantCapability MeetingAvailability = new("meeting.availability", "LAOO_MEETING", "21001", 1, "VIEW");
    public static readonly AssistantCapability MeetingOwnBookings = new("meeting.own_bookings", "LAOO_MEETING", "21001", 1, "VIEW");
    public static readonly AssistantCapability MeetingInvitations = new("meeting.invitations", "LAOO_MEETING", "21003", 2, "VIEW");
    public static readonly AssistantCapability MenuGuide = new("core.menu_guide", "LAOO_AI", "10008", 1, "VIEW");
    public static IReadOnlyList<AssistantCapability> All { get; } = Array.AsReadOnly([CreateOwnRepair, TrackOwnRepair, RepairPartsCost, PendingRepair, SerialLookup, SerialRepairHistory, MeetingAvailability, MeetingOwnBookings, MeetingInvitations, MenuGuide]);

    public static AssistantCapability? Find(string? id) => All.FirstOrDefault(x => x.Id == id);
}
