using System.Data;
using System.Globalization;
using System.Security.Claims;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/support/master-data")]
[Authorize]
public sealed class MasterDataController : ControllerBase
{
    private const string ScreenCode = "05002";
    private const string LegalDocumentTypesScreenCode = "70003";
    private const string LegalDocumentMasterGroupCode = "017";
    private const string LegacyScreenCode = "MASTER_DATA";
    private readonly IConfiguration _configuration;

    public MasterDataController(IConfiguration configuration) => _configuration = configuration;

    [HttpGet("groups")]
    public async Task<ActionResult<List<MasterGroupResponse>>> Groups(CancellationToken cancellationToken, [FromQuery] string? lookup = null, [FromQuery] string menuCode = ScreenCode)
    {
        if (!TryResolveScreenCode(menuCode, out var screenCode)) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        var employeePosition = lookup == "employee-position";
        var employeeVehicle = lookup == "employee-vehicle";
        if (lookup is not null && !employeePosition && !employeeVehicle) return Forbid();
        if (screenCode == LegalDocumentTypesScreenCode && lookup is not null) return Forbid();
        if (!await HasPermissionAsync(connection, "VIEW", cancellationToken, screenCode) && !((employeePosition || employeeVehicle) && await CanReadEmployeePosition(connection, cancellationToken))) return Forbid();
        var sql = screenCode == LegalDocumentTypesScreenCode ? "SELECT Code, Name FROM dbo.TDSTMasterGroup WHERE Code=N'017' ORDER BY Name, Code;" : employeePosition ? "SELECT Code, Name FROM dbo.TDSTMasterGroup WHERE Code=N'008' ORDER BY Name, Code;" : employeeVehicle ? "SELECT Code, Name FROM dbo.TDSTMasterGroup WHERE Code IN(N'009',N'010') ORDER BY Name, Code;" : "SELECT Code, Name FROM dbo.TDSTMasterGroup ORDER BY Name, Code;";
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<MasterGroupResponse>();
        while (await reader.ReadAsync(cancellationToken))
            result.Add(new(TextValue(reader, 0) ?? string.Empty, TextValue(reader, 1) ?? string.Empty));
        return Ok(result);
    }

    [HttpGet("actions")]
    public async Task<ActionResult<object>> Actions(CancellationToken cancellationToken, [FromQuery] string menuCode = ScreenCode)
    {
        if (!TryResolveScreenCode(menuCode, out var screenCode)) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        return Ok(new
        {
            view = await HasPermissionAsync(connection, "VIEW", cancellationToken, screenCode),
            create = await HasPermissionAsync(connection, "CREATE", cancellationToken, screenCode),
            edit = await HasPermissionAsync(connection, "EDIT", cancellationToken, screenCode),
            delete = await HasPermissionAsync(connection, "DELETE", cancellationToken, screenCode),
        });
    }

    [HttpGet]
    public async Task<ActionResult<List<MasterDataResponse>>> List([FromQuery] string groupCode, [FromQuery] string? search, CancellationToken cancellationToken, [FromQuery] string? lookup = null, [FromQuery] string menuCode = ScreenCode)
    {
        if (string.IsNullOrWhiteSpace(groupCode)) return BadRequest(new { message = "กรุณาระบุกลุ่มข้อมูล" });
        if (!TryResolveScreenCode(menuCode, out var screenCode)) return Forbid();
        if (screenCode == LegalDocumentTypesScreenCode && groupCode.Trim() != LegalDocumentMasterGroupCode) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        var employeePosition = lookup == "employee-position" && groupCode.Trim() == "008";
        var employeeVehicle = lookup == "employee-vehicle" && groupCode.Trim() is "009" or "010";
        if (lookup is not null && !employeePosition && !employeeVehicle) return Forbid();
        if (!await HasPermissionAsync(connection, "VIEW", cancellationToken, screenCode) && !((employeePosition || employeeVehicle) && await CanReadEmployeePosition(connection, cancellationToken))) return Forbid();
        var scope = ResolveOwner();
        const string sql = @"
SELECT MasterCode, Name, ISNULL(Seq, 0), NULLIF(ShortCode, N'')
FROM dbo.TDSTMaster
WHERE MasterGroupCode = @GroupCode AND OwnerType = @OwnerType
  AND ISNULL(OwnerPartnerID, 0) = ISNULL(@PartnerID, 0)
  AND ISNULL(OwnerCompanyID, 0) = ISNULL(@CompanyID, 0)
  AND (@Search IS NULL OR MasterCode LIKE N'%' + @Search + N'%' OR Name LIKE N'%' + @Search + N'%' OR ISNULL(ShortCode, N'') LIKE N'%' + @Search + N'%')
ORDER BY Seq, Name;";
        await using var command = new SqlCommand(sql, connection);
        AddScope(command, scope);
        command.Parameters.Add("@GroupCode", SqlDbType.NVarChar, 10).Value = groupCode.Trim();
        command.Parameters.Add("@Search", SqlDbType.NVarChar, 250).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<MasterDataResponse>();
        while (await reader.ReadAsync(cancellationToken)) result.Add(new(TextValue(reader, 0) ?? string.Empty, TextValue(reader, 1) ?? string.Empty, reader.GetInt32(2), TextValue(reader, 3)));
        return Ok(result);
    }

