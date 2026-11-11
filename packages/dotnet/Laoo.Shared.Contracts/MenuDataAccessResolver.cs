using System.Data;
using System.Data.Common;

namespace Laoo.Shared.Contracts;

/// <summary>Loads company-scoped row policy and employee relationships. Menu and
/// project authorization must be checked separately before calling this class.</summary>
public static class MenuDataAccessResolver
{
    public static async Task<MenuDataAccessRule?> ReadRuleAsync(
        DbConnection db, DbTransaction? transaction, long companyId,
        string menuCode, string action, CancellationToken token)
    {
        if (companyId <= 0 || action is not ("VIEW" or "EDIT" or "DELETE"))
            throw new ArgumentException("Invalid data access request.");
        await using var cmd = db.CreateCommand();
        cmd.Transaction = transaction;
        cmd.CommandText = """
SELECT m.AllowDataAccessSettings,p.ViewScope,p.EditScope,p.DeleteScope,
       p.ViewHead,p.ViewManager,p.EditHead,p.EditManager,p.DeleteHead,p.DeleteManager,
       g.ViewScope,g.EditMode,g.DeleteMode,p.ViewStaff,p.EditStaff,p.DeleteStaff,
       d.ViewScope,d.EditScope,d.DeleteScope,d.ViewHead,d.ViewManager,d.EditHead,d.EditManager,d.DeleteHead,d.DeleteManager,d.ViewStaff,d.EditStaff,d.DeleteStaff
FROM dbo.TDADMainMenu m
LEFT JOIN dbo.TDSTMenuDataAccessPolicy p ON p.CompanyID=@company AND p.MenuCode=m.MenuCode
LEFT JOIN dbo.TDSTTravelClaimAccess g ON g.CompanyID=@company
LEFT JOIN dbo.TDSTCompanyDataAccessDefault d ON d.CompanyID=@company
WHERE m.MenuCode=@menu AND m.IsActive=1;
""";
        Add(cmd,"@company",DbType.Int64,companyId);
        Add(cmd,"@menu",DbType.String,menuCode);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) throw new InvalidOperationException("Menu not found.");
        if (!reader.GetBoolean(0)) return null;
        if (!reader.IsDBNull(1))
        {
            var index = action == "VIEW" ? 1 : action == "EDIT" ? 2 : 3;
            var headIndex = action == "VIEW" ? 4 : action == "EDIT" ? 6 : 8;
            var selectedScope=reader.GetString(index);
            return new(selectedScope,selectedScope != "SELF" && reader.GetBoolean(headIndex),selectedScope is not ("SELF" or "DEPARTMENT") && reader.GetBoolean(headIndex+1),selectedScope != "SELF");
        }
        if (!reader.IsDBNull(16))
        {
            var index=action=="VIEW"?16:action=="EDIT"?17:18;
            var headIndex=action=="VIEW"?19:action=="EDIT"?21:23;
            var selectedScope=reader.GetString(index);
            return new(selectedScope,selectedScope!="SELF" && reader.GetBoolean(headIndex),selectedScope is not ("SELF" or "DEPARTMENT") && reader.GetBoolean(headIndex+1),selectedScope!="SELF");
        }
        // If no per-menu override exists, inherit the company-wide setting.
        var scope = reader.IsDBNull(10) ? "SELF" : reader.GetString(10);
        if (scope is not ("SELF" or "DEPARTMENT" or "DIVISION"))
            throw new InvalidOperationException("Invalid company access policy.");
        if (action == "VIEW") return new(scope,scope != "SELF",scope == "DIVISION",scope != "SELF");
        var modeIndex = action == "EDIT" ? 11 : 12;
        var mode = reader.IsDBNull(modeIndex) ? "HEAD" : reader.GetString(modeIndex);
        if (mode is not ("ALL" or "HEAD")) throw new InvalidOperationException("Invalid company access mode.");
        return mode == "ALL" ? new(scope,scope != "SELF",scope == "DIVISION",scope != "SELF") : new("SELF",false,false,false);
    }

    public static async Task<MenuDataAccessContext> ReadContextAsync(
        DbConnection db, DbTransaction? transaction, long companyId, long actorId,
        long ownerId, CancellationToken token)
    {
        await using var cmd = db.CreateCommand();
        cmd.Transaction = transaction;
        cmd.CommandText = """
SELECT
 CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE CompanyID=@company AND UserID=@actor AND IsActive=1 AND IsCompanyAdmin=1) THEN 1 ELSE 0 END AS bit),
 (SELECT CASE WHEN COUNT(DISTINCT e.DepartmentOrgUnitID)=1 THEN MIN(e.DepartmentOrgUnitID) END FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID AND e.IsActive=1 WHERE ue.CompanyID=@company AND ue.UserID=@actor AND ue.IsActive=1),
 (SELECT CASE WHEN COUNT(DISTINCT e.DepartmentOrgUnitID)=1 THEN MIN(e.DepartmentOrgUnitID) END FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID AND e.IsActive=1 WHERE ue.CompanyID=@company AND ue.UserID=@owner AND ue.IsActive=1),
 (SELECT CASE WHEN COUNT(DISTINCT e.DivisionOrgUnitID)=1 THEN MIN(e.DivisionOrgUnitID) END FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID AND e.IsActive=1 WHERE ue.CompanyID=@company AND ue.UserID=@actor AND ue.IsActive=1),
 (SELECT CASE WHEN COUNT(DISTINCT e.DivisionOrgUnitID)=1 THEN MIN(e.DivisionOrgUnitID) END FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID AND e.IsActive=1 WHERE ue.CompanyID=@company AND ue.UserID=@owner AND ue.IsActive=1);
""";
        Add(cmd,"@company",DbType.Int64,companyId);
        Add(cmd,"@actor",DbType.Int64,actorId);
        Add(cmd,"@owner",DbType.Int64,ownerId);
        bool admin; long? actorDept, ownerDept, actorDiv, ownerDiv;
        await using (var reader = await cmd.ExecuteReaderAsync(token))
        {
            if (!await reader.ReadAsync(token)) throw new InvalidOperationException("Access context unavailable.");
            admin=reader.GetBoolean(0);
            actorDept=GetLong(reader,1); ownerDept=GetLong(reader,2);
            actorDiv=GetLong(reader,3); ownerDiv=GetLong(reader,4);
        }
        cmd.Parameters.Clear();
        cmd.CommandText = """
SELECT CAST(CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID AND e.IsActive=1 JOIN dbo.TDADOrganizationSupervisor s ON s.CompanyID=ue.CompanyID AND s.EmployeeID=e.EmployeeID AND s.IsActive=1 WHERE ue.CompanyID=@company AND ue.UserID=@actor AND ue.IsActive=1 AND s.SupervisorType=N'DEPARTMENT_HEAD' AND s.OrgUnitID=@department) THEN 1 ELSE 0 END AS bit),
CAST(CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID AND e.IsActive=1 JOIN dbo.TDADOrganizationSupervisor s ON s.CompanyID=ue.CompanyID AND s.EmployeeID=e.EmployeeID AND s.IsActive=1 WHERE ue.CompanyID=@company AND ue.UserID=@actor AND ue.IsActive=1 AND s.SupervisorType=N'DIVISION_MANAGER' AND s.OrgUnitID=@division) THEN 1 ELSE 0 END AS bit);
""";
        Add(cmd,"@company",DbType.Int64,companyId); Add(cmd,"@actor",DbType.Int64,actorId);
        Add(cmd,"@department",DbType.Int64,ownerDept); Add(cmd,"@division",DbType.Int64,ownerDiv);
        await using var supervisors = await cmd.ExecuteReaderAsync(token);
        if (!await supervisors.ReadAsync(token)) throw new InvalidOperationException("Supervisor context unavailable.");
        return new(admin,actorId,ownerId,actorDept,ownerDept,actorDiv,ownerDiv,supervisors.GetBoolean(0),supervisors.GetBoolean(1));
    }

    private static long? GetLong(DbDataReader r,int i) => r.IsDBNull(i) ? null : Convert.ToInt64(r.GetValue(i));
    private static void Add(DbCommand cmd,string name,DbType type,object? value)
    {
        var p=cmd.CreateParameter(); p.ParameterName=name; p.DbType=type; p.Value=value ?? DBNull.Value; cmd.Parameters.Add(p);
    }
}
