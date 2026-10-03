using System.Data;
using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooProviderModule.Controllers;

public abstract class ProviderControllerBase(IConfiguration configuration) : ControllerBase
{
    protected async Task<SqlConnection> Open(CancellationToken token){var db=new SqlConnection(configuration.GetConnectionString("LaooDatabase"));await db.OpenAsync(token);return db;}
    protected bool CompanyScope(out long company,out long user){company=0;user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}
    protected long? CompanyId()=>long.TryParse(User.FindFirstValue("company_id"),out var id)?id:null;
    protected bool SupportScope()=>User.FindFirstValue("user_type")=="LAOO_SUPPORT"&&long.TryParse(User.FindFirstValue("laoo_user_id"),out var id)&&id>0;
    protected long ActorId()=>long.TryParse(User.FindFirstValue("user_id")??User.FindFirstValue("laoo_user_id"),out var id)?id:0;
    protected async Task<bool> Can(SqlConnection db,string menu,string action,CancellationToken token)
    {
        if(User.FindFirstValue("user_type")=="COMPANY_USER")return await CompanyMenuAccess.IsAllowedAsync(db,User,menu,action,token);
        if(User.FindFirstValue("user_type")!="LAOO_SUPPORT"||!long.TryParse(User.FindFirstValue("laoo_user_id"),out var id))return false;
        return await ProviderDb.Scalar<int>(db,"SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADLaooUserPermission up JOIN dbo.TDADPermission p ON p.PermissionID=up.PermissionID AND p.ProjectID=up.ProjectID JOIN dbo.TDADProject pr ON pr.ProjectID=p.ProjectID AND pr.ProjectCode=N'LAOO_PROVIDER' AND pr.IsActive=1 JOIN dbo.TDADLaooUser u ON u.LaooUserID=up.LaooUserID AND u.IsActive=1 WHERE up.LaooUserID=@id AND up.IsAllowed=1 AND up.IsActive=1 AND p.IsActive=1 AND p.ScreenCode=@menu AND p.ActionCode=@action) THEN 1 ELSE 0 END",token,("@id",id),("@menu",menu),("@action",action))==1;
    }
    protected async Task EnsureSettings(SqlConnection db,long company,long user,CancellationToken token)=>await ProviderDb.Execute(db,"IF NOT EXISTS(SELECT 1 FROM dbo.TDPRSystemSetting WHERE CompanyID=@company) INSERT dbo.TDPRSystemSetting(CompanyID,CreateBy) VALUES(@company,@user)",token,("@company",company),("@user",user));
    protected async Task Audit(SqlConnection db,SqlTransaction tx,long? company,string entity,long id,string action,string? detail,long user,CancellationToken token)=>await ProviderDb.Execute(db,tx,"INSERT dbo.TDPRAudit(CompanyID,EntityType,EntityID,ActionCode,DetailText,UserID,IpAddress) VALUES(@company,@entity,@id,@action,@detail,@user,@ip)",token,("@company",company),("@entity",entity),("@id",id),("@action",action),("@detail",detail),("@user",user),("@ip",HttpContext.Connection.RemoteIpAddress?.ToString()));
    protected static bool ValidUrl(string? value)=>string.IsNullOrWhiteSpace(value)||Uri.TryCreate(value,UriKind.Absolute,out var uri)&&uri.Scheme is "http" or "https";
    protected static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
}

internal static class ProviderDb
{
    static void Params(SqlCommand command,IEnumerable<(string Name,object? Value)> values){foreach(var(name,value)in values){if(command.Parameters.Contains(name))continue;command.Parameters.AddWithValue(name,value??DBNull.Value);}}
    public static async Task<List<Dictionary<string,object?>>> Query(SqlConnection db,string sql,CancellationToken token,params(string,object?)[] values)=>await Query(db,null,sql,token,values);
    public static async Task<List<Dictionary<string,object?>>> Query(SqlConnection db,SqlTransaction? tx,string sql,CancellationToken token,params(string,object?)[] values){await using var cmd=new SqlCommand(sql,db,tx);Params(cmd,values);await using var reader=await cmd.ExecuteReaderAsync(token);var result=new List<Dictionary<string,object?>>(32);while(await reader.ReadAsync(token)){var row=new Dictionary<string,object?>(StringComparer.OrdinalIgnoreCase);for(var i=0;i<reader.FieldCount;i++)row[reader.GetName(i)]=await reader.IsDBNullAsync(i,token)?null:reader.GetValue(i);result.Add(row);}return result;}
    public static async Task<int> Execute(SqlConnection db,string sql,CancellationToken token,params(string,object?)[] values)=>await Execute(db,null,sql,token,values);
    public static async Task<int> Execute(SqlConnection db,SqlTransaction? tx,string sql,CancellationToken token,params(string,object?)[] values){await using var cmd=new SqlCommand(sql,db,tx);Params(cmd,values);return await cmd.ExecuteNonQueryAsync(token);}
    public static async Task<T> Scalar<T>(SqlConnection db,string sql,CancellationToken token,params(string,object?)[] values)=>await Scalar<T>(db,null,sql,token,values);
    public static async Task<T> Scalar<T>(SqlConnection db,SqlTransaction? tx,string sql,CancellationToken token,params(string,object?)[] values){await using var cmd=new SqlCommand(sql,db,tx);Params(cmd,values);var value=await cmd.ExecuteScalarAsync(token);return value is null or DBNull?default!:(T)Convert.ChangeType(value,Nullable.GetUnderlyingType(typeof(T))??typeof(T));}
}

public sealed record ProviderSettings(int ServiceCoverMaxMb,int ReviewExpiryDays,int BayesianMinimumReviews,double RatingWeightNoGps,double RecencyWeightNoGps,double RatingWeightGps,double DistanceWeightGps,double RecencyWeightGps,double MaxDistanceKm);
public sealed record LocationRequest(string Code,string Type,long? ParentId,string Name,string? NameEn,decimal? Latitude,decimal? Longitude,int SortOrder=0,bool Active=true);
public sealed record ServiceTypeRequest(string Code,string Name,string? Description,string? IconName,int SortOrder=0,bool Active=true);
public sealed record BranchRequest(long? BranchId,string Name,string? Address,string? Telephone,decimal? Latitude,decimal? Longitude,bool IsPrimary=false);
public sealed record ProfileRequest(string Slug,string DisplayName,string? Summary,string? Address,string? Telephone,string? Email,string? LineId,string? LineUrl,string? WebsiteUrl,List<long>? ServiceTypeIds,List<long>? AreaIds,List<BranchRequest>? Branches);
public sealed record DecisionRequest(string? Reason);
public sealed record ReviewLinkRequest(long ServiceTypeId,long? BranchId,DateTime ServiceDate,string? ReferenceNo);
public sealed record ReviewSubmit(int Quality,int Punctuality,int Service,int Value,string? Comment);
public sealed record ModerateRequest(bool Hidden,string? Reason);
