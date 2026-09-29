using System.Data;
using System.Security.Claims;
using LaooApi.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/service/complaints")]
public sealed class ServiceComplaintController(IConfiguration configuration, IWebHostEnvironment environment) : ControllerBase
{
    private const string Menu = "20006";
    private const long MaxAttachmentBytes = 5_000_000;
    private long CompanyId => ClaimLong("company_id");
    private long UserId => ClaimLong("user_id");
    private long? PersonId => ClaimLongNullable("person_id");

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await Allowed(c, "VIEW", token)) return Forbid();
        var screenType = await ScreenType(c, token);
        return Ok(new { screenType, view = true, create = screenType == 1 && await Allowed(c, "CREATE", token), edit = screenType == 1 && await Allowed(c, "EDIT", token), delete = screenType == 1 && await Allowed(c, "DELETE", token) });
    }

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? status, [FromQuery] bool self = true, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken token = default)
    {
        await using var c = await Open(token);
        if (!await InService(c, token)) return Forbid();
        if (!await Allowed(c, "VIEW", token) || (!self && !await Allowed(c, "EDIT", token))) return Forbid();
        page = Math.Max(1, page); pageSize = Math.Clamp(pageSize, 1, 100);
        const string sql = """
SELECT COUNT_BIG(1) OVER(),ComplaintID,ComplaintNo,ComplainantNameSnapshot,LocationSnapshot,Subject,StatusCode,RequestDate,StartedDate,CompletedDate
FROM dbo.TDADServiceComplaint
WHERE CompanyID=@company AND IsActive=1 AND (@self=0 OR CreateBy=@user)
  AND (@status IN(N'',N'ALL') OR StatusCode=@status)
  AND (@q=N'' OR ComplaintNo LIKE N'%'+@q+N'%' OR ComplainantNameSnapshot LIKE N'%'+@q+N'%' OR Subject LIKE N'%'+@q+N'%')
ORDER BY RequestDate DESC,ComplaintID DESC OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY;
""";
        await using var q = new SqlCommand(sql, c); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@self",SqlDbType.Bit,self); Add(q,"@user",SqlDbType.BigInt,UserId); Add(q,"@status",SqlDbType.NVarChar,status?.Trim().ToUpperInvariant() ?? string.Empty,30); Add(q,"@q",SqlDbType.NVarChar,search?.Trim() ?? string.Empty,200); Add(q,"@offset",SqlDbType.Int,(page-1)*pageSize); Add(q,"@take",SqlDbType.Int,pageSize);
        var items = new List<object>(); long total = 0; await using var r = await q.ExecuteReaderAsync(token);
        while (await r.ReadAsync(token)) { total=r.GetInt64(0); items.Add(new { complaintId=r.GetInt64(1), complaintNo=r.GetString(2), complainantName=r.GetString(3), locationSnapshot=Text(r,4), subject=r.GetString(5), statusCode=r.GetString(6), requestDate=r.GetDateTime(7), startedDate=Date(r,8), completedDate=Date(r,9) }); }
        return Ok(new { items,total,page,pageSize });
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Detail(long id, CancellationToken token)
    {
        await using var c = await Open(token); if (!await InService(c, token)) return Forbid();
        var access = await Access(c,id,token); if (!access.Found) return NotFound(new { message="ไม่พบเรื่องร้องเรียน",description="ไม่พบข้อมูลใน Company ปัจจุบัน" });
        if (!await CanRead(c,access,token)) return Forbid();
        const string sql = "SELECT ComplaintID,ComplaintNo,ComplainantNameSnapshot,ComplainantPhoneSnapshot,ComplainantEmailSnapshot,LocationSnapshot,Subject,Detail,StatusCode,RequestDate,StartedDate,CompletedDate,ResolutionDetail,CancellationReason,RowVersion FROM dbo.TDADServiceComplaint WHERE CompanyID=@company AND ComplaintID=@id AND IsActive=1";
        await using var q=new SqlCommand(sql,c); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id); await using var r=await q.ExecuteReaderAsync(token); if(!await r.ReadAsync(token)) return NotFound();
        return Ok(new { complaintId=r.GetInt64(0),complaintNo=r.GetString(1),complainantName=r.GetString(2),complainantPhone=Text(r,3),complainantEmail=Text(r,4),locationSnapshot=Text(r,5),subject=r.GetString(6),detail=r.GetString(7),statusCode=r.GetString(8),requestDate=r.GetDateTime(9),startedDate=Date(r,10),completedDate=Date(r,11),resolutionDetail=Text(r,12),cancellationReason=Text(r,13),rowVersion=Convert.ToBase64String((byte[])r[14]) });
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateComplaintRequest request, CancellationToken token)
    {
        await using var c=await Open(token); if(!await IsCrud(c,token) || !await Allowed(c,"CREATE",token)) return Forbid();
        if(string.IsNullOrWhiteSpace(request.Subject) || string.IsNullOrWhiteSpace(request.Detail)) return BadRequest(new { message="กรุณาระบุหัวข้อและรายละเอียด",description="หัวข้อและรายละเอียดเป็นข้อมูลบังคับ" });
        if(PersonId is null) return BadRequest(new { message="ไม่พบข้อมูลผู้ร้อง",description="บัญชีผู้ใช้นี้ไม่ผูกกับทะเบียนบุคคลใน Company ปัจจุบัน" });
        var person=await Person(c,token); if(person is null) return BadRequest(new { message="ข้อมูลผู้ร้องไม่ถูกต้อง",description="ไม่พบทะเบียนบุคคลที่ Active ใน Company ปัจจุบัน" });
        await using var tx=(SqlTransaction)await c.BeginTransactionAsync(token);
        try
        {
            const string next = "SELECT N'CP'+CONVERT(nvarchar(8),CONVERT(date,SYSUTCDATETIME()),112)+RIGHT(N'000000'+CONVERT(nvarchar(6),ISNULL(MAX(TRY_CONVERT(int,RIGHT(ComplaintNo,6))),0)+1),6) FROM dbo.TDADServiceComplaint WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND ComplaintNo LIKE N'CP'+CONVERT(nvarchar(8),CONVERT(date,SYSUTCDATETIME()),112)+N'%';";
            await using var n=new SqlCommand(next,c,tx); Add(n,"@company",SqlDbType.BigInt,CompanyId); var no=Convert.ToString(await n.ExecuteScalarAsync(token))!;
            const string insert="""INSERT dbo.TDADServiceComplaint(CompanyID,ComplaintNo,ComplainantPersonID,ComplainantNameSnapshot,ComplainantPhoneSnapshot,ComplainantEmailSnapshot,LocationSnapshot,Subject,Detail,CreateBy) OUTPUT INSERTED.ComplaintID VALUES(@company,@no,@person,@name,@phone,@email,@location,@subject,@detail,@user);""";
            await using var q=new SqlCommand(insert,c,tx); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@no",SqlDbType.NVarChar,no,30); Add(q,"@person",SqlDbType.BigInt,PersonId); Add(q,"@name",SqlDbType.NVarChar,person.Name,200); Add(q,"@phone",SqlDbType.NVarChar,person.Phone,50); Add(q,"@email",SqlDbType.NVarChar,person.Email,320); Add(q,"@location",SqlDbType.NVarChar,person.Location,500); Add(q,"@subject",SqlDbType.NVarChar,request.Subject.Trim(),200); Add(q,"@detail",SqlDbType.NVarChar,request.Detail.Trim(),2000); Add(q,"@user",SqlDbType.BigInt,UserId);
            var id=Convert.ToInt64(await q.ExecuteScalarAsync(token)); await tx.CommitAsync(token); return Ok(new { complaintId=id,complaintNo=no,statusCode="NEW" });
        }
        catch(SqlException ex) when(ex.Number is 2601 or 2627) { await tx.RollbackAsync(token); return Conflict(new { message="บันทึกเรื่องร้องเรียนไม่สำเร็จ",description="เลขที่เรื่องร้องเรียนซ้ำ กรุณาลองใหม่" }); }
        catch { await tx.RollbackAsync(token); throw; }
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Edit(long id, EditComplaintRequest request, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await IsCrud(c,token) || !await Allowed(c,"EDIT",token)) return Forbid();
        if (string.IsNullOrWhiteSpace(request.Subject) || request.Subject.Trim().Length > 200 ||
            string.IsNullOrWhiteSpace(request.Detail) || request.Detail.Trim().Length > 2000 ||
            string.IsNullOrWhiteSpace(request.RowVersion)) return BadRequest(new { message = "ข้อมูลเรื่องร้องเรียนไม่ครบหรือยาวเกินกำหนด" });
        byte[] version;
        try { version = Convert.FromBase64String(request.RowVersion); }
        catch (FormatException) { return BadRequest(new { message = "ข้อมูลเวอร์ชันไม่ถูกต้อง" }); }
        if (version.Length != 8) return BadRequest(new { message = "ข้อมูลเวอร์ชันไม่ถูกต้อง" });
        await using var q = new SqlCommand("""
UPDATE dbo.TDADServiceComplaint
SET Subject=@subject,Detail=@detail,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user
WHERE CompanyID=@company AND ComplaintID=@id AND IsActive=1
  AND StatusCode=N'NEW' AND RowVersion=@version;
""",c);
        Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id);
        Add(q,"@subject",SqlDbType.NVarChar,request.Subject.Trim(),200);
        Add(q,"@detail",SqlDbType.NVarChar,request.Detail.Trim(),2000);
        Add(q,"@user",SqlDbType.BigInt,UserId); Add(q,"@version",SqlDbType.Binary,version,8);
        if (await q.ExecuteNonQueryAsync(token) == 0) return Conflict(new { message = "แก้ไขไม่ได้", description = "รายการอาจไม่ใช่สถานะรอรับเรื่อง หรือข้อมูลถูกเปลี่ยนไปแล้ว" });
        return Ok(new { complaintId=id,updated=true });
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, [FromQuery] string? rowVersion, CancellationToken token)
    {
        await using var c = await Open(token);
        if (!await IsCrud(c,token) || !await Allowed(c,"DELETE",token)) return Forbid();
        byte[] version;
        try { version = Convert.FromBase64String(rowVersion ?? string.Empty); }
        catch (FormatException) { return BadRequest(new { message = "ข้อมูลเวอร์ชันไม่ถูกต้อง" }); }
        if (version.Length != 8) return BadRequest(new { message = "ข้อมูลเวอร์ชันไม่ถูกต้อง" });
        var files = new List<string>();
        await using var tx = (SqlTransaction)await c.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try
        {
            await using (var current = new SqlCommand("""
SELECT StatusCode FROM dbo.TDADServiceComplaint WITH(UPDLOCK,HOLDLOCK)
WHERE CompanyID=@company AND ComplaintID=@id AND IsActive=1 AND RowVersion=@version;
""",c,tx))
            {
                Add(current,"@company",SqlDbType.BigInt,CompanyId); Add(current,"@id",SqlDbType.BigInt,id); Add(current,"@version",SqlDbType.Binary,version,8);
                var status=Convert.ToString(await current.ExecuteScalarAsync(token));
                if(status is null) { await tx.RollbackAsync(token); return Conflict(new { message = "รายการถูกแก้ไขหรือลบไปแล้ว", description = "กรุณาโหลดข้อมูลใหม่ก่อนลบ" }); }
                if(status!="NEW") { await tx.RollbackAsync(token); return Conflict(new { message = "ลบได้เฉพาะเรื่องร้องเรียนที่ยังไม่เริ่มดำเนินงาน", description = "รายการที่เริ่มดำเนินงานหรือปิดแล้วไม่สามารถลบได้" }); }
            }
            await using (var paths = new SqlCommand("SELECT StoredPath FROM dbo.TDADServiceComplaintAttachment WHERE CompanyID=@company AND ComplaintID=@id",c,tx))
            {
                Add(paths,"@company",SqlDbType.BigInt,CompanyId); Add(paths,"@id",SqlDbType.BigInt,id);
                await using var r=await paths.ExecuteReaderAsync(token);
                while(await r.ReadAsync(token)) if(!r.IsDBNull(0)) files.Add(r.GetString(0));
            }
            await using (var children=new SqlCommand("DELETE FROM dbo.TDADServiceComplaintAttachment WHERE CompanyID=@company AND ComplaintID=@id",c,tx))
            {
                Add(children,"@company",SqlDbType.BigInt,CompanyId); Add(children,"@id",SqlDbType.BigInt,id);
                await children.ExecuteNonQueryAsync(token);
            }
            await using (var parent=new SqlCommand("DELETE FROM dbo.TDADServiceComplaint WHERE CompanyID=@company AND ComplaintID=@id AND IsActive=1 AND StatusCode=N'NEW' AND RowVersion=@version",c,tx))
            {
                Add(parent,"@company",SqlDbType.BigInt,CompanyId); Add(parent,"@id",SqlDbType.BigInt,id); Add(parent,"@version",SqlDbType.Binary,version,8);
                if(await parent.ExecuteNonQueryAsync(token)!=1) throw new DBConcurrencyException();
            }
            await tx.CommitAsync(token);
        }
        catch (DBConcurrencyException)
        {
            await tx.RollbackAsync(token);
            return Conflict(new { message = "รายการถูกแก้ไขไปแล้ว", description = "กรุณาโหลดข้อมูลใหม่ก่อนลบ" });
        }
        foreach(var path in files) TryDelete(path);
        return NoContent();
    }

    [HttpPost("{id:long}/start")]
    public Task<IActionResult> Start(long id,CancellationToken token) => Change(id,"NEW","IN_PROGRESS",null,token);
    [HttpPost("{id:long}/complete")]
    public Task<IActionResult> Complete(long id,CompleteComplaintRequest request,CancellationToken token) => Change(id,"IN_PROGRESS","COMPLETED",request.ResolutionDetail,token);
    [HttpPost("{id:long}/cancel")]
    public Task<IActionResult> Cancel(long id,CancelComplaintRequest request,CancellationToken token) => Change(id,"OPEN","CANCELLED",request.CancellationReason,token);

    private async Task<IActionResult> Change(long id,string required,string target,string? note,CancellationToken token)
    {
        await using var c=await Open(token); if(!await IsCrud(c,token) || !await Allowed(c,"EDIT",token)) return Forbid();
        if(target is "COMPLETED" or "CANCELLED" && string.IsNullOrWhiteSpace(note)) return BadRequest(new { message=target=="COMPLETED"?"กรุณาระบุผลการดำเนินการ":"กรุณาระบุเหตุผลการยกเลิก",description="ข้อมูลนี้เป็นข้อมูลบังคับ" });
        var statuses=required=="OPEN" ? new[]{"NEW","IN_PROGRESS"} : new[]{required};
        var sql=target switch { "IN_PROGRESS"=>"UPDATE dbo.TDADServiceComplaint SET StatusCode=N'IN_PROGRESS',StartedDate=SYSUTCDATETIME(),StartedBy=@user,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND ComplaintID=@id AND IsActive=1 AND StatusCode=N'NEW'", "COMPLETED"=>"UPDATE dbo.TDADServiceComplaint SET StatusCode=N'COMPLETED',CompletedDate=SYSUTCDATETIME(),CompletedBy=@user,ResolutionDetail=@note,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND ComplaintID=@id AND IsActive=1 AND StatusCode=N'IN_PROGRESS'", _=>"UPDATE dbo.TDADServiceComplaint SET StatusCode=N'CANCELLED',CancelledDate=SYSUTCDATETIME(),CancelledBy=@user,CancellationReason=@note,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND ComplaintID=@id AND IsActive=1 AND StatusCode IN(N'NEW',N'IN_PROGRESS')" };
        await using var q=new SqlCommand(sql,c); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id); Add(q,"@user",SqlDbType.BigInt,UserId); Add(q,"@note",SqlDbType.NVarChar,note?.Trim(),2000); if(await q.ExecuteNonQueryAsync(token)==0) return Conflict(new { message="ไม่สามารถเปลี่ยนสถานะได้",description="ข้อมูลอาจถูกแก้ไขหรือเปลี่ยนสถานะโดยผู้ใช้อื่นแล้ว กรุณาโหลดข้อมูลใหม่" }); return Ok(new { complaintId=id,statusCode=target });
    }

    [HttpGet("{id:long}/attachments")]
    public async Task<IActionResult> Attachments(long id,CancellationToken token)
    {
        await using var c=await Open(token); if(!await InService(c,token)) return Forbid(); var access=await Access(c,id,token); if(!access.Found) return NotFound(); if(!await CanRead(c,access,token)) return Forbid();
        const string sql="SELECT ComplaintAttachmentID,FileName,ContentType,FileSize,ImageWidth,ImageHeight,CreateDate FROM dbo.TDADServiceComplaintAttachment WHERE CompanyID=@company AND ComplaintID=@id AND IsActive=1 ORDER BY CreateDate,ComplaintAttachmentID";
        await using var q=new SqlCommand(sql,c); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id); var items=new List<object>(); await using var r=await q.ExecuteReaderAsync(token); while(await r.ReadAsync(token)) items.Add(new { attachmentId=r.GetInt64(0),complaintId=id,fileName=r.GetString(1),contentType=r.GetString(2),fileSize=r.GetInt64(3),imageWidth=Int(r,4),imageHeight=Int(r,5),createDate=r.GetDateTime(6),url=$"/api/service/complaints/{id}/attachments/{r.GetInt64(0)}" }); return Ok(new { items });
    }

    [HttpGet("{id:long}/attachments/{attachmentId:long}")]
    public async Task<IActionResult> Attachment(long id,long attachmentId,CancellationToken token)
    {
        await using var c=await Open(token); if(!await InService(c,token)) return Forbid(); var access=await Access(c,id,token); if(!access.Found) return NotFound(); if(!await CanRead(c,access,token)) return Forbid();
        await using var q=new SqlCommand("SELECT FileName,StoredPath,ContentType FROM dbo.TDADServiceComplaintAttachment WHERE CompanyID=@company AND ComplaintID=@id AND ComplaintAttachmentID=@attachment AND IsActive=1",c); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id); Add(q,"@attachment",SqlDbType.BigInt,attachmentId); await using var r=await q.ExecuteReaderAsync(token); if(!await r.ReadAsync(token)) return NotFound(); var path=SafePath(r.GetString(1)); if(path is null || !System.IO.File.Exists(path)) return NotFound(); return PhysicalFile(path,r.GetString(2),r.GetString(0),enableRangeProcessing:true);
    }

    [HttpPost("{id:long}/attachments"),RequestSizeLimit(MaxAttachmentBytes)]
    public async Task<IActionResult> Upload(long id,IFormFile? file,CancellationToken token)
    {
        await using var c=await Open(token); if(!await IsCrud(c,token)) return Forbid(); var access=await Access(c,id,token); if(!access.Found) return NotFound(); if(access.Status is "COMPLETED" or "CANCELLED") return Conflict(new { message="ไม่สามารถเพิ่มรูปได้",description="เรื่องร้องเรียนปิดแล้ว" });
        var canOwner=access.CreatedBy==UserId && await Allowed(c,"CREATE",token); if(!canOwner && !await Allowed(c,"EDIT",token)) return Forbid(); if(file is null || file.Length==0) return BadRequest(new { message="กรุณาเลือกไฟล์รูปภาพ",description="รองรับ JPG, PNG และ WEBP" }); if(file.Length>MaxAttachmentBytes) return BadRequest(new { message="ไฟล์ใหญ่เกินกำหนด",description="รองรับรูปภาพไม่เกิน 5 MB ต่อไฟล์" });
        var ext=Path.GetExtension(file.FileName).ToLowerInvariant(); var type=(file.ContentType??string.Empty).ToLowerInvariant(); if(type is not ("image/jpeg" or "image/png" or "image/webp") && ext is not (".jpg" or ".jpeg" or ".png" or ".webp")) return BadRequest(new { message="ชนิดไฟล์ไม่ถูกต้อง",description="รองรับเฉพาะ JPG, PNG และ WEBP" });
        await using var ms=new MemoryStream(); await file.CopyToAsync(ms,token); await using var tx=(SqlTransaction)await c.BeginTransactionAsync(token); string? relative=null;
        try { const string insert="INSERT dbo.TDADServiceComplaintAttachment(CompanyID,ComplaintID,FileName,StoredPath,ContentType,FileSize,CreateBy) OUTPUT INSERTED.ComplaintAttachmentID VALUES(@company,@id,@name,N'',@type,@size,@user)"; await using var q=new SqlCommand(insert,c,tx); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id); Add(q,"@name",SqlDbType.NVarChar,SafeName(file.FileName),255); Add(q,"@type",SqlDbType.NVarChar,type.Length==0?"image/jpeg":type,100); Add(q,"@size",SqlDbType.BigInt,ms.Length); Add(q,"@user",SqlDbType.BigInt,UserId); var attachmentId=Convert.ToInt64(await q.ExecuteScalarAsync(token)); relative=$"uploads/service-complaints/{CompanyId}/{id}/{attachmentId}{(ext.Length==0?".jpg":ext)}"; var full=SafePath(relative)??throw new InvalidOperationException(); Directory.CreateDirectory(Path.GetDirectoryName(full)!); await System.IO.File.WriteAllBytesAsync(full,ms.ToArray(),token); await using var u=new SqlCommand("UPDATE dbo.TDADServiceComplaintAttachment SET StoredPath=@path,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE CompanyID=@company AND ComplaintAttachmentID=@attachment",c,tx); Add(u,"@path",SqlDbType.NVarChar,relative,500); Add(u,"@user",SqlDbType.BigInt,UserId); Add(u,"@company",SqlDbType.BigInt,CompanyId); Add(u,"@attachment",SqlDbType.BigInt,attachmentId); await u.ExecuteNonQueryAsync(token); await tx.CommitAsync(token); return Ok(new { attachmentId,complaintId=id,fileName=SafeName(file.FileName),contentType=type,fileSize=ms.Length,url=$"/api/service/complaints/{id}/attachments/{attachmentId}" }); } catch { await tx.RollbackAsync(token); if(relative is not null) TryDelete(relative); throw; }
    }

    [HttpDelete("{id:long}/attachments/{attachmentId:long}")]
    public async Task<IActionResult> DeleteAttachment(long id,long attachmentId,CancellationToken token)
    {
        await using var c=await Open(token); if(!await IsCrud(c,token) || !await Allowed(c,"DELETE",token)) return Forbid(); var access=await Access(c,id,token); if(!access.Found) return NotFound(); if(access.Status is "COMPLETED" or "CANCELLED") return Conflict(new { message="ไม่สามารถลบรูปได้",description="เรื่องร้องเรียนปิดแล้ว" }); await using var q=new SqlCommand("SELECT StoredPath FROM dbo.TDADServiceComplaintAttachment WHERE CompanyID=@company AND ComplaintID=@id AND ComplaintAttachmentID=@attachment AND IsActive=1",c); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id); Add(q,"@attachment",SqlDbType.BigInt,attachmentId); var path=Convert.ToString(await q.ExecuteScalarAsync(token)); if(string.IsNullOrWhiteSpace(path)) return NotFound(); await using var u=new SqlCommand("DELETE FROM dbo.TDADServiceComplaintAttachment WHERE CompanyID=@company AND ComplaintID=@id AND ComplaintAttachmentID=@attachment",c); Add(u,"@company",SqlDbType.BigInt,CompanyId); Add(u,"@id",SqlDbType.BigInt,id); Add(u,"@attachment",SqlDbType.BigInt,attachmentId); await u.ExecuteNonQueryAsync(token); TryDelete(path); return Ok(new { attachmentId,deleted=true });
    }

    private async Task<PersonInfo?> Person(SqlConnection c,CancellationToken token)
    {
        const string sql="""SELECT P.FullName,P.Mobile,P.Email,COALESCE((SELECT TOP(1) CONCAT(B.BuildingNameTH,N' / ',F.FloorNameTH,N' / ',RM.RoomCode) FROM dbo.TDADResident R JOIN dbo.TDADRoom RM ON RM.CompanyID=R.CompanyID AND RM.RoomID=R.RoomID JOIN dbo.TDADBuilding B ON B.CompanyID=RM.CompanyID AND B.BuildingID=RM.BuildingID JOIN dbo.TDADFloor F ON F.BuildingID=RM.BuildingID AND F.FloorID=RM.FloorID WHERE R.CompanyID=P.CompanyID AND R.PersonID=P.PersonID AND R.IsActive=1),(SELECT TOP(1) CONCAT(L.LaneName,N' / ',H.HouseNo) FROM dbo.TDADResident R JOIN dbo.TDADVillageHouse H ON H.CompanyID=R.CompanyID AND H.HouseID=R.HouseID JOIN dbo.TDADVillageLane L ON L.CompanyID=H.CompanyID AND L.LaneID=H.LaneID WHERE R.CompanyID=P.CompanyID AND R.PersonID=P.PersonID AND R.IsActive=1)) FROM dbo.TDADPerson P WHERE P.CompanyID=@company AND P.PersonID=@person AND P.IsActive=1;""";
        await using var q=new SqlCommand(sql,c); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@person",SqlDbType.BigInt,PersonId); await using var r=await q.ExecuteReaderAsync(token); return await r.ReadAsync(token)?new(r.GetString(0),Text(r,1),Text(r,2),Text(r,3)):null;
    }
    private async Task<AccessInfo> Access(SqlConnection c,long id,CancellationToken token) { await using var q=new SqlCommand("SELECT StatusCode,CreateBy FROM dbo.TDADServiceComplaint WHERE CompanyID=@company AND ComplaintID=@id AND IsActive=1",c); Add(q,"@company",SqlDbType.BigInt,CompanyId); Add(q,"@id",SqlDbType.BigInt,id); await using var r=await q.ExecuteReaderAsync(token); return await r.ReadAsync(token)?new(true,r.GetString(0),r.IsDBNull(1)?null:r.GetInt64(1)):new(false,string.Empty,null); }
    private async Task<bool> CanRead(SqlConnection c,AccessInfo a,CancellationToken t) => await Allowed(c,"VIEW",t) && (await Allowed(c,"EDIT",t) || a.CreatedBy==UserId);
    private async Task<bool> InService(SqlConnection c,CancellationToken t) => CompanyId>0 && (await Allowed(c,"VIEW",t) || await Allowed(c,"CREATE",t) || await Allowed(c,"EDIT",t));
    private async Task<int> ScreenType(SqlConnection c,CancellationToken t) { await using var q=new SqlCommand("SELECT ScreenType FROM dbo.TDADMainMenu WHERE MenuCode=@menu AND IsActive=1 AND IsVisible=1",c); Add(q,"@menu",SqlDbType.VarChar,Menu,20); var value=await q.ExecuteScalarAsync(t); return value is null ? 0 : Convert.ToInt32(value); }
    private async Task<bool> IsCrud(SqlConnection c,CancellationToken t) => CompanyId>0 && await ScreenType(c,t)==1;
    private Task<bool> Allowed(SqlConnection c,string action,CancellationToken t) => CompanyProjectPermission.IsAllowedAsync(c,User,Menu,action,t);
    private async Task<SqlConnection> Open(CancellationToken t) { var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(t); return c; }
    private string? SafePath(string relative) { var root=environment.WebRootPath; if(string.IsNullOrWhiteSpace(root)) root=Path.Combine(environment.ContentRootPath,"wwwroot"); var rootPath=Path.GetFullPath(root)+Path.DirectorySeparatorChar; var full=Path.GetFullPath(Path.Combine(root,relative.Replace('/',Path.DirectorySeparatorChar))); return full.StartsWith(rootPath,StringComparison.OrdinalIgnoreCase)?full:null; }
    private void TryDelete(string relative) { var p=SafePath(relative); try { if(p is not null && System.IO.File.Exists(p)) System.IO.File.Delete(p); } catch { } }
    private long ClaimLong(string name) => long.TryParse(User.FindFirstValue(name),out var v)?v:0;
    private long? ClaimLongNullable(string name) => long.TryParse(User.FindFirstValue(name),out var v)?v:null;
    private static string? Text(SqlDataReader r,int i) => r.IsDBNull(i)?null:r.GetString(i);
    private static DateTime? Date(SqlDataReader r,int i) => r.IsDBNull(i)?null:r.GetDateTime(i);
    private static int? Int(SqlDataReader r,int i) => r.IsDBNull(i)?null:r.GetInt32(i);
    private static string SafeName(string name) { name=Path.GetFileName(name).Trim(); return string.IsNullOrEmpty(name)?"attachment":name[..Math.Min(name.Length,255)]; }
    private static void Add(SqlCommand c,string n,SqlDbType t,object? v,int size=0) { var p=size==0?c.Parameters.Add(n,t):c.Parameters.Add(n,t,size); p.Value=v??DBNull.Value; }
    public sealed record CreateComplaintRequest(string? Subject,string? Detail);
    public sealed record EditComplaintRequest(string? Subject,string? Detail,string? RowVersion);
    public sealed record CompleteComplaintRequest(string? ResolutionDetail);
    public sealed record CancelComplaintRequest(string? CancellationReason);
    private sealed record PersonInfo(string Name,string? Phone,string? Email,string? Location);
    private sealed record AccessInfo(bool Found,string Status,long? CreatedBy);
}
