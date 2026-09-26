using Laoo.Shared.Contracts.Evaluations;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooEvaluationModule.Services;

public sealed class EvaluationSourceCompletedPublisher(IConfiguration configuration) : IEvaluationSourceCompletedPublisher
{
    public async Task PublishAsync(EvaluationSourceCompletedContract source,CancellationToken token=default)
    {
        if(source.CompanyId<=0||source.ReferenceEntityId<=0||string.IsNullOrWhiteSpace(source.SourceProjectCode)||string.IsNullOrWhiteSpace(source.SourceType)||source.RespondentUserIds.Count==0)return;
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);
        object? template;
        if(source.EvaluationTemplateId is long selectedTemplate)
        {
            var selected=new SqlCommand("SELECT EvaluationTemplateID FROM dbo.TDEVTemplate WHERE CompanyID=@c AND EvaluationTemplateID=@template AND IsActive=1 AND SourceType=@source",db);
            selected.Parameters.AddWithValue("@c",source.CompanyId);selected.Parameters.AddWithValue("@template",selectedTemplate);selected.Parameters.AddWithValue("@source",source.SourceType.Trim().ToUpperInvariant());
            template=await selected.ExecuteScalarAsync(token);
        }
        else
        {
            var setting=new SqlCommand("SELECT S.DefaultEvaluationTemplateID FROM dbo.TDEVSystemSetting S JOIN dbo.TDEVTemplate T ON T.CompanyID=S.CompanyID AND T.EvaluationTemplateID=S.DefaultEvaluationTemplateID AND T.IsActive=1 AND T.SourceType=S.SourceType WHERE S.CompanyID=@c AND S.SourceType=@source AND S.IsActive=1",db);setting.Parameters.AddWithValue("@c",source.CompanyId);setting.Parameters.AddWithValue("@source",source.SourceType.Trim().ToUpperInvariant());template=await setting.ExecuteScalarAsync(token);
        }
        if(template is null)return;
        await using var tx=(SqlTransaction)await db.BeginTransactionAsync(token);
        var duplicate=new SqlCommand("SELECT TOP(1) EvaluationRoundID FROM dbo.TDEVRound WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@c AND SourceProjectCode=@project AND SourceType=@source AND ReferenceEntityID=@reference",db,tx);duplicate.Parameters.AddWithValue("@c",source.CompanyId);duplicate.Parameters.AddWithValue("@project",source.SourceProjectCode.Trim().ToUpperInvariant());duplicate.Parameters.AddWithValue("@source",source.SourceType.Trim().ToUpperInvariant());duplicate.Parameters.AddWithValue("@reference",source.ReferenceEntityId);if(await duplicate.ExecuteScalarAsync(token)is not null){foreach(var user in source.RespondentUserIds.Distinct())await EnsureMyEvaluationAccess(db,tx,source.CompanyId,user,token);await tx.CommitAsync(token);return;}
        var snapshot=await Snapshot(db,tx,source.CompanyId,Convert.ToInt64(template),token);if(snapshot=="""{"questions":[]}"""){await tx.RollbackAsync(token);return;}
        var no="EV"+DateTime.UtcNow.ToString("yyyyMMddHHmmss")+Guid.NewGuid().ToString("N")[..4].ToUpperInvariant();var title=source.ReferenceTitleSnapshot.Trim();var name=(title+" - แบบประเมิน")[..Math.Min(200,title.Length+13)];
        var round=new SqlCommand("INSERT dbo.TDEVRound(CompanyID,RoundNo,RoundName,SourceType,SourceProjectCode,ReferenceEntityID,ReferenceTitleSnapshot,EvaluationTemplateID,TemplateSnapshotJson,OpenDateTime,CloseDateTime) VALUES(@c,@no,@name,@source,@project,@reference,@title,@template,@snapshot,@open,@close); SELECT CONVERT(bigint,SCOPE_IDENTITY());",db,tx);round.Parameters.AddWithValue("@c",source.CompanyId);round.Parameters.AddWithValue("@no",no);round.Parameters.AddWithValue("@name",name);round.Parameters.AddWithValue("@source",source.SourceType.Trim().ToUpperInvariant());round.Parameters.AddWithValue("@project",source.SourceProjectCode.Trim().ToUpperInvariant());round.Parameters.AddWithValue("@reference",source.ReferenceEntityId);round.Parameters.AddWithValue("@title",title);round.Parameters.AddWithValue("@template",template);round.Parameters.AddWithValue("@snapshot",snapshot);round.Parameters.AddWithValue("@open",source.CompletedAtUtc);round.Parameters.AddWithValue("@close",source.CompletedAtUtc.AddDays(14));var id=Convert.ToInt64(await round.ExecuteScalarAsync(token));
        var target=new SqlCommand("INSERT dbo.TDEVRoundTargetReference(CompanyID,EvaluationRoundID,TargetType,TargetEntityID,TargetNameSnapshot) VALUES(@c,@round,@type,@entity,@name)",db,tx);target.Parameters.AddWithValue("@c",source.CompanyId);target.Parameters.AddWithValue("@round",id);target.Parameters.AddWithValue("@type",source.SourceType.Trim().ToUpperInvariant());target.Parameters.AddWithValue("@entity",source.ReferenceEntityId);target.Parameters.AddWithValue("@name",title);await target.ExecuteNonQueryAsync(token);
        foreach(var user in source.RespondentUserIds.Distinct()){var respondent=new SqlCommand("INSERT dbo.TDEVRoundRespondent(CompanyID,EvaluationRoundID,UserID,EmployeeID) SELECT @c,@round,U.UserID,UE.EmployeeID FROM dbo.TDADUser U LEFT JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=U.CompanyID AND UE.UserID=U.UserID AND UE.IsActive=1 WHERE U.CompanyID=@c AND U.UserID=@user AND U.IsActive=1",db,tx);respondent.Parameters.AddWithValue("@c",source.CompanyId);respondent.Parameters.AddWithValue("@round",id);respondent.Parameters.AddWithValue("@user",user);await respondent.ExecuteNonQueryAsync(token);await EnsureMyEvaluationAccess(db,tx,source.CompanyId,user,token);}await tx.CommitAsync(token);
    }

    static async Task EnsureMyEvaluationAccess(SqlConnection db,SqlTransaction tx,long company,long user,CancellationToken token)
    {
        const string sql="""
DECLARE @project bigint=(SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode='LAOO_EVALUATION' AND IsActive=1);
IF @project IS NULL RETURN;
IF NOT EXISTS(SELECT 1 FROM dbo.TDADUserProject WHERE CompanyID=@company AND UserID=@user AND ProjectID=@project)
    INSERT dbo.TDADUserProject(CompanyID,UserID,ProjectID,IsDefault,IsActive) VALUES(@company,@user,@project,0,1);
INSERT dbo.TDADUserPermission(UserID,ProjectID,PermissionID,IsAllowed,IsActive,Remark)
SELECT @user,@project,P.PermissionID,1,1,N'Automatic evaluation assignment'
FROM dbo.TDADPermission P
WHERE P.ProjectID=@project AND P.IsActive=1 AND P.ScreenCode='47005' AND P.ActionCode IN('VIEW','SUBMIT')
  AND NOT EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.PermissionID=P.PermissionID);
""";
        await using var cmd=new SqlCommand(sql,db,tx);
        cmd.Parameters.AddWithValue("@company",company);
        cmd.Parameters.AddWithValue("@user",user);
        await cmd.ExecuteNonQueryAsync(token);
    }

    static async Task<string> Snapshot(SqlConnection db,SqlTransaction tx,long company,long template,CancellationToken token){var cmd=new SqlCommand("SELECT Q.EvaluationTemplateQuestionID,Q.QuestionText,Q.QuestionType,Q.IsRequired,Q.SortOrder,O.EvaluationTemplateQuestionOptionID,O.OptionText,O.SortOrder FROM dbo.TDEVTemplateQuestion Q LEFT JOIN dbo.TDEVTemplateQuestionOption O ON O.EvaluationTemplateQuestionID=Q.EvaluationTemplateQuestionID WHERE Q.CompanyID=@c AND Q.EvaluationTemplateID=@template ORDER BY Q.SortOrder,O.SortOrder",db,tx);cmd.Parameters.AddWithValue("@c",company);cmd.Parameters.AddWithValue("@template",template);await using var r=await cmd.ExecuteReaderAsync(token);var list=new List<Dictionary<string,object?>>();var map=new Dictionary<long,Dictionary<string,object?>>();while(await r.ReadAsync(token)){var id=r.GetInt64(0);if(!map.TryGetValue(id,out var q)){q=new Dictionary<string,object?>{{"id",$"Q-{id}"},{"text",r.GetString(1)},{"type",r.GetString(2)},{"required",r.GetBoolean(3)},{"sortOrder",r.GetInt32(4)},{"options",new List<object>()}};map.Add(id,q);list.Add(q);}if(!r.IsDBNull(5))((List<object>)q["options"]!).Add(new{id=$"O-{r.GetInt64(5)}",text=r.GetString(6),sortOrder=r.GetInt32(7)});}return System.Text.Json.JsonSerializer.Serialize(new{questions=list});}
}