    private Task<bool> CanReadEmployeePosition(SqlConnection connection, CancellationToken token) =>
        ResolveOwner().Type == "C"
            ? CompanyProjectPermission.IsAllowedAsync(connection, User, "10001", "VIEW", token)
            : Task.FromResult(false);

    [HttpPost("{groupCode}")]
    public Task<ActionResult<MasterDataResponse>> Create(string groupCode, MasterDataRequest request, CancellationToken cancellationToken, [FromQuery] string menuCode = ScreenCode) => Save(groupCode, null, request, cancellationToken, menuCode);

    [HttpPut("{groupCode}/{code}")]
    public Task<ActionResult<MasterDataResponse>> Update(string groupCode, string code, MasterDataRequest request, CancellationToken cancellationToken, [FromQuery] string menuCode = ScreenCode) => Save(groupCode, code, request, cancellationToken, menuCode);

    [HttpDelete("{groupCode}/{code}")]
    public async Task<IActionResult> Delete(string groupCode, string code, CancellationToken cancellationToken, [FromQuery] string menuCode = ScreenCode)
    {
        if (!TryResolveScreenCode(menuCode, out var screenCode)) return Forbid();
        if (screenCode == LegalDocumentTypesScreenCode && groupCode.Trim() != LegalDocumentMasterGroupCode) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        if (!await HasPermissionAsync(connection, "DELETE", cancellationToken, screenCode)) return Forbid();
        var scope = ResolveOwner();
        const string sql = "DELETE FROM dbo.TDSTMaster WHERE MasterGroupCode=@GroupCode AND MasterCode=@Code AND OwnerType=@OwnerType AND ISNULL(OwnerPartnerID,0)=ISNULL(@PartnerID,0) AND ISNULL(OwnerCompanyID,0)=ISNULL(@CompanyID,0);";
        await using var command = new SqlCommand(sql, connection);
        AddScope(command, scope);
        command.Parameters.Add("@GroupCode", SqlDbType.NVarChar, 10).Value = groupCode.Trim();
        command.Parameters.Add("@Code", SqlDbType.NVarChar, 10).Value = code.Trim();
        if (await command.ExecuteNonQueryAsync(cancellationToken) == 0) return NotFound();
        return NoContent();
    }

