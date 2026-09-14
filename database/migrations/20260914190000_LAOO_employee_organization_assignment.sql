/* Core effective-dated employee organization assignment. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.TDADEmployeeOrganizationAssignment',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.TDADEmployeeOrganizationAssignment(
  EmployeeOrganizationAssignmentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDADEmployeeOrganizationAssignment PRIMARY KEY,
  CompanyID bigint NOT NULL, EmployeeID bigint NOT NULL, HomeBranchID bigint NULL,
  DivisionOrgUnitID bigint NULL, DepartmentOrgUnitID bigint NULL,
  EffectiveFrom date NOT NULL, EffectiveTo date NULL, IsActive bit NOT NULL CONSTRAINT DF_TDADEmployeeOrganizationAssignment_IsActive DEFAULT(1),
  CreateDate datetime2 NOT NULL CONSTRAINT DF_TDADEmployeeOrganizationAssignment_CreateDate DEFAULT(SYSUTCDATETIME()),CreateBy bigint NULL,UpdateDate datetime2 NULL,UpdateBy bigint NULL,RowVersion rowversion NOT NULL,
  CONSTRAINT CK_TDADEmployeeOrganizationAssignment_Range CHECK(EffectiveTo IS NULL OR EffectiveTo>=EffectiveFrom),
  CONSTRAINT FK_TDADEmployeeOrganizationAssignment_Employee FOREIGN KEY(EmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID),
  CONSTRAINT FK_TDADEmployeeOrganizationAssignment_Branch FOREIGN KEY(HomeBranchID) REFERENCES dbo.TDADBranch(BranchID),
  CONSTRAINT FK_TDADEmployeeOrganizationAssignment_Division FOREIGN KEY(DivisionOrgUnitID) REFERENCES dbo.TDADOrganizationUnit(OrgUnitID),
  CONSTRAINT FK_TDADEmployeeOrganizationAssignment_Department FOREIGN KEY(DepartmentOrgUnitID) REFERENCES dbo.TDADOrganizationUnit(OrgUnitID));
 CREATE INDEX IX_TDADEmployeeOrganizationAssignment_Effective ON dbo.TDADEmployeeOrganizationAssignment(CompanyID,EmployeeID,EffectiveFrom,EffectiveTo) INCLUDE(HomeBranchID,DivisionOrgUnitID,DepartmentOrgUnitID,IsActive);
END
GO
CREATE OR ALTER TRIGGER dbo.TR_TDADEmployeeOrganizationAssignment_Validate ON dbo.TDADEmployeeOrganizationAssignment AFTER INSERT,UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted I LEFT JOIN dbo.TDADEmployee E ON E.EmployeeID=I.EmployeeID AND E.CompanyID=I.CompanyID WHERE E.EmployeeID IS NULL) THROW 53010,'EMPLOYEE_COMPANY_MISMATCH',1;
 IF EXISTS(SELECT 1 FROM inserted I WHERE I.HomeBranchID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADBranch B WHERE B.BranchID=I.HomeBranchID AND B.CompanyID=I.CompanyID)) THROW 53011,'BRANCH_COMPANY_MISMATCH',1;
 IF EXISTS(SELECT 1 FROM inserted I WHERE I.DivisionOrgUnitID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit U WHERE U.OrgUnitID=I.DivisionOrgUnitID AND U.CompanyID=I.CompanyID AND U.OwnerType=N'C' AND U.UnitType=N'DIV')) THROW 53012,'DIVISION_COMPANY_MISMATCH',1;
 IF EXISTS(SELECT 1 FROM inserted I WHERE I.DepartmentOrgUnitID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDADOrganizationUnit U WHERE U.OrgUnitID=I.DepartmentOrgUnitID AND U.CompanyID=I.CompanyID AND U.OwnerType=N'C' AND U.UnitType=N'DEP')) THROW 53013,'DEPARTMENT_COMPANY_MISMATCH',1;
 IF EXISTS(SELECT 1 FROM dbo.TDADEmployeeOrganizationAssignment A JOIN dbo.TDADEmployeeOrganizationAssignment B ON A.CompanyID=B.CompanyID AND A.EmployeeID=B.EmployeeID AND A.EmployeeOrganizationAssignmentID<B.EmployeeOrganizationAssignmentID AND A.IsActive=1 AND B.IsActive=1 AND A.EffectiveFrom<=ISNULL(B.EffectiveTo,CONVERT(date,'99991231')) AND B.EffectiveFrom<=ISNULL(A.EffectiveTo,CONVERT(date,'99991231'))) THROW 53014,'EFFECTIVE_RANGE_OVERLAP',1;
END
GO
COMMIT TRANSACTION;