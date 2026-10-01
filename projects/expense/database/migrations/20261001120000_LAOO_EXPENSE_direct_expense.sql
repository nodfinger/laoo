SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
  BEGIN TRANSACTION;

  DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_EXPENSE' AND IsActive=1);
  DECLARE @CoreProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
  IF @ProjectID IS NULL OR @CoreProjectID IS NULL THROW 56410,N'Active LAOO and LAOO_EXPENSE projects are required.',1;

  IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemExpense',N'IsEnabled') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemExpense ADD IsEnabled bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemExpense_IsEnabled DEFAULT(1);
  IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemExpense',N'AllowDirectEntry') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemExpense ADD AllowDirectEntry bit NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemExpense_AllowDirectEntry DEFAULT(1);
  IF COL_LENGTH(N'dbo.TDSTCompanySetupSystemExpense',N'DefaultCurrencyCode') IS NULL
    ALTER TABLE dbo.TDSTCompanySetupSystemExpense ADD DefaultCurrencyCode nvarchar(3) NOT NULL CONSTRAINT DF_TDSTCompanySetupSystemExpense_Currency DEFAULT(N'THB');

  IF NOT EXISTS(SELECT 1 FROM dbo.TDSTMasterGroup WHERE Code=N'015')
    INSERT dbo.TDSTMasterGroup(Code,Name) VALUES(N'015',N'ประเภทค่าใช้จ่าย');
  ELSE
    UPDATE dbo.TDSTMasterGroup SET Name=N'ประเภทค่าใช้จ่าย' WHERE Code=N'015';

  IF OBJECT_ID(N'dbo.TDEXExpense',N'U') IS NULL
  BEGIN
    CREATE TABLE dbo.TDEXExpense(
      ExpenseID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEXExpense PRIMARY KEY,
      CompanyID bigint NOT NULL,
      ProjectID bigint NOT NULL,
      ExpenseNo nvarchar(40) NOT NULL,
      ExpenseDate date NOT NULL,
      PayeeName nvarchar(250) NOT NULL,
      BillNo nvarchar(100) NULL,
      PaymentMethodCode nvarchar(20) NOT NULL,
      CurrencyCode nvarchar(3) NOT NULL CONSTRAINT DF_TDEXExpense_Currency DEFAULT(N'THB'),
      TotalAmount decimal(18,2) NOT NULL,
      StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDEXExpense_Status DEFAULT(N'RECORDED'),
      Remark nvarchar(2000) NULL,
      CreateBy bigint NOT NULL,
      CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDEXExpense_CreateDate DEFAULT SYSUTCDATETIME(),
      UpdateBy bigint NULL,
      UpdateDate datetime2(3) NULL,
      CONSTRAINT UQ_TDEXExpense_Company_No UNIQUE(CompanyID,ExpenseNo),
      CONSTRAINT CK_TDEXExpense_Total CHECK(TotalAmount>0),
      CONSTRAINT CK_TDEXExpense_Status CHECK(StatusCode IN(N'RECORDED',N'CANCELLED')),
      CONSTRAINT CK_TDEXExpense_Payment CHECK(PaymentMethodCode IN(N'CASH',N'BANK',N'CARD',N'OTHER'))
    );
    CREATE INDEX IX_TDEXExpense_Company_Date ON dbo.TDEXExpense(CompanyID,ExpenseDate DESC,ExpenseID DESC);
    CREATE INDEX IX_TDEXExpense_Company_Status ON dbo.TDEXExpense(CompanyID,StatusCode,ExpenseDate DESC);
  END;

  IF OBJECT_ID(N'dbo.TDEXExpenseDetail',N'U') IS NULL
  BEGIN
    CREATE TABLE dbo.TDEXExpenseDetail(
      ExpenseDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEXExpenseDetail PRIMARY KEY,
      ExpenseID bigint NOT NULL,
      CompanyID bigint NOT NULL,
      LineSeq int NOT NULL,
      ExpenseTypeCode nvarchar(10) NOT NULL,
      DescriptionText nvarchar(500) NOT NULL,
      Amount decimal(18,2) NOT NULL,
      CONSTRAINT FK_TDEXExpenseDetail_Header FOREIGN KEY(ExpenseID) REFERENCES dbo.TDEXExpense(ExpenseID) ON DELETE CASCADE,
      CONSTRAINT UQ_TDEXExpenseDetail_Line UNIQUE(ExpenseID,LineSeq),
      CONSTRAINT CK_TDEXExpenseDetail_Line CHECK(LineSeq>0),
      CONSTRAINT CK_TDEXExpenseDetail_Amount CHECK(Amount>0)
    );
    CREATE INDEX IX_TDEXExpenseDetail_Header ON dbo.TDEXExpenseDetail(ExpenseID,LineSeq);
    CREATE INDEX IX_TDEXExpenseDetail_Company_Type ON dbo.TDEXExpenseDetail(CompanyID,ExpenseTypeCode);
  END;

  IF NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'41009')
    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateBy,ShowPermissionPoint)
    VALUES(N'41009',N'41',N'บันทึกค่าใช้จ่ายโดยตรง',4,N'expenseDirectEntries',N'/company/direct-expenses',N'EXPENSE_DIRECT',N'receipt_long_outlined',90,1,1,1,0,0);
  ELSE
    UPDATE dbo.TDADMainMenu SET MenuName=N'บันทึกค่าใช้จ่ายโดยตรง',ScreenType=4,RouteName=N'expenseDirectEntries',RoutePath=N'/company/direct-expenses',FeatureCode=N'EXPENSE_DIRECT',IconName=N'receipt_long_outlined',SortOrder=90,IsVisible=1,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=N'41009';

  IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu WHERE ProjectID=@ProjectID AND MenuCode=N'41009')
    INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateBy) VALUES(@ProjectID,N'41009',N'41',90,1,0);
  ELSE
    UPDATE dbo.TDADProjectMenu SET IsActive=1,SortOrder=90,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuCode=N'41009';

  UPDATE dbo.TDADProjectMenu SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuCode IN(N'41001',N'41002');
  UPDATE dbo.TDADProjectMenu SET IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuCode BETWEEN N'41003' AND N'41008';
  UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuGroupCode=N'41';

  DECLARE @Actions TABLE(ActionCode nvarchar(50),ActionNameTH nvarchar(100),ActionNameEN nvarchar(100));
  INSERT @Actions VALUES(N'VIEW',N'ดูข้อมูล',N'VIEW'),(N'CREATE',N'เพิ่มข้อมูล',N'CREATE'),(N'EDIT',N'แก้ไขข้อมูล',N'EDIT'),(N'DELETE',N'ลบข้อมูล',N'DELETE');
  INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedBy)
  SELECT @ProjectID,N'41009',N'บันทึกค่าใช้จ่ายโดยตรง',N'DIRECT_EXPENSE',A.ActionCode,A.ActionNameTH,A.ActionNameEN,1,0
  FROM @Actions A WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission P WHERE P.ProjectID=@ProjectID AND P.ScreenCode=N'41009' AND P.ActionCode=A.ActionCode);
  UPDATE dbo.TDADPermission SET IsActive=1,ModifiedDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND ScreenCode=N'41009';

  DECLARE @AdminRoles TABLE(RoleGroupID bigint NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL);
  INSERT @AdminRoles(RoleGroupID,CompanyID)
  SELECT RG.RoleGroupID,RG.CompanyID FROM dbo.TDADRoleGroup RG
  WHERE RG.ProjectID=@CoreProjectID AND RG.ScopeType=N'C' AND RG.CompanyID IS NOT NULL AND RG.IsActive=1
    AND (UPPER(LTRIM(RTRIM(RG.RoleCode)))=N'ADMIN' OR UPPER(LTRIM(RTRIM(RG.RoleNameTH)))=N'ADMIN' OR RG.RoleNameTH=N'ผู้ดูแลระบบ');

  INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
  SELECT AR.RoleGroupID,@ProjectID,P.ScreenCode,P.ActionCode,1,N'migration'
  FROM @AdminRoles AR CROSS JOIN dbo.TDADPermission P
  WHERE P.ProjectID=@ProjectID AND P.IsActive=1 AND P.ScreenCode IN(N'41001',N'41002',N'41009')
    AND NOT EXISTS(SELECT 1 FROM dbo.TDADRoleGroupPermission RP WHERE RP.RoleGroupID=AR.RoleGroupID AND RP.ProjectID=@ProjectID AND RP.MenuCode=P.ScreenCode AND RP.ActionCode=P.ActionCode);
  UPDATE RP SET IsAllowed=1 FROM dbo.TDADRoleGroupPermission RP INNER JOIN @AdminRoles AR ON AR.RoleGroupID=RP.RoleGroupID
  WHERE RP.ProjectID=@ProjectID AND RP.MenuCode IN(N'41001',N'41002',N'41009');

  INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
  SELECT DISTINCT AR.CompanyID,UE.UserID,@ProjectID,0,1,SYSUTCDATETIME(),UE.UserID
  FROM @AdminRoles AR
  INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.RoleGroupID=AR.RoleGroupID AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
  INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=ERG.EmployeeID AND E.CompanyID=AR.CompanyID AND E.IsActive=1
  INNER JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=E.EmployeeID AND UE.CompanyID=AR.CompanyID AND UE.IsActive=1
  WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject UP WHERE UP.CompanyID=AR.CompanyID AND UP.UserID=UE.UserID AND UP.ProjectID=@ProjectID);

  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
GO