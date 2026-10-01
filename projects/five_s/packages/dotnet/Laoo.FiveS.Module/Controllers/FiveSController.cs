using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooFiveSModule.Controllers;

[ApiController, Authorize, Route("api/company/five-s")]
public sealed class FiveSController(IConfiguration config) : ControllerBase
{
    static readonly string[] Menus = ["39001", "39002", "39003", "39004", "39005", "39006", "39007", "39008", "39009", "39010"];

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken t)
    {
        if (!Menus.Contains(menu)) return NotFound();
        if (!Scope(out _, out _)) return Forbid();
        await using var c = await Open(t);
        if (!await Can(c, menu, "VIEW", t)) return Forbid();
        return Ok(new
        {
            create = await Can(c, menu, "CREATE", t),
            edit = await Can(c, menu, "EDIT", t),
            delete = await Can(c, menu, "DELETE", t),
            submit = await Can(c, menu, "SUBMIT", t),
            actOnBehalf = await Can(c, menu, "ACT_ON_BEHALF", t),
            approve = await Can(c, menu, "APPROVE", t),
            selfApprove = await Can(c, menu, "SELF_APPROVE", t),
            assign = await Can(c, menu, "ASSIGN", t),
            confirm = await Can(c, menu, "CONFIRM", t)
        });
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken t)
    {
        if (!Scope(out var co, out _)) return Forbid();
        await using var c = await Open(t);
        if (!await Can(c, "39010", "VIEW", t)) return Forbid();
        await EnsureSetting(c, co, t);
        return await Rows(c, "SELECT IsEnabled,ScoreMax,DefaultPassPercent,RequireFailurePhoto,RequireClosurePhoto,MaxAttachmentSizeMB,MaxAttachmentsPerItem,LowDueDays,MediumDueDays,HighDueDays,AllowSelfApprove,DefaultApproverUserID FROM dbo.TDFSSetting WHERE CompanyID=@co", co, t);
    }

    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(SettingInput x, CancellationToken t)
    {
        if (!Scope(out var co, out var user)) return Forbid();
        if (x.ScoreMax <= 0 || x.ScoreMax > 100 || x.DefaultPassPercent < 0 || x.DefaultPassPercent > 100 || x.MaxAttachmentSizeMB <= 0 || x.MaxAttachmentSizeMB > 1 || x.MaxAttachmentsPerItem is < 1 or > 20 || x.LowDueDays < 1 || x.MediumDueDays < 1 || x.HighDueDays < 1)
            return Bad("ข้อมูลตั้งค่าไม่ถูกต้อง", "คะแนนและวันครบกำหนดต้องมากกว่า 0 รูปหลังย่อต้องไม่เกิน 1 MB และจำนวนรูปต้องอยู่ระหว่าง 1-20");
        await using var c = await Open(t); if (!await Can(c, "39010", "EDIT", t)) return Forbid();
        if (x.DefaultApproverUserID is long approver && !await UserExists(c, co, approver, t)) return Bad("ผู้ยืนยันไม่ถูกต้อง", "เลือกผู้ใช้ที่เปิดใช้งานในบริษัทเดียวกัน");
        const string sql = "UPDATE dbo.TDFSSetting SET IsEnabled=@e,ScoreMax=@s,DefaultPassPercent=@p,RequireFailurePhoto=@rf,RequireClosurePhoto=@rc,MaxAttachmentSizeMB=@mb,MaxAttachmentsPerItem=@mf,LowDueDays=@l,MediumDueDays=@m,HighDueDays=@h,AllowSelfApprove=@sa,DefaultApproverUserID=@a,UpdateDate=SYSUTCDATETIME(),UpdateBy=@u WHERE CompanyID=@co;IF @@ROWCOUNT=0 INSERT dbo.TDFSSetting(CompanyID,IsEnabled,ScoreMax,DefaultPassPercent,RequireFailurePhoto,RequireClosurePhoto,MaxAttachmentSizeMB,MaxAttachmentsPerItem,LowDueDays,MediumDueDays,HighDueDays,AllowSelfApprove,DefaultApproverUserID,UpdateBy) VALUES(@co,@e,@s,@p,@rf,@rc,@mb,@mf,@l,@m,@h,@sa,@a,@u);";
        await using var q = new SqlCommand(sql, c);
        P(q, "@co", SqlDbType.BigInt, co); P(q, "@e", SqlDbType.Bit, x.IsEnabled); P(q, "@s", SqlDbType.Decimal, x.ScoreMax); P(q, "@p", SqlDbType.Decimal, x.DefaultPassPercent); P(q, "@rf", SqlDbType.Bit, x.RequireFailurePhoto); P(q, "@rc", SqlDbType.Bit, x.RequireClosurePhoto); P(q, "@mb", SqlDbType.Decimal, x.MaxAttachmentSizeMB); P(q, "@mf", SqlDbType.Int, x.MaxAttachmentsPerItem); P(q, "@l", SqlDbType.Int, x.LowDueDays); P(q, "@m", SqlDbType.Int, x.MediumDueDays); P(q, "@h", SqlDbType.Int, x.HighDueDays); P(q, "@sa", SqlDbType.Bit, x.AllowSelfApprove); P(q, "@a", SqlDbType.BigInt, x.DefaultApproverUserID); P(q, "@u", SqlDbType.BigInt, user);
        await q.ExecuteNonQueryAsync(t); return NoContent();
    }

    [HttpGet("options")]
    public async Task<IActionResult> Options(CancellationToken t)
    {
        if (!Scope(out var co, out _)) return Forbid(); await using var c = await Open(t); if (!await HasAnyView(c, t)) return Forbid();
        const string sql = "SELECT UserID id,Username code,COALESCE(NULLIF(DisplayName,N''),Username) name FROM dbo.TDADUser WHERE CompanyID=@co AND IsActive=1 ORDER BY name;SELECT BuildingID id,BuildingCode code,BuildingNameTH name FROM dbo.TDADBuilding WHERE CompanyID=@co AND IsActive=1 ORDER BY BuildingCode;SELECT FloorID id,BuildingID parentId,FloorCode code,FloorNameTH name FROM dbo.TDADFloor WHERE IsActive=1 AND BuildingID IN(SELECT BuildingID FROM dbo.TDADBuilding WHERE CompanyID=@co) ORDER BY FloorCode;SELECT RoomID id,FloorID parentId,RoomCode code,RoomNameTH name FROM dbo.TDADRoom WHERE CompanyID=@co AND IsActive=1 ORDER BY RoomCode;SELECT TemplateID id,TemplateCode code,TemplateName name FROM dbo.TDFSTemplate WHERE CompanyID=@co AND IsActive=1 ORDER BY TemplateCode;SELECT TeamID id,TeamCode code,TeamName name FROM dbo.TDFSTeam WHERE CompanyID=@co AND IsActive=1 ORDER BY TeamCode;SELECT AreaID id,AreaCode code,AreaName name FROM dbo.TDFSArea WHERE CompanyID=@co AND IsActive=1 ORDER BY AreaCode;";
        return await Multi(c, sql, co, t, ["users", "buildings", "floors", "rooms", "templates", "teams", "areas"]);
    }

    [HttpGet("areas")]
    public Task<IActionResult> Areas(CancellationToken t) => Read("39001", "SELECT AreaID id,AreaCode code,AreaName name,BranchID,BuildingID,FloorID,RoomID,DepartmentID,OwnerUserID,DescriptionText description,IsActive active FROM dbo.TDFSArea WHERE CompanyID=@co ORDER BY AreaCode", t);

    [HttpPost("areas")]
    public Task<IActionResult> CreateArea(AreaInput x, CancellationToken t) => SaveArea(null, x, "CREATE", t);

    [HttpPut("areas/{id:long}")]
    public Task<IActionResult> UpdateArea(long id, AreaInput x, CancellationToken t) => SaveArea(id, x, "EDIT", t);

    [HttpDelete("areas/{id:long}")]
    public async Task<IActionResult> DeleteArea(long id, CancellationToken t)
    {
        if (!Scope(out var co, out _)) return Forbid(); await using var c = await Open(t); if (!await Can(c, "39001", "DELETE", t)) return Forbid();
        await using var q = new SqlCommand("DELETE dbo.TDFSArea WHERE AreaID=@id AND CompanyID=@co", c); P(q, "@id", SqlDbType.BigInt, id); P(q, "@co", SqlDbType.BigInt, co);
        try { return await q.ExecuteNonQueryAsync(t) == 1 ? NoContent() : NotFound(); }
        catch (SqlException e) when (e.Number == 547) { return Conflict(new { message = "ลบพื้นที่ไม่ได้", description = "พื้นที่ถูกใช้ในแผนหรือผลตรวจแล้ว ให้ปิดสถานะแทนการลบ" }); }
    }

    async Task<IActionResult> SaveArea(long? id, AreaInput x, string action, CancellationToken t)
    {
        if (!Scope(out var co, out var user)) return Forbid();
        if (string.IsNullOrWhiteSpace(x.Code) || string.IsNullOrWhiteSpace(x.Name)) return Bad("ข้อมูลไม่ครบ", "ระบุรหัสและชื่อพื้นที่ตรวจ");
        await using var c = await Open(t); if (!await Can(c, "39001", action, t)) return Forbid();
        if (x.OwnerUserID is long owner && !await UserExists(c, co, owner, t)) return Bad("ผู้รับผิดชอบไม่ถูกต้อง", "เลือกผู้ใช้ในบริษัทเดียวกัน");
        var sql = id is null
         ? "INSERT dbo.TDFSArea(CompanyID,AreaCode,AreaName,BranchID,BuildingID,FloorID,RoomID,DepartmentID,OwnerUserID,DescriptionText,IsActive,CreateBy) OUTPUT INSERTED.AreaID VALUES(@co,@code,@name,@branch,@building,@floor,@room,@department,@owner,@description,@active,@user)"
         : "UPDATE dbo.TDFSArea SET AreaCode=@code,AreaName=@name,BranchID=@branch,BuildingID=@building,FloorID=@floor,RoomID=@room,DepartmentID=@department,OwnerUserID=@owner,DescriptionText=@description,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE AreaID=@id AND CompanyID=@co";
        await using var q = new SqlCommand(sql, c); P(q, "@co", SqlDbType.BigInt, co); P(q, "@id", SqlDbType.BigInt, id); P(q, "@code", SqlDbType.NVarChar, x.Code.Trim().ToUpperInvariant(), 30); P(q, "@name", SqlDbType.NVarChar, x.Name.Trim(), 200); P(q, "@branch", SqlDbType.BigInt, x.BranchID); P(q, "@building", SqlDbType.BigInt, x.BuildingID); P(q, "@floor", SqlDbType.BigInt, x.FloorID); P(q, "@room", SqlDbType.BigInt, x.RoomID); P(q, "@department", SqlDbType.BigInt, x.DepartmentID); P(q, "@owner", SqlDbType.BigInt, x.OwnerUserID); P(q, "@description", SqlDbType.NVarChar, Clean(x.Description), 1000); P(q, "@active", SqlDbType.Bit, x.IsActive); P(q, "@user", SqlDbType.BigInt, user);
        try { if (id is null) return Ok(new { id = Convert.ToInt64(await q.ExecuteScalarAsync(t)) }); return await q.ExecuteNonQueryAsync(t) == 1 ? NoContent() : NotFound(); }
        catch (SqlException e) when (e.Number is 2601 or 2627) { return Conflict(new { message = "รหัสพื้นที่ซ้ำ", description = "กรุณาใช้รหัสพื้นที่อื่นภายในบริษัท" }); }
    }

    [HttpGet("templates")]
    public Task<IActionResult> Templates(CancellationToken t) => Read("39002", "SELECT h.TemplateID id,h.TemplateCode code,h.TemplateName name,h.VersionNo version,h.PassPercent passPercent,h.IsActive active,COUNT(d.TemplateItemID) itemCount FROM dbo.TDFSTemplate h LEFT JOIN dbo.TDFSTemplateItem d ON d.TemplateID=h.TemplateID WHERE h.CompanyID=@co GROUP BY h.TemplateID,h.TemplateCode,h.TemplateName,h.VersionNo,h.PassPercent,h.IsActive ORDER BY h.TemplateCode,h.VersionNo DESC", t);

    [HttpGet("templates/{id:long}")]
    public Task<IActionResult> Template(long id, CancellationToken t) => ReadDetail("39002", id, "SELECT TemplateID id,TemplateCode code,TemplateName name,VersionNo version,PassPercent passPercent,DescriptionText description,IsActive active FROM dbo.TDFSTemplate WHERE CompanyID=@co AND TemplateID=@id", "SELECT TemplateItemID id,CategoryCode category,QuestionText question,WeightValue weight,IsCritical critical,RequireFailurePhoto requirePhoto FROM dbo.TDFSTemplateItem WHERE CompanyID=@co AND TemplateID=@id ORDER BY SortOrder", t);

    [HttpGet("teams")]
    public Task<IActionResult> Teams(CancellationToken t) => Read("39003", "SELECT h.TeamID id,h.TeamCode code,h.TeamName name,h.LeaderUserID,COALESCE(NULLIF(u.DisplayName,N''),u.Username) leaderName,h.EffectiveFrom,h.EffectiveTo,h.IsActive active,COUNT(m.TeamMemberID) memberCount FROM dbo.TDFSTeam h LEFT JOIN dbo.TDADUser u ON u.CompanyID=h.CompanyID AND u.UserID=h.LeaderUserID LEFT JOIN dbo.TDFSTeamMember m ON m.TeamID=h.TeamID WHERE h.CompanyID=@co GROUP BY h.TeamID,h.TeamCode,h.TeamName,h.LeaderUserID,u.DisplayName,u.Username,h.EffectiveFrom,h.EffectiveTo,h.IsActive ORDER BY h.TeamCode", t);

    [HttpGet("teams/{id:long}")]
    public Task<IActionResult> Team(long id, CancellationToken t) => ReadDetail("39003", id, "SELECT TeamID id,TeamCode code,TeamName name,LeaderUserID leaderUserID,EffectiveFrom effectiveFrom,EffectiveTo effectiveTo,IsActive active FROM dbo.TDFSTeam WHERE CompanyID=@co AND TeamID=@id", "SELECT UserID userID FROM dbo.TDFSTeamMember WHERE CompanyID=@co AND TeamID=@id ORDER BY TeamMemberID", t);

    [HttpGet("plans")]
    public Task<IActionResult> Plans(CancellationToken t) => Read("39004", "SELECT p.PlanID id,p.PlanNo number,p.PlanName name,p.StartDate,p.EndDate,p.FrequencyCode frequency,p.StatusCode status,t.TemplateName template,tm.TeamName team,COUNT(a.PlanAreaID) areaCount FROM dbo.TDFSPlan p JOIN dbo.TDFSTemplate t ON t.TemplateID=p.TemplateID JOIN dbo.TDFSTeam tm ON tm.TeamID=p.TeamID LEFT JOIN dbo.TDFSPlanArea a ON a.PlanID=p.PlanID WHERE p.CompanyID=@co GROUP BY p.PlanID,p.PlanNo,p.PlanName,p.StartDate,p.EndDate,p.FrequencyCode,p.StatusCode,t.TemplateName,tm.TeamName ORDER BY p.StartDate DESC,p.PlanID DESC", t);

    [HttpGet("plans/{id:long}")]
    public Task<IActionResult> Plan(long id, CancellationToken t) => ReadDetail("39004", id, "SELECT PlanID id,PlanNo number,PlanName name,TemplateID templateID,TeamID teamID,ApproverUserID approverUserID,StartDate startDate,EndDate endDate,FrequencyCode frequency,Remark remark,StatusCode status FROM dbo.TDFSPlan WHERE CompanyID=@co AND PlanID=@id", "SELECT PlanAreaID id,AreaID areaID,ScheduledAt scheduledAt FROM dbo.TDFSPlanArea WHERE CompanyID=@co AND PlanID=@id ORDER BY ScheduledAt", t);

    [HttpGet("inspections")]
    public Task<IActionResult> Inspections(CancellationToken t) => Read("39005", "SELECT InspectionID id,InspectionNo number,AreaNameSnapshot area,TemplateNameSnapshot template,TeamNameSnapshot team,ScheduledAt,ScorePercent,StatusCode status,InspectorUserID FROM dbo.TDFSInspection WHERE CompanyID=@co ORDER BY ScheduledAt DESC,InspectionID DESC", t);

    [HttpGet("confirmations")]
    public Task<IActionResult> Confirmations(CancellationToken t) => Read("39006", "SELECT InspectionID id,InspectionNo number,AreaNameSnapshot area,TemplateNameSnapshot template,ScorePercent,SubmittedAt,ApproverUserID,StatusCode status FROM dbo.TDFSInspection WHERE CompanyID=@co AND StatusCode IN(N'SUBMITTED',N'CONFIRMED',N'RETURNED') ORDER BY SubmittedAt DESC", t);

    [HttpGet("findings")]
    public Task<IActionResult> Findings(CancellationToken t) => Read("39007", "SELECT f.FindingID id,f.FindingNo number,i.InspectionNo inspection,a.AreaName area,f.SeverityCode severity,f.DescriptionText description,f.AssignedUserID,f.DueDate,f.StatusCode status,CASE WHEN f.StatusCode<>N'CLOSED' AND f.DueDate<CONVERT(date,SYSUTCDATETIME()) THEN CONVERT(bit,1) ELSE CONVERT(bit,0) END overdue FROM dbo.TDFSFinding f JOIN dbo.TDFSInspection i ON i.InspectionID=f.InspectionID JOIN dbo.TDFSArea a ON a.AreaID=f.AreaID WHERE f.CompanyID=@co ORDER BY CASE WHEN f.StatusCode=N'CLOSED' THEN 1 ELSE 0 END,f.DueDate", t);

    [HttpGet("history")]
    public Task<IActionResult> History(CancellationToken t) => Read("39008", "SELECT InspectionID id,InspectionNo number,AreaNameSnapshot area,TemplateNameSnapshot template,TemplateVersionSnapshot version,ScorePercent,PassPercentSnapshot,ConfirmedAt,ConfirmedBy,StatusCode status FROM dbo.TDFSInspection WHERE CompanyID=@co AND StatusCode=N'CONFIRMED' ORDER BY ConfirmedAt DESC", t);

    [HttpGet("reports")]
    public Task<IActionResult> Reports(CancellationToken t) => Read("39009", "SELECT COUNT(*) confirmedCount,AVG(ScorePercent) averageScore,SUM(CASE WHEN ScorePercent>=PassPercentSnapshot THEN 1 ELSE 0 END) passedCount,(SELECT COUNT(*) FROM dbo.TDFSFinding f WHERE f.CompanyID=@co AND f.StatusCode<>N'CLOSED') openFindings,(SELECT COUNT(*) FROM dbo.TDFSFinding f WHERE f.CompanyID=@co AND f.StatusCode<>N'CLOSED' AND f.DueDate<CONVERT(date,SYSUTCDATETIME())) overdueFindings FROM dbo.TDFSInspection WHERE CompanyID=@co AND StatusCode=N'CONFIRMED'", t);

    [HttpPost("templates")]
    public Task<IActionResult> CreateTemplate(TemplateInput x, CancellationToken t) => SaveTemplate(null, x, "CREATE", t);
    [HttpPut("templates/{id:long}")]
    public Task<IActionResult> UpdateTemplate(long id, TemplateInput x, CancellationToken t) => SaveTemplate(id, x, "EDIT", t);
    [HttpDelete("templates/{id:long}")]
    public Task<IActionResult> DeleteTemplate(long id, CancellationToken t) => DeleteMaster("39002", "dbo.TDFSTemplate", "TemplateID", id, "Template ถูกใช้ในแผนหรือใบตรวจแล้ว ให้ปิดสถานะแทน", t);

    async Task<IActionResult> SaveTemplate(long? id, TemplateInput x, string action, CancellationToken t)
    {
        if (!Scope(out var co, out var user)) return Forbid(); if (string.IsNullOrWhiteSpace(x.Code) || string.IsNullOrWhiteSpace(x.Name) || x.PassPercent is < 0 or > 100 || x.Items is null || x.Items.Count == 0) return Bad("ข้อมูล Template ไม่ครบ", "ระบุรหัส ชื่อ เกณฑ์ผ่าน และคำถามอย่างน้อยหนึ่งข้อ");
        if (x.Items.Any(i => string.IsNullOrWhiteSpace(i.Question) || i.Weight <= 0 || !Categories.Contains(i.Category, StringComparer.OrdinalIgnoreCase))) return Bad("รายการตรวจไม่ถูกต้อง", "คำถาม น้ำหนัก และหมวด 5ส ต้องถูกต้อง");
        await using var c = await Open(t); if (!await Can(c, "39002", action, t)) return Forbid(); await using var tx = (SqlTransaction)await c.BeginTransactionAsync(t);
        try
        {
            if (id is not null) { await using var used = new SqlCommand("SELECT COUNT(*) FROM dbo.TDFSInspection WHERE CompanyID=@co AND TemplateID=@id", c, tx); P(used, "@co", SqlDbType.BigInt, co); P(used, "@id", SqlDbType.BigInt, id); if (Convert.ToInt32(await used.ExecuteScalarAsync(t)) > 0) { await tx.RollbackAsync(t); return Conflict(new { message = "Template ถูกใช้งานแล้ว", description = "ให้สร้าง Version ใหม่แทนการแก้ไข Template ที่ถูก snapshot แล้ว" }); } }
            var sql = id is null ? "INSERT dbo.TDFSTemplate(CompanyID,TemplateCode,TemplateName,VersionNo,DescriptionText,PassPercent,IsActive,CreateBy) OUTPUT INSERTED.TemplateID VALUES(@co,@code,@name,@version,@description,@pass,@active,@user)" : "UPDATE dbo.TDFSTemplate SET TemplateCode=@code,TemplateName=@name,VersionNo=@version,DescriptionText=@description,PassPercent=@pass,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@co AND TemplateID=@id;SELECT @id";
            await using var h = new SqlCommand(sql, c, tx); P(h, "@co", SqlDbType.BigInt, co); P(h, "@id", SqlDbType.BigInt, id); P(h, "@code", SqlDbType.NVarChar, x.Code.Trim().ToUpperInvariant(), 30); P(h, "@name", SqlDbType.NVarChar, x.Name.Trim(), 200); P(h, "@version", SqlDbType.Int, x.Version); P(h, "@description", SqlDbType.NVarChar, Clean(x.Description), 1000); P(h, "@pass", SqlDbType.Decimal, x.PassPercent); P(h, "@active", SqlDbType.Bit, x.IsActive); P(h, "@user", SqlDbType.BigInt, user); var saved = Convert.ToInt64(await h.ExecuteScalarAsync(t));
            await using (var d = new SqlCommand("DELETE dbo.TDFSTemplateItem WHERE TemplateID=@id AND CompanyID=@co", c, tx)) { P(d, "@id", SqlDbType.BigInt, saved); P(d, "@co", SqlDbType.BigInt, co); await d.ExecuteNonQueryAsync(t); }
            var order = 0; foreach (var item in x.Items) { await using var d = new SqlCommand("INSERT dbo.TDFSTemplateItem(CompanyID,TemplateID,CategoryCode,SortOrder,QuestionText,WeightValue,IsCritical,RequireFailurePhoto) VALUES(@co,@id,@category,@sort,@question,@weight,@critical,@photo)", c, tx); P(d, "@co", SqlDbType.BigInt, co); P(d, "@id", SqlDbType.BigInt, saved); P(d, "@category", SqlDbType.NVarChar, item.Category.ToUpperInvariant(), 20); P(d, "@sort", SqlDbType.Int, ++order); P(d, "@question", SqlDbType.NVarChar, item.Question.Trim(), 1000); P(d, "@weight", SqlDbType.Decimal, item.Weight); P(d, "@critical", SqlDbType.Bit, item.IsCritical); P(d, "@photo", SqlDbType.Bit, item.RequireFailurePhoto); await d.ExecuteNonQueryAsync(t); }
            await tx.CommitAsync(t); return Ok(new { id = saved });
        }
        catch (SqlException e) when (e.Number is 2601 or 2627) { await tx.RollbackAsync(t); return Conflict(new { message = "รหัสหรือ Version ซ้ำ", description = "ใช้รหัสและ Version อื่นภายในบริษัท" }); }
        catch { await tx.RollbackAsync(t); throw; }
    }

    [HttpPost("teams")]
    public Task<IActionResult> CreateTeam(TeamInput x, CancellationToken t) => SaveTeam(null, x, "CREATE", t);
    [HttpPut("teams/{id:long}")]
    public Task<IActionResult> UpdateTeam(long id, TeamInput x, CancellationToken t) => SaveTeam(id, x, "EDIT", t);
    [HttpDelete("teams/{id:long}")]
    public Task<IActionResult> DeleteTeam(long id, CancellationToken t) => DeleteMaster("39003", "dbo.TDFSTeam", "TeamID", id, "ทีมถูกใช้ในแผนหรือใบตรวจแล้ว ให้ปิดสถานะแทน", t);

    async Task<IActionResult> SaveTeam(long? id, TeamInput x, string action, CancellationToken t)
    {
        if (!Scope(out var co, out var user)) return Forbid(); var members = (x.MemberUserIDs ?? []).Where(v => v > 0).Append(x.LeaderUserID).Distinct().ToArray();
        if (string.IsNullOrWhiteSpace(x.Code) || string.IsNullOrWhiteSpace(x.Name) || x.LeaderUserID <= 0 || members.Length == 0 || x.EffectiveTo < x.EffectiveFrom) return Bad("ข้อมูลทีมไม่ถูกต้อง", "ระบุรหัส ชื่อ หัวหน้าทีม สมาชิก และช่วงวันที่ให้ถูกต้อง");
        await using var c = await Open(t); if (!await Can(c, "39003", action, t)) return Forbid(); if (!await UsersExist(c, co, members, t)) return Bad("สมาชิกทีมไม่ถูกต้อง", "สมาชิกทุกคนต้องเป็นผู้ใช้ Active ในบริษัทเดียวกัน"); await using var tx = (SqlTransaction)await c.BeginTransactionAsync(t);
        try { var sql = id is null ? "INSERT dbo.TDFSTeam(CompanyID,TeamCode,TeamName,LeaderUserID,EffectiveFrom,EffectiveTo,IsActive,CreateBy) OUTPUT INSERTED.TeamID VALUES(@co,@code,@name,@leader,@from,@to,@active,@user)" : "UPDATE dbo.TDFSTeam SET TeamCode=@code,TeamName=@name,LeaderUserID=@leader,EffectiveFrom=@from,EffectiveTo=@to,IsActive=@active,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@co AND TeamID=@id;SELECT @id"; await using var h = new SqlCommand(sql, c, tx); P(h, "@co", SqlDbType.BigInt, co); P(h, "@id", SqlDbType.BigInt, id); P(h, "@code", SqlDbType.NVarChar, x.Code.Trim().ToUpperInvariant(), 30); P(h, "@name", SqlDbType.NVarChar, x.Name.Trim(), 200); P(h, "@leader", SqlDbType.BigInt, x.LeaderUserID); P(h, "@from", SqlDbType.Date, x.EffectiveFrom); P(h, "@to", SqlDbType.Date, x.EffectiveTo); P(h, "@active", SqlDbType.Bit, x.IsActive); P(h, "@user", SqlDbType.BigInt, user); var saved = Convert.ToInt64(await h.ExecuteScalarAsync(t)); await using (var d = new SqlCommand("DELETE dbo.TDFSTeamMember WHERE TeamID=@id AND CompanyID=@co", c, tx)) { P(d, "@id", SqlDbType.BigInt, saved); P(d, "@co", SqlDbType.BigInt, co); await d.ExecuteNonQueryAsync(t); } foreach (var member in members) { await using var d = new SqlCommand("INSERT dbo.TDFSTeamMember(CompanyID,TeamID,UserID) VALUES(@co,@id,@user)", c, tx); P(d, "@co", SqlDbType.BigInt, co); P(d, "@id", SqlDbType.BigInt, saved); P(d, "@user", SqlDbType.BigInt, member); await d.ExecuteNonQueryAsync(t); } await tx.CommitAsync(t); return Ok(new { id = saved }); }
        catch (SqlException e) when (e.Number is 2601 or 2627) { await tx.RollbackAsync(t); return Conflict(new { message = "รหัสทีมหรือสมาชิกซ้ำ", description = "ตรวจรหัสทีมและสมาชิกก่อนบันทึก" }); }
        catch { await tx.RollbackAsync(t); throw; }
    }

    [HttpPost("plans")]
    public Task<IActionResult> CreatePlan(PlanInput x, CancellationToken t) => SavePlan(null, x, "CREATE", t);
    [HttpPut("plans/{id:long}")]
    public Task<IActionResult> UpdatePlan(long id, PlanInput x, CancellationToken t) => SavePlan(id, x, "EDIT", t);
    [HttpDelete("plans/{id:long}")]
    public Task<IActionResult> DeletePlan(long id, CancellationToken t) => DeleteMaster("39004", "dbo.TDFSPlan", "PlanID", id, "ลบได้เฉพาะแผนร่างที่ยังไม่สร้างใบตรวจ", t, " AND StatusCode=N'DRAFT'");

    async Task<IActionResult> SavePlan(long? id, PlanInput x, string action, CancellationToken t)
    {
        if (!Scope(out var co, out var user)) return Forbid(); if (string.IsNullOrWhiteSpace(x.Name) || x.TemplateID <= 0 || x.TeamID <= 0 || x.ApproverUserID <= 0 || x.EndDate < x.StartDate || x.Areas is null || x.Areas.Count == 0 || !Frequencies.Contains(x.Frequency, StringComparer.OrdinalIgnoreCase)) return Bad("ข้อมูลแผนไม่ครบ", "ระบุชื่อ ช่วงวันที่ Template ทีม ผู้ยืนยัน และพื้นที่อย่างน้อยหนึ่งรายการ");
        await using var c = await Open(t); if (!await Can(c, "39004", action, t)) return Forbid(); if (!await UserExists(c, co, x.ApproverUserID, t)) return Bad("ผู้ยืนยันไม่ถูกต้อง", "เลือกผู้ใช้ Active ในบริษัทเดียวกัน");
        await using var valid = new SqlCommand("SELECT (SELECT COUNT(*) FROM dbo.TDFSTemplate WHERE CompanyID=@co AND TemplateID=@template AND IsActive=1)+(SELECT COUNT(*) FROM dbo.TDFSTeam WHERE CompanyID=@co AND TeamID=@team AND IsActive=1)+(SELECT COUNT(*) FROM dbo.TDFSArea WHERE CompanyID=@co AND AreaID IN(" + string.Join(',', x.Areas.Select((_, i) => "@a" + i)) + ") AND IsActive=1)", c); P(valid, "@co", SqlDbType.BigInt, co); P(valid, "@template", SqlDbType.BigInt, x.TemplateID); P(valid, "@team", SqlDbType.BigInt, x.TeamID); for (var i = 0; i < x.Areas.Count; i++) P(valid, "@a" + i, SqlDbType.BigInt, x.Areas[i].AreaID); if (Convert.ToInt32(await valid.ExecuteScalarAsync(t)) != 2 + x.Areas.Select(a => a.AreaID).Distinct().Count()) return Bad("ข้อมูลอ้างอิงไม่ถูกต้อง", "Template ทีม และพื้นที่ต้องเปิดใช้งานในบริษัทเดียวกัน");
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(t); try
        {
            if (id is not null) { await using var state = new SqlCommand("SELECT StatusCode FROM dbo.TDFSPlan WHERE CompanyID=@co AND PlanID=@id", c, tx); P(state, "@co", SqlDbType.BigInt, co); P(state, "@id", SqlDbType.BigInt, id); if (Convert.ToString(await state.ExecuteScalarAsync(t)) != "DRAFT") { await tx.RollbackAsync(t); return Conflict(new { message = "แก้แผนไม่ได้", description = "แก้โครงสร้างได้เฉพาะแผนสถานะ DRAFT" }); } }
            var no = "5SP" + DateTime.UtcNow.ToString("yyyyMMddHHmmssfff"); var sql = id is null ? "INSERT dbo.TDFSPlan(CompanyID,PlanNo,PlanName,TemplateID,TeamID,ApproverUserID,StartDate,EndDate,FrequencyCode,Remark,CreateBy) OUTPUT INSERTED.PlanID VALUES(@co,@no,@name,@template,@team,@approver,@start,@end,@frequency,@remark,@user)" : "UPDATE dbo.TDFSPlan SET PlanName=@name,TemplateID=@template,TeamID=@team,ApproverUserID=@approver,StartDate=@start,EndDate=@end,FrequencyCode=@frequency,Remark=@remark,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@co AND PlanID=@id;SELECT @id"; await using var h = new SqlCommand(sql, c, tx); P(h, "@co", SqlDbType.BigInt, co); P(h, "@id", SqlDbType.BigInt, id); P(h, "@no", SqlDbType.NVarChar, no, 40); P(h, "@name", SqlDbType.NVarChar, x.Name.Trim(), 200); P(h, "@template", SqlDbType.BigInt, x.TemplateID); P(h, "@team", SqlDbType.BigInt, x.TeamID); P(h, "@approver", SqlDbType.BigInt, x.ApproverUserID); P(h, "@start", SqlDbType.Date, x.StartDate); P(h, "@end", SqlDbType.Date, x.EndDate); P(h, "@frequency", SqlDbType.NVarChar, x.Frequency.ToUpperInvariant(), 20); P(h, "@remark", SqlDbType.NVarChar, Clean(x.Remark), 1000); P(h, "@user", SqlDbType.BigInt, user); var saved = Convert.ToInt64(await h.ExecuteScalarAsync(t)); await using (var d = new SqlCommand("DELETE dbo.TDFSPlanArea WHERE CompanyID=@co AND PlanID=@id", c, tx)) { P(d, "@co", SqlDbType.BigInt, co); P(d, "@id", SqlDbType.BigInt, saved); await d.ExecuteNonQueryAsync(t); }
            foreach (var a in x.Areas.DistinctBy(v => (v.AreaID, v.ScheduledAt))) { await using var d = new SqlCommand("INSERT dbo.TDFSPlanArea(CompanyID,PlanID,AreaID,ScheduledAt) VALUES(@co,@id,@area,@at)", c, tx); P(d, "@co", SqlDbType.BigInt, co); P(d, "@id", SqlDbType.BigInt, saved); P(d, "@area", SqlDbType.BigInt, a.AreaID); P(d, "@at", SqlDbType.DateTime2, a.ScheduledAt); await d.ExecuteNonQueryAsync(t); }
            await tx.CommitAsync(t); return Ok(new { id = saved });
        }
        catch { await tx.RollbackAsync(t); throw; }
    }

    [HttpPost("plans/{id:long}/activate")]
    public async Task<IActionResult> ActivatePlan(long id, CancellationToken t)
    {
        if (!Scope(out var co, out var user)) return Forbid(); await using var c = await Open(t); if (!await Can(c, "39004", "EDIT", t)) return Forbid(); await EnsureSetting(c, co, t); await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, t);
        try
        {
            const string header = "SELECT p.TemplateID,p.TeamID,p.ApproverUserID,p.StatusCode,t.TemplateCode,t.TemplateName,t.VersionNo,t.PassPercent,tm.TeamName FROM dbo.TDFSPlan p JOIN dbo.TDFSTemplate t ON t.TemplateID=p.TemplateID AND t.CompanyID=p.CompanyID JOIN dbo.TDFSTeam tm ON tm.TeamID=p.TeamID AND tm.CompanyID=p.CompanyID JOIN dbo.TDFSSetting s ON s.CompanyID=p.CompanyID AND s.IsEnabled=1 WHERE p.CompanyID=@co AND p.PlanID=@id";
            await using var h = new SqlCommand(header, c, tx); P(h, "@co", SqlDbType.BigInt, co); P(h, "@id", SqlDbType.BigInt, id); await using var r = await h.ExecuteReaderAsync(t); if (!await r.ReadAsync(t)) { await r.CloseAsync(); await tx.RollbackAsync(t); return NotFound(new { message = "ไม่พบแผนหรือระบบปิดใช้งาน" }); }
            if (r.GetString(3) != "DRAFT") { await r.CloseAsync(); await tx.RollbackAsync(t); return Conflict(new { message = "เปิดแผนซ้ำไม่ได้", description = "เปิดใช้งานได้เฉพาะแผน DRAFT" }); }
            var template = r.GetInt64(0); var team = r.GetInt64(1); var approver = r.GetInt64(2); var tc = r.GetString(4); var tn = r.GetString(5); var version = r.GetInt32(6); var pass = r.GetDecimal(7); var teamName = r.GetString(8); await r.CloseAsync();
            await using var areas = new SqlCommand("SELECT pa.PlanAreaID,pa.AreaID,pa.ScheduledAt,a.AreaCode,a.AreaName FROM dbo.TDFSPlanArea pa JOIN dbo.TDFSArea a ON a.AreaID=pa.AreaID AND a.CompanyID=pa.CompanyID AND a.IsActive=1 WHERE pa.CompanyID=@co AND pa.PlanID=@id", c, tx); P(areas, "@co", SqlDbType.BigInt, co); P(areas, "@id", SqlDbType.BigInt, id); await using var ar = await areas.ExecuteReaderAsync(t); var rows = new List<(long pa, long area, DateTime at, string code, string name)>(); while (await ar.ReadAsync(t)) rows.Add((ar.GetInt64(0), ar.GetInt64(1), ar.GetDateTime(2), ar.GetString(3), ar.GetString(4))); await ar.CloseAsync(); if (rows.Count == 0) { await tx.RollbackAsync(t); return Bad("แผนไม่มีพื้นที่", "เพิ่มพื้นที่และกำหนดวันตรวจก่อนเปิดแผน"); }
            foreach (var a in rows) { var no = "5SI" + DateTime.UtcNow.ToString("yyyyMMddHHmmssfff") + a.pa.ToString()[^Math.Min(3, a.pa.ToString().Length)..]; await using var ins = new SqlCommand("INSERT dbo.TDFSInspection(CompanyID,InspectionNo,PlanID,PlanAreaID,AreaID,TemplateID,TeamID,InspectorUserID,ApproverUserID,ScheduledAt,PassPercentSnapshot,AreaCodeSnapshot,AreaNameSnapshot,TemplateCodeSnapshot,TemplateNameSnapshot,TemplateVersionSnapshot,TeamNameSnapshot,CreateBy) OUTPUT INSERTED.InspectionID VALUES(@co,@no,@plan,@pa,@area,@template,@team,@inspector,@approver,@at,@pass,@ac,@an,@tc,@tn,@version,@teamName,@user)", c, tx); P(ins, "@co", SqlDbType.BigInt, co); P(ins, "@no", SqlDbType.NVarChar, no, 40); P(ins, "@plan", SqlDbType.BigInt, id); P(ins, "@pa", SqlDbType.BigInt, a.pa); P(ins, "@area", SqlDbType.BigInt, a.area); P(ins, "@template", SqlDbType.BigInt, template); P(ins, "@team", SqlDbType.BigInt, team); P(ins, "@inspector", SqlDbType.BigInt, user); P(ins, "@approver", SqlDbType.BigInt, approver); P(ins, "@at", SqlDbType.DateTime2, a.at); P(ins, "@pass", SqlDbType.Decimal, pass); P(ins, "@ac", SqlDbType.NVarChar, a.code, 30); P(ins, "@an", SqlDbType.NVarChar, a.name, 200); P(ins, "@tc", SqlDbType.NVarChar, tc, 30); P(ins, "@tn", SqlDbType.NVarChar, tn, 200); P(ins, "@version", SqlDbType.Int, version); P(ins, "@teamName", SqlDbType.NVarChar, teamName, 200); P(ins, "@user", SqlDbType.BigInt, user); var inspection = Convert.ToInt64(await ins.ExecuteScalarAsync(t)); await using var details = new SqlCommand("INSERT dbo.TDFSInspectionDetail(CompanyID,InspectionID,TemplateItemID,CategoryCode,SortOrder,QuestionTextSnapshot,WeightSnapshot,IsCriticalSnapshot,RequireFailurePhotoSnapshot) SELECT CompanyID,@inspection,TemplateItemID,CategoryCode,SortOrder,QuestionText,WeightValue,IsCritical,RequireFailurePhoto FROM dbo.TDFSTemplateItem WHERE CompanyID=@co AND TemplateID=@template", c, tx); P(details, "@inspection", SqlDbType.BigInt, inspection); P(details, "@co", SqlDbType.BigInt, co); P(details, "@template", SqlDbType.BigInt, template); if (await details.ExecuteNonQueryAsync(t) == 0) throw new InvalidOperationException("Template has no items"); }
            await using var update = new SqlCommand("UPDATE dbo.TDFSPlan SET StatusCode=N'ACTIVE',UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@co AND PlanID=@id AND StatusCode=N'DRAFT'", c, tx); P(update, "@co", SqlDbType.BigInt, co); P(update, "@id", SqlDbType.BigInt, id); P(update, "@user", SqlDbType.BigInt, user); await update.ExecuteNonQueryAsync(t); await tx.CommitAsync(t); return NoContent();
        }
        catch { await tx.RollbackAsync(t); throw; }
    }

    [HttpGet("inspections/{id:long}")]
    public async Task<IActionResult> Inspection(long id, CancellationToken t)
    {
        if (!Scope(out var co, out _)) return Forbid(); await using var c = await Open(t); if (!await Can(c, "39005", "VIEW", t) && !await Can(c, "39006", "VIEW", t) && !await Can(c, "39008", "VIEW", t)) return Forbid();
        await using var h = new SqlCommand("SELECT InspectionID id,InspectionNo number,AreaNameSnapshot area,TemplateNameSnapshot template,TemplateVersionSnapshot version,TeamNameSnapshot team,ScheduledAt,StartedAt,SubmittedAt,ConfirmedAt,StatusCode status,ScorePercent,PassPercentSnapshot,ReturnReason FROM dbo.TDFSInspection WHERE CompanyID=@co AND InspectionID=@id", c); P(h, "@co", SqlDbType.BigInt, co); P(h, "@id", SqlDbType.BigInt, id); var headers = await ReadRows(h, t); if (headers.Count == 0) return NotFound();
        await using var d = new SqlCommand("SELECT InspectionDetailID id,CategoryCode category,SortOrder sortOrder,QuestionTextSnapshot question,WeightSnapshot weight,IsCriticalSnapshot critical,RequireFailurePhotoSnapshot requirePhoto,ScoreValue score,IsNotApplicable notApplicable,Remark remark,CreateFinding createFinding FROM dbo.TDFSInspectionDetail WHERE CompanyID=@co AND InspectionID=@id ORDER BY SortOrder", c); P(d, "@co", SqlDbType.BigInt, co); P(d, "@id", SqlDbType.BigInt, id); return Ok(new { header = headers[0], details = await ReadRows(d, t) });
    }

    [HttpPut("inspections/{id:long}/details")]
    public async Task<IActionResult> SaveInspection(long id, InspectionSaveInput x, CancellationToken t)
    {
        if (!Scope(out var co, out var user)) return Forbid(); if (x.Items is null || x.Items.Count == 0) return Bad("ไม่มีผลตรวจ", "ระบุผลตรวจอย่างน้อยหนึ่งรายการ"); await using var c = await Open(t); var canEdit = await Can(c, "39005", "EDIT", t); var onBehalf = await Can(c, "39005", "ACT_ON_BEHALF", t); if (!canEdit && !onBehalf) return Forbid(); await EnsureSetting(c, co, t); await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, t);
        try
        {
            await using var state = new SqlCommand("SELECT InspectorUserID,StatusCode,(SELECT ScoreMax FROM dbo.TDFSSetting WHERE CompanyID=@co) FROM dbo.TDFSInspection WHERE CompanyID=@co AND InspectionID=@id", c, tx); P(state, "@co", SqlDbType.BigInt, co); P(state, "@id", SqlDbType.BigInt, id); await using var r = await state.ExecuteReaderAsync(t); if (!await r.ReadAsync(t)) { await r.CloseAsync(); await tx.RollbackAsync(t); return NotFound(); }
            var inspector = r.GetInt64(0); var status = r.GetString(1); var max = r.GetDecimal(2); await r.CloseAsync(); if (inspector != user && !onBehalf) { await tx.RollbackAsync(t); return Forbid(); }
            if (status is not ("DRAFT" or "IN_PROGRESS" or "RETURNED")) { await tx.RollbackAsync(t); return Conflict(new { message = "แก้ผลตรวจไม่ได้", description = "แก้ได้เฉพาะร่าง กำลังตรวจ หรือรายการที่ถูกส่งกลับ" }); }
            foreach (var item in x.Items) { if (!item.NotApplicable && (item.Score is null || item.Score < 0 || item.Score > max)) { await tx.RollbackAsync(t); return Bad("คะแนนไม่ถูกต้อง", $"คะแนนต้องอยู่ระหว่าง 0-{max} หรือเลือก N/A"); } await using var q = new SqlCommand("UPDATE dbo.TDFSInspectionDetail SET ScoreValue=@score,IsNotApplicable=@na,Remark=@remark,CreateFinding=@finding WHERE CompanyID=@co AND InspectionID=@inspection AND InspectionDetailID=@detail", c, tx); P(q, "@score", SqlDbType.Decimal, item.NotApplicable ? null : item.Score); P(q, "@na", SqlDbType.Bit, item.NotApplicable); P(q, "@remark", SqlDbType.NVarChar, Clean(item.Remark), 1000); P(q, "@finding", SqlDbType.Bit, item.CreateFinding); P(q, "@co", SqlDbType.BigInt, co); P(q, "@inspection", SqlDbType.BigInt, id); P(q, "@detail", SqlDbType.BigInt, item.DetailID); if (await q.ExecuteNonQueryAsync(t) != 1) { await tx.RollbackAsync(t); return Bad("รายการตรวจไม่ถูกต้อง", "มีรายการที่ไม่ได้อยู่ในใบตรวจนี้"); } }
            await using var update = new SqlCommand("UPDATE dbo.TDFSInspection SET StatusCode=N'IN_PROGRESS',StartedAt=COALESCE(StartedAt,SYSUTCDATETIME()),ReturnReason=NULL,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@co AND InspectionID=@id", c, tx); P(update, "@co", SqlDbType.BigInt, co); P(update, "@id", SqlDbType.BigInt, id); P(update, "@user", SqlDbType.BigInt, user); await update.ExecuteNonQueryAsync(t); await tx.CommitAsync(t); return NoContent();
        }
        catch { await tx.RollbackAsync(t); throw; }
    }

    [HttpPost("inspections/{id:long}/submit")]
    public async Task<IActionResult> SubmitInspection(long id, CancellationToken t)
    {
        if (!Scope(out var co, out var user)) return Forbid(); await using var c = await Open(t); var submit = await Can(c, "39005", "SUBMIT", t); var onBehalf = await Can(c, "39005", "ACT_ON_BEHALF", t); if (!submit && !onBehalf) return Forbid(); await EnsureSetting(c, co, t); await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, t);
        try
        {
            await using var state = new SqlCommand("SELECT InspectorUserID,StatusCode,AreaID,(SELECT ScoreMax FROM dbo.TDFSSetting WHERE CompanyID=@co) maxScore FROM dbo.TDFSInspection WHERE CompanyID=@co AND InspectionID=@id", c, tx); P(state, "@co", SqlDbType.BigInt, co); P(state, "@id", SqlDbType.BigInt, id); await using var r = await state.ExecuteReaderAsync(t); if (!await r.ReadAsync(t)) { await r.CloseAsync(); await tx.RollbackAsync(t); return NotFound(); }
            var inspector = r.GetInt64(0); var status = r.GetString(1); var area = r.GetInt64(2); var max = r.GetDecimal(3); await r.CloseAsync(); if (inspector != user && !onBehalf) { await tx.RollbackAsync(t); return Forbid(); }
            if (status is not ("DRAFT" or "IN_PROGRESS" or "RETURNED")) { await tx.RollbackAsync(t); return Conflict(new { message = "ส่งผลตรวจซ้ำไม่ได้", description = "สถานะปัจจุบันไม่อนุญาตให้ส่งผลตรวจ" }); }
            await using var validate = new SqlCommand("SELECT COUNT(*) total,SUM(CASE WHEN ScoreValue IS NULL AND IsNotApplicable=0 THEN 1 ELSE 0 END) missing,SUM(CASE WHEN IsNotApplicable=0 THEN WeightSnapshot ELSE 0 END) weights,SUM(CASE WHEN IsNotApplicable=0 THEN ScoreValue*WeightSnapshot ELSE 0 END) points FROM dbo.TDFSInspectionDetail WHERE CompanyID=@co AND InspectionID=@id", c, tx); P(validate, "@co", SqlDbType.BigInt, co); P(validate, "@id", SqlDbType.BigInt, id); await using var vr = await validate.ExecuteReaderAsync(t); await vr.ReadAsync(t); var total = vr.GetInt32(0); var missing = vr.IsDBNull(1) ? 0 : vr.GetInt32(1); var weights = vr.IsDBNull(2) ? 0 : vr.GetDecimal(2); var points = vr.IsDBNull(3) ? 0 : vr.GetDecimal(3); await vr.CloseAsync(); if (total == 0 || missing > 0 || weights <= 0) { await tx.RollbackAsync(t); return Bad("ผลตรวจยังไม่ครบ", "ให้คะแนนหรือเลือก N/A ให้ครบทุกข้อ และต้องมีอย่างน้อยหนึ่งข้อที่นำมาคำนวณ"); }
            var percent = Math.Round(points / (weights * max) * 100m, 4);
            await using var photoCheck = new SqlCommand("SELECT COUNT(*) FROM dbo.TDFSInspectionDetail d JOIN dbo.TDFSSetting s ON s.CompanyID=d.CompanyID WHERE d.CompanyID=@co AND d.InspectionID=@id AND d.IsNotApplicable=0 AND d.ScoreValue<@max AND (s.RequireFailurePhoto=1 OR d.RequireFailurePhotoSnapshot=1) AND NOT EXISTS(SELECT 1 FROM dbo.TDFSAttachment a WHERE a.CompanyID=d.CompanyID AND a.InspectionDetailID=d.InspectionDetailID AND a.StageCode=N'INSPECTION')", c, tx); P(photoCheck, "@co", SqlDbType.BigInt, co); P(photoCheck, "@id", SqlDbType.BigInt, id); P(photoCheck, "@max", SqlDbType.Decimal, max); if (Convert.ToInt32(await photoCheck.ExecuteScalarAsync(t)) > 0) { await tx.RollbackAsync(t); return Bad("รูปหลักฐานไม่ครบ", "รายการที่ไม่ผ่านต้องแนบรูปหลักฐานก่อนส่งผลตรวจ"); }
            await using var update = new SqlCommand("UPDATE dbo.TDFSInspection SET StatusCode=N'SUBMITTED',TotalScore=@points,ScorePercent=@percent,SubmittedAt=SYSUTCDATETIME(),ReturnReason=NULL,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@co AND InspectionID=@id", c, tx); P(update, "@points", SqlDbType.Decimal, points); P(update, "@percent", SqlDbType.Decimal, percent); P(update, "@user", SqlDbType.BigInt, user); P(update, "@co", SqlDbType.BigInt, co); P(update, "@id", SqlDbType.BigInt, id); await update.ExecuteNonQueryAsync(t);
            const string findingSql = "INSERT dbo.TDFSFinding(CompanyID,FindingNo,InspectionID,InspectionDetailID,AreaID,SeverityCode,DescriptionText,DueDate,CreateBy) SELECT d.CompanyID,N'5SF'+FORMAT(SYSUTCDATETIME(),'yyyyMMddHHmmss')+RIGHT(CONVERT(nvarchar(36),NEWID()),5),d.InspectionID,d.InspectionDetailID,@area,CASE WHEN d.IsCriticalSnapshot=1 THEN N'HIGH' WHEN d.ScoreValue<@max*0.4 THEN N'MEDIUM' ELSE N'LOW' END,d.QuestionTextSnapshot,DATEADD(DAY,CASE WHEN d.IsCriticalSnapshot=1 THEN s.HighDueDays WHEN d.ScoreValue<@max*0.4 THEN s.MediumDueDays ELSE s.LowDueDays END,CONVERT(date,SYSUTCDATETIME())),@user FROM dbo.TDFSInspectionDetail d JOIN dbo.TDFSSetting s ON s.CompanyID=d.CompanyID WHERE d.CompanyID=@co AND d.InspectionID=@id AND d.IsNotApplicable=0 AND (d.ScoreValue<@max OR d.CreateFinding=1 OR d.IsCriticalSnapshot=1) AND NOT EXISTS(SELECT 1 FROM dbo.TDFSFinding f WHERE f.InspectionDetailID=d.InspectionDetailID);";
            await using var finding = new SqlCommand(findingSql, c, tx); P(finding, "@area", SqlDbType.BigInt, area); P(finding, "@max", SqlDbType.Decimal, max); P(finding, "@user", SqlDbType.BigInt, user); P(finding, "@co", SqlDbType.BigInt, co); P(finding, "@id", SqlDbType.BigInt, id); await finding.ExecuteNonQueryAsync(t); await Audit(c, tx, co, "INSPECTION", id, "SUBMIT", status, "SUBMITTED", null, user, t); await tx.CommitAsync(t); return Ok(new { scorePercent = percent });
        }
        catch { await tx.RollbackAsync(t); throw; }
    }

    [HttpPost("confirmations/{id:long}/{operation}")]
    public async Task<IActionResult> ConfirmInspection(long id, [FromRoute(Name = "operation")] string action, DecisionInput x, CancellationToken t)
    {
        action = action.Trim().ToLowerInvariant(); if (action != "approve" && action != "return") return Bad("Action ไม่ถูกต้อง", "รองรับ approve หรือ return เท่านั้น"); if (!Scope(out var co, out var user)) return Forbid(); await using var c = await Open(t); if (!await Can(c, "39006", "APPROVE", t)) return Forbid(); var canSelfApprove = await Can(c, "39006", "SELF_APPROVE", t); await EnsureSetting(c, co, t); await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, t);
        try
        {
            await using var state = new SqlCommand("SELECT InspectorUserID,ApproverUserID,StatusCode,(SELECT AllowSelfApprove FROM dbo.TDFSSetting WHERE CompanyID=@co) FROM dbo.TDFSInspection WHERE CompanyID=@co AND InspectionID=@id", c, tx); P(state, "@co", SqlDbType.BigInt, co); P(state, "@id", SqlDbType.BigInt, id); await using var r = await state.ExecuteReaderAsync(t); if (!await r.ReadAsync(t)) { await r.CloseAsync(); await tx.RollbackAsync(t); return NotFound(); }
            var inspector = r.GetInt64(0); var approver = r.GetInt64(1); var status = r.GetString(2); var allowSelf = r.GetBoolean(3); await r.CloseAsync(); if (status != "SUBMITTED") { await tx.RollbackAsync(t); return Conflict(new { message = "สถานะไม่ถูกต้อง", description = "ดำเนินการได้เฉพาะผลตรวจที่ส่งยืนยันแล้ว" }); }
            if (approver != user) { await tx.RollbackAsync(t); return Forbid(); }
            if (inspector == user && !allowSelf && !canSelfApprove) { await tx.RollbackAsync(t); return Forbid(); }
            if (action == "return" && string.IsNullOrWhiteSpace(x.Remark)) { await tx.RollbackAsync(t); return Bad("ต้องระบุเหตุผล", "กรุณาระบุเหตุผลที่ส่งกลับแก้ไข"); }
            var next = action == "approve" ? "CONFIRMED" : "RETURNED"; await using var q = new SqlCommand("UPDATE dbo.TDFSInspection SET StatusCode=@next,ConfirmedAt=CASE WHEN @next=N'CONFIRMED' THEN SYSUTCDATETIME() ELSE NULL END,ConfirmedBy=CASE WHEN @next=N'CONFIRMED' THEN @user ELSE NULL END,ReturnReason=CASE WHEN @next=N'RETURNED' THEN @remark ELSE NULL END,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@co AND InspectionID=@id AND StatusCode=N'SUBMITTED'", c, tx); P(q, "@next", SqlDbType.NVarChar, next, 20); P(q, "@user", SqlDbType.BigInt, user); P(q, "@remark", SqlDbType.NVarChar, Clean(x.Remark), 1000); P(q, "@co", SqlDbType.BigInt, co); P(q, "@id", SqlDbType.BigInt, id); await q.ExecuteNonQueryAsync(t); await Audit(c, tx, co, "INSPECTION", id, action.ToUpperInvariant(), status, next, x.Remark, user, t); await tx.CommitAsync(t); return NoContent();
        }
        catch { await tx.RollbackAsync(t); throw; }
    }

    [HttpPost("findings/{id:long}/{operation}")]
    public async Task<IActionResult> ActFinding(long id, [FromRoute(Name = "operation")] string action, FindingActionInput x, CancellationToken t)
    {
        action = action.Trim().ToLowerInvariant();
        if (action != "assign" && action != "progress" && action != "submit" && action != "close" && action != "reopen") return Bad("Action ไม่ถูกต้อง", "Action ของข้อบกพร่องไม่อยู่ใน Flow ที่รองรับ");
        if (!Scope(out var co, out var user)) return Forbid();
        var permission = action == "assign" ? "ASSIGN" : action is "close" or "reopen" ? "CONFIRM" : "EDIT";
        await using var c = await Open(t);
        if (!await Can(c, "39007", permission, t)) return Forbid();
        if (x.AssignedUserID is long assignee && !await UserExists(c, co, assignee, t)) return Bad("ผู้รับผิดชอบไม่ถูกต้อง", "เลือกผู้ใช้ Active ในบริษัทเดียวกัน");
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable, t);
        try
        {
            await using var state = new SqlCommand("SELECT StatusCode,AssignedUserID FROM dbo.TDFSFinding WHERE CompanyID=@co AND FindingID=@id", c, tx);
            P(state, "@co", SqlDbType.BigInt, co); P(state, "@id", SqlDbType.BigInt, id);
            await using var r = await state.ExecuteReaderAsync(t);
            if (!await r.ReadAsync(t)) { await r.CloseAsync(); await tx.RollbackAsync(t); return NotFound(); }
            var old = r.GetString(0); var assigned = r.IsDBNull(1) ? (long?)null : r.GetInt64(1);
            await r.CloseAsync();
            var valid = action switch
            {
                "assign" => old is "OPEN" or "REOPENED",
                "progress" => old == "ASSIGNED",
                "submit" => old == "IN_PROGRESS",
                "close" => old == "PENDING_CONFIRM",
                "reopen" => old == "CLOSED",
                _ => false
            };
            if (!valid) { await tx.RollbackAsync(t); return Conflict(new { message = "สถานะไม่ถูกต้อง", description = "กรุณาดำเนินการตามลำดับ มอบหมาย → เริ่มแก้ไข → ส่งยืนยัน → ปิดงาน" }); }
            var next = action switch { "assign" => "ASSIGNED", "progress" => "IN_PROGRESS", "submit" => "PENDING_CONFIRM", "close" => "CLOSED", "reopen" => "REOPENED", _ => old };
            if (action is "progress" or "submit" && assigned != user) { await tx.RollbackAsync(t); return Forbid(); }
            if (action == "assign" && x.AssignedUserID is null) { await tx.RollbackAsync(t); return Bad("ยังไม่ได้เลือกผู้รับผิดชอบ", "เลือกผู้รับผิดชอบก่อนมอบหมาย"); }
            if (action is "submit" or "reopen" && string.IsNullOrWhiteSpace(x.Remark)) { await tx.RollbackAsync(t); return Bad("ข้อมูลไม่ครบ", "ระบุรายละเอียดการแก้ไขหรือเหตุผลเปิดใหม่"); }
            if (action == "close")
            {
                await using var photo = new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDFSSetting WHERE CompanyID=@co AND RequireClosurePhoto=0) OR EXISTS(SELECT 1 FROM dbo.TDFSAttachment WHERE CompanyID=@co AND FindingID=@id AND StageCode=N'FINDING_AFTER') THEN 1 ELSE 0 END", c, tx);
                P(photo, "@co", SqlDbType.BigInt, co); P(photo, "@id", SqlDbType.BigInt, id);
                if (!Convert.ToBoolean(await photo.ExecuteScalarAsync(t))) { await tx.RollbackAsync(t); return Bad("ยังไม่มีรูปหลังแก้ไข", "แนบรูปหลังแก้ไขก่อนยืนยันปิดข้อบกพร่อง"); }
            }
            await using var q = new SqlCommand("UPDATE dbo.TDFSFinding SET AssignedUserID=CASE WHEN @action=N'assign' THEN @assigned ELSE AssignedUserID END,CorrectionText=CASE WHEN @action IN(N'progress',N'submit') THEN @remark ELSE CorrectionText END,ReopenReason=CASE WHEN @action=N'reopen' THEN @remark ELSE ReopenReason END,StatusCode=@next,SubmittedAt=CASE WHEN @next=N'PENDING_CONFIRM' THEN SYSUTCDATETIME() ELSE SubmittedAt END,ClosedAt=CASE WHEN @next=N'CLOSED' THEN SYSUTCDATETIME() ELSE NULL END,ClosedBy=CASE WHEN @next=N'CLOSED' THEN @user ELSE NULL END,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@co AND FindingID=@id", c, tx);
            P(q, "@action", SqlDbType.NVarChar, action, 20); P(q, "@assigned", SqlDbType.BigInt, x.AssignedUserID); P(q, "@remark", SqlDbType.NVarChar, Clean(x.Remark), 2000); P(q, "@next", SqlDbType.NVarChar, next, 20); P(q, "@user", SqlDbType.BigInt, user); P(q, "@co", SqlDbType.BigInt, co); P(q, "@id", SqlDbType.BigInt, id);
            await q.ExecuteNonQueryAsync(t); await Audit(c, tx, co, "FINDING", id, action.ToUpperInvariant(), old, next, x.Remark, user, t); await tx.CommitAsync(t); return NoContent();
        }
        catch { await tx.RollbackAsync(t); throw; }
    }

    static readonly string[] Categories = ["SEIRI", "SEITON", "SEISO", "SEIKETSU", "SHITSUKE"];
    static readonly string[] Frequencies = ["ONCE", "WEEKLY", "MONTHLY", "QUARTERLY"];
    async Task<IActionResult> Read(string menu, string sql, CancellationToken t) { if (!Scope(out var co, out _)) return Forbid(); await using var c = await Open(t); if (!await Can(c, menu, "VIEW", t)) return Forbid(); return await Rows(c, sql, co, t); }
    async Task<IActionResult> ReadDetail(string menu, long id, string headerSql, string detailSql, CancellationToken t) { if (!Scope(out var co, out _)) return Forbid(); await using var c = await Open(t); if (!await Can(c, menu, "VIEW", t)) return Forbid(); await using var h = new SqlCommand(headerSql, c); P(h, "@co", SqlDbType.BigInt, co); P(h, "@id", SqlDbType.BigInt, id); var headers = await ReadRows(h, t); if (headers.Count == 0) return NotFound(); await using var d = new SqlCommand(detailSql, c); P(d, "@co", SqlDbType.BigInt, co); P(d, "@id", SqlDbType.BigInt, id); return Ok(new { header = headers[0], details = await ReadRows(d, t) }); }
    async Task<IActionResult> Rows(SqlConnection c, string sql, long co, CancellationToken t) { await using var q = new SqlCommand(sql, c); P(q, "@co", SqlDbType.BigInt, co); return Ok(await ReadRows(q, t)); }
    static async Task<List<Dictionary<string, object?>>> ReadRows(SqlCommand q, CancellationToken t) { await using var r = await q.ExecuteReaderAsync(t); var rows = new List<Dictionary<string, object?>>(); while (await r.ReadAsync(t)) { var row = new Dictionary<string, object?>(); for (var i = 0; i < r.FieldCount; i++) { var key = r.GetName(i); row[char.ToLowerInvariant(key[0]) + key[1..]] = r.IsDBNull(i) ? null : r.GetValue(i); } rows.Add(row); } return rows; }
    async Task<IActionResult> Multi(SqlConnection c, string sql, long co, CancellationToken t, string[] names) { await using var q = new SqlCommand(sql, c); P(q, "@co", SqlDbType.BigInt, co); await using var r = await q.ExecuteReaderAsync(t); var result = new Dictionary<string, object?>(); var i = 0; do { var rows = new List<Dictionary<string, object?>>(); while (await r.ReadAsync(t)) { var row = new Dictionary<string, object?>(); for (var f = 0; f < r.FieldCount; f++) row[r.GetName(f)] = r.IsDBNull(f) ? null : r.GetValue(f); rows.Add(row); } result[names[i++]] = rows; } while (i < names.Length && await r.NextResultAsync(t)); return Ok(result); }
    async Task<IActionResult> DeleteMaster(string menu, string table, string key, long id, string referenced, CancellationToken t, string extra = "") { if (!Scope(out var co, out _)) return Forbid(); await using var c = await Open(t); if (!await Can(c, menu, "DELETE", t)) return Forbid(); await using var q = new SqlCommand($"DELETE {table} WHERE {key}=@id AND CompanyID=@co{extra}", c); P(q, "@id", SqlDbType.BigInt, id); P(q, "@co", SqlDbType.BigInt, co); try { return await q.ExecuteNonQueryAsync(t) == 1 ? NoContent() : NotFound(); } catch (SqlException e) when (e.Number == 547) { return Conflict(new { message = "ลบรายการไม่ได้", description = referenced }); } }
    async Task<bool> HasAnyView(SqlConnection c, CancellationToken t) { foreach (var m in Menus) if (await Can(c, m, "VIEW", t)) return true; return false; }
    Task<bool> Can(SqlConnection c, string menu, string action, CancellationToken t) => CompanyMenuAccess.IsAllowedAsync(c, User, menu, action, t);
    bool Scope(out long co, out long user) { co = 0; user = 0; return User.FindFirstValue("user_type") == "COMPANY_USER" && long.TryParse(User.FindFirstValue("company_id"), out co) && long.TryParse(User.FindFirstValue("user_id"), out user) && co > 0 && user > 0; }
    async Task<SqlConnection> Open(CancellationToken t) { var c = new SqlConnection(config.GetConnectionString("LaooDatabase")); await c.OpenAsync(t); return c; }
    static async Task EnsureSetting(SqlConnection c, long co, CancellationToken t) { await using var q = new SqlCommand("IF NOT EXISTS(SELECT 1 FROM dbo.TDFSSetting WHERE CompanyID=@co) INSERT dbo.TDFSSetting(CompanyID,UpdateBy) VALUES(@co,0)", c); P(q, "@co", SqlDbType.BigInt, co); await q.ExecuteNonQueryAsync(t); }
    static async Task<bool> UserExists(SqlConnection c, long co, long user, CancellationToken t) { await using var q = new SqlCommand("SELECT COUNT(*) FROM dbo.TDADUser WHERE CompanyID=@co AND UserID=@user AND IsActive=1", c); P(q, "@co", SqlDbType.BigInt, co); P(q, "@user", SqlDbType.BigInt, user); return Convert.ToInt32(await q.ExecuteScalarAsync(t)) == 1; }
    static async Task<bool> UsersExist(SqlConnection c, long co, long[] users, CancellationToken t) { var names = users.Select((_, i) => "@u" + i).ToArray(); await using var q = new SqlCommand($"SELECT COUNT(*) FROM dbo.TDADUser WHERE CompanyID=@co AND IsActive=1 AND UserID IN({string.Join(',', names)})", c); P(q, "@co", SqlDbType.BigInt, co); for (var i = 0; i < users.Length; i++) P(q, names[i], SqlDbType.BigInt, users[i]); return Convert.ToInt32(await q.ExecuteScalarAsync(t)) == users.Distinct().Count(); }
    static async Task Audit(SqlConnection c, SqlTransaction tx, long co, string type, long id, string action, string? from, string? to, string? remark, long user, CancellationToken t) { await using var q = new SqlCommand("INSERT dbo.TDFSAudit(CompanyID,EntityType,EntityID,ActionCode,FromStatus,ToStatus,Remark,ActionBy) VALUES(@co,@type,@id,@action,@from,@to,@remark,@user)", c, tx); P(q, "@co", SqlDbType.BigInt, co); P(q, "@type", SqlDbType.NVarChar, type, 30); P(q, "@id", SqlDbType.BigInt, id); P(q, "@action", SqlDbType.NVarChar, action, 30); P(q, "@from", SqlDbType.NVarChar, from, 20); P(q, "@to", SqlDbType.NVarChar, to, 20); P(q, "@remark", SqlDbType.NVarChar, Clean(remark), 1000); P(q, "@user", SqlDbType.BigInt, user); await q.ExecuteNonQueryAsync(t); }
    static void P(SqlCommand q, string name, SqlDbType type, object? value, int size = 0) { var p = size > 0 ? q.Parameters.Add(name, type, size) : q.Parameters.Add(name, type); p.Value = value ?? DBNull.Value; }
    static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    BadRequestObjectResult Bad(string message, string description) => BadRequest(new { message, description });
}

