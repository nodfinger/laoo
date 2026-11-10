using System.Text.Json;
using LaooApi.Services.Assistant;
using LaooMeetingApi.Controllers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/assistant/meeting")]
public sealed class AssistantMeetingController(IConfiguration configuration) : ControllerBase
{
    private async Task<bool> Allowed(string code, CancellationToken token)
    {
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        return await AssistantCapabilityAccess.IsAllowed(db, User, code, token);
    }

    [HttpGet("bookings")]
    public async Task<IActionResult> Bookings(CancellationToken token)
    {
        if (!await Allowed(AssistantCapabilities.MeetingOwnBookings.Id, token)) return Forbid();
        var controller = new MeetingRoomBookingController(configuration) { ControllerContext = ControllerContext };
        return await controller.List(null, null, null, true, 1, 20, token);
    }

    [HttpGet("invitations")]
    public async Task<IActionResult> Invitations(CancellationToken token)
    {
        if (!await Allowed(AssistantCapabilities.MeetingInvitations.Id, token)) return Forbid();
        var controller = new MeetingInvitationController(configuration) { ControllerContext = ControllerContext };
        var response = await controller.List(null, null, 1, 100, token);
        if (response is not OkObjectResult ok) return response;
        // The source API permits company administrators to list other people's invitations.
        // This assistant capability is deliberately limited to the signed-in employee.
        var root = JsonSerializer.SerializeToElement(ok.Value);
        var items = root.GetProperty("items").EnumerateArray()
            .Where(x => x.TryGetProperty("canRespond", out var own) && own.ValueKind == JsonValueKind.True)
            .Take(20).Select(x => new { subject = x.GetProperty("subject").GetString(),
                roomName = x.GetProperty("roomName").GetString(),
                startDateTime = x.GetProperty("startDateTime").GetDateTime(),
                endDateTime = x.GetProperty("endDateTime").GetDateTime(),
                invitationStatus = x.GetProperty("invitationStatus").GetString() }).ToArray();
        return Ok(new { items });
    }

    public sealed record AvailabilityInput(DateTime Start, DateTime End);
    [HttpPost("availability")]
    public async Task<IActionResult> Availability(AvailabilityInput request, CancellationToken token)
    {
        if (!await Allowed(AssistantCapabilities.MeetingAvailability.Id, token)) return Forbid();
        if (request.Start >= request.End || request.Start.Date != request.End.Date)
            return BadRequest(new { message = "กรุณาระบุวันและเวลาเริ่มต้นและสิ้นสุดในวันเดียวกัน" });
        var controller = new MeetingRoomBookingController(configuration) { ControllerContext = ControllerContext };
        var result = await controller.Availability(new AvailabilityRequest(
            [new BookingSlotRequest(request.Start, request.End)], null, null, null, null, null, null), token);
        if (result is not OkObjectResult ok) return result;
        var rows = JsonSerializer.SerializeToElement(ok.Value).EnumerateArray()
            .Where(x => x.GetProperty("isAvailable").GetBoolean())
            .Take(20).Select(x => new { roomName = x.GetProperty("RoomNameTh").GetString() }).ToArray();
        return Ok(new { items = rows });
    }
}
