namespace LaooApi.Services;

/// <summary>Calculates a claim using company-configured rates, never client totals.</summary>
public static class TravelClaimCalculation
{
    public sealed record Amounts(int Days, decimal Fuel, decimal Lodging, decimal Total);

    public static Amounts Calculate(DateOnly start, DateOnly end, decimal distancePerDay,
        decimal? flatFare, decimal? ratePerKm, decimal lodgingPerNight, int nights,
        decimal toll, decimal parking, decimal publicTransport)
    {
        if (end < start) throw new ArgumentException("วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่มเดินทาง");
        if (distancePerDay < 0 || flatFare < 0 || ratePerKm < 0 || lodgingPerNight < 0 ||
            nights < 0 || toll < 0 || parking < 0 || publicTransport < 0)
            throw new ArgumentException("จำนวนเงิน ระยะทาง และจำนวนคืนต้องไม่ติดลบ");
        if (flatFare is null && ratePerKm is null)
            throw new ArgumentException("ไม่พบราคาเหมาจ่ายหรืออัตราต่อกิโลเมตรของประเภทรถ");

        var days = checked(end.DayNumber - start.DayNumber + 1);
        var fuel = Round(flatFare ?? checked(distancePerDay * days * ratePerKm!.Value));
        var lodging = Round(checked(lodgingPerNight * nights));
        var total = Round(checked(fuel + lodging + toll + parking + publicTransport));
        return new Amounts(days, fuel, lodging, total);
    }

    private static decimal Round(decimal value) => decimal.Round(value, 2, MidpointRounding.AwayFromZero);
}
