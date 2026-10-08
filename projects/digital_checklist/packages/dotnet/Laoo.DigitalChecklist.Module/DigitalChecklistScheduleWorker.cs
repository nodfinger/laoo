using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Laoo.DigitalChecklist;

public sealed class DigitalChecklistScheduleWorker(IConfiguration configuration, ILogger<DigitalChecklistScheduleWorker> logger, IDigitalChecklistEmailSender emailSender) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
        do
        {
            try { await GenerateAsync(stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogError(ex, "Digital Checklist รอบตรวจทำงานไม่สำเร็จ"); }
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task GenerateAsync(CancellationToken cancellationToken)
    {
        var connectionString = configuration.GetConnectionString("LaooDatabase");
        if (string.IsNullOrWhiteSpace(connectionString)) return;
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        const string sql = """
            IF OBJECT_ID(N'dbo.TDCLSchedule',N'U') IS NULL RETURN;
            SET DATEFIRST 1;
            DECLARE @utc datetime2=SYSUTCDATETIME();
            DECLARE @today date=CONVERT(date,@utc AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time');
            WITH Slots AS
            (
              SELECT S.CompanyID,S.ScheduleID,S.TypeID,G.DepartmentOrgUnitID,S.ResponsibleEmployeeID,U.UserID,
                TRY_CONVERT(time(0),J.value) AS Slot,
                CONVERT(datetime2,DATEADD(second,DATEDIFF(second,CONVERT(time(0),'00:00'),TRY_CONVERT(time(0),J.value)),CONVERT(datetime2,@today)) AT TIME ZONE 'SE Asia Standard Time' AT TIME ZONE 'UTC') AS DueAt
              FROM dbo.TDCLSchedule S
              JOIN dbo.TDCLType T ON T.CompanyID=S.CompanyID AND T.TypeID=S.TypeID AND T.IsActive=1
              JOIN dbo.TDCLGroup G ON G.CompanyID=T.CompanyID AND G.GroupID=T.GroupID AND G.IsActive=1
              JOIN dbo.TDADUserEmployee U ON U.CompanyID=S.CompanyID AND U.EmployeeID=S.ResponsibleEmployeeID AND U.IsActive=1
              CROSS APPLY OPENJSON(S.TimesJson) J
              WHERE S.IsActive=1 AND S.StartsOn<=@today AND (S.EndsOn IS NULL OR S.EndsOn>=@today)
                AND TRY_CONVERT(time(0),J.value) IS NOT NULL
                AND (S.FrequencyCode='DAILY'
                  OR (S.FrequencyCode='WEEKLY' AND EXISTS(SELECT 1 FROM OPENJSON(COALESCE(S.WeekDaysJson,N'[1]')) D WHERE TRY_CONVERT(int,D.value)=DATEPART(weekday,@today)))
                  OR (S.FrequencyCode='MONTHLY' AND DAY(@today)=COALESCE(S.MonthDay,DAY(S.StartsOn)))
                  OR (S.FrequencyCode='YEARLY' AND MONTH(@today)=COALESCE(S.YearMonth,MONTH(S.StartsOn)) AND DAY(@today)=COALESCE(S.MonthDay,DAY(S.StartsOn))))
            )
            MERGE dbo.TDCLInspection WITH(HOLDLOCK) AS Target
            USING (SELECT *,CONCAT(N'DCL-',ScheduleID,N'-',CONVERT(char(8),@today,112),N'-',REPLACE(CONVERT(char(5),Slot,108),N':',N'')) AS Code FROM Slots) AS Source
              ON Target.CompanyID=Source.CompanyID AND Target.ScheduleID=Source.ScheduleID AND Target.DueAt=Source.DueAt
            WHEN NOT MATCHED THEN INSERT(CompanyID,ScheduleID,TypeID,DepartmentOrgUnitID,InspectionCode,DueAt,StatusCode,CreatedBy)
              VALUES(Source.CompanyID,Source.ScheduleID,Source.TypeID,Source.DepartmentOrgUnitID,Source.Code,Source.DueAt,'DUE',Source.UserID);
            INSERT dbo.TDCLNotification(CompanyID,UserID,InspectionID,NoticeCode,NoticeKey,Message)
              SELECT I.CompanyID,I.CreatedBy,I.InspectionID,'INSPECTION_REMINDER',CONCAT(N'REMINDER:',I.InspectionID),CONCAT(N'ใกล้ถึงเวลาตรวจ ',I.InspectionCode)
              FROM dbo.TDCLInspection I LEFT JOIN dbo.TDCLSetting S ON S.CompanyID=I.CompanyID
              WHERE I.StatusCode='DUE' AND I.DueAt>@utc AND COALESCE(S.ReminderMinutes,60)>0 AND I.DueAt<=DATEADD(minute,COALESCE(S.ReminderMinutes,60),@utc)
                AND (S.CompanyID IS NULL OR S.NotifyInApp=1 OR S.NotifyEmail=1)
                AND NOT EXISTS(SELECT 1 FROM dbo.TDCLNotification N WHERE N.CompanyID=I.CompanyID AND N.UserID=I.CreatedBy AND N.NoticeKey=CONCAT(N'REMINDER:',I.InspectionID));
            INSERT dbo.TDCLNotification(CompanyID,UserID,InspectionID,NoticeCode,NoticeKey,Message)
              SELECT I.CompanyID,I.CreatedBy,I.InspectionID,'INSPECTION_DUE',CONCAT(N'DUE:',I.InspectionID),CONCAT(N'ถึงเวลาตรวจ ',I.InspectionCode)
              FROM dbo.TDCLInspection I LEFT JOIN dbo.TDCLSetting S ON S.CompanyID=I.CompanyID
              WHERE I.StatusCode IN('DUE','OVERDUE') AND I.DueAt<=@utc AND (S.CompanyID IS NULL OR S.NotifyInApp=1 OR S.NotifyEmail=1)
                AND NOT EXISTS(SELECT 1 FROM dbo.TDCLNotification N WHERE N.CompanyID=I.CompanyID AND N.UserID=I.CreatedBy AND N.NoticeKey=CONCAT(N'DUE:',I.InspectionID));
            UPDATE I SET StatusCode='OVERDUE' FROM dbo.TDCLInspection I WHERE I.StatusCode='DUE' AND I.DueAt<DATEADD(day,-1,@utc);
            """;
        await using var command = new SqlCommand(sql, connection) { CommandTimeout = 60 };
        await command.ExecuteNonQueryAsync(cancellationToken);
        await DeliverEmailNotificationsAsync(connection, cancellationToken);
    }

    private async Task DeliverEmailNotificationsAsync(SqlConnection connection, CancellationToken cancellationToken)
    {
        await using (var exists = new SqlCommand("SELECT CASE WHEN OBJECT_ID(N'dbo.TDCLNotification',N'U') IS NULL THEN 0 ELSE 1 END", connection))
            if (Convert.ToInt32(await exists.ExecuteScalarAsync(cancellationToken)) == 0) return;
        const string select = "SELECT TOP(30) N.NotificationID,N.CompanyID,N.UserID,N.Message FROM dbo.TDCLNotification N JOIN dbo.TDCLSetting S ON S.CompanyID=N.CompanyID AND S.NotifyEmail=1 WHERE N.SentAt IS NULL ORDER BY N.CreatedAt,N.NotificationID";
        await using var command = new SqlCommand(select, connection);
        var pending = new List<(long Id, long Company, long User, string Message)>();
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
            while (await reader.ReadAsync(cancellationToken)) pending.Add((reader.GetInt64(0), reader.GetInt64(1), reader.GetInt64(2), reader.GetString(3)));
        foreach (var notice in pending)
        {
            try
            {
                if (!await emailSender.SendToCompanyUserAsync(notice.Company, notice.User, "Laoo - แจ้งเตือนตรวจสอบดิจิทัล", notice.Message, cancellationToken)) continue;
                await using var update = new SqlCommand("UPDATE dbo.TDCLNotification SET SentAt=SYSUTCDATETIME() WHERE NotificationID=@id AND CompanyID=@company AND SentAt IS NULL", connection);
                update.Parameters.AddWithValue("@id", notice.Id); update.Parameters.AddWithValue("@company", notice.Company);
                await update.ExecuteNonQueryAsync(cancellationToken);
            }
            catch (Exception ex) { logger.LogWarning(ex, "ส่งอีเมล Digital Checklist ไม่สำเร็จ; NotificationID={NotificationId}", notice.Id); }
        }
    }
}
