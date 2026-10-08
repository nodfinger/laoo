using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpDelete("facilities/{id:long}")]
    public async Task<IActionResult> DeleteFacility(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54003", "DELETE", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            var owned = await SportDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDSPFacility F WHERE F.CompanyID=@co AND F.FacilityID=@id
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor
 AND UB.BranchID=F.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@actor", Actor), ("@id", id));
            if (owned == 0) { await tx.RollbackAsync(ct); return NotFound(); }
            var used = await SportDb.Id(db, tx, """
SELECT (SELECT COUNT(*) FROM dbo.TDSPBooking WHERE CompanyID=@co AND FacilityID=@id)
 + (SELECT COUNT(*) FROM dbo.TDSPFacilityBlock WHERE CompanyID=@co AND FacilityID=@id)
""", ct, ("@co", Company), ("@id", id));
            if (used > 0) { await tx.RollbackAsync(ct); return Conflict(new {
                message = "ลบสนามไม่ได้", description = "มีประวัติการจองหรือช่วงปิดสนาม ให้ปิดสถานะแทน" }); }
            await SportDb.Execute(db, tx,
                "DELETE FROM dbo.TDSPFacilityHours WHERE CompanyID=@co AND FacilityID=@id",
                ct, ("@co", Company), ("@id", id));
            await SportDb.Execute(db, tx,
                "DELETE FROM dbo.TDSPFacility WHERE CompanyID=@co AND FacilityID=@id",
                ct, ("@co", Company), ("@id", id));
            await tx.CommitAsync(ct);
            return NoContent();
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }
    [HttpDelete("members/{id:long}")]
    public async Task<IActionResult> DeleteMember(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54006", "DELETE", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            var owned = await SportDb.Id(db, tx,
                "SELECT COUNT(*) FROM dbo.TDSPMember WHERE CompanyID=@co AND MemberID=@id",
                ct, ("@co", Company), ("@id", id));
            if (owned == 0) { await tx.RollbackAsync(ct); return NotFound(); }
            var used = await SportDb.Id(db, tx, """
SELECT (SELECT COUNT(*) FROM dbo.TDSPMembership WHERE CompanyID=@co AND MemberID=@id)
 + (SELECT COUNT(*) FROM dbo.TDSPBooking WHERE CompanyID=@co AND MemberID=@id)
""", ct, ("@co", Company), ("@id", id));
            if (used > 0) { await tx.RollbackAsync(ct); return Conflict(new {
                message = "ลบสมาชิกไม่ได้", description = "มีประวัติสมัครหรือจองสนาม ให้ปิดสถานะแทน" }); }
            await SportDb.Execute(db, tx,
                "DELETE FROM dbo.TDSPMemberCredential WHERE CompanyID=@co AND MemberID=@id",
                ct, ("@co", Company), ("@id", id));
            await SportDb.Execute(db, tx,
                "DELETE FROM dbo.TDSPMember WHERE CompanyID=@co AND MemberID=@id",
                ct, ("@co", Company), ("@id", id));
            await tx.CommitAsync(ct);
            return NoContent();
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }
}
