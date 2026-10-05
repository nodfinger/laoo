using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpGet("facilities/{id:long}/hours")]
    public async Task<IActionResult> FacilityHours(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54003", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT H.HoursID id,H.DayOfWeek day,H.OpensAt opensAt,H.ClosesAt closesAt,H.IsActive active
FROM dbo.TDSPFacilityHours H
JOIN dbo.TDSPFacility F ON F.CompanyID=H.CompanyID AND F.FacilityID=H.FacilityID
WHERE H.CompanyID=@co AND H.FacilityID=@facility
 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor
 AND UB.BranchID=F.BranchID AND UB.IsActive=1))
ORDER BY H.DayOfWeek,H.OpensAt
""", ct, ("@co", Company), ("@facility", id), ("@actor", Actor)));
    }

    [HttpPost("facilities")]
    public Task<IActionResult> AddFacility(SportFacilityInput input, CancellationToken ct) =>
        SaveFacility(null, input, ct);

    [HttpPut("facilities/{id:long}")]
    public Task<IActionResult> EditFacility(long id, SportFacilityInput input, CancellationToken ct) =>
        SaveFacility(id, input, ct);

    private async Task<IActionResult> SaveFacility(long? id, SportFacilityInput input, CancellationToken ct)
    {
        if (input.BranchID <= 0 || input.SportTypeID <= 0 || input.Capacity is < 1 or > 100000
            || string.IsNullOrWhiteSpace(input.Code) || input.Code.Length > 30
            || string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 150
            || input.Hours is null or { Length: 0 or > 21 }
            || input.Hours.Any(h => h.DayOfWeek is < 0 or > 6
                || h.OpensAt < TimeSpan.Zero || h.ClosesAt > TimeSpan.FromDays(1)
                || h.OpensAt >= h.ClosesAt)
            || input.Hours.GroupBy(h => h.DayOfWeek).Any(group =>
            {
                var sorted = group.OrderBy(h => h.OpensAt).ToArray();
                return sorted.Skip(1).Where((hour, i) => sorted[i].ClosesAt > hour.OpensAt).Any();
            }))
            return Invalid("ข้อมูลสนามหรือช่วงเวลาเปิดสนามไม่ถูกต้อง/ซ้อนกัน");
        await using var db = await Open(ct);
        if (await Guard(db, "54003", id is null ? "CREATE" : "EDIT", ct) is { } denied) return denied;
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        try
        {
            var available = await SportDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDADBranch B
JOIN dbo.TDSPSportType S ON S.CompanyID=B.CompanyID AND S.SportTypeID=@sport AND S.IsActive=1
WHERE B.CompanyID=@co AND B.BranchID=@branch AND B.IsActive=1
 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor
 AND UB.BranchID=B.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@branch", input.BranchID), ("@sport", input.SportTypeID),
                ("@actor", Actor));
            if (available != 1)
            {
                await tx.RollbackAsync(ct);
                return Conflict(new { message = "บันทึกสนามไม่ได้",
                    description = "ตรวจสาขา สิทธิ์สาขา และประเภทกีฬาที่เปิดใช้งาน" });
            }
            long facility;
            if (id is null)
                facility = await SportDb.Id(db, tx, """
INSERT dbo.TDSPFacility(CompanyID,BranchID,SportTypeID,FacilityCode,FacilityName,Capacity,IsActive)
OUTPUT INSERTED.FacilityID
VALUES(@co,@branch,@sport,@code,@name,@capacity,@active)
""", ct, ("@co", Company), ("@branch", input.BranchID), ("@sport", input.SportTypeID),
                    ("@code", input.Code.Trim().ToUpperInvariant()), ("@name", input.Name.Trim()),
                    ("@capacity", input.Capacity), ("@active", input.Active));
            else
            {
                facility = id.Value;
                var current = await SportDb.Rows(db, tx, """
SELECT BranchID,SportTypeID FROM dbo.TDSPFacility WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND FacilityID=@facility
 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor
 AND UB.BranchID=TDSPFacility.BranchID AND UB.IsActive=1))
""", ct, ("@co", Company), ("@facility", facility), ("@actor", Actor));
                if (current.Count != 1)
                {
                    await tx.RollbackAsync(ct);
                    return NotFound(new { message = "ไม่พบสนาม", description = "ตรวจสาขาที่มีสิทธิ์และลองใหม่" });
                }
                var future = await SportDb.Id(db, tx, """
SELECT COUNT(*) FROM dbo.TDSPBooking WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@co AND FacilityID=@facility AND EndsAt>SYSUTCDATETIME()
 AND StatusCode IN(N'PENDING_PAYMENT',N'CONFIRMED',N'CHECKED_IN')
""", ct, ("@co", Company), ("@facility", facility));
                if (future > 0)
                {
                    await tx.RollbackAsync(ct);
                    return Conflict(new { message = "สนามมีรายการจองในอนาคต",
                        description = "จัดการรายการจองก่อนเปลี่ยนข้อมูลหรือเวลาทำการสนาม" });
                }
                await SportDb.Execute(db, tx, """
UPDATE dbo.TDSPFacility SET BranchID=@branch,SportTypeID=@sport,FacilityCode=@code,
 FacilityName=@name,Capacity=@capacity,IsActive=@active
WHERE CompanyID=@co AND FacilityID=@facility
""", ct, ("@co", Company), ("@facility", facility), ("@branch", input.BranchID),
                    ("@sport", input.SportTypeID), ("@code", input.Code.Trim().ToUpperInvariant()),
                    ("@name", input.Name.Trim()), ("@capacity", input.Capacity),
                    ("@active", input.Active));
                await SportDb.Execute(db, tx, """
DELETE FROM dbo.TDSPFacilityHours WHERE CompanyID=@co AND FacilityID=@facility
""", ct, ("@co", Company), ("@facility", facility));
            }
            foreach (var hour in input.Hours)
                await SportDb.Execute(db, tx, """
INSERT dbo.TDSPFacilityHours(CompanyID,FacilityID,DayOfWeek,OpensAt,ClosesAt,IsActive)
VALUES(@co,@facility,@day,@open,@close,1)
""", ct, ("@co", Company), ("@facility", facility), ("@day", hour.DayOfWeek),
                    ("@open", hour.OpensAt), ("@close", hour.ClosesAt));
            await tx.CommitAsync(ct);
            return Ok(new { id = facility, saved = true });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627 or 1205)
        {
            await tx.RollbackAsync(ct);
            return Conflict(new { message = "รหัสสนามซ้ำหรือข้อมูลเปลี่ยน",
                description = "ตรวจรหัสสนามและลองใหม่" });
        }
        catch { await tx.RollbackAsync(ct); throw; }
    }
}

public sealed record SportFacilityInput(long BranchID,long SportTypeID,string Code,
    string Name,int Capacity,bool Active,SportHoursInput[] Hours);
public sealed record SportHoursInput(int DayOfWeek,TimeSpan OpensAt,TimeSpan ClosesAt);
