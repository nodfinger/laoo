-- Test-only data. RunID SF_20261004_DEMO. No production wallet/student is changed.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @co bigint=(SELECT CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@co);
DECLARE @partner bigint=(SELECT TOP 1 PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@co AND IsActive=1);
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SCHOOL_FOOD');
DECLARE @package bigint=(SELECT PackageID FROM dbo.TDADProjectPackage WHERE ProjectID=@project AND PackageCode=N'STANDARD');
DECLARE @branch bigint=(SELECT TOP 1 BranchID FROM dbo.TDADBranch WHERE CompanyID=@co AND IsActive=1 ORDER BY BranchID);
IF @co IS NULL OR @partner IS NULL OR @package IS NULL OR @branch IS NULL THROW 57310,N'Missing demo prerequisites.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@co AND ProjectID=@project AND IsCurrent=1)
BEGIN
 INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,ReasonText,CreateBy)
 VALUES(@partner,@co,@project,@package,N'TRIAL',CONVERT(date,SYSUTCDATETIME()),DATEADD(day,30,CONVERT(date,SYSUTCDATETIME())),N'SF_20261004_DEMO: school food acceptance testing',@actor);
 INSERT dbo.TDADCompanyProject(PartnerID,CompanyID,ProjectID,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 SELECT @partner,@co,@project,1,1,CONVERT(date,SYSUTCDATETIME()),DATEADD(day,30,CONVERT(date,SYSUTCDATETIME())),@actor
 WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE CompanyID=@co AND ProjectID=@project);
 INSERT dbo.TDADCompanyFeature(PartnerID,CompanyID,ProjectID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 SELECT @partner,@co,@project,F.FeatureCode,1,1,CONVERT(date,SYSUTCDATETIME()),DATEADD(day,30,CONVERT(date,SYSUTCDATETIME())),@actor
 FROM dbo.TDADProjectPackageFeature F WHERE PackageID=@package AND IsEnabled=1
 AND NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyFeature C WHERE C.CompanyID=@co AND C.ProjectID=@project AND C.FeatureCode=F.FeatureCode);
 INSERT dbo.TDSFAudit(CompanyID,UserID,ActionCode,EntityType,EntityID,DetailJson)
 VALUES(@co,@actor,N'DEMO_ENABLE',N'PROJECT',@project,N'{"runId":"SF_20261004_DEMO","trialDays":30}');
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@co AND UserID=@actor AND ProjectID=@project)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy) VALUES(@co,@actor,@project,0,1,SYSUTCDATETIME(),@actor);
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
SELECT @actor,@project,P.PermissionID,1,1,N'SF_20261004_DEMO',@actor FROM dbo.TDADPermission P
WHERE P.ProjectID=@project AND P.IsActive=1 AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission U WHERE U.UserID=@actor AND U.ProjectID=@project AND U.PermissionID=P.PermissionID);
IF NOT EXISTS(SELECT 1 FROM dbo.TDSCSchoolLevel WHERE CompanyID=@co AND LevelCode=N'SFDEMO-M3')
 INSERT dbo.TDSCSchoolLevel(CompanyID,LevelCode,LevelName,SortOrder,CreateBy) VALUES(@co,N'SFDEMO-M3',N'ชั้นทดสอบ มัธยม 3 [SF_20261004_DEMO]',990,@actor);
DECLARE @level bigint=(SELECT LevelID FROM dbo.TDSCSchoolLevel WHERE CompanyID=@co AND LevelCode=N'SFDEMO-M3');
IF NOT EXISTS(SELECT 1 FROM dbo.TDSCClassroom WHERE CompanyID=@co AND RoomCode=N'SFDEMO-3/2')
 INSERT dbo.TDSCClassroom(CompanyID,LevelID,RoomCode,RoomName,AcademicYear,CreateBy) VALUES(@co,@level,N'SFDEMO-3/2',N'ห้องทดสอบ 3/2 [SF_20261004_DEMO]',2569,@actor);
DECLARE @room bigint=(SELECT ClassroomID FROM dbo.TDSCClassroom WHERE CompanyID=@co AND RoomCode=N'SFDEMO-3/2');
IF NOT EXISTS(SELECT 1 FROM dbo.TDSCStudent WHERE CompanyID=@co AND StudentCode=N'SFDEMO001')
 INSERT dbo.TDSCStudent(CompanyID,StudentCode,FirstName,LastName,ClassroomID,EnrollmentDate,CreateBy) VALUES(@co,N'SFDEMO001',N'นักเรียนตัวอย่าง',N'SF_20261004_DEMO',@room,CONVERT(date,SYSUTCDATETIME()),@actor);
IF NOT EXISTS(SELECT 1 FROM dbo.TDSCStudent WHERE CompanyID=@co AND StudentCode=N'SFDEMO002')
 INSERT dbo.TDSCStudent(CompanyID,StudentCode,FirstName,LastName,ClassroomID,EnrollmentDate,CreateBy) VALUES(@co,N'SFDEMO002',N'นักเรียนยอดไม่พอ',N'SF_20261004_DEMO',@room,CONVERT(date,SYSUTCDATETIME()),@actor);
