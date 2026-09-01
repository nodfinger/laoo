namespace Laoo.Shared.Contracts.Employees;

public enum EmployeeOwnerScope
{
    Partner,
    PartnerCustomer,
    Company,
}

public sealed record EmployeeScreenContract(
    EmployeeOwnerScope Scope,
    string MenuCode,
    string RouteName,
    string ApiPath,
    int ScreenType,
    string RequiredUserType);

public static class EmployeeScreenContracts
{
    public static readonly EmployeeScreenContract Partner =
        new(EmployeeOwnerScope.Partner, "11001", "partnerEmployees", "/api/partner/employees", 1, "PARTNER_USER");

    public static readonly EmployeeScreenContract PartnerCustomer =
        new(EmployeeOwnerScope.PartnerCustomer, "12001", "partnerCustomerEmployees", "/api/partner/customer-employees", 1, "PARTNER_USER");

    public static readonly EmployeeScreenContract Company =
        new(EmployeeOwnerScope.Company, "10001", "companyEmployees", "/api/company/employees", 1, "COMPANY_USER");

    public static EmployeeScreenContract FromRequestPath(string? path)
    {
        if (path?.Contains("/api/company/", StringComparison.OrdinalIgnoreCase) == true)
            return Company;
        if (path?.Contains("customer-employees", StringComparison.OrdinalIgnoreCase) == true)
            return PartnerCustomer;
        return Partner;
    }
}

public sealed class EmployeeResponse
{
    public long EmployeeId { get; init; }
    public long PartnerId { get; init; }
    public long? CompanyId { get; init; }
    public long? DivisionOrgUnitId { get; init; }
    public string? DivisionName { get; init; }
    public long? DepartmentOrgUnitId { get; init; }
    public string? DepartmentName { get; init; }
    public string EmployeeCode { get; init; } = string.Empty;
    public string FullName { get; init; } = string.Empty;
    public string? NickName { get; init; }
    public string? PositionCode { get; init; }
    public string? Email { get; init; }
    public bool NotifyByEmail { get; init; }
    public bool NotifyInSystem { get; init; } = true;
    public string? Telephone { get; init; }
    public string? PersonalTelephone { get; init; }
    public string? ContName1 { get; init; }
    public string? ContRelation1 { get; init; }
    public string? ContPhone1 { get; init; }
    public string? ContName2 { get; init; }
    public string? ContRelation2 { get; init; }
    public string? ContPhone2 { get; init; }
    public DateTime? StartWorkDate { get; init; }
    public bool HasImage { get; init; }
    public bool IsActive { get; init; }
    public string? CarID1 { get; init; }
    public string? CarColor1 { get; init; }
    public string? CarTypeCode1 { get; init; }
    public string? CarOilType1 { get; init; }
    public string? CarID2 { get; init; }
    public string? CarColor2 { get; init; }
    public string? CarTypeCode2 { get; init; }
    public string? CarOilType2 { get; init; }
}

public sealed class EmployeeUpsertRequest
{
    public long? CompanyId { get; init; }
    public long? DivisionOrgUnitId { get; init; }
    public long? DepartmentOrgUnitId { get; init; }
    public string EmployeeCode { get; init; } = string.Empty;
    public string FullName { get; init; } = string.Empty;
    public string? NickName { get; init; }
    public string? PositionCode { get; init; }
    public string? Email { get; init; }
    public bool NotifyByEmail { get; init; }
    public bool NotifyInSystem { get; init; } = true;
    public string? Telephone { get; init; }
    public string? PersonalTelephone { get; init; }
    public string? ContName1 { get; init; }
    public string? ContRelation1 { get; init; }
    public string? ContPhone1 { get; init; }
    public string? ContName2 { get; init; }
    public string? ContRelation2 { get; init; }
    public string? ContPhone2 { get; init; }
    public DateTime? StartWorkDate { get; init; }
    public bool IsActive { get; init; } = true;
    public string? CarID1 { get; init; }
    public string? CarColor1 { get; init; }
    public string? CarTypeCode1 { get; init; }
    public string? CarOilType1 { get; init; }
    public string? CarID2 { get; init; }
    public string? CarColor2 { get; init; }
    public string? CarTypeCode2 { get; init; }
    public string? CarOilType2 { get; init; }
}

public sealed class EmployeeImageUpsertRequest
{
    public long? CompanyId { get; init; }
    public string ImageType { get; init; } = "FORMAL";
    public string ContentType { get; init; } = "image/jpeg";
    public string? FileName { get; init; }
    public string ImageDataBase64 { get; init; } = string.Empty;
    public int ImageWidth { get; init; }
    public int ImageHeight { get; init; }
}

public sealed class EmployeeCarImageUpsertRequest
{
    public long? CompanyId { get; init; }
    public int CarNo { get; init; }
    public string ContentType { get; init; } = "image/jpeg";
    public string? FileName { get; init; }
    public string ImageDataBase64 { get; init; } = string.Empty;
    public int ImageWidth { get; init; }
    public int ImageHeight { get; init; }
}

public sealed class EmployeeUserCreateRequest
{
    public long? CompanyId { get; init; }
    public string Username { get; init; } = string.Empty;
    public string Password { get; init; } = string.Empty;
}

public sealed class EmployeeUserUpsertRequest
{
    public long? CompanyId { get; init; }
    public string Username { get; init; } = string.Empty;
    public string? Password { get; init; }
    public long? RoleGroupId { get; init; }
}
