using System.Data;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooProviderModule.Controllers;

[ApiController, AllowAnonymous, Route("api/public/providers")]
public sealed class ProviderPublicController(
    IConfiguration configuration,
    IWebHostEnvironment environment) : ProviderControllerBase(configuration)
{
    [HttpGet("service-types")]
    public async Task<IActionResult> ServiceTypes(CancellationToken token) { await using var db = await Open(token); return Ok(await ProviderDb.Query(db, "SELECT s.ServiceTypeID id,s.ServiceCode code,s.ServiceName name,s.DescriptionText description,s.IconName iconName,s.CoverImagePath coverImagePath,COUNT(DISTINCT CASE WHEN p.PublishedRevisionID=ps.RevisionID AND p.IsActive=1 AND p.StatusCode<>N'SUSPENDED' THEN p.CompanyID END) providerCount FROM dbo.TDPRServiceType s LEFT JOIN dbo.TDPRProviderService ps ON ps.ServiceTypeID=s.ServiceTypeID LEFT JOIN dbo.TDPRProviderProfile p ON p.PublishedRevisionID=ps.RevisionID WHERE s.IsActive=1 GROUP BY s.ServiceTypeID,s.ServiceCode,s.ServiceName,s.DescriptionText,s.IconName,s.CoverImagePath,s.SortOrder ORDER BY s.SortOrder,s.ServiceName", token)); }

    [HttpGet("locations")]
    public async Task<IActionResult> Locations(long? parentId = null, string? type = null, CancellationToken token = default) { await using var db = await Open(token); return Ok(await ProviderDb.Query(db, "SELECT LocationID id,LocationCode code,LocationType type,ParentLocationID parentId,NameTH name,NameEN nameEn,Latitude latitude,Longitude longitude FROM dbo.TDPRLocation WHERE IsActive=1 AND ((@parent IS NULL AND ParentLocationID IS NULL) OR ParentLocationID=@parent) AND (@type IS NULL OR LocationType=@type) ORDER BY SortOrder,NameTH", token, ("@parent", parentId), ("@type", Clean(type)?.ToUpperInvariant()))); }

    [HttpGet("service-types/{id:long}/cover")]
    public async Task<IActionResult> ServiceCover(long id, CancellationToken token)
    {
        await using var db = await Open(token);
        var rows = await ProviderDb.Query(db, "SELECT CoverImagePath path,CoverMimeType mime FROM dbo.TDPRServiceType WHERE ServiceTypeID=@id AND IsActive=1 AND CoverImagePath IS NOT NULL", token, ("@id", id));
        return ProviderAsset(rows);
    }

    [HttpGet("companies/{companyId:long}/cover")]
    public async Task<IActionResult> CompanyCover(long companyId, CancellationToken token)
    {
        await using var db = await Open(token);
        var rows = await ProviderDb.Query(db, """
SELECT c.MemberCoverImagePath path,c.MemberCoverMimeType mime
FROM dbo.TDSTCompanySetUp c
WHERE c.CompanyID=@company AND c.MemberCoverImagePath IS NOT NULL AND EXISTS(
 SELECT 1 FROM dbo.TDPRProviderProfile p
 JOIN dbo.TDPRProviderRevision r ON r.RevisionID=p.PublishedRevisionID AND r.CompanyID=p.CompanyID AND r.StatusCode=N'APPROVED'
 WHERE p.CompanyID=c.CompanyID AND p.IsActive=1 AND p.StatusCode<>N'SUSPENDED')
""", token, ("@company", companyId));
        return ProviderAsset(rows);
    }

    [HttpGet("profiles/{providerId:long}/cover")]
    public async Task<IActionResult> ProviderCover(long providerId, CancellationToken token)
    {
        await using var db = await Open(token);
        var rows = await ProviderDb.Query(db, """
SELECT c.MemberCoverImagePath path,c.MemberCoverMimeType mime
FROM dbo.TDPRProviderProfile p
JOIN dbo.TDPRProviderRevision r ON r.RevisionID=p.PublishedRevisionID AND r.CompanyID=p.CompanyID AND r.StatusCode=N'APPROVED'
JOIN dbo.TDSTCompanySetUp c ON c.CompanyID=p.CompanyID
WHERE p.ProviderID=@provider AND p.IsActive=1 AND p.StatusCode<>N'SUSPENDED' AND c.MemberCoverImagePath IS NOT NULL
""", token, ("@provider", providerId));
        return ProviderAsset(rows);
    }

    [HttpGet("portfolio/{id:long}/cover")]
    public async Task<IActionResult> PortfolioCover(long id, CancellationToken token)
    {
        await using var db = await Open(token);
        var rows = await ProviderDb.Query(db, """
SELECT w.CoverImagePath path,w.CoverMimeType mime
FROM dbo.TDPRPortfolio w
WHERE w.PortfolioID=@id AND w.IsActive=1 AND EXISTS(
 SELECT 1 FROM dbo.TDPRProviderProfile p
 JOIN dbo.TDPRProviderRevision r ON r.RevisionID=p.PublishedRevisionID AND r.CompanyID=p.CompanyID AND r.StatusCode=N'APPROVED'
 WHERE p.CompanyID=w.CompanyID AND p.IsActive=1 AND p.StatusCode<>N'SUSPENDED')
""", token, ("@id", id));
        return ProviderAsset(rows);
    }

    [HttpGet("portfolio/photos/{id:long}")]
    public async Task<IActionResult> PortfolioPhoto(long id, CancellationToken token)
    {
        await using var db = await Open(token);
        var rows = await ProviderDb.Query(db, """
SELECT i.ImagePath path,i.MimeType mime
FROM dbo.TDPRPortfolioImage i
JOIN dbo.TDPRPortfolio w ON w.PortfolioID=i.PortfolioID AND w.CompanyID=i.CompanyID AND w.IsActive=1
WHERE i.PortfolioImageID=@id AND EXISTS(
 SELECT 1 FROM dbo.TDPRProviderProfile p
 JOIN dbo.TDPRProviderRevision r ON r.RevisionID=p.PublishedRevisionID AND r.CompanyID=p.CompanyID AND r.StatusCode=N'APPROVED'
 WHERE p.CompanyID=i.CompanyID AND p.IsActive=1 AND p.StatusCode<>N'SUSPENDED')
""", token, ("@id", id));
        return ProviderAsset(rows);
    }

    private IActionResult ProviderAsset(List<Dictionary<string, object?>> rows)
    {
        if (rows.Count == 0) return NotFound();
        var relative = Convert.ToString(rows[0]["path"])?.Replace('\\', '/').TrimStart('/');
        if (string.IsNullOrWhiteSpace(relative) || !relative.StartsWith("uploads/provider/", StringComparison.OrdinalIgnoreCase)) return NotFound();
        var root = Path.GetFullPath(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"));
        var absolute = Path.GetFullPath(Path.Combine(root, relative.Replace('/', Path.DirectorySeparatorChar)));
        if (!absolute.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || !System.IO.File.Exists(absolute)) return NotFound();
        var mime = Convert.ToString(rows[0]["mime"]);
        return PhysicalFile(absolute, string.IsNullOrWhiteSpace(mime) ? "application/octet-stream" : mime, enableRangeProcessing: true);
    }

    [HttpGet]
    public async Task<IActionResult> Search(string? search = null, long? serviceTypeId = null, long? locationId = null, double? latitude = null, double? longitude = null, int page = 1, int pageSize = 12, CancellationToken token = default)
    {
        page = Math.Max(page, 1); pageSize = Math.Clamp(pageSize, 1, 48); await using var db = await Open(token);
        const string from = """
FROM dbo.TDPRProviderProfile p
JOIN dbo.TDPRProviderRevision r ON r.RevisionID=p.PublishedRevisionID AND r.StatusCode=N'APPROVED'
JOIN dbo.TDSTCompanySetUp c ON c.CompanyID=p.CompanyID AND c.IsActive=1
OUTER APPLY(SELECT COUNT(*) reviewCount,AVG(CAST((rv.QualityScore+rv.PunctualityScore+rv.ServiceScore+rv.ValueScore)/4.0 AS decimal(6,3))) averageRating,MAX(rv.CreatedAt) latestReview FROM dbo.TDPRReview rv WHERE rv.ProviderID=p.ProviderID AND rv.IsHidden=0) score
OUTER APPLY(SELECT TOP(1) BayesianMinimumReviews,RatingWeightNoGps,RecencyWeightNoGps,RatingWeightGps,DistanceWeightGps,RecencyWeightGps,MaxDistanceKm FROM dbo.TDPRSystemSetting WHERE CompanyID=p.CompanyID) cfg
OUTER APPLY(SELECT (ISNULL(score.reviewCount,0)*ISNULL(score.averageRating,0)+ISNULL(cfg.BayesianMinimumReviews,5)*4.0)/(ISNULL(score.reviewCount,0)+ISNULL(cfg.BayesianMinimumReviews,5)) trustedRating,CASE WHEN score.latestReview IS NULL OR DATEDIFF(day,score.latestReview,SYSUTCDATETIME())>=365 THEN 0 ELSE 5.0*(1.0-DATEDIFF(day,score.latestReview,SYSUTCDATETIME())/365.0) END recencyScore) metric
OUTER APPLY(SELECT TOP(1) b.BranchName,b.Latitude,b.Longitude,CASE WHEN @lat IS NULL OR @lng IS NULL OR b.Latitude IS NULL OR b.Longitude IS NULL THEN NULL ELSE 6371*ACOS(CASE WHEN COS(RADIANS(@lat))*COS(RADIANS(CAST(b.Latitude AS float)))*COS(RADIANS(CAST(b.Longitude AS float))-RADIANS(@lng))+SIN(RADIANS(@lat))*SIN(RADIANS(CAST(b.Latitude AS float)))>1 THEN 1 WHEN COS(RADIANS(@lat))*COS(RADIANS(CAST(b.Latitude AS float)))*COS(RADIANS(CAST(b.Longitude AS float))-RADIANS(@lng))+SIN(RADIANS(@lat))*SIN(RADIANS(CAST(b.Latitude AS float)))<-1 THEN -1 ELSE COS(RADIANS(@lat))*COS(RADIANS(CAST(b.Latitude AS float)))*COS(RADIANS(CAST(b.Longitude AS float))-RADIANS(@lng))+SIN(RADIANS(@lat))*SIN(RADIANS(CAST(b.Latitude AS float))) END) END distanceKm FROM dbo.TDPRProviderBranch b WHERE b.RevisionID=r.RevisionID ORDER BY CASE WHEN b.IsPrimary=1 THEN 0 ELSE 1 END,distanceKm) nearest
OUTER APPLY(SELECT CASE WHEN @lat IS NULL OR @lng IS NULL THEN metric.trustedRating*ISNULL(cfg.RatingWeightNoGps,90)/100.0+metric.recencyScore*ISNULL(cfg.RecencyWeightNoGps,10)/100.0 ELSE metric.trustedRating*ISNULL(cfg.RatingWeightGps,70)/100.0+(CASE WHEN nearest.distanceKm IS NULL THEN 0 ELSE 5.0*(1.0-CASE WHEN nearest.distanceKm>=ISNULL(cfg.MaxDistanceKm,100) THEN 1 ELSE nearest.distanceKm/ISNULL(cfg.MaxDistanceKm,100) END) END)*ISNULL(cfg.DistanceWeightGps,20)/100.0+metric.recencyScore*ISNULL(cfg.RecencyWeightGps,10)/100.0 END rankScore) ranking
WHERE p.IsActive=1 AND p.PublishedRevisionID IS NOT NULL AND p.StatusCode<>N'SUSPENDED'
AND (@search IS NULL OR r.DisplayName LIKE N'%'+@search+N'%' OR r.SummaryText LIKE N'%'+@search+N'%')
AND (@service IS NULL OR EXISTS(SELECT 1 FROM dbo.TDPRProviderService ps WHERE ps.RevisionID=r.RevisionID AND ps.ServiceTypeID=@service))
AND (@location IS NULL OR EXISTS(SELECT 1 FROM dbo.TDPRProviderArea pa JOIN dbo.TDPRLocation l ON l.LocationID=pa.LocationID LEFT JOIN dbo.TDPRLocation parent ON parent.LocationID=l.ParentLocationID LEFT JOIN dbo.TDPRLocation grand ON grand.LocationID=parent.ParentLocationID WHERE pa.RevisionID=r.RevisionID AND @location IN(l.LocationID,parent.LocationID,grand.LocationID)))
AND (@lat IS NULL OR nearest.distanceKm<=ISNULL(cfg.MaxDistanceKm,100))
""";
        var args = new (string, object?)[] { ("@search", Clean(search)), ("@service", serviceTypeId), ("@location", locationId), ("@lat", latitude), ("@lng", longitude) };
        var total = await ProviderDb.Scalar<int>(db, "SELECT COUNT(*) " + from, token, args);
        var sql = "SELECT p.ProviderID id,p.Slug slug,r.DisplayName name,r.SummaryText summary,r.PublicAddress address,r.PublicTelephone telephone,c.MemberCoverImagePath memberCoverImagePath,ISNULL(score.reviewCount,0) reviewCount,CAST(ISNULL(score.averageRating,0) AS decimal(4,2)) averageRating,nearest.BranchName nearestBranch,CAST(nearest.distanceKm AS decimal(10,2)) distanceKm,CASE WHEN ISNULL(score.reviewCount,0)=0 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END isNew " + from + " ORDER BY CASE WHEN ISNULL(score.reviewCount,0)=0 THEN 1 ELSE 0 END,ranking.rankScore DESC,score.latestReview DESC OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY";
        var items = await ProviderDb.Query(db, sql, token, [.. args, ("@skip", (page - 1) * pageSize), ("@take", pageSize)]);
        foreach (var row in items) row["services"] = await ProviderDb.Query(db, "SELECT s.ServiceTypeID id,s.ServiceName name,s.IconName iconName FROM dbo.TDPRProviderService ps JOIN dbo.TDPRServiceType s ON s.ServiceTypeID=ps.ServiceTypeID AND s.IsActive=1 JOIN dbo.TDPRProviderProfile p ON p.PublishedRevisionID=ps.RevisionID WHERE p.ProviderID=@id ORDER BY s.SortOrder,s.ServiceName", token, ("@id", row["id"]));
        return Ok(new { items, total, page, pageSize });
    }

    [HttpGet("{slug}")]
    public async Task<IActionResult> Detail(string slug, CancellationToken token)
    {
        await using var db = await Open(token); var rows = await ProviderDb.Query(db, "SELECT p.ProviderID id,p.Slug slug,r.DisplayName name,r.SummaryText summary,r.PublicAddress address,r.PublicTelephone telephone,r.PublicEmail email,r.LineID lineId,r.LineUrl lineUrl,r.WebsiteUrl websiteUrl,CAST(ISNULL(x.averageRating,0) AS decimal(4,2)) averageRating,ISNULL(x.reviewCount,0) reviewCount FROM dbo.TDPRProviderProfile p JOIN dbo.TDPRProviderRevision r ON r.RevisionID=p.PublishedRevisionID OUTER APPLY(SELECT AVG(CAST((QualityScore+PunctualityScore+ServiceScore+ValueScore)/4.0 AS decimal(6,3))) averageRating,COUNT(*) reviewCount FROM dbo.TDPRReview WHERE ProviderID=p.ProviderID AND IsHidden=0)x WHERE p.Slug=@slug AND p.PublishedRevisionID IS NOT NULL AND p.StatusCode<>N'SUSPENDED' AND p.IsActive=1", token, ("@slug", slug)); if (rows.Count == 0) return NotFound(new { message = "ไม่พบผู้ให้บริการ" });
        var id = Convert.ToInt64(rows[0]["id"]); rows[0]["services"] = await ProviderDb.Query(db, "SELECT s.ServiceTypeID id,s.ServiceName name,s.DescriptionText description,s.CoverImagePath coverImagePath FROM dbo.TDPRProviderService ps JOIN dbo.TDPRServiceType s ON s.ServiceTypeID=ps.ServiceTypeID JOIN dbo.TDPRProviderProfile p ON p.PublishedRevisionID=ps.RevisionID WHERE p.ProviderID=@id ORDER BY s.SortOrder,s.ServiceName", token, ("@id", id)); rows[0]["branches"] = await ProviderDb.Query(db, "SELECT b.BranchName name,b.AddressText address,b.Telephone telephone,b.Latitude latitude,b.Longitude longitude,b.IsPrimary isPrimary FROM dbo.TDPRProviderBranch b JOIN dbo.TDPRProviderProfile p ON p.PublishedRevisionID=b.RevisionID WHERE p.ProviderID=@id ORDER BY b.IsPrimary DESC,b.BranchName", token, ("@id", id)); rows[0]["areas"] = await ProviderDb.Query(db, "SELECT l.LocationID id,l.LocationType type,l.NameTH name FROM dbo.TDPRProviderArea a JOIN dbo.TDPRLocation l ON l.LocationID=a.LocationID JOIN dbo.TDPRProviderProfile p ON p.PublishedRevisionID=a.RevisionID WHERE p.ProviderID=@id ORDER BY l.LocationType,l.NameTH", token, ("@id", id)); rows[0]["productCategories"] = await ProviderDb.Query(db, "SELECT ItemGroupCode groupCode,ItemTypeCode typeCode,COUNT(*) itemCount FROM dbo.TDIVItem i JOIN dbo.TDPRProviderProfile p ON p.CompanyID=i.CompanyID WHERE p.ProviderID=@id AND i.IsActive=1 GROUP BY ItemGroupCode,ItemTypeCode ORDER BY ItemGroupCode,ItemTypeCode", token, ("@id", id)); rows[0]["reviews"] = await ProviderDb.Query(db, "SELECT TOP(20) QualityScore quality,PunctualityScore punctuality,ServiceScore service,ValueScore value,CommentText comment,CreatedAt createdAt FROM dbo.TDPRReview WHERE ProviderID=@id AND IsHidden=0 ORDER BY CreatedAt DESC", token, ("@id", id)); var companyInfo = (await ProviderDb.Query(db, "SELECT p.CompanyID companyId,c.MemberCoverImagePath memberCoverImagePath FROM dbo.TDPRProviderProfile p JOIN dbo.TDSTCompanySetUp c ON c.CompanyID=p.CompanyID WHERE p.ProviderID=@id", token, ("@id", id))).Single(); var company = Convert.ToInt64(companyInfo["companyId"]); rows[0]["memberCoverImagePath"] = companyInfo["memberCoverImagePath"]; var works = await ProviderDb.Query(db, "SELECT PortfolioID id,WorkTitle title,ServiceDate serviceDate,CoverImagePath coverImagePath FROM dbo.TDPRPortfolio WHERE CompanyID=@company AND IsActive=1 ORDER BY ServiceDate DESC,PortfolioID DESC", token, ("@company", company)); foreach (var work in works) work["photos"] = await ProviderDb.Query(db, "SELECT PortfolioImageID id,ImagePath imagePath,SortOrder sortOrder FROM dbo.TDPRPortfolioImage WHERE CompanyID=@company AND PortfolioID=@portfolio ORDER BY SortOrder,PortfolioImageID", token, ("@company", company), ("@portfolio", work["id"])); rows[0]["portfolio"] = works; return Ok(rows[0]);
    }

    [HttpGet("review/{tokenValue}")]
    public async Task<IActionResult> ReviewInfo(string tokenValue, CancellationToken token) { var hash = Hash(tokenValue); await using var db = await Open(token); var rows = await ProviderDb.Query(db, "SELECT i.ReviewInviteID id,r.DisplayName providerName,s.ServiceName serviceName,i.ServiceDate serviceDate,i.ExpiresAt expiresAt,i.StatusCode status FROM dbo.TDPRReviewInvite i JOIN dbo.TDPRProviderProfile p ON p.ProviderID=i.ProviderID JOIN dbo.TDPRProviderRevision r ON r.RevisionID=p.PublishedRevisionID JOIN dbo.TDPRServiceType s ON s.ServiceTypeID=i.ServiceTypeID WHERE i.TokenHash=@hash", token, ("@hash", hash)); return rows.Count == 0 ? NotFound(new { message = "ลิงก์ไม่ถูกต้อง" }) : Ok(rows[0]); }

    [HttpPost("review/{tokenValue}"), EnableRateLimiting("provider-review")]
    public async Task<IActionResult> Review(string tokenValue, ReviewSubmit request, CancellationToken token)
    {
        if (new[] { request.Quality, request.Punctuality, request.Service, request.Value }.Any(x => x is < 1 or > 5)) return BadRequest(new { message = "คะแนนต้องอยู่ระหว่าง 1–5" }); var hash = Hash(tokenValue); await using var db = await Open(token); await using var tx = (SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable, token);
        var rows = await ProviderDb.Query(db, tx, "SELECT ReviewInviteID id,CompanyID companyId,ProviderID providerId,ServiceTypeID serviceTypeId,StatusCode status,ExpiresAt expiresAt FROM dbo.TDPRReviewInvite WITH(UPDLOCK,HOLDLOCK) WHERE TokenHash=@hash", token, ("@hash", hash)); if (rows.Count == 0) { await tx.RollbackAsync(token); return NotFound(new { message = "ลิงก์ไม่ถูกต้อง" }); }
        var row = rows[0]; if (Convert.ToString(row["status"]) != "ACTIVE" || Convert.ToDateTime(row["expiresAt"]) < DateTime.UtcNow) { await tx.RollbackAsync(token); return Conflict(new { message = "ลิงก์ถูกใช้ ยกเลิก หรือหมดอายุแล้ว" }); }
        var id = Convert.ToInt64(row["id"]); await ProviderDb.Execute(db, tx, "INSERT dbo.TDPRReview(CompanyID,ProviderID,ReviewInviteID,ServiceTypeID,QualityScore,PunctualityScore,ServiceScore,ValueScore,CommentText) VALUES(@company,@provider,@invite,@service,@quality,@punctuality,@serviceScore,@value,@comment);UPDATE dbo.TDPRReviewInvite SET StatusCode=N'USED',UsedAt=SYSUTCDATETIME(),UpdateDate=SYSUTCDATETIME() WHERE ReviewInviteID=@invite", token, ("@company", row["companyId"]), ("@provider", row["providerId"]), ("@invite", id), ("@service", row["serviceTypeId"]), ("@quality", request.Quality), ("@punctuality", request.Punctuality), ("@serviceScore", request.Service), ("@value", request.Value), ("@comment", Clean(request.Comment))); await tx.CommitAsync(token); return Ok(new { message = "ขอบคุณสำหรับการประเมิน" });
    }
    static string Hash(string value) => Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(value)));
}
