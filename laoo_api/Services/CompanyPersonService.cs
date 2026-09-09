using System.Data;
using Laoo.Shared.Contracts.Employees;
using Microsoft.Data.SqlClient;

namespace LaooApi.Services;

public sealed class CompanyPersonService
{
    public async Task<CompanyEmployeeIdentityResult> UpsertEmployeeIdentityAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long companyId,
        long employeeId,
        EmployeeUpsertRequest request,
        string username,
        string normalizedUsername,
        string? passwordHash,
        long roleGroupId,
        long projectId,
        long? actorId,
        CancellationToken cancellationToken)
    {
        long? personId;
        long? userId;
        string? currentNormalizedUsername;

        const string identitySql = """
SELECT E.PersonID, U.UserID, U.NormalizedUsername
FROM dbo.TDADEmployee AS E WITH (UPDLOCK, HOLDLOCK)
OUTER APPLY
(
    SELECT TOP (1) Link.UserID
    FROM dbo.TDADUserEmployee AS Link
    WHERE Link.EmployeeID=E.EmployeeID AND Link.CompanyID=E.CompanyID
    ORDER BY Link.IsActive DESC, Link.UserEmployeeID DESC
) AS UE
LEFT JOIN dbo.TDADUser AS U
  ON U.UserID=UE.UserID AND U.CompanyID=E.CompanyID
WHERE E.EmployeeID=@EmployeeID AND E.CompanyID=@CompanyID;
""";
        await using (var command = new SqlCommand(identitySql, connection, transaction))
        {
            Add(command, "@EmployeeID", SqlDbType.BigInt, employeeId);
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
                throw new CompanyPersonException(
                    "EMPLOYEE_NOT_FOUND",
                    "ไม่พบข้อมูลพนักงาน",
                    "พนักงานไม่อยู่ในขอบเขต Company ที่กำลังดำเนินการ");
            personId = reader.IsDBNull(0) ? null : reader.GetInt64(0);
            userId = reader.IsDBNull(1) ? null : reader.GetInt64(1);
            currentNormalizedUsername = reader.IsDBNull(2) ? null : reader.GetString(2);
            if (await reader.ReadAsync(cancellationToken))
                throw new CompanyPersonException(
                    "MULTIPLE_EMPLOYEE_USERS",
                    "พนักงานเชื่อมกับบัญชีมากกว่าหนึ่งบัญชี",
                    "กรุณาให้ผู้ดูแลตรวจสอบ TDADUserEmployee ก่อนบันทึก");
        }

        if (currentNormalizedUsername is not null
            && !string.Equals(currentNormalizedUsername, normalizedUsername, StringComparison.Ordinal))
        {
            throw new CompanyPersonException(
                "USERNAME_IMMUTABLE",
                "ไม่สามารถเปลี่ยน Username ได้",
                "Username เป็นรหัสเข้าใช้งานถาวร หากต้องการเปลี่ยนกรุณาสร้างบัญชีใหม่ตามขั้นตอนผู้ดูแลระบบ");
        }

        if (userId is null && string.IsNullOrWhiteSpace(passwordHash))
        {
            throw new CompanyPersonException(
                "PASSWORD_REQUIRED",
                "กรุณากรอก Password",
                "พนักงาน Company ใหม่ต้องมี Username และ Password สำหรับเข้าใช้งานระบบ");
        }

        const string usernameSql = """
IF EXISTS(SELECT 1 FROM dbo.TDADLaooUser WHERE NormalizedUsername=@NormalizedUsername)
   OR EXISTS(SELECT 1 FROM dbo.TDADPartnerUser WHERE NormalizedUsername=@NormalizedUsername)
   OR EXISTS(SELECT 1 FROM dbo.TDADUser WHERE NormalizedUsername=@NormalizedUsername AND (@UserID IS NULL OR UserID<>@UserID))
    THROW 51101, 'USERNAME_EXISTS', 1;
""";
        await using (var command = new SqlCommand(usernameSql, connection, transaction))
        {
            Add(command, "@NormalizedUsername", SqlDbType.NVarChar, normalizedUsername, 100);
            Add(command, "@UserID", SqlDbType.BigInt, userId);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        if (personId is null)
        {
            const string insertPersonSql = """
INSERT dbo.TDADPerson
    (CompanyID,FullName,NickName,Email,Mobile,IsActive,CreateBy)
VALUES
    (@CompanyID,@FullName,@NickName,@Email,@Mobile,@IsActive,@ActorID);
SELECT CONVERT(bigint,SCOPE_IDENTITY());
""";
            await using var command = new SqlCommand(insertPersonSql, connection, transaction);
            BindPerson(command, companyId, request, actorId);
            personId = Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken));
        }
        else
        {
            const string updatePersonSql = """
UPDATE dbo.TDADPerson
SET FullName=@FullName,NickName=@NickName,Email=@Email,Mobile=@Mobile,
    IsActive=@IsActive,UpdateDate=SYSUTCDATETIME(),UpdateBy=@ActorID
WHERE PersonID=@PersonID AND CompanyID=@CompanyID;
IF @@ROWCOUNT=0 THROW 51102, 'PERSON_SCOPE_MISMATCH', 1;
""";
            await using var command = new SqlCommand(updatePersonSql, connection, transaction);
            BindPerson(command, companyId, request, actorId);
            Add(command, "@PersonID", SqlDbType.BigInt, personId.Value);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        await using (var command = new SqlCommand(
                         "UPDATE dbo.TDADEmployee SET PersonID=@PersonID WHERE EmployeeID=@EmployeeID AND CompanyID=@CompanyID;",
                         connection,
                         transaction))
        {
            Add(command, "@PersonID", SqlDbType.BigInt, personId.Value);
            Add(command, "@EmployeeID", SqlDbType.BigInt, employeeId);
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        if (userId is null)
        {
            const string insertUserSql = """
INSERT dbo.TDADUser
    (CompanyID,PersonID,Username,NormalizedUsername,PasswordHash,DisplayName,
     IsCompanyAdmin,IsActive,FailedLoginCount,LastPasswordChangeDate,CreateDate,CreateBy)
VALUES
    (@CompanyID,@PersonID,@Username,@NormalizedUsername,@PasswordHash,@DisplayName,
     0,@IsActive,0,SYSUTCDATETIME(),SYSUTCDATETIME(),@ActorID);
SELECT CONVERT(bigint,SCOPE_IDENTITY());
""";
            await using var command = new SqlCommand(insertUserSql, connection, transaction);
            BindUser(command, companyId, personId.Value, request, username, normalizedUsername, passwordHash!, actorId);
            userId = Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken));
        }
        else
        {
            const string updateUserSql = """
UPDATE dbo.TDADUser
SET PersonID=@PersonID,DisplayName=@DisplayName,IsActive=@IsActive,
    PasswordHash=CASE WHEN @PasswordHash IS NULL THEN PasswordHash ELSE @PasswordHash END,
    LastPasswordChangeDate=CASE WHEN @PasswordHash IS NULL THEN LastPasswordChangeDate ELSE SYSUTCDATETIME() END,
    UpdateDate=SYSUTCDATETIME(),UpdateBy=@ActorID
WHERE UserID=@UserID AND CompanyID=@CompanyID;
IF @@ROWCOUNT=0 THROW 51103, 'USER_SCOPE_MISMATCH', 1;
""";
            await using var command = new SqlCommand(updateUserSql, connection, transaction);
            BindUser(command, companyId, personId.Value, request, username, normalizedUsername, passwordHash, actorId);
            Add(command, "@UserID", SqlDbType.BigInt, userId.Value);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        const string relationshipSql = """
UPDATE dbo.TDADUserEmployee
SET IsActive=1,UpdateDate=SYSUTCDATETIME()
WHERE CompanyID=@CompanyID AND UserID=@UserID AND EmployeeID=@EmployeeID;
IF @@ROWCOUNT=0
    INSERT dbo.TDADUserEmployee(UserID,EmployeeID,CompanyID,IsActive)
    VALUES(@UserID,@EmployeeID,@CompanyID,1);

INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate)
SELECT @CompanyID,@UserID,@ProjectID,1,1,SYSUTCDATETIME()
WHERE EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectID=@ProjectID AND IsActive=1)
  AND NOT EXISTS
  (
      SELECT 1 FROM dbo.TDADUserProject
      WHERE CompanyID=@CompanyID AND UserID=@UserID AND ProjectID=@ProjectID
  );

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.TDADRoleGroup
    WHERE RoleGroupID=@RoleGroupID AND ScopeType='C'
      AND CompanyID=@CompanyID AND ProjectID=@ProjectID AND IsActive=1
)
    THROW 51104, 'ROLE_GROUP_SCOPE_INVALID', 1;

UPDATE dbo.TDADEmployeeRoleGroup
SET IsActive=0,EffectiveTo=CONVERT(date,SYSUTCDATETIME()),
    UpdatedUtc=SYSUTCDATETIME(),UpdatedBy=N'CompanyPersonService'
WHERE EmployeeID=@EmployeeID AND IsActive=1 AND RoleGroupID<>@RoleGroupID;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.TDADEmployeeRoleGroup
    WHERE EmployeeID=@EmployeeID AND RoleGroupID=@RoleGroupID AND IsActive=1
)
    INSERT dbo.TDADEmployeeRoleGroup
        (EmployeeID,RoleGroupID,EffectiveFrom,IsActive,CreatedBy)
    VALUES
        (@EmployeeID,@RoleGroupID,CONVERT(date,SYSUTCDATETIME()),1,N'CompanyPersonService');
""";
        await using (var command = new SqlCommand(relationshipSql, connection, transaction))
        {
            Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
            Add(command, "@UserID", SqlDbType.BigInt, userId.Value);
            Add(command, "@EmployeeID", SqlDbType.BigInt, employeeId);
            Add(command, "@ProjectID", SqlDbType.BigInt, projectId);
            Add(command, "@RoleGroupID", SqlDbType.BigInt, roleGroupId);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        return new CompanyEmployeeIdentityResult(personId.Value, userId.Value);
    }

    private static void BindPerson(
        SqlCommand command,
        long companyId,
        EmployeeUpsertRequest request,
        long? actorId)
    {
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@FullName", SqlDbType.NVarChar, request.FullName.Trim(), 200);
        Add(command, "@NickName", SqlDbType.NVarChar, NullIfBlank(request.NickName), 100);
        Add(command, "@Email", SqlDbType.NVarChar, NullIfBlank(request.Email), 320);
        Add(command, "@Mobile", SqlDbType.NVarChar,
            NullIfBlank(request.PersonalTelephone) ?? NullIfBlank(request.Telephone), 50);
        Add(command, "@IsActive", SqlDbType.Bit, request.IsActive);
        Add(command, "@ActorID", SqlDbType.BigInt, actorId);
    }

    private static void BindUser(
        SqlCommand command,
        long companyId,
        long personId,
        EmployeeUpsertRequest request,
        string username,
        string normalizedUsername,
        string? passwordHash,
        long? actorId)
    {
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@PersonID", SqlDbType.BigInt, personId);
        Add(command, "@Username", SqlDbType.NVarChar, username, 100);
        Add(command, "@NormalizedUsername", SqlDbType.NVarChar, normalizedUsername, 100);
        Add(command, "@PasswordHash", SqlDbType.NVarChar, passwordHash, 500);
        Add(command, "@DisplayName", SqlDbType.NVarChar, request.FullName.Trim(), 200);
        Add(command, "@IsActive", SqlDbType.Bit, request.IsActive);
        Add(command, "@ActorID", SqlDbType.BigInt, actorId);
    }

    private static string? NullIfBlank(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static void Add(
        SqlCommand command,
        string name,
        SqlDbType type,
        object? value,
        int size = 0)
    {
        var parameter = size > 0
            ? command.Parameters.Add(name, type, size)
            : command.Parameters.Add(name, type);
        parameter.Value = value ?? DBNull.Value;
    }
}

public sealed record CompanyEmployeeIdentityResult(long PersonId, long UserId);

public sealed class CompanyPersonException(
    string code,
    string message,
    string description) : Exception(message)
{
    public string Code { get; } = code;
    public string Description { get; } = description;
}
