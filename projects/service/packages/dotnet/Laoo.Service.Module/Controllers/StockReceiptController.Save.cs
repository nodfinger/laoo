using System.Data;
using LaooServiceModule.Infrastructure;
using LaooServiceModule.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace LaooServiceModule.Controllers;

public sealed partial class StockReceiptController
{
    private IActionResult InvalidReceipt(string detail) =>
        BadRequest(new { message = "บันทึกใบรับสินค้าไม่ได้", description = detail });

    // Serialize reservation of serials across drafts and confirmation within one Company.
    private async Task LockReceiptSerials(SqlConnection c, SqlTransaction tx, CancellationToken token)
    {
        await using var cmd = new SqlCommand("""
DECLARE @result int;
EXEC @result=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',
 @LockOwner='Transaction',@LockTimeout=10000;
IF @result<0 THROW 52711,'Receipt is busy. Retry the operation.',1;
""", c, tx);
        Add(cmd, "@resource", SqlDbType.NVarChar, $"LAOO:receipt-serials:{CompanyId()}", 255);
        await cmd.ExecuteNonQueryAsync(token);
    }

    private async Task<IActionResult> SaveIntegrated(long? id, StockReceiptUpsertRequest request, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Can(c, id.HasValue ? "EDIT" : "CREATE", token))
            return StatusCode(403, new { message = "ไม่มีสิทธิ์บันทึกใบรับสินค้า", description = "กรุณาติดต่อผู้ดูแลสิทธิ์ของบริษัท" });
        var type = request.ReceiptType?.Trim().ToUpperInvariant();
        if (type is not ("RECEIPT" or "OPENING") || request.Items is null || request.Items.Count is < 1 or > 500)
            return InvalidReceipt("กรุณาระบุประเภทและรายการสินค้า 1–500 รายการ");
        if (request.ReceiptDate == default || request.ReferenceNo?.Length > 100 ||
            request.Remark?.Length > 1000 || request.DeliveredBy?.Length > 200)
            return InvalidReceipt("กรุณาตรวจวันที่รับ ความยาวเลขอ้างอิง (100) ผู้ส่งมอบ (200) และหมายเหตุ (1000)");
        if (type == "RECEIPT" && request.VendorID is not > 0)
            return InvalidReceipt("กรุณาเลือกผู้ขายสำหรับการรับสินค้า");

        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            await LockReceiptSerials(c, tx, token);
            if (!await WarehouseAccessService.CanAccessAsync(c, tx, CompanyId(), UserId(), request.WarehouseID, token))
                return StatusCode(403, new { message = "ไม่มีสิทธิ์เข้าถึงคลัง", description = "กรุณาเลือกคลังที่ได้รับสิทธิ์และเปิดใช้งาน" });
            // Check the old warehouse too; an inaccessible document cannot be moved into an accessible one.
            if (id.HasValue)
            {
                var oldWarehouse = await ScalarLong(c, tx,
                    "SELECT WarehouseID FROM dbo.TDIVStockReceipt WITH(UPDLOCK,HOLDLOCK) WHERE StockReceiptID=@id AND CompanyID=@company AND StatusCode=N'DRAFT' AND IsActive=1", id.Value, token);
                if (!oldWarehouse.HasValue) return InvalidReceipt("แก้ไขได้เฉพาะเอกสารร่างของบริษัทนี้");
                if (!await WarehouseAccessService.CanAccessAsync(c, tx, CompanyId(), UserId(), oldWarehouse.Value, token))
                    return StatusCode(403, new { message = "ไม่มีสิทธิ์เข้าถึงคลัง", description = "ไม่สามารถแก้ไขเอกสารจากคลังเดิมที่ไม่ได้รับสิทธิ์" });
            }

            string? vendorCode = null, vendorName = null;
            if (request.VendorID.HasValue)
            {
                await using var vendor = new SqlCommand(
                    "SELECT VendorCode,VendorName FROM dbo.TDAPVendor WITH(HOLDLOCK) WHERE VendorID=@vendor AND CompanyID=@company AND IsActive=1", c, tx);
                Add(vendor, "@vendor", SqlDbType.BigInt, request.VendorID);
                Add(vendor, "@company", SqlDbType.BigInt, CompanyId());
                await using var vr = await vendor.ExecuteReaderAsync(token);
                if (!await vr.ReadAsync(token)) return InvalidReceipt("ผู้ขายไม่เปิดใช้งานหรือไม่ได้อยู่ในบริษัทนี้ กรุณาเลือกใหม่");
                vendorCode = vr.GetString(0); vendorName = vr.GetString(1);
            }

