SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDADServiceRequest', N'U') IS NULL OR OBJECT_ID(N'dbo.TDSTMasterCont', N'U') IS NULL
    THROW 53700, N'Required service request or constant table is missing.', 1;

IF EXISTS (SELECT 1 FROM dbo.TDSTMasterCont WHERE GroupCode IN (N'006', N'007'))
    THROW 53701, N'Constant group 006 or 007 is already in use; migration stopped.', 1;

IF COL_LENGTH(N'dbo.TDADServiceRequest', N'PriorityCode') IS NOT NULL OR COL_LENGTH(N'dbo.TDADServiceRequest', N'RequestChannelCode') IS NOT NULL
    THROW 53702, N'Service request columns already exist; migration stopped.', 1;

ALTER TABLE dbo.TDADServiceRequest ADD PriorityCode nvarchar(1) NOT NULL
    CONSTRAINT DF_ServiceRequest_PriorityCode DEFAULT (N'0') WITH VALUES;
ALTER TABLE dbo.TDADServiceRequest ADD RequestChannelCode nvarchar(1) NULL;

INSERT dbo.TDSTMasterCont (GroupCode, Code, Name, Seq) VALUES
    (N'006', N'0', N'ปกติ', 0),
    (N'006', N'1', N'ด่วน', 1),
    (N'006', N'2', N'ด่วนมาก', 2),
    (N'007', N'0', N'แจ้งเองผ่านหน้าจอ', 0),
    (N'007', N'1', N'แจ้งแทน', 1),
    (N'007', N'2', N'แจ้งเองผ่าน AI', 2);
