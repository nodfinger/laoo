using System.Data;
using System.Security.Claims;
using Laoo.SchoolFood;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController,Route("api/school/student")]
public sealed class SchoolStudentAuthController(IConfiguration config,PasswordService passwords,JwtTokenService tokens):ControllerBase
{
    private async Task<SqlConnection> Open(CancellationToken ct){
        var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));await db.OpenAsync(ct);return db;
    }
    private static SqlCommand Cmd(SqlConnection db,SqlTransaction? tx,string sql,params (string,object?)[] values){
        var cmd=new SqlCommand(sql,db,tx);foreach(var (name,value) in values)cmd.Parameters.AddWithValue(name,value??DBNull.Value);return cmd;
    }
    private IActionResult Failed()=>Unauthorized(new{message="เข้าสู่ระบบนักเรียนไม่สำเร็จ",description="ตรวจสอบรหัสโรงเรียน รหัสนักเรียน และรหัสผ่าน หรือสอบถามโรงเรียนหากบัญชีถูกระงับ"});
    private bool Verify(string username,string hash,string password){
        try{return passwords.VerifyPassword(username,hash,password);}catch(FormatException){return false;}
    }
    private static bool ValidPassword(string value)=>value.Length is >=12 and <=256
        &&value.Any(char.IsUpper)&&value.Any(char.IsLower)&&value.Any(char.IsDigit)&&value.Any(c=>!char.IsLetterOrDigit(c));

    [AllowAnonymous,EnableRateLimiting("authentication"),HttpPost("login")]
    public async Task<IActionResult> Login(StudentLoginInput input,CancellationToken ct){
        if(string.IsNullOrWhiteSpace(input.CompanyCode)||input.CompanyCode.Length>50
            ||string.IsNullOrWhiteSpace(input.StudentCode)||input.StudentCode.Length>50
            ||string.IsNullOrEmpty(input.Password)||input.Password.Length>256)return Failed();
        await using var db=await Open(ct);
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        await using var cmd=Cmd(db,tx,"""
SELECT S.StudentID,S.CompanyID,S.StudentCode,CONCAT(S.FirstName,N' ',S.LastName) Name,
 K.PasswordHash,K.FailedLoginCount,K.LockedUntil,K.TokenVersion,K.MustChangePassword,P.ProjectID
FROM dbo.TDSFStudentCredential K WITH(UPDLOCK,HOLDLOCK)
JOIN dbo.TDSCStudent S ON S.StudentID=K.StudentID AND S.CompanyID=K.CompanyID AND S.IsActive=1
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID AND C.CompanyCode=@school AND C.IsActive=1
JOIN dbo.TDADProject P ON P.ProjectCode=N'LAOO_SCHOOL_FOOD' AND P.IsActive=1
WHERE S.StudentCode=@code AND K.IsActive=1
""",("@school",input.CompanyCode.Trim()),("@code",input.StudentCode.Trim()));
        await using var reader=await cmd.ExecuteReaderAsync(ct);
        if(!await reader.ReadAsync(ct)){await reader.DisposeAsync();await tx.RollbackAsync(ct);return Failed();}
        var id=reader.GetInt64(0);var company=reader.GetInt64(1);var code=reader.GetString(2);var name=reader.GetString(3);
        var hash=reader.GetString(4);var failed=reader.GetInt32(5);var locked=reader.IsDBNull(6)?(DateTime?)null:reader.GetDateTime(6);
        var version=reader.GetInt32(7);var mustChange=reader.GetBoolean(8);var project=reader.GetInt64(9);
        await reader.DisposeAsync();
        if(locked>DateTime.UtcNow){await tx.RollbackAsync(ct);return Failed();}
        if(!Verify(code,hash,input.Password)){
            await using var fail=Cmd(db,tx,"UPDATE dbo.TDSFStudentCredential SET FailedLoginCount=FailedLoginCount+1,LockedUntil=CASE WHEN FailedLoginCount+1>=5 THEN DATEADD(minute,15,SYSUTCDATETIME()) ELSE NULL END WHERE CompanyID=@co AND StudentID=@id",("@co",company),("@id",id));
            await fail.ExecuteNonQueryAsync(ct);await tx.CommitAsync(ct);return Failed();
        }
        await using(var success=Cmd(db,tx,"UPDATE dbo.TDSFStudentCredential SET FailedLoginCount=0,LockedUntil=NULL WHERE CompanyID=@co AND StudentID=@id",("@co",company),("@id",id)))await success.ExecuteNonQueryAsync(ct);
        await tx.CommitAsync(ct);
        if(!await SchoolFoodAccess.HasSubscriptions(db,company,false,ct))return Failed();
        var token=tokens.CreateToken(new AuthenticatedUser($"school-student:{id}","SCHOOL_STUDENT","SCHOOL_STUDENT",
            null,null,null,null,company,null,project,"LAOO_SCHOOL_FOOD",code,name,false,StudentId:id,CredentialVersion:version));
        return Ok(new{accessToken=token.AccessToken,expiresAt=token.ExpiresAt,mustChangePassword=mustChange,student=new{id,code,name}});
    }

    [Authorize,EnableRateLimiting("authentication"),HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(StudentPasswordInput input,CancellationToken ct){
        if(User.FindFirstValue("user_type")!="SCHOOL_STUDENT"
            ||!long.TryParse(User.FindFirstValue("company_id"),out var company)
            ||!long.TryParse(User.FindFirstValue("student_id"),out var student)
            ||!int.TryParse(User.FindFirstValue("credential_version"),out var version))return Failed();
        if(string.IsNullOrEmpty(input.CurrentPassword)||input.CurrentPassword.Length>256
            ||input.NewPassword is null||!ValidPassword(input.NewPassword))
            return BadRequest(new{message="รหัสผ่านใหม่ไม่ถูกต้อง",description="ใช้ 12–256 ตัวอักษร มีตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก ตัวเลข และอักขระพิเศษ"});
        await using var db=await Open(ct);
        if(!await SchoolFoodAccess.HasSubscriptions(db,company,false,ct))return Failed();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        await using var cmd=Cmd(db,tx,"SELECT S.StudentCode,K.PasswordHash FROM dbo.TDSFStudentCredential K WITH(UPDLOCK,HOLDLOCK) JOIN dbo.TDSCStudent S ON S.CompanyID=K.CompanyID AND S.StudentID=K.StudentID AND S.IsActive=1 WHERE K.CompanyID=@co AND K.StudentID=@id AND K.IsActive=1 AND K.TokenVersion=@version AND (K.LockedUntil IS NULL OR K.LockedUntil<=SYSUTCDATETIME())",("@co",company),("@id",student),("@version",version));
        await using var reader=await cmd.ExecuteReaderAsync(ct);
        if(!await reader.ReadAsync(ct)){await reader.DisposeAsync();await tx.RollbackAsync(ct);return Failed();}
        var code=reader.GetString(0);var hash=reader.GetString(1);await reader.DisposeAsync();
        if(!Verify(code,hash,input.CurrentPassword)){
            await using var fail=Cmd(db,tx,"UPDATE dbo.TDSFStudentCredential SET FailedLoginCount=FailedLoginCount+1,LockedUntil=CASE WHEN FailedLoginCount+1>=5 THEN DATEADD(minute,15,SYSUTCDATETIME()) ELSE NULL END WHERE CompanyID=@co AND StudentID=@id",("@co",company),("@id",student));
            await fail.ExecuteNonQueryAsync(ct);await tx.CommitAsync(ct);return Failed();
        }
        if(Verify(code,hash,input.NewPassword)){await tx.RollbackAsync(ct);return BadRequest(new{message="รหัสผ่านใหม่ต้องต่างจากเดิม",description="เลือกรหัสผ่านใหม่แล้วลองอีกครั้ง"});}
        await using var update=Cmd(db,tx,"UPDATE dbo.TDSFStudentCredential SET PasswordHash=@hash,TokenVersion=TokenVersion+1,MustChangePassword=0,FailedLoginCount=0,LockedUntil=NULL,UpdatedAt=SYSUTCDATETIME() WHERE CompanyID=@co AND StudentID=@id; INSERT dbo.TDSFAudit(CompanyID,UserID,ActionCode,EntityType,EntityID) VALUES(@co,0,N'STUDENT_PASSWORD',N'STUDENT',@id)",("@hash",passwords.HashPassword(code,input.NewPassword)),("@co",company),("@id",student));
        await update.ExecuteNonQueryAsync(ct);await tx.CommitAsync(ct);
        return Ok(new{saved=true,reauthenticate=true,message="เปลี่ยนรหัสผ่านแล้ว กรุณาเข้าสู่ระบบใหม่"});
    }

    [Authorize,HttpPut("/api/company/school-food/students/{student:long}/credential")]
    public async Task<IActionResult> SetCredential(long student,StudentCredentialInput input,CancellationToken ct){
        await using var db=await Open(ct);
        if(!SchoolFoodAccess.Scope(User,out var company,out var actor)
            ||!await SchoolFoodAccess.Can(db,User,"53005","MANAGE_CREDENTIAL",ct)
            ||await SchoolFoodAccess.ShopScope(db,company,actor,ct) is not null)
            return StatusCode(403,new{message="ไม่มีสิทธิ์จัดการบัญชีนักเรียน",description="ติดต่อผู้ดูแลโรงเรียนเพื่อขอสิทธิ์จัดการรหัสผ่าน"});
        if(input.NewPassword is null||!ValidPassword(input.NewPassword))return BadRequest(new{
            message="รหัสผ่านไม่ถูกต้อง",description="ใช้ 12–256 ตัวอักษร มีตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก ตัวเลข และอักขระพิเศษ"});
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        await using var find=Cmd(db,tx,"SELECT StudentCode FROM dbo.TDSCStudent WHERE CompanyID=@co AND StudentID=@id AND IsActive=1",("@co",company),("@id",student));
        var code=await find.ExecuteScalarAsync(ct) as string;
        if(code is null){await tx.RollbackAsync(ct);return NotFound(new{message="ไม่พบนักเรียน",description="เลือกนักเรียนที่เปิดใช้งานในโรงเรียนนี้"});}
        await using var save=Cmd(db,tx,"""
MERGE dbo.TDSFStudentCredential WITH(HOLDLOCK) AS T
USING(SELECT @co CompanyID,@id StudentID) AS S ON T.CompanyID=S.CompanyID AND T.StudentID=S.StudentID
WHEN MATCHED THEN UPDATE SET PasswordHash=@hash,IsActive=@active,MustChangePassword=1,TokenVersion=T.TokenVersion+1,FailedLoginCount=0,LockedUntil=NULL,UpdatedAt=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(CompanyID,StudentID,PasswordHash,IsActive) VALUES(@co,@id,@hash,@active);
INSERT dbo.TDSFAudit(CompanyID,UserID,ActionCode,EntityType,EntityID) VALUES(@co,@actor,N'STUDENT_CREDENTIAL',N'STUDENT',@id);
""",("@co",company),("@id",student),("@hash",passwords.HashPassword(code,input.NewPassword)),("@active",input.IsActive),("@actor",actor));
        await save.ExecuteNonQueryAsync(ct);await tx.CommitAsync(ct);
        return Ok(new{saved=true,mustChangePassword=true});
    }
}
public sealed record StudentLoginInput(string CompanyCode,string StudentCode,string Password);
public sealed record StudentPasswordInput(string CurrentPassword,string NewPassword);
public sealed record StudentCredentialInput(string NewPassword,bool IsActive=true);
