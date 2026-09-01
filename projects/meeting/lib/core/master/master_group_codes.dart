/// Central definitions for master groups stored in dbo.TDSTMaster.
abstract final class MasterGroupCodes {
  static const province = '001';
  static const unit = '002';
  static const customerBusiness = '003';
  static const priceLevel = '004';
  static const customerGroup = '005';
  static const itemGroup = '006';
  static const position = '007';
  static const carType = '009';
  static const oilType = '010';
  static const foodType = '011';

  static const variableNames = <String, String>{
    province: 'MsProv',
    unit: 'MsUnit',
    customerBusiness: 'MsBusiness',
    priceLevel: 'MsPriceLevel',
    customerGroup: 'MsCusGroup',
    itemGroup: 'MsItemGroup',
    position: 'MsPosition',
    carType: 'MSCarTypeCode',
    oilType: 'MSOliTypeCode',
    foodType: 'MsFoodType',
  };

  static String? variableNameOf(String code) => variableNames[code];
}
