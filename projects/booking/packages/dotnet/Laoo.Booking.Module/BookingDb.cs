using Microsoft.Data.SqlClient;

namespace Laoo.Booking;

internal static class BookingDb
{
    public static bool InvalidPage(int? page, int pageSize) =>
        pageSize is < 1 or > 100 || page is < 1 || (page.HasValue && page.Value > int.MaxValue / pageSize);
    static SqlCommand Cmd(SqlConnection db, SqlTransaction? tx, string sql, params (string, object?)[] args)
    {
        var c = new SqlCommand(sql, db, tx);
        foreach (var (k, v) in args) c.Parameters.AddWithValue(k, v ?? DBNull.Value);
        return c;
    }
    public static async Task<List<Dictionary<string, object?>>> Rows(SqlConnection db, SqlTransaction? tx, string sql, CancellationToken ct, params (string, object?)[] args)
    {
        await using var c = Cmd(db, tx, sql, args); await using var r = await c.ExecuteReaderAsync(ct);
        var rows = new List<Dictionary<string, object?>>();
        while (await r.ReadAsync(ct)) { var d = new Dictionary<string, object?>(); for (int i = 0; i < r.FieldCount; i++) d[r.GetName(i)] = r.IsDBNull(i) ? null : r.GetValue(i); rows.Add(d); }
        return rows;
    }
    public static async Task<long> Id(SqlConnection db, SqlTransaction? tx, string sql, CancellationToken ct, params (string, object?)[] args)
    { await using var c = Cmd(db, tx, sql, args); return Convert.ToInt64(await c.ExecuteScalarAsync(ct)); }
    public static async Task<int> Exec(SqlConnection db, SqlTransaction? tx, string sql, CancellationToken ct, params (string, object?)[] args)
    { await using var c = Cmd(db, tx, sql, args); return await c.ExecuteNonQueryAsync(ct); }
    public static async Task<object> CompanyPage(SqlConnection db, string selectSql, string countSql, long company, int page, int pageSize, CancellationToken ct)
    {
        var total = await Id(db, null, countSql, ct, ("@c", company));
        var items = await Rows(db, null, selectSql + " OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY", ct,
            ("@c", company), ("@offset", (page - 1) * pageSize), ("@size", pageSize));
        return new { items, total, page, pageSize };
    }
}
