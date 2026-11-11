using System.Data;
using Laoo.Shared.Contracts;
using LaooApi.Security;
using LaooApi.Services;
using LaooApi.Services.Assistant;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/travel-claims")]
public sealed class TravelClaimController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");
    private Task<bool> Allowed(SqlConnection db, string action, CancellationToken token) => CompanyProjectPermission.IsAllowedAsync(db, User, "66001", action, token);

    public sealed record TravelAssistantSummaryRequest(DateOnly From, DateOnly To, string Scope, long? OrgUnitId = null, string? Category = null, bool BreakdownByCategory = true);
    private sealed record TravelAssistantClaim(long OwnerId, long? DepartmentId, string Department,
        long? DivisionId, string Division, decimal Fuel, decimal Lodging, decimal Toll,
        decimal Parking, decimal Transport, decimal Total);
    private sealed class TravelAssistantAggregate(string? unitName = null, long? unitId = null)
    {
        public string? UnitName { get; } = unitName;
        public long? UnitId { get; } = unitId;
        public int ClaimCount { get; set; }
        public decimal Fuel { get; set; }
        public decimal Lodging { get; set; }
        public decimal Toll { get; set; }
        public decimal Parking { get; set; }
        public decimal Transport { get; set; }
        public decimal Total { get; set; }
    }

    private sealed record ClaimListRow(long Id, string Number, string Date, string Origin,
        string Destination, decimal Total, string Purpose, string WorkPlace,
        string Claimant, string Department, long OwnerId, long? DivisionId, string Division, long? DepartmentId);

    private async Task<bool> RowAllowed(SqlConnection db, SqlTransaction? tx, long ownerId, string action, CancellationToken token)
    {
        var rule = await MenuDataAccessResolver.ReadRuleAsync(db, tx, CompanyId, "66001", action, token);
        if (rule is null) return true;
        var context = await MenuDataAccessResolver.ReadContextAsync(db, tx, CompanyId, UserId, ownerId, token);
        return MenuDataAccessPolicy.Allows(rule, context);
    }

    private async Task<long?> ClaimOwner(SqlConnection db, SqlTransaction? tx, long id, bool lockRow, CancellationToken token)
    {
        var hint = lockRow ? " WITH (UPDLOCK,HOLDLOCK)" : "";
        await using var q = new SqlCommand($"SELECT UserID FROM dbo.TDSTTravelClaim{hint} WHERE Id=@id AND CompanyID=@company", db, tx);
        q.Parameters.AddWithValue("@id", id);
        q.Parameters.AddWithValue("@company", CompanyId);
        var value = await q.ExecuteScalarAsync(token);
        return value is null or DBNull ? null : Convert.ToInt64(value);
    }

    [HttpGet("vehicle-default")]
    public async Task<IActionResult> VehicleDefault(CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"CREATE",token)) return Forbid();
        const string sql="""
SELECT TOP(1) VehicleTypeCode,VehicleRegistration FROM dbo.TDSTTravelClaim
 WHERE CompanyID=@company AND UserID=@user ORDER BY Id DESC;
SELECT e.CarTypeCode1,e.CarID1,e.CarTypeCode2,e.CarID2
 FROM dbo.TDADEmployee e JOIN dbo.TDADUserEmployee ue ON ue.EmployeeID=e.EmployeeID AND ue.CompanyID=e.CompanyID
 WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1 AND e.IsActive=1
 AND (SELECT COUNT(DISTINCT u.EmployeeID) FROM dbo.TDADUserEmployee u JOIN dbo.TDADEmployee x ON x.CompanyID=u.CompanyID AND x.EmployeeID=u.EmployeeID AND x.IsActive=1 WHERE u.CompanyID=@company AND u.UserID=@user AND u.IsActive=1)=1;
""";
        await using var q=new SqlCommand(sql,db);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
        await using var r=await q.ExecuteReaderAsync(token);
        if(await r.ReadAsync(token)) return Ok(new { vehicle=r.GetString(0),registration=r.GetString(1),source="claim" });
        await r.NextResultAsync(token);
        if(await r.ReadAsync(token)) {
            string? Text(int i) => r.IsDBNull(i) ? null : Convert.ToString(r.GetValue(i))?.Trim();
            var firstType=Text(0);var firstRegistration=Text(1);var secondType=Text(2);var secondRegistration=Text(3);
            var first=!string.IsNullOrWhiteSpace(firstType) || !string.IsNullOrWhiteSpace(firstRegistration);
            return Ok(new { vehicle=first?firstType:secondType,registration=first?firstRegistration:secondRegistration,source="employee" });
        }
        return Ok(new { vehicle=(string?)null,registration=(string?)null,source="none" });
    }

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || UserId <= 0 || !await Allowed(db, "VIEW", token)) return Forbid();
        var create = await Allowed(db, "CREATE", token); var edit = await Allowed(db, "EDIT", token); var delete = await Allowed(db, "DELETE", token);
        var print = await PrintAllowed(db, token);
        const string sql = """
SELECT c.Id,c.ClaimNo,c.ClaimDate,c.Origin,c.Destination,c.TotalAmount,c.Purpose,c.WorkPlace,
 COALESCE(emp.FullName,N''),COALESCE(emp.NickName,N''),COALESCE(emp.DepartmentName,N''),COALESCE(cs.EmployeeNameDisplay,'FULL'),c.UserID,emp.DivisionOrgUnitID,COALESCE(emp.DivisionName,N''),emp.DepartmentOrgUnitID
FROM dbo.TDSTTravelClaim c
OUTER APPLY (SELECT TOP(1) EmployeeNameDisplay FROM dbo.TDSTCompanySetUp WHERE CompanyID=c.CompanyID AND OwnerType='C' AND IsActive=1) cs
OUTER APPLY (SELECT TOP(1) e.FullName,e.NickName,d.NameTH DepartmentName,e.DivisionOrgUnitID,v.NameTH DivisionName,e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue
 JOIN dbo.TDADEmployee e ON e.EmployeeID=ue.EmployeeID AND e.CompanyID=ue.CompanyID
 LEFT JOIN dbo.TDADOrganizationUnit d ON d.OrgUnitID=e.DepartmentOrgUnitID AND d.CompanyID=e.CompanyID
 LEFT JOIN dbo.TDADOrganizationUnit v ON v.OrgUnitID=e.DivisionOrgUnitID AND v.CompanyID=e.CompanyID
 WHERE ue.UserID=c.UserID AND ue.CompanyID=c.CompanyID ORDER BY ue.IsActive DESC,e.EmployeeID) emp
WHERE c.CompanyID=@company ORDER BY c.Id DESC;
SELECT MasterCode,Name FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterGroupCode=N'009' ORDER BY Seq,Name;
SELECT Id,Origin,Destination,DistanceKm FROM dbo.TDSTTravelRoute WHERE CompanyID=@company ORDER BY Origin,Destination;
SELECT v.VehicleTypeCode,v.RatePerKm FROM dbo.TDSTTravelVehicleRate v WHERE v.CompanyID=@company;
SELECT r.RouteID,r.VehicleTypeCode,r.Amount FROM dbo.TDSTTravelRouteRate r WHERE r.CompanyID=@company AND r.RouteID IS NOT NULL;
SELECT CASE WHEN COUNT(DISTINCT l.Amount)=1 THEN MAX(l.Amount) END FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.EmployeeID=ue.EmployeeID AND e.CompanyID=ue.CompanyID AND e.IsActive=1
JOIN dbo.TDSTTravelPositionLevel p ON p.CompanyID=e.CompanyID AND p.PositionCode=e.PositionCode
JOIN dbo.TDSTTravelLodgingRate l ON l.CompanyID=p.CompanyID AND l.PositionLevelCode=p.PositionLevelCode
WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1;
SELECT o.OrgUnitID,o.UnitType,o.ParentOrgUnitID,o.NameTH
FROM dbo.TDADOrganizationUnit o
WHERE o.OwnerType='C' AND o.CompanyID=@company AND o.IsActive=1 AND o.UnitType IN ('DIV','DEP')
 AND (dbo.LaooMenuDataAccessAllowed(@company,@user,0,N'66001','VIEW')=1 OR EXISTS (
    SELECT 1 FROM dbo.TDADUserEmployee ue
    JOIN dbo.TDADUser u ON u.CompanyID=ue.CompanyID AND u.UserID=ue.UserID AND u.IsActive=1
    JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID AND e.IsActive=1
    LEFT JOIN dbo.TDADOrganizationUnit dep ON dep.CompanyID=e.CompanyID AND dep.OrgUnitID=e.DepartmentOrgUnitID AND dep.IsActive=1
    WHERE ue.CompanyID=@company AND ue.IsActive=1
      AND ((o.UnitType='DEP' AND o.OrgUnitID=e.DepartmentOrgUnitID)
        OR (o.UnitType='DIV' AND (o.OrgUnitID=e.DivisionOrgUnitID OR o.OrgUnitID=dep.ParentOrgUnitID)))
      AND dbo.LaooMenuDataAccessAllowed(@company,@user,ue.UserID,N'66001','VIEW')=1
 )) ORDER BY o.UnitType,o.UnitCode;
""";
        await using var q = new SqlCommand(sql, db); q.Parameters.AddWithValue("@company", CompanyId); q.Parameters.AddWithValue("@user", UserId);
        await using var r = await q.ExecuteReaderAsync(token);
        var rows = new List<ClaimListRow>(); while (await r.ReadAsync(token)) rows.Add(new(r.GetInt64(0), r.GetString(1), r.GetDateTime(2).ToString("yyyy-MM-dd"), r.GetString(3), r.GetString(4), r.GetDecimal(5), r.GetString(6), r.GetString(7),
            r.GetString(11)=="NICK" ? (string.IsNullOrWhiteSpace(r.GetString(9)) ? r.GetString(8) : r.GetString(9)) : r.GetString(11)=="BOTH" && !string.IsNullOrWhiteSpace(r.GetString(9)) ? $"{r.GetString(8)} ({r.GetString(9)})" : r.GetString(8), r.GetString(10), Convert.ToInt64(r.GetValue(12)),r.IsDBNull(13)?null:Convert.ToInt64(r.GetValue(13)),r.GetString(14),r.IsDBNull(15)?null:Convert.ToInt64(r.GetValue(15))));
        await r.NextResultAsync(token); var vehicles = new List<object>(); while(await r.ReadAsync(token)) vehicles.Add(new { code=r.GetString(0), name=r.GetString(1) });
        await r.NextResultAsync(token); var routes = new List<object>(); while(await r.ReadAsync(token)) routes.Add(new { id=r.GetInt64(0), origin=r.GetString(1), destination=r.GetString(2), distance=r.GetDecimal(3) });
        await r.NextResultAsync(token); var rates = new List<object>(); while(await r.ReadAsync(token)) rates.Add(new { code=r.GetString(0), rate=r.GetDecimal(1) });
        await r.NextResultAsync(token); var fares = new List<object>(); while(await r.ReadAsync(token)) fares.Add(new { routeId=r.GetInt64(0), code=r.GetString(1), amount=r.GetDecimal(2) });
        await r.NextResultAsync(token); decimal? lodging = await r.ReadAsync(token) && !r.IsDBNull(0) ? r.GetDecimal(0) : null;
        await r.NextResultAsync(token);var organizations=new List<object>();while(await r.ReadAsync(token)) organizations.Add(new {id=Convert.ToInt64(r.GetValue(0)),type=r.GetString(1),parentId=r.IsDBNull(2)?(long?)null:Convert.ToInt64(r.GetValue(2)),name=r.GetString(3)});
        await r.CloseAsync();
        var viewRule = await MenuDataAccessResolver.ReadRuleAsync(db, null, CompanyId, "66001", "VIEW", token);
        var editRule = edit ? await MenuDataAccessResolver.ReadRuleAsync(db, null, CompanyId, "66001", "EDIT", token) : null;
        var deleteRule = delete ? await MenuDataAccessResolver.ReadRuleAsync(db, null, CompanyId, "66001", "DELETE", token) : null;
        var items = new List<object>();
        var contexts = new Dictionary<long, MenuDataAccessContext>();
        foreach (var row in rows)
        {
            if (!contexts.TryGetValue(row.OwnerId, out var context))
            {
                context = viewRule is null && editRule is null && deleteRule is null
                    ? new MenuDataAccessContext(false, UserId, row.OwnerId, null, null, null, null, false, false)
                    : await MenuDataAccessResolver.ReadContextAsync(db, null, CompanyId, UserId, row.OwnerId, token);
                contexts.Add(row.OwnerId, context);
            }
            if (!MenuDataAccessPolicy.Allows(viewRule, context)) continue;
            items.Add(new { id=row.Id, number=row.Number, date=row.Date, origin=row.Origin, destination=row.Destination, total=row.Total,
                purpose=row.Purpose, workPlace=row.WorkPlace, claimant=row.Claimant, department=row.Department, claimantId=row.OwnerId, divisionId=row.DivisionId, division=row.Division, departmentId=row.DepartmentId,
                canEdit=edit && MenuDataAccessPolicy.Allows(editRule, context), canDelete=delete && MenuDataAccessPolicy.Allows(deleteRule, context) });
        }
        return Ok(new { items, vehicles, routes, rates, fares, lodging, organizations, create, edit, delete, print });
    }

    [HttpGet("assistant/options")]
    public async Task<IActionResult> TravelAssistantOptions(CancellationToken token)
    {
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || UserId <= 0 || !await AssistantCapabilityAccess.IsAllowed(db, User, AssistantCapabilities.TravelClaimSummary.Id, token) || !await Allowed(db, "VIEW", token)) return Forbid();
        const string sql = """
SELECT o.OrgUnitID,o.UnitType,o.NameTH
FROM dbo.TDADOrganizationUnit o
WHERE o.OwnerType='C' AND o.CompanyID=@company AND o.IsActive=1 AND o.UnitType IN ('DIV','DEP')
 AND (dbo.LaooMenuDataAccessAllowed(@company,@user,0,N'66001','VIEW')=1 OR EXISTS (
    SELECT 1 FROM dbo.TDSTTravelClaim c
    OUTER APPLY (SELECT TOP(1) e.DepartmentOrgUnitID,e.DivisionOrgUnitID FROM dbo.TDADUserEmployee ue
      JOIN dbo.TDADEmployee e ON e.EmployeeID=ue.EmployeeID AND e.CompanyID=ue.CompanyID AND e.IsActive=1
      WHERE ue.UserID=c.UserID AND ue.CompanyID=c.CompanyID AND ue.IsActive=1 ORDER BY e.EmployeeID) e
    WHERE c.CompanyID=@company AND c.UserID<>@user
      AND ((o.UnitType='DEP' AND o.OrgUnitID=e.DepartmentOrgUnitID)
        OR (o.UnitType='DIV' AND o.OrgUnitID=e.DivisionOrgUnitID))
      AND dbo.LaooMenuDataAccessAllowed(@company,@user,c.UserID,N'66001','VIEW')=1
 )) ORDER BY o.UnitType,o.NameTH,o.OrgUnitID;
""";
        await using var q = new SqlCommand(sql, db);
        q.Parameters.AddWithValue("@company", CompanyId);
        q.Parameters.AddWithValue("@user", UserId);
        await using var reader = await q.ExecuteReaderAsync(token);
        var departments = new List<object>();
        var divisions = new List<object>();
        while (await reader.ReadAsync(token))
        {
            var item = new { id = Convert.ToInt64(reader.GetValue(0)), name = reader.GetString(2) };
            if (reader.GetString(1) == "DEP") departments.Add(item); else divisions.Add(item);
        }
        return Ok(new { departments, divisions });
    }

    [HttpPost("assistant/summary")]
    public async Task<IActionResult> TravelAssistantSummary([FromBody] TravelAssistantSummaryRequest request, CancellationToken token)
    {
        if (request.From > request.To || request.To.DayNumber - request.From.DayNumber > 366)
            return BadRequest(new { message = "กรุณาเลือกช่วงวันที่ไม่เกิน 12 เดือน" });
        var scope = request.Scope?.Trim().ToLowerInvariant();
        if (scope is not ("self" or "department" or "division"))
            return BadRequest(new { message = "ไม่รู้จักขอบเขตการสรุปที่เลือก" });
        var category = request.Category?.Trim().ToLowerInvariant();
        if (category is not null && category is not ("fuel" or "lodging" or "toll" or "parking" or "transport"))
            return BadRequest(new { message = "ไม่รู้จักประเภทค่าใช้จ่ายที่เลือก" });
        if (scope == "self" && request.OrgUnitId is not null)
            return BadRequest(new { message = "การสรุปของฉันไม่ต้องระบุหน่วยงาน" });

        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || UserId <= 0 || !await AssistantCapabilityAccess.IsAllowed(db, User, AssistantCapabilities.TravelClaimSummary.Id, token) || !await Allowed(db, "VIEW", token)) return Forbid();
        if (scope != "self" && request.OrgUnitId is not null)
        {
            var unitType = scope == "department" ? "DEP" : "DIV";
            await using var unit = new SqlCommand("SELECT COUNT_BIG(*) FROM dbo.TDADOrganizationUnit o WHERE o.OrgUnitID=@id AND o.CompanyID=@company AND o.OwnerType='C' AND o.UnitType=@type AND o.IsActive=1 AND (dbo.LaooMenuDataAccessAllowed(@company,@user,0,N'66001','VIEW')=1 OR EXISTS (SELECT 1 FROM dbo.TDSTTravelClaim c OUTER APPLY (SELECT TOP(1) e.DepartmentOrgUnitID,e.DivisionOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.EmployeeID=ue.EmployeeID AND e.CompanyID=ue.CompanyID AND e.IsActive=1 WHERE ue.UserID=c.UserID AND ue.CompanyID=c.CompanyID AND ue.IsActive=1 ORDER BY e.EmployeeID) e WHERE c.CompanyID=@company AND c.UserID<>@user AND ((@type='DEP' AND o.OrgUnitID=e.DepartmentOrgUnitID) OR (@type='DIV' AND o.OrgUnitID=e.DivisionOrgUnitID)) AND dbo.LaooMenuDataAccessAllowed(@company,@user,c.UserID,N'66001','VIEW')=1))", db);
            unit.Parameters.AddWithValue("@id", request.OrgUnitId!.Value);
            unit.Parameters.AddWithValue("@company", CompanyId);
            unit.Parameters.AddWithValue("@user", UserId);
            unit.Parameters.AddWithValue("@type", unitType);
            if (Convert.ToInt64(await unit.ExecuteScalarAsync(token)) == 0) return Forbid();
        }

        const string sql = """
SELECT c.UserID,dep.OrgUnitID,COALESCE(dep.NameTH,N''),div.OrgUnitID,COALESCE(div.NameTH,N''),
       c.FuelAmount,c.LodgingAmount,c.Toll,c.Parking,c.PublicTransport,c.TotalAmount
FROM dbo.TDSTTravelClaim c
OUTER APPLY (
 SELECT TOP(1) e.DepartmentOrgUnitID,e.DivisionOrgUnitID
 FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.EmployeeID=ue.EmployeeID AND e.CompanyID=ue.CompanyID AND e.IsActive=1
 WHERE ue.UserID=c.UserID AND ue.CompanyID=c.CompanyID AND ue.IsActive=1
 ORDER BY ue.IsActive DESC,e.EmployeeID
) e
LEFT JOIN dbo.TDADOrganizationUnit dep ON dep.OrgUnitID=e.DepartmentOrgUnitID AND dep.CompanyID=c.CompanyID
LEFT JOIN dbo.TDADOrganizationUnit div ON div.OrgUnitID=e.DivisionOrgUnitID AND div.CompanyID=c.CompanyID
WHERE c.CompanyID=@company AND c.ClaimDate>=@from AND c.ClaimDate<DATEADD(day,1,@to)
 AND (@self=0 OR c.UserID=@user)
 AND (@unit IS NULL OR (@scope='department' AND e.DepartmentOrgUnitID=@unit) OR (@scope='division' AND e.DivisionOrgUnitID=@unit))
ORDER BY c.ClaimDate,c.Id;
""";
        var claims = new List<TravelAssistantClaim>();
        await using (var q = new SqlCommand(sql, db))
        {
            q.Parameters.AddWithValue("@company", CompanyId);
            q.Parameters.AddWithValue("@user", UserId);
            q.Parameters.Add("@from", SqlDbType.Date).Value = request.From.ToDateTime(TimeOnly.MinValue);
            q.Parameters.Add("@to", SqlDbType.Date).Value = request.To.ToDateTime(TimeOnly.MinValue);
            q.Parameters.Add("@self", SqlDbType.Bit).Value = scope == "self";
            q.Parameters.Add("@unit", SqlDbType.BigInt).Value = (object?)request.OrgUnitId ?? DBNull.Value;
            q.Parameters.Add("@scope", SqlDbType.NVarChar, 20).Value = scope;
            await using var reader = await q.ExecuteReaderAsync(token);
            while (await reader.ReadAsync(token)) claims.Add(new(
                reader.GetInt64(0), reader.IsDBNull(1) ? null : Convert.ToInt64(reader.GetValue(1)), reader.GetString(2),
                reader.IsDBNull(3) ? null : Convert.ToInt64(reader.GetValue(3)), reader.GetString(4),
                reader.GetDecimal(5), reader.GetDecimal(6), reader.GetDecimal(7), reader.GetDecimal(8), reader.GetDecimal(9), reader.GetDecimal(10)));
        }

        var accessByOwner = new Dictionary<long, bool>();
        var grand = new TravelAssistantAggregate();
        var groups = new Dictionary<long, TravelAssistantAggregate>();
        foreach (var claim in claims)
        {
            if (!accessByOwner.TryGetValue(claim.OwnerId, out var canView))
            {
                canView = await RowAllowed(db, null, claim.OwnerId, "VIEW", token);
                accessByOwner[claim.OwnerId] = canView;
            }
            if (!canView) continue;
            Add(claim, grand, category);
            if (scope != "self")
            {
                var unitId = scope == "department" ? claim.DepartmentId : claim.DivisionId;
                var unitName = scope == "department" ? claim.Department : claim.Division;
                if (unitId is not null)
                {
                    if (!groups.TryGetValue(unitId.Value, out var group))
                        groups[unitId.Value] = group = new TravelAssistantAggregate(unitName, unitId);
                    Add(claim, group, category);
                }
            }
        }
        var categories = Categories(grand, category, request.BreakdownByCategory);
        var groupResults = groups.Values.OrderByDescending(x => x.Total).Select(x => new
        {
            id = x.UnitId, name = x.UnitName, claimCount = x.ClaimCount, total = x.Total,
            categories = Categories(x, category, request.BreakdownByCategory)
        }).ToArray();
        var selectedUnit = groupResults.FirstOrDefault(x => x.id == request.OrgUnitId);
        return Ok(new
        {
            from = request.From.ToString("yyyy-MM-dd"), to = request.To.ToString("yyyy-MM-dd"), scope,
            scopeName = scope == "self" ? "ของฉัน" : scope == "department" ? "แผนก" : "ฝ่าย",
            unitName = selectedUnit?.name, claimCount = grand.ClaimCount, total = grand.Total,
            categories, groups = groupResults
        });

        static void Add(TravelAssistantClaim claim, TravelAssistantAggregate aggregate, string? selectedCategory)
        {
            aggregate.ClaimCount++;
            var amount = selectedCategory switch
            {
                "fuel" => claim.Fuel,
                "lodging" => claim.Lodging,
                "toll" => claim.Toll,
                "parking" => claim.Parking,
                "transport" => claim.Transport,
                _ => claim.Total
            };
            aggregate.Total += amount;
            if (selectedCategory is null or "fuel") aggregate.Fuel += claim.Fuel;
            if (selectedCategory is null or "lodging") aggregate.Lodging += claim.Lodging;
            if (selectedCategory is null or "toll") aggregate.Toll += claim.Toll;
            if (selectedCategory is null or "parking") aggregate.Parking += claim.Parking;
            if (selectedCategory is null or "transport") aggregate.Transport += claim.Transport;
        }

        static object[] Categories(TravelAssistantAggregate aggregate, string? selectedCategory, bool showBreakdown)
        {
            if (!showBreakdown && selectedCategory is null) return [];
            var items = new (string Code, string Name, decimal Amount)[]
            {
                ("fuel", "ค่าน้ำมัน/ค่าเดินทาง", aggregate.Fuel), ("lodging", "ค่าที่พัก", aggregate.Lodging),
                ("toll", "ค่าทางด่วน", aggregate.Toll), ("parking", "ค่าจอดรถ", aggregate.Parking),
                ("transport", "ค่าขนส่งสาธารณะ", aggregate.Transport)
            };
            return items.Where(x => (selectedCategory is null || x.Code == selectedCategory) && x.Amount != 0)
                .Select(x => (object)new { code = x.Code, name = x.Name, amount = x.Amount }).ToArray();
        }
    }

    private async Task<bool> PrintAllowed(SqlConnection db, CancellationToken token)
    {
        await using var cmd = new SqlCommand("SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode=N'66001' AND IsActive=1 AND AllowPrint=1) THEN 1 ELSE 0 END AS bit)",db);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token)) && await Allowed(db,"PRINT",token);
    }

    [HttpGet("{id:long}/print")]
    public async Task<IActionResult> Print(long id, CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if (CompanyId<=0 || UserId<=0 || !await PrintAllowed(db,token)) return Forbid();
        // Detail also checks the VIEW action, company and record-level access.
        return await Detail(id,token);
    }

    public sealed record ClaimAttachmentInput(string Name,string Base64);
    public sealed record ClaimInput(DateOnly ClaimDate, long? RouteId, string Origin, string Destination, string Purpose, string WorkPlace, string? MapUrl,
        decimal DistanceKm, DateOnly StartDate, DateOnly EndDate, string VehicleTypeCode, string VehicleRegistration, int Nights, decimal Toll, decimal Parking, decimal PublicTransport, bool IsInterbranch, List<ClaimAttachmentInput>? Attachments, Guid? RequestKey, TimeOnly? StartTime = null, TimeOnly? EndTime = null);

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Detail(long id, CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"VIEW",token)) return Forbid();
        var owner = await ClaimOwner(db, null, id, false, token);
        if (owner is null) return NotFound();
        if (!await RowAllowed(db, null, owner.Value, "VIEW", token)) return Forbid();
        const string sql="""
SELECT ClaimNo,ClaimDate,RouteID,Origin,Destination,Purpose,WorkPlace,MapUrl,DistanceKm,StartDate,EndDate,VehicleTypeCode,VehicleRegistration,Nights,Toll,Parking,PublicTransport,FuelAmount,LodgingAmount,TotalAmount,IsInterbranch,RatePerKm,FlatFare,LodgingRate,StartTime,EndTime
FROM dbo.TDSTTravelClaim WHERE Id=@id AND CompanyID=@company;
SELECT a.Id,a.FileName FROM dbo.TDSTTravelClaimAttachment a JOIN dbo.TDSTTravelClaim c ON c.Id=a.ClaimID AND c.CompanyID=a.CompanyID WHERE c.Id=@id AND c.CompanyID=@company ORDER BY a.Id;
SELECT CASE WHEN COUNT(DISTINCT l.Amount)=1 THEN MAX(l.Amount) END FROM dbo.TDSTTravelClaim c
JOIN dbo.TDADUserEmployee ue ON ue.CompanyID=c.CompanyID AND ue.UserID=c.UserID AND ue.IsActive=1
JOIN dbo.TDADEmployee e ON e.EmployeeID=ue.EmployeeID AND e.CompanyID=ue.CompanyID AND e.IsActive=1
JOIN dbo.TDSTTravelPositionLevel p ON p.CompanyID=e.CompanyID AND p.PositionCode=e.PositionCode
JOIN dbo.TDSTTravelLodgingRate l ON l.CompanyID=p.CompanyID AND l.PositionLevelCode=p.PositionLevelCode
WHERE c.Id=@id AND c.CompanyID=@company;
SELECT COALESCE(s.CustomerNameTH,N''),COALESCE(s.AddressText,N''),
       COALESCE(emp.FullName,N''),COALESCE(emp.EmployeeCode,N''),
       COALESCE(emp.PositionName,N''),COALESCE(emp.DivisionName,N'')
FROM dbo.TDSTTravelClaim c
OUTER APPLY (SELECT TOP (1) CustomerNameTH,AddressText FROM dbo.TDSTCompanySetUp
 WHERE CompanyID=c.CompanyID AND OwnerType='C' AND IsActive=1 ORDER BY CompanyID) s
OUTER APPLY (SELECT TOP (1) e.FullName,e.EmployeeCode,p.Name PositionName,d.NameTH DivisionName
 FROM dbo.TDADUserEmployee ue
 JOIN dbo.TDADEmployee e ON e.EmployeeID=ue.EmployeeID AND e.CompanyID=ue.CompanyID
 LEFT JOIN dbo.TDSTMaster p ON p.OwnerType=N'C' AND ISNULL(p.OwnerPartnerID,0)=0 AND p.OwnerCompanyID=e.CompanyID AND p.MasterGroupCode=N'008' AND p.MasterCode=e.PositionCode
 LEFT JOIN dbo.TDADOrganizationUnit d ON d.OrgUnitID=e.DivisionOrgUnitID AND d.CompanyID=e.CompanyID
 WHERE ue.CompanyID=c.CompanyID AND ue.UserID=c.UserID ORDER BY ue.IsActive DESC,e.EmployeeID) emp
WHERE c.Id=@id AND c.CompanyID=@company;
""";
        await using var q=new SqlCommand(sql,db);q.Parameters.AddWithValue("@id",id);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
        await using var r=await q.ExecuteReaderAsync(token);if(!await r.ReadAsync(token)) return NotFound(new { message="ไม่พบเอกสารในบริษัทของคุณ" });
        var item=new { id,number=r.GetString(0),date=r.GetDateTime(1).ToString("yyyy-MM-dd"),routeId=r.IsDBNull(2)?(long?)null:r.GetInt64(2),origin=r.GetString(3),destination=r.GetString(4),purpose=r.GetString(5),workPlace=r.GetString(6),mapUrl=r.IsDBNull(7)?null:r.GetString(7),distance=r.GetDecimal(8),start=r.GetDateTime(9).ToString("yyyy-MM-dd"),end=r.GetDateTime(10).ToString("yyyy-MM-dd"),vehicle=r.GetString(11),registration=r.GetString(12),nights=r.GetInt32(13),toll=r.GetDecimal(14),parking=r.GetDecimal(15),transport=r.GetDecimal(16),fuel=r.GetDecimal(17),lodging=r.GetDecimal(18),total=r.GetDecimal(19),isInterbranch=r.GetBoolean(20),rate=r.IsDBNull(21)?(decimal?)null:r.GetDecimal(21),flat=r.IsDBNull(22)?(decimal?)null:r.GetDecimal(22),lodgingRate=r.GetDecimal(23),startTime=r.IsDBNull(24)?null:r.GetTimeSpan(24).ToString(@"hh\:mm"),endTime=r.IsDBNull(25)?null:r.GetTimeSpan(25).ToString(@"hh\:mm") };
        await r.NextResultAsync(token);var attachments=new List<object>();while(await r.ReadAsync(token))attachments.Add(new {id=r.GetInt64(0),name=r.GetString(1)});
        await r.NextResultAsync(token); decimal? ownerLodging=await r.ReadAsync(token) && !r.IsDBNull(0) ? r.GetDecimal(0) : null;
        await r.NextResultAsync(token);
        object? printInfo = null;
        if (await r.ReadAsync(token)) printInfo = new { companyName=r.GetString(0), address=r.GetString(1), claimant=r.GetString(2), employeeCode=r.GetString(3), position=r.GetString(4), division=r.GetString(5) };
        return Ok(new {item,attachments,ownerLodging,printInfo});
    }

    [HttpPost("{id:long}/attachments")]
    [RequestSizeLimit(2_500_000)]
    public async Task<IActionResult> Upload(long id, IFormFile? file, CancellationToken token)
    {
        if(file is null || file.Length is <=0 or >2_000_000) return BadRequest(new {message="กรุณาเลือกไฟล์ขนาดไม่เกิน 2 MB"});
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"EDIT",token)) return Forbid();
        await using var data=new MemoryStream(); await file.CopyToAsync(data,token);var bytes=data.ToArray();
        var type=DetectContentType(bytes);
        if(type is null) return BadRequest(new {message="รองรับเฉพาะไฟล์ JPG, PNG, WEBP และ PDF"});
        var name=Path.GetFileName(file.FileName);if(string.IsNullOrWhiteSpace(name) || name.Length>255) return BadRequest(new {message="ชื่อไฟล์ไม่ถูกต้อง"});
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        var owner = await ClaimOwner(db, tx, id, true, token);
        if (owner is null) return NotFound();
        if (!await RowAllowed(db, tx, owner.Value, "EDIT", token)) return Forbid();
        await using var q=new SqlCommand("""
INSERT dbo.TDSTTravelClaimAttachment(ClaimID,CompanyID,FileName,ContentType,FileData)
SELECT Id,CompanyID,@name,@type,@data FROM dbo.TDSTTravelClaim WHERE Id=@id AND CompanyID=@company;
SELECT @@ROWCOUNT;
""",db,tx);
        q.Parameters.AddWithValue("@id",id);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);q.Parameters.AddWithValue("@name",name);q.Parameters.AddWithValue("@type",type);q.Parameters.Add("@data",SqlDbType.VarBinary,-1).Value=bytes;
        var count=Convert.ToInt32(await q.ExecuteScalarAsync(token));
        await tx.CommitAsync(token);
        return count==0 ? NotFound(new {message="ไม่พบเอกสารในบริษัทของคุณ"}) : Ok(new {saved=true});
    }

    [HttpGet("{id:long}/attachments/{attachment:long}")]
    public async Task<IActionResult> Attachment(long id,long attachment,CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"VIEW",token)) return Forbid();
        var owner = await ClaimOwner(db, null, id, false, token);
        if (owner is null) return NotFound();
        if (!await RowAllowed(db, null, owner.Value, "VIEW", token)) return Forbid();
        await using var q=new SqlCommand("SELECT a.FileData,a.ContentType,a.FileName FROM dbo.TDSTTravelClaimAttachment a JOIN dbo.TDSTTravelClaim c ON c.Id=a.ClaimID AND c.CompanyID=a.CompanyID WHERE a.Id=@attachment AND c.Id=@id AND c.CompanyID=@company",db);
        q.Parameters.AddWithValue("@attachment",attachment);q.Parameters.AddWithValue("@id",id);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
        await using var r=await q.ExecuteReaderAsync(token);if(!await r.ReadAsync(token)) return NotFound();
        return File((byte[])r.GetValue(0),r.GetString(1),r.GetString(2));
    }

    [HttpDelete("{id:long}/attachments/{attachment:long}")]
    public async Task<IActionResult> DeleteAttachment(long id,long attachment,CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"EDIT",token)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        var owner = await ClaimOwner(db, tx, id, true, token);
        if (owner is null) return NotFound();
        if (!await RowAllowed(db, tx, owner.Value, "EDIT", token)) return Forbid();
        await using var q=new SqlCommand("DELETE a FROM dbo.TDSTTravelClaimAttachment a JOIN dbo.TDSTTravelClaim c ON c.Id=a.ClaimID AND c.CompanyID=a.CompanyID WHERE a.Id=@attachment AND c.Id=@id AND c.CompanyID=@company",db,tx);
        q.Parameters.AddWithValue("@attachment",attachment);q.Parameters.AddWithValue("@id",id);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
        var count=await q.ExecuteNonQueryAsync(token);
        await tx.CommitAsync(token);
        return count==0 ? NotFound() : NoContent();
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"DELETE",token)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        var owner = await ClaimOwner(db, tx, id, true, token);
        if (owner is null) return NotFound();
        if (!await RowAllowed(db, tx, owner.Value, "DELETE", token)) return Forbid();
        await using var q=new SqlCommand("""
DELETE a FROM dbo.TDSTTravelClaimAttachment a JOIN dbo.TDSTTravelClaim c ON c.Id=a.ClaimID AND c.CompanyID=a.CompanyID WHERE c.Id=@id AND c.CompanyID=@company;
DELETE FROM dbo.TDSTTravelClaim WHERE Id=@id AND CompanyID=@company; SELECT @@ROWCOUNT;
""",db,tx);
        q.Parameters.AddWithValue("@id",id);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
        var count=Convert.ToInt32(await q.ExecuteScalarAsync(token));await tx.CommitAsync(token);
        return count==0 ? NotFound(new {message="ไม่พบเอกสารในบริษัทของคุณ"}) : Ok(new {deleted=true});
    }

    [HttpPost]
    [RequestSizeLimit(30_000_000)]
    public Task<IActionResult> Create(ClaimInput input, CancellationToken token) => Save(null, input, token);
    [HttpPut("{id:long}")]
    [RequestSizeLimit(30_000_000)]
    public Task<IActionResult> Update(long id, ClaimInput input, CancellationToken token) => Save(id, input, token);

    private async Task<IActionResult> Save(long? id, ClaimInput input, CancellationToken token)
    {
        if (input is null || string.IsNullOrWhiteSpace(input.Origin) || input.Origin.Length>200 || string.IsNullOrWhiteSpace(input.Destination) || input.Destination.Length>200 ||
            string.IsNullOrWhiteSpace(input.Purpose) || input.Purpose.Length>500 || string.IsNullOrWhiteSpace(input.WorkPlace) || input.WorkPlace.Length>500 ||
            input.MapUrl?.Length>1000 || string.IsNullOrWhiteSpace(input.VehicleTypeCode) || input.VehicleTypeCode.Length>10 || string.IsNullOrWhiteSpace(input.VehicleRegistration) || input.VehicleRegistration.Length>50 ||
            new[] {input.DistanceKm,input.Toll,input.Parking,input.PublicTransport}.Any(x => x<0 || x>9999999999.99m || decimal.Round(x,2)!=x) || input.Nights<0 || input.Nights>366 || input.ClaimDate.Year is <2000 or >2100 || input.StartDate.Year is <2000 or >2100 || input.EndDate.Year is <2000 or >2100 || input.EndDate.DayNumber-input.StartDate.DayNumber>366 || (input.Attachments?.Count ?? 0)>50 || (id is null && (input.RequestKey is null || input.RequestKey==Guid.Empty)))
            return BadRequest(new { message="กรุณาระบุข้อมูลการเดินทางให้ครบถ้วน" });
        if (input.StartDate == input.EndDate && input.StartTime.HasValue && input.EndTime.HasValue && input.EndTime.Value < input.StartTime.Value)
            return BadRequest(new {message="เวลาสิ้นสุดต้องไม่ก่อนเวลาเริ่มเดินทาง"});
        var files=new List<(string Name,string Type,byte[] Data)>();
        try {
            long totalBytes=0;
            foreach(var file in input.Attachments??[]) {
                var name=Path.GetFileName(file.Name); if(string.IsNullOrWhiteSpace(name) || name.Length>255 || file.Base64 is null || file.Base64.Length>13_333_336) return BadRequest(new {message="ชื่อหรือขนาดไฟล์แนบไม่ถูกต้อง"});
                var bytes=Convert.FromBase64String(file.Base64);totalBytes+=bytes.Length;var type=DetectContentType(bytes);
                if(bytes.Length is <=0 or >2_000_000 || totalBytes>20_000_000 || type is null) return BadRequest(new {message="รองรับ JPG, PNG, WEBP และ PDF ไม่เกิน 2 MB ต่อไฟล์ และรวมไม่เกิน 20 MB"});
                files.Add((name,type,bytes));
            }
        } catch(FormatException) { return BadRequest(new {message="ไม่สามารถอ่านไฟล์แนบ กรุณาเลือกไฟล์ใหม่"}); }
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId<=0 || UserId<=0 || !await Allowed(db,id is null ? "CREATE" : "EDIT",token)) return Forbid();
        var requestHash=System.Security.Cryptography.SHA256.HashData(System.Text.Json.JsonSerializer.SerializeToUtf8Bytes(input));
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try {
            if(id is null) {
                await using(var allocationLock=new SqlCommand("DECLARE @result int,@resource nvarchar(255)=CONCAT(N'LAOO_DOCUMENT_NUMBER:66001:',@company); EXEC @result=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000; IF @result<0 THROW 53965,N'Unable to lock document numbering.',1;",db,tx)) {
                    allocationLock.Parameters.AddWithValue("@company",CompanyId);await allocationLock.ExecuteNonQueryAsync(token);
                }
                await using var existing=new SqlCommand("SELECT Id,ClaimNo,TotalAmount,RequestHash FROM dbo.TDSTTravelClaim WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND UserID=@user AND RequestKey=@key",db,tx);
                existing.Parameters.AddWithValue("@company",CompanyId);existing.Parameters.AddWithValue("@user",UserId);existing.Parameters.AddWithValue("@key",input.RequestKey!.Value);
                await using var reader=await existing.ExecuteReaderAsync(token);
                if(await reader.ReadAsync(token)) { var existingId=reader.GetInt64(0);var existingNo=reader.GetString(1);var existingTotal=reader.GetDecimal(2);var same=!reader.IsDBNull(3) && System.Security.Cryptography.CryptographicOperations.FixedTimeEquals((byte[])reader.GetValue(3),requestHash);await reader.CloseAsync();if(!same)return Conflict(new {message="ใบเบิกจากคำขอนี้บันทึกแล้ว",description="กรุณากลับไปหน้ารายการและเปิดเอกสารเดิมเพื่อแก้ไข"});await tx.CommitAsync(token);return Ok(new {id=existingId,number=existingNo,total=existingTotal}); }
            }
            var ownerId=UserId;
            if(id is not null) {
                await using var ownerQuery=new SqlCommand("SELECT UserID FROM dbo.TDSTTravelClaim WITH(UPDLOCK,HOLDLOCK) WHERE Id=@id AND CompanyID=@company",db,tx);
                ownerQuery.Parameters.AddWithValue("@id",id.Value); ownerQuery.Parameters.AddWithValue("@company",CompanyId); ownerQuery.Parameters.AddWithValue("@user",UserId);
                var owner=await ownerQuery.ExecuteScalarAsync(token); if(owner is null) return NotFound(new {message="ไม่พบเอกสารหรือไม่มีสิทธิ์แก้ไข"});
                ownerId=Convert.ToInt64(owner);
                if (!await RowAllowed(db, tx, ownerId, "EDIT", token)) return Forbid();
            }
            const string lookup="""
IF NOT EXISTS(SELECT 1 FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND ISNULL(OwnerPartnerID,0)=0 AND MasterGroupCode=N'009' AND MasterCode=@vehicle) THROW 54080,N'Invalid vehicle',1;
IF @route IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDSTTravelRoute WHERE CompanyID=@company AND Id=@route AND Origin=@origin AND Destination=@destination) THROW 54081,N'Invalid route',1;
SELECT (SELECT RatePerKm FROM dbo.TDSTTravelVehicleRate WHERE CompanyID=@company AND VehicleTypeCode=@vehicle),
 (SELECT Amount FROM dbo.TDSTTravelRouteRate WHERE CompanyID=@company AND RouteID=@route AND VehicleTypeCode=@vehicle),
 (SELECT CASE WHEN COUNT(DISTINCT l.Amount)=1 THEN MAX(l.Amount) END FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.EmployeeID=ue.EmployeeID AND e.CompanyID=ue.CompanyID AND e.IsActive=1 JOIN dbo.TDSTTravelPositionLevel p ON p.CompanyID=e.CompanyID AND p.PositionCode=e.PositionCode JOIN dbo.TDSTTravelLodgingRate l ON l.CompanyID=p.CompanyID AND l.PositionLevelCode=p.PositionLevelCode WHERE ue.CompanyID=@company AND ue.UserID=@owner AND ue.IsActive=1);
""";
            decimal? rate, flat, lodging;
            await using(var q=new SqlCommand(lookup,db,tx)) {
                q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@owner",ownerId);q.Parameters.AddWithValue("@vehicle",input.VehicleTypeCode);
                q.Parameters.AddWithValue("@route",(object?)input.RouteId??DBNull.Value);q.Parameters.AddWithValue("@origin",input.Origin.Trim());q.Parameters.AddWithValue("@destination",input.Destination.Trim());
                await using var reader=await q.ExecuteReaderAsync(token); await reader.ReadAsync(token);
                rate=reader.IsDBNull(0)?null:reader.GetDecimal(0); flat=reader.IsDBNull(1)?null:reader.GetDecimal(1); lodging=reader.IsDBNull(2)?null:reader.GetDecimal(2);
            }
            if(id is not null) {
                await using var snapshot=new SqlCommand("SELECT RouteID,VehicleTypeCode,RatePerKm,FlatFare,LodgingRate,Nights FROM dbo.TDSTTravelClaim WITH(UPDLOCK,HOLDLOCK) WHERE Id=@id AND CompanyID=@company",db,tx);
                snapshot.Parameters.AddWithValue("@id",id.Value);snapshot.Parameters.AddWithValue("@company",CompanyId);snapshot.Parameters.AddWithValue("@user",UserId);
                await using var reader=await snapshot.ExecuteReaderAsync(token);if(!await reader.ReadAsync(token))return NotFound(new {message="ไม่พบเอกสารในบริษัทของคุณ"});
                var oldRoute=reader.IsDBNull(0)?(long?)null:reader.GetInt64(0);
                if(oldRoute==input.RouteId && string.Equals(reader.GetString(1),input.VehicleTypeCode,StringComparison.OrdinalIgnoreCase)) { rate=reader.IsDBNull(2)?null:reader.GetDecimal(2);flat=reader.IsDBNull(3)?null:reader.GetDecimal(3); }
                if(reader.GetInt32(5)>0 || input.Nights==0) lodging=reader.GetDecimal(4);
            }
            if(input.Nights>0 && lodging is null) return BadRequest(new { message="ไม่พบอัตราค่าที่พักตามตำแหน่งงาน กรุณาให้ผู้ดูแลกำหนดระดับตำแหน่งและอัตราก่อน" });
            var amounts=TravelClaimCalculation.Calculate(input.StartDate,input.EndDate,input.DistanceKm,flat,rate,lodging??0,input.Nights,input.Toll,input.Parking,input.PublicTransport);
            if(amounts.Total>99999999999999.99m) return BadRequest(new {message="ยอดเบิกสูงเกินกว่าที่ระบบรองรับ กรุณาตรวจสอบระยะทางและจำนวนเงิน"});
            string? number;
            if (id is null) {
                await using var q=new SqlCommand(DocumentNumbering.Sql("66001"),db,tx); q.Parameters.AddWithValue("@company",CompanyId); number=(await q.ExecuteScalarAsync(token)) as string;
                if (number is null) {
                    const string fallback="""
DECLARE @lockResult int,@head nvarchar(20)=N'OI'+CONVERT(char(4),DATEPART(year,SYSUTCDATETIME())),@next bigint;
DECLARE @resource nvarchar(255)=CONCAT(N'LAOO_DOCUMENT_NUMBER:66001:',@company);
EXEC @lockResult=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
IF @lockResult<0 THROW 53965,N'Unable to lock document numbering.',1;
SELECT @next=ISNULL(MAX(TRY_CONVERT(bigint,SUBSTRING(ClaimNo,LEN(@head)+1,30))),0)+1 FROM dbo.TDSTTravelClaim WITH(TABLOCKX,HOLDLOCK)
WHERE CompanyID=@company AND LEFT(ClaimNo,LEN(@head))=@head AND LEN(ClaimNo)>LEN(@head) AND SUBSTRING(ClaimNo,LEN(@head)+1,30) NOT LIKE N'%[^0-9]%';
IF @next>9999 THROW 53965,N'Document sequence exhausted.',1;
SELECT @head+RIGHT(N'0000'+CONVERT(nvarchar(20),@next),4);
""";
                    await using var fallbackCommand=new SqlCommand(fallback,db,tx);fallbackCommand.Parameters.AddWithValue("@company",CompanyId);number=(string?)await fallbackCommand.ExecuteScalarAsync(token);
                }
            } else {
                await using var q=new SqlCommand("SELECT ClaimNo FROM dbo.TDSTTravelClaim WITH (UPDLOCK,HOLDLOCK) WHERE Id=@id AND CompanyID=@company",db,tx);
                q.Parameters.AddWithValue("@id",id.Value);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
                number=(await q.ExecuteScalarAsync(token)) as string; if(number is null) return NotFound(new { message="ไม่พบเอกสารในบริษัทของคุณ" });
            }
            const string insert="""
INSERT dbo.TDSTTravelClaim(CompanyID,UserID,ClaimNo,RequestKey,RequestHash,ClaimDate,RouteID,IsInterbranch,Origin,Destination,Purpose,WorkPlace,MapUrl,DistanceKm,StartDate,EndDate,StartTime,EndTime,VehicleTypeCode,VehicleRegistration,RatePerKm,FlatFare,LodgingRate,Nights,Toll,Parking,PublicTransport,FuelAmount,LodgingAmount,TotalAmount)
OUTPUT INSERTED.Id VALUES(@company,@user,@number,@requestKey,@requestHash,@date,@route,@interbranch,@origin,@destination,@purpose,@workplace,@map,@distance,@start,@end,@startTime,@endTime,@vehicle,@registration,@rate,@flat,@lodging,@nights,@toll,@parking,@transport,@fuel,@lodgingAmount,@total);
""";
            const string update="""
UPDATE dbo.TDSTTravelClaim SET ClaimDate=@date,RouteID=@route,IsInterbranch=@interbranch,Origin=@origin,Destination=@destination,Purpose=@purpose,WorkPlace=@workplace,MapUrl=@map,DistanceKm=@distance,StartDate=@start,EndDate=@end,StartTime=@startTime,EndTime=@endTime,VehicleTypeCode=@vehicle,VehicleRegistration=@registration,RatePerKm=@rate,FlatFare=@flat,LodgingRate=@lodging,Nights=@nights,Toll=@toll,Parking=@parking,PublicTransport=@transport,FuelAmount=@fuel,LodgingAmount=@lodgingAmount,TotalAmount=@total,UpdatedAt=SYSUTCDATETIME() OUTPUT INSERTED.Id WHERE Id=@id AND CompanyID=@company;
""";
            await using var cmd=new SqlCommand(id is null ? insert : update,db,tx);
            if(id is not null) cmd.Parameters.AddWithValue("@id",id.Value);
            else { cmd.Parameters.AddWithValue("@requestKey",input.RequestKey!.Value);cmd.Parameters.Add("@requestHash",SqlDbType.VarBinary,32).Value=requestHash; }
            cmd.Parameters.AddWithValue("@company",CompanyId);cmd.Parameters.AddWithValue("@user",UserId);cmd.Parameters.AddWithValue("@number",number);
            cmd.Parameters.AddWithValue("@date",input.ClaimDate.ToDateTime(TimeOnly.MinValue));cmd.Parameters.AddWithValue("@route",(object?)input.RouteId??DBNull.Value);
            cmd.Parameters.AddWithValue("@interbranch",input.IsInterbranch);
            cmd.Parameters.AddWithValue("@origin",input.Origin.Trim());cmd.Parameters.AddWithValue("@destination",input.Destination.Trim());cmd.Parameters.AddWithValue("@purpose",input.Purpose.Trim());cmd.Parameters.AddWithValue("@workplace",input.WorkPlace.Trim());
            cmd.Parameters.AddWithValue("@map",(object?)input.MapUrl?.Trim()??DBNull.Value);cmd.Parameters.AddWithValue("@distance",input.DistanceKm);
            cmd.Parameters.AddWithValue("@start",input.StartDate.ToDateTime(TimeOnly.MinValue));cmd.Parameters.AddWithValue("@end",input.EndDate.ToDateTime(TimeOnly.MinValue));
            cmd.Parameters.Add("@startTime",SqlDbType.Time).Value=(object?)input.StartTime?.ToTimeSpan()??DBNull.Value;
            cmd.Parameters.Add("@endTime",SqlDbType.Time).Value=(object?)input.EndTime?.ToTimeSpan()??DBNull.Value;
            cmd.Parameters.AddWithValue("@vehicle",input.VehicleTypeCode);cmd.Parameters.AddWithValue("@registration",input.VehicleRegistration.Trim());
            cmd.Parameters.AddWithValue("@rate",(object?)rate??DBNull.Value);cmd.Parameters.AddWithValue("@flat",(object?)flat??DBNull.Value);cmd.Parameters.AddWithValue("@lodging",lodging??0);
            cmd.Parameters.AddWithValue("@nights",input.Nights);cmd.Parameters.AddWithValue("@toll",input.Toll);cmd.Parameters.AddWithValue("@parking",input.Parking);cmd.Parameters.AddWithValue("@transport",input.PublicTransport);
            cmd.Parameters.AddWithValue("@fuel",amounts.Fuel);cmd.Parameters.AddWithValue("@lodgingAmount",amounts.Lodging);cmd.Parameters.AddWithValue("@total",amounts.Total);
            var savedId=Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
            foreach(var file in files) {
                await using var attachment=new SqlCommand("INSERT dbo.TDSTTravelClaimAttachment(ClaimID,CompanyID,FileName,ContentType,FileData) VALUES(@id,@company,@name,@type,@data)",db,tx);
                attachment.Parameters.AddWithValue("@id",savedId);attachment.Parameters.AddWithValue("@company",CompanyId);attachment.Parameters.AddWithValue("@name",file.Name);attachment.Parameters.AddWithValue("@type",file.Type);attachment.Parameters.Add("@data",SqlDbType.VarBinary,-1).Value=file.Data;
                await attachment.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);return Ok(new { id=savedId,number,total=amounts.Total });
        } catch(ArgumentException ex) { return BadRequest(new { message=ex.Message }); }
        catch(SqlException ex) when(ex.Number is 54080 or 54081) { return BadRequest(new { message="ไม่พบเส้นทางหรือประเภทรถของบริษัท กรุณาโหลดข้อมูลใหม่" }); }
        catch(OverflowException) { return BadRequest(new { message="จำนวนเงินหรือระยะทางสูงเกินกว่าที่ระบบรองรับ" }); }
    }

    private static string? DetectContentType(byte[] bytes) =>
        bytes.Length>=4 && bytes[0]==0x25 && bytes[1]==0x50 && bytes[2]==0x44 && bytes[3]==0x46 ? "application/pdf" :
        bytes.Length>=3 && bytes[0]==0xff && bytes[1]==0xd8 && bytes[2]==0xff ? "image/jpeg" :
        bytes.Length>=8 && bytes.AsSpan(0,8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10}) ? "image/png" :
        bytes.Length>=12 && System.Text.Encoding.ASCII.GetString(bytes,0,4)=="RIFF" && System.Text.Encoding.ASCII.GetString(bytes,8,4)=="WEBP" ? "image/webp" : null;
}
