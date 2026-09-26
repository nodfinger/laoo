using Laoo.Shared.Contracts.Evaluations;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace LaooMeetingApi.Services;

public sealed class MeetingEvaluationCompletionWorker(
    IConfiguration configuration,
    IServiceScopeFactory scopes,
    ILogger<MeetingEvaluationCompletionWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken token)
    {
        while(!token.IsCancellationRequested)
        {
            try
            {
                await PublishCompletedAsync(token);
            }
            catch(Exception exception) when(!token.IsCancellationRequested)
            {
                logger.LogError(exception,"Unable to create evaluation drafts for completed meeting bookings");
            }

            await Task.Delay(TimeSpan.FromMinutes(5),token);
        }
    }

    async Task PublishCompletedAsync(CancellationToken token)
    {
        using var scope=scopes.CreateScope();
        var publisher=scope.ServiceProvider.GetRequiredService<IEvaluationSourceCompletedPublisher>();
        await using var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);
        const string sql="""SELECT B.CompanyID,B.BookingID,B.BookingNo,B.Subject,E.EvaluationSourceType,E.EvaluationTemplateID,MAX(S.EndDateTime) CompletedAt FROM dbo.TDADMeetingRoomBooking B JOIN dbo.TDADMeetingRoomBookingSlot S ON S.CompanyID=B.CompanyID AND S.BookingID=B.BookingID JOIN dbo.TDADMeetingRoomBookingEvaluation E ON E.CompanyID=B.CompanyID AND E.BookingID=B.BookingID AND E.IsActive=1 WHERE B.BookingStatus='APPROVED' GROUP BY B.CompanyID,B.BookingID,B.BookingNo,B.Subject,E.EvaluationSourceType,E.EvaluationTemplateID HAVING MAX(S.EndDateTime)<=SYSUTCDATETIME();""";
        await using var cmd=new SqlCommand(sql,db);await using var rows=await cmd.ExecuteReaderAsync(token);var completed=new List<(long Company,long Booking,string Title,string Source,long Template,DateTime End)>();while(await rows.ReadAsync(token))completed.Add((rows.GetInt64(0),rows.GetInt64(1),$"{rows.GetString(2)} | {rows.GetString(3)}",rows.GetString(4),rows.GetInt64(5),rows.GetDateTime(6)));await rows.DisposeAsync();
        foreach(var item in completed){var userIds=await Respondents(db,item.Company,item.Booking,token);if(userIds.Count==0)continue;var project=item.Source==EvaluationSourceTypes.MeetingRoom?"LAOO_MEETING":"LAOO_TRAINING";await publisher.PublishAsync(new(item.Company,project,item.Source,item.Booking,item.Title,item.End.ToUniversalTime(),userIds,item.Template),token);}
    }

    static async Task<List<long>> Respondents(SqlConnection db,long company,long booking,CancellationToken token)
    {
        const string sql="""SELECT DISTINCT UE.UserID FROM dbo.TDADMeetingRoomBookingParticipant P JOIN dbo.TDADMeetingParticipantCheckIn C ON C.CompanyID=P.CompanyID AND C.BookingParticipantID=P.BookingParticipantID JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=P.CompanyID AND UE.EmployeeID=P.EmployeeID AND UE.IsActive=1 JOIN dbo.TDADUser U ON U.CompanyID=UE.CompanyID AND U.UserID=UE.UserID AND U.IsActive=1 WHERE P.CompanyID=@company AND P.BookingID=@booking AND P.InvitationStatus='ACCEPTED';""";
        await using var cmd=new SqlCommand(sql,db);cmd.Parameters.AddWithValue("@company",company);cmd.Parameters.AddWithValue("@booking",booking);await using var rows=await cmd.ExecuteReaderAsync(token);var ids=new List<long>();while(await rows.ReadAsync(token))ids.Add(rows.GetInt64(0));return ids;
    }
}
