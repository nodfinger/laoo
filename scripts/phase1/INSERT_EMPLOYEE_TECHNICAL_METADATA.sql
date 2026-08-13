USE [DBTDLaoo];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Now nvarchar(50) = CONVERT(nvarchar(50), SYSUTCDATETIME(), 126);

/* Menu source of truth */
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'10001')
BEGIN
    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,ScreenType,CreateDate)
    VALUES(N'10001',N'10',N'พนักงานของ Customer',N'companyEmployees',N'/company/employees',N'CUSTOMER_EMPLOYEE',N'badge',10,1,1,1,1,SYSUTCDATETIME());
END;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'11001')
BEGIN
    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,ScreenType,CreateDate)
    VALUES(N'11001',N'11',N'พนักงานของ Partner',N'partnerEmployees',N'/partner/employees',N'PARTNER_EMPLOYEE',N'badge',10,1,1,1,1,SYSUTCDATETIME());
END;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode = N'12001')
BEGIN
    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,ScreenType,CreateDate)
    VALUES(N'12001',N'12',N'พนักงานของ Customer',N'customerEmployees',N'/partner/customer-employees',N'CUSTOMER_EMPLOYEE',N'badge',10,1,1,1,1,SYSUTCDATETIME());
END;
UPDATE dbo.TDADMainMenu SET MenuName=N'พนักงานของ Partner',RouteName=N'partnerEmployees',RoutePath=N'/partner/employees',FeatureCode=N'PARTNER_EMPLOYEE',ScreenType=1,IsActive=1 WHERE MenuCode=N'11001';
UPDATE dbo.TDADMainMenu SET MenuName=N'พนักงานของ Customer',RouteName=N'customerEmployees',RoutePath=N'/partner/customer-employees',FeatureCode=N'CUSTOMER_EMPLOYEE',ScreenType=1,IsActive=1 WHERE MenuCode=N'12001';
UPDATE dbo.TDADMainMenu SET MenuName=N'พนักงานของ Customer',RouteName=N'companyEmployees',RoutePath=N'/company/employees',FeatureCode=N'CUSTOMER_EMPLOYEE',ScreenType=1,IsActive=1 WHERE MenuCode=N'10001';

/* Screen metadata */
IF EXISTS (SELECT 1 FROM dbo.TDSTScreen WHERE CompanyCode='TD' AND ScreenCode='11001')
    UPDATE dbo.TDSTScreen SET MenuCode='11001',ScreenName=N'พนักงานของ Partner',ScreenType='CRUD',RouteName=N'partnerEmployees',RoutePath=N'/partner/employees',Module='AD',LastUpdate=@Now WHERE CompanyCode='TD' AND ScreenCode='11001';
ELSE
    INSERT dbo.TDSTScreen(CompanyCode,ScreenCode,MenuCode,MDCode,ScreenName,ScreenType,RouteName,RoutePath,Module,LastUpdate) VALUES('TD','11001','11001',NULL,N'พนักงานของ Partner','CRUD',N'partnerEmployees',N'/partner/employees',N'AD',@Now);
IF EXISTS (SELECT 1 FROM dbo.TDSTScreen WHERE CompanyCode='TD' AND ScreenCode='12001')
    UPDATE dbo.TDSTScreen SET MenuCode='12001',ScreenName=N'พนักงานของ Customer',ScreenType='CRUD',RouteName=N'customerEmployees',RoutePath=N'/partner/customer-employees',Module='AD',LastUpdate=@Now WHERE CompanyCode='TD' AND ScreenCode='12001';
ELSE
    INSERT dbo.TDSTScreen(CompanyCode,ScreenCode,MenuCode,MDCode,ScreenName,ScreenType,RouteName,RoutePath,Module,LastUpdate) VALUES('TD','12001','12001',NULL,N'พนักงานของ Customer','CRUD',N'customerEmployees',N'/partner/customer-employees',N'AD',@Now);
IF EXISTS (SELECT 1 FROM dbo.TDSTScreen WHERE CompanyCode='TD' AND ScreenCode='10001')
    UPDATE dbo.TDSTScreen SET MenuCode='10001',ScreenName=N'พนักงานของ Customer',ScreenType='CRUD',RouteName=N'companyEmployees',RoutePath=N'/company/employees',Module='AD',LastUpdate=@Now WHERE CompanyCode='TD' AND ScreenCode='10001';
