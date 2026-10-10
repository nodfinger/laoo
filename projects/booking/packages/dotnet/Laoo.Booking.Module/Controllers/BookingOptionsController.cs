using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Laoo.Booking.Controllers;

[ApiController, Authorize, Route("api/company/booking/options")]
public sealed class BookingOptionsController(IConfiguration config) : ControllerBase
{
    [HttpGet("{menu}")]
    public async Task<IActionResult> Options(string menu, string? q, CancellationToken ct)
    {
        if (menu is not ("61003" or "61004" or "61005" or "61006" or "61007" or "61008" or "61009" or "61010")) return NotFound(new { message = "ไม่พบเมนู", description = "เลือกเมนู Booking ที่รองรับตัวเลือก" });
        if (!BookingAccess.Scope(User, out var company, out _)) return StatusCode(403, new { message = "ไม่มีสิทธิ์เข้าถึงบริษัท", description = "เข้าสู่ระบบด้วยบัญชีบริษัท" });
        await using var d = new SqlConnection(config.GetConnectionString("LaooDatabase"));
        await d.OpenAsync(ct);
        if (!await BookingAccess.Can(d, User, menu, "VIEW", ct)) return StatusCode(403, new { message = "ไม่มีสิทธิ์ดูตัวเลือก", description = "ตรวจสอบสิทธิ์เมนูและแพ็กเกจ Booking" });
        var people = menu is "61003" or "61005" ? await BookingDb.Rows(d, null, "SELECT TOP 50 PersonID id,FullName name FROM dbo.TDADPerson WHERE CompanyID=@c AND IsActive=1 AND (@q IS NULL OR FullName LIKE @pattern) ORDER BY FullName", ct, ("@c", company), ("@q", q), ("@pattern", q is null ? null : $"%{q.Trim()}%")) : [];
        var services = menu is "61003" or "61004" or "61006" or "61007" or "61008" ? await BookingDb.Rows(d, null, "SELECT TOP 200 ServiceID id,ServiceName name,Price price,DurationMinutes durationMinutes,RequiresProvider requiresProvider,RequiresResource requiresResource FROM dbo.TDBKService WHERE CompanyID=@c AND IsActive=1 ORDER BY ServiceName", ct, ("@c", company)) : [];
        var branches = menu is "61004" or "61007" or "61010" ? await BookingDb.Rows(d, null, "SELECT TOP 200 BranchID id,BranchNameTH name FROM dbo.TDADBranch WHERE CompanyID=@c AND IsActive=1 ORDER BY BranchNameTH", ct, ("@c", company)) : [];
        var providers = menu is "61007" or "61008" ? await BookingDb.Rows(d, null, "SELECT TOP 200 P.ProviderID id,X.FullName name FROM dbo.TDBKProvider P JOIN dbo.TDADPerson X ON X.CompanyID=P.CompanyID AND X.PersonID=P.PersonID WHERE P.CompanyID=@c AND P.IsActive=1 AND X.IsActive=1 ORDER BY X.FullName", ct, ("@c", company)) : [];
        var resources = menu is "61007" or "61008" ? await BookingDb.Rows(d, null, "SELECT TOP 200 ResourceID id,BranchID branchId,ResourceName name FROM dbo.TDBKResource WHERE CompanyID=@c AND IsActive=1 ORDER BY ResourceName", ct, ("@c", company)) : [];
        var members = menu is "61007" or "61008" or "61009" ? await BookingDb.Rows(d, null, "SELECT TOP 200 M.MemberID id,M.MemberCode code,P.FullName name,M.TierCode tierCode FROM dbo.TDBKMember M JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID WHERE M.CompanyID=@c AND M.IsActive=1 AND P.IsActive=1 ORDER BY M.MemberCode", ct, ("@c", company)) : [];
        return Ok(new { people, services, branches, providers, resources, members });
    }
}
