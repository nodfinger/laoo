using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/school/guardian")]
public sealed class SchoolGuardianPortalController(
    IConfiguration configuration,
    PasswordService passwords,
    JwtTokenService tokens) : ControllerBase
{
    [AllowAnonymous]
    [EnableRateLimiting("authentication")]
    [HttpPost("login")]
    public async Task<IActionResult> Login(
        GuardianLoginRequest request,
        CancellationToken cancellationToken)
    {
        var companyCode = request.CompanyCode?.Trim();
        var email = request.Email?.Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(companyCode) ||
            string.IsNullOrWhiteSpace(email) ||
            string.IsNullOrWhiteSpace(request.Password))
        {
            return Unauthorized(FailedLogin());
        }

        await using var connection = await OpenAsync(cancellationToken);
        const string sql = """
SELECT TOP (1)
       g.GuardianID,
       g.CompanyID,
       g.FullName,
       g.Email,
       g.PasswordHash,
       g.FailedLoginCount,
       g.LockedUntil,
       p.ProjectID
FROM dbo.TDSCGuardian g
JOIN dbo.TDSTCompanySetUp c
  ON c.CompanyID=g.CompanyID
 AND c.CompanyCode=@CompanyCode
 AND c.IsActive=1
JOIN dbo.TDADProject p
  ON p.ProjectCode=N'LAOO_SCHOOL'
 AND p.IsActive=1
JOIN dbo.TDADCompanyProject cp
  ON cp.ProjectID=p.ProjectID
 AND cp.CompanyID=g.CompanyID
 AND cp.IsEnabled=1
WHERE g.Email=@Email
  AND g.IsActive=1;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@CompanyCode", SqlDbType.NVarChar, 50).Value = companyCode;
        command.Parameters.Add("@Email", SqlDbType.NVarChar, 200).Value = email;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return Unauthorized(FailedLogin());
        }

        var guardianId = reader.GetInt64(0);
        var companyId = reader.GetInt64(1);
        var fullName = reader.GetString(2);
        var storedEmail = reader.GetString(3);
        var passwordHash = reader.IsDBNull(4) ? null : reader.GetString(4);
        var failedCount = reader.GetInt32(5);
        var lockedUntil = reader.IsDBNull(6)
            ? (DateTime?)null
            : reader.GetDateTime(6);
        var projectId = reader.GetInt64(7);
        await reader.DisposeAsync();

        if (lockedUntil is not null && lockedUntil > DateTime.UtcNow)
        {
            return StatusCode(StatusCodes.Status423Locked, new
            {
                success = false,
                message = "บัญชีถูกล็อกชั่วคราว กรุณาลองใหม่ภายหลัง"
            });
        }

        if (string.IsNullOrWhiteSpace(passwordHash) ||
            !passwords.VerifyPassword(storedEmail, passwordHash, request.Password))
        {
            await RecordFailureAsync(
                connection,
                guardianId,
                failedCount + 1,
                cancellationToken);
            return Unauthorized(FailedLogin());
        }

        await ExecuteAsync(
            connection,
            "UPDATE dbo.TDSCGuardian SET FailedLoginCount=0,LockedUntil=NULL WHERE GuardianID=@GuardianID",
            cancellationToken,
            ("@GuardianID", guardianId));

        var token = tokens.CreateToken(new AuthenticatedUser(
            $"school-guardian:{guardianId}",
            "SCHOOL_GUARDIAN",
            "SCHOOL_GUARDIAN",
            null,
            null,
            null,
            null,
            companyId,
            null,
            projectId,
            "LAOO_SCHOOL",
            storedEmail,
            fullName,
            false,
            GuardianId: guardianId));

        return Ok(new
        {
            success = true,
            accessToken = token.AccessToken,
            expiresAt = token.ExpiresAt,
            guardian = new { id = guardianId, name = fullName, email = storedEmail }
        });
    }

    [Authorize]
    [HttpGet("portal")]
    public async Task<IActionResult> Portal(CancellationToken cancellationToken)
    {
        if (!GuardianScope(out var companyId, out var guardianId))
        {
            return Forbid();
        }

        await using var connection = await OpenAsync(cancellationToken);
        const string guardianSql = """
SELECT GuardianID id,GuardianCode code,FullName name,Email email,Telephone telephone
FROM dbo.TDSCGuardian
WHERE CompanyID=@CompanyID AND GuardianID=@GuardianID AND IsActive=1;
""";
        const string childrenSql = """
SELECT s.StudentID id,s.StudentCode code,
       CONCAT(s.FirstName,N' ',s.LastName) name,
       c.RoomName classroom,sg.RelationshipName relationship,
       sg.IsPrimary isPrimary
FROM dbo.TDSCStudentGuardian sg
JOIN dbo.TDSCStudent s ON s.StudentID=sg.StudentID AND s.CompanyID=@CompanyID AND s.IsActive=1
JOIN dbo.TDSCClassroom c ON c.ClassroomID=s.ClassroomID
WHERE sg.GuardianID=@GuardianID
ORDER BY sg.IsPrimary DESC,s.StudentCode;
""";
        const string attendanceSql = """
SELECT a.StudentID studentId,CONVERT(nvarchar(10),a.AttendanceDate,23) attendanceDate,
       a.CheckInAt checkInAt,a.CheckOutAt checkOutAt,a.StatusCode status,a.Remark remark
FROM dbo.TDSCSchoolAttendance a
JOIN dbo.TDSCStudentGuardian sg
  ON sg.StudentID=a.StudentID
 AND sg.GuardianID=@GuardianID
 AND sg.CanViewAttendance=1
WHERE a.CompanyID=@CompanyID
  AND a.AttendanceDate>=DATEADD(day,-30,CONVERT(date,SYSUTCDATETIME()))
ORDER BY a.AttendanceDate DESC,a.StudentID;
""";
        const string newsSql = """
SELECT DISTINCT n.NewsID id,n.Title title,n.SummaryText summary,n.BodyText body,
       n.PublishedAt publishedAt
FROM dbo.TDSCNews n
WHERE n.CompanyID=@CompanyID
  AND n.IsActive=1
  AND n.StatusCode=N'PUBLISHED'
  AND (
      n.AudienceMode=N'ALL'
      OR EXISTS(
          SELECT 1
          FROM dbo.TDSCNewsAudience a
          WHERE a.NewsID=n.NewsID
            AND (
                (a.AudienceType=N'GUARDIAN' AND a.AudienceID=@GuardianID)
                OR (a.AudienceType=N'CLASSROOM' AND EXISTS(
                    SELECT 1 FROM dbo.TDSCStudentGuardian sg
                    JOIN dbo.TDSCStudent s ON s.StudentID=sg.StudentID
                    WHERE sg.GuardianID=@GuardianID
                      AND sg.CanReceiveNews=1
                      AND s.ClassroomID=a.AudienceID))
                OR (a.AudienceType=N'LEVEL' AND EXISTS(
                    SELECT 1 FROM dbo.TDSCStudentGuardian sg
                    JOIN dbo.TDSCStudent s ON s.StudentID=sg.StudentID
                    JOIN dbo.TDSCClassroom c ON c.ClassroomID=s.ClassroomID
                    WHERE sg.GuardianID=@GuardianID
                      AND sg.CanReceiveNews=1
                      AND c.LevelID=a.AudienceID))
            ))
  )
ORDER BY n.PublishedAt DESC;
""";

        var guardian = (await QueryAsync(
            connection, guardianSql, cancellationToken,
            ("@CompanyID", companyId), ("@GuardianID", guardianId))).SingleOrDefault();
        if (guardian is null)
        {
            return Unauthorized();
        }

        return Ok(new
        {
            guardian,
            children = await QueryAsync(
                connection, childrenSql, cancellationToken,
                ("@CompanyID", companyId), ("@GuardianID", guardianId)),
            attendance = await QueryAsync(
                connection, attendanceSql, cancellationToken,
                ("@CompanyID", companyId), ("@GuardianID", guardianId)),
            news = await QueryAsync(
                connection, newsSql, cancellationToken,
                ("@CompanyID", companyId), ("@GuardianID", guardianId))
        });
    }

    [Authorize]
    [HttpPut("/api/company/school/guardians/{guardianId:long}/password")]
    public async Task<IActionResult> SetPassword(
        long guardianId,
        GuardianPasswordRequest request,
        CancellationToken cancellationToken)
    {
        if (!CompanyScope(out var companyId) ||
            string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest();
        }

        await using var connection = await OpenAsync(cancellationToken);
        if (!await CompanyMenuAccess.IsAllowedAsync(
                connection, User, "52007", "EDIT", cancellationToken))
        {
            return Forbid();
        }

        const string findSql = """
SELECT Email FROM dbo.TDSCGuardian
WHERE CompanyID=@CompanyID AND GuardianID=@GuardianID AND IsActive=1;
""";
        await using var find = new SqlCommand(findSql, connection);
        find.Parameters.AddWithValue("@CompanyID", companyId);
        find.Parameters.AddWithValue("@GuardianID", guardianId);
        var email = Convert.ToString(await find.ExecuteScalarAsync(cancellationToken));
        if (string.IsNullOrWhiteSpace(email))
        {
            return NotFound();
        }
        if (!PasswordService.MeetsPolicy(email, request.Password))
        {
            return BadRequest(new
            {
                message = "รหัสผ่านไม่เป็นไปตามนโยบาย",
                description = PasswordService.GetReadablePolicyMessage(PasswordService.DefaultPolicyCode)
            });
        }

        var hash = passwords.HashPassword(email, request.Password);
        await ExecuteAsync(
            connection,
            """
UPDATE dbo.TDSCGuardian
SET PasswordHash=@Hash,FailedLoginCount=0,LockedUntil=NULL,
    UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@CompanyID AND GuardianID=@GuardianID;
""",
            cancellationToken,
            ("@Hash", hash),
            ("@CompanyID", companyId),
            ("@GuardianID", guardianId));
        return NoContent();
    }

    private bool GuardianScope(out long companyId, out long guardianId)
    {
        companyId = 0;
        guardianId = 0;
        return User.FindFirstValue("user_type") == "SCHOOL_GUARDIAN" &&
               long.TryParse(User.FindFirstValue("company_id"), out companyId) &&
               long.TryParse(User.FindFirstValue("guardian_id"), out guardianId) &&
               companyId > 0 &&
               guardianId > 0;
    }

    private bool CompanyScope(out long companyId)
    {
        companyId = 0;
        return User.FindFirstValue("user_type") == "COMPANY_USER" &&
               long.TryParse(User.FindFirstValue("company_id"), out companyId) &&
               companyId > 0;
    }

    private async Task<SqlConnection> OpenAsync(CancellationToken cancellationToken)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken);
        return connection;
    }

    private static object FailedLogin() => new
    {
        success = false,
        message = "รหัสโรงเรียน Email หรือรหัสผ่านไม่ถูกต้อง"
    };

    private static async Task RecordFailureAsync(
        SqlConnection connection,
        long guardianId,
        int failedCount,
        CancellationToken cancellationToken)
    {
        await ExecuteAsync(
            connection,
            """
UPDATE dbo.TDSCGuardian
SET FailedLoginCount=@FailedCount,
    LockedUntil=CASE WHEN @FailedCount>=5 THEN DATEADD(minute,15,SYSUTCDATETIME()) ELSE NULL END
WHERE GuardianID=@GuardianID;
""",
            cancellationToken,
            ("@FailedCount", failedCount),
            ("@GuardianID", guardianId));
    }

    private static async Task ExecuteAsync(
        SqlConnection connection,
        string sql,
        CancellationToken cancellationToken,
        params (string Name, object? Value)[] parameters)
    {
        await using var command = new SqlCommand(sql, connection);
        foreach (var parameter in parameters)
        {
            command.Parameters.AddWithValue(parameter.Name, parameter.Value ?? DBNull.Value);
        }
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task<List<Dictionary<string, object?>>> QueryAsync(
        SqlConnection connection,
        string sql,
        CancellationToken cancellationToken,
        params (string Name, object? Value)[] parameters)
    {
        await using var command = new SqlCommand(sql, connection);
        foreach (var parameter in parameters)
        {
            command.Parameters.AddWithValue(parameter.Name, parameter.Value ?? DBNull.Value);
        }
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var rows = new List<Dictionary<string, object?>>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            for (var index = 0; index < reader.FieldCount; index++)
            {
                row[reader.GetName(index)] =
                    await reader.IsDBNullAsync(index, cancellationToken)
                        ? null
                        : reader.GetValue(index);
            }
            rows.Add(row);
        }
        return rows;
    }
}

public sealed record GuardianLoginRequest(
    string? CompanyCode,
    string? Email,
    string Password);

public sealed record GuardianPasswordRequest(string Password);
