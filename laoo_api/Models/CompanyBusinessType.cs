namespace LaooApi.Models;

public static class CompanyBusinessType
{
    public const string Company = "COMPANY";
    public const string Dormitory = "DORMITORY";
    public const string ServiceCenter = "SERVICE_CENTER";

    public static bool IsSupported(string? code) =>
        code is Company or Dormitory or ServiceCenter;

    public static string Normalize(string? code) =>
        string.IsNullOrWhiteSpace(code)
            ? Company
            : code.Trim().ToUpperInvariant();

    public static string RequesterMode(string? code) =>
        Normalize(code) == Dormitory ? "RESIDENT" : "EMPLOYEE";

    public static string RequesterCaption(string? code) =>
        Normalize(code) switch
        {
            Dormitory => "ผู้พักอาศัยผู้แจ้งซ่อม",
            ServiceCenter => "พนักงานศูนย์ผู้แจ้งซ่อม",
            _ => "พนักงานผู้แจ้งซ่อม",
        };
}
