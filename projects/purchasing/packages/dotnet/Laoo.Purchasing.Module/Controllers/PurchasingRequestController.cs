using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Globalization;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authorization;
using Laoo.Shared.Contracts;

namespace LaooPurchasingModule.Controllers;

[ApiController, Authorize]
[Route("api/purchasing/requests")]
public sealed class PurchasingRequestController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private string ConnectionString => configuration.GetConnectionString("LaooDatabase") ?? throw new InvalidOperationException("LaooDatabase is not configured.");

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] long? divisionId, [FromQuery] long? departmentId, [FromQuery] long? requesterId, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken token = default)
    {
        if (!TryScope(out var company, out var user)) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        await using var db = new SqlConnection(ConnectionString); await db.OpenAsync(token);
        if (!await CompanyMenuAccess.IsAllowedAsync(db, User, "69002", "VIEW", token)) return Forbid();
        var canDelete = await CompanyMenuAccess.IsAllowedAsync(db, User, "69002", "DELETE", token);
        const string sql = """
            SELECT h.RequestID, h.RequestNo, h.RequestDate, h.StatusCode, h.ResponsibleUserID, h.Remark,
                   div.NameTH, dep.NameTH, emp.FullName, emp.NickName, setup.EmployeeNameDisplay, usr.DisplayName, usr.Username,
                   dbo.LaooMenuDataAccessAllowed(@company,@user,h.RequesterUserID,N'69002',N'DELETE')
            FROM dbo.TDAPPurchaseRequest h
            LEFT JOIN dbo.TDADUser usr ON usr.CompanyID=h.CompanyID AND usr.UserID=h.RequesterUserID
            OUTER APPLY (SELECT TOP(1) e.FullName,e.NickName,e.DivisionOrgUnitID,e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=h.CompanyID AND ue.UserID=h.RequesterUserID ORDER BY ue.IsActive DESC,e.IsActive DESC,e.EmployeeID) emp
            LEFT JOIN dbo.TDADOrganizationUnit div ON div.CompanyID=h.CompanyID AND div.OrgUnitID=COALESCE(h.DivisionID,emp.DivisionOrgUnitID)
            LEFT JOIN dbo.TDADOrganizationUnit dep ON dep.CompanyID=h.CompanyID AND dep.OrgUnitID=COALESCE(h.DepartmentID,emp.DepartmentOrgUnitID)
            OUTER APPLY (SELECT TOP(1) EmployeeNameDisplay FROM dbo.TDSTCompanySetUp WHERE CompanyID=h.CompanyID AND OwnerType='C' AND IsActive=1) setup
            WHERE h.CompanyID=@company AND dbo.LaooMenuDataAccessAllowed(@company,@user,h.RequesterUserID,N'69002',N'VIEW')=1 AND (@search IS NULL OR h.RequestNo LIKE @likeSearch OR h.Remark LIKE @likeSearch)
              AND (@division IS NULL OR h.DivisionID=@division) AND (@department IS NULL OR h.DepartmentID=@department)
              AND (@requester IS NULL OR h.RequesterUserID=@requester)
            ORDER BY h.RequestDate DESC, h.RequestID DESC OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY;
            SELECT COUNT_BIG(1) FROM dbo.TDAPPurchaseRequest WHERE CompanyID=@company AND dbo.LaooMenuDataAccessAllowed(@company,@user,RequesterUserID,N'69002',N'VIEW')=1
              AND (@search IS NULL OR RequestNo LIKE @likeSearch OR Remark LIKE @likeSearch)
              AND (@division IS NULL OR DivisionID=@division) AND (@department IS NULL OR DepartmentID=@department)
              AND (@requester IS NULL OR RequesterUserID=@requester);
            """;
        await using var q = new SqlCommand(sql, db); Add(q, "@company", SqlDbType.BigInt, company); Add(q, "@user", SqlDbType.BigInt, user); Add(q, "@search", SqlDbType.NVarChar, string.IsNullOrWhiteSpace(search) ? DBNull.Value : search); Add(q, "@likeSearch", SqlDbType.NVarChar, $"%{search}%"); Add(q, "@division", SqlDbType.BigInt, divisionId is null ? DBNull.Value : divisionId); Add(q, "@department", SqlDbType.BigInt, departmentId is null ? DBNull.Value : departmentId); Add(q, "@requester", SqlDbType.BigInt, requesterId is null ? DBNull.Value : requesterId); Add(q, "@skip", SqlDbType.Int, (page - 1) * pageSize); Add(q, "@take", SqlDbType.Int, pageSize);
        var items = new List<object>(); long total = 0; await using var reader = await q.ExecuteReaderAsync(token); while (await reader.ReadAsync(token)) {
            var full = reader.IsDBNull(8) ? "" : reader.GetString(8).Trim(); var nick = reader.IsDBNull(9) ? "" : reader.GetString(9).Trim(); var mode = reader.IsDBNull(10) ? "FULL" : reader.GetString(10).Trim().ToUpperInvariant();
            var requester = mode == "NICK" && nick.Length > 0 ? nick : mode == "BOTH" && full.Length > 0 && nick.Length > 0 ? $"{full} ({nick})" : full.Length > 0 ? full : nick.Length > 0 ? nick : !reader.IsDBNull(11) && !string.IsNullOrWhiteSpace(reader.GetString(11)) ? reader.GetString(11) : !reader.IsDBNull(12) ? reader.GetString(12) : "-";
            items.Add(new { requestId = reader.GetInt64(0), requestNo = reader.GetString(1), requestDate = reader.GetDateTime(2).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), statusCode = reader.GetString(3), responsibleUserId = reader.IsDBNull(4) ? (long?)null : reader.GetInt64(4), remark = reader.IsDBNull(5) ? null : reader.GetString(5), divisionName = reader.IsDBNull(6) ? null : reader.GetString(6), departmentName = reader.IsDBNull(7) ? null : reader.GetString(7), requesterName = requester, canDelete = canDelete && reader.GetString(3)=="DRAFT" && !reader.IsDBNull(13) && Convert.ToBoolean(reader.GetValue(13)) });
        } if (await reader.NextResultAsync(token) && await reader.ReadAsync(token)) total = reader.GetInt64(0);
        return Ok(new { items, total, page, pageSize, divisions = Array.Empty<object>(), departments = Array.Empty<object>(), requesters = Array.Empty<object>() });
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token = default)
    {
        if (!TryScope(out var company, out var user)) return Forbid();
        await using var db = new SqlConnection(ConnectionString); await db.OpenAsync(token);
        if (!await CompanyMenuAccess.IsAllowedAsync(db, User, "69002", "VIEW", token)) return Forbid();
        await using var q = new SqlCommand("SELECT RequestID,RequestNo,RequestDate,StatusCode,RequesterUserID,DivisionID,DepartmentID,ResponsibleUserID,Remark,PreviousPONo,PreviousPRNo FROM dbo.TDAPPurchaseRequest WHERE CompanyID=@company AND RequestID=@id AND dbo.LaooMenuDataAccessAllowed(@company,@user,RequesterUserID,N'69002',N'VIEW')=1", db);
        Add(q, "@company", SqlDbType.BigInt, company); Add(q, "@user", SqlDbType.BigInt, user); Add(q, "@id", SqlDbType.BigInt, id);
        var result = new Dictionary<string,object?>();
        await using (var r = await q.ExecuteReaderAsync(token)) {
            if (!await r.ReadAsync(token)) return NotFound();
            result["requestId"]=r.GetInt64(0);result["requestNo"]=r.GetString(1);result["requestDate"]=r.GetDateTime(2).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);result["statusCode"]=r.GetString(3);
            result["requesterUserId"]=r.IsDBNull(4)?null:r.GetInt64(4);result["divisionId"]=r.IsDBNull(5)?null:r.GetInt64(5);result["departmentId"]=r.IsDBNull(6)?null:r.GetInt64(6);result["responsibleUserId"]=r.IsDBNull(7)?null:r.GetInt64(7);result["remark"]=r.IsDBNull(8)?null:r.GetString(8);
            result["previousPoNo"]=r.IsDBNull(9)?null:r.GetString(9);result["previousPrNo"]=r.IsDBNull(10)?null:r.GetString(10);
        }
        await using var details = new SqlCommand("SELECT DetailID,ItemText,Quantity,EstimatedMin,EstimatedMax,Remark,NeededDate,UrgencyLevel,ReferenceUrl1,ReferenceUrl2,ReferenceUrl3,PreviousPONo,PreviousPRNo FROM dbo.TDAPPurchaseRequestDetail WHERE RequestID=@id ORDER BY SortOrder,DetailID", db);
        Add(details,"@id",SqlDbType.BigInt,id);
        var items = new List<Dictionary<string,object?>>();
        await using (var r = await details.ExecuteReaderAsync(token)) while(await r.ReadAsync(token)) items.Add(new() {
            ["detailId"]=r.GetInt64(0),["itemText"]=r.GetString(1),["quantity"]=r.IsDBNull(2)?null:r.GetDecimal(2),["estimatedMin"]=r.IsDBNull(3)?null:r.GetDecimal(3),["estimatedMax"]=r.IsDBNull(4)?null:r.GetDecimal(4),["remark"]=r.IsDBNull(5)?null:r.GetString(5),["neededDate"]=r.IsDBNull(6)?null:r.GetDateTime(6).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),["urgencyLevel"]=r.GetByte(7),["referenceUrl1"]=r.IsDBNull(8)?null:r.GetString(8),["referenceUrl2"]=r.IsDBNull(9)?null:r.GetString(9),["referenceUrl3"]=r.IsDBNull(10)?null:r.GetString(10),["previousPoNo"]=r.IsDBNull(11)?null:r.GetString(11),["previousPrNo"]=r.IsDBNull(12)?null:r.GetString(12),["attachments"]=new List<object>()
        });
        await using(var attachmentQuery=new SqlCommand("SELECT DetailID,AttachmentID,FileName FROM dbo.TDAPPurchaseRequestAttachment WHERE RequestID=@id ORDER BY AttachmentID",db)) {
            Add(attachmentQuery,"@id",SqlDbType.BigInt,id);await using var r=await attachmentQuery.ExecuteReaderAsync(token);
            while(await r.ReadAsync(token)){var item=items.FirstOrDefault(x=>Convert.ToInt64(x["detailId"])==r.GetInt64(0));if(item is not null)((List<object>)item["attachments"]!).Add(new {attachmentId=r.GetInt64(1),name=r.GetString(2)});}
        }
        result["details"]=items;return Ok(result);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] PurchaseRequestWriteRequest request, CancellationToken token = default)
    {
        if (!TryScope(out var company, out var user)) return Forbid();
        if ((request.PreviousPoNo?.Length ?? 0)>100 || (request.PreviousPrNo?.Length ?? 0)>100) return BadRequest(new {message="เลขที่อ้างอิงยาวเกิน 100 ตัวอักษร"});
        if (request.Details.Any(x => (x.PreviousPoNo?.Length ?? 0)>100 || (x.PreviousPrNo?.Length ?? 0)>100)) return BadRequest(new {message="เลขที่อ้างอิงของรายการยาวเกิน 100 ตัวอักษร"});
        if (!ValidDate(request.RequestDate, false) || request.Details.Any(x => !ValidDate(x.NeededDate, true))) return BadRequest(new {message="วันที่ไม่ถูกต้อง",description="กรุณาเลือกวันที่ใหม่"});
        if (request.Details.Count == 0) return BadRequest(new { message = "บันทึกไม่ได้", description = "ต้องมีรายการจัดซื้ออย่างน้อย 1 รายการ" });
        if (request.Details.Any(x => string.IsNullOrWhiteSpace(x.ItemText) || x.ItemText.Length > 2000)) return BadRequest(new { message = "รายการไม่ถูกต้อง", description = "รายการต้องมีข้อความและยาวไม่เกิน 2,000 ตัวอักษร" });
        if (request.Details.Any(x => x.UrgencyLevel is < 0 or > 2 || (x.EstimatedMin.HasValue && x.EstimatedMax.HasValue && x.EstimatedMin > x.EstimatedMax))) return BadRequest(new { message = "ข้อมูลรายการไม่ถูกต้อง", description = "ตรวจสอบระดับความต้องการและช่วงราคาประมาณ" });
        if (request.Details.Any(x => !ValidReference(x.ReferenceUrl1) || !ValidReference(x.ReferenceUrl2) || !ValidReference(x.ReferenceUrl3))) return BadRequest(new { message = "ลิงก์อ้างอิงไม่ถูกต้อง", description = "กรุณาระบุลิงก์ http หรือ https ไม่เกิน 2,048 ตัวอักษร" });
        await using var db = new SqlConnection(ConnectionString); await db.OpenAsync(token);
        if (!await CompanyMenuAccess.IsAllowedAsync(db, User, "69002", "CREATE", token)) return Forbid();
        await using var tx = await db.BeginTransactionAsync(token);
        try
        {
            await using var insert = new SqlCommand("INSERT dbo.TDAPPurchaseRequest(CompanyID,RequestNo,RequestDate,RequesterUserID,DivisionID,DepartmentID,StatusCode,Remark,CreateBy,PreviousPONo,PreviousPRNo) OUTPUT INSERTED.RequestID VALUES(@company,@no,@date,@user,@division,@department,N'DRAFT',@remark,@user,@previousPo,@previousPr)", db, (SqlTransaction)tx);
            Add(insert, "@company", SqlDbType.BigInt, company); Add(insert, "@no", SqlDbType.NVarChar, string.IsNullOrWhiteSpace(request.RequestNo) ? $"PR-{DateTime.UtcNow:yyyyMMddHHmmssfff}" : request.RequestNo); Add(insert, "@date", SqlDbType.Date, DateTime.TryParse(request.RequestDate, CultureInfo.InvariantCulture, DateTimeStyles.None, out var date) ? date.Date : DateTime.UtcNow.Date); Add(insert, "@user", SqlDbType.BigInt, user); Add(insert, "@division", SqlDbType.BigInt, request.DivisionId ?? (object)DBNull.Value); Add(insert, "@department", SqlDbType.BigInt, request.DepartmentId ?? (object)DBNull.Value); Add(insert, "@remark", SqlDbType.NVarChar, request.Remark ?? (object)DBNull.Value); Add(insert,"@previousPo",SqlDbType.NVarChar,ReferenceValue(request.PreviousPoNo));Add(insert,"@previousPr",SqlDbType.NVarChar,ReferenceValue(request.PreviousPrNo)); var requestId = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            var detailIds = new List<long>(); var sort = 1;
            foreach (var item in request.Details)
            {
                await using var detail = new SqlCommand("INSERT dbo.TDAPPurchaseRequestDetail(RequestID,ItemText,Quantity,EstimatedMin,EstimatedMax,Remark,NeededDate,UrgencyLevel,SortOrder,ReferenceUrl1,ReferenceUrl2,ReferenceUrl3,PreviousPONo,PreviousPRNo) OUTPUT INSERTED.DetailID VALUES(@request,@item,@quantity,@min,@max,@remark,@needed,@urgency,@sort,@url1,@url2,@url3,@detailPo,@detailPr)", db, (SqlTransaction)tx); AddDetailParameters(detail,requestId,item,sort++); detailIds.Add(Convert.ToInt64(await detail.ExecuteScalarAsync(token)));
            }
            await tx.CommitAsync(token); return Ok(new { requestId, detailIds, statusCode = "DRAFT" });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627) { await tx.RollbackAsync(token); return Conflict(new { message = "เลขที่คำขอซ้ำ", description = "กรุณาบันทึกใหม่อีกครั้ง" }); }
        catch { await tx.RollbackAsync(token); throw; }
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id,[FromBody] PurchaseRequestWriteRequest request,CancellationToken token=default)
    {
        if (!TryScope(out var company,out var user)) return Forbid();
        if ((request.PreviousPoNo?.Length ?? 0)>100 || (request.PreviousPrNo?.Length ?? 0)>100) return BadRequest(new {message="เลขที่อ้างอิงยาวเกิน 100 ตัวอักษร"});
        if (request.Details.Any(x => (x.PreviousPoNo?.Length ?? 0)>100 || (x.PreviousPrNo?.Length ?? 0)>100)) return BadRequest(new {message="เลขที่อ้างอิงของรายการยาวเกิน 100 ตัวอักษร"});
        if (request.Details.Count==0 || request.Details.Any(x=>string.IsNullOrWhiteSpace(x.ItemText)||x.ItemText.Length>2000||x.UrgencyLevel>2||(x.EstimatedMin.HasValue&&x.EstimatedMax.HasValue&&x.EstimatedMin>x.EstimatedMax)||!ValidReference(x.ReferenceUrl1)||!ValidReference(x.ReferenceUrl2)||!ValidReference(x.ReferenceUrl3))) return BadRequest(new {message="ข้อมูลรายการไม่ถูกต้อง",description="กรุณาตรวจสอบรายการ ช่วงราคา และลิงก์อ้างอิง"});
        if (!ValidDate(request.RequestDate, false) || request.Details.Any(x => !ValidDate(x.NeededDate, true)) || !DateTime.TryParseExact(request.RequestDate,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out var date)) return BadRequest(new {message="วันที่ไม่ถูกต้อง"});
        var requestedIds=request.Details.Where(x=>x.DetailId.HasValue).Select(x=>x.DetailId!.Value).ToList();
        if(requestedIds.Any(x=>x<=0)||requestedIds.Distinct().Count()!=requestedIds.Count)return BadRequest(new {message="รายการซ้ำหรือไม่ถูกต้อง"});
        await using var db=new SqlConnection(ConnectionString);await db.OpenAsync(token);
        if(!await CompanyMenuAccess.IsAllowedAsync(db,User,"69002","EDIT",token))return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        try {
            await using var header=new SqlCommand("UPDATE dbo.TDAPPurchaseRequest SET RequestDate=@date,Remark=@remark,PreviousPONo=CASE WHEN @hasPo=1 THEN @previousPo ELSE PreviousPONo END,PreviousPRNo=CASE WHEN @hasPr=1 THEN @previousPr ELSE PreviousPRNo END,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE RequestID=@id AND CompanyID=@company AND StatusCode=N'DRAFT' AND dbo.LaooMenuDataAccessAllowed(@company,@user,RequesterUserID,N'69002',N'EDIT')=1",db,tx);
            Add(header,"@date",SqlDbType.Date,date.Date);Add(header,"@remark",SqlDbType.NVarChar,(object?)request.Remark??DBNull.Value);Add(header,"@user",SqlDbType.BigInt,user);Add(header,"@id",SqlDbType.BigInt,id);Add(header,"@company",SqlDbType.BigInt,company);
            Add(header,"@hasPo",SqlDbType.Bit,request.HasPreviousPoNo);Add(header,"@hasPr",SqlDbType.Bit,request.HasPreviousPrNo);Add(header,"@previousPo",SqlDbType.NVarChar,ReferenceValue(request.PreviousPoNo));Add(header,"@previousPr",SqlDbType.NVarChar,ReferenceValue(request.PreviousPrNo));
            if(await header.ExecuteNonQueryAsync(token)!=1){await tx.RollbackAsync(token);return Conflict(new {message="แก้ไขไม่ได้",description="ไม่พบแบบร่างในขอบเขตสิทธิ์ของคุณ"});}
            var existing=new Dictionary<long,bool>();
            await using(var read=new SqlCommand("SELECT d.DetailID,CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.TDAPPurchaseRequestAttachment a WHERE a.RequestID=d.RequestID AND a.DetailID=d.DetailID) THEN 1 ELSE 0 END) FROM dbo.TDAPPurchaseRequestDetail d WHERE d.RequestID=@id",db,tx)){
                Add(read,"@id",SqlDbType.BigInt,id);await using var r=await read.ExecuteReaderAsync(token);while(await r.ReadAsync(token))existing.Add(r.GetInt64(0),r.GetBoolean(1));
            }
            if(requestedIds.Any(x=>!existing.ContainsKey(x))){await tx.RollbackAsync(token);return BadRequest(new {message="ไม่พบรายการในใบขอนี้"});}
            var removed=existing.Where(x=>!requestedIds.Contains(x.Key)).ToList();
            var deletedFiles = new List<string>();
            var uploadRoot = Path.GetFullPath(Path.Combine(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"), "uploads", "purchasing", company.ToString(CultureInfo.InvariantCulture), id.ToString(CultureInfo.InvariantCulture))) + Path.DirectorySeparatorChar;
            foreach(var item in removed){
                await using(var paths=new SqlCommand("SELECT StoredPath FROM dbo.TDAPPurchaseRequestAttachment WHERE RequestID=@id AND DetailID=@detail",db,tx)) {
                    Add(paths,"@id",SqlDbType.BigInt,id);Add(paths,"@detail",SqlDbType.BigInt,item.Key);await using var reader=await paths.ExecuteReaderAsync(token);
                    while(await reader.ReadAsync(token)) {
                        var full=Path.GetFullPath(Path.Combine(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath,"wwwroot"),reader.GetString(0).Replace('/',Path.DirectorySeparatorChar)));
                        if(!full.StartsWith(uploadRoot,OperatingSystem.IsWindows()?StringComparison.OrdinalIgnoreCase:StringComparison.Ordinal)) { await reader.CloseAsync(); await tx.RollbackAsync(token); return Conflict(new {message="ลบรายการไม่ได้",description="ตำแหน่งไฟล์แนบไม่ถูกต้อง"}); }
                        deletedFiles.Add(full);
                    }
                }
                await using var del=new SqlCommand("DELETE dbo.TDAPPurchaseRequestAttachment WHERE RequestID=@id AND DetailID=@detail; DELETE dbo.TDAPPurchaseRequestDetail WHERE RequestID=@id AND DetailID=@detail",db,tx);Add(del,"@id",SqlDbType.BigInt,id);Add(del,"@detail",SqlDbType.BigInt,item.Key);await del.ExecuteNonQueryAsync(token);
            }
            var ids=new List<long>();var sort=1;
            foreach(var item in request.Details){
                var sql=item.DetailId.HasValue
                    ? "UPDATE dbo.TDAPPurchaseRequestDetail SET ItemText=@item,Quantity=@quantity,EstimatedMin=@min,EstimatedMax=@max,Remark=@remark,NeededDate=@needed,UrgencyLevel=@urgency,SortOrder=@sort,ReferenceUrl1=@url1,ReferenceUrl2=@url2,ReferenceUrl3=@url3,PreviousPONo=CASE WHEN @hasDetailPo=1 THEN @detailPo ELSE PreviousPONo END,PreviousPRNo=CASE WHEN @hasDetailPr=1 THEN @detailPr ELSE PreviousPRNo END OUTPUT INSERTED.DetailID WHERE RequestID=@request AND DetailID=@detail"
                    : "INSERT dbo.TDAPPurchaseRequestDetail(RequestID,ItemText,Quantity,EstimatedMin,EstimatedMax,Remark,NeededDate,UrgencyLevel,SortOrder,ReferenceUrl1,ReferenceUrl2,ReferenceUrl3,PreviousPONo,PreviousPRNo) OUTPUT INSERTED.DetailID VALUES(@request,@item,@quantity,@min,@max,@remark,@needed,@urgency,@sort,@url1,@url2,@url3,@detailPo,@detailPr)";
                await using var command=new SqlCommand(sql,db,tx);AddDetailParameters(command,id,item,sort++);if(item.DetailId.HasValue)Add(command,"@detail",SqlDbType.BigInt,item.DetailId.Value);var newId=await command.ExecuteScalarAsync(token);if(newId is null)throw new InvalidOperationException("Item update failed");ids.Add(Convert.ToInt64(newId));
            }
            await tx.CommitAsync(token);
            var cleanupFailed=false;
            foreach(var file in deletedFiles) { try { System.IO.File.Delete(file); } catch (IOException) { cleanupFailed=true; } catch (UnauthorizedAccessException) { cleanupFailed=true; } }
            return Ok(new {requestId=id,detailIds=ids,statusCode="DRAFT",attachmentCleanupFailed=cleanupFailed});
        } catch {await tx.RollbackAsync(token);throw;}
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, CancellationToken token = default)
    {
        if (!TryScope(out var company, out var user)) return Forbid();
        await using var db = new SqlConnection(ConnectionString); await db.OpenAsync(token);
        if (!await CompanyMenuAccess.IsAllowedAsync(db, User, "69002", "DELETE", token)) return Forbid();
        await using var tx = (SqlTransaction)await db.BeginTransactionAsync(token);
        try {
            await using var check = new SqlCommand("SELECT StatusCode FROM dbo.TDAPPurchaseRequest WITH (UPDLOCK,HOLDLOCK) WHERE RequestID=@id AND CompanyID=@company AND dbo.LaooMenuDataAccessAllowed(@company,@user,RequesterUserID,N'69002',N'DELETE')=1",db,tx);
            Add(check,"@id",SqlDbType.BigInt,id); Add(check,"@company",SqlDbType.BigInt,company); Add(check,"@user",SqlDbType.BigInt,user);
            var status = await check.ExecuteScalarAsync(token);
            if (status is null) { await tx.RollbackAsync(token); return NotFound(); }
            if (!string.Equals(Convert.ToString(status),"DRAFT",StringComparison.Ordinal)) { await tx.RollbackAsync(token); return Conflict(new {message="ลบได้เฉพาะแบบร่าง"}); }
            await using var attachments = new SqlCommand("SELECT COUNT_BIG(1) FROM dbo.TDAPPurchaseRequestAttachment WHERE RequestID=@id",db,tx); Add(attachments,"@id",SqlDbType.BigInt,id);
            if (Convert.ToInt64(await attachments.ExecuteScalarAsync(token)) > 0) { await tx.RollbackAsync(token); return Conflict(new {message="ลบไม่ได้",description="ใบขอนี้มีไฟล์แนบ ระบบยังไม่รองรับการลบไฟล์แนบอย่างปลอดภัย"}); }
            await using var delete = new SqlCommand("DELETE FROM dbo.TDAPPurchaseRequestDetail WHERE RequestID=@id; DELETE FROM dbo.TDAPPurchaseRequest WHERE RequestID=@id AND CompanyID=@company",db,tx);
            Add(delete,"@id",SqlDbType.BigInt,id); Add(delete,"@company",SqlDbType.BigInt,company); await delete.ExecuteNonQueryAsync(token);
            await tx.CommitAsync(token); return NoContent();
        } catch { await tx.RollbackAsync(token); throw; }
    }

    [HttpPost("{requestId:long}/details/{detailId:long}/attachments"), RequestSizeLimit(3 * 1024 * 1024)]
    public async Task<IActionResult> Upload(long requestId, long detailId, IFormFile file, CancellationToken token = default)
    {
        if (file.Length <= 0 || file.Length > 3 * 1024 * 1024) return BadRequest(new { message = "ไฟล์ไม่ถูกต้อง", description = "ไฟล์ต้องมีขนาดไม่เกิน 3 MiB" });
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant(); var allowed = new[] { ".jpg", ".jpeg", ".png", ".webp", ".pdf", ".doc", ".docx", ".xls", ".xlsx" }; if (!allowed.Contains(ext)) return BadRequest(new { message = "ชนิดไฟล์ไม่รองรับ", description = "รองรับรูปภาพและเอกสารสำนักงาน" });
        if (!TryScope(out var company, out var user)) return Forbid();
        await using var db = new SqlConnection(ConnectionString); await db.OpenAsync(token);
        var canCreate = await CompanyMenuAccess.IsAllowedAsync(db, User, "69002", "CREATE", token);
        var canEdit = await CompanyMenuAccess.IsAllowedAsync(db, User, "69002", "EDIT", token);
        if (!canCreate && !canEdit) return Forbid();
        await using var tx = await db.BeginTransactionAsync(token);
        await using var check = new SqlCommand("SELECT COUNT(1) FROM dbo.TDAPPurchaseRequestDetail d JOIN dbo.TDAPPurchaseRequest h WITH (UPDLOCK,HOLDLOCK) ON h.RequestID=d.RequestID WHERE h.CompanyID=@company AND d.RequestID=@request AND d.DetailID=@detail AND h.StatusCode=N'DRAFT' AND ((@canEdit=1 AND dbo.LaooMenuDataAccessAllowed(@company,@user,h.RequesterUserID,N'69002',N'EDIT')=1) OR (@canCreate=1 AND h.CreateBy=@user AND h.RequesterUserID=@user))", db, (SqlTransaction)tx); Add(check, "@company", SqlDbType.BigInt, company); Add(check, "@user", SqlDbType.BigInt, user); Add(check, "@request", SqlDbType.BigInt, requestId); Add(check, "@detail", SqlDbType.BigInt, detailId); Add(check,"@canEdit",SqlDbType.Bit,canEdit); Add(check,"@canCreate",SqlDbType.Bit,canCreate); if (Convert.ToInt32(await check.ExecuteScalarAsync(token)) != 1) return NotFound();
        var stored = $"{Guid.NewGuid():N}{ext}"; var relative = Path.Combine("uploads", "purchasing", company.ToString(CultureInfo.InvariantCulture), requestId.ToString(CultureInfo.InvariantCulture), detailId.ToString(CultureInfo.InvariantCulture), stored); var full = Path.Combine(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"), relative); Directory.CreateDirectory(Path.GetDirectoryName(full)!); await using (var output = System.IO.File.Create(full)) await file.CopyToAsync(output, token);
        await using var insert = new SqlCommand("INSERT dbo.TDAPPurchaseRequestAttachment(RequestID,DetailID,FileName,StoredPath,ContentType,FileSize,CreateBy) OUTPUT INSERTED.AttachmentID VALUES(@request,@detail,@name,@path,@type,@size,@user)", db, (SqlTransaction)tx); Add(insert, "@request", SqlDbType.BigInt, requestId); Add(insert, "@detail", SqlDbType.BigInt, detailId); Add(insert, "@name", SqlDbType.NVarChar, Path.GetFileName(file.FileName)); Add(insert, "@path", SqlDbType.NVarChar, relative.Replace('\\', '/')); Add(insert, "@type", SqlDbType.NVarChar, file.ContentType ?? "application/octet-stream"); Add(insert, "@size", SqlDbType.BigInt, file.Length); Add(insert, "@user", SqlDbType.BigInt, user); var id = Convert.ToInt64(await insert.ExecuteScalarAsync(token)); await tx.CommitAsync(token); return Ok(new { attachmentId = id, fileName = Path.GetFileName(file.FileName), url = $"/api/purchasing/requests/{requestId}/attachments/{id}" });
    }

    [HttpGet("{requestId:long}/attachments/{attachmentId:long}")]
    public async Task<IActionResult> ReadAttachment(long requestId, long attachmentId, CancellationToken token = default)
    {
        if (!TryScope(out var company, out var user)) return Forbid();
        await using var db = new SqlConnection(ConnectionString); await db.OpenAsync(token);
        if (!await CompanyMenuAccess.IsAllowedAsync(db, User, "69002", "VIEW", token)) return Forbid();
        await using var cmd = new SqlCommand("SELECT a.StoredPath,a.FileName,a.ContentType FROM dbo.TDAPPurchaseRequestAttachment a JOIN dbo.TDAPPurchaseRequest h ON h.RequestID=a.RequestID WHERE h.CompanyID=@company AND h.RequestID=@request AND a.AttachmentID=@attachment AND dbo.LaooMenuDataAccessAllowed(@company,@user,h.RequesterUserID,N'69002',N'VIEW')=1", db);
        Add(cmd,"@company",SqlDbType.BigInt,company); Add(cmd,"@user",SqlDbType.BigInt,user); Add(cmd,"@request",SqlDbType.BigInt,requestId); Add(cmd,"@attachment",SqlDbType.BigInt,attachmentId);
        await using var reader=await cmd.ExecuteReaderAsync(token); if(!await reader.ReadAsync(token))return NotFound();
        var path=SafeAttachmentPath(company,requestId,reader.GetString(0)); var name=reader.GetString(1);var type=reader.GetString(2);
        if(path is null || !System.IO.File.Exists(path))return NotFound();
        var bytes=await System.IO.File.ReadAllBytesAsync(path,token); return Ok(new {name,contentType=type,base64=Convert.ToBase64String(bytes)});
    }

    [HttpDelete("{requestId:long}/attachments/{attachmentId:long}")]
    public async Task<IActionResult> DeleteAttachment(long requestId, long attachmentId, CancellationToken token = default)
    {
        if (!TryScope(out var company, out var user)) return Forbid();
        await using var db=new SqlConnection(ConnectionString); await db.OpenAsync(token);
        if (!await CompanyMenuAccess.IsAllowedAsync(db,User,"69002","EDIT",token)) return Forbid();
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        try {
            await using var select=new SqlCommand("SELECT a.StoredPath FROM dbo.TDAPPurchaseRequestAttachment a JOIN dbo.TDAPPurchaseRequest h WITH (UPDLOCK,HOLDLOCK) ON h.RequestID=a.RequestID WHERE h.CompanyID=@company AND h.RequestID=@request AND h.StatusCode=N'DRAFT' AND a.AttachmentID=@attachment AND dbo.LaooMenuDataAccessAllowed(@company,@user,h.RequesterUserID,N'69002',N'EDIT')=1",db,tx);
            Add(select,"@company",SqlDbType.BigInt,company); Add(select,"@user",SqlDbType.BigInt,user); Add(select,"@request",SqlDbType.BigInt,requestId); Add(select,"@attachment",SqlDbType.BigInt,attachmentId);
            var stored=await select.ExecuteScalarAsync(token) as string; if(stored is null){await tx.RollbackAsync(token);return NotFound();}
            var path=SafeAttachmentPath(company,requestId,stored); if(path is null){await tx.RollbackAsync(token);return Conflict(new {message="ตำแหน่งไฟล์แนบไม่ถูกต้อง"});}
            await using var delete=new SqlCommand("DELETE dbo.TDAPPurchaseRequestAttachment WHERE RequestID=@request AND AttachmentID=@attachment",db,tx);Add(delete,"@request",SqlDbType.BigInt,requestId);Add(delete,"@attachment",SqlDbType.BigInt,attachmentId);await delete.ExecuteNonQueryAsync(token);
            await tx.CommitAsync(token);var cleanupFailed=false;try{System.IO.File.Delete(path);}catch(IOException){cleanupFailed=true;}catch(UnauthorizedAccessException){cleanupFailed=true;}return Ok(new {attachmentCleanupFailed=cleanupFailed});
        } catch { await tx.RollbackAsync(token); throw; }
    }

    private string? SafeAttachmentPath(long company,long requestId,string stored)
    {
        var webRoot=environment.WebRootPath ?? Path.Combine(environment.ContentRootPath,"wwwroot");
        var root=Path.GetFullPath(Path.Combine(webRoot,"uploads","purchasing",company.ToString(CultureInfo.InvariantCulture),requestId.ToString(CultureInfo.InvariantCulture)))+Path.DirectorySeparatorChar;
        var full=Path.GetFullPath(Path.Combine(webRoot,stored.Replace('/',Path.DirectorySeparatorChar)));
        return full.StartsWith(root,OperatingSystem.IsWindows()?StringComparison.OrdinalIgnoreCase:StringComparison.Ordinal)?full:null;
    }

    private bool TryScope(out long company, out long user)
    {
        company = 0; user = 0;
        return User.FindFirst("user_type")?.Value == "COMPANY_USER"
            && long.TryParse(User.FindFirst("company_id")?.Value, out company) && company > 0
            && long.TryParse(User.FindFirst("user_id")?.Value, out user) && user > 0;
    }
    private static void Add(SqlCommand command, string name, SqlDbType type, object value) { var p = command.Parameters.Add(name, type); p.Value = value; }
    private static object ReferenceValue(string? value) => string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim();
    private static bool ValidDate(string? value, bool optional) => string.IsNullOrWhiteSpace(value) ? optional : DateTime.TryParseExact(value,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out var date) && date.Year is >= 1900 and <= 2100;
    private static bool ValidReference(string? value) => string.IsNullOrWhiteSpace(value) || (value.Trim().Length <= 2048 && Uri.TryCreate(value.Trim(),UriKind.Absolute,out var uri) && !string.IsNullOrEmpty(uri.Host) && (uri.Scheme==Uri.UriSchemeHttp || uri.Scheme==Uri.UriSchemeHttps));
    private static void AddDetailParameters(SqlCommand detail,long requestId,PurchaseRequestDetailWriteRequest item,int sort) {
        Add(detail,"@request",SqlDbType.BigInt,requestId);Add(detail,"@item",SqlDbType.NVarChar,item.ItemText.Trim());Add(detail,"@quantity",SqlDbType.Decimal,item.Quantity??(object)DBNull.Value);Add(detail,"@min",SqlDbType.Decimal,item.EstimatedMin??(object)DBNull.Value);Add(detail,"@max",SqlDbType.Decimal,item.EstimatedMax??(object)DBNull.Value);Add(detail,"@remark",SqlDbType.NVarChar,item.Remark??(object)DBNull.Value);Add(detail,"@needed",SqlDbType.Date,DateTime.TryParse(item.NeededDate,CultureInfo.InvariantCulture,DateTimeStyles.None,out var needed)?needed.Date:DBNull.Value);Add(detail,"@urgency",SqlDbType.TinyInt,item.UrgencyLevel);Add(detail,"@sort",SqlDbType.Int,sort);
        Add(detail,"@url1",SqlDbType.NVarChar,string.IsNullOrWhiteSpace(item.ReferenceUrl1)?DBNull.Value:item.ReferenceUrl1.Trim());Add(detail,"@url2",SqlDbType.NVarChar,string.IsNullOrWhiteSpace(item.ReferenceUrl2)?DBNull.Value:item.ReferenceUrl2.Trim());Add(detail,"@url3",SqlDbType.NVarChar,string.IsNullOrWhiteSpace(item.ReferenceUrl3)?DBNull.Value:item.ReferenceUrl3.Trim());
        Add(detail,"@detailPo",SqlDbType.NVarChar,ReferenceValue(item.PreviousPoNo));Add(detail,"@detailPr",SqlDbType.NVarChar,ReferenceValue(item.PreviousPrNo));Add(detail,"@hasDetailPo",SqlDbType.Bit,item.HasPreviousPoNo);Add(detail,"@hasDetailPr",SqlDbType.Bit,item.HasPreviousPrNo);
    }
}

public sealed class PurchaseRequestWriteRequest
{
    private string? _previousPoNo, _previousPrNo;
    [JsonIgnore] public bool HasPreviousPoNo { get; private set; }
    [JsonIgnore] public bool HasPreviousPrNo { get; private set; }
    public string? PreviousPoNo { get => _previousPoNo; set { _previousPoNo=value; HasPreviousPoNo=true; } }
    public string? PreviousPrNo { get => _previousPrNo; set { _previousPrNo=value; HasPreviousPrNo=true; } }
    public string? RequestNo { get; init; }
    public string? RequestDate { get; init; }
    public long? DivisionId { get; init; }
    public long? DepartmentId { get; init; }
    public string? Remark { get; init; }
    public List<PurchaseRequestDetailWriteRequest> Details { get; init; } = [];
}
public sealed class PurchaseRequestDetailWriteRequest
{
    private string? _previousPoNo, _previousPrNo;
    [JsonIgnore] public bool HasPreviousPoNo { get; private set; }
    [JsonIgnore] public bool HasPreviousPrNo { get; private set; }
    public string? PreviousPoNo { get => _previousPoNo; set { _previousPoNo=value; HasPreviousPoNo=true; } }
    public string? PreviousPrNo { get => _previousPrNo; set { _previousPrNo=value; HasPreviousPrNo=true; } }
    public long? DetailId { get; init; }
    public string ItemText { get; init; } = string.Empty;
    public decimal? Quantity { get; init; }
    public decimal? EstimatedMin { get; init; }
    public decimal? EstimatedMax { get; init; }
    public string? Remark { get; init; }
    public string? NeededDate { get; init; }
    public byte UrgencyLevel { get; init; }
    public string? ReferenceUrl1 { get; init; }
    public string? ReferenceUrl2 { get; init; }
    public string? ReferenceUrl3 { get; init; }
}
