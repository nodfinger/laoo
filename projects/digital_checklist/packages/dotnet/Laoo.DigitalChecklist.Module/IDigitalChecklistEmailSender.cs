namespace Laoo.DigitalChecklist;

public interface IDigitalChecklistEmailSender
{
    Task<bool> SendToCompanyUserAsync(long companyId, long userId, string subject, string body, CancellationToken cancellationToken);
}
