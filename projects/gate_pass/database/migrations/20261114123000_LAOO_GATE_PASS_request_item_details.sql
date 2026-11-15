IF COL_LENGTH(N'dbo.TDGPGatePass', N'DocumentDateTime') IS NULL
    ALTER TABLE dbo.TDGPGatePass ADD DocumentDateTime datetime2(3) NULL;
IF COL_LENGTH(N'dbo.TDGPGatePass', N'PlannedExitDate') IS NULL
    ALTER TABLE dbo.TDGPGatePass ADD PlannedExitDate date NULL;
IF COL_LENGTH(N'dbo.TDGPGatePass', N'CarrierPhone') IS NULL
    ALTER TABLE dbo.TDGPGatePass ADD CarrierPhone nvarchar(40) NULL;
IF COL_LENGTH(N'dbo.TDGPGatePassAttachment', N'GatePassItemID') IS NULL
    ALTER TABLE dbo.TDGPGatePassAttachment ADD GatePassItemID bigint NULL;
IF COL_LENGTH(N'dbo.TDGPGatePassItem', N'IsReturnRequired') IS NULL
BEGIN
    ALTER TABLE dbo.TDGPGatePassItem ADD IsReturnRequired bit NULL;
    EXEC(N'UPDATE i SET IsReturnRequired=g.IsReturnRequired FROM dbo.TDGPGatePassItem i JOIN dbo.TDGPGatePass g ON g.GatePassID=i.GatePassID AND g.CompanyID=i.CompanyID WHERE i.IsReturnRequired IS NULL');
    EXEC(N'ALTER TABLE dbo.TDGPGatePassItem ALTER COLUMN IsReturnRequired bit NOT NULL');
    EXEC(N'ALTER TABLE dbo.TDGPGatePassItem ADD CONSTRAINT DF_TDGPGatePassItem_Return DEFAULT (0) FOR IsReturnRequired');
END;
EXEC(N'UPDATE dbo.TDGPGatePass SET DocumentDateTime=CreateDate WHERE DocumentDateTime IS NULL');
IF OBJECT_ID(N'dbo.TDGPGatePassRequestFile',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDGPGatePassRequestFile(
        RequestFileID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDGPGatePassRequestFile PRIMARY KEY,
        CompanyID bigint NOT NULL,
        GatePassID bigint NOT NULL,
        GatePassItemID bigint NULL,
        FileName nvarchar(255) NOT NULL,
        ContentType nvarchar(100) NOT NULL,
        FileData varbinary(max) NOT NULL,
        CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDGPGatePassRequestFile_CreateDate DEFAULT SYSUTCDATETIME(),
        CreateBy bigint NOT NULL,
        CONSTRAINT FK_TDGPGatePassRequestFile_Header FOREIGN KEY(GatePassID) REFERENCES dbo.TDGPGatePass(GatePassID) ON DELETE CASCADE,
        CONSTRAINT FK_TDGPGatePassRequestFile_Item FOREIGN KEY(GatePassItemID) REFERENCES dbo.TDGPGatePassItem(GatePassItemID)
    );
    CREATE INDEX IX_TDGPGatePassRequestFile_Header ON dbo.TDGPGatePassRequestFile(CompanyID,GatePassID,GatePassItemID);
END;
