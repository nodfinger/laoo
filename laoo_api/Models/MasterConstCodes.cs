namespace LaooApi.Models;

/// Central constants stored in TDSTMasterConst.
public static class MasterConstCodes
{
    public const string CustomerCodeGeneration = "001";
    public const string ItemCodeGeneration = "002";

    public const string ConstRunCus = "ConstRunCus";
    public const string ConstRunItem = "ConstRunItem";

    public const string Manual = "0";
    public const string RunByYear = "1";
    public const string RunAuto = "2";
    public const string RunByItemType = "1";

    public static readonly IReadOnlyDictionary<string, string> GroupVariables =
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            [CustomerCodeGeneration] = ConstRunCus,
            [ItemCodeGeneration] = ConstRunItem,
        };
}
