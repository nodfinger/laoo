namespace LaooMeetingApi.Models;

/// Central definitions for master groups stored in dbo.TDSTMaster.
public static class MasterGroupCodes
{
    public const string Province = "001";
    public const string Unit = "002";
    public const string CustomerBusiness = "003";
    public const string PriceLevel = "004";
    public const string CustomerGroup = "005";
    public const string ItemGroup = "006";
    public const string ItemType = "007";
    public const string FoodType = "011";

    public static readonly IReadOnlyDictionary<string, string> VariableNames =
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            [Province] = "MsProv",
            [Unit] = "MsUnit",
            [CustomerBusiness] = "MsBusiness",
            [PriceLevel] = "MsPriceLevel",
            [CustomerGroup] = "MsCusGroup",
            [ItemGroup] = "MsItemGroup",
            [ItemType] = "MsItemType",
            [FoodType] = "MsFoodType",
        };
}
