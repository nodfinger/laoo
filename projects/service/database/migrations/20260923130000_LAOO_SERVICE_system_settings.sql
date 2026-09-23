SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDSTCompanySetupSystemService', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDSTCompanySetupSystemService
    (
        CompanyID bigint NOT NULL,
        ProjectID bigint NOT NULL,
        ServiceEnabled bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_Enabled DEFAULT(1),
        AllowWalkIn bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_WalkIn DEFAULT(1),
        RequireEquipment bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_Equipment DEFAULT(1),
        AttachmentRequired bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_Attachment DEFAULT(0),
        WorkflowEnabled bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_Workflow DEFAULT(1),
        AttachmentMaxBytes int NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_AttachmentMax DEFAULT(1048576),
        CreateBy bigint NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_CreateDate DEFAULT(SYSUTCDATETIME()),
        UpdateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        CONSTRAINT PK_TDSTCompanySetupSystemService PRIMARY KEY(CompanyID,ProjectID),
        CONSTRAINT CK_TDSTCompanySetupSystemService_AttachmentMax CHECK(AttachmentMaxBytes=1048576)
    );
END;

IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService',N'ServiceEnabled') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD ServiceEnabled bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_Enabled DEFAULT(1);
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService',N'AllowWalkIn') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD AllowWalkIn bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_WalkIn DEFAULT(1);
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService',N'RequireEquipment') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD RequireEquipment bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_Equipment DEFAULT(1);
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService',N'AttachmentRequired') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD AttachmentRequired bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_Attachment DEFAULT(0);
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService',N'WorkflowEnabled') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD WorkflowEnabled bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_Workflow DEFAULT(1);
IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemService',N'AttachmentMaxBytes') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemService ADD AttachmentMaxBytes int NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemService_AttachmentMax DEFAULT(1048576);
