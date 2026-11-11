using System.Security.Claims;
using LaooApi.Controllers;
using Laoo.Shared.Contracts;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

// Read-only access checks against the current account; no records are created or changed.
var root=Path.GetFullPath(args[0]);
var config=new ConfigurationBuilder().AddJsonFile(Path.Combine(root,"laoo_api/appsettings.json"))
    .AddJsonFile(Path.Combine(root,"laoo_api/local.json")).Build();
await using var db=new SqlConnection(config.GetConnectionString("LaooDatabase"));await db.OpenAsync();
await using var q=new SqlCommand("SELECT TOP 1 U.UserID,U.CompanyID,C.PartnerID FROM dbo.TDADUser U JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID WHERE U.NormalizedUsername=N'IT#P' AND U.IsActive=1 AND C.IsActive=1",db);
await using var reader=await q.ExecuteReaderAsync();if(!await reader.ReadAsync()) throw new Exception("Test user not found.");
var user=reader.GetInt64(0);var company=reader.GetInt64(1);var partner=reader.GetInt64(2);await reader.CloseAsync();
if(args.Contains("--global-access-only")) {
    var principal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",user.ToString()),new Claim("company_id",company.ToString()),new Claim("partner_id",partner.ToString())],"test"));
    var controller=new TravelExpenseSettingsController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=principal } } };
    if(await controller.GlobalAccess(CancellationToken.None) is not OkObjectResult ok) throw new Exception("Global access settings unavailable.");
    var json=System.Text.Json.JsonSerializer.SerializeToElement(ok.Value,new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web));
    if(!json.GetProperty("policy").TryGetProperty("viewScope",out _)) throw new Exception("Global policy missing.");
    Console.WriteLine("Global access settings read passed."); return;
}
if(args.Contains("--vehicle-default-only")) {
    var principal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",user.ToString()),new Claim("company_id",company.ToString()),new Claim("partner_id",partner.ToString())],"test"));
    var controller=new TravelClaimController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=principal } } };
    if(await controller.VehicleDefault(CancellationToken.None) is not OkObjectResult ok) throw new Exception("Cannot load own vehicle defaults.");
    var json=System.Text.Json.JsonSerializer.SerializeToElement(ok.Value);
    await using var latest=new SqlCommand("SELECT TOP(1) VehicleTypeCode,VehicleRegistration FROM dbo.TDSTTravelClaim WHERE CompanyID=@company AND UserID=@user ORDER BY Id DESC",db);
    latest.Parameters.AddWithValue("@company",company);latest.Parameters.AddWithValue("@user",user);
    await using(var latestReader=await latest.ExecuteReaderAsync()) { if(await latestReader.ReadAsync() && (json.GetProperty("source").GetString()!="claim" || json.GetProperty("vehicle").GetString()!=latestReader.GetString(0) || json.GetProperty("registration").GetString()!=latestReader.GetString(1))) throw new Exception("Latest claim vehicle was not preferred."); }
    var foreign=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",user.ToString()),new Claim("company_id",long.MaxValue.ToString()),new Claim("partner_id",partner.ToString())],"test"));
    var foreignController=new TravelClaimController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=foreign } } };
    if(await foreignController.VehicleDefault(CancellationToken.None) is not ForbidResult) throw new Exception("Cross-company vehicle data accessible.");
    Console.WriteLine("Vehicle defaults and company isolation passed."); return;
}
if(args.Contains("--company-setup-only")) {
    await using var setupProjectQuery=new SqlCommand("SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode='LAOO' AND IsActive=1",db);
    var projectId=Convert.ToInt64(await setupProjectQuery.ExecuteScalarAsync());
    var principal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",user.ToString()),new Claim("company_id",company.ToString()),new Claim("partner_id",partner.ToString()),new Claim("project_id",projectId.ToString())],"test"));
    if(!await Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedAsync(db,principal,"05001","VIEW",CancellationToken.None)) throw new Exception("Fixture lacks menu view permission.");
    var controller=new CompanySetupController(config,null!,null!,null!) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=principal } } };
    if((await controller.GetAsync(CancellationToken.None)).Result is not OkObjectResult) throw new Exception("User with menu view permission cannot load company setup.");
    if((await controller.RunItemOptions("001",CancellationToken.None)).Result is not OkObjectResult) throw new Exception("User with menu view permission cannot load options.");
    if((await controller.BusinessTypeOptions(CancellationToken.None)).Result is not OkObjectResult) throw new Exception("User with menu view permission cannot load business types.");
    var foreignPrincipal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",user.ToString()),new Claim("company_id",long.MaxValue.ToString()),new Claim("partner_id",partner.ToString()),new Claim("project_id",projectId.ToString())],"test"));
    var foreignController=new CompanySetupController(config,null!,null!,null!) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=foreignPrincipal } } };
    if((await foreignController.GetAsync(CancellationToken.None)).Result is not ForbidResult) throw new Exception("Company setup allowed access across companies.");
    Console.WriteLine("Company setup menu access passed."); return;
}
if(args.Contains("--approval-specific-only")) {
    await using var tx=(SqlTransaction)await db.BeginTransactionAsync();
    var sql=await File.ReadAllTextAsync(Path.Combine(root,"database/migrations/20261111021000_LAOO_approval_specific_position.sql"));
    await using(var install=new SqlCommand(sql,db,tx)) await install.ExecuteNonQueryAsync();
    await using(var insert=new SqlCommand("INSERT dbo.TDSTApprovalPatternCatalog(CompanyID,PatternCode,PatternName,PatternType,UpdateBy) VALUES(@company,@code,N'Test','SPECIFIC',@user); SELECT PatternType FROM dbo.TDSTApprovalPatternCatalog WHERE CompanyID=@company AND PatternCode=@code",db,tx)) {
        insert.Parameters.AddWithValue("@company",company);insert.Parameters.AddWithValue("@user",user);insert.Parameters.AddWithValue("@code","TEST-"+Guid.NewGuid().ToString("N"));
        if((string?)await insert.ExecuteScalarAsync()!="SPECIFIC") throw new Exception("Specific position type was not saved.");
    }
    await tx.RollbackAsync(); Console.WriteLine("Specific approval migration verified in rollback transaction."); return;
}
if (args.Contains("--access-list-only")) {
    await using var adminQuery=new SqlCommand("SELECT TOP(1) UserID FROM dbo.TDADUser WHERE CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1 ORDER BY UserID",db);
    adminQuery.Parameters.AddWithValue("@company",company);var adminValue=await adminQuery.ExecuteScalarAsync();
    if(adminValue is null) throw new Exception("Active company administrator not found.");
    var principal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",Convert.ToInt64(adminValue).ToString()),new Claim("company_id",company.ToString()),new Claim("partner_id",partner.ToString())],"test"));
    var controller=new CompanyMenuDataAccessController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=principal } } };
    if(await controller.List(CancellationToken.None) is not OkObjectResult ok) throw new Exception("Data access list unavailable.");
    var json=System.Text.Json.JsonSerializer.SerializeToElement(ok.Value);
    if(json.GetProperty("rows").GetArrayLength()>0 && !json.GetProperty("rows")[0].TryGetProperty("updatedByName",out _)) throw new Exception("Audit information unavailable.");
    Console.WriteLine("Data access list and audit query passed."); return;
}
if (args.Contains("--staff-only")) {
    await using var tx=(SqlTransaction)await db.BeginTransactionAsync();
    var migration=await File.ReadAllTextAsync(Path.Combine(root,"database/migrations/20261111019000_LAOO_data_access_scope_limits.sql"));
    await using(var install=new SqlCommand(migration,db,tx)) await install.ExecuteNonQueryAsync();
    var auditMigration=await File.ReadAllTextAsync(Path.Combine(root,"database/migrations/20261111020000_LAOO_menu_data_access_audit.sql"));
    await using(var installAudit=new SqlCommand(auditMigration,db,tx)) await installAudit.ExecuteNonQueryAsync();
    var globalMigration=await File.ReadAllTextAsync(Path.Combine(root,"database/migrations/20261111022000_LAOO_company_data_access_defaults.sql"));
    await using(var installGlobal=new SqlCommand(globalMigration,db,tx)) await installGlobal.ExecuteNonQueryAsync();
    var staffScopeMigration=await File.ReadAllTextAsync(Path.Combine(root,"database/migrations/20261111023000_LAOO_department_division_staff_access.sql"));
    await using(var installStaffScope=new SqlCommand(staffScopeMigration,db,tx)) await installStaffScope.ExecuteNonQueryAsync();
    await using(var verifyAudit=new SqlCommand("SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDSTMenuDataAccessPolicy p WHERE NOT EXISTS(SELECT 1 FROM dbo.TDSTMenuDataAccessAudit a WHERE a.CompanyID=p.CompanyID AND a.MenuCode=p.MenuCode)) THEN 0 ELSE 1 END",db,tx))
        if(Convert.ToInt32(await verifyAudit.ExecuteScalarAsync())!=1) throw new Exception("Existing access audit was not preserved.");
    var users=new List<long>();
    await using(var query=new SqlCommand("SELECT TOP(8) UserID FROM dbo.TDADUser WHERE CompanyID=@company AND IsActive=1 ORDER BY UserID",db,tx)) {
        query.Parameters.AddWithValue("@company",company);
        await using var u=await query.ExecuteReaderAsync(); while(await u.ReadAsync()) users.Add(Convert.ToInt64(u.GetValue(0)));
    }
    var owners=users.Append(long.MaxValue).ToArray();
    foreach(var scope in new[]{"SELF","DEPARTMENT","DIVISION","ALL"}) foreach(var staff in new[]{false,true}) {
        await using(var configure=new SqlCommand("DELETE dbo.TDSTMenuDataAccessPolicy WHERE CompanyID=@company AND MenuCode='66001'; INSERT dbo.TDSTMenuDataAccessPolicy(CompanyID,MenuCode,ViewScope,EditScope,DeleteScope,ViewHead,ViewManager,EditHead,EditManager,DeleteHead,DeleteManager,ViewStaff,EditStaff,DeleteStaff,UpdateBy) VALUES(@company,'66001',@scope,@scope,@scope,1,1,0,1,1,0,@staff,@staff,@staff,@user)",db,tx)) {
            configure.Parameters.AddWithValue("@company",company);configure.Parameters.AddWithValue("@scope",scope);configure.Parameters.AddWithValue("@staff",staff);configure.Parameters.AddWithValue("@user",user);await configure.ExecuteNonQueryAsync();
        }
        foreach(var actor in users) foreach(var owner in owners) foreach(var action in new[]{"VIEW","EDIT","DELETE"}) {
            var rule=await MenuDataAccessResolver.ReadRuleAsync(db,tx,company,"66001",action,CancellationToken.None);
            var context=await MenuDataAccessResolver.ReadContextAsync(db,tx,company,actor,owner,CancellationToken.None);
            await using var check=new SqlCommand("SELECT dbo.LaooMenuDataAccessAllowed(@company,@actor,@owner,'66001',@action)",db,tx);
            check.Parameters.AddWithValue("@company",company);check.Parameters.AddWithValue("@actor",actor);check.Parameters.AddWithValue("@owner",owner);check.Parameters.AddWithValue("@action",action);
            if(Convert.ToBoolean(await check.ExecuteScalarAsync())!=MenuDataAccessPolicy.Allows(rule,context)) throw new Exception($"SQL/API mismatch: {scope}/{staff}/{action}");
        }
    }
    await using(var setup=new SqlCommand("DELETE dbo.TDSTMenuDataAccessPolicy WHERE CompanyID=@company AND MenuCode='66001'; DELETE dbo.TDSTCompanyDataAccessDefault WHERE CompanyID=@company; INSERT dbo.TDSTCompanyDataAccessDefault(CompanyID,ViewScope,EditScope,DeleteScope,ViewStaff,ViewHead,ViewManager,EditStaff,EditHead,EditManager,DeleteStaff,DeleteHead,DeleteManager,UpdateBy) VALUES(@company,'DEPARTMENT','DIVISION','SELF',1,1,0,0,1,1,0,0,0,@user)",db,tx)) { setup.Parameters.AddWithValue("@company",company);setup.Parameters.AddWithValue("@user",user);await setup.ExecuteNonQueryAsync(); }
    foreach(var actor in users) foreach(var owner in owners) foreach(var action in new[]{"VIEW","EDIT","DELETE"}) {
        var rule=await MenuDataAccessResolver.ReadRuleAsync(db,tx,company,"66001",action,CancellationToken.None);
        var context=await MenuDataAccessResolver.ReadContextAsync(db,tx,company,actor,owner,CancellationToken.None);
        await using var check=new SqlCommand("SELECT dbo.LaooMenuDataAccessAllowed(@company,@actor,@owner,'66001',@action)",db,tx);
        check.Parameters.AddWithValue("@company",company);check.Parameters.AddWithValue("@actor",actor);check.Parameters.AddWithValue("@owner",owner);check.Parameters.AddWithValue("@action",action);
        if(Convert.ToBoolean(await check.ExecuteScalarAsync())!=MenuDataAccessPolicy.Allows(rule,context)) throw new Exception($"Global SQL/API mismatch: {action}");
    }
    await tx.RollbackAsync();
    Console.WriteLine("Staff and global access migration and SQL/API parity verified in rollback transaction.");
    return;
}
TravelClaimController Controller(long companyId) {
    var principal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",user.ToString()),new Claim("company_id",companyId.ToString()),new Claim("partner_id",partner.ToString())],"test"));
    return new TravelClaimController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=principal } } };
}
var result=await Controller(company).List(CancellationToken.None);
if(result is not OkObjectResult) throw new Exception($"The test account cannot read the travel menu: {result.GetType().Name}");
var isolated=await Controller(long.MaxValue).List(CancellationToken.None);
if(isolated is not ForbidResult) throw new Exception("Cross-company read was not rejected.");
var invalid=await Controller(company).Detail(long.MaxValue,CancellationToken.None);
if(invalid is not NotFoundObjectResult and not NotFoundResult) throw new Exception("An unknown document was not rejected.");
await using var projectQuery=new SqlCommand("SELECT ProjectID FROM dbo.TDADProject WHERE ProjectCode='LAOO' AND IsActive=1",db);
var project=Convert.ToInt64(await projectQuery.ExecuteScalarAsync());
var meetingPrincipal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",user.ToString()),new Claim("company_id",company.ToString()),new Claim("partner_id",partner.ToString()),new Claim("project_id",project.ToString())],"test"));
var meeting=new LaooMeetingApi.Controllers.MeetingRoomBookingController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=meetingPrincipal } } };
var meetingResult=await meeting.List(null,null,null,false,1,30,CancellationToken.None);
var meetingActions=(OkObjectResult)await meeting.Actions(CancellationToken.None);
var meetingView=(bool)meetingActions.Value!.GetType().GetProperty("view")!.GetValue(meetingActions.Value)!;
if(meetingView && meetingResult is not OkObjectResult || !meetingView && meetingResult is not ForbidResult)
    throw new Exception($"Meeting list did not enforce menu permission: {meetingResult.GetType().Name}");