    private async Task<ActionResult<MasterDataResponse>> Save(string groupCode, string? existingCode, MasterDataRequest request, CancellationToken cancellationToken, string menuCode)
    {
        if (string.IsNullOrWhiteSpace(request.Name)) return BadRequest(new { message = "กรุณาระบุชื่อ" });
        if (!TryResolveScreenCode(menuCode, out var screenCode)) return Forbid();
        if (screenCode == LegalDocumentTypesScreenCode && groupCode.Trim() != LegalDocumentMasterGroupCode) return Forbid();
        await using var connection = await OpenConnectionAsync(cancellationToken);
        var action = existingCode is null ? "CREATE" : "EDIT";
        if (!await HasPermissionAsync(connection, action, cancellationToken, screenCode)) return Forbid();
        var scope = ResolveOwner();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        await using var lockCommand = new SqlCommand("DECLARE @result int; EXEC @result = sys.sp_getapplock @Resource=@resource, @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000; SELECT @result;", connection, transaction);
        lockCommand.Parameters.Add("@resource", SqlDbType.NVarChar, 255).Value = $"master-data:{scope.Type}:{scope.Partner}:{scope.Company}:{groupCode.Trim()}";
        if (Convert.ToInt32(await lockCommand.ExecuteScalarAsync(cancellationToken)) < 0)
            return Conflict(new { message = "ข้อมูลกำลังถูกแก้ไข กรุณาลองใหม่อีกครั้ง" });
        var code = existingCode?.Trim();
        if (code is null)
        {
            const string nextSql = "SELECT RIGHT(N'00000' + CAST(ISNULL(MAX(TRY_CONVERT(int, MasterCode)),0)+1 AS nvarchar(10)),5) FROM dbo.TDSTMaster WHERE MasterGroupCode=@GroupCode AND OwnerType=@OwnerType AND ISNULL(OwnerPartnerID,0)=ISNULL(@PartnerID,0) AND ISNULL(OwnerCompanyID,0)=ISNULL(@CompanyID,0);";
            await using var next = new SqlCommand(nextSql, connection, transaction);
            AddScope(next, scope); next.Parameters.Add("@GroupCode", SqlDbType.NVarChar, 10).Value = groupCode.Trim();
            code = Convert.ToString(await next.ExecuteScalarAsync(cancellationToken)) ?? "00001";
        }
        const string duplicateSql = "SELECT COUNT(1) FROM dbo.TDSTMaster WHERE MasterGroupCode=@GroupCode AND LOWER(REPLACE(Name, N' ', N''))=LOWER(REPLACE(@Name, N' ', N'')) AND MasterCode<>@Code AND OwnerType=@OwnerType AND ISNULL(OwnerPartnerID,0)=ISNULL(@PartnerID,0) AND ISNULL(OwnerCompanyID,0)=ISNULL(@CompanyID,0);";
        await using var duplicate = new SqlCommand(duplicateSql, connection, transaction);
        AddScope(duplicate, scope); duplicate.Parameters.Add("@GroupCode", SqlDbType.NVarChar, 10).Value = groupCode.Trim(); duplicate.Parameters.Add("@Name", SqlDbType.NVarChar, 250).Value = request.Name.Trim(); duplicate.Parameters.Add("@Code", SqlDbType.NVarChar, 10).Value = code;
        if (Convert.ToInt32(await duplicate.ExecuteScalarAsync(cancellationToken)) > 0) return Conflict(new { message = "ชื่อซ้ำในกลุ่มข้อมูลนี้" });
        var sql = existingCode is null
            ? "INSERT dbo.TDSTMaster(MasterGroupCode,MasterCode,Name,Seq,OrderBy,ShortCode,OwnerType,OwnerPartnerID,OwnerCompanyID) VALUES(@GroupCode,@Code,@Name,@Seq,N'Seq',@ShortCode,@OwnerType,@PartnerID,@CompanyID);"
            : "UPDATE dbo.TDSTMaster SET Name=@Name, Seq=@Seq, ShortCode=@ShortCode, UpdateDate=SYSUTCDATETIME() WHERE MasterGroupCode=@GroupCode AND MasterCode=@Code AND OwnerType=@OwnerType AND ISNULL(OwnerPartnerID,0)=ISNULL(@PartnerID,0) AND ISNULL(OwnerCompanyID,0)=ISNULL(@CompanyID,0);";
        await using var command = new SqlCommand(sql, connection, transaction); AddScope(command, scope);
        command.Parameters.Add("@GroupCode", SqlDbType.NVarChar, 10).Value = groupCode.Trim(); command.Parameters.Add("@Code", SqlDbType.NVarChar, 10).Value = code; command.Parameters.Add("@Name", SqlDbType.NVarChar, 250).Value = request.Name.Trim(); command.Parameters.Add("@Seq", SqlDbType.Int).Value = request.Seq; command.Parameters.Add("@ShortCode", SqlDbType.NVarChar, 50).Value = string.IsNullOrWhiteSpace(request.ShortCode) ? DBNull.Value : request.ShortCode.Trim().ToUpperInvariant();
        if (await command.ExecuteNonQueryAsync(cancellationToken) == 0) return NotFound(new { message = "ไม่พบข้อมูลที่ต้องการแก้ไข" });
        await transaction.CommitAsync(cancellationToken);
        return Ok(new MasterDataResponse(code, request.Name.Trim(), request.Seq, string.IsNullOrWhiteSpace(request.ShortCode) ? null : request.ShortCode.Trim().ToUpperInvariant()));
    }

    private (string Type, long? Partner, long? Company) ResolveOwner() =>
        long.TryParse(User.FindFirstValue("company_id"), out var company) ? ("C", null, company) :
        long.TryParse(User.FindFirstValue("partner_id"), out var partner) ? ("P", partner, null) : ("L", null, null);

    private static string? TextValue(SqlDataReader reader, int ordinal) =>
        reader.IsDBNull(ordinal)
            ? null
            : Convert.ToString(reader.GetValue(ordinal), CultureInfo.InvariantCulture);

    private static void AddScope(SqlCommand command, (string Type, long? Partner, long? Company) scope)
    {
        command.Parameters.Add("@OwnerType", SqlDbType.NVarChar, 1).Value = scope.Type;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = scope.Partner ?? (object)DBNull.Value;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = scope.Company ?? (object)DBNull.Value;
    }

