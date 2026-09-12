using System.Data;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController, Route("api/company/meeting-participant-responses"), Authorize]
[LaooMeetingApi.Security.RequireCompanyProject("LAOO_MEETING")]
public sealed class MeetingParticipantResponseController(IConfiguration configuration) : ControllerBase
{
    [HttpGet("{participantId:long}")]
    public async Task<IActionResult> Get(long participantId, CancellationToken token)
    {
        if (!Scope(out var company, out var user)) return Forbid();
        await using var db = await Open(token);
        if (!await Ready(db, token)) return StatusCode(503, Error("ระบบตอบรับยังไม่พร้อม", "กรุณาให้ผู้ดูแลระบบรัน Migration ของ Meeting ล่าสุด"));
        var access = await LoadAccess(db, participantId, company, user, token);
        if (access is null || (!access.Own && !access.Manager)) return Forbid();
        var now = DateTime.Now;
        var afterCutoff = access.Cutoff is not null && access.Cutoff <= now;
        var duringMeeting = access.Start <= now && access.End > now;
        var lateResponseMode = duringMeeting && access.Status != "ACCEPTED";
        var lateAcceptanceOnly = access.Own && !access.Manager && lateResponseMode;
        var canRespond = access.End > now && (access.Own && !duringMeeting && !afterCutoff || lateAcceptanceOnly || access.Manager);
        var canEditPreferences = canRespond && !duringMeeting && (!afterCutoff || access.Manager);

        var groups = new List<object>();
        const string groupSql = """
SELECT G.FoodTypeCode,ISNULL(M.Name,G.FoodTypeCode),G.MaxQuantity,G.IsRequired
FROM dbo.TDADMeetingBookingFoodGroup G
OUTER APPLY(SELECT TOP(1) X.Name FROM dbo.TDSTMaster X
 WHERE X.MasterGroupCode='011' AND X.MasterCode=G.FoodTypeCode AND X.IsActive=1
 AND X.OwnerType='C' AND X.OwnerCompanyID=@company) M
WHERE G.BookingID=@booking AND G.CompanyID=@company AND G.IsActive=1
ORDER BY G.BookingFoodGroupID;
""";
        await using (var cmd = new SqlCommand(groupSql, db))
        {
            Add(cmd,"@booking",access.BookingId); Add(cmd,"@company",company);
            await using var r = await cmd.ExecuteReaderAsync(token);
            while(await r.ReadAsync(token)) groups.Add(new { foodTypeCode=r.GetString(0),foodTypeName=r.GetString(1),maxQuantity=r.GetInt32(2),isRequired=r.GetBoolean(3) });
        }

        var foods = new List<object>();
        const string foodSql = """
SELECT F.FoodID,F.FoodCode,F.FoodNameTH,F.FoodTypeCode,F.FoodImageUrl,
 CASE WHEN ISNULL(H.IsCancelled,0)=0 THEN ISNULL(D.Quantity,0) ELSE 0 END
FROM dbo.TDADMeetingBookingFoodOption O
JOIN dbo.TDADMeetingFood F ON F.FoodID=O.FoodID AND F.CompanyID=O.CompanyID
LEFT JOIN dbo.TDADMeetingBookingFoodOrder H ON H.CompanyID=@company AND H.BookingID=@booking AND H.BookingParticipantID=@participant
LEFT JOIN dbo.TDADMeetingBookingFoodOrderDetail D ON D.BookingFoodOrderID=H.BookingFoodOrderID AND D.FoodID=F.FoodID
WHERE O.BookingID=@booking AND O.CompanyID=@company ORDER BY F.FoodTypeCode,F.FoodCode;
""";
        await using (var cmd = new SqlCommand(foodSql,db))
        {
            Add(cmd,"@booking",access.BookingId);Add(cmd,"@company",company);Add(cmd,"@participant",participantId);
            await using var r=await cmd.ExecuteReaderAsync(token);
            while(await r.ReadAsync(token)) foods.Add(new {foodId=r.GetInt64(0),code=r.GetString(1),nameTh=r.GetString(2),foodTypeCode=r.GetString(3),imageUrl=Text(r,4),orderQuantity=r.GetInt32(5)});
        }

        var rows = new List<QuestionRow>();
        const string questionSql = """
SELECT Q.RequirementQuestionID,Q.QuestionText,Q.AnswerType,Q.IsRequired,Q.SortOrder,A.AnswerValue,
 O.RequirementOptionID,O.OptionText,O.SortOrder
FROM dbo.TDADMeetingBookingRequirementQuestion Q
LEFT JOIN dbo.TDADMeetingParticipantRequirementAnswer A ON A.CompanyID=Q.CompanyID
 AND A.BookingParticipantID=@participant AND A.RequirementQuestionID=Q.RequirementQuestionID
LEFT JOIN dbo.TDADMeetingBookingRequirementOption O ON O.RequirementQuestionID=Q.RequirementQuestionID AND O.IsActive=1
WHERE Q.CompanyID=@company AND Q.BookingID=@booking AND Q.IsActive=1
ORDER BY Q.SortOrder,Q.RequirementQuestionID,O.SortOrder,O.RequirementOptionID;
""";
        await using (var cmd=new SqlCommand(questionSql,db))
        {
            Add(cmd,"@participant",participantId);Add(cmd,"@company",company);Add(cmd,"@booking",access.BookingId);
            await using var r=await cmd.ExecuteReaderAsync(token);
            while(await r.ReadAsync(token)) rows.Add(new(r.GetInt64(0),r.GetString(1),r.GetString(2),r.GetBoolean(3),r.GetInt32(4),Text(r,5),
                r.IsDBNull(6)?null:r.GetInt64(6),Text(r,7),r.IsDBNull(8)?null:r.GetInt32(8)));
        }
        var questions=rows.GroupBy(x=>new{x.Id,x.Text,x.Type,x.Required,x.Sort,x.Answer})
            .Select(g=>new{questionId=g.Key.Id,questionText=g.Key.Text,answerType=g.Key.Type,isRequired=g.Key.Required,
                sortOrder=g.Key.Sort,answerValue=g.Key.Answer,options=g.Where(x=>x.OptionId is not null)
                    .Select(x=>new{optionId=x.OptionId,optionText=x.OptionText,sortOrder=x.OptionSort})}).ToList();

        return Ok(new { invitation=new {participantId,access.BookingId,access.BookingNo,access.Subject,access.RoomCode,access.RoomName,
            startDateTime=access.Start,endDateTime=access.End,invitationStatus=access.Status,remark=access.Remark,
            access.ParticipantName,access.ParticipantNickName,access.OrganizerName,orderCutoffDateTime=access.Cutoff,canRespond,
            canEditPreferences,lateResponseMode,lateAcceptanceOnly,access.IsLateResponse,access.LateResponseReason,access.LateResponseAtUtc,
            requiresChangeReason=lateResponseMode||((duringMeeting||afterCutoff)&&access.Manager),responseUnavailableReason=canRespond?null:
                afterCutoff?"พ้นเวลาปิดรับแล้ว กรุณาติดต่อผู้จัดประชุมหรือผู้ดูแลห้อง":"การประชุมสิ้นสุดแล้วจึงไม่สามารถเปลี่ยนคำตอบได้"},
            groups,foods,questions});
    }

