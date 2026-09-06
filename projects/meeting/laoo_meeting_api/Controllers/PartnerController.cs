using System.Data;
using System.Security.Claims;
using LaooMeetingApi.Models.Support;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController]
[Route("api/support/partners")]
[Authorize]
public sealed class PartnerController : ControllerBase
{
    private const string ScreenCode = "PARTNER";

    private readonly IConfiguration _configuration;

    public PartnerController(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    [HttpGet]
    public async Task<ActionResult<List<PartnerResponse>>> GetAll(
        [FromQuery] string? search,
        [FromQuery] bool? isActive,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);

        var scope = ResolveScope();
        if (scope is null)
        {
            return Forbid();
        }

        if (!await HasPermissionAsync(
                connection,
                "VIEW",
                cancellationToken))
        {
            return Forbid();
        }

        const string sql = @"
SELECT
    PartnerID,
    PartnerCode,
    PartnerNameTH,
    PartnerNameEN,
    Email,
    Telephone,
    AddressText,
    ShortName,
    Province,
    StartContactDate,
    ContactName1,
    ContactPosition1,
    ContactPhone1,
    ContactEmail1,
    ContactName2,
    ContactPosition2,
    ContactPhone2,
    ContactEmail2,
    Remark,
    IsActive,
    (SELECT TOP (1) U.PartnerUserID
     FROM dbo.TDADPartnerUser AS U
     WHERE U.PartnerID = P.PartnerID
       AND U.IsPartnerAdmin = 1
       AND U.IsActive = 1
     ORDER BY U.PartnerUserID) AS PartnerAdminUserID,
    (SELECT TOP (1) U.Username
     FROM dbo.TDADPartnerUser AS U
     WHERE U.PartnerID = P.PartnerID
       AND U.IsPartnerAdmin = 1
       AND U.IsActive = 1
     ORDER BY U.PartnerUserID) AS PartnerAdminUsername
FROM dbo.TDADPartner AS P
WHERE
    (
        @Search IS NULL
        OR PartnerCode LIKE N'%' + @Search + N'%'
        OR PartnerNameTH LIKE N'%' + @Search + N'%'
        OR ISNULL(PartnerNameEN, N'') LIKE N'%' + @Search + N'%'
        OR ISNULL(ContactName1, N'') LIKE N'%' + @Search + N'%'
        OR ISNULL(ContactName2, N'') LIKE N'%' + @Search + N'%'
    )
    AND (@IsActive IS NULL OR IsActive = @IsActive)
    AND (
        @CanReadAll = 1
        OR @PartnerID = P.PartnerID
        OR EXISTS
        (
            SELECT 1
            FROM dbo.TDSTCompanySetUp AS C
            WHERE C.CompanyID = @CompanyID
              AND C.PartnerID = P.PartnerID
        )
    )
ORDER BY PartnerCode;";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add(
            new SqlParameter("@Search", SqlDbType.NVarChar, 200)
            {
                Value = string.IsNullOrWhiteSpace(search)
                    ? DBNull.Value
                    : search.Trim()
            });

        command.Parameters.Add(
            new SqlParameter("@IsActive", SqlDbType.Bit)
            {
                Value = isActive.HasValue
                    ? isActive.Value
                    : DBNull.Value
            });

        AddScopeParameters(command, scope.Value);

        var result = new List<PartnerResponse>();

        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(ReadPartner(reader));
        }

        return Ok(result);
    }

    [HttpGet("{partnerId:long}")]
    public async Task<ActionResult<PartnerResponse>> GetById(
        long partnerId,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);

        var scope = ResolveScope();
        if (scope is null)
        {
            return Forbid();
        }

        if (!await HasPermissionAsync(
                connection,
                "VIEW",
                cancellationToken))
        {
            return Forbid();
        }

        const string sql = @"
