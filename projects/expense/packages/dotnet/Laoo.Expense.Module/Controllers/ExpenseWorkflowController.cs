using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooExpenseModule.Controllers;

[ApiController, Authorize, Route("api/company/expense-workflow")]
public sealed class ExpenseWorkflowController(IConfiguration configuration) : ControllerBase
{
    private const string Group = "015";

    [HttpGet("options")]
    public async Task<IActionResult> Options(CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var cn = await Open(token);
        if (!await AnyView(cn, token)) return Forbid();
        const string sql = "SELECT MasterCode code,Name name FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND MasterGroupCode=@group AND IsActive=1 ORDER BY ISNULL(Seq,0),Name;SELECT ExpenseDocumentID id,DocumentNo code,TotalAmount total,StatusCode status FROM dbo.TDEXExpenseDocument WHERE CompanyID=@company AND OwnerUserID=@user AND DocumentTypeCode=N'ADVANCE' AND StatusCode=N'PAID' ORDER BY DocumentDate DESC,ExpenseDocumentID DESC;SELECT BusinessProjectID id,ProjectNo code,ProjectName name FROM dbo.TDPMProject WHERE CompanyID=@company AND StatusCode IN(N'DRAFT',N'ACTIVE') ORDER BY ProjectName";
        await using var cmd = new SqlCommand(sql, cn); P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@user",SqlDbType.BigInt,user);P(cmd,"@group",SqlDbType.NVarChar,Group,10);
        return Ok(await Multi(cmd, token, ["categories","advances","projects"]));
    }

    [HttpGet("advances")]
    public Task<IActionResult> Advances(string? search,string? status,int page=1,int pageSize=10,CancellationToken token=default)=>List("41003","ADVANCE",false,search,status,page,pageSize,token);
    [HttpGet("claims")]
    public Task<IActionResult> Claims(string? search,string? status,int page=1,int pageSize=10,CancellationToken token=default)=>List("41004","CLAIM",false,search,status,page,pageSize,token);
    [HttpGet("mine")]
    public Task<IActionResult> Mine(string? search,string? status,int page=1,int pageSize=10,CancellationToken token=default)=>List("41007",null,true,search,status,page,pageSize,token);

    [HttpGet("documents/{id:long}")]
    public async Task<IActionResult> Document(long id,CancellationToken token)
    {
        if (!Scope(out var company,out var user)) return Forbid();
        await using var cn=await Open(token);
        const string sql="SELECT ExpenseDocumentID id,DocumentTypeCode type,DocumentNo code,OwnerUserID ownerUserId,AdvanceDocumentID advanceId,DocumentDate,RequiredDate,PayeeName payee,PurposeText purpose,CurrencyCode currency,TotalAmount total,StatusCode status,BusinessProjectID projectId,Remark FROM dbo.TDEXExpenseDocument WHERE CompanyID=@company AND ExpenseDocumentID=@id;SELECT ExpenseDocumentDetailID id,LineSeq [lineNo],ExpenseTypeCode categoryCode,DescriptionText description,Amount FROM dbo.TDEXExpenseDocumentDetail WHERE CompanyID=@company AND ExpenseDocumentID=@id ORDER BY LineSeq;SELECT ActionCode action,FromStatusCode fromStatus,ToStatusCode toStatus,Remark,ActionBy actionBy,ActionDate FROM dbo.TDEXExpenseDocumentHistory WHERE CompanyID=@company AND ExpenseDocumentID=@id ORDER BY ActionDate,ExpenseDocumentHistoryID";
        await using var cmd=new SqlCommand(sql,cn);P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@id",SqlDbType.BigInt,id);
        var result=await Multi(cmd,token,["header","details","history"]);var headers=(List<Dictionary<string,object?>>)result["header"]!;if(headers.Count==0)return NotFound();
        var h=headers[0];var type=$"{h["type"]}";var owner=Convert.ToInt64(h["ownerUserId"]);var menu=type=="ADVANCE"?"41003":"41004";
        var allowed=owner==user?(await Can(cn,"41007","VIEW",token)||await Can(cn,menu,"VIEW",token)):(await Can(cn,menu,"VIEW",token)||await Can(cn,"41005","VIEW",token)||await Can(cn,"41006","VIEW",token));
        if(!allowed)return Forbid();
        return Ok(new{header=h,details=result["details"],history=result["history"]});
    }

    [HttpPost("advances")]
    public Task<IActionResult> CreateAdvance(ExpenseDocumentInput input,CancellationToken token)=>Save(null,"ADVANCE","41003",input,"CREATE",token);
    [HttpPut("advances/{id:long}")]
    public Task<IActionResult> UpdateAdvance(long id,ExpenseDocumentInput input,CancellationToken token)=>Save(id,"ADVANCE","41003",input,"EDIT",token);
    [HttpDelete("advances/{id:long}")]
    public Task<IActionResult> DeleteAdvance(long id,CancellationToken token)=>Delete(id,"ADVANCE","41003",token);
    [HttpPost("claims")]
    public Task<IActionResult> CreateClaim(ExpenseDocumentInput input,CancellationToken token)=>Save(null,"CLAIM","41004",input,"CREATE",token);
    [HttpPut("claims/{id:long}")]
    public Task<IActionResult> UpdateClaim(long id,ExpenseDocumentInput input,CancellationToken token)=>Save(id,"CLAIM","41004",input,"EDIT",token);
    [HttpDelete("claims/{id:long}")]
    public Task<IActionResult> DeleteClaim(long id,CancellationToken token)=>Delete(id,"CLAIM","41004",token);
    [HttpPut("mine/advances/{id:long}")]
    public Task<IActionResult> UpdateMyAdvance(long id,ExpenseDocumentInput input,CancellationToken token)=>Save(id,"ADVANCE","41007",input,"EDIT",token);
    [HttpDelete("mine/advances/{id:long}")]
    public Task<IActionResult> DeleteMyAdvance(long id,CancellationToken token)=>Delete(id,"ADVANCE","41007",token);
    [HttpPost("mine/claims")]
    public Task<IActionResult> CreateMyClaim(ExpenseDocumentInput input,CancellationToken token)=>Save(null,"CLAIM","41007",input,"CREATE",token);
    [HttpPut("mine/claims/{id:long}")]
    public Task<IActionResult> UpdateMyClaim(long id,ExpenseDocumentInput input,CancellationToken token)=>Save(id,"CLAIM","41007",input,"EDIT",token);
    [HttpDelete("mine/claims/{id:long}")]
    public Task<IActionResult> DeleteMyClaim(long id,CancellationToken token)=>Delete(id,"CLAIM","41007",token);

