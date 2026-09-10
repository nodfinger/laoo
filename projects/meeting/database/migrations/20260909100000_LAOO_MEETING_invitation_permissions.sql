SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @MeetingProjectID bigint =
(
    SELECT TOP (1) ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO_MEETING' AND IsActive=1
    ORDER BY ProjectID
);

IF @MeetingProjectID IS NULL
    THROW 51000, 'Active LAOO_MEETING project was not found.', 1;

DECLARE @Permissions TABLE
(
    ScreenCode nvarchar(50),
    ScreenNameTH nvarchar(200),
    ScreenNameEN nvarchar(200),
    ActionCode nvarchar(50),
    ActionNameTH nvarchar(200),
    ActionNameEN nvarchar(200),
    PRIMARY KEY(ScreenCode,ActionCode)
);

INSERT @Permissions VALUES
(N'21003',N'การเชิญของฉัน',N'My meeting invitations',N'VIEW',N'ดูข้อมูล',N'View'),
(N'21003',N'การเชิญของฉัน',N'My meeting invitations',N'EDIT',N'ตอบรับคำเชิญ',N'Respond');

INSERT dbo.TDADPermission
(
    ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,
    ActionNameTH,ActionNameEN,IsActive,CreatedDate
)
SELECT @MeetingProjectID,P.ScreenCode,P.ScreenNameTH,P.ScreenNameEN,
       P.ActionCode,P.ActionNameTH,P.ActionNameEN,1,SYSDATETIME()
FROM @Permissions P
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADPermission X
    WHERE X.ProjectID=@MeetingProjectID
      AND X.ScreenCode=P.ScreenCode
      AND X.ActionCode=P.ActionCode
);

UPDATE X
SET X.ScreenNameTH=P.ScreenNameTH,
    X.ScreenNameEN=P.ScreenNameEN,
    X.ActionNameTH=P.ActionNameTH,
    X.ActionNameEN=P.ActionNameEN,
    X.IsActive=1,
    X.ModifiedDate=SYSDATETIME()
FROM dbo.TDADPermission X
JOIN @Permissions P
  ON P.ScreenCode=X.ScreenCode AND P.ActionCode=X.ActionCode
WHERE X.ProjectID=@MeetingProjectID;

COMMIT TRANSACTION;
GO
