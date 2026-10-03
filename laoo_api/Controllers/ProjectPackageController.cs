using System.Data;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using LaooApi.Models.Partner;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/support/project-packages")]
public sealed class SupportProjectPackageController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] long? projectId, CancellationToken token)
    {
        if (!IsSupport()) return Forbid();
        await using var db = await Open(token);
        if (!await SupportAllowed(db, "VIEW", token)) return Forbid();
        const string sql = """
SELECT P.ProjectID projectId,P.ProjectCode projectCode,P.ProjectNameTH projectNameTh,
 PK.PackageID packageId,PK.PackageCode packageCode,PK.PackageNameTH packageNameTh,
 PK.TierCode tierCode,PK.BillingCycle billingCycle,PK.Price price,RTRIM(PK.CurrencyCode) currencyCode,
 PK.TrialDays trialDays,PK.SortOrder sortOrder,PK.IsActive isActive
FROM dbo.TDADProject P LEFT JOIN dbo.TDADProjectPackage PK ON PK.ProjectID=P.ProjectID
WHERE P.IsActive=1 AND P.ProjectType<>N'CORE' AND (@ProjectID IS NULL OR P.ProjectID=@ProjectID)
ORDER BY P.SortOrder,PK.SortOrder,PK.PackageID FOR JSON PATH;
""";
        await using var cmd = new SqlCommand(sql, db);
        Add(cmd, "@ProjectID", SqlDbType.BigInt, projectId);
        var json = await ReadJson(cmd, token, "[]");
        return new ContentResult { Content = json, ContentType = "application/json", StatusCode = 200 };
    }

    [HttpGet("{packageId:long}")]
    public async Task<IActionResult> GetDetail(long packageId, CancellationToken token)
    {
        if (!IsSupport()) return Forbid();
        await using var db = await Open(token);
        if (!await SupportAllowed(db, "VIEW", token)) return Forbid();
        const string sql = """
SELECT PK.PackageID packageId,PK.ProjectID projectId,PK.PackageCode packageCode,
 PK.PackageNameTH packageNameTh,PK.PackageNameEN packageNameEn,PK.TierCode tierCode,
 PK.BillingCycle billingCycle,PK.Price price,RTRIM(PK.CurrencyCode) currencyCode,
 PK.TrialDays trialDays,PK.SortOrder sortOrder,PK.IsActive isActive,
 JSON_QUERY((SELECT F.FeatureCode featureCode,CAST(CASE WHEN PF.PackageFeatureID IS NULL THEN 0 ELSE 1 END AS bit) isEnabled
  FROM (SELECT DISTINCT M.FeatureCode FROM dbo.TDADMainMenu M
        JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode AND PM.ProjectID=PK.ProjectID AND PM.IsActive=1
        WHERE M.IsActive=1 AND NULLIF(LTRIM(RTRIM(M.FeatureCode)),N'') IS NOT NULL) F
  LEFT JOIN dbo.TDADProjectPackageFeature PF ON PF.PackageID=PK.PackageID AND PF.FeatureCode=F.FeatureCode AND PF.IsEnabled=1
  ORDER BY F.FeatureCode FOR JSON PATH)) features,
 JSON_QUERY((SELECT QuotaCode quotaCode,QuotaNameTH quotaNameTh,LimitValue limitValue,UnitCode unitCode
  FROM dbo.TDADProjectPackageQuota WHERE PackageID=PK.PackageID ORDER BY QuotaCode FOR JSON PATH)) quotas
FROM dbo.TDADProjectPackage PK WHERE PK.PackageID=@ID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER;
""";
        await using var cmd = new SqlCommand(sql, db);
        Add(cmd, "@ID", SqlDbType.BigInt, packageId);
        var json = await ReadJson(cmd, token, "");
        return string.IsNullOrWhiteSpace(json) ? NotFound() : new ContentResult
        { Content = json, ContentType = "application/json", StatusCode = 200 };
    }

    [HttpGet("options/{projectId:long}")]
    public async Task<IActionResult> GetOptions(long projectId, CancellationToken token)
    {
        if (!IsSupport()) return Forbid();
        await using var db = await Open(token);
        if (!await SupportAllowed(db, "VIEW", token)) return Forbid();
        const string sql = """
SELECT DISTINCT M.FeatureCode featureCode,CAST(0 AS bit) isEnabled
FROM dbo.TDADMainMenu M JOIN dbo.TDADProjectMenu PM ON PM.MenuCode=M.MenuCode
WHERE PM.ProjectID=@Project AND PM.IsActive=1 AND M.IsActive=1
 AND NULLIF(LTRIM(RTRIM(M.FeatureCode)),N'') IS NOT NULL
ORDER BY M.FeatureCode FOR JSON PATH;
""";
        await using var cmd = new SqlCommand(sql, db);
        Add(cmd, "@Project", SqlDbType.BigInt, projectId);
        var json = await ReadJson(cmd, token, "[]");
        return new ContentResult { Content = json, ContentType = "application/json", StatusCode = 200 };
    }

    [HttpPost]
    public Task<IActionResult> Create(ProjectPackageUpsertRequest request, CancellationToken token) => Save(null, request, token);

    [HttpPut("{packageId:long}")]
    public Task<IActionResult> Update(long packageId, ProjectPackageUpsertRequest request, CancellationToken token) => Save(packageId, request, token);

    private async Task<IActionResult> Save(long? packageId, ProjectPackageUpsertRequest r, CancellationToken token)
    {
        var validation = Validate(r);
        if (validation is not null) return BadRequest(new { message = "ข้อมูลแพ็กเกจไม่ถูกต้อง", description = validation });
        if (!IsSupport() || !long.TryParse(User.FindFirstValue("laoo_user_id"), out var actor)) return Forbid();
        await using var db = await Open(token);
        if (!await SupportAllowed(db, "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(token);
        try
        {
            var id = await UpsertPackage(db, tx, packageId, r, actor, token);
            await using (var clear = new SqlCommand(
                "DELETE dbo.TDADProjectPackageFeature WHERE PackageID=@ID; DELETE dbo.TDADProjectPackageQuota WHERE PackageID=@ID;", db, tx))
            {
                Add(clear, "@ID", SqlDbType.BigInt, id);
                await clear.ExecuteNonQueryAsync(token);
            }
            foreach (var code in r.Features.Where(x => x.IsEnabled)
                         .Select(x => x.FeatureCode.Trim().ToUpperInvariant()).Where(x => x.Length > 0).Distinct())
            {
                await using var feature = new SqlCommand(
                    "INSERT dbo.TDADProjectPackageFeature(PackageID,FeatureCode,IsEnabled,CreateBy) VALUES(@ID,@Code,1,@Actor);", db, tx);
                Add(feature, "@ID", SqlDbType.BigInt, id); Add(feature, "@Code", SqlDbType.NVarChar, code, 50); Add(feature, "@Actor", SqlDbType.BigInt, actor);
                await feature.ExecuteNonQueryAsync(token);
            }
            foreach (var q in r.Quotas.GroupBy(x => x.QuotaCode.Trim().ToUpperInvariant()).Select(x => x.First()))
            {
                await using var quota = new SqlCommand(
                    "INSERT dbo.TDADProjectPackageQuota(PackageID,QuotaCode,QuotaNameTH,LimitValue,UnitCode,CreateBy) VALUES(@ID,@Code,@Name,@Value,@Unit,@Actor);", db, tx);
                Add(quota, "@ID", SqlDbType.BigInt, id); Add(quota, "@Code", SqlDbType.NVarChar, q.QuotaCode.Trim().ToUpperInvariant(), 50);
                Add(quota, "@Name", SqlDbType.NVarChar, q.QuotaNameTh.Trim(), 200); Add(quota, "@Value", SqlDbType.Decimal, q.LimitValue);
                Add(quota, "@Unit", SqlDbType.NVarChar, q.UnitCode.Trim().ToUpperInvariant(), 30); Add(quota, "@Actor", SqlDbType.BigInt, actor);
                await quota.ExecuteNonQueryAsync(token);
            }
            await SyncCurrentSubscribers(db, tx, id, actor, token);
            await tx.CommitAsync(token);
            return Ok(new { packageId = id });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627)
        {
            await tx.RollbackAsync(token);
            return Conflict(new { message = "รหัสแพ็กเกจซ้ำ", description = "Project นี้มีรหัสแพ็กเกจดังกล่าวแล้ว" });
        }
        catch (SqlException ex) when (ex.Number is 57201 or 57202)
        {
            await tx.RollbackAsync(token);
            return BadRequest(new { message = "ไม่สามารถบันทึกแพ็กเกจได้", description = ex.Number == 57201 ? "Project ส่วนกลางไม่สามารถสร้างแพ็กเกจได้" : "ไม่พบแพ็กเกจที่ต้องการแก้ไข" });
        }
    }

    private static async Task SyncCurrentSubscribers(SqlConnection db, SqlTransaction tx,
        long packageId, long actor, CancellationToken token)
    {
        const string sql = """
UPDATE CF SET CF.IsEnabled=0,CF.UpdateDate=SYSUTCDATETIME(),CF.UpdatedBy=@Actor
FROM dbo.TDADCompanyFeature CF
JOIN dbo.TDADCompanyProjectSubscription S ON S.CompanyID=CF.CompanyID AND S.ProjectID=CF.ProjectID
WHERE S.PackageID=@Package AND S.IsCurrent=1;
MERGE dbo.TDADCompanyFeature AS T
USING (SELECT S.CompanyID,S.PartnerID,S.ProjectID,F.FeatureCode
 FROM dbo.TDADCompanyProjectSubscription S
 JOIN dbo.TDADProjectPackageFeature F ON F.PackageID=S.PackageID AND F.IsEnabled=1
 WHERE S.PackageID=@Package AND S.IsCurrent=1) AS X
ON T.CompanyID=X.CompanyID AND T.ProjectID=X.ProjectID AND T.FeatureCode=X.FeatureCode
WHEN MATCHED THEN UPDATE SET IsEnabled=1,PartnerID=X.PartnerID,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@Actor
WHEN NOT MATCHED THEN INSERT(CompanyID,PartnerID,ProjectID,FeatureCode,IsEnabled,StartDate,CreatedBy)
 VALUES(X.CompanyID,X.PartnerID,X.ProjectID,X.FeatureCode,1,CONVERT(date,SYSUTCDATETIME()),@Actor);
""";
        await using var cmd = new SqlCommand(sql, db, tx);
        Add(cmd, "@Package", SqlDbType.BigInt, packageId);
        Add(cmd, "@Actor", SqlDbType.BigInt, actor);
        await cmd.ExecuteNonQueryAsync(token);
    }

    private static async Task<long> UpsertPackage(SqlConnection db, SqlTransaction tx, long? id,
        ProjectPackageUpsertRequest r, long actor, CancellationToken token)
    {
        const string sql = """
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectID=@ProjectID AND IsActive=1 AND ProjectType<>N'CORE')
 THROW 57201,N'PACKAGE_PROJECT_INVALID',1;
IF @PackageID IS NULL
BEGIN
 INSERT dbo.TDADProjectPackage(ProjectID,PackageCode,PackageNameTH,PackageNameEN,TierCode,BillingCycle,Price,CurrencyCode,TrialDays,SortOrder,IsActive,CreateBy)
 VALUES(@ProjectID,@Code,@NameTH,@NameEN,@Tier,@Cycle,@Price,@Currency,@TrialDays,@SortOrder,@Active,@Actor);
 SELECT CAST(SCOPE_IDENTITY() AS bigint);
END
ELSE
BEGIN
 UPDATE dbo.TDADProjectPackage SET PackageCode=@Code,PackageNameTH=@NameTH,PackageNameEN=@NameEN,TierCode=@Tier,
  BillingCycle=@Cycle,Price=@Price,CurrencyCode=@Currency,TrialDays=@TrialDays,SortOrder=@SortOrder,IsActive=@Active,
  UpdateDate=SYSUTCDATETIME(),UpdateBy=@Actor WHERE PackageID=@PackageID AND ProjectID=@ProjectID;
 IF @@ROWCOUNT=0 THROW 57202,N'PACKAGE_NOT_FOUND',1;
 SELECT @PackageID;
END;
""";
        await using var cmd = new SqlCommand(sql, db, tx);
        Add(cmd, "@PackageID", SqlDbType.BigInt, id); Add(cmd, "@ProjectID", SqlDbType.BigInt, r.ProjectId);
        Add(cmd, "@Code", SqlDbType.NVarChar, r.PackageCode.Trim().ToUpperInvariant(), 50);
        Add(cmd, "@NameTH", SqlDbType.NVarChar, r.PackageNameTh.Trim(), 200);
        Add(cmd, "@NameEN", SqlDbType.NVarChar, string.IsNullOrWhiteSpace(r.PackageNameEn) ? null : r.PackageNameEn.Trim(), 200);
        Add(cmd, "@Tier", SqlDbType.NVarChar, r.TierCode.Trim().ToUpperInvariant(), 30);
        Add(cmd, "@Cycle", SqlDbType.NVarChar, r.BillingCycle.Trim().ToUpperInvariant(), 20);
        Add(cmd, "@Price", SqlDbType.Decimal, r.Price); Add(cmd, "@Currency", SqlDbType.Char, r.CurrencyCode.Trim().ToUpperInvariant(), 3);
        Add(cmd, "@TrialDays", SqlDbType.Int, r.TrialDays); Add(cmd, "@SortOrder", SqlDbType.Int, r.SortOrder);
        Add(cmd, "@Active", SqlDbType.Bit, r.IsActive); Add(cmd, "@Actor", SqlDbType.BigInt, actor);
        return Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
    }

    private static string? Validate(ProjectPackageUpsertRequest r)
    {
        if (r.ProjectId <= 0 || string.IsNullOrWhiteSpace(r.PackageCode) || string.IsNullOrWhiteSpace(r.PackageNameTh)) return "กรุณาระบุ Project รหัส และชื่อแพ็กเกจ";
        if (!new[] { "FREE", "STANDARD", "ENTERPRISE" }.Contains(r.TierCode.Trim().ToUpperInvariant())) return "ระดับแพ็กเกจไม่ถูกต้อง";
        if (!new[] { "NONE", "MONTHLY", "YEARLY" }.Contains(r.BillingCycle.Trim().ToUpperInvariant())) return "รอบบิลไม่ถูกต้อง";
        if (r.Price < 0 || r.TrialDays < 0 || r.Quotas.Any(x => x.LimitValue < -1)) return "ราคา วันทดลองใช้ หรือโควตาไม่ถูกต้อง";
        return null;
    }

    private bool IsSupport() => User.FindFirstValue("user_type") == "LAOO_SUPPORT";
    private async Task<bool> SupportAllowed(SqlConnection db, string action, CancellationToken token)
    {
        if (!long.TryParse(User.FindFirstValue("laoo_user_id"), out var user) ||
            !long.TryParse(User.FindFirstValue("project_id"), out var project)) return false;
        const string sql = """
SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADLaooUser U
 WHERE U.LaooUserID=@User AND U.IsActive=1 AND U.IsSupportUser=1)
 AND EXISTS(SELECT 1 FROM dbo.TDADLaooUserPermission UP
 JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
 WHERE UP.LaooUserID=@User AND UP.ProjectID=@Project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1
 AND ((P.ScreenCode=N'*' AND P.ActionCode=N'ADMIN')
   OR (P.ScreenCode IN(N'06001',N'COMPANY') AND P.ActionCode=@Action)))
 THEN 1 ELSE 0 END AS bit);
""";
        await using var cmd = new SqlCommand(sql, db);
        Add(cmd, "@User", SqlDbType.BigInt, user);
        Add(cmd, "@Project", SqlDbType.BigInt, project);
        Add(cmd, "@Action", SqlDbType.NVarChar, action, 50);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }
    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        return db;
    }
    internal static void Add(SqlCommand cmd, string name, SqlDbType type, object? value, int size = 0)
    {
        var parameter = size > 0 ? cmd.Parameters.Add(name, type, size) : cmd.Parameters.Add(name, type);
        parameter.Value = value ?? DBNull.Value;
    }
    internal static async Task<string> ReadJson(SqlCommand cmd, CancellationToken token, string fallback)
    {
        var value = new StringBuilder();
        await using var reader = await cmd.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token))
            if (!reader.IsDBNull(0)) value.Append(reader.GetString(0));
        return value.Length == 0 ? fallback : value.ToString();
    }
}

