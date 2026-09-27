SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @ProjectID bigint = (
    SELECT ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_MEETING' AND IsActive = 1
);

IF @ProjectID IS NULL
    THROW 51000, 'Active LAOO_MEETING project was not found.', 1;

DECLARE @Permissions TABLE
(
    ActionCode varchar(20) NOT NULL,
    ActionNameTH nvarchar(100) NOT NULL,
    ActionNameEN nvarchar(100) NOT NULL
);

INSERT @Permissions(ActionCode, ActionNameTH, ActionNameEN)
VALUES
    ('VIEW', N'ดูงานเตรียมห้องและอุปกรณ์', N'View room support tasks'),
    ('EDIT', N'ดำเนินงานเตรียมห้องและอุปกรณ์', N'Process room support tasks');

INSERT dbo.TDADPermission
(
    ProjectID, ScreenCode, ScreenNameTH, ScreenNameEN, ActionCode,
    ActionNameTH, ActionNameEN, IsActive, CreatedDate
)
SELECT
    @ProjectID, N'22002', N'งานเตรียมห้องและอุปกรณ์', N'Room support tasks',
    P.ActionCode, P.ActionNameTH, P.ActionNameEN, 1, SYSDATETIME()
FROM @Permissions P
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADPermission X
    WHERE X.ProjectID = @ProjectID
      AND X.ScreenCode = N'22002'
      AND X.ActionCode = P.ActionCode
);

COMMIT TRANSACTION;
GO
