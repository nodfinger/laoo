SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.TDADMainMenu', N'AllowDataAccessSettings') IS NULL
    ALTER TABLE dbo.TDADMainMenu ADD AllowDataAccessSettings bit NOT NULL
        CONSTRAINT DF_MainMenu_AllowDataAccessSettings DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.TDADMainMenu', N'RequiresApproval') IS NULL
    ALTER TABLE dbo.TDADMainMenu ADD RequiresApproval bit NOT NULL
        CONSTRAINT DF_MainMenu_RequiresApproval DEFAULT (0) WITH VALUES;

EXEC sp_executesql N'UPDATE dbo.TDADMainMenu SET AllowDataAccessSettings=1
    WHERE MenuCode IN (N''20001'',N''21001'',N''66001'');';

-- Keep the existing relative order of the other menus in the same group.
UPDATE dbo.TDADMainMenu SET SortOrder=CASE MenuCode
    WHEN N'10003' THEN 1 WHEN N'10004' THEN 2 WHEN N'10006' THEN 3
    WHEN N'10005' THEN 4 WHEN N'10007' THEN 5 WHEN N'10009' THEN 6
    WHEN N'10001' THEN 7 ELSE SortOrder END
WHERE MenuGroupCode=N'10' AND MenuCode IN (N'10003',N'10004',N'10006',N'10005',N'10007',N'10009',N'10001');

UPDATE pm SET SortOrder=m.SortOrder
FROM dbo.TDADProjectMenu pm JOIN dbo.TDADMainMenu m ON m.MenuCode=pm.MenuCode
WHERE pm.MenuGroupCode=N'10' AND pm.MenuCode IN (N'10003',N'10004',N'10006',N'10005',N'10007',N'10009',N'10001');
