using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.Pet;
public abstract class PetControllerBase(IConfiguration configuration) : ControllerBase
{
    protected long Company => long.Parse(User.FindFirst("company_id")!.Value);
    protected long Actor => long.Parse(User.FindFirst("user_id")!.Value);
    protected async Task<SqlConnection> Open(CancellationToken ct)
    {
        var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        return db;
    }
    protected async Task<IActionResult?> Guard(SqlConnection db,string menu,string action,CancellationToken ct)
    {
        if (!PetAccess.Scope(User,out _,out _))
            return StatusCode(403,new { message="ไม่สามารถเข้าถึงข้อมูลบริษัทได้",description="เข้าสู่ระบบด้วยบัญชีบริษัทที่มีสิทธิ์ใช้งาน" });
        if (!await PetAccess.Can(db,User,menu,action,ct))
            return StatusCode(403,new { message="ไม่มีสิทธิ์ดำเนินการ",description="ตรวจสอบแพ็กเกจ เมนู และสิทธิ์ของบัญชีนี้" });
        return null;
    }
    protected IActionResult Invalid(string detail) => BadRequest(new { message="ข้อมูลไม่ถูกต้อง",description=detail });
    protected IActionResult Missing() => NotFound(new { message="ไม่พบข้อมูล",description="รายการนี้อาจถูกลบหรือไม่ได้อยู่ในบริษัทของคุณ" });
}
