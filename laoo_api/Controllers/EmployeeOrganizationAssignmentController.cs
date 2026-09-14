using System.Data;
using System.Security.Claims;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/employees/{employeeId:long}/organization-assignment")]
public sealed class EmployeeOrganizationAssignmentController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(long employeeId, [FromQuery] DateOnly? workDate, CancellationToken token)
    {
        var companyId = long.TryParse(User.FindFirstValue("company_id"), out var company) ? company : 0;
        if (companyId <= 0 || User.FindFirstValue("user_type") != "COMPANY_USER") return Forbid();
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        if (!await CompanyProjectPermission.IsAllowedAsync(connection, User, "10001", "VIEW", token)) return Forbid();
        const string sql = """
SELECT TOP(1) EmployeeOrganizationAssignmentID,EmployeeID,CompanyID,HomeBranchID,DivisionOrgUnitID,DepartmentOrgUnitID,EffectiveFrom,EffectiveTo,IsActive,RowVersion
FROM dbo.TDADEmployeeOrganizationAssignment
WHERE CompanyID=@company AND EmployeeID=@employee AND IsActive=1 AND EffectiveFrom<=@workDate AND (EffectiveTo IS NULL OR EffectiveTo>=@workDate)
ORDER BY EffectiveFrom DESC,EmployeeOrganizationAssignmentID DESC;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@employee", SqlDbType.BigInt).Value = employeeId;
        command.Parameters.Add("@workDate", SqlDbType.Date).Value = workDate ?? DateOnly.FromDateTime(DateTime.UtcNow);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound();
        return Ok(new { employeeOrganizationAssignmentID=reader.GetInt64(0),employeeID=reader.GetInt64(1),companyID=reader.GetInt64(2),homeBranchID=reader.IsDBNull(3)?(long?)null:reader.GetInt64(3),divisionOrgUnitID=reader.IsDBNull(4)?(long?)null:reader.GetInt64(4),departmentOrgUnitID=reader.IsDBNull(5)?(long?)null:reader.GetInt64(5),effectiveFrom=reader.GetDateTime(6),effectiveTo=reader.IsDBNull(7)?(DateTime?)null:reader.GetDateTime(7),isActive=reader.GetBoolean(8),rowVersion=Convert.ToBase64String((byte[])reader[9]) });
    }
}