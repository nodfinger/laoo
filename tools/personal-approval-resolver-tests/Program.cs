using System.Text.Json;
using Laoo.Shared.Contracts;
using Microsoft.Data.SqlClient;

var root=Directory.GetCurrentDirectory();
using var config=JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(root,"laoo_api","local.json")));
var connection=config.RootElement.GetProperty("ConnectionStrings").GetProperty("LaooDatabase").GetString();
await using var db=new SqlConnection(connection);
await db.OpenAsync();
await using var tx=(SqlTransaction)await db.BeginTransactionAsync();
try {
    const string sample="""
SELECT TOP(1) UE.CompanyID,UE.UserID,UE.EmployeeID,
 (SELECT TOP(1) E2.EmployeeID FROM dbo.TDADEmployee E2 WHERE E2.CompanyID=UE.CompanyID AND E2.IsActive=1 AND E2.EmployeeID<>UE.EmployeeID ORDER BY E2.EmployeeID)
FROM dbo.TDADUserEmployee UE
JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1
JOIN dbo.TDADUser U ON U.UserID=UE.UserID AND U.CompanyID=UE.CompanyID AND U.IsActive=1
WHERE UE.IsActive=1 AND 1=(SELECT COUNT(DISTINCT E3.EmployeeID) FROM dbo.TDADUserEmployee UE3 JOIN dbo.TDADEmployee E3 ON E3.EmployeeID=UE3.EmployeeID AND E3.CompanyID=UE3.CompanyID AND E3.IsActive=1 WHERE UE3.CompanyID=UE.CompanyID AND UE3.UserID=UE.UserID AND UE3.IsActive=1)
AND EXISTS(SELECT 1 FROM dbo.TDADEmployee E2 WHERE E2.CompanyID=UE.CompanyID AND E2.IsActive=1 AND E2.EmployeeID<>UE.EmployeeID)
ORDER BY UE.CompanyID,UE.UserID;
""";
    long company,user,requester,approver;
    await using(var q=new SqlCommand(sample,db,tx)) await using(var r=await q.ExecuteReaderAsync()) {
        if(!await r.ReadAsync()) throw new Exception("No suitable test identity.");
        company=r.GetInt64(0);user=r.GetInt64(1);requester=r.GetInt64(2);approver=r.GetInt64(3);
    }
    const string menu="10011";
    await using(var q=new SqlCommand("DELETE dbo.TDSTPersonalApprovalStep WHERE CompanyID=@company AND MenuCode=@menu AND RequesterEmployeeID=@requester",db,tx)) {
        q.Parameters.AddWithValue("@company",company);q.Parameters.AddWithValue("@menu",menu);q.Parameters.AddWithValue("@requester",requester);await q.ExecuteNonQueryAsync();
    }
    var empty=await PersonalApprovalResolver.ReadAsync(db,tx,company,user,menu,CancellationToken.None);
    if(empty is not null)throw new Exception("Missing personal configuration should use the normal pattern.");
    await using(var q=new SqlCommand("INSERT dbo.TDSTPersonalApprovalStep(CompanyID,MenuCode,RequesterEmployeeID,StepNo,ApproverEmployeeID,UpdateBy) VALUES(@company,@menu,@requester,1,@approver,@user)",db,tx)) {
        q.Parameters.AddWithValue("@company",company);q.Parameters.AddWithValue("@menu",menu);q.Parameters.AddWithValue("@requester",requester);q.Parameters.AddWithValue("@approver",approver);q.Parameters.AddWithValue("@user",user);await q.ExecuteNonQueryAsync();
    }
    var selected=await PersonalApprovalResolver.ReadAsync(db,tx,company,user,menu,CancellationToken.None);
    if(selected is null || !selected.SequenceEqual([approver]))throw new Exception("Personal order not selected.");
    var otherMenu=await PersonalApprovalResolver.ReadAsync(db,tx,company,user,"68002",CancellationToken.None);
    if(otherMenu is not null)throw new Exception("Personal order leaked to another menu.");
    var otherCompany=await PersonalApprovalResolver.ReadAsync(db,tx,company+1000000,user,menu,CancellationToken.None);
    if(otherCompany is not null)throw new Exception("Personal order leaked to another company.");
    await using(var q=new SqlCommand("UPDATE dbo.TDADEmployee SET IsActive=0 WHERE CompanyID=@company AND EmployeeID=@approver",db,tx)) {
        q.Parameters.AddWithValue("@company",company);q.Parameters.AddWithValue("@approver",approver);await q.ExecuteNonQueryAsync();
    }
    try {await PersonalApprovalResolver.ReadAsync(db,tx,company,user,menu,CancellationToken.None);throw new Exception("Invalid personal order must not fall back.");}
    catch(InvalidOperationException) { }
    Console.WriteLine("Personal approval selection tests passed; all test changes rolled back.");
} finally {await tx.RollbackAsync();}
