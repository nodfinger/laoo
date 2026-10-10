using System.Security.Cryptography;
using Laoo.Pet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;

namespace Laoo.Pet.Controllers;

[ApiController, Authorize, Route("api/company/pet/photos")]
public sealed class PetPhotosController(IConfiguration config, IWebHostEnvironment environment) : PetControllerBase(config)
{
    const long MaxBytes = 2 * 1024 * 1024;

    [HttpPost]
    [RequestSizeLimit(MaxBytes + 65536)]
    public async Task<IActionResult> Upload([FromForm] long petId, [FromForm] long? stayId, [FromForm] IFormFile file, CancellationToken ct)
    {
        if (petId < 1 || file is null || file.Length is < 12 or > MaxBytes)
            return Invalid("เลือกรูปภาพขนาดไม่เกิน 2 MB");
        await using var db = await Open(ct);
        if (await Guard(db, stayId is null ? "62004" : "62007", "EDIT", ct) is { } denied) return denied;
        var belongs = await PetDb.Id(db, null, @"SELECT COUNT(*) FROM dbo.TDPTPet P
WHERE P.CompanyID=@c AND P.PetID=@pet AND P.IsActive=1
AND (@stay IS NULL OR EXISTS(SELECT 1 FROM dbo.TDPTStay S
  WHERE S.CompanyID=P.CompanyID AND S.PetID=P.PetID AND S.StayID=@stay))", ct,
            ("@c", Company), ("@pet", petId), ("@stay", stayId));
        if (belongs == 0) return Missing();

        var header = new byte[12];
        await using (var source = file.OpenReadStream())
        {
            await source.ReadExactlyAsync(header, ct);
        }
        var kind = Detect(header);
        if (kind is null) return Invalid("รองรับเฉพาะรูป JPG, PNG หรือ WebP");
        var root = Path.Combine(environment.ContentRootPath, "private_uploads", "pet", Company.ToString(), petId.ToString());
        Directory.CreateDirectory(root);
        var name = $"{Guid.NewGuid():N}.{kind.Value.Extension}";
        var full = Path.Combine(root, name);
        try
        {
            await using (var target = new FileStream(full, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                await file.CopyToAsync(target, ct);
            await using var saved = System.IO.File.OpenRead(full);
            var hash = Convert.ToHexString(await SHA256.HashDataAsync(saved, ct));
            var relative = $"pet/{Company}/{petId}/{name}";
            await using var tx = await db.BeginTransactionAsync(ct);
            try
            {
                var id = await PetDb.Id(db, (Microsoft.Data.SqlClient.SqlTransaction)tx,
                    "INSERT dbo.TDPTPhoto(CompanyID,PetID,StayID,FilePath,MimeType,FileSize,Sha256) VALUES(@c,@pet,@stay,@path,@mime,@size,@hash);SELECT CONVERT(bigint,SCOPE_IDENTITY())", ct,
                    ("@c", Company), ("@pet", petId), ("@stay", stayId), ("@path", relative),
                    ("@mime", kind.Value.Mime), ("@size", file.Length), ("@hash", hash));
                await PetDb.Exec(db, (Microsoft.Data.SqlClient.SqlTransaction)tx,
                    "INSERT dbo.TDPTAudit(CompanyID,EntityCode,EntityID,ActionCode,ActorID) VALUES(@c,N'PHOTO',@id,N'UPLOAD',@actor)", ct,
                    ("@c", Company), ("@id", id), ("@actor", Actor));
                await tx.CommitAsync(ct);
                return Created($"/api/company/pet/photos/{id}", new { id, petId, stayId, size = file.Length });
            }
            catch { await tx.RollbackAsync(ct); throw; }
        }
        catch
        {
            if (System.IO.File.Exists(full)) System.IO.File.Delete(full);
            throw;
        }
    }

    [HttpGet("pet/{petId:long}")]
    public async Task<IActionResult> List(long petId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "62004", "VIEW", ct) is { } denied) return denied;
        return Ok(await PetDb.Rows(db, null, "SELECT PhotoID id,StayID stayId,MimeType mimeType,FileSize size,CreatedAt createdAt FROM dbo.TDPTPhoto WHERE CompanyID=@c AND PetID=@pet ORDER BY PhotoID DESC", ct,
            ("@c", Company), ("@pet", petId)));
    }

    [HttpGet("stay/{stayId:long}")]
    public async Task<IActionResult> ListForStay(long stayId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "62007", "VIEW", ct) is { } denied) return denied;
        if (await PetDb.Id(db, null, "SELECT COUNT(*) FROM dbo.TDPTStay WHERE CompanyID=@c AND StayID=@stay", ct,
            ("@c", Company), ("@stay", stayId)) == 0) return Missing();
        return Ok(await PetDb.Rows(db, null,
            "SELECT PhotoID id,PetID petId,MimeType mimeType,FileSize size,CreatedAt createdAt FROM dbo.TDPTPhoto WHERE CompanyID=@c AND StayID=@stay ORDER BY PhotoID DESC", ct,
            ("@c", Company), ("@stay", stayId)));
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Read(long id, CancellationToken ct)
    {
        if (!PetAccess.Scope(User, out _, out _)) return Forbid();
        await using var db = await Open(ct);
        var rows = await PetDb.Rows(db, null,
            "SELECT PetID petId,StayID stayId,FilePath path,MimeType mime,Sha256 hash FROM dbo.TDPTPhoto WHERE CompanyID=@c AND PhotoID=@id", ct,
            ("@c", Company), ("@id", id));
        if (rows.Count == 0) return Missing();
        if (await Guard(db, rows[0]["stayId"] is null ? "62004" : "62007", "VIEW", ct) is { } denied) return denied;
        var relative = Convert.ToString(rows[0]["path"]);
        var prefix = $"pet/{Company}/{rows[0]["petId"]}/";
        if (relative is null || !relative.StartsWith(prefix, StringComparison.Ordinal) ||
            Path.GetFileName(relative) != relative[prefix.Length..]) return Missing();
        var full = Path.Combine(environment.ContentRootPath, "private_uploads", relative.Replace('/', Path.DirectorySeparatorChar));
        if (!System.IO.File.Exists(full)) return Missing();
        return PhysicalFile(full, Convert.ToString(rows[0]["mime"])!, enableRangeProcessing: true);
    }

    static (string Extension, string Mime)? Detect(byte[] h)
    {
        if (h[0] == 0xFF && h[1] == 0xD8 && h[2] == 0xFF) return ("jpg", "image/jpeg");
        if (h.AsSpan(0, 8).SequenceEqual(new byte[] {137,80,78,71,13,10,26,10})) return ("png", "image/png");
        if (System.Text.Encoding.ASCII.GetString(h, 0, 4) == "RIFF" &&
            System.Text.Encoding.ASCII.GetString(h, 8, 4) == "WEBP") return ("webp", "image/webp");
        return null;
    }
}
