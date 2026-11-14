IF OBJECT_ID(N'dbo.TDADMeetingDisplayVisibility', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingDisplayVisibility (
        CompanyID bigint NOT NULL PRIMARY KEY,
        PrivateSubject bit NOT NULL DEFAULT 0,
        ShowRequester bit NOT NULL DEFAULT 0,
        ShowDepartment bit NOT NULL DEFAULT 0,
        ShowActivityType bit NOT NULL DEFAULT 0,
        ShowAttendeeCount bit NOT NULL DEFAULT 0,
        ShowSubject bit NOT NULL DEFAULT 0,
        ShowDetails bit NOT NULL DEFAULT 0,
        ShowRemark bit NOT NULL DEFAULT 0,
        UpdateBy bigint NULL,
        UpdateDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME()
    );
END;
