using System.Data;
using LaooApi.Data;
using LaooApi.Security;
using Microsoft.Data.SqlClient;

namespace LaooApi.Services;

public sealed class DatabaseSeeder
{
    private readonly SqlConnectionFactory _connectionFactory;
    private readonly PasswordService _passwordService;
    private readonly IConfiguration _configuration;
    private readonly ILogger<DatabaseSeeder> _logger;

    public DatabaseSeeder(
        SqlConnectionFactory connectionFactory,
        PasswordService passwordService,
        IConfiguration configuration,
        ILogger<DatabaseSeeder> logger)
    {
        _connectionFactory = connectionFactory;
        _passwordService = passwordService;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        var username = _configuration["SeedData:SuperAdminUsername"] ?? "t";
        var password = _configuration["SeedData:SuperAdminPassword"] ?? "t";

        await using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await using var transaction =
            (SqlTransaction)await connection.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

        try
        {
            var partnerId = await EnsurePartnerAsync(connection, transaction, cancellationToken);
            var companyId = await EnsureCompanyAsync(connection, transaction, partnerId, cancellationToken);
            var branchId = await EnsureBranchAsync(connection, transaction, companyId, cancellationToken);
            var projectIds = await LoadProjectsAsync(connection, transaction, cancellationToken);

            var laooUserId = await EnsureLaooUserAsync(
                connection,
                transaction,
                username,
                password,
                cancellationToken);

            foreach (var projectId in projectIds.Values)
            {
                await EnsureLaooProjectAccessAsync(
                    connection,
                    transaction,
                    laooUserId,
                    projectId,
                    cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);

            _logger.LogWarning(
                "Seed สำเร็จ: Super Admin Username={Username}",
                username);
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    private static async Task<long> EnsurePartnerAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        CancellationToken cancellationToken)
    {
        const string sql = """
        IF NOT EXISTS (SELECT 1 FROM dbo.TDADPartner WHERE PartnerCode = N'LAOO')
        BEGIN
            INSERT INTO dbo.TDADPartner
            (
                PartnerCode, PartnerNameTH, PartnerNameEN, Email, IsActive
            )
            VALUES
            (
                N'LAOO', N'Laoo Solutions', N'Laoo Solutions',
                N'support@laoo.local', 1
            );
        END;

        SELECT PartnerID
        FROM dbo.TDADPartner
        WHERE PartnerCode = N'LAOO';
        """;

        return await ScalarIdAsync(connection, transaction, sql, [], cancellationToken);
    }

    private static async Task<long> EnsureCompanyAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long partnerId,
        CancellationToken cancellationToken)
    {
        const string sql = """
        IF NOT EXISTS (SELECT 1 FROM dbo.TDADCompany WHERE CompanyCode = N'DEMO')
        BEGIN
            INSERT INTO dbo.TDADCompany
            (
                PartnerID, CompanyCode, CompanyNameTH, CompanyNameEN, IsActive
            )
            VALUES
            (
                @PartnerID, N'DEMO', N'บริษัทตัวอย่าง Laoo',
                N'Laoo Demo Company', 1
            );
        END;

        SELECT CompanyID
        FROM dbo.TDADCompany
        WHERE CompanyCode = N'DEMO';
        """;

        return await ScalarIdAsync(
            connection,
            transaction,
            sql,
            [new SqlParameter("@PartnerID", partnerId)],
            cancellationToken);
    }

    private static async Task<long> EnsureBranchAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long companyId,
        CancellationToken cancellationToken)
    {
        const string sql = """
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.TDADBranch
            WHERE CompanyID = @CompanyID
              AND BranchCode = N'HO'
        )
        BEGIN
            INSERT INTO dbo.TDADBranch
            (
                CompanyID, BranchCode, BranchNameTH, BranchNameEN, IsActive
            )
            VALUES
            (
                @CompanyID, N'HO', N'สำนักงานใหญ่', N'Head Office', 1
            );
        END;

        SELECT BranchID
        FROM dbo.TDADBranch
        WHERE CompanyID = @CompanyID
          AND BranchCode = N'HO';
        """;

        return await ScalarIdAsync(
            connection,
            transaction,
            sql,
            [new SqlParameter("@CompanyID", companyId)],
            cancellationToken);
    }

