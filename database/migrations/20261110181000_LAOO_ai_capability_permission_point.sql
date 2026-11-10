SET NOCOUNT ON;
SET XACT_ABORT ON;
UPDATE dbo.TDADMainMenu SET ShowPermissionPoint=1
WHERE MenuCode=N'10008' AND ISNULL(ShowPermissionPoint,0)=0;
