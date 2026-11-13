using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Globalization;

namespace LaooPurchasingModule.Controllers;

[ApiController]
[Route("api/purchasing/requests")]
public sealed class PurchasingRequestController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private string ConnectionString => configuration.GetConnectionString("LaooDatabase") ?? throw new InvalidOperationException("LaooDatabase is not configured.");

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] long? divisionId, [FromQuery] long? departmentId, [FromQuery] long? requesterId, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken token = default)
    {
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        await using var db = new SqlConnection(ConnectionString); await db.OpenAsync(token);
        const string sql = """
            SELECT RequestID, RequestNo, RequestDate, StatusCode, ResponsibleUserID, Remark
            FROM dbo.TDAPPurchaseRequest
            WHERE CompanyID=@company AND (@search IS NULL OR RequestNo LIKE @likeSearch OR Remark LIKE @likeSearch)
              AND (@division IS NULL OR DivisionID=@division) AND (@department IS NULL OR DepartmentID=@department)
              AND (@requester IS NULL OR RequesterUserID=@requester)
            ORDER BY RequestDate DESC, RequestID DESC OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;
            SELECT COUNT_BIG(1) FROM dbo.TDAPPurchaseRequest WHERE CompanyID=@company;
            """;
        await using var q = new SqlCommand(sql, db); Add(q, "@company", SqlDbType.BigInt, CompanyId()); Add(q, "@search", SqlDbType.NVarChar, string.IsNullOrWhiteSpace(search) ? DBNull.Value : search); Add(q, "@likeSearch", SqlDbType.NVarChar, $"%{search}%"); Add(q, "@division", SqlDbType.BigInt, divisionId is null ? DBNull.Value : divisionId); Add(q, "@department", SqlDbType.BigInt, departmentId is null ? DBNull.Value : departmentId); Add(q, "@requester", SqlDbType.BigInt, requesterId is null ? DBNull.Value : requesterId); Add(q, "@skip", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@take", SqlDbType.Int, pageSize);
        var items = new List<object>(); long total = 0; await using var reader = await q.ExecuteReaderAsync(token); while (await reader.ReadAsync(token)) items.Add(new { requestId = reader.GetInt64(0), requestNo = reader.GetString(1), requestDate = reader.GetDateTime(2).ToString("yyyy-MM-dd"), statusCode = reader.GetString(3), responsibleUserId = reader.IsDBNull(4) ? (long?)null : reader.GetInt64(4), remark = reader.IsDBNull(5) ? null : reader.GetString(5) }); if (await reader.NextResultAsync(token) && await reader.ReadAsync(token)) total = reader.GetInt64(0);
        return Ok(new { items, total, page, pageSize, divisions = Array.Empty<object>(), departments = Array.Empty<object>(), requesters = Array.Empty<object>() });
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token = default)
    {
        await using var db = new SqlConnection(ConnectionString); await db.OpenAsync(token);
        await using var q = new SqlCommand("SELECT RequestID,RequestNo,RequestDate,StatusCode,RequesterUserID,DivisionID,DepartmentID,ResponsibleUserID,Remark FROM dbo.TDAPPurchaseRequest WHERE CompanyID=@company AND RequestID=@id", db); Add(q, "@company", SqlDbType.BigInt, CompanyId()); Add(q, "@id", SqlDbType.BigInt, id); await using var r = await q.ExecuteReaderAsync(token); if (!await r.ReadAsync(token)) return NotFound(); return Ok(new { requestId = r.GetInt64(0), requestNo = r.GetString(1), requestDate = r.GetDateTime(2).ToString("yyyy-MM-dd"), statusCode = r.GetString(3), requesterUserId = r.IsDBNull(4) ? (long?)null : r.GetInt64(4), divisionId = r.IsDBNull(5) ? (long?)null : r.GetInt64(5), departmentId = r.IsDBNull(6) ? (long?)null : r.GetInt64(6), responsibleUserId = r.IsDBNull(7) ? (long?)null : r.GetInt64(7), remark = r.IsDBNull(8) ? null : r.GetString(8), details = Array.Empty<object>() });
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] PurchaseRequestWriteRequest request, CancellationToken token = default)
    {
        if (request.Details.Count == 0) return BadRequest(new { message = "บันทึกไม่ได้", description = "ต้องมีรายการจัดซื้ออย่างน้อย 1 รายการ" });
        if (request.Details.Any(x => string.IsNullOrWhiteSpace(x.ItemText) || x.ItemText.Length > 2000)) return BadRequest(new { message = "รายการไม่ถูกต้อง", description = "รายการต้องมีข้อความและยาวไม่เกิน 2,000 ตัวอักษร" });
        if (request.Details.Any(x => x.UrgencyLevel is < 0 or > 2 || (x.EstimatedMin.HasValue && x.EstimatedMax.HasValue && x.EstimatedMin > x.EstimatedMax))) return BadRequest(new { message = "ข้อมูลรายการไม่ถูกต้อง", description = "ตรวจสอบระดับความต้องการและช่วงราคาประมาณ" });
        await using var db = new SqlConnection(ConnectionString); await db.OpenAsync(token); await using var tx = await db.BeginTransactionAsync(token);
        try
        {
            var user = UserId(); var company = CompanyId();
            await using var insert = new SqlCommand("INSERT dbo.TDAPPurchaseRequest(CompanyID,RequestNo,RequestDate,RequesterUserID,DivisionID,DepartmentID,StatusCode,Remark,CreateBy) OUTPUT INSERTED.RequestID VALUES(@company,@no,@date,@user,@division,@department,N'DRAFT',@remark,@user)", db, (SqlTransaction)tx);
            Add(insert, "@company", SqlDbType.BigInt, company); Add(insert, "@no", SqlDbType.NVarChar, string.IsNullOrWhiteSpace(request.RequestNo) ? $"PR-{DateTime.UtcNow:yyyyMMddHHmmssfff}" : request.RequestNo); Add(insert, "@date", SqlDbType.Date, DateTime.TryParse(request.RequestDate, CultureInfo.InvariantCulture, DateTimeStyles.None, out var date) ? date.Date : DateTime.UtcNow.Date); Add(insert, "@user", SqlDbType.BigInt, user); Add(insert, "@division", SqlDbType.BigInt, request.DivisionId ?? (object)DBNull.Value); Add(insert, "@department", SqlDbType.BigInt, request.DepartmentId ?? (object)DBNull.Value); Add(insert, "@remark", SqlDbType.NVarChar, request.Remark ?? (object)DBNull.Value); var requestId = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            var detailIds = new List<long>(); var sort = 1;
            foreach (var item in request.Details)
            {
                await using var detail = new SqlCommand("INSERT dbo.TDAPPurchaseRequestDetail(RequestID,ItemText,Quantity,EstimatedMin,EstimatedMax,Remark,NeededDate,UrgencyLevel,SortOrder) OUTPUT INSERTED.DetailID VALUES(@request,@item,@quantity,@min,@max,@remark,@needed,@urgency,@sort)", db, (SqlTransaction)tx); Add(detail, "@request", SqlDbType.BigInt, requestId); Add(detail, "@item", SqlDbType.NVarChar, item.ItemText); Add(detail, "@quantity", SqlDbType.Decimal, item.Quantity ?? (object)DBNull.Value); Add(detail, "@min", SqlDbType.Decimal, item.EstimatedMin ?? (object)DBNull.Value); Add(detail, "@max", SqlDbType.Decimal, item.EstimatedMax ?? (object)DBNull.Value); Add(detail, "@remark", SqlDbType.NVarChar, item.Remark ?? (object)DBNull.Value); Add(detail, "@needed", SqlDbType.Date, DateTime.TryParse(item.NeededDate, CultureInfo.InvariantCulture, DateTimeStyles.None, out var needed) ? needed.Date : DBNull.Value); Add(detail, "@urgency", SqlDbType.TinyInt, item.UrgencyLevel); Add(detail, "@sort", SqlDbType.Int, sort++); detailIds.Add(Convert.ToInt64(await detail.ExecuteScalarAsync(token)));
            }
            await tx.CommitAsync(token); return Ok(new { requestId, detailIds, statusCode = "DRAFT" });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { await tx.RollbackAsync(token); return Conflict(new { message = "เลขที่คำขอซ้ำ", description = "กรุณาบันทึกใหม่อีกครั้ง" }); }
        catch { await tx.RollbackAsync(token); throw; }
    }

    [HttpPost("{requestId:long}/details/{detailId:long}/attachments"), RequestSizeLimit(3 * 1024 * 1024)]
    public async Task<IActionResult> Upload(long requestId, long detailId, IFormFile file, CancellationToken token = default)
    {
        if (file.Length <= 0 || file.Length > 3 * 1024 * 1024) return BadRequest(new { message = "ไฟล์ไม่ถูกต้อง", description = "ไฟล์ต้องมีขนาดไม่เกิน 3 MiB" });
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant(); var allowed = new[] { ".jpg", ".jpeg", ".png", ".webp", ".pdf", ".doc", ".docx", ".xls", ".xlsx" }; if (!allowed.Contains(ext)) return BadRequest(new { message = "ชนิดไฟล์ไม่รองรับ", description = "รองรับรูปภาพและเอกสารสำนักงาน" });
        await using var db = new SqlConnection(ConnectionString); await db.OpenAsync(token); await using var tx = await db.BeginTransactionAsync(token); var company = CompanyId();
        await using var check = new SqlCommand("SELECT COUNT(1) FROM dbo.TDAPPurchaseRequestDetail d JOIN dbo.TDAPPurchaseRequest h ON h.RequestID=d.RequestID WHERE h.CompanyID=@company AND d.RequestID=@request AND d.DetailID=@detail", db, (SqlTransaction)tx); Add(check, "@company", SqlDbType.BigInt, company); Add(check, "@request", SqlDbType.BigInt, requestId); Add(check, "@detail", SqlDbType.BigInt, detailId); if (Convert.ToInt32(await check.ExecuteScalarAsync(token)) != 1) return NotFound();
        var stored = $"{Guid.NewGuid():N}{ext}"; var relative = Path.Combine("uploads", "purchasing", company.ToString(CultureInfo.InvariantCulture), requestId.ToString(CultureInfo.InvariantCulture), detailId.ToString(CultureInfo.InvariantCulture), stored); var full = Path.Combine(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"), relative); Directory.CreateDirectory(Path.GetDirectoryName(full)!); await using (var output = System.IO.File.Create(full)) await file.CopyToAsync(output, token);
        await using var insert = new SqlCommand("INSERT dbo.TDAPPurchaseRequestAttachment(RequestID,DetailID,FileName,StoredPath,ContentType,FileSize,CreateBy) OUTPUT INSERTED.AttachmentID VALUES(@request,@detail,@name,@path,@type,@size,@user)", db, (SqlTransaction)tx); Add(insert, "@request", SqlDbType.BigInt, requestId); Add(insert, "@detail", SqlDbType.BigInt, detailId); Add(insert, "@name", SqlDbType.NVarChar, Path.GetFileName(file.FileName)); Add(insert, "@path", SqlDbType.NVarChar, relative.Replace('\\', '/')); Add(insert, "@type", SqlDbType.NVarChar, file.ContentType ?? "application/octet-stream"); Add(insert, "@size", SqlDbType.BigInt, file.Length); Add(insert, "@user", SqlDbType.BigInt, UserId()); var id = Convert.ToInt64(await insert.ExecuteScalarAsync(token)); await tx.CommitAsync(token); return Ok(new { attachmentId = id, fileName = Path.GetFileName(file.FileName), url = $"/api/purchasing/requests/{requestId}/attachments/{id}" });
    }

    private long CompanyId() => long.TryParse(User.FindFirst("CompanyID")?.Value, out var id) ? id : throw new UnauthorizedAccessException("Company scope is required.");
    private long UserId() => long.TryParse(User.FindFirst("UserID")?.Value, out var id) ? id : throw new UnauthorizedAccessException("User identity is required.");
    private static void Add(SqlCommand command, string name, SqlDbType type, object value) { var p = command.Parameters.Add(name, type); p.Value = value; }
}

public sealed class PurchaseRequestWriteRequest
{
    public string? RequestNo { get; init; }
    public string? RequestDate { get; init; }
    public long? DivisionId { get; init; }
    public long? DepartmentId { get; init; }
    public string? Remark { get; init; }
    public List<PurchaseRequestDetailWriteRequest> Details { get; init; } = [];
}
public sealed class PurchaseRequestDetailWriteRequest
{
    public string ItemText { get; init; } = string.Empty;
    public decimal? Quantity { get; init; }
    public decimal? EstimatedMin { get; init; }
    public decimal? EstimatedMax { get; init; }
    public string? Remark { get; init; }
    public string? NeededDate { get; init; }
    public byte UrgencyLevel { get; init; }
}