[ApiController, Authorize, Route("api/partner/companies/{companyId:long}/subscriptions")]
public sealed class PartnerProjectSubscriptionController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(long companyId, CancellationToken token)
    {
        if (!Scope(out var partner, out _)) return Forbid();
        await using var db = await Open(token);
        if (!await PartnerAllowed(db, partner, "VIEW", token)) return Forbid();
        if (!await OwnsCompany(db, partner, companyId, token))
            return NotFound(Problem("ไม่พบผู้ใช้บริการ", "Company ไม่อยู่ภายใต้ Partner ที่ Login"));
        const string sql = """
SELECT P.ProjectID projectId,P.ProjectCode projectCode,P.ProjectNameTH projectNameTh,
 S.SubscriptionID subscriptionId,S.PackageID packageId,S.StatusCode statusCode,S.StartDate startDate,S.ExpireDate expireDate,
 CASE WHEN S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())) THEN N'FULL'
      WHEN S.StatusCode=N'EXPIRED' OR S.ExpireDate<CONVERT(date,SYSUTCDATETIME()) THEN N'READ_ONLY' ELSE N'BLOCKED' END accessMode,
 JSON_QUERY((SELECT PK.PackageID packageId,PK.PackageCode packageCode,PK.PackageNameTH packageNameTh,
  PK.TierCode tierCode,PK.BillingCycle billingCycle,PK.Price price,RTRIM(PK.CurrencyCode) currencyCode,PK.TrialDays trialDays
  FROM dbo.TDADProjectPackage PK WHERE PK.ProjectID=P.ProjectID AND PK.IsActive=1 ORDER BY PK.SortOrder FOR JSON PATH)) packages
FROM dbo.TDADProject P
LEFT JOIN dbo.TDADCompanyProjectSubscription S ON S.ProjectID=P.ProjectID AND S.CompanyID=@Company AND S.IsCurrent=1
WHERE P.IsActive=1 AND P.ProjectType<>N'CORE' ORDER BY P.SortOrder FOR JSON PATH;
""";
        await using var cmd = new SqlCommand(sql, db);
        Add(cmd, "@Company", SqlDbType.BigInt, companyId);
        var json = await SupportProjectPackageController.ReadJson(cmd, token, "[]");
        return new ContentResult { Content = json, ContentType = "application/json", StatusCode = 200 };
    }

    [HttpPut("{projectId:long}")]
    public async Task<IActionResult> Save(long companyId, long projectId,
        CompanySubscriptionUpdateRequest request, CancellationToken token)
    {
        if (!Scope(out var partner, out var actor)) return Forbid();
        var status = request.StatusCode.Trim().ToUpperInvariant();
        if (!new[] { "TRIAL", "ACTIVE", "EXPIRED", "SUSPENDED", "CANCELLED" }.Contains(status))
            return BadRequest(Problem("สถานะแพ็กเกจไม่ถูกต้อง", "กรุณาเลือกสถานะที่ระบบรองรับ"));
        if (request.StartDate == default || request.ExpireDate < request.StartDate)
            return BadRequest(Problem("ช่วงวันที่ไม่ถูกต้อง", "วันหมดอายุต้องไม่น้อยกว่าวันเริ่มต้น"));
        await using var db = await Open(token);
        if (!await PartnerAllowed(db, partner, "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(token);
        try
        {
            await ValidateTarget(db, tx, partner, companyId, projectId, request.PackageId, token);
            var before = await CurrentJson(db, tx, companyId, projectId, token);
            await CloseCurrent(db, tx, companyId, projectId, actor, token);
            var id = await InsertSubscription(db, tx, partner, companyId, projectId, actor, status, request, token);
            await SyncLegacy(db, tx, partner, companyId, projectId, actor, status, request, token);
            await WriteAudit(db, tx, id, partner, companyId, projectId, actor, status, before, request, token);
            await tx.CommitAsync(token);
            return Ok(new { subscriptionId = id });
        }
        catch (SqlException ex) when (ex.Number is 57211 or 57212)
        {
            await tx.RollbackAsync(token);
            return ex.Number == 57211
                ? NotFound(Problem("ไม่พบผู้ใช้บริการ", "Company ไม่อยู่ภายใต้ Partner ที่ Login"))
                : BadRequest(Problem("แพ็กเกจไม่ถูกต้อง", "แพ็กเกจไม่อยู่ใน Project นี้หรือถูกปิดใช้งาน"));
        }
    }

    private bool Scope(out long partner, out long actor)
    {
        partner = 0;
        actor = 0;
        return User.FindFirstValue("user_type") == "PARTNER_USER" &&
               long.TryParse(User.FindFirstValue("partner_id"), out partner) &&
               long.TryParse(User.FindFirstValue("partner_user_id"), out actor);
    }

    private static async Task ValidateTarget(SqlConnection db, SqlTransaction tx, long partner,
        long company, long project, long package, CancellationToken token)
    {
        const string sql = """
IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanySetUp WITH(UPDLOCK,HOLDLOCK)
 WHERE CompanyID=@Company AND PartnerID=@Partner AND IsActive=1)
 THROW 57211,N'COMPANY_SCOPE_INVALID',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADProjectPackage PK JOIN dbo.TDADProject P ON P.ProjectID=PK.ProjectID
 WHERE PK.PackageID=@Package AND PK.ProjectID=@Project AND PK.IsActive=1 AND P.IsActive=1 AND P.ProjectType<>N'CORE')
 THROW 57212,N'PACKAGE_SCOPE_INVALID',1;
""";
        await using var cmd = new SqlCommand(sql, db, tx);
        Bind(cmd, partner, company, project, package, 0);
        await cmd.ExecuteNonQueryAsync(token);
    }

    private static async Task<string?> CurrentJson(SqlConnection db, SqlTransaction tx,
        long company, long project, CancellationToken token)
    {
        await using var cmd = new SqlCommand(
            "SELECT TOP(1) SubscriptionID subscriptionId,S.PackageID packageId,PK.SortOrder packageSortOrder,StatusCode statusCode,StartDate startDate,ExpireDate expireDate FROM dbo.TDADCompanyProjectSubscription S JOIN dbo.TDADProjectPackage PK ON PK.PackageID=S.PackageID WHERE S.CompanyID=@Company AND S.ProjectID=@Project AND S.IsCurrent=1 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER;", db, tx);
        Add(cmd, "@Company", SqlDbType.BigInt, company); Add(cmd, "@Project", SqlDbType.BigInt, project);
        return Convert.ToString(await cmd.ExecuteScalarAsync(token));
    }

    private static async Task CloseCurrent(SqlConnection db, SqlTransaction tx,
        long company, long project, long actor, CancellationToken token)
    {
        await using var cmd = new SqlCommand(
            "UPDATE dbo.TDADCompanyProjectSubscription SET IsCurrent=0,UpdateDate=SYSUTCDATETIME(),UpdateBy=@Actor WHERE CompanyID=@Company AND ProjectID=@Project AND IsCurrent=1;", db, tx);
        Add(cmd, "@Actor", SqlDbType.BigInt, actor); Add(cmd, "@Company", SqlDbType.BigInt, company); Add(cmd, "@Project", SqlDbType.BigInt, project);
        await cmd.ExecuteNonQueryAsync(token);
    }

    private static async Task<long> InsertSubscription(SqlConnection db, SqlTransaction tx,
        long partner, long company, long project, long actor, string status,
        CompanySubscriptionUpdateRequest r, CancellationToken token)
    {
        const string sql = """
INSERT dbo.TDADCompanyProjectSubscription(PartnerID,CompanyID,ProjectID,PackageID,StatusCode,StartDate,ExpireDate,IsCurrent,ReasonText,CreateBy)
OUTPUT INSERTED.SubscriptionID VALUES(@Partner,@Company,@Project,@Package,@Status,@Start,@Expire,1,@Reason,@Actor);
""";
        await using var cmd = new SqlCommand(sql, db, tx);
        Bind(cmd, partner, company, project, r.PackageId, actor);
        Add(cmd, "@Status", SqlDbType.NVarChar, status, 20);
        Add(cmd, "@Start", SqlDbType.Date, r.StartDate.ToDateTime(TimeOnly.MinValue));
        Add(cmd, "@Expire", SqlDbType.Date, r.ExpireDate?.ToDateTime(TimeOnly.MinValue));
        Add(cmd, "@Reason", SqlDbType.NVarChar, Clean(r.Reason), 500);
        return Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
    }

    private static async Task SyncLegacy(SqlConnection db, SqlTransaction tx, long partner,
        long company, long project, long actor, string status,
        CompanySubscriptionUpdateRequest r, CancellationToken token)
    {
        var enabled = status is "ACTIVE" or "TRIAL" or "EXPIRED";
        const string sql = """
UPDATE dbo.TDADCompanyProject SET PartnerID=@Partner,IsEnabled=@Enabled,IsTrial=@Trial,
 StartDate=@Start,ExpireDate=@Expire,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@Actor
WHERE CompanyID=@Company AND ProjectID=@Project;
IF @@ROWCOUNT=0 INSERT dbo.TDADCompanyProject(ProjectID,PartnerID,CompanyID,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 VALUES(@Project,@Partner,@Company,@Enabled,@Trial,@Start,@Expire,@Actor);

UPDATE dbo.TDADCompanyFeature SET IsEnabled=0,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@Actor
 WHERE CompanyID=@Company AND ProjectID=@Project;
MERGE dbo.TDADCompanyFeature T
USING(SELECT @Project ProjectID,@Partner PartnerID,@Company CompanyID,F.FeatureCode,@Enabled IsEnabled
 FROM dbo.TDADProjectPackageFeature F WHERE F.PackageID=@Package AND F.IsEnabled=1) S
ON T.ProjectID=S.ProjectID AND T.PartnerID=S.PartnerID AND T.CompanyID=S.CompanyID AND T.FeatureCode=S.FeatureCode
WHEN MATCHED THEN UPDATE SET IsEnabled=S.IsEnabled,IsTrial=@Trial,StartDate=@Start,ExpireDate=@Expire,
 UpdateDate=SYSUTCDATETIME(),UpdatedBy=@Actor
WHEN NOT MATCHED THEN INSERT(ProjectID,PartnerID,CompanyID,FeatureCode,IsEnabled,IsTrial,StartDate,ExpireDate,CreatedBy)
 VALUES(S.ProjectID,S.PartnerID,S.CompanyID,S.FeatureCode,S.IsEnabled,@Trial,@Start,@Expire,@Actor);

IF @Enabled=1
BEGIN
 INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive,CreateDate)
 SELECT U.CompanyID,U.UserID,@Project,0,1,SYSUTCDATETIME() FROM dbo.TDADUser U
 WHERE U.CompanyID=@Company AND U.IsActive=1 AND U.IsCompanyAdmin=1
 AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject X
   WHERE X.CompanyID=U.CompanyID AND X.UserID=U.UserID AND X.ProjectID=@Project);
 UPDATE UP SET IsActive=1,UpdateDate=SYSUTCDATETIME() FROM dbo.TDADUserProject UP
 JOIN dbo.TDADUser U ON U.UserID=UP.UserID AND U.CompanyID=UP.CompanyID
  AND U.IsCompanyAdmin=1 AND U.IsActive=1
 WHERE UP.CompanyID=@Company AND UP.ProjectID=@Project;
END;
""";
        await using var cmd = new SqlCommand(sql, db, tx);
        Bind(cmd, partner, company, project, r.PackageId, actor);
        Add(cmd, "@Enabled", SqlDbType.Bit, enabled); Add(cmd, "@Trial", SqlDbType.Bit, status == "TRIAL");
        Add(cmd, "@Start", SqlDbType.Date, r.StartDate.ToDateTime(TimeOnly.MinValue));
        Add(cmd, "@Expire", SqlDbType.Date, r.ExpireDate?.ToDateTime(TimeOnly.MinValue));
        await cmd.ExecuteNonQueryAsync(token);
    }

    private static async Task WriteAudit(SqlConnection db, SqlTransaction tx, long subscription,
        long partner, long company, long project, long actor, string status, string? before,
        CompanySubscriptionUpdateRequest r, CancellationToken token)
    {
        long? previousPackage = null;
        int? previousSort = null;
        if (!string.IsNullOrWhiteSpace(before))
        {
            using var json = JsonDocument.Parse(before);
            if (json.RootElement.TryGetProperty("packageId", out var packageNode)) previousPackage = packageNode.GetInt64();
            if (json.RootElement.TryGetProperty("packageSortOrder", out var sortNode)) previousSort = sortNode.GetInt32();
        }
        var currentSort = await PackageSortOrder(db, tx, r.PackageId, token);
        var action = status switch
        {
            "SUSPENDED" => "SUSPEND",
            "CANCELLED" => "CANCEL",
            "EXPIRED" => "EXPIRE",
            _ when previousPackage is null => "ASSIGN",
            _ when previousPackage == r.PackageId => "RENEW",
            _ when currentSort > previousSort => "UPGRADE",
            _ => "DOWNGRADE"
        };
        const string sql = """
INSERT dbo.TDADCompanyProjectSubscriptionAudit
(SubscriptionID,PartnerID,CompanyID,ProjectID,PackageID,ActionCode,BeforeJson,AfterJson,ReasonText,ActorType,ActorID)
VALUES(@Subscription,@Partner,@Company,@Project,@Package,@Action,@Before,@After,@Reason,N'PARTNER_USER',@Actor);
""";
        await using var cmd = new SqlCommand(sql, db, tx);
        Bind(cmd, partner, company, project, r.PackageId, actor);
        Add(cmd, "@Subscription", SqlDbType.BigInt, subscription);
        Add(cmd, "@Action", SqlDbType.NVarChar, action, 30);
        Add(cmd, "@Before", SqlDbType.NVarChar, before);
        Add(cmd, "@After", SqlDbType.NVarChar, JsonSerializer.Serialize(r));
        Add(cmd, "@Reason", SqlDbType.NVarChar, Clean(r.Reason), 500);
        await cmd.ExecuteNonQueryAsync(token);
    }

    private static async Task<int> PackageSortOrder(SqlConnection db, SqlTransaction tx,
        long packageId, CancellationToken token)
    {
        await using var cmd = new SqlCommand(
            "SELECT SortOrder FROM dbo.TDADProjectPackage WHERE PackageID=@Package;", db, tx);
        Add(cmd, "@Package", SqlDbType.BigInt, packageId);
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(token));
    }

    private static void Bind(SqlCommand cmd, long partner, long company, long project, long package, long actor)
    {
        Add(cmd, "@Partner", SqlDbType.BigInt, partner); Add(cmd, "@Company", SqlDbType.BigInt, company);
        Add(cmd, "@Project", SqlDbType.BigInt, project); Add(cmd, "@Package", SqlDbType.BigInt, package);
        Add(cmd, "@Actor", SqlDbType.BigInt, actor);
    }
    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private async Task<bool> PartnerAllowed(SqlConnection db, long partner, string action, CancellationToken token)
    {
        if (!long.TryParse(User.FindFirstValue("partner_user_id"), out var user) ||
            !long.TryParse(User.FindFirstValue("project_id"), out var project)) return false;
        const string sql = """
SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADPartnerUser U
 WHERE U.PartnerUserID=@User AND U.PartnerID=@Partner AND U.IsActive=1
 AND (U.IsPartnerAdmin=1 OR EXISTS(SELECT 1 FROM dbo.TDADPartnerUserPermission UP
 JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
 WHERE UP.PartnerUserID=U.PartnerUserID AND UP.ProjectID=@Project AND UP.IsAllowed=1 AND UP.IsActive=1
 AND P.IsActive=1 AND P.ScreenCode=N'06001' AND P.ActionCode=@Action)))
 THEN 1 ELSE 0 END AS bit);
""";
        await using var cmd = new SqlCommand(sql, db);
        Add(cmd, "@User", SqlDbType.BigInt, user); Add(cmd, "@Partner", SqlDbType.BigInt, partner);
        Add(cmd, "@Project", SqlDbType.BigInt, project); Add(cmd, "@Action", SqlDbType.NVarChar, action, 50);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }

    private static async Task<bool> OwnsCompany(SqlConnection db, long partner, long company, CancellationToken token)
    {
        await using var cmd = new SqlCommand(
            "SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDSTCompanySetUp WHERE CompanyID=@Company AND PartnerID=@Partner AND IsActive=1) THEN 1 ELSE 0 END AS bit);", db);
        Add(cmd, "@Company", SqlDbType.BigInt, company); Add(cmd, "@Partner", SqlDbType.BigInt, partner);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }

    private async Task<SqlConnection> Open(CancellationToken token)
    {
        var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        return db;
    }
    private static void Add(SqlCommand cmd, string name, SqlDbType type, object? value, int size = 0) =>
        SupportProjectPackageController.Add(cmd, name, type, value, size);
    private static object Problem(string message, string description) => new { message, description };
}

