using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
namespace Laoo.Site;
public abstract class SiteControllerBase(IConfiguration configuration) : ControllerBase
{
    protected long Company => long.Parse(User.FindFirst("company_id")!.Value);
    protected long Actor => long.Parse(User.FindFirst("user_id")!.Value);
    protected async Task<SqlConnection> Open(CancellationToken ct)
    {
        var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(ct);
        return db;
    }
    protected async Task<IActionResult?> Guard(SqlConnection db, string menu, string action, CancellationToken ct)
    {
        if (!SiteAccess.Scope(User,out _,out _) || !await SiteAccess.Can(db,User,menu,action,ct))
            return StatusCode(403,new { message="ไม่มีสิทธิ์ดำเนินการ",description="ตรวจสอบแพ็กเกจ เมนู และสิทธิ์บัญชีผู้ใช้" });
        return null;
    }
    protected IActionResult Invalid(string detail) => BadRequest(new { message="ข้อมูลไม่ถูกต้อง",description=detail });
    protected IActionResult Missing() => NotFound(new { message="ไม่พบข้อมูล",description="รายการนี้อาจถูกลบหรือไม่อยู่ในบริษัทของคุณ" });
    protected async Task<bool> ProjectInScope(SqlConnection db,long projectId,CancellationToken ct)
        => await SiteDb.Scalar(db,null,@"SELECT COUNT(*) FROM dbo.TDSIProject P
WHERE P.CompanyID=@c AND P.SiteProjectID=@project AND P.StatusCode<>N'CANCELLED'
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@c AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch X WHERE X.CompanyID=@c AND X.UserID=@actor AND X.BranchID=P.BranchID AND X.IsActive=1))",
            ct,("@c",Company),("@project",projectId),("@actor",Actor))>0;
}
