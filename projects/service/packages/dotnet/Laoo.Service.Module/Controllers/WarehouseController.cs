using System.Data;
using LaooServiceModule.Infrastructure;
using LaooServiceModule.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Controllers;

[ApiController, Authorize]
[LaooServiceModule.Security.RequireCompanyProject("LAOO")]
[Route("api/company/warehouses")]
public sealed class WarehouseController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "08004";

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var connection = await Open(token);
        return Ok(new { view=await Can(connection,"VIEW",token), create=await Can(connection,"CREATE",token), edit=await Can(connection,"EDIT",token), delete=await Can(connection,"DELETE",token) });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, CancellationToken token)
    {
        await using var connection = await Open(token);
        if (!await Can(connection,"VIEW",token)) return Forbid();
        var canManage = await Can(connection,"EDIT",token);
        var sql = $"""
SELECT W.WarehouseID,W.BranchID,W.WarehouseCode,W.WarehouseName,W.IsDefault,W.IsActive,
       COALESCE(CONVERT(nvarchar(200),B.BranchNameTH),CONVERT(nvarchar(200),B.BranchCode),N'') BranchName,
       W.AccessModeCode
FROM dbo.TDIVWarehouse W
LEFT JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID
WHERE W.CompanyID=@company AND (@search=N'' OR W.WarehouseCode LIKE @like OR W.WarehouseName LIKE @like)
  AND (@manage=1 OR {WarehouseAccessService.WarehouseAliasPredicate})
ORDER BY B.BranchCode,W.WarehouseCode,W.WarehouseName;
""";
        await using var command = new SqlCommand(sql,connection);
        var value=search?.Trim()??string.Empty; var companyId=CompanyId(); var userId=UserId();
        Add(command,"@company",SqlDbType.BigInt,companyId); Add(command,"@user",SqlDbType.BigInt,userId); Add(command,"@manage",SqlDbType.Bit,canManage); Add(command,"@search",SqlDbType.NVarChar,value,200); Add(command,"@like",SqlDbType.NVarChar,$"%{value}%",210);
        var rows=new List<object>();
        await using var reader=await command.ExecuteReaderAsync(token);
        while(await reader.ReadAsync(token)) rows.Add(new { warehouseID=reader.GetInt64(0),branchID=reader.GetInt64(1),warehouseCode=reader.GetString(2),warehouseName=reader.GetString(3),isDefault=reader.GetBoolean(4),isActive=reader.GetBoolean(5),branchName=reader.GetString(6),accessModeCode=reader.GetString(7) });
        return Ok(rows);
    }

    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(CancellationToken token)
    {
        await using var connection=await Open(token);
        if(!await Can(connection,"VIEW",token)) return Forbid();
        const string sql="SELECT BranchID,BranchCode,BranchNameTH FROM dbo.TDADBranch WHERE CompanyID=@company AND IsActive=1 ORDER BY BranchCode";
        await using var command=new SqlCommand(sql,connection);Add(command,"@company",SqlDbType.BigInt,CompanyId());var rows=new List<object>();await using var reader=await command.ExecuteReaderAsync(token);while(await reader.ReadAsync(token))rows.Add(new{branchID=reader.GetInt64(0),branchCode=reader.GetString(1),branchName=reader.GetString(2)});return Ok(rows);
    }

    [HttpGet("{id:long}/access")]
    public async Task<IActionResult> GetAccess(long id,CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"EDIT",token))return Forbid();var company=CompanyId();
        const string warehouseSql="SELECT W.WarehouseCode,W.WarehouseName,W.AccessModeCode,W.BranchID FROM dbo.TDIVWarehouse W WHERE W.WarehouseID=@id AND W.CompanyID=@company";
        await using var warehouse=new SqlCommand(warehouseSql,c);Add(warehouse,"@id",SqlDbType.BigInt,id);Add(warehouse,"@company",SqlDbType.BigInt,company);await using var wr=await warehouse.ExecuteReaderAsync(token);
        if(!await wr.ReadAsync(token))return NotFound(new{message="ไม่พบคลังสินค้า",description="คลังไม่อยู่ใน Company ปัจจุบัน"});var code=wr.GetString(0);var name=wr.GetString(1);var mode=wr.GetString(2);var branchId=wr.GetInt64(3);await wr.DisposeAsync();
        const string userSql="""
SELECT U.UserID,U.Username,COALESCE(NULLIF(P.FullName,N''),NULLIF(U.DisplayName,N''),U.Username) DisplayName,
       CONVERT(bit,CASE WHEN UW.UserWarehouseID IS NULL THEN 0 ELSE 1 END) IsSelected
FROM dbo.TDADUser U
LEFT JOIN dbo.TDADPerson P ON P.PersonID=U.PersonID AND P.CompanyID=U.CompanyID
LEFT JOIN dbo.TDIVUserWarehouse UW ON UW.UserID=U.UserID AND UW.CompanyID=U.CompanyID AND UW.WarehouseID=@id AND UW.IsActive=1
LEFT JOIN dbo.TDADUserBranch UB ON UB.UserID=U.UserID AND UB.CompanyID=U.CompanyID AND UB.BranchID=@branch AND UB.IsActive=1
INNER JOIN dbo.TDADBranch B ON B.BranchID=@branch AND B.CompanyID=U.CompanyID AND B.IsActive=1
WHERE U.CompanyID=@company AND U.IsActive=1
  AND (U.IsCompanyAdmin=1 OR B.AccessModeCode=N'ALL' OR UB.UserBranchID IS NOT NULL)
ORDER BY DisplayName,U.Username;
""";
        await using var command=new SqlCommand(userSql,c);Add(command,"@id",SqlDbType.BigInt,id);Add(command,"@branch",SqlDbType.BigInt,branchId);Add(command,"@company",SqlDbType.BigInt,company);var users=new List<object>();await using var reader=await command.ExecuteReaderAsync(token);while(await reader.ReadAsync(token))users.Add(new{userId=reader.GetInt64(0),username=reader.GetString(1),displayName=reader.GetString(2),isSelected=reader.GetBoolean(3)});
        return Ok(new{warehouseId=id,warehouseCode=code,warehouseName=name,branchId,accessModeCode=mode,users});
    }

    [HttpPut("{id:long}/access")]
    public async Task<IActionResult> UpdateAccess(long id,WarehouseAccessRequest request,CancellationToken token)
    {
        await using var c=await Open(token);if(!await Can(c,"EDIT",token))return Forbid();var company=CompanyId();var user=UserId();var mode=request.AccessModeCode?.Trim().ToUpperInvariant();
        if(mode is not("INHERIT" or "RESTRICTED"))return BadRequest(new{message="รูปแบบสิทธิ์ไม่ถูกต้อง",description="กรุณาเลือกสืบทอดจากสาขาหรือเฉพาะผู้เลือก"});var ids=(request.UserIds??Array.Empty<long>()).Where(x=>x>0).Distinct().ToArray();await using var tx=(SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            long branchId;await using(var scope=new SqlCommand("SELECT BranchID FROM dbo.TDIVWarehouse WHERE WarehouseID=@id AND CompanyID=@company",c,tx)){Add(scope,"@id",SqlDbType.BigInt,id);Add(scope,"@company",SqlDbType.BigInt,company);var value=await scope.ExecuteScalarAsync(token);if(value is null)return NotFound(new{message="ไม่พบคลังสินค้า",description="คลังไม่อยู่ใน Company ปัจจุบัน"});branchId=Convert.ToInt64(value);}
            if(mode=="RESTRICTED")foreach(var selectedUser in ids){await using var validate=new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser U INNER JOIN dbo.TDADBranch B ON B.BranchID=@branch AND B.CompanyID=U.CompanyID LEFT JOIN dbo.TDADUserBranch UB ON UB.CompanyID=U.CompanyID AND UB.BranchID=B.BranchID AND UB.UserID=U.UserID AND UB.IsActive=1 WHERE U.UserID=@selectedUser AND U.CompanyID=@company AND U.IsActive=1 AND (U.IsCompanyAdmin=1 OR B.AccessModeCode=N'ALL' OR UB.UserBranchID IS NOT NULL)) THEN 1 ELSE 0 END",c,tx);Add(validate,"@branch",SqlDbType.BigInt,branchId);Add(validate,"@selectedUser",SqlDbType.BigInt,selectedUser);Add(validate,"@company",SqlDbType.BigInt,company);if(Convert.ToInt32(await validate.ExecuteScalarAsync(token))!=1)return BadRequest(new{message="ผู้ใช้ไม่ถูกต้อง",description="มีผู้ใช้ที่ไม่ผ่านสิทธิ์สาขา ปิดใช้งาน หรืออยู่นอก Company"});}
            await using(var update=new SqlCommand("UPDATE dbo.TDIVWarehouse SET AccessModeCode=@mode,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE WarehouseID=@id AND CompanyID=@company",c,tx)){Add(update,"@mode",SqlDbType.NVarChar,mode,20);Add(update,"@user",SqlDbType.BigInt,user);Add(update,"@id",SqlDbType.BigInt,id);Add(update,"@company",SqlDbType.BigInt,company);await update.ExecuteNonQueryAsync(token);}
            if(mode=="RESTRICTED")
            {
                await using(var disable=new SqlCommand("UPDATE dbo.TDIVUserWarehouse SET IsActive=0,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE WarehouseID=@id AND CompanyID=@company",c,tx)){Add(disable,"@user",SqlDbType.BigInt,user);Add(disable,"@id",SqlDbType.BigInt,id);Add(disable,"@company",SqlDbType.BigInt,company);await disable.ExecuteNonQueryAsync(token);}
                foreach(var selectedUser in ids){const string upsert="UPDATE dbo.TDIVUserWarehouse SET IsActive=1,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@actor WHERE WarehouseID=@id AND CompanyID=@company AND UserID=@selectedUser; IF @@ROWCOUNT=0 INSERT dbo.TDIVUserWarehouse(CompanyID,WarehouseID,UserID,IsActive,CreatedBy) VALUES(@company,@id,@selectedUser,1,@actor)";await using var command=new SqlCommand(upsert,c,tx);Add(command,"@actor",SqlDbType.BigInt,user);Add(command,"@id",SqlDbType.BigInt,id);Add(command,"@company",SqlDbType.BigInt,company);Add(command,"@selectedUser",SqlDbType.BigInt,selectedUser);await command.ExecuteNonQueryAsync(token);}
            }
            await tx.CommitAsync(token);return Ok(new{warehouseId=id,accessModeCode=mode,userIds=ids});
        }
        catch(SqlException ex){try{await tx.RollbackAsync(token);}catch{}return BadRequest(new{message="บันทึกสิทธิ์คลังไม่สำเร็จ",description=ex.Number is 2601 or 2627?"พบความสัมพันธ์ผู้ใช้กับคลังซ้ำ":ex.Message});}
    }

    [HttpPost]
    public Task<IActionResult> Create(WarehouseUpsertRequest request,CancellationToken token)=>Save(null,request,token);

    [HttpPut("{id:long}")]
    public Task<IActionResult> Update(long id,WarehouseUpsertRequest request,CancellationToken token)=>Save(id,request,token);

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id,CancellationToken token)
    {
        await using var connection=await Open(token);
        if(!await Can(connection,"DELETE",token)) return Forbid();
        const string sql="UPDATE dbo.TDIVWarehouse SET IsActive=0,IsDefault=0,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE WarehouseID=@id AND CompanyID=@company AND NOT EXISTS(SELECT 1 FROM dbo.TDIVStockBalance B WHERE B.CompanyID=@company AND B.WarehouseID=@id AND B.Quantity<>0)";
        await using var command=new SqlCommand(sql,connection);
        Add(command,"@user",SqlDbType.BigInt,UserId()); Add(command,"@id",SqlDbType.BigInt,id); Add(command,"@company",SqlDbType.BigInt,CompanyId());
        return await command.ExecuteNonQueryAsync(token)==1 ? NoContent() : BadRequest(new {message="ไม่สามารถปิดคลังได้",description="ไม่พบคลังใน Company นี้ หรือคลังยังมียอดคงเหลือ"});
    }

    private async Task<IActionResult> Save(long? id,WarehouseUpsertRequest request,CancellationToken token)
    {
        await using var connection=await Open(token);
        if(!await Can(connection,id.HasValue?"EDIT":"CREATE",token)) return Forbid();
        var code=request.WarehouseCode?.Trim().ToUpperInvariant()??string.Empty;
        var name=request.WarehouseName?.Trim()??string.Empty;
        if(code.Length==0||name.Length==0) return BadRequest(new {message="ข้อมูลคลังไม่ครบ",description="กรุณาระบุรหัสและชื่อคลัง"});
        await using var transaction=(SqlTransaction)await connection.BeginTransactionAsync(token);
        try
        {
            await using(var branch=new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADBranch WHERE BranchID=@branch AND CompanyID=@company AND IsActive=1) THEN 1 ELSE 0 END",connection,transaction))
            {
                Add(branch,"@branch",SqlDbType.BigInt,request.BranchID); Add(branch,"@company",SqlDbType.BigInt,CompanyId());
                if(Convert.ToInt32(await branch.ExecuteScalarAsync(token))!=1) return BadRequest(new {message="สาขาไม่ถูกต้อง",description="กรุณาเลือกสาขาที่เปิดใช้งานภายใน Company เดียวกัน"});
            }
            if(request.IsDefault)
            {
                await using var clear=new SqlCommand("UPDATE dbo.TDIVWarehouse SET IsDefault=0,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE CompanyID=@company AND IsDefault=1 AND (@id IS NULL OR WarehouseID<>@id)",connection,transaction);
                Add(clear,"@user",SqlDbType.BigInt,UserId()); Add(clear,"@company",SqlDbType.BigInt,CompanyId()); Add(clear,"@id",SqlDbType.BigInt,id); await clear.ExecuteNonQueryAsync(token);
            }
            long warehouseId;
            if(id.HasValue)
            {
                const string sql="UPDATE dbo.TDIVWarehouse SET BranchID=@branch,WarehouseCode=@code,WarehouseName=@name,IsDefault=@default,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE WarehouseID=@id AND CompanyID=@company";
                await using var command=new SqlCommand(sql,connection,transaction); Bind(command,request,code,name); Add(command,"@id",SqlDbType.BigInt,id.Value);
                if(await command.ExecuteNonQueryAsync(token)!=1) return NotFound(); warehouseId=id.Value;
            }
            else
            {
                const string sql="INSERT dbo.TDIVWarehouse(CompanyID,BranchID,WarehouseCode,WarehouseName,IsDefault,IsActive,CreatedBy) OUTPUT INSERTED.WarehouseID VALUES(@company,@branch,@code,@name,@default,@active,@user)";
                await using var command=new SqlCommand(sql,connection,transaction); Bind(command,request,code,name); warehouseId=Convert.ToInt64(await command.ExecuteScalarAsync(token));
            }
            await transaction.CommitAsync(token); return Ok(new {warehouseID=warehouseId});
        }
        catch(SqlException ex)
        {
            try{await transaction.RollbackAsync(token);}catch{}
            return BadRequest(new {message="บันทึกคลังไม่สำเร็จ",description=ex.Number is 2601 or 2627?"รหัสคลังซ้ำใน Company เดียวกัน":ex.Message});
        }
    }

    private void Bind(SqlCommand command,WarehouseUpsertRequest request,string code,string name){Add(command,"@company",SqlDbType.BigInt,CompanyId());Add(command,"@branch",SqlDbType.BigInt,request.BranchID);Add(command,"@code",SqlDbType.NVarChar,code,50);Add(command,"@name",SqlDbType.NVarChar,name,200);Add(command,"@default",SqlDbType.Bit,request.IsDefault);Add(command,"@active",SqlDbType.Bit,request.IsActive);Add(command,"@user",SqlDbType.BigInt,UserId());}
    private Task<bool> Can(SqlConnection c,string action,CancellationToken t)=>InventoryControllerSupport.CanAsync(c,User,ScreenCode,action,t);
    private Task<SqlConnection> Open(CancellationToken t)=>InventoryControllerSupport.OpenAsync(configuration,t);
    private long CompanyId()=>InventoryControllerSupport.ClaimId(User,"company_id");
    private long UserId()=>InventoryControllerSupport.ClaimId(User,"user_id");
    private static void Add(SqlCommand c,string n,SqlDbType t,object? v,int s=0)=>InventoryControllerSupport.Add(c,n,t,v,s);
}
