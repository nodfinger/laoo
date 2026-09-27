SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDSTCompanySetUp', N'BusinessTypeCode') IS NULL
BEGIN
    ALTER TABLE dbo.TDSTCompanySetUp
        ADD BusinessTypeCode nvarchar(20) NULL;
END;

GO

UPDATE dbo.TDSTCompanySetUp
SET BusinessTypeCode = N'COMPANY',
    UpdateDate = SYSUTCDATETIME()
WHERE OwnerType = 'C'
  AND NULLIF(LTRIM(RTRIM(BusinessTypeCode)), N'') IS NULL;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_TDSTCompanySetUp_BusinessTypeCode'
)
BEGIN
    ALTER TABLE dbo.TDSTCompanySetUp
        ADD CONSTRAINT CK_TDSTCompanySetUp_BusinessTypeCode
        CHECK
        (
            BusinessTypeCode IS NULL
            OR BusinessTypeCode IN (N'COMPANY', N'DORMITORY', N'SERVICE_CENTER')
        );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDSTMasterGroup
    WHERE Code = N'012'
)
BEGIN
    INSERT dbo.TDSTMasterGroup(Code, Name)
    VALUES (N'012', N'ประเภทธุรกิจ Company');
END;

-- SERVICE_CENTER requires 14 characters; existing codes are preserved.
IF COL_LENGTH(N'dbo.TDSTMasterCont', N'Code') < 40
    ALTER TABLE dbo.TDSTMasterCont ALTER COLUMN Code nvarchar(20) NULL;

GO

MERGE dbo.TDSTMasterCont AS Target
USING
(
    VALUES
        (N'012', N'COMPANY', N'บริษัท', 10),
        (N'012', N'DORMITORY', N'หอพัก', 20),
        (N'012', N'SERVICE_CENTER', N'ศูนย์บริการ', 30)
) AS Source(GroupCode, Code, Name, Seq)
ON Target.GroupCode = Source.GroupCode
AND Target.Code = Source.Code
WHEN MATCHED THEN
    UPDATE SET Name = Source.Name, Seq = Source.Seq
WHEN NOT MATCHED THEN
    INSERT(GroupCode, Code, Name, Seq)
    VALUES(Source.GroupCode, Source.Code, Source.Name, Source.Seq);

COMMIT TRANSACTION;
