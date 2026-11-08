SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SERVICE' AND IsActive=1);
IF @Project IS NULL THROW 53600,N'Active service project is required.',1;
IF OBJECT_ID(N'dbo.TDADServiceRequestSubject',N'U') IS NOT NULL THROW 53601,N'Subject table already exists; review before migration.',1;
IF EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'18002') THROW 53602,N'Menu code 18002 already exists.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDSTMasterGroup WHERE Code=N'014') THROW 53603,N'Master group 014 is missing.',1;

CREATE TABLE dbo.TDADServiceRequestSubject(
    SubjectID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADServiceRequestSubject PRIMARY KEY,
    OwnerType char(1) NOT NULL,
    OwnerPartnerID bigint NULL,
    OwnerCompanyID bigint NULL,
    TemplateSubjectID bigint NULL,
    SubjectCode nvarchar(20) NOT NULL,
    Name nvarchar(500) NOT NULL,
    Seq int NOT NULL CONSTRAINT DF_ServiceRequestSubject_Seq DEFAULT(0),
    OrderBy nvarchar(100) NULL,
    ShortCode nvarchar(100) NULL,
    IsActive bit NOT NULL CONSTRAINT DF_ServiceRequestSubject_Active DEFAULT(1),
    CreateDate datetime2 NOT NULL CONSTRAINT DF_ServiceRequestSubject_CreateDate DEFAULT(SYSUTCDATETIME()),
    CreateBy bigint NULL,
    UpdateDate datetime2 NULL,
    UpdateBy bigint NULL
);

IF EXISTS(SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014' AND (MasterCode IS NULL OR Name IS NULL))
    THROW 53604,N'A subject has no code or name; data migration stopped.',1;
INSERT dbo.TDADServiceRequestSubject(OwnerType,OwnerPartnerID,OwnerCompanyID,SubjectCode,Name,Seq,OrderBy,ShortCode,IsActive,CreateDate,CreateBy,UpdateDate,UpdateBy)
SELECT OwnerType,OwnerPartnerID,OwnerCompanyID,MasterCode,Name,ISNULL(Seq,0),OrderBy,ShortCode,IsActive,CreateDate,CreateBy,UpdateDate,UpdateBy
FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014';
IF (SELECT COUNT(*) FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014')<>(SELECT COUNT(*) FROM dbo.TDADServiceRequestSubject)
    THROW 53605,N'Subject copy count mismatch.',1;
IF EXISTS(
 SELECT OwnerType,OwnerPartnerID,OwnerCompanyID,MasterCode,Name,ISNULL(Seq,0),OrderBy,ShortCode,IsActive,CreateDate,CreateBy,UpdateDate,UpdateBy FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014'
 EXCEPT SELECT OwnerType,OwnerPartnerID,OwnerCompanyID,SubjectCode,Name,Seq,OrderBy,ShortCode,IsActive,CreateDate,CreateBy,UpdateDate,UpdateBy FROM dbo.TDADServiceRequestSubject
) THROW 53606,N'Subject copy data mismatch.',1;

-- Keep the original central records as templates and give every company its
-- own independently editable copy, including currently inactive companies.
IF EXISTS (
 SELECT 1 FROM dbo.TDSTCompanySetUp C
 OUTER APPLY (SELECT ISNULL(MAX(TRY_CONVERT(int,S.SubjectCode)),0) MaxCode
   FROM dbo.TDADServiceRequestSubject S WHERE S.OwnerType=N'C' AND S.OwnerCompanyID=C.CompanyID) M
 WHERE C.OwnerType=N'C' AND M.MaxCode+(SELECT COUNT(*) FROM dbo.TDADServiceRequestSubject
   WHERE OwnerType=N'L' AND ISNULL(OwnerPartnerID,0)=0 AND ISNULL(OwnerCompanyID,0)=0)>99999
) THROW 53607,N'Subject code limit reached during company copy.',1;

;WITH Templates AS (
 SELECT *,ROW_NUMBER() OVER(ORDER BY Seq,SubjectID) AS RowNo
 FROM dbo.TDADServiceRequestSubject
 WHERE OwnerType=N'L' AND ISNULL(OwnerPartnerID,0)=0 AND ISNULL(OwnerCompanyID,0)=0
)
INSERT dbo.TDADServiceRequestSubject
 (OwnerType,OwnerCompanyID,TemplateSubjectID,SubjectCode,Name,Seq,OrderBy,ShortCode,IsActive,CreateDate,CreateBy,UpdateDate,UpdateBy)
SELECT N'C',C.CompanyID,T.SubjectID,RIGHT(N'00000'+CONVERT(nvarchar(20),M.MaxCode+T.RowNo),5),
 T.Name,T.Seq,T.OrderBy,T.ShortCode,T.IsActive,T.CreateDate,T.CreateBy,T.UpdateDate,T.UpdateBy
FROM dbo.TDSTCompanySetUp C
CROSS JOIN Templates T
OUTER APPLY (SELECT ISNULL(MAX(TRY_CONVERT(int,S.SubjectCode)),0) MaxCode
 FROM dbo.TDADServiceRequestSubject S WHERE S.OwnerType=N'C' AND S.OwnerCompanyID=C.CompanyID) M
WHERE C.OwnerType=N'C';
IF EXISTS (
 SELECT 1 FROM dbo.TDSTCompanySetUp C CROSS JOIN dbo.TDADServiceRequestSubject T
 WHERE C.OwnerType=N'C' AND T.OwnerType=N'L' AND ISNULL(T.OwnerPartnerID,0)=0 AND ISNULL(T.OwnerCompanyID,0)=0
 AND NOT EXISTS (SELECT 1 FROM dbo.TDADServiceRequestSubject S WHERE S.OwnerType=N'C'
  AND S.OwnerCompanyID=C.CompanyID AND S.TemplateSubjectID=T.SubjectID
  AND S.Name=T.Name AND S.Seq=T.Seq AND ISNULL(S.ShortCode,N'')=ISNULL(T.ShortCode,N'') AND S.IsActive=T.IsActive)
) THROW 53608,N'Company subject copy verification failed.',1;

INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive)
VALUES(N'18002',N'18',N'หัวข้อแจ้งซ่อม',1,N'serviceRequestSubjects',N'/company/service-request-subjects',N'SERVICE_SETTINGS',N'list_alt',2,1,1,1);
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive)
VALUES(@Project,N'18002',N'18',2,1);
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive)
SELECT @Project,N'18002',N'หัวข้อแจ้งซ่อม',N'Request Subjects',A.Code,A.NameTH,A.NameEN,1
FROM (VALUES(N'VIEW',N'แสดง',N'View'),(N'CREATE',N'เพิ่ม',N'Create'),(N'EDIT',N'แก้ไข',N'Edit'),(N'DELETE',N'ลบ',N'Delete')) A(Code,NameTH,NameEN);

DELETE FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014';
DELETE FROM dbo.TDSTMasterGroup WHERE Code=N'014';
