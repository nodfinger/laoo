using Laoo.Pet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
namespace Laoo.Pet.Controllers;
[ApiController,Authorize,Route("api/company/pet")]
public sealed class PetSettingsController(IConfiguration config) : PetControllerBase(config)
{
    [HttpGet("options/{menu}")]
    public async Task<IActionResult> Options(string menu,CancellationToken ct)
    {
        if (menu is not ("62002" or "62003" or "62004" or "62005" or "62006" or "62007"))
            return NotFound();
        await using var db=await Open(ct);
        if(await Guard(db,menu,"VIEW",ct) is { } no)return no;
        var empty=new List<Dictionary<string,object?>>();
        var customers=menu is "62004" or "62006"
            ? await PetDb.Rows(db,null,"SELECT TOP 100 CustomerID id,CusCode code,CusName name FROM dbo.TDARCustomer WHERE CompanyID=@c AND IsActive=1 ORDER BY CusName",ct,("@c",Company)) : empty;
        var members=menu is "62004" or "62005"
            ? await PetDb.Rows(db,null,"SELECT TOP 100 M.MemberID id,M.MemberCode code,P.FullName name FROM dbo.TDBKMember M JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID WHERE M.CompanyID=@c AND M.IsActive=1 ORDER BY P.FullName",ct,("@c",Company)) : empty;
        var services=menu is "62005" or "62006"
            ? await PetDb.Rows(db,null,"SELECT M.ServiceID id,S.ServiceName name,M.KindCode kind,S.Price price FROM dbo.TDPTServiceMap M JOIN dbo.TDBKService S ON S.CompanyID=M.CompanyID AND S.ServiceID=M.ServiceID WHERE M.CompanyID=@c AND M.IsActive=1 AND S.IsActive=1 ORDER BY S.ServiceName",ct,("@c",Company)) : empty;
        var bookingServices=menu=="62002"
            ? await PetDb.Rows(db,null,"SELECT ServiceID id,ServiceName name FROM dbo.TDBKService WHERE CompanyID=@c AND IsActive=1 ORDER BY ServiceName",ct,("@c",Company)) : empty;
        var resources=menu=="62003"
            ? await PetDb.Rows(db,null,"SELECT ResourceID id,ResourceName name FROM dbo.TDBKResource WHERE CompanyID=@c AND IsActive=1 ORDER BY ResourceName",ct,("@c",Company)) : empty;
        var rooms=menu=="62006"
            ? await PetDb.Rows(db,null,"SELECT RoomID id,RoomName name,Capacity capacity FROM dbo.TDPTRoom WHERE CompanyID=@c AND IsActive=1 ORDER BY RoomName",ct,("@c",Company)) : empty;
        var providers=menu=="62006"
            ? await PetDb.Rows(db,null,"SELECT V.ProviderID id,P.FullName name FROM dbo.TDBKProvider V JOIN dbo.TDADPerson P ON P.CompanyID=V.CompanyID AND P.PersonID=V.PersonID AND P.IsActive=1 WHERE V.CompanyID=@c AND V.IsActive=1 ORDER BY P.FullName",ct,("@c",Company)) : empty;
        var branches=menu=="62006"
            ? await PetDb.Rows(db,null,@"SELECT B.BranchID id,B.BranchNameTH name FROM dbo.TDADBranch B
WHERE B.CompanyID=@c AND B.IsActive=1 AND
  (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
   OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=B.BranchID AND X.IsActive=1))
ORDER BY B.BranchNameTH",ct,("@c",Company),("@actor",Actor)) : empty;
        var pets=menu=="62006"
            ? await PetDb.Rows(db,null,"SELECT PetID id,PetName name,OwnerCustomerID ownerCustomerId FROM dbo.TDPTPet WHERE CompanyID=@c AND IsActive=1 ORDER BY PetName",ct,("@c",Company)) : empty;
        var packages=menu=="62005"
            ? await PetDb.Rows(db,null,"SELECT PackageID id,PackageName name FROM dbo.TDPTPackage WHERE CompanyID=@c AND IsActive=1 ORDER BY PackageName",ct,("@c",Company)) : empty;
        var items=menu=="62005"
            ? await PetDb.Rows(db,null,"SELECT TOP 100 ItemID id,ItemCode code FROM dbo.TDIVItem WHERE CompanyID=@c AND IsActive=1 ORDER BY ItemCode",ct,("@c",Company)) : empty;
        return Ok(new {customers,members,services,bookingServices,resources,rooms,providers,branches,pets,packages,items});
    }
    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,menu,"VIEW",ct) is { } no)return no;
        var meta=await PetDb.Rows(db,null,"SELECT MenuName,ScreenType,IconName FROM dbo.TDADMainMenu WHERE MenuCode=@m AND IsActive=1",ct,("@m",menu));
        var allowed=new Dictionary<string,bool>();
        foreach(var action in new[]{"VIEW","CREATE","EDIT","DELETE","CANCEL","CHECKIN","COMPLETE"})
            allowed[action.ToLowerInvariant()]=await PetAccess.Can(db,User,menu,action,ct);
        return Ok(new { metadata=meta[0],actions=allowed });
    }
    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,"62001","VIEW",ct) is { } no)return no;
        var rows=await PetDb.Rows(db,null,"SELECT ReminderHours reminderHours,CheckInStart checkInStart,CheckInEnd checkInEnd FROM dbo.TDPTSetting WHERE CompanyID=@c",ct,("@c",Company));
        return Ok(rows.Count==0?new { reminderHours=24,checkInStart="09:00",checkInEnd="18:00" }:(object)rows[0]);
    }
    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(PetSettingsRequest input,CancellationToken ct)
    {
        if(input.ReminderHours is <0 or >720 || input.CheckInEnd<=input.CheckInStart)return Invalid("กำหนดเวลาที่ถูกต้องและชั่วโมงแจ้งเตือนระหว่าง 0–720");
        await using var db=await Open(ct);
        if(await Guard(db,"62001","EDIT",ct) is { } no)return no;
        await PetDb.Exec(db,null,"UPDATE dbo.TDPTSetting SET ReminderHours=@r,CheckInStart=@s,CheckInEnd=@e,UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@c; IF @@ROWCOUNT=0 INSERT dbo.TDPTSetting(CompanyID,ReminderHours,CheckInStart,CheckInEnd) VALUES(@c,@r,@s,@e)",ct,("@c",Company),("@r",input.ReminderHours),("@s",input.CheckInStart),("@e",input.CheckInEnd));
        return NoContent();
    }
}
public sealed record PetSettingsRequest(int ReminderHours,TimeSpan CheckInStart,TimeSpan CheckInEnd);
