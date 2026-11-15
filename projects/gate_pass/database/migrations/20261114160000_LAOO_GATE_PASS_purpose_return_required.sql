IF COL_LENGTH(N'dbo.TDGPPurpose',N'AlwaysReturnRequired') IS NULL
    ALTER TABLE dbo.TDGPPurpose ADD AlwaysReturnRequired bit NOT NULL
        CONSTRAINT DF_TDGPPurpose_AlwaysReturnRequired DEFAULT(0) WITH VALUES;
