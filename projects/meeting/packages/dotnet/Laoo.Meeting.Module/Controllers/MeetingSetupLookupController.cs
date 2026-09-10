using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using LaooMeetingApi.Security;

namespace LaooMeetingApi.Controllers;

[ApiController, Authorize, Route("api/company/meeting-setup-lookups")]
[RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingSetupLookupController(IConfiguration configuration) : ControllerBase
{
    [HttpGet("{screenCode}")]
    public async Task<IActionResult> Get(string screenCode, CancellationToken token)
    {
        if (screenCode is not ("23001" or "23002") ||
            !long.TryParse(User.FindFirstValue("company_id"), out var company)) return Forbid();
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await MeetingFoodPlanAccess.Allowed(db, User, "VIEW", token, screenCode)) return Forbid();
        const string sql = """
SELECT
 JSON_QUERY((SELECT BranchID branchId,BranchCode branchCode,BranchNameTH branchNameTh
 FROM dbo.TDADBranch WHERE CompanyID=@company ORDER BY BranchCode FOR JSON PATH)) branches,
 JSON_QUERY((SELECT B.BuildingID buildingId,B.BranchID branchId,B.BuildingCode code,B.BuildingNameTH nameTh,B.IsActive isActive,
 JSON_QUERY((SELECT F.FloorID floorId,F.BuildingID buildingId,F.FloorCode code,F.FloorNameTH nameTh,F.IsActive isActive
 FROM dbo.TDADFloor F WHERE F.BuildingID=B.BuildingID ORDER BY F.FloorNumber,F.FloorCode FOR JSON PATH)) floors
 FROM dbo.TDADBuilding B WHERE B.CompanyID=@company AND @rooms=1 ORDER BY B.BuildingCode FOR JSON PATH)) buildings,
 JSON_QUERY((SELECT FacilityID facilityId,FacilityCode code,FacilityNameTH nameTh
 FROM dbo.TDADMeetingFacility WHERE CompanyID=@company AND @rooms=1 ORDER BY FacilityCode FOR JSON PATH)) facilities
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
""";
        await using var cmd = new SqlCommand(sql, db);
        cmd.Parameters.AddWithValue("@company", company);
        cmd.Parameters.AddWithValue("@rooms", screenCode == "23002");
        await using var reader = await cmd.ExecuteReaderAsync(token);
        var json = new StringBuilder();
        while (await reader.ReadAsync(token)) json.Append(reader.GetString(0));
        return Content(json.ToString(), "application/json", Encoding.UTF8);
    }
}
