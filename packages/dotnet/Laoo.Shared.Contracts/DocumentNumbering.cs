namespace Laoo.Shared.Contracts;

/// <summary>SQL for allocating a configured document number inside the caller's transaction.</summary>
public static class DocumentNumbering
{
    public static string Sql(string menuCode)
    {
        var (table, column) = menuCode switch
        {
            "09004" => ("TDARPreOrder", "PreOrderCode"),
            "09005" => ("TDARTemporaryReceipt", "ReceiptCode"),
            "09006" => ("TDARDeliveryNote", "DeliveryCode"),
            "09007" => ("TDARTaxInvoice", "TaxInvoiceCode"),
            "09009" => ("TDAPPurchaseDelivery", "DeliveryCode"),
            "09010" => ("TDAPTaxInvoice", "InternalCode"),
            "09015" => ("TDAPPayment", "PaymentCode"),
            "08005" => ("TDIVStockReceipt", "ReceiptCode"),
            "08003" => ("TDIVStockIssue", "IssueCode"),
            _ => throw new ArgumentOutOfRangeException(nameof(menuCode))
        };
        return $$"""
IF @@TRANCOUNT=0 THROW 53965,N'Document numbering requires a transaction.',1;
DECLARE @prefix nvarchar(12),@after nvarchar(2),@before nvarchar(2),@format varchar(8),@digits int,
        @head nvarchar(30),@datePart nvarchar(8),@next bigint,@result nvarchar(30),@lockResult int;
SELECT @prefix=Prefix,@after=AfterPrefix,@before=BeforeSequence,@format=DateFormat,@digits=Digits
FROM dbo.TDADDocumentNumberFormat WITH(HOLDLOCK) WHERE CompanyID=@company AND MenuCode=N'{{menuCode}}';
IF @prefix IS NOT NULL
BEGIN
    DECLARE @resource nvarchar(255)=CONCAT(N'LAOO_DOCUMENT_NUMBER:{{menuCode}}:',@company);
    EXEC @lockResult=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
    IF @lockResult<0 THROW 53965,N'Unable to lock document numbering.',1;
    IF @format NOT IN('NONE','yy','yyyy','MM','dd','MMdd','yyMM','yydd','yyMMdd','yyyyMM','yyyydd','yyyyMMdd') OR @digits NOT BETWEEN 1 AND 9
        THROW 53965,N'Invalid document numbering configuration.',1;
    DECLARE @today char(8)=CONVERT(char(8),SYSUTCDATETIME(),112);
    SET @datePart=CASE WHEN @format='NONE' THEN N'' ELSE REPLACE(REPLACE(REPLACE(REPLACE(@format,'yyyy',SUBSTRING(@today,1,4)),'yy',SUBSTRING(@today,3,2)),'MM',SUBSTRING(@today,5,2)),'dd',SUBSTRING(@today,7,2)) END;
    SET @head=@prefix+@after+@datePart+@before;
    IF LEN(@head)+@digits>30 THROW 53965,N'Document number format too long.',1;
    SELECT @next=ISNULL(MAX(TRY_CONVERT(bigint,SUBSTRING({{column}},LEN(@head)+1,30))),0)+1
    FROM dbo.{{table}} WITH(TABLOCKX,HOLDLOCK)
    WHERE CompanyID=@company AND LEFT({{column}},LEN(@head))=@head AND LEN({{column}})>LEN(@head)
      AND SUBSTRING({{column}},LEN(@head)+1,30) NOT LIKE N'%[^0-9]%';
    IF LEN(CONVERT(varchar(20),@next))>@digits THROW 53965,N'Document sequence exhausted.',1;
    SET @result=@head+RIGHT(REPLICATE(N'0',@digits)+CONVERT(nvarchar(20),@next),@digits);
END
SELECT @result;
""";
    }
}
