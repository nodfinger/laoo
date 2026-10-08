using Microsoft.AspNetCore.Mvc;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpGet("packages/{id:long}/sports")]
    public async Task<IActionResult> PackageSports(long id, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54005", "VIEW", ct) is { } denied) return denied;
        var rows = await SportDb.Rows(db, null, """
SELECT X.SportTypeID id FROM dbo.TDSPPackageSport X
JOIN dbo.TDSPPackage P ON P.CompanyID=X.CompanyID AND P.PackageID=X.PackageID
WHERE X.CompanyID=@co AND X.PackageID=@package
""", ct, ("@co", Company), ("@package", id));
        return Ok(rows.Select(r => Convert.ToInt64(r["id"])));
    }
    [HttpGet("options/{menu}")]
    public async Task<IActionResult> ScreenOptions(string menu, CancellationToken ct)
    {
        if (menu is not ("54003" or "54005" or "54006" or "54007" or "54008" or "54010" or "54011"))
            return NotFound();
        await using var db = await Open(ct);
        if (await Guard(db, menu, "VIEW", ct) is { } denied) return denied;
        var branches = menu is "54003" or "54011" ? await SportDb.Rows(db, null, """
SELECT B.BranchID id,B.BranchCode code,B.BranchNameTH name
FROM dbo.TDADBranch B WHERE B.CompanyID=@co AND B.IsActive=1
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor
 AND UB.BranchID=B.BranchID AND UB.IsActive=1)) ORDER BY B.BranchCode
""", ct, ("@co", Company), ("@actor", Actor)) : [];
        var people = menu == "54006" ? await SportDb.Rows(db, null, """
SELECT TOP(200) PersonID id,FullName name FROM dbo.TDADPerson
WHERE CompanyID=@co AND IsActive=1 ORDER BY FullName
""", ct, ("@co", Company)) : [];
        var sports = menu is "54003" or "54005" or "54011" ? await SportDb.Rows(db, null, """
SELECT SportTypeID id,SportCode code,SportName name FROM dbo.TDSPSportType
WHERE CompanyID=@co AND IsActive=1 ORDER BY SportName
""", ct, ("@co", Company)) : [];
        var levels = menu is "54005" or "54006" or "54010" ? await SportDb.Rows(db, null, """
SELECT LevelID id,LevelCode code,LevelName name FROM dbo.TDSPMemberLevel
WHERE CompanyID=@co AND IsActive=1 ORDER BY LevelName
""", ct, ("@co", Company)) : [];
        var packages = menu is "54007" or "54008" ? await SportDb.Rows(db, null, """
SELECT PackageID id,PackageCode code,PackageName name,Price price FROM dbo.TDSPPackage
WHERE CompanyID=@co AND IsActive=1
AND (@menu<>N'54008' OR (QuotaUnit=N'VISIT' AND QuotaAmount=1))
ORDER BY PackageName
""", ct, ("@co", Company), ("@menu", menu)) : [];
        var members = menu is "54007" or "54008" ? await SportDb.Rows(db, null, """
SELECT M.MemberID id,M.MemberCode code,P.FullName name FROM dbo.TDSPMember M
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID
WHERE M.CompanyID=@co AND M.IsActive=1 ORDER BY M.MemberCode
""", ct, ("@co", Company)) : [];
        var facilities = menu == "54008" ? await SportDb.Rows(db, null, """
SELECT F.FacilityID id,F.FacilityCode code,F.FacilityName name FROM dbo.TDSPFacility F
WHERE F.CompanyID=@co AND F.IsActive=1
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor
 AND UB.BranchID=F.BranchID AND UB.IsActive=1)) ORDER BY F.FacilityCode
""", ct, ("@co", Company), ("@actor", Actor)) : [];
        return Ok(new { branches, people, sports, levels, packages, members, facilities });
    }

    [HttpGet("memberships")]
    public async Task<IActionResult> MembershipList(int page = 1, CancellationToken ct = default)
    {
        if (page is < 1 or > 100000) return Invalid("เลขหน้าไม่ถูกต้อง");
        await using var db = await Open(ct);
        if (await Guard(db, "54007", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT E.MembershipID id,M.MemberCode memberCode,P.FullName memberName,
 E.PackageNameSnapshot packageName,E.StartsOn startsOn,E.EndsOn endsOn,
 E.PriceSnapshot price,E.StatusCode status
FROM dbo.TDSPMembership E
JOIN dbo.TDSPMember M ON M.CompanyID=E.CompanyID AND M.MemberID=E.MemberID
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID
WHERE E.CompanyID=@co ORDER BY E.MembershipID DESC
OFFSET @skip ROWS FETCH NEXT 20 ROWS ONLY
""", ct, ("@co", Company), ("@skip", (page - 1) * 20)));
    }

    [HttpGet("bookings/member/{memberId:long}/entitlements")]
    public async Task<IActionResult> BookingEntitlements(long memberId, CancellationToken ct)
    {
        await using var db = await Open(ct);
        if (await Guard(db, "54008", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT E.MembershipID id,E.PackageNameSnapshot name,E.EndsOn endsOn
FROM dbo.TDSPMembership E
JOIN dbo.TDSPMember M ON M.CompanyID=E.CompanyID AND M.MemberID=E.MemberID AND M.IsActive=1
WHERE E.CompanyID=@co AND E.MemberID=@member AND E.StatusCode=N'ACTIVE'
AND E.StartsOn<=CONVERT(date,SYSUTCDATETIME()) AND E.EndsOn>=CONVERT(date,SYSUTCDATETIME())
ORDER BY E.EndsOn
""", ct, ("@co", Company), ("@member", memberId)));
    }

    [HttpGet("checkins")]
    public async Task<IActionResult> CheckinList(DateTimeOffset from, DateTimeOffset to, CancellationToken ct)
    {
        if (from == default || to <= from || (to - from).TotalDays > 31)
            return Invalid("เลือกช่วงเวลาไม่เกิน 31 วัน");
        await using var db = await Open(ct);
        if (await Guard(db, "54009", "VIEW", ct) is { } denied) return denied;
        return Ok(await SportDb.Rows(db, null, """
SELECT B.BookingID id,F.FacilityName facility,P.FullName memberName,
 B.StartsAt startsAt,B.EndsAt endsAt,B.StatusCode status,B.PriceSnapshot price
FROM dbo.TDSPBooking B
JOIN dbo.TDSPFacility F ON F.CompanyID=B.CompanyID AND F.FacilityID=B.FacilityID
JOIN dbo.TDSPMember M ON M.CompanyID=B.CompanyID AND M.MemberID=B.MemberID
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID
WHERE B.CompanyID=@co AND B.StartsAt>=@from AND B.StartsAt<@to
AND (EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor
 AND UB.BranchID=B.BranchID AND UB.IsActive=1))
ORDER BY B.StartsAt DESC
""", ct, ("@co", Company), ("@actor", Actor), ("@from", from.UtcDateTime), ("@to", to.UtcDateTime)));
    }
}
