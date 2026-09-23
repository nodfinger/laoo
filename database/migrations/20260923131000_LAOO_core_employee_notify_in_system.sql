IF COL_LENGTH(N'dbo.TDADEmployee',N'NotifyInSystem') IS NULL
BEGIN
    ALTER TABLE dbo.TDADEmployee ADD NotifyInSystem bit NOT NULL CONSTRAINT DF_TDADEmployee_NotifyInSystem DEFAULT(1);
END;
