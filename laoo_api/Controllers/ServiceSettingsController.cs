using System.Data;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/service/settings")]
public sealed class ServiceSettingsController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (!await CompanyProjectPermission.IsAllowedAsync(c, User, "18001", "VIEW", token)) return Forbid();
        var projectId = await ProjectId(c, token);
        const string sql = "SELECT COALESCE(ServiceEnabled,1),COALESCE(AllowWalkIn,1),COALESCE(RequireEquipment,1),COALESCE(AttachmentRequired,0),COALESCE(WorkflowEnabled,1),COALESCE(AttachmentMaxBytes,1048576) FROM dbo.TDSTCompanySetupSystemService WHERE CompanyID=@company AND ProjectID=@project";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@project", SqlDbType.BigInt, projectId);
        await using var r = await q.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return Ok(Default(projectId));
        return Ok(new { companyId = CompanyId, projectId, serviceEnabled = r.GetBoolean(0), allowWalkIn = r.GetBoolean(1), requireEquipment = r.GetBoolean(2), attachmentRequired = r.GetBoolean(3), workflowEnabled = r.GetBoolean(4), attachmentMaxBytes = r.GetInt32(5) });
    }

    [HttpPut]
    public async Task<IActionResult> Update([FromBody] ServiceSettingsRequest request, CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (!await CompanyProjectPermission.IsAllowedAsync(c, User, "18001", "EDIT", token)) return Forbid();
        var projectId = await ProjectId(c, token);
        const string sql = """
MERGE dbo.TDSTCompanySetupSystemService AS target
USING (SELECT @company AS CompanyID,@project AS ProjectID) AS source ON target.CompanyID=source.CompanyID AND target.ProjectID=source.ProjectID
WHEN MATCHED THEN UPDATE SET ServiceEnabled=@enabled,AllowWalkIn=@walkin,RequireEquipment=@equipment,AttachmentRequired=@attachment,WorkflowEnabled=@workflow,AttachmentMaxBytes=1048576,UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(CompanyID,ProjectID,ServiceEnabled,AllowWalkIn,RequireEquipment,AttachmentRequired,WorkflowEnabled,AttachmentMaxBytes,CreateBy) VALUES(@company,@project,@enabled,@walkin,@equipment,@attachment,@workflow,1048576,@user);
""";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@project", SqlDbType.BigInt, projectId); Add(q, "@enabled", SqlDbType.Bit, request.ServiceEnabled); Add(q, "@walkin", SqlDbType.Bit, request.AllowWalkIn); Add(q, "@equipment", SqlDbType.Bit, request.RequireEquipment); Add(q, "@attachment", SqlDbType.Bit, request.AttachmentRequired); Add(q, "@workflow", SqlDbType.Bit, request.WorkflowEnabled); Add(q, "@user", SqlDbType.BigInt, UserId); await q.ExecuteNonQueryAsync(token);
        return Ok(new { saved = true, attachmentMaxBytes = 1048576 });
    }

    private async Task<long> ProjectId(SqlConnection c, CancellationToken token)
    {
        await using var q = new SqlCommand("SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SERVICE' AND IsActive=1", c);
        var value = await q.ExecuteScalarAsync(token); return Convert.ToInt64(value);
    }

    private static object Default(long projectId) => new { companyId = 0L, projectId, serviceEnabled = true, allowWalkIn = true, requireEquipment = true, attachmentRequired = false, workflowEnabled = true, attachmentMaxBytes = 1048576 };
    private static void Add(SqlCommand command, string name, SqlDbType type, object? value) => command.Parameters.Add(name, type).Value = value ?? DBNull.Value;
}

public sealed record ServiceSettingsRequest(bool ServiceEnabled, bool AllowWalkIn, bool RequireEquipment, bool AttachmentRequired, bool WorkflowEnabled);
