using System.Security.Cryptography;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Laoo.Rental.Controllers;

public sealed partial class RentalController
{
    private string FileDirectory(long bookingId)
    {
        var root = configuration["Rental:PrivateStorageRoot"];
        if (string.IsNullOrWhiteSpace(root))
            root = Path.Combine(AppContext.BaseDirectory, "private", "rental");
        return Path.Combine(Path.GetFullPath(root), Company.ToString(), bookingId.ToString());
    }

    private static bool ImageMatches(string mime, ReadOnlySpan<byte> bytes) => mime switch
    {
        "image/jpeg" => bytes.Length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF,
        "image/png" => bytes.Length >= 8 && bytes[..8].SequenceEqual(
            new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }),
        "image/webp" => bytes.Length >= 12 && bytes[..4].SequenceEqual("RIFF"u8)
            && bytes[8..12].SequenceEqual("WEBP"u8),
        _ => false
    };

    [HttpPost("bookings/{bookingId:long}/attachments")]
    [RequestSizeLimit(11_000_000)]
    public async Task<IActionResult> UploadAttachment(long bookingId, [FromForm] string kind,
        [FromForm] long? bookingLineId, [FromForm] IFormFile file, CancellationToken ct)
    {
        var isHandover = kind is "HANDOVER_PHOTO" or "HANDOVER_STAFF_SIGN" or "HANDOVER_CUSTOMER_SIGN";
        var isReturn = kind is "RETURN_PHOTO" or "RETURN_STAFF_SIGN" or "RETURN_CUSTOMER_SIGN";
        if ((!isHandover && !isReturn) || file is null || file.Length is < 1 or > 10_000_000
            || file.ContentType is not ("image/jpeg" or "image/png" or "image/webp")
            || (kind.EndsWith("_SIGN", StringComparison.Ordinal) && file.ContentType != "image/png")
            || (kind.EndsWith("_PHOTO", StringComparison.Ordinal) != (bookingLineId is > 0))
            || Path.GetFileName(file.FileName).Length > 260)
            return Invalid("Invalid rental attachment");
        await using var db = await Open(ct);
        if (await Guard(db, isHandover ? "60006" : "60007", "CREATE", ct) is { } denied) return denied;
        var scope = await BookingScope(db, null, bookingId, ct);
        if (scope is null) return NotFound();
        if (await BranchGuard(db, scope.Value.Branch, ct) is { } blocked) return blocked;
        if (scope.Value.Status is "CANCELLED" or "CLOSED") return Conflict(new { message = "Booking is closed" });
        if (isReturn && scope.Value.Status is not ("OUT" or "PARTIAL_RETURN"))
            return Conflict(new { message = "Return evidence is available after handover" });
        if (isHandover && scope.Value.Status is not ("RESERVED" or "PAID"))
            return Conflict(new { message = "Handover evidence is no longer available" });
        if (bookingLineId is > 0 && await RentalDb.Number(db, null, """
SELECT COUNT(*) FROM dbo.TDRNBookingLine WHERE CompanyID=@co AND BookingID=@booking AND BookingLineID=@line
""", ct, ("@co", Company), ("@booking", bookingId), ("@line", bookingLineId.Value)) == 0)
            return Invalid("Line does not belong to booking");
        var header = new byte[12];
        await using (var source = file.OpenReadStream())
        {
            var read = await source.ReadAsync(header, ct);
            if (!ImageMatches(file.ContentType, header.AsSpan(0, read)))
                return Invalid("File content does not match image type");
        }
        var name = Guid.NewGuid().ToString("N") + (file.ContentType switch
        {
            "image/jpeg" => ".jpg", "image/png" => ".png", _ => ".webp"
        });
        var directory = FileDirectory(bookingId);
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, name);
        try
        {
            await using (var target = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                await file.CopyToAsync(target, ct);
            var actualSize = new FileInfo(path).Length;
            if (actualSize > 10_000_000)
            {
                System.IO.File.Delete(path);
                return Invalid("Image is too large");
            }
            await using var saved = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
            var sha = Convert.ToHexString(await SHA256.HashDataAsync(saved, ct));
            var id = await RentalDb.Number(db, null, """
INSERT dbo.TDRNAttachment(CompanyID,BookingID,BookingLineID,Kind,StoredName,OriginalName,
MimeType,SizeBytes,Sha256,CreatedBy)
OUTPUT INSERTED.AttachmentID
VALUES(@co,@booking,@line,@kind,@name,@original,@mime,@size,@hash,@actor)
""", ct, ("@co", Company), ("@booking", bookingId), ("@line", bookingLineId),
                ("@kind", kind), ("@name", name), ("@original", Path.GetFileName(file.FileName)),
                ("@mime", file.ContentType), ("@size", actualSize), ("@hash", sha),
                ("@actor", Actor));
            return Created($"/api/company/rental/attachments/{id}", new { id, kind });
        }
        catch
        {
            if (System.IO.File.Exists(path)) System.IO.File.Delete(path);
            throw;
        }
    }

    [HttpGet("attachments/{attachmentId:long}")]
    public async Task<IActionResult> DownloadAttachment(long attachmentId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (!RentalAccess.Scope(User, out _, out _)) return Forbid();
        var rows = await RentalDb.Rows(db, null, """
SELECT A.BookingID,A.Kind,A.StoredName,A.OriginalName,A.MimeType,H.BranchID
FROM dbo.TDRNAttachment A JOIN dbo.TDRNBooking H
 ON H.CompanyID=A.CompanyID AND H.BookingID=A.BookingID
WHERE A.CompanyID=@co AND A.AttachmentID=@id
""", ct, ("@co", Company), ("@id", attachmentId));
        if (rows.Count == 0) return NotFound();
        var row = rows[0];
        var kind = Convert.ToString(row["Kind"])!;
        if (await Guard(db, kind.StartsWith("HANDOVER_", StringComparison.Ordinal) ? "60006" : "60007",
            "VIEW", ct) is { } denied) return denied;
        if (await BranchGuard(db, Convert.ToInt64(row["BranchID"]), ct) is { } blocked) return blocked;
        var name = Convert.ToString(row["StoredName"])!;
        if (Path.GetFileName(name) != name) return NotFound();
        var path = Path.Combine(FileDirectory(Convert.ToInt64(row["BookingID"])), name);
        if (!System.IO.File.Exists(path)) return NotFound();
        return PhysicalFile(path, Convert.ToString(row["MimeType"])!);
    }
}
