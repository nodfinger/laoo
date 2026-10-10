using Laoo.Pet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
namespace Laoo.Pet.Controllers;
[ApiController,Authorize,Route("api/company/pet/packages")]
public sealed class PetPackagesController(IConfiguration config) : PetControllerBase(config)
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct,int page=1,int pageSize=20,string? search=null)
    {
        if(page<1||pageSize is <1 or >100||page>int.MaxValue/pageSize)return Invalid("เลขหน้าหรือจำนวนรายการไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62005","VIEW",ct) is { } no)return no;
        var term=(search??"").Trim();
        if(term.Length>100)return Invalid("คำค้นหาต้องไม่เกิน 100 อักษร");
        const string filter=" WHERE CompanyID=@c AND (@term=N'' OR PackageCode LIKE N'%'+@term+N'%' OR PackageName LIKE N'%'+@term+N'%')";
        var total=await PetDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDPTPackage"+filter,ct,("@c",Company),("@term",term));
        var packages=await PetDb.Rows(db,null,"SELECT PackageID id,PackageCode code,PackageName name,Price price,ValidDays validDays,IncludedUnits units,PosItemID posItemId,IsActive active FROM dbo.TDPTPackage"+filter+" ORDER BY PackageID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@c",Company),("@term",term),("@offset",(page-1)*pageSize),("@size",pageSize));
        var services=await PetDb.Rows(db,null,"SELECT PS.PackageID packageId,PS.ServiceID serviceId FROM dbo.TDPTPackageService PS JOIN dbo.TDPTPackage P ON P.CompanyID=PS.CompanyID AND P.PackageID=PS.PackageID WHERE PS.CompanyID=@c AND (@term=N'' OR P.PackageCode LIKE N'%'+@term+N'%' OR P.PackageName LIKE N'%'+@term+N'%') AND P.PackageID IN (SELECT PackageID FROM dbo.TDPTPackage WHERE CompanyID=@c AND (@term=N'' OR PackageCode LIKE N'%'+@term+N'%' OR PackageName LIKE N'%'+@term+N'%') ORDER BY PackageID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY)",ct,("@c",Company),("@term",term),("@offset",(page-1)*pageSize),("@size",pageSize));
        return Ok(new{items=packages,services,total,page,pageSize});
    }
    [HttpPost]
    public async Task<IActionResult> Create(PetPackageRequest input,CancellationToken ct)
    {
        if(!Valid(input))return Invalid("กรอกรหัส ชื่อ ราคา อายุสิทธิ์ จำนวนหน่วย และเลือกบริการอย่างน้อยหนึ่งรายการ");
        await using var db=await Open(ct);
        if(await Guard(db,"62005","CREATE",ct) is { } no)return no;
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        try
        {
            if(!await ValidServices(db,tx,input.ServiceIds,ct)||!await ValidItem(db,tx,input.PosItemId,ct))return Invalid("มีบริการหรือสินค้า POS ที่ไม่เปิดใช้งานในบริษัทนี้");
            var id=await PetDb.Id(db,tx,"INSERT dbo.TDPTPackage(CompanyID,PackageCode,PackageName,Price,ValidDays,IncludedUnits,PosItemID,IsActive) VALUES(@c,@code,@name,@price,@days,@units,@item,@active); SELECT CONVERT(bigint,SCOPE_IDENTITY())",ct,("@c",Company),("@code",input.Code.Trim()),("@name",input.Name.Trim()),("@price",input.Price),("@days",input.ValidDays),("@units",input.Units),("@item",input.PosItemId),("@active",input.Active));
            foreach(var service in input.ServiceIds)await PetDb.Exec(db,tx,"INSERT dbo.TDPTPackageService(CompanyID,PackageID,ServiceID) VALUES(@c,@package,@service)",ct,("@c",Company),("@package",id),("@service",service));
            await tx.CommitAsync(ct);
            return Created($"/api/company/pet/packages/{id}",new{id});
        }
        catch(SqlException e) when(e.Number is 2601 or 2627){await tx.RollbackAsync(ct);return Conflict(new{message="รหัสแพ็กเกจซ้ำ",description="ใช้รหัสใหม่หรือแก้ไขแพ็กเกจเดิม"});}
        catch{await tx.RollbackAsync(ct);throw;}
    }
    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id,PetPackageRequest input,CancellationToken ct)
    {
        if(id<1||!Valid(input))return Invalid("ข้อมูลแพ็กเกจไม่ถูกต้อง");
        await using var db=await Open(ct);
        if(await Guard(db,"62005","EDIT",ct) is { } no)return no;
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        try
        {
            if(!await ValidServices(db,tx,input.ServiceIds,ct)||!await ValidItem(db,tx,input.PosItemId,ct))return Invalid("มีบริการหรือสินค้า POS ที่ไม่เปิดใช้งานในบริษัทนี้");
            var changed=await PetDb.Exec(db,tx,"UPDATE dbo.TDPTPackage SET PackageName=@name,Price=@price,ValidDays=@days,IncludedUnits=@units,PosItemID=@item,IsActive=@active WHERE CompanyID=@c AND PackageID=@id AND PackageCode=@code",ct,("@c",Company),("@id",id),("@code",input.Code),("@name",input.Name.Trim()),("@price",input.Price),("@days",input.ValidDays),("@units",input.Units),("@item",input.PosItemId),("@active",input.Active));
            if(changed==0)return Missing();
            await PetDb.Exec(db,tx,"DELETE FROM dbo.TDPTPackageService WHERE CompanyID=@c AND PackageID=@id",ct,("@c",Company),("@id",id));
            foreach(var service in input.ServiceIds)await PetDb.Exec(db,tx,"INSERT dbo.TDPTPackageService(CompanyID,PackageID,ServiceID) VALUES(@c,@package,@service)",ct,("@c",Company),("@package",id),("@service",service));
            await tx.CommitAsync(ct);
            return NoContent();
        }
        catch{await tx.RollbackAsync(ct);throw;}
    }
    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Deactivate(long id,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"62005","DELETE",ct) is { } no)return no;
        var changed=await PetDb.Exec(db,null,"UPDATE dbo.TDPTPackage SET IsActive=0 WHERE CompanyID=@c AND PackageID=@id AND IsActive=1",ct,("@c",Company),("@id",id));
        return changed==0?Missing():NoContent();
    }
    static bool Valid(PetPackageRequest x)=>!string.IsNullOrWhiteSpace(x.Code)&&x.Code.Length<=30&&!string.IsNullOrWhiteSpace(x.Name)&&x.Name.Length<=150&&x.Price>=0&&x.ValidDays is >0 and <=3650&&x.Units is >0 and <=10000&&x.ServiceIds is {Count:>0 and <=50}&&x.ServiceIds.Distinct().Count()==x.ServiceIds.Count;
    async Task<bool> ValidServices(SqlConnection db,SqlTransaction tx,IReadOnlyList<long> services,CancellationToken ct)
    {
        foreach(var id in services)if(await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDPTServiceMap M JOIN dbo.TDBKService B ON B.CompanyID=M.CompanyID AND B.ServiceID=M.ServiceID WHERE M.CompanyID=@c AND M.ServiceID=@id AND M.IsActive=1 AND B.IsActive=1",ct,("@c",Company),("@id",id))==0)return false;
        return true;
    }
    async Task<bool> ValidItem(SqlConnection db,SqlTransaction tx,long? item,CancellationToken ct)=>item is null||await PetDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDIVItem WHERE CompanyID=@c AND ItemID=@item AND IsActive=1",ct,("@c",Company),("@item",item))>0;
}
public sealed record PetPackageRequest(string Code,string Name,decimal Price,int ValidDays,int Units,IReadOnlyList<long> ServiceIds,long? PosItemId,bool Active=true);
