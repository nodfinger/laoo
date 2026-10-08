using Microsoft.AspNetCore.Mvc;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpGet("sport-types")]
    public async Task<IActionResult> SportTypes(CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54002", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT SportTypeID id,SportCode code,SportName name,IsActive active
FROM dbo.TDSPSportType WHERE CompanyID=@co ORDER BY SportName
""", ct, ("@co", Company)));
    }

    [HttpGet("levels")]
    public async Task<IActionResult> Levels(CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54004", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT LevelID id,LevelCode code,LevelName name,RequiresResident resident,IsActive active
FROM dbo.TDSPMemberLevel WHERE CompanyID=@co ORDER BY LevelName
""", ct, ("@co", Company)));
    }

    [HttpGet("facilities")]
    public async Task<IActionResult> Facilities(long? branchId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54003", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT F.FacilityID id,F.FacilityCode code,F.FacilityName name,F.BranchID branchId,
 F.SportTypeID sportTypeId,S.SportName sport,F.Capacity capacity,F.IsActive active
FROM dbo.TDSPFacility F
JOIN dbo.TDSPSportType S ON S.CompanyID=F.CompanyID AND S.SportTypeID=F.SportTypeID
WHERE F.CompanyID=@co AND (@branch IS NULL OR F.BranchID=@branch)
 AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor
 AND UB.BranchID=F.BranchID AND UB.IsActive=1))
ORDER BY F.FacilityName
""", ct, ("@co", Company), ("@actor", Actor), ("@branch", branchId)));
    }

    [HttpGet("packages")]
    public async Task<IActionResult> Packages(CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54005", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT P.PackageID id,P.PackageCode code,P.PackageName name,P.LevelID levelId,
 P.DurationDays days,P.QuotaUnit unit,P.QuotaAmount quota,P.Price price,P.IsActive active
FROM dbo.TDSPPackage P WHERE P.CompanyID=@co ORDER BY P.PackageName
""", ct, ("@co", Company)));
    }

    [HttpGet("members")]
    public async Task<IActionResult> Members(string? search, int page = 1, CancellationToken ct = default)
    {
        if (page < 1 || page > 100000) return Invalid("เลขหน้าไม่ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "54006", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT M.MemberID id,M.MemberCode code,M.PersonID personId,P.FullName name,M.LevelID levelId,
 L.LevelName level,M.GenderCode gender,M.BirthDate birthDate,M.IsActive active
FROM dbo.TDSPMember M
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID
JOIN dbo.TDSPMemberLevel L ON L.CompanyID=M.CompanyID AND L.LevelID=M.LevelID
WHERE M.CompanyID=@co AND (@search IS NULL OR M.MemberCode LIKE N'%'+@search+N'%'
 OR P.FullName LIKE N'%'+@search+N'%')
ORDER BY M.MemberID OFFSET @skip ROWS FETCH NEXT 20 ROWS ONLY
""", ct, ("@co", Company), ("@search", string.IsNullOrWhiteSpace(search) ? null : search.Trim()),
            ("@skip", (page - 1) * 20)));
    }
}