    [HttpPut("{participantId:long}")]
    public async Task<IActionResult> Save(long participantId,ParticipantResponseRequest request,CancellationToken token)
    {
        var status=request.Status?.Trim().ToUpperInvariant();
        if(status is not ("PENDING" or "ACCEPTED" or "DECLINED"))
            return BadRequest(Error("สถานะตอบรับไม่ถูกต้อง","เลือกได้เฉพาะ รอตอบรับ เข้าร่วม หรือไม่เข้าร่วม"));
        if(!Scope(out var company,out var user)) return Forbid();
        var items=(request.Items??[]).Where(x=>x.FoodId>0&&x.Quantity>0).GroupBy(x=>x.FoodId)
            .Select(x=>new ParticipantFoodItem(x.Key,x.Sum(y=>y.Quantity))).ToList();
        if(items.Any(x=>x.Quantity>99)) return BadRequest(Error("จำนวนอาหารไม่ถูกต้อง","จำนวนอาหารแต่ละรายการต้องไม่เกิน 99"));
        await using var db=await Open(token);
        if(!await Ready(db,token))return StatusCode(503,Error("ระบบตอบรับยังไม่พร้อม","กรุณาให้ผู้ดูแลระบบรัน Migration ของ Meeting ล่าสุด"));
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(IsolationLevel.Serializable,token);
        try
        {
            var access=await LoadAccess(db,participantId,company,user,token,tx,true);
            if(access is null||(!access.Own&&!access.Manager)) return Forbid();
            if(access.End<=DateTime.Now) return BadRequest(Error("ตอบรับไม่ได้","การประชุมสิ้นสุดแล้ว"));
            var now=DateTime.Now;
            var afterCutoff=access.Cutoff is not null&&access.Cutoff<=now;
            var duringMeeting=access.Start<=now&&access.End>now;
            var lateAcceptance=status=="ACCEPTED"&&access.Status!="ACCEPTED"&&duringMeeting;
            if(duringMeeting&&!access.Manager&&!lateAcceptance) return Forbid();
            if(afterCutoff&&!access.Manager&&!lateAcceptance) return Forbid();
            var reason=Clean(request.ChangeReason);
            if(reason is {Length:>500})
                return BadRequest(Error("เหตุผลยาวเกินไป","เหตุผลการตอบรับภายหลังต้องไม่เกิน 500 ตัวอักษร"));
            if((((duringMeeting||afterCutoff)&&access.Manager)||lateAcceptance)&&reason is null)
                return BadRequest(Error("กรุณาระบุเหตุผล",lateAcceptance?"การตอบรับหลังเริ่มประชุมต้องระบุเหตุผลทุกครั้ง":"การแก้ไขหลังเวลาปิดรับต้องระบุเหตุผลทุกครั้ง"));
            if(lateAcceptance&&(items.Count>0||(request.Answers?.Count??0)>0))
                return BadRequest(Error("แก้ไขอาหารหลังปิดรับไม่ได้","การตอบรับภายหลังบันทึกได้เฉพาะสถานะและเหตุผล อาหารกับความต้องการยังคงตามข้อมูลก่อนปิดรับ"));
            if(status=="ACCEPTED"&&!lateAcceptance)
            {
                var error=await ValidateAccepted(db,tx,access.BookingId,company,items,request.Answers??[],token);
                if(error is not null) return BadRequest(error);
            }
            else if(items.Count>0||(request.Answers?.Count??0)>0)
                return BadRequest(Error("ข้อมูลตอบรับไม่สอดคล้องกัน","อาหารและความต้องการบันทึกได้เมื่อเลือกเข้าร่วมเท่านั้น"));
            if(await HasReceipt(db,tx,company,participantId,token))
                return Conflict(Error("แก้ไขคำตอบไม่ได้","ผู้เข้าร่วมได้รับอาหารแล้ว กรุณาตรวจสอบรายการรับอาหาร"));

            const string historySql="""
DECLARE @food nvarchar(max)=(SELECT D.FoodID,D.Quantity,H.IsCancelled
 FROM dbo.TDADMeetingBookingFoodOrder H JOIN dbo.TDADMeetingBookingFoodOrderDetail D ON D.BookingFoodOrderID=H.BookingFoodOrderID
 WHERE H.CompanyID=@company AND H.BookingParticipantID=@participant FOR JSON PATH);
DECLARE @answers nvarchar(max)=(SELECT A.RequirementQuestionID,A.AnswerValue
 FROM dbo.TDADMeetingParticipantRequirementAnswer A WHERE A.CompanyID=@company AND A.BookingParticipantID=@participant FOR JSON PATH);
INSERT dbo.TDADMeetingParticipantResponseHistory
 (CompanyID,BookingParticipantID,PreviousStatus,NewStatus,ResponseRemark,ChangeReason,FoodSnapshot,RequirementSnapshot,ChangedByUserID)
VALUES(@company,@participant,@previous,@status,@remark,@reason,@food,@answers,@user);
UPDATE dbo.TDADMeetingRoomBookingParticipant
 SET InvitationStatus=@status,ResponseDate=CASE WHEN @status='PENDING' THEN NULL ELSE SYSUTCDATETIME() END,Remark=@remark,
     IsLateResponse=CASE WHEN @late=1 THEN 1 ELSE 0 END,
     LateResponseReason=CASE WHEN @late=1 THEN COALESCE(@lateReason,LateResponseReason) ELSE NULL END,
     LateResponseAtUtc=CASE WHEN @late=1 THEN COALESCE(LateResponseAtUtc,SYSUTCDATETIME()) ELSE NULL END
 WHERE CompanyID=@company AND BookingParticipantID=@participant;
""";
            await using(var cmd=new SqlCommand(historySql,db,tx))
            {
                var markLate=status=="ACCEPTED"&&(lateAcceptance||access.IsLateResponse);
                Add(cmd,"@company",company);Add(cmd,"@participant",participantId);Add(cmd,"@previous",access.Status);
                Add(cmd,"@status",status);Add(cmd,"@remark",Clean(request.Remark));Add(cmd,"@reason",reason);Add(cmd,"@user",user);
                Add(cmd,"@late",markLate);Add(cmd,"@lateReason",lateAcceptance?reason:access.LateResponseReason);
                await cmd.ExecuteNonQueryAsync(token);
            }
            if(!lateAcceptance)
            {
                await SaveOrder(db,tx,access,company,user,participantId,status!,reason,items,token);
                await SaveAnswers(db,tx,access.BookingId,company,user,participantId,status!,request.Answers??[],token);
            }
            await tx.CommitAsync(token);
            return Ok(new{participantId,status,itemCount=items.Count,answerCount=status=="ACCEPTED"?(request.Answers?.Count??0):0});
        }
        catch{await tx.RollbackAsync(token);throw;}
    }

