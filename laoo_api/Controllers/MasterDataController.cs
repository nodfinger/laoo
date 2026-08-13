using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/support/master-data")]
[Authorize]
public sealed class MasterDataController : ControllerBase
{
    private const string ScreenCode = "MASTER_DATA";
    private readonly IConfiguration _configuration;

    public MasterDataController(IConfiguration configuration) => _configuration = configuration;

    [HttpGet("groups")]
    public async Task<ActionResult<List<MasterGroupResponse>>> Groups(CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        if (!await HasPermissionAsync(connection, "VIEW", cancellationToken)) return Forbid();
        const string sql = "SELECT Code, Name FROM dbo.TDSTMasterGroup ORDER BY Name, Code;";
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<MasterGroupResponse>();
        while (await reader.ReadAsync(cancellationToken))
            result.Add(new(reader.GetString(0), reader.GetString(1)));
        return Ok(result);
    }

    [HttpGet]
    public async Task<ActionResult<List<MasterDataResponse>>> List([FromQuery] string groupCode, [FromQuery] string? search, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(groupCode)) return BadRequest(new { message = "กรุณาระบุกลุ่มข้อมูล" });
        await using var connection = await OpenConnectionAsync(cancellationToken);
        if (!await HasPermissionAsync(connection, "VIEW", cancellationToken)) return Forbid();
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
        while (await reader.ReadAsync(cancellationToken)) result.Add(new(reader.GetString(0), reader.GetString(1), reader.GetInt32(2), reader.IsDBNull(3) ? null : reader.GetString(3)));
        return Ok(result);
    }

    [HttpPost("{groupCode}")]
    public Task<ActionResult<MasterDataResponse>> Create(string groupCode, MasterDataRequest request, CancellationToken cancellationToken) => Save(groupCode, null, request, cancellationToken);

    [HttpPut("{groupCode}/{code}")]
    public Task<ActionResult<MasterDataResponse>> Update(string groupCode, string code, MasterDataRequest request, CancellationToken cancellationToken) => Save(groupCode, code, request, cancellationToken);

    [HttpDelete("{groupCode}/{code}")]
    public async Task<IActionResult> Delete(string groupCode, string code, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        if (!await HasPermissionAsync(connection, "DELETE", cancellationToken)) return Forbid();
        var scope = ResolveOwner();
        const string sql = "DELETE FROM dbo.TDSTMaster WHERE MasterGroupCode=@GroupCode AND MasterCode=@Code AND OwnerType=@OwnerType AND ISNULL(OwnerPartnerID,0)=ISNULL(@PartnerID,0) AND ISNULL(OwnerCompanyID,0)=ISNULL(@CompanyID,0);";
        await using var command = new SqlCommand(sql, connection);
        AddScope(command, scope);
        command.Parameters.Add("@GroupCode", SqlDbType.NVarChar, 10).Value = groupCode.Trim();
        command.Parameters.Add("@Code", SqlDbType.NVarChar, 10).Value = code.Trim();
        if (await command.ExecuteNonQueryAsync(cancellationToken) == 0) return NotFound();
        return NoContent();
    }

    private async Task<ActionResult<MasterDataResponse>> Save(string groupCode, string? existingCode, MasterDataRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name)) return BadRequest(new { message = "กรุณาระบุชื่อ" });
        await using var connection = await OpenConnectionAsync(cancellationToken);
        var action = existingCode is null ? "CREATE" : "EDIT";
        if (!await HasPermissionAsync(connection, action, cancellationToken)) return Forbid();
        var scope = ResolveOwner();
        var code = existingCode?.Trim();
        if (code is null)
        {
            const string nextSql = "SELECT RIGHT(N'00000' + CAST(ISNULL(MAX(TRY_CONVERT(int, MasterCode)),0)+1 AS nvarchar(10)),5) FROM dbo.TDSTMaster WHERE MasterGroupCode=@GroupCode AND OwnerType=@OwnerType AND ISNULL(OwnerPartnerID,0)=ISNULL(@PartnerID,0) AND ISNULL(OwnerCompanyID,0)=ISNULL(@CompanyID,0);";
            await using var next = new SqlCommand(nextSql, connection);
            AddScope(next, scope); next.Parameters.Add("@GroupCode", SqlDbType.NVarChar, 10).Value = groupCode.Trim();
            code = Convert.ToString(await next.ExecuteScalarAsync(cancellationToken)) ?? "00001";
        }
        const string duplicateSql = "SELECT COUNT(1) FROM dbo.TDSTMaster WHERE MasterGroupCode=@GroupCode AND LOWER(REPLACE(Name, N' ', N''))=LOWER(REPLACE(@Name, N' ', N'')) AND MasterCode<>@Code AND OwnerType=@OwnerType AND ISNULL(OwnerPartnerID,0)=ISNULL(@PartnerID,0) AND ISNULL(OwnerCompanyID,0)=ISNULL(@CompanyID,0);";
        await using var duplicate = new SqlCommand(duplicateSql, connection);
        AddScope(duplicate, scope); duplicate.Parameters.Add("@GroupCode", SqlDbType.NVarChar, 10).Value = groupCode.Trim(); duplicate.Parameters.Add("@Name", SqlDbType.NVarChar, 250).Value = request.Name.Trim(); duplicate.Parameters.Add("@Code", SqlDbType.NVarChar, 10).Value = code;
        if (Convert.ToInt32(await duplicate.ExecuteScalarAsync(cancellationToken)) > 0) return Conflict(new { message = "ชื่อซ้ำในกลุ่มข้อมูลนี้" });
        const string sql = "IF EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=@GroupCode AND MasterCode=@Code AND OwnerType=@OwnerType AND ISNULL(OwnerPartnerID,0)=ISNULL(@PartnerID,0) AND ISNULL(OwnerCompanyID,0)=ISNULL(@CompanyID,0)) UPDATE dbo.TDSTMaster SET Name=@Name, Seq=@Seq, ShortCode=@ShortCode, UpdateDate=SYSUTCDATETIME() WHERE MasterGroupCode=@GroupCode AND MasterCode=@Code AND OwnerType=@OwnerType AND ISNULL(OwnerPartnerID,0)=ISNULL(@PartnerID,0) AND ISNULL(OwnerCompanyID,0)=ISNULL(@CompanyID,0); ELSE INSERT dbo.TDSTMaster(MasterGroupCode,MasterCode,Name,Seq,OrderBy,ShortCode,OwnerType,OwnerPartnerID,OwnerCompanyID) VALUES(@GroupCode,@Code,@Name,@Seq,N'Seq',@ShortCode,@OwnerType,@PartnerID,@CompanyID);";
        await using var command = new SqlCommand(sql, connection); AddScope(command, scope);
        command.Parameters.Add("@GroupCode", SqlDbType.NVarChar, 10).Value = groupCode.Trim(); command.Parameters.Add("@Code", SqlDbType.NVarChar, 10).Value = code; command.Parameters.Add("@Name", SqlDbType.NVarChar, 250).Value = request.Name.Trim(); command.Parameters.Add("@Seq", SqlDbType.Int).Value = request.Seq; command.Parameters.Add("@ShortCode", SqlDbType.NVarChar, 50).Value = string.IsNullOrWhiteSpace(request.ShortCode) ? DBNull.Value : request.ShortCode.Trim();
        await command.ExecuteNonQueryAsync(cancellationToken);
        return Ok(new MasterDataResponse(code, request.Name.Trim(), request.Seq, string.IsNullOrWhiteSpace(request.ShortCode) ? null : request.ShortCode.Trim()));
    }

    private (string Type, long? Partner, long? Company) ResolveOwner() =>
        long.TryParse(User.FindFirstValue("company_id"), out var company) ? ("C", null, company) :
        long.TryParse(User.FindFirstValue("partner_id"), out var partner) ? ("P", partner, null) : ("L", null, null);

    private static void AddScope(SqlCommand command, (string Type, long? Partner, long? Company) scope)
    {
        command.Parameters.Add("@OwnerType", SqlDbType.NVarChar, 1).Value = scope.Type;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = scope.Partner ?? (object)DBNull.Value;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = scope.Company ?? (object)DBNull.Value;
    }

    private async Task<bool> HasPermissionAsync(SqlConnection connection, string action, CancellationToken cancellationToken)
    {
        if (string.Equals(User.FindFirstValue("user_type"), "PARTNER_USER", StringComparison.OrdinalIgnoreCase))
        {
            var partnerProject = User.FindFirstValue("project_id");
            var partnerClaim = User.FindFirstValue("partner_id");
            if (!long.TryParse(partnerProject, out var partnerProjectId) ||
                !long.TryParse(partnerClaim, out var partnerId)) return false;
            const string partnerSql = "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADPartnerUser U WHERE U.PartnerID=@PartnerID AND U.NormalizedUsername=@Username AND U.IsPartnerAdmin=1 AND U.IsActive=1) OR EXISTS (SELECT 1 FROM dbo.TDADPartnerUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID INNER JOIN dbo.TDADPartnerUser U ON U.PartnerUserID=UP.PartnerUserID WHERE U.PartnerID=@PartnerID AND U.NormalizedUsername=@Username AND U.IsActive=1 AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@ScreenCode AND P.ActionCode=@Action) THEN 1 ELSE 0 END";
            await using var partnerCommand = new SqlCommand(partnerSql, connection);
            partnerCommand.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId;
            partnerCommand.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = (User.Identity?.Name ?? User.FindFirstValue("username") ?? string.Empty).ToUpperInvariant();
            partnerCommand.Parameters.AddWithValue("@ProjectID", partnerProjectId);
            partnerCommand.Parameters.AddWithValue("@ScreenCode", ScreenCode);
            partnerCommand.Parameters.AddWithValue("@Action", action);
            return Convert.ToBoolean(await partnerCommand.ExecuteScalarAsync(cancellationToken));
        }
        var user = User.FindFirstValue("laoo_user_id") ?? User.FindFirstValue("user_id");
        var project = User.FindFirstValue("project_id");
        if (!long.TryParse(user, out var userId) || !long.TryParse(project, out var projectId)) return false;
        var table = User.FindFirstValue("laoo_user_id") is not null ? "TDADLaooUserPermission" : "TDADUserPermission";
        var key = User.FindFirstValue("laoo_user_id") is not null ? "LaooUserID" : "UserID";
        var sql = User.FindFirstValue("laoo_user_id") is not null
            ? $"SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.{table} UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.{key}=@UserID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@ScreenCode AND P.ActionCode=@Action) THEN 1 ELSE 0 END"
            : $"SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@UserID AND U.IsActive=1 AND U.IsCompanyAdmin=1) OR EXISTS (SELECT 1 FROM dbo.{table} UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.{key}=@UserID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@ScreenCode AND P.ActionCode=@Action) THEN 1 ELSE 0 END";
        await using var command = new SqlCommand(sql, connection); command.Parameters.AddWithValue("@UserID", userId); command.Parameters.AddWithValue("@ProjectID", projectId); command.Parameters.AddWithValue("@ScreenCode", ScreenCode); command.Parameters.AddWithValue("@Action", action);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(cancellationToken));
    }

    private async Task<SqlConnection> OpenConnectionAsync(CancellationToken cancellationToken)
    {
        var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken); return connection;
    }
}
