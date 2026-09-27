DECLARE @CompanyID bigint=(SELECT TOP(1) U.CompanyID FROM dbo.TDADUser U INNER JOIN dbo.TDADUserProject UP ON UP.UserID=U.UserID AND UP.CompanyID=U.CompanyID INNER JOIN dbo.TDADProject P ON P.ProjectID=UP.ProjectID AND P.ProjectCode=N'LAOO_VOTE' WHERE U.IsActive=1 ORDER BY U.IsCompanyAdmin DESC,U.UserID);
DECLARE @UserID bigint=(SELECT TOP(1) UserID FROM dbo.TDADUser WHERE CompanyID=@CompanyID AND IsActive=1 ORDER BY IsCompanyAdmin DESC,UserID);
DECLARE @EmployeeID bigint=(SELECT TOP(1) EmployeeID FROM dbo.TDADEmployee WHERE CompanyID=@CompanyID AND IsActive=1 ORDER BY EmployeeID);
DECLARE @DepartmentID bigint=(SELECT TOP(1) DepartmentOrgUnitID FROM dbo.TDADEmployee WHERE CompanyID=@CompanyID AND IsActive=1 AND DepartmentOrgUnitID IS NOT NULL ORDER BY EmployeeID);
IF @CompanyID IS NOT NULL AND @UserID IS NOT NULL AND @EmployeeID IS NOT NULL
BEGIN
  IF NOT EXISTS(SELECT 1 FROM dbo.TDVTTopic WHERE CompanyID=@CompanyID AND VoteNo=N'DEMO-VOTE-CUSTOM')
    INSERT dbo.TDVTTopic(CompanyID,VoteNo,TopicName,Description,TargetMode,IdentityMode,StatusCode,OpenDateTime,CloseDateTime,CreateBy)
    VALUES(@CompanyID,N'DEMO-VOTE-CUSTOM',N'ตัวอย่าง: กำหนดผู้โหวตเฉพาะกลุ่ม',N'ตัวอย่างผู้โหวตแบบกำหนดเองจากพนักงานและแผนก',N'CUSTOM',N'OPEN',N'DRAFT',DATEADD(day,1,SYSUTCDATETIME()),DATEADD(day,4,SYSUTCDATETIME()),@UserID);
  DECLARE @TopicID bigint=(SELECT VoteTopicID FROM dbo.TDVTTopic WHERE CompanyID=@CompanyID AND VoteNo=N'DEMO-VOTE-CUSTOM');
  IF NOT EXISTS(SELECT 1 FROM dbo.TDVTTopicOption WHERE VoteTopicID=@TopicID) INSERT dbo.TDVTTopicOption(CompanyID,VoteTopicID,OptionText,SortOrder) VALUES(@CompanyID,@TopicID,N'เห็นด้วย',1),(@CompanyID,@TopicID,N'ไม่เห็นด้วย',2);
  IF NOT EXISTS(SELECT 1 FROM dbo.TDVTTopicTarget WHERE VoteTopicID=@TopicID AND TargetType=N'EMPLOYEE') INSERT dbo.TDVTTopicTarget(CompanyID,VoteTopicID,TargetType,TargetID) VALUES(@CompanyID,@TopicID,N'EMPLOYEE',@EmployeeID);
  IF @DepartmentID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDVTTopicTarget WHERE VoteTopicID=@TopicID AND TargetType=N'DEPARTMENT') INSERT dbo.TDVTTopicTarget(CompanyID,VoteTopicID,TargetType,TargetID) VALUES(@CompanyID,@TopicID,N'DEPARTMENT',@DepartmentID);
END