    private static async Task<object?> ValidateAccepted(SqlConnection db,SqlTransaction tx,long booking,long company,
        List<ParticipantFoodItem> items,List<ParticipantRequirementAnswerRequest> answers,CancellationToken token)
    {
        var selected=items.ToDictionary(x=>x.FoodId,x=>x.Quantity);
        var totals=new Dictionary<string,int>(StringComparer.OrdinalIgnoreCase);
        const string itemSql="""
SELECT F.FoodID,F.FoodTypeCode FROM dbo.TDADMeetingBookingFoodOption O
JOIN dbo.TDADMeetingFood F ON F.FoodID=O.FoodID AND F.CompanyID=O.CompanyID
WHERE O.BookingID=@booking AND O.CompanyID=@company;
""";
        await using(var cmd=new SqlCommand(itemSql,db,tx))
        {
            Add(cmd,"@booking",booking);Add(cmd,"@company",company);var allowed=new HashSet<long>();
            await using var r=await cmd.ExecuteReaderAsync(token);
            while(await r.ReadAsync(token)){var id=r.GetInt64(0);allowed.Add(id);if(selected.TryGetValue(id,out var quantity)){var type=r.GetString(1);totals[type]=totals.GetValueOrDefault(type)+quantity;}}
            if(selected.Keys.Any(x=>!allowed.Contains(x))) return Error("มีอาหารที่ไม่ได้เปิดให้เลือก","กรุณาเลือกเฉพาะรายการอาหารของการประชุมนี้");
        }
        var configuredGroups=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        await using(var cmd=new SqlCommand("SELECT FoodTypeCode,MaxQuantity,IsRequired FROM dbo.TDADMeetingBookingFoodGroup WHERE BookingID=@booking AND CompanyID=@company AND IsActive=1",db,tx))
        {
            Add(cmd,"@booking",booking);Add(cmd,"@company",company);await using var r=await cmd.ExecuteReaderAsync(token);
            while(await r.ReadAsync(token)){var type=r.GetString(0);configuredGroups.Add(type);var total=totals.GetValueOrDefault(type);if(total>r.GetInt32(1))return Error("จำนวนอาหารเกินสิทธิ์ของกลุ่ม",$"กลุ่ม {type} เลือกได้รวมไม่เกิน {r.GetInt32(1)}");if(r.GetBoolean(2)&&total==0)return Error("ยังเลือกอาหารไม่ครบ",$"กลุ่ม {type} เป็นรายการที่ต้องเลือก");}
        }
        if(totals.Keys.Any(x=>!configuredGroups.Contains(x)))return Error("ไม่พบกติกากลุ่มอาหาร","กรุณาให้ผู้จัดประชุมตรวจสอบกลุ่มและรายการอาหารอีกครั้ง");
        var submitted=answers.GroupBy(x=>x.QuestionId).ToDictionary(x=>x.Key,x=>x.Last());
        const string questionSql="""
SELECT Q.RequirementQuestionID,Q.QuestionText,Q.AnswerType,Q.IsRequired,O.RequirementOptionID
FROM dbo.TDADMeetingBookingRequirementQuestion Q
LEFT JOIN dbo.TDADMeetingBookingRequirementOption O ON O.RequirementQuestionID=Q.RequirementQuestionID AND O.IsActive=1
WHERE Q.BookingID=@booking AND Q.CompanyID=@company AND Q.IsActive=1 ORDER BY Q.RequirementQuestionID;
""";
        var definitions=new Dictionary<long,(string Text,string Type,bool Required,HashSet<long> Options)>();
        await using(var cmd=new SqlCommand(questionSql,db,tx))
        {
            Add(cmd,"@booking",booking);Add(cmd,"@company",company);await using var r=await cmd.ExecuteReaderAsync(token);
            while(await r.ReadAsync(token)){var id=r.GetInt64(0);if(!definitions.ContainsKey(id))definitions[id]=(r.GetString(1),r.GetString(2),r.GetBoolean(3),[]);if(!r.IsDBNull(4))definitions[id].Options.Add(r.GetInt64(4));}
        }
        if(submitted.Keys.Any(x=>!definitions.ContainsKey(x))) return Error("มีคำตอบที่ไม่อยู่ในแบบฟอร์ม","กรุณาโหลดแบบฟอร์มใหม่แล้วตอบอีกครั้ง");
        foreach(var (id,d) in definitions)
        {
            submitted.TryGetValue(id,out var answer);var value=Clean(answer?.Value);var optionIds=answer?.OptionIds?.Distinct().ToList()??[];
            var empty=value is null&&optionIds.Count==0;if(d.Required&&empty)return Error("ยังตอบข้อมูลไม่ครบ",$"กรุณาตอบ: {d.Text}");if(empty)continue;
            if(d.Type=="NUMBER"&&!decimal.TryParse(value,out _))return Error("คำตอบต้องเป็นตัวเลข",d.Text);
            if(d.Type=="BOOLEAN"&&value is not ("true" or "false"))return Error("คำตอบใช่/ไม่ใช่ไม่ถูกต้อง",d.Text);
            if(d.Type is "TEXT" or "NUMBER" or "BOOLEAN" && optionIds.Count>0)return Error("รูปแบบคำตอบไม่ถูกต้อง",d.Text);
            if(d.Type=="SINGLE"&&optionIds.Count!=1)return Error("กรุณาเลือกหนึ่งตัวเลือก",d.Text);
            if(optionIds.Any(x=>!d.Options.Contains(x)))return Error("ตัวเลือกไม่ถูกต้อง",$"กรุณาเลือกคำตอบของ {d.Text} ใหม่");
        }
        return null;
    }

