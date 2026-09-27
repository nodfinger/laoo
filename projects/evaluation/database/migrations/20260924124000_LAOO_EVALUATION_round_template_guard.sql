SET XACT_ABORT ON;
BEGIN TRANSACTION;
GO
CREATE OR ALTER TRIGGER dbo.TR_TDEVRound_TemplateSnapshot
ON dbo.TDEVRound
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted I
        JOIN dbo.TDEVTemplate T ON T.EvaluationTemplateID = I.EvaluationTemplateID
        WHERE T.CompanyID <> I.CompanyID OR T.IsActive = 0 OR T.SourceType <> I.SourceType
    )
    BEGIN
        THROW 50001, N'Template must be active and match the evaluation source type.', 1;
    END;

    UPDATE R
       SET TemplateSnapshotJson = COALESCE(Snapshot.JsonValue, N'{"questions":[]}')
    FROM dbo.TDEVRound R
    JOIN inserted I ON I.EvaluationRoundID = R.EvaluationRoundID
    OUTER APPLY
    (
        SELECT CONCAT(N'q', Q.EvaluationTemplateQuestionID) AS id, Q.QuestionText AS text,
               Q.QuestionType AS type, Q.IsRequired AS required,
               JSON_QUERY(COALESCE((SELECT CONCAT(N'o', O.EvaluationTemplateQuestionOptionID) AS id, O.OptionText AS text
                 FROM dbo.TDEVTemplateQuestionOption O WHERE O.EvaluationTemplateQuestionID = Q.EvaluationTemplateQuestionID
                 ORDER BY O.SortOrder FOR JSON PATH), N'[]')) AS options
        FROM dbo.TDEVTemplateQuestion Q
        WHERE Q.EvaluationTemplateID = I.EvaluationTemplateID
        ORDER BY Q.SortOrder
        FOR JSON PATH, ROOT('questions')
    ) Snapshot(JsonValue);
END;
GO
COMMIT;
