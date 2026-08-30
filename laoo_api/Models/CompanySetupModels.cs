namespace LaooApi.Models;

public sealed record CompanySetupResponse(
    long? PKValue,
    string OwnerType,
    long? PartnerID,
    long? CompanyID,
    string OwnerCode,
    string OwnerName,
    string? CustomerNameTh,
    string? CustomerNameEn,
    string? AddressText,
    string? Telephone,
    string? TaxID,
    string? CustomerEmail,
    string Name,
    string TitleHeader,
    string? RunItem,
    string? MarkItem,
    int ItemDigit,
    string? RunCus,
    string? MarkCus,
    int CustomerDigit,
    int RowSTD,
    int RowCardSTD,
    int TimeAlert,
    int OrgStructureType,
    int PasswordPolicyCode,
    string? YearFormat,
    string? VersionID,
    string? EmailHost,
    int? EmailPort,
    string? EmailCenter,
    string? EmailAdmin,
    bool IsActive,
    DateTime? CreateDate,
    long? CreateBy,
    DateTime? UpdateDate,
    long? UpdateBy,
    bool HasSuperUser,
    bool HasPasswordCry,
    bool HasEmailPasswordCenter,
    bool HasPasswordEmpDefault,
    bool HasPasswordDirect);
    

public sealed class CompanySetupUpdateRequest
{
    public string? CustomerNameTh { get; init; }
    public string? CustomerNameEn { get; init; }
    public string? AddressText { get; init; }
    public string? Telephone { get; init; }
    public string? TaxID { get; init; }
    public string? CustomerEmail { get; init; }
    public string Name { get; init; } = string.Empty;
    public string TitleHeader { get; init; } = string.Empty;
    public string? RunItem { get; init; }
    public string? MarkItem { get; init; }
    public int ItemDigit { get; init; } = 3;
    public string? RunCus { get; init; }
    public string? MarkCus { get; init; }
    public int CustomerDigit { get; init; } = 5;
    public int RowSTD { get; init; }
    public int RowCardSTD { get; init; }
    public int TimeAlert { get; init; }
    public int OrgStructureType { get; init; } = 1;
    public int PasswordPolicyCode { get; init; } = 3;
    public string? YearFormat { get; init; }
    public string? VersionID { get; init; }
    public string? EmailHost { get; init; }
    public int? EmailPort { get; init; }
    public string? EmailCenter { get; init; }
    public string? EmailAdmin { get; init; }

    // Write-only: blank means keep existing.
    public string? SuperUserName { get; init; }
    public string? PasswordCry { get; init; }
    public string? EmailPasswordCenter { get; init; }
    public string? PasswordEmpDefault { get; init; }
    public string? PasswordDirect { get; init; }
}

public sealed record CompanySetupOption(string Code, string Name);
