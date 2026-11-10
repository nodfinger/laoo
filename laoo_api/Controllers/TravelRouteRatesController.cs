using System.Data;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/company/travel-route-rates")]
public sealed class TravelRouteRatesController(IConfiguration configuration) : ControllerBase
{
    private long CompanyId => RegistryControllerSupport.ClaimLong(User, "company_id");
    private long UserId => RegistryControllerSupport.ClaimLong(User, "user_id");
    private Task<bool> Allowed(SqlConnection c, string action, CancellationToken token) => CompanyProjectPermission.IsAllowedAsync(c, User, "67002", action, token);

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await Allowed(c, "VIEW", token)) return Forbid();
        var create = await Allowed(c, "CREATE", token);
        var edit = await Allowed(c, "EDIT", token);
        var delete = await Allowed(c, "DELETE", token);
        const string sql = """
SELECT Id, Origin, Destination, DistanceKm FROM dbo.TDSTTravelRoute WHERE CompanyID=@company ORDER BY Id;
SELECT MasterCode, Name FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterGroupCode=N'009' ORDER BY Seq,Name,MasterCode;
""";
        await using var q = new SqlCommand(sql, c);
        q.Parameters.Add("@company", SqlDbType.BigInt).Value = CompanyId;
        await using var r = await q.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await r.ReadAsync(token)) items.Add(new { id=r.GetInt64(0), origin=r.GetString(1), destination=r.GetString(2), distance=r.GetDecimal(3) });
        await r.NextResultAsync(token);
        var vehicles = new List<object>();
        while (await r.ReadAsync(token)) vehicles.Add(new { code=r.GetString(0), name=r.GetString(1) });
        return Ok(new { create, edit, delete, items, vehicles });
    }

    [HttpGet("{id:long}/vehicle-rates")]
    public async Task<IActionResult> VehicleRates(long id, CancellationToken token)
    {
        await using var c = await RegistryControllerSupport.Open(configuration, token);
        if (CompanyId <= 0 || !await Allowed(c, "VIEW", token)) return Forbid();
        const string sql = """
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTTravelRoute WHERE Id=@id AND CompanyID=@company) THROW 54044,N'Route not found',1;
SELECT m.MasterCode,m.Name,r.Amount FROM dbo.TDSTMaster m
LEFT JOIN dbo.TDSTTravelRouteRate r ON r.CompanyID=@company AND r.RouteID=@id AND r.VehicleTypeCode=m.MasterCode
WHERE m.OwnerType=N'C' AND ISNULL(m.OwnerPartnerID,0)=0 AND m.OwnerCompanyID=@company AND m.MasterGroupCode=N'009'
ORDER BY m.Seq,m.Name,m.MasterCode;
""";
        await using var q = new SqlCommand(sql,c);
        q.Parameters.Add("@company",SqlDbType.BigInt).Value=CompanyId;
        q.Parameters.Add("@id",SqlDbType.BigInt).Value=id;
        try {
            await using var r=await q.ExecuteReaderAsync(token);
            var items=new List<object>();
            while(await r.ReadAsync(token)) items.Add(new { code=r.GetString(0),name=r.GetString(1),amount=r.IsDBNull(2)?(decimal?)null:r.GetDecimal(2) });
            return Ok(new { items });
        } catch(SqlException ex) when(ex.Number==54044) { return NotFound(new { message="ไม่พบเส้นทางที่ต้องการ" }); }
    }

    [HttpPost] public Task<IActionResult> Create([FromBody] TravelRouteRequest request,CancellationToken token) => Save(null,request,token);
    [HttpPut("{id:long}")] public Task<IActionResult> Update(long id,[FromBody] TravelRouteRequest request,CancellationToken token) => Save(id,request,token);
    private async Task<IActionResult> Save(long? id,TravelRouteRequest request,CancellationToken token)
    {
        if(string.IsNullOrWhiteSpace(request.Origin)||request.Origin.Trim().Length>200||string.IsNullOrWhiteSpace(request.Destination)||request.Destination.Trim().Length>200||!Valid(request.Distance))
            return BadRequest(new { message="กรุณาระบุต้นทาง ปลายทาง และระยะทางที่ถูกต้อง" });
        await using var c=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || !await Allowed(c,id is null?"CREATE":"EDIT",token)) return Forbid();
        const string sql="""
IF @id IS NULL INSERT dbo.TDSTTravelRoute(CompanyID,Origin,Destination,DistanceKm,CreateBy) VALUES(@company,@origin,@destination,@distance,@user);
ELSE BEGIN
 UPDATE dbo.TDSTTravelRoute SET Origin=@origin,Destination=@destination,DistanceKm=@distance,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND Id=@id;
 IF @@ROWCOUNT=0 THROW 54044,N'Route not found',1;
 UPDATE dbo.TDSTTravelRouteRate SET Origin=@origin,Destination=@destination,DistanceKm=@distance WHERE CompanyID=@company AND RouteID=@id;
END
""";
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(token);
        await using var q=new SqlCommand(sql,c,tx);
        q.Parameters.Add("@company",SqlDbType.BigInt).Value=CompanyId;
        q.Parameters.Add("@user",SqlDbType.BigInt).Value=UserId;
        q.Parameters.Add("@id",SqlDbType.BigInt).Value=(object?)id??DBNull.Value;
        q.Parameters.Add("@origin",SqlDbType.NVarChar,200).Value=request.Origin.Trim();
        q.Parameters.Add("@destination",SqlDbType.NVarChar,200).Value=request.Destination.Trim();
        var distance=q.Parameters.Add("@distance",SqlDbType.Decimal); distance.Precision=12; distance.Scale=2; distance.Value=request.Distance;
        try { await q.ExecuteNonQueryAsync(token); await tx.CommitAsync(token); return Ok(new { saved=true }); }
        catch(SqlException ex) when(ex.Number==54044) { await tx.RollbackAsync(token); return NotFound(new { message="ไม่พบรายการที่ต้องการแก้ไข" }); }
    }

    [HttpPut("{id:long}/vehicle-rates")]
    public async Task<IActionResult> SaveVehicleRates(long id,[FromBody] TravelVehicleRatesRequest request,CancellationToken token)
    {
        if(request.Items is null || request.Items.Any(x=>string.IsNullOrWhiteSpace(x.Code)||x.Code.Length>10||(x.Amount is not null && !Valid(x.Amount.Value))) || request.Items.Select(x=>x.Code).Distinct(StringComparer.OrdinalIgnoreCase).Count()!=request.Items.Count)
            return BadRequest(new { message="กรุณาตรวจสอบประเภทรถและจำนวนเงิน" });
        await using var c=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || !await Allowed(c,"EDIT",token)) return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try {
            foreach(var item in request.Items) {
                const string sql="""
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTTravelRoute WITH (UPDLOCK,HOLDLOCK) WHERE Id=@id AND CompanyID=@company) THROW 54044,N'Route not found',1;
IF NOT EXISTS (SELECT 1 FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterGroupCode=N'009' AND MasterCode=@vehicle) THROW 54030,N'Invalid vehicle',1;
IF @amount IS NULL DELETE FROM dbo.TDSTTravelRouteRate WHERE CompanyID=@company AND RouteID=@id AND VehicleTypeCode=@vehicle;
ELSE BEGIN
 UPDATE dbo.TDSTTravelRouteRate SET Amount=@amount,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND RouteID=@id AND VehicleTypeCode=@vehicle;
 IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelRouteRate(CompanyID,RouteID,Origin,Destination,DistanceKm,VehicleTypeCode,Amount,CreateBy)
 SELECT CompanyID,Id,Origin,Destination,DistanceKm,@vehicle,@amount,@user FROM dbo.TDSTTravelRoute WHERE Id=@id AND CompanyID=@company;
END
""";
                await using var q=new SqlCommand(sql,c,tx);
                q.Parameters.Add("@id",SqlDbType.BigInt).Value=id; q.Parameters.Add("@company",SqlDbType.BigInt).Value=CompanyId;
                q.Parameters.Add("@user",SqlDbType.BigInt).Value=UserId; q.Parameters.Add("@vehicle",SqlDbType.NVarChar,10).Value=item.Code;
                var amount=q.Parameters.Add("@amount",SqlDbType.Decimal); amount.Precision=12; amount.Scale=2; amount.Value=(object?)item.Amount??DBNull.Value;
                await q.ExecuteNonQueryAsync(token);
            }
            await tx.CommitAsync(token); return Ok(new { saved=true });
        } catch(SqlException ex) when(ex.Number is 54030 or 54044) {
            await tx.RollbackAsync(token); return BadRequest(new { message="ไม่พบเส้นทางหรือประเภทรถ กรุณาโหลดข้อมูลใหม่" });
        }
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,CancellationToken token)
    {
        await using var c=await RegistryControllerSupport.Open(configuration,token);
        if(CompanyId<=0 || !await Allowed(c,"DELETE",token)) return Forbid();
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(token);
        await using var q=new SqlCommand("DELETE FROM dbo.TDSTTravelRouteRate WHERE CompanyID=@company AND RouteID=@id; DELETE FROM dbo.TDSTTravelRoute WHERE CompanyID=@company AND Id=@id; SELECT @@ROWCOUNT;",c,tx);
        q.Parameters.Add("@company",SqlDbType.BigInt).Value=CompanyId; q.Parameters.Add("@id",SqlDbType.BigInt).Value=id;
        var count=Convert.ToInt32(await q.ExecuteScalarAsync(token)); await tx.CommitAsync(token);
        return count==0 ? NotFound(new { message="ไม่พบรายการที่ต้องการลบ" }) : Ok(new { deleted=true });
    }
    private static bool Valid(decimal value) => value>=0 && value<=9999999999.99m && decimal.Round(value,2)==value;
}
public sealed record TravelRouteRequest(string Origin,string Destination,decimal Distance);
public sealed record TravelVehicleRate(string Code,decimal? Amount);
public sealed record TravelVehicleRatesRequest(List<TravelVehicleRate> Items);
