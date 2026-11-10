namespace Laoo.Shared.Contracts;

/// <summary>Allocate a repair number inside the caller's transaction. Requires @company.</summary>
public static class ServiceRequestNumbering
{
    public const string AcquireLockSql = """
IF @@TRANCOUNT=0 THROW 53965,N'Repair numbering requires a transaction.',1;
DECLARE @repairLockResult int, @repairLockResource nvarchar(255)=CONCAT(N'LAOO_SERVICE_REQUEST_NUMBER:',@company);
EXEC @repairLockResult=sys.sp_getapplock @Resource=@repairLockResource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
IF @repairLockResult<0 THROW 53965,N'Could not acquire repair numbering lock.',1;
""";
    // Every service-request creation path executes this fragment in its existing transaction.
    // The table lock protects the scan and insert, including callers from other projects.
    public const string AllocateSql = AcquireLockSql + """

DECLARE @requestNo nvarchar(30), @prefix nvarchar(12)=N'SR', @after nvarchar(2)=N'', @before nvarchar(2)=N'',
        @dateFormat varchar(8)='yyyyMMdd', @digits int=6, @datePart nvarchar(8), @head nvarchar(30), @next bigint;
SELECT @prefix=Prefix,@after=AfterPrefix,@before=BeforeSequence,@dateFormat=DateFormat,@digits=Digits
FROM dbo.TDADDocumentNumberFormat WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND MenuCode=N'20001';
IF @dateFormat NOT IN('NONE','yy','yyyy','MM','dd','MMdd','yyMM','yydd','yyMMdd','yyyyMM','yyyydd','yyyyMMdd') OR @digits NOT BETWEEN 1 AND 9
    THROW 53965,N'Invalid repair numbering configuration.',1;
DECLARE @today char(8)=CONVERT(char(8),SYSUTCDATETIME(),112);
SET @datePart=CASE WHEN @dateFormat='NONE' THEN N'' ELSE
    REPLACE(REPLACE(REPLACE(REPLACE(@dateFormat,'yyyy',SUBSTRING(@today,1,4)),'yy',SUBSTRING(@today,3,2)),'MM',SUBSTRING(@today,5,2)),'dd',SUBSTRING(@today,7,2)) END;
SET @head=@prefix+@after+@datePart+@before;
IF LEN(@head)+@digits>30 THROW 53965,N'Repair numbering format is too long.',1;
SELECT @next=ISNULL(MAX(TRY_CONVERT(bigint,SUBSTRING(RequestNo,LEN(@head)+1,30))),0)+1
FROM dbo.TDADServiceRequest WITH(TABLOCKX,HOLDLOCK)
WHERE CompanyID=@company AND LEFT(RequestNo,LEN(@head))=@head AND LEN(RequestNo)>LEN(@head)
  AND SUBSTRING(RequestNo,LEN(@head)+1,30) NOT LIKE N'%[^0-9]%';
IF LEN(CONVERT(varchar(20),@next))>@digits THROW 53965,N'Repair numbering sequence is exhausted.',1;
SET @requestNo=@head+RIGHT(REPLICATE(N'0',@digits)+CONVERT(nvarchar(20),@next),@digits);
""";
}
