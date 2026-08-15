USE [DBTDLaoo];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Now nvarchar(50) = CONVERT(nvarchar(50), SYSUTCDATETIME(), 126);

/* Keep Employee menu captions as real Unicode Thai text. */
DECLARE @EmployeeCaption nvarchar(200) =
    NCHAR(3614)+NCHAR(3609)+NCHAR(3633)+NCHAR(3585)+NCHAR(3591)+NCHAR(3634)+NCHAR(3609)+NCHAR(3586)+NCHAR(3629)+NCHAR(3591);
UPDATE dbo.TDADMainMenu
SET MenuName = @EmployeeCaption + CASE WHEN MenuCode = N'11001' THEN N' ของ Partner' ELSE N' ของ Customer' END,
    UpdateDate = SYSUTCDATETIME()
WHERE MenuCode IN (N'10001',N'11001',N'12001');
UPDATE dbo.TDSTScreen
SET ScreenName = @EmployeeCaption + CASE WHEN ScreenCode = '11001' THEN N' ของ Partner' ELSE N' ของ Customer' END,
    LastUpdate = @Now
WHERE CompanyCode='TD' AND ScreenCode IN ('10001','11001','12001');

/* Table and column metadata */
DECLARE @TableFields TABLE
(
    ColName nvarchar(100) NOT NULL,
    DataType nvarchar(50) NOT NULL,
    Remark nvarchar(500) NOT NULL
);
INSERT @TableFields VALUES
    (N'EmployeeCarImageID',N'bigint',N'Identity key of employee vehicle image'),
    (N'EmployeeID',N'bigint',N'Employee that owns the vehicle image'),
    (N'CarNo',N'tinyint',N'Vehicle number for the employee; 1 or 2'),
    (N'ImageData',N'varbinary(max)',N'Binary image content of the employee vehicle'),
    (N'ContentType',N'nvarchar(100)',N'MIME content type of the vehicle image'),
    (N'FileName',N'nvarchar(250)',N'Original file name of the vehicle image'),
    (N'FileSize',N'int',N'Image file size in bytes; maximum 102400'),
    (N'ImageWidth',N'int',N'Image width in pixels'),
    (N'ImageHeight',N'int',N'Image height in pixels'),
    (N'IsActive',N'bit',N'Whether the vehicle image is active'),
    (N'CreateDate',N'datetime2(3)',N'UTC date and time the vehicle image was created'),
    (N'CreateBy',N'bigint',N'User that created the vehicle image'),
    (N'UpdateDate',N'datetime2(3)',N'UTC date and time the vehicle image was updated'),
    (N'UpdateBy',N'bigint',N'User that updated the vehicle image');

MERGE dbo.TDSTTableName AS T
USING (SELECT N'TD' CompanyCode,N'AD' Module,N'dbo.TDADEmployeeCarImage' TableName,
              N'Employee vehicle image' Name,ColName,DataType,Remark FROM @TableFields) AS S
ON T.CompanyCode=S.CompanyCode AND T.Module=S.Module AND T.TableName=S.TableName AND T.ColName=S.ColName
WHEN MATCHED THEN UPDATE SET Name=S.Name,DataType=S.DataType,Remark=S.Remark,LastUpdate=@Now
WHEN NOT MATCHED THEN INSERT (CompanyCode,Module,TableName,Name,ColName,DataType,Remark,LastUpdate)
VALUES (S.CompanyCode,S.Module,S.TableName,S.Name,S.ColName,S.DataType,S.Remark,@Now);

/* Include the image table in all Employee screen technical definitions */
MERGE dbo.TDSTScreenTable AS T
USING (VALUES
    ('10001','dbo.TDADEmployeeCarImage','N','Employee vehicle image by CarNo'),
    ('11001','dbo.TDADEmployeeCarImage','N','Employee vehicle image by CarNo'),
    ('12001','dbo.TDADEmployeeCarImage','N','Employee vehicle image by CarNo')
) AS S(ScreenCode,TableName,IsPrimary,Remark)
ON T.CompanyCode='TD' AND T.ScreenCode=S.ScreenCode AND T.TableName=S.TableName
WHEN MATCHED THEN UPDATE SET IsPrimary=S.IsPrimary,Remark=S.Remark,LastUpdate=@Now
WHEN NOT MATCHED THEN INSERT (CompanyCode,ScreenCode,TableName,IsPrimary,Remark,LastUpdate)
VALUES ('TD',S.ScreenCode,S.TableName,S.IsPrimary,S.Remark,@Now);

