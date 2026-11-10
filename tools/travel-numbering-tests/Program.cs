using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

// Temporary SQL tables only; no application rows or schemas are changed.
var root = Path.GetFullPath(args[0]);
var config = new ConfigurationBuilder().AddJsonFile(Path.Combine(root,"laoo_api/appsettings.json"))
    .AddJsonFile(Path.Combine(root,"laoo_api/local.json")).Build();
await using var db = new SqlConnection(config.GetConnectionString("LaooDatabase"));
await db.OpenAsync();
await using (var q = new SqlCommand("""
CREATE TABLE #Formats(CompanyID bigint,MenuCode nvarchar(20),Prefix nvarchar(12),AfterPrefix nvarchar(2),BeforeSequence nvarchar(2),DateFormat varchar(8),Digits int);
CREATE TABLE #Claims(CompanyID bigint,ClaimNo nvarchar(30));
INSERT #Formats VALUES(1,N'66001',N'OI',N'-',N'-','yyyy',3),(2,N'66001',N'OT',N'',N'','NONE',3);
INSERT #Claims VALUES(1,N'OI-2026-001'),(1,N'OI-2026-003'),(2,N'OI-2026-099');
""",db)) await q.ExecuteNonQueryAsync();
var sql=DocumentNumbering.Sql("66001").Replace("dbo.TDADDocumentNumberFormat","#Formats").Replace("dbo.TDSTTravelClaim","#Claims");
async Task<string> Next(long company) {
    await using var tx=(SqlTransaction)await db.BeginTransactionAsync();
    await using var q=new SqlCommand(sql,db,tx);q.Parameters.AddWithValue("@company",company);
    var result=(string)(await q.ExecuteScalarAsync())!;await tx.RollbackAsync();return result;
}
var year=DateTime.UtcNow.Year;
var expected=year==2026 ? "OI-2026-004" : $"OI-{year}-001";
if(await Next(1)!=expected || await Next(2)!="OT001") throw new Exception("Travel numbering format or company scope failed.");
Console.WriteLine("Travel numbering tests passed (temporary tables; rolled back).");
