using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

public sealed record TimeReasonSaveRequest(
    string ReasonCode,
    string ReasonName,
    bool RequireRemark,
    bool RequireEvidence,
    bool IsActive,
    string? RowVersion);

[ApiController]
[Route("api/time/on-behalf-reasons")]
[Authorize]
public sealed class OnBehalfReasonsController(IConfiguration configuration) : ControllerBase
{
    private const string MenuCode = "28003";
    private const string Table = "TDTMOnBehalfReason";
    private const string IdColumn = "OnBehalfReasonID";

    [HttpGet("actions")]
    public Task<IActionResult> Actions(CancellationToken token) =>
        TimeReasonStore.Actions(configuration, User, MenuCode, "เหตุผลทำแทน", token);

    [HttpGet]
    public Task<IActionResult> List([FromQuery] string? search, [FromQuery] bool? isActive,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 30,
        CancellationToken token = default) =>
        TimeReasonStore.List(configuration, User, MenuCode, Table, IdColumn,
            search, isActive, page, pageSize, token);

    [HttpPost]
    public Task<IActionResult> Create(TimeReasonSaveRequest request, CancellationToken token) =>
        TimeReasonStore.Save(configuration, User, MenuCode, Table, IdColumn,
            null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, TimeReasonSaveRequest request,
        CancellationToken token) =>
        TimeReasonStore.Save(configuration, User, MenuCode, Table, IdColumn,
            id, request, token);

    [HttpDelete("{id:long}")]
    public Task<IActionResult> Delete(long id, [FromQuery] string rowVersion,
        CancellationToken token) =>
        TimeReasonStore.Delete(configuration, User, MenuCode, Table, IdColumn,
            "TDTMRequest", "OnBehalfReasonID", id, rowVersion, token);
}

[ApiController]
[Route("api/time/adjustment-reasons")]
[Authorize]
public sealed class TimeAdjustmentReasonsController(IConfiguration configuration) : ControllerBase
{
    private const string MenuCode = "28004";
    private const string Table = "TDTMTimeAdjustmentReason";
    private const string IdColumn = "TimeAdjustmentReasonID";

    [HttpGet("actions")]
    public Task<IActionResult> Actions(CancellationToken token) =>
        TimeReasonStore.Actions(configuration, User, MenuCode, "เหตุผลปรับเวลา", token);

    [HttpGet]
    public Task<IActionResult> List([FromQuery] string? search, [FromQuery] bool? isActive,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 30,
        CancellationToken token = default) =>
        TimeReasonStore.List(configuration, User, MenuCode, Table, IdColumn,
            search, isActive, page, pageSize, token);

    [HttpPost]
    public Task<IActionResult> Create(TimeReasonSaveRequest request, CancellationToken token) =>
        TimeReasonStore.Save(configuration, User, MenuCode, Table, IdColumn,
            null, request, token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id, TimeReasonSaveRequest request,
        CancellationToken token) =>
        TimeReasonStore.Save(configuration, User, MenuCode, Table, IdColumn,
            id, request, token);

    [HttpDelete("{id:long}")]
    public Task<IActionResult> Delete(long id, [FromQuery] string rowVersion,
        CancellationToken token) =>
        TimeReasonStore.Delete(configuration, User, MenuCode, Table, IdColumn,
            "TDTMTimeCorrectionRequest", "TimeAdjustmentReasonID", id,
            rowVersion, token);
}

internal static class TimeReasonStore
{
    public static async Task<IActionResult> Actions(IConfiguration configuration,
        ClaimsPrincipal user, string menuCode, string fallbackCaption,
        CancellationToken token)
    {
        if (!TryScope(user, out _, out _)) return new ForbidResult();
        await using var connection = await Open(configuration, token);
        return new OkObjectResult(new
        {
            menuCode,
            caption = await Caption(connection, menuCode, fallbackCaption, token),
            screenType = 1,
            view = await Can(connection, user, menuCode, "VIEW", token),
            create = await Can(connection, user, menuCode, "CREATE", token),
            edit = await Can(connection, user, menuCode, "EDIT", token),
            delete = await Can(connection, user, menuCode, "DELETE", token),
        });
    }

