namespace Laoo.Shared.Contracts;

/// <summary>Resolves already-authorized, company-scoped approval candidates.
/// Callers must load candidates for the document's company, validate the menu
/// permission and persist the resulting workflow in the document transaction.</summary>
public sealed record ApprovalPositionRule(string Code,string UnitScope);
public sealed record ApprovalStepRule(int Order,string Condition,IReadOnlyList<ApprovalPositionRule> Positions);
public sealed record ApprovalCandidate(string PositionCode,long UserId,long? DepartmentId,long? DivisionId,bool Active,bool Vacant);
public sealed record ApprovalResolvedPosition(string Code,IReadOnlyList<long> Users);
public sealed record ApprovalResolvedStep(int Order,string Condition,IReadOnlyList<ApprovalResolvedPosition> Positions);
public sealed record ApprovalLevel(string Code,string Name,string? ShortCode,int Sequence);

public static class ApprovalPatternResolver
{
    /// <summary>Sort levels from lower to higher; ambiguous or missing keys fail closed.</summary>
    public static IReadOnlyList<string> OrderLevels(IReadOnlyList<ApprovalLevel> levels,string method)
    {
        if (levels.Any(x => string.IsNullOrWhiteSpace(x.Code)) ||
            levels.Select(x => x.Code.Trim()).Distinct(StringComparer.OrdinalIgnoreCase).Count() != levels.Count)
            throw new ArgumentException("Invalid or duplicate level code.");
        var comparer = StringComparer.Create(System.Globalization.CultureInfo.GetCultureInfo("th-TH"), true);
        if (method is "NAME" or "SHORTCODE") {
            var pairs = levels.Select(x => (x.Code, Key: method == "NAME" ? x.Name?.Trim() : x.ShortCode?.Trim())).ToArray();
            if (pairs.Any(x => string.IsNullOrWhiteSpace(x.Key)) || pairs.Select(x => x.Key!).Distinct(comparer).Count() != pairs.Length)
                throw new ArgumentException("Missing or duplicate level ordering value.");
            return pairs.OrderBy(x => x.Key, comparer).Select(x => x.Code).ToArray();
        }
        if (method != "SEQUENCE" || levels.Select(x => x.Sequence).Distinct().Count() != levels.Count)
            throw new ArgumentException("Invalid or duplicate level sequence.");
        return levels.OrderBy(x => x.Sequence).Select(x => x.Code).ToArray();
    }
    /// <summary>Input levels must be ordered from the lowest to the highest
    /// according to company configuration; no ordering is inferred from codes.</summary>
    public static IReadOnlyList<string> HigherLevels(IReadOnlyList<string> lowToHigh,string current,int count)
    {
        if(count<=0)throw new ArgumentOutOfRangeException(nameof(count));
        var index=-1;
        for(var i=0;i<lowToHigh.Count;i++)if(string.Equals(lowToHigh[i],current,StringComparison.OrdinalIgnoreCase)) {
            if(index>=0)throw new ArgumentException("Duplicate level.");
            index=i;
        }
        if(index<0)throw new ArgumentException("Current level not found.");
        return lowToHigh.Skip(index+1).Take(count).ToArray();
    }

    public static IReadOnlyList<ApprovalResolvedStep> Resolve(
        IReadOnlyList<ApprovalStepRule> steps,IReadOnlyList<ApprovalCandidate> candidates,
        IEnumerable<string> requesterPositions,long requesterUserId,long? departmentId,long? divisionId)
    {
        var own=new HashSet<string>(requesterPositions,StringComparer.OrdinalIgnoreCase);
        var seen=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var orders=new HashSet<int>();
        var result=new List<ApprovalResolvedStep>();
        foreach(var step in steps.OrderBy(s=>s.Order)) {
            if(step.Order<=0 || !orders.Add(step.Order) || step.Condition is not ("ANY" or "ALL"))throw new ArgumentException("Invalid approval step.");
            var eligible=new List<ApprovalResolvedPosition>();
            foreach(var position in step.Positions) {
                if(string.IsNullOrWhiteSpace(position.Code) || !seen.Add(position.Code.Trim()) || position.UnitScope is not ("ANY" or "DEPARTMENT" or "DIVISION"))
                    throw new ArgumentException("Invalid or duplicate approval position.");
                var code=position.Code.Trim();
                if(own.Contains(code))continue;
                var users=candidates.Where(c=>string.Equals(c.PositionCode,code,StringComparison.OrdinalIgnoreCase) && c.Active && !c.Vacant && c.UserId>0 && c.UserId!=requesterUserId &&
                    (position.UnitScope=="ANY" || position.UnitScope=="DEPARTMENT" && departmentId is >0 && c.DepartmentId==departmentId ||
                     position.UnitScope=="DIVISION" && divisionId is >0 && c.DivisionId==divisionId))
                    .Select(c=>c.UserId).Distinct().Order().ToArray();
                if(users.Length>0)eligible.Add(new(code,users));
            }
            if(eligible.Count>0)result.Add(new(step.Order,step.Condition,eligible));
        }
        return result;
    }
}
