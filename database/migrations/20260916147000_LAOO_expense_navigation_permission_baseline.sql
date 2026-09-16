/* Core-owned LAOO_EXPENSE menu and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_EXPENSE' AND IsActive=1);
IF @ProjectID IS NULL THROW 52930,N'Active LAOO_EXPENSE project is required.',1;
DECLARE @MenuGroupCode char(2)=N'41';
UPDATE dbo.TDADMenuGroup SET AudienceType=N'C',MenuGroupName=N'ระบบบันทึกค่าใช้จ่าย',IconName=N'receipt_long_outlined',SortOrder=410,IsExpandedDefault=0,IsActive=1,ShowPermissionPoint=0,OpenOption=0,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=@MenuGroupCode;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode) INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption) VALUES(N'C',@MenuGroupCode,N'ระบบบันทึกค่าใช้จ่าย',N'receipt_long_outlined',410,0,1,SYSUTCDATETIME(),0,0);
DECLARE @Menus TABLE(MenuCode char(5) PRIMARY KEY,MenuName nvarchar(150),ScreenType int,RouteName nvarchar(150),RoutePath nvarchar(300),FeatureCode nvarchar(100),IconName nvarchar(100),SortOrder int);
INSERT @Menus VALUES
(N'41001',N'ตั้งค่าระบบค่าใช้จ่าย',2,N'expenseSettings',N'/company/expense-settings',N'EXPENSE_SETTINGS',N'settings_outlined',10),
(N'41002',N'ประเภทค่าใช้จ่าย',1,N'expenseCategories',N'/company/expense-categories',N'EXPENSE_CATEGORIES',N'category_outlined',20),
(N'41003',N'เงินทดรองและเคลียร์เงิน',4,N'expenseAdvances',N'/company/expense-advances',N'EXPENSE_ADVANCES',N'account_balance_wallet_outlined',30),
(N'41004',N'ใบขอเบิกค่าใช้จ่าย',4,N'expenseClaims',N'/company/expense-claims',N'EXPENSE_CLAIMS',N'receipt_long_outlined',40),
(N'41005',N'กล่องอนุมัติค่าใช้จ่าย',3,N'expenseApprovalInbox',N'/company/expense-approvals',N'EXPENSE_APPROVAL',N'approval_outlined',50),
(N'41006',N'ติดตามการจ่ายและเคลียร์เงิน',2,N'expenseSettlements',N'/company/expense-settlements',N'EXPENSE_SETTLEMENTS',N'paid_outlined',60),
(N'41007',N'ค่าใช้จ่ายของฉัน',4,N'myExpenses',N'/company/my-expenses',N'MY_EXPENSES',N'person_outline',70),
(N'41008',N'รายงานค่าใช้จ่าย',3,N'expenseReports',N'/company/expense-reports',N'EXPENSE_REPORTS',N'assessment_outlined',80);
IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON t.MenuCode=s.MenuCode WHERE t.ScreenType<>s.ScreenType OR ISNULL(t.RouteName,N'')<>s.RouteName OR ISNULL(t.RoutePath,N'')<>s.RoutePath) THROW 52931,N'LAOO_EXPENSE MenuCode conflicts with existing ScreenType or route.',1;
IF EXISTS(SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON(t.RouteName=s.RouteName OR t.RoutePath=s.RoutePath) AND t.MenuCode<>s.MenuCode) THROW 52932,N'LAOO_EXPENSE RouteName or RoutePath is already used.',1;
UPDATE t SET MenuGroupCode=@MenuGroupCode,MenuName=s.MenuName,ScreenType=s.ScreenType,RouteName=s.RouteName,RoutePath=s.RoutePath,FeatureCode=s.FeatureCode,IconName=s.IconName,SortOrder=s.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMainMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode;
INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint) SELECT MenuCode,@MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu t WHERE t.MenuCode=s.MenuCode);
/* Stay unavailable until the Expense owner provides real routes, API and migrations. */
UPDATE dbo.TDADProjectMenuGroup SET SortOrder=1,IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode) INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,@MenuGroupCode,1,0,SYSUTCDATETIME());
UPDATE t SET MenuGroupCode=@MenuGroupCode,SortOrder=s.SortOrder,IsActive=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADProjectMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode WHERE t.ProjectID=@ProjectID;
INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate) SELECT @ProjectID,MenuCode,@MenuGroupCode,SortOrder,0,SYSUTCDATETIME() FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu t WHERE t.ProjectID=@ProjectID AND t.MenuCode=s.MenuCode);
DECLARE @Permissions TABLE(MenuCode char(5),ActionCode nvarchar(50),PRIMARY KEY(MenuCode,ActionCode));
INSERT @Permissions VALUES
(N'41001',N'VIEW'),(N'41001',N'EDIT'),
(N'41002',N'VIEW'),(N'41002',N'CREATE'),(N'41002',N'EDIT'),(N'41002',N'DELETE'),
(N'41003',N'VIEW'),(N'41003',N'CREATE'),(N'41003',N'EDIT'),(N'41003',N'DELETE'),(N'41003',N'SUBMIT'),(N'41003',N'CANCEL'),(N'41003',N'ACT_ON_BEHALF'),
(N'41004',N'VIEW'),(N'41004',N'CREATE'),(N'41004',N'EDIT'),(N'41004',N'DELETE'),(N'41004',N'SUBMIT'),(N'41004',N'CANCEL'),(N'41004',N'ACT_ON_BEHALF'),
(N'41005',N'VIEW'),(N'41005',N'APPROVE'),(N'41005',N'SELF_APPROVE'),
(N'41006',N'VIEW'),(N'41006',N'CONFIRM_PAYMENT'),(N'41006',N'CONFIRM_SETTLEMENT'),
(N'41007',N'VIEW'),(N'41007',N'CREATE'),(N'41007',N'EDIT'),(N'41007',N'DELETE'),(N'41007',N'SUBMIT'),(N'41007',N'CANCEL'),
(N'41008',N'VIEW');
UPDATE t SET ScreenNameTH=m.MenuName,ScreenNameEN=m.FeatureCode,ActionNameTH=CASE p.ActionCode WHEN N'VIEW' THEN N'ดูข้อมูล' WHEN N'CREATE' THEN N'เพิ่มข้อมูล' WHEN N'EDIT' THEN N'แก้ไขข้อมูล' WHEN N'DELETE' THEN N'ลบข้อมูล' WHEN N'SUBMIT' THEN N'ส่งอนุมัติ' WHEN N'CANCEL' THEN N'ยกเลิก' WHEN N'ACT_ON_BEHALF' THEN N'ทำรายการแทน' WHEN N'APPROVE' THEN N'อนุมัติ' WHEN N'SELF_APPROVE' THEN N'อนุมัติรายการของตนเอง' WHEN N'CONFIRM_PAYMENT' THEN N'ยืนยันจ่ายเงิน' WHEN N'CONFIRM_SETTLEMENT' THEN N'ยืนยันเคลียร์เงิน' END,ActionNameEN=p.ActionCode,IsActive=1,ModifiedDate=SYSUTCDATETIME() FROM dbo.TDADPermission t JOIN @Permissions p ON p.MenuCode=t.ScreenCode AND p.ActionCode=t.ActionCode JOIN @Menus m ON m.MenuCode=p.MenuCode WHERE t.ProjectID=@ProjectID;
INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate) SELECT @ProjectID,p.MenuCode,m.MenuName,m.FeatureCode,p.ActionCode,CASE p.ActionCode WHEN N'VIEW' THEN N'ดูข้อมูล' WHEN N'CREATE' THEN N'เพิ่มข้อมูล' WHEN N'EDIT' THEN N'แก้ไขข้อมูล' WHEN N'DELETE' THEN N'ลบข้อมูล' WHEN N'SUBMIT' THEN N'ส่งอนุมัติ' WHEN N'CANCEL' THEN N'ยกเลิก' WHEN N'ACT_ON_BEHALF' THEN N'ทำรายการแทน' WHEN N'APPROVE' THEN N'อนุมัติ' WHEN N'SELF_APPROVE' THEN N'อนุมัติรายการของตนเอง' WHEN N'CONFIRM_PAYMENT' THEN N'ยืนยันจ่ายเงิน' WHEN N'CONFIRM_SETTLEMENT' THEN N'ยืนยันเคลียร์เงิน' END,p.ActionCode,1,SYSUTCDATETIME() FROM @Permissions p JOIN @Menus m ON m.MenuCode=p.MenuCode WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission t WHERE t.ProjectID=@ProjectID AND t.ScreenCode=p.MenuCode AND t.ActionCode=p.ActionCode);
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
GO
