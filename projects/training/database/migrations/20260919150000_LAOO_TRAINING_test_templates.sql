/* Training-owned reusable PRE/POST test templates. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID(N'dbo.TDTRTrainingTestTemplate', N'U') IS NULL
 BEGIN
  CREATE TABLE dbo.TDTRTrainingTestTemplate (
   TrainingTestTemplateID bigint IDENTITY PRIMARY KEY,
   CompanyID bigint NOT NULL,
   TrainingTestTemplateCode nvarchar(30) NOT NULL,
   TrainingTestTemplateName nvarchar(200) NOT NULL,
   SectionCode varchar(4) NOT NULL,
   DefinitionJson nvarchar(max) NOT NULL,
   VersionNo int NOT NULL DEFAULT 1,
   IsActive bit NOT NULL DEFAULT 1,
   CreateBy bigint NOT NULL,
   CreateDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
   UpdateBy bigint NOT NULL,
   UpdateDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
   RowVersion rowversion NOT NULL,
   CONSTRAINT UQ_TDTRTrainingTestTemplate_Code UNIQUE(CompanyID,TrainingTestTemplateCode),
   CONSTRAINT CK_TDTRTrainingTestTemplate_Section CHECK(SectionCode IN ('PRE','POST')),
   CONSTRAINT CK_TDTRTrainingTestTemplate_Definition CHECK(ISJSON(DefinitionJson)=1),
   CONSTRAINT CK_TDTRTrainingTestTemplate_Version CHECK(VersionNo>0)
  );
  CREATE INDEX IX_TDTRTrainingTestTemplate_List
   ON dbo.TDTRTrainingTestTemplate(CompanyID,SectionCode,IsActive,TrainingTestTemplateName);
 END;
 IF OBJECT_ID(N'dbo.TDTRTrainingTestTemplateImage', N'U') IS NULL
 BEGIN
  CREATE TABLE dbo.TDTRTrainingTestTemplateImage (
   ImageID uniqueidentifier PRIMARY KEY,
   CompanyID bigint NOT NULL,
   TrainingTestTemplateID bigint NOT NULL
    REFERENCES dbo.TDTRTrainingTestTemplate(TrainingTestTemplateID),
   ContentType varchar(20) NOT NULL,
   ByteLength int NOT NULL,
   CreateBy bigint NOT NULL,
   CreateDate datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
   CONSTRAINT CK_TDTRTrainingTestTemplateImage_Size CHECK(ByteLength BETWEEN 1 AND 1048576),
   CONSTRAINT CK_TDTRTrainingTestTemplateImage_Type CHECK(ContentType IN ('image/jpeg','image/png','image/webp'))
  );
  CREATE INDEX IX_TDTRTrainingTestTemplateImage_Template
   ON dbo.TDTRTrainingTestTemplateImage(CompanyID,TrainingTestTemplateID);
 END;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
