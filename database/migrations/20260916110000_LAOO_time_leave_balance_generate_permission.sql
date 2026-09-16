/* Core-owned permission extension for LAOO_TIME leave balances. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
BEGIN TRANSACTION;

DECLARE @TimeProjectID bigint =
(
    SELECT ProjectID FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO_TIME' AND IsActive=1
);
IF @TimeProjectID IS NULL
    THROW 52890,N'Active LAOO_TIME project is required.',1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADMainMenu
    WHERE MenuCode=N'28011'
      AND ScreenType=3
      AND RouteName=N'timeLeaveBalances'
      AND RoutePath=N'/company/time-leave-balances'
)
    THROW 52891,N'LAOO_TIME leave balance menu 28011 must be bootstrapped first.',1;

UPDATE dbo.TDADPermission
SET ScreenNameTH=N'สิทธิ์ลาคงเหลือ',
    ScreenNameEN=N'Leave balances',
    ActionNameTH=N'ประมวลผลสิทธิ์ลาคงเหลือ',
    ActionNameEN=N'Generate leave balances',
    IsActive=1,
    ModifiedDate=SYSUTCDATETIME()
WHERE ProjectID=@TimeProjectID
  AND ScreenCode=N'28011'
  AND ActionCode=N'GENERATE';

INSERT dbo.TDADPermission
(
    ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,
    ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate
)
SELECT @TimeProjectID,N'28011',N'สิทธิ์ลาคงเหลือ',N'Leave balances',
       N'GENERATE',N'ประมวลผลสิทธิ์ลาคงเหลือ',N'Generate leave balances',1,SYSUTCDATETIME()
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADPermission
    WHERE ProjectID=@TimeProjectID
      AND ScreenCode=N'28011'
      AND ActionCode=N'GENERATE'
);

COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
GO
