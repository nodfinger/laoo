SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTCompanyDataAccessDefault',N'U') IS NULL
CREATE TABLE dbo.TDSTCompanyDataAccessDefault (
 CompanyID bigint NOT NULL CONSTRAINT PK_CompanyDataAccessDefault PRIMARY KEY,
 ViewScope varchar(12) NOT NULL, EditScope varchar(12) NOT NULL, DeleteScope varchar(12) NOT NULL,
 ViewStaff bit NOT NULL, ViewHead bit NOT NULL, ViewManager bit NOT NULL,
 EditStaff bit NOT NULL, EditHead bit NOT NULL, EditManager bit NOT NULL,
 DeleteStaff bit NOT NULL, DeleteHead bit NOT NULL, DeleteManager bit NOT NULL,
 UpdateBy bigint NOT NULL, UpdateDate datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_CompanyDataAccessDefault_Scopes CHECK (ViewScope IN ('SELF','DEPARTMENT','DIVISION','ALL') AND EditScope IN ('SELF','DEPARTMENT','DIVISION','ALL') AND DeleteScope IN ('SELF','DEPARTMENT','DIVISION','ALL'))
);
INSERT dbo.TDSTCompanyDataAccessDefault(CompanyID,ViewScope,EditScope,DeleteScope,ViewStaff,ViewHead,ViewManager,EditStaff,EditHead,EditManager,DeleteStaff,DeleteHead,DeleteManager,UpdateBy,UpdateDate)
SELECT g.CompanyID,g.ViewScope,CASE WHEN g.EditMode='HEAD' THEN 'SELF' ELSE g.ViewScope END,CASE WHEN g.DeleteMode='HEAD' THEN 'SELF' ELSE g.ViewScope END,
 CASE WHEN g.ViewScope='SELF' THEN 0 ELSE 1 END,CASE WHEN g.ViewScope='SELF' THEN 0 ELSE 1 END,CASE WHEN g.ViewScope='DIVISION' THEN 1 ELSE 0 END,
 CASE WHEN g.EditMode='ALL' AND g.ViewScope<>'SELF' THEN 1 ELSE 0 END,CASE WHEN g.EditMode='ALL' AND g.ViewScope<>'SELF' THEN 1 ELSE 0 END,CASE WHEN g.EditMode='ALL' AND g.ViewScope='DIVISION' THEN 1 ELSE 0 END,
 CASE WHEN g.DeleteMode='ALL' AND g.ViewScope<>'SELF' THEN 1 ELSE 0 END,CASE WHEN g.DeleteMode='ALL' AND g.ViewScope<>'SELF' THEN 1 ELSE 0 END,CASE WHEN g.DeleteMode='ALL' AND g.ViewScope='DIVISION' THEN 1 ELSE 0 END,g.UpdateBy,COALESCE(g.UpdateDate,SYSUTCDATETIME())
FROM dbo.TDSTTravelClaimAccess g WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanyDataAccessDefault x WHERE x.CompanyID=g.CompanyID);

