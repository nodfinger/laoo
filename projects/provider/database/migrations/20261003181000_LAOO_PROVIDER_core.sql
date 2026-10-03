SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID(N'dbo.TDPRSystemSetting',N'U') IS NULL CREATE TABLE dbo.TDPRSystemSetting(
  CompanyID bigint NOT NULL PRIMARY KEY,ServiceCoverMaxMB int NOT NULL CONSTRAINT DF_TDPRSetting_Cover DEFAULT(2),ReviewExpiryDays int NOT NULL CONSTRAINT DF_TDPRSetting_Expiry DEFAULT(30),BayesianMinimumReviews int NOT NULL CONSTRAINT DF_TDPRSetting_Bayesian DEFAULT(5),RatingWeightNoGps decimal(5,2) NOT NULL CONSTRAINT DF_TDPRSetting_RatingNoGps DEFAULT(90),RecencyWeightNoGps decimal(5,2) NOT NULL CONSTRAINT DF_TDPRSetting_RecencyNoGps DEFAULT(10),RatingWeightGps decimal(5,2) NOT NULL CONSTRAINT DF_TDPRSetting_RatingGps DEFAULT(70),DistanceWeightGps decimal(5,2) NOT NULL CONSTRAINT DF_TDPRSetting_DistanceGps DEFAULT(20),RecencyWeightGps decimal(5,2) NOT NULL CONSTRAINT DF_TDPRSetting_RecencyGps DEFAULT(10),MaxDistanceKm decimal(8,2) NOT NULL CONSTRAINT DF_TDPRSetting_Distance DEFAULT(100),CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRSetting_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT CK_TDPRSetting CHECK(ServiceCoverMaxMB BETWEEN 1 AND 10 AND ReviewExpiryDays BETWEEN 1 AND 90 AND BayesianMinimumReviews BETWEEN 1 AND 100 AND MaxDistanceKm BETWEEN 1 AND 1000));

 IF OBJECT_ID(N'dbo.TDPRLocation',N'U') IS NULL CREATE TABLE dbo.TDPRLocation(
  LocationID bigint IDENTITY(1,1) PRIMARY KEY,LocationCode nvarchar(20) NOT NULL,LocationType nvarchar(20) NOT NULL,ParentLocationID bigint NULL,NameTH nvarchar(200) NOT NULL,NameEN nvarchar(200) NULL,Latitude decimal(10,7) NULL,Longitude decimal(10,7) NULL,SortOrder int NOT NULL CONSTRAINT DF_TDPRLocation_Sort DEFAULT(0),IsActive bit NOT NULL CONSTRAINT DF_TDPRLocation_Active DEFAULT(1),CreateBy bigint NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRLocation_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDPRLocation_Code UNIQUE(LocationCode),CONSTRAINT FK_TDPRLocation_Parent FOREIGN KEY(ParentLocationID) REFERENCES dbo.TDPRLocation(LocationID),CONSTRAINT CK_TDPRLocation_Type CHECK(LocationType IN(N'PROVINCE',N'DISTRICT',N'SUBDISTRICT')));

 IF OBJECT_ID(N'dbo.TDPRServiceType',N'U') IS NULL CREATE TABLE dbo.TDPRServiceType(
  ServiceTypeID bigint IDENTITY(1,1) PRIMARY KEY,ServiceCode nvarchar(40) NOT NULL,ServiceName nvarchar(200) NOT NULL,DescriptionText nvarchar(1000) NULL,IconName nvarchar(100) NULL,CoverImagePath nvarchar(1000) NULL,CoverMimeType nvarchar(100) NULL,CoverSizeBytes bigint NULL,SortOrder int NOT NULL CONSTRAINT DF_TDPRServiceType_Sort DEFAULT(0),IsActive bit NOT NULL CONSTRAINT DF_TDPRServiceType_Active DEFAULT(1),CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRServiceType_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDPRServiceType_Code UNIQUE(ServiceCode));

 IF OBJECT_ID(N'dbo.TDPRProviderProfile',N'U') IS NULL CREATE TABLE dbo.TDPRProviderProfile(
  ProviderID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,Slug nvarchar(160) NOT NULL,StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDPRProvider_Status DEFAULT(N'DRAFT'),CurrentRevisionID bigint NULL,PublishedRevisionID bigint NULL,SubmittedAt datetime2 NULL,ApprovedBy bigint NULL,ApprovedAt datetime2 NULL,ReturnReason nvarchar(2000) NULL,SuspendedReason nvarchar(2000) NULL,IsActive bit NOT NULL CONSTRAINT DF_TDPRProvider_Active DEFAULT(1),CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRProvider_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDPRProvider_Company UNIQUE(CompanyID),CONSTRAINT UQ_TDPRProvider_Slug UNIQUE(Slug),CONSTRAINT CK_TDPRProvider_Status CHECK(StatusCode IN(N'DRAFT',N'SUBMITTED',N'APPROVED',N'RETURNED',N'WITHDRAWN',N'SUSPENDED')));

 IF OBJECT_ID(N'dbo.TDPRProviderRevision',N'U') IS NULL CREATE TABLE dbo.TDPRProviderRevision(
  RevisionID bigint IDENTITY(1,1) PRIMARY KEY,ProviderID bigint NOT NULL,CompanyID bigint NOT NULL,RevisionNo int NOT NULL,DisplayName nvarchar(300) NOT NULL,SummaryText nvarchar(2000) NULL,PublicAddress nvarchar(1000) NULL,PublicTelephone nvarchar(100) NULL,PublicEmail nvarchar(320) NULL,LineID nvarchar(200) NULL,LineUrl nvarchar(1000) NULL,WebsiteUrl nvarchar(1000) NULL,LogoPath nvarchar(1000) NULL,StatusCode nvarchar(20) NOT NULL,CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRRevision_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT FK_TDPRRevision_Provider FOREIGN KEY(ProviderID) REFERENCES dbo.TDPRProviderProfile(ProviderID),CONSTRAINT UQ_TDPRRevision UNIQUE(ProviderID,RevisionNo),CONSTRAINT CK_TDPRRevision_Status CHECK(StatusCode IN(N'DRAFT',N'SUBMITTED',N'APPROVED',N'RETURNED',N'WITHDRAWN',N'SUSPENDED')));

 IF OBJECT_ID(N'dbo.TDPRProviderService',N'U') IS NULL CREATE TABLE dbo.TDPRProviderService(
  ProviderServiceID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,RevisionID bigint NOT NULL,ServiceTypeID bigint NOT NULL,CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRProviderService_Create DEFAULT(SYSUTCDATETIME()),CONSTRAINT FK_TDPRProviderService_Revision FOREIGN KEY(RevisionID) REFERENCES dbo.TDPRProviderRevision(RevisionID) ON DELETE CASCADE,CONSTRAINT FK_TDPRProviderService_Type FOREIGN KEY(ServiceTypeID) REFERENCES dbo.TDPRServiceType(ServiceTypeID),CONSTRAINT UQ_TDPRProviderService UNIQUE(RevisionID,ServiceTypeID));

 IF OBJECT_ID(N'dbo.TDPRProviderBranch',N'U') IS NULL CREATE TABLE dbo.TDPRProviderBranch(
  ProviderBranchID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,RevisionID bigint NOT NULL,BranchID bigint NULL,BranchName nvarchar(300) NOT NULL,AddressText nvarchar(1000) NULL,Telephone nvarchar(100) NULL,Latitude decimal(10,7) NULL,Longitude decimal(10,7) NULL,IsPrimary bit NOT NULL CONSTRAINT DF_TDPRBranch_Primary DEFAULT(0),CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRBranch_Create DEFAULT(SYSUTCDATETIME()),CONSTRAINT FK_TDPRBranch_Revision FOREIGN KEY(RevisionID) REFERENCES dbo.TDPRProviderRevision(RevisionID) ON DELETE CASCADE);

 IF OBJECT_ID(N'dbo.TDPRProviderArea',N'U') IS NULL CREATE TABLE dbo.TDPRProviderArea(
  ProviderAreaID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,RevisionID bigint NOT NULL,LocationID bigint NOT NULL,CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRProviderArea_Create DEFAULT(SYSUTCDATETIME()),CONSTRAINT FK_TDPRProviderArea_Revision FOREIGN KEY(RevisionID) REFERENCES dbo.TDPRProviderRevision(RevisionID) ON DELETE CASCADE,CONSTRAINT FK_TDPRProviderArea_Location FOREIGN KEY(LocationID) REFERENCES dbo.TDPRLocation(LocationID),CONSTRAINT UQ_TDPRProviderArea UNIQUE(RevisionID,LocationID));

 IF OBJECT_ID(N'dbo.TDPRReviewInvite',N'U') IS NULL CREATE TABLE dbo.TDPRReviewInvite(
  ReviewInviteID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,ProviderID bigint NOT NULL,ProviderBranchID bigint NULL,ServiceTypeID bigint NOT NULL,TokenHash char(64) NOT NULL,ServiceDate date NOT NULL,ReferenceNo nvarchar(100) NULL,ExpiresAt datetime2 NOT NULL,StatusCode nvarchar(20) NOT NULL CONSTRAINT DF_TDPRInvite_Status DEFAULT(N'ACTIVE'),UsedAt datetime2 NULL,CreateBy bigint NOT NULL,CreateDate datetime2 NOT NULL CONSTRAINT DF_TDPRInvite_Create DEFAULT(SYSUTCDATETIME()),UpdateBy bigint NULL,UpdateDate datetime2 NULL,
  CONSTRAINT UQ_TDPRInvite_Token UNIQUE(TokenHash),CONSTRAINT FK_TDPRInvite_Provider FOREIGN KEY(ProviderID) REFERENCES dbo.TDPRProviderProfile(ProviderID),CONSTRAINT FK_TDPRInvite_Service FOREIGN KEY(ServiceTypeID) REFERENCES dbo.TDPRServiceType(ServiceTypeID),CONSTRAINT CK_TDPRInvite_Status CHECK(StatusCode IN(N'ACTIVE',N'USED',N'CANCELLED',N'EXPIRED')));

 IF OBJECT_ID(N'dbo.TDPRReview',N'U') IS NULL CREATE TABLE dbo.TDPRReview(
  ReviewID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NOT NULL,ProviderID bigint NOT NULL,ReviewInviteID bigint NOT NULL,ServiceTypeID bigint NOT NULL,QualityScore tinyint NOT NULL,PunctualityScore tinyint NOT NULL,ServiceScore tinyint NOT NULL,ValueScore tinyint NOT NULL,CommentText nvarchar(2000) NULL,IsHidden bit NOT NULL CONSTRAINT DF_TDPRReview_Hidden DEFAULT(0),HiddenReason nvarchar(1000) NULL,CreatedAt datetime2 NOT NULL CONSTRAINT DF_TDPRReview_Create DEFAULT(SYSUTCDATETIME()),HiddenBy bigint NULL,HiddenAt datetime2 NULL,
  CONSTRAINT UQ_TDPRReview_Invite UNIQUE(ReviewInviteID),CONSTRAINT FK_TDPRReview_Invite FOREIGN KEY(ReviewInviteID) REFERENCES dbo.TDPRReviewInvite(ReviewInviteID),CONSTRAINT CK_TDPRReview_Scores CHECK(QualityScore BETWEEN 1 AND 5 AND PunctualityScore BETWEEN 1 AND 5 AND ServiceScore BETWEEN 1 AND 5 AND ValueScore BETWEEN 1 AND 5));

 IF OBJECT_ID(N'dbo.TDPRAudit',N'U') IS NULL CREATE TABLE dbo.TDPRAudit(
  AuditID bigint IDENTITY(1,1) PRIMARY KEY,CompanyID bigint NULL,EntityType nvarchar(40) NOT NULL,EntityID bigint NULL,ActionCode nvarchar(50) NOT NULL,DetailText nvarchar(2000) NULL,UserID bigint NULL,IpAddress nvarchar(80) NULL,ActionDate datetime2 NOT NULL CONSTRAINT DF_TDPRAudit_Date DEFAULT(SYSUTCDATETIME()));

 IF COL_LENGTH(N'dbo.TDPRProviderProfile',N'CurrentRevisionID') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_TDPRProvider_CurrentRevision') ALTER TABLE dbo.TDPRProviderProfile ADD CONSTRAINT FK_TDPRProvider_CurrentRevision FOREIGN KEY(CurrentRevisionID) REFERENCES dbo.TDPRProviderRevision(RevisionID);
 IF COL_LENGTH(N'dbo.TDPRProviderProfile',N'PublishedRevisionID') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_TDPRProvider_PublishedRevision') ALTER TABLE dbo.TDPRProviderProfile ADD CONSTRAINT FK_TDPRProvider_PublishedRevision FOREIGN KEY(PublishedRevisionID) REFERENCES dbo.TDPRProviderRevision(RevisionID);
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDPRProviderProfile') AND name=N'IX_TDPRProvider_Public') CREATE INDEX IX_TDPRProvider_Public ON dbo.TDPRProviderProfile(StatusCode,IsActive,PublishedRevisionID);
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDPRLocation') AND name=N'IX_TDPRLocation_Cascade') CREATE INDEX IX_TDPRLocation_Cascade ON dbo.TDPRLocation(ParentLocationID,LocationType,IsActive,SortOrder);
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDPRReview') AND name=N'IX_TDPRReview_Ranking') CREATE INDEX IX_TDPRReview_Ranking ON dbo.TDPRReview(ProviderID,IsHidden,CreatedAt DESC);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
