using LaooApi.Data;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.Data.SqlClient;

namespace LaooApi.Services;

public sealed class AuthenticationService
{
    private readonly SqlConnectionFactory _connectionFactory;
    private readonly PasswordService _passwordService;
    private readonly JwtTokenService _jwtTokenService;

    public AuthenticationService(
        SqlConnectionFactory connectionFactory,
        PasswordService passwordService,
        JwtTokenService jwtTokenService)
    {
        _connectionFactory = connectionFactory;
        _passwordService = passwordService;
        _jwtTokenService = jwtTokenService;
    }

    public async Task<LoginResponse> LoginAsync(
        LoginRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Username) ||
            string.IsNullOrWhiteSpace(request.Password))
        {
            return Failed("กรุณากรอก Username และ Password");
        }

        var normalizedUsername = request.Username.Trim().ToUpperInvariant();
        var projectCode = string.IsNullOrWhiteSpace(request.ProjectCode)
            ? "LAOO"
            : request.ProjectCode.Trim().ToUpperInvariant();

        await using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var project = await FindProjectAsync(
            connection,
            projectCode,
            cancellationToken);

        if (project is null)
        {
            return Failed("ไม่พบ Project หรือ Project ไม่เปิดใช้งาน");
        }

        var laooUser = await FindLaooUserAsync(
            connection,
            normalizedUsername,
            project.Value.ProjectId,
            cancellationToken);

        AuthenticatedUser authenticated;

        if (laooUser is not null &&
            laooUser.IsSupportUser &&
            laooUser.IsActive &&
            laooUser.CanAccessProject &&
            _passwordService.VerifyPassword(
                laooUser.Username,
                laooUser.PasswordHash,
                request.Password))
        {
            authenticated = new AuthenticatedUser(
                SubjectId: $"laoo:{laooUser.LaooUserId}",
                UserType: "LAOO_SUPPORT",
                LoginMode: "LAOO",
                LaooUserId: laooUser.LaooUserId,
                PartnerId: null,
                UserId: null,
                CompanyId: null,
                BranchId: null,
                ProjectId: project.Value.ProjectId,
                ProjectCode: project.Value.ProjectCode,
                Username: laooUser.Username,
                DisplayName: laooUser.DisplayName,
                CanLoginAsUser:
                    laooUser.CanLoginAsUser &&
                    laooUser.CanLoginAsUserForProject);
        }
        else
        {
            var partnerUser = await FindPartnerUserAsync(
                connection,
                normalizedUsername,
                cancellationToken);

            if (partnerUser is not null &&
                !_passwordService.VerifyPassword(
                    partnerUser.Username,
                    partnerUser.PasswordHash,
                    request.Password))
            {
                return Failed("Username หรือ Password ไม่ถูกต้อง");
            }

            if (partnerUser is not null)
            {
                authenticated = new AuthenticatedUser(
                    SubjectId: $"partner:{partnerUser.PartnerUserId}",
                    UserType: "PARTNER_USER",
                    LoginMode: "PARTNER",
                    LaooUserId: null,
                    PartnerId: partnerUser.PartnerId,
                    UserId: null,
                    CompanyId: null,
                    BranchId: null,
                    ProjectId: project.Value.ProjectId,
                    ProjectCode: project.Value.ProjectCode,
                    Username: partnerUser.Username,
                    DisplayName: partnerUser.DisplayName,
                    CanLoginAsUser: false);
            }
            else
            {
                var companyUser = await FindCompanyUserAsync(
                    connection,
                    normalizedUsername,
                    project.Value.ProjectId,
                    cancellationToken);

                if (companyUser is null ||
                    !_passwordService.VerifyPassword(
                        companyUser.Username,
                        companyUser.PasswordHash,
                        request.Password))
                {
                    return Failed("Username หรือ Password ไม่ถูกต้อง");
                }

                authenticated = new AuthenticatedUser(
                    SubjectId: $"user:{companyUser.UserId}",
                    UserType: "COMPANY_USER",
                    LoginMode: "USER",
                    LaooUserId: null,
                    PartnerId: companyUser.PartnerId,
                    UserId: companyUser.UserId,
                    CompanyId: companyUser.CompanyId,
                    BranchId: companyUser.BranchId,
                    ProjectId: project.Value.ProjectId,
                    ProjectCode: project.Value.ProjectCode,
                    Username: companyUser.Username,
                    DisplayName: companyUser.DisplayName,
                    CanLoginAsUser: false);
            }
        }

        var token = _jwtTokenService.CreateToken(authenticated);

        return new LoginResponse(
            true,
            "เข้าสู่ระบบสำเร็จ",
            token.AccessToken,
            token.ExpiresAt,
            new LoginUserResponse(
                authenticated.UserType,
                authenticated.LoginMode,
                authenticated.LaooUserId,
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

    private static LoginResponse Failed(string message)
    {
        return new LoginResponse(false, message, null, null, null);
    }

    private static async Task<(long ProjectId, string ProjectCode)?>
        FindProjectAsync(
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

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return (reader.GetInt64(0), reader.GetString(1));
    }

    private static async Task<LaooUserRow?> FindLaooUserAsync(
        SqlConnection connection,
        string normalizedUsername,
        long projectId,
        CancellationToken cancellationToken)
    {
        const string sql = """
        SELECT TOP (1)
            u.LaooUserID,
            u.Username,
            u.PasswordHash,
            u.DisplayName,
            u.IsSupportUser,
            u.IsActive,
            u.CanLoginAsUser,
            CAST(CASE WHEN up.LaooUserProjectID IS NULL
                      THEN 0 ELSE up.CanAccess END AS BIT),
            CAST(CASE WHEN up.LaooUserProjectID IS NULL
                      THEN 0 ELSE up.CanLoginAsUser END AS BIT)
        FROM dbo.TDADLaooUser AS u
        LEFT JOIN dbo.TDADLaooUserProject AS up
            ON up.LaooUserID = u.LaooUserID
           AND up.ProjectID = @ProjectID
           AND up.IsActive = 1
        WHERE u.NormalizedUsername = @NormalizedUsername;
        """;

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@NormalizedUsername", normalizedUsername);
        command.Parameters.AddWithValue("@ProjectID", projectId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new LaooUserRow(
            reader.GetInt64(0),
            reader.GetString(1),
            reader.GetString(2),
            reader.GetString(3),
            reader.GetBoolean(4),
            reader.GetBoolean(5),
            reader.GetBoolean(6),
            reader.GetBoolean(7),
            reader.GetBoolean(8));
    }

    private static async Task<PartnerUserRow?> FindPartnerUserAsync(
        SqlConnection connection,
        string normalizedUsername,
        CancellationToken cancellationToken)
    {
        const string sql = """
        SELECT TOP (1)
            u.PartnerUserID,
            u.PartnerID,
            u.Username,
            u.PasswordHash,
            u.DisplayName
        FROM dbo.TDADPartnerUser AS u
        INNER JOIN dbo.TDADPartner AS p
            ON p.PartnerID = u.PartnerID
           AND p.IsActive = 1
        WHERE u.NormalizedUsername = @NormalizedUsername
          AND u.IsActive = 1
          AND (u.LockedUntilUtc IS NULL OR u.LockedUntilUtc <= SYSUTCDATETIME());
        """;

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@NormalizedUsername", normalizedUsername);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new PartnerUserRow(
            reader.GetInt64(0),
            reader.GetInt64(1),
            reader.GetString(2),
            reader.GetString(3),
            reader.GetString(4));
    }

    private static async Task<CompanyUserRow?> FindCompanyUserAsync(
        SqlConnection connection,
        string normalizedUsername,
        long projectId,
        CancellationToken cancellationToken)
    {
        const string sql = """
        SELECT TOP (1)
            u.UserID,
            u.CompanyID,
            c.PartnerID,
            b.BranchID,
            u.Username,
            u.PasswordHash,
            u.DisplayName
        FROM dbo.TDADUser AS u
        INNER JOIN dbo.TDADCompany AS c
            ON c.CompanyID = u.CompanyID
           AND c.IsActive = 1
        INNER JOIN dbo.TDADPartner AS p
            ON p.PartnerID = c.PartnerID
           AND p.IsActive = 1
        INNER JOIN dbo.TDADUserProject AS up
            ON up.UserID = u.UserID
           AND up.CompanyID = u.CompanyID
           AND up.ProjectID = @ProjectID
           AND up.IsActive = 1
        OUTER APPLY
        (
            SELECT TOP (1) ub.BranchID
            FROM dbo.TDADUserBranch AS ub
            INNER JOIN dbo.TDADBranch AS branch
                ON branch.BranchID = ub.BranchID
               AND branch.CompanyID = ub.CompanyID
               AND branch.IsActive = 1
            WHERE ub.UserID = u.UserID
              AND ub.CompanyID = u.CompanyID
              AND ub.IsActive = 1
            ORDER BY ub.IsDefault DESC, ub.UserBranchID
        ) AS b
        WHERE u.NormalizedUsername = @NormalizedUsername
          AND u.IsActive = 1
          AND (u.LockedUntil IS NULL OR u.LockedUntil <= SYSUTCDATETIME());
        """;

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@NormalizedUsername", normalizedUsername);
        command.Parameters.AddWithValue("@ProjectID", projectId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new CompanyUserRow(
            reader.GetInt64(0),
            reader.GetInt64(1),
            reader.GetInt64(2),
            reader.IsDBNull(3) ? null : reader.GetInt64(3),
            reader.GetString(4),
            reader.GetString(5),
            reader.GetString(6));
    }

    private sealed record LaooUserRow(
        long LaooUserId,
        string Username,
        string PasswordHash,
        string DisplayName,
        bool IsSupportUser,
        bool IsActive,
        bool CanLoginAsUser,
        bool CanAccessProject,
        bool CanLoginAsUserForProject);

    private sealed record PartnerUserRow(
        long PartnerUserId,
        long PartnerId,
        string Username,
        string PasswordHash,
        string DisplayName);

    private sealed record CompanyUserRow(
        long UserId,
        long PartnerId,
        long CompanyId,
        long? BranchId,
        string Username,
        string PasswordHash,
        string DisplayName);
}
