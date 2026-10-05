using System.Data;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Laoo.SchoolFood.Controllers;

[ApiController,Authorize,Route("api/company/school-food")]
public sealed partial class SchoolFoodController(IConfiguration configuration) : ControllerBase
{
    private long Company => long.Parse(User.FindFirst("company_id")!.Value);
    private long Actor => long.Parse(User.FindFirst("user_id")!.Value);
    private async Task<SqlConnection> Open(CancellationToken ct)
    {
        var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct); return db;
    }

    private async Task<IActionResult?> Guard(SqlConnection db,string menu,string action,CancellationToken ct,
        long? shop=null,bool schoolOnly=false)
    {
        if(!SchoolFoodAccess.Scope(User,out var company,out var actor)) return Denied();
        if(await FoodDb.Id(db,null,"SELECT COUNT(*) FROM sys.tables WHERE name=N'TDSFSetting' AND schema_id=SCHEMA_ID(N'dbo')",ct)!=1)
            return StatusCode(503,new{message="ระบบขายอาหารยังไม่พร้อมใช้งาน",description="รอผู้ดูแลติดตั้งโครงสร้างข้อมูล School Food"});
        if(!await SchoolFoodAccess.Can(db,User,menu,action,ct)) return Denied();
        var scope=await SchoolFoodAccess.ShopScope(db,company,actor,ct);
        if(scope is -1 || (schoolOnly&&scope.HasValue) || (shop.HasValue&&scope.HasValue&&scope!=shop)) return Denied();
        return null;
    }
    private IActionResult Denied()=>StatusCode(403,new{
        message="ไม่มีสิทธิ์ทำรายการขายอาหารนี้",
        description="ตรวจสอบสิทธิ์เมนู ร้านค้าที่ได้รับมอบหมาย และแพ็กเกจ School/School Food กับผู้ดูแลโรงเรียน"});

    private IActionResult Bad(string description)=>BadRequest(new{message="ข้อมูลไม่ถูกต้อง",description});
    private async Task<IActionResult> Transact(SqlConnection db,Guid key,string action,object request,
        Func<SqlTransaction,long,Task<object>> work,CancellationToken ct)
    {
        try { return Content(await FoodTransaction.Run(db,Company,Actor,key,action,request,work,ct),"application/json"); }
        catch(FoodBusinessException e) { return Conflict(new{message="ทำรายการไม่สำเร็จ",description=e.Message}); }
        catch(SqlException e) when(e.Number is 2601 or 2627 or 1205)
        { return Conflict(new{message="รายการมีการเปลี่ยนแปลงหรือถูกส่งซ้ำ",description="ตรวจสอบรายการล่าสุด แล้วลองใหม่ด้วยรหัสคำขอเดิม"}); }
    }

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu,CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(await Guard(db,menu,"VIEW",ct) is {} fail)return fail;
        var result=new Dictionary<string,bool>();
        foreach(var action in SchoolFoodContract.Menus.Single(m=>m.Code==menu).Actions)
            result[action.ToLowerInvariant()]=await SchoolFoodAccess.Can(db,User,menu,action,ct);
        var scope=await SchoolFoodAccess.ShopScope(db,Company,Actor,ct);
        if(scope.HasValue)
        {
            foreach(var action in result.Keys.ToArray())
                if(menu is "53001" or "53002" or "53005" or "53007" or "53010"
                    || (menu=="53004"&&action!="view")
                    || (menu=="53006"&&action is not ("view" or "receive")))
                    result[action]=false;
        }
        var metadata=await FoodDb.Rows(db,null,"SELECT MenuName,ScreenType,IconName FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1",ct,("@menu",menu));
        return Ok(new{actions=result,shopId=scope,schoolUser=!scope.HasValue,metadata=metadata.Single()});
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken ct)
    {
        await using var db=await Open(ct);if(await Guard(db,"53001","VIEW",ct,schoolOnly:true) is {} f)return f;
        var rows=await FoodDb.Rows(db,null,"SELECT IsEnabled,CommissionEnabled,DefaultCommissionRate FROM dbo.TDSFSetting WHERE CompanyID=@co",ct,("@co",Company));
        return Ok(rows.FirstOrDefault()??new Dictionary<string,object?>{{"IsEnabled",true},{"CommissionEnabled",false},{"DefaultCommissionRate",0m}});
    }

    [HttpPut("settings")]
    public async Task<IActionResult> Settings(SettingInput input,CancellationToken ct)
    {
        if(input.DefaultCommissionRate is <0 or >100)return Bad("อัตราหักต้องอยู่ระหว่าง 0–100");
        await using var db=await Open(ct);if(await Guard(db,"53001","EDIT",ct,schoolOnly:true) is {} f)return f;
        return await Transact(db,input.RequestKey,"SETTINGS",input,async(tx,op)=>{
            await FoodDb.Execute(db,tx,"MERGE dbo.TDSFSetting WITH(HOLDLOCK) AS t USING(SELECT @co CompanyID)s ON t.CompanyID=s.CompanyID WHEN MATCHED THEN UPDATE SET IsEnabled=@enabled,CommissionEnabled=@commission,DefaultCommissionRate=@rate,UpdatedBy=@actor,UpdatedAt=SYSUTCDATETIME() WHEN NOT MATCHED THEN INSERT(CompanyID,IsEnabled,CommissionEnabled,DefaultCommissionRate,UpdatedBy) VALUES(@co,@enabled,@commission,@rate,@actor);",ct,
                ("@co",Company),("@enabled",input.IsEnabled),("@commission",input.CommissionEnabled),("@rate",input.DefaultCommissionRate),("@actor",Actor));
            return new{saved=true};
        },ct);
    }

    [HttpGet("shops")]
    public async Task<IActionResult> Shops([FromQuery]string menu="53002",CancellationToken ct=default)
    {
        await using var db=await Open(ct);if(await Guard(db,menu,"VIEW",ct) is {} f)return f;
        var scope=await SchoolFoodAccess.ShopScope(db,Company,Actor,ct);
        return Ok(await FoodDb.Rows(db,null,"SELECT ShopID id,ShopCode code,ShopName name,TrackStock,WarehouseID,IsActive,CommissionRate FROM dbo.TDSFShop WHERE CompanyID=@co AND (@shop IS NULL OR ShopID=@shop) ORDER BY ShopCode",ct,("@co",Company),("@shop",scope)));
    }

    [HttpPost("shops")]
    public Task<IActionResult> CreateShop(ShopInput input,CancellationToken ct)=>SaveShop(null,input,ct);
    [HttpPut("shops/{id:long}")]
    public Task<IActionResult> EditShop(long id,ShopInput input,CancellationToken ct)=>SaveShop(id,input,ct);
    private async Task<IActionResult> SaveShop(long? id,ShopInput input,CancellationToken ct)
    {
        if(string.IsNullOrWhiteSpace(input.Code)||input.Code.Length>30||string.IsNullOrWhiteSpace(input.Name)||input.Name.Length>200
            ||(input.TrackStock&&!input.WarehouseID.HasValue)||input.CommissionRate is <0 or >100)
            return Bad("ระบุรหัส ชื่อร้าน คลังที่เก็บสต๊อก และอัตรา 0–100");
        await using var db=await Open(ct);if(await Guard(db,"53002",id.HasValue?"EDIT":"CREATE",ct,schoolOnly:true) is {} f)return f;
        return await Transact(db,input.RequestKey,"SHOP",new{id,input},async(tx,op)=>{
            if(input.WarehouseID.HasValue && await FoodDb.Id(db,tx,"SELECT COUNT(*) FROM dbo.TDIVWarehouse WHERE CompanyID=@co AND WarehouseID=@wh AND IsActive=1",ct,("@co",Company),("@wh",input.WarehouseID))!=1)
                throw new FoodBusinessException("เลือกคลังที่เปิดใช้งานภายในโรงเรียนนี้");
            if(id.HasValue)
            {
                var existing=await FoodDb.Rows(db,tx,"SELECT TrackStock,WarehouseID FROM dbo.TDSFShop WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co AND ShopID=@id",ct,("@co",Company),("@id",id));
                if(existing.Count!=1)throw new FoodBusinessException("ไม่พบร้านค้า");
                if(existing[0].Bool("TrackStock")!=input.TrackStock || Convert.ToInt64(existing[0]["WarehouseID"]??0)!=input.WarehouseID.GetValueOrDefault())
                    if(await FoodDb.Id(db,tx,"SELECT (SELECT COUNT(*) FROM dbo.TDSFSale WHERE CompanyID=@co AND ShopID=@id)+(SELECT COUNT(*) FROM dbo.TDSFTransfer WHERE CompanyID=@co AND ShopID=@id)",ct,("@co",Company),("@id",id))>0)
                        throw new FoodBusinessException("ร้านค้ามีประวัติแล้ว ไม่สามารถเปลี่ยนคลังหรือวิธีเก็บสต๊อก");
            }
            var sql=id.HasValue?"UPDATE dbo.TDSFShop SET ShopCode=@code,ShopName=@name,TrackStock=@track,WarehouseID=@wh,IsActive=@active,CommissionRate=@rate OUTPUT INSERTED.ShopID WHERE CompanyID=@co AND ShopID=@id"
                :"INSERT dbo.TDSFShop(CompanyID,ShopCode,ShopName,TrackStock,WarehouseID,IsActive,CommissionRate,CreatedBy) OUTPUT INSERTED.ShopID VALUES(@co,@code,@name,@track,@wh,@active,@rate,@actor)";
            var saved=await FoodDb.Id(db,tx,sql,ct,("@co",Company),("@id",id),("@code",input.Code.Trim()),("@name",input.Name.Trim()),("@track",input.TrackStock),("@wh",input.WarehouseID),("@active",input.IsActive),("@rate",input.CommissionRate),("@actor",Actor));
            return new{id=saved};
        },ct);
    }

    [HttpGet("wallets")]
    public async Task<IActionResult> Wallets([FromQuery]int page=1,[FromQuery]int pageSize=10,[FromQuery]string? search=null,CancellationToken ct=default)
    {
        await using var db=await Open(ct);if(await Guard(db,"53007","VIEW",ct,schoolOnly:true) is {} f)return f;
        page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        const string where=" FROM dbo.TDSCStudent S LEFT JOIN dbo.TDSFWallet W ON W.CompanyID=S.CompanyID AND W.StudentID=S.StudentID WHERE S.CompanyID=@co AND (@q IS NULL OR S.StudentCode LIKE N'%'+@q+N'%' OR S.FirstName LIKE N'%'+@q+N'%')";
        var rows=await FoodDb.Rows(db,null,"SELECT S.StudentID id,S.StudentCode code,CONCAT(S.FirstName,N' ',S.LastName) name,COALESCE(W.Balance,0) balance"+where+" ORDER BY S.StudentCode OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,("@co",Company),("@q",search),("@offset",(page-1)*pageSize),("@size",pageSize));
        var total=await FoodDb.Id(db,null,"SELECT COUNT(*)"+where,ct,("@co",Company),("@q",search));
        return Ok(new{rows,total,page,pageSize});
    }

    [HttpGet("wallets/{student:long}/entries")]
    public async Task<IActionResult> WalletEntries(long student,[FromQuery]int page=1,[FromQuery]int pageSize=20,CancellationToken ct=default)
    {
        await using var db=await Open(ct);if(await Guard(db,"53007","VIEW",ct,schoolOnly:true) is {} f)return f;
        if(await FoodDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDSCStudent WHERE CompanyID=@co AND StudentID=@student",ct,("@co",Company),("@student",student))!=1)
            return NotFound(new{message="ไม่พบนักเรียน",description="เลือกนักเรียนในโรงเรียนนี้"});
        page=Math.Clamp(page,1,100000);pageSize=Math.Clamp(pageSize,1,100);
        var rows=await FoodDb.Rows(db,null,"SELECT LedgerID id,EntryType kind,Amount amount,BalanceAfter balance,ReferenceNo referenceNo,Reason reason,PaymentMethod paymentMethod,CreatedAt date FROM dbo.TDSFWalletLedger WHERE CompanyID=@co AND StudentID=@student ORDER BY LedgerID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY",ct,
            ("@co",Company),("@student",student),("@offset",(page-1)*pageSize),("@size",pageSize));
        var total=await FoodDb.Id(db,null,"SELECT COUNT(*) FROM dbo.TDSFWalletLedger WHERE CompanyID=@co AND StudentID=@student",ct,("@co",Company),("@student",student));
        return Ok(new{rows,total,page,pageSize});
    }

    [HttpPost("wallets/{student:long}/entries")]
    public async Task<IActionResult> WalletEntry(long student,WalletInput input,CancellationToken ct)
    {
        if(input.Kind is not ("TOPUP" or "ADJUST")||input.Amount==0||input.Amount!=SchoolFoodRules.Money(input.Amount)
            ||(input.Kind=="TOPUP"&&input.Amount<0)||string.IsNullOrWhiteSpace(input.ReferenceNo)||input.ReferenceNo.Length>100
            ||(input.Kind=="ADJUST"&&string.IsNullOrWhiteSpace(input.Reason))||input.Reason?.Length>500
            ||input.PaymentMethod is not ("CASH" or "TRANSFER"))
            return Bad("ระบุยอดเงิน เลขอ้างอิง วิธีรับเงิน และเหตุผลสำหรับการปรับยอดให้ครบ");
        await using var db=await Open(ct);if(await Guard(db,"53007",input.Kind,ct,schoolOnly:true) is {} f)return f;
        return await Transact(db,input.RequestKey,input.Kind,new{student,input},async(tx,op)=>{
            var balance=await FoodTransaction.Wallet(db,tx,Company,student,op,Actor,input.Amount,input.Kind,input.ReferenceNo,input.Reason,input.PaymentMethod,ct);
            return new{studentId=student,balance};
        },ct);
    }

    [HttpPost("identify")]
    public async Task<IActionResult> Identify(IdentifyInput input,CancellationToken ct)
    {
        if(input.Kind is not ("CARD" or "QR") || string.IsNullOrWhiteSpace(input.Value)||input.Value.Length>256)
            return Bad("ใช้รหัสบัตรหรือ QR; ลายนิ้วมือต้องผ่าน Adapter ของอุปกรณ์ที่ลงทะเบียน");
        await using var db=await Open(ct);if(await Guard(db,"53008","SALE",ct,input.ShopID) is {} f)return f;
        var hash=SHA256.HashData(Encoding.UTF8.GetBytes(input.Value.Trim()));
        var rows=await FoodDb.Rows(db,null,"SELECT S.StudentID id,S.StudentCode code,CONCAT(S.FirstName,N' ',S.LastName) name,C.RoomName classroom,COALESCE(W.Balance,0) balance FROM dbo.TDSFStudentIdentifier I JOIN dbo.TDSCStudent S ON S.CompanyID=I.CompanyID AND S.StudentID=I.StudentID AND S.IsActive=1 JOIN dbo.TDSCClassroom C ON C.CompanyID=S.CompanyID AND C.ClassroomID=S.ClassroomID LEFT JOIN dbo.TDSFWallet W ON W.CompanyID=S.CompanyID AND W.StudentID=S.StudentID WHERE I.CompanyID=@co AND I.Kind=@kind AND I.IdentifierHash=@hash AND I.IsActive=1",ct,("@co",Company),("@kind",input.Kind),("@hash",hash));
        return rows.Count==1?Ok(rows[0]):NotFound(new{message="ไม่สามารถใช้บัตรนี้ได้",description="ไม่พบบัตรหรือบัตรถูกระงับ กรุณาติดต่อโรงเรียน"});
    }
}

public sealed record SettingInput(Guid RequestKey,bool IsEnabled,bool CommissionEnabled,decimal DefaultCommissionRate);
public sealed record ShopInput(Guid RequestKey,string Code,string Name,bool TrackStock,long? WarehouseID,bool IsActive,decimal? CommissionRate);
public sealed record WalletInput(Guid RequestKey,string Kind,decimal Amount,string ReferenceNo,string PaymentMethod,string? Reason);
public sealed record IdentifyInput(long ShopID,string Kind,string Value);