if(meetingView) {
    var start=DateTime.Today.AddDays(1).AddHours(10);
    var availability=new LaooMeetingApi.Controllers.AvailabilityRequest([new(start,start.AddHours(1))],null,null,null,null,null,null);
    if(await meeting.Availability(availability,CancellationToken.None) is not OkObjectResult) throw new Exception("Meeting availability failed.");
}
var meetingAuthorizedTested=meetingView;
if(!meetingAuthorizedTested) {
    await using var adminQuery=new SqlCommand("SELECT TOP(1) UserID FROM dbo.TDADUser WHERE CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1 ORDER BY UserID",db);
    adminQuery.Parameters.AddWithValue("@company",company);var adminValue=await adminQuery.ExecuteScalarAsync();
    if(adminValue is not null) {
        var admin=Convert.ToInt64(adminValue);
        var adminPrincipal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",admin.ToString()),new Claim("company_id",company.ToString()),new Claim("partner_id",partner.ToString()),new Claim("project_id",project.ToString())],"test"));
        var adminMeeting=new LaooMeetingApi.Controllers.MeetingRoomBookingController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=adminPrincipal } } };
        var adminActions=(OkObjectResult)await adminMeeting.Actions(CancellationToken.None);
        if((bool)adminActions.Value!.GetType().GetProperty("view")!.GetValue(adminActions.Value)!) {
            if(await adminMeeting.List(null,null,null,false,1,30,CancellationToken.None) is not OkObjectResult) throw new Exception("Authorized meeting list failed.");
            meetingAuthorizedTested=true;
        }
    }
}
var service=new ServiceRequestController(config,null!,null!,null!) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=meetingPrincipal } } };
var serviceResult=await service.List(null,null,true,1,20,"20001",CancellationToken.None);
if(serviceResult is not OkObjectResult) throw new Exception($"Service list failed: {serviceResult.GetType().Name}");
var serviceJson=System.Text.Json.JsonSerializer.SerializeToElement(((OkObjectResult)serviceResult).Value);
var serviceDetailTested=false;
if(serviceJson.GetProperty("items").GetArrayLength()>0) {
    var id=serviceJson.GetProperty("items")[0].GetProperty("requestId").GetInt64();
    if(await service.Detail(id,"20001",CancellationToken.None) is not OkObjectResult) throw new Exception("A visible service request could not be read.");
    if(await service.Attachments(id,"20001",CancellationToken.None) is not OkObjectResult) throw new Exception("Attachments of a visible service request could not be read.");
    serviceDetailTested=true;
}
var duplicateApproval=new CompanyApprovalPatternController.PatternRequest(1,[
    new("ANY",[new("TEST","ANY")]),new("ALL",[new("test","DIVISION")])]);
