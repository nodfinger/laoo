SET NOCOUNT ON;
SET XACT_ABORT ON;
IF COL_LENGTH(N'dbo.TDSTMenuDataAccessPolicy',N'ViewStaff') IS NULL
BEGIN
 ALTER TABLE dbo.TDSTMenuDataAccessPolicy ADD ViewStaff bit NOT NULL CONSTRAINT DF_MenuDataAccessPolicy_ViewStaff DEFAULT(0) WITH VALUES;
 EXEC sp_executesql N'UPDATE dbo.TDSTMenuDataAccessPolicy SET ViewStaff=CASE WHEN ViewScope IN (N''DEPARTMENT'',N''DIVISION'',N''ALL'') THEN 1 ELSE 0 END';
END;
IF COL_LENGTH(N'dbo.TDSTMenuDataAccessPolicy',N'EditStaff') IS NULL
BEGIN
 ALTER TABLE dbo.TDSTMenuDataAccessPolicy ADD EditStaff bit NOT NULL CONSTRAINT DF_MenuDataAccessPolicy_EditStaff DEFAULT(0) WITH VALUES;
 EXEC sp_executesql N'UPDATE dbo.TDSTMenuDataAccessPolicy SET EditStaff=CASE WHEN EditScope IN (N''DEPARTMENT'',N''DIVISION'',N''ALL'') THEN 1 ELSE 0 END';
END;
IF COL_LENGTH(N'dbo.TDSTMenuDataAccessPolicy',N'DeleteStaff') IS NULL
BEGIN
 ALTER TABLE dbo.TDSTMenuDataAccessPolicy ADD DeleteStaff bit NOT NULL CONSTRAINT DF_MenuDataAccessPolicy_DeleteStaff DEFAULT(0) WITH VALUES;
 EXEC sp_executesql N'UPDATE dbo.TDSTMenuDataAccessPolicy SET DeleteStaff=CASE WHEN DeleteScope IN (N''DEPARTMENT'',N''DIVISION'',N''ALL'') THEN 1 ELSE 0 END';
END;
SET NOCOUNT ON;
SET XACT_ABORT ON;
EXEC(N'CREATE OR ALTER FUNCTION dbo.LaooMenuDataAccessAllowed
(@company bigint,@actor bigint,@owner bigint,@menu nvarchar(20),@action varchar(6))
RETURNS bit AS
BEGIN
 IF @company IS NULL OR @actor IS NULL OR @company<=0 OR @actor<=0 OR @action NOT IN (''VIEW'',''EDIT'',''DELETE'') RETURN 0;
 DECLARE @flag bit, @scope varchar(12), @head bit, @manager bit, @staff bit, @global varchar(12), @mode varchar(12);
 SELECT @flag=M.AllowDataAccessSettings,
  @scope=CASE @action WHEN ''VIEW'' THEN P.ViewScope WHEN ''EDIT'' THEN P.EditScope ELSE P.DeleteScope END,
  @head=CASE @action WHEN ''VIEW'' THEN P.ViewHead WHEN ''EDIT'' THEN P.EditHead ELSE P.DeleteHead END,
  @manager=CASE @action WHEN ''VIEW'' THEN P.ViewManager WHEN ''EDIT'' THEN P.EditManager ELSE P.DeleteManager END,
  @staff=CASE @action WHEN ''VIEW'' THEN P.ViewStaff WHEN ''EDIT'' THEN P.EditStaff ELSE P.DeleteStaff END,
  @global=ISNULL(G.ViewScope,''SELF''),
  @mode=CASE @action WHEN ''EDIT'' THEN ISNULL(G.EditMode,''HEAD'') WHEN ''DELETE'' THEN ISNULL(G.DeleteMode,''HEAD'') ELSE ''ALL'' END
 FROM dbo.TDADMainMenu M
 LEFT JOIN dbo.TDSTMenuDataAccessPolicy P ON P.CompanyID=@company AND P.MenuCode=M.MenuCode
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
 IF @scope=''SELF'' BEGIN SET @head=1; SET @manager=1; END;
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
 IF @staff=1 AND @scope IN (''SELF'',''DEPARTMENT'') AND @actorDept>0 AND @actorDept=@ownerDept RETURN 1;
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
