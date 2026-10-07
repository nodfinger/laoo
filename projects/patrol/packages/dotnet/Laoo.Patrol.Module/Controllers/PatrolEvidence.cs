using System.Security.Cryptography;
using System.Text;

namespace Laoo.Patrol.Controllers;

internal static class PatrolEvidence
{
    internal static string CanonicalPayload(CheckEventInput input, long runId, long pointId) =>
        $"{input.EventKey:N}|{runId}|{pointId}|{input.OccurredAt.ToUniversalTime():O}|{input.DeviceSequence}|{input.Method}";

    internal static bool VerifySignature(string? publicKey, string? signature, string payload)
    {
        if (string.IsNullOrWhiteSpace(publicKey) || string.IsNullOrWhiteSpace(signature)) return false;
        try
        {
            using var rsa = RSA.Create();
            rsa.ImportFromPem(publicKey);
            return rsa.VerifyData(
                Encoding.UTF8.GetBytes(payload),
                Convert.FromBase64String(signature),
                HashAlgorithmName.SHA256,
                RSASignaturePadding.Pkcs1);
        }
        catch (Exception) when (publicKey.Length <= 2000 && signature.Length <= 4000)
        {
            return false;
        }
    }

    internal static double DistanceMeters(double latitude1, double longitude1, double latitude2, double longitude2)
    {
        const double earthRadius = 6_371_000;
        var deltaLatitude = DegreesToRadians(latitude2 - latitude1);
        var deltaLongitude = DegreesToRadians(longitude2 - longitude1);
        var latitude1Radians = DegreesToRadians(latitude1);
        var latitude2Radians = DegreesToRadians(latitude2);
        var haversine = Math.Sin(deltaLatitude / 2) * Math.Sin(deltaLatitude / 2) +
                        Math.Cos(latitude1Radians) * Math.Cos(latitude2Radians) *
                        Math.Sin(deltaLongitude / 2) * Math.Sin(deltaLongitude / 2);
        return earthRadius * 2 * Math.Atan2(Math.Sqrt(haversine), Math.Sqrt(1 - haversine));
    }

    private static double DegreesToRadians(double value) => value * Math.PI / 180;
}