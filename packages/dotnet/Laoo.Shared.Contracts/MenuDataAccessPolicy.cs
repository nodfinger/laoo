namespace Laoo.Shared.Contracts;

/// <summary>Row-level access is an additional restriction; callers must still
/// check company, project, package and menu/action permissions separately.</summary>
public sealed record MenuDataAccessRule(
    string Scope, bool AllowDepartmentHead, bool AllowDivisionManager, bool AllowStaff = true);

public sealed record MenuDataAccessContext(
    bool IsCompanyAdmin,
    long? ActorUserId,
    long? OwnerUserId,
    long? ActorDepartmentId,
    long? OwnerDepartmentId,
    long? ActorDivisionId,
    long? OwnerDivisionId,
    bool IsOwnerDepartmentHead,
    bool IsOwnerDivisionManager);

public static class MenuDataAccessPolicy
{
    /// <summary>Null means the menu does not opt in to row-level access;
    /// normal menu permissions continue to apply.</summary>
    public static bool Allows(MenuDataAccessRule? rule, MenuDataAccessContext context)
    {
        if (context.IsCompanyAdmin || rule is null) return true;
        if (context.ActorUserId is > 0 && context.ActorUserId == context.OwnerUserId)
            return true;

        var sameDepartment = context.ActorDepartmentId is > 0 &&
            context.ActorDepartmentId == context.OwnerDepartmentId;
        var sameDivision = context.ActorDivisionId is > 0 &&
            context.ActorDivisionId == context.OwnerDivisionId;
        if (rule.Scope == "SELF") return false;
        if (rule.AllowDepartmentHead && context.IsOwnerDepartmentHead && context.OwnerDepartmentId is > 0)
            return true;
        if (rule.Scope != "DEPARTMENT" && rule.AllowDivisionManager && context.IsOwnerDivisionManager && context.OwnerDivisionId is > 0)
            return true;

        return rule.Scope switch
        {
            "ALL" => true,
            "DEPARTMENT" => sameDepartment,
            "DIVISION" => sameDivision,
            _ => false
        };
    }
}
