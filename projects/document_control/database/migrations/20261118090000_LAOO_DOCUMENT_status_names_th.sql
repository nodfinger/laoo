SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.TDDCDocument', N'U') IS NULL OR OBJECT_ID(N'dbo.TDDCRevision', N'U') IS NULL
        THROW 51000, N'Document Control tables are required before adding status names.', 1;

    IF COL_LENGTH(N'dbo.TDDCDocument', N'StatusName') IS NULL
        ALTER TABLE dbo.TDDCDocument ADD StatusName AS
            (CASE StatusCode
                WHEN N'DRAFT' THEN N'ร่าง'
                WHEN N'IN_REVIEW' THEN N'รอตรวจทาน'
                WHEN N'IN_APPROVAL' THEN N'รออนุมัติ'
                WHEN N'APPROVED' THEN N'อนุมัติแล้ว'
                WHEN N'EFFECTIVE' THEN N'มีผลบังคับใช้'
                WHEN N'PUBLISHED' THEN N'เผยแพร่'
                WHEN N'OBSOLETE' THEN N'ยกเลิกใช้'
                WHEN N'RETURNED' THEN N'ส่งกลับ'
                ELSE StatusCode END);

    IF COL_LENGTH(N'dbo.TDDCRevision', N'StatusName') IS NULL
        ALTER TABLE dbo.TDDCRevision ADD StatusName AS
            (CASE StatusCode
                WHEN N'DRAFT' THEN N'ร่าง'
                WHEN N'IN_REVIEW' THEN N'รอตรวจทาน'
                WHEN N'IN_APPROVAL' THEN N'รออนุมัติ'
                WHEN N'APPROVED' THEN N'อนุมัติแล้ว'
                WHEN N'EFFECTIVE' THEN N'มีผลบังคับใช้'
                WHEN N'PUBLISHED' THEN N'เผยแพร่'
                WHEN N'OBSOLETE' THEN N'ยกเลิกใช้'
                WHEN N'RETURNED' THEN N'ส่งกลับ'
                ELSE StatusCode END);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