ELSE
    INSERT dbo.TDSTScreen(CompanyCode,ScreenCode,MenuCode,MDCode,ScreenName,ScreenType,RouteName,RoutePath,Module,LastUpdate) VALUES('TD','10001','10001',NULL,N'พนักงานของ Customer','CRUD',N'companyEmployees',N'/company/employees',N'AD',@Now);

DECLARE @ScreenCode varchar(20), @ApiName varchar(100), @Method varchar(10), @Path varchar(200), @Action varchar(50), @Remark nvarchar(500);
DECLARE api_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT S.ScreenCode,A.ApiName,A.Method,A.ApiPath,A.ActionCode,A.Remark
    FROM (VALUES
        ('11001','Employee.Partner.List','GET','/api/partner/employees','VIEW',N'List Partner employees within Login Partner scope'),
        ('11001','Employee.Partner.Create','POST','/api/partner/employees','CREATE',N'Create Partner employee with PartnerID from Login Context'),
        ('11001','Employee.Partner.Update','PUT','/api/partner/employees/{id}','EDIT',N'Update Partner employee within Login Partner scope'),
        ('11001','Employee.Partner.Delete','DELETE','/api/partner/employees/{id}','DELETE',N'Delete Partner employee within Login Partner scope'),
        ('12001','Employee.Customer.List','GET','/api/partner/customer-employees','VIEW',N'List Customer employees for selected Customer under Login Partner'),
        ('12001','Employee.Customer.Create','POST','/api/partner/customer-employees','CREATE',N'Create Customer employee with validated PartnerID and CompanyID'),
        ('12001','Employee.Customer.Update','PUT','/api/partner/customer-employees/{id}','EDIT',N'Update Customer employee within Partner and Customer scope'),
        ('12001','Employee.Customer.Delete','DELETE','/api/partner/customer-employees/{id}','DELETE',N'Delete Customer employee within Partner and Customer scope'),
        ('10001','Employee.Company.List','GET','/api/company/employees','VIEW',N'List employees within Login Company scope'),
        ('10001','Employee.Company.Create','POST','/api/company/employees','CREATE',N'Create employee within Login Company scope'),
        ('10001','Employee.Company.Update','PUT','/api/company/employees/{id}','EDIT',N'Update employee within Login Company scope'),
        ('10001','Employee.Company.Delete','DELETE','/api/company/employees/{id}','DELETE',N'Delete employee within Login Company scope')
    ) A(ScreenCode,ApiName,Method,ApiPath,ActionCode,Remark)
    INNER JOIN (SELECT DISTINCT ScreenCode FROM (VALUES ('10001'),('11001'),('12001')) X(ScreenCode)) S ON S.ScreenCode=A.ScreenCode;
OPEN api_cursor;
FETCH NEXT FROM api_cursor INTO @ScreenCode,@ApiName,@Method,@Path,@Action,@Remark;
WHILE @@FETCH_STATUS=0
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.TDSTScreenAPI WHERE CompanyCode='TD' AND ScreenCode=@ScreenCode AND APIName=@ApiName)
        UPDATE dbo.TDSTScreenAPI SET HttpMethod=@Method,Endpoint=@Path,ActionName=@Action,Remark=@Remark,LastUpdate=@Now WHERE CompanyCode='TD' AND ScreenCode=@ScreenCode AND APIName=@ApiName;
    ELSE
        INSERT dbo.TDSTScreenAPI VALUES('TD',@ScreenCode,@ApiName,@Method,@Path,@Action,@Remark,@Now);
    FETCH NEXT FROM api_cursor INTO @ScreenCode,@ApiName,@Method,@Path,@Action,@Remark;
END;
CLOSE api_cursor; DEALLOCATE api_cursor;

