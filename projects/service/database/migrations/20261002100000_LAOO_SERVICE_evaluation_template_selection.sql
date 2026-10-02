/* Service owns the selected evaluation template; Evaluation remains the template/round owner. */
BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.TDADServiceRequest', N'EvaluationTemplateID') IS NULL
        ALTER TABLE dbo.TDADServiceRequest ADD EvaluationTemplateID bigint NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.TDADServiceRequest')
          AND name = N'IX_TDADServiceRequest_Company_EvaluationTemplate'
    )
        EXEC(N'CREATE INDEX IX_TDADServiceRequest_Company_EvaluationTemplate
            ON dbo.TDADServiceRequest(CompanyID, EvaluationTemplateID)
            WHERE EvaluationTemplateID IS NOT NULL;');

    DECLARE @ServiceProjectID bigint =
    (
        SELECT ProjectID
        FROM dbo.TDADProject
        WHERE ProjectCode = N'LAOO_SERVICE'
    );

    UPDATE dbo.TDADProjectMenu
       SET IsActive = 0,
           UpdateDate = SYSUTCDATETIME()
     WHERE ProjectID = @ServiceProjectID
       AND MenuCode IN (N'14001', N'19003', N'20005')
       AND IsActive = 1;

    UPDATE dbo.TDADMainMenu
       SET IsActive = 0,
           IsVisible = 0,
           UpdateDate = SYSUTCDATETIME()
     WHERE MenuCode IN (N'19003', N'20005')
       AND (IsActive = 1 OR IsVisible = 1);

    UPDATE dbo.TDADPermission
       SET IsActive = 0,
           ModifiedDate = SYSUTCDATETIME()
     WHERE ProjectID = @ServiceProjectID
       AND ScreenCode IN (N'14001', N'19003', N'20005')
       AND IsActive = 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
