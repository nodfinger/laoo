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
        ValidateConfiguration(_configuration);

        var username = RequiredValue(_configuration, "SuperAdminUsername");
        var password = RequiredValue(_configuration, "SuperAdminPassword");
        var partnerUsername = RequiredValue(_configuration, "DemoPartnerUsername");
        var partnerPassword = RequiredValue(_configuration, "DemoPartnerPassword");
        var demoUsername = RequiredValue(_configuration, "DemoNormalUsername");
        var demoPassword = RequiredValue(_configuration, "DemoNormalPassword");

        await using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await using var transaction =
            (SqlTransaction)await connection.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

        try
        {
            var partnerId = await EnsurePartnerAsync(connection, transaction, cancellationToken);
            await EnsurePartnerUserAsync(
                connection,
                transaction,
                partnerId,
                partnerUsername,
                partnerPassword,
                cancellationToken);
            var companyId = await EnsureCompanyAsync(connection, transaction, partnerId, cancellationToken);
            var branchId = await EnsureBranchAsync(connection, transaction, companyId, cancellationToken);
            var projectIds = await LoadProjectsAsync(connection, transaction, cancellationToken);

            var laooUserId = await EnsureLaooUserAsync(
                connection,
                transaction,
                username,
                password,
                cancellationToken);

            var demoUserId = await EnsureNormalUserAsync(
                connection,
                transaction,
                companyId,
                branchId,
                demoUsername,
                demoPassword,
                cancellationToken);

            foreach (var projectId in projectIds.Values)
            {
                await EnsureNormalUserProjectAsync(
                    connection,
                    transaction,
                    demoUserId,
                    companyId,
                    projectId,
                    cancellationToken);
            }

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

    public static void ValidateConfiguration(IConfiguration configuration)
    {
        ValidateCredential(configuration, "SuperAdminUsername", "SuperAdminPassword");
        ValidateCredential(configuration, "DemoNormalUsername", "DemoNormalPassword");
        ValidateCredential(configuration, "DemoPartnerUsername", "DemoPartnerPassword");
    }

    private static void ValidateCredential(
        IConfiguration configuration,
        string usernameKey,
        string passwordKey)
    {
        var username = RequiredValue(configuration, usernameKey);
        var password = RequiredValue(configuration, passwordKey);

        if (!PasswordService.MeetsPolicy(username, password))
        {
            throw new InvalidOperationException(
                $"SeedData:{passwordKey} must satisfy the default password policy " +
                "(at least 6 characters with upper-case, lower-case, and special characters).");
        }
    }

    private static string RequiredValue(
        IConfiguration configuration,
        string key)
    {
        var value = configuration[$"SeedData:{key}"]?.Trim();
        return string.IsNullOrWhiteSpace(value)
            ? throw new InvalidOperationException(
                $"SeedData:{key} is required when SeedData:Enabled=true.")
            : value;
    }

    private async Task EnsurePartnerUserAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long partnerId,
        string username,
        string password,
        CancellationToken cancellationToken)
    {
        const string sql = """
        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.TDADPartnerUser WHERE NormalizedUsername = @NormalizedUsername
        )
        BEGIN
            INSERT INTO dbo.TDADPartnerUser
            (
                PartnerID, Username, NormalizedUsername, PasswordHash, DisplayName,
                IsPartnerAdmin, IsActive, FailedLoginCount, CreatedUtc, CreatedBy
            )
            VALUES
            (
                @PartnerID, @Username, @NormalizedUsername, @PasswordHash, N'Demo Partner Admin',
                1, 1, 0, SYSUTCDATETIME(), N'DatabaseSeeder'
            );
        END;
        """;

        var normalized = username.Trim().ToUpperInvariant();
        await ExecuteAsync(
            connection,
            transaction,
            sql,
            [
                new SqlParameter("@PartnerID", partnerId),
                new SqlParameter("@Username", username.Trim()),
                new SqlParameter("@NormalizedUsername", normalized),
                new SqlParameter("@PasswordHash", _passwordService.HashPassword(normalized, password))
            ],
            cancellationToken);
    }

    private async Task<long> EnsureNormalUserAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long companyId,
        long branchId,
        string username,
        string password,
        CancellationToken cancellationToken)
    {
        const string sql = """
        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.TDADUser WHERE NormalizedUsername = @NormalizedUsername
        )
        BEGIN
            INSERT INTO dbo.TDADUser
            (
                CompanyID, Username, NormalizedUsername, PasswordHash, DisplayName,
                IsActive, FailedLoginCount, LastPasswordChangeDate, CreateDate
            )
            VALUES
            (
                @CompanyID, @Username, @NormalizedUsername, @PasswordHash, N'Demo Admin',
                1, 0, SYSUTCDATETIME(), SYSUTCDATETIME()
            );
        END;
        SELECT UserID FROM dbo.TDADUser WHERE NormalizedUsername = @NormalizedUsername;
        """;

        var normalized = username.Trim().ToUpperInvariant();
        var userId = await ScalarIdAsync(
            connection,
            transaction,
            sql,
            [
                new SqlParameter("@CompanyID", companyId),
                new SqlParameter("@Username", username.Trim()),
                new SqlParameter("@NormalizedUsername", normalized),
                new SqlParameter("@PasswordHash", _passwordService.HashPassword(normalized, password))
            ],
            cancellationToken);

        const string branchSql = """
        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.TDADUserBranch
            WHERE UserID = @UserID AND CompanyID = @CompanyID AND BranchID = @BranchID
        )
        BEGIN
            INSERT INTO dbo.TDADUserBranch
            (UserID, CompanyID, BranchID, IsDefault, IsActive, CreateDate)
            VALUES (@UserID, @CompanyID, @BranchID, 1, 1, SYSUTCDATETIME());
        END;
        """;

        await ExecuteAsync(
            connection,
            transaction,
            branchSql,
            [
                new SqlParameter("@UserID", userId),
                new SqlParameter("@CompanyID", companyId),
                new SqlParameter("@BranchID", branchId)
            ],
            cancellationToken);

        return userId;
    }

    private static async Task EnsureNormalUserProjectAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long userId,
        long companyId,
        long projectId,
        CancellationToken cancellationToken)
    {
        const string sql = """
        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.TDADUserProject
            WHERE UserID = @UserID AND CompanyID = @CompanyID AND ProjectID = @ProjectID
        )
        BEGIN
            INSERT INTO dbo.TDADUserProject
            (CompanyID, UserID, ProjectID, IsDefault, IsActive, CreateDate)
            VALUES (@CompanyID, @UserID, @ProjectID, 1, 1, SYSUTCDATETIME());
        END;
        """;

        await ExecuteAsync(
            connection,
            transaction,
            sql,
            [
                new SqlParameter("@UserID", userId),
                new SqlParameter("@CompanyID", companyId),
                new SqlParameter("@ProjectID", projectId)
            ],
            cancellationToken);
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
        IF NOT EXISTS (SELECT 1 FROM dbo.TDSTCompanySetUp WHERE CompanyCode = N'DEMO')
        BEGIN
            DECLARE @CompanyID bigint = ISNULL((SELECT MAX(CompanyID) FROM dbo.TDSTCompanySetUp WITH (UPDLOCK, HOLDLOCK)), 0) + 1;
            INSERT INTO dbo.TDSTCompanySetUp
            (
                CompanyID, PartnerID, CompanyCode, CustomerNameTH, CustomerNameEN,
                Name, TitleHeader, RowSTD, RowCardSTD, TimeAlert, OrgStructureType,
                OwnerType, IsActive, CreateDate
            )
            VALUES
            (
                @CompanyID, @PartnerID, N'DEMO', N'Demo Company Laoo', N'Laoo Demo Company',
                N'Demo Company Laoo', N'Laoo Demo Company', 30, 30, 5, 1, N'C', 1, SYSUTCDATETIME()
            );
        END;

        SELECT CompanyID
        FROM dbo.TDSTCompanySetUp
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

    private static async Task ExecuteAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string sql,
        IEnumerable<SqlParameter> parameters,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.AddRange(parameters.ToArray());
        await command.ExecuteNonQueryAsync(cancellationToken);
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