    private static async Task<Dictionary<string, long>> LoadProjectsAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        CancellationToken cancellationToken)
    {
        const string sql = """
        SELECT ProjectID, ProjectCode
        FROM dbo.TDADProject
        WHERE ProjectCode IN (N'LAOO', N'LAOO_MEETING')
          AND IsActive = 1;
        """;

        await using var command = new SqlCommand(sql, connection, transaction);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var result = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);

        while (await reader.ReadAsync(cancellationToken))
        {
            result[reader.GetString(1)] = reader.GetInt64(0);
        }

        if (!result.ContainsKey("LAOO") || !result.ContainsKey("LAOO_MEETING"))
        {
            throw new InvalidOperationException(
                "ไม่พบ Project LAOO หรือ LAOO_MEETING");
        }

        return result;
    }

    private async Task<long> EnsureLaooUserAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string username,
        string password,
        CancellationToken cancellationToken)
    {
        var normalized = username.Trim().ToUpperInvariant();

        const string findSql = """
        SELECT LaooUserID
        FROM dbo.TDADLaooUser
        WHERE NormalizedUsername = @NormalizedUsername;
        """;

        var existing = await OptionalIdAsync(
            connection,
            transaction,
            findSql,
            [new SqlParameter("@NormalizedUsername", normalized)],
            cancellationToken);

        if (existing.HasValue)
        {
            return existing.Value;
        }

        var hash = _passwordService.HashPassword(normalized, password);

        const string insertSql = """
        INSERT INTO dbo.TDADLaooUser
        (
            Username,
            NormalizedUsername,
            PasswordHash,
            DisplayName,
            Email,
            IsSupportUser,
            CanLoginAsUser,
            IsActive,
            LastPasswordChangeDate
        )
        VALUES
        (
            @Username,
            @NormalizedUsername,
            @PasswordHash,
            N'Laoo Super Admin',
            N'support@laoo.local',
            1,
            1,
            1,
            SYSUTCDATETIME()
        );

        SELECT CAST(SCOPE_IDENTITY() AS BIGINT);
        """;

        return await ScalarIdAsync(
            connection,
            transaction,
            insertSql,
            [
                new SqlParameter("@Username", username.Trim()),
                new SqlParameter("@NormalizedUsername", normalized),
                new SqlParameter("@PasswordHash", hash)
            ],
            cancellationToken);
    }

    private static async Task EnsureLaooProjectAccessAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long laooUserId,
        long projectId,
        CancellationToken cancellationToken)
    {
        const string sql = """
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.TDADLaooUserProject
            WHERE LaooUserID = @LaooUserID
              AND ProjectID = @ProjectID
        )
        BEGIN
            INSERT INTO dbo.TDADLaooUserProject
            (
                LaooUserID,
                ProjectID,
                CanAccess,
                CanLoginAsUser,
                IsActive
            )
            VALUES
            (
                @LaooUserID,
                @ProjectID,
                1,
                1,
                1
            );
        END;
        """;

        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("@LaooUserID", laooUserId);
        command.Parameters.AddWithValue("@ProjectID", projectId);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task<long> ScalarIdAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string sql,
        IEnumerable<SqlParameter> parameters,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.AddRange(parameters.ToArray());

        var value = await command.ExecuteScalarAsync(cancellationToken);

        return value is null || value is DBNull
            ? throw new InvalidOperationException("SQL ไม่คืนค่า ID")
            : Convert.ToInt64(value);
    }

    private static async Task<long?> OptionalIdAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string sql,
        IEnumerable<SqlParameter> parameters,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.AddRange(parameters.ToArray());

        var value = await command.ExecuteScalarAsync(cancellationToken);

        return value is null || value is DBNull
            ? null
            : Convert.ToInt64(value);
    }
}
