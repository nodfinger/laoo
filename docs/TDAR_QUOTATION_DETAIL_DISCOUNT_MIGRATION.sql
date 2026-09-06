SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.TDARQuotationDetail', N'DiscountPercent') IS NOT NULL
BEGIN
    ALTER TABLE dbo.TDARQuotationDetail
        ALTER COLUMN DiscountPercent decimal(9,4) NOT NULL;
END;

IF COL_LENGTH(N'dbo.TDARQuotationDetail', N'DiscountType') IS NULL
BEGIN
    ALTER TABLE dbo.TDARQuotationDetail
        ADD DiscountType nvarchar(1) NOT NULL
            CONSTRAINT DF_TDARQuotationDetail_DiscountType DEFAULT (N'N');
END;

IF COL_LENGTH(N'dbo.TDARQuotationDetail', N'BeforeDiscount') IS NULL
BEGIN
    ALTER TABLE dbo.TDARQuotationDetail ADD BeforeDiscount decimal(18,4) NULL;
    EXEC sys.sp_executesql N'
        UPDATE dbo.TDARQuotationDetail
           SET BeforeDiscount = ROUND(Quantity * UnitPrice, 4);';
    ALTER TABLE dbo.TDARQuotationDetail ALTER COLUMN BeforeDiscount decimal(18,4) NOT NULL;
    ALTER TABLE dbo.TDARQuotationDetail
        ADD CONSTRAINT DF_TDARQuotationDetail_BeforeDiscount DEFAULT (0) FOR BeforeDiscount;
END;

IF COL_LENGTH(N'dbo.TDARQuotationDetail', N'DiscountAmount') IS NULL
BEGIN
    ALTER TABLE dbo.TDARQuotationDetail
        ADD DiscountAmount decimal(18,4) NOT NULL
            CONSTRAINT DF_TDARQuotationDetail_DiscountAmount DEFAULT (0);

    EXEC sys.sp_executesql N'
        UPDATE dbo.TDARQuotationDetail
           SET DiscountType = CASE WHEN DiscountPercent > 0 THEN N''P'' ELSE N''N'' END,
               DiscountAmount = ROUND(BeforeDiscount * DiscountPercent / 100.0, 4),
               Amount = BeforeDiscount - ROUND(BeforeDiscount * DiscountPercent / 100.0, 4);';
END;

IF OBJECT_ID(N'dbo.CK_TDARQuotationDetail_DiscountType', N'C') IS NULL
BEGIN
    EXEC sys.sp_executesql N'
        ALTER TABLE dbo.TDARQuotationDetail WITH CHECK
            ADD CONSTRAINT CK_TDARQuotationDetail_DiscountType
            CHECK (DiscountType IN (N''N'',N''P'',N''A''));';
END;

IF OBJECT_ID(N'dbo.CK_TDARQuotationDetail_DiscountValue', N'C') IS NULL
BEGIN
    EXEC sys.sp_executesql N'
        ALTER TABLE dbo.TDARQuotationDetail WITH CHECK
            ADD CONSTRAINT CK_TDARQuotationDetail_DiscountValue
            CHECK
            (
                DiscountPercent >= 0 AND DiscountPercent <= 100
                AND DiscountAmount >= 0
                AND DiscountAmount <= BeforeDiscount
                AND Amount = BeforeDiscount - DiscountAmount
            );';
END;

COMMIT TRANSACTION;

SELECT
    COL_LENGTH(N'dbo.TDARQuotationDetail', N'DiscountType') AS DiscountTypeLength,
    COL_LENGTH(N'dbo.TDARQuotationDetail', N'BeforeDiscount') AS BeforeDiscountLength,
    COL_LENGTH(N'dbo.TDARQuotationDetail', N'DiscountAmount') AS DiscountAmountLength;
