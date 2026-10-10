using Microsoft.Data.SqlClient;

namespace Laoo.Rental;

internal static class RentalDb
{
    private static SqlCommand Command(SqlConnection db, SqlTransaction? tx, string sql,
        params (string Name, object? Value)[] values)
    {
        var command = new SqlCommand(sql, db, tx);
        foreach (var (name, value) in values)
            command.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return command;
    }

    public static async Task<long> Number(SqlConnection db, SqlTransaction? tx, string sql,
        CancellationToken ct, params (string, object?)[] values)
    {
        await using var command = Command(db, tx, sql, values);
        return Convert.ToInt64(await command.ExecuteScalarAsync(ct));
    }

    public static async Task<decimal> Money(SqlConnection db, SqlTransaction? tx, string sql,
        CancellationToken ct, params (string, object?)[] values)
    {
        await using var command = Command(db, tx, sql, values);
        return Convert.ToDecimal(await command.ExecuteScalarAsync(ct));
    }

    public static async Task<int> Execute(SqlConnection db, SqlTransaction? tx, string sql,
        CancellationToken ct, params (string, object?)[] values)
    {
        await using var command = Command(db, tx, sql, values);
        return await command.ExecuteNonQueryAsync(ct);
    }

    public static Task<int> Audit(SqlConnection db, SqlTransaction tx, long company,
        long actor, string eventCode, long? bookingId, long? rentalItemId,
        string? detail, CancellationToken ct) =>
        Execute(db, tx, """
INSERT dbo.TDRNAudit(CompanyID,BookingID,RentalItemID,EventCode,Detail,ActorID)
VALUES(@co,@booking,@item,@event,@detail,@actor)
""", ct, ("@co", company), ("@booking", bookingId), ("@item", rentalItemId),
            ("@event", eventCode),
            ("@detail", detail is { Length: > 1000 } ? detail[..1000] : detail),
            ("@actor", actor));

    public static async Task<List<Dictionary<string, object?>>> Rows(SqlConnection db,
        SqlTransaction? tx, string sql, CancellationToken ct, params (string, object?)[] values)
    {
        await using var command = Command(db, tx, sql, values);
        await using var reader = await command.ExecuteReaderAsync(ct);
        var rows = new List<Dictionary<string, object?>>();
        while (await reader.ReadAsync(ct))
        {
            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            for (var i = 0; i < reader.FieldCount; i++)
                row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
            rows.Add(row);
        }
        return rows;
    }
}
