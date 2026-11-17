IF OBJECT_ID(N'dbo.TDSTBusinessCardReviewSetting', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSTBusinessCardReviewSetting (
  CompanyID bigint NOT NULL, TargetType varchar(10) NOT NULL,
  ReviewMode varchar(10) NOT NULL, OrgLevel varchar(10) NOT NULL,
  UpdateBy bigint NOT NULL, UpdateDate datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_TDSTBusinessCardReviewSetting PRIMARY KEY (CompanyID,TargetType),
  CONSTRAINT CK_BusinessCardReview_Target CHECK (TargetType IN ('CUSTOMER','SUPPLIER')),
  CONSTRAINT CK_BusinessCardReview_Mode CHECK (ReviewMode IN ('ORG','EMPLOYEE')),
  CONSTRAINT CK_BusinessCardReview_Level CHECK (OrgLevel IN ('DIV','DEP'))
 );
END;
IF OBJECT_ID(N'dbo.TDSTBusinessCardReviewer', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDSTBusinessCardReviewer (
  CompanyID bigint NOT NULL, TargetType varchar(10) NOT NULL, EmployeeID bigint NOT NULL,
  CONSTRAINT PK_TDSTBusinessCardReviewer PRIMARY KEY (CompanyID,TargetType,EmployeeID),
  CONSTRAINT FK_BusinessCardReviewer_Setting FOREIGN KEY (CompanyID,TargetType)
   REFERENCES dbo.TDSTBusinessCardReviewSetting(CompanyID,TargetType) ON DELETE CASCADE
 );
END;
