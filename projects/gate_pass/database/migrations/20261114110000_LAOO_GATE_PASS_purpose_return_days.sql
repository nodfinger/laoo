IF COL_LENGTH(N'dbo.TDGPPurpose', N'ReturnDays') IS NULL
BEGIN
    ALTER TABLE dbo.TDGPPurpose ADD ReturnDays int NULL;
    EXEC(N'UPDATE P SET ReturnDays=COALESCE(S.DefaultReturnDays,7) FROM dbo.TDGPPurpose P LEFT JOIN dbo.TDGPSetting S ON S.CompanyID=P.CompanyID WHERE P.ReturnDays IS NULL');
    EXEC(N'ALTER TABLE dbo.TDGPPurpose ALTER COLUMN ReturnDays int NOT NULL');
    EXEC(N'ALTER TABLE dbo.TDGPPurpose ADD CONSTRAINT DF_TDGPPurpose_ReturnDays DEFAULT (7) FOR ReturnDays');
    EXEC(N'ALTER TABLE dbo.TDGPPurpose ADD CONSTRAINT CK_TDGPPurpose_ReturnDays CHECK (ReturnDays BETWEEN 1 AND 365)');
END;
