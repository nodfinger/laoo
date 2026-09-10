using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Infrastructure;

public sealed class ItemProjectDeniedException() : Exception("สินค้าไม่ได้เปิดใช้สำหรับ Project งานขาย–สต๊อกนี้");

public sealed class ItemProjectExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not ItemProjectDeniedException) return;
        context.Result = new ObjectResult(new {
            message = "ไม่สามารถใช้สินค้าใน Project นี้ได้",
            description = "สินค้าต้องเปิดใช้งาน อยู่ในบริษัทเดียวกัน และอนุญาต Project งานขาย–สต๊อก กรุณาตรวจการกำหนด Project ที่ทะเบียนสินค้า",
            code = "ITEM_PROJECT_DENIED",
        }) { StatusCode = 403 };
        context.ExceptionHandled = true;
    }
}

// Sales and inventory belong to Core (LAOO). The legacy source folder does not
// determine the consuming project, and the client cannot override this scope.
public static class ItemProjectAccess
{
    public const string ItemAliasPredicate = """
I.IsActive=1 AND EXISTS (
 SELECT 1 FROM dbo.TDADProject AP
 JOIN dbo.TDADCompanyProject ACP ON ACP.ProjectID=AP.ProjectID AND ACP.CompanyID=I.CompanyID AND ACP.IsEnabled=1
 JOIN dbo.TDSTCompanySetUp AC ON AC.CompanyID=ACP.CompanyID AND AC.PartnerID=ACP.PartnerID AND AC.IsActive=1
 WHERE AP.ProjectCode=N'LAOO' AND AP.IsActive=1
 AND (ACP.StartDate IS NULL OR ACP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (ACP.ExpireDate IS NULL OR ACP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
 AND (NOT EXISTS(SELECT 1 FROM dbo.TDIVItemProjectPolicy IP WITH(HOLDLOCK) WHERE IP.CompanyID=I.CompanyID AND IP.ItemID=I.ItemID AND IP.AccessModeCode=N'SELECTED')
 OR EXISTS(SELECT 1 FROM dbo.TDIVItemProject IX WITH(HOLDLOCK) WHERE IX.CompanyID=I.CompanyID AND IX.ItemID=I.ItemID AND IX.ProjectID=AP.ProjectID))
)
""";

    public static async Task EnsureAsync(SqlConnection c, SqlTransaction? tx, long company, long item, CancellationToken token)
    {
        await using var command = new SqlCommand($"SELECT I.ItemID FROM dbo.TDIVItem I WITH(HOLDLOCK) WHERE I.CompanyID=@company AND I.ItemID=@item AND I.IsActive=1 AND {ItemAliasPredicate}", c, tx);
        command.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
        command.Parameters.Add("@item",SqlDbType.BigInt).Value=item;
        if (await command.ExecuteScalarAsync(token) is null) throw new ItemProjectDeniedException();
    }

    public static async Task EnsureInstanceAsync(SqlConnection c, SqlTransaction? tx, long company, long instance, CancellationToken token)
    {
        await using var command = new SqlCommand("SELECT ItemID FROM dbo.TDIVItemInstance WITH(HOLDLOCK) WHERE CompanyID=@company AND ItemInstanceID=@instance", c, tx);
        command.Parameters.Add("@company",SqlDbType.BigInt).Value=company;
        command.Parameters.Add("@instance",SqlDbType.BigInt).Value=instance;
        var id=await command.ExecuteScalarAsync(token);
        if (id is null) throw new ItemProjectDeniedException();
        await EnsureAsync(c,tx,company,Convert.ToInt64(id),token);
    }
}
