using Microsoft.Data.SqlClient;
namespace Laoo.DigitalChecklist;
internal static class DigitalChecklistDb
{
    internal static SqlCommand Cmd(SqlConnection db, string sql, params (string, object?)[] args) { var c = new SqlCommand(sql, db); foreach (var (n, v) in args) c.Parameters.AddWithValue(n, v ?? DBNull.Value); return c; }
    internal static async Task<List<Dictionary<string, object?>>> Rows(SqlConnection db, string sql, CancellationToken ct, params (string, object?)[] args) { await using var c = Cmd(db, sql, args); await using var r = await c.ExecuteReaderAsync(ct); var a = new List<Dictionary<string, object?>>(); while (await r.ReadAsync(ct)) { var d = new Dictionary<string, object?>(); for (int i = 0; i < r.FieldCount; i++) d[r.GetName(i)] = r.IsDBNull(i) ? null : r.GetValue(i); a.Add(d); } return a; }
    internal static async Task<long> Id(SqlConnection db, string sql, CancellationToken ct, params (string, object?)[] args) { await using var c = Cmd(db, sql, args); return Convert.ToInt64(await c.ExecuteScalarAsync(ct)); }
}
