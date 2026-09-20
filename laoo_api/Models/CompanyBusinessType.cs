namespace LaooApi.Models;

public static class CompanyBusinessType
{
    public const string Company = "COMPANY";
    public const string Dormitory = "DORMITORY";
    public const string ServiceCenter = "SERVICE_CENTER";
    public const string RentalOffice = "RENTAL_OFFICE";
    public const string Village = "VILLAGE";

    public static bool IsSupported(string? code) =>
        code is Company or Dormitory or ServiceCenter or RentalOffice or Village;

    public static string Normalize(string? code) =>
        string.IsNullOrWhiteSpace(code)
            ? Company
            : code.Trim().ToUpperInvariant();

    public static string RequesterMode(string? code) =>
        Normalize(code) switch
        {
            Dormitory => "RESIDENT",
            RentalOffice => "TENANT_CONTACT",
            Village => "VILLAGE_RESIDENT",
            _ => "EMPLOYEE",
        };

    public static string RequesterCaption(string? code) =>
        Normalize(code) switch
        {
            Dormitory => "ผู้พักอาศัย/ผู้แจ้งซ่อม",
            ServiceCenter => "พนักงานศูนย์บริการ/ผู้แจ้งซ่อม",
            RentalOffice => "ผู้ติดต่อบริษัทผู้เช่า",
            Village => "ผู้อยู่อาศัย",
            _ => "พนักงาน/ผู้แจ้งซ่อม",
        };
}