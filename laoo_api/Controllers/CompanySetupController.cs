using System.Data;
using System.Security.Claims;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/company-setup")]
[Authorize]
public sealed class CompanySetupController : ControllerBase
{
    private readonly IConfiguration _configuration;
    private readonly PasswordService _passwordService;
    private readonly CompanySetupSecretService _secretService;

    public CompanySetupController(
        IConfiguration configuration,
        PasswordService passwordService,
        CompanySetupSecretService secretService)
    {
        _configuration = configuration;
        _passwordService = passwordService;
        _secretService = secretService;
    }

    [HttpGet]
    public async Task<ActionResult<CompanySetupResponse>> GetAsync(
        CancellationToken cancellationToken)
    {
        var owner = ResolveOwner();
        if (owner is null)
            return Forbid();

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        if (!await AllowedAsync(connection, "VIEW", cancellationToken))
            return Forbid();

        var response = await LoadOwnerSetupAsync(
            connection, owner.Value, cancellationToken);

        if (response is null)
            return NotFound(new { message = "ไม่พบข้อมูลกำหนดค่าระบบของผู้ใช้งาน" });

        return Ok(response);
    }

    [HttpPut]
    public async Task<ActionResult<CompanySetupResponse>> UpdateAsync(
        [FromBody] CompanySetupUpdateRequest request,
        [FromQuery] bool additionalOnly,
        CancellationToken cancellationToken)
    {
        var owner = ResolveOwner();
        if (owner is null)
            return Forbid();

        var validationError = ValidateRequest(request);
        if (validationError is not null)
            return BadRequest(new { message = validationError });

        var passwordCry = HashIfProvided(request.PasswordCry);
        var passwordEmpDefault = HashIfProvided(request.PasswordEmpDefault);
        var passwordDirect = HashIfProvided(request.PasswordDirect);
        var emailPasswordCenter = _secretService.Protect(request.EmailPasswordCenter);
        var actorId = GetActorIdFromToken();

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        if (!await AllowedAsync(connection, "EDIT", cancellationToken))
            return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        const string sql = """
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
UPDATE dbo.TDSTCompanySetUp
SET
    CustomerNameTH = @CustomerNameTH,
    CustomerNameEN = @CustomerNameEN,
    AddressText = @CustomerAddressText,
    Telephone = @CustomerTelephone,
    TaxID = @CustomerTaxID,
    Name = @Name,
    TitleHeader = @TitleHeader,
    RowSTD = @RowSTD,
    RowCardSTD = @RowCardSTD,
    TimeAlert = @TimeAlert,
    OrgStructureType = @OrgStructureType,
    PasswordPolicyCode = @PasswordPolicyCode,
    YearFormat = @YearFormat,
    VersionID = @VersionID,
    EmailHost = @EmailHost,
    EmailPort = @EmailPort,
    EmailCenter = @EmailCenter,
    EmailAdmin = @EmailAdmin,
    EmailPasswordCenter =
        CASE WHEN @EmailPasswordCenter IS NULL THEN EmailPasswordCenter ELSE @EmailPasswordCenter END,
    SuperUserName =
        CASE WHEN @SuperUserName IS NULL THEN SuperUserName ELSE @SuperUserName END,
    PasswordCry =
        CASE WHEN @PasswordCry IS NULL THEN PasswordCry ELSE @PasswordCry END,
    PasswordEmpDefault =
        CASE WHEN @PasswordEmpDefault IS NULL THEN PasswordEmpDefault ELSE @PasswordEmpDefault END,
    PasswordDirect =
        CASE WHEN @PasswordDirect IS NULL THEN PasswordDirect ELSE @PasswordDirect END,
    UpdateDate = SYSUTCDATETIME(),
    UpdateBy = @ActorID
WHERE OwnerType = @OwnerType
  AND (
        (@OwnerType = 'L' AND PartnerID IS NULL AND CompanyID IS NULL)
        OR (@OwnerType = 'P' AND PartnerID = @PartnerID AND CompanyID IS NULL)
        OR (@OwnerType = 'C' AND CompanyID = @CompanyID)
      );
""";

        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@CustomerNameTH", SqlDbType.NVarChar, NullIfBlank(request.CustomerNameTh), 200);
        Add(command, "@CustomerNameEN", SqlDbType.NVarChar, NullIfBlank(request.CustomerNameEn), 200);
        Add(command, "@CustomerAddressText", SqlDbType.NVarChar, NullIfBlank(request.AddressText), 1000);
        Add(command, "@CustomerTelephone", SqlDbType.NVarChar, NullIfBlank(request.Telephone), 50);
        Add(command, "@CustomerTaxID", SqlDbType.NVarChar, NullIfBlank(request.TaxID), 20);
        Add(command, "@Name", SqlDbType.NVarChar, request.Name.Trim(), 200);
        Add(command, "@TitleHeader", SqlDbType.NVarChar, request.TitleHeader.Trim(), 300);
        Add(command, "@RowSTD", SqlDbType.Int, request.RowSTD);
        Add(command, "@RowCardSTD", SqlDbType.Int, request.RowCardSTD);
        Add(command, "@TimeAlert", SqlDbType.Int, request.TimeAlert);
        Add(command, "@OrgStructureType", SqlDbType.Int, request.OrgStructureType);
        Add(command, "@PasswordPolicyCode", SqlDbType.TinyInt, PasswordService.NormalizePolicyCode(request.PasswordPolicyCode));
        Add(command, "@YearFormat", SqlDbType.NVarChar, NullIfBlank(request.YearFormat), 10);
        Add(command, "@VersionID", SqlDbType.NVarChar, NullIfBlank(request.VersionID), 50);
        Add(command, "@EmailHost", SqlDbType.NVarChar, NullIfBlank(request.EmailHost), 255);
        Add(command, "@EmailPort", SqlDbType.Int, request.EmailPort);
        Add(command, "@EmailCenter", SqlDbType.NVarChar, NullIfBlank(request.EmailCenter), 320);
        Add(command, "@EmailAdmin", SqlDbType.NVarChar, NullIfBlank(request.EmailAdmin), 320);
        Add(command, "@EmailPasswordCenter", SqlDbType.NVarChar, emailPasswordCenter, 1000);
        Add(command, "@SuperUserName", SqlDbType.NVarChar, NullIfBlank(request.SuperUserName), 200);
        Add(command, "@PasswordCry", SqlDbType.NVarChar, passwordCry, 500);
        Add(command, "@PasswordEmpDefault", SqlDbType.NVarChar, passwordEmpDefault, 500);
        Add(command, "@PasswordDirect", SqlDbType.NVarChar, passwordDirect, 500);
        Add(command, "@ActorID", SqlDbType.BigInt, actorId);
        Add(command, "@OwnerType", SqlDbType.Char, owner.Value.OwnerType, 1);
        Add(command, "@PartnerID", SqlDbType.BigInt, owner.Value.PartnerID);
        Add(command, "@CompanyID", SqlDbType.BigInt, owner.Value.CompanyID);

        var affected = await command.ExecuteNonQueryAsync(cancellationToken);
        if (additionalOnly)
        await using (var runItem = new SqlCommand("""
IF EXISTS (
    SELECT 1
    FROM dbo.TDSTCompanySetupSystem
    WHERE ProjectID=@ProjectID
      AND OwnerType=@OwnerType
      AND ISNULL(PartnerID,0)=ISNULL(@PartnerID,0)
      AND ISNULL(CompanyID,0)=ISNULL(@CompanyID,0)
)
    UPDATE dbo.TDSTCompanySetupSystem
    SET RunItem=@RunItem,
        MarkItem=@MarkItem,
        ItemDigit=@ItemDigit,
        RunCus=@RunCus,
        MarkCus=@MarkCus,
        CustomerDigit=@CustomerDigit,
        IsActive=1,
        UpdateDate=SYSUTCDATETIME()
    WHERE ProjectID=@ProjectID
      AND OwnerType=@OwnerType
      AND ISNULL(PartnerID,0)=ISNULL(@PartnerID,0)
      AND ISNULL(CompanyID,0)=ISNULL(@CompanyID,0);
ELSE
    INSERT dbo.TDSTCompanySetupSystem
        (ProjectID,OwnerType,PartnerID,CompanyID,RunItem,MarkItem,ItemDigit,RunCus,MarkCus,CustomerDigit,IsActive,CreateDate)
    VALUES
        (@ProjectID,@OwnerType,@PartnerID,@CompanyID,@RunItem,@MarkItem,@ItemDigit,@RunCus,@MarkCus,@CustomerDigit,1,SYSUTCDATETIME());
""", connection, transaction))
        {
            Add(runItem, "@ProjectID", SqlDbType.BigInt, owner.Value.ProjectID);
            Add(runItem, "@OwnerType", SqlDbType.Char, owner.Value.OwnerType, 1);
            Add(runItem, "@PartnerID", SqlDbType.BigInt, owner.Value.PartnerID);
            Add(runItem, "@CompanyID", SqlDbType.BigInt, owner.Value.CompanyID);
            Add(runItem, "@RunItem", SqlDbType.NVarChar, NullIfBlank(request.RunItem), 10);
            Add(runItem, "@MarkItem", SqlDbType.NVarChar, NullIfBlank(request.MarkItem), 20);
            Add(runItem, "@ItemDigit", SqlDbType.Int, request.ItemDigit);
            Add(runItem, "@RunCus", SqlDbType.NVarChar, NullIfBlank(request.RunCus), 10);
            Add(runItem, "@MarkCus", SqlDbType.NVarChar, NullIfBlank(request.MarkCus), 20);
            Add(runItem, "@CustomerDigit", SqlDbType.Int, request.CustomerDigit);
            await runItem.ExecuteNonQueryAsync(cancellationToken);
        }
        if (affected == 0)
            return NotFound(new { message = "ไม่พบ Setup ของเจ้าของที่ Login อยู่" });

        await transaction.CommitAsync(cancellationToken);

        var response = await LoadOwnerSetupAsync(
            connection, owner.Value, cancellationToken);

        if (response is null)
            return NotFound(new { message = "ไม่พบข้อมูลหลังบันทึก ItemDigit" });

        if (additionalOnly && response.ItemDigit != request.ItemDigit)
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "บันทึก ItemDigit ไม่สำเร็จ",
                description = $"ค่าที่ส่งคือ {request.ItemDigit} แต่ค่าที่อ่านกลับจากฐานข้อมูลคือ {response.ItemDigit}"
            });

        if (additionalOnly && (response.CustomerDigit != request.CustomerDigit ||
            !string.Equals(response.RunCus, request.RunCus, StringComparison.OrdinalIgnoreCase)))
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "บันทึกการตั้งค่ารหัสลูกค้าไม่สำเร็จ",
                description = $"ค่าที่ส่ง RunCus={request.RunCus}, CustomerDigit={request.CustomerDigit} " +
                              $"แต่ค่าที่อ่านกลับ RunCus={response.RunCus}, CustomerDigit={response.CustomerDigit}"
            });

        return Ok(response);
    }

    [HttpGet("actions")]
    public async Task<ActionResult<object>> Actions(CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        return Ok(new { view = await AllowedAsync(connection, "VIEW", cancellationToken), edit = await AllowedAsync(connection, "EDIT", cancellationToken) });
    }

    [HttpGet("run-item-options")]
    public async Task<ActionResult<List<CompanySetupOption>>> RunItemOptions(
        [FromQuery] string? groupCode,
        CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        if (!await AllowedAsync(connection, "VIEW", cancellationToken)) return Forbid();
        const string sql = "SELECT Code,Name FROM dbo.TDSTMasterCont WHERE GroupCode=@GroupCode ORDER BY Seq,Code";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@GroupCode", SqlDbType.NVarChar,
            string.IsNullOrWhiteSpace(groupCode)
                ? MasterConstCodes.ItemCodeGeneration
                : groupCode.Trim(),
            10);
        var result = new List<CompanySetupOption>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            result.Add(new CompanySetupOption(reader.GetString(0), reader.GetString(1)));
        return Ok(result);
    }

    private async Task<bool> AllowedAsync(SqlConnection connection, string action, CancellationToken token)
    {
        if (!long.TryParse(User.FindFirstValue("project_id"), out var projectId)) return false;
        var userType = User.FindFirstValue("user_type") ?? string.Empty;
        var isPartner = userType.Equals("PARTNER_USER", StringComparison.OrdinalIgnoreCase);
        var isLaoo = userType.Equals("LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase);
        const string menuCode = "COMPANY_SETUP";
        var sql = isPartner ? """
            SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADPartnerUser U WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND U.IsPartnerAdmin=1 AND U.IsActive=1)
              OR EXISTS(SELECT 1 FROM dbo.TDADPartnerUser U INNER JOIN dbo.TDADPartnerUserPermission UP ON UP.PartnerUserID=U.PartnerUserID INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND U.IsActive=1 AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@menu AND P.ActionCode=@action)
              OR EXISTS(SELECT 1 FROM dbo.TDADPartnerUser U INNER JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.PartnerUserID=U.PartnerUserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=PUE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='P' AND RG.PartnerID=U.PartnerID AND RG.ProjectID=@project INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@menu AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.PartnerID=@partner AND U.NormalizedUsername=@username AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END
            """ : isLaoo ? """
            SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADLaooUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.LaooUserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@menu AND P.ActionCode=@action) THEN 1 ELSE 0 END
            """ : """
            SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.IsActive=1 AND U.IsCompanyAdmin=1)
              OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ScreenCode=@menu AND P.ActionCode=@action)
              OR EXISTS(SELECT 1 FROM dbo.TDADUser U INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@menu AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.UserID=@user AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END
            """;
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@project", SqlDbType.BigInt, projectId); Add(command, "@menu", SqlDbType.NVarChar, menuCode, 20); Add(command, "@action", SqlDbType.NVarChar, action, 50);
        if (isPartner) { Add(command, "@partner", SqlDbType.BigInt, GetLongClaim("partner_id")); Add(command, "@username", SqlDbType.NVarChar, (User.Identity?.Name ?? User.FindFirstValue("unique_name") ?? string.Empty).Trim().ToUpperInvariant(), 100); }
        else Add(command, "@user", SqlDbType.BigInt, GetLongClaim(isLaoo ? "laoo_user_id" : "user_id"));
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private OwnerScope? ResolveOwner()
    {
        // A selected company is the most specific runtime context, including
        // when a LAOO support user is working on behalf of that company.
        var companyId = GetLongClaim("company_id");
        var projectId = GetLongClaim("project_id");
        if (projectId is null)
            return null;

        if (companyId is not null)
            return new OwnerScope(projectId.Value, "C", null, companyId);

        var partnerId = GetLongClaim("partner_id");
        if (partnerId is not null)
            return new OwnerScope(projectId.Value, "P", partnerId, null);

        var loginMode = User.FindFirstValue("login_mode");

        // LAOO account owns the single LAOO setup.
        if (string.Equals(loginMode, "LAOO", StringComparison.OrdinalIgnoreCase))
            return new OwnerScope(projectId.Value, "L", null, null);

        return null;
    }

    private async Task<CompanySetupResponse?> LoadOwnerSetupAsync(
        SqlConnection connection,
        OwnerScope owner,
        CancellationToken cancellationToken)
    {
        const string sql = """
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SELECT
    S.PKValue,
    S.OwnerType,
    S.PartnerID,
    S.CompanyID,
    CASE
        WHEN S.OwnerType = 'L' THEN N'LAOO'
        WHEN S.OwnerType = 'P' THEN COALESCE(P.PartnerCode, S.CompanyCode)
        ELSE S.CompanyCode
    END AS OwnerCode,
    CASE
        WHEN S.OwnerType = 'L' THEN N'Laoo Solutions'
        WHEN S.OwnerType = 'P' THEN COALESCE(P.PartnerCode, S.CompanyCode)
        ELSE COALESCE(NULLIF(S.CustomerNameTH, N''), S.CompanyCode)
    END AS OwnerName,
    S.CustomerNameTH AS CustomerNameTh,
    S.CustomerNameEN AS CustomerNameEn,
    S.AddressText AS AddressText,
    S.Telephone AS Telephone,
    S.TaxID AS TaxID,
    CAST(NULL AS nvarchar(320)) AS CustomerEmail,
    S.Name,
    S.TitleHeader,
    (SELECT TOP 1 RunItem
       FROM dbo.TDSTCompanySetupSystem AS SS
      WHERE SS.ProjectID = @ProjectID
        AND SS.OwnerType = S.OwnerType
        AND ISNULL(SS.PartnerID,0)=ISNULL(@PartnerID,0)
        AND ISNULL(SS.CompanyID,0)=ISNULL(@CompanyID,0)
        AND SS.IsActive=1
    ORDER BY ISNULL(SS.UpdateDate, SS.CreateDate) DESC, SS.PKValue DESC) AS RunItem,
    (SELECT TOP 1 MarkItem
       FROM dbo.TDSTCompanySetupSystem AS SS
      WHERE SS.ProjectID = @ProjectID
        AND SS.OwnerType = S.OwnerType
        AND ISNULL(SS.PartnerID,0)=ISNULL(@PartnerID,0)
        AND ISNULL(SS.CompanyID,0)=ISNULL(@CompanyID,0)
        AND SS.IsActive=1
      ORDER BY ISNULL(SS.UpdateDate, SS.CreateDate) DESC, SS.PKValue DESC) AS MarkItem,
    (SELECT TOP 1 ItemDigit
       FROM dbo.TDSTCompanySetupSystem AS SS
      WHERE SS.ProjectID = @ProjectID
        AND SS.OwnerType = S.OwnerType
        AND ISNULL(SS.PartnerID,0)=ISNULL(@PartnerID,0)
        AND ISNULL(SS.CompanyID,0)=ISNULL(@CompanyID,0)
        AND SS.IsActive=1
      ORDER BY ISNULL(SS.UpdateDate, SS.CreateDate) DESC, SS.PKValue DESC) AS ItemDigit,
    (SELECT TOP 1 RunCus
       FROM dbo.TDSTCompanySetupSystem AS SS
      WHERE SS.ProjectID = @ProjectID
        AND SS.OwnerType = S.OwnerType
        AND ISNULL(SS.PartnerID,0)=ISNULL(@PartnerID,0)
        AND ISNULL(SS.CompanyID,0)=ISNULL(@CompanyID,0)
        AND SS.IsActive=1
    ORDER BY ISNULL(SS.UpdateDate, SS.CreateDate) DESC, SS.PKValue DESC) AS RunCus,
    (SELECT TOP 1 MarkCus
       FROM dbo.TDSTCompanySetupSystem AS SS
      WHERE SS.ProjectID = @ProjectID
        AND SS.OwnerType = S.OwnerType
        AND ISNULL(SS.PartnerID,0)=ISNULL(@PartnerID,0)
        AND ISNULL(SS.CompanyID,0)=ISNULL(@CompanyID,0)
        AND SS.IsActive=1
      ORDER BY ISNULL(SS.UpdateDate, SS.CreateDate) DESC, SS.PKValue DESC) AS MarkCus,
    (SELECT TOP 1 CustomerDigit
       FROM dbo.TDSTCompanySetupSystem AS SS
      WHERE SS.ProjectID = @ProjectID
        AND SS.OwnerType = S.OwnerType
        AND ISNULL(SS.PartnerID,0)=ISNULL(@PartnerID,0)
        AND ISNULL(SS.CompanyID,0)=ISNULL(@CompanyID,0)
        AND SS.IsActive=1
      ORDER BY ISNULL(SS.UpdateDate, SS.CreateDate) DESC, SS.PKValue DESC) AS CustomerDigit,
    S.RowSTD,
    S.RowCardSTD,
    S.TimeAlert,
    S.OrgStructureType,
    CAST(COALESCE(S.PasswordPolicyCode, 3) AS tinyint) AS PasswordPolicyCode,
    S.YearFormat,
    S.VersionID,
    S.EmailHost,
    S.EmailPort,
    S.EmailCenter,
    S.EmailAdmin,
    S.IsActive,
    S.CreateDate,
    S.CreateBy,
    S.UpdateDate,
    S.UpdateBy,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(S.SuperUserName)), N'') IS NULL THEN 0 ELSE 1 END AS bit) AS HasSuperUser,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(S.PasswordCry)), N'') IS NULL THEN 0 ELSE 1 END AS bit) AS HasPasswordCry,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(S.EmailPasswordCenter)), N'') IS NULL THEN 0 ELSE 1 END AS bit) AS HasEmailPasswordCenter,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(S.PasswordEmpDefault)), N'') IS NULL THEN 0 ELSE 1 END AS bit) AS HasPasswordEmpDefault,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(S.PasswordDirect)), N'') IS NULL THEN 0 ELSE 1 END AS bit) AS HasPasswordDirect
FROM dbo.TDSTCompanySetUp AS S
LEFT JOIN dbo.TDADPartner AS P
    ON P.PartnerID = S.PartnerID
WHERE S.OwnerType = @OwnerType
  AND (
        (@OwnerType = 'L' AND S.PartnerID IS NULL AND S.CompanyID IS NULL)
        OR (@OwnerType = 'P' AND S.PartnerID = @PartnerID AND S.CompanyID IS NULL)
        OR (@OwnerType = 'C' AND S.CompanyID = @CompanyID)
      );
""";

        await using var command = new SqlCommand(sql, connection);
        Add(command, "@OwnerType", SqlDbType.Char, owner.OwnerType, 1);
        Add(command, "@PartnerID", SqlDbType.BigInt, owner.PartnerID);
        Add(command, "@CompanyID", SqlDbType.BigInt, owner.CompanyID);
        Add(command, "@ProjectID", SqlDbType.BigInt, owner.ProjectID);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
            return null;

        long? NLong(string name)
        {
            var i = reader.GetOrdinal(name);
            return reader.IsDBNull(i) ? null : reader.GetInt64(i);
        }

        int? NInt(string name)
        {
            var i = reader.GetOrdinal(name);
            return reader.IsDBNull(i) ? null : reader.GetInt32(i);
        }

        string? NString(string name)
        {
            var i = reader.GetOrdinal(name);
            return reader.IsDBNull(i) ? null : reader.GetString(i);
        }

        DateTime? NDate(string name)
        {
            var i = reader.GetOrdinal(name);
            return reader.IsDBNull(i) ? null : reader.GetDateTime(i);
        }

        return new CompanySetupResponse(
            NLong("PKValue"),
            reader.GetString(reader.GetOrdinal("OwnerType")),
            NLong("PartnerID"),
            NLong("CompanyID"),
            reader.GetString(reader.GetOrdinal("OwnerCode")),
            reader.GetString(reader.GetOrdinal("OwnerName")),
            NString("CustomerNameTh"),
            NString("CustomerNameEn"),
            NString("AddressText"),
            NString("Telephone"),
            NString("TaxID"),
            NString("CustomerEmail"),
            reader.GetString(reader.GetOrdinal("Name")),
            reader.GetString(reader.GetOrdinal("TitleHeader")),
            NString("RunItem"),
            NString("MarkItem"),
            reader.IsDBNull(reader.GetOrdinal("ItemDigit"))
                ? 3
                : Convert.ToInt32(reader.GetValue(reader.GetOrdinal("ItemDigit"))),
            NString("RunCus"),
            NString("MarkCus"),
            reader.IsDBNull(reader.GetOrdinal("CustomerDigit"))
                ? 5
                : Convert.ToInt32(reader.GetValue(reader.GetOrdinal("CustomerDigit"))),
            reader.GetInt32(reader.GetOrdinal("RowSTD")),
            reader.GetInt32(reader.GetOrdinal("RowCardSTD")),
            reader.GetInt32(reader.GetOrdinal("TimeAlert")),
            reader.GetInt32(reader.GetOrdinal("OrgStructureType")),
            reader.GetByte(reader.GetOrdinal("PasswordPolicyCode")),
            NString("YearFormat"),
            NString("VersionID"),
            NString("EmailHost"),
            NInt("EmailPort"),
            NString("EmailCenter"),
            NString("EmailAdmin"),
            reader.GetBoolean(reader.GetOrdinal("IsActive")),
            NDate("CreateDate"),
            NLong("CreateBy"),
            NDate("UpdateDate"),
            NLong("UpdateBy"),
            reader.GetBoolean(reader.GetOrdinal("HasSuperUser")),
            reader.GetBoolean(reader.GetOrdinal("HasPasswordCry")),
            reader.GetBoolean(reader.GetOrdinal("HasEmailPasswordCenter")),
            reader.GetBoolean(reader.GetOrdinal("HasPasswordEmpDefault")),
            reader.GetBoolean(reader.GetOrdinal("HasPasswordDirect")));
    }

    private SqlConnection CreateConnection()
    {
        var connectionString =
            _configuration.GetConnectionString("LaooDatabase");

        if (string.IsNullOrWhiteSpace(connectionString))
            throw new InvalidOperationException(
                "ไม่พบ ConnectionStrings:LaooDatabase");

        return new SqlConnection(connectionString);
    }

    private long? GetLongClaim(string type)
    {
        var raw = User.FindFirstValue(type);
        return long.TryParse(raw, out var value) ? value : null;
    }

    private long? GetActorIdFromToken()
    {
        foreach (var claim in new[] { "user_id", "laoo_user_id" })
        {
            var value = GetLongClaim(claim);
            if (value is not null) return value;
        }

        return null;
    }

    private string? HashIfProvided(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
            return null;

        var username =
            User.FindFirstValue(ClaimTypes.Name)
            ?? User.FindFirstValue("username")
            ?? User.FindFirstValue("name")
            ?? User.FindFirstValue("laoo_user_id")
            ?? User.FindFirstValue("user_id")
            ?? "system";

        return _passwordService.HashPassword(username, raw);
    }

    private static string? ValidateRequest(CompanySetupUpdateRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            return "กรุณาระบุชื่อระบบ";
        if (string.IsNullOrWhiteSpace(request.TitleHeader))
            return "กรุณาระบุหัวข้อระบบ";
        if (request.RowSTD <= 0)
            return "จำนวนแถว List ต้องมากกว่า 0";
        if (request.RowCardSTD <= 0)
            return "จำนวน Card ต้องมากกว่า 0";
        if (request.TimeAlert <= 0)
            return "เวลา Alert ต้องมากกว่า 0";
        if (request.ItemDigit is < 1 or > 10)
            return "จำนวนหลักของสินค้าต้องอยู่ระหว่าง 1 ถึง 10";
        if (request.CustomerDigit is < 1 or > 10)
            return "จำนวนหลักของลูกค้าต้องอยู่ระหว่าง 1 ถึง 10";
        if (request.OrgStructureType is not (1 or 2))
            return "รูปแบบโครงสร้างองค์กรต้องเป็น 1 หรือ 2";
        if (request.PasswordPolicyCode is not (1 or 2 or 3))
            return "รูปแบบ Password ต้องเป็น 1, 2 หรือ 3";
        if (request.EmailPort is < 1 or > 65535)
            return "Email Port ต้องอยู่ระหว่าง 1 ถึง 65535";
        if (!string.IsNullOrWhiteSpace(request.PasswordCry)
            && request.PasswordCry.Length < 4)
            return "PasswordCry ต้องอย่างน้อย 4 ตัวอักษร";
        if (!string.IsNullOrWhiteSpace(request.PasswordEmpDefault)
            && request.PasswordEmpDefault.Length < 4)
            return "PasswordEmpDefault ต้องอย่างน้อย 4 ตัวอักษร";

        return null;
    }

    private static string? NullIfBlank(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static void Add(
        SqlCommand command,
        string name,
        SqlDbType type,
        object? value,
        int? size = null)
    {
        var parameter =
            size.HasValue
                ? command.Parameters.Add(name, type, size.Value)
                : command.Parameters.Add(name, type);

        parameter.Value = value ?? DBNull.Value;
    }

    private readonly record struct OwnerScope(
        long ProjectID,
        string OwnerType,
        long? PartnerID,
        long? CompanyID);
}
