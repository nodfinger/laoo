using System.Data;
using Microsoft.Data.SqlClient;

namespace LaooTimeModule;

public static class AttendanceCalculator
{
    private sealed record Session(long Id, int Sequence, string Name, DateTime ScheduledIn, DateTime ScheduledOut,
        DateTime InStart, DateTime InEnd, DateTime OutStart, DateTime OutEnd, int LateTolerance, int EarlyTolerance);

    public static async Task RecalculateAsync(SqlConnection connection, SqlTransaction transaction,
        long companyId, long employeeId, DateOnly workDate, long actorId, CancellationToken token)
    {
        var (shiftVersionId, sessions, breaks) = await Schedule(connection, transaction, companyId, employeeId, workDate, token);
        var resultVersion = await NextVersion(connection, transaction, companyId, employeeId, workDate, token);
        await using (var deactivate = new SqlCommand("UPDATE dbo.TDTMAttendanceResult SET IsCurrent=0 WHERE CompanyID=@C AND EmployeeID=@E AND WorkDate=@D AND IsCurrent=1", connection, transaction))
        { Add(deactivate, "@C", SqlDbType.BigInt, companyId); Add(deactivate, "@E", SqlDbType.BigInt, employeeId); Add(deactivate, "@D", SqlDbType.Date, workDate.ToDateTime(TimeOnly.MinValue)); await deactivate.ExecuteNonQueryAsync(token); }

        if (sessions.Count == 0)
        {
            await InsertResult(connection, transaction, companyId, employeeId, workDate, null, resultVersion, "DAY_OFF", 0, 0, 0, 0, null, actorId, [], token);
            return;
        }

        var rows = new List<(Session Session, DateTime? In, DateTime? Out, int Work, int Late, int Early)>();
        foreach (var session in sessions)
        {
            var input = await Endpoint(connection, transaction, companyId, employeeId, workDate, session.Id, "IN", session.InStart, session.InEnd, true, token);
            var output = await Endpoint(connection, transaction, companyId, employeeId, workDate, session.Id, "OUT", session.OutStart, session.OutEnd, false, token);
            var work = input.HasValue && output.HasValue && output > input
                ? Math.Max(0, (int)(output.Value - input.Value).TotalMinutes - OverlapMinutes(input.Value, output.Value, breaks)) : 0;
            var late = input.HasValue ? Math.Max(0, (int)(input.Value - session.ScheduledIn).TotalMinutes - session.LateTolerance) : 0;
            var early = output.HasValue ? Math.Max(0, (int)(session.ScheduledOut - output.Value).TotalMinutes - session.EarlyTolerance) : 0;
            rows.Add((session, input, output, work, late, early));
        }
        var unresolved = rows.Any(x => !x.In.HasValue || !x.Out.HasValue || x.Out <= x.In);
        var reason = unresolved ? "ข้อมูลเวลาเข้า/ออกไม่ครบตามรอบที่กำหนด" : null;
        var scheduled = sessions.Sum(x => (int)(x.ScheduledOut - x.ScheduledIn).TotalMinutes) - OverlapMinutes(sessions.Min(x => x.ScheduledIn), sessions.Max(x => x.ScheduledOut), breaks);
        await InsertResult(connection, transaction, companyId, employeeId, workDate, shiftVersionId, resultVersion,
            unresolved ? "UNRESOLVED" : "COMPLETE", Math.Max(0, scheduled), rows.Sum(x => x.Work), rows.Sum(x => x.Late), rows.Sum(x => x.Early), reason, actorId, rows, token);
    }

    private static async Task<DateTime?> Endpoint(SqlConnection c, SqlTransaction tx, long company, long employee, DateOnly date,
        long rule, string endpoint, DateTime start, DateTime end, bool first, CancellationToken token)
    {
        await using var adjustment = new SqlCommand("SELECT TOP(1) AdjustedDateTime FROM dbo.TDTMTimeAdjustment WHERE CompanyID=@C AND SubjectEmployeeID=@E AND WorkDate=@D AND AttendanceSessionRuleID=@R AND EndpointCode=@P ORDER BY CreateDate DESC,TimeAdjustmentID DESC", c, tx);
        Add(adjustment, "@C", SqlDbType.BigInt, company); Add(adjustment, "@E", SqlDbType.BigInt, employee); Add(adjustment, "@D", SqlDbType.Date, date.ToDateTime(TimeOnly.MinValue)); Add(adjustment, "@R", SqlDbType.BigInt, rule); Add(adjustment, "@P", SqlDbType.VarChar, endpoint, 10);
        var value = await adjustment.ExecuteScalarAsync(token); if (value is DateTime adjusted) return adjusted;
        await using var source = new SqlCommand($"SELECT TOP(1) EventDateTime FROM dbo.TDTMAttendanceEvent WHERE CompanyID=@C AND EmployeeID=@E AND EventDateTime>=@S AND EventDateTime<=@T ORDER BY EventDateTime {(first ? "ASC" : "DESC")},AttendanceEventID {(first ? "ASC" : "DESC")}", c, tx);
        Add(source, "@C", SqlDbType.BigInt, company); Add(source, "@E", SqlDbType.BigInt, employee); Add(source, "@S", SqlDbType.DateTime2, start); Add(source, "@T", SqlDbType.DateTime2, end);
        value = await source.ExecuteScalarAsync(token); return value is DateTime eventDateTime ? eventDateTime : null;
    }