    private static async Task SaveOrder(SqlConnection db,SqlTransaction tx,AccessData access,long company,long user,long participant,
        string status,string? reason,List<ParticipantFoodItem> items,CancellationToken token)
    {
        long? orderId;
        await using(var find=new SqlCommand("SELECT BookingFoodOrderID FROM dbo.TDADMeetingBookingFoodOrder WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND BookingParticipantID=@participant",db,tx))
        {Add(find,"@company",company);Add(find,"@participant",participant);var value=await find.ExecuteScalarAsync(token);orderId=value is null?null:Convert.ToInt64(value);}
        if(status!="ACCEPTED"||items.Count==0)
        {
            if(orderId is not null){await using var cancel=new SqlCommand("UPDATE dbo.TDADMeetingBookingFoodOrder SET IsCancelled=1,CancelledAtUtc=SYSUTCDATETIME(),CancelledByUserID=@user,CancelReason=@reason,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE BookingFoodOrderID=@order",db,tx);Add(cancel,"@user",user);Add(cancel,"@reason",reason??"เปลี่ยนสถานะการตอบรับ");Add(cancel,"@order",orderId);await cancel.ExecuteNonQueryAsync(token);}
            return;
        }
        if(orderId is null)
        {
            await using var insert=new SqlCommand("""
INSERT dbo.TDADMeetingBookingFoodOrder(CompanyID,BookingID,BookingParticipantID,OrderedForEmployeeID,OrderedByUserID,CreateBy,IsCancelled)
VALUES(@company,@booking,@participant,@employee,@user,@user,0);SELECT CONVERT(bigint,SCOPE_IDENTITY());
""",db,tx);
            Add(insert,"@company",company);Add(insert,"@booking",access.BookingId);Add(insert,"@participant",participant);
            Add(insert,"@employee",access.EmployeeId);Add(insert,"@user",user);orderId=Convert.ToInt64(await insert.ExecuteScalarAsync(token));
        }
        else
        {
            await using var update=new SqlCommand("""
UPDATE dbo.TDADMeetingBookingFoodOrder SET IsCancelled=0,CancelledAtUtc=NULL,CancelledByUserID=NULL,CancelReason=NULL,
 OrderedByUserID=@user,UpdateDate=SYSUTCDATETIME(),UpdateBy=@user WHERE BookingFoodOrderID=@order;
DELETE dbo.TDADMeetingBookingFoodOrderDetail WHERE BookingFoodOrderID=@order;
""",db,tx);
            Add(update,"@user",user);Add(update,"@order",orderId);await update.ExecuteNonQueryAsync(token);
        }
        foreach(var item in items){await using var detail=new SqlCommand("INSERT dbo.TDADMeetingBookingFoodOrderDetail(BookingFoodOrderID,FoodID,Quantity,CreateBy) VALUES(@order,@food,@quantity,@user)",db,tx);Add(detail,"@order",orderId);Add(detail,"@food",item.FoodId);Add(detail,"@quantity",item.Quantity);Add(detail,"@user",user);await detail.ExecuteNonQueryAsync(token);}
    }

