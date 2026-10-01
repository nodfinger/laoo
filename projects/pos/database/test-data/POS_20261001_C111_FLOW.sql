SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Run nvarchar(40)=N'POS-20261001-C111';
DECLARE @Company bigint=(SELECT TOP 1 CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
DECLARE @User bigint=(SELECT TOP 1 UserID FROM dbo.TDADUser WHERE Username=N'c111' AND CompanyID=@Company AND IsActive=1);
DECLARE @Project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_POS' AND IsActive=1);
DECLARE @Partner bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@Company AND IsActive=1);
DECLARE @AdminRole bigint=(SELECT TOP 1 RoleGroupID FROM dbo.TDADRoleGroup WHERE CompanyID=@Company AND RoleCode=N'ca' AND IsActive=1);
DECLARE @Branch bigint=(SELECT TOP 1 BranchID FROM dbo.TDADBranch WHERE CompanyID=@Company AND BranchCode=N'P110' AND IsActive=1);
DECLARE @Warehouse bigint=(SELECT TOP 1 WarehouseID FROM dbo.TDIVWarehouse WHERE CompanyID=@Company AND BranchID=@Branch AND WarehouseCode=N'W110-A' AND IsActive=1);
IF @Company IS NULL OR @User IS NULL OR @Project IS NULL OR @Partner IS NULL OR @AdminRole IS NULL OR @Branch IS NULL OR @Warehouse IS NULL
 THROW 56620,N'POS c111 fixture prerequisites are missing.',1;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE ProjectID=@Project AND PartnerID=@Partner AND CompanyID=@Company)
 INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,CreateDate,CreatedBy)
 VALUES(@Project,@Partner,@Company,1,0,SYSUTCDATETIME(),@User);
ELSE UPDATE dbo.TDADCompanyProject SET IsEnabled=1,ExpireDate=NULL,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@User
 WHERE ProjectID=@Project AND PartnerID=@Partner AND CompanyID=@Company;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project)
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy)
 VALUES(@Company,@User,@Project,0,1,SYSUTCDATETIME(),@User);
ELSE UPDATE dbo.TDADUserProject SET IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=@User
 WHERE CompanyID=@Company AND UserID=@User AND ProjectID=@Project;

MERGE dbo.TDADRoleGroupPermission AS target
USING(SELECT @AdminRole RoleGroupID,ProjectID,ScreenCode MenuCode,ActionCode
      FROM dbo.TDADPermission WHERE ProjectID=@Project AND IsActive=1) source
ON target.RoleGroupID=source.RoleGroupID AND target.ProjectID=source.ProjectID
 AND target.MenuCode=source.MenuCode AND target.ActionCode=source.ActionCode
WHEN MATCHED THEN UPDATE SET IsAllowed=1,UpdatedUtc=SYSUTCDATETIME(),UpdatedBy=N'fixture'
WHEN NOT MATCHED THEN INSERT(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedUtc,CreatedBy)
 VALUES(source.RoleGroupID,source.ProjectID,source.MenuCode,source.ActionCode,1,SYSUTCDATETIME(),N'fixture');

INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark,CreatedBy)
SELECT @User,@Project,p.PermissionID,1,1,@Run,@User
FROM dbo.TDADPermission p
WHERE p.ProjectID=@Project AND p.IsActive=1
 AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission x
                WHERE x.UserID=@User AND x.ProjectID=@Project AND x.PermissionID=p.PermissionID);
UPDATE up SET IsAllowed=1,IsActive=1,ModifiedDate=SYSUTCDATETIME(),ModifiedBy=@User
FROM dbo.TDADUserPermission up
JOIN dbo.TDADPermission p ON p.ProjectID=up.ProjectID AND p.PermissionID=up.PermissionID
WHERE up.UserID=@User AND up.ProjectID=@Project AND p.IsActive=1;

IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserBranch WHERE CompanyID=@Company AND UserID=@User AND BranchID=@Branch)
 INSERT dbo.TDADUserBranch(CompanyID,BranchID,UserID,IsDefault,IsActive,CreateBy)
 VALUES(@Company,@Branch,@User,1,1,@User);