    private static async Task<(long? Version, List<Session> Sessions, List<(DateTime Start, DateTime End)> Breaks)> Schedule(SqlConnection c, SqlTransaction tx, long company, long employee, DateOnly date, CancellationToken token)
    {
        const string sql = """
WITH EffectiveShift AS(
 SELECT COALESCE(O.ShiftTemplateID,RD.ShiftTemplateID) ShiftTemplateID FROM(VALUES(1))X(N)
 OUTER APPLY(SELECT TOP(1) ShiftTemplateID,IsDayOff FROM dbo.TDTMScheduleOverride WHERE CompanyID=@C AND EmployeeID=@E AND WorkDate=@D AND IsActive=1 ORDER BY ScheduleOverrideID DESC)O
 OUTER APPLY(SELECT TOP(1) WorkScheduleGroupID FROM dbo.TDTMWorkScheduleGroupAssignment WHERE CompanyID=@C AND EmployeeID=@E AND IsActive=1 AND EffectiveFrom<=@D AND(EffectiveTo IS NULL OR EffectiveTo>=@D) ORDER BY EffectiveFrom DESC)A
 OUTER APPLY(SELECT TOP(1) RotationPatternID,AnchorDate FROM dbo.TDTMGroupShiftRotation WHERE CompanyID=@C AND WorkScheduleGroupID=A.WorkScheduleGroupID AND IsActive=1 AND EffectiveFrom<=@D AND(EffectiveTo IS NULL OR EffectiveTo>=@D) ORDER BY EffectiveFrom DESC)G
 OUTER APPLY(SELECT TOP(1) RotationPatternVersionID,CycleDays FROM dbo.TDTMRotationPatternVersion WHERE CompanyID=@C AND RotationPatternID=G.RotationPatternID AND IsActive=1 AND EffectiveFrom<=@D AND(EffectiveTo IS NULL OR EffectiveTo>=@D) ORDER BY EffectiveFrom DESC)PV
 OUTER APPLY(SELECT TOP(1) ShiftTemplateID,IsDayOff FROM dbo.TDTMRotationDay WHERE CompanyID=@C AND RotationPatternVersionID=PV.RotationPatternVersionID AND DayNo=((DATEDIFF(day,G.AnchorDate,@D)%PV.CycleDays+PV.CycleDays)%PV.CycleDays)+1)RD
 WHERE ISNULL(O.IsDayOff,ISNULL(RD.IsDayOff,1))=0), V AS(
 SELECT TOP(1) V.ShiftTemplateVersionID FROM EffectiveShift S JOIN dbo.TDTMShiftTemplateVersion V ON V.CompanyID=@C AND V.ShiftTemplateID=S.ShiftTemplateID WHERE V.IsActive=1 AND V.EffectiveFrom<=@D AND(V.EffectiveTo IS NULL OR V.EffectiveTo>=@D) ORDER BY V.EffectiveFrom DESC,V.ShiftTemplateVersionID DESC)
SELECT V.ShiftTemplateVersionID,R.AttendanceSessionRuleID,R.SequenceNo,R.RuleName,R.ScheduledInDayOffset,R.ScheduledInTime,R.ScheduledOutDayOffset,R.ScheduledOutTime,R.InWindowStartDayOffset,R.InWindowStartTime,R.InWindowEndDayOffset,R.InWindowEndTime,R.OutWindowStartDayOffset,R.OutWindowStartTime,R.OutWindowEndDayOffset,R.OutWindowEndTime,COALESCE(R.LateToleranceMinutes,0),COALESCE(R.EarlyToleranceMinutes,0)
FROM V JOIN dbo.TDTMAttendanceSessionRule R ON R.ShiftTemplateVersionID=V.ShiftTemplateVersionID AND R.CompanyID=@C ORDER BY R.SequenceNo;
""";
        await using var q = new SqlCommand(sql, c, tx); Add(q,"@C",SqlDbType.BigInt,company); Add(q,"@E",SqlDbType.BigInt,employee); Add(q,"@D",SqlDbType.Date,date.ToDateTime(TimeOnly.MinValue));
        await using var r = await q.ExecuteReaderAsync(token); var sessions=new List<Session>(); long? version=null;
        while(await r.ReadAsync(token)){version=r.GetInt64(0); DateTime At(int col)=>date.AddDays(r.GetByte(col)).ToDateTime(TimeOnly.FromTimeSpan(r.GetTimeSpan(col+1))); sessions.Add(new Session(r.GetInt64(1),r.GetInt32(2),r.GetString(3),At(4),At(6),At(8),At(10),At(12),At(14),r.GetInt32(16),r.GetInt32(17)));} await r.CloseAsync();
        var breaks=new List<(DateTime,DateTime)>(); if(!version.HasValue)return(version,sessions,breaks);
        await using var b=new SqlCommand("SELECT StartDayOffset,StartTime,EndDayOffset,EndTime FROM dbo.TDTMShiftSegment WHERE CompanyID=@C AND ShiftTemplateVersionID=@V AND SegmentTypeCode='BREAK'",c,tx); Add(b,"@C",SqlDbType.BigInt,company);Add(b,"@V",SqlDbType.BigInt,version);await using var br=await b.ExecuteReaderAsync(token);while(await br.ReadAsync(token))breaks.Add((date.AddDays(br.GetByte(0)).ToDateTime(TimeOnly.FromTimeSpan(br.GetTimeSpan(1))),date.AddDays(br.GetByte(2)).ToDateTime(TimeOnly.FromTimeSpan(br.GetTimeSpan(3)))));return(version,sessions,breaks);
    }
    private static int OverlapMinutes(DateTime start,DateTime end,List<(DateTime Start,DateTime End)> ranges)=>ranges.Sum(x=>(int)Math.Max(0,((end<x.End?end:x.End)-(start>x.Start?start:x.Start)).TotalMinutes));
    private static async Task<int> NextVersion(SqlConnection c,SqlTransaction tx,long company,long employee,DateOnly date,CancellationToken token){await using var q=new SqlCommand("SELECT ISNULL(MAX(ResultVersion),0)+1 FROM dbo.TDTMAttendanceResult WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@C AND EmployeeID=@E AND WorkDate=@D",c,tx);Add(q,"@C",SqlDbType.BigInt,company);Add(q,"@E",SqlDbType.BigInt,employee);Add(q,"@D",SqlDbType.Date,date.ToDateTime(TimeOnly.MinValue));return Convert.ToInt32(await q.ExecuteScalarAsync(token));}
    private static async Task InsertResult(SqlConnection c,SqlTransaction tx,long company,long employee,DateOnly date,long? version,int resultVersion,string status,int scheduled,int actual,int late,int early,string? reason,long actor,IReadOnlyList<(Session Session,DateTime? In,DateTime? Out,int Work,int Late,int Early)> rows,CancellationToken token){await using var h=new SqlCommand("INSERT dbo.TDTMAttendanceResult(CompanyID,EmployeeID,WorkDate,ShiftTemplateVersionID,ResultVersion,StatusCode,ScheduledWorkMinutes,ActualWorkMinutes,LateMinutes,EarlyMinutes,UnresolvedReason,CreateBy) OUTPUT INSERTED.AttendanceResultID VALUES(@C,@E,@D,@V,@N,@S,@SW,@AW,@L,@ER,@R,@U)",c,tx);Add(h,"@C",SqlDbType.BigInt,company);Add(h,"@E",SqlDbType.BigInt,employee);Add(h,"@D",SqlDbType.Date,date.ToDateTime(TimeOnly.MinValue));Add(h,"@V",SqlDbType.BigInt,version);Add(h,"@N",SqlDbType.Int,resultVersion);Add(h,"@S",SqlDbType.VarChar,status,20);Add(h,"@SW",SqlDbType.Int,scheduled);Add(h,"@AW",SqlDbType.Int,actual);Add(h,"@L",SqlDbType.Int,late);Add(h,"@ER",SqlDbType.Int,early);Add(h,"@R",SqlDbType.NVarChar,reason,1000);Add(h,"@U",SqlDbType.BigInt,actor);var id=Convert.ToInt64(await h.ExecuteScalarAsync(token));foreach(var row in rows){await using var d=new SqlCommand("INSERT dbo.TDTMAttendanceSessionResult(AttendanceResultID,AttendanceSessionRuleID,SequenceNo,SessionStatusCode,ActualInDateTime,ActualOutDateTime,WorkMinutes,LateMinutes,EarlyMinutes)VALUES(@I,@R,@N,@S,@IN,@OUT,@W,@L,@E)",c,tx);Add(d,"@I",SqlDbType.BigInt,id);Add(d,"@R",SqlDbType.BigInt,row.Session.Id);Add(d,"@N",SqlDbType.Int,row.Session.Sequence);Add(d,"@S",SqlDbType.VarChar,row.In.HasValue&&row.Out.HasValue&&row.Out>row.In?"COMPLETE":"UNRESOLVED",20);Add(d,"@IN",SqlDbType.DateTime2,row.In);Add(d,"@OUT",SqlDbType.DateTime2,row.Out);Add(d,"@W",SqlDbType.Int,row.Work);Add(d,"@L",SqlDbType.Int,row.Late);Add(d,"@E",SqlDbType.Int,row.Early);await d.ExecuteNonQueryAsync(token);}}
    private static void Add(SqlCommand q,string name,SqlDbType type,object? value,int size=0){var p=size==0?q.Parameters.Add(name,type):q.Parameters.Add(name,type,size);p.Value=value??DBNull.Value;}
}
