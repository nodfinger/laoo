namespace LaooApi.Models.Support;

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