            var prepared = new List<(StockReceiptLineRequest Line, string Source, string[] Serials)>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var totalSerials = 0;
            foreach (var line in request.Items)
            {
                if (line is null || line.Quantity <= 0 || line.Quantity > 99999999999999m ||
                    line.UnitCost < 0 || line.UnitCost > 99999999999999m ||
                    decimal.Round(line.Quantity, 4) != line.Quantity || decimal.Round(line.UnitCost, 4) != line.UnitCost ||
                    line.Remark?.Length > 500)
                    return InvalidReceipt($"รายการที่ {prepared.Count + 1}: จำนวนต้องมากกว่า 0 ต้นทุนไม่ติดลบ และทศนิยมไม่เกิน 4 ตำแหน่ง");
                var tracking = await ItemTracking(c, tx, line.ItemID, token);
                if (string.IsNullOrEmpty(tracking)) return InvalidReceipt("กรุณาเลือกสินค้าที่ควบคุมสต๊อกและเปิดใช้งาน");
                var source = line.SerialSourceCode?.Trim().ToUpperInvariant() ?? "FACTORY";
                if (source is not ("FACTORY" or "INTERNAL")) return InvalidReceipt("รูปแบบ Serial ต้องเป็นโรงงานหรือสร้างเลขภายใน");
                var serials = (line.Serials ?? []).Select(x => x?.SerialNo?.Trim() ?? "").ToArray();
                if (tracking == "SERIAL")
                {
                    if (line.Quantity != decimal.Truncate(line.Quantity) || line.Quantity > 2000 || (totalSerials += (int)line.Quantity) > 2000)
                        return InvalidReceipt("สินค้าควบคุม Serial ต้องเป็นจำนวนเต็ม รวมไม่เกิน 2,000 ชิ้นต่อเอกสาร");
                    if (source == "INTERNAL" && serials.Length == 0)
                        serials = Enumerable.Range(0, (int)line.Quantity).Select(_ => "IS" + Guid.NewGuid().ToString("N").ToUpperInvariant()).ToArray();
                    else if (source == "INTERNAL")
                    {
                        // Re-saving must preserve only numbers previously issued by this document.
                        foreach (var serial in serials)
                        {
                            await using var issued = new SqlCommand("""
SELECT COUNT(*) FROM dbo.TDIVStockReceiptSerial S
JOIN dbo.TDIVStockReceiptDetail D ON D.StockReceiptDetailID=S.StockReceiptDetailID
JOIN dbo.TDIVStockReceipt R ON R.StockReceiptID=D.StockReceiptID
WHERE R.CompanyID=@company AND R.StockReceiptID=@id AND D.ItemID=@item
 AND D.SerialSourceCode='INTERNAL' AND S.SerialNo=@serial
""", c, tx);
                            Add(issued, "@company", SqlDbType.BigInt, CompanyId());
                            Add(issued, "@id", SqlDbType.BigInt, id ?? 0);
                            Add(issued, "@item", SqlDbType.BigInt, line.ItemID);
                            Add(issued, "@serial", SqlDbType.NVarChar, serial, 200);
                            if (Convert.ToInt32(await issued.ExecuteScalarAsync(token)) != 1)
                                return InvalidReceipt("เลข Serial ภายในต้องให้ระบบสร้าง หรือใช้เลขเดิมจากเอกสารนี้");
                        }
                    }
                    if (serials.Length != (int)line.Quantity || serials.Any(x => x.Length is < 1 or > 200))
                        return InvalidReceipt($"รายการที่ {prepared.Count + 1}: ระบุ Serial ให้ครบ {line.Quantity:0} ชิ้น ความยาว 1–200 ตัวอักษร");
                }
                else if (serials.Length > 0 || source == "INTERNAL")
                    return InvalidReceipt("สินค้าที่ไม่ควบคุม Serial ไม่สามารถระบุหรือสร้าง Serial ได้");
                foreach (var serial in serials)
                {
                    if (!seen.Add(serial)) return InvalidReceipt("Serial ซ้ำภายในเอกสาร กรุณาตรวจรายการ");
                    await using var duplicate = new SqlCommand("""
SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDIVItemInstance WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND SerialNo=@serial)
 OR EXISTS(SELECT 1 FROM dbo.TDIVStockReceiptSerial S
 JOIN dbo.TDIVStockReceiptDetail D ON D.StockReceiptDetailID=S.StockReceiptDetailID
 JOIN dbo.TDIVStockReceipt R ON R.StockReceiptID=D.StockReceiptID
 WHERE R.CompanyID=@company AND R.StockReceiptID<>@id AND R.IsActive=1
 AND R.StatusCode IN(N'DRAFT',N'CONFIRMED') AND S.SerialNo=@serial)
 THEN 1 ELSE 0 END
""", c, tx);
                    Add(duplicate, "@company", SqlDbType.BigInt, CompanyId());
                    Add(duplicate, "@id", SqlDbType.BigInt, id ?? 0);
                    Add(duplicate, "@serial", SqlDbType.NVarChar, serial, 200);
                    if (Convert.ToInt32(await duplicate.ExecuteScalarAsync(token)) != 0)
                        return InvalidReceipt($"Serial {serial} มีแล้วหรือถูกจองในใบรับอื่นของบริษัท");
                }
                prepared.Add((line, source, serials));
            }

