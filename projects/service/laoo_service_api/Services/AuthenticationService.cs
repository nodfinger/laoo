using System.Data;
using LaooServiceApi.Data;
using LaooServiceApi.Models;
using LaooServiceApi.Security;
using Microsoft.Data.SqlClient;

namespace LaooServiceApi.Services;

public sealed class AuthenticationService
{
    private const int MaxFailedAttempts = 5;
    private const int LockoutMinutes = 15;
    private readonly SqlConnectionFactory _connections;
    private readonly PasswordService _passwords;
    private readonly JwtTokenService _tokens;

    public AuthenticationService(
        SqlConnectionFactory connections,
        PasswordService passwords,
        JwtTokenService tokens)
    {
        _connections = connections;
        _passwords = passwords;
        _tokens = tokens;
    }

    public async Task<LoginResponse> LoginAsync(
        LoginRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Username) ||
            string.IsNullOrWhiteSpace(request.Password) ||
            string.IsNullOrWhiteSpace(request.ProjectCode))
        {
            return InvalidCredentials();
        }

        var username = request.Username.Trim().ToUpperInvariant();
        var projectCode = request.ProjectCode.Trim().ToUpperInvariant();
        await using var connection = _connections.CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var project = await FindProjectAsync(
            connection,
            projectCode,
            cancellationToken);
        if (project is null)
        {
            return InvalidCredentials();
        }

        AuthenticatedUser? authenticated = null;
        var laoo = await FindLaooUserAsync(
            connection,
            username,
            project.Value.Id,
            cancellationToken);

        if (laoo is not null)
        {
            if (!await ValidatePasswordAsync(
                connection,
                AccountType.Laoo,
                laoo.Id,
                request.Password,
                cancellationToken))
            {
                return InvalidCredentials();
            }

            authenticated = new AuthenticatedUser(
                $"laoo:{laoo.Id}",
                "LAOO_SUPPORT",
                "LAOO",
                laoo.Id,
                null,
                null,
                null,
                null,
                null,
                project.Value.Id,
                project.Value.Code,
                laoo.Username,
                laoo.DisplayName,
                laoo.CanLoginAsUser && laoo.ProjectCanLoginAsUser);
        }

        if (authenticated is null)
        {
            var partner = await FindPartnerUserAsync(
                connection,
                username,
                project.Value.Id,
                cancellationToken);
            if (partner is not null)
            {
                if (!await ValidatePasswordAsync(
                    connection,
                    AccountType.Partner,
                    partner.Id,
                    request.Password,
                    cancellationToken))
                {
                    return InvalidCredentials();
                }

                authenticated = new AuthenticatedUser(
                    $"partner:{partner.Id}",
                    "PARTNER_USER",
                    "PARTNER",
                    null,
                    partner.Id,
                    partner.PartnerId,
                    null,
                    null,
                    null,
                    project.Value.Id,
                    project.Value.Code,
                    partner.Username,
                    partner.DisplayName,
                    false);
            }
        }

        if (authenticated is null)
        {
            var company = await FindCompanyUserAsync(
                connection,
                username,
                project.Value.Id,
                cancellationToken);
            if (company is null ||
                !await ValidatePasswordAsync(
                    connection,
                    AccountType.Company,
                    company.Id,
                    request.Password,
                    cancellationToken))
            {
                return InvalidCredentials();
            }

            authenticated = new AuthenticatedUser(
                $"user:{company.Id}",
                "COMPANY_USER",
                "USER",
                null,
                null,
                company.PartnerId,
                company.Id,
                company.CompanyId,
                company.BranchId,
                project.Value.Id,
                project.Value.Code,
                company.Username,
                company.DisplayName,
                false);
        }

        var token = _tokens.CreateToken(authenticated);
        return new LoginResponse(
            true,
            "เข้าสู่ระบบสำเร็จ",
            token.AccessToken,
            token.ExpiresAt,
            new LoginUserResponse(
                authenticated.UserType,
                authenticated.LoginMode,
                authenticated.LaooUserId,
                authenticated.PartnerUserId,
                authenticated.PartnerId,
                authenticated.UserId,
                authenticated.CompanyId,
                authenticated.BranchId,
                authenticated.ProjectId,
                authenticated.ProjectCode,
                authenticated.Username,
                authenticated.DisplayName,
                authenticated.CanLoginAsUser,
                false));
    }

    private async Task<bool> ValidatePasswordAsync(
        SqlConnection connection,
        AccountType accountType,
        long accountId,
        string suppliedPassword,
        CancellationToken cancellationToken)
    {
        await using var transaction = (SqlTransaction)await connection
            .BeginTransactionAsync(IsolationLevel.ReadCommitted, cancellationToken);
        try
        {
            var state = await ReadAccountStateAsync(
                connection, transaction, accountType, accountId, cancellationToken);
            if (state is null ||
                (state.LockedUntil.HasValue && state.LockedUntil.Value > DateTime.UtcNow))
            {
                await transaction.RollbackAsync(cancellationToken);
                return false;
            }

            if (!_passwords.VerifyPassword(
                    state.Username, state.PasswordHash, suppliedPassword))
            {
                await RegisterFailedLoginAsync(
                    connection, transaction, accountType, accountId, cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return false;
            }

            await RegisterSuccessfulLoginAsync(
                connection, transaction, accountType, accountId, cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return true;
        }
        catch
        {
            if (transaction.Connection is not null)
            {
                await transaction.RollbackAsync(CancellationToken.None);
            }

            throw;
        }
    }

    private static async Task<AccountState?> ReadAccountStateAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        AccountType accountType,
        long accountId,
        CancellationToken cancellationToken)
    {
        var columns = accountType switch
        {
            AccountType.Laoo =>
                ("TDADLaooUser", "LaooUserID", "LockedUntil"),
            AccountType.Partner =>
                ("TDADPartnerUser", "PartnerUserID", "LockedUntilUtc"),
            AccountType.Company =>
                ("TDADUser", "UserID", "LockedUntil"),
            _ => throw new ArgumentOutOfRangeException(nameof(accountType))
        };
        var sql = $"""
            SELECT Username, PasswordHash, {columns.Item3}
            FROM dbo.{columns.Item1} WITH (UPDLOCK, ROWLOCK)
            WHERE {columns.Item2} = @AccountID
              AND IsActive = 1;
            """;
        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.Add("@AccountID", SqlDbType.BigInt).Value = accountId;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new AccountState(
            reader.GetString(0),
            reader.GetString(1),
            reader.IsDBNull(2) ? null : reader.GetDateTime(2));
    }

    private static LoginResponse InvalidCredentials() =>
        Failed("ชื่อผู้ใช้ รหัสผ่าน หรือโครงการไม่ถูกต้อง");

    private static LoginResponse Failed(string message) =>
        new(false, message, null, null, null);

    private static async Task<(long Id, string Code)?> FindProjectAsync(
        SqlConnection connection,
        string projectCode,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT TOP (1) ProjectID, ProjectCode
            FROM dbo.TDADProject
            WHERE ProjectCode = @ProjectCode
              AND IsActive = 1;
            """;
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@ProjectCode", projectCode);
        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken)
            ? (reader.GetInt64(0), reader.GetString(1))
            : null;
    }

    private static async Task<LaooRow?> FindLaooUserAsync(
        SqlConnection connection,
        string username,
        long projectId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT TOP (1)
                u.LaooUserID, u.Username, u.PasswordHash, u.DisplayName,
                u.CanLoginAsUser, userProject.CanLoginAsUser, u.LockedUntil
            FROM dbo.TDADLaooUser AS u
            INNER JOIN dbo.TDADLaooUserProject AS userProject
                ON userProject.LaooUserID = u.LaooUserID
               AND userProject.ProjectID = @ProjectID
               AND userProject.IsActive = 1
               AND userProject.CanAccess = 1
            WHERE u.NormalizedUsername = @Username
              AND u.IsSupportUser = 1
              AND u.IsActive = 1;
            """;
        await using var command = new SqlCommand(sql, connection);
        AddIdentityParameters(command, username, projectId);
        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new LaooRow(
            reader.GetInt64(0),
            reader.GetString(1),
            reader.GetString(2),
            reader.GetString(3),
            reader.GetBoolean(4),
            reader.GetBoolean(5),
            reader.IsDBNull(6) ? null : reader.GetDateTime(6));
    }

    private static async Task<PartnerRow?> FindPartnerUserAsync(
        SqlConnection connection,
        string username,
        long projectId,
        CancellationToken cancellationToken)
    {
        var sql = $$"""
            SELECT TOP (1)
                u.PartnerUserID, u.PartnerID, u.Username, u.PasswordHash,
                u.DisplayName, u.LockedUntilUtc
            FROM dbo.TDADPartnerUser AS u
            INNER JOIN dbo.TDADPartner AS partner
                ON partner.PartnerID = u.PartnerID
               AND partner.IsActive = 1
            INNER JOIN dbo.TDADProject AS project
                ON project.ProjectID = @ProjectID
               AND project.IsActive = 1
            WHERE u.NormalizedUsername = @Username
              AND u.IsActive = 1
              AND {{AuthenticationProjectAccess.PartnerSql}};
            """;
        await using var command = new SqlCommand(sql, connection);
        AddIdentityParameters(command, username, projectId);
        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        return new PartnerRow(
            reader.GetInt64(0),
            reader.GetInt64(1),
            reader.GetString(2),
            reader.GetString(3),
            reader.GetString(4),
            reader.IsDBNull(5) ? null : reader.GetDateTime(5));
    }

    private static async Task<CompanyRow?> FindCompanyUserAsync(
        SqlConnection connection,
        string username,
        long projectId,
        CancellationToken cancellationToken)
    {
        var sql = $$"""
            SELECT TOP (2)
                u.UserID, company.PartnerID, u.CompanyID, branch.BranchID,
                u.Username, u.PasswordHash,
                CASE WHEN employee.EmployeeID IS NULL THEN u.DisplayName
                     ELSE employee.FullName + CASE WHEN NULLIF(LTRIM(RTRIM(employee.NickName)), N'') IS NULL THEN N'' ELSE N' | ' + employee.NickName END
                END AS DisplayName,
                u.LockedUntil
            FROM dbo.TDADUser AS u
            INNER JOIN dbo.TDSTCompanySetUp AS company
                ON company.CompanyID = u.CompanyID
               AND company.IsActive = 1
            INNER JOIN dbo.TDADPartner AS partner
                ON partner.PartnerID = company.PartnerID
               AND partner.IsActive = 1
            INNER JOIN dbo.TDADProject AS project
                ON project.ProjectID = @ProjectID
               AND project.IsActive = 1
            OUTER APPLY
            (
                SELECT TOP (1) userBranch.BranchID
                FROM dbo.TDADUserBranch AS userBranch
                INNER JOIN dbo.TDADBranch AS activeBranch
                    ON activeBranch.BranchID = userBranch.BranchID
                   AND activeBranch.CompanyID = userBranch.CompanyID
                   AND activeBranch.IsActive = 1
                WHERE userBranch.UserID = u.UserID
                  AND userBranch.CompanyID = u.CompanyID
                  AND userBranch.IsActive = 1
                ORDER BY userBranch.IsDefault DESC, userBranch.UserBranchID
            ) AS branch
            OUTER APPLY
            (
                SELECT TOP (1) employee.EmployeeID, employee.FullName, employee.NickName
                FROM dbo.TDADUserEmployee AS userEmployee
                INNER JOIN dbo.TDADEmployee AS employee
                    ON employee.EmployeeID = userEmployee.EmployeeID
                   AND employee.CompanyID = u.CompanyID
                   AND employee.IsActive = 1
                WHERE userEmployee.UserID = u.UserID
                  AND userEmployee.CompanyID = u.CompanyID
                ORDER BY employee.EmployeeID
            ) AS employee
            WHERE u.NormalizedUsername = @Username
              AND u.IsActive = 1
              AND {{AuthenticationProjectAccess.CompanySql}};
            """;
        await using var command = new SqlCommand(sql, connection);
        AddIdentityParameters(command, username, projectId);
        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return null;
        var result = new CompanyRow(
            reader.GetInt64(0),
            reader.GetInt64(1),
            reader.GetInt64(2),
            reader.IsDBNull(3) ? null : reader.GetInt64(3),
            reader.GetString(4),
            reader.GetString(5),
            reader.GetString(6),
            reader.IsDBNull(7) ? null : reader.GetDateTime(7));
        if (await reader.ReadAsync(cancellationToken)) return null;
        return result;
    }

    private static async Task RegisterFailedLoginAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        AccountType accountType,
        long accountId,
        CancellationToken cancellationToken)
    {
        var sql = accountType switch
        {
            AccountType.Laoo => """
                UPDATE dbo.TDADLaooUser
                SET FailedLoginCount = FailedLoginCount + 1,
                    LockedUntil = CASE WHEN FailedLoginCount + 1 >= @MaxAttempts
                        THEN DATEADD(MINUTE, @LockoutMinutes, SYSUTCDATETIME())
                        ELSE LockedUntil END,
                    UpdateDate = SYSUTCDATETIME()
                WHERE LaooUserID = @AccountID AND IsActive = 1;
                """,
            AccountType.Partner => """
                UPDATE dbo.TDADPartnerUser
                SET FailedLoginCount = FailedLoginCount + 1,
                    LockedUntilUtc = CASE WHEN FailedLoginCount + 1 >= @MaxAttempts
                        THEN DATEADD(MINUTE, @LockoutMinutes, SYSUTCDATETIME())
                        ELSE LockedUntilUtc END,
                    UpdatedUtc = SYSUTCDATETIME(),
                    UpdatedBy = N'AuthenticationService'
                WHERE PartnerUserID = @AccountID AND IsActive = 1;
                """,
            AccountType.Company => """
                UPDATE dbo.TDADUser
                SET FailedLoginCount = FailedLoginCount + 1,
                    LockedUntil = CASE WHEN FailedLoginCount + 1 >= @MaxAttempts
                        THEN DATEADD(MINUTE, @LockoutMinutes, SYSUTCDATETIME())
                        ELSE LockedUntil END,
                    UpdateDate = SYSUTCDATETIME()
                WHERE UserID = @AccountID AND IsActive = 1;
                """,
            _ => throw new ArgumentOutOfRangeException(nameof(accountType))
        };

        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("@AccountID", accountId);
        command.Parameters.AddWithValue("@MaxAttempts", MaxFailedAttempts);
        command.Parameters.AddWithValue("@LockoutMinutes", LockoutMinutes);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task RegisterSuccessfulLoginAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        AccountType accountType,
        long accountId,
        CancellationToken cancellationToken)
    {
        var sql = accountType switch
        {
            AccountType.Laoo => """
                UPDATE dbo.TDADLaooUser
                SET FailedLoginCount = 0, LockedUntil = NULL,
                    LastLoginDate = SYSUTCDATETIME(), UpdateDate = SYSUTCDATETIME()
                WHERE LaooUserID = @AccountID AND IsActive = 1;
                """,
            AccountType.Partner => """
                UPDATE dbo.TDADPartnerUser
                SET FailedLoginCount = 0, LockedUntilUtc = NULL,
                    LastLoginUtc = SYSUTCDATETIME(),
                    UpdatedUtc = SYSUTCDATETIME(),
                    UpdatedBy = N'AuthenticationService'
                WHERE PartnerUserID = @AccountID AND IsActive = 1;
                """,
            AccountType.Company => """
                UPDATE dbo.TDADUser
                SET FailedLoginCount = 0, LockedUntil = NULL,
                    LastLoginDate = SYSUTCDATETIME(), UpdateDate = SYSUTCDATETIME()
                WHERE UserID = @AccountID AND IsActive = 1;
                """,
            _ => throw new ArgumentOutOfRangeException(nameof(accountType))
        };

        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("@AccountID", accountId);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static void AddIdentityParameters(
        SqlCommand command,
        string username,
        long projectId)
    {
        command.Parameters.AddWithValue("@Username", username);
        command.Parameters.AddWithValue("@ProjectID", projectId);
    }

    private enum AccountType { Laoo, Partner, Company }
    private sealed record AccountState(
        string Username,
        string PasswordHash,
        DateTime? LockedUntil);
    private sealed record LaooRow(
        long Id,
        string Username,
        string PasswordHash,
        string DisplayName,
        bool CanLoginAsUser,
        bool ProjectCanLoginAsUser,
        DateTime? LockedUntil);
    private sealed record PartnerRow(
        long Id,
        long PartnerId,
        string Username,
        string PasswordHash,
        string DisplayName,
        DateTime? LockedUntil);
    private sealed record CompanyRow(
        long Id,
        long PartnerId,
        long CompanyId,
        long? BranchId,
        string Username,
        string PasswordHash,
        string DisplayName,
        DateTime? LockedUntil);
}
