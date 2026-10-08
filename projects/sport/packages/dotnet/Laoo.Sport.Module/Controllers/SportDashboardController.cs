using Microsoft.AspNetCore.Mvc;

namespace Laoo.Sport.Controllers;

public sealed partial class SportController
{
    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard(DateOnly from, DateOnly to,
        long? branchId, long? sportTypeId, CancellationToken ct)
    {
        if (from.Year < 2000 || to.Year > 2100 || to < from || to.DayNumber - from.DayNumber > 366)
            return Invalid("ช่วงรายงานต้องไม่เกิน 366 วัน");
        await using var db = await Open(ct);
        if (await Guard(db, "54011", "VIEW", ct) is { } denied) return denied;
        var fromUtc = from.ToDateTime(TimeOnly.MinValue).AddHours(-7);
        var toUtc = to.AddDays(1).ToDateTime(TimeOnly.MinValue).AddHours(-7);
        var permittedBranch = """
(EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co AND U.UserID=@actor AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserBranch UB WHERE UB.CompanyID=@co AND UB.UserID=@actor
 AND UB.BranchID=F.BranchID AND UB.IsActive=1))
""";
        var summary = await SportDb.Rows(db, null, $"""
SELECT COUNT(*) bookings,
 SUM(CASE WHEN B.StatusCode=N'CHECKED_IN' THEN 1 ELSE 0 END) checkIns,
 SUM(CASE WHEN B.StatusCode=N'NO_SHOW' THEN 1 ELSE 0 END) noShows,
 SUM(CASE WHEN B.StatusCode=N'CANCELLED' THEN 1 ELSE 0 END) cancelled,
 COALESCE(SUM(CASE WHEN B.StatusCode IN(N'CONFIRMED',N'CHECKED_IN',N'NO_SHOW')
 THEN B.PriceSnapshot ELSE 0 END),0) bookingRevenue
FROM dbo.TDSPBooking B
JOIN dbo.TDSPFacility F ON F.CompanyID=B.CompanyID AND F.FacilityID=B.FacilityID
WHERE B.CompanyID=@co AND B.StartsAt>=@from AND B.StartsAt<@to
 AND (@branch IS NULL OR F.BranchID=@branch)
 AND (@sport IS NULL OR F.SportTypeID=@sport) AND {permittedBranch}
""", ct, ("@co", Company), ("@actor", Actor), ("@from", fromUtc),
            ("@to", toUtc), ("@branch", branchId), ("@sport", sportTypeId));
        var sports = await SportDb.Rows(db, null, $"""
SELECT S.SportCode code,S.SportName name,COUNT(*) bookings,
 SUM(CASE WHEN B.StatusCode=N'CHECKED_IN' THEN 1 ELSE 0 END) checkIns
FROM dbo.TDSPBooking B
JOIN dbo.TDSPFacility F ON F.CompanyID=B.CompanyID AND F.FacilityID=B.FacilityID
JOIN dbo.TDSPSportType S ON S.CompanyID=F.CompanyID AND S.SportTypeID=F.SportTypeID
WHERE B.CompanyID=@co AND B.StartsAt>=@from AND B.StartsAt<@to
 AND (@branch IS NULL OR F.BranchID=@branch)
 AND (@sport IS NULL OR F.SportTypeID=@sport) AND {permittedBranch}
GROUP BY S.SportCode,S.SportName ORDER BY checkIns DESC,S.SportName
""", ct, ("@co", Company), ("@actor", Actor), ("@from", fromUtc),
            ("@to", toUtc), ("@branch", branchId), ("@sport", sportTypeId));
        var gender = await SportDb.Rows(db, null, $"""
SELECT COALESCE(M.GenderCode,N'UNSPECIFIED') code,COUNT(DISTINCT M.MemberID) members
FROM dbo.TDSPBooking B
JOIN dbo.TDSPFacility F ON F.CompanyID=B.CompanyID AND F.FacilityID=B.FacilityID
JOIN dbo.TDSPMember M ON M.CompanyID=B.CompanyID AND M.MemberID=B.MemberID
WHERE B.CompanyID=@co AND B.StartsAt>=@from AND B.StartsAt<@to
 AND (@branch IS NULL OR F.BranchID=@branch)
 AND (@sport IS NULL OR F.SportTypeID=@sport) AND {permittedBranch}
GROUP BY COALESCE(M.GenderCode,N'UNSPECIFIED')
""", ct, ("@co", Company), ("@actor", Actor), ("@from", fromUtc),
            ("@to", toUtc), ("@branch", branchId), ("@sport", sportTypeId));
        var age = await SportDb.Rows(db, null, $"""
SELECT CASE WHEN M.BirthDate IS NULL THEN N'ไม่ระบุ'
 WHEN DATEDIFF(year,M.BirthDate,CONVERT(date,SYSUTCDATETIME()))<18 THEN N'ต่ำกว่า 18'
 WHEN DATEDIFF(year,M.BirthDate,CONVERT(date,SYSUTCDATETIME()))<35 THEN N'18-34'
 WHEN DATEDIFF(year,M.BirthDate,CONVERT(date,SYSUTCDATETIME()))<60 THEN N'35-59'
 ELSE N'60 ขึ้นไป' END ageRange,
 COUNT(DISTINCT M.MemberID) members
FROM dbo.TDSPBooking B
JOIN dbo.TDSPFacility F ON F.CompanyID=B.CompanyID AND F.FacilityID=B.FacilityID
JOIN dbo.TDSPMember M ON M.CompanyID=B.CompanyID AND M.MemberID=B.MemberID
WHERE B.CompanyID=@co AND B.StartsAt>=@from AND B.StartsAt<@to
 AND (@branch IS NULL OR F.BranchID=@branch)
 AND (@sport IS NULL OR F.SportTypeID=@sport) AND {permittedBranch}
GROUP BY CASE WHEN M.BirthDate IS NULL THEN N'ไม่ระบุ'
 WHEN DATEDIFF(year,M.BirthDate,CONVERT(date,SYSUTCDATETIME()))<18 THEN N'ต่ำกว่า 18'
 WHEN DATEDIFF(year,M.BirthDate,CONVERT(date,SYSUTCDATETIME()))<35 THEN N'18-34'
 WHEN DATEDIFF(year,M.BirthDate,CONVERT(date,SYSUTCDATETIME()))<60 THEN N'35-59'
 ELSE N'60 ขึ้นไป' END
""", ct, ("@co", Company), ("@actor", Actor), ("@from", fromUtc),
            ("@to", toUtc), ("@branch", branchId), ("@sport", sportTypeId));
        var expiring = await SportDb.Rows(db, null, """
SELECT TOP(20) M.MemberCode code,P.FullName name,E.EndsOn endsOn
FROM dbo.TDSPMembership E
JOIN dbo.TDSPMember M ON M.CompanyID=E.CompanyID AND M.MemberID=E.MemberID AND M.IsActive=1
JOIN dbo.TDADPerson P ON P.CompanyID=M.CompanyID AND P.PersonID=M.PersonID
WHERE E.CompanyID=@co AND E.StatusCode=N'ACTIVE'
AND E.EndsOn>=CONVERT(date,DATEADD(hour,7,SYSUTCDATETIME()))
AND E.EndsOn<=DATEADD(day,COALESCE((SELECT ExpiryNoticeDays FROM dbo.TDSPSetting
 WHERE CompanyID=@co),30),CONVERT(date,DATEADD(hour,7,SYSUTCDATETIME())))
AND EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.CompanyID=@co
 AND U.UserID=@actor AND U.IsCompanyAdmin=1)
ORDER BY E.EndsOn,M.MemberCode
""", ct, ("@co", Company), ("@actor", Actor));
        return Ok(new { summary = summary.Single(), sports, gender, age, expiring });
    }
}
