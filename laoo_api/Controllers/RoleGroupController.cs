using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Route("api/role-groups"), Authorize]
public sealed class RoleGroupController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<RoleGroupResponse>>> List([FromQuery] string scope, [FromQuery] string? search, CancellationToken token)
    {
        if (!TryScope(scope, out var scopeType, out var screen)) return BadRequest(new { message = "scope ไม่ถูกต้อง" });
        await using var c = await OpenAsync(token);
        if (!await HasPermissionAsync(c, screen, "VIEW", token)) return Forbid();
        var owner = OwnerId(scopeType); var project = ClaimLong("project_id");
        if (!owner.HasValue || !project.HasValue) return BadRequest(new { message = "ไม่พบ Scope ของผู้ใช้งาน" });
        const string sql = """
            SELECT RoleGroupID,RoleCode,RoleNameTH,Description,IsActive
            FROM dbo.TDADRoleGroup
            WHERE ProjectID=@ProjectID AND ScopeType=@ScopeType
              AND ((@ScopeType='P' AND PartnerID=@PartnerID AND CompanyID IS NULL)
                OR (@ScopeType='C' AND CompanyID=@CompanyID AND PartnerID IS NULL)
                OR (@ScopeType='L' AND PartnerID IS NULL AND CompanyID IS NULL))
              AND (@Search IS NULL OR RoleCode LIKE @Search OR RoleNameTH LIKE @Search)
            ORDER BY RoleNameTH;
            """;
        await using var cmd = new SqlCommand(sql, c);
        BindScope(cmd, project.Value, scopeType, owner.Value); Add(cmd, "@Search", SqlDbType.NVarChar, string.IsNullOrWhiteSpace(search) ? null : $"%{search.Trim()}%", 500);
        await using var r = await cmd.ExecuteReaderAsync(token); var result = new List<RoleGroupResponse>();
        while (await r.ReadAsync(token)) result.Add(Read(r, scope));
        return Ok(result);
    }

    [HttpGet("actions")]
    public async Task<ActionResult<object>> Actions([FromQuery] string scope, CancellationToken token)
    {
        if (!TryScope(scope, out _, out var screen)) return BadRequest(new { message = "scope ไม่ถูกต้อง" });
        await using var c = await OpenAsync(token);
        return Ok(new
        {
            view = await HasPermissionAsync(c, screen, "VIEW", token),
            create = await HasPermissionAsync(c, screen, "CREATE", token),
            edit = await HasPermissionAsync(c, screen, "EDIT", token),
            delete = await HasPermissionAsync(c, screen, "DELETE", token)
        });
    }

    [HttpPost]
    public async Task<ActionResult<RoleGroupResponse>> Create([FromQuery] string scope, RoleGroupUpsertRequest request, CancellationToken token)
    {
        if (!TryScope(scope, out var st, out var screen)) return BadRequest(new { message = "scope ไม่ถูกต้อง" });
        if (string.IsNullOrWhiteSpace(request.RoleCode) || string.IsNullOrWhiteSpace(request.RoleNameTh)) return BadRequest(new { message = "กรุณาระบุรหัสและชื่อกลุ่มสิทธิ์" });
        await using var c = await OpenAsync(token); if (!await HasPermissionAsync(c, screen, "CREATE", token)) return Forbid();
        var owner = OwnerId(st); var project = ClaimLong("project_id"); if (!owner.HasValue || !project.HasValue) return BadRequest(new { message = "ไม่พบ Scope ของผู้ใช้งาน" });
        var duplicate = await DuplicateMessageAsync(c, project.Value, st, owner.Value, request, null, token); if (duplicate != null) return Conflict(new { message = duplicate });
        const string sql = "INSERT dbo.TDADRoleGroup(ProjectID,ScopeType,PartnerID,CompanyID,RoleCode,RoleNameTH,Description,IsActive,CreatedBy) VALUES(@ProjectID,@ScopeType,@PartnerID,@CompanyID,@RoleCode,@RoleNameTH,@Description,@IsActive,N'api'); SELECT CAST(SCOPE_IDENTITY() AS BIGINT);";
        await using var cmd = new SqlCommand(sql, c); BindScope(cmd, project.Value, st, owner.Value); BindRequest(cmd, request);
        try { var id = Convert.ToInt64(await cmd.ExecuteScalarAsync(token)); return Created($"/api/role-groups/{id}", new RoleGroupResponse { RoleGroupId = id, Scope = scope, RoleCode = request.RoleCode.Trim(), RoleNameTh = request.RoleNameTh.Trim(), Description = Null(request.Description), IsActive = request.IsActive }); }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { return Conflict(new { message = "รหัสกลุ่มสิทธิ์ซ้ำ" }); }
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, [FromQuery] string scope, RoleGroupUpsertRequest request, CancellationToken token)
    {
        if (!TryScope(scope, out var st, out var screen)) return BadRequest(new { message = "scope ไม่ถูกต้อง" });
        if (string.IsNullOrWhiteSpace(request.RoleCode) || string.IsNullOrWhiteSpace(request.RoleNameTh)) return BadRequest(new { message = "กรุณาระบุรหัสและชื่อกลุ่มสิทธิ์" });
        await using var c = await OpenAsync(token); if (!await HasPermissionAsync(c, screen, "EDIT", token)) return Forbid();
        var owner = OwnerId(st); var project = ClaimLong("project_id"); if (!owner.HasValue || !project.HasValue) return BadRequest(new { message = "ไม่พบ Scope ของผู้ใช้งาน" });
        var duplicate = await DuplicateMessageAsync(c, project.Value, st, owner.Value, request, id, token); if (duplicate != null) return Conflict(new { message = duplicate });
        const string sql = "UPDATE dbo.TDADRoleGroup SET RoleCode=@RoleCode,RoleNameTH=@RoleNameTH,Description=@Description,IsActive=@IsActive,UpdatedUtc=SYSUTCDATETIME(),UpdatedBy=N'api' WHERE RoleGroupID=@ID AND ProjectID=@ProjectID AND ScopeType=@ScopeType AND ((@ScopeType='P' AND PartnerID=@PartnerID AND CompanyID IS NULL) OR (@ScopeType='C' AND CompanyID=@CompanyID AND PartnerID IS NULL) OR (@ScopeType='L' AND PartnerID IS NULL AND CompanyID IS NULL));";
        await using var cmd = new SqlCommand(sql, c); BindScope(cmd, project.Value, st, owner.Value); BindRequest(cmd, request); Add(cmd, "@ID", SqlDbType.BigInt, id);
        return await cmd.ExecuteNonQueryAsync(token) == 0 ? NotFound() : NoContent();
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, [FromQuery] string scope, CancellationToken token)
    {
        if (!TryScope(scope, out var st, out var screen)) return BadRequest(new { message = "scope ไม่ถูกต้อง" });
        await using var c = await OpenAsync(token); if (!await HasPermissionAsync(c, screen, "DELETE", token)) return Forbid();
        if (!TryGetDeleteScope(st, out var project, out var owner)) return Forbid();
        const string sql = """
            IF NOT EXISTS
            (
                SELECT 1 FROM dbo.TDADRoleGroup WITH (UPDLOCK,HOLDLOCK)
                WHERE RoleGroupID=@ID AND ProjectID=@ProjectID AND ScopeType=@ScopeType
                  AND ((@ScopeType='P' AND PartnerID=@PartnerID AND CompanyID IS NULL)
                    OR (@ScopeType='C' AND CompanyID=@CompanyID AND PartnerID IS NULL)
                    OR (@ScopeType='L' AND PartnerID IS NULL AND CompanyID IS NULL))
            )
            BEGIN
                SELECT CAST(0 AS int);
                RETURN;
            END;
            DELETE RP FROM dbo.TDADRoleGroupPermission RP
            INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=RP.RoleGroupID
            WHERE RP.RoleGroupID=@ID AND RP.ProjectID=@ProjectID
              AND RG.ProjectID=@ProjectID AND RG.ScopeType=@ScopeType
              AND ((@ScopeType='P' AND RG.PartnerID=@PartnerID AND RG.CompanyID IS NULL)
                OR (@ScopeType='C' AND RG.CompanyID=@CompanyID AND RG.PartnerID IS NULL)
                OR (@ScopeType='L' AND RG.PartnerID IS NULL AND RG.CompanyID IS NULL));
            DELETE ERG FROM dbo.TDADEmployeeRoleGroup ERG
            INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID
            WHERE ERG.RoleGroupID=@ID AND RG.ProjectID=@ProjectID AND RG.ScopeType=@ScopeType
              AND ((@ScopeType='P' AND RG.PartnerID=@PartnerID AND RG.CompanyID IS NULL)
                OR (@ScopeType='C' AND RG.CompanyID=@CompanyID AND RG.PartnerID IS NULL)
                OR (@ScopeType='L' AND RG.PartnerID IS NULL AND RG.CompanyID IS NULL));
            DELETE FROM dbo.TDADRoleGroup
            WHERE RoleGroupID=@ID AND ProjectID=@ProjectID AND ScopeType=@ScopeType
              AND ((@ScopeType='P' AND PartnerID=@PartnerID AND CompanyID IS NULL)
                OR (@ScopeType='C' AND CompanyID=@CompanyID AND PartnerID IS NULL)
                OR (@ScopeType='L' AND PartnerID IS NULL AND CompanyID IS NULL));
            SELECT @@ROWCOUNT;
            """;
        await using var transaction = await c.BeginTransactionAsync(token);
        try
        {
            await using var cmd = new SqlCommand(sql, c, (SqlTransaction)transaction);
            BindScope(cmd, project, st, owner); Add(cmd, "@ID", SqlDbType.BigInt, id);
            var deleted = Convert.ToInt32(await cmd.ExecuteScalarAsync(token));
            if (deleted == 0)
            {
                await transaction.RollbackAsync(token);
                return NotFound();
            }
            await transaction.CommitAsync(token);
            return NoContent();
        }
        catch
        {
            await transaction.RollbackAsync(token);
            throw;
        }
    }

    private async Task<string?> DuplicateMessageAsync(SqlConnection c, long project, char st, long owner, RoleGroupUpsertRequest request, long? exclude, CancellationToken token)
    {
        const string sql = """
            SELECT CASE
              WHEN EXISTS (SELECT 1 FROM dbo.TDADRoleGroup WHERE ProjectID=@ProjectID AND ScopeType=@ScopeType AND ((@ScopeType='P' AND PartnerID=@PartnerID AND CompanyID IS NULL) OR (@ScopeType='C' AND CompanyID=@CompanyID AND PartnerID IS NULL) OR (@ScopeType='L' AND PartnerID IS NULL AND CompanyID IS NULL)) AND RoleCode=@RoleCode AND (@ExcludeID IS NULL OR RoleGroupID<>@ExcludeID)) THEN N'รหัสกลุ่มสิทธิ์ซ้ำ'
              WHEN EXISTS (SELECT 1 FROM dbo.TDADRoleGroup WHERE ProjectID=@ProjectID AND ScopeType=@ScopeType AND ((@ScopeType='P' AND PartnerID=@PartnerID AND CompanyID IS NULL) OR (@ScopeType='C' AND CompanyID=@CompanyID AND PartnerID IS NULL) OR (@ScopeType='L' AND PartnerID IS NULL AND CompanyID IS NULL)) AND UPPER(LTRIM(RTRIM(RoleNameTH)))=UPPER(LTRIM(RTRIM(@RoleNameTH))) AND (@ExcludeID IS NULL OR RoleGroupID<>@ExcludeID)) THEN N'ชื่อกลุ่มสิทธิ์ซ้ำ'
              ELSE NULL END;
            """;
        await using var cmd = new SqlCommand(sql, c); BindScope(cmd, project, st, owner); Add(cmd, "@RoleCode", SqlDbType.NVarChar, request.RoleCode.Trim(), 50); Add(cmd, "@RoleNameTH", SqlDbType.NVarChar, request.RoleNameTh.Trim(), 200); Add(cmd, "@ExcludeID", SqlDbType.BigInt, exclude);
        return await cmd.ExecuteScalarAsync(token) as string;
    }

    private async Task<bool> HasPermissionAsync(SqlConnection c, string screen, string action, CancellationToken token)
    {
        var type = User.FindFirstValue("user_type") ?? string.Empty; var support = type.Equals("LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase); var partner = type.Equals("PARTNER_USER", StringComparison.OrdinalIgnoreCase); var user = support ? ClaimLong("laoo_user_id") : partner ? PartnerUserId() : ClaimLong("user_id"); var project = ClaimLong("project_id"); if (!user.HasValue || !project.HasValue) return false;
        var table = support ? "TDADLaooUserPermission" : partner ? "TDADPartnerUserPermission" : "TDADUserPermission";
        var column = support ? "LaooUserID" : partner ? "PartnerUserID" : "UserID";
        var admin = partner
            ? "OR EXISTS (SELECT 1 FROM dbo.TDADPartnerUser A WHERE A.PartnerUserID=@UserID AND A.IsPartnerAdmin=1 AND A.IsActive=1)"
            : type.Equals("COMPANY_USER", StringComparison.OrdinalIgnoreCase)
                ? "OR EXISTS (SELECT 1 FROM dbo.TDADUser A WHERE A.UserID=@UserID AND A.IsCompanyAdmin=1 AND A.IsActive=1)"
                : string.Empty;
        var rolePermission = partner ? """
            OR EXISTS (SELECT 1 FROM dbo.TDADPartnerUser U
              INNER JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.PartnerUserID=U.PartnerUserID
              INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=PUE.EmployeeID
              INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='P' AND RG.PartnerID=U.PartnerID AND RG.ProjectID=@ProjectID
              INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@ProjectID
                AND RP.MenuCode=@ScreenCode AND RP.ActionCode=@Action AND RP.IsAllowed=1
              WHERE U.PartnerUserID=@UserID AND U.IsActive=1 AND ERG.IsActive=1
                AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
                AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))
            """ : type.Equals("COMPANY_USER", StringComparison.OrdinalIgnoreCase) ? """
            OR EXISTS (SELECT 1 FROM dbo.TDADUser U
              INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID
              INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID
              INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@ProjectID
              INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@ProjectID
                AND RP.MenuCode=@ScreenCode AND RP.ActionCode=@Action AND RP.IsAllowed=1
              WHERE U.UserID=@UserID AND U.IsActive=1 AND ERG.IsActive=1
                AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
                AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))
            """ : string.Empty;
        var sql = $"SELECT CASE WHEN (EXISTS (SELECT 1 FROM dbo.{table} UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.{column}=@UserID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@ScreenCode AND P.ActionCode=@Action) {rolePermission} {admin}) THEN 1 ELSE 0 END";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@UserID", SqlDbType.BigInt, user); Add(cmd, "@ProjectID", SqlDbType.BigInt, project); Add(cmd, "@ScreenCode", SqlDbType.NVarChar, screen); Add(cmd, "@Action", SqlDbType.NVarChar, action); return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }

    private long? ClaimLong(string name) => long.TryParse(User.FindFirstValue(name), out var value) ? value : null;
    private bool TryGetDeleteScope(char scope, out long project, out long owner)
    {
        project = 0;
        owner = 0;
        if (ClaimLong("project_id") is not long projectId) return false;
        var userType = User.FindFirstValue("user_type") ?? string.Empty;
        if (scope == 'P' && userType.Equals("PARTNER_USER", StringComparison.OrdinalIgnoreCase) && ClaimLong("partner_id") is long partnerId) owner = partnerId;
        else if (scope == 'C' && userType.Equals("COMPANY_USER", StringComparison.OrdinalIgnoreCase) && ClaimLong("company_id") is long companyId) owner = companyId;
        else if (scope != 'L' || !userType.Equals("LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase) || !ClaimLong("laoo_user_id").HasValue) return false;
        project = projectId;
        return true;
    }
    private long? OwnerId(char scope) => scope == 'L' ? 0 : ClaimLong(scope == 'P' ? "partner_id" : "company_id");
    private long? PartnerUserId() { var subject = User.FindFirstValue("sub") ?? User.FindFirstValue(ClaimTypes.NameIdentifier); return subject?.StartsWith("partner:", StringComparison.OrdinalIgnoreCase) == true && long.TryParse(subject[8..], out var id) ? id : null; }
    private static bool TryScope(string value, out char scope, out string screen) { var s = value.Trim().ToLowerInvariant(); scope = s == "partner" ? 'P' : s == "customer" ? 'C' : s is "laoo" or "support" ? 'L' : ' '; screen = scope switch { 'P' => "11003", 'C' => "10003", 'L' => "12003", _ => string.Empty }; return scope != ' '; }
    private async Task<SqlConnection> OpenAsync(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private static void BindScope(SqlCommand c, long project, char scope, long owner) { Add(c, "@ProjectID", SqlDbType.BigInt, project); Add(c, "@ScopeType", SqlDbType.Char, scope); Add(c, "@PartnerID", SqlDbType.BigInt, scope == 'P' ? owner : null); Add(c, "@CompanyID", SqlDbType.BigInt, scope == 'C' ? owner : null); }
    private static void BindRequest(SqlCommand c, RoleGroupUpsertRequest r) { Add(c, "@RoleCode", SqlDbType.NVarChar, r.RoleCode.Trim(), 50); Add(c, "@RoleNameTH", SqlDbType.NVarChar, r.RoleNameTh.Trim(), 200); Add(c, "@Description", SqlDbType.NVarChar, Null(r.Description), 500); Add(c, "@IsActive", SqlDbType.Bit, r.IsActive); }
    private static RoleGroupResponse Read(SqlDataReader r, string scope) => new() { RoleGroupId = r.GetInt64(0), Scope = scope, RoleCode = r.GetString(1), RoleNameTh = r.GetString(2), Description = r.IsDBNull(3) ? null : r.GetString(3), IsActive = r.GetBoolean(4) };
    private static string? Null(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static void Add(SqlCommand c, string name, SqlDbType type, object? value, int size = 0) { var p = size > 0 ? c.Parameters.Add(name, type, size) : c.Parameters.Add(name, type); p.Value = value ?? DBNull.Value; }
}