IF NOT EXISTS(SELECT 1 FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND WarehouseCode=N'SFDEMO-CENTRAL')
 INSERT dbo.TDIVWarehouse(CompanyID,BranchID,WarehouseCode,WarehouseName,CreatedBy) VALUES(@co,@branch,N'SFDEMO-CENTRAL',N'คลังกลางทดสอบ [SF_20261004_DEMO]',@actor);
IF NOT EXISTS(SELECT 1 FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND WarehouseCode=N'SFDEMO-SHOP')
 INSERT dbo.TDIVWarehouse(CompanyID,BranchID,WarehouseCode,WarehouseName,CreatedBy) VALUES(@co,@branch,N'SFDEMO-SHOP',N'คลังร้านทดสอบ [SF_20261004_DEMO]',@actor);
IF NOT EXISTS(SELECT 1 FROM dbo.TDIVItem WHERE CompanyID=@co AND ItemCode=N'SFDEMO-RICE')
 INSERT dbo.TDIVItem(CompanyID,ItemGroupCode,ItemTypeCode,ItemCode,ItemName,UnitPrice,UnitCode,ItemKindCode,StockTrackingCode,RemarkItem1)
 VALUES(@co,N'SFDEMO',N'SFDEMO-FOOD',N'SFDEMO-RICE',N'ข้าวไก่กระเทียม (ทดสอบ)',35,N'จาน',N'GOODS',N'QUANTITY',N'SF_20261004_DEMO');
IF NOT EXISTS(SELECT 1 FROM dbo.TDIVItem WHERE CompanyID=@co AND ItemCode=N'SFDEMO-WATER')
 INSERT dbo.TDIVItem(CompanyID,ItemGroupCode,ItemTypeCode,ItemCode,ItemName,UnitPrice,UnitCode,ItemKindCode,StockTrackingCode,RemarkItem1)
 VALUES(@co,N'SFDEMO',N'SFDEMO-DRINK',N'SFDEMO-WATER',N'น้ำดื่ม (ทดสอบ)',10,N'ขวด',N'GOODS',N'QUANTITY',N'SF_20261004_DEMO');
DECLARE @wh bigint=(SELECT WarehouseID FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND WarehouseCode=N'SFDEMO-CENTRAL');
INSERT dbo.TDIVStockBalance(CompanyID,WarehouseID,ItemID,Quantity)
SELECT @co,@wh,I.ItemID,100 FROM dbo.TDIVItem I WHERE I.CompanyID=@co AND I.ItemCode IN(N'SFDEMO-RICE',N'SFDEMO-WATER')
AND NOT EXISTS(SELECT 1 FROM dbo.TDIVStockBalance B WHERE B.CompanyID=@co AND B.WarehouseID=@wh AND B.ItemID=I.ItemID);
INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,Remark,CreatedBy)
SELECT @co,@wh,I.ItemID,N'SCHOOL_FOOD_DEMO',I.ItemID,I.ItemID,N'OPENING',100,N'SF_20261004_DEMO opening test stock',@actor
FROM dbo.TDIVItem I WHERE I.CompanyID=@co AND I.ItemCode IN(N'SFDEMO-RICE',N'SFDEMO-WATER')
AND NOT EXISTS(SELECT 1 FROM dbo.TDIVStockMovement M WHERE M.CompanyID=@co AND M.WarehouseID=@wh AND M.ItemID=I.ItemID AND M.Remark=N'SF_20261004_DEMO opening test stock');
IF NOT EXISTS(SELECT 1 FROM dbo.TDSCGuardian WHERE CompanyID=@co AND GuardianCode=N'SFDEMO-G')
 INSERT dbo.TDSCGuardian(CompanyID,GuardianCode,FullName,Email,EmailVerified,CreateBy)
 VALUES(@co,N'SFDEMO-G',N'ผู้ปกครองทดสอบ [SF_20261004_DEMO]',N'school-food-demo@example.com',0,@actor);
DECLARE @guardian bigint=(SELECT GuardianID FROM dbo.TDSCGuardian WHERE CompanyID=@co AND GuardianCode=N'SFDEMO-G');
DECLARE @child bigint=(SELECT StudentID FROM dbo.TDSCStudent WHERE CompanyID=@co AND StudentCode=N'SFDEMO001');
IF NOT EXISTS(SELECT 1 FROM dbo.TDSCStudentGuardian WHERE GuardianID=@guardian AND StudentID=@child)
 INSERT dbo.TDSCStudentGuardian(StudentID,GuardianID,RelationshipName,IsPrimary) VALUES(@child,@guardian,N'ผู้ปกครองทดสอบ',1);
COMMIT;
