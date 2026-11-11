using Laoo.Shared.Contracts;
using LaooApi.Services.Assistant;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController, Authorize, Route("api/assistant/menu-guide")]
public sealed class AssistantMenuGuideController(IConfiguration configuration) : ControllerBase
{
    private async Task<List<GuideItem>?> AllowedMenus(CancellationToken token, Func<string, string, string, bool> filter)
    {
        await using var db = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await db.OpenAsync(token);
        if (!await AssistantCapabilityAccess.IsAllowed(db, User, AssistantCapabilities.MenuGuide.Id, token)) return null;
        var navigation = new NavigationController(configuration) { ControllerContext = ControllerContext };
        var response = await navigation.GetProjects(token);
        var projects = response.Value ?? (response.Result as OkObjectResult)?.Value as List<LaooApi.Models.Navigation.NavigationProjectResponse>;
        if (projects is null) return null;
        var result = new List<GuideItem>();
        foreach (var project in projects)
        foreach (var group in project.MenuGroups)
        foreach (var item in group.Items)
        {
            if (!filter(project.ProjectCode, item.MenuCode, item.MenuName)) continue;
            var path = item.RoutePath;
            if (string.IsNullOrWhiteSpace(path) || !path.StartsWith('/') || path.StartsWith("//") || path.Contains('\\') || path.Contains('?') || path.Contains('#')) continue;
            if (!await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, project.ProjectCode, item.MenuCode, "VIEW", token)) continue;
            var canCreate = await CompanyMenuAccess.IsAllowedForProjectAsync(db, User, project.ProjectCode, item.MenuCode, "CREATE", token);
            result.Add(new GuideItem(project.ProjectCode, project.ProjectName, group.MenuGroupName, item.MenuCode, item.MenuName, path, canCreate));
        }
        return result;
    }

    private static string Subject(string name)
    {
        var text = name.Trim();
        foreach (var prefix in new[] { "ข้อมูล", "ทะเบียน", "รายการ", "จัดการ", "บันทึก", "ระบบ" })
            if (text.StartsWith(prefix, StringComparison.Ordinal) && text.Length > prefix.Length) { text = text[prefix.Length..].Trim(); break; }
        return text;
    }

    [HttpGet]
    public async Task<IActionResult> Search([FromQuery] string? query, CancellationToken token)
    {
        if (string.IsNullOrWhiteSpace(query) || query.Length > 1000) return BadRequest(new { message = "กรุณาระบุข้อมูลที่ต้องการค้นหา" });
        var input = query.Trim();
        var items = await AllowedMenus(token, (_, _, name) => {
            var subject = Subject(name);
            return name.Length >= 2 && input.Contains(name, StringComparison.OrdinalIgnoreCase)
                || subject.Length >= 2 && input.Contains(subject, StringComparison.OrdinalIgnoreCase);
        });
        if (items is null) return Forbid();
        var matches = items.GroupBy(x => (x.ProjectCode, x.MenuCode)).Select(g => g.First()).Take(20).ToArray();
        return Ok(new { items = matches });
    }

    [HttpGet("systems")]
    public async Task<IActionResult> Systems(CancellationToken token)
    {
        var items = await AllowedMenus(token, (_, _, _) => true);
        if (items is null) return Forbid();
        return Ok(new { items = items.GroupBy(x => (x.ProjectCode, x.ProjectName))
            .Select(g => new { projectCode = g.Key.ProjectCode, projectName = g.Key.ProjectName }) });
    }

    [HttpGet("systems/{project}")]
    public async Task<IActionResult> SystemMenus(string project, CancellationToken token)
    {
        var items = await AllowedMenus(token, (projectCode, _, _) => projectCode == project);
        if (items is null) return Forbid();
        return Ok(new { items = items.GroupBy(x => (x.ProjectCode, x.MenuCode)).Select(g => g.First()) });
    }

    [HttpGet("{project}/{menu}")]
    public async Task<IActionResult> Resolve(string project, string menu, CancellationToken token)
    {
        var items = await AllowedMenus(token, (projectCode, menuCode, _) => projectCode == project && menuCode == menu);
        if (items is null) return Forbid();
        var item = items.FirstOrDefault(x => x.ProjectCode == project && x.MenuCode == menu);
        return item is null ? NotFound(new { message = "เมนูนี้ไม่พร้อมใช้งานหรือคุณไม่มีสิทธิ์เข้าถึง" }) : Ok(item);
    }

    private sealed record GuideItem(string ProjectCode, string ProjectName, string GroupName, string MenuCode, string MenuName, string RoutePath, bool CanCreate);
}
