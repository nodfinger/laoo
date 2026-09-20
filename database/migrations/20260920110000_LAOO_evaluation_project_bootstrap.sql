SET NOCOUNT ON; SET XACT_ABORT ON;
BEGIN TRY BEGIN TRANSACTION;
IF EXISTS(SELECT 1 FROM dbo.TDSTMasterGroup WHERE Code=N'013' AND Name<>N'ประเภทการประเมิน') THROW 53100,N'MasterGroup 013 conflicts.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDSTMasterGroup WHERE Code=N'013') INSERT dbo.TDSTMasterGroup(Code,Name) VALUES(N'013',N'ประเภทการประเมิน');
UPDATE dbo.TDADProject SET ProjectNameTH=N'ระบบประเมิน',ProjectNameEN=N'Evaluation',DescriptionText=N'ระบบแบบประเมินและผลการประเมิน',ProjectType=N'BUSINESS',IconName=N'rate_review_outlined',SortOrder=150,IsExpandedDefault=0,IsActive=1,UpdateDate=SYSUTCDATETIME() WHERE ProjectCode=N'LAOO_EVALUATION';
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_EVALUATION') INSERT dbo.TDADProject(ProjectCode,ProjectNameTH,ProjectNameEN,DescriptionText,IsActive,CreateDate,ProjectType,SortOrder,IconName,IsExpandedDefault) VALUES(N'LAOO_EVALUATION',N'ระบบประเมิน',N'Evaluation',N'ระบบแบบประเมินและผลการประเมิน',1,SYSUTCDATETIME(),N'BUSINESS',150,N'rate_review_outlined',0);
COMMIT TRANSACTION; END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK TRANSACTION; THROW; END CATCH;
GO
