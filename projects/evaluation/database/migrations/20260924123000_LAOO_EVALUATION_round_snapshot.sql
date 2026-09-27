SET XACT_ABORT ON;
BEGIN TRANSACTION;
GO
CREATE OR ALTER TRIGGER dbo.TR_TDEVRound_TemplateSnapshot
ON dbo.TDEVRound
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE R
       SET TemplateSnapshotJson = COALESCE(Snapshot.JsonValue, N'{"questions":[]}')
    FROM dbo.TDEVRound R
    JOIN inserted I ON I.EvaluationRoundID = R.EvaluationRoundID
    OUTER APPLY
    (
        SELECT
            CONCAT(N'q', Q.EvaluationTemplateQuestionID) AS id,
            Q.QuestionText AS text,
            Q.QuestionType AS type,
            Q.IsRequired AS required,
            JSON_QUERY(COALESCE((
                SELECT CONCAT(N'o', O.EvaluationTemplateQuestionOptionID) AS id, O.OptionText AS text
                FROM dbo.TDEVTemplateQuestionOption O
                WHERE O.EvaluationTemplateQuestionID = Q.EvaluationTemplateQuestionID
                ORDER BY O.SortOrder
                FOR JSON PATH
            ), N'[]')) AS options
        FROM dbo.TDEVTemplateQuestion Q
        WHERE Q.EvaluationTemplateID = I.EvaluationTemplateID
        ORDER BY Q.SortOrder
        FOR JSON PATH, ROOT('questions')
    ) Snapshot(JsonValue);
END;
GO
COMMIT;