    [HttpPost("documents/{id:long}/submit")]
    public Task<IActionResult> Submit(long id,CancellationToken token)=>TransitionOwner(id,"SUBMIT","DRAFT","SUBMITTED",token);
    [HttpPost("documents/{id:long}/cancel")]
    public Task<IActionResult> Cancel(long id,CancellationToken token)=>CancelOwner(id,token);

    [HttpGet("approvals")]
    public Task<IActionResult> Approvals(string? search,int page=1,int pageSize=10,CancellationToken token=default)=>Queue("41005",["SUBMITTED"],search,page,pageSize,token);
    [HttpPost("approvals/{id:long}/approve")]
    public Task<IActionResult> Approve(long id,ExpenseDecisionInput input,CancellationToken token)=>Decide(id,true,input,token);
    [HttpPost("approvals/{id:long}/reject")]
    public Task<IActionResult> Reject(long id,ExpenseDecisionInput input,CancellationToken token)=>Decide(id,false,input,token);

    [HttpGet("settlements")]
    public Task<IActionResult> Settlements(string? search,int page=1,int pageSize=10,CancellationToken token=default)=>Queue("41006",["APPROVED","PAID"],search,page,pageSize,token);
    [HttpPost("settlements/{id:long}/payment")]
    public Task<IActionResult> Payment(long id,ExpenseDecisionInput input,CancellationToken token)=>Finance(id,"CONFIRM_PAYMENT","APPROVED","PAID",input.Remark,token);
    [HttpPost("settlements/{id:long}/settle")]
    public Task<IActionResult> Settle(long id,ExpenseDecisionInput input,CancellationToken token)=>Finance(id,"CONFIRM_SETTLEMENT","PAID","SETTLED",input.Remark,token);

    [HttpGet("reports")]
    public async Task<IActionResult> Reports(DateTime? dateFrom,DateTime? dateTo,string? period,string? categoryCode,long? departmentId,long? employeeId,int page=1,int pageSize=10,CancellationToken token=default)
    {
        if(!Scope(out var company,out _))return Forbid();
        await using var cn=await Open(token);
        if(!await Can(cn,"41008","VIEW",token))return Forbid();
        if(dateFrom?.Date>dateTo?.Date)return BadRequest(new{message="ช่วงวันที่ไม่ถูกต้อง",description="วันที่เริ่มต้นต้องไม่มากกว่าวันที่สิ้นสุด"});
        var periodCode=Clean(period)?.ToUpperInvariant()??"MONTH";
        if(periodCode is not("YEAR" or "MONTH" or "DAY"))return BadRequest(new{message="มุมมองเวลาไม่ถูกต้อง",description="เลือกมุมมองปี เดือน หรือวัน"});
        page=Math.Max(1,page);pageSize=Math.Clamp(pageSize,1,100);
        var filter=" WHERE (@from IS NULL OR d.documentDate>=@from) AND (@to IS NULL OR d.documentDate<=@to) AND (@department IS NULL OR d.departmentId=@department) AND (@employee IS NULL OR d.employeeId=@employee) AND (@category IS NULL OR EXISTS(SELECT 1 FROM #Lines lf WHERE lf.docKey=d.docKey AND lf.categoryCode=@category))";
        var sql=$@"
CREATE TABLE #Docs(docKey nvarchar(50) NOT NULL PRIMARY KEY,source nvarchar(20) NOT NULL,sourceId bigint NOT NULL,code nvarchar(40) NOT NULL,documentDate date NOT NULL,payee nvarchar(250) NOT NULL,total decimal(18,2) NOT NULL,status nvarchar(20) NOT NULL,userId bigint NOT NULL,employeeId bigint NULL,employeeCode nvarchar(50) NULL,employeeName nvarchar(250) NULL,departmentId bigint NULL,departmentName nvarchar(250) NULL);
INSERT #Docs
SELECT CONCAT(N'DIRECT:',x.ExpenseID),N'DIRECT',x.ExpenseID,x.ExpenseNo,x.ExpenseDate,x.PayeeName,x.TotalAmount,x.StatusCode,x.CreateBy,e.EmployeeID,e.EmployeeCode,e.FullName,COALESCE(a.DepartmentOrgUnitID,e.DepartmentOrgUnitID),o.NameTH
FROM dbo.TDEXExpense x
OUTER APPLY(SELECT TOP(1) ue.EmployeeID FROM dbo.TDADUserEmployee ue WHERE ue.CompanyID=x.CompanyID AND ue.UserID=x.CreateBy AND ue.IsActive=1 ORDER BY ue.UserEmployeeID) ue
LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=x.CompanyID AND e.EmployeeID=ue.EmployeeID
OUTER APPLY(SELECT TOP(1) oa.DepartmentOrgUnitID FROM dbo.TDADEmployeeOrganizationAssignment oa WHERE oa.CompanyID=x.CompanyID AND oa.EmployeeID=e.EmployeeID AND oa.IsActive=1 AND oa.EffectiveFrom<=x.ExpenseDate AND(oa.EffectiveTo IS NULL OR oa.EffectiveTo>=x.ExpenseDate) ORDER BY oa.EffectiveFrom DESC,oa.EmployeeOrganizationAssignmentID DESC)a
LEFT JOIN dbo.TDADOrganizationUnit o ON o.CompanyID=x.CompanyID AND o.OrgUnitID=COALESCE(a.DepartmentOrgUnitID,e.DepartmentOrgUnitID)
WHERE x.CompanyID=@company;
INSERT #Docs
SELECT CONCAT(N'CLAIM:',x.ExpenseDocumentID),N'CLAIM',x.ExpenseDocumentID,x.DocumentNo,x.DocumentDate,x.PayeeName,x.TotalAmount,x.StatusCode,x.OwnerUserID,e.EmployeeID,e.EmployeeCode,e.FullName,COALESCE(a.DepartmentOrgUnitID,e.DepartmentOrgUnitID),o.NameTH
FROM dbo.TDEXExpenseDocument x
OUTER APPLY(SELECT TOP(1) ue.EmployeeID FROM dbo.TDADUserEmployee ue WHERE ue.CompanyID=x.CompanyID AND ue.UserID=x.OwnerUserID AND ue.IsActive=1 ORDER BY ue.UserEmployeeID) ue
LEFT JOIN dbo.TDADEmployee e ON e.CompanyID=x.CompanyID AND e.EmployeeID=ue.EmployeeID
OUTER APPLY(SELECT TOP(1) oa.DepartmentOrgUnitID FROM dbo.TDADEmployeeOrganizationAssignment oa WHERE oa.CompanyID=x.CompanyID AND oa.EmployeeID=e.EmployeeID AND oa.IsActive=1 AND oa.EffectiveFrom<=x.DocumentDate AND(oa.EffectiveTo IS NULL OR oa.EffectiveTo>=x.DocumentDate) ORDER BY oa.EffectiveFrom DESC,oa.EmployeeOrganizationAssignmentID DESC)a
LEFT JOIN dbo.TDADOrganizationUnit o ON o.CompanyID=x.CompanyID AND o.OrgUnitID=COALESCE(a.DepartmentOrgUnitID,e.DepartmentOrgUnitID)
WHERE x.CompanyID=@company AND x.DocumentTypeCode=N'CLAIM';
CREATE TABLE #Lines(docKey nvarchar(50) NOT NULL,categoryCode nvarchar(10) NOT NULL,categoryName nvarchar(250) NOT NULL,amount decimal(18,2) NOT NULL);
INSERT #Lines
SELECT d.docKey,l.ExpenseTypeCode,COALESCE(m.Name,l.ExpenseTypeCode),l.Amount FROM #Docs d JOIN dbo.TDEXExpenseDetail l ON d.source=N'DIRECT' AND l.CompanyID=@company AND l.ExpenseID=d.sourceId LEFT JOIN dbo.TDSTMaster m ON m.OwnerType=N'C' AND m.OwnerCompanyID=@company AND m.MasterGroupCode=@group AND m.MasterCode=l.ExpenseTypeCode;
INSERT #Lines
SELECT d.docKey,l.ExpenseTypeCode,COALESCE(m.Name,l.ExpenseTypeCode),l.Amount FROM #Docs d JOIN dbo.TDEXExpenseDocumentDetail l ON d.source=N'CLAIM' AND l.CompanyID=@company AND l.ExpenseDocumentID=d.sourceId LEFT JOIN dbo.TDSTMaster m ON m.OwnerType=N'C' AND m.OwnerCompanyID=@company AND m.MasterGroupCode=@group AND m.MasterCode=l.ExpenseTypeCode;
SELECT COUNT(*) documentCount,COALESCE(SUM(d.total),0) totalAmount,COALESCE(AVG(d.total),0) averageAmount,COALESCE(SUM(CASE WHEN d.status=N'SUBMITTED' THEN d.total ELSE 0 END),0) pendingAmount,COALESCE(SUM(CASE WHEN d.status IN(N'RECORDED',N'PAID',N'SETTLED') THEN d.total ELSE 0 END),0) paidAmount FROM #Docs d{filter};
SELECT d.status,COUNT(*) documentCount,SUM(d.total) total FROM #Docs d{filter} GROUP BY d.status ORDER BY d.status;
SELECT CASE @period WHEN N'YEAR' THEN CONVERT(nvarchar(4),YEAR(d.documentDate)) WHEN N'MONTH' THEN CONVERT(nvarchar(7),d.documentDate,120) ELSE CONVERT(nvarchar(10),d.documentDate,120) END bucket,MIN(d.documentDate) bucketDate,COUNT(*) documentCount,SUM(d.total) total FROM #Docs d{filter} GROUP BY CASE @period WHEN N'YEAR' THEN CONVERT(nvarchar(4),YEAR(d.documentDate)) WHEN N'MONTH' THEN CONVERT(nvarchar(7),d.documentDate,120) ELSE CONVERT(nvarchar(10),d.documentDate,120) END ORDER BY bucketDate;
SELECT l.categoryCode code,MAX(l.categoryName) name,COUNT(DISTINCT l.docKey) documentCount,SUM(l.amount) total FROM #Lines l JOIN #Docs d ON d.docKey=l.docKey{filter} GROUP BY l.categoryCode ORDER BY total DESC,l.categoryCode;
SELECT d.departmentId id,COALESCE(d.departmentName,N'ไม่ระบุแผนก') name,COUNT(*) documentCount,SUM(d.total) total FROM #Docs d{filter} GROUP BY d.departmentId,d.departmentName ORDER BY total DESC,name;
SELECT d.employeeId id,COALESCE(d.employeeCode,N'-') code,COALESCE(d.employeeName,N'ไม่ระบุพนักงาน') name,COUNT(*) documentCount,SUM(d.total) total FROM #Docs d{filter} GROUP BY d.employeeId,d.employeeCode,d.employeeName ORDER BY total DESC,name;
SELECT COUNT(*) total FROM #Docs d{filter};
SELECT d.source,d.sourceId id,d.code,d.documentDate,d.payee,d.total,N'THB' currency,d.status,d.employeeId,d.employeeCode,d.employeeName,d.departmentId,d.departmentName FROM #Docs d{filter} ORDER BY d.documentDate DESC,d.sourceId DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY;
SELECT DISTINCT d.departmentId id,d.departmentName name FROM #Docs d WHERE d.departmentId IS NOT NULL ORDER BY d.departmentName;
SELECT DISTINCT d.employeeId id,d.employeeCode code,d.employeeName name FROM #Docs d WHERE d.employeeId IS NOT NULL ORDER BY d.employeeName;
SELECT MasterCode code,Name name FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND MasterGroupCode=@group AND IsActive=1 ORDER BY ISNULL(Seq,0),Name;";
        await using var cmd=new SqlCommand(sql,cn);
        P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@group",SqlDbType.NVarChar,Group,10);P(cmd,"@from",SqlDbType.Date,dateFrom?.Date);P(cmd,"@to",SqlDbType.Date,dateTo?.Date);P(cmd,"@period",SqlDbType.NVarChar,periodCode,10);P(cmd,"@category",SqlDbType.NVarChar,Clean(categoryCode)?.ToUpperInvariant(),10);P(cmd,"@department",SqlDbType.BigInt,departmentId);P(cmd,"@employee",SqlDbType.BigInt,employeeId);P(cmd,"@offset",SqlDbType.Int,(page-1)*pageSize);P(cmd,"@size",SqlDbType.Int,pageSize);
        var result=await Multi(cmd,token,["metrics","summary","trend","byCategory","byDepartment","byEmployee","count","items","departmentOptions","employeeOptions","categoryOptions"]);
        var metricRows=(List<Dictionary<string,object?>>)result["metrics"]!;
        var countRows=(List<Dictionary<string,object?>>)result["count"]!;
        var total=countRows.Count==0?0:Convert.ToInt32(countRows[0]["total"]);
        return Ok(new{metrics=metricRows.FirstOrDefault()??[],summary=result["summary"],trend=result["trend"],byCategory=result["byCategory"],byDepartment=result["byDepartment"],byEmployee=result["byEmployee"],items=result["items"],departmentOptions=result["departmentOptions"],employeeOptions=result["employeeOptions"],categoryOptions=result["categoryOptions"],total,page,pageSize,period=periodCode});
    }
    private async Task<IActionResult> List(string menu,string? type,bool mine,string? search,string? status,int page,int pageSize,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();await using var cn=await Open(token);if(!await Can(cn,menu,"VIEW",token))return Forbid();page=Math.Max(1,page);pageSize=Math.Clamp(pageSize,1,100);
        const string where="FROM dbo.TDEXExpenseDocument d WHERE d.CompanyID=@company AND (@type IS NULL OR d.DocumentTypeCode=@type) AND (@mine=0 OR d.OwnerUserID=@user) AND (@status IS NULL OR d.StatusCode=@status) AND (@search IS NULL OR d.DocumentNo LIKE N'%'+@search+N'%' OR d.PayeeName LIKE N'%'+@search+N'%' OR d.PurposeText LIKE N'%'+@search+N'%')";
        var sql=$"SELECT COUNT(*) {where};SELECT d.ExpenseDocumentID id,d.DocumentTypeCode type,d.DocumentNo code,d.DocumentDate,d.PayeeName payee,d.PurposeText purpose,d.TotalAmount total,d.CurrencyCode currency,d.StatusCode status,d.OwnerUserID ownerUserId {where} ORDER BY d.DocumentDate DESC,d.ExpenseDocumentID DESC OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY";
        await using var cmd=new SqlCommand(sql,cn);P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@user",SqlDbType.BigInt,user);P(cmd,"@type",SqlDbType.NVarChar,type,20);P(cmd,"@mine",SqlDbType.Bit,mine);P(cmd,"@status",SqlDbType.NVarChar,Clean(status)?.ToUpperInvariant(),20);P(cmd,"@search",SqlDbType.NVarChar,Clean(search),250);P(cmd,"@offset",SqlDbType.Int,(page-1)*pageSize);P(cmd,"@size",SqlDbType.Int,pageSize);
        return Ok(await Paged(cmd,page,pageSize,token));
    }

    private async Task<IActionResult> Queue(string menu,string[] statuses,string? search,int page,int pageSize,CancellationToken token)
    {
        if(!Scope(out var company,out _))return Forbid();await using var cn=await Open(token);if(!await Can(cn,menu,"VIEW",token))return Forbid();page=Math.Max(1,page);pageSize=Math.Clamp(pageSize,1,100);var names=statuses.Select((_,i)=>$"@s{i}").ToArray();var filter=string.Join(',',names);
        var where=$"FROM dbo.TDEXExpenseDocument d WHERE d.CompanyID=@company AND d.StatusCode IN({filter}) AND (@search IS NULL OR d.DocumentNo LIKE N'%'+@search+N'%' OR d.PayeeName LIKE N'%'+@search+N'%')";var sql=$"SELECT COUNT(*) {where};SELECT d.ExpenseDocumentID id,d.DocumentTypeCode type,d.DocumentNo code,d.DocumentDate,d.PayeeName payee,d.PurposeText purpose,d.TotalAmount total,d.CurrencyCode currency,d.StatusCode status,d.OwnerUserID ownerUserId {where} ORDER BY d.DocumentDate,d.ExpenseDocumentID OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY";
        await using var cmd=new SqlCommand(sql,cn);P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@search",SqlDbType.NVarChar,Clean(search),250);P(cmd,"@offset",SqlDbType.Int,(page-1)*pageSize);P(cmd,"@size",SqlDbType.Int,pageSize);for(var i=0;i<statuses.Length;i++)P(cmd,names[i],SqlDbType.NVarChar,statuses[i],20);return Ok(await Paged(cmd,page,pageSize,token));
    }

    private async Task<IActionResult> Save(long? id,string type,string menu,ExpenseDocumentInput input,string action,CancellationToken token)
    {
        var payee=Clean(input.PayeeName);var purpose=Clean(input.Purpose);var currency=Clean(input.CurrencyCode)?.ToUpperInvariant();if(payee is null||purpose is null||currency is null||currency.Length!=3||input.Details is null||input.Details.Count==0)return BadRequest(new{message="ข้อมูลเอกสารไม่ครบ",description="ระบุวันที่ ผู้รับเงิน วัตถุประสงค์ สกุลเงิน และรายละเอียดอย่างน้อย 1 รายการ"});if(input.Details.Any(x=>string.IsNullOrWhiteSpace(x.ExpenseTypeCode)||string.IsNullOrWhiteSpace(x.Description)||x.Amount<=0))return BadRequest(new{message="รายละเอียดเอกสารไม่ถูกต้อง",description="ทุกรายการต้องมีประเภท รายละเอียด และจำนวนเงินมากกว่า 0"});
        if(!Scope(out var company,out var user))return Forbid();await using var cn=await Open(token);if(!await Can(cn,menu,action,token))return Forbid();var codes=input.Details.Select(x=>x.ExpenseTypeCode.Trim().ToUpperInvariant()).Distinct().ToArray();if(!await ValidCategories(cn,company,codes,token))return BadRequest(new{message="ประเภทค่าใช้จ่ายไม่ถูกต้อง",description="เลือกประเภทที่เปิดใช้งานภายในบริษัท"});
        if(type=="CLAIM"&&input.AdvanceId is long advance&&!await ValidAdvance(cn,company,user,advance,token))return BadRequest(new{message="เงินทดรองอ้างอิงไม่ถูกต้อง",description="เลือกเงินทดรองของผู้ขอที่อนุมัติหรือจ่ายแล้ว"});var total=input.Details.Sum(x=>decimal.Round(x.Amount,2,MidpointRounding.AwayFromZero));if(input.BusinessProjectId is not null){await using var project=new SqlCommand("SELECT COUNT(*) FROM dbo.TDPMProject WHERE CompanyID=@company AND BusinessProjectID=@project AND StatusCode<>N'CANCELLED'",cn);P(project,"@company",SqlDbType.BigInt,company);P(project,"@project",SqlDbType.BigInt,input.BusinessProjectId);if(Convert.ToInt32(await project.ExecuteScalarAsync(token))!=1)return BadRequest(new{message="โครงการไม่ถูกต้อง",description="เลือกโครงการในบริษัทเดียวกันที่ยังไม่ยกเลิก"});}await using var tx=(SqlTransaction)await cn.BeginTransactionAsync(token);
        try{long docId;if(id is null){var code=string.IsNullOrWhiteSpace(input.DocumentNo)?$"{(type=="ADVANCE"?"ADV":"CLM")}{DateTime.UtcNow:yyyyMMddHHmmssfff}":input.DocumentNo.Trim().ToUpperInvariant();const string sql="INSERT dbo.TDEXExpenseDocument(CompanyID,ProjectID,BusinessProjectID,DocumentTypeCode,DocumentNo,OwnerUserID,AdvanceDocumentID,DocumentDate,RequiredDate,PayeeName,PurposeText,CurrencyCode,TotalAmount,StatusCode,Remark,CreateBy) OUTPUT INSERTED.ExpenseDocumentID SELECT @company,ProjectID,@businessProject,@type,@code,@user,@advance,@date,@required,@payee,@purpose,@currency,@total,N'DRAFT',@remark,@user FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_EXPENSE' AND IsActive=1";await using var cmd=new SqlCommand(sql,cn,tx);Bind(cmd,company,null,type,code,input,payee,purpose,currency,total,user);docId=Convert.ToInt64(await cmd.ExecuteScalarAsync(token));await History(cn,tx,docId,company,"CREATE",null,"DRAFT",input.Remark,user,token);}else{const string sql="UPDATE dbo.TDEXExpenseDocument SET BusinessProjectID=@businessProject,AdvanceDocumentID=@advance,DocumentDate=@date,RequiredDate=@required,PayeeName=@payee,PurposeText=@purpose,CurrencyCode=@currency,TotalAmount=@total,Remark=@remark,UpdateBy=@user,UpdateDate=SYSUTCDATETIME() WHERE CompanyID=@company AND ExpenseDocumentID=@id AND DocumentTypeCode=@type AND OwnerUserID=@user AND StatusCode=N'DRAFT'";await using var cmd=new SqlCommand(sql,cn,tx);Bind(cmd,company,id,type,null,input,payee,purpose,currency,total,user);if(await cmd.ExecuteNonQueryAsync(token)!=1){await tx.RollbackAsync(token);return Conflict(new{message="แก้ไขเอกสารไม่ได้",description="แก้ไขได้เฉพาะเอกสารร่างของผู้ Login"});}docId=id.Value;await using var clear=new SqlCommand("DELETE dbo.TDEXExpenseDocumentDetail WHERE CompanyID=@company AND ExpenseDocumentID=@id",cn,tx);P(clear,"@company",SqlDbType.BigInt,company);P(clear,"@id",SqlDbType.BigInt,docId);await clear.ExecuteNonQueryAsync(token);}
            for(var i=0;i<input.Details.Count;i++){var line=input.Details[i];await using var detail=new SqlCommand("INSERT dbo.TDEXExpenseDocumentDetail(ExpenseDocumentID,CompanyID,LineSeq,ExpenseTypeCode,DescriptionText,Amount) VALUES(@id,@company,@line,@type,@description,@amount)",cn,tx);P(detail,"@id",SqlDbType.BigInt,docId);P(detail,"@company",SqlDbType.BigInt,company);P(detail,"@line",SqlDbType.Int,i+1);P(detail,"@type",SqlDbType.NVarChar,line.ExpenseTypeCode.Trim().ToUpperInvariant(),10);P(detail,"@description",SqlDbType.NVarChar,line.Description.Trim(),500);P(detail,"@amount",SqlDbType.Decimal,decimal.Round(line.Amount,2));detail.Parameters["@amount"].Precision=18;detail.Parameters["@amount"].Scale=2;await detail.ExecuteNonQueryAsync(token);}await tx.CommitAsync(token);return Ok(new{id=docId,status="DRAFT",total});}
        catch(SqlException ex)when(ex.Number is 2601 or 2627){await tx.RollbackAsync(token);return Conflict(new{message="เลขที่เอกสารซ้ำ",description="ใช้เลขที่เอกสารอื่นภายในบริษัท"});}catch{await tx.RollbackAsync(token);throw;}
    }

    private async Task<IActionResult> Delete(long id,string type,string menu,CancellationToken token){if(!Scope(out var company,out var user))return Forbid();await using var cn=await Open(token);if(!await Can(cn,menu,"DELETE",token))return Forbid();await using var cmd=new SqlCommand("DELETE dbo.TDEXExpenseDocument WHERE CompanyID=@company AND ExpenseDocumentID=@id AND DocumentTypeCode=@type AND OwnerUserID=@user AND StatusCode=N'DRAFT'",cn);P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@id",SqlDbType.BigInt,id);P(cmd,"@type",SqlDbType.NVarChar,type,20);P(cmd,"@user",SqlDbType.BigInt,user);return await cmd.ExecuteNonQueryAsync(token)==1?NoContent():Conflict(new{message="ลบเอกสารไม่ได้",description="ลบได้เฉพาะเอกสารร่างของผู้ Login"});}
    private async Task<IActionResult> TransitionOwner(long id,string action,string from,string to,CancellationToken token){if(!Scope(out var company,out var user))return Forbid();await using var cn=await Open(token);var meta=await Meta(cn,company,id,token);if(meta is null)return NotFound();var menu=meta.Value.Type=="ADVANCE"?"41003":"41004";if(meta.Value.Owner!=user||(!await Can(cn,menu,action,token)&&!await Can(cn,"41007",action,token)))return Forbid();return await Transition(cn,id,company,user,action,from,to,null,token);}
    private async Task<IActionResult> CancelOwner(long id,CancellationToken token){if(!Scope(out var company,out var user))return Forbid();await using var cn=await Open(token);var meta=await Meta(cn,company,id,token);if(meta is null)return NotFound();var menu=meta.Value.Type=="ADVANCE"?"41003":"41004";if(meta.Value.Owner!=user||(!await Can(cn,menu,"CANCEL",token)&&!await Can(cn,"41007","CANCEL",token)))return Forbid();if(meta.Value.Status is not("DRAFT" or "SUBMITTED"))return Conflict(new{message="ยกเลิกเอกสารไม่ได้",description="ยกเลิกได้เฉพาะร่างหรือรออนุมัติ"});return await Transition(cn,id,company,user,"CANCEL",meta.Value.Status,"CANCELLED",null,token);}
    private async Task<IActionResult> Decide(long id,bool approve,ExpenseDecisionInput input,CancellationToken token){if(!Scope(out var company,out var user))return Forbid();await using var cn=await Open(token);if(!await Can(cn,"41005","APPROVE",token))return Forbid();var meta=await Meta(cn,company,id,token);if(meta is null)return NotFound();if(meta.Value.Owner==user&&!await Can(cn,"41005","SELF_APPROVE",token))return Forbid();if(!approve&&string.IsNullOrWhiteSpace(input.Remark))return BadRequest(new{message="กรุณาระบุเหตุผลไม่อนุมัติ",description="เหตุผลใช้แจ้งผู้ขอและเก็บในประวัติ"});return await Transition(cn,id,company,user,approve?"APPROVE":"REJECT","SUBMITTED",approve?"APPROVED":"REJECTED",Clean(input.Remark),token);}
    private async Task<IActionResult> Finance(long id,string action,string from,string to,string? remark,CancellationToken token)
    {
        if(!Scope(out var company,out var user))return Forbid();
        await using var cn=await Open(token);
        if(!await Can(cn,"41006",action,token))return Forbid();
        var meta=await Meta(cn,company,id,token);
        if(meta is null)return NotFound();
        if(to=="SETTLED"&&meta.Value.Type=="ADVANCE")return Conflict(new{message="เคลียร์เงินทดรองโดยตรงไม่ได้",description="ให้บันทึกใบเคลียร์ค่าใช้จ่ายที่อ้างอิงเงินทดรอง แล้วเคลียร์ผ่านใบนั้น"});
        await using var tx=(SqlTransaction)await cn.BeginTransactionAsync(token);
        try
        {
            var sets=to switch{"PAID"=>",PaidBy=@user,PaidDate=SYSUTCDATETIME()","SETTLED"=>",SettledBy=@user,SettledDate=SYSUTCDATETIME()",_=>""};
            await using var update=new SqlCommand($"UPDATE dbo.TDEXExpenseDocument SET StatusCode=@to,UpdateBy=@user,UpdateDate=SYSUTCDATETIME(){sets} WHERE CompanyID=@company AND ExpenseDocumentID=@id AND StatusCode=@from",cn,tx);
            P(update,"@to",SqlDbType.NVarChar,to,20);P(update,"@user",SqlDbType.BigInt,user);P(update,"@company",SqlDbType.BigInt,company);P(update,"@id",SqlDbType.BigInt,id);P(update,"@from",SqlDbType.NVarChar,from,20);
            if(await update.ExecuteNonQueryAsync(token)!=1){await tx.RollbackAsync(token);return Conflict(new{message="สถานะเอกสารไม่ถูกต้อง",description=$"ต้องอยู่สถานะ {from} ก่อนทำรายการ"});}
            var cleaned=Clean(remark);
            await History(cn,tx,id,company,action,from,to,cleaned,user,token);
            if(to=="SETTLED")
            {
                await using var linked=new SqlCommand("UPDATE a SET StatusCode=N'SETTLED',SettledBy=@user,SettledDate=SYSUTCDATETIME(),UpdateBy=@user,UpdateDate=SYSUTCDATETIME() OUTPUT INSERTED.ExpenseDocumentID FROM dbo.TDEXExpenseDocument c JOIN dbo.TDEXExpenseDocument a ON a.ExpenseDocumentID=c.AdvanceDocumentID AND a.CompanyID=c.CompanyID WHERE c.CompanyID=@company AND c.ExpenseDocumentID=@id AND c.DocumentTypeCode=N'CLAIM' AND a.StatusCode=N'PAID'",cn,tx);
                P(linked,"@user",SqlDbType.BigInt,user);P(linked,"@company",SqlDbType.BigInt,company);P(linked,"@id",SqlDbType.BigInt,id);
                var linkedId=await linked.ExecuteScalarAsync(token);
                if(linkedId is not null)await History(cn,tx,Convert.ToInt64(linkedId),company,"CONFIRM_SETTLEMENT_LINKED","PAID","SETTLED",cleaned,user,token);
            }
            await tx.CommitAsync(token);
            return Ok(new{id,status=to});
        }
        catch{await tx.RollbackAsync(token);throw;}
    }
    private static async Task<IActionResult> Transition(SqlConnection cn,long id,long company,long user,string action,string from,string to,string? remark,CancellationToken token){await using var tx=(SqlTransaction)await cn.BeginTransactionAsync(token);var sets=to switch{"SUBMITTED"=>",SubmittedBy=@user,SubmittedDate=SYSUTCDATETIME()","APPROVED"=>",ApprovedBy=@user,ApprovedDate=SYSUTCDATETIME()","REJECTED"=>",RejectedBy=@user,RejectedDate=SYSUTCDATETIME(),RejectReason=@remark","PAID"=>",PaidBy=@user,PaidDate=SYSUTCDATETIME()","SETTLED"=>",SettledBy=@user,SettledDate=SYSUTCDATETIME()","CANCELLED"=>",CancelledBy=@user,CancelledDate=SYSUTCDATETIME()",_=>""};await using var cmd=new SqlCommand($"UPDATE dbo.TDEXExpenseDocument SET StatusCode=@to,UpdateBy=@user,UpdateDate=SYSUTCDATETIME(){sets} WHERE CompanyID=@company AND ExpenseDocumentID=@id AND StatusCode=@from",cn,tx);P(cmd,"@to",SqlDbType.NVarChar,to,20);P(cmd,"@user",SqlDbType.BigInt,user);P(cmd,"@remark",SqlDbType.NVarChar,remark,1000);P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@id",SqlDbType.BigInt,id);P(cmd,"@from",SqlDbType.NVarChar,from,20);if(await cmd.ExecuteNonQueryAsync(token)!=1){await tx.RollbackAsync(token);return new ConflictObjectResult(new{message="สถานะเอกสารไม่ถูกต้อง",description=$"ต้องอยู่สถานะ {from} ก่อนทำรายการ"});}await History(cn,tx,id,company,action,from,to,remark,user,token);await tx.CommitAsync(token);return new OkObjectResult(new{id,status=to});}

    private static async Task History(SqlConnection cn,SqlTransaction tx,long id,long company,string action,string? from,string to,string? remark,long user,CancellationToken token){await using var cmd=new SqlCommand("INSERT dbo.TDEXExpenseDocumentHistory(ExpenseDocumentID,CompanyID,ActionCode,FromStatusCode,ToStatusCode,Remark,ActionBy) VALUES(@id,@company,@action,@from,@to,@remark,@user)",cn,tx);P(cmd,"@id",SqlDbType.BigInt,id);P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@action",SqlDbType.NVarChar,action,30);P(cmd,"@from",SqlDbType.NVarChar,from,20);P(cmd,"@to",SqlDbType.NVarChar,to,20);P(cmd,"@remark",SqlDbType.NVarChar,Clean(remark),1000);P(cmd,"@user",SqlDbType.BigInt,user);await cmd.ExecuteNonQueryAsync(token);}
    private static void Bind(SqlCommand cmd,long company,long? id,string type,string? code,ExpenseDocumentInput input,string payee,string purpose,string currency,decimal total,long user){P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@businessProject",SqlDbType.BigInt,input.BusinessProjectId);P(cmd,"@id",SqlDbType.BigInt,id);P(cmd,"@type",SqlDbType.NVarChar,type,20);P(cmd,"@code",SqlDbType.NVarChar,code,40);P(cmd,"@user",SqlDbType.BigInt,user);P(cmd,"@advance",SqlDbType.BigInt,input.AdvanceId);P(cmd,"@date",SqlDbType.Date,input.DocumentDate.Date);P(cmd,"@required",SqlDbType.Date,input.RequiredDate?.Date);P(cmd,"@payee",SqlDbType.NVarChar,payee,250);P(cmd,"@purpose",SqlDbType.NVarChar,purpose,1000);P(cmd,"@currency",SqlDbType.NVarChar,currency,3);P(cmd,"@total",SqlDbType.Decimal,total);cmd.Parameters["@total"].Precision=18;cmd.Parameters["@total"].Scale=2;P(cmd,"@remark",SqlDbType.NVarChar,Clean(input.Remark),2000);}
    private async Task<bool> ValidCategories(SqlConnection cn,long company,string[] codes,CancellationToken token){if(codes.Length==0)return false;var names=codes.Select((_,i)=>$"@c{i}").ToArray();await using var cmd=new SqlCommand($"SELECT COUNT(DISTINCT MasterCode) FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND OwnerCompanyID=@company AND MasterGroupCode=@group AND IsActive=1 AND MasterCode IN({string.Join(',',names)})",cn);P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@group",SqlDbType.NVarChar,Group,10);for(var i=0;i<codes.Length;i++)P(cmd,names[i],SqlDbType.NVarChar,codes[i],10);return Convert.ToInt32(await cmd.ExecuteScalarAsync(token))==codes.Length;}
    private static async Task<bool> ValidAdvance(SqlConnection cn,long company,long user,long id,CancellationToken token){await using var cmd=new SqlCommand("SELECT COUNT(*) FROM dbo.TDEXExpenseDocument WHERE CompanyID=@company AND ExpenseDocumentID=@id AND OwnerUserID=@user AND DocumentTypeCode=N'ADVANCE' AND StatusCode=N'PAID'",cn);P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@user",SqlDbType.BigInt,user);P(cmd,"@id",SqlDbType.BigInt,id);return Convert.ToInt32(await cmd.ExecuteScalarAsync(token))==1;}
    private static async Task<(string Type,long Owner,string Status)?> Meta(SqlConnection cn,long company,long id,CancellationToken token){await using var cmd=new SqlCommand("SELECT DocumentTypeCode,OwnerUserID,StatusCode FROM dbo.TDEXExpenseDocument WHERE CompanyID=@company AND ExpenseDocumentID=@id",cn);P(cmd,"@company",SqlDbType.BigInt,company);P(cmd,"@id",SqlDbType.BigInt,id);await using var r=await cmd.ExecuteReaderAsync(token);return await r.ReadAsync(token)?(r.GetString(0),r.GetInt64(1),r.GetString(2)):null;}
    private async Task<bool> AnyView(SqlConnection cn,CancellationToken token)=>await Can(cn,"41003","VIEW",token)||await Can(cn,"41004","VIEW",token)||await Can(cn,"41007","VIEW",token);
    private Task<bool> Can(SqlConnection cn,string menu,string action,CancellationToken token)=>CompanyMenuAccess.IsAllowedAsync(cn,User,menu,action,token);
    private bool Scope(out long company,out long user){company=0;user=0;return string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&string.Equals(User.FindFirstValue("project_code"),"LAOO_EXPENSE",StringComparison.OrdinalIgnoreCase)&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}
    private async Task<SqlConnection> Open(CancellationToken token){var cn=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await cn.OpenAsync(token);return cn;}
    private static async Task<Dictionary<string,object?>> Paged(SqlCommand cmd,int page,int size,CancellationToken token){await using var r=await cmd.ExecuteReaderAsync(token);var total=0;if(await r.ReadAsync(token))total=r.GetInt32(0);await r.NextResultAsync(token);return new(){["items"]=await Read(r,token),["total"]=total,["page"]=page,["pageSize"]=size};}
    private static async Task<Dictionary<string,object?>> Multi(SqlCommand cmd,CancellationToken token,string[] names){await using var r=await cmd.ExecuteReaderAsync(token);var result=new Dictionary<string,object?>();var i=0;do{result[names[i++]]=await Read(r,token);}while(i<names.Length&&await r.NextResultAsync(token));return result;}
    private static async Task<List<Dictionary<string,object?>>> Read(SqlDataReader r,CancellationToken token){var rows=new List<Dictionary<string,object?>>();while(await r.ReadAsync(token)){var row=new Dictionary<string,object?>();for(var i=0;i<r.FieldCount;i++){var name=r.GetName(i);row[char.ToLowerInvariant(name[0])+name[1..]]=r.IsDBNull(i)?null:r.GetValue(i);}rows.Add(row);}return rows;}
    private static void P(SqlCommand cmd,string name,SqlDbType type,object? value,int size=0){var p=size>0?cmd.Parameters.Add(name,type,size):cmd.Parameters.Add(name,type);p.Value=value??DBNull.Value;}
    private static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
}

public sealed record ExpenseDocumentDetailInput(string ExpenseTypeCode,string Description,decimal Amount);
public sealed record ExpenseDocumentInput(string? DocumentNo,DateTime DocumentDate,DateTime? RequiredDate,string PayeeName,string Purpose,string CurrencyCode,long? AdvanceId,long? BusinessProjectId,string? Remark,List<ExpenseDocumentDetailInput> Details);
public sealed record ExpenseDecisionInput(string? Remark);