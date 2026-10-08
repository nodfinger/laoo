using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.DigitalChecklist.Controllers;

public sealed partial class DigitalChecklistController
{
    [HttpPost("corrective/{id:long}/handoff")]
    public async Task<IActionResult> HandoffRequest(long id, CancellationToken ct)
    {
        try { return await Handoff(id, ct); }
        catch (SqlException error) when (error.Number == 58016)
        {
            return Conflict(new { message = "งานนี้ส่งแจ้งซ่อมแล้ว หรือไม่อยู่ในขอบเขตที่คุณจัดการได้" });
        }
    }
}