    private static async Task SaveAnswers(SqlConnection db,SqlTransaction tx,long booking,long company,long user,long participant,
        string status,List<ParticipantRequirementAnswerRequest> answers,CancellationToken token)
    {
        await using(var remove=new SqlCommand("DELETE A FROM dbo.TDADMeetingParticipantRequirementAnswer A JOIN dbo.TDADMeetingBookingRequirementQuestion Q ON Q.RequirementQuestionID=A.RequirementQuestionID WHERE A.CompanyID=@company AND A.BookingParticipantID=@participant AND Q.BookingID=@booking",db,tx))
        {Add(remove,"@company",company);Add(remove,"@participant",participant);Add(remove,"@booking",booking);await remove.ExecuteNonQueryAsync(token);}
        if(status!="ACCEPTED")return;
        foreach(var answer in answers.GroupBy(x=>x.QuestionId).Select(x=>x.Last()))
        {
            var value=answer.OptionIds is {Count:>0}?JsonSerializer.Serialize(answer.OptionIds.Distinct().OrderBy(x=>x)):Clean(answer.Value);
            if(value is null)continue;
            await using var insert=new SqlCommand("INSERT dbo.TDADMeetingParticipantRequirementAnswer(CompanyID,BookingParticipantID,RequirementQuestionID,AnswerValue,AnsweredByUserID,CreateBy) VALUES(@company,@participant,@question,@value,@user,@user)",db,tx);
            Add(insert,"@company",company);Add(insert,"@participant",participant);Add(insert,"@question",answer.QuestionId);Add(insert,"@value",value);Add(insert,"@user",user);await insert.ExecuteNonQueryAsync(token);
        }
    }