public sealed record SettingInput(bool IsEnabled, decimal ScoreMax, decimal DefaultPassPercent, bool RequireFailurePhoto, bool RequireClosurePhoto, decimal MaxAttachmentSizeMB, int MaxAttachmentsPerItem, int LowDueDays, int MediumDueDays, int HighDueDays, bool AllowSelfApprove, long? DefaultApproverUserID);
public sealed record AreaInput(string Code, string Name, long? BranchID, long? BuildingID, long? FloorID, long? RoomID, long? DepartmentID, long? OwnerUserID, string? Description, bool IsActive = true);
public sealed record TemplateItemInput(string Category, string Question, decimal Weight, bool IsCritical, bool RequireFailurePhoto);
public sealed record TemplateInput(string Code, string Name, int Version, decimal PassPercent, string? Description, bool IsActive, List<TemplateItemInput>? Items);
public sealed record TeamInput(string Code, string Name, long LeaderUserID, DateTime? EffectiveFrom, DateTime? EffectiveTo, bool IsActive, List<long>? MemberUserIDs);
public sealed record PlanAreaInput(long AreaID, DateTime ScheduledAt);
public sealed record PlanInput(string Name, long TemplateID, long TeamID, long ApproverUserID, DateTime StartDate, DateTime EndDate, string Frequency, string? Remark, List<PlanAreaInput>? Areas);
public sealed record InspectionItemInput(long DetailID, decimal? Score, bool NotApplicable, string? Remark, bool CreateFinding);
public sealed record InspectionSaveInput(List<InspectionItemInput>? Items);
public sealed record DecisionInput(string? Remark);
public sealed record FindingActionInput(long? AssignedUserID, string? Remark);
