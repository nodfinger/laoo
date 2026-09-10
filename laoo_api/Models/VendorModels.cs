using System.ComponentModel.DataAnnotations;

namespace LaooApi.Models;

public sealed record VendorRequest(
    [Required, StringLength(50)] string VendorCode,
    [Required, StringLength(200)] string VendorName,
    [Required, RegularExpression("^(PERSON|ORGANIZATION)$")] string EntityTypeCode,
    [StringLength(50)] string? TaxID,
    [StringLength(1000)] string? Address,
    [StringLength(50)] string? Telephone,
    [StringLength(320), EmailAddress] string? Email,
    [StringLength(200)] string? ContactName,
    [StringLength(50)] string? ContactTelephone,
    [StringLength(320), EmailAddress] string? ContactEmail,
    [Range(0,3650)] int CreditDays,
    [StringLength(1000)] string? Remark,
    bool IsActive,
    string? RowVersion);

public sealed record VendorResponse(long VendorID, string VendorCode, string VendorName,
    string EntityTypeCode, string? TaxID, string? Address, string? Telephone, string? Email,
    string? ContactName, string? ContactTelephone, string? ContactEmail,
    int CreditDays, string? Remark, bool IsActive, string RowVersion);
