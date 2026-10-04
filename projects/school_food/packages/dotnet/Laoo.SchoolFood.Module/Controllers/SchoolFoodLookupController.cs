using Microsoft.AspNetCore.Mvc;
namespace Laoo.SchoolFood.Controllers;
public sealed partial class SchoolFoodController
{
    [HttpGet("lookups/{menu}/{kind}")]
    public async Task<IActionResult> Lookup(string menu,string kind,[FromQuery]string? search=null,[FromQuery]int page=1,CancellationToken ct=default)
    {
        var allowed=kind switch{
            "students"=>menu is "53005" or "53007" or "53010",
            "items"=>menu is "53003" or "53004" or "53006",
            "categories"=>menu=="53004",
            "users"=>menu=="53002",_=>false};
        if(!allowed)return NotFound();
        await using var db=await Open(ct);
        if(await Guard(db,menu,"VIEW",ct,schoolOnly:kind is "students" or "users") is {} f)return f;
        var source=kind switch{
            "students"=>"SELECT StudentID id,StudentCode code,CONCAT(FirstName,N' ',LastName) name FROM dbo.TDSCStudent WHERE CompanyID=@co AND IsActive=1",
            "items"=>"SELECT ItemID id,ItemCode code,ItemName name FROM dbo.TDIVItem WHERE CompanyID=@co AND IsActive=1",
            "categories"=>"SELECT DISTINCT ItemTypeCode id,ItemTypeCode code,ItemTypeCode name FROM dbo.TDIVItem WHERE CompanyID=@co AND IsActive=1 AND ItemTypeCode IS NOT NULL AND ItemTypeCode<>N''",
            _=>"SELECT UserID id,Username code,Username name FROM dbo.TDADUser WHERE CompanyID=@co AND IsActive=1 AND IsCompanyAdmin=0"};
        var cte="WITH Choices AS("+source+") ";
        const string where=" FROM Choices WHERE (@q IS NULL OR code LIKE N'%'+@q+N'%' OR name LIKE N'%'+@q+N'%')";
        page=Math.Clamp(page,1,100000);
        var rows=await FoodDb.Rows(db,null,cte+"SELECT *"+where+" ORDER BY code,id OFFSET @offset ROWS FETCH NEXT 20 ROWS ONLY",ct,("@co",Company),("@q",search),("@offset",(page-1)*20));
        var total=await FoodDb.Id(db,null,cte+"SELECT COUNT(*)"+where,ct,("@co",Company),("@q",search));
        return Ok(new{rows,total,page,pageSize=20});
    }
}
