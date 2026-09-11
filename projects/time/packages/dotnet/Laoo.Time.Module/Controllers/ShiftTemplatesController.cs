using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTimeModule.Controllers;

[ApiController]
[Authorize]
[Route("api/time/shift-templates")]
public sealed class ShiftTemplatesController(IConfiguration configuration) : ControllerBase
{
    private const string MenuCode = "27001";

    public sealed record SegmentRequest(
        int SequenceNo, string SegmentTypeCode, int StartDayOffset,
        TimeOnly StartTime, int EndDayOffset, TimeOnly EndTime);

    public sealed record SessionRuleRequest(
        int SequenceNo, string RuleName,
        int ScheduledInDayOffset, TimeOnly ScheduledInTime,
        int ScheduledOutDayOffset, TimeOnly ScheduledOutTime,
        int InWindowStartDayOffset, TimeOnly InWindowStartTime,
        int InWindowEndDayOffset, TimeOnly InWindowEndTime,
        int OutWindowStartDayOffset, TimeOnly OutWindowStartTime,
        int OutWindowEndDayOffset, TimeOnly OutWindowEndTime,
        int? LateToleranceMinutes, int? EarlyToleranceMinutes);

    public sealed record SaveRequest(
        string ShiftCode, string ShiftName, string? DescriptionText,
        bool IsActive, DateOnly EffectiveFrom, int LateToleranceMinutes,
        int EarlyToleranceMinutes, List<SegmentRequest> Segments,
        List<SessionRuleRequest> SessionRules, string? RowVersion);

