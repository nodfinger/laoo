SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (SELECT 1 FROM dbo.TDSTMasterGroup WHERE Code = N'016' AND ISNULL(Name,N'') <> N'ระดับตำแหน่งงาน')
    THROW 54050, N'Master group code 016 is already in use.', 1;
IF EXISTS (SELECT 1 FROM dbo.TDSTMasterGroup WHERE Name = N'ระดับตำแหน่งงาน' AND ISNULL(Code,N'') <> N'016')
    THROW 54051, N'Job position level master group already exists under another code.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMasterGroup WHERE Code = N'016')
    INSERT dbo.TDSTMasterGroup(Code, Name) VALUES (N'016', N'ระดับตำแหน่งงาน');
