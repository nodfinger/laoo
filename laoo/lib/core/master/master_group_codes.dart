/// Central definitions for master groups stored in dbo.TDSTMaster.
abstract final class MasterGroupCodes {
  static const province = '001';
  static const unit = '002';
  static const customerBusiness = '003';
  static const priceLevel = '004';
  static const customerGroup = '005';
  static const itemGroup = '006';
  static const itemType = '007';

  static const variableNames = <String, String>{
    province: 'MsProv',
    unit: 'MsUnit',
    customerBusiness: 'MsBusiness',
    priceLevel: 'MsPriceLevel',
    customerGroup: 'MsCusGroup',
    itemGroup: 'MsItemGroup',
    itemType: 'MsItemType',
  };

  static String? variableNameOf(String code) => variableNames[code];
}
