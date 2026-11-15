IF COL_LENGTH(N'dbo.TDGPSetting', N'DefaultQrExpiryDays') IS NULL
BEGIN
    ALTER TABLE dbo.TDGPSetting ADD DefaultQrExpiryDays int NOT NULL
        CONSTRAINT DF_TDGPSetting_DefaultQrExpiryDays DEFAULT (1) WITH VALUES;
END;
IF OBJECT_ID(N'dbo.CK_TDGPSetting_DefaultQrExpiryDays', N'C') IS NULL
    EXEC(N'ALTER TABLE dbo.TDGPSetting ADD CONSTRAINT CK_TDGPSetting_DefaultQrExpiryDays CHECK (DefaultQrExpiryDays BETWEEN 1 AND 365)');