    public static async Task<IActionResult> List(IConfiguration configuration,
        ClaimsPrincipal user, string menuCode, string table, string idColumn,
        string? search, bool? isActive, int page, int pageSize,
        CancellationToken token)
    {
        if (!TryScope(user, out var companyId, out _)) return new ForbidResult();
        if (page < 1 || pageSize is < 1 or > 100)
            return new BadRequestObjectResult(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง" });
        await using var connection = await Open(configuration, token);
        if (!await Can(connection, user, menuCode, "VIEW", token)) return new ForbidResult();
        search = Clean(search);
        var where = $"FROM dbo.{table} WHERE CompanyID=@CompanyID AND (@IsActive IS NULL OR IsActive=@IsActive) AND (@Search IS NULL OR ReasonCode LIKE N'%'+@Search+N'%' OR ReasonName LIKE N'%'+@Search+N'%')";
        await using var count = new SqlCommand($"SELECT COUNT_BIG(1) {where}", connection);
        Bind(count, companyId, search, isActive);
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var command = new SqlCommand($"SELECT {idColumn},ReasonCode,ReasonName,RequireRemark,RequireEvidence,IsActive,CONVERT(varchar(32),RowVersion,2) {where} ORDER BY ReasonCode OFFSET @Offset ROWS FETCH NEXT @Take ROWS ONLY", connection);
        Bind(command, companyId, search, isActive);
        Add(command, "@Offset", SqlDbType.Int, (page - 1) * pageSize);
        Add(command, "@Take", SqlDbType.Int, pageSize);
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token)) items.Add(new
        {
            id = reader.GetInt64(0), reasonCode = reader.GetString(1),
            reasonName = reader.GetString(2), requireRemark = reader.GetBoolean(3),
            requireEvidence = reader.GetBoolean(4), isActive = reader.GetBoolean(5),
            rowVersion = reader.GetString(6),
        });
        return new OkObjectResult(new { total, page, pageSize, items });
    }

    public static async Task<IActionResult> Save(IConfiguration configuration,
        ClaimsPrincipal user, string menuCode, string table, string idColumn,
        long? id, TimeReasonSaveRequest request, CancellationToken token)
    {
        if (!TryScope(user, out var companyId, out var userId)) return new ForbidResult();
        var code = Clean(request.ReasonCode)?.ToUpperInvariant();
        var name = Clean(request.ReasonName);
        if (code is null || code.Length > 50 || name is null || name.Length > 200)
            return new BadRequestObjectResult(new { message = "กรุณาระบุรหัสและชื่อเหตุผลให้ถูกต้อง" });
        if (id.HasValue && !ValidRowVersion(request.RowVersion))
            return new BadRequestObjectResult(new { message = "ไม่พบ Version ของข้อมูล กรุณาโหลดใหม่" });
        await using var connection = await Open(configuration, token);
        if (!await Can(connection, user, menuCode, id.HasValue ? "EDIT" : "CREATE", token))
            return new ForbidResult();
        try
        {
            if (!id.HasValue)
            {
                await using var insert = new SqlCommand($"INSERT dbo.{table}(CompanyID,ReasonCode,ReasonName,RequireRemark,RequireEvidence,IsActive,CreateBy) VALUES(@CompanyID,@Code,@Name,@Remark,@Evidence,@Active,@UserID)", connection);
                BindSave(insert, companyId, userId, code, name, request);
                await insert.ExecuteNonQueryAsync(token);
                return new NoContentResult();
            }
            await using var update = new SqlCommand($"UPDATE dbo.{table} SET ReasonCode=@Code,ReasonName=@Name,RequireRemark=@Remark,RequireEvidence=@Evidence,IsActive=@Active,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND {idColumn}=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2)", connection);
            BindSave(update, companyId, userId, code, name, request);
            Add(update, "@ID", SqlDbType.BigInt, id.Value);
            Add(update, "@RowVersion", SqlDbType.VarChar, request.RowVersion, 32);
            return await update.ExecuteNonQueryAsync(token) == 1
                ? new NoContentResult()
                : new ConflictObjectResult(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" });
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            return new ConflictObjectResult(new { message = "รหัสเหตุผลซ้ำในบริษัท" });
        }
    }

    public static async Task<IActionResult> Delete(IConfiguration configuration,
        ClaimsPrincipal user, string menuCode, string table, string idColumn,
        string usedTable, string usedColumn, long id, string rowVersion,
        CancellationToken token)
    {
        if (!TryScope(user, out var companyId, out var userId)) return new ForbidResult();
        if (!ValidRowVersion(rowVersion))
            return new BadRequestObjectResult(new { message = "ไม่พบ Version ของข้อมูล กรุณาโหลดใหม่" });
        await using var connection = await Open(configuration, token);
        if (!await Can(connection, user, menuCode, "DELETE", token)) return new ForbidResult();
        await using var command = new SqlCommand($"IF EXISTS(SELECT 1 FROM dbo.{usedTable} WHERE CompanyID=@CompanyID AND {usedColumn}=@ID) THROW 52521,N'เหตุผลนี้ถูกใช้งานแล้ว ไม่สามารถลบได้',1; UPDATE dbo.{table} SET IsActive=0,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND {idColumn}=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2)", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        Add(command, "@ID", SqlDbType.BigInt, id);
        Add(command, "@RowVersion", SqlDbType.VarChar, rowVersion, 32);
        try
        {
            return await command.ExecuteNonQueryAsync(token) == 1
                ? new NoContentResult()
                : new ConflictObjectResult(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" });
        }
        catch (SqlException exception) when (exception.Number == 52521)
        {
            return new ConflictObjectResult(new { message = exception.Message });
        }
    }

    private static void Bind(SqlCommand command, long companyId, string? search, bool? active)
    {
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@Search", SqlDbType.NVarChar, search, 200);
        Add(command, "@IsActive", SqlDbType.Bit, active);
    }

    private static void BindSave(SqlCommand command, long companyId, long userId,
        string code, string name, TimeReasonSaveRequest request)
    {
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@Code", SqlDbType.NVarChar, code, 50);
        Add(command, "@Name", SqlDbType.NVarChar, name, 200);
        Add(command, "@Remark", SqlDbType.Bit, request.RequireRemark);
        Add(command, "@Evidence", SqlDbType.Bit, request.RequireEvidence);
        Add(command, "@Active", SqlDbType.Bit, request.IsActive);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
    }

    private static Task<bool> Can(SqlConnection connection, ClaimsPrincipal user,
        string menuCode, string action, CancellationToken token) =>
        CompanyMenuAccess.IsAllowedAsync(connection, user, menuCode, action, token);

    private static async Task<string> Caption(SqlConnection connection,
        string menuCode, string fallback, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@MenuCode", connection);
        Add(command, "@MenuCode", SqlDbType.Char, menuCode, 5);
        return Convert.ToString(await command.ExecuteScalarAsync(token)) ?? fallback;
    }

    private static bool TryScope(ClaimsPrincipal user, out long companyId, out long userId)
    {
        companyId = 0; userId = 0;
        return string.Equals(user.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase)
            && long.TryParse(user.FindFirstValue("company_id"), out companyId)
            && long.TryParse(user.FindFirstValue("user_id"), out userId)
            && companyId > 0 && userId > 0;
    }

    private static async Task<SqlConnection> Open(IConfiguration configuration, CancellationToken token)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static bool ValidRowVersion(string? value) => value is { Length: 16 } && value.All(Uri.IsHexDigit);
    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0)
    {
        var parameter = size == 0 ? command.Parameters.Add(name, type) : command.Parameters.Add(name, type, size);
        parameter.Value = value ?? DBNull.Value;
    }
}
