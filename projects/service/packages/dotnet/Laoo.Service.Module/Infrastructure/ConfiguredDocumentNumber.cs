using System.Data;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Infrastructure;

internal static class ConfiguredDocumentNumber
{
    internal static async Task<string?> Get(SqlConnection connection, SqlTransaction transaction, long companyId, string menuCode, CancellationToken token)
    {
        await using var command = new SqlCommand(Laoo.Shared.Contracts.DocumentNumbering.Sql(menuCode), connection, transaction);
        command.Parameters.Add("@company", SqlDbType.BigInt).Value = companyId;
        var value = await command.ExecuteScalarAsync(token);
        return value is null or DBNull ? null : Convert.ToString(value);
    }
}
