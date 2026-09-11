-- Approved preview activation for DEMO / Laoo Platform only.
-- Attendance, leave, overtime and self-service menus remain disabled.
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ProjectID bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TIME' AND IsActive=1);
    DECLARE @CompanyID bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO' AND PartnerID=1 AND IsActive=1);
    DECLARE @PartnerID bigint=(SELECT PartnerID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@CompanyID);

    IF @ProjectID IS NULL THROW 52401,N'LAOO_TIME project is required.',1;
    IF @CompanyID IS NULL OR @PartnerID IS NULL THROW 52402,N'Active DEMO company is required for Time preview.',1;

    UPDATE dbo.TDADMenuGroup
    SET IsActive=1,UpdateDate=SYSDATETIME()
    WHERE MenuGroupCode=N'28';

    UPDATE dbo.TDADMainMenu
    SET IsActive=1,IsVisible=1,UpdateDate=SYSDATETIME()
    WHERE MenuCode IN(N'28001',N'28002');

    UPDATE dbo.TDADProjectMenuGroup
    SET IsActive=1,UpdateDate=SYSDATETIME()
    WHERE ProjectID=@ProjectID AND MenuGroupCode=N'28';

    UPDATE dbo.TDADProjectMenu
    SET IsActive=1,UpdateDate=SYSDATETIME()
    WHERE ProjectID=@ProjectID AND MenuCode IN(N'28001',N'28002');

    IF EXISTS(SELECT 1 FROM dbo.TDADCompanyProject WHERE CompanyID=@CompanyID AND ProjectID=@ProjectID)
        UPDATE dbo.TDADCompanyProject
        SET PartnerID=@PartnerID,IsEnabled=1,IsTrial=1,
            StartDate=COALESCE(StartDate,CONVERT(date,SYSDATETIME())),ExpireDate=NULL,
            UpdateDate=SYSDATETIME()
        WHERE CompanyID=@CompanyID AND ProjectID=@ProjectID;
    ELSE
        INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,StartDate,ExpireDate,CreateDate)
        VALUES(@ProjectID,@PartnerID,@CompanyID,1,1,CONVERT(date,SYSDATETIME()),NULL,SYSDATETIME());

    UPDATE UP
    SET IsActive=1,UpdateDate=SYSDATETIME()
    FROM dbo.TDADUserProject UP
    JOIN dbo.TDADUser U ON U.UserID=UP.UserID AND U.CompanyID=UP.CompanyID
    WHERE UP.CompanyID=@CompanyID AND UP.ProjectID=@ProjectID
      AND U.IsActive=1 AND U.IsCompanyAdmin=1;

    INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate)
    SELECT @CompanyID,U.UserID,@ProjectID,0,1,SYSDATETIME()
    FROM dbo.TDADUser U
    WHERE U.CompanyID=@CompanyID AND U.IsActive=1 AND U.IsCompanyAdmin=1
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.TDADUserProject UP
          WHERE UP.CompanyID=@CompanyID AND UP.UserID=U.UserID AND UP.ProjectID=@ProjectID
      );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
