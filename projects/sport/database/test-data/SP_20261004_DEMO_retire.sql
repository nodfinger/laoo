SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Explicitly run only when retiring the SP261004 demo dataset.
BEGIN TRAN;
DECLARE @co bigint=(SELECT CompanyID FROM dbo.TDSTCompanySetUp WHERE CompanyCode=N'DEMO');
DECLARE @prefix nvarchar(20)=N'SP261004';
IF @co IS NULL THROW 57502,N'DEMO company missing',1;
IF EXISTS(SELECT 1 FROM dbo.TDPOSale S JOIN dbo.TDSPMember M
 ON M.CompanyID=S.CompanyID AND M.MemberID=S.SportMemberID
 WHERE S.CompanyID=@co AND M.MemberCode LIKE @prefix+N'%')
 THROW 57505,N'Sample members have POS sales; preserve sale audit and retire separately',1;
IF EXISTS(SELECT 1 FROM dbo.TDSPBooking B JOIN dbo.TDSPMember M
 ON M.CompanyID=B.CompanyID AND M.MemberID=B.MemberID
 WHERE B.CompanyID=@co AND M.MemberCode LIKE @prefix+N'%'
 AND (B.StatusCode<>N'CANCELLED' OR B.CancelReason<>N'HTTP smoke SP261004'))
 THROW 57503,N'Sample members have non-test or active bookings',1;
DELETE U FROM dbo.TDSPMembershipUse U JOIN dbo.TDSPBooking B
 ON B.CompanyID=U.CompanyID AND B.BookingID=U.BookingID
 JOIN dbo.TDSPMember M ON M.CompanyID=B.CompanyID AND M.MemberID=B.MemberID
 WHERE U.CompanyID=@co AND M.MemberCode LIKE @prefix+N'%'
 AND B.StatusCode=N'CANCELLED' AND B.CancelReason=N'HTTP smoke SP261004';
DELETE B FROM dbo.TDSPBooking B JOIN dbo.TDSPMember M
 ON M.CompanyID=B.CompanyID AND M.MemberID=B.MemberID
 WHERE B.CompanyID=@co AND M.MemberCode LIKE @prefix+N'%'
 AND B.StatusCode=N'CANCELLED' AND B.CancelReason=N'HTTP smoke SP261004';
DELETE P FROM dbo.TDSPPayment P JOIN dbo.TDSPMembership E
 ON E.CompanyID=P.CompanyID AND E.MembershipID=P.MembershipID
 JOIN dbo.TDSPMember M ON M.CompanyID=E.CompanyID AND M.MemberID=E.MemberID
 WHERE P.CompanyID=@co AND M.MemberCode LIKE @prefix+N'%';
DELETE E FROM dbo.TDSPMembership E JOIN dbo.TDSPMember M
 ON M.CompanyID=E.CompanyID AND M.MemberID=E.MemberID
 WHERE E.CompanyID=@co AND M.MemberCode LIKE @prefix+N'%';
DELETE X FROM dbo.TDSPPackageSport X JOIN dbo.TDSPPackage P
 ON P.CompanyID=X.CompanyID AND P.PackageID=X.PackageID
 WHERE X.CompanyID=@co AND P.PackageCode LIKE @prefix+N'%';
DELETE FROM dbo.TDSPPackage WHERE CompanyID=@co AND PackageCode LIKE @prefix+N'%';
DELETE FROM dbo.TDSPFacilityHours WHERE CompanyID=@co
 AND FacilityID IN(SELECT FacilityID FROM dbo.TDSPFacility WHERE CompanyID=@co AND FacilityCode LIKE @prefix+N'%');
DELETE FROM dbo.TDSPFacility WHERE CompanyID=@co AND FacilityCode LIKE @prefix+N'%';
DELETE FROM dbo.TDSPMember WHERE CompanyID=@co AND MemberCode LIKE @prefix+N'%';
DELETE R FROM dbo.TDSPPosPriceRule R JOIN dbo.TDSPMemberLevel L
 ON L.CompanyID=R.CompanyID AND L.LevelID=R.LevelID
 WHERE R.CompanyID=@co AND L.LevelCode LIKE @prefix+N'%';
DELETE FROM dbo.TDSPMemberLevel WHERE CompanyID=@co AND LevelCode LIKE @prefix+N'%';
DELETE FROM dbo.TDSPSportType WHERE CompanyID=@co AND SportCode LIKE @prefix+N'%';
DELETE FROM dbo.TDADPerson WHERE CompanyID=@co AND Email IN
 (N'sport-a-261004@example.invalid',N'sport-b-261004@example.invalid');
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SPORT');
DECLARE @actor bigint=(SELECT UserID FROM dbo.TDADUser WHERE CompanyID=@co AND Username=N'c111');
IF EXISTS(SELECT 1 FROM dbo.TDADCompanyProjectSubscription
 WHERE CompanyID=@co AND ProjectID=@project AND ReasonText=N'SP_20261004_DEMO acceptance test')
BEGIN
 DELETE FROM dbo.TDADUserPermission WHERE UserID=@actor AND ProjectID=@project
 AND Remark=N'SP_20261004_DEMO';
 DELETE FROM dbo.TDADUserProject WHERE CompanyID=@co AND UserID=@actor AND ProjectID=@project;
 DELETE FROM dbo.TDADCompanyFeature WHERE CompanyID=@co AND ProjectID=@project;
 DELETE FROM dbo.TDADCompanyProject WHERE CompanyID=@co AND ProjectID=@project;
 DELETE FROM dbo.TDADCompanyProjectSubscription WHERE CompanyID=@co AND ProjectID=@project
 AND ReasonText=N'SP_20261004_DEMO acceptance test';
END;
COMMIT;
