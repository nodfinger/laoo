SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TDSTMenuDataAccessPolicy', N'U') IS NULL
    CREATE TABLE dbo.TDSTMenuDataAccessPolicy (
        CompanyID bigint NOT NULL,
        MenuCode nvarchar(20) NOT NULL,
        ViewScope varchar(12) NOT NULL,
        EditScope varchar(12) NOT NULL,
        DeleteScope varchar(12) NOT NULL,
        ViewHead bit NOT NULL,
        ViewManager bit NOT NULL,
        EditHead bit NOT NULL,
        EditManager bit NOT NULL,
        DeleteHead bit NOT NULL,
        DeleteManager bit NOT NULL,
        UpdateBy bigint NOT NULL,
        UpdateDate datetime2 NOT NULL CONSTRAINT DF_MenuDataAccessPolicy_UpdateDate DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_MenuDataAccessPolicy PRIMARY KEY (CompanyID, MenuCode),
        CONSTRAINT CK_MenuDataAccessPolicy_ViewScope CHECK (ViewScope IN ('SELF','DEPARTMENT','DIVISION','ALL')),
        CONSTRAINT CK_MenuDataAccessPolicy_EditScope CHECK (EditScope IN ('SELF','DEPARTMENT','DIVISION','ALL')),
        CONSTRAINT CK_MenuDataAccessPolicy_DeleteScope CHECK (DeleteScope IN ('SELF','DEPARTMENT','DIVISION','ALL'))
    );
