SET XACT_ABORT ON;

IF EXISTS
(
    SELECT 1
    FROM dbo.TDADEmployee AS E
    WHERE E.CompanyID IS NOT NULL
      AND
      (
          SELECT COUNT_BIG(1)
          FROM dbo.TDADUserEmployee AS UE
          WHERE UE.CompanyID = E.CompanyID
            AND UE.EmployeeID = E.EmployeeID
            AND UE.IsActive = 1
      ) <> 1
)
    THROW 51001, 'COMPANY_EMPLOYEE_LOGIN_REQUIRED', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.TDADUserEmployee AS UE
    INNER JOIN dbo.TDADEmployee AS E ON E.EmployeeID = UE.EmployeeID
    INNER JOIN dbo.TDADUser AS U ON U.UserID = UE.UserID
    WHERE UE.IsActive = 1
      AND (UE.CompanyID <> E.CompanyID OR UE.CompanyID <> U.CompanyID)
)
    THROW 51002, 'COMPANY_USER_EMPLOYEE_SCOPE_MISMATCH', 1;

IF EXISTS
(
    SELECT UE.CompanyID, UE.UserID
    FROM dbo.TDADUserEmployee AS UE
    WHERE UE.IsActive = 1
    GROUP BY UE.CompanyID, UE.UserID
    HAVING COUNT_BIG(1) > 1
)
    THROW 51003, 'COMPANY_USER_HAS_MULTIPLE_EMPLOYEES', 1;

