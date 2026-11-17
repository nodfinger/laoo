using System.Data;
using System.Reflection;
using LaooApi.Controllers;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

if (args.Length != 1) throw new ArgumentException("Pass the root containing laoo_api/local.json");
var configuration = new ConfigurationBuilder().AddJsonFile(Path.Combine(args[0], "laoo_api", "local.json")).Build();
await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
await connection.OpenAsync();
await using var tx = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable);
try
{
    async Task<int> Exec(string sql, params (string Name, object Value)[] args)
    {
        if (sql.Contains("dbo.", StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Refusing access to non-temporary tables");
        await using var command = new SqlCommand(sql, connection, tx);
        foreach (var (name, value) in args) command.Parameters.AddWithValue(name, value);
        return await command.ExecuteNonQueryAsync();
    }
    async Task<object?> Scalar(string sql, params (string Name, object Value)[] args)
    {
        if (sql.Contains("dbo.", StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Refusing access to non-temporary tables");
        await using var command = new SqlCommand(sql, connection, tx);
        foreach (var (name, value) in args) command.Parameters.AddWithValue(name, value);
        return await command.ExecuteScalarAsync();
    }
    await Exec("""
CREATE TABLE #Setting(CompanyID bigint,TargetType varchar(10),ReviewMode varchar(10),OrgLevel varchar(10));
CREATE TABLE #Reviewer(CompanyID bigint,TargetType varchar(10),EmployeeID bigint);
CREATE TABLE #UserEmployee(CompanyID bigint,UserID bigint,EmployeeID bigint,IsActive bit);
CREATE TABLE #Employee(CompanyID bigint,EmployeeID bigint,IsActive bit,DepartmentOrgUnitID bigint NULL,DivisionOrgUnitID bigint NULL);
CREATE TABLE #Users(CompanyID bigint,UserID bigint,IsActive bit);
CREATE TABLE #Draft(CompanyID bigint,DraftID bigint,SubmittedBy bigint,Status varchar(12),Payload nvarchar(max),RowVersion rowversion);
CREATE TABLE #Images(CompanyID bigint,DraftID bigint,ImageData varbinary(max));
INSERT #Draft(CompanyID,DraftID,SubmittedBy,Status,Payload) VALUES(1,5,10,'DRAFT',N'old');
INSERT #Images VALUES(1,5,0x010203);
INSERT #Users VALUES(1,10,1),(1,20,1),(2,30,1),(1,40,0);
INSERT #Employee VALUES(1,100,1,7,8),(1,200,1,7,8),(2,300,1,7,8),(1,400,1,7,8);
INSERT #UserEmployee VALUES(1,10,100,1),(1,20,200,1),(2,30,300,1),(1,40,400,1);
""");
    foreach (var (type, controller, name) in new[] { ("CUSTOMER", typeof(CompanyContactsController), "ReviewerPredicate"), ("SUPPLIER", typeof(SupplierContactsController), "Reviewer") })
    {
        var predicate = (string?)controller.GetField(name, BindingFlags.NonPublic | BindingFlags.Static)?.GetRawConstantValue() ?? throw new Exception("Reviewer predicate not found");
        predicate = predicate.Replace("dbo.TDSTBusinessCardReviewSetting", "#Setting").Replace("dbo.TDSTBusinessCardReviewer", "#Reviewer").Replace("dbo.TDADUserEmployee", "#UserEmployee").Replace("dbo.TDADEmployee", "#Employee").Replace("@actor", "candidate.UserID");
        if (predicate.Contains("dbo.", StringComparison.OrdinalIgnoreCase)) throw new Exception("Predicate references an unexpected real table");
        var query = $"SELECT COUNT(*) FROM #Draft q JOIN #Users candidate ON candidate.CompanyID=q.CompanyID AND candidate.IsActive=1 WHERE q.DraftID=5 AND candidate.UserID=@candidate AND {predicate}";
        async Task Expect(long user, int expected, string scenario) { var actual = Convert.ToInt32(await Scalar(query, ("@candidate", user))); if (actual != expected) throw new Exception($"{type} {scenario}: expected {expected}, got {actual}"); }
        await Expect(20, 0, "no configuration");
        await Exec("INSERT #Setting VALUES(1,@type,'EMPLOYEE','DEP'); INSERT #Reviewer VALUES(1,@type,200)", ("@type", type));
        await Expect(20, 1, "assigned active reviewer");
        await Expect(30, 0, "different company");
        await Exec("UPDATE #Users SET IsActive=0 WHERE UserID=20"); await Expect(20, 0, "disabled account"); await Exec("UPDATE #Users SET IsActive=1 WHERE UserID=20");
        await Exec("UPDATE #Setting SET ReviewMode='ORG' WHERE CompanyID=1 AND TargetType=@type", ("@type", type)); await Expect(20, 1, "same department");
        await Exec("UPDATE #Employee SET DepartmentOrgUnitID=9 WHERE EmployeeID=200"); await Expect(20, 0, "different department");
        await Exec("UPDATE #Setting SET OrgLevel='DIV' WHERE CompanyID=1 AND TargetType=@type", ("@type", type)); await Expect(20, 1, "same division");
        await Exec("UPDATE #Employee SET DivisionOrgUnitID=10 WHERE EmployeeID=200"); await Expect(20, 0, "different division");
        await Exec("UPDATE #Employee SET DepartmentOrgUnitID=7,DivisionOrgUnitID=8 WHERE EmployeeID=200");
        await Exec("DELETE #Setting WHERE TargetType=@type; DELETE #Reviewer WHERE TargetType=@type", ("@type", type));
        Console.WriteLine($"{type}: reviewer configuration, company, active account and organization checks passed");
    }
    var stale = (byte[])(await Scalar("SELECT RowVersion FROM #Draft WHERE DraftID=5"))!;
    var edit = "UPDATE #Draft SET Payload=N'new' WHERE CompanyID=@company AND DraftID=5 AND SubmittedBy=@actor AND Status='DRAFT' AND RowVersion=@version";
    if (await Exec(edit, ("@company", 2), ("@actor", 10), ("@version", stale)) != 0) throw new Exception("Cross-company edit accepted");
    if (await Exec(edit, ("@company", 1), ("@actor", 20), ("@version", stale)) != 0) throw new Exception("Non-owner edit accepted");
    if (await Exec(edit, ("@company", 1), ("@actor", 10), ("@version", stale)) != 1) throw new Exception("Owner edit failed");
    if (await Exec(edit, ("@company", 1), ("@actor", 10), ("@version", stale)) != 0) throw new Exception("Stale edit accepted");
    if (Convert.ToInt32(await Scalar("SELECT COUNT(*) FROM #Images WHERE CompanyID=1 AND DraftID=5 AND ImageData=0x010203")) != 1) throw new Exception("Image not preserved");
    var fresh = (byte[])(await Scalar("SELECT RowVersion FROM #Draft WHERE DraftID=5"))!;
    if (await Exec("UPDATE #Draft SET Status='PENDING' WHERE CompanyID=1 AND DraftID=5 AND SubmittedBy=10 AND Status='DRAFT' AND RowVersion=@version", ("@version", stale)) != 0) throw new Exception("Stale send accepted");
    if (await Exec("UPDATE #Draft SET Status='PENDING' WHERE CompanyID=1 AND DraftID=5 AND SubmittedBy=10 AND Status='DRAFT' AND RowVersion=@version", ("@version", fresh)) != 1) throw new Exception("Current draft send failed");
    fresh = (byte[])(await Scalar("SELECT RowVersion FROM #Draft WHERE DraftID=5"))!;
    if (await Exec(edit, ("@company", 1), ("@actor", 10), ("@version", fresh)) != 0) throw new Exception("Pending edit accepted");
    Console.WriteLine("Draft owner/company/state, image preservation and RowVersion checks passed");
}
finally { await tx.RollbackAsync(); Console.WriteLine("Transaction rolled back"); }
