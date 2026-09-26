/* Explicit evaluation selections made for each meeting booking. */
IF OBJECT_ID(N'dbo.TDADMeetingRoomBookingEvaluation',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingRoomBookingEvaluation
    (
        BookingEvaluationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADMeetingRoomBookingEvaluation PRIMARY KEY,
        CompanyID bigint NOT NULL,
        BookingID bigint NOT NULL,
        EvaluationSourceType varchar(50) NOT NULL,
        EvaluationTemplateID bigint NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_TDADMeetingRoomBookingEvaluation_IsActive DEFAULT(1),
        CreateDate datetime2 NOT NULL CONSTRAINT DF_TDADMeetingRoomBookingEvaluation_CreateDate DEFAULT(SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2 NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDADMeetingRoomBookingEvaluation UNIQUE(CompanyID,BookingID,EvaluationSourceType),
        CONSTRAINT CK_TDADMeetingRoomBookingEvaluation_Source CHECK(EvaluationSourceType IN ('MEETING_ROOM','TRAINING_COURSE','TRAINING_INSTRUCTOR'))
    );
    CREATE INDEX IX_TDADMeetingRoomBookingEvaluation_Completion ON dbo.TDADMeetingRoomBookingEvaluation(CompanyID,BookingID,IsActive);
END;
