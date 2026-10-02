using System.Security.Claims;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

using Microsoft.Extensions.Configuration;

namespace LaooMemoModule.Controllers;

public abstract class MemoControllerBase(IConfiguration config):ControllerBase
{
 protected static readonly string[] Menus=["50001","50002","50003","50004","50005","50006","50007","50008","50009"];
 protected IConfiguration Config=>config;
 protected bool Scope(out long company,out long user){company=0;user=0;return User.FindFirstValue("user_type")=="COMPANY_USER"&&long.TryParse(User.FindFirstValue("company_id"),out company)&&long.TryParse(User.FindFirstValue("user_id"),out user)&&company>0&&user>0;}
 protected async Task<SqlConnection> Open(CancellationToken ct){var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));await db.OpenAsync(ct);return db;}
 protected Task<bool> Can(SqlConnection db,string menu,string action,CancellationToken ct)=>CompanyMenuAccess.IsAllowedAsync(db,User,menu,action,ct);
 protected async Task<bool> AnyView(SqlConnection db,CancellationToken ct){foreach(var menu in Menus)if(await Can(db,menu,"VIEW",ct))return true;return false;}
 protected ObjectResult Invalid(string message,string description)=>BadRequest(new{message,description});
 protected static string? Clean(string? value)=>string.IsNullOrWhiteSpace(value)?null:value.Trim();
 protected static void Params(SqlCommand cmd,IEnumerable<(string Name,object? Value)> values){foreach(var(name,value)in values)cmd.Parameters.AddWithValue(name,value??DBNull.Value);}
 protected static Task<List<Dictionary<string,object?>>> Query(SqlConnection db,string sql,CancellationToken ct,params(string,object?)[] values)=>Query(db,null,sql,ct,values);
 protected static async Task<List<Dictionary<string,object?>>> Query(SqlConnection db,SqlTransaction? tx,string sql,CancellationToken ct,params(string,object?)[] values){await using var cmd=new SqlCommand(sql,db,tx);Params(cmd,values);await using var reader=await cmd.ExecuteReaderAsync(ct);var result=new List<Dictionary<string,object?>>();while(await reader.ReadAsync(ct)){var row=new Dictionary<string,object?>(StringComparer.OrdinalIgnoreCase);for(var i=0;i<reader.FieldCount;i++)row[reader.GetName(i)]=await reader.IsDBNullAsync(i,ct)?null:reader.GetValue(i);result.Add(row);}return result;}
 protected static Task<int> Execute(SqlConnection db,string sql,CancellationToken ct,params(string,object?)[] values)=>Execute(db,null,sql,ct,values);
 protected static async Task<int> Execute(SqlConnection db,SqlTransaction? tx,string sql,CancellationToken ct,params(string,object?)[] values){await using var cmd=new SqlCommand(sql,db,tx);Params(cmd,values);return await cmd.ExecuteNonQueryAsync(ct);}
 protected static Task<T> Scalar<T>(SqlConnection db,string sql,CancellationToken ct,params(string,object?)[] values)=>Scalar<T>(db,null,sql,ct,values);
 protected static async Task<T> Scalar<T>(SqlConnection db,SqlTransaction? tx,string sql,CancellationToken ct,params(string,object?)[] values){await using var cmd=new SqlCommand(sql,db,tx);Params(cmd,values);var value=await cmd.ExecuteScalarAsync(ct);if(value is null||value==DBNull.Value)return default!;return(T)Convert.ChangeType(value,Nullable.GetUnderlyingType(typeof(T))??typeof(T));}
 protected Task EnsureSettings(SqlConnection db,long company,long user,CancellationToken ct)=>Execute(db,"IF NOT EXISTS(SELECT 1 FROM dbo.TDMESystemSetting WHERE CompanyID=@company) INSERT dbo.TDMESystemSetting(CompanyID,CreateBy) VALUES(@company,@user)",ct,("@company",company),("@user",user));
 protected Task Audit(SqlConnection db,SqlTransaction tx,long company,long memo,long? version,string action,string? detail,long user,CancellationToken ct)=>Execute(db,tx,"INSERT dbo.TDMEAudit(CompanyID,MemoID,VersionID,ActionCode,DetailText,UserID,IpAddress) VALUES(@company,@memo,@version,@action,@detail,@user,@ip)",ct,("@company",company),("@memo",memo),("@version",version),("@action",action),("@detail",Clean(detail)),("@user",user),("@ip",HttpContext.Connection.RemoteIpAddress?.ToString()));
 protected async Task<bool> CanRead(SqlConnection db,long company,long memo,long user,CancellationToken ct)=>await Scalar<int>(db,"SELECT COUNT(*) FROM dbo.TDMEMemo m WHERE m.CompanyID=@company AND m.MemoID=@memo AND (m.OwnerUserID=@user OR EXISTS(SELECT 1 FROM dbo.TDMEMemoApproval a WHERE a.CompanyID=m.CompanyID AND a.MemoID=m.MemoID AND a.AssigneeUserID=@user) OR m.StatusCode=N'DISTRIBUTED' AND EXISTS(SELECT 1 FROM dbo.TDMEMemoRecipient r WHERE r.CompanyID=m.CompanyID AND r.MemoID=m.MemoID AND (r.SubjectType=N'USER' AND r.SubjectID=@user OR r.SubjectType=N'DEPARTMENT' AND r.SubjectID IN(SELECT e.DepartmentOrgUnitID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployee e ON e.CompanyID=ue.CompanyID AND e.EmployeeID=ue.EmployeeID WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1) OR r.SubjectType=N'ROLE' AND r.SubjectID IN(SELECT erg.RoleGroupID FROM dbo.TDADUserEmployee ue JOIN dbo.TDADEmployeeRoleGroup erg ON erg.EmployeeID=ue.EmployeeID AND erg.IsActive=1 AND erg.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (erg.EffectiveTo IS NULL OR erg.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())) WHERE ue.CompanyID=@company AND ue.UserID=@user AND ue.IsActive=1))))",ct,("@company",company),("@memo",memo),("@user",user))>0;
}
public sealed record SettingRequest(int MaxAttachmentMb,string AllowedExtensions,bool AutoDistribute);
public sealed record TypeRequest(string Code,string Name,string Prefix,long? RouteId,long? TemplateId,string Confidentiality,bool Active=true);
public sealed record RouteStepRequest(long UserId,string? Name);
public sealed record RouteRequest(string Code,string Name,List<RouteStepRequest> Steps,bool Active=true);
public sealed record TemplateRequest(string Code,string Name,string? Subject,string? Delta,string? Body,bool Active=true);
public sealed record RecipientRequest(string Role,string SubjectType,long SubjectId);
public sealed record MemoRequest(long TypeId,string Subject,string Recipient,DateTime MemoDate,long? DepartmentId,string Confidentiality,string? Delta,string Body,List<RecipientRequest>? Recipients);
public sealed record SubmitRequest(long RouteId);
public sealed record NoteRequest(string? Note);
public sealed record DecisionRequest(string? Action,string? Note);
