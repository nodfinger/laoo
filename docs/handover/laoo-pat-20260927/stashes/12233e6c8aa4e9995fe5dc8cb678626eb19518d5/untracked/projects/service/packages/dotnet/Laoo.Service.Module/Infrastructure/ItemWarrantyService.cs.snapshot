using System.Data;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Infrastructure;

internal static class ItemWarrantyService
{
    internal static async Task CreateSnapshotAsync(SqlConnection connection, SqlTransaction transaction, long companyId, long userId, long itemId, long instanceId, string coverageType, string eventCode, DateOnly startDate, string? documentType, long? documentId, long? documentDetailId, CancellationToken token)
    {
        const string policySql = "SELECT WarrantyModeCode,DurationMonths FROM dbo.TDIVItemWarrantyPolicy WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND ItemID=@item AND CoverageTypeCode=@coverage";
        string mode = "NONE"; int? months = null;
        await using (var policy = new SqlCommand(policySql, connection, transaction))
        {
            Add(policy,"@company",SqlDbType.BigInt,companyId); Add(policy,"@item",SqlDbType.BigInt,itemId); Add(policy,"@coverage",SqlDbType.NVarChar,coverageType,20);
            await using var reader = await policy.ExecuteReaderAsync(token);
            if (await reader.ReadAsync(token)) { mode = reader.GetString(0); months = reader.IsDBNull(1) ? null : reader.GetInt32(1); }
        }
        var expiry = mode == "MONTHS" && months.HasValue ? startDate.AddMonths(months.Value) : (DateOnly?)null;
        const string insert = """
INSERT dbo.TDIVItemInstanceWarranty(CompanyID,ItemInstanceID,CoverageTypeCode,WarrantyModeCode,DurationMonths,StartDate,ExpireDate,StartEventCode,SourceDocumentType,SourceDocumentID,SourceDocumentDetailID,CreatedBy)
SELECT @company,@instance,@coverage,@mode,@months,@start,@expiry,@event,@documentType,@document,@detail,@user
WHERE NOT EXISTS(SELECT 1 FROM dbo.TDIVItemInstanceWarranty WITH(UPDLOCK,HOLDLOCK) WHERE CompanyID=@company AND ItemInstanceID=@instance AND CoverageTypeCode=@coverage AND VoidedDate IS NULL);
""";
        await using var command = new SqlCommand(insert, connection, transaction);
        Add(command,"@company",SqlDbType.BigInt,companyId); Add(command,"@instance",SqlDbType.BigInt,instanceId); Add(command,"@coverage",SqlDbType.NVarChar,coverageType,20); Add(command,"@mode",SqlDbType.NVarChar,mode,20); Add(command,"@months",SqlDbType.Int,months); Add(command,"@start",SqlDbType.Date,startDate); Add(command,"@expiry",SqlDbType.Date,expiry); Add(command,"@event",SqlDbType.NVarChar,eventCode,30); Add(command,"@documentType",SqlDbType.NVarChar,documentType,30); Add(command,"@document",SqlDbType.BigInt,documentId); Add(command,"@detail",SqlDbType.BigInt,documentDetailId); Add(command,"@user",SqlDbType.BigInt,userId);
        await command.ExecuteNonQueryAsync(token);
    }

    internal static async Task VoidBySourceAsync(SqlConnection connection, SqlTransaction transaction, long companyId, long userId, string documentType, long documentId, string remark, CancellationToken token)
    {
        const string sql = "UPDATE dbo.TDIVItemInstanceWarranty SET VoidedDate=SYSUTCDATETIME(),VoidedBy=@user,VoidRemark=@remark,UpdateDate=SYSUTCDATETIME(),UpdatedBy=@user WHERE CompanyID=@company AND SourceDocumentType=@type AND SourceDocumentID=@document AND VoidedDate IS NULL";
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command,"@company",SqlDbType.BigInt,companyId); Add(command,"@user",SqlDbType.BigInt,userId); Add(command,"@type",SqlDbType.NVarChar,documentType,30); Add(command,"@document",SqlDbType.BigInt,documentId); Add(command,"@remark",SqlDbType.NVarChar,remark,500);
        await command.ExecuteNonQueryAsync(token);
    }

    internal static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0) { var parameter=command.Parameters.Add(name,type); if(size>0)parameter.Size=size; parameter.Value=value??DBNull.Value; }
}
