IF NOT EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'55002' AND ScreenType=1 AND IsActive=1)
    THROW 51000, 'Active menu 55002 with ScreenType 1 is required.', 1;
IF EXISTS (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'55002' AND MenuName NOT IN (N'ทะเบียนผู้ติดต่อ',N'ข้อมูลลูกค้า/ผู้ติดต่อ'))
    THROW 51001, 'Menu 55002 has an unexpected name; review before changing it.', 1;
UPDATE dbo.TDADMainMenu SET MenuName=N'ข้อมูลลูกค้า/ผู้ติดต่อ'
WHERE MenuCode=N'55002' AND MenuName=N'ทะเบียนผู้ติดต่อ';