    [HttpGet("actions")]
    public async Task<IActionResult> Actions(CancellationToken token)
    {
        if (!TryScope(out _, out _)) return Forbid();
        await using var connection = await Open(token);
        return Ok(new
        {
            menuCode = MenuCode,
            caption = await Caption(connection, token),
            screenType = 1,
            view = await Can(connection, "VIEW", token),
            create = await Can(connection, "CREATE", token),
            edit = await Can(connection, "EDIT", token),
            delete = await Can(connection, "DELETE", token),
        });
    }

    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] string? search, [FromQuery] bool? isActive,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 30,
        CancellationToken token = default)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        if (page < 1 || pageSize is < 1 or > 100)
            return BadRequest(new { message = "หน้าหรือจำนวนรายการต่อหน้าไม่ถูกต้อง" });
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();
        search = Clean(search);
        const string where = """
FROM dbo.TDTMShiftTemplate T
OUTER APPLY
(
    SELECT TOP(1) V.ShiftTemplateVersionID,V.EffectiveFrom,V.EffectiveTo,
           V.LateToleranceMinutes,V.EarlyToleranceMinutes
    FROM dbo.TDTMShiftTemplateVersion V
    WHERE V.CompanyID=T.CompanyID AND V.ShiftTemplateID=T.ShiftTemplateID
      AND V.IsActive=1 AND V.EffectiveFrom<=CONVERT(date,GETDATE())
      AND (V.EffectiveTo IS NULL OR V.EffectiveTo>=CONVERT(date,GETDATE()))
    ORDER BY V.EffectiveFrom DESC,V.ShiftTemplateVersionID DESC
) V
WHERE T.CompanyID=@CompanyID AND (@IsActive IS NULL OR T.IsActive=@IsActive)
  AND (@Search IS NULL OR T.ShiftCode LIKE N'%'+@Search+N'%'
       OR T.ShiftName LIKE N'%'+@Search+N'%')
""";
        await using var count = new SqlCommand($"SELECT COUNT_BIG(1) {where}", connection);
        BindList(count, companyId, search, isActive);
        var total = Convert.ToInt64(await count.ExecuteScalarAsync(token));
        await using var command = new SqlCommand($"""
SELECT T.ShiftTemplateID,T.ShiftCode,T.ShiftName,T.DescriptionText,T.IsActive,
       V.EffectiveFrom,V.EffectiveTo,V.LateToleranceMinutes,V.EarlyToleranceMinutes,
       (SELECT COUNT(*) FROM dbo.TDTMShiftSegment S WHERE S.ShiftTemplateVersionID=V.ShiftTemplateVersionID) SegmentCount,
       (SELECT COUNT(*) FROM dbo.TDTMAttendanceSessionRule R WHERE R.ShiftTemplateVersionID=V.ShiftTemplateVersionID) SessionCount,
       CONVERT(varchar(32),T.RowVersion,2) RowVersion
{where}
ORDER BY T.ShiftCode,T.ShiftTemplateID
OFFSET @Offset ROWS FETCH NEXT @Take ROWS ONLY;
""", connection);
        BindList(command, companyId, search, isActive);
        command.Parameters.Add("@Offset", SqlDbType.Int).Value = (page - 1) * pageSize;
        command.Parameters.Add("@Take", SqlDbType.Int).Value = pageSize;
        await using var reader = await command.ExecuteReaderAsync(token);
        var items = new List<object>();
        while (await reader.ReadAsync(token))
            items.Add(new
            {
                shiftTemplateId = reader.GetInt64(0), shiftCode = reader.GetString(1),
                shiftName = reader.GetString(2), descriptionText = Text(reader, 3),
                isActive = reader.GetBoolean(4), effectiveFrom = Date(reader, 5),
                effectiveTo = Date(reader, 6), lateToleranceMinutes = Int(reader, 7),
                earlyToleranceMinutes = Int(reader, 8), segmentCount = reader.GetInt32(9),
                sessionCount = reader.GetInt32(10), rowVersion = reader.GetString(11),
            });
        return Ok(new { total, page, pageSize, items });
    }

    [HttpGet("{id:long}")]
    public async Task<IActionResult> Get(long id, CancellationToken token)
    {
        if (!TryScope(out var companyId, out _)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "VIEW", token)) return Forbid();
        await using var command = new SqlCommand("""
SELECT T.ShiftCode,T.ShiftName,T.DescriptionText,T.IsActive,
       V.ShiftTemplateVersionID,V.EffectiveFrom,V.LateToleranceMinutes,V.EarlyToleranceMinutes,
       CONVERT(varchar(32),T.RowVersion,2)
FROM dbo.TDTMShiftTemplate T
JOIN dbo.TDTMShiftTemplateVersion V ON V.ShiftTemplateID=T.ShiftTemplateID AND V.CompanyID=T.CompanyID
WHERE T.CompanyID=@CompanyID AND T.ShiftTemplateID=@ID AND V.IsActive=1 AND V.EffectiveTo IS NULL;
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@ID", SqlDbType.BigInt, id);
        await using var reader = await command.ExecuteReaderAsync(token);
        if (!await reader.ReadAsync(token)) return NotFound();
        var code = reader.GetString(0); var name = reader.GetString(1);
        var description = Text(reader, 2); var active = reader.GetBoolean(3);
        var versionId = reader.GetInt64(4); var effective = reader.GetDateTime(5);
        var late = reader.GetInt32(6); var early = reader.GetInt32(7);
        var rowVersion = reader.GetString(8);
        await reader.CloseAsync();
        var segments = await Segments(connection, companyId, versionId, token);
        var rules = await Rules(connection, companyId, versionId, token);
        return Ok(new
        {
            shiftTemplateId = id, shiftCode = code, shiftName = name,
            descriptionText = description, isActive = active,
            effectiveFrom = DateOnly.FromDateTime(effective),
            lateToleranceMinutes = late, earlyToleranceMinutes = early,
            segments, sessionRules = rules, rowVersion,
        });
    }

    [HttpPost]
    public async Task<IActionResult> Create(SaveRequest request, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var error = Validate(request);
        if (error is not null) return BadRequest(new { message = error });
        await using var connection = await Open(token);
        if (!await Can(connection, "CREATE", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            await using var insert = new SqlCommand("""
INSERT dbo.TDTMShiftTemplate(CompanyID,ShiftCode,ShiftName,DescriptionText,IsActive,CreateBy)
OUTPUT INSERTED.ShiftTemplateID
VALUES(@CompanyID,@Code,@Name,@Description,@IsActive,@UserID);
""", connection, transaction);
            BindHeader(insert, companyId, userId, request);
            var id = Convert.ToInt64(await insert.ExecuteScalarAsync(token));
            await SaveVersion(connection, transaction, companyId, id, userId, request, token);
            await transaction.CommitAsync(token);
            return CreatedAtAction(nameof(Get), new { id }, new { shiftTemplateId = id });
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = "รหัสกะหรือวันที่เริ่มใช้ซ้ำกับข้อมูลเดิม" });
        }
    }

    [HttpPut("{id:long}")]
    public async Task<IActionResult> Update(long id, SaveRequest request, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        var error = Validate(request);
        if (error is not null) return BadRequest(new { message = error });
        if (string.IsNullOrWhiteSpace(request.RowVersion))
            return BadRequest(new { message = "ไม่พบ Version ของข้อมูล" });
        await using var connection = await Open(token);
        if (!await Can(connection, "EDIT", token)) return Forbid();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.Serializable, token);
        try
        {
            await using var update = new SqlCommand("""
UPDATE dbo.TDTMShiftTemplate SET ShiftCode=@Code,ShiftName=@Name,DescriptionText=@Description,
 IsActive=@IsActive,UpdateDate=SYSDATETIME(),UpdateBy=@UserID
WHERE CompanyID=@CompanyID AND ShiftTemplateID=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2);
""", connection, transaction);
            BindHeader(update, companyId, userId, request);
            Add(update, "@ID", SqlDbType.BigInt, id);
            Add(update, "@RowVersion", SqlDbType.VarChar, request.RowVersion, 32);
            if (await update.ExecuteNonQueryAsync(token) != 1)
            {
                await transaction.RollbackAsync(token);
                return Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" });
            }
            await SaveVersion(connection, transaction, companyId, id, userId, request, token);
            await transaction.CommitAsync(token);
            return NoContent();
        }
        catch (InvalidOperationException exception)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = exception.Message });
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            await transaction.RollbackAsync(token);
            return Conflict(new { message = "รหัสกะหรือวันที่เริ่มใช้ซ้ำกับข้อมูลเดิม" });
        }
    }

    [HttpDelete("{id:long}")]
    public async Task<IActionResult> Delete(long id, [FromQuery] string rowVersion, CancellationToken token)
    {
        if (!TryScope(out var companyId, out var userId)) return Forbid();
        await using var connection = await Open(token);
        if (!await Can(connection, "DELETE", token)) return Forbid();
        await using var command = new SqlCommand("""
