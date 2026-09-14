using System.Reflection;
using System.Text.RegularExpressions;
using LaooMeetingApi.Controllers;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

var assembly = typeof(MeetingEquipmentRequestController).Assembly;
var accessType = typeof(MeetingEquipmentRequestController).GetNestedType("Access", BindingFlags.NonPublic)!;
var requestState = typeof(MeetingEquipmentRequestController).GetMethod("RequestState", BindingFlags.Static | BindingFlags.NonPublic)!;
var now = DateTime.Now;
foreach (var test in new[] {
    ("OPEN", true, "APPROVED", now.AddHours(2), (DateTime?)now.AddHours(1), true),
    ("NO_PERMISSION", false, "APPROVED", now.AddHours(2), (DateTime?)now.AddHours(1), true),
    ("BOOKING_NOT_APPROVED", true, "PENDING", now.AddHours(2), (DateTime?)now.AddHours(1), true),
    ("BOOKING_NOT_APPROVED", true, "CANCELLED", now.AddHours(2), (DateTime?)now.AddHours(1), true),
    ("MEETING_STARTED", true, "APPROVED", now, (DateTime?)now.AddHours(1), true),
    ("MEETING_STARTED", true, "APPROVED", now.AddSeconds(-1), (DateTime?)now.AddHours(1), true),
    ("CUTOFF_EXPIRED", true, "APPROVED", now.AddHours(2), (DateTime?)now, true),
    ("CUTOFF_DISABLED", true, "APPROVED", now.AddHours(2), (DateTime?)now.AddHours(1), false),
    ("CUTOFF_NOT_CONFIGURED", true, "APPROVED", now.AddHours(2), (DateTime?)null, true),
}) {
    var access = Activator.CreateInstance(accessType, 1L, "TEST", "Test", "R", "Room",
        test.Item4, now.AddHours(3), test.Item5, test.Item6, test.Item3, "Test", "INVITEE", false, test.Item2);
    Check((string)requestState.Invoke(null, [access])! == test.Item1, "request state " + test.Item1);
}

if (args.Length != 1) throw new ArgumentException("Pass repository root to run read-only SQL checks.");
var root = Path.GetFullPath(args[0]);
var config = new ConfigurationBuilder().AddJsonFile(Path.Combine(root, "laoo_api", "local.json")).Build();
await using var db = new SqlConnection(config.GetConnectionString("LaooDatabase"));
await db.OpenAsync();
var source = File.ReadAllText(Path.Combine(root, "projects/meeting/packages/dotnet/Laoo.Meeting.Module/Controllers/MeetingEquipmentRequestController.cs"));
var roomSql = (string)assembly.GetType("LaooMeetingApi.Security.MeetingRoomAdminAccess")!
    .GetField("BookingRoomSql", BindingFlags.NonPublic | BindingFlags.Static)!.GetRawConstantValue()!;
var accessSource = source[source.IndexOf("private async Task<Access?> GetAccess", StringComparison.Ordinal)..];
var sql = Regex.Match(accessSource, "var sql=\\$\"\"\"([\\s\\S]*?)\"\"\"").Groups[1].Value
    .Replace("{MeetingRoomAdminAccess.BookingRoomSql}", roomSql);
Check(sql.Length > 100, "access SQL located");
await using (var cmd = new SqlCommand(sql, db)) {
    Bind(cmd, -1, -1, -1);
    await using var reader = await cmd.ExecuteReaderAsync();
    Check(!await reader.ReadAsync(), "actual database schema compiles; foreign scope returns no row");
}