ELSE UPDATE dbo.TDADUserBranch SET IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=@User
 WHERE CompanyID=@Company AND UserID=@User AND BranchID=@Branch;

IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanySetupSystemPOS WHERE CompanyID=@Company AND ProjectID=@Project)
 INSERT dbo.TDSTCompanySetupSystemPOS(CompanyID,ProjectID,IsEnabled,RequireOpenShift,AllowNegativeStock,TaxPercent,ReceiptPrefix,DefaultPaymentCode,CreateBy)
 VALUES(@Company,@Project,1,1,0,7,N'POS',N'CASH',@User);
ELSE UPDATE dbo.TDSTCompanySetupSystemPOS
 SET IsEnabled=1,RequireOpenShift=1,AllowNegativeStock=0,TaxPercent=7,ReceiptPrefix=N'POS',
     DefaultPaymentCode=N'CASH',UpdateBy=@User,UpdateDate=SYSUTCDATETIME()
 WHERE CompanyID=@Company AND ProjectID=@Project;

IF NOT EXISTS(SELECT 1 FROM dbo.TDPOOutlet WHERE CompanyID=@Company AND OutletCode=N'POS-HO')
 INSERT dbo.TDPOOutlet(CompanyID,ProjectID,OutletCode,OutletName,BranchID,WarehouseID,IsActive,CreateBy)
 VALUES(@Company,@Project,N'POS-HO',N'จุดขายสำนักงานใหญ่',@Branch,@Warehouse,1,@User);
ELSE UPDATE dbo.TDPOOutlet SET OutletName=N'จุดขายสำนักงานใหญ่',BranchID=@Branch,WarehouseID=@Warehouse,
 IsActive=1,UpdateBy=@User,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@Company AND OutletCode=N'POS-HO';
DECLARE @Outlet bigint=(SELECT OutletID FROM dbo.TDPOOutlet WHERE CompanyID=@Company AND OutletCode=N'POS-HO');

IF NOT EXISTS(SELECT 1 FROM dbo.TDPOTerminal WHERE CompanyID=@Company AND TerminalCode=N'POS-HO-01')
 INSERT dbo.TDPOTerminal(CompanyID,OutletID,TerminalCode,TerminalName,ActivationID,IsActive,CreateBy)
 VALUES(@Company,@Outlet,N'POS-HO-01',N'เครื่องขายสำนักงานใหญ่ 01','46004001-0000-4000-8000-000000000001',1,@User);
ELSE UPDATE dbo.TDPOTerminal SET OutletID=@Outlet,TerminalName=N'เครื่องขายสำนักงานใหญ่ 01',
 ActivationID='46004001-0000-4000-8000-000000000001',IsActive=1,UpdateBy=@User,UpdateDate=SYSUTCDATETIME()
 WHERE CompanyID=@Company AND TerminalCode=N'POS-HO-01';

INSERT dbo.TDPOOutletItem(CompanyID,OutletID,ItemID,Barcode,SalePriceOverride,IsSellable,ShowStock,CreateBy)
SELECT @Company,@Outlet,i.ItemID,N'POS-'+i.ItemCode,
       CASE WHEN i.UnitPrice>0 THEN NULL ELSE CAST(10 AS decimal(18,4)) END,1,1,@User
FROM dbo.TDIVItem i
WHERE i.CompanyID=@Company AND i.IsActive=1
 AND NOT EXISTS(SELECT 1 FROM dbo.TDPOOutletItem x
                WHERE x.CompanyID=@Company AND x.OutletID=@Outlet AND x.ItemID=i.ItemID);
UPDATE x SET IsSellable=1,ShowStock=1,UpdateBy=@User,UpdateDate=SYSUTCDATETIME()
FROM dbo.TDPOOutletItem x WHERE x.CompanyID=@Company AND x.OutletID=@Outlet;

COMMIT TRANSACTION;
