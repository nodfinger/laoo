using Microsoft.Data.SqlClient;

namespace Laoo.Market;

internal static class MarketDb
{
    private static SqlCommand Command(SqlConnection db, SqlTransaction? tx, string sql,
        params (string Name, object? Value)[] values)
    {
        var command = new SqlCommand(sql, db, tx);
        foreach (var (name, value) in values)
            command.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return command;
    }

    public static async Task<List<Dictionary<string, object?>>> Rows(SqlConnection db,
        SqlTransaction? tx, string sql, CancellationToken ct, params (string, object?)[] values)
    {
        await using var command = Command(db, tx, sql, values);
        await using var reader = await command.ExecuteReaderAsync(ct);
        var result = new List<Dictionary<string, object?>>();
        while (await reader.ReadAsync(ct))
        {
            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            for (var i = 0; i < reader.FieldCount; i++)
                row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
            result.Add(row);
        }
        return result;
    }

    public static async Task<long> Id(SqlConnection db, SqlTransaction? tx, string sql,
        CancellationToken ct, params (string, object?)[] values)
    {
        await using var command = Command(db, tx, sql, values);
        return Convert.ToInt64(await command.ExecuteScalarAsync(ct));
    }

    public static async Task<int> Execute(SqlConnection db, SqlTransaction? tx, string sql,
        CancellationToken ct, params (string, object?)[] values)
    {
        await using var command = Command(db, tx, sql, values);
        return await command.ExecuteNonQueryAsync(ct);
    }
}
