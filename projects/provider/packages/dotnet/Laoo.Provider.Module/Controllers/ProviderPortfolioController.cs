using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooProviderModule.Controllers;

[ApiController, Authorize, Route("api/company/provider/portfolio")]
public sealed class ProviderPortfolioController(
    IConfiguration configuration,
    IWebHostEnvironment environment) : ProviderControllerBase(configuration)
{
    private const string MenuCode = "51009";
    private const long MaxImageBytes = 1024 * 1024;
    private static readonly HashSet<string> Extensions =
        new(StringComparer.OrdinalIgnoreCase) { ".jpg", ".jpeg", ".png", ".webp" };

    [HttpGet]
    public async Task<IActionResult> List(
        string? search = null,
        int page = 1,
        int pageSize = 30,
        CancellationToken token = default)
    {
        if (!CompanyScope(out var company, out _)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, MenuCode, "VIEW", token)) return Forbid();
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var query = Clean(search);
        var total = await ProviderDb.Scalar<int>(
            db,
            "SELECT COUNT(*) FROM dbo.TDPRPortfolio WHERE CompanyID=@company AND (@search IS NULL OR WorkTitle LIKE N'%'+@search+N'%')",
            token,
            ("@company", company),
            ("@search", query));
        var items = await ProviderDb.Query(
            db,
            """
SELECT PortfolioID id,WorkTitle title,ServiceDate serviceDate,CoverImagePath coverImagePath,
       CoverMimeType coverMimeType,CoverSizeBytes coverSizeBytes,IsActive active,
       CreateDate createDate,UpdateDate updateDate
FROM dbo.TDPRPortfolio
WHERE CompanyID=@company AND (@search IS NULL OR WorkTitle LIKE N'%'+@search+N'%')
ORDER BY ServiceDate DESC,PortfolioID DESC
OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY
""",
            token,
            ("@company", company),
            ("@search", query),
            ("@skip", (page - 1) * pageSize),
            ("@take", pageSize));
        foreach (var item in items)
        {
            item["photos"] = await ProviderDb.Query(
                db,
                """
SELECT PortfolioImageID id,ImagePath imagePath,MimeType mimeType,SizeBytes sizeBytes,SortOrder sortOrder
FROM dbo.TDPRPortfolioImage
WHERE CompanyID=@company AND PortfolioID=@portfolio
ORDER BY SortOrder,PortfolioImageID
""",
                token,
                ("@company", company),
                ("@portfolio", item["id"]));
        }
        return Ok(new { items, total, page, pageSize });
    }

    [HttpPost, RequestSizeLimit(MaxImageBytes + 65536)]
    public async Task<IActionResult> Create(
        IFormFile file,
        [FromForm] string title,
        [FromForm] DateTime serviceDate,
        [FromForm] bool active = true,
        CancellationToken token = default)
    {
        var cleanTitle = Clean(title);
        if (cleanTitle is null || cleanTitle.Length > 200)
            return BadRequest(new { message = "กรุณาระบุชื่อผลงานไม่เกิน 200 ตัวอักษร" });
        if (serviceDate.Date > DateTime.UtcNow.Date)
            return BadRequest(new { message = "วันที่ดำเนินการต้องไม่เป็นวันที่ในอนาคต" });
        var validation = await ValidateImage(file, token);
        if (validation.Error is not null) return BadRequest(new { message = validation.Error });
        if (!CompanyScope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, MenuCode, "CREATE", token)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(token);
        string? absolutePath = null;
        try
        {
            var id = await ProviderDb.Scalar<long>(
                db,
                tx,
                """
INSERT dbo.TDPRPortfolio(CompanyID,WorkTitle,ServiceDate,CoverImagePath,CoverMimeType,CoverSizeBytes,IsActive,CreateBy)
OUTPUT INSERTED.PortfolioID
VALUES(@company,@title,@date,N'pending',@mime,@size,@active,@user)
""",
                token,
                ("@company", company),
                ("@title", cleanTitle),
                ("@date", serviceDate.Date),
                ("@mime", validation.MimeType),
                ("@size", file.Length),
                ("@active", active),
                ("@user", user));
            var stored = await StoreImage(file, company, id, "cover", validation.Extension!, token);
            absolutePath = stored.AbsolutePath;
            await ProviderDb.Execute(
                db,
                tx,
                "UPDATE dbo.TDPRPortfolio SET CoverImagePath=@path WHERE PortfolioID=@id AND CompanyID=@company",
                token,
                ("@path", stored.RelativePath),
                ("@id", id),
                ("@company", company));
            await Audit(db, tx, company, "PORTFOLIO", id, "CREATE", cleanTitle, user, token);
            await tx.CommitAsync(token);
            return Ok(new { id, coverImagePath = stored.RelativePath });
        }
        catch
        {
            await tx.RollbackAsync(token);
            DeleteFile(absolutePath);
            throw;
        }
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(
        long id,
        PortfolioUpdateRequest request,
        CancellationToken token)
    {
        var cleanTitle = Clean(request.Title);
        if (cleanTitle is null || cleanTitle.Length > 200)
            return BadRequest(new { message = "กรุณาระบุชื่อผลงานไม่เกิน 200 ตัวอักษร" });
        if (request.ServiceDate.Date > DateTime.UtcNow.Date)
            return BadRequest(new { message = "วันที่ดำเนินการต้องไม่เป็นวันที่ในอนาคต" });
        if (!CompanyScope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, MenuCode, "EDIT", token)) return Forbid();
        var changed = await ProviderDb.Execute(
            db,
            """
UPDATE dbo.TDPRPortfolio
SET WorkTitle=@title,ServiceDate=@date,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHERE PortfolioID=@id AND CompanyID=@company
""",
            token,
            ("@title", cleanTitle),
            ("@date", request.ServiceDate.Date),
            ("@active", request.Active),
            ("@user", user),
            ("@id", id),
            ("@company", company));
        return changed == 1 ? NoContent() : NotFound();
    }

    [HttpPost("{id:long}/cover"), RequestSizeLimit(MaxImageBytes + 65536)]
    public async Task<IActionResult> ReplaceCover(long id, IFormFile file, CancellationToken token)
    {
        var validation = await ValidateImage(file, token);
        if (validation.Error is not null) return BadRequest(new { message = validation.Error });
        if (!CompanyScope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, MenuCode, "EDIT", token)) return Forbid();
        var rows = await ProviderDb.Query(
            db,
            "SELECT CoverImagePath path FROM dbo.TDPRPortfolio WHERE PortfolioID=@id AND CompanyID=@company",
            token,
            ("@id", id),
            ("@company", company));
        if (rows.Count == 0) return NotFound();
        var stored = await StoreImage(file, company, id, "cover", validation.Extension!, token);
        var changed = await ProviderDb.Execute(
            db,
            """
UPDATE dbo.TDPRPortfolio
SET CoverImagePath=@path,CoverMimeType=@mime,CoverSizeBytes=@size,UpdateBy=@user,UpdateDate=SYSUTCDATETIME()
WHERE PortfolioID=@id AND CompanyID=@company
""",
            token,
            ("@path", stored.RelativePath),
            ("@mime", validation.MimeType),
            ("@size", file.Length),
            ("@user", user),
            ("@id", id),
            ("@company", company));
        if (changed != 1)
        {
            DeleteFile(stored.AbsolutePath);
            return NotFound();
        }
        DeleteRelativeFile(Convert.ToString(rows[0]["path"]));
        return Ok(new { coverImagePath = stored.RelativePath });
    }

    [HttpPost("{id:long}/photos"), RequestSizeLimit(MaxImageBytes + 65536)]
    public async Task<IActionResult> AddPhoto(long id, IFormFile file, CancellationToken token)
    {
        var validation = await ValidateImage(file, token);
        if (validation.Error is not null) return BadRequest(new { message = validation.Error });
        if (!CompanyScope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, MenuCode, "EDIT", token)) return Forbid();
        if (await ProviderDb.Scalar<int>(
                db,
                "SELECT COUNT(*) FROM dbo.TDPRPortfolio WHERE PortfolioID=@id AND CompanyID=@company",
                token,
                ("@id", id),
                ("@company", company)) == 0) return NotFound();
        var stored = await StoreImage(file, company, id, "photo", validation.Extension!, token);
        try
        {
            var photoId = await ProviderDb.Scalar<long>(
                db,
                """
INSERT dbo.TDPRPortfolioImage(PortfolioID,CompanyID,ImagePath,MimeType,SizeBytes,SortOrder,CreateBy)
OUTPUT INSERTED.PortfolioImageID
VALUES(@portfolio,@company,@path,@mime,@size,
       ISNULL((SELECT MAX(SortOrder)+1 FROM dbo.TDPRPortfolioImage WHERE PortfolioID=@portfolio),1),@user)
""",
                token,
                ("@portfolio", id),
                ("@company", company),
                ("@path", stored.RelativePath),
                ("@mime", validation.MimeType),
                ("@size", file.Length),
                ("@user", user));
            return Ok(new { id = photoId, imagePath = stored.RelativePath });
        }
        catch
        {
            DeleteFile(stored.AbsolutePath);
            throw;
        }
    }

    [HttpDelete("{portfolioId:long}/photos/{photoId:long}")]
    public async Task<IActionResult> DeletePhoto(long portfolioId, long photoId, CancellationToken token)
    {
        if (!CompanyScope(out var company, out _)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, MenuCode, "EDIT", token)) return Forbid();
        var rows = await ProviderDb.Query(
            db,
            """
SELECT i.ImagePath path
FROM dbo.TDPRPortfolioImage i
JOIN dbo.TDPRPortfolio p ON p.PortfolioID=i.PortfolioID AND p.CompanyID=i.CompanyID
WHERE i.PortfolioImageID=@photo AND i.PortfolioID=@portfolio AND i.CompanyID=@company
""",
            token,
            ("@photo", photoId),
            ("@portfolio", portfolioId),
            ("@company", company));
        if (rows.Count == 0) return NotFound();
        await ProviderDb.Execute(
            db,
            "DELETE dbo.TDPRPortfolioImage WHERE PortfolioImageID=@photo AND PortfolioID=@portfolio AND CompanyID=@company",
            token,
            ("@photo", photoId),
            ("@portfolio", portfolioId),
            ("@company", company));
        DeleteRelativeFile(Convert.ToString(rows[0]["path"]));
        return NoContent();
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        if (!CompanyScope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await Can(db, MenuCode, "DELETE", token)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(token);
        var paths = await ProviderDb.Query(
            db,
            tx,
            """
SELECT CoverImagePath path FROM dbo.TDPRPortfolio WHERE PortfolioID=@id AND CompanyID=@company
UNION ALL
SELECT i.ImagePath FROM dbo.TDPRPortfolioImage i JOIN dbo.TDPRPortfolio p ON p.PortfolioID=i.PortfolioID AND p.CompanyID=i.CompanyID
WHERE i.PortfolioID=@id AND i.CompanyID=@company
""",
            token,
            ("@id", id),
            ("@company", company));
        if (paths.Count == 0)
        {
            await tx.RollbackAsync(token);
            return NotFound();
        }
        await ProviderDb.Execute(
            db,
            tx,
            "DELETE dbo.TDPRPortfolio WHERE PortfolioID=@id AND CompanyID=@company",
            token,
            ("@id", id),
            ("@company", company));
        await Audit(db, tx, company, "PORTFOLIO", id, "DELETE", null, user, token);
        await tx.CommitAsync(token);
        foreach (var path in paths) DeleteRelativeFile(Convert.ToString(path["path"]));
        return NoContent();
    }

    private async Task<(string? Error, string? Extension, string? MimeType)> ValidateImage(
        IFormFile file,
        CancellationToken token)
    {
        if (file is null || file.Length <= 0)
            return ("กรุณาเลือกไฟล์รูปภาพ", null, null);
        if (file.Length > MaxImageBytes)
            return ("รูปภาพต้องมีขนาดไม่เกิน 1 MB หลังลดขนาด", null, null);
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!Extensions.Contains(extension))
            return ("รองรับเฉพาะไฟล์ JPG, PNG และ WEBP", null, null);
        await using var stream = file.OpenReadStream();
        var header = new byte[12];
        var read = await stream.ReadAsync(header.AsMemory(0, header.Length), token);
        var jpeg = read >= 3 && header[0] == 0xff && header[1] == 0xd8 && header[2] == 0xff;
        var png = read >= 8 && header.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 });
        var webp = read >= 12 && header.AsSpan(0, 4).SequenceEqual("RIFF"u8) && header.AsSpan(8, 4).SequenceEqual("WEBP"u8);
        if (!jpeg && !png && !webp)
            return ("เนื้อหาไฟล์ไม่ใช่รูป JPG, PNG หรือ WEBP ที่ถูกต้อง", null, null);
        if ((jpeg && extension is not ".jpg" and not ".jpeg") ||
            (png && extension != ".png") ||
            (webp && extension != ".webp"))
            return ("นามสกุลไฟล์ไม่ตรงกับชนิดรูปภาพ", null, null);
        return (null, extension, jpeg ? "image/jpeg" : png ? "image/png" : "image/webp");
    }

    private async Task<(string RelativePath, string AbsolutePath)> StoreImage(
        IFormFile file,
        long company,
        long portfolio,
        string kind,
        string extension,
        CancellationToken token)
    {
        var relativeFolder = Path.Combine("uploads", "provider", "companies", company.ToString(), "portfolio", portfolio.ToString());
        var root = environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot");
        var folder = Path.Combine(root, relativeFolder);
        Directory.CreateDirectory(folder);
        var storedName = $"{kind}-{Guid.NewGuid():N}{extension}";
        var absolute = Path.Combine(folder, storedName);
        await using var output = System.IO.File.Create(absolute);
        await file.CopyToAsync(output, token);
        return ((relativeFolder + "/" + storedName).Replace((char)92, '/'), absolute);
    }

    private void DeleteRelativeFile(string? relativePath)
    {
        if (string.IsNullOrWhiteSpace(relativePath)) return;
        var root = Path.GetFullPath(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"));
        var absolute = Path.GetFullPath(Path.Combine(root, relativePath.Replace('/', Path.DirectorySeparatorChar)));
        if (absolute.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            DeleteFile(absolute);
    }

    private static void DeleteFile(string? absolutePath)
    {
        if (!string.IsNullOrWhiteSpace(absolutePath) && System.IO.File.Exists(absolutePath))
            System.IO.File.Delete(absolutePath);
    }
}

public sealed record PortfolioUpdateRequest(string Title, DateTime ServiceDate, bool Active = true);
