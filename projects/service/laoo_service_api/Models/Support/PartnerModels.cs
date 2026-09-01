namespace LaooServiceApi.Models.Support;

public sealed class PartnerResponse
{
    public long PartnerId { get; init; }
    public string PartnerCode { get; init; } = string.Empty;
    public string PartnerNameTh { get; init; } = string.Empty;
    public string? PartnerNameEn { get; init; }

    public string? Email { get; init; }
    public string? Telephone { get; init; }
    public string? AddressText { get; init; }

    public string? ShortName { get; init; }
    public string? Province { get; init; }
    public DateTime? StartContactDate { get; init; }

    public string? ContactName1 { get; init; }
    public string? ContactPosition1 { get; init; }
    public string? ContactPhone1 { get; init; }
    public string? ContactEmail1 { get; init; }

    public string? ContactName2 { get; init; }
    public string? ContactPosition2 { get; init; }
    public string? ContactPhone2 { get; init; }
    public string? ContactEmail2 { get; init; }

    public string? Remark { get; init; }
    public bool IsActive { get; init; }
    public string? PartnerAdminUsername { get; init; }
    public long? PartnerAdminUserId { get; init; }
}

public sealed class PartnerUpsertRequest
{
    public string PartnerNameTh { get; init; } = string.Empty;
    public string? PartnerNameEn { get; init; }

    public string? Email { get; init; }
    public string? Telephone { get; init; }
    public string? AddressText { get; init; }

    public string? ShortName { get; init; }
    public string? Province { get; init; }
    public DateTime? StartContactDate { get; init; }

    public string? ContactName1 { get; init; }
    public string? ContactPosition1 { get; init; }
    public string? ContactPhone1 { get; init; }
    public string? ContactEmail1 { get; init; }

    public string? ContactName2 { get; init; }
    public string? ContactPosition2 { get; init; }
    public string? ContactPhone2 { get; init; }
    public string? ContactEmail2 { get; init; }

    public string? Remark { get; init; }
}

public sealed class PartnerStatusRequest
{
    public bool IsActive { get; init; }
}
