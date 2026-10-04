using Laoo.SchoolFood;

var passed = 0;
void Check(string name, Action test)
{
    test();
    passed++;
    Console.WriteLine($"PASS {name}");
}
void Equal<T>(T expected, T actual)
{
    if (!EqualityComparer<T>.Default.Equals(expected, actual))
        throw new Exception($"Expected {expected}; actual {actual}");
}
void Throws<T>(Action work) where T : Exception
{
    try { work(); } catch (T) { return; }
    throw new Exception($"Expected {typeof(T).Name}");
}

Check("Wallet debit", () => Equal(65m, SchoolFoodRules.Debit(100m, 35m)));
Check("Wallet exact balance", () => Equal(0m, SchoolFoodRules.Debit(35m, 35m)));
Check("Wallet insufficient", () => Throws<InvalidOperationException>(() => SchoolFoodRules.Debit(34m, 35m)));
Check("Wallet zero rejected", () => Throws<ArgumentException>(() => SchoolFoodRules.Debit(100m, 0m)));
Check("Wallet negative rejected", () => Throws<ArgumentException>(() => SchoolFoodRules.Debit(100m, -1m)));
Check("Wallet fractional cent rejected", () => Throws<ArgumentException>(() => SchoolFoodRules.Debit(100m, 1.001m)));
Check("Commission disabled", () => Equal(0m, SchoolFoodRules.CommissionRate(false, 10, 20, 30, 40)));
Check("Commission default", () => Equal(10m, SchoolFoodRules.CommissionRate(true, 10, null, null, null)));
Check("Commission shop", () => Equal(20m, SchoolFoodRules.CommissionRate(true, 10, 20, null, null)));
Check("Commission category", () => Equal(30m, SchoolFoodRules.CommissionRate(true, 10, 20, 30, null)));
Check("Commission item", () => Equal(40m, SchoolFoodRules.CommissionRate(true, 10, 20, 30, 40)));
Check("Zero override is intentional", () => Equal(0m, SchoolFoodRules.CommissionRate(true, 10, 20, 30, 0)));
Check("Commission below zero rejected", () => Throws<ArgumentOutOfRangeException>(() => SchoolFoodRules.CommissionRate(true, -1, null, null, null)));
Check("Commission above 100 rejected", () => Throws<ArgumentOutOfRangeException>(() => SchoolFoodRules.CommissionRate(true, 101, null, null, null)));
Check("Half-cent rounding", () => Equal(1.01m, SchoolFoodRules.Money(1.005m)));
Check("Partial refund rounding", () =>
{
    Equal(.33m, SchoolFoodRules.RefundCommission(1, 3, 0, 1));
    Equal(.34m, SchoolFoodRules.RefundCommission(1, 3, 1, 1));
    Equal(.33m, SchoolFoodRules.RefundCommission(1, 3, 2, 1));
});
Check("Refund cannot exceed original quantity", () => Throws<ArgumentException>(() => SchoolFoodRules.RefundCommission(1, 3, 2, 2)));
Check("Refund must be positive", () => Throws<ArgumentException>(() => SchoolFoodRules.RefundCommission(1, 3, 0, 0)));
Check("All partitioned refunds preserve charge", () =>
{
    for (var cents = 0; cents <= 1000; cents++)
        for (var quantity = 1; quantity <= 20; quantity++)
        {
            var amount = cents / 100m;
            var total = Enumerable.Range(0, quantity)
                .Sum(done => SchoolFoodRules.RefundCommission(amount, quantity, done, 1));
            Equal(amount, total);
        }
});
Check("Menu range and ScreenType", () =>
{
    int[] types = [2, 1, 2, 2, 1, 4, 4, 4, 4, 3, 3, 3];
    Equal(12, SchoolFoodContract.Menus.Length);
    for (var i = 0; i < types.Length; i++)
    {
        Equal((53001 + i).ToString(), SchoolFoodContract.Menus[i].Code);
        Equal(types[i], SchoolFoodContract.Menus[i].ScreenType);
    }
    Equal(12, SchoolFoodContract.Menus.Select(x => x.Route).Distinct().Count());
});
Check("UpdateOnly and ShowOnly action contracts", () =>
{
    foreach (var menu in SchoolFoodContract.Menus)
    {
        Equal(true, menu.Actions.Contains("VIEW"));
        if (menu.ScreenType == 2)
            Equal(true, menu.Actions.All(a => a is "VIEW" or "EDIT"));
        if (menu.ScreenType == 3)
            Equal(true, menu.Actions.All(a => a is "VIEW" or "EXPORT"));
    }
});
Console.WriteLine($"Passed {passed} checks. Database, HTTP authorization, UI and hardware are NOT covered.");
