using System.Security.Claims;
using Laoo.Shared.Contracts;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

public sealed record SiteCustomerLogin(string CompanyCode,string Email,string Password);
public sealed record SiteCustomerRegister(long ProjectId,string Email,string Password);
public sealed record SiteCustomerGrant(long ProjectId,long CustomerAccountId);

[ApiController,Route("api/site/customer")]
public sealed class SiteCustomerAuthController(
    IConfiguration config,PasswordService passwords,JwtTokenService tokens) : ControllerBase
{
    async Task<SqlConnection> Open(CancellationToken ct)
    {
        var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        return db;
    }
    static bool PasswordValid(string? value)=>value is {Length: >=12 and <=256}
        &&value.Any(char.IsUpper)&&value.Any(char.IsLower)&&value.Any(char.IsDigit)
        &&value.Any(ch=>!char.IsLetterOrDigit(ch));
    static bool EmailValid(string? value)=>!string.IsNullOrWhiteSpace(value)&&value.Length<=320
        &&value.Contains('@')&&!value.Contains(' ');
    static SqlCommand Cmd(SqlConnection db,SqlTransaction? tx,string sql,params (string,object?)[] args)
    {
        var command=new SqlCommand(sql,db,tx);
        foreach(var(key,value) in args)command.Parameters.AddWithValue(key,value??DBNull.Value);
        return command;
    }
    static async Task<bool> Subscription(SqlConnection db,long company,CancellationToken ct)
    {
        await using var command=Cmd(db,null,@"SELECT COUNT(*) FROM dbo.TDADCompanyProjectSubscription S
JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_SITE' AND P.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.PartnerID=S.PartnerID AND C.IsActive=1
WHERE S.CompanyID=@company AND S.IsCurrent=1 AND S.StatusCode IN(N'ACTIVE',N'TRIAL')
AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))",("@company",company));
        return Convert.ToInt64(await command.ExecuteScalarAsync(ct))>0;
    }
    static IActionResult Failed(ControllerBase c)=>c.Unauthorized(new{message="เข้าสู่ระบบไม่สำเร็จ",
        description="ตรวจสอบรหัสบริษัท อีเมล และรหัสผ่าน"});
    async Task<(long Company,long Actor)?> Staff(SqlConnection db,CancellationToken ct)
    {
        if(User.FindFirstValue("user_type")!="COMPANY_USER"
            ||!long.TryParse(User.FindFirstValue("company_id"),out var company)
            ||!long.TryParse(User.FindFirstValue("user_id"),out var actor)
            ||company<=0||actor<=0)return null;
        if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"63002","EDIT",ct))return null;
        return(company,actor);
    }
    static async Task<long> ProjectCustomer(SqlConnection db,long company,long actor,long project,CancellationToken ct)
    {
        await using var command=Cmd(db,null,@"SELECT P.CustomerID FROM dbo.TDSIProject P
WHERE P.CompanyID=@c AND P.SiteProjectID=@project AND P.StatusCode=N'ACTIVE'
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch B WHERE B.CompanyID=@c AND B.UserID=@actor AND B.BranchID=P.BranchID AND B.IsActive=1))",
            ("@c",company),("@actor",actor),("@project",project));
        return Convert.ToInt64(await command.ExecuteScalarAsync(ct)??0L);
    }

    [AllowAnonymous,EnableRateLimiting("authentication"),HttpPost("login")]
    public async Task<IActionResult> Login(SiteCustomerLogin input,CancellationToken ct)
    {
        if(string.IsNullOrWhiteSpace(input.CompanyCode)||input.CompanyCode.Length>50
            ||!EmailValid(input.Email)||string.IsNullOrWhiteSpace(input.Password)||input.Password.Length>256)
            return Failed(this);
        await using var db=await Open(ct);
        var email=input.Email.Trim().ToUpperInvariant();
        await using var command=Cmd(db,null,@"SELECT A.CustomerAccountID,A.CompanyID,A.EmailNormalized,A.PasswordHash,
A.CustomerID,P.ProjectID FROM dbo.TDSICustomerAccount A
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=A.CompanyID AND C.CompanyCode=@code AND C.IsActive=1
JOIN dbo.TDARCustomer R ON R.CompanyID=A.CompanyID AND R.CustomerID=A.CustomerID AND R.IsActive=1
JOIN dbo.TDADProject P ON P.ProjectCode=N'LAOO_SITE' AND P.IsActive=1
WHERE A.EmailNormalized=@email AND A.IsActive=1",
            ("@code",input.CompanyCode.Trim()),("@email",email));
        await using var reader=await command.ExecuteReaderAsync(ct);
        if(!await reader.ReadAsync(ct))return Failed(this);
        var id=reader.GetInt64(0);var company=reader.GetInt64(1);var username=reader.GetString(2);
        var hash=reader.GetString(3);var customer=reader.GetInt64(4);var project=reader.GetInt64(5);
        await reader.DisposeAsync();
        bool verified;
        try{verified=passwords.VerifyPassword(username,hash,input.Password);}
        catch(FormatException){verified=false;}
        if(!verified||!await Subscription(db,company,ct))return Failed(this);
        await using var access=Cmd(db,null,@"SELECT COUNT(*) FROM dbo.TDSICustomerAccess A
JOIN dbo.TDSIProject P ON P.CompanyID=A.CompanyID AND P.SiteProjectID=A.SiteProjectID
WHERE A.CompanyID=@c AND A.CustomerAccountID=@id AND A.CustomerID=@customer
AND A.IsActive=1 AND P.StatusCode<>N'CANCELLED'",("@c",company),("@id",id),("@customer",customer));
        if(Convert.ToInt64(await access.ExecuteScalarAsync(ct))==0)return Failed(this);
        var token=tokens.CreateToken(new AuthenticatedUser($"site-customer:{company}:{id}",
            "SITE_CUSTOMER","SITE_CUSTOMER",null,null,null,null,company,null,project,
            "LAOO_SITE",username,username,false,SiteCustomerAccountId:id));
        return Ok(new{accessToken=token.AccessToken,expiresAt=token.ExpiresAt});
    }

    [Authorize,HttpPost("accounts")]
    public async Task<IActionResult> Register(SiteCustomerRegister input,CancellationToken ct)
    {
        if(input.ProjectId<=0||!EmailValid(input.Email)||!PasswordValid(input.Password))
            return BadRequest(new{message="ข้อมูลไม่ถูกต้อง",description="อีเมลต้องถูกต้องและรหัสผ่านยาวอย่างน้อย 12 ตัว มีพิมพ์ใหญ่ พิมพ์เล็ก ตัวเลข และสัญลักษณ์"});
        await using var db=await Open(ct);
        var staff=await Staff(db,ct);
        if(staff is null)return Forbid();
        var customer=await ProjectCustomer(db,staff.Value.Company,staff.Value.Actor,input.ProjectId,ct);
        if(customer==0)return NotFound();
        var email=input.Email.Trim().ToUpperInvariant();
        var hash=passwords.HashPassword(email,input.Password);
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(ct);
        try
        {
            long id;
            await using(var command=Cmd(db,tx,@"INSERT dbo.TDSICustomerAccount(CompanyID,CustomerID,EmailNormalized,PasswordHash)
VALUES(@c,@customer,@email,@hash);SELECT CONVERT(bigint,SCOPE_IDENTITY())",
                ("@c",staff.Value.Company),("@customer",customer),("@email",email),("@hash",hash)))
                id=Convert.ToInt64(await command.ExecuteScalarAsync(ct));
            await using(var grant=Cmd(db,tx,@"INSERT dbo.TDSICustomerAccess(CompanyID,SiteProjectID,CustomerID,CustomerAccountID,GrantedBy)
VALUES(@c,@project,@customer,@account,@actor)",("@c",staff.Value.Company),("@project",input.ProjectId),
                ("@customer",customer),("@account",id),("@actor",staff.Value.Actor)))
                await grant.ExecuteNonQueryAsync(ct);
            await tx.CommitAsync(ct);
            return Created($"/api/site/customer/accounts/{id}",new{id});
        }
        catch(SqlException e) when(e.Number is 2601 or 2627)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new{message="บัญชีลูกค้าซ้ำ",description="อีเมลนี้มีบัญชีในบริษัทแล้ว ให้เพิ่มสิทธิ์โครงการแทน"});
        }
        catch{await tx.RollbackAsync(ct);throw;}
    }

    [Authorize,HttpPost("access")]
    public async Task<IActionResult> Grant(SiteCustomerGrant input,CancellationToken ct)
    {
        if(input.ProjectId<=0||input.CustomerAccountId<=0)return BadRequest();
        await using var db=await Open(ct);
        var staff=await Staff(db,ct);
        if(staff is null)return Forbid();
        var customer=await ProjectCustomer(db,staff.Value.Company,staff.Value.Actor,input.ProjectId,ct);
        if(customer==0)return NotFound();
        await using var command=Cmd(db,null,@"IF EXISTS(SELECT 1 FROM dbo.TDSICustomerAccount
WHERE CompanyID=@c AND CustomerAccountID=@account AND CustomerID=@customer AND IsActive=1)
BEGIN
UPDATE dbo.TDSICustomerAccess SET IsActive=1 WHERE CompanyID=@c AND SiteProjectID=@project AND CustomerAccountID=@account;
IF @@ROWCOUNT=0 INSERT dbo.TDSICustomerAccess(CompanyID,SiteProjectID,CustomerID,CustomerAccountID,GrantedBy)
VALUES(@c,@project,@customer,@account,@actor);
SELECT 1;
END ELSE SELECT 0",("@c",staff.Value.Company),("@customer",customer),("@project",input.ProjectId),
            ("@account",input.CustomerAccountId),("@actor",staff.Value.Actor));
        var result=Convert.ToInt32(await command.ExecuteScalarAsync(ct));
        return result==0?NotFound():NoContent();
    }

    [Authorize,HttpGet("access")]
    public async Task<IActionResult> Access(CancellationToken ct)
    {
        await using var db=await Open(ct);
        if(User.FindFirstValue("user_type")!="COMPANY_USER"
            ||!long.TryParse(User.FindFirstValue("company_id"),out var company)
            ||!long.TryParse(User.FindFirstValue("user_id"),out var actor)
            ||!await CompanyMenuAccess.IsAllowedAsync(db,User,"63007","VIEW",ct))return Forbid();
        await using var command=Cmd(db,null,@"SELECT G.AccessID id,G.SiteProjectID projectId,P.ProjectName projectName,
G.CustomerAccountID accountId,A.EmailNormalized email,G.IsActive active
FROM dbo.TDSICustomerAccess G
JOIN dbo.TDSICustomerAccount A ON A.CompanyID=G.CompanyID AND A.CustomerAccountID=G.CustomerAccountID
JOIN dbo.TDSIProject P ON P.CompanyID=G.CompanyID AND P.SiteProjectID=G.SiteProjectID
WHERE G.CompanyID=@c AND
(EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch B WHERE B.CompanyID=@c AND B.UserID=@actor AND B.BranchID=P.BranchID AND B.IsActive=1))
ORDER BY G.AccessID DESC",("@c",company),("@actor",actor));
        await using var reader=await command.ExecuteReaderAsync(ct);
        var rows=new List<object>();
        while(await reader.ReadAsync(ct))
            rows.Add(new{id=reader.GetInt64(0),projectId=reader.GetInt64(1),projectName=reader.GetString(2),
                accountId=reader.GetInt64(3),email=reader.GetString(4),active=reader.GetBoolean(5)});
        return Ok(new{items=rows,total=rows.Count,page=1,pageSize=rows.Count});
    }

    [Authorize,HttpDelete("access/{projectId:long}/{accountId:long}")]
    public async Task<IActionResult> Revoke(long projectId,long accountId,CancellationToken ct)
    {
        await using var db=await Open(ct);
        var staff=await Staff(db,ct);
        if(staff is null)return Forbid();
        if(await ProjectCustomer(db,staff.Value.Company,staff.Value.Actor,projectId,ct)==0)return NotFound();
        await using var command=Cmd(db,null,@"UPDATE dbo.TDSICustomerAccess SET IsActive=0
WHERE CompanyID=@c AND SiteProjectID=@project AND CustomerAccountID=@account AND IsActive=1",
            ("@c",staff.Value.Company),("@project",projectId),("@account",accountId));
        return await command.ExecuteNonQueryAsync(ct)==0?NotFound():NoContent();
    }
}
