/* Core-owned LAOO_VOTE menu and permission baseline. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @ProjectID bigint = (SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode = N'LAOO_VOTE' AND IsActive = 1);
    IF @ProjectID IS NULL THROW 52960, N'Active LAOO_VOTE project is required.', 1;
    DECLARE @MenuGroupCode char(2) = N'44';
    IF EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode = @MenuGroupCode AND (AudienceType <> N'C' OR MenuGroupName <> N'ระบบโหวต'))
        THROW 52959, N'LAOO_VOTE MenuGroupCode conflicts with an existing group.', 1;
    UPDATE dbo.TDADMenuGroup SET AudienceType=N'C', MenuGroupName=N'ระบบโหวต', IconName=N'how_to_vote_outlined', SortOrder=440, IsExpandedDefault=0, IsActive=1, ShowPermissionPoint=0, OpenOption=0, UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=@MenuGroupCode;
    IF NOT EXISTS (SELECT 1 FROM dbo.TDADMenuGroup WHERE MenuGroupCode=@MenuGroupCode)
        INSERT dbo.TDADMenuGroup(AudienceType,MenuGroupCode,MenuGroupName,IconName,SortOrder,IsExpandedDefault,IsActive,CreateDate,ShowPermissionPoint,OpenOption)
        VALUES(N'C',@MenuGroupCode,N'ระบบโหวต',N'how_to_vote_outlined',440,0,1,SYSUTCDATETIME(),0,0);

    DECLARE @Menus TABLE(MenuCode char(5) PRIMARY KEY, MenuName nvarchar(150), ScreenType int, RouteName nvarchar(150), RoutePath nvarchar(300), FeatureCode nvarchar(100), IconName nvarchar(100), SortOrder int);
    INSERT @Menus VALUES
        (N'44001',N'ตั้งค่าระบบโหวต',2,N'voteSettings',N'/company/vote-settings',N'VOTE_SETTINGS',N'settings_outlined',10),
        (N'44002',N'หัวข้อโหวต',4,N'votes',N'/company/votes',N'VOTES',N'how_to_vote_outlined',20),
        (N'44003',N'กล่องอนุมัติหัวข้อโหวต',3,N'voteApprovalInbox',N'/company/vote-approvals',N'VOTE_APPROVAL',N'approval_outlined',30),
        (N'44004',N'โหวตของฉัน',3,N'myVotes',N'/company/my-votes',N'MY_VOTES',N'ballot_outlined',40),
        (N'44005',N'ผลและรายงานการโหวต',3,N'voteResults',N'/company/vote-results',N'VOTE_RESULTS',N'bar_chart_outlined',50);
    IF EXISTS (SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON t.MenuCode=s.MenuCode WHERE t.MenuGroupCode<>@MenuGroupCode OR t.ScreenType<>s.ScreenType OR ISNULL(t.RouteName,N'')<>s.RouteName OR ISNULL(t.RoutePath,N'')<>s.RoutePath)
        THROW 52961,N'LAOO_VOTE MenuCode conflicts with existing ScreenType or route.',1;
    IF EXISTS (SELECT 1 FROM @Menus s JOIN dbo.TDADMainMenu t ON (t.RouteName=s.RouteName OR t.RoutePath=s.RoutePath) AND t.MenuCode<>s.MenuCode)
        THROW 52962,N'LAOO_VOTE RouteName or RoutePath is already used.',1;
    UPDATE t SET MenuGroupCode=@MenuGroupCode,MenuName=s.MenuName,ScreenType=s.ScreenType,RouteName=s.RouteName,RoutePath=s.RoutePath,FeatureCode=s.FeatureCode,IconName=s.IconName,SortOrder=s.SortOrder,IsVisible=1,IsFavoriteAllowed=1,IsActive=1,ShowPermissionPoint=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADMainMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode;
    INSERT dbo.TDADMainMenu(MenuCode,MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,IsVisible,IsFavoriteAllowed,IsActive,CreateDate,ShowPermissionPoint)
    SELECT MenuCode,@MenuGroupCode,MenuName,ScreenType,RouteName,RoutePath,FeatureCode,IconName,SortOrder,1,1,1,SYSUTCDATETIME(),0 FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADMainMenu t WHERE t.MenuCode=s.MenuCode);

    /* Menus remain unavailable until real routes, API and project migrations exist. */
    UPDATE dbo.TDADProjectMenuGroup SET SortOrder=1,IsActive=0,UpdateDate=SYSUTCDATETIME() WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode;
    IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenuGroup WHERE ProjectID=@ProjectID AND MenuGroupCode=@MenuGroupCode)
        INSERT dbo.TDADProjectMenuGroup(ProjectID,MenuGroupCode,SortOrder,IsActive,CreateDate) VALUES(@ProjectID,@MenuGroupCode,1,0,SYSUTCDATETIME());
    UPDATE t SET MenuGroupCode=@MenuGroupCode,SortOrder=s.SortOrder,IsActive=0,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADProjectMenu t JOIN @Menus s ON s.MenuCode=t.MenuCode WHERE t.ProjectID=@ProjectID;
    INSERT dbo.TDADProjectMenu(ProjectID,MenuCode,MenuGroupCode,SortOrder,IsActive,CreateDate)
    SELECT @ProjectID,MenuCode,@MenuGroupCode,SortOrder,0,SYSUTCDATETIME() FROM @Menus s WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADProjectMenu t WHERE t.ProjectID=@ProjectID AND t.MenuCode=s.MenuCode);

    DECLARE @Permissions TABLE(MenuCode char(5),ActionCode nvarchar(50),PRIMARY KEY(MenuCode,ActionCode));
    INSERT @Permissions VALUES
        (N'44001',N'VIEW'),(N'44001',N'EDIT'),
        (N'44002',N'VIEW'),(N'44002',N'CREATE'),(N'44002',N'EDIT'),(N'44002',N'DELETE'),(N'44002',N'SUBMIT'),(N'44002',N'CANCEL'),(N'44002',N'PUBLISH'),(N'44002',N'CLOSE'),
        (N'44003',N'VIEW'),(N'44003',N'APPROVE'),(N'44003',N'SELF_APPROVE'),
        (N'44004',N'VIEW'),(N'44004',N'VOTE'),
        (N'44005',N'VIEW');
    UPDATE t SET ScreenNameTH=m.MenuName,ScreenNameEN=m.FeatureCode,ActionNameTH=CASE p.ActionCode WHEN N'VIEW' THEN N'ดูข้อมูล' WHEN N'CREATE' THEN N'เพิ่มข้อมูล' WHEN N'EDIT' THEN N'แก้ไขข้อมูล' WHEN N'DELETE' THEN N'ลบข้อมูล' WHEN N'SUBMIT' THEN N'ส่งอนุมัติ' WHEN N'CANCEL' THEN N'ยกเลิก' WHEN N'PUBLISH' THEN N'เผยแพร่' WHEN N'CLOSE' THEN N'ปิดรอบโหวต' WHEN N'APPROVE' THEN N'อนุมัติ' WHEN N'SELF_APPROVE' THEN N'อนุมัติรายการของตนเอง' WHEN N'VOTE' THEN N'ลงคะแนน' END,ActionNameEN=p.ActionCode,IsActive=1,ModifiedDate=SYSUTCDATETIME() FROM dbo.TDADPermission t JOIN @Permissions p ON p.MenuCode=t.ScreenCode AND p.ActionCode=t.ActionCode JOIN @Menus m ON m.MenuCode=p.MenuCode WHERE t.ProjectID=@ProjectID;
    INSERT dbo.TDADPermission(ProjectID,ScreenCode,ScreenNameTH,ScreenNameEN,ActionCode,ActionNameTH,ActionNameEN,IsActive,CreatedDate)
    SELECT @ProjectID,p.MenuCode,m.MenuName,m.FeatureCode,p.ActionCode,CASE p.ActionCode WHEN N'VIEW' THEN N'ดูข้อมูล' WHEN N'CREATE' THEN N'เพิ่มข้อมูล' WHEN N'EDIT' THEN N'แก้ไขข้อมูล' WHEN N'DELETE' THEN N'ลบข้อมูล' WHEN N'SUBMIT' THEN N'ส่งอนุมัติ' WHEN N'CANCEL' THEN N'ยกเลิก' WHEN N'PUBLISH' THEN N'เผยแพร่' WHEN N'CLOSE' THEN N'ปิดรอบโหวต' WHEN N'APPROVE' THEN N'อนุมัติ' WHEN N'SELF_APPROVE' THEN N'อนุมัติรายการของตนเอง' WHEN N'VOTE' THEN N'ลงคะแนน' END,p.ActionCode,1,SYSUTCDATETIME() FROM @Permissions p JOIN @Menus m ON m.MenuCode=p.MenuCode WHERE NOT EXISTS(SELECT 1 FROM dbo.TDADPermission t WHERE t.ProjectID=@ProjectID AND t.ScreenCode=p.MenuCode AND t.ActionCode=p.ActionCode);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO