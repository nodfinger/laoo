using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooSalesModule.Controllers;

[ApiController, Authorize, Route("api/company/sales")]
public sealed class SalesController(IConfiguration config) : ControllerBase
{
    static readonly string[] Menus = ["45001", "45002", "45003", "45004", "45005", "45006", "45007"];

    [HttpGet("actions/{menu}")]
    public async Task<IActionResult> Actions(string menu, CancellationToken t)
    {
        if (!Menus.Contains(menu) || !Scope(out _, out _)) return Forbid();
        await using var c = await Open(t); if (!await Can(c, menu, "VIEW", t)) return Forbid();
        return Ok(new { create = await Can(c, menu, "CREATE", t), edit = await Can(c, menu, "EDIT", t), delete = await Can(c, menu, "DELETE", t), convert = await Can(c, menu, "CONVERT", t), close = await Can(c, menu, "CLOSE", t) });
    }

    [HttpGet("options")]
    public async Task<IActionResult> Options(CancellationToken t)
    {
        if (!Scope(out var co, out var user)) return Forbid(); await using var c = await Open(t); if (!await HasAnyView(c, t)) return Forbid();
        const string sql = "SELECT PipelineStageID id,StageCode code,StageName name,ProbabilityPercent probability,StageType type FROM dbo.TDSLPipelineStage WHERE CompanyID=@co AND IsActive=1 ORDER BY SortOrder;SELECT E.EmployeeID id,E.EmployeeCode code,E.FullName name,CASE WHEN UE.UserID=@user THEN CONVERT(bit,1) ELSE CONVERT(bit,0) END isCurrent FROM dbo.TDADEmployee E LEFT JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=E.CompanyID AND UE.EmployeeID=E.EmployeeID AND UE.UserID=@user WHERE E.CompanyID=@co AND E.IsActive=1 ORDER BY E.FullName;SELECT CustomerID id,CusCode code,CusName name FROM dbo.TDARCustomer WHERE CompanyID=@co AND IsActive=1 ORDER BY CusCode;SELECT LeadID id,LeadCode code,LeadName name FROM dbo.TDSLLead WHERE CompanyID=@co AND IsActive=1 AND StatusCode<>N'CONVERTED' ORDER BY LeadCode;SELECT OpportunityID id,OpportunityCode code,OpportunityName name FROM dbo.TDSLOpportunity WHERE CompanyID=@co AND IsActive=1 ORDER BY OpportunityCode;";
        await using var q = new SqlCommand(sql, c); P(q,"@co",SqlDbType.BigInt,co); P(q,"@user",SqlDbType.BigInt,user); return Ok(await Multi(q,t,["stages","employees","customers","leads","opportunities"]));
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken t)
    {
        if (!Scope(out var co, out _)) return Forbid(); await using var c=await Open(t); if(!await Can(c,"45001","VIEW",t)) return Forbid(); await EnsureSetting(c,co,t);
        return await Rows(c,"SELECT IsEnabled,LeadIdleDays,ActivityReminderDays,DefaultStageID,WonStageID,LostStageID FROM dbo.TDSTCompanySetupSystemSales WHERE CompanyID=@co",co,t);
    }

    [HttpPut("settings")]
    public async Task<IActionResult> SaveSettings(SalesSettingInput x,CancellationToken t)
    {
        if(!Scope(out var co,out var user)) return Forbid(); if(x.LeadIdleDays is <1 or >365 || x.ActivityReminderDays is <0 or >90) return Bad("ข้อมูลตั้งค่าไม่ถูกต้อง","วันแจ้งเตือน Lead ต้องอยู่ระหว่าง 1-365 วัน และกิจกรรม 0-90 วัน");
        await using var c=await Open(t); if(!await Can(c,"45001","EDIT",t)) return Forbid(); if(!await ValidStages(c,co,[x.DefaultStageID,x.WonStageID,x.LostStageID],t)) return Bad("ขั้นตอนการขายไม่ถูกต้อง","เลือกขั้นตอนที่เปิดใช้งานในบริษัทเดียวกันให้ครบ");
        const string sql="UPDATE dbo.TDSTCompanySetupSystemSales SET IsEnabled=@enabled,LeadIdleDays=@idle,ActivityReminderDays=@reminder,DefaultStageID=@default,WonStageID=@won,LostStageID=@lost,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co;";
        await using var q=new SqlCommand(sql,c); P(q,"@enabled",SqlDbType.Bit,x.IsEnabled); P(q,"@idle",SqlDbType.Int,x.LeadIdleDays); P(q,"@reminder",SqlDbType.Int,x.ActivityReminderDays); P(q,"@default",SqlDbType.BigInt,x.DefaultStageID); P(q,"@won",SqlDbType.BigInt,x.WonStageID); P(q,"@lost",SqlDbType.BigInt,x.LostStageID); P(q,"@user",SqlDbType.BigInt,user); P(q,"@co",SqlDbType.BigInt,co); await q.ExecuteNonQueryAsync(t); return NoContent();
    }

    [HttpGet("pipeline-stages")]
    public Task<IActionResult> PipelineStages(CancellationToken t)=>Read("45002","SELECT PipelineStageID id,StageCode code,StageName name,SortOrder sortOrder,ProbabilityPercent probability,StageType type,IsActive active FROM dbo.TDSLPipelineStage WHERE CompanyID=@co ORDER BY SortOrder,StageCode",t);

    [HttpGet("leads")]
    public Task<IActionResult> Leads(CancellationToken t)=>Read("45003","SELECT l.LeadID id,l.LeadCode code,l.LeadType type,l.LeadName name,l.ContactName,l.Phone,l.Email,l.TaxID,l.AddressText address,l.SourceCode source,l.ScoreValue score,l.StatusCode status,l.AssignedEmployeeID,e.FullName assignedName,l.LastContactAt,l.NextContactAt,l.ConvertedCustomerID,l.ConvertedOpportunityID,l.Remark,l.IsActive active FROM dbo.TDSLLead l LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=l.CompanyID AND e.EmployeeID=l.AssignedEmployeeID WHERE l.CompanyID=@co ORDER BY l.CreateDate DESC,l.LeadID DESC",t);

    [HttpGet("opportunities")]
    public Task<IActionResult> Opportunities(CancellationToken t)=>Read("45004","SELECT o.OpportunityID id,o.OpportunityCode code,o.OpportunityName name,o.CustomerID,c.CusName customer,o.LeadID,o.PipelineStageID,s.StageName stage,s.StageType stageType,o.Amount,o.ProbabilityPercent probability,o.ExpectedCloseDate,o.AssignedEmployeeID,e.FullName assignedName,o.CompetitorName,o.Remark,o.StatusCode status,o.ClosedDate,o.CloseReason,o.IsActive active,(SELECT COUNT(*) FROM dbo.TDSLOpportunityQuotation q WHERE q.CompanyID=o.CompanyID AND q.OpportunityID=o.OpportunityID) quotationCount FROM dbo.TDSLOpportunity o JOIN dbo.TDSLPipelineStage s ON s.PipelineStageID=o.PipelineStageID LEFT JOIN dbo.TDARCustomer c ON c.CompanyID=o.CompanyID AND c.CustomerID=o.CustomerID LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=o.CompanyID AND e.EmployeeID=o.AssignedEmployeeID WHERE o.CompanyID=@co ORDER BY o.CreateDate DESC,o.OpportunityID DESC",t);

    [HttpGet("activities")]
    public Task<IActionResult> Activities(CancellationToken t)=>Read("45005","SELECT a.ActivityID id,a.ActivityCode code,a.ActivityType type,a.Title,a.LeadID,l.LeadName lead,a.CustomerID,c.CusName customer,a.OpportunityID,o.OpportunityName opportunity,a.AssignedEmployeeID,e.FullName assignedName,a.StartAt,a.DueAt,a.CompletedAt,a.StatusCode status,a.DescriptionText description,a.ResultText result,a.IsActive active,CASE WHEN a.StatusCode NOT IN(N'DONE',N'CANCELLED') AND a.DueAt<SYSUTCDATETIME() THEN CONVERT(bit,1) ELSE CONVERT(bit,0) END overdue FROM dbo.TDSLActivity a LEFT JOIN dbo.TDSLLead l ON l.CompanyID=a.CompanyID AND l.LeadID=a.LeadID LEFT JOIN dbo.TDARCustomer c ON c.CompanyID=a.CompanyID AND c.CustomerID=a.CustomerID LEFT JOIN dbo.TDSLOpportunity o ON o.CompanyID=a.CompanyID AND o.OpportunityID=a.OpportunityID LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=a.CompanyID AND e.EmployeeID=a.AssignedEmployeeID WHERE a.CompanyID=@co ORDER BY CASE WHEN a.StatusCode IN(N'DONE',N'CANCELLED') THEN 1 ELSE 0 END,a.DueAt",t);

    [HttpGet("my-tasks")]
    public async Task<IActionResult> MyTasks(CancellationToken t)
    {
        if(!Scope(out var co,out var user)) return Forbid(); await using var c=await Open(t); if(!await Can(c,"45006","VIEW",t)) return Forbid();
        const string sql="SELECT a.ActivityID id,a.ActivityCode code,a.ActivityType type,a.Title,a.DueAt,a.StatusCode status,a.ResultText result,CASE WHEN a.DueAt<SYSUTCDATETIME() AND a.StatusCode NOT IN(N'DONE',N'CANCELLED') THEN CONVERT(bit,1) ELSE CONVERT(bit,0) END overdue FROM dbo.TDSLActivity a WHERE a.CompanyID=@co AND a.AssignedEmployeeID IN(SELECT EmployeeID FROM dbo.TDADUserEmployee WHERE CompanyID=@co AND UserID=@user) AND a.IsActive=1 ORDER BY overdue DESC,a.DueAt;";
        await using var q=new SqlCommand(sql,c); P(q,"@co",SqlDbType.BigInt,co); P(q,"@user",SqlDbType.BigInt,user); return Ok(await ReadRows(q,t));
    }

    [HttpGet("reports")]
    public async Task<IActionResult> Reports(CancellationToken t)
    {
        if(!Scope(out var co,out _)) return Forbid(); await using var c=await Open(t); if(!await Can(c,"45007","VIEW",t)) return Forbid();
        const string sql="SELECT COUNT(*) opportunityCount,COALESCE(SUM(CASE WHEN StatusCode=N'OPEN' THEN Amount ELSE 0 END),0) pipelineValue,COALESCE(SUM(CASE WHEN StatusCode=N'OPEN' THEN Amount*ProbabilityPercent/100 ELSE 0 END),0) weightedValue,SUM(CASE WHEN StatusCode=N'WON' THEN 1 ELSE 0 END) wonCount,SUM(CASE WHEN StatusCode=N'LOST' THEN 1 ELSE 0 END) lostCount,(SELECT COUNT(*) FROM dbo.TDSLLead WHERE CompanyID=@co) leadCount,(SELECT COUNT(*) FROM dbo.TDSLLead WHERE CompanyID=@co AND StatusCode=N'CONVERTED') convertedLeadCount,(SELECT COUNT(*) FROM dbo.TDSLActivity WHERE CompanyID=@co AND StatusCode NOT IN(N'DONE',N'CANCELLED') AND DueAt<SYSUTCDATETIME()) overdueActivities FROM dbo.TDSLOpportunity WHERE CompanyID=@co;SELECT s.StageName stage,COUNT(o.OpportunityID) itemCount,COALESCE(SUM(o.Amount),0) amount FROM dbo.TDSLPipelineStage s LEFT JOIN dbo.TDSLOpportunity o ON o.CompanyID=s.CompanyID AND o.PipelineStageID=s.PipelineStageID AND o.IsActive=1 WHERE s.CompanyID=@co AND s.IsActive=1 GROUP BY s.StageName,s.SortOrder ORDER BY s.SortOrder;";
        await using var q=new SqlCommand(sql,c); P(q,"@co",SqlDbType.BigInt,co); return Ok(await Multi(q,t,["summary","pipeline"]));
    }

    [HttpPost("pipeline-stages")]
    public Task<IActionResult> CreateStage(PipelineStageInput x,CancellationToken t)=>SaveStage(null,x,"CREATE",t);
    [HttpPut("pipeline-stages/{id:long}")]
    public Task<IActionResult> UpdateStage(long id,PipelineStageInput x,CancellationToken t)=>SaveStage(id,x,"EDIT",t);
    [HttpDelete("pipeline-stages/{id:long}")]
    public Task<IActionResult> DeleteStage(long id,CancellationToken t)=>Delete("45002","dbo.TDSLPipelineStage","PipelineStageID",id,"ขั้นตอนนี้ถูกใช้โดยโอกาสการขายหรือการตั้งค่าระบบแล้ว",t);

    async Task<IActionResult> SaveStage(long? id,PipelineStageInput x,string action,CancellationToken t)
    {
        var type=x.Type.Trim().ToUpperInvariant(); if(string.IsNullOrWhiteSpace(x.Code)||string.IsNullOrWhiteSpace(x.Name)||x.SortOrder<0||x.Probability is <0 or >100||!new[]{"OPEN","WON","LOST"}.Contains(type)) return Bad("ข้อมูลขั้นตอนไม่ถูกต้อง","ระบุรหัส ชื่อ ลำดับ ความน่าจะเป็น 0-100 และประเภท OPEN/WON/LOST");
        if(!Scope(out var co,out var user)) return Forbid(); await using var c=await Open(t); if(!await Can(c,"45002",action,t)) return Forbid();
        var sql=id is null?"INSERT dbo.TDSLPipelineStage(CompanyID,ProjectID,StageCode,StageName,SortOrder,ProbabilityPercent,StageType,IsActive,CreateBy) OUTPUT INSERTED.PipelineStageID SELECT @co,ProjectID,@code,@name,@sort,@probability,@type,@active,@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES'":"UPDATE dbo.TDSLPipelineStage SET StageCode=@code,StageName=@name,SortOrder=@sort,ProbabilityPercent=@probability,StageType=@type,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND PipelineStageID=@id;SELECT @id";
        await using var q=new SqlCommand(sql,c); P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);P(q,"@code",SqlDbType.NVarChar,x.Code.Trim().ToUpperInvariant(),30);P(q,"@name",SqlDbType.NVarChar,x.Name.Trim(),150);P(q,"@sort",SqlDbType.Int,x.SortOrder);P(q,"@probability",SqlDbType.Decimal,x.Probability);P(q,"@type",SqlDbType.NVarChar,type,10);P(q,"@active",SqlDbType.Bit,x.IsActive);P(q,"@user",SqlDbType.BigInt,user);
        try{return Ok(new{id=Convert.ToInt64(await q.ExecuteScalarAsync(t))});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสขั้นตอนซ้ำ",description="ใช้รหัสอื่นภายในบริษัท"});}
    }

    [HttpPost("leads")]
    public Task<IActionResult> CreateLead(LeadInput x,CancellationToken t)=>SaveLead(null,x,"CREATE",t);
    [HttpPut("leads/{id:long}")]
    public Task<IActionResult> UpdateLead(long id,LeadInput x,CancellationToken t)=>SaveLead(id,x,"EDIT",t);
    [HttpDelete("leads/{id:long}")]
    public Task<IActionResult> DeleteLead(long id,CancellationToken t)=>Delete("45003","dbo.TDSLLead","LeadID",id,"Lead นี้ถูกแปลงหรือถูกใช้ในกิจกรรม/โอกาสการขายแล้ว",t," AND StatusCode<>N'CONVERTED'");

    async Task<IActionResult> SaveLead(long? id,LeadInput x,string action,CancellationToken t)
    {
        var type=x.Type.Trim().ToUpperInvariant();var status=x.Status.Trim().ToUpperInvariant(); if(string.IsNullOrWhiteSpace(x.Name)||!new[]{"COMPANY","PERSON"}.Contains(type)||!new[]{"NEW","CONTACTED","QUALIFIED","DISQUALIFIED"}.Contains(status)||x.Score is <0 or >100) return Bad("ข้อมูล Lead ไม่ถูกต้อง","ระบุชื่อ ประเภท สถานะ และคะแนน 0-100 ให้ถูกต้อง");
        if(!Scope(out var co,out var user)) return Forbid();await using var c=await Open(t);if(!await Can(c,"45003",action,t))return Forbid();if(x.AssignedEmployeeID is long employee&&!await EmployeeExists(c,co,employee,t))return Bad("ผู้รับผิดชอบไม่ถูกต้อง","เลือกพนักงาน Active ในบริษัทเดียวกัน");
        var code=string.IsNullOrWhiteSpace(x.Code)?"LD"+DateTime.UtcNow.ToString("yyyyMMddHHmmssfff"):x.Code.Trim().ToUpperInvariant();var sql=id is null?"INSERT dbo.TDSLLead(CompanyID,ProjectID,LeadCode,LeadType,LeadName,ContactName,Phone,Email,TaxID,AddressText,SourceCode,ScoreValue,StatusCode,AssignedEmployeeID,LastContactAt,NextContactAt,Remark,IsActive,CreateBy) OUTPUT INSERTED.LeadID SELECT @co,ProjectID,@code,@type,@name,@contact,@phone,@email,@tax,@address,@source,@score,@status,@employee,@last,@next,@remark,@active,@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES'":"UPDATE dbo.TDSLLead SET LeadCode=@code,LeadType=@type,LeadName=@name,ContactName=@contact,Phone=@phone,Email=@email,TaxID=@tax,AddressText=@address,SourceCode=@source,ScoreValue=@score,StatusCode=@status,AssignedEmployeeID=@employee,LastContactAt=@last,NextContactAt=@next,Remark=@remark,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND LeadID=@id AND StatusCode<>N'CONVERTED';SELECT @id";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);P(q,"@code",SqlDbType.NVarChar,code,30);P(q,"@type",SqlDbType.NVarChar,type,20);P(q,"@name",SqlDbType.NVarChar,x.Name.Trim(),200);P(q,"@contact",SqlDbType.NVarChar,Clean(x.ContactName),200);P(q,"@phone",SqlDbType.NVarChar,Clean(x.Phone),50);P(q,"@email",SqlDbType.NVarChar,Clean(x.Email),320);P(q,"@tax",SqlDbType.NVarChar,Clean(x.TaxID),50);P(q,"@address",SqlDbType.NVarChar,Clean(x.Address),1000);P(q,"@source",SqlDbType.NVarChar,Clean(x.Source),50);P(q,"@score",SqlDbType.Int,x.Score);P(q,"@status",SqlDbType.NVarChar,status,20);P(q,"@employee",SqlDbType.BigInt,x.AssignedEmployeeID);P(q,"@last",SqlDbType.DateTime2,x.LastContactAt);P(q,"@next",SqlDbType.DateTime2,x.NextContactAt);P(q,"@remark",SqlDbType.NVarChar,Clean(x.Remark),2000);P(q,"@active",SqlDbType.Bit,x.IsActive);P(q,"@user",SqlDbType.BigInt,user);
        try{return Ok(new{id=Convert.ToInt64(await q.ExecuteScalarAsync(t))});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัส Lead ซ้ำ",description="ใช้รหัสอื่นภายในบริษัท"});}
    }

    [HttpPost("leads/{id:long}/convert")]
    public async Task<IActionResult> ConvertLead(long id,LeadConvertInput x,CancellationToken t)
    {
        if(string.IsNullOrWhiteSpace(x.OpportunityName)||x.ExpectedCloseDate.Date<DateTime.UtcNow.Date||x.Amount<0)return Bad("ข้อมูลแปลง Lead ไม่ครบ","ระบุชื่อโอกาส มูลค่า และวันที่คาดปิดตั้งแต่วันนี้เป็นต้นไป");if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"45003","CONVERT",t))return Forbid();await using var tx=(SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,t);
        try{
            await using var h=new SqlCommand("SELECT LeadName,ContactName,Phone,Email,TaxID,AddressText,AssignedEmployeeID,StatusCode FROM dbo.TDSLLead WHERE CompanyID=@co AND LeadID=@id",c,tx);P(h,"@co",SqlDbType.BigInt,co);P(h,"@id",SqlDbType.BigInt,id);await using var r=await h.ExecuteReaderAsync(t);if(!await r.ReadAsync(t)){await r.CloseAsync();await tx.RollbackAsync(t);return NotFound();}var name=r.GetString(0);var contact=Text(r,1);var phone=Text(r,2);var email=Text(r,3);var tax=Text(r,4);var address=Text(r,5);var employee=r.IsDBNull(6)?(long?)null:r.GetInt64(6);var status=r.GetString(7);await r.CloseAsync();if(status=="CONVERTED"){await tx.RollbackAsync(t);return Conflict(new{message="Lead ถูกแปลงแล้ว",description="ไม่สามารถแปลง Lead เดิมซ้ำได้"});}
            long customer;if(x.CustomerID is long existing){await using var v=new SqlCommand("SELECT CustomerID FROM dbo.TDARCustomer WHERE CompanyID=@co AND CustomerID=@id AND IsActive=1",c,tx);P(v,"@co",SqlDbType.BigInt,co);P(v,"@id",SqlDbType.BigInt,existing);customer=Convert.ToInt64(await v.ExecuteScalarAsync(t)??0);if(customer==0){await tx.RollbackAsync(t);return Bad("ลูกค้าไม่ถูกต้อง","เลือกลูกค้าที่เปิดใช้งานในบริษัทเดียวกัน");}}
            else
            {
                await using var duplicate=new SqlCommand("SELECT TOP 1 CustomerID FROM dbo.TDARCustomer WHERE CompanyID=@co AND IsActive=1 AND ((@tax IS NOT NULL AND TaxID=@tax) OR (@email IS NOT NULL AND Email=@email) OR (@phone IS NOT NULL AND Phone=@phone))",c,tx);
                P(duplicate,"@co",SqlDbType.BigInt,co);P(duplicate,"@tax",SqlDbType.NVarChar,tax,50);P(duplicate,"@email",SqlDbType.NVarChar,email,320);P(duplicate,"@phone",SqlDbType.NVarChar,phone,50);
                var found=await duplicate.ExecuteScalarAsync(t);
                if(found is not null){await tx.RollbackAsync(t);return Conflict(new{message="พบลูกค้าที่อาจซ้ำ",description="เลือกลูกค้าเดิมในหน้าต่างแปลง Lead ก่อนดำเนินการ"});}
                await using var nextCode=new SqlCommand("SELECT RIGHT(N'00000'+CONVERT(nvarchar(20),COALESCE(MAX(TRY_CONVERT(int,CusCode)),0)+1),5) FROM dbo.TDARCustomer WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@co",c,tx);
                P(nextCode,"@co",SqlDbType.BigInt,co);
                var customerCode=Convert.ToString(await nextCode.ExecuteScalarAsync(t))!;
                await using var create=new SqlCommand("INSERT dbo.TDARCustomer(CompanyID,CusCode,CusName,CusAddress,StartDate,TaxID,Phone,Email,ContName1,Phone1,Email1,SalespersonEmployeeID,IsActive) OUTPUT INSERTED.CustomerID VALUES(@co,@code,@name,@address,CONVERT(date,SYSUTCDATETIME()),@tax,@phone,@email,@contact,@phone,@email,@employee,1)",c,tx);
                P(create,"@co",SqlDbType.BigInt,co);P(create,"@code",SqlDbType.NVarChar,customerCode,5);P(create,"@name",SqlDbType.NVarChar,name,200);P(create,"@address",SqlDbType.NVarChar,address,1000);P(create,"@tax",SqlDbType.NVarChar,tax,50);P(create,"@phone",SqlDbType.NVarChar,phone,50);P(create,"@email",SqlDbType.NVarChar,email,320);P(create,"@contact",SqlDbType.NVarChar,contact,200);P(create,"@employee",SqlDbType.BigInt,employee);
                customer=Convert.ToInt64(await create.ExecuteScalarAsync(t));
            }
            await using var stage=new SqlCommand("SELECT DefaultStageID FROM dbo.TDSTCompanySetupSystemSales WHERE CompanyID=@co",c,tx);P(stage,"@co",SqlDbType.BigInt,co);var stageId=Convert.ToInt64(await stage.ExecuteScalarAsync(t)??0);if(stageId==0){await tx.RollbackAsync(t);return Conflict(new{message="ยังไม่ได้ตั้งค่าขั้นตอนเริ่มต้น",description="กำหนดขั้นตอนเริ่มต้นที่เมนูตั้งค่าระบบขาย"});}
            await using var createOpportunity=new SqlCommand("INSERT dbo.TDSLOpportunity(CompanyID,ProjectID,OpportunityCode,OpportunityName,CustomerID,LeadID,PipelineStageID,Amount,ProbabilityPercent,ExpectedCloseDate,AssignedEmployeeID,StatusCode,CreateBy) OUTPUT INSERTED.OpportunityID SELECT @co,ProjectID,@code,@name,@customer,@lead,@stage,@amount,(SELECT ProbabilityPercent FROM dbo.TDSLPipelineStage WHERE PipelineStageID=@stage),@close,@employee,N'OPEN',@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES'",c,tx);P(createOpportunity,"@co",SqlDbType.BigInt,co);P(createOpportunity,"@code",SqlDbType.NVarChar,"OP"+DateTime.UtcNow.ToString("yyyyMMddHHmmssfff"),30);P(createOpportunity,"@name",SqlDbType.NVarChar,x.OpportunityName.Trim(),200);P(createOpportunity,"@customer",SqlDbType.BigInt,customer);P(createOpportunity,"@lead",SqlDbType.BigInt,id);P(createOpportunity,"@stage",SqlDbType.BigInt,stageId);P(createOpportunity,"@amount",SqlDbType.Decimal,x.Amount);P(createOpportunity,"@close",SqlDbType.Date,x.ExpectedCloseDate);P(createOpportunity,"@employee",SqlDbType.BigInt,employee);P(createOpportunity,"@user",SqlDbType.BigInt,user);var opportunity=Convert.ToInt64(await createOpportunity.ExecuteScalarAsync(t));
            await using var finish=new SqlCommand("UPDATE dbo.TDSLLead SET StatusCode=N'CONVERTED',ConvertedCustomerID=@customer,ConvertedOpportunityID=@opportunity,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND LeadID=@lead",c,tx);P(finish,"@customer",SqlDbType.BigInt,customer);P(finish,"@opportunity",SqlDbType.BigInt,opportunity);P(finish,"@user",SqlDbType.BigInt,user);P(finish,"@co",SqlDbType.BigInt,co);P(finish,"@lead",SqlDbType.BigInt,id);await finish.ExecuteNonQueryAsync(t);await tx.CommitAsync(t);return Ok(new{customerId=customer,opportunityId=opportunity});
        }catch{await tx.RollbackAsync(t);throw;}
    }

    [HttpPost("opportunities")]
    public Task<IActionResult> CreateOpportunity(OpportunityInput x,CancellationToken t)=>SaveOpportunity(null,x,"CREATE",t);
    [HttpPut("opportunities/{id:long}")]
    public Task<IActionResult> UpdateOpportunity(long id,OpportunityInput x,CancellationToken t)=>SaveOpportunity(id,x,"EDIT",t);
    [HttpDelete("opportunities/{id:long}")]
    public Task<IActionResult> DeleteOpportunity(long id,CancellationToken t)=>Delete("45004","dbo.TDSLOpportunity","OpportunityID",id,"โอกาสการขายนี้มีกิจกรรมหรือใบเสนอราคาเชื่อมอยู่",t," AND StatusCode=N'OPEN'");

    async Task<IActionResult> SaveOpportunity(long? id,OpportunityInput x,string action,CancellationToken t)
    {
        if(string.IsNullOrWhiteSpace(x.Name)||x.CustomerID<=0||x.StageID<=0||x.Amount<0||x.Probability is <0 or >100)return Bad("ข้อมูลโอกาสการขายไม่ถูกต้อง","ระบุลูกค้า ชื่อ ขั้นตอน มูลค่า และความน่าจะเป็นให้ครบ");if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"45004",action,t))return Forbid();if(x.AssignedEmployeeID is long employee&&!await EmployeeExists(c,co,employee,t))return Bad("ผู้รับผิดชอบไม่ถูกต้อง","เลือกพนักงาน Active ในบริษัทเดียวกัน");if(!await CustomerStageValid(c,co,x.CustomerID,x.StageID,t))return Bad("ข้อมูลอ้างอิงไม่ถูกต้อง","ลูกค้าและขั้นตอนต้องเปิดใช้งานในบริษัทเดียวกัน");
        var code=string.IsNullOrWhiteSpace(x.Code)?"OP"+DateTime.UtcNow.ToString("yyyyMMddHHmmssfff"):x.Code.Trim().ToUpperInvariant();var sql=id is null?"INSERT dbo.TDSLOpportunity(CompanyID,ProjectID,OpportunityCode,OpportunityName,CustomerID,PipelineStageID,Amount,ProbabilityPercent,ExpectedCloseDate,AssignedEmployeeID,CompetitorName,Remark,StatusCode,IsActive,CreateBy) OUTPUT INSERTED.OpportunityID SELECT @co,ProjectID,@code,@name,@customer,@stage,@amount,@probability,@close,@employee,@competitor,@remark,N'OPEN',@active,@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES'":"UPDATE dbo.TDSLOpportunity SET OpportunityCode=@code,OpportunityName=@name,CustomerID=@customer,PipelineStageID=@stage,Amount=@amount,ProbabilityPercent=@probability,ExpectedCloseDate=@close,AssignedEmployeeID=@employee,CompetitorName=@competitor,Remark=@remark,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND OpportunityID=@id AND StatusCode=N'OPEN';SELECT @id";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);P(q,"@code",SqlDbType.NVarChar,code,30);P(q,"@name",SqlDbType.NVarChar,x.Name.Trim(),200);P(q,"@customer",SqlDbType.BigInt,x.CustomerID);P(q,"@stage",SqlDbType.BigInt,x.StageID);P(q,"@amount",SqlDbType.Decimal,x.Amount);P(q,"@probability",SqlDbType.Decimal,x.Probability);P(q,"@close",SqlDbType.Date,x.ExpectedCloseDate);P(q,"@employee",SqlDbType.BigInt,x.AssignedEmployeeID);P(q,"@competitor",SqlDbType.NVarChar,Clean(x.Competitor),200);P(q,"@remark",SqlDbType.NVarChar,Clean(x.Remark),2000);P(q,"@active",SqlDbType.Bit,x.IsActive);P(q,"@user",SqlDbType.BigInt,user);try{return Ok(new{id=Convert.ToInt64(await q.ExecuteScalarAsync(t))});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสโอกาสการขายซ้ำ",description="ใช้รหัสอื่นภายในบริษัท"});}
    }

    [HttpPost("opportunities/{id:long}/close")]
    public async Task<IActionResult> CloseOpportunity(long id,OpportunityCloseInput x,CancellationToken t)
    {
        var status=x.Status.Trim().ToUpperInvariant();if(!new[]{"WON","LOST"}.Contains(status)||string.IsNullOrWhiteSpace(x.Reason))return Bad("ข้อมูลปิดการขายไม่ครบ","เลือกปิดชนะหรือปิดแพ้และระบุเหตุผล");if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"45004","CLOSE",t))return Forbid();await EnsureSetting(c,co,t);var stageColumn=status=="WON"?"WonStageID":"LostStageID";var sql=$"UPDATE o SET StatusCode=@status,PipelineStageID=s.{stageColumn},ProbabilityPercent=CASE WHEN @status=N'WON' THEN 100 ELSE 0 END,ClosedDate=@date,CloseReason=@reason,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() FROM dbo.TDSLOpportunity o JOIN dbo.TDSTCompanySetupSystemSales s ON s.CompanyID=o.CompanyID WHERE o.CompanyID=@co AND o.OpportunityID=@id AND o.StatusCode=N'OPEN' AND s.{stageColumn} IS NOT NULL";await using var q=new SqlCommand(sql,c);P(q,"@status",SqlDbType.NVarChar,status,10);P(q,"@date",SqlDbType.Date,x.ClosedDate);P(q,"@reason",SqlDbType.NVarChar,x.Reason.Trim(),1000);P(q,"@user",SqlDbType.BigInt,user);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);return await q.ExecuteNonQueryAsync(t)==1?NoContent():Conflict(new{message="ปิดโอกาสการขายไม่ได้",description="รายการอาจถูกปิดแล้ว หรือยังไม่ได้ตั้งค่า Stage ชนะ/แพ้"});
    }

    [HttpPost("opportunities/{id:long}/quotations/{quotationId:long}")]
    public async Task<IActionResult> LinkQuotation(long id,long quotationId,CancellationToken t)
    {
        if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"45004","EDIT",t))return Forbid();const string sql="INSERT dbo.TDSLOpportunityQuotation(CompanyID,OpportunityID,QuotationID,CreateBy) SELECT @co,o.OpportunityID,q.QuotationID,@user FROM dbo.TDSLOpportunity o JOIN dbo.TDARQuotation q ON q.CompanyID=o.CompanyID AND q.QuotationID=@quotation WHERE o.CompanyID=@co AND o.OpportunityID=@id AND NOT EXISTS(SELECT 1 FROM dbo.TDSLOpportunityQuotation x WHERE x.CompanyID=@co AND x.OpportunityID=@id AND x.QuotationID=@quotation)";await using var cmd=new SqlCommand(sql,c);P(cmd,"@co",SqlDbType.BigInt,co);P(cmd,"@id",SqlDbType.BigInt,id);P(cmd,"@quotation",SqlDbType.BigInt,quotationId);P(cmd,"@user",SqlDbType.BigInt,user);return await cmd.ExecuteNonQueryAsync(t)==1?NoContent():Conflict(new{message="เชื่อมใบเสนอราคาไม่ได้",description="ตรวจสอบโอกาสการขาย ใบเสนอราคา หรือรายการที่เชื่อมซ้ำ"});
    }

    [HttpPost("activities")]
    public Task<IActionResult> CreateActivity(ActivityInput x,CancellationToken t)=>SaveActivity(null,x,"CREATE",t);
    [HttpPut("activities/{id:long}")]
    public Task<IActionResult> UpdateActivity(long id,ActivityInput x,CancellationToken t)=>SaveActivity(id,x,"EDIT",t);
    [HttpDelete("activities/{id:long}")]
    public Task<IActionResult> DeleteActivity(long id,CancellationToken t)=>Delete("45005","dbo.TDSLActivity","ActivityID",id,"กิจกรรมที่เสร็จแล้วไม่อนุญาตให้ลบ",t," AND StatusCode NOT IN(N'DONE',N'CANCELLED')");

    async Task<IActionResult> SaveActivity(long? id,ActivityInput x,string action,CancellationToken t)
    {
        var type=x.Type.Trim().ToUpperInvariant();var status=x.Status.Trim().ToUpperInvariant();if(string.IsNullOrWhiteSpace(x.Title)||!new[]{"CALL","MEETING","EMAIL","TASK"}.Contains(type)||!new[]{"PENDING","IN_PROGRESS","DONE","CANCELLED"}.Contains(status)||x.DueAt<x.StartAt||(x.LeadID is null&&x.CustomerID is null&&x.OpportunityID is null))return Bad("ข้อมูลกิจกรรมไม่ถูกต้อง","ระบุประเภท หัวข้อ เรื่องที่เกี่ยวข้อง ผู้รับผิดชอบ และช่วงเวลาให้ถูกต้อง");if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"45005",action,t))return Forbid();if(!await ActivityReferencesValid(c,co,x,t))return Bad("ข้อมูลอ้างอิงไม่ถูกต้อง","Lead ลูกค้า โอกาสการขาย และผู้รับผิดชอบต้องอยู่บริษัทเดียวกัน");
        var code=string.IsNullOrWhiteSpace(x.Code)?"AC"+DateTime.UtcNow.ToString("yyyyMMddHHmmssfff"):x.Code.Trim().ToUpperInvariant();var sql=id is null?"INSERT dbo.TDSLActivity(CompanyID,ProjectID,ActivityCode,ActivityType,Title,LeadID,CustomerID,OpportunityID,AssignedEmployeeID,StartAt,DueAt,CompletedAt,StatusCode,DescriptionText,ResultText,IsActive,CreateBy) OUTPUT INSERTED.ActivityID SELECT @co,ProjectID,@code,@type,@title,@lead,@customer,@opportunity,@employee,@start,@due,CASE WHEN @status=N'DONE' THEN SYSUTCDATETIME() END,@status,@description,@result,@active,@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES'":"UPDATE dbo.TDSLActivity SET ActivityCode=@code,ActivityType=@type,Title=@title,LeadID=@lead,CustomerID=@customer,OpportunityID=@opportunity,AssignedEmployeeID=@employee,StartAt=@start,DueAt=@due,CompletedAt=CASE WHEN @status=N'DONE' THEN COALESCE(CompletedAt,SYSUTCDATETIME()) ELSE NULL END,StatusCode=@status,DescriptionText=@description,ResultText=@result,IsActive=@active,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@co AND ActivityID=@id;SELECT @id";
        await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);P(q,"@code",SqlDbType.NVarChar,code,30);P(q,"@type",SqlDbType.NVarChar,type,20);P(q,"@title",SqlDbType.NVarChar,x.Title.Trim(),200);P(q,"@lead",SqlDbType.BigInt,x.LeadID);P(q,"@customer",SqlDbType.BigInt,x.CustomerID);P(q,"@opportunity",SqlDbType.BigInt,x.OpportunityID);P(q,"@employee",SqlDbType.BigInt,x.AssignedEmployeeID);P(q,"@start",SqlDbType.DateTime2,x.StartAt);P(q,"@due",SqlDbType.DateTime2,x.DueAt);P(q,"@status",SqlDbType.NVarChar,status,20);P(q,"@description",SqlDbType.NVarChar,Clean(x.Description),2000);P(q,"@result",SqlDbType.NVarChar,Clean(x.Result),2000);P(q,"@active",SqlDbType.Bit,x.IsActive);P(q,"@user",SqlDbType.BigInt,user);try{return Ok(new{id=Convert.ToInt64(await q.ExecuteScalarAsync(t))});}catch(SqlException e)when(e.Number is 2601 or 2627){return Conflict(new{message="รหัสกิจกรรมซ้ำ",description="ใช้รหัสอื่นภายในบริษัท"});}
    }

    [HttpPut("my-tasks/{id:long}")]
    public async Task<IActionResult> UpdateMyTask(long id,MyTaskInput x,CancellationToken t)
    {
        var status=x.Status.Trim().ToUpperInvariant();if(!new[]{"PENDING","IN_PROGRESS","DONE","CANCELLED"}.Contains(status))return Bad("สถานะไม่ถูกต้อง","เลือกสถานะงานขายที่ระบบรองรับ");if(!Scope(out var co,out var user))return Forbid();await using var c=await Open(t);if(!await Can(c,"45006","EDIT",t))return Forbid();const string sql="UPDATE a SET StatusCode=@status,ResultText=@result,DueAt=COALESCE(@next,a.DueAt),CompletedAt=CASE WHEN @status=N'DONE' THEN COALESCE(a.CompletedAt,SYSUTCDATETIME()) ELSE NULL END,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() FROM dbo.TDSLActivity a WHERE a.CompanyID=@co AND a.ActivityID=@id AND a.AssignedEmployeeID IN(SELECT EmployeeID FROM dbo.TDADUserEmployee WHERE CompanyID=@co AND UserID=@user)";await using var q=new SqlCommand(sql,c);P(q,"@status",SqlDbType.NVarChar,status,20);P(q,"@result",SqlDbType.NVarChar,Clean(x.Result),2000);P(q,"@next",SqlDbType.DateTime2,x.NextDueAt);P(q,"@user",SqlDbType.BigInt,user);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);return await q.ExecuteNonQueryAsync(t)==1?NoContent():Forbid();
    }

    async Task<IActionResult> Read(string menu,string sql,CancellationToken t){if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,menu,"VIEW",t))return Forbid();return await Rows(c,sql,co,t);}
    async Task<IActionResult> Rows(SqlConnection c,string sql,long co,CancellationToken t){await using var q=new SqlCommand(sql,c);P(q,"@co",SqlDbType.BigInt,co);return Ok(await ReadRows(q,t));}
    static async Task<List<Dictionary<string,object?>>> ReadRows(SqlCommand q,CancellationToken t){await using var r=await q.ExecuteReaderAsync(t);var result=new List<Dictionary<string,object?>>();while(await r.ReadAsync(t)){var row=new Dictionary<string,object?>();for(var i=0;i<r.FieldCount;i++){var key=r.GetName(i);row[char.ToLowerInvariant(key[0])+key[1..]]=r.IsDBNull(i)?null:r.GetValue(i);}result.Add(row);}return result;}
    static async Task<Dictionary<string,object?>> Multi(SqlCommand q,CancellationToken t,string[] names){await using var r=await q.ExecuteReaderAsync(t);var result=new Dictionary<string,object?>();var n=0;do{var rows=new List<Dictionary<string,object?>>();while(await r.ReadAsync(t)){var row=new Dictionary<string,object?>();for(var i=0;i<r.FieldCount;i++){var key=r.GetName(i);row[char.ToLowerInvariant(key[0])+key[1..]]=r.IsDBNull(i)?null:r.GetValue(i);}rows.Add(row);}result[names[n++]]=rows;}while(n<names.Length&&await r.NextResultAsync(t));return result;}
    async Task<IActionResult> Delete(string menu,string table,string key,long id,string detail,CancellationToken t,string extra=""){if(!Scope(out var co,out _))return Forbid();await using var c=await Open(t);if(!await Can(c,menu,"DELETE",t))return Forbid();await using var q=new SqlCommand($"DELETE {table} WHERE CompanyID=@co AND {key}=@id{extra}",c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);try{return await q.ExecuteNonQueryAsync(t)==1?NoContent():Conflict(new{message="ลบรายการไม่ได้",description=detail});}catch(SqlException e)when(e.Number==547){return Conflict(new{message="ลบรายการไม่ได้",description=detail});}}
    async Task<bool> ActivityReferencesValid(SqlConnection c,long co,ActivityInput x,CancellationToken t){await using var q=new SqlCommand("SELECT (SELECT COUNT(*) FROM dbo.TDADEmployee WHERE CompanyID=@co AND EmployeeID=@employee AND IsActive=1)+(CASE WHEN @lead IS NULL THEN 1 ELSE (SELECT COUNT(*) FROM dbo.TDSLLead WHERE CompanyID=@co AND LeadID=@lead AND IsActive=1) END)+(CASE WHEN @customer IS NULL THEN 1 ELSE (SELECT COUNT(*) FROM dbo.TDARCustomer WHERE CompanyID=@co AND CustomerID=@customer AND IsActive=1) END)+(CASE WHEN @opportunity IS NULL THEN 1 ELSE (SELECT COUNT(*) FROM dbo.TDSLOpportunity WHERE CompanyID=@co AND OpportunityID=@opportunity AND IsActive=1) END)",c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@employee",SqlDbType.BigInt,x.AssignedEmployeeID);P(q,"@lead",SqlDbType.BigInt,x.LeadID);P(q,"@customer",SqlDbType.BigInt,x.CustomerID);P(q,"@opportunity",SqlDbType.BigInt,x.OpportunityID);return Convert.ToInt32(await q.ExecuteScalarAsync(t))==4;}
    async Task<bool> CustomerStageValid(SqlConnection c,long co,long customer,long stage,CancellationToken t){await using var q=new SqlCommand("SELECT (SELECT COUNT(*) FROM dbo.TDARCustomer WHERE CompanyID=@co AND CustomerID=@customer AND IsActive=1)+(SELECT COUNT(*) FROM dbo.TDSLPipelineStage WHERE CompanyID=@co AND PipelineStageID=@stage AND IsActive=1 AND StageType=N'OPEN')",c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@customer",SqlDbType.BigInt,customer);P(q,"@stage",SqlDbType.BigInt,stage);return Convert.ToInt32(await q.ExecuteScalarAsync(t))==2;}
    async Task<bool> ValidStages(SqlConnection c,long co,long[] ids,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT(*) FROM dbo.TDSLPipelineStage WHERE CompanyID=@co AND IsActive=1 AND PipelineStageID IN(@a,@b,@c)",c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@a",SqlDbType.BigInt,ids[0]);P(q,"@b",SqlDbType.BigInt,ids[1]);P(q,"@c",SqlDbType.BigInt,ids[2]);return Convert.ToInt32(await q.ExecuteScalarAsync(t))==ids.Distinct().Count();}
    static async Task<bool> EmployeeExists(SqlConnection c,long co,long id,CancellationToken t){await using var q=new SqlCommand("SELECT COUNT(*) FROM dbo.TDADEmployee WHERE CompanyID=@co AND EmployeeID=@id AND IsActive=1",c);P(q,"@co",SqlDbType.BigInt,co);P(q,"@id",SqlDbType.BigInt,id);return Convert.ToInt32(await q.ExecuteScalarAsync(t))==1;}
    static async Task EnsureSetting(SqlConnection c,long co,CancellationToken t){await using var q=new SqlCommand("DECLARE @p bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_SALES');IF NOT EXISTS(SELECT 1 FROM dbo.TDSTCompanySetupSystemSales WHERE CompanyID=@co AND ProjectID=@p) INSERT dbo.TDSTCompanySetupSystemSales(CompanyID,ProjectID,CreateBy) VALUES(@co,@p,0)",c);P(q,"@co",SqlDbType.BigInt,co);await q.ExecuteNonQueryAsync(t);}
    async Task<bool> HasAnyView(SqlConnection c,CancellationToken t){foreach(var menu in Menus)if(await Can(c,menu,"VIEW",t))return true;return false;}
    Task<bool> Can(SqlConnection c,string menu,string action,CancellationToken t)=>CompanyMenuAccess.IsAllowedAsync(c,User,menu,action,t);
    bool Scope(out long co,out long user){co=0;user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out co)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&co>0&&user>0;}
    async Task<SqlConnection> Open(CancellationToken t){var c=new SqlConnection(config.GetConnectionString("LaooDatabase"));await c.OpenAsync(t);return c;}
    static void P(SqlCommand q,string name,SqlDbType type,object? value,int size=0){var p=size>0?q.Parameters.Add(name,type,size):q.Parameters.Add(name,type);p.Value=value??DBNull.Value;}
    static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
    static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetValue(i)?.ToString();
    BadRequestObjectResult Bad(string message,string description)=>BadRequest(new{message,description});
}

public sealed record SalesSettingInput(bool IsEnabled,int LeadIdleDays,int ActivityReminderDays,long DefaultStageID,long WonStageID,long LostStageID);
public sealed record PipelineStageInput(string Code,string Name,int SortOrder,decimal Probability,string Type,bool IsActive=true);
public sealed record LeadInput(string? Code,string Type,string Name,string? ContactName,string? Phone,string? Email,string? TaxID,string? Address,string? Source,int Score,string Status,long? AssignedEmployeeID,DateTime? LastContactAt,DateTime? NextContactAt,string? Remark,bool IsActive=true);
public sealed record LeadConvertInput(long? CustomerID,string OpportunityName,decimal Amount,DateTime ExpectedCloseDate);
public sealed record OpportunityInput(string? Code,string Name,long CustomerID,long StageID,decimal Amount,decimal Probability,DateTime ExpectedCloseDate,long? AssignedEmployeeID,string? Competitor,string? Remark,bool IsActive=true);
public sealed record OpportunityCloseInput(string Status,DateTime ClosedDate,string Reason);
public sealed record ActivityInput(string? Code,string Type,string Title,long? LeadID,long? CustomerID,long? OpportunityID,long AssignedEmployeeID,DateTime StartAt,DateTime DueAt,string Status,string? Description,string? Result,bool IsActive=true);
public sealed record MyTaskInput(string Status,string? Result,DateTime? NextDueAt);
