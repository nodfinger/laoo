SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDADProject', N'ProjectType') IS NULL
    ALTER TABLE dbo.TDADProject ADD ProjectType nvarchar(20) NOT NULL CONSTRAINT DF_TDADProject_ProjectType DEFAULT N'BUSINESS' WITH VALUES;
IF COL_LENGTH(N'dbo.TDADProject', N'SortOrder') IS NULL
    ALTER TABLE dbo.TDADProject ADD SortOrder int NOT NULL CONSTRAINT DF_TDADProject_SortOrder DEFAULT 0 WITH VALUES;
IF COL_LENGTH(N'dbo.TDADProject', N'IconName') IS NULL
    ALTER TABLE dbo.TDADProject ADD IconName nvarchar(100) NULL;
IF COL_LENGTH(N'dbo.TDADProject', N'IsExpandedDefault') IS NULL
    ALTER TABLE dbo.TDADProject ADD IsExpandedDefault bit NOT NULL CONSTRAINT DF_TDADProject_IsExpandedDefault DEFAULT 0 WITH VALUES;

GO

UPDATE dbo.TDADProject
SET ProjectNameTH=N'ข้อมูลส่วนกลาง',ProjectNameEN=N'Center',ProjectType=N'CORE',SortOrder=10,
    IconName=N'hub_outlined',IsExpandedDefault=0,UpdateDate=SYSUTCDATETIME()
WHERE ProjectCode=N'LAOO';

UPDATE dbo.TDADProject
SET ProjectNameTH=N'ระบบห้องประชุม',ProjectNameEN=N'Meeting',ProjectType=N'BUSINESS',SortOrder=20,
    IconName=N'meeting_room_outlined',IsExpandedDefault=0,UpdateDate=SYSUTCDATETIME()
WHERE ProjectCode=N'LAOO_MEETING';

IF NOT EXISTS (SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SERVICE')
BEGIN
    INSERT dbo.TDADProject
        (ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,
         ProjectType,SortOrder,IconName,IsExpandedDefault)
    VALUES
        (N'LAOO_SERVICE',N'ระบบแจ้งซ่อม',N'Service',N'ระบบรับแจ้งซ่อม งานบริการ บำรุงรักษา และงานช่าง',
         1,SYSUTCDATETIME(),N'BUSINESS',30,N'home_repair_service_outlined',0);
END
ELSE
BEGIN
    UPDATE dbo.TDADProject
    SET ProjectNameTH=N'ระบบแจ้งซ่อม',ProjectNameEN=N'Service',
        DescriptionText=N'ระบบรับแจ้งซ่อม งานบริการ บำรุงรักษา และงานช่าง',ProjectType=N'BUSINESS',SortOrder=30,
        IconName=N'home_repair_service_outlined',IsExpandedDefault=0,UpdateDate=SYSUTCDATETIME()
    WHERE ProjectCode=N'LAOO_SERVICE';
END;

IF OBJECT_ID(N'dbo.TDADCompanyProject',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADCompanyProject
    (
        CompanyProjectID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADCompanyProject PRIMARY KEY,
        ProjectID bigint NOT NULL,
        PartnerID bigint NOT NULL,
        CompanyID bigint NOT NULL,
        IsEnabled bit NOT NULL CONSTRAINT DF_TDADCompanyProject_IsEnabled DEFAULT 1,
        IsTrial bit NOT NULL CONSTRAINT DF_TDADCompanyProject_IsTrial DEFAULT 0,
        StartDate date NULL,
        ExpireDate date NULL,
        CreateDate datetime2(7) NOT NULL CONSTRAINT DF_TDADCompanyProject_CreateDate DEFAULT SYSUTCDATETIME(),
        CreatedBy bigint NULL,
        UpdateDate datetime2(7) NULL,
        UpdatedBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDADCompanyProject_Company_Project UNIQUE(CompanyID,ProjectID),
        CONSTRAINT FK_TDADCompanyProject_Project FOREIGN KEY(ProjectID) REFERENCES dbo.TDADProject(ProjectID),
        CONSTRAINT FK_TDADCompanyProject_Partner FOREIGN KEY(PartnerID) REFERENCES dbo.TDADPartner(PartnerID),
        CONSTRAINT CK_TDADCompanyProject_DateRange CHECK(ExpireDate IS NULL OR StartDate IS NULL OR ExpireDate>=StartDate)
    );
    CREATE INDEX IX_TDADCompanyProject_Partner_Company ON dbo.TDADCompanyProject(PartnerID,CompanyID,IsEnabled);
END;

DECLARE @CenterProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO');
DECLARE @MeetingProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MEETING');
DECLARE @ServiceProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SERVICE');

-- Existing service feature switches originally belonged to the combined LAOO project.
-- Copy them to LAOO_SERVICE so project navigation and feature switches remain independent.
INSERT dbo.TDADCompanyFeature
    (ProjectID,PartnerID,CompanyID,FeatureCode,IsEnabled,IsTrial,
     StartDate,ExpireDate,CreateDate,CreatedBy)
SELECT @ServiceProjectID,CF.PartnerID,CF.CompanyID,CF.FeatureCode,CF.IsEnabled,CF.IsTrial,
       CF.StartDate,CF.ExpireDate,SYSUTCDATETIME(),CF.CreatedBy
FROM dbo.TDADCompanyFeature CF
WHERE CF.ProjectID=@CenterProjectID
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.TDADCompanyFeature X
      WHERE X.ProjectID=@ServiceProjectID
        AND X.PartnerID=CF.PartnerID
        AND X.CompanyID=CF.CompanyID
        AND X.FeatureCode=CF.FeatureCode
  );

INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial)
SELECT @CenterProjectID,C.PartnerID,C.CompanyID,1,0
FROM dbo.TDSTCompanySetUp C
WHERE C.CompanyID IS NOT NULL AND C.PartnerID IS NOT NULL AND C.IsActive=1
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject X WHERE X.CompanyID=C.CompanyID AND X.ProjectID=@CenterProjectID);

INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial)
SELECT DISTINCT @ServiceProjectID,C.PartnerID,C.CompanyID,1,0
FROM dbo.TDSTCompanySetUp C
INNER JOIN dbo.TDADCompanyFeature CF ON CF.CompanyID=C.CompanyID AND CF.PartnerID=C.PartnerID
    AND CF.FeatureCode=N'SERVICE' AND CF.IsEnabled=1
    AND (CF.StartDate IS NULL OR CF.StartDate<=CONVERT(date,SYSUTCDATETIME()))
    AND (CF.ExpireDate IS NULL OR CF.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
WHERE C.IsActive=1
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject X WHERE X.CompanyID=C.CompanyID AND X.ProjectID=@ServiceProjectID);

INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial)
SELECT DISTINCT @MeetingProjectID,C.PartnerID,UP.CompanyID,1,0
FROM dbo.TDADUserProject UP
INNER JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=UP.CompanyID AND C.IsActive=1
WHERE UP.ProjectID=@MeetingProjectID AND UP.IsActive=1
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject X WHERE X.CompanyID=UP.CompanyID AND X.ProjectID=@MeetingProjectID);

INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate)
SELECT U.CompanyID,U.UserID,@CenterProjectID,
       CASE WHEN NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject X WHERE X.UserID=U.UserID AND X.IsActive=1) THEN 1 ELSE 0 END,
       1,SYSUTCDATETIME()
FROM dbo.TDADUser U
WHERE U.IsActive=1
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject X WHERE X.CompanyID=U.CompanyID AND X.UserID=U.UserID AND X.ProjectID=@CenterProjectID);

INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate)
SELECT UP.CompanyID,UP.UserID,@ServiceProjectID,0,UP.IsActive,SYSUTCDATETIME()
FROM dbo.TDADUserProject UP
INNER JOIN dbo.TDADCompanyProject CP ON CP.CompanyID=UP.CompanyID AND CP.ProjectID=@ServiceProjectID AND CP.IsEnabled=1
WHERE UP.ProjectID=@CenterProjectID AND UP.IsActive=1
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject X WHERE X.CompanyID=UP.CompanyID AND X.UserID=UP.UserID AND X.ProjectID=@ServiceProjectID);

IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode='13')
BEGIN
    INSERT dbo.TDADMenuGroup
        (AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,OpenOption)
    VALUES(N'C','13',N'ข้อมูลองค์กร',N'account_tree_outlined',130,0,1,SYSUTCDATETIME(),0);
END;

UPDATE dbo.TDADMenuGroup
SET MenuGroupName=N'ข้อมูลองค์กร',IconName=N'account_tree_outlined',SortOrder=130,
    IsExpandedDefault=0,IsActive=1,OpenOption=0,UpdateDate=SYSUTCDATETIME()
WHERE MenuGroupCode='13';

IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode='13001')
BEGIN
    INSERT dbo.TDADMainMenu
        (MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,
         SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
    SELECT '13001','13',MenuName,ScreenType,RouteName,RoutePath,NULL,IconName,
           10,IsVisible,IsFavoriteAllowed,IsActive,SYSUTCDATETIME(),ShowPermissionPoint
    FROM dbo.TDADMainMenu WHERE MenuCode='09002';
END;

DELETE FROM dbo.TDADProjectMenu WHERE MenuCode='09002';

IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@CenterProjectID AND MenuGroupCode='13')
    INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
    VALUES(@CenterProjectID,'13',70,1,SYSUTCDATETIME());
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@CenterProjectID AND MenuGroupCode='13' AND MenuCode='13001')
    INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
    VALUES(@CenterProjectID,'13001','13',10,1,SYSUTCDATETIME());

