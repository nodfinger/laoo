SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMasterGroup WHERE Code=N'014')
    INSERT dbo.TDSTMasterGroup(Code,Name) VALUES(N'014',N'หัวข้อแจ้งซ่อม');

IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014' AND MasterCode=N'00001' AND OwnerType=N'L' AND ISNULL(OwnerPartnerID,0)=0 AND ISNULL(OwnerCompanyID,0)=0)
    INSERT dbo.TDSTMaster(MasterGroupCode,MasterCode,Name,Seq,OrderBy,ShortCode,OwnerType,OwnerPartnerID,OwnerCompanyID) VALUES(N'014',N'00001',N'อุปกรณ์ชำรุด',1,N'Seq',N'EQUIPMENT',N'L',NULL,NULL);
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014' AND MasterCode=N'00002' AND OwnerType=N'L' AND ISNULL(OwnerPartnerID,0)=0 AND ISNULL(OwnerCompanyID,0)=0)
    INSERT dbo.TDSTMaster(MasterGroupCode,MasterCode,Name,Seq,OrderBy,ShortCode,OwnerType,OwnerPartnerID,OwnerCompanyID) VALUES(N'014',N'00002',N'ระบบไฟฟ้า',2,N'Seq',N'ELECTRICAL',N'L',NULL,NULL);
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014' AND MasterCode=N'00003' AND OwnerType=N'L' AND ISNULL(OwnerPartnerID,0)=0 AND ISNULL(OwnerCompanyID,0)=0)
    INSERT dbo.TDSTMaster(MasterGroupCode,MasterCode,Name,Seq,OrderBy,ShortCode,OwnerType,OwnerPartnerID,OwnerCompanyID) VALUES(N'014',N'00003',N'ระบบประปา',3,N'Seq',N'PLUMBING',N'L',NULL,NULL);
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014' AND MasterCode=N'00004' AND OwnerType=N'L' AND ISNULL(OwnerPartnerID,0)=0 AND ISNULL(OwnerCompanyID,0)=0)
    INSERT dbo.TDSTMaster(MasterGroupCode,MasterCode,Name,Seq,OrderBy,ShortCode,OwnerType,OwnerPartnerID,OwnerCompanyID) VALUES(N'014',N'00004',N'เครื่องปรับอากาศ',4,N'Seq',N'AIR_CONDITIONER',N'L',NULL,NULL);
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014' AND MasterCode=N'00005' AND OwnerType=N'L' AND ISNULL(OwnerPartnerID,0)=0 AND ISNULL(OwnerCompanyID,0)=0)
    INSERT dbo.TDSTMaster(MasterGroupCode,MasterCode,Name,Seq,OrderBy,ShortCode,OwnerType,OwnerPartnerID,OwnerCompanyID) VALUES(N'014',N'00005',N'ทำความสะอาด',5,N'Seq',N'CLEANING',N'L',NULL,NULL);
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'014' AND MasterCode=N'00006' AND OwnerType=N'L' AND ISNULL(OwnerPartnerID,0)=0 AND ISNULL(OwnerCompanyID,0)=0)
    INSERT dbo.TDSTMaster(MasterGroupCode,MasterCode,Name,Seq,OrderBy,ShortCode,OwnerType,OwnerPartnerID,OwnerCompanyID) VALUES(N'014',N'00006',N'อื่น ๆ (ระบุเอง)',99,N'Seq',N'OTHER',N'L',NULL,NULL);
