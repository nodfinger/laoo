using System.Data;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/travel-settings")]
public sealed class TravelExpenseSettingsController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");

    public sealed record GeneralSettingsRequest(int? DocumentExpiryDays, string? DocumentRevision, string? Remark1, string? Remark2, string? Remark3, string? Remark4, string? Remark5);

    [HttpGet("general")]
    public async Task<IActionResult> General(CancellationToken token)
    {
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || UserId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(db, User, "67001", "VIEW", token)) return Forbid();
        var canEdit = await CompanyProjectPermission.IsAllowedAsync(db, User, "67001", "EDIT", token);
        await using var q = new SqlCommand("SELECT DocumentExpiryDays,DocumentRevision,Remark1,Remark2,Remark3,Remark4,Remark5 FROM dbo.TDSTTravelGeneralSettings WHERE CompanyID=@company", db);
        q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        await using var r = await q.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return Ok(new { canEdit, settings = new GeneralSettingsRequest(null, "", "", "", "", "", "") });
        return Ok(new { canEdit, settings = new GeneralSettingsRequest(r.IsDBNull(0) ? null : r.GetInt32(0), r.GetString(1), r.GetString(2), r.GetString(3), r.GetString(4), r.GetString(5), r.GetString(6)) });
    }

    [HttpPut("general")]
    public async Task<IActionResult> SaveGeneral(GeneralSettingsRequest? input, CancellationToken token)
    {
        if (input is null || input.DocumentExpiryDays < 0 || (input.DocumentRevision?.Length ?? 0) > 100 ||
            new[] { input.Remark1, input.Remark2, input.Remark3, input.Remark4, input.Remark5 }.Any(x => (x?.Length ?? 0) > 1000))
            return BadRequest(new { message = "กรุณาตรวจสอบจำนวนวันและความยาวข้อความ โดย Rev. ไม่เกิน 100 อักษร และหมายเหตุแต่ละช่องไม่เกิน 1,000 อักษร" });
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || UserId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(db, User, "67001", "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        const string sql = """
UPDATE dbo.TDSTTravelGeneralSettings SET DocumentExpiryDays=@days,DocumentRevision=@rev,Remark1=@r1,Remark2=@r2,Remark3=@r3,Remark4=@r4,Remark5=@r5,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company;
IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelGeneralSettings(CompanyID,DocumentExpiryDays,DocumentRevision,Remark1,Remark2,Remark3,Remark4,Remark5,UpdateBy) VALUES(@company,@days,@rev,@r1,@r2,@r3,@r4,@r5,@user);
""";
        await using var q = new SqlCommand(sql, db, tx);
        q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        q.Parameters.Add("@user", SqlDbType.BigInt).Value = UserId;
        q.Parameters.Add("@days", SqlDbType.Int).Value = (object?)input.DocumentExpiryDays ?? DBNull.Value;
        q.Parameters.Add("@rev", SqlDbType.NVarChar, 100).Value = input.DocumentRevision ?? "";
        var remarks = new[] { input.Remark1, input.Remark2, input.Remark3, input.Remark4, input.Remark5 };
        for (var i = 0; i < remarks.Length; i++) q.Parameters.Add("@r" + (i + 1), SqlDbType.NVarChar, 1000).Value = remarks[i] ?? "";
        await q.ExecuteNonQueryAsync(token);
        await tx.CommitAsync(token);
        return Ok(new { saved = true });
    }

    private static readonly HashSet<string> AccessScopes = ["SELF", "DEPARTMENT", "DIVISION"];
    private static readonly HashSet<string> AccessModes = ["ALL", "HEAD"];
    public sealed record TravelAccessRequest(string Scope, string EditMode, string DeleteMode);

    [HttpGet("global-access")]
    public async Task<IActionResult> GlobalAccess(CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || !await CompanyProjectPermission.IsAllowedAsync(db,User,"05001","VIEW",token)) return Forbid();
        var canEdit=await CompanyProjectPermission.IsAllowedAsync(db,User,"05001","EDIT",token);
        await using var q=new SqlCommand("SELECT ViewScope,EditScope,DeleteScope,ViewHead,ViewManager,EditHead,EditManager,DeleteHead,DeleteManager,ViewStaff,EditStaff,DeleteStaff FROM dbo.TDSTCompanyDataAccessDefault WHERE CompanyID=@company",db);
        q.Parameters.AddWithValue("@company",CompanyId);await using var r=await q.ExecuteReaderAsync(token);
        if(!await r.ReadAsync(token)) return Ok(new { canEdit, policy=new CompanyMenuDataAccessController.PolicyRequest("SELF","SELF","SELF",false,false,false,false,false,false,false,false,false) });
        return Ok(new { canEdit, policy=new CompanyMenuDataAccessController.PolicyRequest(r.GetString(0),r.GetString(1),r.GetString(2),r.GetBoolean(3),r.GetBoolean(4),r.GetBoolean(5),r.GetBoolean(6),r.GetBoolean(7),r.GetBoolean(8),r.GetBoolean(9),r.GetBoolean(10),r.GetBoolean(11)) });
    }

    [HttpPut("global-access")]
    public async Task<IActionResult> SaveGlobalAccess(CompanyMenuDataAccessController.PolicyRequest input,CancellationToken token)
    {
        var scopes=new HashSet<string>{"SELF","DEPARTMENT","DIVISION","ALL"};
        if(input is null || !scopes.Contains(input.ViewScope) || !scopes.Contains(input.EditScope) || !scopes.Contains(input.DeleteScope)) return BadRequest();
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await CompanyProjectPermission.IsAllowedAsync(db,User,"05001","EDIT",token)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        const string sql="""
UPDATE dbo.TDSTCompanyDataAccessDefault SET ViewScope=@v,EditScope=@e,DeleteScope=@d,ViewStaff=@vs,ViewHead=@vh,ViewManager=@vm,EditStaff=@es,EditHead=@eh,EditManager=@em,DeleteStaff=@ds,DeleteHead=@dh,DeleteManager=@dm,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company;
IF @@ROWCOUNT=0 INSERT dbo.TDSTCompanyDataAccessDefault(CompanyID,ViewScope,EditScope,DeleteScope,ViewStaff,ViewHead,ViewManager,EditStaff,EditHead,EditManager,DeleteStaff,DeleteHead,DeleteManager,UpdateBy) VALUES(@company,@v,@e,@d,@vs,@vh,@vm,@es,@eh,@em,@ds,@dh,@dm,@user);
""";
        await using var q=new SqlCommand(sql,db,tx);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
        void Add(string prefix,string scope,bool? staff,bool head,bool manager) { q.Parameters.AddWithValue("@"+prefix,scope);q.Parameters.AddWithValue("@"+prefix+"s",scope!="SELF");q.Parameters.AddWithValue("@"+prefix+"h",scope!="SELF" && head);q.Parameters.AddWithValue("@"+prefix+"m",scope is not ("SELF" or "DEPARTMENT") && manager); }
        Add("v",input.ViewScope,input.ViewStaff,input.ViewHead,input.ViewManager);Add("e",input.EditScope,input.EditStaff,input.EditHead,input.EditManager);Add("d",input.DeleteScope,input.DeleteStaff,input.DeleteHead,input.DeleteManager);
        await q.ExecuteNonQueryAsync(token);await tx.CommitAsync(token);return Ok(new { saved=true });
    }

    [HttpGet("access")]
    public async Task<IActionResult> Access(CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "05001", "VIEW", token)) return Forbid();
        var canEdit = await CompanyProjectPermission.IsAllowedAsync(c, User, "05001", "EDIT", token);
        await using var q = new SqlCommand("SELECT ViewScope,EditMode,DeleteMode FROM dbo.TDSTTravelClaimAccess WHERE CompanyID=@company", c);
        q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        await using var r = await q.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return Ok(new { scope="SELF", editMode="HEAD", deleteMode="HEAD", canEdit });
        return Ok(new { scope=r.GetString(0), editMode=r.GetString(1), deleteMode=r.GetString(2), canEdit });
    }

    [HttpPut("access")]
    public async Task<IActionResult> SaveAccess(TravelAccessRequest request, CancellationToken token)
    {
        if (request is null || !AccessScopes.Contains(request.Scope) || !AccessModes.Contains(request.EditMode) || !AccessModes.Contains(request.DeleteMode))
            return BadRequest(new { message="กรุณาเลือกเงื่อนไขการเข้าถึงข้อมูลให้ถูกต้อง" });
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || UserId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "05001", "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        await using var q = new SqlCommand("UPDATE dbo.TDSTTravelClaimAccess SET ViewScope=@scope,EditMode=@edit,DeleteMode=@delete,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company; IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelClaimAccess(CompanyID,ViewScope,EditMode,DeleteMode,UpdateBy) VALUES(@company,@scope,@edit,@delete,@user)",c,tx);
        q.Parameters.AddWithValue("@company",CompanyId); q.Parameters.AddWithValue("@user",UserId);
        q.Parameters.AddWithValue("@scope",request.Scope); q.Parameters.AddWithValue("@edit",request.EditMode); q.Parameters.AddWithValue("@delete",request.DeleteMode);
        await q.ExecuteNonQueryAsync(token); await tx.CommitAsync(token);
        return Ok(new { saved=true });
    }

    [HttpGet("position-levels")]
    public async Task<IActionResult> PositionLevels(CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "10009", "VIEW", token)) return Forbid();
        var canEdit = await CompanyProjectPermission.IsAllowedAsync(c, User, "10009", "EDIT", token);
        const string sql = """
SELECT m.MasterCode,m.Name,p.PositionLevelCode,ISNULL(v.IsVacant,0),v.SubstituteEmployeeID FROM dbo.TDSTMaster m
LEFT JOIN dbo.TDSTTravelPositionLevel p ON p.CompanyID=@company AND p.PositionCode=m.MasterCode
LEFT JOIN dbo.TDSTPositionVacancy v ON v.CompanyID=@company AND v.PositionCode=m.MasterCode
WHERE m.MasterGroupCode=N'008' AND m.OwnerType=N'C' AND ISNULL(m.OwnerPartnerID,0)=0 AND m.OwnerCompanyID=@company ORDER BY m.Seq,m.Name,m.MasterCode;
SELECT MasterCode,Name FROM dbo.TDSTMaster WHERE MasterGroupCode=N'016' AND OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company ORDER BY Seq,Name,MasterCode;
SELECT e.EmployeeID,e.FullName,COALESCE(e.NickName,N''),e.DepartmentOrgUnitID,COALESCE(d.NameTH,N''),e.IsActive FROM dbo.TDADEmployee e LEFT JOIN dbo.TDADOrganizationUnit d ON d.OrgUnitID=e.DepartmentOrgUnitID AND d.CompanyID=e.CompanyID WHERE e.CompanyID=@company AND (e.IsActive=1 OR EXISTS(SELECT 1 FROM dbo.TDSTPositionVacancy v WHERE v.CompanyID=e.CompanyID AND v.SubstituteEmployeeID=e.EmployeeID)) ORDER BY e.FullName,e.EmployeeID;
""";
        await using var q = new SqlCommand(sql, c);
        q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        await using var r = await q.ExecuteReaderAsync(token);
        var positions = new List<object>();
        while (await r.ReadAsync(token)) positions.Add(new { code = r.GetString(0), name = r.GetString(1), level = r.IsDBNull(2) ? null : r.GetString(2), vacant = r.GetBoolean(3), substituteId = r.IsDBNull(4) ? (long?)null : r.GetInt64(4) });
        await r.NextResultAsync(token);
        var levels = new List<object>();
        while (await r.ReadAsync(token)) levels.Add(new { code = r.GetString(0), name = r.GetString(1) });
        await r.NextResultAsync(token);
        var employees = new List<object>();
        while (await r.ReadAsync(token)) employees.Add(new { id=r.GetInt64(0), name=r.GetString(1), nickname=r.GetString(2), departmentId=r.IsDBNull(3) ? (long?)null : r.GetInt64(3), department=r.GetString(4), active=r.GetBoolean(5) });
        return Ok(new { canEdit, positions, levels, employees });
    }

    [HttpPut("position-levels")]
    public async Task<IActionResult> SavePositionLevels([FromBody] TravelPositionLevelsRequest request, CancellationToken token)
    {
        if (request.Items is null || request.Items.Any(x => string.IsNullOrWhiteSpace(x.Code) || x.Code.Length > 10 || x.Level?.Length > 10) ||
            request.Items.Select(x => x.Code).Distinct(StringComparer.OrdinalIgnoreCase).Count() != request.Items.Count)
            return BadRequest(new { message = "กรุณาตรวจสอบตำแหน่งงานและระดับตำแหน่ง" });
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "10009", "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            foreach (var item in request.Items)
            {
                const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'008' AND OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterCode=@code) THROW 54072,N'Invalid position',1;
IF @level IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'016' AND OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterCode=@level) THROW 54072,N'Invalid position level',1;
IF @level IS NULL DELETE dbo.TDSTTravelPositionLevel WHERE CompanyID=@company AND PositionCode=@code;
ELSE BEGIN
 UPDATE dbo.TDSTTravelPositionLevel SET PositionLevelCode=@level,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND PositionCode=@code;
 IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelPositionLevel(CompanyID,PositionCode,PositionLevelCode,UpdateBy) VALUES(@company,@code,@level,@user);
END;
IF @substitute IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.TDADEmployee WHERE CompanyID=@company AND EmployeeID=@substitute AND IsActive=1) AND NOT EXISTS (SELECT 1 FROM dbo.TDSTPositionVacancy WHERE CompanyID=@company AND PositionCode=@code AND SubstituteEmployeeID=@substitute) THROW 54072,N'Invalid employee',1;
UPDATE dbo.TDSTPositionVacancy SET IsVacant=@vacant,SubstituteEmployeeID=@substitute,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND PositionCode=@code;
IF @@ROWCOUNT=0 AND (@vacant=1 OR @substitute IS NOT NULL) INSERT dbo.TDSTPositionVacancy(CompanyID,PositionCode,IsVacant,SubstituteEmployeeID,UpdateBy) VALUES(@company,@code,@vacant,@substitute,@user);
""";
                await using var q = new SqlCommand(sql, c, tx);
                q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
                q.Parameters.Add("@user", SqlDbType.BigInt).Value = UserId;
                q.Parameters.Add("@vacant",SqlDbType.Bit).Value=item.Vacant;
                q.Parameters.Add("@substitute",SqlDbType.BigInt).Value=(object?)item.SubstituteId ?? DBNull.Value;
                q.Parameters.Add("@code", SqlDbType.NVarChar, 10).Value = item.Code;
                q.Parameters.Add("@level", SqlDbType.NVarChar, 10).Value = string.IsNullOrWhiteSpace(item.Level) ? DBNull.Value : item.Level;
                await q.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return Ok(new { saved = true });
        }
        catch (SqlException ex) when (ex.Number == 54072)
        {
            await tx.RollbackAsync(token);
            return BadRequest(new { message = "ไม่พบตำแหน่งงานหรือระดับตำแหน่งของบริษัท กรุณาโหลดข้อมูลใหม่" });
        }
    }

    [HttpGet("lodging-rates")]
    public async Task<IActionResult> LodgingRates(CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "VIEW", token)) return Forbid();
        var canEdit = await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "EDIT", token);
        const string sql = """
SELECT m.MasterCode,m.Name,r.Amount FROM dbo.TDSTMaster m
LEFT JOIN dbo.TDSTTravelLodgingRate r ON r.CompanyID=@company AND r.PositionLevelCode=m.MasterCode
WHERE m.MasterGroupCode=N'016' AND m.OwnerType=N'C' AND ISNULL(m.OwnerPartnerID,0)=0 AND m.OwnerCompanyID=@company
ORDER BY m.Seq,m.Name,m.MasterCode;
""";
        await using var q = new SqlCommand(sql, c);
        q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        var items = new List<object>();
        await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
            items.Add(new { code = r.GetString(0), name = r.GetString(1), rate = r.IsDBNull(2) ? (decimal?)null : r.GetDecimal(2) });
        return Ok(new { canEdit, items });
    }

    [HttpPut("lodging-rates")]
    public async Task<IActionResult> SaveLodgingRates([FromBody] TravelRateRequest request, CancellationToken token)
    {
        if (request.Items is null || request.Items.Any(x => string.IsNullOrWhiteSpace(x.Code) || x.Code.Length > 10 ||
            (x.Rate is decimal rate && (rate < 0 || rate > 9999999999.99m || decimal.Round(rate, 2) != rate))) ||
            request.Items.Select(x => x.Code).Distinct(StringComparer.OrdinalIgnoreCase).Count() != request.Items.Count)
            return BadRequest(new { message = "กรุณาตรวจสอบอัตราค่าห้องพักให้เป็นตัวเลขไม่ติดลบและมีทศนิยมไม่เกิน 2 ตำแหน่ง" });
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        foreach (var item in request.Items)
        {
            const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'016' AND OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterCode=@code)
    THROW 54071,N'Invalid position level',1;
IF @rate IS NULL DELETE FROM dbo.TDSTTravelLodgingRate WHERE CompanyID=@company AND PositionLevelCode=@code;
ELSE BEGIN
 UPDATE dbo.TDSTTravelLodgingRate SET Amount=@rate,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND PositionLevelCode=@code;
 IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelLodgingRate(CompanyID,PositionLevelCode,Amount,UpdateBy) VALUES(@company,@code,@rate,@user);
END;
""";
            await using var q = new SqlCommand(sql, c, tx);
            q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
            q.Parameters.Add("@user", SqlDbType.BigInt).Value = UserId;
            q.Parameters.Add("@code", SqlDbType.NVarChar, 10).Value = item.Code;
            var p = q.Parameters.Add("@rate", SqlDbType.Decimal);
            p.Precision = 12; p.Scale = 2; p.Value = (object?)item.Rate ?? DBNull.Value;
            try { await q.ExecuteNonQueryAsync(token); }
            catch (SqlException ex) when (ex.Number == 54071)
            {
                await tx.RollbackAsync(token);
                return BadRequest(new { message = "ไม่พบระดับตำแหน่งงานของบริษัท กรุณาโหลดข้อมูลใหม่" });
            }
        }
        await tx.CommitAsync(token);
        return Ok(new { saved = true });
    }

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "VIEW", token)) return Forbid();
        var canEdit = await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "EDIT", token);
        const string sql = """
SELECT m.MasterCode,m.Name,r.RatePerKm FROM dbo.TDSTMaster m
LEFT JOIN dbo.TDSTTravelVehicleRate r ON r.CompanyID=@company AND r.VehicleTypeCode=m.MasterCode
WHERE m.MasterGroupCode=N'009' AND m.OwnerType=N'C' AND ISNULL(m.OwnerPartnerID,0)=0 AND m.OwnerCompanyID=@company
ORDER BY m.Seq,m.Name,m.MasterCode
""";
        await using var q = new SqlCommand(sql, c);
        q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        var rows = new List<object>();
        await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) rows.Add(new { code = r.GetString(0), name = r.GetString(1), rate = r.IsDBNull(2) ? (decimal?)null : r.GetDecimal(2) });
        return Ok(new { canEdit, items = rows });
    }

    [HttpPut]
    public async Task<IActionResult> Save([FromBody] TravelRateRequest request, CancellationToken token)
    {
        if (request.Items is null || request.Items.Any(x => string.IsNullOrWhiteSpace(x.Code) || x.Code.Length > 10 || (x.Rate is decimal rate && (rate < 0 || rate > 9999999999.99m || decimal.Round(rate, 2) != rate))) || request.Items.Select(x => x.Code).Distinct(StringComparer.OrdinalIgnoreCase).Count() != request.Items.Count)
            return BadRequest(new { message = "กรุณาตรวจสอบอัตราต่อกิโลเมตรให้เป็นตัวเลขไม่ติดลบและมีทศนิยมไม่เกิน 2 ตำแหน่ง" });
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await CompanyProjectPermission.IsAllowedAsync(c, User, "67001", "EDIT", token)) return Forbid();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        foreach (var item in request.Items)
        {
            const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE MasterGroupCode=N'009' AND OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterCode=@code)
    THROW 54010,N'Invalid vehicle type',1;
IF @rate IS NULL DELETE FROM dbo.TDSTTravelVehicleRate WHERE CompanyID=@company AND VehicleTypeCode=@code;
ELSE BEGIN
 UPDATE dbo.TDSTTravelVehicleRate SET RatePerKm=@rate,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND VehicleTypeCode=@code;
 IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelVehicleRate(CompanyID,VehicleTypeCode,RatePerKm,UpdateBy) VALUES(@company,@code,@rate,@user);
END;
""";
            await using var q = new SqlCommand(sql, c, tx);
            q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
            q.Parameters.Add("@user", SqlDbType.BigInt).Value = UserId;
            q.Parameters.Add("@code", SqlDbType.NVarChar, 10).Value = item.Code;
            var p = q.Parameters.Add("@rate", SqlDbType.Decimal); p.Precision = 12; p.Scale = 2; p.Value = (object?)item.Rate ?? DBNull.Value;
            try { await q.ExecuteNonQueryAsync(token); }
            catch (SqlException ex) when (ex.Number == 54010) { return BadRequest(new { message = "ไม่พบประเภทรถของบริษัท กรุณาโหลดข้อมูลใหม่" }); }
        }
        await tx.CommitAsync(token);
        return Ok(new { saved = true });
    }
}

public sealed record TravelRateItem(string Code, decimal? Rate);
public sealed record TravelRateRequest(List<TravelRateItem> Items);
public sealed record TravelPositionLevelItem(string Code, string? Level, bool Vacant = false, long? SubstituteId = null);
public sealed record TravelPositionLevelsRequest(List<TravelPositionLevelItem> Items);
