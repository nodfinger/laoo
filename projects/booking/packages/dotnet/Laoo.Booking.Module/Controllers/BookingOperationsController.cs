using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

namespace Laoo.Booking.Controllers;

public sealed record BookingSettingRequest(int AdvanceDays, int CancelBeforeHours, int NoShowGraceMinutes);
public sealed record BookingPromotionRequest(string PromotionCode, string PromotionName, long? ServiceId, string? TierCode, DateTimeOffset StartsAt, DateTimeOffset EndsAt, string DiscountType, decimal DiscountValue);
public sealed record ProviderScheduleSlot(int WeekdayNumber, TimeOnly StartsAt, TimeOnly EndsAt);
public sealed record ProviderScheduleRequest(IReadOnlyList<ProviderScheduleSlot> Slots, IReadOnlyList<long> ServiceIds);
public sealed record ResourceServicesRequest(IReadOnlyList<long> ServiceIds);

[ApiController, Authorize, Route("api/company/booking")]
public sealed class BookingOperationsController(IConfiguration config) : ControllerBase
{
    long Company => long.Parse(User.FindFirst("company_id")!.Value);
    long Actor => long.Parse(User.FindFirst("user_id")!.Value);
    async Task<SqlConnection> Open(CancellationToken ct) { var d = new SqlConnection(config.GetConnectionString("LaooDatabase")); await d.OpenAsync(ct); return d; }
    async Task<IActionResult?> Guard(SqlConnection db, string menu, string action, CancellationToken ct)
    {
        if (!BookingAccess.Scope(User, out _, out _)) return StatusCode(403, new { message = "ไม่สามารถเข้าถึงบริษัท", description = "กรุณาเข้าสู่ระบบด้วยบัญชีบริษัท" });
        return await BookingAccess.Can(db, User, menu, action, ct) ? null : StatusCode(403, new { message = "ไม่มีสิทธิ์ดำเนินการ", description = "ตรวจสอบแพ็กเกจและสิทธิ์เมนูของผู้ใช้" });
    }
    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61001", "VIEW", ct) is { } no) return no;
        var rows = await BookingDb.Rows(d, null, "SELECT AdvanceDays advanceDays,CancelBeforeHours cancelBeforeHours,NoShowGraceMinutes noShowGraceMinutes FROM dbo.TDBKSetting WHERE CompanyID=@c", ct, ("@c", Company));
        return Ok(rows.Count == 0 ? new { advanceDays = 90, cancelBeforeHours = 2, noShowGraceMinutes = 15 } : rows[0]);
    }
    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(BookingSettingRequest x, CancellationToken ct)
    {
        if (x.AdvanceDays is < 1 or > 365 || x.CancelBeforeHours is < 0 or > 168 || x.NoShowGraceMinutes is < 0 or > 1440)
            return BadRequest(new { message = "ค่าตั้งค่าไม่ถูกต้อง", description = "ตรวจสอบจำนวนวันจองล่วงหน้า ชั่วโมงยกเลิก และเวลารอสถานะไม่มา" });
        await using var d = await Open(ct);
        if (await Guard(d, "61001", "EDIT", ct) is { } no) return no;
        await using var tx = (SqlTransaction)await d.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await BookingDb.Exec(d, tx, "UPDATE dbo.TDBKSetting WITH(UPDLOCK,HOLDLOCK) SET AdvanceDays=@days,CancelBeforeHours=@hours,NoShowGraceMinutes=@grace,UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@u WHERE CompanyID=@c; IF @@ROWCOUNT=0 INSERT dbo.TDBKSetting(CompanyID,AdvanceDays,CancelBeforeHours,NoShowGraceMinutes,UpdatedBy) VALUES(@c,@days,@hours,@grace,@u)", ct, ("@c", Company), ("@u", Actor), ("@days", x.AdvanceDays), ("@hours", x.CancelBeforeHours), ("@grace", x.NoShowGraceMinutes));
        await tx.CommitAsync(ct);
        return NoContent();
    }
    [HttpGet("promotions")]
    public async Task<IActionResult> Promotions(CancellationToken ct, int? page = null, int pageSize = 20)
    {
        if (BookingDb.InvalidPage(page, pageSize)) return BadRequest(new { message = "เลขหน้าไม่ถูกต้อง", description = "เลือกหน้าตั้งแต่ 1 และจำนวนไม่เกิน 100 รายการต่อหน้า" });
        await using var d = await Open(ct);
        if (await Guard(d, "61006", "VIEW", ct) is { } no) return no;
        const string sql = "SELECT PromotionID id,PromotionCode code,PromotionName name,ServiceID serviceId,TierCode tierCode,StartsAt startsAt,EndsAt endsAt,DiscountType discountType,DiscountValue discountValue,IsActive active FROM dbo.TDBKPromotion WHERE CompanyID=@c ORDER BY StartsAt DESC,PromotionID DESC";
        return Ok(page is null ? await BookingDb.Rows(d, null, sql, ct, ("@c", Company)) : await BookingDb.CompanyPage(d, sql, "SELECT COUNT(*) FROM dbo.TDBKPromotion WHERE CompanyID=@c", Company, page.Value, pageSize, ct));
    }
    static bool Valid(BookingPromotionRequest x) => !string.IsNullOrWhiteSpace(x.PromotionCode) && x.PromotionCode.Length <= 30 && !string.IsNullOrWhiteSpace(x.PromotionName) && x.PromotionName.Length <= 150 && x.EndsAt > x.StartsAt && x.DiscountValue > 0 && (x.DiscountType == "AMOUNT" || x.DiscountType == "PERCENT" && x.DiscountValue <= 100);
    [HttpPost("promotions")]
    public async Task<IActionResult> CreatePromotion(BookingPromotionRequest x, CancellationToken ct)
    {
        if (!Valid(x)) return BadRequest(new { message = "ข้อมูลโปรโมชั่นไม่ถูกต้อง", description = "ตรวจรหัส ชื่อ ช่วงวันที่ ประเภท และจำนวนส่วนลด" });
        await using var d = await Open(ct);
        if (await Guard(d, "61006", "CREATE", ct) is { } no) return no;
        if (x.ServiceId is { } service && await BookingDb.Id(d, null, "SELECT COUNT(*) FROM dbo.TDBKService WHERE CompanyID=@c AND ServiceID=@s AND IsActive=1", ct, ("@c", Company), ("@s", service)) == 0) return BadRequest(new { message = "ไม่พบบริการ", description = "เลือกบริการที่อยู่ในบริษัทนี้และยังใช้งาน" });
        try
        {
            var id = await BookingDb.Id(d, null, "INSERT dbo.TDBKPromotion(CompanyID,PromotionCode,PromotionName,ServiceID,TierCode,StartsAt,EndsAt,DiscountType,DiscountValue) VALUES(@c,@code,@name,@service,@tier,@from,@to,@type,@value);SELECT SCOPE_IDENTITY()", ct, ("@c", Company), ("@code", x.PromotionCode.Trim()), ("@name", x.PromotionName.Trim()), ("@service", x.ServiceId), ("@tier", string.IsNullOrWhiteSpace(x.TierCode) ? null : x.TierCode.Trim()), ("@from", x.StartsAt.UtcDateTime), ("@to", x.EndsAt.UtcDateTime), ("@type", x.DiscountType), ("@value", x.DiscountValue));
            return Created($"/api/company/booking/promotions/{id}", new { id });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627) { return Conflict(new { message = "รหัสโปรโมชั่นซ้ำ", description = "ใช้รหัสอื่นหรือแก้ไขโปรโมชั่นเดิม" }); }
    }
    [HttpPut("promotions/{id:long}")]
    public async Task<IActionResult> UpdatePromotion(long id, BookingPromotionRequest x, CancellationToken ct)
    {
        if (id <= 0 || !Valid(x)) return BadRequest(new { message = "ข้อมูลโปรโมชั่นไม่ถูกต้อง", description = "ตรวจรหัส ชื่อ ช่วงวันที่ ประเภท และจำนวนส่วนลด" });
        await using var d = await Open(ct);
        if (await Guard(d, "61006", "EDIT", ct) is { } no) return no;
        if (x.ServiceId is { } service && await BookingDb.Id(d, null, "SELECT COUNT(*) FROM dbo.TDBKService WHERE CompanyID=@c AND ServiceID=@s AND IsActive=1", ct, ("@c", Company), ("@s", service)) == 0) return BadRequest(new { message = "ไม่พบบริการ", description = "เลือกบริการที่อยู่ในบริษัทนี้และยังใช้งาน" });
        try
        {
            var n = await BookingDb.Exec(d, null, "UPDATE dbo.TDBKPromotion SET PromotionCode=@code,PromotionName=@name,ServiceID=@service,TierCode=@tier,StartsAt=@from,EndsAt=@to,DiscountType=@type,DiscountValue=@value WHERE CompanyID=@c AND PromotionID=@id AND IsActive=1", ct, ("@c", Company), ("@id", id), ("@code", x.PromotionCode.Trim()), ("@name", x.PromotionName.Trim()), ("@service", x.ServiceId), ("@tier", string.IsNullOrWhiteSpace(x.TierCode) ? null : x.TierCode.Trim()), ("@from", x.StartsAt.UtcDateTime), ("@to", x.EndsAt.UtcDateTime), ("@type", x.DiscountType), ("@value", x.DiscountValue));
            return n == 0 ? NotFound(new { message = "ไม่พบโปรโมชั่น", description = "โปรโมชั่นอาจถูกปิดหรือไม่ได้อยู่ในบริษัทนี้" }) : NoContent();
        }
        catch (SqlException e) when (e.Number is 2601 or 2627) { return Conflict(new { message = "รหัสโปรโมชั่นซ้ำ", description = "ใช้รหัสอื่นหรือแก้ไขโปรโมชั่นเดิม" }); }
    }
    [HttpDelete("promotions/{id:long}")]
    public async Task<IActionResult> DeactivatePromotion(long id, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61006", "DELETE", ct) is { } no) return no;
        var n = await BookingDb.Exec(d, null, "UPDATE dbo.TDBKPromotion SET IsActive=0 WHERE CompanyID=@c AND PromotionID=@id AND IsActive=1", ct, ("@c", Company), ("@id", id));
        return n == 0 ? NotFound(new { message = "ไม่พบโปรโมชั่น", description = "โปรโมชั่นอาจถูกปิดหรือไม่ได้อยู่ในบริษัทนี้" }) : NoContent();
    }
    [HttpGet("providers/{id:long}/schedule")]
    public async Task<IActionResult> ProviderSchedule(long id, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61003", "VIEW", ct) is { } no) return no;
        if (await BookingDb.Id(d, null, "SELECT COUNT(*) FROM dbo.TDBKProvider WHERE CompanyID=@c AND ProviderID=@id AND IsActive=1", ct, ("@c", Company), ("@id", id)) == 0) return NotFound(new { message = "ไม่พบผู้ให้บริการ", description = "เลือกผู้ให้บริการที่ยังใช้งานในบริษัทนี้" });
        var slots = await BookingDb.Rows(d, null, "SELECT WeekdayNumber weekdayNumber,StartsAt startsAt,EndsAt endsAt FROM dbo.TDBKProviderSchedule WHERE CompanyID=@c AND ProviderID=@id ORDER BY WeekdayNumber,StartsAt", ct, ("@c", Company), ("@id", id));
        var services = await BookingDb.Rows(d, null, "SELECT ServiceID serviceId FROM dbo.TDBKProviderService WHERE CompanyID=@c AND ProviderID=@id ORDER BY ServiceID", ct, ("@c", Company), ("@id", id));
        return Ok(new { slots, serviceIds = services.Select(x => x["serviceId"]) });
    }
    [HttpPut("providers/{id:long}/schedule")]
    public async Task<IActionResult> SaveProviderSchedule(long id, ProviderScheduleRequest x, CancellationToken ct)
    {
        if (x.Slots is null || x.ServiceIds is null || x.Slots.Count > 70 || x.ServiceIds.Count > 100 || x.ServiceIds.Distinct().Count() != x.ServiceIds.Count || x.Slots.Any(s => s.WeekdayNumber is < 1 or > 7 || s.EndsAt <= s.StartsAt)) return BadRequest(new { message = "ตารางเวลาไม่ถูกต้อง", description = "ระบุวันจันทร์ถึงอาทิตย์ ช่วงเวลาที่สิ้นสุดหลังเริ่ม และบริการไม่ซ้ำ" });
        foreach (var day in x.Slots.GroupBy(s => s.WeekdayNumber)) { var ordered = day.OrderBy(s => s.StartsAt).ToArray(); for (var i = 1; i < ordered.Length; i++) if (ordered[i].StartsAt < ordered[i - 1].EndsAt) return BadRequest(new { message = "เวลาช่างซ้อนกัน", description = "แก้ช่วงเวลาของวันเดียวกันให้ไม่ทับกัน" }); }
        await using var d = await Open(ct);
        if (await Guard(d, "61003", "EDIT", ct) is { } no) return no;
        await using var tx = (SqlTransaction)await d.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        if (await BookingDb.Id(d, tx, "SELECT COUNT(*) FROM dbo.TDBKProvider WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND ProviderID=@id AND IsActive=1", ct, ("@c", Company), ("@id", id)) == 0) return NotFound(new { message = "ไม่พบผู้ให้บริการ", description = "เลือกผู้ให้บริการที่ยังใช้งานในบริษัทนี้" });
        foreach (var service in x.ServiceIds) if (await BookingDb.Id(d, tx, "SELECT COUNT(*) FROM dbo.TDBKService WHERE CompanyID=@c AND ServiceID=@s AND IsActive=1", ct, ("@c", Company), ("@s", service)) == 0) return BadRequest(new { message = "ไม่พบบริการ", description = "เลือกเฉพาะบริการที่ยังใช้งานในบริษัทนี้" });
        await BookingDb.Exec(d, tx, "DELETE dbo.TDBKProviderSchedule WHERE CompanyID=@c AND ProviderID=@id;DELETE dbo.TDBKProviderService WHERE CompanyID=@c AND ProviderID=@id", ct, ("@c", Company), ("@id", id));
        foreach (var slot in x.Slots) await BookingDb.Exec(d, tx, "INSERT dbo.TDBKProviderSchedule(CompanyID,ProviderID,WeekdayNumber,StartsAt,EndsAt) VALUES(@c,@id,@day,@from,@to)", ct, ("@c", Company), ("@id", id), ("@day", slot.WeekdayNumber), ("@from", slot.StartsAt.ToTimeSpan()), ("@to", slot.EndsAt.ToTimeSpan()));
        foreach (var service in x.ServiceIds) await BookingDb.Exec(d, tx, "INSERT dbo.TDBKProviderService(CompanyID,ProviderID,ServiceID) VALUES(@c,@id,@s)", ct, ("@c", Company), ("@id", id), ("@s", service));
        await tx.CommitAsync(ct);
        return NoContent();
    }
    [HttpGet("resources/{id:long}/services")]
    public async Task<IActionResult> ResourceServices(long id, CancellationToken ct)
    {
        await using var d = await Open(ct);
        if (await Guard(d, "61004", "VIEW", ct) is { } no) return no;
        if (await BookingDb.Id(d, null, "SELECT COUNT(*) FROM dbo.TDBKResource WHERE CompanyID=@c AND ResourceID=@id AND IsActive=1", ct, ("@c", Company), ("@id", id)) == 0) return NotFound(new { message = "ไม่พบทรัพยากร", description = "เลือกห้องหรือทรัพยากรที่ยังใช้งานในบริษัทนี้" });
        return Ok(await BookingDb.Rows(d, null, "SELECT ServiceID serviceId FROM dbo.TDBKResourceService WHERE CompanyID=@c AND ResourceID=@id ORDER BY ServiceID", ct, ("@c", Company), ("@id", id)));
    }
    [HttpPut("resources/{id:long}/services")]
    public async Task<IActionResult> SaveResourceServices(long id, ResourceServicesRequest x, CancellationToken ct)
    {
        if (x.ServiceIds is null || x.ServiceIds.Count > 100 || x.ServiceIds.Distinct().Count() != x.ServiceIds.Count) return BadRequest(new { message = "รายการบริการไม่ถูกต้อง", description = "เลือกบริการไม่เกิน 100 รายการและห้ามซ้ำ" });
        await using var d = await Open(ct);
        if (await Guard(d, "61004", "EDIT", ct) is { } no) return no;
        await using var tx = (SqlTransaction)await d.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        if (await BookingDb.Id(d, tx, "SELECT COUNT(*) FROM dbo.TDBKResource WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND ResourceID=@id AND IsActive=1", ct, ("@c", Company), ("@id", id)) == 0) return NotFound(new { message = "ไม่พบทรัพยากร", description = "เลือกห้องหรือทรัพยากรที่ยังใช้งานในบริษัทนี้" });
        foreach (var service in x.ServiceIds) if (await BookingDb.Id(d, tx, "SELECT COUNT(*) FROM dbo.TDBKService WHERE CompanyID=@c AND ServiceID=@s AND IsActive=1", ct, ("@c", Company), ("@s", service)) == 0) return BadRequest(new { message = "ไม่พบบริการ", description = "เลือกเฉพาะบริการที่ยังใช้งานในบริษัทนี้" });
        await BookingDb.Exec(d, tx, "DELETE dbo.TDBKResourceService WHERE CompanyID=@c AND ResourceID=@id", ct, ("@c", Company), ("@id", id));
        foreach (var service in x.ServiceIds) await BookingDb.Exec(d, tx, "INSERT dbo.TDBKResourceService(CompanyID,ResourceID,ServiceID) VALUES(@c,@id,@s)", ct, ("@c", Company), ("@id", id), ("@s", service));
        await tx.CommitAsync(ct);
        return NoContent();
    }
}
