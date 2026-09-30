SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;

UPDATE dbo.TDGPSetting
SET MaxAttachmentSizeMB=1,
    UpdateDate=SYSUTCDATETIME()
WHERE MaxAttachmentSizeMB<>1;

DECLARE @defaultName sysname;
SELECT @defaultName=dc.name
FROM sys.default_constraints dc
JOIN sys.columns c
  ON c.object_id=dc.parent_object_id
 AND c.column_id=dc.parent_column_id
WHERE dc.parent_object_id=OBJECT_ID(N'dbo.TDGPSetting')
  AND c.name=N'MaxAttachmentSizeMB';

IF @defaultName IS NOT NULL
BEGIN
    DECLARE @dropDefaultSql nvarchar(1000)=
        N'ALTER TABLE dbo.TDGPSetting DROP CONSTRAINT '+QUOTENAME(@defaultName);
    EXEC sys.sp_executesql @dropDefaultSql;
END;

ALTER TABLE dbo.TDGPSetting ADD CONSTRAINT DF_TDGPSetting_MaxAttachmentMB
    DEFAULT(1) FOR MaxAttachmentSizeMB;

IF NOT EXISTS(
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.TDGPSetting')
      AND name=N'CK_TDGPSetting_MaxAttachmentMB')
    ALTER TABLE dbo.TDGPSetting ADD CONSTRAINT CK_TDGPSetting_MaxAttachmentMB
        CHECK(MaxAttachmentSizeMB>0 AND MaxAttachmentSizeMB<=1);

COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