/* Image APIs for Partner, Customer and Company Employee screens */
DECLARE @Apis TABLE
(
    ScreenCode varchar(20), APIName varchar(100), HttpMethod varchar(10),
    Endpoint varchar(200), ActionName varchar(50), Remark nvarchar(500)
);
INSERT @Apis VALUES
('10001','Employee.Company.CarImage.Get','GET','/api/company/employees/{id}/car-image/{carNo}','VIEW',N'Get scoped employee vehicle image'),
('10001','Employee.Company.CarImage.Save','PUT','/api/company/employees/{id}/car-image/{carNo}','EDIT',N'Save scoped employee vehicle image'),
('10001','Employee.Company.CarImage.Delete','DELETE','/api/company/employees/{id}/car-image/{carNo}','EDIT',N'Delete scoped employee vehicle image'),
('11001','Employee.Partner.CarImage.Get','GET','/api/partner/employees/{id}/car-image/{carNo}','VIEW',N'Get partner employee vehicle image'),
('11001','Employee.Partner.CarImage.Save','PUT','/api/partner/employees/{id}/car-image/{carNo}','EDIT',N'Save partner employee vehicle image'),
('11001','Employee.Partner.CarImage.Delete','DELETE','/api/partner/employees/{id}/car-image/{carNo}','EDIT',N'Delete partner employee vehicle image'),
('12001','Employee.Customer.CarImage.Get','GET','/api/partner/customer-employees/{id}/car-image/{carNo}','VIEW',N'Get customer employee vehicle image'),
('12001','Employee.Customer.CarImage.Save','PUT','/api/partner/customer-employees/{id}/car-image/{carNo}','EDIT',N'Save customer employee vehicle image'),
('12001','Employee.Customer.CarImage.Delete','DELETE','/api/partner/customer-employees/{id}/car-image/{carNo}','EDIT',N'Delete customer employee vehicle image');

MERGE dbo.TDSTScreenAPI AS T
USING @Apis AS S
ON T.CompanyCode='TD' AND T.ScreenCode=S.ScreenCode AND T.APIName=S.APIName
WHEN MATCHED THEN UPDATE SET HttpMethod=S.HttpMethod,Endpoint=S.Endpoint,ActionName=S.ActionName,Remark=S.Remark,LastUpdate=@Now
WHEN NOT MATCHED THEN INSERT (CompanyCode,ScreenCode,APIName,HttpMethod,Endpoint,ActionName,Remark,LastUpdate)
VALUES ('TD',S.ScreenCode,S.APIName,S.HttpMethod,S.Endpoint,S.ActionName,S.Remark,@Now);

/* Image slots shown by each Employee Action screen */
MERGE dbo.TDSTScreenField AS T
USING (SELECT S.ScreenCode,F.FieldName,F.Caption,F.DataType,F.IsRequired,F.IsFilter,F.IsEditable,F.SourceTable,F.SourceField,F.Remark
       FROM (VALUES ('10001'),('11001'),('12001')) S(ScreenCode)
       CROSS JOIN (VALUES
         ('CarImage1',N'Vehicle image 1','image','N','N','Y','dbo.TDADEmployeeCarImage','ImageData',N'Image for employee vehicle number 1'),
         ('CarImage2',N'Vehicle image 2','image','N','N','Y','dbo.TDADEmployeeCarImage','ImageData',N'Image for employee vehicle number 2')
       ) F(FieldName,Caption,DataType,IsRequired,IsFilter,IsEditable,SourceTable,SourceField,Remark)) AS S
ON T.CompanyCode='TD' AND T.ScreenCode=S.ScreenCode AND T.FieldName=S.FieldName
WHEN MATCHED THEN UPDATE SET Caption=S.Caption,DataType=S.DataType,IsRequired=S.IsRequired,IsFilter=S.IsFilter,IsEditable=S.IsEditable,SourceTable=S.SourceTable,SourceField=S.SourceField,Remark=S.Remark,LastUpdate=@Now
WHEN NOT MATCHED THEN INSERT (CompanyCode,ScreenCode,FieldName,Caption,DataType,IsRequired,IsFilter,IsEditable,SourceTable,SourceField,Remark,LastUpdate)
VALUES ('TD',S.ScreenCode,S.FieldName,S.Caption,S.DataType,S.IsRequired,S.IsFilter,S.IsEditable,S.SourceTable,S.SourceField,S.Remark,@Now);

COMMIT TRANSACTION;
GO
