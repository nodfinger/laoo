using LaooApi.Models.DatabaseRouting;
using Microsoft.Data.SqlClient;

namespace LaooApi.Data;

/// <summary>
/// Resolves a business database through the DBTDLaoo control-plane catalog.
/// Order: Company -> Partner -> Default.
/// Connection secrets remain in configuration; the catalog stores only keys.
/// </summary>
public sealed class DatabaseRouteResolver
{
    private readonly SqlConnectionFactory _connectionFactory;
    private readonly IConfiguration _configuration;
    private readonly IHostEnvironment _environment;

    public DatabaseRouteResolver(
        SqlConnectionFactory connectionFactory,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        _connectionFactory = connectionFactory;
        _configuration = configuration;
        _environment = environment;
    }

    public async Task<DatabaseRouteResolution> ResolveAsync(
        long projectId,
        long? companyId,
        long? partnerId,
        CancellationToken cancellationToken)
    {
        await using var catalog = _connectionFactory.CreateConnection();
        await catalog.OpenAsync(cancellationToken);

        var effectivePartnerId = partnerId;
        if (companyId.HasValue)
        {
            const string partnerSql = """
            SELECT PartnerID
            FROM dbo.TDADCompany
            WHERE CompanyID = @CompanyID
              AND IsActive = 1;
            """;
            await using var partnerCommand = new SqlCommand(partnerSql, catalog);
            partnerCommand.Parameters.AddWithValue("@CompanyID", companyId.Value);
            var result = await partnerCommand.ExecuteScalarAsync(cancellationToken);
            if (result is null || result is DBNull)
            {
                throw new InvalidOperationException("ไม่พบ Company ที่เปิดใช้งาน");
            }
            effectivePartnerId = Convert.ToInt64(result);
        }

        const string routeSql = """
        SELECT TOP (1)
            r.DatabaseRouteID,
            r.ScopeType,
            r.PartnerID,
            r.CompanyID,
            e.ConnectionKey,
            e.DatabaseName,
            e.SchemaName,
            r.EnvironmentCode,
            e.RequiredSchemaVersion
        FROM dbo.TDSYDatabaseRoute AS r
        INNER JOIN dbo.TDSYDatabaseEndpoint AS e
            ON e.DatabaseEndpointID = r.DatabaseEndpointID
           AND e.IsActive = 1
        WHERE r.IsActive = 1
          AND r.ProjectID = @ProjectID
          AND r.EnvironmentCode = @EnvironmentCode
          AND (r.EffectiveFrom IS NULL OR r.EffectiveFrom <= SYSUTCDATETIME())
          AND (r.EffectiveTo IS NULL OR r.EffectiveTo > SYSUTCDATETIME())
          AND (
                (r.ScopeType = 'C' AND r.CompanyID = @CompanyID)
             OR (r.ScopeType = 'P' AND r.PartnerID = @PartnerID)
             OR r.ScopeType = 'D'
          )
        ORDER BY CASE r.ScopeType WHEN 'C' THEN 1 WHEN 'P' THEN 2 ELSE 3 END;
        """;

        await using var command = new SqlCommand(routeSql, catalog);
        command.Parameters.AddWithValue("@ProjectID", projectId);
        command.Parameters.AddWithValue("@EnvironmentCode", EnvironmentCode());
        command.Parameters.AddWithValue("@CompanyID", (object?)companyId ?? DBNull.Value);
        command.Parameters.AddWithValue("@PartnerID", (object?)effectivePartnerId ?? DBNull.Value);

        try
        {
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                return DefaultRoute(usedFallback: true);
            }

            var connectionKey = reader.GetString(4);
            EnsureConnectionKeyExists(connectionKey);

            return new DatabaseRouteResolution(
                reader.GetInt64(0),
                reader.GetString(1),
                reader.IsDBNull(2) ? null : reader.GetInt64(2),
                reader.IsDBNull(3) ? null : reader.GetInt64(3),
                connectionKey,
                reader.GetString(5),
                reader.GetString(6),
                reader.GetString(7),
                reader.IsDBNull(8) ? null : reader.GetString(8),
                false);
        }
        catch (SqlException exception) when (exception.Number == 208)
        {
            // Allows the existing application to run before the additive
            // migration is installed.
            return DefaultRoute(usedFallback: true);
        }
    }

    public SqlConnection CreateBusinessConnection(DatabaseRouteResolution route)
    {
        var configured = _configuration.GetConnectionString(route.ConnectionKey)
            ?? throw new InvalidOperationException(
                $"ไม่พบ ConnectionStrings:{route.ConnectionKey}");

        var builder = new SqlConnectionStringBuilder(configured)
        {
            InitialCatalog = route.DatabaseName
        };
        return new SqlConnection(builder.ConnectionString);
    }

    private DatabaseRouteResolution DefaultRoute(bool usedFallback)
    {
        const string key = "LaooDatabase";
        var configured = EnsureConnectionKeyExists(key);
        var builder = new SqlConnectionStringBuilder(configured);
        return new DatabaseRouteResolution(
            null, "D", null, null, key, builder.InitialCatalog, "dbo",
            EnvironmentCode(), null, usedFallback);
    }

    private string EnsureConnectionKeyExists(string connectionKey)
    {
        return _configuration.GetConnectionString(connectionKey)
            ?? throw new InvalidOperationException(
                $"Route อ้าง ConnectionStrings:{connectionKey} แต่ยังไม่ได้กำหนดค่า");
    }

    private string EnvironmentCode() =>
        _environment.IsDevelopment() ? "DEVELOPMENT" : "PRODUCTION";
}
