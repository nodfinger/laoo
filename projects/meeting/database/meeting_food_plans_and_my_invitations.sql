USE [DBTDMeeting];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.TDADMeetingBookingFoodPlan', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingBookingFoodPlan
    (
        BookingFoodPlanID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADMeetingBookingFoodPlan PRIMARY KEY,
        BookingID BIGINT NOT NULL,
        CompanyID BIGINT NOT NULL,
        OrderCutoffDateTime DATETIME2(0) NOT NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_TDADMeetingBookingFoodPlan_IsActive DEFAULT (1),
        CreateDate DATETIME2(0) NOT NULL
            CONSTRAINT DF_TDADMeetingBookingFoodPlan_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy BIGINT NOT NULL,
        UpdateDate DATETIME2(0) NULL,
        UpdateBy BIGINT NULL,
        CONSTRAINT FK_TDADMeetingBookingFoodPlan_Booking
            FOREIGN KEY (BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID) ON DELETE CASCADE,
        CONSTRAINT UX_TDADMeetingBookingFoodPlan_Booking UNIQUE (BookingID)
    );
    CREATE INDEX IX_TDADMeetingBookingFoodPlan_Company_Cutoff
        ON dbo.TDADMeetingBookingFoodPlan (CompanyID, OrderCutoffDateTime, IsActive);
END;

IF OBJECT_ID(N'dbo.TDADMeetingBookingFoodOption', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADMeetingBookingFoodOption
    (
        BookingFoodOptionID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADMeetingBookingFoodOption PRIMARY KEY,
        BookingID BIGINT NOT NULL,
        CompanyID BIGINT NOT NULL,
        FoodID BIGINT NOT NULL,
        CreateDate DATETIME2(0) NOT NULL
            CONSTRAINT DF_TDADMeetingBookingFoodOption_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy BIGINT NOT NULL,
        CONSTRAINT FK_TDADMeetingBookingFoodOption_Booking
            FOREIGN KEY (BookingID) REFERENCES dbo.TDADMeetingRoomBooking(BookingID) ON DELETE CASCADE,
        CONSTRAINT FK_TDADMeetingBookingFoodOption_Food
            FOREIGN KEY (FoodID) REFERENCES dbo.TDADMeetingFood(FoodID),
        CONSTRAINT UX_TDADMeetingBookingFoodOption_Booking_Food UNIQUE (BookingID, FoodID)
    );
    CREATE INDEX IX_TDADMeetingBookingFoodOption_Company_Food
        ON dbo.TDADMeetingBookingFoodOption (CompanyID, FoodID, BookingID);
END;

UPDATE dbo.TDADMainMenu
SET MenuName=N'การเชิญของฉัน',
    RouteName=N'meetingInvitationRsvp',
    RoutePath=N'/company/meeting-invitations',
    FeatureCode=N'MEETING_INVITATION',
    IconName=N'mark_email_read',
    ScreenType=2,
    IsActive=1,
    IsVisible=1,
    UpdateDate=SYSDATETIME()
WHERE MenuCode='13003';

IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode='13005')
BEGIN
    INSERT dbo.TDADMainMenu
    (
        MenuGroupCode,MenuCode,MenuName,RouteName,RoutePath,FeatureCode,
        IconName,SortOrder,ScreenType,IsActive,IsVisible,IsFavoriteAllowed,CreateDate
    )
    VALUES
    (
        '13','13005',N'เมนูอาหารสำหรับการประชุม',N'meetingFoodPlans',
        N'/company/meeting-food-plans',N'MEETING_FOOD_PLAN',N'room_service',
        25,1,1,1,1,SYSDATETIME()
    );
END;

UPDATE dbo.TDADMainMenu
SET MenuName=N'เมนูอาหารสำหรับการประชุม',
    RouteName=N'meetingFoodPlans',
    RoutePath=N'/company/meeting-food-plans',
    FeatureCode=N'MEETING_FOOD_PLAN',
    IconName=N'room_service',
    SortOrder=25,
    ScreenType=1,
    IsActive=1,
    IsVisible=1,
    IsFavoriteAllowed=1,
    UpdateDate=SYSDATETIME()
WHERE MenuCode='13005';

COMMIT TRANSACTION;
GO
