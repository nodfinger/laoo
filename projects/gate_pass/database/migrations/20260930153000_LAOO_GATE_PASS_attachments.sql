SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDGPSetting',N'MaxAttachmentSizeMB') IS NULL
    ALTER TABLE dbo.TDGPSetting ADD MaxAttachmentSizeMB decimal(6,2) NOT NULL
        CONSTRAINT DF_TDGPSetting_MaxAttachmentMB DEFAULT(2);

IF COL_LENGTH(N'dbo.TDGPSetting',N'MaxAttachmentsPerStage') IS NULL
    ALTER TABLE dbo.TDGPSetting ADD MaxAttachmentsPerStage int NOT NULL
        CONSTRAINT DF_TDGPSetting_MaxAttachments DEFAULT(5);

IF OBJECT_ID(N'dbo.TDGPGatePassAttachment',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDGPGatePassAttachment(
        GatePassAttachmentID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDGPGatePassAttachment PRIMARY KEY,
        CompanyID bigint NOT NULL,
        GatePassID bigint NOT NULL,
        StageCode nvarchar(20) NOT NULL,
        OriginalFileName nvarchar(255) NOT NULL,
        StoredPath nvarchar(1000) NOT NULL,
        ContentType nvarchar(100) NOT NULL,
        FileSizeBytes bigint NOT NULL,
        Width int NULL,
        Height int NULL,
        CreateDate datetime2(3) NOT NULL
            CONSTRAINT DF_TDGPGatePassAttachment_Create DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NOT NULL,
        CONSTRAINT FK_TDGPGatePassAttachment_Header FOREIGN KEY(GatePassID)
            REFERENCES dbo.TDGPGatePass(GatePassID) ON DELETE CASCADE,
        CONSTRAINT CK_TDGPGatePassAttachment_Stage CHECK(
            StageCode IN(N'REQUEST',N'HANDOVER',N'EXIT',N'RETURN')),
        CONSTRAINT CK_TDGPGatePassAttachment_Size CHECK(FileSizeBytes>0)
    );
    CREATE INDEX IX_TDGPGatePassAttachment_Header
        ON dbo.TDGPGatePassAttachment(CompanyID,GatePassID,StageCode,CreateDate);
END;

COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