DECLARE @FieldScreen varchar(20), @FieldName varchar(100), @FieldCaption nvarchar(200), @DataType varchar(50), @Required char(1), @ReadOnly char(1), @Editable char(1), @TableName varchar(200), @ColumnName varchar(100), @FieldRemark nvarchar(500);
DECLARE field_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT S.ScreenCode,F.FieldName,F.FieldCaption,F.DataType,F.Required,F.ReadOnly,F.Editable,F.TableName,F.ColumnName,F.Remark
    FROM (VALUES ('10001'),('11001'),('12001')) S(ScreenCode)
    CROSS JOIN (VALUES
        ('CompanyID',N'Customer','bigint','N','N','Y','dbo.TDADEmployee','CompanyID',N'Customer scope; required only for Customer screen'),
        ('EmployeeCode',N'รหัสพนักงาน','nvarchar(50)','Y','N','Y','dbo.TDADEmployee','EmployeeCode',N'Unique employee code within Partner or Customer scope'),
        ('FullName',N'ชื่อ-นามสกุล','nvarchar(200)','Y','N','Y','dbo.TDADEmployee','FullName',N'Employee full name'),
        ('NickName',N'ชื่อเล่น','nvarchar(100)','N','N','Y','dbo.TDADEmployee','NickName',N'Employee nickname'),
        ('DivisionOrgUnitID',N'ฝ่าย','bigint','N','N','Y','dbo.TDADEmployee','DivisionOrgUnitID',N'Organization division when configured'),
        ('DepartmentOrgUnitID',N'แผนก','bigint','N','N','Y','dbo.TDADEmployee','DepartmentOrgUnitID',N'Organization department when configured'),
        ('PositionCode',N'ตำแหน่ง','nvarchar(50)','N','N','Y','dbo.TDADEmployee','PositionCode',N'Position code'),
        ('Email',N'Email','nvarchar(200)','N','N','Y','dbo.TDADEmployee','Email',N'Employee email'),
        ('Telephone',N'โทรศัพท์','nvarchar(50)','N','N','Y','dbo.TDADEmployee','Telephone',N'Work telephone'),
        ('PersonalTelephone',N'โทรศัพท์ส่วนตัว','nvarchar(50)','N','N','Y','dbo.TDADEmployee','PersonalTelephone',N'Personal telephone'),
        ('StartWorkDate',N'วันที่เริ่มงาน','date','N','N','Y','dbo.TDADEmployee','StartWorkDate',N'Employment start date'),
        ('ContName1',N'ผู้ติดต่อฉุกเฉิน 1','nvarchar(250)','N','N','Y','dbo.TDADEmployee','ContName1',N'First emergency contact name'),
        ('ContRelation1',N'ความสัมพันธ์ 1','nvarchar(250)','N','N','Y','dbo.TDADEmployee','ContRelation1',N'First emergency contact relation'),
        ('ContPhone1',N'โทรศัพท์ผู้ติดต่อ 1','nvarchar(250)','N','N','Y','dbo.TDADEmployee','ContPhone1',N'First emergency contact phone'),
        ('ContName2',N'ผู้ติดต่อฉุกเฉิน 2','nvarchar(250)','N','N','Y','dbo.TDADEmployee','ContName2',N'Second emergency contact name'),
        ('ContRelation2',N'ความสัมพันธ์ 2','nvarchar(250)','N','N','Y','dbo.TDADEmployee','ContRelation2',N'Second emergency contact relation'),
        ('ContPhone2',N'โทรศัพท์ผู้ติดต่อ 2','nvarchar(250)','N','N','Y','dbo.TDADEmployee','ContPhone2',N'Second emergency contact phone'),
        ('CarID1',N'ทะเบียนรถ 1','nvarchar(50)','N','N','Y','dbo.TDADEmployee','CarID1',N'First vehicle registration'),
        ('CarColor1',N'สีรถ 1','nvarchar(100)','N','N','Y','dbo.TDADEmployee','CarColor1',N'First vehicle color'),
        ('CarTypeCode1',N'ประเภทรถ 1','nvarchar(50)','N','N','Y','dbo.TDADEmployee','CarTypeCode1',N'First vehicle type from MasterGroupCode 009'),
        ('CarOilType1',N'เชื้อเพลิง 1','nvarchar(50)','N','N','Y','dbo.TDADEmployee','CarOilType1',N'First vehicle fuel type from MasterGroupCode 010'),
        ('CarID2',N'ทะเบียนรถ 2','nvarchar(50)','N','N','Y','dbo.TDADEmployee','CarID2',N'Second vehicle registration'),
        ('CarColor2',N'สีรถ 2','nvarchar(100)','N','N','Y','dbo.TDADEmployee','CarColor2',N'Second vehicle color'),
        ('CarTypeCode2',N'ประเภทรถ 2','nvarchar(50)','N','N','Y','dbo.TDADEmployee','CarTypeCode2',N'Second vehicle type from MasterGroupCode 009'),
        ('CarOilType2',N'เชื้อเพลิง 2','nvarchar(50)','N','N','Y','dbo.TDADEmployee','CarOilType2',N'Second vehicle fuel type from MasterGroupCode 010'),
        ('IsActive',N'สถานะ','bit','Y','N','Y','dbo.TDADEmployee','IsActive',N'Employee active status')
    ) F(FieldName,FieldCaption,DataType,Required,ReadOnly,Editable,TableName,ColumnName,Remark);