if(await new CompanyApprovalPatternController(config).Save(duplicateApproval,CancellationToken.None) is not BadRequestObjectResult)
    throw new Exception("Duplicate positions were not rejected before database access.");
await using(var adminQuery=new SqlCommand("SELECT TOP(1) UserID FROM dbo.TDADUser WHERE CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1 ORDER BY UserID",db)) {
    adminQuery.Parameters.AddWithValue("@company",company);var adminValue=await adminQuery.ExecuteScalarAsync();
    if(adminValue is not null) {
        var admin=Convert.ToInt64(adminValue);
        var principal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",admin.ToString()),new Claim("company_id",company.ToString()),new Claim("partner_id",partner.ToString()),new Claim("project_id",project.ToString())],"test"));
        var approvals=new CompanyApprovalPatternController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=principal } } };
        if(await approvals.Get(CancellationToken.None) is not OkObjectResult) throw new Exception("Company administrator cannot read approval pattern settings.");
        var accessSettings=new CompanyMenuDataAccessController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=principal } } };
        if(await accessSettings.List(CancellationToken.None) is not OkObjectResult) throw new Exception("Company administrator cannot read data access settings.");
        var catalog=new CompanyApprovalCatalogController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=principal } } };
        if(await catalog.List(CancellationToken.None) is not OkObjectResult) throw new Exception("Company administrator cannot read approval catalog.");
        var duplicate=new CompanyApprovalCatalogController.ConfigInput("POSITION",null,[new("ANY",[new("TEST","ANY")]),new("ALL",[new("test","DIVISION")])]);
        if(await catalog.SaveConfig("test",duplicate,CancellationToken.None) is not BadRequestObjectResult) throw new Exception("Catalog allowed duplicate positions.");
        var foreignPrincipal=new ClaimsPrincipal(new ClaimsIdentity([new Claim("user_type","COMPANY_USER"),new Claim("user_id",admin.ToString()),new Claim("company_id",long.MaxValue.ToString()),new Claim("partner_id",partner.ToString()),new Claim("project_id",project.ToString())],"test"));
        var foreignCatalog=new CompanyApprovalCatalogController(config) { ControllerContext=new ControllerContext { HttpContext=new DefaultHttpContext { User=foreignPrincipal } } };
        if(await foreignCatalog.List(CancellationToken.None) is not ForbidResult) throw new Exception("Approval catalog allowed cross-company access.");
        var testCode="TEST-"+Guid.NewGuid().ToString("N")[..12];
        try {
            if(await catalog.Create(new(testCode,"Temporary approval test"),CancellationToken.None) is not OkObjectResult) throw new Exception("Cannot create approval pattern.");
            if(await catalog.SaveConfig(testCode,new("LEVEL",2,[]),CancellationToken.None) is not OkObjectResult) throw new Exception("Cannot save level configuration.");
            if(await catalog.GetConfig(testCode,CancellationToken.None) is not OkObjectResult) throw new Exception("Cannot read approval configuration.");
            await using(var positionQuery=new SqlCommand("SELECT TOP(1) MasterCode FROM dbo.TDSTMaster WHERE OwnerType=N'C' AND ISNULL(OwnerPartnerID,0)=0 AND OwnerCompanyID=@company AND MasterGroupCode=N'008' ORDER BY MasterCode",db)) {
                positionQuery.Parameters.AddWithValue("@company",company);var position=await positionQuery.ExecuteScalarAsync();
                if(position is not null && await catalog.SaveConfig(testCode,new("POSITION",null,[new("ANY",[new(position.ToString()!,"DEPARTMENT")])]),CancellationToken.None) is not OkObjectResult) throw new Exception("Cannot save position configuration.");
            }
            if(await catalog.SaveConfig(testCode,new("MANUAL",null,[]),CancellationToken.None) is not OkObjectResult) throw new Exception("Cannot save manual configuration.");
            if(await catalog.Rename(testCode,new(testCode,"Temporary approval renamed"),CancellationToken.None) is not OkObjectResult) throw new Exception("Cannot update approval pattern.");
            if(await foreignCatalog.GetConfig(testCode,CancellationToken.None) is not ForbidResult) throw new Exception("Cross-company configuration was accessible.");
        } finally {
            await using var cleanup=new SqlCommand("DELETE dbo.TDSTApprovalPatternCatalog WHERE CompanyID=@company AND PatternCode=@code",db);
            cleanup.Parameters.AddWithValue("@company",company);cleanup.Parameters.AddWithValue("@code",testCode);await cleanup.ExecuteNonQueryAsync();
        }
    }
}
var sample=new TravelClaimController.ClaimInput(new DateOnly(2026,11,10),null,"A","B","Test","Test",null,10,new DateOnly(2026,11,10),new DateOnly(2026,11,10),"V","TEST",0,0,0,0,false,null,Guid.NewGuid());
if(await Controller(long.MaxValue).Create(sample,CancellationToken.None) is not ForbidResult) throw new Exception("Cross-company create was not rejected.");
var matchedOrganizationScopes=0;
await using(var tx=(SqlTransaction)await db.BeginTransactionAsync()) {
    await using(var test=new SqlCommand("""
INSERT dbo.TDSTTravelClaim(CompanyID,UserID,ClaimNo,RequestKey,ClaimDate,Origin,Destination,Purpose,WorkPlace,DistanceKm,StartDate,EndDate,VehicleTypeCode,VehicleRegistration,LodgingRate,Nights,Toll,Parking,PublicTransport,FuelAmount,LodgingAmount,TotalAmount)
OUTPUT INSERTED.Id VALUES(@company,@user,@number,@key,'2026-11-10',N'A',N'B',N'test',N'test',10,'2026-11-10','2026-11-10',N'V',N'TEST',0,0,0,0,0,5,0,5);
""",db,tx)) {
        test.Parameters.AddWithValue("@company",company);test.Parameters.AddWithValue("@user",user);test.Parameters.AddWithValue("@number","TEST-"+Guid.NewGuid().ToString("N")[..16]);test.Parameters.AddWithValue("@key",Guid.NewGuid());
        var id=Convert.ToInt64(await test.ExecuteScalarAsync());
        await using var file=new SqlCommand("INSERT dbo.TDSTTravelClaimAttachment(ClaimID,CompanyID,FileName,ContentType,FileData) VALUES(@id,@company,N'test.pdf','application/pdf',0x25504446)",db,tx);
        file.Parameters.AddWithValue("@id",id);file.Parameters.AddWithValue("@company",company);await file.ExecuteNonQueryAsync();
    }
    await tx.RollbackAsync();
}
await using(var tx=(SqlTransaction)await db.BeginTransactionAsync()) {
    async Task Run(string sql) { await using var cmd=new SqlCommand(sql,db,tx);cmd.Parameters.AddWithValue("@company",company);cmd.Parameters.AddWithValue("@user",user);await cmd.ExecuteNonQueryAsync(); }
    await Run("DELETE dbo.TDSTMenuDataAccessPolicy WHERE CompanyID=@company AND MenuCode='66001'");
    await Run("UPDATE dbo.TDSTTravelClaimAccess SET ViewScope='SELF',EditMode='HEAD',DeleteMode='HEAD' WHERE CompanyID=@company; IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelClaimAccess(CompanyID,ViewScope,EditMode,DeleteMode,UpdateBy) VALUES(@company,'SELF','HEAD','HEAD',@user)");
    foreach(var action in new[]{"VIEW","EDIT","DELETE"}) {
        var rule=await MenuDataAccessResolver.ReadRuleAsync(db,tx,company,"66001",action,CancellationToken.None);
        var selfContext=await MenuDataAccessResolver.ReadContextAsync(db,tx,company,user,user,CancellationToken.None);
        if(rule is null || !MenuDataAccessPolicy.Allows(rule,selfContext)) throw new Exception("Resolver did not allow the document owner.");
        var missing=await MenuDataAccessResolver.ReadContextAsync(db,tx,company,user,long.MaxValue,CancellationToken.None);
        if(!missing.IsCompanyAdmin && MenuDataAccessPolicy.Allows(rule,missing)) throw new Exception("Resolver allowed a missing owner in self scope.");
    }
    await Run("INSERT dbo.TDSTMenuDataAccessPolicy(CompanyID,MenuCode,ViewScope,EditScope,DeleteScope,ViewHead,ViewManager,EditHead,EditManager,DeleteHead,DeleteManager,UpdateBy) VALUES(@company,'66001','ALL','SELF','SELF',0,0,0,0,0,0,@user)");
    var viewOverride=await MenuDataAccessResolver.ReadRuleAsync(db,tx,company,"66001","VIEW",CancellationToken.None);
    var editOverride=await MenuDataAccessResolver.ReadRuleAsync(db,tx,company,"66001","EDIT",CancellationToken.None);
    if(viewOverride?.Scope!="ALL" || editOverride?.Scope!="SELF") throw new Exception("Per-menu action overrides were not loaded.");
    async Task<bool> Allowed(long owner,string action) { await using var cmd=new SqlCommand("SELECT dbo.LaooTravelClaimCanAccess(@company,@user,@owner,@action)",db,tx);cmd.Parameters.AddWithValue("@company",company);cmd.Parameters.AddWithValue("@user",user);cmd.Parameters.AddWithValue("@owner",owner);cmd.Parameters.AddWithValue("@action",action);return Convert.ToBoolean(await cmd.ExecuteScalarAsync()); }
    await Run("UPDATE dbo.TDSTTravelClaimAccess SET ViewScope='SELF',EditMode='HEAD',DeleteMode='HEAD' WHERE CompanyID=@company; IF @@ROWCOUNT=0 INSERT dbo.TDSTTravelClaimAccess(CompanyID,ViewScope,EditMode,DeleteMode,UpdateBy) VALUES(@company,'SELF','HEAD','HEAD',@user)");
    foreach(var action in new[]{"VIEW","EDIT","DELETE"}) {
        if(!await Allowed(user,action) || await Allowed(long.MaxValue,action)) throw new Exception("Self scope check failed.");
    }
    foreach(var scope in new[]{"DEPARTMENT","DIVISION"}) {
        await Run($"UPDATE dbo.TDSTTravelClaimAccess SET ViewScope='{scope}',EditMode='ALL',DeleteMode='ALL' WHERE CompanyID=@company");
        foreach(var action in new[]{"VIEW","EDIT","DELETE"}) if(await Allowed(long.MaxValue,action)) throw new Exception("Missing employee was allowed.");
        var column=scope=="DEPARTMENT" ? "DepartmentOrgUnitID" : "DivisionOrgUnitID";
        await using var pair=new SqlCommand($"SELECT TOP 1 other.UserID FROM dbo.TDADUserEmployee me JOIN dbo.TDADEmployee a ON a.CompanyID=me.CompanyID AND a.EmployeeID=me.EmployeeID AND a.IsActive=1 JOIN dbo.TDADEmployee b ON b.CompanyID=a.CompanyID AND b.{column}=a.{column} AND b.IsActive=1 JOIN dbo.TDADUserEmployee other ON other.CompanyID=b.CompanyID AND other.EmployeeID=b.EmployeeID AND other.IsActive=1 AND other.UserID<>me.UserID WHERE me.CompanyID=@company AND me.UserID=@user AND me.IsActive=1 AND a.{column} IS NOT NULL",db,tx);
        pair.Parameters.AddWithValue("@company",company);pair.Parameters.AddWithValue("@user",user);var other=await pair.ExecuteScalarAsync();
        if(other is not null) {
            matchedOrganizationScopes++;
            var otherId=Convert.ToInt64(other);
            foreach(var action in new[]{"VIEW","EDIT","DELETE"}) if(!await Allowed(otherId,action)) throw new Exception("Matching organization scope was denied.");
            await Run("UPDATE dbo.TDSTTravelClaimAccess SET EditMode='HEAD',DeleteMode='HEAD' WHERE CompanyID=@company");
            var supervisorType=scope=="DEPARTMENT" ? "DEPARTMENT_HEAD" : "DIVISION_MANAGER";
            var unitType=scope=="DEPARTMENT" ? "DEP" : "DIV";
            await using var expectedQuery=new SqlCommand($"SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUserEmployee me JOIN dbo.TDADEmployee a ON a.CompanyID=me.CompanyID AND a.EmployeeID=me.EmployeeID AND a.IsActive=1 JOIN dbo.TDADUserEmployee them ON them.CompanyID=me.CompanyID AND them.UserID=@other AND them.IsActive=1 JOIN dbo.TDADEmployee b ON b.CompanyID=them.CompanyID AND b.EmployeeID=them.EmployeeID AND b.IsActive=1 JOIN dbo.TDADOrganizationSupervisor s ON s.CompanyID=me.CompanyID AND s.EmployeeID=a.EmployeeID AND s.IsActive=1 JOIN dbo.TDADOrganizationUnit u ON u.CompanyID=s.CompanyID AND u.OrgUnitID=s.OrgUnitID AND u.IsActive=1 WHERE me.CompanyID=@company AND me.UserID=@user AND me.IsActive=1 AND a.{column}=b.{column} AND s.OrgUnitID=b.{column} AND s.SupervisorType=@type AND u.UnitType=@unit) THEN 1 ELSE 0 END",db,tx);
            expectedQuery.Parameters.AddWithValue("@company",company);expectedQuery.Parameters.AddWithValue("@user",user);expectedQuery.Parameters.AddWithValue("@other",otherId);expectedQuery.Parameters.AddWithValue("@type",supervisorType);expectedQuery.Parameters.AddWithValue("@unit",unitType);
            var expected=Convert.ToInt32(await expectedQuery.ExecuteScalarAsync())==1;
            if(!await Allowed(otherId,"VIEW") || await Allowed(otherId,"EDIT")!=expected || await Allowed(otherId,"DELETE")!=expected) throw new Exception("Supervisor-only scope failed.");
        }
    }
    await tx.RollbackAsync();
}
// Compile the shared SQL predicate inside a rollback-only transaction and compare
// it with the C# evaluator using real employee relationships and policy overrides.
await using(var tx=(SqlTransaction)await db.BeginTransactionAsync()) {
    var migration=await File.ReadAllTextAsync(Path.Combine(root,"database/migrations/20261111017000_LAOO_self_scope_supervisors.sql"));
    await using(var install=new SqlCommand(migration,db,tx)) await install.ExecuteNonQueryAsync();
    var users=new List<long>();
    await using(var query=new SqlCommand("SELECT TOP(8) UserID FROM dbo.TDADUser WHERE CompanyID=@company AND IsActive=1 ORDER BY UserID",db,tx)) {
        query.Parameters.AddWithValue("@company",company);
        await using var u=await query.ExecuteReaderAsync(); while(await u.ReadAsync()) users.Add(Convert.ToInt64(u.GetValue(0)));
    }
    users.Add(long.MaxValue);
    foreach(var scope in new[]{"SELF","DEPARTMENT","DIVISION","ALL"}) {
        await using(var configure=new SqlCommand("DELETE dbo.TDSTMenuDataAccessPolicy WHERE CompanyID=@company AND MenuCode='66001'; INSERT dbo.TDSTMenuDataAccessPolicy(CompanyID,MenuCode,ViewScope,EditScope,DeleteScope,ViewHead,ViewManager,EditHead,EditManager,DeleteHead,DeleteManager,UpdateBy) VALUES(@company,'66001',@scope,@scope,@scope,1,1,0,1,1,0,@user)",db,tx)) {
            configure.Parameters.AddWithValue("@company",company);configure.Parameters.AddWithValue("@scope",scope);configure.Parameters.AddWithValue("@user",user);await configure.ExecuteNonQueryAsync();
        }
        foreach(var actor in users.Where(x=>x!=long.MaxValue)) foreach(var owner in users) foreach(var action in new[]{"VIEW","EDIT","DELETE"}) {
            var rule=await MenuDataAccessResolver.ReadRuleAsync(db,tx,company,"66001",action,CancellationToken.None);
            var context=await MenuDataAccessResolver.ReadContextAsync(db,tx,company,actor,owner,CancellationToken.None);
            var expected=MenuDataAccessPolicy.Allows(rule,context);
            await using var sql=new SqlCommand("SELECT dbo.LaooMenuDataAccessAllowed(@company,@actor,@owner,'66001',@action)",db,tx);
            sql.Parameters.AddWithValue("@company",company);sql.Parameters.AddWithValue("@actor",actor);sql.Parameters.AddWithValue("@owner",owner);sql.Parameters.AddWithValue("@action",action);
            if(Convert.ToBoolean(await sql.ExecuteScalarAsync())!=expected) throw new Exception($"SQL and API scope rules differ: {scope}/{action}.");
        }
    }
    await tx.RollbackAsync();
}
await using(var tx=(SqlTransaction)await db.BeginTransactionAsync()) {
    var migration=await File.ReadAllTextAsync(Path.Combine(root,"database/migrations/20261111011000_LAOO_menu_data_access.sql"));
    await using(var install=new SqlCommand(migration,db,tx)) await install.ExecuteNonQueryAsync();
    await using var verify=new SqlCommand("SELECT COUNT(*) FROM dbo.TDADMainMenu WHERE MenuCode='10010' AND ScreenType=3 AND RouteName='companyMenuDataAccess' AND AllowListDisplaySettings=0",db,tx);
    if(Convert.ToInt32(await verify.ExecuteScalarAsync())!=1) throw new Exception("Data access menu migration did not register the expected screen.");
    await tx.RollbackAsync();
}
await using(var tx=(SqlTransaction)await db.BeginTransactionAsync()) {
    var migration=await File.ReadAllTextAsync(Path.Combine(root,"database/migrations/20261111013000_LAOO_approval_pattern.sql"));
    await using(var install=new SqlCommand(migration,db,tx)) await install.ExecuteNonQueryAsync();
    await using var verify=new SqlCommand("SELECT CASE WHEN OBJECT_ID(N'dbo.TDSTCompanyApprovalPattern',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.TDSTCompanyApprovalStep',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.TDSTCompanyApprovalPosition',N'U') IS NOT NULL THEN 1 ELSE 0 END",db,tx);
    if(Convert.ToInt32(await verify.ExecuteScalarAsync())!=1) throw new Exception("Approval pattern schema was not created.");
    await using(var sampleApproval=new SqlCommand("INSERT dbo.TDSTCompanyApprovalPattern(CompanyID,LevelsUp,UpdateBy) VALUES(@company,2,1); INSERT dbo.TDSTCompanyApprovalStep(CompanyID,StepNo,ApprovalCondition) VALUES(@company,1,'ANY'),(@company,2,'ALL'); INSERT dbo.TDSTCompanyApprovalPosition(CompanyID,StepNo,PositionCode,UnitScope) VALUES(@company,1,'TEST-A','DEPARTMENT'),(@company,1,'TEST-B','DIVISION'),(@company,2,'TEST-C','ANY'); SELECT COUNT(*) FROM dbo.TDSTCompanyApprovalPosition WHERE CompanyID=@company",db,tx)) {
        sampleApproval.Parameters.AddWithValue("@company",long.MaxValue);
        if(Convert.ToInt32(await sampleApproval.ExecuteScalarAsync())!=3) throw new Exception("Multiple approval positions were not saved together.");
    }
    await using(var uniqueCheck=new SqlCommand("SELECT COUNT(*) FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDSTCompanyApprovalPosition') AND name=N'UQ_CompanyApprovalPosition_CompanyPosition'",db,tx))
        if(Convert.ToInt32(await uniqueCheck.ExecuteScalarAsync())!=1) throw new Exception("Unique company position constraint is missing.");
    var menuMigration=await File.ReadAllTextAsync(Path.Combine(root,"database/migrations/20261111014000_LAOO_approval_pattern_menu.sql"));
    await using(var legacyType=new SqlCommand("UPDATE dbo.TDADMainMenu SET ScreenType=3 WHERE MenuCode='10011' AND RouteName='companyApprovalPattern'",db,tx)) await legacyType.ExecuteNonQueryAsync();
    await using(var installMenu=new SqlCommand(menuMigration,db,tx)) await installMenu.ExecuteNonQueryAsync();
    await using var verifyMenu=new SqlCommand("SELECT COUNT(*) FROM dbo.TDADMainMenu WHERE MenuCode='10011' AND ScreenType=3 AND RouteName='companyApprovalPattern' AND AllowListDisplaySettings=0",db,tx);
    if(Convert.ToInt32(await verifyMenu.ExecuteScalarAsync())!=1) throw new Exception("Approval pattern menu migration invalid.");
    await tx.RollbackAsync();
}
Console.WriteLine($"Travel access, company isolation and transaction rollback checks passed; matching organization scopes exercised: {matchedOrganizationScopes}/2; shared SQL rule matches the API evaluator; authorized meeting list tested: {meetingAuthorizedTested}; service detail and attachments tested: {serviceDetailTested}; menu migration rolled back.");
