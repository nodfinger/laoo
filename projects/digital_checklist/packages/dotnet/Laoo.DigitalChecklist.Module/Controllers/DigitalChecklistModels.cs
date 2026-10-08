namespace Laoo.DigitalChecklist.Controllers;
public sealed record MasterInput(string? MenuCode, string? Code, string Name, long? ParentId, long? DepartmentId, string? Frequency, string? TimesJson, string? Details, string? WeekDaysJson = null, long? ResponsibleEmployeeId = null);
public sealed record InspectionItemInput(long TemplateItemId, string ResultCode, string? Detail);
public sealed record InspectionInput(long TypeId, long? ScheduleId, List<InspectionItemInput> Items, string? Note, long? InspectionId = null);
public sealed record DecisionInput(string? Note);
public sealed record TaskInput(string StatusCode, string? Detail);
public sealed record DigitalChecklistGroupInput(string Code, string Name, long DepartmentId);
public sealed record ChecklistSettingInput(string TimeZoneId, bool NotifyInApp, bool NotifyEmail, int ReminderMinutes, string? ServiceMenuCode);
