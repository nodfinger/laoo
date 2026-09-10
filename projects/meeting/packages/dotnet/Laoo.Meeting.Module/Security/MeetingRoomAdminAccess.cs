using System.Security.Claims;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Security;

internal static class MeetingRoomAdminAccess
{
    internal static async Task<HashSet<long>> Rooms(SqlConnection db, ClaimsPrincipal user, CancellationToken token)
    {
        var rooms = new HashSet<long>();
        if (user.FindFirstValue("user_type") != "COMPANY_USER" ||
            !long.TryParse(user.FindFirstValue("company_id"), out var company) ||
            !long.TryParse(user.FindFirstValue("user_id"), out var id)) return rooms;
        const string sql = """
SELECT DISTINCT R.RoomID
FROM dbo.TDADMeetingRoom R
JOIN dbo.TDADMeetingRoomContact C ON C.RoomID=R.RoomID AND C.IsActive=1
JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=C.EmployeeID AND UE.CompanyID=R.CompanyID AND UE.IsActive=1
JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=R.CompanyID AND E.IsActive=1
JOIN dbo.TDADUser U ON U.UserID=UE.UserID AND U.CompanyID=R.CompanyID AND U.IsActive=1
WHERE R.CompanyID=@company AND U.UserID=@user;
""";
        await using var cmd = new SqlCommand(sql, db);
        cmd.Parameters.AddWithValue("@company", company);
        cmd.Parameters.AddWithValue("@user", id);
        await using var reader = await cmd.ExecuteReaderAsync(token);
        while (await reader.ReadAsync(token)) rooms.Add(reader.GetInt64(0));
        return rooms;
    }
}
