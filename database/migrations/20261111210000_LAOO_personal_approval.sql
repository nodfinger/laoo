SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDSTPersonalApprovalStep',N'U') IS NULL
CREATE TABLE dbo.TDSTPersonalApprovalStep (
 CompanyID bigint NOT NULL,
 MenuCode char(5) NOT NULL,
 RequesterEmployeeID bigint NOT NULL,
 StepNo int NOT NULL,
 ApproverEmployeeID bigint NOT NULL,
 UpdateBy bigint NOT NULL,
 UpdateDate datetime2 NOT NULL CONSTRAINT DF_PersonalApprovalStep_Date DEFAULT SYSUTCDATETIME(),
 CONSTRAINT PK_PersonalApprovalStep PRIMARY KEY(CompanyID,MenuCode,RequesterEmployeeID,StepNo),
 CONSTRAINT UQ_PersonalApprovalStep_Approver UNIQUE(CompanyID,MenuCode,RequesterEmployeeID,ApproverEmployeeID),
 CONSTRAINT CK_PersonalApprovalStep_Valid CHECK(StepNo>0 AND RequesterEmployeeID<>ApproverEmployeeID),
 CONSTRAINT FK_PersonalApprovalStep_Menu FOREIGN KEY(MenuCode) REFERENCES dbo.TDADMainMenu(MenuCode),
 CONSTRAINT FK_PersonalApprovalStep_Requester FOREIGN KEY(RequesterEmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID),
 CONSTRAINT FK_PersonalApprovalStep_Approver FOREIGN KEY(ApproverEmployeeID) REFERENCES dbo.TDADEmployee(EmployeeID)
);
