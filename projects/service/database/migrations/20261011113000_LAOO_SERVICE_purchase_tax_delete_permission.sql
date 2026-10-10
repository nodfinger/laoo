SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
IF @ProjectID IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'09010' AND ScreenType=4)
    THROW 59130,N'Purchase tax invoice menu contract is missing',1;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
SELECT @ProjectID,N'09010',M.MenuName,N'Purchase tax invoice',N'DELETE',N'ลบ',N'Delete',1,SYSUTCDATETIME()
FROM dbo.TDADMainMenu M
WHERE M.MenuCode=N'09010'
AND NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@ProjectID AND P.ScreenCode=N'09010' AND P.ActionCode=N'DELETE');
COMMIT TRANSACTION;
