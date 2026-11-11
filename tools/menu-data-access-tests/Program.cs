using Laoo.Shared.Contracts;

var own = new MenuDataAccessContext(false, 1, 1, 10, 10, 20, 20, false, false);
var other = own with { OwnerUserId = 2 };
void Expect(bool actual, bool expected, string description)
{
    if (actual != expected) throw new Exception(description);
}
var self = new MenuDataAccessRule("SELF", true, true, false);
Expect(MenuDataAccessPolicy.Allows(self, own), true, "owner must be allowed");
Expect(MenuDataAccessPolicy.Allows(self, other), false, "peer must be denied in self scope");
Expect(MenuDataAccessPolicy.Allows(self, other with { IsOwnerDepartmentHead = true }), false, "self scope excludes head");
Expect(MenuDataAccessPolicy.Allows(self, other with { IsOwnerDivisionManager = true }), false, "self scope excludes manager");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DEPARTMENT", AllowDepartmentHead = false }, other with { OwnerDepartmentId = 11, IsOwnerDepartmentHead = true }), false, "other scopes respect disabled head access");
Expect(MenuDataAccessPolicy.Allows(self, other with { IsOwnerDepartmentHead = true, OwnerDepartmentId = null }), false, "head without owner department must be denied");
Expect(MenuDataAccessPolicy.Allows(self, other with { IsOwnerDivisionManager = true, OwnerDivisionId = null }), false, "manager without owner division must be denied");
Expect(MenuDataAccessPolicy.Allows(self with { AllowStaff = true }, other), false, "self scope excludes staff");
Expect(MenuDataAccessPolicy.Allows(self with { AllowStaff = true }, other with { OwnerDepartmentId = 11 }), false, "self staff must be in owner's department");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DEPARTMENT" }, other), true, "department staff automatically allowed");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DEPARTMENT", AllowStaff = true }, other), true, "department peer");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DEPARTMENT", AllowDivisionManager = true }, other with { IsOwnerDivisionManager = true, ActorDepartmentId = 11 }), false, "department excludes manager from another department");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DIVISION", AllowDivisionManager = true }, other with { IsOwnerDivisionManager = true }), true, "division permits manager");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DEPARTMENT" }, other with { OwnerDepartmentId = null }), false, "missing department must not match");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DEPARTMENT" }, other with { OwnerDepartmentId = 11 }), false, "different department must not match");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DIVISION" }, other), true, "division staff automatically allowed");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DIVISION", AllowStaff = true }, other), true, "division peer");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DIVISION" }, other with { OwnerDivisionId = null }), false, "missing division must not match");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "DIVISION" }, other with { OwnerDivisionId = 21 }), false, "different division must not match");
Expect(MenuDataAccessPolicy.Allows(self, other with { IsCompanyAdmin = true }), true, "company admin bypass");
Expect(MenuDataAccessPolicy.Allows(null, other), true, "non-opted-in menu uses ordinary permissions");
Expect(MenuDataAccessPolicy.Allows(self with { Scope = "unexpected" }, other), false, "invalid scope fails closed");
var approvalSteps=new[] {
    new ApprovalStepRule(1,"ALL",[new("SELF","ANY"),new("VACANT","ANY"),new("HEAD","DEPARTMENT"),new("MANAGER","DIVISION")]),
    new ApprovalStepRule(2,"ANY",[new("OTHER","ANY")])
};
var candidates=new[] {
    new ApprovalCandidate("SELF",1,10,20,true,false),new ApprovalCandidate("VACANT",2,10,20,true,true),
    new ApprovalCandidate("HEAD",3,10,20,true,false),new ApprovalCandidate("HEAD",4,11,20,true,false),
    new ApprovalCandidate("MANAGER",5,11,20,true,false),new ApprovalCandidate("OTHER",6,11,21,true,false)
};
var resolved=ApprovalPatternResolver.Resolve(approvalSteps,candidates,["SELF"],1,10,20);
Expect(resolved.Count==2 && resolved[0].Positions.Count==2,true,"skip self and vacant positions, keep other positions in the same step");
Expect(resolved[0].Positions[0].Users.SequenceEqual([3L]),true,"department scope");
Expect(resolved[0].Positions[1].Users.SequenceEqual([5L]),true,"division scope");
var missingUnit=ApprovalPatternResolver.Resolve(approvalSteps,candidates,["SELF"],1,null,null);
Expect(missingUnit.Count==1 && missingUnit[0].Order==2,true,"skip a step when all scoped positions are unavailable");
var allPositionsUnavailable=ApprovalPatternResolver.Resolve([new(1,"ALL",[new("VACANT","ANY")])],candidates,[],1,10,20);
Expect(allPositionsUnavailable.Count==0,true,"skip a vacant step");
Expect(ApprovalPatternResolver.HigherLevels(["R7","R6","R5","R4"],"R6",2).SequenceEqual(["R5","R4"]),true,"levels above requester");
var levelsForOrder = new[] { new ApprovalLevel("B", "B", "02", 2), new ApprovalLevel("A", "A", "01", 1) };
foreach (var method in new[] { "NAME", "SHORTCODE", "SEQUENCE" })
    Expect(ApprovalPatternResolver.OrderLevels(levelsForOrder, method).SequenceEqual(["A", "B"]), true, $"level order {method}");
try { ApprovalPatternResolver.OrderLevels([new("A", "A", null, 1)], "SHORTCODE"); throw new Exception("Missing short code accepted."); }
catch (ArgumentException) { }
try { ApprovalPatternResolver.Resolve([new(1,"ANY",[new("HEAD","ANY")]),new(2,"ALL",[new("head","ANY")])],candidates,[],1,10,20); throw new Exception("Duplicate position accepted."); }
catch(ArgumentException) { }
Console.WriteLine("Menu data access rule checks passed.");
