using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

// Tests use local temporary tables only; no application rows are read or written.
var root=Path.GetFullPath(args[0]);
var configuration=new ConfigurationBuilder().AddJsonFile(Path.Combine(root,"laoo_api/appsettings.json"))
    .AddJsonFile(Path.Combine(root,"laoo_api/local.json")).Build();
await using var connection=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
await connection.OpenAsync();
await using(var setup=new SqlCommand("""
CREATE TABLE #Formats(CompanyID bigint,MenuCode nvarchar(20),Prefix nvarchar(12),AfterPrefix nvarchar(2),BeforeSequence nvarchar(2),DateFormat varchar(8),Digits int);
CREATE TABLE #Requests(CompanyID bigint,RequestNo nvarchar(30));
""",connection)) await setup.ExecuteNonQueryAsync();
var sql=ServiceRequestNumbering.AllocateSql.Replace("LAOO_SERVICE_REQUEST_NUMBER:","LAOO_SERVICE_NUMBER_TEST:").Replace("dbo.TDADDocumentNumberFormat","#Formats").Replace("dbo.TDADServiceRequest","#Requests")+"\nSELECT @requestNo;";
async Task<string> Allocate(long company)
{
    await using var transaction=(SqlTransaction)await connection.BeginTransactionAsync();
    await using var command=new SqlCommand(sql,connection,transaction);
    command.Parameters.AddWithValue("@company",company);
    var result=(string)(await command.ExecuteScalarAsync())!;
    await transaction.CommitAsync();
    return result;
}
async Task Execute(string text) { await using var command=new SqlCommand(text,connection); await command.ExecuteNonQueryAsync(); }
var today=DateTime.UtcNow.ToString("yyyyMMdd",System.Globalization.CultureInfo.InvariantCulture);
await Execute($"INSERT #Requests VALUES(1,N'SR{today}000004'),(2,N'SR{today}000020')");
if(await Allocate(1)!=$"SR{today}000005") throw new Exception("Legacy numbering or company scope failed");
await Execute("INSERT #Formats VALUES(1,N'20001',N'FIX',N'-',N'-','yyMMdd',3)");
var head="FIX-"+DateTime.UtcNow.ToString("yyMMdd",System.Globalization.CultureInfo.InvariantCulture)+"-";
await Execute($"INSERT #Requests VALUES(1,N'{head}001'),(1,N'{head}003'),(2,N'{head}099')");
if(await Allocate(1)!=head+"004") throw new Exception("Configured format or existing-number continuity failed");
await Execute($"INSERT #Requests VALUES(1,N'{head}999')");
try { await Allocate(1); throw new Exception("Exhaustion was not rejected"); }
catch(SqlException ex) when(ex.Number==53965) { }

var suffix=Guid.NewGuid().ToString("N");
var formats="##fmt"+suffix; var requests="##req"+suffix;
await Execute($"CREATE TABLE {formats}(CompanyID bigint,MenuCode nvarchar(20),Prefix nvarchar(12),AfterPrefix nvarchar(2),BeforeSequence nvarchar(2),DateFormat varchar(8),Digits int); CREATE TABLE {requests}(CompanyID bigint,RequestNo nvarchar(30), UNIQUE(CompanyID,RequestNo)); INSERT {formats} VALUES(1,N'20001',N'T',N'',N'','NONE',3)");
var concurrentSql=ServiceRequestNumbering.AllocateSql.Replace("LAOO_SERVICE_REQUEST_NUMBER:","LAOO_SERVICE_NUMBER_TEST_"+suffix+":").Replace("dbo.TDADDocumentNumberFormat",formats).Replace("dbo.TDADServiceRequest",requests)+$"\nINSERT {requests}(CompanyID,RequestNo) VALUES(@company,@requestNo); SELECT @requestNo;";
async Task<string> AllocateConcurrently()
{
    await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
    await db.OpenAsync();
    await using var tx=(SqlTransaction)await db.BeginTransactionAsync();
    await using var command=new SqlCommand(concurrentSql,db,tx);
    command.Parameters.AddWithValue("@company",1L);
    var result=(string)(await command.ExecuteScalarAsync())!;
    await tx.CommitAsync();
    return result;
}
var concurrent=await Task.WhenAll(Enumerable.Range(0,4).Select(_=>AllocateConcurrently()));
if(concurrent.Distinct().Count()!=4 || !concurrent.Order().SequenceEqual(new[]{"T001","T002","T003","T004"}))
    throw new Exception("Concurrent allocation generated duplicate or missing numbers");
