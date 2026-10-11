using System.Data;
using System.Security.Cryptography;
using LaooServiceModule.Infrastructure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;

public sealed partial class EmployeeBorrowController
{
    [HttpPost("requests/{id:long}/lines/{lineId:long}/issue")]
    public Task<IActionResult> Issue(long id, long lineId, [FromForm] BorrowTransferInput input, CancellationToken token) => Transfer(id, lineId, input, false, token);

    [HttpPost("requests/{id:long}/lines/{lineId:long}/return")]
    public Task<IActionResult> Return(long id, long lineId, [FromForm] BorrowTransferInput input, CancellationToken token) => Transfer(id, lineId, input, true, token);

    private async Task<IActionResult> Transfer(long id, long lineId, BorrowTransferInput input, bool returning, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "08010", returning ? "RETURN" : "ISSUE", token)) return Denied();
        if (input.Photo is null || input.Photo.Length == 0 || input.Photo.Length > 5 * 1024 * 1024)
            return Invalid("รูปประกอบไม่ถูกต้อง", "แนบ JPG, PNG หรือ WebP ขนาดไม่เกิน 5 MB ต่อรายการ");
        if (input.Quantity <= 0) return Invalid("จำนวนไม่ถูกต้อง", "จำนวนต้องมากกว่า 0");
        var extension = Path.GetExtension(input.Photo.FileName).ToLowerInvariant();
        if (extension is not (".jpg" or ".jpeg" or ".png" or ".webp")) return Invalid("รูปประกอบไม่ถูกต้อง", "ชนิดไฟล์ต้องเป็น JPG, PNG หรือ WebP");
        var folder = Path.Combine(environment.ContentRootPath, "private_uploads", "borrow", Company.ToString(), id.ToString());
        Directory.CreateDirectory(folder);
        var fileName = Guid.NewGuid().ToString("N") + extension;
        var fullPath = Path.Combine(folder, fileName);
        string hash;
        string mime;
        try
        {
            await using (var file = System.IO.File.Create(fullPath)) await input.Photo.CopyToAsync(file, token);
            await using var fileForHash = System.IO.File.OpenRead(fullPath);
            var signature = new byte[12];
            var count = await fileForHash.ReadAsync(signature, token);
            mime = count >= 3 && signature[0] == 0xff && signature[1] == 0xd8 && signature[2] == 0xff ? "image/jpeg"
                : count >= 8 && signature.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }) ? "image/png"
                : count >= 12 && System.Text.Encoding.ASCII.GetString(signature, 0, 4) == "RIFF" && System.Text.Encoding.ASCII.GetString(signature, 8, 4) == "WEBP" ? "image/webp"
                : throw new InvalidDataException("Invalid image signature");
            if ((mime == "image/jpeg" && extension is not (".jpg" or ".jpeg")) || (mime == "image/png" && extension != ".png") || (mime == "image/webp" && extension != ".webp")) throw new InvalidDataException("Image extension does not match content");
            fileForHash.Position = 0;
            hash = Convert.ToHexString(await SHA256.HashDataAsync(fileForHash, token)).ToLowerInvariant();
        }
        catch
        {
            if (System.IO.File.Exists(fullPath)) System.IO.File.Delete(fullPath);
            return Invalid("บันทึกรูปไม่สำเร็จ", "โปรดลองแนบรูปอีกครั้ง");
        }
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            var request = await LockedRequest(c, tx, id, token);
            if (request is null) { await tx.RollbackAsync(token); System.IO.File.Delete(fullPath); return NotFound(); }
            if (!await WarehouseAccessService.CanAccessAsync(c, tx, Company, UserId, request.Value.WarehouseID, token)) throw new InvalidOperationException("คำขออยู่นอกคลังที่มีสิทธิ์");
            if (returning && request.Value.Status is not ("ISSUED" or "PARTIAL_RETURN")) throw new InvalidOperationException("คำขอยังไม่ส่งมอบ");
            if (!returning && request.Value.Status is not ("READY" or "ISSUED" or "PARTIAL_RETURN")) throw new InvalidOperationException("คำขอยังไม่พร้อมส่งมอบ");
            long item = 0; decimal quantity = 0, issued = 0, returned = 0; string? tracking = null;
            await using (var line = new SqlCommand("SELECT ItemID,Quantity,IssuedQuantity,ReturnedQuantity,StockTrackingSnapshot FROM dbo.TDIVBorrowRequestLine WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND BorrowRequestID=@request AND BorrowRequestLineID=@line", c, tx))
            {
                P(line, "@company", SqlDbType.BigInt, Company); P(line, "@request", SqlDbType.BigInt, id); P(line, "@line", SqlDbType.BigInt, lineId);
                await using var r = await line.ExecuteReaderAsync(token);
                if (await r.ReadAsync(token)) { item = r.GetInt64(0); quantity = r.GetDecimal(1); issued = r.GetDecimal(2); returned = r.GetDecimal(3); tracking = r.GetString(4); }
            }
            if (tracking is null) throw new InvalidOperationException("ไม่พบรายการสินค้าในคำขอ");
            if (returning ? returned + input.Quantity > issued : issued + input.Quantity > quantity) throw new InvalidOperationException("จำนวนเกินยอดคงค้างของรายการ");
            if (tracking == "SERIAL" && (input.Quantity != 1 || input.ItemInstanceID is null)) throw new InvalidOperationException("สินค้า SN ต้องเลือกทีละหนึ่งหมายเลขต่อรูป");
            if (tracking != "SERIAL" && input.ItemInstanceID is not null) throw new InvalidOperationException("สินค้านับจำนวนไม่ต้องระบุ SN");
            if (tracking == "SERIAL")
            {
                await using var serial = new SqlCommand("UPDATE S SET StatusCode=@next FROM dbo.TDIVBorrowSerial S JOIN dbo.TDIVBorrowRequestLine L ON L.BorrowRequestLineID=S.BorrowRequestLineID WHERE S.CompanyID=@company AND S.BorrowRequestLineID=@line AND L.BorrowRequestID=@request AND S.ItemInstanceID=@instance AND S.StatusCode=@previous; IF @@ROWCOUNT<>1 THROW 59211,N'Borrow serial state conflict',1; UPDATE dbo.TDIVItemInstance SET StatusCode=@instanceNext,WarehouseID=@nextWarehouse,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE CompanyID=@company AND ItemInstanceID=@instance AND ItemID=@item AND StatusCode=@instancePrevious AND ((@returning=1 AND WarehouseID IS NULL) OR (@returning=0 AND WarehouseID=@warehouse)); IF @@ROWCOUNT<>1 THROW 59212,N'Item instance state conflict',1; INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,WarehouseID,DocumentType,DocumentID,DocumentDetailID,CreatedBy) VALUES(@company,@instance,@instancePrevious,@instanceNext,@warehouse,N'BORROW',@request,@line,@user)", c, tx);
                P(serial, "@next", SqlDbType.NVarChar, returning ? "RETURNED" : "ISSUED", 15); P(serial, "@previous", SqlDbType.NVarChar, returning ? "ISSUED" : "RESERVED", 15);
                P(serial, "@instanceNext", SqlDbType.NVarChar, returning ? "IN_STOCK" : "ISSUED", 20); P(serial, "@instancePrevious", SqlDbType.NVarChar, returning ? "ISSUED" : "RESERVED", 20);
                P(serial, "@nextWarehouse", SqlDbType.BigInt, returning ? request.Value.WarehouseID : null); P(serial, "@returning", SqlDbType.Bit, returning); P(serial, "@warehouse", SqlDbType.BigInt, request.Value.WarehouseID);
                P(serial, "@company", SqlDbType.BigInt, Company); P(serial, "@line", SqlDbType.BigInt, lineId); P(serial, "@request", SqlDbType.BigInt, id); P(serial, "@instance", SqlDbType.BigInt, input.ItemInstanceID); P(serial, "@item", SqlDbType.BigInt, item); P(serial, "@user", SqlDbType.BigInt, UserId);
                await serial.ExecuteNonQueryAsync(token);
            }
            await using (var stock = new SqlCommand("UPDATE dbo.TDIVStockBalance SET Quantity=Quantity+@change,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND WarehouseID=@warehouse AND ItemID=@item AND Quantity+@change>=0; IF @@ROWCOUNT<>1 THROW 59213,N'Borrow stock conflict',1", c, tx))
            {
                P(stock, "@change", SqlDbType.Decimal, returning ? input.Quantity : -input.Quantity); P(stock, "@company", SqlDbType.BigInt, Company); P(stock, "@warehouse", SqlDbType.BigInt, request.Value.WarehouseID); P(stock, "@item", SqlDbType.BigInt, item);
                await stock.ExecuteNonQueryAsync(token);
            }
            await using var transfer = new SqlCommand("INSERT dbo.TDIVBorrowTransfer(CompanyID,BorrowRequestLineID,ItemInstanceID,TransferType,Quantity,ConditionNote,CreatedBy) OUTPUT INSERTED.BorrowTransferID VALUES(@company,@line,@instance,@type,@quantity,@note,@user)", c, tx);
            P(transfer, "@company", SqlDbType.BigInt, Company); P(transfer, "@line", SqlDbType.BigInt, lineId); P(transfer, "@instance", SqlDbType.BigInt, input.ItemInstanceID); P(transfer, "@type", SqlDbType.NVarChar, returning ? "RETURN" : "ISSUE", 10); P(transfer, "@quantity", SqlDbType.Decimal, input.Quantity); P(transfer, "@note", SqlDbType.NVarChar, input.ConditionNote?.Trim(), 1000); P(transfer, "@user", SqlDbType.BigInt, UserId);
            var transferID = Convert.ToInt64(await transfer.ExecuteScalarAsync(token));
            await using (var movement = new SqlCommand("INSERT dbo.TDIVStockMovement(CompanyID,WarehouseID,ItemID,ItemInstanceID,DocumentType,DocumentID,DocumentDetailID,MovementType,Quantity,CreatedBy) VALUES(@company,@warehouse,@item,@instance,N'BORROW_TRANSFER',@request,@transfer,@type,@quantity,@user)", c, tx))
            {
                P(movement, "@company", SqlDbType.BigInt, Company); P(movement, "@warehouse", SqlDbType.BigInt, request.Value.WarehouseID); P(movement, "@item", SqlDbType.BigInt, item); P(movement, "@instance", SqlDbType.BigInt, input.ItemInstanceID); P(movement, "@request", SqlDbType.BigInt, id); P(movement, "@transfer", SqlDbType.BigInt, transferID); P(movement, "@type", SqlDbType.NVarChar, returning ? "BORROW_RETURN" : "BORROW_OUT", 30); P(movement, "@quantity", SqlDbType.Decimal, returning ? input.Quantity : -input.Quantity); P(movement, "@user", SqlDbType.BigInt, UserId);
                await movement.ExecuteNonQueryAsync(token);
            }
            var relative = $"borrow/{Company}/{id}/{fileName}";
            await using (var photo = new SqlCommand("INSERT dbo.TDIVBorrowPhoto(CompanyID,BorrowTransferID,FilePath,FileName,ContentType,FileSize,Sha256) VALUES(@company,@transfer,@path,@name,@type,@size,@sha)", c, tx))
            {
                P(photo, "@company", SqlDbType.BigInt, Company); P(photo, "@transfer", SqlDbType.BigInt, transferID); P(photo, "@path", SqlDbType.NVarChar, relative, 500); P(photo, "@name", SqlDbType.NVarChar, Path.GetFileName(input.Photo.FileName), 255); P(photo, "@type", SqlDbType.NVarChar, mime, 100); P(photo, "@size", SqlDbType.BigInt, input.Photo.Length); P(photo, "@sha", SqlDbType.Char, hash, 64); await photo.ExecuteNonQueryAsync(token);
            }
            await using (var count = new SqlCommand($"UPDATE dbo.TDIVBorrowRequestLine SET {(returning ? "ReturnedQuantity" : "IssuedQuantity")}={(returning ? "ReturnedQuantity" : "IssuedQuantity")}+@quantity WHERE BorrowRequestLineID=@line AND CompanyID=@company", c, tx))
            {
                P(count, "@quantity", SqlDbType.Decimal, input.Quantity); P(count, "@line", SqlDbType.BigInt, lineId); P(count, "@company", SqlDbType.BigInt, Company); await count.ExecuteNonQueryAsync(token);
            }
            string nextStatus;
            await using (var totals = new SqlCommand("SELECT SUM(Quantity),SUM(IssuedQuantity),SUM(ReturnedQuantity) FROM dbo.TDIVBorrowRequestLine WHERE CompanyID=@company AND BorrowRequestID=@request", c, tx))
            {
                P(totals, "@company", SqlDbType.BigInt, Company); P(totals, "@request", SqlDbType.BigInt, id);
                await using var r = await totals.ExecuteReaderAsync(token); await r.ReadAsync(token);
                var total = r.GetDecimal(0); var sent = r.GetDecimal(1); var back = r.GetDecimal(2);
                nextStatus = sent == total && back == sent ? "RETURNED" : back > 0 ? "PARTIAL_RETURN" : sent > 0 ? "ISSUED" : "READY";
            }
            await using (var update = new SqlCommand("UPDATE dbo.TDIVBorrowRequest SET StatusCode=@status,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE CompanyID=@company AND BorrowRequestID=@request", c, tx))
            {
                P(update, "@status", SqlDbType.NVarChar, nextStatus, 25); P(update, "@user", SqlDbType.BigInt, UserId); P(update, "@company", SqlDbType.BigInt, Company); P(update, "@request", SqlDbType.BigInt, id); await update.ExecuteNonQueryAsync(token);
            }
            await Audit(c, tx, id, returning ? "RETURN" : "ISSUE", $"line={lineId},qty={input.Quantity},transfer={transferID}", token);
            await tx.CommitAsync(token);
            return Ok(new { transferID, statusCode = nextStatus });
        }
        catch (Exception ex) when (ex is InvalidOperationException or SqlException)
        {
            await tx.RollbackAsync(token);
            System.IO.File.Delete(fullPath);
            return Invalid(returning ? "รับคืนไม่สำเร็จ" : "ส่งมอบไม่สำเร็จ", ex is InvalidOperationException ? ex.Message : "สต๊อกหรือสถานะ SN เปลี่ยนไป โปรดโหลดรายการแล้วลองใหม่");
        }
    }

    [HttpGet("photos/{photoId:long}")]
    public async Task<IActionResult> Photo(long photoId, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, "08008", "VIEW", token) && !await Can(c, "08010", "VIEW", token) && !await Can(c, "08011", "VIEW", token)) return Denied();
        await using var cmd = new SqlCommand($"SELECT P.FilePath,P.ContentType FROM dbo.TDIVBorrowPhoto P JOIN dbo.TDIVBorrowTransfer T ON T.BorrowTransferID=P.BorrowTransferID AND T.CompanyID=P.CompanyID JOIN dbo.TDIVBorrowRequestLine L ON L.BorrowRequestLineID=T.BorrowRequestLineID AND L.CompanyID=P.CompanyID JOIN dbo.TDIVBorrowRequest R ON R.BorrowRequestID=L.BorrowRequestID AND R.CompanyID=P.CompanyID JOIN dbo.TDIVWarehouse W ON W.WarehouseID=R.WarehouseID AND W.CompanyID=R.CompanyID JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1 WHERE P.BorrowPhotoID=@photo AND P.CompanyID=@company AND {WarehouseAccessService.WarehouseAliasPredicate}", c);
        P(cmd, "@photo", SqlDbType.BigInt, photoId); P(cmd, "@company", SqlDbType.BigInt, Company); P(cmd, "@user", SqlDbType.BigInt, UserId);
        string? relative = null, content = null;
        await using (var r = await cmd.ExecuteReaderAsync(token)) if (await r.ReadAsync(token)) { relative = r.GetString(0); content = r.GetString(1); }
        if (relative is null) return NotFound();
        var root = Path.Combine(environment.ContentRootPath, "private_uploads");
        var path = Path.GetFullPath(Path.Combine(root, relative.Replace('/', Path.DirectorySeparatorChar)));
        if (!path.StartsWith(Path.GetFullPath(root) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || !System.IO.File.Exists(path)) return NotFound();
        return PhysicalFile(path, content!);
    }
}

public sealed class BorrowTransferInput
{
    public decimal Quantity { get; set; }
    public long? ItemInstanceID { get; set; }
    public string? ConditionNote { get; set; }
    [FromForm(Name = "file")]
    public IFormFile? Photo { get; set; }
}