EXEC(N'CREATE OR ALTER FUNCTION dbo.LaooMenuDataAccessAllowed
(@company bigint,@actor bigint,@owner bigint,@menu nvarchar(20),@action varchar(6))
RETURNS bit AS
BEGIN
 IF @company IS NULL OR @actor IS NULL OR @company<=0 OR @actor<=0 OR @action NOT IN (''VIEW'',''EDIT'',''DELETE'') RETURN 0;
 DECLARE @flag bit, @scope varchar(12), @head bit, @manager bit, @staff bit, @global varchar(12), @mode varchar(12);
 SELECT @flag=M.AllowDataAccessSettings,
  @scope=CASE @action WHEN ''VIEW'' THEN COALESCE(P.ViewScope,D.ViewScope) WHEN ''EDIT'' THEN COALESCE(P.EditScope,D.EditScope) ELSE COALESCE(P.DeleteScope,D.DeleteScope) END,
  @head=CASE @action WHEN ''VIEW'' THEN COALESCE(P.ViewHead,D.ViewHead) WHEN ''EDIT'' THEN COALESCE(P.EditHead,D.EditHead) ELSE COALESCE(P.DeleteHead,D.DeleteHead) END,
  @manager=CASE @action WHEN ''VIEW'' THEN COALESCE(P.ViewManager,D.ViewManager) WHEN ''EDIT'' THEN COALESCE(P.EditManager,D.EditManager) ELSE COALESCE(P.DeleteManager,D.DeleteManager) END,
  @staff=CASE @action WHEN ''VIEW'' THEN COALESCE(P.ViewStaff,D.ViewStaff) WHEN ''EDIT'' THEN COALESCE(P.EditStaff,D.EditStaff) ELSE COALESCE(P.DeleteStaff,D.DeleteStaff) END,
  @global=ISNULL(G.ViewScope,''SELF''),
  @mode=CASE @action WHEN ''EDIT'' THEN ISNULL(G.EditMode,''HEAD'') WHEN ''DELETE'' THEN ISNULL(G.DeleteMode,''HEAD'') ELSE ''ALL'' END
 FROM dbo.TDADMainMenu M
 LEFT JOIN dbo.TDSTMenuDataAccessPolicy P ON P.CompanyID=@company AND P.MenuCode=M.MenuCode
 LEFT JOIN dbo.TDSTCompanyDataAccessDefault D ON D.CompanyID=@company
 LEFT JOIN dbo.TDSTTravelClaimAccess G ON G.CompanyID=@company
 WHERE M.MenuCode=@menu AND M.IsActive=1;
 IF @flag IS NULL RETURN 0;
 IF @flag=0 RETURN 1;
 IF EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@company AND U.UserID=@actor AND U.IsActive=1 AND U.IsCompanyAdmin=1) RETURN 1;
 IF @actor=@owner AND @owner>0 RETURN 1;
 IF @scope IS NULL
 BEGIN
  IF @global NOT IN (''SELF'',''DEPARTMENT'',''DIVISION'') OR @mode NOT IN (''ALL'',''HEAD'') RETURN 0;
  SET @scope=CASE WHEN @action<>''VIEW'' AND @mode=''HEAD'' THEN ''SELF'' ELSE @global END;
  SET @head=1; SET @manager=1; SET @staff=CASE WHEN @scope=''SELF'' THEN 0 ELSE 1 END;
 END;
 IF @scope=''SELF'' RETURN 0;
 IF @scope=''DEPARTMENT'' SET @manager=0;
 IF @scope=''ALL'' RETURN 1;
 DECLARE @actorDept bigint,@ownerDept bigint,@actorDiv bigint,@ownerDiv bigint;
 SELECT @actorDept=CASE WHEN COUNT(DISTINCT E.DepartmentOrgUnitID)=1 THEN MIN(E.DepartmentOrgUnitID) END,
        @actorDiv=CASE WHEN COUNT(DISTINCT E.DivisionOrgUnitID)=1 THEN MIN(E.DivisionOrgUnitID) END
 FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployee E ON E.CompanyID=UE.CompanyID AND E.EmployeeID=UE.EmployeeID AND E.IsActive=1
 WHERE UE.CompanyID=@company AND UE.UserID=@actor AND UE.IsActive=1;
 SELECT @ownerDept=CASE WHEN COUNT(DISTINCT E.DepartmentOrgUnitID)=1 THEN MIN(E.DepartmentOrgUnitID) END,
        @ownerDiv=CASE WHEN COUNT(DISTINCT E.DivisionOrgUnitID)=1 THEN MIN(E.DivisionOrgUnitID) END
 FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployee E ON E.CompanyID=UE.CompanyID AND E.EmployeeID=UE.EmployeeID AND E.IsActive=1
 WHERE UE.CompanyID=@company AND UE.UserID=@owner AND UE.IsActive=1;
 IF @staff=1 AND @scope=''DEPARTMENT'' AND @actorDept>0 AND @actorDept=@ownerDept RETURN 1;
 IF @staff=1 AND @scope=''DIVISION'' AND @actorDiv>0 AND @actorDiv=@ownerDiv RETURN 1;
 IF @head=1 AND @ownerDept>0 AND EXISTS (
  SELECT 1 FROM dbo.TDADUserEmployee UE
  JOIN dbo.TDADEmployee E ON E.CompanyID=UE.CompanyID AND E.EmployeeID=UE.EmployeeID AND E.IsActive=1
  JOIN dbo.TDADOrganizationSupervisor S ON S.CompanyID=UE.CompanyID AND S.EmployeeID=E.EmployeeID AND S.IsActive=1
  WHERE UE.CompanyID=@company AND UE.UserID=@actor AND UE.IsActive=1 AND S.SupervisorType=N''DEPARTMENT_HEAD'' AND S.OrgUnitID=@ownerDept) RETURN 1;
 IF @manager=1 AND @ownerDiv>0 AND EXISTS (
  SELECT 1 FROM dbo.TDADUserEmployee UE
  JOIN dbo.TDADEmployee E ON E.CompanyID=UE.CompanyID AND E.EmployeeID=UE.EmployeeID AND E.IsActive=1
  JOIN dbo.TDADOrganizationSupervisor S ON S.CompanyID=UE.CompanyID AND S.EmployeeID=E.EmployeeID AND S.IsActive=1
  WHERE UE.CompanyID=@company AND UE.UserID=@actor AND UE.IsActive=1 AND S.SupervisorType=N''DIVISION_MANAGER'' AND S.OrgUnitID=@ownerDiv) RETURN 1;
 RETURN 0;
END');
