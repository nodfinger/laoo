using LaooApi.Services;

var start = new DateOnly(2026, 11, 10);
var end = new DateOnly(2026, 11, 12);
var flat = TravelClaimCalculation.Calculate(start, end, 150, 800, 5, 2000, 2, 50, 20, 100);
if (flat.Days != 3 || flat.Fuel != 800 || flat.Lodging != 4000 || flat.Total != 4970)
    throw new Exception("Flat fare or total calculation failed.");
var distance = TravelClaimCalculation.Calculate(start, end, 150, null, 5, 2000, 2, 50, 20, 100);
if (distance.Fuel != 2250 || distance.Total != 6420)
    throw new Exception("Per-kilometre fare calculation failed.");
var free = TravelClaimCalculation.Calculate(start, start, 150, 0, 5, 0, 0, 0, 0, 0);
if (free.Days != 1 || free.Fuel != 0 || free.Total != 0)
    throw new Exception("A configured zero flat fare must not fall back to a distance rate.");
var rounded = TravelClaimCalculation.Calculate(start, start, 1, null, 0.005m, 0, 0, 0, 0, 0);
if (rounded.Fuel != 0.01m) throw new Exception("Currency rounding failed.");
try { TravelClaimCalculation.Calculate(end, start, 1, 1, 1, 1, 1, 0, 0, 0); throw new Exception("Invalid dates accepted."); }
catch (ArgumentException) { }
try { TravelClaimCalculation.Calculate(start, end, 1, null, null, 1, 1, 0, 0, 0); throw new Exception("Missing rate accepted."); }
catch (ArgumentException) { }
Console.WriteLine("Travel claim calculation tests passed.");
