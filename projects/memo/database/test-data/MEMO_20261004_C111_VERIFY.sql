SET NOCOUNT ON;
DECLARE @Run nvarchar(50)=N'MEMO-20261004-C111';DECLARE @Company bigint=(SELECT TOP 1 CompanyID FROM dbo.TDADUser WHERE Username=N'c111' AND IsActive=1);
SELECT ProjectCode,ProjectNameTH,IsActive FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_MEMO';
SELECT MenuCode,MenuName,ScreenType,RouteName,RoutePath,IsActive FROM dbo.TDADMainMenu WHERE MenuCode BETWEEN N'50001' AND N'50009' ORDER BY MenuCode;
SELECT TemporaryNo,MemoNo,SubjectText,StatusCode,ConfidentialityCode FROM dbo.TDMEMemo WHERE CompanyID=@Company AND TemporaryNo LIKE @Run+N'%' ORDER BY MemoID;
SELECT a.ActionCode,COUNT(*) Total FROM dbo.TDMEAudit a WHERE a.CompanyID=@Company AND a.DetailText=@Run GROUP BY a.ActionCode;
