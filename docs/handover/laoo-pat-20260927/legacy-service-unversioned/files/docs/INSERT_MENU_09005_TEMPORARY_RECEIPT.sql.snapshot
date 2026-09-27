/* MenuCode 09005: ใบเสร็จรับเงินชั่วคราว, ScreenType 4, Customer only */
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @MenuGroupCode nvarchar(20)=N'09';

IF NOT EXISTS
(
    SELECT 1 FROM dbo.TDADMenuGroup
    WHERE MenuGroupCode=@MenuGroupCode
      AND UPPER(LTRIM(RTRIM(AudienceType))) IN (N'C',N'A')
)
    THROW 50026, N'ไม่พบกลุ่มเมนู 09 สำหรับ Customer/Company Admin', 1;

IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'09005')
BEGIN
    UPDATE dbo.TDADMainMenu
       SET MenuName=N'ใบเสร็จรับเงินชั่วคราว',
           MenuGroupCode=@MenuGroupCode,
           RouteName=N'companyTemporaryReceipts',
           RoutePath=N'/company/temporary-receipts',
           ScreenType=4,
           FeatureCode=NULL,
           IconName=N'receipt_long_outlined',
           IsFavoriteAllowed=1,
           IsActive=1,
           IsVisible=1
     WHERE MenuCode=N'09005';
END
ELSE
BEGIN
    INSERT dbo.TDADMainMenu
    (
        MenuCode,MenuName,MenuGroupCode,RouteName,RoutePath,
        ScreenType,FeatureCode,IconName,SortOrder,
        IsFavoriteAllowed,IsActive,IsVisible
    )
    SELECT N'09005',N'ใบเสร็จรับเงินชั่วคราว',@MenuGroupCode,
           N'companyTemporaryReceipts',N'/company/temporary-receipts',
           4,NULL,N'receipt_long_outlined',ISNULL(MAX(SortOrder),0)+1,
           1,1,1
      FROM dbo.TDADMainMenu
     WHERE MenuGroupCode=@MenuGroupCode;
END;

COMMIT TRANSACTION;

SELECT MenuCode,MenuName,MenuGroupCode,RouteName,RoutePath,ScreenType
FROM dbo.TDADMainMenu WHERE MenuCode=N'09005';