INSERT dbo.TDADPermission
    (ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,
     IsActive,CreatedDate,CreatedBy)
SELECT P.ProjectID,N'13001',N'สาขา',P.ScreenNameEN,P.ActionCode,P.ActionNameTH,P.ActionNameEN,
       P.IsActive,SYSUTCDATETIME(),P.CreatedBy
FROM dbo.TDADPermission P
WHERE P.ProjectID=@CenterProjectID AND P.ScreenCode=N'09002'
  AND NOT EXISTS
      (SELECT 1 FROM dbo.TDADPermission X
       WHERE X.ProjectID=@CenterProjectID AND X.ScreenCode=N'13001' AND X.ActionCode=P.ActionCode);

INSERT dbo.TDADUserPermission
    (UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedDate,CreatedBy)
SELECT UP.UserID,@CenterProjectID,NewP.PermissionID,UP.IsAllowed,UP.IsActive,UP.Remark,SYSUTCDATETIME(),UP.CreatedBy
FROM dbo.TDADUserPermission UP
INNER JOIN dbo.TDADPermission OldP ON OldP.PermissionID=UP.PermissionID AND OldP.ProjectID=UP.ProjectID AND OldP.ScreenCode=N'09002'
INNER JOIN dbo.TDADPermission NewP ON NewP.ProjectID=@CenterProjectID AND NewP.ScreenCode=N'13001' AND NewP.ActionCode=OldP.ActionCode
WHERE UP.ProjectID=@CenterProjectID
  AND NOT EXISTS
      (SELECT 1 FROM dbo.TDADUserPermission X
       WHERE X.UserID=UP.UserID AND X.ProjectID=@CenterProjectID AND X.PermissionID=NewP.PermissionID);

INSERT dbo.TDADRoleGroupPermission
    (RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedUtc,CreatedBy)
SELECT RP.RoleGroupID,@CenterProjectID,N'13001',RP.ActionCode,RP.IsAllowed,SYSUTCDATETIME(),N'migration'
FROM dbo.TDADRoleGroupPermission RP
WHERE RP.ProjectID=@CenterProjectID AND RP.MenuCode=N'09002'
  AND NOT EXISTS
      (SELECT 1 FROM dbo.TDADRoleGroupPermission X
       WHERE X.RoleGroupID=RP.RoleGroupID AND X.ProjectID=@CenterProjectID
         AND X.MenuCode=N'13001' AND X.ActionCode=RP.ActionCode);

DECLARE @ServiceGroups TABLE(MenuGroupCode char(2) PRIMARY KEY);
INSERT @ServiceGroups VALUES('08'),('09'),('14'),('15'),('16'),('17'),('19'),('20');

INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @ServiceProjectID,PG.MenuGroupCode,PG.SortOrder,1,SYSUTCDATETIME()
FROM dbo.TDADProjectMenuGroup PG
INNER JOIN @ServiceGroups SG ON SG.MenuGroupCode=PG.MenuGroupCode
WHERE PG.ProjectID=@CenterProjectID AND PG.IsActive=1
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup X WHERE X.ProjectID=@ServiceProjectID AND X.MenuGroupCode=PG.MenuGroupCode);

INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
SELECT @ServiceProjectID,PM.MenuCode,PM.MenuGroupCode,PM.SortOrder,1,SYSUTCDATETIME()
FROM dbo.TDADProjectMenu PM
INNER JOIN @ServiceGroups SG ON SG.MenuGroupCode=PM.MenuGroupCode
WHERE PM.ProjectID=@CenterProjectID AND PM.IsActive=1
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu X WHERE X.ProjectID=@ServiceProjectID AND X.MenuCode=PM.MenuCode AND X.MenuGroupCode=PM.MenuGroupCode);

DELETE PM FROM dbo.TDADProjectMenu PM INNER JOIN @ServiceGroups SG ON SG.MenuGroupCode=PM.MenuGroupCode WHERE PM.ProjectID=@CenterProjectID;
DELETE PG FROM dbo.TDADProjectMenuGroup PG INNER JOIN @ServiceGroups SG ON SG.MenuGroupCode=PG.MenuGroupCode WHERE PG.ProjectID=@CenterProjectID;

DELETE FROM dbo.TDADProjectMenu WHERE ProjectID=@MeetingProjectID AND MenuGroupCode NOT IN('21','22','23','24');
DELETE FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@MeetingProjectID AND MenuGroupCode NOT IN('21','22','23','24');

COMMIT TRANSACTION;
