using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/menu-permissions")]
[Authorize]
public sealed class MenuPermissionController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<MenuPermissionMatrixResponse>>> List([FromQuery] string scope, [FromQuery] long roleGroupId, CancellationToken token)
    {
        if (!TryScope(scope, out var prefix, out var screen)) return BadRequest(new { message = "ขอบเขตไม่ถูกต้อง" });
        if (!TryGetRoleGroupScope(scope, out var targetScope)) return Forbid();
        await using var connection = await OpenAsync(token);
        if (!await HasPermissionAsync(connection, screen, "VIEW", token)) return Forbid();
        if (!await RoleGroupBelongsToScopeAsync(connection, null, roleGroupId, targetScope, token)) return NotFound();
        const string sql = """
            SELECT M.MenuCode,M.MenuName,M.MenuGroupCode,G.MenuGroupName,M.ScreenType,
              CAST(CASE WHEN MAX(CASE WHEN RP.ActionCode='VIEW' AND RP.IsAllowed=1 THEN 1 ELSE 0 END)=1 THEN 1 ELSE 0 END AS bit),
              CAST(CASE WHEN MAX(CASE WHEN RP.ActionCode='CREATE' AND RP.IsAllowed=1 THEN 1 ELSE 0 END)=1 THEN 1 ELSE 0 END AS bit),
              CAST(CASE WHEN MAX(CASE WHEN RP.ActionCode='EDIT' AND RP.IsAllowed=1 THEN 1 ELSE 0 END)=1 THEN 1 ELSE 0 END AS bit),
              CAST(CASE WHEN MAX(CASE WHEN RP.ActionCode='DELETE' AND RP.IsAllowed=1 THEN 1 ELSE 0 END)=1 THEN 1 ELSE 0 END AS bit)
            FROM dbo.TDADMainMenu M
            INNER JOIN dbo.TDADMenuGroup G ON G.MenuGroupCode=M.MenuGroupCode AND G.IsActive=1
            LEFT JOIN dbo.TDADRoleGroupPermission RP ON RP.MenuCode=M.MenuCode AND RP.RoleGroupID=@RoleGroupID AND RP.ProjectID=@ProjectID
            WHERE M.IsActive=1 AND M.IsVisible=1
              AND UPPER(LTRIM(RTRIM(G.AudienceType))) IN (N'A',@AudienceType)
            GROUP BY M.MenuCode,M.MenuName,M.MenuGroupCode,G.MenuGroupName,G.SortOrder,M.ScreenType,M.SortOrder ORDER BY G.SortOrder,M.SortOrder,M.MenuCode;
            """;
        await using var command = new SqlCommand(sql, connection);
        Add(command,"@RoleGroupID",SqlDbType.BigInt,roleGroupId); Add(command,"@ProjectID",SqlDbType.BigInt,targetScope.ProjectId); Add(command,"@AudienceType",SqlDbType.Char,prefix switch { "10" => "C", "12" => "L", _ => "P" });
        await using var reader = await command.ExecuteReaderAsync(token);
        var result = new List<MenuPermissionMatrixResponse>();
        while (await reader.ReadAsync(token)) result.Add(new MenuPermissionMatrixResponse { MenuCode=reader.GetString(0), MenuName=reader.GetString(1), MenuGroupCode=reader.GetString(2).Trim(), MenuGroupName=reader.GetString(3), ScreenType=reader.GetInt32(4), CanView=reader.GetBoolean(5), CanCreate=reader.GetBoolean(6), CanEdit=reader.GetBoolean(7), CanDelete=reader.GetBoolean(8) });
        return Ok(result);
    }

    [HttpGet("actions")]
    public async Task<ActionResult<object>> Actions([FromQuery] string scope, CancellationToken token)
    {
        if (!TryScope(scope, out _, out var screen)) return BadRequest(new { message = "ขอบเขตไม่ถูกต้อง" });
        if (!TryGetRoleGroupScope(scope, out _)) return Forbid();
        await using var connection = await OpenAsync(token);
        return Ok(new
        {
            view = await HasPermissionAsync(connection, screen, "VIEW", token),
            edit = await HasPermissionAsync(connection, screen, "EDIT", token),
            delete = await HasPermissionAsync(connection, screen, "DELETE", token)
        });
    }

    [HttpPut]
    public async Task<IActionResult> Save([FromQuery] string scope, [FromQuery] long roleGroupId, [FromBody] List<MenuPermissionSaveRequest> requests, CancellationToken token)
    {
        if (!TryScope(scope, out var prefix, out var screen)) return BadRequest(new { message = "ขอบเขตไม่ถูกต้อง" });
        if (!TryGetRoleGroupScope(scope, out var targetScope)) return Forbid();
        await using var connection = await OpenAsync(token); if (!await HasPermissionAsync(connection, screen, "EDIT", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(token);
        try
        {
            if (!await RoleGroupBelongsToScopeAsync(connection, transaction, roleGroupId, targetScope, token))
            {
                await transaction.RollbackAsync(token);
                return NotFound();
            }
            var audienceType = prefix switch { "10" => 'C', "12" => 'L', _ => 'P' };
            foreach (var item in requests) await SaveRowAsync(connection, transaction, roleGroupId, targetScope, audienceType, item, token);
            await transaction.CommitAsync(token);
            return NoContent();
        }
        catch (SqlException exception) when (exception.Number == 50010)
        {
            await transaction.RollbackAsync(token);
            return BadRequest(new { message = "เมนูไม่อยู่ในขอบเขตที่กำหนด" });
        }
        catch { await transaction.RollbackAsync(token); throw; }
    }

    [HttpDelete]
    public async Task<IActionResult> Clear([FromQuery] string scope, [FromQuery] long roleGroupId, CancellationToken token)
    {
        if (!TryScope(scope, out _, out var screen)) return BadRequest(new { message = "ขอบเขตไม่ถูกต้อง" });
        if (!TryGetRoleGroupScope(scope, out var targetScope)) return Forbid();
        await using var connection = await OpenAsync(token);
        if (!await HasPermissionAsync(connection, screen, "DELETE", token)) return Forbid();
        const string sql = """
            DELETE RP FROM dbo.TDADRoleGroupPermission RP
            INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=RP.RoleGroupID
            WHERE RP.RoleGroupID=@RoleGroupID AND RP.ProjectID=@ProjectID
              AND RG.ProjectID=@ProjectID AND RG.ScopeType=@ScopeType
              AND ((@ScopeType='P' AND RG.PartnerID=@PartnerID AND RG.CompanyID IS NULL)
                OR (@ScopeType='C' AND RG.CompanyID=@CompanyID AND RG.PartnerID IS NULL)
                OR (@ScopeType='L' AND RG.PartnerID IS NULL AND RG.CompanyID IS NULL));
            """;
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(token);
        try
        {
            if (!await RoleGroupBelongsToScopeAsync(connection, transaction, roleGroupId, targetScope, token))
            {
                await transaction.RollbackAsync(token);
                return NotFound();
            }
            await using var command = new SqlCommand(sql, connection, transaction);
            Add(command,"@RoleGroupID",SqlDbType.BigInt,roleGroupId); BindScope(command, targetScope.ProjectId, targetScope.ScopeType, targetScope.OwnerId);
            await command.ExecuteNonQueryAsync(token);
            await transaction.CommitAsync(token);
            return NoContent();
        }
        catch { await transaction.RollbackAsync(token); throw; }
    }

    private static async Task SaveRowAsync(SqlConnection connection, SqlTransaction transaction, long roleGroupId, RoleGroupScope targetScope, char audienceType, MenuPermissionSaveRequest request, CancellationToken token)
    {
        const string sql = """
            DECLARE @ScreenType int;
            SELECT @ScreenType=M.ScreenType
            FROM dbo.TDADMainMenu M
            INNER JOIN dbo.TDADMenuGroup G ON G.MenuGroupCode=M.MenuGroupCode AND G.IsActive=1
            WHERE M.MenuCode=@MenuCode AND M.IsActive=1
              AND UPPER(LTRIM(RTRIM(G.AudienceType))) IN (N'A',@AudienceType);
            IF @ScreenType IS NULL THROW 50010,'MENU_SCOPE_INVALID',1;
            DELETE RP FROM dbo.TDADRoleGroupPermission RP
            INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=RP.RoleGroupID
            WHERE RP.RoleGroupID=@RoleGroupID AND RP.ProjectID=@ProjectID AND RP.MenuCode=@MenuCode
              AND RG.ProjectID=@ProjectID AND RG.ScopeType=@ScopeType
              AND ((@ScopeType='P' AND RG.PartnerID=@PartnerID AND RG.CompanyID IS NULL)
                OR (@ScopeType='C' AND RG.CompanyID=@CompanyID AND RG.PartnerID IS NULL)
                OR (@ScopeType='L' AND RG.PartnerID IS NULL AND RG.CompanyID IS NULL));
            INSERT dbo.TDADRoleGroupPermission(RoleGroupID,ProjectID,MenuCode,ActionCode,IsAllowed,CreatedBy)
            SELECT @RoleGroupID,@ProjectID,@MenuCode,A.ActionCode,1,N'api'
            FROM (VALUES (N'VIEW',@CanView),(N'CREATE',@CanCreate),(N'EDIT',@CanEdit),(N'DELETE',@CanDelete)) A(ActionCode,IsRequested)
            WHERE A.IsRequested=1
              AND (@CanView=1 OR A.ActionCode=N'VIEW')
              AND ((@ScreenType=1 AND A.ActionCode IN (N'VIEW',N'CREATE',N'EDIT',N'DELETE')) OR (@ScreenType=2 AND A.ActionCode IN (N'VIEW',N'EDIT')) OR (@ScreenType=3 AND A.ActionCode=N'VIEW'));
            """;
        await using var command = new SqlCommand(sql,connection,transaction);
        Add(command,"@RoleGroupID",SqlDbType.BigInt,roleGroupId); BindScope(command,targetScope.ProjectId,targetScope.ScopeType,targetScope.OwnerId); Add(command,"@AudienceType",SqlDbType.Char,audienceType); Add(command,"@MenuCode",SqlDbType.NVarChar,request.MenuCode,20); Add(command,"@CanView",SqlDbType.Bit,request.CanView); Add(command,"@CanCreate",SqlDbType.Bit,request.CanCreate); Add(command,"@CanEdit",SqlDbType.Bit,request.CanEdit); Add(command,"@CanDelete",SqlDbType.Bit,request.CanDelete); await command.ExecuteNonQueryAsync(token);
    }

    private static async Task<bool> RoleGroupBelongsToScopeAsync(SqlConnection connection, SqlTransaction? transaction, long roleGroupId, RoleGroupScope targetScope, CancellationToken token)
    {
        var lockHint = transaction is null ? string.Empty : "WITH (UPDLOCK,HOLDLOCK)";
        var sql = $"""
            SELECT CASE WHEN EXISTS
            (
                SELECT 1 FROM dbo.TDADRoleGroup {lockHint}
                WHERE RoleGroupID=@RoleGroupID AND ProjectID=@ProjectID AND ScopeType=@ScopeType
                  AND ((@ScopeType='P' AND PartnerID=@PartnerID AND CompanyID IS NULL)
                    OR (@ScopeType='C' AND CompanyID=@CompanyID AND PartnerID IS NULL)
                    OR (@ScopeType='L' AND PartnerID IS NULL AND CompanyID IS NULL))
            ) THEN 1 ELSE 0 END;
            """;
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command,"@RoleGroupID",SqlDbType.BigInt,roleGroupId); BindScope(command,targetScope.ProjectId,targetScope.ScopeType,targetScope.OwnerId);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private async Task<bool> HasPermissionAsync(SqlConnection connection,string screen,string action,CancellationToken token)
    {
        var type=User.FindFirstValue("user_type")??string.Empty; var support=type.Equals("LAOO_SUPPORT",StringComparison.OrdinalIgnoreCase); var partner=type.Equals("PARTNER_USER",StringComparison.OrdinalIgnoreCase); var userId=support?ClaimLong("laoo_user_id"):partner?PartnerUserId():ClaimLong("user_id"); var projectId=ClaimLong("project_id"); if(!userId.HasValue||!projectId.HasValue)return false;
        var table=support?"TDADLaooUserPermission":partner?"TDADPartnerUserPermission":"TDADUserPermission"; var column=support?"LaooUserID":partner?"PartnerUserID":"UserID"; var admin=partner?"OR EXISTS (SELECT 1 FROM dbo.TDADPartnerUser A WHERE A.PartnerUserID=@UserID AND A.IsPartnerAdmin=1 AND A.IsActive=1)":type.Equals("COMPANY_USER",StringComparison.OrdinalIgnoreCase)?"OR EXISTS (SELECT 1 FROM dbo.TDADUser A WHERE A.UserID=@UserID AND A.IsCompanyAdmin=1 AND A.IsActive=1)":"";
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
            """ : type.Equals("COMPANY_USER",StringComparison.OrdinalIgnoreCase) ? """
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
        var sql=$"SELECT CASE WHEN (EXISTS (SELECT 1 FROM dbo.{table} UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.{column}=@UserID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@ScreenCode AND P.ActionCode=@Action) {rolePermission} {admin}) THEN 1 ELSE 0 END";
        await using var command=new SqlCommand(sql,connection); Add(command,"@UserID",SqlDbType.BigInt,userId); Add(command,"@ProjectID",SqlDbType.BigInt,projectId); Add(command,"@ScreenCode",SqlDbType.NVarChar,screen); Add(command,"@Action",SqlDbType.NVarChar,action); return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }
    private long? ClaimLong(string name)=>long.TryParse(User.FindFirstValue(name),out var value)?value:null;
    private long? PartnerUserId(){var value=ClaimLong("user_id"); if(value.HasValue)return value; var subject=User.FindFirstValue(ClaimTypes.NameIdentifier)??User.FindFirstValue("sub")??string.Empty; return subject.StartsWith("partner:",StringComparison.OrdinalIgnoreCase)&&long.TryParse(subject[8..],out var id)?id:null;}
    private bool TryGetRoleGroupScope(string value,out RoleGroupScope targetScope)
    {
        targetScope=default;
        var projectId=ClaimLong("project_id");
        if(!projectId.HasValue)return false;
        var scope=value.Trim().ToLowerInvariant();
        var userType=User.FindFirstValue("user_type")??string.Empty;
        if(scope=="partner"&&userType.Equals("PARTNER_USER",StringComparison.OrdinalIgnoreCase)&&ClaimLong("partner_id") is long partnerId){targetScope=new RoleGroupScope(projectId.Value,'P',partnerId);return true;}
        if(scope=="customer"&&userType.Equals("COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&ClaimLong("company_id") is long companyId){targetScope=new RoleGroupScope(projectId.Value,'C',companyId);return true;}
        return false;
    }
    private static bool TryScope(string value,out string prefix,out string screen){var scope=value.Trim().ToLowerInvariant(); prefix=scope=="customer"?"10":scope=="partner"?"11":""; screen=prefix switch { "10" => "10004", "11" => "11004", _ => string.Empty }; return prefix.Length>0;}
    private async Task<SqlConnection> OpenAsync(CancellationToken token){var connection=new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await connection.OpenAsync(token); return connection;}
    private static void Add(SqlCommand command,string name,SqlDbType type,object? value,int size=0){var parameter=size>0?command.Parameters.Add(name,type,size):command.Parameters.Add(name,type); parameter.Value=value??DBNull.Value;}
    private static void BindScope(SqlCommand command,long project,char scope,long owner){ Add(command,"@ProjectID",SqlDbType.BigInt,project); Add(command,"@ScopeType",SqlDbType.Char,scope); Add(command,"@PartnerID",SqlDbType.BigInt,scope=='P'?owner:null); Add(command,"@CompanyID",SqlDbType.BigInt,scope=='C'?owner:null); }
    private readonly record struct RoleGroupScope(long ProjectId,char ScopeType,long OwnerId);
}
