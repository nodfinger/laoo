using System.Data;
using System.Security.Claims;
using LaooServiceModule.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;

public sealed record VatRegistrationUpdate(bool? IsVatRegistered, string? Reason);

[ApiController, Authorize, LaooServiceModule.Security.RequireCompanyFeature("SALES")]
[LaooServiceModule.Security.RequireCompanyProject("LAOO")]
[TypeFilter(typeof(ItemProjectExceptionFilter))]
[Route("api/company/vat-settings")]
public sealed class VatSettingsController(IConfiguration configuration) : ControllerBase
{
    private readonly IConfiguration _configuration = configuration;
    private long CompanyId => long.TryParse(User.FindFirstValue("company_id"), out var n) ? n : 0;
    private long UserId => long.TryParse(User.FindFirstValue("user_id"), out var n) ? n : 0;

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private Task<bool> Can(SqlConnection connection, string action, CancellationToken token) =>
        Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedAsync(connection, User, "09008", action, token);

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();
        var canEdit = await Can(connection, "EDIT", token)
            && await WarehouseAccessService.IsCompanyAdminAsync(connection, CompanyId, UserId, token);
        var canClose = await Can(connection, "CLOSE", token);
        await using var command = new SqlCommand(
            "SELECT IsVatRegistered,TaxID FROM dbo.TDSTCompanySetUp WHERE CompanyID=@company AND IsActive=1",
            connection);
        command.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound();
        return Ok(new {
            isVatRegistered = reader.IsDBNull(0) ? (bool?)null : reader.GetBoolean(0),
            taxId = reader.IsDBNull(1) ? null : reader.GetString(1),
            canEdit, canClose
        });
    }

    [HttpPut]
    public async Task<IActionResult> Update([FromBody] VatRegistrationUpdate request, CancellationToken token)
    {
        if (request.IsVatRegistered is null)
            return BadRequest(new { message = "กรุณาระบุสถานะ VAT", description = "เลือกว่าบริษัทจดทะเบียน VAT แล้วหรือยัง ก่อนบันทึก" });
        if (request.Reason?.Length > 500)
            return BadRequest(new { message = "เหตุผลยาวเกินกำหนด", description = "ระบุเหตุผลไม่เกิน 500 ตัวอักษร" });
        await using var connection = await Open(token);
        if (!await Can(connection, "EDIT", token)
            || !await WarehouseAccessService.IsCompanyAdminAsync(connection, CompanyId, UserId, token))
            return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            await using var command = new SqlCommand("""
                UPDATE dbo.TDSTCompanySetUp
                SET IsVatRegistered=@registered,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user
                WHERE CompanyID=@company AND IsActive=1
                """, connection, transaction);
            command.Parameters.Add("@registered", SqlDbType.Bit).Value = request.IsVatRegistered.Value;
            command.Parameters.Add("@user", SqlDbType.BigInt).Value = UserId;
            command.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
            if (await command.ExecuteNonQueryAsync(token) != 1)
            {
                await transaction.RollbackAsync(token);
                return NotFound();
            }
            await using var audit = new SqlCommand("""
                INSERT dbo.TDADFinanceAudit(CompanyID,EntityType,EntityID,ActionCode,Reason,ActorUserID)
                VALUES(@company,N'VAT_REGISTRATION',@company,N'UPDATE',@reason,@user)
                """, connection, transaction);
            audit.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
            audit.Parameters.Add("@user", SqlDbType.BigInt).Value = UserId;
            audit.Parameters.Add("@reason", SqlDbType.NVarChar, 500).Value =
                (object?)request.Reason?.Trim() ?? DBNull.Value;
            await audit.ExecuteNonQueryAsync(token);
            await transaction.CommitAsync(token);
            return Ok(new { isVatRegistered = request.IsVatRegistered });
        }
        catch
        {
            await transaction.RollbackAsync(token);
            throw;
        }
    }
}
