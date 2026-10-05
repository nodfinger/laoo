namespace Laoo.SchoolFood;

public static class SchoolFoodRules
{
    public static decimal Money(decimal value) =>
        Math.Round(value, 2, MidpointRounding.AwayFromZero);

    public static decimal CommissionRate(bool enabled, decimal defaultRate,
        decimal? shopRate, decimal? categoryRate, decimal? itemRate)
    {
        if (!enabled) return 0;
        var rate = itemRate ?? categoryRate ?? shopRate ?? defaultRate;
        if (rate is < 0 or > 100) throw new ArgumentOutOfRangeException(nameof(rate));
        return rate;
    }

    public static decimal Debit(decimal balance, decimal amount)
    {
        if (amount <= 0 || amount != Money(amount))
            throw new ArgumentException("ยอดเงินต้องมากกว่า 0 และไม่เกินสองตำแหน่งทศนิยม");
        if (balance < amount) throw new InvalidOperationException("ยอด Wallet ไม่เพียงพอ");
        return balance - amount;
    }

    // Cumulative rounding makes multiple partial refunds total exactly the original charge.
    public static decimal RefundCommission(decimal originalCommission,
        decimal originalQuantity, decimal alreadyReturned, decimal returnQuantity)
    {
        if (originalQuantity <= 0 || alreadyReturned < 0 || returnQuantity <= 0 ||
            alreadyReturned + returnQuantity > originalQuantity)
            throw new ArgumentException("จำนวนคืนเกินรายการขายเดิม");
        return Money(originalCommission * (alreadyReturned + returnQuantity) / originalQuantity)
            - Money(originalCommission * alreadyReturned / originalQuantity);
    }
}
