using System.Data;
using Laoo.Shared.Contracts;
using LaooApi.Security;
using LaooApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/travel-claims")]
public sealed class TravelClaimController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");
    private Task<bool> Allowed(SqlConnection db, string action, CancellationToken token) => CompanyProjectPermission.IsAllowedAsync(db, User, "66001", action, token);

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || UserId <= 0 || !await Allowed(db, "VIEW", token)) return Forbid();
        var create = await Allowed(db, "CREATE", token); var edit = await Allowed(db, "EDIT", token); var delete = await Allowed(db, "DELETE", token);
        const string sql = """
SELECT Id,ClaimNo,ClaimDate,Origin,Destination,TotalAmount FROM dbo.TDSTTravelClaim WHERE CompanyID=@company AND UserID=@user ORDER BY Id DESC;
SELECT MasterCode,Name FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterGroupCode=N'009' ORDER BY Seq,Name;
SELECT Id,Origin,Destination,DistanceKm FROM dbo.TDSTTravelRoute WHERE CompanyID=@company ORDER BY Origin,Destination;
SELECT v.VehicleTypeCode,v.RatePerKm FROM dbo.TDSTTravelVehicleRate v WHERE v.CompanyID=@company;
SELECT r.RouteID,r.VehicleTypeCode,r.Amount FROM dbo.TDSTTravelRouteRate r WHERE r.CompanyID=@company AND r.RouteID IS NOT NULL;
SELECT CASE WHEN COUNT(DISTINCT l.Amount)=1 THEN MAX(l.Amount) END FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.EmployeeID=ue.EmployeeID AND e.CompanyID=ue.CompanyID AND e.IsActive=1
JOIN dbo.TDSTTravelPositionLevel p ON p.CompanyID=e.CompanyID AND p.PositionCode=e.PositionCode
JOIN dbo.TDSTTravelLodgingRate l ON l.CompanyID=p.CompanyID AND l.PositionLevelCode=p.PositionLevelCode
WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1;
""";
        await using var q = new SqlCommand(sql, db); q.Parameters.AddWithValue("@company", CompanyId); q.Parameters.AddWithValue("@user", UserId);
        await using var r = await q.ExecuteReaderAsync(token);
        var items = new List<object>(); while (await r.ReadAsync(token)) items.Add(new { id=r.GetInt64(0), number=r.GetString(1), date=r.GetDateTime(2).ToString("yyyy-MM-dd"), origin=r.GetString(3), destination=r.GetString(4), total=r.GetDecimal(5) });
        await r.NextResultAsync(token); var vehicles = new List<object>(); while(await r.ReadAsync(token)) vehicles.Add(new { code=r.GetString(0), name=r.GetString(1) });
        await r.NextResultAsync(token); var routes = new List<object>(); while(await r.ReadAsync(token)) routes.Add(new { id=r.GetInt64(0), origin=r.GetString(1), destination=r.GetString(2), distance=r.GetDecimal(3) });
        await r.NextResultAsync(token); var rates = new List<object>(); while(await r.ReadAsync(token)) rates.Add(new { code=r.GetString(0), rate=r.GetDecimal(1) });
        await r.NextResultAsync(token); var fares = new List<object>(); while(await r.ReadAsync(token)) fares.Add(new { routeId=r.GetInt64(0), code=r.GetString(1), amount=r.GetDecimal(2) });
        await r.NextResultAsync(token); decimal? lodging = await r.ReadAsync(token) && !r.IsDBNull(0) ? r.GetDecimal(0) : null;
        return Ok(new { items, vehicles, routes, rates, fares, lodging, create, edit, delete });
    }

    public sealed record ClaimAttachmentInput(string Name,string Base64);
    public sealed record ClaimInput(DateOnly ClaimDate, long? RouteId, string Origin, string Destination, string Purpose, string WorkPlace, string? MapUrl,
        decimal DistanceKm, DateOnly StartDate, DateOnly EndDate, string VehicleTypeCode, string VehicleRegistration, int Nights, decimal Toll, decimal Parking, decimal PublicTransport, bool IsInterbranch, List<ClaimAttachmentInput>? Attachments, Guid? RequestKey);

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Detail(long id, CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"VIEW",token)) return Forbid();
        const string sql="""
SELECT ClaimNo,ClaimDate,RouteID,Origin,Destination,Purpose,WorkPlace,MapUrl,DistanceKm,StartDate,EndDate,VehicleTypeCode,VehicleRegistration,Nights,Toll,Parking,PublicTransport,FuelAmount,LodgingAmount,TotalAmount,IsInterbranch,RatePerKm,FlatFare,LodgingRate
FROM dbo.TDSTTravelClaim WHERE Id=@id AND CompanyID=@company AND UserID=@user;
SELECT a.Id,a.FileName FROM dbo.TDSTTravelClaimAttachment a JOIN dbo.TDSTTravelClaim c ON c.Id=a.ClaimID AND c.CompanyID=a.CompanyID WHERE c.Id=@id AND c.CompanyID=@company AND c.UserID=@user ORDER BY a.Id;
""";
        await using var q=new SqlCommand(sql,db);q.Parameters.AddWithValue("@id",id);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
        await using var r=await q.ExecuteReaderAsync(token);if(!await r.ReadAsync(token)) return NotFound(new { message="ไม่พบเอกสารของคุณ" });
        var item=new { id,number=r.GetString(0),date=r.GetDateTime(1).ToString("yyyy-MM-dd"),routeId=r.IsDBNull(2)?(long?)null:r.GetInt64(2),origin=r.GetString(3),destination=r.GetString(4),purpose=r.GetString(5),workPlace=r.GetString(6),mapUrl=r.IsDBNull(7)?null:r.GetString(7),distance=r.GetDecimal(8),start=r.GetDateTime(9).ToString("yyyy-MM-dd"),end=r.GetDateTime(10).ToString("yyyy-MM-dd"),vehicle=r.GetString(11),registration=r.GetString(12),nights=r.GetInt32(13),toll=r.GetDecimal(14),parking=r.GetDecimal(15),transport=r.GetDecimal(16),fuel=r.GetDecimal(17),lodging=r.GetDecimal(18),total=r.GetDecimal(19),isInterbranch=r.GetBoolean(20),rate=r.IsDBNull(21)?(decimal?)null:r.GetDecimal(21),flat=r.IsDBNull(22)?(decimal?)null:r.GetDecimal(22),lodgingRate=r.GetDecimal(23) };
        await r.NextResultAsync(token);var attachments=new List<object>();while(await r.ReadAsync(token))attachments.Add(new {id=r.GetInt64(0),name=r.GetString(1)});
        return Ok(new {item,attachments});
    }

    [HttpPost("{id:long}/attachments")]
    [RequestSizeLimit(10_500_000)]
    public async Task<IActionResult> Upload(long id, IFormFile? file, CancellationToken token)
    {
        if(file is null || file.Length is <=0 or >10_000_000) return BadRequest(new {message="กรุณาเลือกไฟล์ขนาดไม่เกิน 10 MB"});
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"EDIT",token)) return Forbid();
        await using var data=new MemoryStream(); await file.CopyToAsync(data,token);var bytes=data.ToArray();
        var type=DetectContentType(bytes);
        if(type is null) return BadRequest(new {message="รองรับเฉพาะไฟล์ JPG, PNG, WEBP และ PDF"});
        var name=Path.GetFileName(file.FileName);if(string.IsNullOrWhiteSpace(name) || name.Length>255) return BadRequest(new {message="ชื่อไฟล์ไม่ถูกต้อง"});
        await using var q=new SqlCommand("""
INSERT dbo.TDSTTravelClaimAttachment(ClaimID,CompanyID,FileName,ContentType,FileData)
SELECT Id,CompanyID,@name,@type,@data FROM dbo.TDSTTravelClaim WHERE Id=@id AND CompanyID=@company AND UserID=@user;
SELECT @@ROWCOUNT;
""",db);
        q.Parameters.AddWithValue("@id",id);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);q.Parameters.AddWithValue("@name",name);q.Parameters.AddWithValue("@type",type);q.Parameters.Add("@data",SqlDbType.VarBinary,-1).Value=bytes;
        return Convert.ToInt32(await q.ExecuteScalarAsync(token))==0 ? NotFound(new {message="ไม่พบเอกสารของคุณ"}) : Ok(new {saved=true});
    }

    [HttpGet("{id:long}/attachments/{attachment:long}")]
    public async Task<IActionResult> Attachment(long id,long attachment,CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"VIEW",token)) return Forbid();
        await using var q=new SqlCommand("SELECT a.FileData,a.ContentType,a.FileName FROM dbo.TDSTTravelClaimAttachment a JOIN dbo.TDSTTravelClaim c ON c.Id=a.ClaimID AND c.CompanyID=a.CompanyID WHERE a.Id=@attachment AND c.Id=@id AND c.CompanyID=@company AND c.UserID=@user",db);
        q.Parameters.AddWithValue("@attachment",attachment);q.Parameters.AddWithValue("@id",id);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
        await using var r=await q.ExecuteReaderAsync(token);if(!await r.ReadAsync(token)) return NotFound();
        return File((byte[])r.GetValue(0),r.GetString(1),r.GetString(2));
    }

    [HttpDelete("{id:long}/attachments/{attachment:long}")]
    public async Task<IActionResult> DeleteAttachment(long id,long attachment,CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"EDIT",token)) return Forbid();
        await using var q=new SqlCommand("DELETE a FROM dbo.TDSTTravelClaimAttachment a JOIN dbo.TDSTTravelClaim c ON c.Id=a.ClaimID AND c.CompanyID=a.CompanyID WHERE a.Id=@attachment AND c.Id=@id AND c.CompanyID=@company AND c.UserID=@user",db);
        q.Parameters.AddWithValue("@attachment",attachment);q.Parameters.AddWithValue("@id",id);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
        return await q.ExecuteNonQueryAsync(token)==0 ? NotFound() : NoContent();
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,CancellationToken token)
    {
        await using var db=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || UserId<=0 || !await Allowed(db,"DELETE",token)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        await using var q=new SqlCommand("""
DELETE a FROM dbo.TDSTTravelClaimAttachment a JOIN dbo.TDSTTravelClaim c ON c.Id=a.ClaimID AND c.CompanyID=a.CompanyID WHERE c.Id=@id AND c.CompanyID=@company AND c.UserID=@user;
DELETE FROM dbo.TDSTTravelClaim WHERE Id=@id AND CompanyID=@company AND UserID=@user; SELECT @@ROWCOUNT;
""",db,tx);
        q.Parameters.AddWithValue("@id",id);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
        var count=Convert.ToInt32(await q.ExecuteScalarAsync(token));await tx.CommitAsync(token);
        return count==0 ? NotFound(new {message="ไม่พบเอกสารของคุณ"}) : Ok(new {deleted=true});
    }

    [HttpPost]
    [RequestSizeLimit(30_000_000)]
    public Task<IActionResult> Create(ClaimInput input, CancellationToken token) => Save(null, input, token);
    [HttpPut("{id:long}")]
    [RequestSizeLimit(30_000_000)]
    public Task<IActionResult> Update(long id, ClaimInput input, CancellationToken token) => Save(id, input, token);

    private async Task<IActionResult> Save(long? id, ClaimInput input, CancellationToken token)
    {
        if (input is null || string.IsNullOrWhiteSpace(input.Origin) || input.Origin.Length>200 || string.IsNullOrWhiteSpace(input.Destination) || input.Destination.Length>200 ||
            string.IsNullOrWhiteSpace(input.Purpose) || input.Purpose.Length>500 || string.IsNullOrWhiteSpace(input.WorkPlace) || input.WorkPlace.Length>500 ||
            input.MapUrl?.Length>1000 || string.IsNullOrWhiteSpace(input.VehicleTypeCode) || input.VehicleTypeCode.Length>10 || string.IsNullOrWhiteSpace(input.VehicleRegistration) || input.VehicleRegistration.Length>50 ||
            new[] {input.DistanceKm,input.Toll,input.Parking,input.PublicTransport}.Any(x => x<0 || x>9999999999.99m || decimal.Round(x,2)!=x) || input.Nights<0 || input.Nights>366 || input.ClaimDate.Year is <2000 or >2100 || input.StartDate.Year is <2000 or >2100 || input.EndDate.Year is <2000 or >2100 || input.EndDate.DayNumber-input.StartDate.DayNumber>366 || (input.Attachments?.Count ?? 0)>50 || (id is null && (input.RequestKey is null || input.RequestKey==Guid.Empty)))
            return BadRequest(new { message="กรุณาระบุข้อมูลการเดินทางให้ครบถ้วน" });
        var files=new List<(string Name,string Type,byte[] Data)>();
        try {
            long totalBytes=0;
            foreach(var file in input.Attachments??[]) {
                var name=Path.GetFileName(file.Name); if(string.IsNullOrWhiteSpace(name) || name.Length>255 || file.Base64 is null || file.Base64.Length>13_333_336) return BadRequest(new {message="ชื่อหรือขนาดไฟล์แนบไม่ถูกต้อง"});
                var bytes=Convert.FromBase64String(file.Base64);totalBytes+=bytes.Length;var type=DetectContentType(bytes);
                if(bytes.Length is <=0 or >10_000_000 || totalBytes>20_000_000 || type is null) return BadRequest(new {message="รองรับ JPG, PNG, WEBP และ PDF ไม่เกิน 10 MB ต่อไฟล์ และรวมไม่เกิน 20 MB"});
                files.Add((name,type,bytes));
            }
        } catch(FormatException) { return BadRequest(new {message="ไม่สามารถอ่านไฟล์แนบ กรุณาเลือกไฟล์ใหม่"}); }
        await using var db = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId<=0 || UserId<=0 || !await Allowed(db,id is null ? "CREATE" : "EDIT",token)) return Forbid();
        var requestHash=System.Security.Cryptography.SHA256.HashData(System.Text.Json.JsonSerializer.SerializeToUtf8Bytes(input));
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try {
            if(id is null) {
                await using(var allocationLock=new SqlCommand("DECLARE @result int,@resource nvarchar(255)=CONCAT(N'LAOO_DOCUMENT_NUMBER:66001:',@company); EXEC @result=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000; IF @result<0 THROW 53965,N'Unable to lock document numbering.',1;",db,tx)) {
                    allocationLock.Parameters.AddWithValue("@company",CompanyId);await allocationLock.ExecuteNonQueryAsync(token);
                }
                await using var existing=new SqlCommand("SELECT Id,ClaimNo,TotalAmount,RequestHash FROM dbo.TDSTTravelClaim WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND UserID=@user AND RequestKey=@key",db,tx);
                existing.Parameters.AddWithValue("@company",CompanyId);existing.Parameters.AddWithValue("@user",UserId);existing.Parameters.AddWithValue("@key",input.RequestKey!.Value);
                await using var reader=await existing.ExecuteReaderAsync(token);
                if(await reader.ReadAsync(token)) { var existingId=reader.GetInt64(0);var existingNo=reader.GetString(1);var existingTotal=reader.GetDecimal(2);var same=!reader.IsDBNull(3) && System.Security.Cryptography.CryptographicOperations.FixedTimeEquals((byte[])reader.GetValue(3),requestHash);await reader.CloseAsync();if(!same)return Conflict(new {message="ใบเบิกจากคำขอนี้บันทึกแล้ว",description="กรุณากลับไปหน้ารายการและเปิดเอกสารเดิมเพื่อแก้ไข"});await tx.CommitAsync(token);return Ok(new {id=existingId,number=existingNo,total=existingTotal}); }
            }
            const string lookup="""
IF NOT EXISTS(SELECT 1 FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND ISNULL(OwnerPartnerID,0)=0 AND MasterGroupCode=N'009' AND MasterCode=@vehicle) THROW 54080,N'Invalid vehicle',1;
IF @route IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.TDSTTravelRoute WHERE CompanyID=@company AND Id=@route AND Origin=@origin AND Destination=@destination) THROW 54081,N'Invalid route',1;
SELECT (SELECT RatePerKm FROM dbo.TDSTTravelVehicleRate WHERE CompanyID=@company AND VehicleTypeCode=@vehicle),
 (SELECT Amount FROM dbo.TDSTTravelRouteRate WHERE CompanyID=@company AND RouteID=@route AND VehicleTypeCode=@vehicle),
 (SELECT CASE WHEN COUNT(DISTINCT l.Amount)=1 THEN MAX(l.Amount) END FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.EmployeeID=ue.EmployeeID AND e.CompanyID=ue.CompanyID AND e.IsActive=1 JOIN dbo.TDSTTravelPositionLevel p ON p.CompanyID=e.CompanyID AND p.PositionCode=e.PositionCode JOIN dbo.TDSTTravelLodgingRate l ON l.CompanyID=p.CompanyID AND l.PositionLevelCode=p.PositionLevelCode WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1);
""";
            decimal? rate, flat, lodging;
            await using(var q=new SqlCommand(lookup,db,tx)) {
                q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);q.Parameters.AddWithValue("@vehicle",input.VehicleTypeCode);
                q.Parameters.AddWithValue("@route",(object?)input.RouteId??DBNull.Value);q.Parameters.AddWithValue("@origin",input.Origin.Trim());q.Parameters.AddWithValue("@destination",input.Destination.Trim());
                await using var reader=await q.ExecuteReaderAsync(token); await reader.ReadAsync(token);
                rate=reader.IsDBNull(0)?null:reader.GetDecimal(0); flat=reader.IsDBNull(1)?null:reader.GetDecimal(1); lodging=reader.IsDBNull(2)?null:reader.GetDecimal(2);
            }
            if(id is not null) {
                await using var snapshot=new SqlCommand("SELECT RouteID,VehicleTypeCode,RatePerKm,FlatFare,LodgingRate,Nights FROM dbo.TDSTTravelClaim WITH(UPDLOCK,HOLDLOCK) WHERE Id=@id AND CompanyID=@company AND UserID=@user",db,tx);
                snapshot.Parameters.AddWithValue("@id",id.Value);snapshot.Parameters.AddWithValue("@company",CompanyId);snapshot.Parameters.AddWithValue("@user",UserId);
                await using var reader=await snapshot.ExecuteReaderAsync(token);if(!await reader.ReadAsync(token))return NotFound(new {message="ไม่พบเอกสารของคุณ"});
                var oldRoute=reader.IsDBNull(0)?(long?)null:reader.GetInt64(0);
                if(oldRoute==input.RouteId && string.Equals(reader.GetString(1),input.VehicleTypeCode,StringComparison.OrdinalIgnoreCase)) { rate=reader.IsDBNull(2)?null:reader.GetDecimal(2);flat=reader.IsDBNull(3)?null:reader.GetDecimal(3); }
                if(reader.GetInt32(5)>0 || input.Nights==0) lodging=reader.GetDecimal(4);
            }
            if(input.Nights>0 && lodging is null) return BadRequest(new { message="ไม่พบอัตราค่าที่พักตามตำแหน่งงาน กรุณาให้ผู้ดูแลกำหนดระดับตำแหน่งและอัตราก่อน" });
            var amounts=TravelClaimCalculation.Calculate(input.StartDate,input.EndDate,input.DistanceKm,flat,rate,lodging??0,input.Nights,input.Toll,input.Parking,input.PublicTransport);
            if(amounts.Total>99999999999999.99m) return BadRequest(new {message="ยอดเบิกสูงเกินกว่าที่ระบบรองรับ กรุณาตรวจสอบระยะทางและจำนวนเงิน"});
            string? number;
            if (id is null) {
                await using var q=new SqlCommand(DocumentNumbering.Sql("66001"),db,tx); q.Parameters.AddWithValue("@company",CompanyId); number=(await q.ExecuteScalarAsync(token)) as string;
                if (number is null) {
                    const string fallback="""
DECLARE @lockResult int,@head nvarchar(20)=N'OI'+CONVERT(char(4),DATEPART(year,SYSUTCDATETIME())),@next bigint;
DECLARE @resource nvarchar(255)=CONCAT(N'LAOO_DOCUMENT_NUMBER:66001:',@company);
EXEC @lockResult=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
IF @lockResult<0 THROW 53965,N'Unable to lock document numbering.',1;
SELECT @next=ISNULL(MAX(TRY_CONVERT(bigint,SUBSTRING(ClaimNo,LEN(@head)+1,30))),0)+1 FROM dbo.TDSTTravelClaim WITH(TABLOCKX,HOLDLOCK)
WHERE CompanyID=@company AND LEFT(ClaimNo,LEN(@head))=@head AND LEN(ClaimNo)>LEN(@head) AND SUBSTRING(ClaimNo,LEN(@head)+1,30) NOT LIKE N'%[^0-9]%';
IF @next>9999 THROW 53965,N'Document sequence exhausted.',1;
SELECT @head+RIGHT(N'0000'+CONVERT(nvarchar(20),@next),4);
""";
                    await using var fallbackCommand=new SqlCommand(fallback,db,tx);fallbackCommand.Parameters.AddWithValue("@company",CompanyId);number=(string?)await fallbackCommand.ExecuteScalarAsync(token);
                }
            } else {
                await using var q=new SqlCommand("SELECT ClaimNo FROM dbo.TDSTTravelClaim WITH (UPDLOCK,HOLDLOCK) WHERE Id=@id AND CompanyID=@company AND UserID=@user",db,tx);
                q.Parameters.AddWithValue("@id",id.Value);q.Parameters.AddWithValue("@company",CompanyId);q.Parameters.AddWithValue("@user",UserId);
                number=(await q.ExecuteScalarAsync(token)) as string; if(number is null) return NotFound(new { message="ไม่พบเอกสารของคุณ" });
            }
            const string insert="""
INSERT dbo.TDSTTravelClaim(CompanyID,UserID,ClaimNo,RequestKey,RequestHash,ClaimDate,RouteID,IsInterbranch,Origin,Destination,Purpose,WorkPlace,MapUrl,DistanceKm,StartDate,EndDate,VehicleTypeCode,VehicleRegistration,RatePerKm,FlatFare,LodgingRate,Nights,Toll,Parking,PublicTransport,FuelAmount,LodgingAmount,TotalAmount)
OUTPUT INSERTED.Id VALUES(@company,@user,@number,@requestKey,@requestHash,@date,@route,@interbranch,@origin,@destination,@purpose,@workplace,@map,@distance,@start,@end,@vehicle,@registration,@rate,@flat,@lodging,@nights,@toll,@parking,@transport,@fuel,@lodgingAmount,@total);
""";
            const string update="""
UPDATE dbo.TDSTTravelClaim SET ClaimDate=@date,RouteID=@route,IsInterbranch=@interbranch,Origin=@origin,Destination=@destination,Purpose=@purpose,WorkPlace=@workplace,MapUrl=@map,DistanceKm=@distance,StartDate=@start,EndDate=@end,VehicleTypeCode=@vehicle,VehicleRegistration=@registration,RatePerKm=@rate,FlatFare=@flat,LodgingRate=@lodging,Nights=@nights,Toll=@toll,Parking=@parking,PublicTransport=@transport,FuelAmount=@fuel,LodgingAmount=@lodgingAmount,TotalAmount=@total,UpdatedAt=SYSUTCDATETIME() OUTPUT INSERTED.Id WHERE Id=@id AND CompanyID=@company AND UserID=@user;
""";
            await using var cmd=new SqlCommand(id is null ? insert : update,db,tx);
            if(id is not null) cmd.Parameters.AddWithValue("@id",id.Value);
            else { cmd.Parameters.AddWithValue("@requestKey",input.RequestKey!.Value);cmd.Parameters.Add("@requestHash",SqlDbType.VarBinary,32).Value=requestHash; }
            cmd.Parameters.AddWithValue("@company",CompanyId);cmd.Parameters.AddWithValue("@user",UserId);cmd.Parameters.AddWithValue("@number",number);
            cmd.Parameters.AddWithValue("@date",input.ClaimDate.ToDateTime(TimeOnly.MinValue));cmd.Parameters.AddWithValue("@route",(object?)input.RouteId??DBNull.Value);
            cmd.Parameters.AddWithValue("@interbranch",input.IsInterbranch);
            cmd.Parameters.AddWithValue("@origin",input.Origin.Trim());cmd.Parameters.AddWithValue("@destination",input.Destination.Trim());cmd.Parameters.AddWithValue("@purpose",input.Purpose.Trim());cmd.Parameters.AddWithValue("@workplace",input.WorkPlace.Trim());
            cmd.Parameters.AddWithValue("@map",(object?)input.MapUrl?.Trim()??DBNull.Value);cmd.Parameters.AddWithValue("@distance",input.DistanceKm);
            cmd.Parameters.AddWithValue("@start",input.StartDate.ToDateTime(TimeOnly.MinValue));cmd.Parameters.AddWithValue("@end",input.EndDate.ToDateTime(TimeOnly.MinValue));
            cmd.Parameters.AddWithValue("@vehicle",input.VehicleTypeCode);cmd.Parameters.AddWithValue("@registration",input.VehicleRegistration.Trim());
            cmd.Parameters.AddWithValue("@rate",(object?)rate??DBNull.Value);cmd.Parameters.AddWithValue("@flat",(object?)flat??DBNull.Value);cmd.Parameters.AddWithValue("@lodging",lodging??0);
            cmd.Parameters.AddWithValue("@nights",input.Nights);cmd.Parameters.AddWithValue("@toll",input.Toll);cmd.Parameters.AddWithValue("@parking",input.Parking);cmd.Parameters.AddWithValue("@transport",input.PublicTransport);
            cmd.Parameters.AddWithValue("@fuel",amounts.Fuel);cmd.Parameters.AddWithValue("@lodgingAmount",amounts.Lodging);cmd.Parameters.AddWithValue("@total",amounts.Total);
            var savedId=Convert.ToInt64(await cmd.ExecuteScalarAsync(token));
            foreach(var file in files) {
                await using var attachment=new SqlCommand("INSERT dbo.TDSTTravelClaimAttachment(ClaimID,CompanyID,FileName,ContentType,FileData) VALUES(@id,@company,@name,@type,@data)",db,tx);
                attachment.Parameters.AddWithValue("@id",savedId);attachment.Parameters.AddWithValue("@company",CompanyId);attachment.Parameters.AddWithValue("@name",file.Name);attachment.Parameters.AddWithValue("@type",file.Type);attachment.Parameters.Add("@data",SqlDbType.VarBinary,-1).Value=file.Data;
                await attachment.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token);return Ok(new { id=savedId,number,total=amounts.Total });
        } catch(ArgumentException ex) { return BadRequest(new { message=ex.Message }); }
        catch(SqlException ex) when(ex.Number is 54080 or 54081) { return BadRequest(new { message="ไม่พบเส้นทางหรือประเภทรถของบริษัท กรุณาโหลดข้อมูลใหม่" }); }
        catch(OverflowException) { return BadRequest(new { message="จำนวนเงินหรือระยะทางสูงเกินกว่าที่ระบบรองรับ" }); }
    }

    private static string? DetectContentType(byte[] bytes) =>
        bytes.Length>=4 && bytes[0]==0x25 && bytes[1]==0x50 && bytes[2]==0x44 && bytes[3]==0x46 ? "application/pdf" :
        bytes.Length>=3 && bytes[0]==0xff && bytes[1]==0xd8 && bytes[2]==0xff ? "image/jpeg" :
        bytes.Length>=8 && bytes.AsSpan(0,8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10}) ? "image/png" :
        bytes.Length>=12 && System.Text.Encoding.ASCII.GetString(bytes,0,4)=="RIFF" && System.Text.Encoding.ASCII.GetString(bytes,8,4)=="WEBP" ? "image/webp" : null;
}
