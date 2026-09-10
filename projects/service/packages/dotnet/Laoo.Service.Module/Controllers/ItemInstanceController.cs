using System.Data;
using LaooServiceModule.Infrastructure;
using LaooServiceModule.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;

[ApiController, Authorize]
[LaooServiceModule.Security.RequireCompanyProject("LAOO")]
[TypeFilter(typeof(ItemProjectExceptionFilter))]
[Route("api/company/item-instances")]
public sealed class ItemInstanceController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode="08006";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token){await using var c=await Open(token);return Ok(new{view=await Can(c,"VIEW",token),create=false,edit=await Can(c,"EDIT",token),delete=false});}

    [HttpGet]
    public async Task<IActionResult> List([FromQuery]string? search,[FromQuery]string? statusCode,[FromQuery]long? warehouseID,[FromQuery]long? itemID,CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"VIEW",token))return Forbid();
        var sql=$"""
SELECT X.ItemInstanceID,X.ItemID,I.ItemCode,I.ItemName,X.SerialNo,X.StatusCode,X.WarehouseID,W.WarehouseCode,W.WarehouseName,
       X.CustomerID,X.BranchID,X.BuildingID,X.FloorID,X.RoomID,X.UpdateDate,X.CreateDate
FROM dbo.TDIVItemInstance X
JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID
LEFT JOIN dbo.TDIVWarehouse W ON W.WarehouseID=X.WarehouseID AND W.CompanyID=X.CompanyID
LEFT JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1
WHERE X.CompanyID=@company
 AND (@search=N'' OR X.SerialNo LIKE @like OR I.ItemCode LIKE @like OR I.ItemName LIKE @like)
 AND (@status=N'' OR X.StatusCode=@status)
 AND (@warehouse IS NULL OR X.WarehouseID=@warehouse)
 AND (@item IS NULL OR X.ItemID=@item)
 AND (X.WarehouseID IS NULL OR {WarehouseAccessService.WarehouseAliasPredicate})
AND {ItemProjectAccess.ItemAliasPredicate}
ORDER BY X.UpdateDate DESC,X.ItemInstanceID DESC;
""";
        await using var command=new SqlCommand(sql,c);var q=search?.Trim()??"";Add(command,"@company",SqlDbType.BigInt,CompanyId());Add(command,"@user",SqlDbType.BigInt,UserId());Add(command,"@search",SqlDbType.NVarChar,q,200);Add(command,"@like",SqlDbType.NVarChar,$"%{q}%",210);Add(command,"@status",SqlDbType.NVarChar,statusCode?.Trim().ToUpperInvariant()??"",20);Add(command,"@warehouse",SqlDbType.BigInt,warehouseID);Add(command,"@item",SqlDbType.BigInt,itemID);
        var rows=new List<object>();await using var reader=await command.ExecuteReaderAsync(token);while(await reader.ReadAsync(token))rows.Add(new{itemInstanceID=reader.GetInt64(0),itemID=reader.GetInt64(1),itemCode=reader.GetString(2),itemName=reader.GetString(3),serialNo=reader.GetString(4),statusCode=reader.GetString(5),warehouseID=Long(reader,6),warehouseCode=Text(reader,7),warehouseName=Text(reader,8),customerID=Long(reader,9),branchID=Long(reader,10),buildingID=Long(reader,11),floorID=Long(reader,12),roomID=Long(reader,13),updateDate=reader.IsDBNull(14)?null:(DateTime?)reader.GetDateTime(14),createDate=reader.GetDateTime(15)});return Ok(rows);
    }

    [HttpGet("{id:long}/history")]
    public async Task<IActionResult> History(long id,CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"VIEW",token))return Forbid();
        await ItemProjectAccess.EnsureInstanceAsync(c,null,CompanyId(),id,token);
        await using var location=new SqlCommand("SELECT ISNULL(WarehouseID,0) FROM dbo.TDIVItemInstance WHERE ItemInstanceID=@id AND CompanyID=@company",c);Add(location,"@company",SqlDbType.BigInt,CompanyId());Add(location,"@id",SqlDbType.BigInt,id);var warehouseValue=await location.ExecuteScalarAsync(token);if(warehouseValue is null||warehouseValue==DBNull.Value)return NotFound();var warehouseID=Convert.ToInt64(warehouseValue);if(warehouseID>0&&!await WarehouseAccessService.CanAccessAsync(c,null,CompanyId(),UserId(),warehouseID,token))return StatusCode(StatusCodes.Status403Forbidden,new{message="ไม่มีสิทธิ์เข้าถึงคลังสินค้า",description="Serial/อุปกรณ์นี้อยู่ในคลังที่ผู้ใช้ไม่มีสิทธิ์เข้าถึง"});
        const string sql="SELECT H.ItemInstanceHistoryID,H.FromStatusCode,H.ToStatusCode,H.WarehouseID,H.CustomerID,H.BranchID,H.BuildingID,H.FloorID,H.RoomID,H.DocumentType,H.DocumentID,H.DocumentDetailID,H.EventDate,H.Remark FROM dbo.TDIVItemInstanceHistory H JOIN dbo.TDIVItemInstance I ON I.ItemInstanceID=H.ItemInstanceID AND I.CompanyID=H.CompanyID WHERE H.CompanyID=@company AND H.ItemInstanceID=@id ORDER BY H.EventDate,H.ItemInstanceHistoryID";
        await using var command=new SqlCommand(sql,c);Add(command,"@company",SqlDbType.BigInt,CompanyId());Add(command,"@id",SqlDbType.BigInt,id);var rows=new List<object>();await using var reader=await command.ExecuteReaderAsync(token);while(await reader.ReadAsync(token))rows.Add(new{historyID=reader.GetInt64(0),fromStatusCode=Text(reader,1),toStatusCode=reader.GetString(2),warehouseID=Long(reader,3),customerID=Long(reader,4),branchID=Long(reader,5),buildingID=Long(reader,6),floorID=Long(reader,7),roomID=Long(reader,8),documentType=reader.GetString(9),documentID=reader.GetInt64(10),documentDetailID=reader.GetInt64(11),eventDate=reader.GetDateTime(12),remark=Text(reader,13)});return Ok(rows);
    }

    [HttpPut("{id:long}/location")]
    public async Task<IActionResult> UpdateLocation(long id,ItemInstanceLocationRequest request,CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"EDIT",token))return Forbid();var status=request.StatusCode?.Trim().ToUpperInvariant()??"";var statuses=new HashSet<string>(StringComparer.OrdinalIgnoreCase){"IN_STOCK","RESERVED","ISSUED","SOLD","INSTALLED","REPAIR","RETIRED"};if(!statuses.Contains(status))return BadRequest(new{message="สถานะ Serial ไม่ถูกต้อง",description="กรุณาเลือกสถานะจากรายการมาตรฐาน"});if(status=="INSTALLED"&&(!request.BranchID.HasValue||!request.BuildingID.HasValue||!request.FloorID.HasValue||!request.RoomID.HasValue))return BadRequest(new{message="ตำแหน่งติดตั้งไม่ครบ",description="Serial สถานะ INSTALLED ต้องระบุสาขา อาคาร ชั้น และห้อง"});if(status=="SOLD"&&!request.CustomerID.HasValue)return BadRequest(new{message="ลูกค้าไม่ครบ",description="Serial สถานะ SOLD ต้องระบุ Customer"});
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            await ItemProjectAccess.EnsureInstanceAsync(c,tx,CompanyId(),id,token);
            await using var current=new SqlCommand("SELECT StatusCode,WarehouseID FROM dbo.TDIVItemInstance WITH(UPDLOCK,HOLDLOCK) WHERE ItemInstanceID=@id AND CompanyID=@company",c,tx);Add(current,"@id",SqlDbType.BigInt,id);Add(current,"@company",SqlDbType.BigInt,CompanyId());string from;long? currentWarehouseID;await using(var currentReader=await current.ExecuteReaderAsync(token)){if(!await currentReader.ReadAsync(token))return NotFound();from=currentReader.GetString(0);currentWarehouseID=Long(currentReader,1);}if(currentWarehouseID.HasValue&&!await WarehouseAccessService.CanAccessAsync(c,tx,CompanyId(),UserId(),currentWarehouseID.Value,token))return StatusCode(StatusCodes.Status403Forbidden,new{message="ไม่มีสิทธิ์เข้าถึงคลังสินค้า",description="Serial/อุปกรณ์นี้อยู่ในคลังที่ผู้ใช้ไม่มีสิทธิ์เข้าถึง"});if(request.BranchID.HasValue){await using var branch=new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADBranch WHERE BranchID=@branch AND CompanyID=@company) THEN 1 ELSE 0 END",c,tx);Add(branch,"@branch",SqlDbType.BigInt,request.BranchID);Add(branch,"@company",SqlDbType.BigInt,CompanyId());if(Convert.ToInt32(await branch.ExecuteScalarAsync(token))!=1)return BadRequest(new{message="สาขาไม่ถูกต้อง",description="สาขาต้องอยู่ภายใน Company เดียวกัน"});}
            const string update="UPDATE dbo.TDIVItemInstance SET StatusCode=@status,CustomerID=@customer,BranchID=@branch,BuildingID=@building,FloorID=@floor,RoomID=@room,WarehouseID=CASE WHEN @status=N'IN_STOCK' THEN WarehouseID ELSE NULL END,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE ItemInstanceID=@id AND CompanyID=@company";await using var command=new SqlCommand(update,c,tx);Bind(command,id,status,request);await command.ExecuteNonQueryAsync(token);
            const string history="INSERT dbo.TDIVItemInstanceHistory(CompanyID,ItemInstanceID,FromStatusCode,ToStatusCode,CustomerID,BranchID,BuildingID,FloorID,RoomID,DocumentType,DocumentID,DocumentDetailID,Remark,CreatedBy) VALUES(@company,@id,@from,@status,@customer,@branch,@building,@floor,@room,N'MANUAL_LOCATION',@id,@id,@remark,@user)";await using var eventCommand=new SqlCommand(history,c,tx);Bind(eventCommand,id,status,request);Add(eventCommand,"@from",SqlDbType.NVarChar,from,20);await eventCommand.ExecuteNonQueryAsync(token);await tx.CommitAsync(token);return Ok(new{message="อัปเดตตำแหน่ง Serial แล้ว"});
        }
        catch(Exception ex) when (ex is not ItemProjectDeniedException){try{await tx.RollbackAsync(token);}catch{}return BadRequest(new{message="อัปเดต Serial ไม่สำเร็จ",description=ex.Message});}
    }

    private void Bind(SqlCommand c,long id,string status,ItemInstanceLocationRequest r){Add(c,"@company",SqlDbType.BigInt,CompanyId());Add(c,"@id",SqlDbType.BigInt,id);Add(c,"@status",SqlDbType.NVarChar,status,20);Add(c,"@customer",SqlDbType.BigInt,r.CustomerID);Add(c,"@branch",SqlDbType.BigInt,r.BranchID);Add(c,"@building",SqlDbType.BigInt,r.BuildingID);Add(c,"@floor",SqlDbType.BigInt,r.FloorID);Add(c,"@room",SqlDbType.BigInt,r.RoomID);Add(c,"@remark",SqlDbType.NVarChar,r.Remark?.Trim(),500);Add(c,"@user",SqlDbType.BigInt,UserId());}
    private Task<bool> Can(SqlConnection c,string action,CancellationToken t)=>InventoryControllerSupport.CanAsync(c,User,ScreenCode,action,t);private Task<SqlConnection> Open(CancellationToken t)=>InventoryControllerSupport.OpenAsync(configuration,t);private long CompanyId()=>InventoryControllerSupport.ClaimId(User,"company_id");private long UserId()=>InventoryControllerSupport.ClaimId(User,"user_id");private static void Add(SqlCommand c,string n,SqlDbType t,object? v,int s=0)=>InventoryControllerSupport.Add(c,n,t,v,s);private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i);private static long? Long(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetInt64(i);
}
