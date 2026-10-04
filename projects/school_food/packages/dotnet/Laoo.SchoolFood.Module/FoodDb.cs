using System.Data;
using Microsoft.Data.SqlClient;

namespace Laoo.SchoolFood;

internal static class FoodDb
{
    public static SqlCommand Command(SqlConnection db, SqlTransaction? tx, string sql,
        params (string Name, object? Value)[] values)
    {
        var cmd = new SqlCommand(sql, db, tx);
        foreach (var (name, value) in values)
            cmd.Parameters.AddWithValue(name, value ?? DBNull.Value);
        return cmd;
    }

    public static async Task<List<Dictionary<string, object?>>> Rows(SqlConnection db,
        SqlTransaction? tx, string sql, CancellationToken ct, params (string, object?)[] values)
    {
        await using var cmd = Command(db, tx, sql, values);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
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

    public static async Task<int> Execute(SqlConnection db, SqlTransaction? tx, string sql,
        CancellationToken ct, params (string, object?)[] values)
    {
        await using var cmd = Command(db, tx, sql, values);
        return await cmd.ExecuteNonQueryAsync(ct);
    }

    public static async Task<long> Id(SqlConnection db, SqlTransaction? tx, string sql,
        CancellationToken ct, params (string, object?)[] values)
    {
        await using var cmd = Command(db, tx, sql, values);
        return Convert.ToInt64(await cmd.ExecuteScalarAsync(ct));
    }

    public static long Long(this Dictionary<string, object?> row, string key) => Convert.ToInt64(row[key]);
    public static decimal Decimal(this Dictionary<string, object?> row, string key) => Convert.ToDecimal(row[key]);
    public static bool Bool(this Dictionary<string, object?> row, string key) => Convert.ToBoolean(row[key]);
}
