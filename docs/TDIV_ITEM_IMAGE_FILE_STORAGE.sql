/* Switch product images from database binary storage to API server files. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.TDIVItemImage', N'U') IS NULL
    THROW 51001, 'dbo.TDIVItemImage ยังไม่มี กรุณารัน docs/TDIV_ITEM_SCHEMA.sql ก่อน', 1;
GO

IF COL_LENGTH(N'dbo.TDIVItemImage', N'FilePath') IS NULL
    ALTER TABLE dbo.TDIVItemImage ADD FilePath NVARCHAR(500) NULL;
GO

/* Keep old ImageData nullable for backward compatibility and migration fallback. */
IF EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.TDIVItemImage')
      AND name = N'ImageData'
      AND is_nullable = 0
)
    ALTER TABLE dbo.TDIVItemImage ALTER COLUMN ImageData VARBINARY(MAX) NULL;
GO

/* New rows use FilePath. Existing ImageData rows remain readable until migrated. */
IF NOT EXISTS
(
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_TDIVItemImage_Storage'
      AND parent_object_id = OBJECT_ID(N'dbo.TDIVItemImage')
)
    ALTER TABLE dbo.TDIVItemImage ADD CONSTRAINT CK_TDIVItemImage_Storage CHECK (FilePath IS NOT NULL OR ImageData IS NOT NULL);
GO
