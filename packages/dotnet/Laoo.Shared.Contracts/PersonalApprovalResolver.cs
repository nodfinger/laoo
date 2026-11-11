using System.Data;
using System.Data.Common;

namespace Laoo.Shared.Contracts;

/// <summary>
/// Reads a requester's personal approval order for one company and menu.
/// Callers must verify project, menu and action permissions and use the document
/// transaction. A null result means no personal order and permits the normal
/// pattern; invalid personal orders fail closed rather than falling back.
/// </summary>
public static class PersonalApprovalResolver
{
    public static async Task<IReadOnlyList<long>?> ReadAsync(
        DbConnection db,DbTransaction? transaction,long companyId,long userId,
        string menuCode,CancellationToken token)
    {
        if(companyId<=0 || userId<=0 || string.IsNullOrWhiteSpace(menuCode))
            throw new ArgumentException("Invalid personal approval context.");
        await using var cmd=db.CreateCommand();
        cmd.Transaction=transaction;
        cmd.CommandText="""
SELECT DISTINCT E.EmployeeID FROM dbo.TDADUserEmployee UE
JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=UE.CompanyID AND E.IsActive=1
JOIN dbo.TDADUser U ON U.UserID=UE.UserID AND U.CompanyID=UE.CompanyID AND U.IsActive=1
WHERE UE.CompanyID=@company AND UE.UserID=@user AND UE.IsActive=1;
""";
        Add(cmd,"@company",DbType.Int64,companyId);Add(cmd,"@user",DbType.Int64,userId);
        var employees=new List<long>();
        await using(var reader=await cmd.ExecuteReaderAsync(token))
            while(await reader.ReadAsync(token)) employees.Add(reader.GetInt64(0));
        if(employees.Count==0) return null;
        if(employees.Count!=1) throw new InvalidOperationException("The login is linked to multiple active employees.");

        await using var steps=db.CreateCommand();
        steps.Transaction=transaction;
        steps.CommandText="""
SELECT S.StepNo,S.ApproverEmployeeID,CASE WHEN E.EmployeeID IS NOT NULL AND E.IsActive=1 THEN 1 ELSE 0 END
FROM dbo.TDSTPersonalApprovalStep S
LEFT JOIN dbo.TDADEmployee E ON E.EmployeeID=S.ApproverEmployeeID AND E.CompanyID=S.CompanyID
WHERE S.CompanyID=@company AND S.MenuCode=@menu AND S.RequesterEmployeeID=@employee
ORDER BY S.StepNo;
""";
        Add(steps,"@company",DbType.Int64,companyId);Add(steps,"@menu",DbType.String,menuCode.Trim());
        Add(steps,"@employee",DbType.Int64,employees[0]);
        var result=new List<long>();
        await using(var reader=await steps.ExecuteReaderAsync(token)) {
            while(await reader.ReadAsync(token)) {
                var order=reader.GetInt32(0);var approver=reader.GetInt64(1);
                if(order!=result.Count+1 || approver<=0 || approver==employees[0] || Convert.ToInt32(reader.GetValue(2))!=1 || result.Contains(approver))
                    throw new InvalidOperationException("The personal approval order is invalid or contains an inactive approver.");
                result.Add(approver);
            }
        }
        return result.Count==0?null:result;
    }

    private static void Add(DbCommand cmd,string name,DbType type,object value)
    {var p=cmd.CreateParameter();p.ParameterName=name;p.DbType=type;p.Value=value;cmd.Parameters.Add(p);}
}
