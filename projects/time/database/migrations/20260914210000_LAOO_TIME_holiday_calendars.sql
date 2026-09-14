SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDTMHolidayCalendar',N'U') IS NULL
CREATE TABLE dbo.TDTMHolidayCalendar(
 HolidayCalendarID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMHolidayCalendar PRIMARY KEY,
 CompanyID bigint NOT NULL,CalendarCode varchar(30) NOT NULL,CalendarName nvarchar(150) NOT NULL,DescriptionText nvarchar(500) NULL,IsActive bit NOT NULL CONSTRAINT DF_TDTMHolidayCalendar_Active DEFAULT(1),
 CreateDate datetime2 NOT NULL CONSTRAINT DF_TDTMHolidayCalendar_CreateDate DEFAULT(SYSDATETIME()),CreateBy bigint NULL,UpdateDate datetime2 NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT UQ_TDTMHolidayCalendar_Code UNIQUE(CompanyID,CalendarCode));

IF OBJECT_ID(N'dbo.TDTMHolidayDate',N'U') IS NULL
CREATE TABLE dbo.TDTMHolidayDate(
 HolidayDateID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMHolidayDate PRIMARY KEY,
 CompanyID bigint NOT NULL,HolidayCalendarID bigint NOT NULL,HolidayDate date NOT NULL,HolidayName nvarchar(200) NOT NULL,IsActive bit NOT NULL CONSTRAINT DF_TDTMHolidayDate_Active DEFAULT(1),
 CreateDate datetime2 NOT NULL CONSTRAINT DF_TDTMHolidayDate_CreateDate DEFAULT(SYSDATETIME()),CreateBy bigint NULL,UpdateDate datetime2 NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT FK_TDTMHolidayDate_Calendar FOREIGN KEY(HolidayCalendarID) REFERENCES dbo.TDTMHolidayCalendar(HolidayCalendarID),CONSTRAINT UQ_TDTMHolidayDate UNIQUE(CompanyID,HolidayCalendarID,HolidayDate));

IF OBJECT_ID(N'dbo.TDTMBranchHolidayCalendarAssignment',N'U') IS NULL
CREATE TABLE dbo.TDTMBranchHolidayCalendarAssignment(
 BranchHolidayCalendarAssignmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMBranchHolidayCalendarAssignment PRIMARY KEY,
 CompanyID bigint NOT NULL,BranchID bigint NOT NULL,HolidayCalendarID bigint NOT NULL,EffectiveFrom date NOT NULL,EffectiveTo date NULL,IsActive bit NOT NULL CONSTRAINT DF_TDTMBranchHolidayCalendarAssignment_Active DEFAULT(1),
 CreateDate datetime2 NOT NULL CONSTRAINT DF_TDTMBranchHolidayCalendarAssignment_CreateDate DEFAULT(SYSDATETIME()),CreateBy bigint NULL,UpdateDate datetime2 NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT CK_TDTMBranchHolidayCalendarAssignment_Range CHECK(EffectiveTo IS NULL OR EffectiveTo>=EffectiveFrom),CONSTRAINT FK_TDTMBranchHolidayCalendarAssignment_Branch FOREIGN KEY(BranchID) REFERENCES dbo.TDADBranch(BranchID),CONSTRAINT FK_TDTMBranchHolidayCalendarAssignment_Calendar FOREIGN KEY(HolidayCalendarID) REFERENCES dbo.TDTMHolidayCalendar(HolidayCalendarID));

IF OBJECT_ID(N'dbo.TDTMBranchHolidayException',N'U') IS NULL
CREATE TABLE dbo.TDTMBranchHolidayException(
 BranchHolidayExceptionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMBranchHolidayException PRIMARY KEY,
 CompanyID bigint NOT NULL,BranchID bigint NOT NULL,HolidayDate date NOT NULL,IsHoliday bit NOT NULL,HolidayName nvarchar(200) NULL,Reason nvarchar(500) NULL,IsActive bit NOT NULL CONSTRAINT DF_TDTMBranchHolidayException_Active DEFAULT(1),
 CreateDate datetime2 NOT NULL CONSTRAINT DF_TDTMBranchHolidayException_CreateDate DEFAULT(SYSDATETIME()),CreateBy bigint NULL,UpdateDate datetime2 NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT FK_TDTMBranchHolidayException_Branch FOREIGN KEY(BranchID) REFERENCES dbo.TDADBranch(BranchID),CONSTRAINT UQ_TDTMBranchHolidayException UNIQUE(CompanyID,BranchID,HolidayDate));

IF OBJECT_ID(N'dbo.TDTMDefaultHolidayCalendarVersion',N'U') IS NULL
CREATE TABLE dbo.TDTMDefaultHolidayCalendarVersion(
 DefaultHolidayCalendarVersionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTMDefaultHolidayCalendarVersion PRIMARY KEY,
 CompanyID bigint NOT NULL,HolidayCalendarID bigint NOT NULL,EffectiveFrom date NOT NULL,EffectiveTo date NULL,IsActive bit NOT NULL CONSTRAINT DF_TDTMDefaultHolidayCalendarVersion_Active DEFAULT(1),
 CreateDate datetime2 NOT NULL CONSTRAINT DF_TDTMDefaultHolidayCalendarVersion_CreateDate DEFAULT(SYSDATETIME()),CreateBy bigint NULL,UpdateDate datetime2 NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
 CONSTRAINT CK_TDTMDefaultHolidayCalendarVersion_Range CHECK(EffectiveTo IS NULL OR EffectiveTo>=EffectiveFrom),CONSTRAINT FK_TDTMDefaultHolidayCalendarVersion_Calendar FOREIGN KEY(HolidayCalendarID) REFERENCES dbo.TDTMHolidayCalendar(HolidayCalendarID));

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMHolidayDate') AND name=N'IX_TDTMHolidayDate_Lookup')
 CREATE INDEX IX_TDTMHolidayDate_Lookup ON dbo.TDTMHolidayDate(CompanyID,HolidayCalendarID,HolidayDate) WHERE IsActive=1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMBranchHolidayCalendarAssignment') AND name=N'IX_TDTMBranchHolidayCalendarAssignment_Lookup')
 CREATE INDEX IX_TDTMBranchHolidayCalendarAssignment_Lookup ON dbo.TDTMBranchHolidayCalendarAssignment(CompanyID,BranchID,EffectiveFrom,EffectiveTo) WHERE IsActive=1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.TDTMBranchHolidayException') AND name=N'IX_TDTMBranchHolidayException_Lookup')
 CREATE INDEX IX_TDTMBranchHolidayException_Lookup ON dbo.TDTMBranchHolidayException(CompanyID,BranchID,HolidayDate) WHERE IsActive=1;
COMMIT TRANSACTION;