    private static async Task<bool> HasReceipt(SqlConnection db,SqlTransaction tx,long company,long participant,CancellationToken token)
    {
        const string sql="""
SELECT CASE WHEN OBJECT_ID(N'dbo.TDADMeetingFoodReceipt',N'U') IS NOT NULL AND EXISTS
(SELECT 1 FROM dbo.TDADMeetingBookingFoodOrder H JOIN dbo.TDADMeetingBookingFoodOrderDetail D ON D.BookingFoodOrderID=H.BookingFoodOrderID
 JOIN dbo.TDADMeetingFoodReceipt R ON R.BookingFoodOrderDetailID=D.BookingFoodOrderDetailID AND R.CompanyID=H.CompanyID
 WHERE H.CompanyID=@company AND H.BookingParticipantID=@participant) THEN 1 ELSE 0 END;
""";
        await using var cmd=new SqlCommand(sql,db,tx);Add(cmd,"@company",company);Add(cmd,"@participant",participant);return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }

    private static async Task<AccessData?> LoadAccess(SqlConnection db,long participant,long company,long user,CancellationToken token,
        SqlTransaction? tx=null,bool lockRow=false)
    {
        var hint=lockRow?"WITH(UPDLOCK,HOLDLOCK)":"";
        var sql=$"""
SELECT P.BookingID,P.EmployeeID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,MIN(S.StartDateTime),MAX(S.EndDateTime),
 P.InvitationStatus,P.Remark,PE.FullName,PE.NickName,RE.FullName,FP.OrderCutoffDateTime,
 CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE WHERE UE.UserID=@user AND UE.CompanyID=@company AND UE.EmployeeID=P.EmployeeID AND UE.IsActive=1) THEN 1 ELSE 0 END,
 CASE WHEN B.RequesterUserID=@user
  OR EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1)
  OR EXISTS(SELECT 1 FROM dbo.TDADMeetingRoomContact C JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=C.EmployeeID AND UE.CompanyID=@company AND UE.UserID=@user AND UE.IsActive=1 WHERE C.RoomID=B.RoomID AND C.IsActive=1)
 THEN 1 ELSE 0 END,
 P.IsLateResponse,P.LateResponseReason,P.LateResponseAtUtc
FROM dbo.TDADMeetingRoomBookingParticipant P {hint}
JOIN dbo.TDADMeetingRoomBooking B ON B.BookingID=P.BookingID AND B.CompanyID=P.CompanyID AND B.BookingStatus='APPROVED'
JOIN dbo.TDADMeetingRoom R ON R.RoomID=B.RoomID AND R.CompanyID=B.CompanyID
JOIN dbo.TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID AND S.CompanyID=B.CompanyID
JOIN dbo.TDADEmployee PE ON PE.EmployeeID=P.EmployeeID AND PE.CompanyID=P.CompanyID
LEFT JOIN dbo.TDADUserEmployee RUE ON RUE.UserID=B.RequesterUserID AND RUE.CompanyID=B.CompanyID AND RUE.IsActive=1
LEFT JOIN dbo.TDADEmployee RE ON RE.EmployeeID=COALESCE(B.RequesterEmployeeID,RUE.EmployeeID) AND RE.CompanyID=B.CompanyID
LEFT JOIN dbo.TDADMeetingBookingFoodPlan FP ON FP.BookingID=B.BookingID AND FP.CompanyID=B.CompanyID AND FP.IsActive=1
WHERE P.BookingParticipantID=@participant AND P.CompanyID=@company
GROUP BY P.BookingID,P.EmployeeID,B.BookingNo,B.Subject,R.RoomCode,R.RoomNameTH,P.InvitationStatus,P.Remark,PE.FullName,PE.NickName,RE.FullName,
 FP.OrderCutoffDateTime,B.RequesterUserID,B.RoomID,P.IsLateResponse,P.LateResponseReason,P.LateResponseAtUtc;
""";
        await using var cmd=new SqlCommand(sql,db,tx);Add(cmd,"@participant",participant);Add(cmd,"@company",company);Add(cmd,"@user",user);
        await using var r=await cmd.ExecuteReaderAsync(token);if(!await r.ReadAsync(token))return null;
        return new(r.GetInt64(0),r.GetInt64(1),Text(r,2),r.GetString(3),r.GetString(4),r.GetString(5),r.GetDateTime(6),r.GetDateTime(7),
            r.GetString(8),Text(r,9),Text(r,10),Text(r,11),Text(r,12),Date(r,13),r.GetInt32(14)==1,r.GetInt32(15)==1,
            r.GetBoolean(16),Text(r,17),Date(r,18));
    }

