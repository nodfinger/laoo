SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF OBJECT_ID(N'dbo.TDIVItemPackUnit', N'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.TDIVItemPackUnit')
          AND name = N'UX_TDIVItemPackUnit_Default'
    )
        DROP INDEX UX_TDIVItemPackUnit_Default ON dbo.TDIVItemPackUnit;

    IF OBJECT_ID(N'dbo.DF_TDIVItemPackUnit_IsActive', N'D') IS NOT NULL
        ALTER TABLE dbo.TDIVItemPackUnit DROP CONSTRAINT DF_TDIVItemPackUnit_IsActive;

    IF COL_LENGTH(N'dbo.TDIVItemPackUnit', N'IsActive') IS NOT NULL
        ALTER TABLE dbo.TDIVItemPackUnit DROP COLUMN IsActive;

    CREATE UNIQUE INDEX UX_TDIVItemPackUnit_Default
        ON dbo.TDIVItemPackUnit(ItemID)
        WHERE IsDefault = 1;
END;
GO
