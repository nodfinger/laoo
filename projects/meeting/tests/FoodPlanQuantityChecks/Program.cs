using System.Security.Claims;
using System.Text.Json;
using LaooMeetingApi.Controllers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;

var jsonOptions = new JsonSerializerOptions(JsonSerializerDefaults.Web);
var request = JsonSerializer.Deserialize<FoodPlanRequest>(
    """{"orderCutoffDateTime":"2030-01-01T10:00:00","isActive":true,"groups":[{"foodTypeCode":"RICE","maxQuantity":1,"isRequired":true,"foodIds":[11,12]},{"foodTypeCode":"DRINK","maxQuantity":2,"isRequired":false,"foodIds":[21,22]}],"questions":[{"questionText":"แพ้อาหารหรือไม่","answerType":"BOOLEAN","isRequired":true,"sortOrder":1,"options":[]}]}""",
    jsonOptions)!;
Check(request.Groups is { Count:2 } && request.Groups[1].MaxQuantity==2 && request.Groups[0].IsRequired,
    "JSON group limits and required flag deserialize");
var legacy = JsonSerializer.Deserialize<FoodPlanRequest>(
    """{"orderCutoffDateTime":"2030-01-01T10:00:00","foodIds":[11],"isActive":true}""",
    jsonOptions)!;
Check(legacy.Groups is null, "Legacy payload is identifiable before database access");

var controller = new MeetingFoodPlanController(new ConfigurationBuilder().Build())
{
    ControllerContext = new ControllerContext
    {
        HttpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim("company_id", "1"),
                new Claim("user_id", "1"),
                new Claim("user_type", "COMPANY_USER"),
            }, "test")),
        },
    },
};
Check(await controller.Save(1,legacy,default) is BadRequestObjectResult,
    "API rejects legacy per-item quantity contract before database access");
foreach (var (label, groups) in new[]
{
    ("zero quota", new List<FoodGroupRequest>{new("RICE",0,true,[11])}),
    ("quota over 99", new List<FoodGroupRequest>{new("RICE",100,true,[11])}),
    ("empty group", new List<FoodGroupRequest>{new("RICE",1,true,[])}),
    ("duplicate group", new List<FoodGroupRequest>{new("RICE",1,true,[11]),new("RICE",2,false,[12])}),
    ("food in two groups", new List<FoodGroupRequest>{new("RICE",1,true,[11]),new("DRINK",2,false,[11])}),
})
{
    var result = await controller.Save(1, request with { Groups = groups }, default);
    Check(result is BadRequestObjectResult, $"API rejects {label} before writing");
}
Check(await controller.Save(1,request with {Questions=[new("", "TEXT",true,1,[])]},default)
    is BadRequestObjectResult,"API rejects blank requirement question");
Check(await controller.Save(1,request with {Questions=[new("เลือกอาหาร", "SINGLE",true,1,["หนึ่ง"])]},default)
    is BadRequestObjectResult,"API requires at least two options for choice question");

var responseController=new MeetingParticipantResponseController(new ConfigurationBuilder().Build())
{ControllerContext=controller.ControllerContext};
Check(await responseController.Save(1,new("UNKNOWN",null,null,[],[]),default)
    is BadRequestObjectResult,"Unified participant response rejects invalid status before database access");

var attendanceProtection = new Microsoft.AspNetCore.DataProtection.EphemeralDataProtectionProvider();
var attendance = new MeetingAttendanceController(new ConfigurationBuilder().Build(), attendanceProtection)
{
    ControllerContext = controller.ControllerContext,
};
foreach (var badToken in new[] { "", "invalid-token", new string('x', 8193) })
    Check(await attendance.ConsumeQr(new(badToken), default) is BadRequestObjectResult,
        "QR rejects missing, tampered or oversized token before database access");
var protector = Microsoft.AspNetCore.DataProtection.DataProtectionCommonExtensions.CreateProtector(attendanceProtection, "LAOO_MEETING.AttendanceQr.v1");
foreach (var invalidReceipt in new List<MeetingAttendanceController.ReceiptItem>?[]
{
    null, [], [new(1,-1)], [new(1,100)], [new(0,1)], [new(1,1),new(1,2)],
})
    Check(await attendance.SaveFoodReceipt(1,1,1,new(invalidReceipt),default) is BadRequestObjectResult,
        "Receipt rejects missing, empty, invalid quantity/identity or duplicate details");
foreach (var payload in new[]
{
    new { CompanyId=2L, BookingId=1L, SlotId=1L, RoomId=1L, ParticipantId=(long?)null, EmployeeId=(long?)null, Kind="ROOM", ExpiresAtUtc=DateTimeOffset.UtcNow.AddMinutes(5) },
    new { CompanyId=1L, BookingId=1L, SlotId=1L, RoomId=1L, ParticipantId=(long?)null, EmployeeId=(long?)null, Kind="ROOM", ExpiresAtUtc=DateTimeOffset.UtcNow.AddMinutes(-1) },
    new { CompanyId=1L, BookingId=1L, SlotId=1L, RoomId=1L, ParticipantId=(long?)null, EmployeeId=(long?)null, Kind="PERSONAL", ExpiresAtUtc=DateTimeOffset.UtcNow.AddMinutes(5) },
})
{
    var protectedToken = Microsoft.AspNetCore.DataProtection.DataProtectionCommonExtensions.Protect(protector, JsonSerializer.Serialize(payload));
    Check(await attendance.ConsumeQr(new(protectedToken), default) is BadRequestObjectResult,
        "QR rejects wrong company, expiration or incomplete personal identity");
}

var anonymousAttendance = new MeetingAttendanceController(new ConfigurationBuilder().Build(), attendanceProtection)
{
    ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
};
Check(await anonymousAttendance.Get(1,null,default) is ObjectResult { StatusCode:403 }, "Attendance rejects missing company identity");
Check(await anonymousAttendance.List(null,null,null,1,20,default) is ObjectResult { StatusCode:403 },
    "Attendance list rejects missing company identity");
Check(await anonymousAttendance.CheckIn(1,1,1,default) is ObjectResult { StatusCode:403 }, "Check-in rejects missing company identity");
Check(await anonymousAttendance.GetFoodReceipt(1,1,1,default) is ObjectResult { StatusCode:403 }, "Receipt read rejects missing company identity");
Check(await anonymousAttendance.SaveFoodReceipt(1,1,1,new([new(1,1)]),default) is ObjectResult { StatusCode:403 }, "Receipt write rejects missing company identity");

var anonymousSummary = new MeetingFoodOrderSummaryController(new ConfigurationBuilder().Build())
{
    ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
};
Check(await anonymousSummary.List(null,null,null,1,20,default) is ForbidResult,
    "Food summary list rejects missing company identity");
Check(await anonymousSummary.Get(1,default) is ForbidResult,
    "Food summary detail rejects missing company identity");

static void Check(bool result, string name)
{
    if (!result) throw new InvalidOperationException(name);
    Console.WriteLine($"PASS {name}");
}
