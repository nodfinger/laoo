using Microsoft.Data.SqlClient;
namespace Laoo.Site;
internal static class SiteDb
{
    static SqlCommand Command(SqlConnection db, SqlTransaction? tx, string sql, params (string, object?)[] args)
    {
        var cmd = new SqlCommand(sql, db, tx);
        foreach (var (key, value) in args) cmd.Parameters.AddWithValue(key, value ?? DBNull.Value);
        return cmd;
    }
    public static async Task<List<Dictionary<string, object?>>> Rows(SqlConnection db, SqlTransaction? tx, string sql, CancellationToken ct, params (string, object?)[] args)
    {
        await using var cmd = Command(db, tx, sql, args);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        var rows = new List<Dictionary<string, object?>>();
        while (await reader.ReadAsync(ct))
        {
            var row = new Dictionary<string, object?>();
            for (var i = 0; i < reader.FieldCount; i++)
                row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
            rows.Add(row);
        }
        return rows;
    }
    public static async Task<long> Scalar(SqlConnection db, SqlTransaction? tx, string sql, CancellationToken ct, params (string, object?)[] args)
    {
        await using var cmd = Command(db, tx, sql, args);
        return Convert.ToInt64(await cmd.ExecuteScalarAsync(ct));
    }
    public static async Task<int> Exec(SqlConnection db, SqlTransaction? tx, string sql, CancellationToken ct, params (string, object?)[] args)
    {
        await using var cmd = Command(db, tx, sql, args);
        return await cmd.ExecuteNonQueryAsync(ct);
    }
}
