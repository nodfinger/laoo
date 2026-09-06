using Microsoft.Data.SqlClient;

namespace LaooServiceApi.Data;

public sealed class SqlConnectionFactory
{
    private readonly string _connectionString;

    public SqlConnectionFactory(IConfiguration configuration)
    {
        _connectionString =
            configuration.GetConnectionString("LaooDatabase")
            ?? throw new InvalidOperationException(
                "ไม่พบ ConnectionStrings:LaooDatabase ใน local.json");

        if (string.IsNullOrWhiteSpace(_connectionString))
        {
            throw new InvalidOperationException(
                "ConnectionStrings:LaooDatabase ใน local.json ห้ามว่าง");
        }
    }

    public SqlConnection CreateConnection()
    {
        return new SqlConnection(_connectionString);
    }
}
