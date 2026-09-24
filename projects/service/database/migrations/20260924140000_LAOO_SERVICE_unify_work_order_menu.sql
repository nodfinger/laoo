/* 17003 remains routable for old links; closeout now lives in 17002. */
IF OBJECT_ID(N'dbo.TDADProjectMenu', N'U') IS NOT NULL
BEGIN
    UPDATE PM SET IsActive = 0
    FROM dbo.TDADProjectMenu PM
    INNER JOIN dbo.TDADProject P ON P.ProjectID = PM.ProjectID
    WHERE P.ProjectCode = N'LAOO_SERVICE' AND PM.MenuCode = N'17003' AND PM.IsActive = 1;
END;
