using System.Data;
using LaooApi.Models;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

public sealed partial class ItemController
{
    private async Task<IReadOnlyList<ItemWarrantyPolicyInput>> ReadWarrantyPolicies(SqlConnection connection, long itemId, CancellationToken token)
    {
        const string sql = "SELECT CoverageTypeCode,WarrantyModeCode,DurationMonths FROM dbo.TDIVItemWarrantyPolicy WHERE CompanyID=@company AND ItemID=@item ORDER BY CoverageTypeCode";
        await using var command = new SqlCommand(sql, connection); Add(command,"@company",SqlDbType.BigInt,CompanyID()); Add(command,"@item",SqlDbType.BigInt,itemId);
        var rows = new List<ItemWarrantyPolicyInput>(); await using var reader = await command.ExecuteReaderAsync(token);
        while(await reader.ReadAsync(token)) rows.Add(new(reader.GetString(0),reader.GetString(1),reader.IsDBNull(2)?null:reader.GetInt32(2)));
        return rows;
    }

    private static string? ValidateWarrantyPolicies(IReadOnlyList<ItemWarrantyPolicyInput>? policies)
    {
        if(policies is null) return null;
        if(policies.Select(x=>x.CoverageTypeCode?.Trim().ToUpperInvariant()).Distinct(StringComparer.OrdinalIgnoreCase).Count()!=policies.Count) return "ประเภทความคุ้มครองซ้ำกัน";
        foreach(var policy in policies)
        {
            var coverage=policy.CoverageTypeCode?.Trim().ToUpperInvariant(); var mode=policy.WarrantyModeCode?.Trim().ToUpperInvariant();
            if(coverage is not ("SUPPLIER" or "CUSTOMER")) return "รองรับเฉพาะประกันผู้ขายและประกันลูกค้า";
            if(mode is not ("NONE" or "LIFETIME" or "MONTHS")) return "รูปแบบอายุประกันไม่ถูกต้อง";
            if((mode=="MONTHS" && (!policy.DurationMonths.HasValue || policy.DurationMonths<=0)) || (mode!="MONTHS" && policy.DurationMonths.HasValue)) return "จำนวนเดือนประกันไม่ถูกต้อง";
        }
        return null;
    }

    private async Task SaveWarrantyPolicies(SqlConnection connection, SqlTransaction transaction, long itemId, IReadOnlyList<ItemWarrantyPolicyInput> policies, CancellationToken token)
    {
        await using(var clear=new SqlCommand("DELETE dbo.TDIVItemWarrantyPolicy WHERE CompanyID=@company AND ItemID=@item",connection,transaction)){Add(clear,"@company",SqlDbType.BigInt,CompanyID());Add(clear,"@item",SqlDbType.BigInt,itemId);await clear.ExecuteNonQueryAsync(token);}
        foreach(var policy in policies)
        {
            await using var insert=new SqlCommand("INSERT dbo.TDIVItemWarrantyPolicy(CompanyID,ItemID,CoverageTypeCode,WarrantyModeCode,DurationMonths,UpdatedBy) VALUES(@company,@item,@coverage,@mode,@months,@user)",connection,transaction);
            Add(insert,"@company",SqlDbType.BigInt,CompanyID());Add(insert,"@item",SqlDbType.BigInt,itemId);Add(insert,"@coverage",SqlDbType.NVarChar,policy.CoverageTypeCode.Trim().ToUpperInvariant(),20);Add(insert,"@mode",SqlDbType.NVarChar,policy.WarrantyModeCode.Trim().ToUpperInvariant(),20);Add(insert,"@months",SqlDbType.Int,(object?)policy.DurationMonths??DBNull.Value);Add(insert,"@user",SqlDbType.BigInt,UserId());await insert.ExecuteNonQueryAsync(token);
        }
    }
}