    private bool Scope(out long company,out long user)
    {
        company=0;user=0;return long.TryParse(User.FindFirstValue("company_id"),out company)&&company>0
            &&long.TryParse(User.FindFirstValue("user_id"),out user)&&user>0
            &&string.Equals(User.FindFirstValue("user_type"),"COMPANY_USER",StringComparison.OrdinalIgnoreCase);
    }
    private static async Task<bool> Ready(SqlConnection db,CancellationToken token)
    {
        await using var cmd=new SqlCommand("""
SELECT CASE WHEN OBJECT_ID(N'dbo.TDADMeetingBookingFoodGroup',N'U') IS NOT NULL
 AND OBJECT_ID(N'dbo.TDADMeetingBookingRequirementQuestion',N'U') IS NOT NULL
 AND OBJECT_ID(N'dbo.TDADMeetingParticipantRequirementAnswer',N'U') IS NOT NULL
 AND OBJECT_ID(N'dbo.TDADMeetingParticipantResponseHistory',N'U') IS NOT NULL
 AND COL_LENGTH(N'dbo.TDADMeetingBookingFoodOrder',N'IsCancelled') IS NOT NULL
 AND COL_LENGTH(N'dbo.TDADMeetingRoomBookingParticipant',N'IsLateResponse') IS NOT NULL
 AND COL_LENGTH(N'dbo.TDADMeetingRoomBookingParticipant',N'LateResponseReason') IS NOT NULL
 AND COL_LENGTH(N'dbo.TDADMeetingRoomBookingParticipant',N'LateResponseAtUtc') IS NOT NULL
 THEN 1 ELSE 0 END;
""",db);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }
    private async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    private static object Error(string message,string description)=>new{message,description};
    private static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
    private static string? Text(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetString(i);
    private static DateTime? Date(SqlDataReader r,int i)=>r.IsDBNull(i)?null:r.GetDateTime(i);
    private static void Add(SqlCommand cmd,string name,object? value)=>cmd.Parameters.AddWithValue(name,value??DBNull.Value);
}

public sealed record ParticipantResponseRequest(string? Status,string? Remark,string? ChangeReason,List<ParticipantFoodItem>? Items,List<ParticipantRequirementAnswerRequest>? Answers);
public sealed record ParticipantFoodItem(long FoodId,int Quantity);
public sealed record ParticipantRequirementAnswerRequest(long QuestionId,string? Value,List<long>? OptionIds);
internal sealed record AccessData(long BookingId,long EmployeeId,string? BookingNo,string Subject,string RoomCode,string RoomName,
 DateTime Start,DateTime End,string Status,string? Remark,string? ParticipantName,string? ParticipantNickName,string? OrganizerName,DateTime? Cutoff,bool Own,bool Manager,
 bool IsLateResponse,string? LateResponseReason,DateTime? LateResponseAtUtc);
internal sealed record QuestionRow(long Id,string Text,string Type,bool Required,int Sort,string? Answer,long? OptionId,string? OptionText,int? OptionSort);