SELECT
    PartnerID,
    PartnerCode,
    PartnerNameTH,
    PartnerNameEN,
    Email,
    Telephone,
    AddressText,
    ShortName,
    Province,
    StartContactDate,
    ContactName1,
    ContactPosition1,
    ContactPhone1,
    ContactEmail1,
    ContactName2,
    ContactPosition2,
    ContactPhone2,
    ContactEmail2,
    Remark,
    IsActive,
    (SELECT TOP (1) U.PartnerUserID
     FROM dbo.TDADPartnerUser AS U
     WHERE U.PartnerID = P.PartnerID
       AND U.IsPartnerAdmin = 1
       AND U.IsActive = 1
     ORDER BY U.PartnerUserID) AS PartnerAdminUserID,
    (SELECT TOP (1) U.Username
     FROM dbo.TDADPartnerUser AS U
     WHERE U.PartnerID = P.PartnerID
       AND U.IsPartnerAdmin = 1
       AND U.IsActive = 1
     ORDER BY U.PartnerUserID) AS PartnerAdminUsername
FROM dbo.TDADPartner AS P
WHERE P.PartnerID = @RequestedPartnerID
  AND (
      @CanReadAll = 1
      OR @PartnerID = P.PartnerID
      OR EXISTS
      (
          SELECT 1
          FROM dbo.TDSTCompanySetUp AS C
          WHERE C.CompanyID = @CompanyID
            AND C.PartnerID = P.PartnerID
      )
  );";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add(
            new SqlParameter("@RequestedPartnerID", SqlDbType.BigInt)
            {
                Value = partnerId
            });

        AddScopeParameters(command, scope.Value);

        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return NotFound();
        }

        return Ok(ReadPartner(reader));
    }

    [HttpPost]
    public async Task<ActionResult<PartnerResponse>> Create(
        PartnerUpsertRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.PartnerNameTh))
        {
            return BadRequest(
                new { message = "กรุณาระบุชื่อ Partner" });
        }

        await using var connection = await OpenConnectionAsync(cancellationToken);

        var scope = ResolveScope();
        if (scope is null || !scope.Value.CanReadAll)
        {
            return Forbid();
        }

        if (!await HasPermissionAsync(
                connection,
                "CREATE",
                cancellationToken))
        {
            return Forbid();
        }

        await using var transaction =
            (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        try
        {
            const string nextCodeSql = @"
SELECT
    N'P' + RIGHT(
        N'000000' +
        CAST(
            ISNULL(
                MAX(
                    TRY_CONVERT(
                        INT,
                        SUBSTRING(PartnerCode, 2, 20)
                    )
                ),
                0
            ) + 1
            AS NVARCHAR(20)
        ),
        6
    )
FROM dbo.TDADPartner WITH (UPDLOCK, HOLDLOCK)
WHERE PartnerCode LIKE N'P%';";

            await using var nextCodeCommand =
                new SqlCommand(nextCodeSql, connection, transaction);

            var partnerCode =
                Convert.ToString(
                    await nextCodeCommand.ExecuteScalarAsync(cancellationToken))
                ?? "P000001";

            const string insertSql = @"
INSERT INTO dbo.TDADPartner
(
    PartnerCode,
    PartnerNameTH,
    PartnerNameEN,
    Email,
    Telephone,
    AddressText,
    ShortName,
    Province,
    StartContactDate,
    ContactName1,
    ContactPosition1,
    ContactPhone1,
    ContactEmail1,
    ContactName2,
    ContactPosition2,
    ContactPhone2,
    ContactEmail2,
    Remark,
    IsActive,
    CreateDate,
    CreateBy
)
VALUES
(
    @PartnerCode,
    @PartnerNameTH,
    @PartnerNameEN,
    @Email,
    @Telephone,
    @AddressText,
    @ShortName,
    @Province,
    @StartContactDate,
    @ContactName1,
    @ContactPosition1,
    @ContactPhone1,
    @ContactEmail1,
    @ContactName2,
    @ContactPosition2,
    @ContactPhone2,
    @ContactEmail2,
    @Remark,
    1,
    SYSUTCDATETIME(),
    @CreateBy
);
SELECT CAST(SCOPE_IDENTITY() AS BIGINT);";

            await using var insert =
                new SqlCommand(insertSql, connection, transaction);

            AddUpsertParameters(insert, request);

            insert.Parameters.Add(
                new SqlParameter("@PartnerCode", SqlDbType.NVarChar, 30)
                {
                    Value = partnerCode
                });

            insert.Parameters.Add(
                new SqlParameter("@CreateBy", SqlDbType.BigInt)
                {
                    Value = (object?)CurrentActorId() ?? DBNull.Value
                });

            var partnerId =
                Convert.ToInt64(
                    await insert.ExecuteScalarAsync(cancellationToken));

            await transaction.CommitAsync(cancellationToken);

            return CreatedAtAction(
                nameof(GetById),
                new { partnerId },
                new PartnerResponse
                {
                    PartnerId = partnerId,
                    PartnerCode = partnerCode,
                    PartnerNameTh = request.PartnerNameTh.Trim(),
                    PartnerNameEn = TrimOrNull(request.PartnerNameEn),
                    Email = TrimOrNull(request.Email),
                    Telephone = TrimOrNull(request.Telephone),
                    AddressText = TrimOrNull(request.AddressText),
                    ShortName = TrimOrNull(request.ShortName),
                    Province = TrimOrNull(request.Province),
                    StartContactDate = request.StartContactDate,
                    ContactName1 = TrimOrNull(request.ContactName1),
                    ContactPosition1 = TrimOrNull(request.ContactPosition1),
                    ContactPhone1 = TrimOrNull(request.ContactPhone1),
                    ContactEmail1 = TrimOrNull(request.ContactEmail1),
                    ContactName2 = TrimOrNull(request.ContactName2),
                    ContactPosition2 = TrimOrNull(request.ContactPosition2),
                    ContactPhone2 = TrimOrNull(request.ContactPhone2),
                    ContactEmail2 = TrimOrNull(request.ContactEmail2),
                    Remark = TrimOrNull(request.Remark),
                    IsActive = true
                });
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    [HttpPut("{partnerId:long}")]
    public async Task<IActionResult> Update(
        long partnerId,
        PartnerUpsertRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.PartnerNameTh))
        {
            return BadRequest(
                new { message = "กรุณาระบุชื่อ Partner" });
        }

        await using var connection = await OpenConnectionAsync(cancellationToken);

        var scope = ResolveScope();
        if (scope is null || !scope.Value.CanReadAll)
        {
            return Forbid();
        }

        if (!await HasPermissionAsync(
                connection,
                "EDIT",
                cancellationToken))
        {
            return Forbid();
        }

        const string sql = @"
UPDATE P
SET
    PartnerNameTH = @PartnerNameTH,
    PartnerNameEN = @PartnerNameEN,
    Email = @Email,
    Telephone = @Telephone,
    AddressText = @AddressText,
    ShortName = @ShortName,
    Province = @Province,
    StartContactDate = @StartContactDate,
    ContactName1 = @ContactName1,
    ContactPosition1 = @ContactPosition1,
    ContactPhone1 = @ContactPhone1,
    ContactEmail1 = @ContactEmail1,
    ContactName2 = @ContactName2,
    ContactPosition2 = @ContactPosition2,
    ContactPhone2 = @ContactPhone2,
    ContactEmail2 = @ContactEmail2,
    Remark = @Remark,
    UpdateDate = SYSUTCDATETIME(),
    UpdateBy = @UpdateBy
FROM dbo.TDADPartner AS P
WHERE P.PartnerID = @RequestedPartnerID
  AND (
      @CanReadAll = 1
      OR @PartnerID = P.PartnerID
      OR EXISTS
      (
          SELECT 1
          FROM dbo.TDSTCompanySetUp AS C
          WHERE C.CompanyID = @CompanyID
            AND C.PartnerID = P.PartnerID
      )
  );";

        await using var command = new SqlCommand(sql, connection);

        AddUpsertParameters(command, request);

        command.Parameters.Add(
            new SqlParameter("@RequestedPartnerID", SqlDbType.BigInt)
            {
                Value = partnerId
            });

        AddScopeParameters(command, scope.Value);

        command.Parameters.Add(
            new SqlParameter("@UpdateBy", SqlDbType.BigInt)
            {
                Value = (object?)CurrentActorId() ?? DBNull.Value
            });

        var affected =
            await command.ExecuteNonQueryAsync(cancellationToken);

        return affected == 0 ? NotFound() : NoContent();
    }

    [HttpPut("{partnerId:long}/status")]
    public async Task<IActionResult> ChangeStatus(
        long partnerId,
        PartnerStatusRequest request,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);

        var scope = ResolveScope();
        if (scope is null || !scope.Value.CanReadAll)
        {
            return Forbid();
        }

        if (!await HasPermissionAsync(
                connection,
                "CHANGE_STATUS",
                cancellationToken))
        {
            return Forbid();
        }

        const string sql = @"