    private static bool TryResolveScreenCode(string? menuCode, out string screenCode)
    {
        screenCode = menuCode?.Trim() ?? string.Empty;
        return screenCode is ScreenCode or LegalDocumentTypesScreenCode;
    }

    private async Task<bool> HasPermissionAsync(SqlConnection connection, string action, CancellationToken cancellationToken, string screenCode = ScreenCode)
    {
        var legacyScreenCode = screenCode == ScreenCode ? LegacyScreenCode : screenCode;
        if (string.Equals(User.FindFirstValue("user_type"), "PARTNER_USER", StringComparison.OrdinalIgnoreCase))
        {
            var partnerProject = User.FindFirstValue("project_id");
            var partnerClaim = User.FindFirstValue("partner_id");
            if (!long.TryParse(partnerProject, out var partnerProjectId) ||
                !long.TryParse(partnerClaim, out var partnerId)) return false;
            const string partnerSql = "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADPartnerUser U WHERE U.PartnerID=@PartnerID AND U.NormalizedUsername=@Username AND U.IsPartnerAdmin=1 AND U.IsActive=1) OR EXISTS (SELECT 1 FROM dbo.TDADPartnerUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID INNER JOIN dbo.TDADPartnerUser U ON U.PartnerUserID=UP.PartnerUserID WHERE U.PartnerID=@PartnerID AND U.NormalizedUsername=@Username AND U.IsActive=1 AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode IN (@ScreenCode,@LegacyScreenCode) AND P.ActionCode=@Action) OR EXISTS (SELECT 1 FROM dbo.TDADPartnerUser U INNER JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.PartnerUserID=U.PartnerUserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=PUE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='P' AND RG.PartnerID=U.PartnerID AND RG.ProjectID=@ProjectID INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@ProjectID AND RP.MenuCode IN (@ScreenCode,@LegacyScreenCode) AND RP.ActionCode=@Action AND RP.IsAllowed=1 WHERE U.PartnerID=@PartnerID AND U.NormalizedUsername=@Username AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END";
            await using var partnerCommand = new SqlCommand(partnerSql, connection);
            partnerCommand.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId;
            partnerCommand.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = (User.Identity?.Name ?? User.FindFirstValue("username") ?? string.Empty).ToUpperInvariant();
            partnerCommand.Parameters.AddWithValue("@ProjectID", partnerProjectId);
            partnerCommand.Parameters.AddWithValue("@ScreenCode", screenCode);
            partnerCommand.Parameters.AddWithValue("@LegacyScreenCode", legacyScreenCode);
            partnerCommand.Parameters.AddWithValue("@Action", action);
            return Convert.ToBoolean(await partnerCommand.ExecuteScalarAsync(cancellationToken));
        }
        var user = User.FindFirstValue("laoo_user_id") ?? User.FindFirstValue("user_id");
        var project = User.FindFirstValue("project_id");
        if (!long.TryParse(user, out var userId) || !long.TryParse(project, out var projectId)) return false;
        var table = User.FindFirstValue("laoo_user_id") is not null ? "TDADLaooUserPermission" : "TDADUserPermission";
        var key = User.FindFirstValue("laoo_user_id") is not null ? "LaooUserID" : "UserID";
        var sql = User.FindFirstValue("laoo_user_id") is not null
            ? $"SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.{table} UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.{key}=@UserID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode IN (@ScreenCode,@LegacyScreenCode) AND P.ActionCode=@Action) THEN 1 ELSE 0 END"
            : $"SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@UserID AND U.IsActive=1 AND U.IsCompanyAdmin=1) OR EXISTS (SELECT 1 FROM dbo.{table} UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.{key}=@UserID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode IN (@ScreenCode,@LegacyScreenCode) AND P.ActionCode=@Action) OR EXISTS (SELECT 1 FROM dbo.TDADUser U INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@ProjectID INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@ProjectID AND RP.MenuCode IN (@ScreenCode,@LegacyScreenCode) AND RP.ActionCode=@Action AND RP.IsAllowed=1 WHERE U.UserID=@UserID AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END";
        await using var command = new SqlCommand(sql, connection); command.Parameters.AddWithValue("@UserID", userId); command.Parameters.AddWithValue("@ProjectID", projectId); command.Parameters.AddWithValue("@ScreenCode", screenCode); command.Parameters.AddWithValue("@LegacyScreenCode", legacyScreenCode); command.Parameters.AddWithValue("@Action", action);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(cancellationToken));
    }

    private async Task<SqlConnection> OpenConnectionAsync(CancellationToken cancellationToken)
    {
        var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken); return connection;
    }
}