OPEN field_cursor;
FETCH NEXT FROM field_cursor INTO @FieldScreen,@FieldName,@FieldCaption,@DataType,@Required,@ReadOnly,@Editable,@TableName,@ColumnName,@FieldRemark;
WHILE @@FETCH_STATUS=0
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.TDSTScreenField WHERE CompanyCode='TD' AND ScreenCode=@FieldScreen AND FieldName=@FieldName)
        UPDATE dbo.TDSTScreenField SET Caption=@FieldCaption,DataType=@DataType,IsRequired=@Required,IsFilter=@ReadOnly,IsEditable=@Editable,SourceTable=@TableName,SourceField=@ColumnName,Remark=@FieldRemark,LastUpdate=@Now WHERE CompanyCode='TD' AND ScreenCode=@FieldScreen AND FieldName=@FieldName;
    ELSE
        INSERT dbo.TDSTScreenField VALUES('TD',@FieldScreen,@FieldName,@FieldCaption,@DataType,@Required,@ReadOnly,@Editable,@TableName,@ColumnName,@FieldRemark,@Now);
    FETCH NEXT FROM field_cursor INTO @FieldScreen,@FieldName,@FieldCaption,@DataType,@Required,@ReadOnly,@Editable,@TableName,@ColumnName,@FieldRemark;
END;
CLOSE field_cursor; DEALLOCATE field_cursor;

DECLARE @PermissionScreen varchar(20), @PermissionCode varchar(50), @PermissionName nvarchar(100), @PermissionRemark nvarchar(500);
DECLARE permission_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT S.ScreenCode,P.PermissionCode,P.PermissionName,P.Remark
    FROM (VALUES ('10001'),('11001'),('12001')) S(ScreenCode)
    CROSS JOIN (VALUES
        ('VIEW',N'View',N'View scoped employee list'),
        ('CREATE',N'Create',N'Create employee'),
        ('EDIT',N'Edit',N'Edit employee'),
        ('DELETE',N'Delete',N'Delete employee')
    ) P(PermissionCode,PermissionName,Remark);
OPEN permission_cursor;
FETCH NEXT FROM permission_cursor INTO @PermissionScreen,@PermissionCode,@PermissionName,@PermissionRemark;
WHILE @@FETCH_STATUS=0
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.TDSTScreenPermission WHERE CompanyCode='TD' AND ScreenCode=@PermissionScreen AND PermissionCode=@PermissionCode)
        UPDATE dbo.TDSTScreenPermission SET ActionName=@PermissionName,Remark=@PermissionRemark,LastUpdate=@Now WHERE CompanyCode='TD' AND ScreenCode=@PermissionScreen AND PermissionCode=@PermissionCode;
    ELSE
        INSERT dbo.TDSTScreenPermission VALUES('TD',@PermissionScreen,@PermissionCode,@PermissionName,@PermissionRemark,@Now);
    FETCH NEXT FROM permission_cursor INTO @PermissionScreen,@PermissionCode,@PermissionName,@PermissionRemark;
END;
CLOSE permission_cursor; DEALLOCATE permission_cursor;

COMMIT TRANSACTION;
GO