UPDATE P
SET
    IsActive = @IsActive,
    UpdateDate = SYSUTCDATETIME(),
    UpdateBy = @UpdateBy
FROM dbo.TDADPartner AS P
WHERE P.PartnerID = @RequestedPartnerID
  AND (
      @CanReadAll = 1
      OR @PartnerID = P.PartnerID
      OR EXISTS
      (
          SELECT 1
          FROM dbo.TDSTCompanySetUp AS C
          WHERE C.CompanyID = @CompanyID
            AND C.PartnerID = P.PartnerID
      )
  );";

        await using var command = new SqlCommand(sql, connection);

        command.Parameters.Add(
            new SqlParameter("@IsActive", SqlDbType.Bit)
            {
                Value = request.IsActive
            });

        command.Parameters.Add(
            new SqlParameter("@RequestedPartnerID", SqlDbType.BigInt)
            {
                Value = partnerId
            });

        AddScopeParameters(command, scope.Value);

        command.Parameters.Add(
            new SqlParameter("@UpdateBy", SqlDbType.BigInt)
            {
                Value = (object?)CurrentActorId() ?? DBNull.Value
            });

        var affected =
            await command.ExecuteNonQueryAsync(cancellationToken);

        return affected == 0 ? NotFound() : NoContent();
    }


    [HttpDelete("{partnerId:long}")]
    public async Task<IActionResult> Delete(
        long partnerId,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);

        var scope = ResolveScope();
        if (scope is null || !scope.Value.CanReadAll)
        {
            return Forbid();
        }

        if (!await HasPermissionAsync(
                connection,
                "DELETE",
                cancellationToken))
        {
            return Forbid();
        }

        const string dependencySql = @"
