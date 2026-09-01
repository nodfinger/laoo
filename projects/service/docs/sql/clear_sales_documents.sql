SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.TDARPreOrder
        WHERE QuotationID IS NOT NULL
    )
        THROW 51001, N'พบ PreOrder ที่อ้างถึงใบเสนอราคา จึงยกเลิกการลบ', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.TDARPreOrderDetail
        WHERE QuotationDetailID IS NOT NULL
    )
        THROW 51002, N'พบ PreOrder Detail ที่อ้างถึงรายการใบเสนอราคา จึงยกเลิกการลบ', 1;

    DECLARE
        @DeletedDocumentLinks int = 0,
        @DeletedStockMovements int = 0,
        @DeletedTaxInvoiceDetails int = 0,
        @DeletedTaxInvoices int = 0,
        @DeletedDeliveryNoteDetails int = 0,
        @DeletedDeliveryNotes int = 0,
        @DeletedReceiptPayments int = 0,
        @DeletedReceipts int = 0,
        @DeletedQuotationDetails int = 0,
        @DeletedQuotations int = 0;

    DELETE FROM dbo.TDARDocumentLink
    WHERE UPPER(FromDocumentType) IN
          (N'QUOTATION', N'DELIVERY_NOTE', N'TEMPORARY_RECEIPT', N'TAX_INVOICE')
       OR UPPER(ToDocumentType) IN
          (N'QUOTATION', N'DELIVERY_NOTE', N'TEMPORARY_RECEIPT', N'TAX_INVOICE');
    SET @DeletedDocumentLinks = @@ROWCOUNT;

    DELETE FROM dbo.TDIVStockMovement
    WHERE UPPER(DocumentType) IN
          (N'QUOTATION', N'DELIVERY_NOTE', N'TEMPORARY_RECEIPT', N'TAX_INVOICE');
    SET @DeletedStockMovements = @@ROWCOUNT;

    DELETE FROM dbo.TDARTaxInvoiceDetail;
    SET @DeletedTaxInvoiceDetails = @@ROWCOUNT;

    DELETE FROM dbo.TDARTaxInvoice;
    SET @DeletedTaxInvoices = @@ROWCOUNT;

    UPDATE dbo.TDARDeliveryNoteDetail
    SET ParentDeliveryNoteDetailID = NULL
    WHERE ParentDeliveryNoteDetailID IS NOT NULL;

    DELETE FROM dbo.TDARDeliveryNoteDetail;
    SET @DeletedDeliveryNoteDetails = @@ROWCOUNT;

    UPDATE dbo.TDARDeliveryNote
    SET ParentDeliveryNoteID = NULL
    WHERE ParentDeliveryNoteID IS NOT NULL;

    DELETE FROM dbo.TDARDeliveryNote;
    SET @DeletedDeliveryNotes = @@ROWCOUNT;

    DELETE FROM dbo.TDARTemporaryReceiptPayment;
    SET @DeletedReceiptPayments = @@ROWCOUNT;

    DELETE FROM dbo.TDARTemporaryReceipt;
    SET @DeletedReceipts = @@ROWCOUNT;

    DELETE FROM dbo.TDARQuotationDetail;
    SET @DeletedQuotationDetails = @@ROWCOUNT;

    DELETE FROM dbo.TDARQuotation;
    SET @DeletedQuotations = @@ROWCOUNT;

    DBCC CHECKIDENT ('dbo.TDARTaxInvoiceDetail', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.TDARTaxInvoice', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.TDARDeliveryNoteDetail', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.TDARDeliveryNote', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.TDARTemporaryReceiptPayment', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.TDARTemporaryReceipt', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.TDARQuotationDetail', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.TDARQuotation', RESEED, 0) WITH NO_INFOMSGS;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDARDocumentLink)
        DBCC CHECKIDENT ('dbo.TDARDocumentLink', RESEED, 0) WITH NO_INFOMSGS;

    IF NOT EXISTS (SELECT 1 FROM dbo.TDIVStockMovement)
        DBCC CHECKIDENT ('dbo.TDIVStockMovement', RESEED, 0) WITH NO_INFOMSGS;

    COMMIT TRANSACTION;

    SELECT
        @DeletedQuotations AS DeletedQuotations,
        @DeletedQuotationDetails AS DeletedQuotationDetails,
        @DeletedDeliveryNotes AS DeletedDeliveryNotes,
        @DeletedDeliveryNoteDetails AS DeletedDeliveryNoteDetails,
        @DeletedReceipts AS DeletedReceipts,
        @DeletedReceiptPayments AS DeletedReceiptPayments,
        @DeletedTaxInvoices AS DeletedTaxInvoices,
        @DeletedTaxInvoiceDetails AS DeletedTaxInvoiceDetails,
        @DeletedDocumentLinks AS DeletedDocumentLinks,
        @DeletedStockMovements AS DeletedStockMovements;

    SELECT
        (SELECT COUNT(*) FROM dbo.TDARQuotation) AS RemainingQuotations,
        (SELECT COUNT(*) FROM dbo.TDARQuotationDetail) AS RemainingQuotationDetails,
        (SELECT COUNT(*) FROM dbo.TDARDeliveryNote) AS RemainingDeliveryNotes,
        (SELECT COUNT(*) FROM dbo.TDARDeliveryNoteDetail) AS RemainingDeliveryNoteDetails,
        (SELECT COUNT(*) FROM dbo.TDARTemporaryReceipt) AS RemainingReceipts,
        (SELECT COUNT(*) FROM dbo.TDARTemporaryReceiptPayment) AS RemainingReceiptPayments,
        (SELECT COUNT(*) FROM dbo.TDARTaxInvoice) AS RemainingTaxInvoices,
        (SELECT COUNT(*) FROM dbo.TDARTaxInvoiceDetail) AS RemainingTaxInvoiceDetails;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
