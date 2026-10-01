SET NOCOUNT ON;

DECLARE @FiveSProjectID bigint=(
    SELECT ProjectID FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO_5S' AND IsActive=1
);
DECLARE @CoreProjectID bigint=(
    SELECT ProjectID FROM dbo.TDADProject
    WHERE ProjectCode=N'LAOO' AND IsActive=1
);

IF @FiveSProjectID IS NULL OR @CoreProjectID IS NULL
    THROW 50101,N'LAOO or LAOO_5S project was not found',1;

DECLARE @AdminRoles TABLE(
    RoleGroupID bigint NOT NULL PRIMARY KEY,
    CompanyID bigint NOT NULL
);

INSERT @AdminRoles(RoleGroupID,CompanyID)
SELECT RG.RoleGroupID,RG.CompanyID
FROM dbo.TDADRoleGroup RG
WHERE RG.ProjectID=@CoreProjectID
  AND RG.ScopeType='C'
  AND RG.CompanyID IS NOT NULL
  AND RG.IsActive=1
  AND (
      UPPER(LTRIM(RTRIM(RG.RoleCode)))=N'ADMIN'
      OR UPPER(LTRIM(RTRIM(RG.RoleNameTH)))=N'ADMIN'
      OR RG.RoleNameTH=N'ผู้ดูแลระบบ'
  );

INSERT dbo.TDADRoleGroupPermission(
    RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy
)
SELECT AR.RoleGroupID,@FiveSProjectID,P.ScreenCode,P.ActionCode,1,N'migration'
FROM @AdminRoles AR
CROSS JOIN dbo.TDADPermission P
WHERE P.ProjectID=@FiveSProjectID
  AND P.IsActive=1
  AND P.ScreenCode BETWEEN N'39001' AND N'39010'
  AND NOT EXISTS(
      SELECT 1
      FROM dbo.TDADRoleGroupPermission RP
      WHERE RP.RoleGroupID=AR.RoleGroupID
        AND RP.ProjectID=@FiveSProjectID
        AND RP.MenuCode=P.ScreenCode
        AND RP.ActionCode=P.ActionCode
  );

UPDATE RP
SET RP.IsAllowed=1
FROM dbo.TDADRoleGroupPermission RP
INNER JOIN @AdminRoles AR ON AR.RoleGroupID=RP.RoleGroupID
WHERE RP.ProjectID=@FiveSProjectID
  AND RP.MenuCode BETWEEN N'39001' AND N'39010';

INSERT dbo.TDADUserProject(
    CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate,CreateBy
)
SELECT DISTINCT AR.CompanyID,UE.UserID,@FiveSProjectID,0,1,SYSUTCDATETIME(),UE.UserID
FROM @AdminRoles AR
INNER JOIN dbo.TDADEmployeeRoleGroup ERG
    ON ERG.RoleGroupID=AR.RoleGroupID
   AND ERG.IsActive=1
   AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
   AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
INNER JOIN dbo.TDADEmployee E
    ON E.EmployeeID=ERG.EmployeeID
   AND E.CompanyID=AR.CompanyID
   AND E.IsActive=1
INNER JOIN dbo.TDADUserEmployee UE
    ON UE.EmployeeID=E.EmployeeID
   AND UE.CompanyID=AR.CompanyID
   AND UE.IsActive=1
WHERE NOT EXISTS(
    SELECT 1 FROM dbo.TDADUserProject UP
    WHERE UP.CompanyID=AR.CompanyID
      AND UP.UserID=UE.UserID
      AND UP.ProjectID=@FiveSProjectID
);

UPDATE UP
SET UP.IsActive=1,
    UP.UpdateDate=SYSUTCDATETIME(),
    UP.UpdateBy=UP.UserID
FROM dbo.TDADUserProject UP
INNER JOIN @AdminRoles AR ON AR.CompanyID=UP.CompanyID
INNER JOIN dbo.TDADUserEmployee UE
    ON UE.UserID=UP.UserID
   AND UE.CompanyID=UP.CompanyID
   AND UE.IsActive=1
INNER JOIN dbo.TDADEmployeeRoleGroup ERG
    ON ERG.EmployeeID=UE.EmployeeID
   AND ERG.RoleGroupID=AR.RoleGroupID
   AND ERG.IsActive=1
   AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
   AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
WHERE UP.ProjectID=@FiveSProjectID
  AND UP.IsActive=0;