IF OBJECT_ID(N'dbo.TDADPerson', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TDADPerson
    (
        PersonID bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_TDADPerson PRIMARY KEY,
        CompanyID bigint NOT NULL,
        FullName nvarchar(200) NOT NULL,
        NickName nvarchar(100) NULL,
        Email nvarchar(320) NULL,
        Mobile nvarchar(50) NULL,
        IsActive bit NOT NULL
            CONSTRAINT DF_TDADPerson_IsActive DEFAULT (1),
        CreateDate datetime2(3) NOT NULL
            CONSTRAINT DF_TDADPerson_CreateDate DEFAULT (SYSUTCDATETIME()),
        CreateBy bigint NULL,
        UpdateDate datetime2(3) NULL,
        UpdateBy bigint NULL,
        RowVersion rowversion NOT NULL,
        CONSTRAINT UQ_TDADPerson_Company_Person UNIQUE (CompanyID, PersonID)
    );

    CREATE INDEX IX_TDADPerson_Company_Active_Name
        ON dbo.TDADPerson(CompanyID, IsActive, FullName);
END;

IF COL_LENGTH(N'dbo.TDADEmployee', N'PersonID') IS NULL
    ALTER TABLE dbo.TDADEmployee ADD PersonID bigint NULL;

IF COL_LENGTH(N'dbo.TDADUser', N'PersonID') IS NULL
    ALTER TABLE dbo.TDADUser ADD PersonID bigint NULL;

-- SQL Server compiles a batch before executing ALTER TABLE. Start a new batch
-- so all PersonID references below bind to the newly added columns.
GO

DECLARE @EmployeePerson TABLE
(
    EmployeeID bigint NOT NULL PRIMARY KEY,
    PersonID bigint NOT NULL
);

MERGE dbo.TDADPerson AS Target
USING
(
    SELECT E.EmployeeID, E.CompanyID, E.FullName, E.NickName, E.Email,
           COALESCE(NULLIF(LTRIM(RTRIM(E.PersonalTelephone)), N''), E.Telephone) AS Mobile,
           E.IsActive, E.CreateDate, E.UpdateDate
    FROM dbo.TDADEmployee AS E
    WHERE E.CompanyID IS NOT NULL
      AND E.PersonID IS NULL
) AS Source
ON 1 = 0
WHEN NOT MATCHED THEN
    INSERT(CompanyID, FullName, NickName, Email, Mobile, IsActive, CreateDate, UpdateDate)
    VALUES(Source.CompanyID, Source.FullName, Source.NickName, Source.Email,
           Source.Mobile, Source.IsActive, Source.CreateDate, Source.UpdateDate)
OUTPUT Source.EmployeeID, inserted.PersonID
INTO @EmployeePerson(EmployeeID, PersonID);

UPDATE E
SET PersonID = M.PersonID
FROM dbo.TDADEmployee AS E
INNER JOIN @EmployeePerson AS M ON M.EmployeeID = E.EmployeeID;

UPDATE U
SET PersonID = E.PersonID
FROM dbo.TDADUser AS U
INNER JOIN dbo.TDADUserEmployee AS UE
    ON UE.UserID = U.UserID
   AND UE.CompanyID = U.CompanyID
   AND UE.IsActive = 1
INNER JOIN dbo.TDADEmployee AS E
    ON E.EmployeeID = UE.EmployeeID
   AND E.CompanyID = U.CompanyID
WHERE U.PersonID IS NULL;

DECLARE @UserPerson TABLE
(
    UserID bigint NOT NULL PRIMARY KEY,
    PersonID bigint NOT NULL
);

MERGE dbo.TDADPerson AS Target
USING
(
    SELECT U.UserID, U.CompanyID,
           COALESCE(NULLIF(LTRIM(RTRIM(U.DisplayName)), N''), U.Username, N'Company User') AS DisplayName,
           U.Email, U.Mobile, U.IsActive,
           COALESCE(U.CreateDate, SYSUTCDATETIME()) AS CreateDate,
           U.UpdateDate, U.CreateBy, U.UpdateBy
    FROM dbo.TDADUser AS U
    WHERE U.PersonID IS NULL
) AS Source
ON 1 = 0
WHEN NOT MATCHED THEN
    INSERT(CompanyID, FullName, Email, Mobile, IsActive,
           CreateDate, CreateBy, UpdateDate, UpdateBy)
    VALUES(Source.CompanyID, Source.DisplayName, Source.Email, Source.Mobile,
           Source.IsActive, Source.CreateDate, Source.CreateBy,
           Source.UpdateDate, Source.UpdateBy)
OUTPUT Source.UserID, inserted.PersonID
INTO @UserPerson(UserID, PersonID);

UPDATE U
SET PersonID = M.PersonID
FROM dbo.TDADUser AS U
INNER JOIN @UserPerson AS M ON M.UserID = U.UserID;

IF EXISTS (SELECT 1 FROM dbo.TDADUser WHERE PersonID IS NULL)
    THROW 51004, 'COMPANY_USER_PERSON_BACKFILL_INCOMPLETE', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.TDADUser')
      AND name = N'PersonID'
      AND is_nullable = 1
)
    ALTER TABLE dbo.TDADUser ALTER COLUMN PersonID bigint NOT NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_TDADEmployee_Person'
)
    ALTER TABLE dbo.TDADEmployee WITH CHECK
        ADD CONSTRAINT FK_TDADEmployee_Person
        FOREIGN KEY(CompanyID, PersonID)
        REFERENCES dbo.TDADPerson(CompanyID, PersonID);

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_TDADUser_Person'
)
    ALTER TABLE dbo.TDADUser WITH CHECK
        ADD CONSTRAINT FK_TDADUser_Person
        FOREIGN KEY(CompanyID, PersonID)
        REFERENCES dbo.TDADPerson(CompanyID, PersonID);

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADEmployee')
      AND name = N'UX_TDADEmployee_Company_Person'
)
    CREATE UNIQUE INDEX UX_TDADEmployee_Company_Person
        ON dbo.TDADEmployee(CompanyID, PersonID)
        WHERE CompanyID IS NOT NULL AND PersonID IS NOT NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADUser')
      AND name = N'UX_TDADUser_Company_Person'
)
    CREATE UNIQUE INDEX UX_TDADUser_Company_Person
        ON dbo.TDADUser(CompanyID, PersonID)
        WHERE PersonID IS NOT NULL;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADUserEmployee')
      AND name = N'UX_TDADUserEmployee_Company_Employee_Active'
)
    CREATE UNIQUE INDEX UX_TDADUserEmployee_Company_Employee_Active
        ON dbo.TDADUserEmployee(CompanyID, EmployeeID)
        WHERE IsActive = 1;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TDADUserEmployee')
      AND name = N'UX_TDADUserEmployee_Company_User_Active'
)
    CREATE UNIQUE INDEX UX_TDADUserEmployee_Company_User_Active
        ON dbo.TDADUserEmployee(CompanyID, UserID)
        WHERE IsActive = 1;
