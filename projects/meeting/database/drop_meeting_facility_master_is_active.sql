/* Approved schema change: TDADMeetingFacility is a name master only.
   Keep TDADMeetingRoomFacility.IsActive; it is the per-room availability flag. */
IF COL_LENGTH('dbo.TDADMeetingFacility', 'IsActive') IS NOT NULL
BEGIN
    DECLARE @constraint sysname;
    DECLARE @sql nvarchar(max);

    IF EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.TDADMeetingFacility')
          AND name = N'IX_TDADMeetingFacility_Company'
    )
    BEGIN
        DROP INDEX IX_TDADMeetingFacility_Company ON dbo.TDADMeetingFacility;
    END;

    SELECT @constraint = dc.name
    FROM sys.default_constraints dc
    INNER JOIN sys.columns col
        ON col.object_id = dc.parent_object_id
       AND col.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = OBJECT_ID(N'dbo.TDADMeetingFacility')
      AND col.name = N'IsActive';

    IF @constraint IS NOT NULL
    BEGIN
        SET @sql = N'ALTER TABLE dbo.TDADMeetingFacility DROP CONSTRAINT ' + QUOTENAME(@constraint) + N';';
        EXEC sys.sp_executesql @sql;
    END;

    ALTER TABLE dbo.TDADMeetingFacility DROP COLUMN IsActive;

    CREATE INDEX IX_TDADMeetingFacility_Company
        ON dbo.TDADMeetingFacility (CompanyID);
END;