IF EXISTS(SELECT 1 FROM dbo.TDTMRotationDay WHERE CompanyID=@CompanyID AND ShiftTemplateID=@ID)
 OR EXISTS(SELECT 1 FROM dbo.TDTMScheduleOverride WHERE CompanyID=@CompanyID AND ShiftTemplateID=@ID)
 THROW 52330,N'กะนี้ถูกใช้งานในตารางแล้ว ไม่สามารถลบได้',1;
UPDATE dbo.TDTMShiftTemplate SET IsActive=0,UpdateDate=SYSDATETIME(),UpdateBy=@UserID
WHERE CompanyID=@CompanyID AND ShiftTemplateID=@ID AND RowVersion=CONVERT(binary(8),@RowVersion,2);
""", connection);
        Add(command, "@CompanyID", SqlDbType.BigInt, companyId);
        Add(command, "@ID", SqlDbType.BigInt, id);
        Add(command, "@UserID", SqlDbType.BigInt, userId);
        Add(command, "@RowVersion", SqlDbType.VarChar, rowVersion, 32);
        try { return await command.ExecuteNonQueryAsync(token) == 1 ? NoContent() : Conflict(new { message = "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดใหม่" }); }
        catch (SqlException exception) when (exception.Number == 52330) { return Conflict(new { message = exception.Message }); }
    }

    private static string? Validate(SaveRequest request)
    {
        if (Clean(request.ShiftCode) is null || request.ShiftCode.Trim().Length > 30) return "กรุณาระบุรหัสกะไม่เกิน 30 ตัวอักษร";
        if (Clean(request.ShiftName) is null || request.ShiftName.Trim().Length > 150) return "กรุณาระบุชื่อกะไม่เกิน 150 ตัวอักษร";
        if (request.EffectiveFrom < DateOnly.FromDateTime(DateTime.Today)) return "วันที่เริ่มใช้ต้องไม่ย้อนหลัง";
        if (request.LateToleranceMinutes is < 0 or > 1440 || request.EarlyToleranceMinutes is < 0 or > 1440) return "เกณฑ์สายและออกก่อนต้องอยู่ระหว่าง 0–1,440 นาที";
        if (request.Segments.Count == 0 || request.SessionRules.Count == 0) return "ต้องมีช่วงเวลาและรอบลงเวลาอย่างน้อยอย่างละ 1 รายการ";
        if (request.Segments.Select(x => x.SequenceNo).Distinct().Count() != request.Segments.Count || request.SessionRules.Select(x => x.SequenceNo).Distinct().Count() != request.SessionRules.Count) return "ลำดับรายการต้องไม่ซ้ำ";
        if (!request.Segments.Any(x => Normalize(x.SegmentTypeCode) == "WORK")) return "ต้องมีช่วงทำงานปกติอย่างน้อย 1 ช่วง";
        var spans = new List<(int Start, int End)>();
        foreach (var item in request.Segments.OrderBy(x => x.SequenceNo))
        {
            if (Normalize(item.SegmentTypeCode) is not ("WORK" or "BREAK" or "OT")) return "ประเภทช่วงเวลาไม่ถูกต้อง";
            var span = Span(item.StartDayOffset, item.StartTime, item.EndDayOffset, item.EndTime);
            if (span is null) return "ช่วงเวลาต้องสิ้นสุดหลังเวลาเริ่มและข้ามวันได้ไม่เกิน 1 วัน";
            if (spans.Any(x => x.Start < span.Value.End && span.Value.Start < x.End)) return "ช่วงเวลาของกะต้องไม่ซ้อนกัน";
            spans.Add(span.Value);
        }
        foreach (var rule in request.SessionRules)
        {
            if (Clean(rule.RuleName) is null || rule.RuleName.Trim().Length > 100) return "กรุณาระบุชื่อรอบลงเวลาไม่เกิน 100 ตัวอักษร";
            if (Span(rule.ScheduledInDayOffset, rule.ScheduledInTime, rule.ScheduledOutDayOffset, rule.ScheduledOutTime) is null ||
                Span(rule.InWindowStartDayOffset, rule.InWindowStartTime, rule.InWindowEndDayOffset, rule.InWindowEndTime) is null ||
                Span(rule.OutWindowStartDayOffset, rule.OutWindowStartTime, rule.OutWindowEndDayOffset, rule.OutWindowEndTime) is null) return "ช่วงเวลาของรอบลงเวลาไม่ถูกต้อง";
            if (rule.LateToleranceMinutes is < 0 or > 1440 || rule.EarlyToleranceMinutes is < 0 or > 1440) return "เกณฑ์เฉพาะรอบต้องอยู่ระหว่าง 0–1,440 นาที";
        }
        return null;
    }

    private static async Task SaveVersion(SqlConnection connection, SqlTransaction transaction, long companyId, long id, long userId, SaveRequest request, CancellationToken token)
    {
        long versionId;
        await using (var find = new SqlCommand("SELECT TOP(1) ShiftTemplateVersionID,EffectiveFrom FROM dbo.TDTMShiftTemplateVersion WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@CompanyID AND ShiftTemplateID=@ID AND IsActive=1 AND EffectiveTo IS NULL ORDER BY EffectiveFrom DESC", connection, transaction))
        {
            Add(find, "@CompanyID", SqlDbType.BigInt, companyId); Add(find, "@ID", SqlDbType.BigInt, id);
            await using var reader = await find.ExecuteReaderAsync(token);
            if (await reader.ReadAsync(token))
            {
                versionId = reader.GetInt64(0); var start = DateOnly.FromDateTime(reader.GetDateTime(1));
                await reader.CloseAsync();
                if (start > request.EffectiveFrom) throw new InvalidOperationException("วันที่เริ่มใช้ต้องไม่ก่อน Version ที่บันทึกไว้");
                if (start == request.EffectiveFrom)
                {
                    await Execute(connection, transaction, "DELETE dbo.TDTMAttendanceSessionRule WHERE CompanyID=@CompanyID AND ShiftTemplateVersionID=@VersionID; DELETE dbo.TDTMShiftSegment WHERE CompanyID=@CompanyID AND ShiftTemplateVersionID=@VersionID; UPDATE dbo.TDTMShiftTemplateVersion SET LateToleranceMinutes=@Late,EarlyToleranceMinutes=@Early,UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND ShiftTemplateVersionID=@VersionID;", companyId, versionId, userId, request, token);
                }
                else
                {
                    await Execute(connection, transaction, "UPDATE dbo.TDTMShiftTemplateVersion SET EffectiveTo=DATEADD(day,-1,@EffectiveFrom),UpdateDate=SYSDATETIME(),UpdateBy=@UserID WHERE CompanyID=@CompanyID AND ShiftTemplateVersionID=@VersionID;", companyId, versionId, userId, request, token);
                    versionId = await InsertVersion(connection, transaction, companyId, id, userId, request, token);
                }
            }
            else { await reader.CloseAsync(); versionId = await InsertVersion(connection, transaction, companyId, id, userId, request, token); }
        }
        foreach (var item in request.Segments)
        {
            await using var command = new SqlCommand("INSERT dbo.TDTMShiftSegment(CompanyID,ShiftTemplateVersionID,SequenceNo,SegmentTypeCode,StartDayOffset,StartTime,EndDayOffset,EndTime,CreateBy) VALUES(@CompanyID,@VersionID,@Sequence,@Type,@StartOffset,@StartTime,@EndOffset,@EndTime,@UserID);", connection, transaction);
            Add(command,"@CompanyID",SqlDbType.BigInt,companyId); Add(command,"@VersionID",SqlDbType.BigInt,versionId); Add(command,"@Sequence",SqlDbType.Int,item.SequenceNo); Add(command,"@Type",SqlDbType.VarChar,Normalize(item.SegmentTypeCode),20); Add(command,"@StartOffset",SqlDbType.TinyInt,item.StartDayOffset); Add(command,"@StartTime",SqlDbType.Time,item.StartTime.ToTimeSpan()); Add(command,"@EndOffset",SqlDbType.TinyInt,item.EndDayOffset); Add(command,"@EndTime",SqlDbType.Time,item.EndTime.ToTimeSpan()); Add(command,"@UserID",SqlDbType.BigInt,userId); await command.ExecuteNonQueryAsync(token);
        }
        foreach (var item in request.SessionRules) await InsertRule(connection, transaction, companyId, versionId, userId, item, token);
    }

    private static async Task<long> InsertVersion(SqlConnection c, SqlTransaction t, long companyId, long id, long userId, SaveRequest r, CancellationToken token)
    {
        await using var command = new SqlCommand("INSERT dbo.TDTMShiftTemplateVersion(CompanyID,ShiftTemplateID,EffectiveFrom,LateToleranceMinutes,EarlyToleranceMinutes,IsActive,CreateBy) OUTPUT INSERTED.ShiftTemplateVersionID VALUES(@CompanyID,@ID,@EffectiveFrom,@Late,@Early,1,@UserID);", c, t);
        Add(command,"@CompanyID",SqlDbType.BigInt,companyId); Add(command,"@ID",SqlDbType.BigInt,id); Add(command,"@EffectiveFrom",SqlDbType.Date,r.EffectiveFrom.ToDateTime(TimeOnly.MinValue)); Add(command,"@Late",SqlDbType.Int,r.LateToleranceMinutes); Add(command,"@Early",SqlDbType.Int,r.EarlyToleranceMinutes); Add(command,"@UserID",SqlDbType.BigInt,userId); return Convert.ToInt64(await command.ExecuteScalarAsync(token));
    }

    private static async Task Execute(SqlConnection c, SqlTransaction t, string sql, long companyId, long versionId, long userId, SaveRequest r, CancellationToken token)
    { await using var command = new SqlCommand(sql,c,t); Add(command,"@CompanyID",SqlDbType.BigInt,companyId); Add(command,"@VersionID",SqlDbType.BigInt,versionId); Add(command,"@EffectiveFrom",SqlDbType.Date,r.EffectiveFrom.ToDateTime(TimeOnly.MinValue)); Add(command,"@Late",SqlDbType.Int,r.LateToleranceMinutes); Add(command,"@Early",SqlDbType.Int,r.EarlyToleranceMinutes); Add(command,"@UserID",SqlDbType.BigInt,userId); await command.ExecuteNonQueryAsync(token); }

    private static async Task InsertRule(SqlConnection c, SqlTransaction t, long companyId, long versionId, long userId, SessionRuleRequest r, CancellationToken token)
    {
        await using var command = new SqlCommand("INSERT dbo.TDTMAttendanceSessionRule(CompanyID,ShiftTemplateVersionID,SequenceNo,RuleName,ScheduledInDayOffset,ScheduledInTime,ScheduledOutDayOffset,ScheduledOutTime,InWindowStartDayOffset,InWindowStartTime,InWindowEndDayOffset,InWindowEndTime,OutWindowStartDayOffset,OutWindowStartTime,OutWindowEndDayOffset,OutWindowEndTime,LateToleranceMinutes,EarlyToleranceMinutes,CreateBy) VALUES(@C,@V,@N,@Name,@SID,@SIT,@SOD,@SOT,@I1D,@I1T,@I2D,@I2T,@O1D,@O1T,@O2D,@O2T,@Late,@Early,@U);",c,t);
        Add(command,"@C",SqlDbType.BigInt,companyId); Add(command,"@V",SqlDbType.BigInt,versionId); Add(command,"@N",SqlDbType.Int,r.SequenceNo); Add(command,"@Name",SqlDbType.NVarChar,r.RuleName.Trim(),100); Add(command,"@SID",SqlDbType.TinyInt,r.ScheduledInDayOffset); Add(command,"@SIT",SqlDbType.Time,r.ScheduledInTime.ToTimeSpan()); Add(command,"@SOD",SqlDbType.TinyInt,r.ScheduledOutDayOffset); Add(command,"@SOT",SqlDbType.Time,r.ScheduledOutTime.ToTimeSpan()); Add(command,"@I1D",SqlDbType.TinyInt,r.InWindowStartDayOffset); Add(command,"@I1T",SqlDbType.Time,r.InWindowStartTime.ToTimeSpan()); Add(command,"@I2D",SqlDbType.TinyInt,r.InWindowEndDayOffset); Add(command,"@I2T",SqlDbType.Time,r.InWindowEndTime.ToTimeSpan()); Add(command,"@O1D",SqlDbType.TinyInt,r.OutWindowStartDayOffset); Add(command,"@O1T",SqlDbType.Time,r.OutWindowStartTime.ToTimeSpan()); Add(command,"@O2D",SqlDbType.TinyInt,r.OutWindowEndDayOffset); Add(command,"@O2T",SqlDbType.Time,r.OutWindowEndTime.ToTimeSpan()); Add(command,"@Late",SqlDbType.Int,r.LateToleranceMinutes); Add(command,"@Early",SqlDbType.Int,r.EarlyToleranceMinutes); Add(command,"@U",SqlDbType.BigInt,userId); await command.ExecuteNonQueryAsync(token);
    }

    private static async Task<List<object>> Segments(SqlConnection c,long companyId,long versionId,CancellationToken token) { await using var command=new SqlCommand("SELECT SequenceNo,SegmentTypeCode,StartDayOffset,CONVERT(varchar(8),StartTime,108),EndDayOffset,CONVERT(varchar(8),EndTime,108) FROM dbo.TDTMShiftSegment WHERE CompanyID=@C AND ShiftTemplateVersionID=@V ORDER BY SequenceNo",c); Add(command,"@C",SqlDbType.BigInt,companyId);Add(command,"@V",SqlDbType.BigInt,versionId);await using var reader=await command.ExecuteReaderAsync(token);var rows=new List<object>();while(await reader.ReadAsync(token))rows.Add(new{sequenceNo=reader.GetInt32(0),segmentTypeCode=reader.GetString(1),startDayOffset=reader.GetByte(2),startTime=reader.GetString(3),endDayOffset=reader.GetByte(4),endTime=reader.GetString(5)});return rows; }
    private static async Task<List<object>> Rules(SqlConnection c,long companyId,long versionId,CancellationToken token) { await using var command=new SqlCommand("SELECT SequenceNo,RuleName,ScheduledInDayOffset,CONVERT(varchar(8),ScheduledInTime,108),ScheduledOutDayOffset,CONVERT(varchar(8),ScheduledOutTime,108),InWindowStartDayOffset,CONVERT(varchar(8),InWindowStartTime,108),InWindowEndDayOffset,CONVERT(varchar(8),InWindowEndTime,108),OutWindowStartDayOffset,CONVERT(varchar(8),OutWindowStartTime,108),OutWindowEndDayOffset,CONVERT(varchar(8),OutWindowEndTime,108),LateToleranceMinutes,EarlyToleranceMinutes FROM dbo.TDTMAttendanceSessionRule WHERE CompanyID=@C AND ShiftTemplateVersionID=@V ORDER BY SequenceNo",c);Add(command,"@C",SqlDbType.BigInt,companyId);Add(command,"@V",SqlDbType.BigInt,versionId);await using var reader=await command.ExecuteReaderAsync(token);var rows=new List<object>();while(await reader.ReadAsync(token))rows.Add(new{sequenceNo=reader.GetInt32(0),ruleName=reader.GetString(1),scheduledInDayOffset=reader.GetByte(2),scheduledInTime=reader.GetString(3),scheduledOutDayOffset=reader.GetByte(4),scheduledOutTime=reader.GetString(5),inWindowStartDayOffset=reader.GetByte(6),inWindowStartTime=reader.GetString(7),inWindowEndDayOffset=reader.GetByte(8),inWindowEndTime=reader.GetString(9),outWindowStartDayOffset=reader.GetByte(10),outWindowStartTime=reader.GetString(11),outWindowEndDayOffset=reader.GetByte(12),outWindowEndTime=reader.GetString(13),lateToleranceMinutes=reader.IsDBNull(14)?null:(int?)reader.GetInt32(14),earlyToleranceMinutes=reader.IsDBNull(15)?null:(int?)reader.GetInt32(15)});return rows; }

    private async Task<bool> Can(SqlConnection c,string action,CancellationToken token)=>await CompanyMenuAccess.IsAllowedAsync(c,User,MenuCode,action,token);
    private async Task<SqlConnection> Open(CancellationToken token){var c=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await c.OpenAsync(token);return c;}
    private bool TryScope(out long companyId,out long userId){companyId=0;userId=0;return string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase)&&long.TryParse(User.FindFirstValue("company_id"),out companyId)&&long.TryParse(User.FindFirstValue("user_id"),out userId)&&companyId>0&&userId>0;}
    private static async Task<string> Caption(SqlConnection c,CancellationToken token){await using var command=new SqlCommand("SELECT TOP(1) MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@Code",c);Add(command,"@Code",SqlDbType.Char,MenuCode,5);return Convert.ToString(await command.ExecuteScalarAsync(token))??"Master กะทำงาน";}
    private static void BindList(SqlCommand c,long companyId,string? search,bool? active){Add(c,"@CompanyID",SqlDbType.BigInt,companyId);Add(c,"@Search",SqlDbType.NVarChar,search,150);Add(c,"@IsActive",SqlDbType.Bit,active);}
    private static void BindHeader(SqlCommand c,long companyId,long userId,SaveRequest r){Add(c,"@CompanyID",SqlDbType.BigInt,companyId);Add(c,"@Code",SqlDbType.NVarChar,r.ShiftCode.Trim().ToUpperInvariant(),30);Add(c,"@Name",SqlDbType.NVarChar,r.ShiftName.Trim(),150);Add(c,"@Description",SqlDbType.NVarChar,Clean(r.DescriptionText),500);Add(c,"@IsActive",SqlDbType.Bit,r.IsActive);Add(c,"@UserID",SqlDbType.BigInt,userId);}
    private static (int Start,int End)? Span(int sd,TimeOnly st,int ed,TimeOnly et){if(sd is<0 or>1||ed is<0 or>1)return null;var start=sd*86400+st.Hour*3600+st.Minute*60+st.Second;var end=ed*86400+et.Hour*3600+et.Minute*60+et.Second;return end>start?(start,end):null;}
    private static string Normalize(string value)=>value.Trim().ToUpperInvariant(); private static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
    private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i); private static DateOnly? Date(SqlDataReader r,int i)=>r.IsDBNull(i)?null:DateOnly.FromDateTime(r.GetDateTime(i)); private static int? Int(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetInt32(i);
    private static void Add(SqlCommand c,string n,SqlDbType t,object? v,int s=0){var p=s==0?c.Parameters.Add(n,t):c.Parameters.Add(n,t,s);p.Value=v??DBNull.Value;}
}
