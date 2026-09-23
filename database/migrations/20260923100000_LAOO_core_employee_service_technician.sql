IF COL_LENGTH(N'dbo.TDADEmployee',N'IsServiceTechnician') IS NULL
BEGIN
    ALTER TABLE dbo.TDADEmployee ADD IsServiceTechnician bit NOT NULL CONSTRAINT DF_TDADEmployee_IsServiceTechnician DEFAULT(0);
END
