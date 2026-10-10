using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
namespace Laoo.Booking.Controllers;
[ApiController, Authorize, Route("api/company/booking")]
public sealed class BookingController(IConfiguration config) : ControllerBase
{
    long Company => long.Parse(User.FindFirst("company_id")!.Value);
    long Actor => long.Parse(User.FindFirst("user_id")!.Value);
    async Task<SqlConnection> Open(CancellationToken ct) { var d = new SqlConnection(config.GetConnectionString("LaooDatabase")); await d.OpenAsync(ct); return d; }
    async Task<IActionResult?> Guard(SqlConnection db, string m, string a, CancellationToken ct) { if (!BookingAccess.Scope(User, out _, out _)) return StatusCode(403, new { message = "ไม่สามารถเข้าถึงข้อมูลบริษัทได้", description = "กรุณาเข้าสู่ระบบด้วยบัญชีบริษัทที่มีสิทธิ์ใช้งาน" }); if (!await BookingAccess.Can(db, User, m, a, ct)) return StatusCode(403, new { message = "ไม่มีสิทธิ์ดำเนินการ", description = "ตรวจสอบสิทธิ์เมนู ระบบที่เปิดใช้งาน และการกำหนดสิทธิ์ของผู้ใช้" }); return null; }
    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, menu, "VIEW", ct) is { } no) return no;
        var metadata = await BookingDb.Rows(d, null, "SELECT MenuName,ScreenType,IconName FROM dbo.TDADMainMenu WHERE MenuCode=@m AND IsActive=1", ct, ("@m", menu));
        if (metadata.Count == 0) return NotFound(new { message = "ไม่พบเมนู Booking", description = "ตรวจสอบ MenuCode และสถานะเมนูในระบบส่วนกลาง" });
        var permissions = await BookingDb.Rows(d, null, "SELECT ActionCode FROM dbo.TDADPermission P JOIN dbo.TDADProject J ON J.ProjectID=P.ProjectID WHERE J.ProjectCode=N'LAOO_BOOKING' AND P.ScreenCode=@m AND P.IsActive=1", ct, ("@m", menu));
        var actions = new Dictionary<string, bool>();
        foreach (var row in permissions) { var a = Convert.ToString(row["ActionCode"])!; actions[a.ToLowerInvariant()] = await BookingAccess.Can(d, User, menu, a, ct); }
        return Ok(new { metadata = metadata[0], actions });
    }
    [HttpGet("services")]
    public async Task<IActionResult> Services(CancellationToken ct, int? page = null, int pageSize = 20)
    {
        if (BookingDb.InvalidPage(page, pageSize)) return BadRequest(new { message = "เลขหน้าไม่ถูกต้อง", description = "เลือกหน้าตั้งแต่ 1 และจำนวนไม่เกิน 100 รายการต่อหน้า" });
        await using var d = await Open(ct);
        if (await Guard(d, "61002", "VIEW", ct) is { } no) return no;
        const string sql = "SELECT ServiceID id,ServiceCode code,ServiceName name,DurationMinutes durationMinutes,Price price,RequiresProvider requiresProvider,RequiresResource requiresResource,IsActive active FROM dbo.TDBKService WHERE CompanyID=@c ORDER BY ServiceID DESC";
        return Ok(page is null ? await BookingDb.Rows(d, null, sql, ct, ("@c", Company)) : await BookingDb.CompanyPage(d, sql, "SELECT COUNT(*) FROM dbo.TDBKService WHERE CompanyID=@c", Company, page.Value, pageSize, ct));
    }
    [HttpPost("services")]
    public async Task<IActionResult> CreateService(CreateServiceRequest x, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(x.ServiceCode) || string.IsNullOrWhiteSpace(x.ServiceName) || x.DurationMinutes < 1 || x.Price < 0) return BadRequest(new { message = "Invalid service", description = "Provide a name, positive duration and non-negative price" });
        await using var d = await Open(ct);
        if (await Guard(d, "61002", "CREATE", ct) is { } no) return no;
        try { var id = await BookingDb.Id(d, null, "INSERT dbo.TDBKService(CompanyID,ServiceCode,ServiceName,DurationMinutes,Price,RequiresProvider,RequiresResource) VALUES(@c,@code,@name,@duration,@price,@provider,@resource);SELECT SCOPE_IDENTITY();", ct, ("@c", Company), ("@code", x.ServiceCode.Trim()), ("@name", x.ServiceName.Trim()), ("@duration", x.DurationMinutes), ("@price", x.Price), ("@provider", x.RequiresProvider), ("@resource", x.RequiresResource)); return Created($"/api/company/booking/services/{id}", new { id }); }
        catch (SqlException) { return Conflict(new { message = "Service code already exists", description = "Use a different service code or edit the existing service" }); }
    }
    [HttpPut("services/{id:long}")]
    public async Task<IActionResult> UpdateService(long id, UpdateServiceRequest x, CancellationToken ct)
    {
        if (id <= 0 || string.IsNullOrWhiteSpace(x.ServiceName) || x.DurationMinutes < 1 || x.Price < 0) return BadRequest(new { message = "ข้อมูลบริการไม่ถูกต้อง", description = "กรอกชื่อ ระยะเวลามากกว่า 0 นาที และราคาไม่ติดลบ" });
        await using var d = await Open(ct);
        if (await Guard(d, "61002", "EDIT", ct) is { } no) return no;
        var n = await BookingDb.Exec(d, null, "UPDATE dbo.TDBKService SET ServiceName=@name,DurationMinutes=@duration,Price=@price,RequiresProvider=@provider,RequiresResource=@resource WHERE CompanyID=@c AND ServiceID=@id AND IsActive=1", ct, ("@name", x.ServiceName.Trim()), ("@duration", x.DurationMinutes), ("@price", x.Price), ("@provider", x.RequiresProvider), ("@resource", x.RequiresResource), ("@c", Company), ("@id", id));
        return n == 0 ? NotFound(new { message = "ไม่พบบริการ", description = "บริการอาจถูกปิดใช้งานหรือไม่ได้อยู่ในบริษัทนี้" }) : NoContent();
    }
    [HttpDelete("services/{id:long}")]
    public async Task<IActionResult> DeactivateService(long id, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61002", "DELETE", ct) is { } no) return no;
        var n = await BookingDb.Exec(d, null, "UPDATE dbo.TDBKService SET IsActive=0 WHERE CompanyID=@c AND ServiceID=@id AND IsActive=1", ct, ("@c", Company), ("@id", id));
        return n == 0 ? NotFound(new { message = "ไม่พบบริการ", description = "บริการอาจถูกปิดใช้งานหรือไม่ได้อยู่ในบริษัทนี้" }) : NoContent();
    }
    [HttpGet("providers")]
    public async Task<IActionResult> Providers(CancellationToken ct, int? page = null, int pageSize = 20)
    {
        if (BookingDb.InvalidPage(page, pageSize)) return BadRequest(new { message = "เลขหน้าไม่ถูกต้อง", description = "เลือกหน้าตั้งแต่ 1 และจำนวนไม่เกิน 100 รายการต่อหน้า" });
        await using var d = await Open(ct);
        if (await Guard(d, "61003", "VIEW", ct) is { } no) return no;
        const string sql = "SELECT P.ProviderID id,P.PersonID personId,X.FullName name,P.IsActive active FROM dbo.TDBKProvider P JOIN dbo.TDADPerson X ON X.CompanyID=P.CompanyID AND X.PersonID=P.PersonID WHERE P.CompanyID=@c ORDER BY X.FullName,P.ProviderID";
        return Ok(page is null ? await BookingDb.Rows(d, null, sql, ct, ("@c", Company)) : await BookingDb.CompanyPage(d, sql, "SELECT COUNT(*) FROM dbo.TDBKProvider WHERE CompanyID=@c", Company, page.Value, pageSize, ct));
    }
    [HttpPost("providers")]
    public async Task<IActionResult> CreateProvider(CreateProviderRequest x, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61003", "CREATE", ct) is { } no) return no;
        if (x.PersonId <= 0 || await BookingDb.Id(d, null, "SELECT COUNT(*) FROM dbo.TDADPerson WHERE CompanyID=@c AND PersonID=@p AND IsActive=1", ct, ("@c", Company), ("@p", x.PersonId)) == 0) return BadRequest(new { message = "ไม่พบบุคลากร", description = "เลือกข้อมูลบุคคลที่เปิดใช้งานอยู่ในบริษัทนี้" });
        try { var id = await BookingDb.Id(d, null, "INSERT dbo.TDBKProvider(CompanyID,PersonID) VALUES(@c,@p);SELECT SCOPE_IDENTITY()", ct, ("@c", Company), ("@p", x.PersonId)); return Created($"/api/company/booking/providers/{id}", new { id }); }
        catch (SqlException) { return Conflict(new { message = "บุคคลนี้เป็นผู้ให้บริการแล้ว", description = "เลือกบุคคลอื่นหรือแก้ไขทะเบียนผู้ให้บริการเดิม" }); }
    }
    [HttpDelete("providers/{id:long}")]
    public async Task<IActionResult> DeactivateProvider(long id, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61003", "DELETE", ct) is { } no) return no;
        var n = await BookingDb.Exec(d, null, "UPDATE dbo.TDBKProvider SET IsActive=0 WHERE CompanyID=@c AND ProviderID=@id AND IsActive=1", ct, ("@c", Company), ("@id", id));
        return n == 0 ? NotFound(new { message = "ไม่พบผู้ให้บริการ", description = "รายการอาจปิดใช้งานแล้ว" }) : NoContent();
    }
    [HttpGet("resources")]
    public async Task<IActionResult> Resources(CancellationToken ct, int? page = null, int pageSize = 20)
    {
        if (BookingDb.InvalidPage(page, pageSize)) return BadRequest(new { message = "เลขหน้าไม่ถูกต้อง", description = "เลือกหน้าตั้งแต่ 1 และจำนวนไม่เกิน 100 รายการต่อหน้า" });
        await using var d = await Open(ct);
        if (await Guard(d, "61004", "VIEW", ct) is { } no) return no;
        const string sql = "SELECT ResourceID id,BranchID branchId,ResourceName name,ResourceType type,IsActive active FROM dbo.TDBKResource WHERE CompanyID=@c ORDER BY ResourceName,ResourceID";
        return Ok(page is null ? await BookingDb.Rows(d, null, sql, ct, ("@c", Company)) : await BookingDb.CompanyPage(d, sql, "SELECT COUNT(*) FROM dbo.TDBKResource WHERE CompanyID=@c", Company, page.Value, pageSize, ct));
    }
    [HttpPost("resources")]
    public async Task<IActionResult> CreateResource(CreateResourceRequest x, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(x.ResourceName) || string.IsNullOrWhiteSpace(x.ResourceType)) return BadRequest(new { message = "ข้อมูลทรัพยากรไม่ครบ", description = "ระบุชื่อและประเภทห้องหรือทรัพยากร" });
        await using var d = await Open(ct);
        if (await Guard(d, "61004", "CREATE", ct) is { } no) return no;
        if (x.BranchId is { } branch && await BookingDb.Id(d, null, "SELECT COUNT(*) FROM dbo.TDADBranch WHERE CompanyID=@c AND BranchID=@b AND IsActive=1", ct, ("@c", Company), ("@b", branch)) == 0) return BadRequest(new { message = "ไม่พบสาขา", description = "เลือกสาขาที่เปิดใช้งานในบริษัทนี้" });
        var id = await BookingDb.Id(d, null, "INSERT dbo.TDBKResource(CompanyID,BranchID,ResourceName,ResourceType) VALUES(@c,@b,@name,@type);SELECT SCOPE_IDENTITY()", ct, ("@c", Company), ("@b", x.BranchId), ("@name", x.ResourceName.Trim()), ("@type", x.ResourceType.Trim()));
        return Created($"/api/company/booking/resources/{id}", new { id });
    }
    [HttpPut("resources/{id:long}")]
    public async Task<IActionResult> UpdateResource(long id, UpdateResourceRequest x, CancellationToken ct)
    {
        if (id <= 0 || string.IsNullOrWhiteSpace(x.ResourceName) || string.IsNullOrWhiteSpace(x.ResourceType)) return BadRequest(new { message = "ข้อมูลทรัพยากรไม่ครบ", description = "ระบุชื่อและประเภทห้องหรือทรัพยากร" });
        await using var d = await Open(ct);
        if (await Guard(d, "61004", "EDIT", ct) is { } no) return no;
        if (x.BranchId is { } branch && await BookingDb.Id(d, null, "SELECT COUNT(*) FROM dbo.TDADBranch WHERE CompanyID=@c AND BranchID=@b AND IsActive=1", ct, ("@c", Company), ("@b", branch)) == 0) return BadRequest(new { message = "ไม่พบสาขา", description = "เลือกสาขาที่เปิดใช้งานในบริษัทนี้" });
        var n = await BookingDb.Exec(d, null, "UPDATE dbo.TDBKResource SET BranchID=@branch,ResourceName=@name,ResourceType=@type,IsActive=@active WHERE CompanyID=@c AND ResourceID=@id", ct, ("@c", Company), ("@id", id), ("@branch", x.BranchId), ("@name", x.ResourceName.Trim()), ("@type", x.ResourceType.Trim()), ("@active", x.IsActive));
        return n == 0 ? NotFound(new { message = "ไม่พบทรัพยากร", description = "เลือกทรัพยากรในบริษัทนี้" }) : NoContent();
    }
    [HttpDelete("resources/{id:long}")]
    public async Task<IActionResult> DeactivateResource(long id, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61004", "DELETE", ct) is { } no) return no;
        var n = await BookingDb.Exec(d, null, "UPDATE dbo.TDBKResource SET IsActive=0 WHERE CompanyID=@c AND ResourceID=@id AND IsActive=1", ct, ("@c", Company), ("@id", id));
        return n == 0 ? NotFound(new { message = "ไม่พบทรัพยากร", description = "รายการอาจปิดใช้งานแล้ว" }) : NoContent();
    }
    [HttpGet("members")]
    public async Task<IActionResult> Members(string? q, CancellationToken ct, int page = 1, int pageSize = 20)
    {
        if (BookingDb.InvalidPage(page, pageSize)) return BadRequest(new { message = "เลขหน้าไม่ถูกต้อง", description = "เลือกหน้าตั้งแต่ 1 และจำนวนไม่เกิน 100 รายการต่อหน้า" });
        await using var d = await Open(ct);
        if (await Guard(d, "61005", "VIEW", ct) is { } no) return no;
        var pattern = string.IsNullOrWhiteSpace(q) ? null : $"%{q.Trim()}%";
        var total = await BookingDb.Id(d, null, "SELECT COUNT(*) FROM dbo.TDBKMember M JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID WHERE M.CompanyID=@c AND (@q IS NULL OR P.FullName LIKE @q OR M.MemberCode LIKE @q)", ct, ("@c", Company), ("@q", pattern));
        var rows = await BookingDb.Rows(d, null, "SELECT M.MemberID id,M.PersonID personId,M.MemberCode code,P.FullName name,M.TierCode tierCode,M.StartsOn startsOn,M.ExpiresOn expiresOn,M.IsActive active FROM dbo.TDBKMember M JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID WHERE M.CompanyID=@c AND (@q IS NULL OR P.FullName LIKE @q OR M.MemberCode LIKE @q) ORDER BY M.MemberID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY", ct, ("@c", Company), ("@q", pattern), ("@offset", (page - 1) * pageSize), ("@size", pageSize));
        return Ok(new { items = rows, total, page, pageSize });
    }
    [HttpPost("members")]
    public async Task<IActionResult> CreateMember(CreateMemberRequest x, CancellationToken ct)
    {
        if (x.PersonId <= 0 || string.IsNullOrWhiteSpace(x.MemberCode) || string.IsNullOrWhiteSpace(x.TierCode) || x.ExpiresOn < x.StartsOn) return BadRequest(new { message = "Invalid member", description = "Check person, membership tier and validity dates" });
        await using var d = await Open(ct);
        if (await Guard(d, "61005", "CREATE", ct) is { } no) return no;
        if (await BookingDb.Id(d, null, "SELECT COUNT(*) FROM dbo.TDADPerson WHERE CompanyID=@c AND PersonID=@p AND IsActive=1", ct, ("@c", Company), ("@p", x.PersonId)) == 0) return NotFound(new { message = "Person not found", description = "Choose a person registered in this company" });
        try
        {
            var id = await BookingDb.Id(d, null, "INSERT dbo.TDBKMember(CompanyID,PersonID,MemberCode,TierCode,StartsOn,ExpiresOn) VALUES(@c,@person,@code,@tier,@from,@to);SELECT SCOPE_IDENTITY();", ct, ("@c", Company), ("@person", x.PersonId), ("@code", x.MemberCode.Trim()), ("@tier", x.TierCode.Trim()), ("@from", x.StartsOn.ToDateTime(TimeOnly.MinValue)), ("@to", x.ExpiresOn?.ToDateTime(TimeOnly.MinValue)));
            return Created($"/api/company/booking/members/{id}", new { id });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627) { return Conflict(new { message = "ข้อมูลสมาชิกซ้ำ", description = "บุคคลนี้หรือรหัสสมาชิกนี้มีอยู่แล้วในบริษัท" }); }
    }
    [HttpPut("members/{id:long}")]
    public async Task<IActionResult> UpdateMember(long id, UpdateMemberRequest x, CancellationToken ct)
    {
        if (id <= 0 || string.IsNullOrWhiteSpace(x.TierCode) || x.ExpiresOn < x.StartsOn) return BadRequest(new { message = "ข้อมูลสมาชิกไม่ถูกต้อง", description = "ตรวจระดับสมาชิกและวันมีผล" });
        await using var d = await Open(ct);
        if (await Guard(d, "61005", "EDIT", ct) is { } no) return no;
        var n = await BookingDb.Exec(d, null, "UPDATE dbo.TDBKMember SET TierCode=@tier,StartsOn=@from,ExpiresOn=@to,IsActive=@active WHERE CompanyID=@c AND MemberID=@id", ct, ("@c", Company), ("@id", id), ("@tier", x.TierCode.Trim()), ("@from", x.StartsOn.ToDateTime(TimeOnly.MinValue)), ("@to", x.ExpiresOn?.ToDateTime(TimeOnly.MinValue)), ("@active", x.IsActive));
        return n == 0 ? NotFound(new { message = "ไม่พบสมาชิก", description = "เลือกรายการสมาชิกในบริษัทนี้" }) : NoContent();
    }
    [HttpDelete("members/{id:long}")]
    public async Task<IActionResult> DeactivateMember(long id, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61005", "DELETE", ct) is { } no) return no;
        var n = await BookingDb.Exec(d, null, "UPDATE dbo.TDBKMember SET IsActive=0 WHERE CompanyID=@c AND MemberID=@id AND IsActive=1", ct, ("@c", Company), ("@id", id));
        return n == 0 ? NotFound(new { message = "ไม่พบสมาชิก", description = "รายการอาจปิดใช้งานแล้ว" }) : NoContent();
    }
    [HttpGet("bookings")]
    public async Task<IActionResult> Bookings(DateTimeOffset from, DateTimeOffset to, CancellationToken ct, string menu = "61007", int? page = null, int pageSize = 20)
    {
        if (to <= from || to - from > TimeSpan.FromDays(62)) return BadRequest(new { message = "ช่วงวันที่ไม่ถูกต้อง", description = "เลือกช่วงเวลาไม่เกิน 62 วัน" });
        if (menu is not ("61007" or "61008")) return BadRequest(new { message = "เมนูไม่ถูกต้อง", description = "ใช้เมนูรายการจองหรือใช้บริการ" });
        if (BookingDb.InvalidPage(page, pageSize)) return BadRequest(new { message = "เลขหน้าไม่ถูกต้อง", description = "เลือกหน้าตั้งแต่ 1 และจำนวนไม่เกิน 100 รายการต่อหน้า" });
        await using var d = await Open(ct);
        if (await Guard(d, menu, "VIEW", ct) is { } no) return no;
        const string select = "SELECT B.BookingID id,B.BookingNo number,B.MemberID memberId,COALESCE(P.FullName,B.GuestName) name,B.GuestName guestName,B.BranchID branchId,B.StartsAt startsAt,B.EndsAt endsAt,B.StatusCode status,B.TotalAmount amount,B.Note note FROM dbo.TDBKBooking B LEFT JOIN dbo.TDBKMember M ON M.CompanyID=B.CompanyID AND M.MemberID=B.MemberID LEFT JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID WHERE B.CompanyID=@c AND B.StartsAt<@to AND B.EndsAt>@from ORDER BY B.StartsAt,B.BookingID";
        if (page is null) return Ok(await BookingDb.Rows(d, null, select, ct, ("@c", Company), ("@from", from.UtcDateTime), ("@to", to.UtcDateTime)));
        var total = await BookingDb.Id(d, null, "SELECT COUNT(*) FROM dbo.TDBKBooking B WHERE B.CompanyID=@c AND B.StartsAt<@to AND B.EndsAt>@from", ct, ("@c", Company), ("@from", from.UtcDateTime), ("@to", to.UtcDateTime));
        var items = await BookingDb.Rows(d, null, select + " OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY", ct, ("@c", Company), ("@from", from.UtcDateTime), ("@to", to.UtcDateTime), ("@offset", (page.Value - 1) * pageSize), ("@size", pageSize));
        return Ok(new { items, total, page, pageSize });
    }
    [HttpGet("bookings/{id:long}")]
    public async Task<IActionResult> BookingDetail(long id, CancellationToken ct, string menu = "61007")
    {
        if (menu is not ("61007" or "61008")) return BadRequest(new { message = "เมนูไม่ถูกต้อง", description = "ใช้เมนูรายการจองหรือใช้บริการ" });
        await using var d = await Open(ct);
        if (await Guard(d, menu, "VIEW", ct) is { } no) return no;
        var header = await BookingDb.Rows(d, null, "SELECT B.BookingID id,B.BookingNo number,B.MemberID memberId,COALESCE(P.FullName,B.GuestName) name,B.GuestPhone guestPhone,B.BranchID branchId,B.StartsAt startsAt,B.EndsAt endsAt,B.StatusCode status,B.TotalAmount amount,B.Note note FROM dbo.TDBKBooking B LEFT JOIN dbo.TDBKMember M ON M.CompanyID=B.CompanyID AND M.MemberID=B.MemberID LEFT JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID WHERE B.CompanyID=@c AND B.BookingID=@id", ct, ("@c", Company), ("@id", id));
        if (header.Count == 0) return NotFound(new { message = "ไม่พบการจอง", description = "เลือกใบจองในบริษัทนี้" });
        var lines = await BookingDb.Rows(d, null, "SELECT L.LineID id,L.ServiceID serviceId,S.ServiceName service,L.ProviderID providerId,P.FullName provider,L.ResourceID resourceId,R.ResourceName resource,L.PriceSnapshot price,L.DiscountSnapshot discount,L.NetAmount netAmount,U.UsedAt usedAt FROM dbo.TDBKBookingService L JOIN dbo.TDBKService S ON S.CompanyID=L.CompanyID AND S.ServiceID=L.ServiceID LEFT JOIN dbo.TDBKProvider V ON V.CompanyID=L.CompanyID AND V.ProviderID=L.ProviderID LEFT JOIN dbo.TDADPerson P ON P.CompanyID=V.CompanyID AND P.PersonID=V.PersonID LEFT JOIN dbo.TDBKResource R ON R.CompanyID=L.CompanyID AND R.ResourceID=L.ResourceID LEFT JOIN dbo.TDBKUsage U ON U.CompanyID=L.CompanyID AND U.BookingID=L.BookingID AND U.LineID=L.LineID WHERE L.CompanyID=@c AND L.BookingID=@id ORDER BY L.LineID", ct, ("@c", Company), ("@id", id));
        var audit = await BookingDb.Rows(d, null, "SELECT ActionCode action,Reason reason,OccurredAt at FROM dbo.TDBKBookingAudit WHERE CompanyID=@c AND BookingID=@id ORDER BY AuditID", ct, ("@c", Company), ("@id", id));
        var sales = await BookingDb.Rows(d, null, "SELECT L.SaleID saleId,S.ReceiptNo receipt,S.StatusCode status,S.NetAmount amount,L.LinkedAt linkedAt FROM dbo.TDBKSaleLink L JOIN dbo.TDPOSale S ON S.CompanyID=L.CompanyID AND S.SaleID=L.SaleID WHERE L.CompanyID=@c AND L.BookingID=@id ORDER BY L.LinkedAt", ct, ("@c", Company), ("@id", id));
        return Ok(new { header = header[0], lines, sales, audit });
    }
    [HttpPost("bookings")]
    public async Task<IActionResult> CreateBooking(CreateBookingRequest input, CancellationToken ct)
    {
        if (input.Services is null || input.Services.Count == 0 || input.Services.Count > 20) return BadRequest(new { message = "Select services", description = "Choose one or more services" });
        if (input.EndsAt <= input.StartsAt || input.EndsAt - input.StartsAt > TimeSpan.FromDays(31) || input.MemberId is null && string.IsNullOrWhiteSpace(input.GuestName)) return BadRequest(new { message = "Invalid booking", description = "Provide a member or guest name and a valid service period" });
        if (input.StartsAt.UtcDateTime < DateTime.UtcNow) return BadRequest(new { message = "วันเวลาเริ่มไม่ถูกต้อง", description = "เลือกเวลาเริ่มในอนาคตสำหรับการจองใหม่" });
        if (input.GuestName?.Length > 150 || input.GuestPhone?.Length > 50 || input.Note?.Length > 2000) return BadRequest(new { message = "ข้อมูลการจองยาวเกินกำหนด", description = "ตรวจชื่อ เบอร์โทร และหมายเหตุ แล้วลองใหม่" });
        if (input.Services.Select(x => x.ServiceId).Distinct().Count() != input.Services.Count) return BadRequest(new { message = "Duplicate service", description = "Each service can only be added once" });
        await using var db = await Open(ct);
        if (await Guard(db, "61007", "CREATE", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            if (input.BranchId is { } bid && await BookingDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDADBranch B WHERE B.CompanyID=@c AND B.BranchID=@b AND B.IsActive=1 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@u AND U.IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@u AND X.BranchID=@b AND X.IsActive=1))", ct, ("@c", Company), ("@b", bid), ("@u", Actor)) == 0) return StatusCode(403, new { message = "ไม่มีสิทธิ์ใช้สาขานี้", description = "เลือกสาขาที่เปิดใช้งานและอยู่ในขอบเขตสิทธิ์ของผู้ใช้" });
            var localDate = TimeZoneInfo.ConvertTime(input.StartsAt, TimeZoneInfo.FindSystemTimeZoneById("Asia/Bangkok")).Date;
            var maxDays = await BookingDb.Id(db, tx, "SELECT COALESCE((SELECT AdvanceDays FROM dbo.TDBKSetting WHERE CompanyID=@c),90)", ct, ("@c", Company));
            if (input.StartsAt.UtcDateTime > DateTime.UtcNow.AddDays(maxDays)) return BadRequest(new { message = "จองล่วงหน้าเกินกำหนด", description = "เลือกวันจองภายในช่วงที่ตั้งค่าไว้" });
            string? tier = null;
            if (input.MemberId is { } mid)
            {
                var member = await BookingDb.Rows(db, tx, "SELECT TierCode FROM dbo.TDBKMember WHERE CompanyID=@c AND MemberID=@m AND IsActive=1 AND StartsOn<=@day AND (ExpiresOn IS NULL OR ExpiresOn>=@day)", ct, ("@c", Company), ("@m", mid), ("@day", localDate));
                if (member.Count == 0) return BadRequest(new { message = "สมาชิกใช้ไม่ได้", description = "เลือกสมาชิกที่ยังมีผลในวันจอง" });
                tier = Convert.ToString(member[0]["TierCode"]);
            }
            var prices = new List<BookingPrice>();
            foreach (var item in input.Services)
            {
                var rows = await BookingDb.Rows(db, tx, "SELECT Price,RequiresProvider,RequiresResource FROM dbo.TDBKService WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND ServiceID=@s AND IsActive=1", ct, ("@c", Company), ("@s", item.ServiceId));
                if (rows.Count == 0) return BadRequest(new { message = "Service not found", description = "Refresh the service list and select active services" });
                if (Convert.ToBoolean(rows[0]["RequiresProvider"]) && item.ProviderId is null) return BadRequest(new { message = "Provider required", description = "Choose a provider for this service" });
                if (Convert.ToBoolean(rows[0]["RequiresResource"]) && item.ResourceId is null) return BadRequest(new { message = "Resource required", description = "Choose a room or resource for this service" });
                if (item.ProviderId is { } provider && await BookingDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDBKProvider P JOIN dbo.TDADPerson X ON X.CompanyID=P.CompanyID AND X.PersonID=P.PersonID WHERE P.CompanyID=@c AND P.ProviderID=@p AND P.IsActive=1 AND X.IsActive=1", ct, ("@c", Company), ("@p", provider)) == 0) return BadRequest(new { message = "ไม่พบผู้ให้บริการ", description = "เลือกผู้ให้บริการที่ยังใช้งานและอยู่ในบริษัทนี้" });
                if (item.ResourceId is { } resource && await BookingDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDBKResource WHERE CompanyID=@c AND ResourceID=@r AND IsActive=1 AND (BranchID IS NULL OR BranchID=@b)", ct, ("@c", Company), ("@r", resource), ("@b", input.BranchId)) == 0) return BadRequest(new { message = "ไม่พบห้องหรือทรัพยากร", description = "เลือกทรัพยากรที่ยังใช้งานและตรงกับสาขาของการจอง" });
                if (item.ProviderId is { } assignedProvider)
                {
                    var count = await BookingDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDBKProviderService WHERE CompanyID=@c AND ProviderID=@p", ct, ("@c", Company), ("@p", assignedProvider));
                    if (count > 0 && await BookingDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDBKProviderService WHERE CompanyID=@c AND ProviderID=@p AND ServiceID=@s", ct, ("@c", Company), ("@p", assignedProvider), ("@s", item.ServiceId)) == 0) return BadRequest(new { message = "ผู้ให้บริการไม่รับงานนี้", description = "เลือกช่างที่กำหนดให้ทำบริการนี้" });
                    var scheduleCount = await BookingDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDBKProviderSchedule WHERE CompanyID=@c AND ProviderID=@p", ct, ("@c", Company), ("@p", assignedProvider));
                    if (scheduleCount > 0)
                    {
                        var start = TimeZoneInfo.ConvertTime(input.StartsAt, TimeZoneInfo.FindSystemTimeZoneById("Asia/Bangkok"));
                        var end = TimeZoneInfo.ConvertTime(input.EndsAt, TimeZoneInfo.FindSystemTimeZoneById("Asia/Bangkok"));
                        var day = ((int)start.DayOfWeek + 6) % 7 + 1;
                        if (start.Date != end.Date || await BookingDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDBKProviderSchedule WHERE CompanyID=@c AND ProviderID=@p AND WeekdayNumber=@day AND StartsAt<=@start AND EndsAt>=@end", ct, ("@c", Company), ("@p", assignedProvider), ("@day", day), ("@start", start.TimeOfDay), ("@end", end.TimeOfDay)) == 0) return BadRequest(new { message = "เวลาช่างไม่ว่าง", description = "เลือกเวลาที่อยู่ในตารางงานของผู้ให้บริการ" });
                    }
                }
                if (item.ResourceId is { } assignedResource)
                {
                    var count = await BookingDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDBKResourceService WHERE CompanyID=@c AND ResourceID=@r", ct, ("@c", Company), ("@r", assignedResource));
                    if (count > 0 && await BookingDb.Id(db, tx, "SELECT COUNT(*) FROM dbo.TDBKResourceService WHERE CompanyID=@c AND ResourceID=@r AND ServiceID=@s", ct, ("@c", Company), ("@r", assignedResource), ("@s", item.ServiceId)) == 0) return BadRequest(new { message = "ห้องไม่รองรับบริการ", description = "เลือกห้องหรือทรัพยากรที่กำหนดให้ใช้กับบริการนี้" });
                }
                prices.Add(await PriceFor(db, tx, item, Convert.ToDecimal(rows[0]["Price"]), tier, input.StartsAt.UtcDateTime, ct));
            }
            return await SaveBooking(db, tx, input, prices, ct);
        }
        catch (SqlException) { await tx.RollbackAsync(ct); return Conflict(new { message = "Booking conflict", description = "The schedule changed or the database is not initialized; refresh and try again" }); }
        catch { await tx.RollbackAsync(ct); throw; }
    }
    async Task<BookingPrice> PriceFor(SqlConnection db, SqlTransaction tx, BookingServiceRequest item, decimal price, string? tier, DateTime when, CancellationToken ct)
    {
        var promotions = await BookingDb.Rows(db, tx, "SELECT PromotionID,DiscountType,DiscountValue FROM dbo.TDBKPromotion WHERE CompanyID=@c AND IsActive=1 AND (ServiceID IS NULL OR ServiceID=@s) AND (TierCode IS NULL OR TierCode=@tier) AND StartsAt<=@when AND EndsAt>@when", ct, ("@c", Company), ("@s", item.ServiceId), ("@tier", tier), ("@when", when));
        var best = promotions.Select(p =>
        {
            var value = Convert.ToDecimal(p["DiscountValue"]);
            var discount = Convert.ToString(p["DiscountType"]) == "PERCENT" ? Math.Round(price * value / 100, 2, MidpointRounding.AwayFromZero) : Math.Min(price, value);
            return (id: Convert.ToInt64(p["PromotionID"]), discount: Math.Min(price, discount));
        }).OrderByDescending(p => p.discount).ThenBy(p => p.id).FirstOrDefault();
        return new BookingPrice(item, price, best.discount, best.id == 0 ? null : best.id);
    }
    async Task<IActionResult> SaveBooking(SqlConnection db, SqlTransaction tx, CreateBookingRequest input, List<BookingPrice> prices, CancellationToken ct)
    {
        foreach (var quote in prices)
        {
            var item = quote.Item;
            var conflict = await BookingDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDBKBookingService L JOIN dbo.TDBKBooking B
ON B.CompanyID=L.CompanyID AND B.BookingID=L.BookingID
 WHERE B.CompanyID=@c AND B.StatusCode IN(N'BOOKED',N'CONFIRMED',N'IN_SERVICE')
AND ((@provider IS NOT NULL AND L.ProviderID=@provider) OR (@resource IS NOT NULL AND L.ResourceID=@resource))
AND B.StartsAt<@to AND B.EndsAt>@from
""", ct, ("@c", Company), ("@from", input.StartsAt.UtcDateTime), ("@to", input.EndsAt.UtcDateTime), ("@provider", item.ProviderId), ("@resource", item.ResourceId));
            if (conflict > 0) return Conflict(new { message = "Time slot unavailable", description = "Choose a different date or time" });
        }
        var total = prices.Sum(x => x.Net);
        var seq = await BookingDb.Id(db, tx, "SELECT NEXT VALUE FOR dbo.TDBKBookingNoSeq", ct);
        var number = $"BK{DateTime.UtcNow:yyyyMMdd}-{seq:000000}";
        var id = await BookingDb.Id(db, tx, """
 INSERT dbo.TDBKBooking(CompanyID,BookingNo,MemberID,GuestName,GuestPhone,BranchID,StartsAt,EndsAt,StatusCode,TotalAmount,CreatedBy,Note)
 VALUES(@c,@n,@m,@gn,@gp,@b,@from,@to,N'BOOKED',@total,@actor,@note);SELECT SCOPE_IDENTITY();
""", ct, ("@c", Company), ("@n", number), ("@m", input.MemberId), ("@gn", input.GuestName?.Trim()), ("@gp", input.GuestPhone?.Trim()), ("@b", input.BranchId), ("@from", input.StartsAt.UtcDateTime), ("@to", input.EndsAt.UtcDateTime), ("@total", total), ("@actor", Actor), ("@note", input.Note?.Trim()));
        foreach (var quote in prices)
            await BookingDb.Exec(db, tx, "INSERT dbo.TDBKBookingService(CompanyID,BookingID,ServiceID,ProviderID,ResourceID,PriceSnapshot,DiscountSnapshot,NetAmount,PromotionIDSnapshot) VALUES(@c,@b,@s,@p,@r,@price,@discount,@net,@promotion)", ct, ("@c", Company), ("@b", id), ("@s", quote.Item.ServiceId), ("@p", quote.Item.ProviderId), ("@r", quote.Item.ResourceId), ("@price", quote.Price), ("@discount", quote.Discount), ("@net", quote.Net), ("@promotion", quote.PromotionId));
        await BookingDb.Exec(db, tx, "INSERT dbo.TDBKBookingAudit(CompanyID,BookingID,ActionCode,ActorUserID) VALUES(@c,@b,N'CREATE',@u)", ct, ("@c", Company), ("@b", id), ("@u", Actor));
        await tx.CommitAsync(ct);
        return Created($"/api/company/booking/bookings/{id}", new { id, number, totalAmount = total });
    }
    [HttpGet("members/{id:long}/history")]
    public async Task<IActionResult> MemberHistory(long id, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61009", "VIEW", ct) is { } no) return no;
        return Ok(await BookingDb.Rows(d, null, "SELECT B.BookingNo number,B.StartsAt startsAt,B.StatusCode status,B.TotalAmount amount,S.ServiceName service FROM dbo.TDBKBooking B JOIN dbo.TDBKBookingService L ON L.CompanyID=B.CompanyID AND L.BookingID=B.BookingID JOIN dbo.TDBKService S ON S.CompanyID=L.CompanyID AND S.ServiceID=L.ServiceID WHERE B.CompanyID=@c AND B.MemberID=@m ORDER BY B.StartsAt DESC", ct, ("@c", Company), ("@m", id)));
    }
    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard(DateTime from, DateTime to, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61010", "VIEW", ct) is { } no) return no;
        return Ok(await BookingDb.Rows(d, null, "SELECT COUNT(*) bookings,SUM(CASE WHEN StatusCode=N'COMPLETED' THEN 1 ELSE 0 END) completed,SUM(TotalAmount) bookedAmount FROM dbo.TDBKBooking WHERE CompanyID=@c AND StartsAt>=@f AND StartsAt<@t", ct, ("@c", Company), ("@f", from), ("@t", to)));
    }
    [HttpPatch("bookings/{id:long}/cancel"), HttpPost("bookings/{id:long}/cancel")]
    public async Task<IActionResult> Cancel(long id, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61007", "CANCEL", ct) is { } no) return no;
        await using var tx = (SqlTransaction)await d.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var hours = await BookingDb.Id(d, tx, "SELECT COALESCE((SELECT CancelBeforeHours FROM dbo.TDBKSetting WHERE CompanyID=@c),2)", ct, ("@c", Company));
        var n = await BookingDb.Exec(d, tx, "UPDATE dbo.TDBKBooking SET StatusCode=N'CANCELLED' WHERE CompanyID=@c AND BookingID=@id AND StatusCode IN(N'BOOKED',N'CONFIRMED') AND StartsAt>=DATEADD(hour,@hours,SYSUTCDATETIME()) AND NOT EXISTS(SELECT 1 FROM dbo.TDBKUsage WHERE CompanyID=@c AND BookingID=@id)", ct, ("@c", Company), ("@id", id), ("@hours", hours));
        if (n == 0) return Conflict(new { message = "ยกเลิกการจองไม่ได้", description = "รายการอาจเริ่มแล้ว หรือเลยเวลายกเลิกที่บริษัทกำหนด" });
        await BookingDb.Exec(d, tx, "INSERT dbo.TDBKBookingAudit(CompanyID,BookingID,ActionCode,ActorUserID) VALUES(@c,@b,N'CANCEL',@u)", ct, ("@c", Company), ("@b", id), ("@u", Actor));
        await tx.CommitAsync(ct);
        return NoContent();
    }
}