[ApiController, Authorize, Route("api/company/subscriptions")]
public sealed class CompanyProjectSubscriptionController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        if (User.FindFirstValue("user_type") != "COMPANY_USER" ||
            !long.TryParse(User.FindFirstValue("company_id"), out var company)) return Forbid();
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        const string sql = """
SELECT P.ProjectCode projectCode,P.ProjectNameTH projectNameTh,PK.PackageCode packageCode,
 PK.PackageNameTH packageNameTh,S.StatusCode statusCode,S.StartDate startDate,S.ExpireDate expireDate,
 CASE WHEN S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())) THEN N'FULL'
      WHEN S.StatusCode=N'EXPIRED' OR S.ExpireDate<CONVERT(date,SYSUTCDATETIME()) THEN N'READ_ONLY' ELSE N'BLOCKED' END accessMode,
 JSON_QUERY((SELECT Q.QuotaCode quotaCode,Q.QuotaNameTH quotaNameTh,Q.LimitValue limitValue,Q.UnitCode unitCode
  FROM dbo.TDADProjectPackageQuota Q WHERE Q.PackageID=PK.PackageID FOR JSON PATH)) quotas
FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID
JOIN dbo.TDADProjectPackage PK ON PK.PackageID=S.PackageID
WHERE S.CompanyID=@Company AND S.IsCurrent=1 ORDER BY P.SortOrder FOR JSON PATH;
""";
        await using var cmd = new SqlCommand(sql, db);
        SupportProjectPackageController.Add(cmd, "@Company", SqlDbType.BigInt, company);
        var json = await SupportProjectPackageController.ReadJson(cmd, token, "[]");
        return new ContentResult { Content = json, ContentType = "application/json", StatusCode = 200 };
    }
}
