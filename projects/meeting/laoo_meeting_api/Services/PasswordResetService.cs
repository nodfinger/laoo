using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using LaooMeetingApi.Data;
using LaooMeetingApi.Security;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Services;

public sealed class PasswordResetService(
    SqlConnectionFactory connectionFactory,
    PasswordService passwordService,
    CompanySetupSecretService secretService)
{
    public enum RequestResult
    {
        NotFound,
        EmailMissing,
        Sent
    }

    private readonly SqlConnectionFactory _db = connectionFactory;
    private readonly PasswordService _passwords = passwordService;
    private readonly CompanySetupSecretService _secrets = secretService;

    public async Task<RequestResult> RequestAsync(
        string username,
        string? projectCode,
        string? ip,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(username) ||
            string.IsNullOrWhiteSpace(projectCode))
        {
            return RequestResult.NotFound;
        }

        await using var connection = _db.CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var account = await FindAccountAsync(
            connection,
            username.Trim().ToUpperInvariant(),
            projectCode.Trim().ToUpperInvariant(),
            cancellationToken);

        if (account is null)
        {
            return RequestResult.NotFound;
        }

        if (string.IsNullOrWhiteSpace(account.Email))
        {
            return RequestResult.EmailMissing;
        }

        var rawToken = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var tokenHash = SHA256.HashData(Encoding.UTF8.GetBytes(rawToken));

        await using var transaction =
            (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        try
        {
            const string expireExistingSql = """
                UPDATE dbo.TDADPasswordResetToken
                SET UsedAt = SYSUTCDATETIME()
                WHERE UserType = @UserType
                  AND SubjectID = @SubjectID
                  AND ProjectID = @ProjectID
                  AND UsedAt IS NULL;
                """;

            await using (var expire = new SqlCommand(
                expireExistingSql,
                connection,
                transaction))
            {
                Add(expire, "@UserType", account.UserType);
                Add(expire, "@SubjectID", account.SubjectId);
                Add(expire, "@ProjectID", account.ProjectId);
                await expire.ExecuteNonQueryAsync(cancellationToken);
            }

            const string insertSql = """
                INSERT dbo.TDADPasswordResetToken
                (
                    UserType, SubjectID, ProjectID, PartnerID, CompanyID,
                    Username, Email, TokenHash, ExpiresAt, RequestIP
                )
                VALUES
                (
                    @UserType, @SubjectID, @ProjectID, @PartnerID, @CompanyID,
                    @Username, @Email, @TokenHash,
                    DATEADD(MINUTE, 15, SYSUTCDATETIME()), @RequestIP
                );
                """;

            await using (var insert = new SqlCommand(
                insertSql,
                connection,
                transaction))
            {
                Add(insert, "@UserType", account.UserType);
                Add(insert, "@SubjectID", account.SubjectId);
                Add(insert, "@ProjectID", account.ProjectId);
                Add(insert, "@PartnerID", account.PartnerId);
                Add(insert, "@CompanyID", account.CompanyId);
                Add(insert, "@Username", account.Username);
                Add(insert, "@Email", account.Email);
                Add(insert, "@TokenHash", tokenHash);
                Add(insert, "@RequestIP", ip);
                await insert.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            if (transaction.Connection is not null)
            {
                await transaction.RollbackAsync(CancellationToken.None);
            }

            throw;
        }

        await SendEmailAsync(
            account.Email,
            rawToken,
            account.UserType,
            account.PartnerId,
            account.CompanyId,
            cancellationToken);

        return RequestResult.Sent;
    }

    public async Task<bool> ConfirmAsync(
        string token,
        string newPassword,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(token) ||
            string.IsNullOrWhiteSpace(newPassword))
        {
            return false;
        }

        var tokenHash = SHA256.HashData(Encoding.UTF8.GetBytes(token.Trim()));
        await using var connection = _db.CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction =
            (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        try
        {
            ResetTokenRow? resetToken = null;
            const string selectSql = """
                SELECT TOP (1)
                    PasswordResetTokenID, UserType, SubjectID,
                    ProjectID, Username
                FROM dbo.TDADPasswordResetToken WITH (UPDLOCK, ROWLOCK)
                WHERE TokenHash = @TokenHash
                  AND UsedAt IS NULL
                  AND ExpiresAt > SYSUTCDATETIME();
                """;

            await using (var select = new SqlCommand(
                selectSql,
                connection,
                transaction))
            {
                Add(select, "@TokenHash", tokenHash);
                await using var reader =
                    await select.ExecuteReaderAsync(cancellationToken);

                if (await reader.ReadAsync(cancellationToken) &&
                    !reader.IsDBNull(3))
                {
                    resetToken = new ResetTokenRow(
                        reader.GetInt64(0),
                        reader.GetString(1),
                        reader.GetString(2),
                        reader.GetInt64(3),
                        reader.GetString(4));
                }
            }

            var policyCode = resetToken is not null && long.TryParse(resetToken.SubjectId, out var policySubjectId)
                ? await _passwords.GetPolicyForAccountAsync(connection, resetToken.UserType, policySubjectId, cancellationToken)
                : PasswordService.DefaultPolicyCode;
            if (resetToken is null ||
                !long.TryParse(resetToken.SubjectId, out var subjectId) ||
                !PasswordService.MeetsPolicy(resetToken.Username, newPassword, policyCode))
            {
                await transaction.RollbackAsync(CancellationToken.None);
                return false;
            }

            var passwordHash =
                _passwords.HashPassword(resetToken.Username, newPassword);
            var updateSql = GetPasswordUpdateSql(resetToken.UserType);

            if (updateSql is null)
            {
                await transaction.RollbackAsync(CancellationToken.None);
                return false;
            }

            await using (var update = new SqlCommand(
                updateSql,
                connection,
                transaction))
            {
                Add(update, "@PasswordHash", passwordHash);
                Add(update, "@SubjectID", subjectId);
                Add(update, "@ProjectID", resetToken.ProjectId);

                if (await update.ExecuteNonQueryAsync(cancellationToken) != 1)
                {
                    await transaction.RollbackAsync(CancellationToken.None);
                    return false;
                }
            }

            const string markUsedSql = """
                UPDATE dbo.TDADPasswordResetToken
                SET UsedAt = SYSUTCDATETIME()
                WHERE PasswordResetTokenID = @TokenID
                  AND UsedAt IS NULL;
                """;

            await using (var markUsed = new SqlCommand(
                markUsedSql,
                connection,
                transaction))
            {
                Add(markUsed, "@TokenID", resetToken.TokenId);

                if (await markUsed.ExecuteNonQueryAsync(cancellationToken) != 1)
                {
                    await transaction.RollbackAsync(CancellationToken.None);
                    return false;
                }
            }

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

    private static async Task<ResetAccountRow?> FindAccountAsync(
        SqlConnection connection,
        string normalizedUsername,
        string projectCode,
        CancellationToken cancellationToken)
    {
        const string sql = """
            DECLARE @ProjectID BIGINT =
            (
                SELECT TOP (1) ProjectID
                FROM dbo.TDADProject
                WHERE ProjectCode = @ProjectCode
                  AND IsActive = 1
            );

            SELECT TOP (1)
                UserType, SubjectID, ProjectID, PartnerID, CompanyID,
                Username, Email
            FROM
            (
                SELECT
                    1 AS Priority,
                    N'LAOO_SUPPORT' AS UserType,
                    CONVERT(nvarchar(100), U.LaooUserID) AS SubjectID,
                    @ProjectID AS ProjectID,
                    CONVERT(bigint, NULL) AS PartnerID,
                    CONVERT(bigint, NULL) AS CompanyID,
                    U.Username,
                    U.Email
                FROM dbo.TDADLaooUser AS U
                INNER JOIN dbo.TDADLaooUserProject AS UP
                    ON UP.LaooUserID = U.LaooUserID
                   AND UP.ProjectID = @ProjectID
                   AND UP.IsActive = 1
                   AND UP.CanAccess = 1
                WHERE U.NormalizedUsername = @NormalizedUsername
                  AND U.IsSupportUser = 1
                  AND U.IsActive = 1

                UNION ALL

                SELECT
                    2,
                    N'PARTNER_USER',
                    CONVERT(nvarchar(100), U.PartnerUserID),
                    @ProjectID,
                    U.PartnerID,
                    CONVERT(bigint, NULL),
                    U.Username,
                    U.Email
                FROM dbo.TDADPartnerUser AS U
                INNER JOIN dbo.TDADPartner AS Partner
                    ON Partner.PartnerID = U.PartnerID
                   AND Partner.IsActive = 1
                WHERE U.NormalizedUsername = @NormalizedUsername
                  AND U.IsActive = 1
                  AND
                  (
                      EXISTS
                      (
                          SELECT 1
                          FROM dbo.TDADPartnerUserPermission AS UP
                          INNER JOIN dbo.TDADPermission AS Permission
                              ON Permission.PermissionID = UP.PermissionID
                             AND Permission.ProjectID = UP.ProjectID
                             AND Permission.IsActive = 1
                          WHERE UP.PartnerUserID = U.PartnerUserID
                            AND UP.ProjectID = @ProjectID
                            AND UP.IsAllowed = 1
                            AND UP.IsActive = 1
                      )
                      OR EXISTS
                      (
                          SELECT 1
                          FROM dbo.TDADPartnerUserEmployee AS PUE
                          INNER JOIN dbo.TDADEmployee AS E
                              ON E.EmployeeID = PUE.EmployeeID
                             AND E.PartnerID = U.PartnerID
                             AND E.IsActive = 1
                          INNER JOIN dbo.TDADEmployeeRoleGroup AS ERG
                              ON ERG.EmployeeID = E.EmployeeID
                             AND ERG.IsActive = 1
                             AND ERG.EffectiveFrom <= CONVERT(date, SYSUTCDATETIME())
                             AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo >= CONVERT(date, SYSUTCDATETIME()))
                          INNER JOIN dbo.TDADRoleGroup AS RG
                              ON RG.RoleGroupID = ERG.RoleGroupID
                             AND RG.ProjectID = @ProjectID
                             AND RG.ScopeType = 'P'
                             AND RG.PartnerID = U.PartnerID
                             AND RG.IsActive = 1
                          INNER JOIN dbo.TDADRoleGroupPermission AS RGP
                              ON RGP.RoleGroupID = RG.RoleGroupID
                             AND RGP.ProjectID = RG.ProjectID
                             AND RGP.IsAllowed = 1
                          WHERE PUE.PartnerUserID = U.PartnerUserID
                            AND PUE.PartnerID = U.PartnerID
                            AND PUE.IsActive = 1
                      )
                  )

                UNION ALL

                SELECT
                    3,
                    N'COMPANY_USER',
                    CONVERT(nvarchar(100), U.UserID),
                    @ProjectID,
                    Company.PartnerID,
                    U.CompanyID,
                    U.Username,
                    COALESCE(NULLIF(U.Email, N''), Employee.Email)
                FROM dbo.TDADUser AS U
                INNER JOIN dbo.TDSTCompanySetUp AS Company
                    ON Company.CompanyID = U.CompanyID
                   AND Company.IsActive = 1
                INNER JOIN dbo.TDADPartner AS Partner
                    ON Partner.PartnerID = Company.PartnerID
                   AND Partner.IsActive = 1
                OUTER APPLY
                (
                    SELECT TOP (1) E.Email
                    FROM dbo.TDADUserEmployee AS UE
                    INNER JOIN dbo.TDADEmployee AS E
                        ON E.EmployeeID = UE.EmployeeID
                       AND E.CompanyID = UE.CompanyID
                       AND E.IsActive = 1
                    WHERE UE.UserID = U.UserID
                      AND UE.CompanyID = U.CompanyID
                    ORDER BY UE.UserEmployeeID
                ) AS Employee
                WHERE U.NormalizedUsername = @NormalizedUsername
                  AND U.IsActive = 1
                  AND EXISTS
                  (
                      SELECT 1
                      FROM dbo.TDADUserProject AS RequiredProject
                      WHERE RequiredProject.UserID = U.UserID
                        AND RequiredProject.CompanyID = U.CompanyID
                        AND RequiredProject.ProjectID = @ProjectID
                        AND RequiredProject.IsActive = 1
                  )
            ) AS Account
            WHERE ProjectID IS NOT NULL
            ORDER BY Priority;
            """;

        await using var command = new SqlCommand(sql, connection);
        Add(command, "@NormalizedUsername", normalizedUsername);
        Add(command, "@ProjectCode", projectCode);
        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken)) return null;

        return new ResetAccountRow(
            reader.GetString(0),
            reader.GetString(1),
            reader.GetInt64(2),
            reader.IsDBNull(3) ? null : reader.GetInt64(3),
            reader.IsDBNull(4) ? null : reader.GetInt64(4),
            reader.GetString(5),
            reader.IsDBNull(6) ? null : reader.GetString(6));
    }

    private static string? GetPasswordUpdateSql(string userType) =>
        userType switch
        {
            "LAOO_SUPPORT" => """
                UPDATE U
                SET PasswordHash = @PasswordHash,
                    FailedLoginCount = 0,
                    LockedUntil = NULL,
                    LastPasswordChangeDate = SYSUTCDATETIME(),
                    UpdateDate = SYSUTCDATETIME()
                FROM dbo.TDADLaooUser AS U
                WHERE U.LaooUserID = @SubjectID
                  AND U.IsActive = 1
                  AND EXISTS
                  (
                      SELECT 1 FROM dbo.TDADProject AS Project
                      WHERE Project.ProjectID = @ProjectID
                        AND Project.IsActive = 1
                  )
                  AND EXISTS
                  (
                      SELECT 1
                      FROM dbo.TDADLaooUserProject AS UP
                      WHERE UP.LaooUserID = U.LaooUserID
                        AND UP.ProjectID = @ProjectID
                        AND UP.IsActive = 1
                        AND UP.CanAccess = 1
                  );
                """,
            "PARTNER_USER" => """
                UPDATE U
                SET PasswordHash = @PasswordHash,
                    FailedLoginCount = 0,
                    LockedUntilUtc = NULL,
                    UpdatedUtc = SYSUTCDATETIME(),
                    UpdatedBy = N'PasswordResetService'
                FROM dbo.TDADPartnerUser AS U
                WHERE U.PartnerUserID = @SubjectID
                  AND U.IsActive = 1
                  AND EXISTS
                  (
                      SELECT 1
                      FROM dbo.TDADPartner AS Partner
                      INNER JOIN dbo.TDADProject AS Project
                          ON Project.ProjectID = @ProjectID
                         AND Project.IsActive = 1
                      WHERE Partner.PartnerID = U.PartnerID
                        AND Partner.IsActive = 1
                  )
                  AND
                  (
                      EXISTS
                      (
                          SELECT 1
                          FROM dbo.TDADPartnerUserPermission AS UP
                          INNER JOIN dbo.TDADPermission AS Permission
                              ON Permission.PermissionID = UP.PermissionID
                             AND Permission.ProjectID = UP.ProjectID
                             AND Permission.IsActive = 1
                          WHERE UP.PartnerUserID = U.PartnerUserID
                            AND UP.ProjectID = @ProjectID
                            AND UP.IsAllowed = 1
                            AND UP.IsActive = 1
                      )
                      OR EXISTS
                      (
                          SELECT 1
                          FROM dbo.TDADPartnerUserEmployee AS PUE
                          INNER JOIN dbo.TDADEmployee AS E
                              ON E.EmployeeID = PUE.EmployeeID
                             AND E.PartnerID = U.PartnerID
                             AND E.IsActive = 1
                          INNER JOIN dbo.TDADEmployeeRoleGroup AS ERG
                              ON ERG.EmployeeID = E.EmployeeID
                             AND ERG.IsActive = 1
                             AND ERG.EffectiveFrom <= CONVERT(date, SYSUTCDATETIME())
                             AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo >= CONVERT(date, SYSUTCDATETIME()))
                          INNER JOIN dbo.TDADRoleGroup AS RG
                              ON RG.RoleGroupID = ERG.RoleGroupID
                             AND RG.ProjectID = @ProjectID
                             AND RG.ScopeType = 'P'
                             AND RG.PartnerID = U.PartnerID
                             AND RG.IsActive = 1
                          INNER JOIN dbo.TDADRoleGroupPermission AS RGP
                              ON RGP.RoleGroupID = RG.RoleGroupID
                             AND RGP.ProjectID = RG.ProjectID
                             AND RGP.IsAllowed = 1
                          WHERE PUE.PartnerUserID = U.PartnerUserID
                            AND PUE.PartnerID = U.PartnerID
                            AND PUE.IsActive = 1
                      )
                  );
                """,
            "COMPANY_USER" => """
                UPDATE U
                SET PasswordHash = @PasswordHash,
                    FailedLoginCount = 0,
                    LockedUntil = NULL,
                    LastPasswordChangeDate = SYSUTCDATETIME(),
                    UpdateDate = SYSUTCDATETIME()
                FROM dbo.TDADUser AS U
                WHERE U.UserID = @SubjectID
                  AND U.IsActive = 1
                  AND EXISTS
                  (
                      SELECT 1
                      FROM dbo.TDSTCompanySetUp AS Company
                      INNER JOIN dbo.TDADPartner AS Partner
                          ON Partner.PartnerID = Company.PartnerID
                         AND Partner.IsActive = 1
                      INNER JOIN dbo.TDADProject AS Project
                          ON Project.ProjectID = @ProjectID
                         AND Project.IsActive = 1
                      WHERE Company.CompanyID = U.CompanyID
                        AND Company.IsActive = 1
                  )
                  AND EXISTS
                  (
                      SELECT 1
                      FROM dbo.TDADUserProject AS RequiredProject
                      WHERE RequiredProject.UserID = U.UserID
                        AND RequiredProject.CompanyID = U.CompanyID
                        AND RequiredProject.ProjectID = @ProjectID
                        AND RequiredProject.IsActive = 1
                  )
                  ;
                """,
            _ => null
        };

    private async Task SendEmailAsync(
        string email,
        string token,
        string userType,
        long? partnerId,
        long? companyId,
        CancellationToken cancellationToken)
    {
        var ownerType = userType switch
        {
            "LAOO_SUPPORT" => "L",
            "PARTNER_USER" => "P",
            _ => "C"
        };

        const string sql = """
            SELECT TOP (1)
                EmailHost, EmailPort, EmailCenter, EmailPasswordCenter
            FROM dbo.TDSTCompanySetUp
            WHERE OwnerType = @OwnerType
              AND
              (
                  (@OwnerType = 'L' AND PartnerID IS NULL AND CompanyID IS NULL)
                  OR (@OwnerType = 'P' AND PartnerID = @PartnerID AND CompanyID IS NULL)
                  OR (@OwnerType = 'C' AND CompanyID = @CompanyID)
              );
            """;

        await using var connection = _db.CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@OwnerType", ownerType);
        Add(command, "@PartnerID", partnerId);
        Add(command, "@CompanyID", companyId);
        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken)) return;

        var host = reader.IsDBNull(0) ? null : reader.GetString(0);
        var port = reader.IsDBNull(1) ? 587 : reader.GetInt32(1);
        var sender = reader.IsDBNull(2) ? null : reader.GetString(2);
        var password =
            _secrets.Unprotect(reader.IsDBNull(3) ? null : reader.GetString(3));
        await reader.DisposeAsync();

        if (string.IsNullOrWhiteSpace(host) ||
            string.IsNullOrWhiteSpace(sender) ||
            string.IsNullOrWhiteSpace(password))
        {
            return;
        }

        using var mail = new MailMessage(
            sender,
            email,
            "Laoo - Reset Password",
            $"ใช้รหัสนี้เพื่อตั้งรหัสผ่านใหม่ภายใน 15 นาที:\n\n{token}");
        using var smtp = new SmtpClient(host, port)
        {
            EnableSsl = true,
            Credentials = new NetworkCredential(sender, password)
        };
        await smtp.SendMailAsync(mail, cancellationToken);
    }

    private static void Add(SqlCommand command, string name, object? value) =>
        command.Parameters.AddWithValue(name, value ?? DBNull.Value);

    private sealed record ResetAccountRow(
        string UserType,
        string SubjectId,
        long ProjectId,
        long? PartnerId,
        long? CompanyId,
        string Username,
        string? Email);

    private sealed record ResetTokenRow(
        long TokenId,
        string UserType,
        string SubjectId,
        long ProjectId,
        string Username);
}
