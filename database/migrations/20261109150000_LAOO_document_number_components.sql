SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.TDADDocumentNumberFormat',N'U') IS NULL
    THROW 53930, N'Document numbering format table is unavailable.', 1;
IF COL_LENGTH(N'dbo.TDADDocumentNumberFormat',N'AfterPrefix') IS NOT NULL OR COL_LENGTH(N'dbo.TDADDocumentNumberFormat',N'BeforeSequence') IS NOT NULL
    THROW 53931, N'Document numbering separators already exist.', 1;
ALTER TABLE dbo.TDADDocumentNumberFormat ADD
    AfterPrefix nvarchar(2) NOT NULL CONSTRAINT DF_TDADDocumentNumberFormat_AfterPrefix DEFAULT N'',
    BeforeSequence nvarchar(2) NOT NULL CONSTRAINT DF_TDADDocumentNumberFormat_BeforeSequence DEFAULT N'';
ALTER TABLE dbo.TDADDocumentNumberFormat DROP CONSTRAINT CK_TDADDocumentNumberFormat_DateFormat;
ALTER TABLE dbo.TDADDocumentNumberFormat ADD CONSTRAINT CK_TDADDocumentNumberFormat_DateFormat CHECK
    (DateFormat IN ('NONE','yy','yyyy','MM','dd','MMdd','yyMM','yydd','yyMMdd','yyyyMM','yyyydd','yyyyMMdd'));
