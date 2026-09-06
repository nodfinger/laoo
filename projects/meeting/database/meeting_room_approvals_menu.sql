USE [DBTDMeeting];
GO

BEGIN
    INSERT dbo.TDADMainMenu
    (
        MenuGroupCode, MenuCode, MenuName, RouteName, RoutePath, FeatureCode,
        IconName, SortOrder, ScreenType, IsActive, IsVisible, IsFavoriteAllowed
    )
    VALUES

    
    (
        N'13', N'13004', N'รายการรออนุมัติห้องประชุม', N'meetingRoomApprovals',
        N'/company/meeting-room-approvals', N'13004', N'approval_outlined',
        4, 2, 1, 1, 1
    );
END;
GO