SELECT COUNT_BIG(1)
FROM dbo.TDSTCompanySetUp
WHERE PartnerID = @RequestedPartnerID;";

        await using (var dependencyCommand =
            new SqlCommand(dependencySql, connection))
        {
            dependencyCommand.Parameters.Add(
                new SqlParameter("@RequestedPartnerID", SqlDbType.BigInt)
                {
                    Value = partnerId
                });

            var companyCount = Convert.ToInt64(
                await dependencyCommand.ExecuteScalarAsync(cancellationToken));

            if (companyCount > 0)
            {
                return Conflict(new
                {
                    code = "PARTNER_IN_USE",
                    message =
                        $"ไม่สามารถลบ Partner ได้ เนื่องจากมี Company ใช้งานอยู่ {companyCount:N0} รายการ",
                    companyCount
                });
            }
        }

        const string deleteSql = @"
DELETE FROM dbo.TDADPartner
WHERE PartnerID = @RequestedPartnerID;";

        await using var command = new SqlCommand(deleteSql, connection);

        command.Parameters.Add(
            new SqlParameter("@RequestedPartnerID", SqlDbType.BigInt)
            {
                Value = partnerId
            });

        try
        {
            var affected =
                await command.ExecuteNonQueryAsync(cancellationToken);

            return affected == 0
                ? NotFound(new { message = "ไม่พบ Partner ที่ต้องการลบ" })
                : NoContent();
        }
        catch (SqlException ex) when (ex.Number == 547)
        {
            return Conflict(new
            {
                message =
                    "ไม่สามารถลบ Partner ได้ เนื่องจากข้อมูลถูกอ้างอิงโดยข้อมูลอื่น"
            });
        }
    }

    private async Task<bool> HasPermissionAsync(
        SqlConnection connection,
        string actionCode,
        CancellationToken cancellationToken)
    {
        var projectId = ReadLongClaim("project_id");

        if (!projectId.HasValue)
        {
            return false;
        }

        var laooUserId = ReadLongClaim("laoo_user_id");
        var userId = ReadLongClaim("user_id");

        if (laooUserId.HasValue)
        {
            const string sql = @"
SELECT CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDADLaooUserPermission UP
    INNER JOIN dbo.TDADPermission P
        ON P.PermissionID = UP.PermissionID
       AND P.ProjectID = UP.ProjectID
    WHERE UP.LaooUserID = @UserID
      AND UP.ProjectID = @ProjectID
      AND UP.IsAllowed = 1
      AND UP.IsActive = 1
      AND P.IsActive = 1
      AND P.ScreenCode = @ScreenCode
      AND P.ActionCode = @ActionCode
)
THEN CAST(1 AS BIT)
ELSE CAST(0 AS BIT)
END;";

            return await ExecutePermissionCheckAsync(
                connection,
                sql,
                laooUserId.Value,
                projectId.Value,
                actionCode,
                cancellationToken);
        }

        if (userId.HasValue)
        {
            const string sql = @"
SELECT CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDADUserPermission UP
    INNER JOIN dbo.TDADPermission P
        ON P.PermissionID = UP.PermissionID
       AND P.ProjectID = UP.ProjectID
    WHERE UP.UserID = @UserID
      AND UP.ProjectID = @ProjectID
      AND UP.IsAllowed = 1
      AND UP.IsActive = 1
      AND P.IsActive = 1
      AND P.ScreenCode = @ScreenCode
      AND P.ActionCode = @ActionCode
)
THEN CAST(1 AS BIT)
ELSE CAST(0 AS BIT)
END;";

            return await ExecutePermissionCheckAsync(
                connection,
                sql,
                userId.Value,
                projectId.Value,
                actionCode,
                cancellationToken);
        }

        return false;
    }

    private static async Task<bool> ExecutePermissionCheckAsync(
        SqlConnection connection,
        string sql,
        long userId,
        long projectId,
        string actionCode,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand(sql, connection);

        command.Parameters.Add(
            new SqlParameter("@UserID", SqlDbType.BigInt)
            {
                Value = userId
            });

        command.Parameters.Add(
            new SqlParameter("@ProjectID", SqlDbType.BigInt)
            {
                Value = projectId
            });

        command.Parameters.Add(
            new SqlParameter("@ScreenCode", SqlDbType.NVarChar, 100)
            {
                Value = ScreenCode
            });

        command.Parameters.Add(
            new SqlParameter("@ActionCode", SqlDbType.NVarChar, 50)
            {
                Value = actionCode
            });

        return Convert.ToBoolean(
            await command.ExecuteScalarAsync(cancellationToken));
    }

    private long? CurrentActorId()
    {
        return ReadLongClaim("laoo_user_id")
            ?? ReadLongClaim("user_id");
    }

    private PartnerScope? ResolveScope()
    {
        var loginMode = User.FindFirstValue("login_mode");
        var userType = User.FindFirstValue("user_type");
        var laooUserId = ReadLongClaim("laoo_user_id");
        var isLaooSupport = string.Equals(
            loginMode,
            "LAOO",
            StringComparison.OrdinalIgnoreCase)
            || string.Equals(
                userType,
                "LAOO_SUPPORT",
                StringComparison.OrdinalIgnoreCase);
        if (isLaooSupport && laooUserId.HasValue)
        {
            return new PartnerScope(true, null, null);
        }

        var companyId = ReadLongClaim("company_id");
        if (companyId.HasValue)
        {
            return new PartnerScope(false, null, companyId);
        }

        var partnerId = ReadLongClaim("partner_id");
        if (partnerId.HasValue)
        {
            return new PartnerScope(false, partnerId, null);
        }

        return null;
    }

    private static void AddScopeParameters(
        SqlCommand command,
        PartnerScope scope)
    {
        command.Parameters.Add(
            new SqlParameter("@CanReadAll", SqlDbType.Bit)
            {
                Value = scope.CanReadAll
            });

        command.Parameters.Add(
            new SqlParameter("@PartnerID", SqlDbType.BigInt)
            {
                Value = (object?)scope.PartnerId ?? DBNull.Value
            });

        command.Parameters.Add(
            new SqlParameter("@CompanyID", SqlDbType.BigInt)
            {
                Value = (object?)scope.CompanyId ?? DBNull.Value
            });
    }

    private long? ReadLongClaim(string claimType)
    {
        var value = User.FindFirstValue(claimType);

        return long.TryParse(value, out var result)
            ? result
            : null;
    }

    private async Task<SqlConnection> OpenConnectionAsync(
        CancellationToken cancellationToken)
    {
        var connectionString =
            _configuration.GetConnectionString("LaooDatabase");

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "ConnectionStrings:LaooDatabase is not configured.");
        }

        var connection = new SqlConnection(connectionString);

        await connection.OpenAsync(cancellationToken);

        return connection;
    }

    private static void AddUpsertParameters(
        SqlCommand command,
        PartnerUpsertRequest request)
    {
        command.Parameters.Add(
            new SqlParameter("@PartnerNameTH", SqlDbType.NVarChar, 200)
            {
                Value = request.PartnerNameTh.Trim()
            });

        AddNullable(command, "@PartnerNameEN", request.PartnerNameEn, 200);
        AddNullable(command, "@Email", request.Email, 320);
        AddNullable(command, "@Telephone", request.Telephone, 50);
        AddNullable(command, "@AddressText", request.AddressText, 1000);
        AddNullable(command, "@ShortName", request.ShortName, 150);
        AddNullable(command, "@Province", request.Province, 150);

        command.Parameters.Add(
            new SqlParameter("@StartContactDate", SqlDbType.Date)
            {
                Value = request.StartContactDate.HasValue
                    ? request.StartContactDate.Value.Date
                    : DBNull.Value
            });

        AddNullable(command, "@ContactName1", request.ContactName1, 200);
        AddNullable(command, "@ContactPosition1", request.ContactPosition1, 200);
        AddNullable(command, "@ContactPhone1", request.ContactPhone1, 50);
        AddNullable(command, "@ContactEmail1", request.ContactEmail1, 200);

        AddNullable(command, "@ContactName2", request.ContactName2, 200);
        AddNullable(command, "@ContactPosition2", request.ContactPosition2, 200);
        AddNullable(command, "@ContactPhone2", request.ContactPhone2, 50);
        AddNullable(command, "@ContactEmail2", request.ContactEmail2, 200);

        AddNullable(command, "@Remark", request.Remark, 1000);
    }

    private static void AddNullable(
        SqlCommand command,
        string name,
        string? value,
        int size)
    {
        command.Parameters.Add(
            new SqlParameter(name, SqlDbType.NVarChar, size)
            {
                Value = string.IsNullOrWhiteSpace(value)
                    ? DBNull.Value
                    : value.Trim()
            });
    }

    private static string? TrimOrNull(string? value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? null
            : value.Trim();
    }

    private static PartnerResponse ReadPartner(SqlDataReader reader)
    {
        string? N(string name)
        {
            var ordinal = reader.GetOrdinal(name);

            return reader.IsDBNull(ordinal)
                ? null
                : reader.GetString(ordinal);
        }

        var startOrdinal =
            reader.GetOrdinal("StartContactDate");

        return new PartnerResponse
        {
            PartnerId =
                reader.GetInt64(reader.GetOrdinal("PartnerID")),

            PartnerCode =
                reader.GetString(reader.GetOrdinal("PartnerCode")),

            PartnerNameTh =
                reader.GetString(reader.GetOrdinal("PartnerNameTH")),

            PartnerNameEn = N("PartnerNameEN"),
            Email = N("Email"),
            Telephone = N("Telephone"),
            AddressText = N("AddressText"),
            ShortName = N("ShortName"),
            Province = N("Province"),

            StartContactDate =
                reader.IsDBNull(startOrdinal)
                    ? null
                    : reader.GetDateTime(startOrdinal),

            ContactName1 = N("ContactName1"),
            ContactPosition1 = N("ContactPosition1"),
            ContactPhone1 = N("ContactPhone1"),
            ContactEmail1 = N("ContactEmail1"),

            ContactName2 = N("ContactName2"),
            ContactPosition2 = N("ContactPosition2"),
            ContactPhone2 = N("ContactPhone2"),
            ContactEmail2 = N("ContactEmail2"),

            Remark = N("Remark"),

            IsActive =
                reader.GetBoolean(reader.GetOrdinal("IsActive")),

            PartnerAdminUsername = N("PartnerAdminUsername")
            ,PartnerAdminUserId = reader.IsDBNull(reader.GetOrdinal("PartnerAdminUserID")) ? null : reader.GetInt64(reader.GetOrdinal("PartnerAdminUserID"))
        };
    }

    private readonly record struct PartnerScope(
        bool CanReadAll,
        long? PartnerId,
        long? CompanyId);
}