Console.WriteLine("PASS: legacy, configured format, company isolation, existing numbers, sequence exhaustion and concurrent allocation; temporary tables only");

var numberFormats="##numberFmt"+suffix; var issues="##numberIssue"+suffix;
await Execute($"CREATE TABLE {numberFormats}(CompanyID bigint,MenuCode nvarchar(20),Prefix nvarchar(12),AfterPrefix nvarchar(2),BeforeSequence nvarchar(2),DateFormat varchar(8),Digits int); CREATE TABLE {issues}(CompanyID bigint,IssueCode nvarchar(30), UNIQUE(CompanyID,IssueCode)); INSERT {numberFormats} VALUES(1,N'08003',N'IS',N'-',N'-','yyMM',3)");
var issueSql=DocumentNumbering.Sql("08003").Replace("LAOO_DOCUMENT_NUMBER:","LAOO_NUMBER_TEST_"+suffix+":").Replace("dbo.TDADDocumentNumberFormat",numberFormats).Replace("dbo.TDIVStockIssue",issues);
async Task<string?> Issue(long company)
{
    await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await db.OpenAsync();
    await using var tx=(SqlTransaction)await db.BeginTransactionAsync();
    var insertSql=issueSql.Replace("SELECT @result;",$"IF @result IS NOT NULL INSERT {issues} VALUES(@company,@result); SELECT @result;");
    await using var cmd=new SqlCommand(insertSql,db,tx); cmd.Parameters.AddWithValue("@company",company);
    var value=await cmd.ExecuteScalarAsync(); await tx.CommitAsync(); return value is null or DBNull ? null : (string)value;
}
if(await Issue(2) is not null) throw new Exception("Unconfigured company must retain legacy numbering");
var issued=await Task.WhenAll(Enumerable.Range(0,4).Select(_=>Issue(1)));
var issueHead="IS-"+DateTime.UtcNow.ToString("yyMM",System.Globalization.CultureInfo.InvariantCulture)+"-";
if(!issued.Order().SequenceEqual(Enumerable.Range(1,4).Select(i=>issueHead+i.ToString("D3")))) throw new Exception("Stock issue concurrency failed");
foreach(var (code,table,column) in new[]{("08005","TDIVStockReceipt","ReceiptCode"),("09004","TDARPreOrder","PreOrderCode"),("09005","TDARTemporaryReceipt","ReceiptCode"),("09006","TDARDeliveryNote","DeliveryCode"),("09007","TDARTaxInvoice","TaxInvoiceCode"),("09009","TDAPPurchaseDelivery","DeliveryCode"),("09010","TDAPTaxInvoice","InternalCode"),("09015","TDAPPayment","PaymentCode")})
{
    await Execute($"CREATE TABLE #doc{code}(CompanyID bigint,{column} nvarchar(30)); INSERT {numberFormats} VALUES(3,N'{code}',N'X',N'-',N'','NONE',3); INSERT #doc{code} VALUES(3,N'X-002'),(4,N'X-099')");
    var sqlDoc=DocumentNumbering.Sql(code).Replace("LAOO_DOCUMENT_NUMBER:","LAOO_NUMBER_TEST_"+suffix+":").Replace("dbo.TDADDocumentNumberFormat",numberFormats).Replace("dbo."+table,"#doc"+code);
    await using var tx=(SqlTransaction)await connection.BeginTransactionAsync();
    await using var cmd=new SqlCommand(sqlDoc,connection,tx); cmd.Parameters.AddWithValue("@company",3L);
    if((string?)await cmd.ExecuteScalarAsync()!="X-003") throw new Exception($"Continuity failed for {code}");
    await tx.RollbackAsync();
}
Console.WriteLine("PASS: stock numbering legacy fallback, configured format, company isolation and concurrent allocation; temporary tables only");
