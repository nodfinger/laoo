using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/service/request-qr-portals")]
public sealed class ServiceRequestQrPortalController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "15002";
    private long CompanyId => ClaimLong("company_id");
    private long UserId => ClaimLong("user_id");
    private long PartnerId => ClaimLong("partner_id");

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await ServiceEnabled(c, token)) return Forbid();
        return Ok(new { view = await Allowed(c, "VIEW", token), create = await Allowed(c, "CREATE", token), edit = await Allowed(c, "EDIT", token) });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? status, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken token = default)
    {
        await using var c = await Open(token);
        if (!await ServiceEnabled(c, token) || !await Allowed(c, "VIEW", token)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        const string sql = """
SELECT COUNT_BIG(1) OVER(),Q.ServiceRequestQrPortalID,Q.QrToken,Q.IsActive,Q.CreateDate,
       X.ItemInstanceID,X.SerialNo,I.ItemID,I.ItemCode,I.ItemName,
       CONCAT_WS(N' / ',NULLIF(B.BuildingNameTH,N''),NULLIF(F.FloorNameTH,N''),NULLIF(R.RoomCode,N'')) LocationSnapshot
FROM dbo.TDADServiceRequestQrPortal Q
JOIN dbo.TDIVItemInstance X ON X.ItemInstanceID=Q.ItemInstanceID AND X.CompanyID=Q.CompanyID
JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID
LEFT JOIN dbo.TDADBuilding B ON B.BuildingID=X.BuildingID AND B.CompanyID=X.CompanyID
LEFT JOIN dbo.TDADFloor F ON F.FloorID=X.FloorID AND F.BuildingID=X.BuildingID
LEFT JOIN dbo.TDADRoom R ON R.RoomID=X.RoomID AND R.CompanyID=X.CompanyID
WHERE Q.CompanyID=@company
  AND (@status=N'' OR (@status=N'ACTIVE' AND Q.IsActive=1) OR (@status=N'INACTIVE' AND Q.IsActive=0))
  AND (@q=N'' OR Q.QrToken LIKE N'%'+@q+N'%' OR X.SerialNo LIKE N'%'+@q+N'%' OR I.ItemCode LIKE N'%'+@q+N'%' OR I.ItemName LIKE N'%'+@q+N'%')
ORDER BY Q.IsActive DESC,Q.UpdateDate DESC,Q.ServiceRequestQrPortalID DESC
OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY;
""";
        await using var q = new SqlCommand(sql, c);
        Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@status", SqlDbType.NVarChar, status?.Trim().ToUpperInvariant() ?? string.Empty, 10);
        Add(q, "@q", SqlDbType.NVarChar, search?.Trim() ?? string.Empty, 200); Add(q, "@offset", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@take", SqlDbType.Int, pageSize);
        var items = new List<object>(); long total = 0;
        await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token))
        {
            total = r.GetInt64(0);
            items.Add(new { qrPortalId = r.GetInt64(1), qrToken = r.GetString(2), isActive = r.GetBoolean(3), createDate = r.GetDateTime(4), itemInstanceId = r.GetInt64(5), serialNo = r.GetString(6), itemId = r.GetInt64(7), itemCode = r.GetString(8), itemName = r.GetString(9), locationSnapshot = Text(r, 10) });
        }
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup([FromQuery] string? search, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await ServiceEnabled(c, token) || !await Allowed(c, "CREATE", token)) return Forbid();
        const string sql = """
SELECT TOP(100) X.ItemInstanceID,X.SerialNo,I.ItemID,I.ItemCode,I.ItemName,
       CONCAT_WS(N' / ',NULLIF(B.BuildingNameTH,N''),NULLIF(F.FloorNameTH,N''),NULLIF(R.RoomCode,N'')) LocationSnapshot
FROM dbo.TDIVItemInstance X
JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID AND I.IsActive=1
JOIN dbo.TDIVItemUsage U ON U.ItemID=I.ItemID AND U.CompanyID=I.CompanyID AND U.UsageCode=N'EQUIPMENT'
JOIN dbo.TDADBuilding B ON B.BuildingID=X.BuildingID AND B.CompanyID=X.CompanyID AND B.IsActive=1
JOIN dbo.TDADFloor F ON F.FloorID=X.FloorID AND F.BuildingID=X.BuildingID AND F.IsActive=1
JOIN dbo.TDADRoom R ON R.RoomID=X.RoomID AND R.CompanyID=X.CompanyID AND R.IsActive=1
WHERE X.CompanyID=@company AND X.StatusCode IN(N'INSTALLED',N'REPAIR')
  AND (@q=N'' OR X.SerialNo LIKE N'%'+@q+N'%' OR I.ItemCode LIKE N'%'+@q+N'%' OR I.ItemName LIKE N'%'+@q+N'%')
ORDER BY I.ItemCode,X.SerialNo;
""";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@q", SqlDbType.NVarChar, search?.Trim() ?? string.Empty, 200);
        var items = new List<object>(); await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) items.Add(new { itemInstanceId = r.GetInt64(0), serialNo = r.GetString(1), itemId = r.GetInt64(2), itemCode = r.GetString(3), itemName = r.GetString(4), locationSnapshot = Text(r, 5) });
        return Ok(new { items });
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateRequest request, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await ServiceEnabled(c, token) || !await Allowed(c, "CREATE", token)) return Forbid();
        if (!request.ItemInstanceId.HasValue) return BadRequest(new { message = "กรุณาเลือกอุปกรณ์", description = "QR แจ้งซ่อมต้องผูกกับ Asset/Serial ที่ติดตั้งพร้อมสถานที่" });
        if (!await ValidInstance(c, request.ItemInstanceId.Value, token)) return BadRequest(new { message = "อุปกรณ์ไม่ถูกต้อง", description = "เลือกได้เฉพาะอุปกรณ์ Service ที่ติดตั้งและมีอาคาร ชั้น ห้องครบ" });
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            var id = await ExistingPortalId(c, tx, request.ItemInstanceId.Value, token);
            var qrToken = NewToken();
            if (id.HasValue)
            {
                await using var update = new SqlCommand("UPDATE dbo.TDADServiceRequestQrPortal SET QrToken=@token,IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND ServiceRequestQrPortalID=@id", c, tx);
                Add(update, "@token", SqlDbType.NVarChar, qrToken, 100); Add(update, "@user", SqlDbType.BigInt, UserId); Add(update, "@company", SqlDbType.BigInt, CompanyId); Add(update, "@id", SqlDbType.BigInt, id.Value); await update.ExecuteNonQueryAsync(token);
            }
            else
            {
                await using var insert = new SqlCommand("INSERT dbo.TDADServiceRequestQrPortal(CompanyID,ItemInstanceID,QrToken,CreateBy) OUTPUT INSERTED.ServiceRequestQrPortalID VALUES(@company,@instance,@token,@user)", c, tx);
                Add(insert, "@company", SqlDbType.BigInt, CompanyId); Add(insert, "@instance", SqlDbType.BigInt, request.ItemInstanceId.Value); Add(insert, "@token", SqlDbType.NVarChar, qrToken, 100); Add(insert, "@user", SqlDbType.BigInt, UserId); id = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            }
            await tx.CommitAsync(token);
            return Ok(new { qrPortalId = id, qrToken });
        }
        catch { await tx.RollbackAsync(token); throw; }
    }

    [HttpPut("{id:long}/active")]
    public async Task<IActionResult> SetActive(long id, ActiveRequest request, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await ServiceEnabled(c, token) || !await Allowed(c, "EDIT", token)) return Forbid();
        await using var q = new SqlCommand("UPDATE dbo.TDADServiceRequestQrPortal SET IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND ServiceRequestQrPortalID=@id", c);
        Add(q, "@active", SqlDbType.Bit, request.IsActive); Add(q, "@user", SqlDbType.BigInt, UserId); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id);
        return await q.ExecuteNonQueryAsync(token) == 0 ? NotFound() : Ok(new { saved = true });
    }

    [HttpGet("scan/{tokenValue}")]
    public async Task<IActionResult> Scan(string tokenValue, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await ServiceEnabled(c, token) || !await CanCreateRequest(c, token)) return Forbid();
        const string sql = """
SELECT Q.QrToken,X.ItemID,I.ItemCode,I.ItemName,X.ItemInstanceID,X.SerialNo,
       CONCAT_WS(N' / ',NULLIF(B.BuildingNameTH,N''),NULLIF(F.FloorNameTH,N''),NULLIF(R.RoomCode,N'')) LocationSnapshot
FROM dbo.TDADServiceRequestQrPortal Q
JOIN dbo.TDIVItemInstance X ON X.ItemInstanceID=Q.ItemInstanceID AND X.CompanyID=Q.CompanyID AND X.StatusCode IN(N'INSTALLED',N'REPAIR')
JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID AND I.IsActive=1
JOIN dbo.TDIVItemUsage U ON U.ItemID=I.ItemID AND U.CompanyID=I.CompanyID AND U.UsageCode=N'EQUIPMENT'
JOIN dbo.TDADBuilding B ON B.BuildingID=X.BuildingID AND B.CompanyID=X.CompanyID AND B.IsActive=1
JOIN dbo.TDADFloor F ON F.FloorID=X.FloorID AND F.BuildingID=X.BuildingID AND F.IsActive=1
JOIN dbo.TDADRoom R ON R.RoomID=X.RoomID AND R.CompanyID=X.CompanyID AND R.IsActive=1
WHERE Q.CompanyID=@company AND Q.QrToken=@token AND Q.IsActive=1;
""";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@token", SqlDbType.NVarChar, tokenValue.Trim(), 100);
        await using var r = await q.ExecuteReaderAsync(token); if (!await r.ReadAsync(token)) return NotFound(new { message = "ไม่พบ QR Code ที่ใช้งานได้", description = "QR นี้อาจถูกปิดใช้งานหรือไม่อยู่ใน Company ปัจจุบัน" });
        return Ok(new { qrToken = r.GetString(0), itemId = r.GetInt64(1), itemCode = r.GetString(2), itemName = r.GetString(3), itemInstanceId = r.GetInt64(4), serialNo = r.GetString(5), locationSnapshot = Text(r, 6) });
    }

    private async Task<bool> ServiceEnabled(SqlConnection c, CancellationToken token)
    {
        const string sql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDSTCompanySetUp C JOIN dbo.TDADProject P ON P.ProjectCode=N'LAOO_SERVICE' AND P.IsActive=1 JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=P.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1 WHERE C.CompanyID=@company AND C.PartnerID=@partner AND C.IsActive=1 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME())) AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))) THEN 1 ELSE 0 END";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@partner", SqlDbType.BigInt, PartnerId); return Convert.ToBoolean(await q.ExecuteScalarAsync(token));
    }
    private Task<bool> Allowed(SqlConnection c, string action, CancellationToken token) => CompanyProjectPermission.IsAllowedAsync(c, User, ScreenCode, action, token);
    private async Task<bool> CanCreateRequest(SqlConnection c, CancellationToken token) => await CompanyProjectPermission.IsAllowedAsync(c, User, "15001", "CREATE", token) || await CompanyProjectPermission.IsAllowedAsync(c, User, "20001", "CREATE", token);
    private async Task<bool> ValidInstance(SqlConnection c, long id, CancellationToken token)
    {
        const string sql = "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDIVItemInstance X JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID AND I.IsActive=1 JOIN dbo.TDIVItemUsage U ON U.ItemID=I.ItemID AND U.CompanyID=I.CompanyID AND U.UsageCode=N'EQUIPMENT' JOIN dbo.TDADBuilding B ON B.BuildingID=X.BuildingID AND B.CompanyID=X.CompanyID AND B.IsActive=1 JOIN dbo.TDADFloor F ON F.FloorID=X.FloorID AND F.BuildingID=X.BuildingID AND F.IsActive=1 JOIN dbo.TDADRoom R ON R.RoomID=X.RoomID AND R.CompanyID=X.CompanyID AND R.IsActive=1 WHERE X.CompanyID=@company AND X.ItemInstanceID=@id AND X.StatusCode IN(N'INSTALLED',N'REPAIR')) THEN 1 ELSE 0 END";
        await using var q = new SqlCommand(sql, c); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@id", SqlDbType.BigInt, id); return Convert.ToBoolean(await q.ExecuteScalarAsync(token));
    }
    private async Task<long?> ExistingPortalId(SqlConnection c, SqlTransaction tx, long instanceId, CancellationToken token) { await using var q = new SqlCommand("SELECT ServiceRequestQrPortalID FROM dbo.TDADServiceRequestQrPortal WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND ItemInstanceID=@instance", c, tx); Add(q, "@company", SqlDbType.BigInt, CompanyId); Add(q, "@instance", SqlDbType.BigInt, instanceId); var value = await q.ExecuteScalarAsync(token); return value is null ? null : Convert.ToInt64(value); }
    private static string NewToken() => Convert.ToHexString(RandomNumberGenerator.GetBytes(20)).ToLowerInvariant();
    private Task<SqlConnection> Open(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); return OpenAsync(c, token); }
    private static async Task<SqlConnection> OpenAsync(SqlConnection c, CancellationToken token) { await c.OpenAsync(token); return c; }
    private long ClaimLong(string name) => long.TryParse(User.FindFirstValue(name), out var value) ? value : 0;
    private static string? Text(SqlDataReader r, int index) => r.IsDBNull(index) ? null : r.GetString(index);
    private static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0) { var p = size == 0 ? command.Parameters.Add(name, type) : command.Parameters.Add(name, type, size); p.Value = value ?? DBNull.Value; }
    public sealed record CreateRequest(long? ItemInstanceId);
    public sealed record ActiveRequest(bool IsActive);
}
