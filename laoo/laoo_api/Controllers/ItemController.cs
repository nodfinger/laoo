using System.Data;
using System.Globalization;
using System.Security.Claims;
using LaooApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize]
[Route("api/company/items")]
public sealed class ItemController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private const string ScreenCode = "08001";
    private readonly IConfiguration _configuration = configuration;
    private readonly IWebHostEnvironment _environment = environment;

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        var result = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
        foreach (var action in new[] { "VIEW", "CREATE", "EDIT", "DELETE" })
            result[action.ToLowerInvariant()] = await CanAsync(c, action, token);
        return Ok(result);
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ItemListRow>>> List(
        [FromQuery] string? groupCode, [FromQuery] string? typeCode,
        [FromQuery] string? search, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        await EnsureImageStorageSchemaAsync(c, token);
        if (!await CanAsync(c, "VIEW", token)) return Forbid();
        const string sql = """
SELECT I.ItemID,I.ItemCode,I.ItemName,I.ItemGroupCode,I.ItemTypeCode,I.UnitPrice,
       COALESCE(CONVERT(nvarchar(200), U.Name), CONVERT(nvarchar(200), I.UnitCode)) AS UnitCode,
       I.StockBalance,I.MinStock,I.PurchaseQuantity,I.OrderCode,I.OrderLink1,I.OrderLink2,I.IsActive,I.ShowShop,
       (SELECT TOP 1 ItemImageID FROM dbo.TDIVItemImage X WHERE X.ItemID=I.ItemID AND X.IsCover=1 AND X.IsActive=1) AS CoverImageID
FROM dbo.TDIVItem I
LEFT JOIN dbo.TDSTMaster U
  ON U.MasterGroupCode=@unitGroupCode
 AND U.MasterCode=I.UnitCode
 AND U.OwnerType=N'C'
 AND U.OwnerCompanyID=I.CompanyID
WHERE I.CompanyID=@company
  AND (@group='' OR I.ItemGroupCode=@group)
  AND (@type='' OR I.ItemTypeCode=@type)
  AND (@search='' OR I.ItemCode LIKE @like OR I.ItemName LIKE @like)
ORDER BY I.ItemCode;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
        Add(cmd, "@unitGroupCode", SqlDbType.NVarChar, MasterConstCodes.cmsUnit, 10);
        Add(cmd, "@group", SqlDbType.NVarChar, groupCode?.Trim() ?? string.Empty, 50);
        Add(cmd, "@type", SqlDbType.NVarChar, typeCode?.Trim() ?? string.Empty, 50);
        var q = search?.Trim() ?? string.Empty;
        Add(cmd, "@search", SqlDbType.NVarChar, q, 200);
        Add(cmd, "@like", SqlDbType.NVarChar, $"%{q}%", 210);
        var rows = new List<ItemListRow>();
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
            rows.Add(new ItemListRow(r.GetInt64(0), r.GetString(1), r.GetString(2), TextValue(r, 3) ?? string.Empty, TextValue(r, 4) ?? string.Empty, r.GetDecimal(5), TextValue(r, 6) ?? string.Empty, r.GetDecimal(7), r.GetDecimal(8), r.GetDecimal(9), TextValue(r, 10), TextValue(r, 11), TextValue(r, 12), r.GetBoolean(13), r.GetBoolean(14), r.IsDBNull(15) ? null : r.GetInt64(15), null));
        await r.DisposeAsync();
        foreach (var index in Enumerable.Range(0, rows.Count))
            rows[index] = rows[index] with { CoverImageBase64 = await CoverImage(c, rows[index].ItemID, token) };
        return Ok(rows);
    }

    [HttpGet("{id:long}")]
    public async Task<ActionResult<ItemDetail>> Get(long id, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        await EnsureImageStorageSchemaAsync(c, token);
        if (!await CanAsync(c, "VIEW", token)) return Forbid();
        const string itemSql = "SELECT ItemID,ItemCode,ItemName,ItemGroupCode,ItemTypeCode,UnitPrice,UnitCode,CostPrice,StockBalance,MinStock,PurchaseQuantity,RemarkItem1,Note1,Note2,Note3,Note4,Note5,OrderCode,OrderLink1,OrderLink2,IsActive,ShowShop FROM dbo.TDIVItem WHERE ItemID=@id AND CompanyID=@company";
        await using var item = new SqlCommand(itemSql, c);
        Add(item, "@id", SqlDbType.BigInt, id); Add(item, "@company", SqlDbType.BigInt, CompanyID());
        await using var r = await item.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return NotFound();
        var values = new object[] { r.GetInt64(0), r.GetString(1), r.GetString(2), TextValue(r, 3) ?? string.Empty, TextValue(r, 4) ?? string.Empty, r.GetDecimal(5), TextValue(r, 6) ?? string.Empty, r.GetDecimal(7), r.GetDecimal(8), r.GetDecimal(9), r.GetDecimal(10), TextValue(r, 11), TextValue(r, 12), TextValue(r, 13), TextValue(r, 14), TextValue(r, 15), TextValue(r, 16), TextValue(r, 17), TextValue(r, 18), TextValue(r, 19), r.GetBoolean(20), r.GetBoolean(21) };
        await r.DisposeAsync();
        var detail = new ItemDetail((long)values[0], (string)values[1], (string)values[2], (string)values[3], (string)values[4], (decimal)values[5], (string)values[6], (decimal)values[7], (decimal)values[8], (decimal)values[9], (decimal)values[10], (string?)values[11], (string?)values[12], (string?)values[13], (string?)values[14], (string?)values[15], (string?)values[16], (string?)values[17], (string?)values[18], (string?)values[19], (bool)values[20], (bool)values[21], await PackUnits(c, id, token), await Images(c, id, token));
        return Ok(detail);
    }

    [HttpGet("{id:long}/pack-units")]
    public async Task<ActionResult<IReadOnlyList<ItemPackUnitRow>>> GetPackUnits(long id, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "VIEW", token)) return Forbid();
        await using var access = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDIVItem WHERE ItemID=@id AND CompanyID=@company) THEN 1 ELSE 0 END", c);
        Add(access, "@id", SqlDbType.BigInt, id); Add(access, "@company", SqlDbType.BigInt, CompanyID());
        if (Convert.ToInt32(await access.ExecuteScalarAsync(token)) != 1) return NotFound();
        return Ok(await PackUnits(c, id, token));
    }

    [HttpPut("{id:long}/pack-units")]
    public async Task<ActionResult<IReadOnlyList<ItemPackUnitRow>>> SavePackUnits(long id, ItemPackUnitsRequest request, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        await EnsurePackUnitDmlSessionOptionsAsync(c, token);
        if (!await CanAsync(c, "EDIT", token)) return Forbid();
        var items = request.Items ?? [];
        if (items.Count > 20) return BadRequest(new { message = "จำนวนอัตราส่วนการบรรจุเกินกำหนด" });
        if (items.Any(x => string.IsNullOrWhiteSpace(x.UnitCode) || x.ConversionQuantity <= 0 || x.BaseQuantity <= 0))
            return BadRequest(new { message = "กรุณากรอกข้อมูลอัตราส่วนการบรรจุให้ครบถ้วน" });
        if (items.Select(x => x.UnitCode.Trim()).Distinct(StringComparer.OrdinalIgnoreCase).Count() != items.Count)
            return BadRequest(new { message = "หน่วยบรรจุซ้ำกันในสินค้านี้" });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            await using var access = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDIVItem WHERE ItemID=@id AND CompanyID=@company) THEN 1 ELSE 0 END", c, tx);
            Add(access, "@id", SqlDbType.BigInt, id); Add(access, "@company", SqlDbType.BigInt, CompanyID());
            if (Convert.ToInt32(await access.ExecuteScalarAsync(token)) != 1) return NotFound();
            await using (var clear = new SqlCommand("DELETE FROM dbo.TDIVItemPackUnit WHERE ItemID=@id", c, tx)) { Add(clear, "@id", SqlDbType.BigInt, id); await clear.ExecuteNonQueryAsync(token); }
            foreach (var item in items)
            {
                const string sql = "INSERT dbo.TDIVItemPackUnit(ItemID,UnitCode,ParentUnitCode,ConversionQuantity,BaseQuantity,IsDefault,SortOrder) VALUES(@id,@unit,@parent,@conversion,@base,@default,@sort)";
                await using var command = new SqlCommand(sql, c, tx);
                Add(command, "@id", SqlDbType.BigInt, id); Add(command, "@unit", SqlDbType.NVarChar, item.UnitCode.Trim(), 50); Add(command, "@parent", SqlDbType.NVarChar, (object?)item.ParentUnitCode?.Trim() ?? DBNull.Value, 50); Add(command, "@conversion", SqlDbType.Decimal, item.ConversionQuantity); Add(command, "@base", SqlDbType.Decimal, item.BaseQuantity); Add(command, "@default", SqlDbType.Bit, item.IsDefault); Add(command, "@sort", SqlDbType.Int, item.SortOrder);
                await command.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);
            return Ok(await PackUnits(c, id, token));
        }
        catch (Exception ex)
        {
            try { await tx.RollbackAsync(token); } catch { }
            return StatusCode(500, new { message = "บันทึกอัตราส่วนการบรรจุไม่สำเร็จ", description = ex.Message });
        }
    }

    [HttpDelete("{id:long}/pack-units/{packUnitId:long}")]
    public async Task<IActionResult> DeletePackUnit(
        long id,
        long packUnitId,
        CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        await EnsurePackUnitDmlSessionOptionsAsync(c, token);
        if (!await CanAsync(c, "EDIT", token)) return Forbid();
        const string sql = """
DELETE P
FROM dbo.TDIVItemPackUnit P
WHERE P.ItemPackUnitID=@packUnitId
  AND P.ItemID=@id
  AND EXISTS (
      SELECT 1 FROM dbo.TDIVItem I
      WHERE I.ItemID=P.ItemID AND I.CompanyID=@company
  );
SELECT @@ROWCOUNT;
""";
        await using var command = new SqlCommand(sql, c);
        Add(command, "@packUnitId", SqlDbType.BigInt, packUnitId);
        Add(command, "@id", SqlDbType.BigInt, id);
        Add(command, "@company", SqlDbType.BigInt, CompanyID());
        var deleted = Convert.ToInt32(await command.ExecuteScalarAsync(token));
        return deleted == 0 ? NotFound() : NoContent();
    }

    [HttpPatch("{id:long}/visibility")]
    public async Task<IActionResult> UpdateVisibility(long id, ItemVisibilityRequest request, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "EDIT", token)) return Forbid();
        const string sql = "UPDATE dbo.TDIVItem SET IsActive=@active,ShowShop=@showShop,UpdateDate=SYSUTCDATETIME() WHERE ItemID=@id AND CompanyID=@company";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@active", SqlDbType.Bit, request.IsActive);
        Add(cmd, "@showShop", SqlDbType.Bit, request.ShowShop);
        Add(cmd, "@id", SqlDbType.BigInt, id);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
        if (await cmd.ExecuteNonQueryAsync(token) == 0) return NotFound();
        return NoContent();
    }

    [HttpPost]
    public async Task<ActionResult<ItemDetail>> Create(ItemUpsertRequest request, CancellationToken token) => await Save(null, request, token);

    [HttpPut("{id:long}")]
    public async Task<ActionResult<ItemDetail>> Update(long id, ItemUpsertRequest request, CancellationToken token) => await Save(id, request, token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token)
    {
        await using var c = await OpenAsync(token);
        if (!await CanAsync(c, "DELETE", token)) return Forbid();
        await using var cmd = new SqlCommand("DELETE FROM dbo.TDIVItem WHERE ItemID=@id AND CompanyID=@company", c);
        Add(cmd, "@id", SqlDbType.BigInt, id); Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
        if (await cmd.ExecuteNonQueryAsync(token) == 0) return NotFound();
        return NoContent();
    }

    private async Task<ActionResult<ItemDetail>> Save(long? id, ItemUpsertRequest request, CancellationToken token)
    {
        var action = id.HasValue ? "EDIT" : "CREATE";
        await using var c = await OpenAsync(token);
        await EnsureImageStorageSchemaAsync(c, token);
        await EnsurePackUnitDmlSessionOptionsAsync(c, token);
        if (!await CanAsync(c, action, token)) return Forbid();
        var code = request.ItemCode?.Trim() ?? string.Empty;
        var name = request.ItemName?.Trim() ?? string.Empty;
        if (code.Length == 0 || name.Length == 0) return BadRequest(new { message = "กรุณาระบุรหัสสินค้าและชื่อสินค้า" });
        if (request.Images is { Count: > 5 }) return BadRequest(new { message = "สินค้าเก็บรูปได้สูงสุด 5 รูป" });
        var savedImagePaths = new List<string>();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            long itemId;
            if (id is null)
            {
                const string sql = "INSERT dbo.TDIVItem(CompanyID,ItemGroupCode,ItemTypeCode,ItemCode,ItemName,UnitPrice,UnitCode,CostPrice,MinStock,PurchaseQuantity,RemarkItem1,Note1,Note2,Note3,Note4,Note5,OrderCode,OrderLink1,OrderLink2,IsActive,ShowShop) OUTPUT INSERTED.ItemID VALUES(@company,@group,@type,@code,@name,@price,@unit,@cost,@min,@purchase,@remark1,@note1,@note2,@note3,@note4,@note5,@order,@link1,@link2,@active,@showShop)";
                await using var cmd = new SqlCommand(sql, c, tx);
                Bind(cmd, request, code, name); itemId = (long)(await cmd.ExecuteScalarAsync(token))!;
            }
            else
            {
                const string sql = "UPDATE dbo.TDIVItem SET ItemGroupCode=@group,ItemTypeCode=@type,ItemCode=@code,ItemName=@name,UnitPrice=@price,UnitCode=@unit,CostPrice=@cost,MinStock=@min,PurchaseQuantity=@purchase,RemarkItem1=@remark1,Note1=@note1,Note2=@note2,Note3=@note3,Note4=@note4,Note5=@note5,OrderCode=@order,OrderLink1=@link1,OrderLink2=@link2,IsActive=@active,ShowShop=@showShop,UpdateDate=SYSUTCDATETIME() WHERE ItemID=@id AND CompanyID=@company";
                await using var cmd = new SqlCommand(sql, c, tx);
                // Bind already adds @company. Do not add it again to this command.
                Bind(cmd, request, code, name); Add(cmd, "@id", SqlDbType.BigInt, id.Value);
                if (await cmd.ExecuteNonQueryAsync(token) == 0) return NotFound();
                itemId = id.Value;
            }
            await using (var clearUnits = new SqlCommand("DELETE FROM dbo.TDIVItemPackUnit WHERE ItemID=@id", c, tx)) { Add(clearUnits, "@id", SqlDbType.BigInt, itemId); await clearUnits.ExecuteNonQueryAsync(token); }
            foreach (var u in request.PackUnits ?? [])
            {
                const string sql = "INSERT dbo.TDIVItemPackUnit(ItemID,UnitCode,ParentUnitCode,ConversionQuantity,BaseQuantity,IsDefault,SortOrder) VALUES(@id,@unit,@parent,@conversion,@base,@default,@sort)";
                await using var cmd = new SqlCommand(sql, c, tx); Add(cmd, "@id", SqlDbType.BigInt, itemId); Add(cmd, "@unit", SqlDbType.NVarChar, u.UnitCode.Trim(), 50); Add(cmd, "@parent", SqlDbType.NVarChar, (object?)u.ParentUnitCode?.Trim() ?? DBNull.Value, 50); Add(cmd, "@conversion", SqlDbType.Decimal, u.ConversionQuantity); Add(cmd, "@base", SqlDbType.Decimal, u.BaseQuantity); Add(cmd, "@default", SqlDbType.Bit, u.IsDefault); Add(cmd, "@sort", SqlDbType.Int, u.SortOrder); await cmd.ExecuteNonQueryAsync(token);
            }
            if (request.Images is not null)
            {
                await using var clearImages = new SqlCommand("DELETE FROM dbo.TDIVItemImage WHERE ItemID=@id", c, tx); Add(clearImages, "@id", SqlDbType.BigInt, itemId); await clearImages.ExecuteNonQueryAsync(token);
                foreach (var image in request.Images)
                {
                    byte[] bytes; try { bytes = Convert.FromBase64String(image.ImageDataBase64); } catch { return BadRequest(new { message = "รูปภาพไม่ถูกต้อง" }); }
                    if (bytes.Length > 1024 * 1024) return BadRequest(new { message = "รูปภาพต้องมีขนาดไม่เกิน 1 MB" });
                    var relativePath = await SaveImageFileAsync(CompanyID(), itemId, image, bytes, token);
                    savedImagePaths.Add(relativePath);
                    const string sql = "INSERT dbo.TDIVItemImage(ItemID,FilePath,ContentType,FileName,IsCover,SortOrder) VALUES(@id,@path,@type,@file,@cover,@sort)";
                    await using var cmd = new SqlCommand(sql, c, tx); Add(cmd, "@id", SqlDbType.BigInt, itemId); Add(cmd, "@path", SqlDbType.NVarChar, relativePath, 500); Add(cmd, "@type", SqlDbType.NVarChar, image.ContentType, 100); Add(cmd, "@file", SqlDbType.NVarChar, (object?)image.FileName ?? DBNull.Value, 250); Add(cmd, "@cover", SqlDbType.Bit, image.IsCover); Add(cmd, "@sort", SqlDbType.Int, image.SortOrder); await cmd.ExecuteNonQueryAsync(token);
                }
            }
            await tx.CommitAsync(token);
            CleanupUnusedImageFiles(CompanyID(), itemId, savedImagePaths);
            return await Get(itemId, token);
        }
        catch (SqlException ex)
        {
            try { await tx.RollbackAsync(token); } catch { }
            DeleteImageFiles(savedImagePaths);
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "บันทึกข้อมูลสินค้าไม่สำเร็จ",
                description = ex.Message,
                sqlNumber = ex.Number,
            });
        }
        catch (Exception ex)
        {
            try { await tx.RollbackAsync(token); } catch { }
            DeleteImageFiles(savedImagePaths);
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "บันทึกข้อมูลสินค้าไม่สำเร็จ",
                description = ex.Message,
            });
        }
    }

    private async Task<List<ItemPackUnitRow>> PackUnits(SqlConnection c, long id, CancellationToken token)
    {
        var list = new List<ItemPackUnitRow>();
        const string sql = """
SELECT P.ItemPackUnitID,P.UnitCode,P.ParentUnitCode,P.ConversionQuantity,P.BaseQuantity,P.IsDefault,P.SortOrder,
       U.Name AS UnitName, PU.Name AS ParentUnitName
FROM dbo.TDIVItemPackUnit P
LEFT JOIN dbo.TDSTMaster U
  ON U.MasterGroupCode=@unitGroupCode AND U.MasterCode=P.UnitCode
 AND U.OwnerType=N'C' AND U.OwnerCompanyID=@company
LEFT JOIN dbo.TDSTMaster PU
  ON PU.MasterGroupCode=@unitGroupCode AND PU.MasterCode=P.ParentUnitCode
 AND PU.OwnerType=N'C' AND PU.OwnerCompanyID=@company
WHERE P.ItemID=@id
ORDER BY P.SortOrder,P.UnitCode;
""";
        await using var cmd = new SqlCommand(sql, c);
        Add(cmd, "@id", SqlDbType.BigInt, id);
        Add(cmd, "@company", SqlDbType.BigInt, CompanyID());
        Add(cmd, "@unitGroupCode", SqlDbType.NVarChar, MasterConstCodes.cmsUnit, 10);
        await using var r = await cmd.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
            list.Add(new ItemPackUnitRow(
                r.GetInt64(0), TextValue(r, 1) ?? string.Empty, TextValue(r, 2),
                r.GetDecimal(3), r.GetDecimal(4), r.GetBoolean(5), r.GetInt32(6),
                TextValue(r, 7), TextValue(r, 8)));
        return list;
    }

    private async Task<List<ItemImageRow>> Images(SqlConnection c, long id, CancellationToken token)
    {
        var list = new List<ItemImageRow>(); const string sql = "SELECT ItemImageID,ContentType,FileName,IsCover,SortOrder,FilePath,ImageData FROM dbo.TDIVItemImage WHERE ItemID=@id AND IsActive=1 ORDER BY SortOrder";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@id", SqlDbType.BigInt, id); await using var r = await cmd.ExecuteReaderAsync(token); while (await r.ReadAsync(token)) list.Add(new ItemImageRow(r.GetInt64(0), TextValue(r, 1) ?? string.Empty, r.IsDBNull(2) ? null : r.GetString(2), r.GetBoolean(3), r.GetInt32(4), await ReadImageBase64Async(TextValue(r, 5), r.IsDBNull(6) ? null : (byte[])r[6], token))); return list;
    }

    private async Task<string?> CoverImage(SqlConnection c, long id, CancellationToken token)
    {
        await using var cmd = new SqlCommand("SELECT TOP 1 FilePath,ImageData FROM dbo.TDIVItemImage WHERE ItemID=@id AND IsCover=1 AND IsActive=1", c);
        Add(cmd, "@id", SqlDbType.BigInt, id);
        await using var r = await cmd.ExecuteReaderAsync(token);
        if (!await r.ReadAsync(token)) return null;
        return await ReadImageBase64Async(TextValue(r, 0), r.IsDBNull(1) ? null : (byte[])r[1], token);
    }

    private async Task<string> SaveImageFileAsync(long companyId, long itemId, ItemImageUpload image, byte[] bytes, CancellationToken token)
    {
        var folder = ItemImageFolder(companyId, itemId);
        Directory.CreateDirectory(folder);
        var extension = image.ContentType.Equals("image/png", StringComparison.OrdinalIgnoreCase) ? ".png" : ".jpg";
        var fileName = $"{Guid.NewGuid():N}{extension}";
        await System.IO.File.WriteAllBytesAsync(Path.Combine(folder, fileName), bytes, token);
        return Path.Combine("uploads", "items", companyId.ToString(CultureInfo.InvariantCulture), itemId.ToString(CultureInfo.InvariantCulture), fileName).Replace('\\', '/');
    }

    private string ItemImageFolder(long companyId, long itemId)
    {
        var root = _environment.WebRootPath;
        if (string.IsNullOrWhiteSpace(root)) root = Path.Combine(_environment.ContentRootPath, "wwwroot");
        return Path.Combine(root, "uploads", "items", companyId.ToString(CultureInfo.InvariantCulture), itemId.ToString(CultureInfo.InvariantCulture));
    }

    private async Task<string> ReadImageBase64Async(string? relativePath, byte[]? legacyBytes, CancellationToken token)
    {
        if (!string.IsNullOrWhiteSpace(relativePath))
        {
            var root = _environment.WebRootPath;
            if (string.IsNullOrWhiteSpace(root)) root = Path.Combine(_environment.ContentRootPath, "wwwroot");
            var fullPath = Path.GetFullPath(Path.Combine(root, relativePath.Replace('/', Path.DirectorySeparatorChar)));
            var rootPath = Path.GetFullPath(root) + Path.DirectorySeparatorChar;
            if (fullPath.StartsWith(rootPath, StringComparison.OrdinalIgnoreCase) && System.IO.File.Exists(fullPath))
                return Convert.ToBase64String(await System.IO.File.ReadAllBytesAsync(fullPath, token));
        }
        return legacyBytes is null ? string.Empty : Convert.ToBase64String(legacyBytes);
    }

    private void CleanupUnusedImageFiles(long companyId, long itemId, IReadOnlyCollection<string> savedPaths)
    {
        var folder = ItemImageFolder(companyId, itemId);
        if (!Directory.Exists(folder)) return;
        var root = _environment.WebRootPath;
        if (string.IsNullOrWhiteSpace(root)) root = Path.Combine(_environment.ContentRootPath, "wwwroot");
        var keep = savedPaths.Select(path => Path.GetFullPath(Path.Combine(root, path.Replace('/', Path.DirectorySeparatorChar)))).ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var file in Directory.EnumerateFiles(folder)) if (!keep.Contains(Path.GetFullPath(file))) try { System.IO.File.Delete(file); } catch { }
    }

    private void DeleteImageFiles(IEnumerable<string> paths)
    {
        var root = _environment.WebRootPath;
        if (string.IsNullOrWhiteSpace(root)) root = Path.Combine(_environment.ContentRootPath, "wwwroot");
        foreach (var path in paths) try { System.IO.File.Delete(Path.Combine(root, path.Replace('/', Path.DirectorySeparatorChar))); } catch { }
    }

    private async Task<bool> CanAsync(SqlConnection c, string action, CancellationToken token)
    {
        var user = long.TryParse(User.FindFirstValue("user_id"), out var id) ? id : 0; if (user <= 0) return false;
        const string sql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1) OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode=@action AND P.ScreenCode IN (@screen,N'COMPANY_PRODUCTS')) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END";
        await using var cmd = new SqlCommand(sql, c); Add(cmd, "@user", SqlDbType.BigInt, user); Add(cmd, "@company", SqlDbType.BigInt, CompanyID()); Add(cmd, "@project", SqlDbType.BigInt, ProjectID()); Add(cmd, "@action", SqlDbType.NVarChar, action, 30); Add(cmd, "@screen", SqlDbType.NVarChar, ScreenCode, 20); return (bool)(await cmd.ExecuteScalarAsync(token) ?? false);
    }

    private long CompanyID() => long.TryParse(User.FindFirstValue("company_id"), out var id) ? id : 0;
    private long ProjectID() => long.TryParse(User.FindFirstValue("project_id"), out var id) ? id : 0;
    private async Task<SqlConnection> OpenAsync(CancellationToken token) { var c = new SqlConnection(_configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private static async Task EnsureImageStorageSchemaAsync(SqlConnection c, CancellationToken token)
    {
        const string sql = "IF OBJECT_ID(N'dbo.TDIVItemImage',N'U') IS NOT NULL AND COL_LENGTH(N'dbo.TDIVItemImage',N'FilePath') IS NULL ALTER TABLE dbo.TDIVItemImage ADD FilePath NVARCHAR(500) NULL; IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.TDIVItemImage') AND name=N'ImageData' AND is_nullable=0) ALTER TABLE dbo.TDIVItemImage ALTER COLUMN ImageData VARBINARY(MAX) NULL;";
        await using var command = new SqlCommand(sql, c);
        await command.ExecuteNonQueryAsync(token);
    }
    private static async Task EnsurePackUnitDmlSessionOptionsAsync(SqlConnection c, CancellationToken token)
    {
        const string sql = "SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET QUOTED_IDENTIFIER ON; SET NUMERIC_ROUNDABORT OFF;";
        await using var command = new SqlCommand(sql, c);
        await command.ExecuteNonQueryAsync(token);
    }
    private static void Add(SqlCommand c, string name, SqlDbType type, object value, int size = 0) { var p = c.Parameters.Add(name, type); if (size > 0) p.Size = size; p.Value = value ?? DBNull.Value; }
    private static string? TextValue(SqlDataReader r, int ordinal) => r.IsDBNull(ordinal) ? null : Convert.ToString(r.GetValue(ordinal), CultureInfo.InvariantCulture);
    private void Bind(SqlCommand c, ItemUpsertRequest r, string code, string name) { Add(c, "@company", SqlDbType.BigInt, CompanyID()); Add(c, "@group", SqlDbType.NVarChar, r.ItemGroupCode.Trim(), 50); Add(c, "@type", SqlDbType.NVarChar, r.ItemTypeCode.Trim(), 50); Add(c, "@code", SqlDbType.NVarChar, code, 50); Add(c, "@name", SqlDbType.NVarChar, name, 200); Add(c, "@price", SqlDbType.Decimal, r.UnitPrice); Add(c, "@unit", SqlDbType.NVarChar, r.UnitCode.Trim(), 50); Add(c, "@cost", SqlDbType.Decimal, r.CostPrice); Add(c, "@min", SqlDbType.Decimal, r.MinStock); Add(c, "@purchase", SqlDbType.Decimal, r.PurchaseQuantity); Add(c, "@remark1", SqlDbType.NVarChar, (object?)r.RemarkItem1?.Trim() ?? DBNull.Value, 2000); Add(c, "@note1", SqlDbType.NVarChar, (object?)r.Note1?.Trim() ?? DBNull.Value, 1000); Add(c, "@note2", SqlDbType.NVarChar, (object?)r.Note2?.Trim() ?? DBNull.Value, 1000); Add(c, "@note3", SqlDbType.NVarChar, (object?)r.Note3?.Trim() ?? DBNull.Value, 1000); Add(c, "@note4", SqlDbType.NVarChar, (object?)r.Note4?.Trim() ?? DBNull.Value, 1000); Add(c, "@note5", SqlDbType.NVarChar, (object?)r.Note5?.Trim() ?? DBNull.Value, 1000); Add(c, "@order", SqlDbType.NVarChar, (object?)r.OrderCode?.Trim() ?? DBNull.Value, 400); Add(c, "@link1", SqlDbType.NVarChar, (object?)r.OrderLink1?.Trim() ?? DBNull.Value, 2000); Add(c, "@link2", SqlDbType.NVarChar, (object?)r.OrderLink2?.Trim() ?? DBNull.Value, 2000); Add(c, "@active", SqlDbType.Bit, r.IsActive); Add(c, "@showShop", SqlDbType.Bit, r.ShowShop); }
}
