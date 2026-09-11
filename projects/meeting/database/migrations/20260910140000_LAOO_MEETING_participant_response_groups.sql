SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADMeetingBookingFoodGroup', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDADMeetingBookingFoodGroup
 (
  BookingFoodGroupID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingBookingFoodGroup PRIMARY KEY,
  BookingID BIGINT NOT NULL, CompanyID BIGINT NOT NULL, FoodTypeCode NVARCHAR(50) NOT NULL,
  MaxQuantity INT NOT NULL, IsRequired BIT NOT NULL CONSTRAINT DF_TDADMeetingBookingFoodGroup_IsRequired DEFAULT(0),
  IsActive BIT NOT NULL CONSTRAINT DF_TDADMeetingBookingFoodGroup_IsActive DEFAULT(1),
  CreateDate DATETIME2(0) NOT NULL CONSTRAINT DF_TDADMeetingBookingFoodGroup_CreateDate DEFAULT(SYSUTCDATETIME()),
  CreateBy BIGINT NOT NULL, UpdateDate DATETIME2(0) NULL, UpdateBy BIGINT NULL,
  CONSTRAINT FK_TDADMeetingBookingFoodGroup_Booking FOREIGN KEY(BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID) ON DELETE CASCADE,
  CONSTRAINT CK_TDADMeetingBookingFoodGroup_MaxQuantity CHECK(MaxQuantity BETWEEN 1 AND 99),
  CONSTRAINT UX_TDADMeetingBookingFoodGroup_Booking_Type UNIQUE(BookingID,FoodTypeCode)
 );
 CREATE INDEX IX_TDADMeetingBookingFoodGroup_Company_Booking ON dbo.TDADMeetingBookingFoodGroup(CompanyID,BookingID,IsActive);
END;

