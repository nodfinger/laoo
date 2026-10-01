SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
  BEGIN TRANSACTION;

  DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_EXPENSE' AND IsActive=1);
  DECLARE @CoreProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO' AND IsActive=1);
  IF @ProjectID IS NULL OR @CoreProjectID IS NULL THROW 56411,N'Active LAOO and LAOO_EXPENSE projects are required.',1;

  IF OBJECT_ID(N'dbo.TDEXExpenseDocument',N'U') IS NULL
  BEGIN
    CREATE TABLE dbo.TDEXExpenseDocument(
      ExpenseDocumentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEXExpenseDocument PRIMARY KEY,
      CompanyID bigint NOT NULL,
      ProjectID bigint NOT NULL,
      DocumentTypeCode nvarchar(20) NOT NULL,
      DocumentNo nvarchar(40) NOT NULL,
      OwnerUserID bigint NOT NULL,
      AdvanceDocumentID bigint NULL,
      DocumentDate date NOT NULL,
      RequiredDate date NULL,
      PayeeName nvarchar(250) NOT NULL,
      PurposeText nvarchar(1000) NOT NULL,
      CurrencyCode nvarchar(3) NOT NULL CONSTRAINT DF_TDEXExpenseDocument_Currency DEFAULT(N'THB'),
      TotalAmount decimal(18,2) NOT NULL,
      StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDEXExpenseDocument_Status DEFAULT(N'DRAFT'),
      Remark nvarchar(2000) NULL,
      SubmittedBy bigint NULL, SubmittedDate datetime2(3) NULL,
      ApprovedBy bigint NULL, ApprovedDate datetime2(3) NULL,
      RejectedBy bigint NULL, RejectedDate datetime2(3) NULL, RejectReason nvarchar(1000) NULL,
      PaidBy bigint NULL, PaidDate datetime2(3) NULL,
      SettledBy bigint NULL, SettledDate datetime2(3) NULL,
      CancelledBy bigint NULL, CancelledDate datetime2(3) NULL,
      CreateBy bigint NOT NULL,
      CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDEXExpenseDocument_CreateDate DEFAULT SYSUTCDATETIME(),
      UpdateBy bigint NULL, UpdateDate datetime2(3) NULL,
      CONSTRAINT UQ_TDEXExpenseDocument_Company_No UNIQUE(CompanyID,DocumentNo),
      CONSTRAINT CK_TDEXExpenseDocument_Type CHECK(DocumentTypeCode IN(N'ADVANCE',N'CLAIM')),
      CONSTRAINT CK_TDEXExpenseDocument_Status CHECK(StatusCode IN(N'DRAFT',N'SUBMITTED',N'APPROVED',N'REJECTED',N'PAID',N'SETTLED',N'CANCELLED')),
      CONSTRAINT CK_TDEXExpenseDocument_Total CHECK(TotalAmount>0),
      CONSTRAINT FK_TDEXExpenseDocument_Advance FOREIGN KEY(AdvanceDocumentID) REFERENCES dbo.TDEXExpenseDocument(ExpenseDocumentID)
    );
    CREATE INDEX IX_TDEXExpenseDocument_Company_Type_Status ON dbo.TDEXExpenseDocument(CompanyID,DocumentTypeCode,StatusCode,DocumentDate DESC);
    CREATE INDEX IX_TDEXExpenseDocument_Company_Owner ON dbo.TDEXExpenseDocument(CompanyID,OwnerUserID,DocumentDate DESC);
    CREATE INDEX IX_TDEXExpenseDocument_Advance ON dbo.TDEXExpenseDocument(AdvanceDocumentID) WHERE AdvanceDocumentID IS NOT NULL;
  END;

  IF OBJECT_ID(N'dbo.TDEXExpenseDocumentDetail',N'U') IS NULL
  BEGIN
    CREATE TABLE dbo.TDEXExpenseDocumentDetail(
      ExpenseDocumentDetailID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEXExpenseDocumentDetail PRIMARY KEY,
      ExpenseDocumentID bigint NOT NULL,
      CompanyID bigint NOT NULL,
      LineSeq int NOT NULL,
      ExpenseTypeCode nvarchar(10) NOT NULL,
      DescriptionText nvarchar(500) NOT NULL,
      Amount decimal(18,2) NOT NULL,
      CONSTRAINT FK_TDEXExpenseDocumentDetail_Header FOREIGN KEY(ExpenseDocumentID) REFERENCES dbo.TDEXExpenseDocument(ExpenseDocumentID) ON DELETE CASCADE,
      CONSTRAINT UQ_TDEXExpenseDocumentDetail_Line UNIQUE(ExpenseDocumentID,LineSeq),
      CONSTRAINT CK_TDEXExpenseDocumentDetail_Line CHECK(LineSeq>0),
      CONSTRAINT CK_TDEXExpenseDocumentDetail_Amount CHECK(Amount>0)
    );
    CREATE INDEX IX_TDEXExpenseDocumentDetail_Header ON dbo.TDEXExpenseDocumentDetail(ExpenseDocumentID,LineSeq);
    CREATE INDEX IX_TDEXExpenseDocumentDetail_Company_Type ON dbo.TDEXExpenseDocumentDetail(CompanyID,ExpenseTypeCode);
  END;

  IF OBJECT_ID(N'dbo.TDEXExpenseDocumentHistory',N'U') IS NULL
  BEGIN
    CREATE TABLE dbo.TDEXExpenseDocumentHistory(
      ExpenseDocumentHistoryID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDEXExpenseDocumentHistory PRIMARY KEY,
      ExpenseDocumentID bigint NOT NULL,
      CompanyID bigint NOT NULL,
      ActionCode nvarchar(30) NOT NULL,
      FromStatusCode nvarchar(20) NULL,
      ToStatusCode nvarchar(20) NOT NULL,
      Remark nvarchar(1000) NULL,
      ActionBy bigint NOT NULL,
      ActionDate datetime2(3) NOT NULL CONSTRAINT DF_TDEXExpenseDocumentHistory_Date DEFAULT SYSUTCDATETIME(),
      CONSTRAINT FK_TDEXExpenseDocumentHistory_Header FOREIGN KEY(ExpenseDocumentID) REFERENCES dbo.TDEXExpenseDocument(ExpenseDocumentID) ON DELETE CASCADE
    );
    CREATE INDEX IX_TDEXExpenseDocumentHistory_Document ON dbo.TDEXExpenseDocumentHistory(ExpenseDocumentID,ActionDate,ExpenseDocumentHistoryID);
  END;

  UPDATE dbo.TDADProjectMenu SET IsActive=1,UpdateDate=SYSUTCDATETIME()
  WHERE ProjectID=@ProjectID AND MenuCode BETWEEN N'41003' AND N'41008';
  UPDATE dbo.TDADProjectMenuGroup SET IsActive=1,UpdateDate=SYSUTCDATETIME()
  WHERE ProjectID=@ProjectID AND MenuGroupCode=N'41';

  DECLARE @AdminRoles TABLE(RoleGroupID bigint NOT NULL PRIMARY KEY,CompanyID bigint NOT NULL);
  INSERT @AdminRoles(RoleGroupID,CompanyID)
  SELECT RG.RoleGroupID,RG.CompanyID FROM dbo.TDADRoleGroup RG
  WHERE RG.ProjectID=@CoreProjectID AND RG.ScopeType=N'C' AND RG.CompanyID IS NOT NULL AND RG.IsActive=1
    AND (UPPER(LTRIM(RTRIM(RG.RoleCode)))=N'ADMIN' OR UPPER(LTRIM(RTRIM(RG.RoleNameTH)))=N'ADMIN' OR RG.RoleNameTH=N'ผู้ดูแลระบบ');

  INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
  SELECT AR.RoleGroupID,@ProjectID,P.ScreenCode,P.ActionCode,1,N'migration'
  FROM @AdminRoles AR CROSS JOIN dbo.TDADPermission P
  WHERE P.ProjectID=@ProjectID AND P.IsActive=1 AND P.ScreenCode BETWEEN N'41003' AND N'41008'
    AND NOT EXISTS(SELECT 1 FROM dbo.TDADRoleGroupPermission RP WHERE RP.RoleGroupID=AR.RoleGroupID AND RP.ProjectID=@ProjectID AND RP.MenuCode=P.ScreenCode AND RP.ActionCode=P.ActionCode);
  UPDATE RP SET IsAllowed=1
  FROM dbo.TDADRoleGroupPermission RP INNER JOIN @AdminRoles AR ON AR.RoleGroupID=RP.RoleGroupID
  WHERE RP.ProjectID=@ProjectID AND RP.MenuCode BETWEEN N'41003' AND N'41008';

  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
GO