using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/company/organization-supervisors")]
[Authorize]
public sealed class OrganizationSupervisorController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        if (!TryCompany(out var companyId)) return Forbid();
        await using var connection = await Open(token);
        const string sql = """
SELECT U.OrgUnitID,U.UnitType,U.UnitCode,U.NameTH,U.ParentOrgUnitID,
       S.SupervisorID,S.SupervisorType,S.EmployeeID,E.EmployeeCode,E.FullName,E.NickName
FROM dbo.TDADOrganizationUnit U
LEFT JOIN dbo.TDADOrganizationSupervisor S ON S.CompanyID=U.CompanyID AND S.OrgUnitID=U.OrgUnitID AND S.IsActive=1
LEFT JOIN dbo.TDADEmployee E ON E.EmployeeID=S.EmployeeID AND E.CompanyID=U.CompanyID AND E.IsActive=1
WHERE U.CompanyID=@company AND U.OwnerType='C' AND U.IsActive=1 AND U.UnitType IN (N'DIV',N'DEP')
ORDER BY CASE WHEN U.UnitType=N'DIV' THEN 0 ELSE 1 END,U.UnitCode;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId;
        await using var reader = await command.ExecuteReaderAsync(token);
        var rows = new List<object>();
        while (await reader.ReadAsync(token))
        {
            rows.Add(new
            {
                orgUnitId = reader.GetInt64(0),
                unitType = reader.GetString(1),
                unitCode = reader.GetString(2),
                nameTh = reader.GetString(3),
                parentOrgUnitId = reader.IsDBNull(4) ? (long?)null : reader.GetInt64(4),
                supervisorId = reader.IsDBNull(5) ? (long?)null : reader.GetInt64(5),
                supervisorType = reader.IsDBNull(6) ? null : reader.GetString(6),
                employeeId = reader.IsDBNull(7) ? (long?)null : reader.GetInt64(7),
                employeeCode = reader.IsDBNull(8) ? null : reader.GetString(8),
                employeeName = reader.IsDBNull(9) ? null : reader.GetString(9),
                employeeNickName = reader.IsDBNull(10) ? null : reader.GetString(10),
            });
        }
        return Ok(rows);
    }

    [HttpPut("{orgUnitId:long}")]
    public async Task<IActionResult> Save(long orgUnitId, SupervisorRequest request, CancellationToken token)
    {
        if (!TryCompany(out var companyId)) return Forbid();
        if (request.EmployeeId <= 0) return BadRequest(new { message = "กรุณาเลือกผู้บังคับบัญชา" });
        await using var connection = await Open(token);
        const string sql = """
DECLARE @unitType nvarchar(20), @expected nvarchar(30);
SELECT @unitType=UnitType FROM dbo.TDADOrganizationUnit WHERE OrgUnitID=@unit AND CompanyID=@company AND OwnerType='C' AND IsActive=1;
IF @unitType IS NULL THROW 50020,'ไม่พบหน่วยงานของ Customer',1;
SET @expected=CASE WHEN @unitType=N'DIV' THEN N'DIVISION_MANAGER' WHEN @unitType=N'DEP' THEN N'DEPARTMENT_HEAD' ELSE N'' END;
IF @expected<>@type THROW 50021,'ประเภทผู้บังคับบัญชาไม่ตรงกับหน่วยงาน',1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDADEmployee WHERE EmployeeID=@employee AND CompanyID=@company AND IsActive=1)
    THROW 50022,'ไม่พบพนักงานของ Customer',1;
UPDATE dbo.TDADOrganizationSupervisor SET EmployeeID=@employee,IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND OrgUnitID=@unit AND SupervisorType=@type;
IF @@ROWCOUNT=0 INSERT dbo.TDADOrganizationSupervisor(CompanyID,OrgUnitID,EmployeeID,SupervisorType,CreateDate,CreateBy) VALUES(@company,@unit,@employee,@type,SYSUTCDATETIME(),@user);
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@unit", SqlDbType.BigInt).Value = orgUnitId;
        command.Parameters.Add("@employee", SqlDbType.BigInt).Value = request.EmployeeId;
        command.Parameters.Add("@type", SqlDbType.NVarChar, 30).Value = request.SupervisorType.Trim();
        command.Parameters.Add("@user", SqlDbType.BigInt).Value = CurrentUserId();
        await command.ExecuteNonQueryAsync(token);
        return Ok(new { message = "บันทึกผู้บังคับบัญชาสำเร็จ" });
    }

    private bool TryCompany(out long companyId) => long.TryParse(User.FindFirstValue("company_id"), out companyId) && User.FindFirstValue("user_type") == "COMPANY_USER";
    private long CurrentUserId() => long.TryParse(User.FindFirstValue("user_id"), out var id) ? id : 0;
    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }
}

public sealed record SupervisorRequest(long EmployeeId, string SupervisorType);