// CTE fixtures are SELECT-only: no production rows or schema are changed.
var fixture = """
WITH TDADUser AS (
 SELECT * FROM (VALUES (1,1,1,1,'admin'),(2,1,0,1,'owner'),(3,1,0,1,'room'),
 (4,1,0,1,'accepted'),(5,1,0,1,'waiting'),(6,1,0,1,'declined'),
 (7,1,0,1,'stranger'),(8,1,0,1,'other-room'),(9,2,1,1,'foreign'),(10,1,1,0,'inactive'))
 V(UserID,CompanyID,IsCompanyAdmin,IsActive,Username)),
TDADUserEmployee AS (
 SELECT * FROM (VALUES (3,30,1,1),(4,40,1,1),(5,50,1,1),(6,60,1,1),(8,80,1,1))
 V(UserID,EmployeeID,CompanyID,IsActive)),
TDADEmployee AS (
 SELECT * FROM (VALUES (30,1,1,'Room admin'),(40,1,1,'Accepted'),(50,1,1,'Waiting'),
 (60,1,1,'Declined'),(80,1,1,'Other room')) V(EmployeeID,CompanyID,IsActive,FullName)),
TDADMeetingRoom AS (
 SELECT * FROM (VALUES (10,1,'R1','Room 1'),(20,1,'R2','Room 2')) V(RoomID,CompanyID,RoomCode,RoomNameTH)),
TDADMeetingRoomContact AS (
 SELECT * FROM (VALUES (10,30,1),(20,80,1)) V(RoomID,EmployeeID,IsActive)),
TDADMeetingRoomBooking AS (
 SELECT 101 BookingID,1 CompanyID,2 RequesterUserID,10 RoomID,'TEST' BookingNo,'Test' Subject,'APPROVED' BookingStatus),
TDADMeetingRoomBookingSlot AS (
 SELECT 101 BookingID,1 CompanyID,CAST('2030-01-01T10:00:00' AS datetime2) StartDateTime,CAST('2030-01-01T11:00:00' AS datetime2) EndDateTime
 UNION ALL SELECT 101,1,CAST('2030-01-02T10:00:00' AS datetime2),CAST('2030-01-02T11:00:00' AS datetime2)),
TDADMeetingBookingEquipmentPlan AS (
 SELECT 101 BookingID,1 CompanyID,CAST('2030-01-01T09:00:00' AS datetime2) RequestCutoffDateTime,CAST(1 AS bit) IsActive),
TDADMeetingRoomBookingParticipant AS (
 SELECT * FROM (VALUES (101,1,40,'ACCEPTED'),(101,1,50,'PENDING'),(101,1,60,'REJECTED'))
 V(BookingID,CompanyID,EmployeeID,InvitationStatus))
""";
var fixtureSql = fixture + "\n" + Regex.Replace(sql, @"dbo\.(TD\w+)", "$1");
foreach (var (user, admin, room, owner, invited, hasRow) in new[] {
    (1,true,false,false,false,true), (2,false,false,true,false,true),
    (3,false,true,false,false,true), (4,false,false,false,true,true),
    (5,false,false,false,false,true), (6,false,false,false,false,true),
    (7,false,false,false,false,true), (8,false,false,false,false,true),
    (9,false,false,false,false,false), (10,false,false,false,false,false)
}) {
    await using var cmd = new SqlCommand(fixtureSql, db);
    Bind(cmd, 1, user, 101);
    await using var r = await cmd.ExecuteReaderAsync();
    Check(await r.ReadAsync() == hasRow, "role scope " + user);
    if (!hasRow) continue;
    Check((r.GetInt32(11)==1)==admin && (r.GetInt32(12)==1)==room &&
          (r.GetInt32(13)==1)==owner && (r.GetInt32(14)==1)==invited, "role matrix " + user);
    Check(r.GetDateTime(5)==new DateTime(2030,1,1,10,0,0), "first slot controls cutoff " + user);
}
var bookingSource = File.ReadAllText(Path.Combine(root, "projects/meeting/packages/dotnet/Laoo.Meeting.Module/Controllers/MeetingRoomBookingController.cs"));
var approvalCase = Regex.Match(bookingSource, @"CASE WHEN B.BookingStatus='PENDING' AND[\s\S]*?END AS CanApprove").Value;
Check(approvalCase.Length > 0, "booking approval SQL located");
foreach (var (user, admin, rooms, expected) in new[] {
    (1,true,",10,",true), (2,false,",",false), (3,false,",10,",true),
    (4,false,",",false), (5,false,",",false), (8,false,",20,",false)
}) {
    await using var cmd = new SqlCommand(fixture.Replace("'APPROVED' BookingStatus", "'PENDING' BookingStatus") +
        "\nSELECT " + approvalCase + " FROM TDADMeetingRoomBooking B JOIN TDADMeetingRoomBookingSlot S ON S.BookingID=B.BookingID GROUP BY B.BookingStatus,B.RoomID", db);
    cmd.Parameters.AddWithValue("@companyAdmin",admin);
    cmd.Parameters.AddWithValue("@adminRoomIds",rooms);
    cmd.Parameters.AddWithValue("@approvalEdit",true);
    cmd.Parameters.AddWithValue("@user",user);
    Check(Convert.ToInt32(await cmd.ExecuteScalarAsync()) == (expected?1:0), "approval role restriction " + user);
}
var listSql = Regex.Match(source, @"var sql = \$""""""([\s\S]*?)""""""").Groups[1].Value
    .Replace("{MeetingRoomAdminAccess.BookingRoomSql}",roomSql);
await using (var cmd = new SqlCommand(listSql,db)) {
    foreach(var name in new[]{"@company","@user","@room","@department","@requester"})
        cmd.Parameters.AddWithValue(name,-1L);
    cmd.Parameters.AddWithValue("@status",DBNull.Value);
    cmd.Parameters.AddWithValue("@from",new DateTime(2030,1,1));
    cmd.Parameters.AddWithValue("@to",new DateTime(2030,1,1));
    cmd.Parameters.AddWithValue("@admin",false);
    cmd.Parameters.AddWithValue("@edit",false);
    await using var r = await cmd.ExecuteReaderAsync();
    Check(!await r.ReadAsync(),"equipment queue compiles and rejects foreign scope");
}
Console.WriteLine("All permission and read-only schema checks passed.");
static void Bind(SqlCommand cmd, long company, long user, long booking) {
    cmd.Parameters.AddWithValue("@company",company);
    cmd.Parameters.AddWithValue("@user",user);
    cmd.Parameters.AddWithValue("@booking",booking);
}
static void Check(bool value, string name) {
    if (!value) throw new InvalidOperationException(name);
    Console.WriteLine("PASS " + name);
}
