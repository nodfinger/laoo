IF OBJECT_ID(N'dbo.TDADMeetingDisplayBackground', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingDisplayBackground (
        CompanyID bigint NOT NULL,
        SlotNo tinyint NOT NULL,
        Orientation varchar(10) NOT NULL,
        ImageData varbinary(max) NULL,
        ContentType varchar(20) NULL,
        UpdateBy bigint NULL,
        UpdateDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_TDADMeetingDisplayBackground PRIMARY KEY (CompanyID, SlotNo),
        CONSTRAINT CK_TDADMeetingDisplayBackground_Slot CHECK (SlotNo BETWEEN 1 AND 10),
        CONSTRAINT CK_TDADMeetingDisplayBackground_Orientation CHECK (Orientation IN ('PORTRAIT', 'LANDSCAPE'))
    );
END;
