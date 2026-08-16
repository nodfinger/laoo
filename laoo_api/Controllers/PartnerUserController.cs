using System.Data;
using System.Security.Claims;
using LaooApi.Models.Partner;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/support/partner-users")]
[Authorize]
public sealed class PartnerUserController(
    IConfiguration configuration,
    PasswordService passwordService) : ControllerBase
{
    private const string ScreenCode = "PARTNER";

    [HttpGet]
    public async Task<ActionResult<List<PartnerUserResponse>>> List(
        [FromQuery] long partnerId,
        CancellationToken cancellationToken)
    {
        if (!await IsLaooSupportAsync(cancellationToken)) return Forbid();
        await using var connection = await OpenAsync(cancellationToken);
        if (!await HasPermissionAsync(connection, "VIEW", cancellationToken)) return Forbid();

        const string sql = """
SELECT PartnerUserID, PartnerID, Username, DisplayName, Email, MobileNumber, IsPartnerAdmin, IsActive
FROM dbo.TDADPartnerUser
WHERE PartnerID=@PartnerID
ORDER BY Username;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<PartnerUserResponse>();
        while (await reader.ReadAsync(cancellationToken)) result.Add(Read(reader));
        return Ok(result);
    }

    [HttpPost]
    public async Task<ActionResult<PartnerUserResponse>> Create(
        [FromQuery] long partnerId,
        PartnerUserUpsertRequest request,
        CancellationToken cancellationToken)
    {
        if (!await IsLaooSupportAsync(cancellationToken)) return Forbid();
        if (string.IsNullOrWhiteSpace(request.Username) ||
            string.IsNullOrWhiteSpace(request.Password) ||
            string.IsNullOrWhiteSpace(request.DisplayName))
            return BadRequest(new { message = "กรุณาระบุ Username, Password และชื่อผู้ใช้งาน" });
        if (!PasswordService.MeetsPolicy(request.Username.Trim(), request.Password))
            return BadRequest(new { message = PasswordService.PolicyMessage });

        await using var connection = await OpenAsync(cancellationToken);
        if (!await HasPermissionAsync(connection, "CREATE", cancellationToken)) return Forbid();
        if (!await PartnerExistsAsync(connection, partnerId, cancellationToken)) return NotFound(new { message = "ไม่พบ Partner" });
        if (request.IsPartnerAdmin && await HasActiveAdminAsync(connection, partnerId, cancellationToken))
            return Conflict(new { message = "Partner นี้มี Partner Admin ที่ใช้งานอยู่แล้ว" });

        var username = request.Username.Trim();
        const string sql = """
INSERT dbo.TDADPartnerUser
(PartnerID,Username,NormalizedUsername,PasswordHash,DisplayName,Email,MobileNumber,IsPartnerAdmin,IsActive,FailedLoginCount,CreatedUtc,CreatedBy)
VALUES(@PartnerID,@Username,@NormalizedUsername,@PasswordHash,@DisplayName,@Email,@MobileNumber,@IsPartnerAdmin,@IsActive,0,SYSUTCDATETIME(),@CreatedBy);
SELECT CAST(SCOPE_IDENTITY() AS BIGINT);
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@PartnerID", SqlDbType.BigInt, partnerId);
        Add(command, "@Username", SqlDbType.NVarChar, username, 100);
        Add(command, "@NormalizedUsername", SqlDbType.NVarChar, username.ToUpperInvariant(), 100);
        Add(command, "@PasswordHash", SqlDbType.NVarChar, passwordService.HashPassword(username, request.Password), 500);
        Add(command, "@DisplayName", SqlDbType.NVarChar, request.DisplayName.Trim(), 200);
        Add(command, "@Email", SqlDbType.NVarChar, Null(request.Email), 320);
        Add(command, "@MobileNumber", SqlDbType.NVarChar, Null(request.MobileNumber), 50);
        Add(command, "@IsPartnerAdmin", SqlDbType.Bit, request.IsPartnerAdmin);
        Add(command, "@IsActive", SqlDbType.Bit, request.IsActive);
        Add(command, "@CreatedBy", SqlDbType.NVarChar, ActorName(), 100);
        try
        {
            var id = Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken));
            return Created($"/api/support/partner-users/{id}", new PartnerUserResponse { PartnerUserId=id, PartnerId=partnerId, Username=username, DisplayName=request.DisplayName.Trim(), Email=Null(request.Email), MobileNumber=Null(request.MobileNumber), IsPartnerAdmin=request.IsPartnerAdmin, IsActive=request.IsActive });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627)
        {
            return Conflict(new { message = "Username นี้ถูกใช้งานแล้ว" });
        }
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, PartnerUserUpsertRequest request, CancellationToken cancellationToken)
    {
        if (!await IsLaooSupportAsync(cancellationToken)) return Forbid();
        if (string.IsNullOrWhiteSpace(request.DisplayName) || string.IsNullOrWhiteSpace(request.Username)) return BadRequest(new { message = "กรุณาระบุ Username และชื่อผู้ใช้งาน" });
        if (!string.IsNullOrWhiteSpace(request.Password) &&
            !PasswordService.MeetsPolicy(request.Username.Trim(), request.Password))
            return BadRequest(new { message = PasswordService.PolicyMessage });
        await using var connection = await OpenAsync(cancellationToken);
        if (!await HasPermissionAsync(connection, "EDIT", cancellationToken)) return Forbid();
        var passwordSql = string.IsNullOrWhiteSpace(request.Password) ? "" : ", PasswordHash=@PasswordHash";
        const string sql = "UPDATE dbo.TDADPartnerUser SET Username=@Username,NormalizedUsername=@NormalizedUsername,DisplayName=@DisplayName,Email=@Email,MobileNumber=@MobileNumber,IsPartnerAdmin=@IsPartnerAdmin,IsActive=@IsActive,UpdatedUtc=SYSUTCDATETIME(),UpdatedBy=@UpdatedBy";
        var commandText = sql + passwordSql + " WHERE PartnerUserID=@ID;";
        await using var command = new SqlCommand(commandText, connection);
        Add(command,"@Username",SqlDbType.NVarChar,request.Username.Trim(),100); Add(command,"@NormalizedUsername",SqlDbType.NVarChar,request.Username.Trim().ToUpperInvariant(),100);
        Add(command,"@DisplayName",SqlDbType.NVarChar,request.DisplayName.Trim(),200); Add(command,"@Email",SqlDbType.NVarChar,Null(request.Email),320); Add(command,"@MobileNumber",SqlDbType.NVarChar,Null(request.MobileNumber),50); Add(command,"@IsPartnerAdmin",SqlDbType.Bit,request.IsPartnerAdmin); Add(command,"@IsActive",SqlDbType.Bit,request.IsActive); Add(command,"@UpdatedBy",SqlDbType.NVarChar,ActorName(),100); Add(command,"@ID",SqlDbType.BigInt,id);
        if (!string.IsNullOrWhiteSpace(request.Password)) Add(command,"@PasswordHash",SqlDbType.NVarChar,passwordService.HashPassword(request.Username,request.Password),500);
        try
        {
            return await command.ExecuteNonQueryAsync(cancellationToken) == 0 ? NotFound() : NoContent();
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627)
        {
            return Conflict(new { message = "Username นี้ถูกใช้งานแล้ว" });
        }
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken cancellationToken)
    {
        if (!await IsLaooSupportAsync(cancellationToken)) return Forbid();
        await using var connection = await OpenAsync(cancellationToken);
        if (!await HasPermissionAsync(connection, "DELETE", cancellationToken)) return Forbid();

        const string sql = "DELETE FROM dbo.TDADPartnerUser WHERE PartnerUserID=@ID;";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@ID", SqlDbType.BigInt, id);
        return await command.ExecuteNonQueryAsync(cancellationToken) == 0 ? NotFound() : NoContent();
    }

    private Task<bool> IsLaooSupportAsync(CancellationToken token) => Task.FromResult(string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase) && User.FindFirstValue("laoo_user_id") is not null);
    private async Task<bool> HasPermissionAsync(SqlConnection connection, string action, CancellationToken token)
    {
        if (!long.TryParse(User.FindFirstValue("laoo_user_id"), out var user) || !long.TryParse(User.FindFirstValue("project_id"), out var project)) return false;
        const string sql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADLaooUserPermission UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.LaooUserID=@UserID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@ScreenCode AND P.ActionCode=@Action) THEN 1 ELSE 0 END";
        await using var command = new SqlCommand(sql, connection); Add(command,"@UserID",SqlDbType.BigInt,user); Add(command,"@ProjectID",SqlDbType.BigInt,project); Add(command,"@ScreenCode",SqlDbType.NVarChar,ScreenCode,100); Add(command,"@Action",SqlDbType.NVarChar,action,50); return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }
    private async Task<bool> PartnerExistsAsync(SqlConnection c,long id,CancellationToken t){await using var x=new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADPartner WHERE PartnerID=@ID) THEN 1 ELSE 0 END",c);Add(x,"@ID",SqlDbType.BigInt,id);return Convert.ToBoolean(await x.ExecuteScalarAsync(t));}
    private async Task<bool> HasActiveAdminAsync(SqlConnection c,long id,CancellationToken t){await using var x=new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADPartnerUser WHERE PartnerID=@ID AND IsPartnerAdmin=1 AND IsActive=1) THEN 1 ELSE 0 END",c);Add(x,"@ID",SqlDbType.BigInt,id);return Convert.ToBoolean(await x.ExecuteScalarAsync(t));}
    private async Task<SqlConnection> OpenAsync(CancellationToken t){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    private string ActorName()=>User.FindFirstValue(ClaimTypes.Name)??User.FindFirstValue("username")??"t";
    private static string? Null(string? v)=>string.IsNullOrWhiteSpace(v)?null:v.Trim();
    private static void Add(SqlCommand c,string n,SqlDbType t,object? v,int size=0){var p=size>0?c.Parameters.Add(n,t,size):c.Parameters.Add(n,t);p.Value=v??DBNull.Value;}
    private static PartnerUserResponse Read(SqlDataReader r)=>new(){PartnerUserId=r.GetInt64(0),PartnerId=r.GetInt64(1),Username=r.GetString(2),DisplayName=r.GetString(3),Email=r.IsDBNull(4)?null:r.GetString(4),MobileNumber=r.IsDBNull(5)?null:r.GetString(5),IsPartnerAdmin=r.GetBoolean(6),IsActive=r.GetBoolean(7)};
}
