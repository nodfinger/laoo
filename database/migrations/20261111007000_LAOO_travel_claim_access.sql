SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTTravelClaimAccess',N'U') IS NULL
CREATE TABLE dbo.TDSTTravelClaimAccess (
 CompanyID bigint NOT NULL CONSTRAINT PK_TravelClaimAccess PRIMARY KEY,
 ViewScope varchar(12) NOT NULL CONSTRAINT DF_TravelClaimAccess_Scope DEFAULT 'SELF',
 EditMode varchar(12) NOT NULL CONSTRAINT DF_TravelClaimAccess_Edit DEFAULT 'HEAD',
 DeleteMode varchar(12) NOT NULL CONSTRAINT DF_TravelClaimAccess_Delete DEFAULT 'HEAD',
 UpdateBy bigint NOT NULL, UpdateDate datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_TravelClaimAccess_Scope CHECK (ViewScope IN ('SELF','DEPARTMENT','DIVISION')),
 CONSTRAINT CK_TravelClaimAccess_Edit CHECK (EditMode IN ('ALL','HEAD')),
 CONSTRAINT CK_TravelClaimAccess_Delete CHECK (DeleteMode IN ('ALL','HEAD'))
);
EXEC(N'CREATE OR ALTER FUNCTION dbo.LaooTravelClaimCanAccess(@company bigint,@actor bigint,@owner bigint,@action varchar(6))
RETURNS bit AS
BEGIN
 IF @company IS NULL OR @actor IS NULL OR @owner IS NULL RETURN 0;
 IF @actor=@owner RETURN 1;
 DECLARE @scope varchar(12), @mode varchar(12);
 SELECT @scope=ViewScope,@mode=CASE WHEN @action=''EDIT'' THEN EditMode WHEN @action=''DELETE'' THEN DeleteMode ELSE ''ALL'' END
 FROM dbo.TDSTTravelClaimAccess WHERE CompanyID=@company;
 IF @scope NOT IN (''DEPARTMENT'',''DIVISION'') OR @action NOT IN (''VIEW'',''EDIT'',''DELETE'') RETURN 0;
 IF EXISTS (
  SELECT 1 FROM dbo.TDADUserEmployee AU
  JOIN dbo.TDADEmployee A ON A.CompanyID=AU.CompanyID AND A.EmployeeID=AU.EmployeeID AND A.IsActive=1
  JOIN dbo.TDADUserEmployee OU ON OU.CompanyID=AU.CompanyID AND OU.UserID=@owner AND OU.IsActive=1
  JOIN dbo.TDADEmployee O ON O.CompanyID=OU.CompanyID AND O.EmployeeID=OU.EmployeeID AND O.IsActive=1
  WHERE AU.CompanyID=@company AND AU.UserID=@actor AND AU.IsActive=1
    AND ((@scope=''DEPARTMENT'' AND A.DepartmentOrgUnitID IS NOT NULL AND A.DepartmentOrgUnitID=O.DepartmentOrgUnitID)
      OR (@scope=''DIVISION'' AND A.DivisionOrgUnitID IS NOT NULL AND A.DivisionOrgUnitID=O.DivisionOrgUnitID))
    AND (@action=''VIEW'' OR @mode=''ALL'' OR (@mode=''HEAD'' AND EXISTS (
      SELECT 1 FROM dbo.TDADOrganizationSupervisor S JOIN dbo.TDADOrganizationUnit U ON U.CompanyID=S.CompanyID AND U.OrgUnitID=S.OrgUnitID AND U.IsActive=1
      WHERE S.CompanyID=@company AND S.EmployeeID=A.EmployeeID AND S.IsActive=1
        AND ((@scope=''DEPARTMENT'' AND S.SupervisorType=N''DEPARTMENT_HEAD'' AND U.UnitType=N''DEP'' AND S.OrgUnitID=O.DepartmentOrgUnitID)
          OR (@scope=''DIVISION'' AND S.SupervisorType=N''DIVISION_MANAGER'' AND U.UnitType=N''DIV'' AND S.OrgUnitID=O.DivisionOrgUnitID)))))
 ) RETURN 1;
 RETURN 0;
END');
