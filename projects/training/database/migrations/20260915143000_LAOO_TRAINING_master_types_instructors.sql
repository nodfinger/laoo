/* LAOO_TRAINING: company-scoped master data for training types and instructors. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.TDTRTrainingType', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTRTrainingType
        (
            TrainingTypeID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTRTrainingType PRIMARY KEY,
            CompanyID bigint NOT NULL,
            TrainingTypeCode nvarchar(30) NOT NULL,
            TrainingTypeName nvarchar(200) NOT NULL,
            Remark nvarchar(500) NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTRTrainingType_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTRTrainingType_CreateDate DEFAULT(SYSUTCDATETIME()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT UQ_TDTRTrainingType_Company_Code UNIQUE(CompanyID, TrainingTypeCode)
        );
        CREATE INDEX IX_TDTRTrainingType_Company_Name
            ON dbo.TDTRTrainingType(CompanyID, IsActive, TrainingTypeName);
    END;

    IF OBJECT_ID(N'dbo.TDTRTrainingInstructor', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TDTRTrainingInstructor
        (
            TrainingInstructorID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_TDTRTrainingInstructor PRIMARY KEY,
            CompanyID bigint NOT NULL,
            TrainingInstructorCode nvarchar(30) NOT NULL,
            TrainingInstructorName nvarchar(200) NOT NULL,
            PhoneNumber nvarchar(50) NULL,
            Email nvarchar(254) NULL,
            ContactStartDate date NULL,
            InstituteName nvarchar(200) NULL,
            Remark nvarchar(500) NULL,
            IsActive bit NOT NULL CONSTRAINT DF_TDTRTrainingInstructor_IsActive DEFAULT(1),
            CreateDate datetime2(3) NOT NULL CONSTRAINT DF_TDTRTrainingInstructor_CreateDate DEFAULT(SYSUTCDATETIME()),
            CreateBy bigint NULL,
            UpdateDate datetime2(3) NULL,
            UpdateBy bigint NULL,
            RowVersion rowversion NOT NULL,
            CONSTRAINT UQ_TDTRTrainingInstructor_Company_Code UNIQUE(CompanyID, TrainingInstructorCode)
        );
        CREATE INDEX IX_TDTRTrainingInstructor_Company_Name
            ON dbo.TDTRTrainingInstructor(CompanyID, IsActive, TrainingInstructorName);
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