            var code = id.HasValue ? null : await NextCode(c, tx, token);
            var sql = id.HasValue ? """
UPDATE dbo.TDIVStockReceipt SET WarehouseID=@warehouse,ReceiptDate=@date,ReceiptType=@type,
 ReferenceNo=@reference,Remark=@remark,VendorID=@vendor,VendorCode=@vendorCode,VendorName=@vendorName,
 DeliveredBy=@delivered,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user
OUTPUT INSERTED.StockReceiptID,INSERTED.ReceiptCode
WHERE StockReceiptID=@id AND CompanyID=@company
""" : """
INSERT dbo.TDIVStockReceipt(CompanyID,WarehouseID,ReceiptCode,ReceiptDate,ReceiptType,StatusCode,
 ReferenceNo,Remark,VendorID,VendorCode,VendorName,DeliveredBy,CreatedBy)
OUTPUT INSERTED.StockReceiptID,INSERTED.ReceiptCode
VALUES(@company,@warehouse,@code,@date,@type,N'DRAFT',@reference,@remark,@vendor,@vendorCode,@vendorName,@delivered,@user)
""";
            await using var header = new SqlCommand(sql, c, tx);
            BindHeader(header, request, type!);
            Add(header, "@id", SqlDbType.BigInt, id);
            Add(header, "@code", SqlDbType.NVarChar, code, 30);
            Add(header, "@vendor", SqlDbType.BigInt, request.VendorID);
            Add(header, "@vendorCode", SqlDbType.NVarChar, vendorCode, 50);
            Add(header, "@vendorName", SqlDbType.NVarChar, vendorName, 200);
            Add(header, "@delivered", SqlDbType.NVarChar, request.DeliveredBy?.Trim(), 200);
            long receiptId;
            await using (var r = await header.ExecuteReaderAsync(token))
            {
                await r.ReadAsync(token); receiptId = r.GetInt64(0); code = r.GetString(1);
            }
            if (id.HasValue)
            {
                await using var clear = new SqlCommand("DELETE FROM dbo.TDIVStockReceiptDetail WHERE StockReceiptID=@id", c, tx);
                Add(clear, "@id", SqlDbType.BigInt, receiptId); await clear.ExecuteNonQueryAsync(token);
            }
            var saved = new List<object>();
            var lineNo = 0;
            foreach (var p in prepared)
            {
                await using var detail = new SqlCommand("""
INSERT dbo.TDIVStockReceiptDetail(StockReceiptID,[LineNo],ItemID,Quantity,UnitCost,Remark,SerialSourceCode)
OUTPUT INSERTED.StockReceiptDetailID VALUES(@receipt,@line,@item,@qty,@cost,@remark,@source)
""", c, tx);
                Add(detail, "@receipt", SqlDbType.BigInt, receiptId);
                Add(detail, "@line", SqlDbType.Int, ++lineNo);
                Add(detail, "@item", SqlDbType.BigInt, p.Line.ItemID);
                Add(detail, "@qty", SqlDbType.Decimal, p.Line.Quantity);
                Add(detail, "@cost", SqlDbType.Decimal, p.Line.UnitCost);
                Add(detail, "@remark", SqlDbType.NVarChar, p.Line.Remark?.Trim(), 500);
                Add(detail, "@source", SqlDbType.VarChar, p.Source, 20);
                var detailId = Convert.ToInt64(await detail.ExecuteScalarAsync(token));
                foreach (var serial in p.Serials)
                {
                    await using var insert = new SqlCommand("INSERT dbo.TDIVStockReceiptSerial(StockReceiptDetailID,SerialNo) VALUES(@detail,@serial)", c, tx);
                    Add(insert, "@detail", SqlDbType.BigInt, detailId);
                    Add(insert, "@serial", SqlDbType.NVarChar, serial, 200);
                    await insert.ExecuteNonQueryAsync(token);
                }
                saved.Add(new { lineNo, itemID = p.Line.ItemID, serialSourceCode = p.Source, serials = p.Serials });
            }
            await tx.CommitAsync(token);
            return Ok(new { stockReceiptID = receiptId, receiptCode = code, statusCode = "DRAFT", items = saved });
        }
        catch (SqlException ex)
        {
            logger?.LogError(ex, "Receipt save failed for Company {CompanyID}, document {ReceiptID}", CompanyId(), id);
            await tx.RollbackAsync(CancellationToken.None);
            return InvalidReceipt(ex.Number is 2601 or 2627
                ? "เลขเอกสารหรือ Serial ซ้ำ กรุณาตรวจข้อมูลและลองใหม่"
                : "ไม่สามารถบันทึกข้อมูลได้ กรุณาลองใหม่ หากยังไม่สำเร็จให้ติดต่อผู้ดูแลระบบ");
        }
    }
}
