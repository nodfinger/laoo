using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Laoo.SchoolFood.Controllers;

[ApiController, Authorize, Route("api/school/student/food")]
public sealed class SchoolFoodStudentController(IConfiguration configuration) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Purchases([FromQuery] DateTime? from=null,
        [FromQuery] DateTime? to=null,[FromQuery] int page=1,
        [FromQuery] int pageSize=20,CancellationToken ct=default)
    {
        if(User.FindFirstValue("user_type")!="SCHOOL_STUDENT"
            ||!long.TryParse(User.FindFirstValue("company_id"),out var company)||company<=0
            ||!long.TryParse(User.FindFirstValue("student_id"),out var student)||student<=0
            ||!int.TryParse(User.FindFirstValue("credential_version"),out var version)||version<=0)
            return Denied();
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        if(!await SchoolFoodAccess.HasSubscriptions(db,company,false,ct))return Denied();
        var credential=await FoodDb.Rows(db,null,"""
SELECT K.MustChangePassword
FROM dbo.TDSFStudentCredential K
JOIN dbo.TDSCStudent S ON S.StudentID=K.StudentID AND S.CompanyID=K.CompanyID AND S.IsActive=1
WHERE K.CompanyID=@co AND K.StudentID=@student AND K.TokenVersion=@version AND K.IsActive=1
AND (K.LockedUntil IS NULL OR K.LockedUntil<=SYSUTCDATETIME())
""",ct,("@co",company),("@student",student),("@version",version));
        if(credential.Count!=1)return Denied();
        if(Convert.ToBoolean(credential[0]["MustChangePassword"]))
            return StatusCode(403,new{code="PASSWORD_CHANGE_REQUIRED",message="กรุณาเปลี่ยนรหัสผ่านก่อนใช้งาน",description="เปลี่ยนรหัสผ่านเริ่มต้นแล้วเข้าสู่ระบบใหม่เพื่อดูประวัติการซื้อ"});
        // Identity comes exclusively from validated claims, never a route or request student ID.
        return await SchoolFoodGuardianController.PurchaseHistory(db,company,student,from,to,page,pageSize,ct);
    }
    private IActionResult Denied()=>StatusCode(403,new{message="ไม่สามารถเปิดประวัติการซื้อได้",description="กรุณาเข้าสู่ระบบนักเรียนใหม่ หรือติดต่อโรงเรียนเพื่อตรวจสอบสถานะบัญชี"});
}
