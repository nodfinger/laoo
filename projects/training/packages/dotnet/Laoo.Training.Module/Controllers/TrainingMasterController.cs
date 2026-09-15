using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTrainingModule.Controllers;

[ApiController]
[Authorize]
[Route("api/company/training")]
public sealed class TrainingMasterController(IConfiguration configuration) : ControllerBase
{
    private static readonly MasterDefinition Types = new(
        "37001", "dbo.TDTRTrainingType", "TrainingTypeID", "TrainingTypeCode",
        "TrainingTypeName", "TTP", "ประเภทการอบรม");
    private static readonly MasterDefinition Instructors = new(
        "37002", "dbo.TDTRTrainingInstructor", "TrainingInstructorID",
        "TrainingInstructorCode", "TrainingInstructorName", "TIN", "วิทยากร");

    [HttpGet("types")]
    public Task<IActionResult> ListTypes([FromQuery] MasterListQuery query, CancellationToken token) =>
        List(Types, query, token);

    [HttpGet("types/actions")]
    public Task<IActionResult> TypeActions(CancellationToken token) => Actions(Types, token);

    [HttpPost("types")]
    public Task<IActionResult> CreateType(MasterRequest request, CancellationToken token) =>
        Save(Types, null, request, token);

    [HttpPut("types/{id:long}")]
    public Task<IActionResult> UpdateType(long id, MasterRequest request, CancellationToken token) =>
        Save(Types, id, request, token);

    [HttpDelete("types/{id:long}")]
    public Task<IActionResult> DeleteType(long id, [FromQuery] string? rowVersion, CancellationToken token) =>
        Delete(Types, id, rowVersion, token);

    [HttpGet("instructors")]
    public Task<IActionResult> ListInstructors([FromQuery] MasterListQuery query, CancellationToken token) =>
        List(Instructors, query, token);

    [HttpGet("instructors/actions")]
    public Task<IActionResult> InstructorActions(CancellationToken token) => Actions(Instructors, token);

    [HttpPost("instructors")]
    public Task<IActionResult> CreateInstructor(MasterRequest request, CancellationToken token) =>
        Save(Instructors, null, request, token);

    [HttpPut("instructors/{id:long}")]
    public Task<IActionResult> UpdateInstructor(long id, MasterRequest request, CancellationToken token) =>
        Save(Instructors, id, request, token);

    [HttpDelete("instructors/{id:long}")]
    public Task<IActionResult> DeleteInstructor(long id, [FromQuery] string? rowVersion, CancellationToken token) =>
        Delete(Instructors, id, rowVersion, token);

