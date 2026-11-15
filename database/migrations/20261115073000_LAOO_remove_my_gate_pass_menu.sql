SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF EXISTS (SELECT 1 FROM dbo.TDSTMenuApprovalAssignment WHERE MenuCode=N'38007')
 OR EXISTS (SELECT 1 FROM dbo.TDSTPersonalApprovalStep WHERE MenuCode=N'38007')
    THROW 54001, N'ตรวจพบข้อมูลอนุมัติที่ผูกกับเมนู 38007 กรุณาตรวจสอบก่อนลบ', 1;
DELETE FROM dbo.TDADUserPermission WHERE PermissionID IN (SELECT PermissionID FROM dbo.TDADPermission WHERE ScreenCode=N'38007');
DELETE FROM dbo.TDADLaooUserPermission WHERE PermissionID IN (SELECT PermissionID FROM dbo.TDADPermission WHERE ScreenCode=N'38007');
DELETE FROM dbo.TDADPermissionTemplateDetail WHERE PermissionID IN (SELECT PermissionID FROM dbo.TDADPermission WHERE ScreenCode=N'38007');
DELETE FROM dbo.TDADRoleGroupPermission WHERE MenuCode=N'38007';
DELETE FROM dbo.TDADPermission WHERE ScreenCode=N'38007';
DELETE FROM dbo.TDADProjectMenu WHERE MenuCode=N'38007';
DELETE FROM dbo.TDADMainMenu WHERE MenuCode=N'38007';
COMMIT TRANSACTION;
