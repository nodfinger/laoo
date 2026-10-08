using System.Net;
using System.Net.Mail;
using Laoo.DigitalChecklist;
using LaooApi.Data;
using LaooApi.Security;
using Microsoft.Data.SqlClient;

namespace LaooApi.Services;

public sealed class DigitalChecklistEmailSender(SqlConnectionFactory connections, CompanySetupSecretService secrets) : IDigitalChecklistEmailSender
{
    public async Task<bool> SendToCompanyUserAsync(long companyId, long userId, string subject, string body, CancellationToken cancellationToken)
    {
        await using var connection = connections.CreateConnection();
        await connection.OpenAsync(cancellationToken);
        const string sql = """
            SELECT TOP(1) COALESCE(NULLIF(U.Email,N''),E.Email),C.EmailHost,C.EmailPort,C.EmailCenter,C.EmailPasswordCenter
            FROM dbo.TDADUser U
            JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.IsActive=1
            OUTER APPLY(SELECT TOP(1) E0.Email FROM dbo.TDADUserEmployee UE JOIN dbo.TDADEmployee E0 ON E0.CompanyID=UE.CompanyID AND E0.EmployeeID=UE.EmployeeID AND E0.IsActive=1 WHERE UE.CompanyID=U.CompanyID AND UE.UserID=U.UserID AND UE.IsActive=1) E
            WHERE U.CompanyID=@company AND U.UserID=@user AND U.IsActive=1;
            """;
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@company", companyId);
        command.Parameters.AddWithValue("@user", userId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return false;
        var recipient = reader.IsDBNull(0) ? null : reader.GetString(0);
        var host = reader.IsDBNull(1) ? null : reader.GetString(1);
        var port = reader.IsDBNull(2) ? 587 : reader.GetInt32(2);
        var sender = reader.IsDBNull(3) ? null : reader.GetString(3);
        var password = secrets.Unprotect(reader.IsDBNull(4) ? null : reader.GetString(4));
        await reader.DisposeAsync();
        if (string.IsNullOrWhiteSpace(recipient) || string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(sender) || string.IsNullOrWhiteSpace(password)) return false;
        using var mail = new MailMessage(sender, recipient, subject, body);
        using var smtp = new SmtpClient(host, port) { EnableSsl = true, Credentials = new NetworkCredential(sender, password) };
        await smtp.SendMailAsync(mail, cancellationToken);
        return true;
    }
}