    private async Task<IActionResult> Actions(MasterDefinition definition, CancellationToken token)
    {
        if (!TryScope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        var view = await Allowed(connection, definition.ScreenCode, "VIEW", token);
        if (!view) return Forbid();

        var caption = await Caption(connection, definition.ScreenCode, token);
        return Ok(new
        {
            caption = caption ?? definition.FallbackCaption,
            screenType = 1,
            view,
            create = await Allowed(connection, definition.ScreenCode, "CREATE", token),
            edit = await Allowed(connection, definition.ScreenCode, "EDIT", token),
            delete = await Allowed(connection, definition.ScreenCode, "DELETE", token),
        });
    }

    private async Task<IActionResult> List(
        MasterDefinition definition,
        MasterListQuery query,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        var page = Math.Max(query.Page, 1);
        var pageSize = Math.Clamp(query.PageSize, 1, 100);
        await using var connection = await Open(token);
        if (!await Allowed(connection, definition.ScreenCode, "VIEW", token)) return Forbid();

        var filters = "CompanyID=@company AND (@active IS NULL OR IsActive=@active) AND (" +
            definition.CodeColumn + " LIKE @search OR " + definition.NameColumn + " LIKE @search" +
            (definition == Instructors ? " OR InstituteName LIKE @search" : string.Empty) + ")";
        var columns = definition == Types
            ? $"{definition.KeyColumn},{definition.CodeColumn},{definition.NameColumn},Remark,IsActive,RowVersion"
            : $"{definition.KeyColumn},{definition.CodeColumn},{definition.NameColumn},PhoneNumber,Email,ContactStartDate,InstituteName,Remark,IsActive,RowVersion";
        var sql = $"""
SELECT {columns}
FROM {definition.TableName}
WHERE {filters}
ORDER BY {definition.NameColumn},{definition.KeyColumn}
OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
SELECT COUNT_BIG(1) FROM {definition.TableName} WHERE {filters};
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@company", SqlDbType.BigInt, companyId);
        Add(command, "@active", SqlDbType.Bit, query.IsActive);
        Add(command, "@search", SqlDbType.NVarChar, $"%{query.Search?.Trim() ?? string.Empty}%", 202);
        Add(command, "@offset", SqlDbType.Int, (page - 1) * pageSize);
        Add(command, "@pageSize", SqlDbType.Int, pageSize);
        var items = new List<object>();
        await using var reader = await command.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
            items.Add(definition == Types ? TypeRow(reader) : InstructorRow(reader));
        await reader.NextResultAsync(token);
        var total = await reader.ReadAsync(token) ? reader.GetInt64(0) : 0;
        return Ok(new { items, total, page, pageSize });
    }

    private async Task<IActionResult> Save(
        MasterDefinition definition,
        long? id,
        MasterRequest request,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var error = Validate(definition, id, request);
        if (error is not null) return BadRequest(error);
        var rowVersion = DecodeRowVersion(request.RowVersion);
        if (id is not null && rowVersion is null)
            return BadRequest(new { message = "ข้อมูลไม่ครบ", description = "ไม่พบเวอร์ชันข้อมูล กรุณาโหลดรายการใหม่ก่อนบันทึก" });

        await using var connection = await Open(token);
        if (!await Allowed(connection, definition.ScreenCode, id is null ? "CREATE" : "EDIT", token))
            return Forbid();

        var extraColumns = definition == Types ? "Remark,IsActive,CreateDate,CreateBy" :
            "PhoneNumber,Email,ContactStartDate,InstituteName,Remark,IsActive,CreateDate,CreateBy";
        var extraValues = definition == Types ? "@remark,@active,SYSUTCDATETIME(),@user" :
            "@phone,@email,@contactStartDate,@institute,@remark,@active,SYSUTCDATETIME(),@user";
        var updateValues = definition == Types ?
            "Remark=@remark,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user" :
            "PhoneNumber=@phone,Email=@email,ContactStartDate=@contactStartDate,InstituteName=@institute,Remark=@remark,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user";
        var sql = $"""
SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @targetId bigint=@id;
DECLARE @code nvarchar(30)=NULLIF(LTRIM(RTRIM(@codeInput)),N'');
IF @targetId IS NULL
BEGIN
    IF @code IS NULL SET @code=N'__PENDING_'+CONVERT(nvarchar(36),NEWID());
    INSERT {definition.TableName}(CompanyID,{definition.CodeColumn},{definition.NameColumn},{extraColumns})
    VALUES(@company,@code,@name,{extraValues});
    SET @targetId=SCOPE_IDENTITY();
    IF NULLIF(LTRIM(RTRIM(@codeInput)),N'') IS NULL
        UPDATE {definition.TableName}
        SET {definition.CodeColumn}=@prefix+RIGHT(N'000000'+CONVERT(nvarchar(20),@targetId),6)
        WHERE {definition.KeyColumn}=@targetId AND CompanyID=@company;
END
ELSE
BEGIN
    UPDATE {definition.TableName}
    SET {definition.CodeColumn}=COALESCE(@code,{definition.CodeColumn}),
        {definition.NameColumn}=@name,{updateValues}
    WHERE {definition.KeyColumn}=@targetId AND CompanyID=@company AND RowVersion=@rowVersion;
    IF @@ROWCOUNT=0 THROW 52921,N'TRAINING_MASTER_CONCURRENCY',1;
END
COMMIT TRANSACTION;
SELECT @targetId;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@id", SqlDbType.BigInt, id);
        Add(command, "@company", SqlDbType.BigInt, companyId);
        Add(command, "@user", SqlDbType.BigInt, userId);
        Add(command, "@codeInput", SqlDbType.NVarChar, request.Code?.Trim().ToUpperInvariant(), 30);
        Add(command, "@name", SqlDbType.NVarChar, request.Name.Trim(), 200);
        Add(command, "@remark", SqlDbType.NVarChar, NullIfBlank(request.Remark), 500);
        Add(command, "@active", SqlDbType.Bit, request.IsActive);
        Add(command, "@rowVersion", SqlDbType.VarBinary, rowVersion, 8);
        Add(command, "@prefix", SqlDbType.NVarChar, definition.CodePrefix, 3);
        if (definition == Instructors)
        {
            Add(command, "@phone", SqlDbType.NVarChar, NullIfBlank(request.PhoneNumber), 50);
            Add(command, "@email", SqlDbType.NVarChar, NullIfBlank(request.Email), 254);
            Add(command, "@contactStartDate", SqlDbType.Date, request.ContactStartDate);
            Add(command, "@institute", SqlDbType.NVarChar, NullIfBlank(request.InstituteName), 200);
        }
        try
        {
            return Ok(new { id = Convert.ToInt64(await command.ExecuteScalarAsync(token)) });
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            return Conflict(new { message = "รหัสข้อมูลซ้ำ", description = "กรุณาระบุรหัสที่ยังไม่ถูกใช้ในบริษัทนี้" });
        }
        catch (SqlException exception) when (exception.Number == 52921)
        {
            return Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว", description = "กรุณาโหลดรายการใหม่ก่อนบันทึกอีกครั้ง" });
        }
    }

    private async Task<IActionResult> Delete(
        MasterDefinition definition,
        long id,
        string? rowVersionText,
        CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        var rowVersion = DecodeRowVersion(rowVersionText);
        if (rowVersion is null)
            return BadRequest(new { message = "ข้อมูลไม่ครบ", description = "ไม่พบเวอร์ชันข้อมูล กรุณาโหลดรายการใหม่ก่อนลบ" });
        await using var connection = await Open(token);
        if (!await Allowed(connection, definition.ScreenCode, "DELETE", token)) return Forbid();
        await using var command = new SqlCommand($"DELETE FROM {definition.TableName} WHERE {definition.KeyColumn}=@id AND CompanyID=@company AND RowVersion=@rowVersion", connection);
        Add(command, "@id", SqlDbType.BigInt, id);
        Add(command, "@company", SqlDbType.BigInt, companyId);
        Add(command, "@rowVersion", SqlDbType.VarBinary, rowVersion, 8);
        if (await command.ExecuteNonQueryAsync(token) == 0)
            return Conflict(new { message = "ลบข้อมูลไม่สำเร็จ", description = "ข้อมูลอาจถูกแก้ไขหรือลบไปแล้ว กรุณาโหลดรายการใหม่" });
        return NoContent();
    }

    private static object TypeRow(SqlDataReader reader) => new
    {
        id = reader.GetInt64(0),
        code = reader.GetString(1),
        name = reader.GetString(2),
        remark = Text(reader, 3),
        isActive = reader.GetBoolean(4),
        rowVersion = Convert.ToBase64String((byte[])reader.GetValue(5)),
    };

    private static object InstructorRow(SqlDataReader reader) => new
    {
        id = reader.GetInt64(0),
        code = reader.GetString(1),
        name = reader.GetString(2),
        phoneNumber = Text(reader, 3),
        email = Text(reader, 4),
        contactStartDate = reader.IsDBNull(5) ? null : reader.GetDateTime(5).ToString("yyyy-MM-dd"),
        instituteName = Text(reader, 6),
        remark = Text(reader, 7),
        isActive = reader.GetBoolean(8),
        rowVersion = Convert.ToBase64String((byte[])reader.GetValue(9)),
    };

    private async Task<bool> Allowed(SqlConnection connection, string screenCode, string action, CancellationToken token) =>
        await CompanyMenuAccess.IsAllowedAsync(connection, User, screenCode, action, token);

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    private static async Task<string?> Caption(SqlConnection connection, string screenCode, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@screen AND ScreenType=1 AND IsActive=1", connection);
        Add(command, "@screen", SqlDbType.Char, screenCode, 5);
        return Convert.ToString(await command.ExecuteScalarAsync(token));
    }

    private bool TryScope(out long companyId, out long userId)
    {
        companyId = userId = 0;
        return string.Equals(User.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase)
            && long.TryParse(User.FindFirstValue("company_id"), out companyId) && companyId > 0
            && long.TryParse(User.FindFirstValue("user_id"), out userId) && userId > 0;
    }

    private static object? Validate(MasterDefinition definition, long? id, MasterRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            return new { message = "ข้อมูลไม่ครบ", description = $"กรุณาระบุชื่อ{definition.FallbackCaption}" };
        if (request.Name.Trim().Length > 200 || request.Code?.Trim().Length > 30 || request.Remark?.Trim().Length > 500)
            return new { message = "ข้อมูลไม่ถูกต้อง", description = "ข้อมูลมีความยาวเกินกว่าที่ระบบกำหนด" };
        if (definition == Instructors)
        {
            if (request.PhoneNumber?.Trim().Length > 50 || request.Email?.Trim().Length > 254 || request.InstituteName?.Trim().Length > 200)
                return new { message = "ข้อมูลไม่ถูกต้อง", description = "ข้อมูลมีความยาวเกินกว่าที่ระบบกำหนด" };
            if (!string.IsNullOrWhiteSpace(request.Email) && !request.Email.Contains('@', StringComparison.Ordinal))
                return new { message = "อีเมลไม่ถูกต้อง", description = "กรุณาระบุอีเมลในรูปแบบที่ถูกต้อง" };
        }
        return null;
    }

    private static byte[]? DecodeRowVersion(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        try { return Convert.FromBase64String(value); }
        catch (FormatException) { return null; }
    }

    private static string? Text(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
    private static string? NullIfBlank(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0)
    {
        var parameter = size > 0 ? command.Parameters.Add(name, type, size) : command.Parameters.Add(name, type);
        parameter.Value = value ?? DBNull.Value;
    }

    private sealed record MasterDefinition(string ScreenCode, string TableName, string KeyColumn, string CodeColumn, string NameColumn, string CodePrefix, string FallbackCaption);
}

public sealed record MasterListQuery(string? Search, bool? IsActive, int Page = 1, int PageSize = 30);
public sealed record MasterRequest(
    string? Code,
    string Name,
    string? PhoneNumber,
    string? Email,
    DateOnly? ContactStartDate,
    string? InstituteName,
    string? Remark,
    bool IsActive = true,
    string? RowVersion = null);
