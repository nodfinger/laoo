namespace Laoo.Shared.Contracts.Evaluations;

/// <summary>
/// Immutable source payload used to create an evaluation draft without exposing
/// source-module tables to the evaluation module.
/// </summary>
public sealed record EvaluationSourceCompletedContract(
    long CompanyId,
    string SourceProjectCode,
    string SourceType,
    long ReferenceEntityId,
    string ReferenceTitleSnapshot,
    DateTime CompletedAtUtc,
    IReadOnlyCollection<long> RespondentUserIds,
    long? EvaluationTemplateId = null);

public static class EvaluationSourceTypes
{
    public const string TrainingCourse = "TRAINING_COURSE";
    public const string TrainingInstructor = "TRAINING_INSTRUCTOR";
    public const string MeetingRoom = "MEETING_ROOM";
    public const string Service = "SERVICE";
}

public interface IEvaluationSourceCompletedPublisher
{
    Task PublishAsync(
        EvaluationSourceCompletedContract source,
        CancellationToken cancellationToken = default);
}