IF OBJECT_ID(N'dbo.TDADMeetingBookingRequirementQuestion', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDADMeetingBookingRequirementQuestion
 (
  RequirementQuestionID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingBookingRequirementQuestion PRIMARY KEY,
  BookingID BIGINT NOT NULL, CompanyID BIGINT NOT NULL, QuestionText NVARCHAR(300) NOT NULL,
  AnswerType VARCHAR(20) NOT NULL, IsRequired BIT NOT NULL CONSTRAINT DF_TDADMeetingBookingRequirementQuestion_IsRequired DEFAULT(0),
  SortOrder INT NOT NULL CONSTRAINT DF_TDADMeetingBookingRequirementQuestion_SortOrder DEFAULT(1),
  IsActive BIT NOT NULL CONSTRAINT DF_TDADMeetingBookingRequirementQuestion_IsActive DEFAULT(1),
  CreateDate DATETIME2(0) NOT NULL CONSTRAINT DF_TDADMeetingBookingRequirementQuestion_CreateDate DEFAULT(SYSUTCDATETIME()),
  CreateBy BIGINT NOT NULL, UpdateDate DATETIME2(0) NULL, UpdateBy BIGINT NULL,
  CONSTRAINT FK_TDADMeetingBookingRequirementQuestion_Booking FOREIGN KEY(BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID) ON DELETE CASCADE,
  CONSTRAINT CK_TDADMeetingBookingRequirementQuestion_AnswerType CHECK(AnswerType IN('TEXT','BOOLEAN','SINGLE','MULTIPLE','NUMBER')),
  CONSTRAINT CK_TDADMeetingBookingRequirementQuestion_SortOrder CHECK(SortOrder>0)
 );
 CREATE INDEX IX_TDADMeetingBookingRequirementQuestion_Company_Booking ON dbo.TDADMeetingBookingRequirementQuestion(CompanyID,BookingID,IsActive,SortOrder);
END;

IF OBJECT_ID(N'dbo.TDADMeetingBookingRequirementOption', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDADMeetingBookingRequirementOption
 (
  RequirementOptionID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingBookingRequirementOption PRIMARY KEY,
  RequirementQuestionID BIGINT NOT NULL, OptionText NVARCHAR(200) NOT NULL, SortOrder INT NOT NULL,
  IsActive BIT NOT NULL CONSTRAINT DF_TDADMeetingBookingRequirementOption_IsActive DEFAULT(1),
  CreateDate DATETIME2(0) NOT NULL CONSTRAINT DF_TDADMeetingBookingRequirementOption_CreateDate DEFAULT(SYSUTCDATETIME()),
  CreateBy BIGINT NOT NULL,
  CONSTRAINT FK_TDADMeetingBookingRequirementOption_Question FOREIGN KEY(RequirementQuestionID) REFERENCES dbo.TDADMeetingBookingRequirementQuestion(RequirementQuestionID) ON DELETE CASCADE,
  CONSTRAINT CK_TDADMeetingBookingRequirementOption_SortOrder CHECK(SortOrder>0)
 );
 CREATE INDEX IX_TDADMeetingBookingRequirementOption_Question ON dbo.TDADMeetingBookingRequirementOption(RequirementQuestionID,IsActive,SortOrder);
END;

IF OBJECT_ID(N'dbo.TDADMeetingParticipantRequirementAnswer', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDADMeetingParticipantRequirementAnswer
 (
  ParticipantRequirementAnswerID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingParticipantRequirementAnswer PRIMARY KEY,
  CompanyID BIGINT NOT NULL, BookingParticipantID BIGINT NOT NULL, RequirementQuestionID BIGINT NOT NULL,
  AnswerValue NVARCHAR(MAX) NULL, AnsweredByUserID BIGINT NOT NULL,
  CreateDate DATETIME2(0) NOT NULL CONSTRAINT DF_TDADMeetingParticipantRequirementAnswer_CreateDate DEFAULT(SYSUTCDATETIME()),
  CreateBy BIGINT NOT NULL, UpdateDate DATETIME2(0) NULL, UpdateBy BIGINT NULL,
  CONSTRAINT FK_TDADMeetingParticipantRequirementAnswer_Participant FOREIGN KEY(BookingParticipantID) REFERENCES dbo.TDADMeetingRoomBookingParticipant(BookingParticipantID) ON DELETE CASCADE,
  CONSTRAINT FK_TDADMeetingParticipantRequirementAnswer_Question FOREIGN KEY(RequirementQuestionID) REFERENCES dbo.TDADMeetingBookingRequirementQuestion(RequirementQuestionID),
  CONSTRAINT UX_TDADMeetingParticipantRequirementAnswer_Participant_Question UNIQUE(CompanyID,BookingParticipantID,RequirementQuestionID)
 );
END;

IF OBJECT_ID(N'dbo.TDADMeetingParticipantResponseHistory', N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDADMeetingParticipantResponseHistory
 (
  ParticipantResponseHistoryID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingParticipantResponseHistory PRIMARY KEY,
  CompanyID BIGINT NOT NULL, BookingParticipantID BIGINT NOT NULL,
  PreviousStatus VARCHAR(20) NULL, NewStatus VARCHAR(20) NOT NULL,
  ResponseRemark NVARCHAR(1000) NULL, ChangeReason NVARCHAR(500) NULL,
  FoodSnapshot NVARCHAR(MAX) NULL, RequirementSnapshot NVARCHAR(MAX) NULL,
  ChangedByUserID BIGINT NOT NULL,
  ChangedAtUtc DATETIME2(0) NOT NULL CONSTRAINT DF_TDADMeetingParticipantResponseHistory_ChangedAtUtc DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT FK_TDADMeetingParticipantResponseHistory_Participant FOREIGN KEY(BookingParticipantID) REFERENCES dbo.TDADMeetingRoomBookingParticipant(BookingParticipantID) ON DELETE CASCADE
 );
 CREATE INDEX IX_TDADMeetingParticipantResponseHistory_Participant ON dbo.TDADMeetingParticipantResponseHistory(CompanyID,BookingParticipantID,ChangedAtUtc DESC);
END;

IF COL_LENGTH(N'dbo.TDADMeetingBookingFoodOrder',N'IsCancelled') IS NULL
 ALTER TABLE dbo.TDADMeetingBookingFoodOrder ADD IsCancelled BIT NOT NULL CONSTRAINT DF_TDADMeetingBookingFoodOrder_IsCancelled DEFAULT(0) WITH VALUES;
IF COL_LENGTH(N'dbo.TDADMeetingBookingFoodOrder',N'CancelledAtUtc') IS NULL
 ALTER TABLE dbo.TDADMeetingBookingFoodOrder ADD CancelledAtUtc DATETIME2(0) NULL;
IF COL_LENGTH(N'dbo.TDADMeetingBookingFoodOrder',N'CancelledByUserID') IS NULL
 ALTER TABLE dbo.TDADMeetingBookingFoodOrder ADD CancelledByUserID BIGINT NULL;
IF COL_LENGTH(N'dbo.TDADMeetingBookingFoodOrder',N'CancelReason') IS NULL
 ALTER TABLE dbo.TDADMeetingBookingFoodOrder ADD CancelReason NVARCHAR(500) NULL;

INSERT dbo.TDADMeetingBookingFoodGroup(BookingID,CompanyID,FoodTypeCode,MaxQuantity,IsRequired,IsActive,CreateBy)
SELECT O.BookingID,O.CompanyID,F.FoodTypeCode,
 CASE WHEN MAX(ISNULL(O.Quantity,1))>99 THEN 99 ELSE MAX(ISNULL(O.Quantity,1)) END,
 0,1,MIN(O.CreateBy)
FROM dbo.TDADMeetingBookingFoodOption O
JOIN dbo.TDADMeetingFood F ON F.FoodID=O.FoodID AND F.CompanyID=O.CompanyID
WHERE NOT EXISTS
 (SELECT 1 FROM dbo.TDADMeetingBookingFoodGroup G WHERE G.BookingID=O.BookingID AND G.FoodTypeCode=F.FoodTypeCode)
GROUP BY O.BookingID,O.CompanyID,F.FoodTypeCode;

COMMIT TRANSACTION;
GO
