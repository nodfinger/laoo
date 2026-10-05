namespace Laoo.SchoolFood;

public sealed record FoodMenu(string Code, string Name, int ScreenType, string Route,
    string Icon, string[] Actions);

public static class SchoolFoodContract
{
    public const string Project = "LAOO_SCHOOL_FOOD";
    public static readonly FoodMenu[] Menus =
    [
        new("53001","ตั้งค่าระบบขายอาหารในโรงเรียน",2,"school-food-settings","settings_outlined",["VIEW","EDIT"]),
        new("53002","ข้อมูลร้านค้าในโรงเรียน",1,"school-food-shops","storefront_outlined",["VIEW","CREATE","EDIT","DELETE"]),
        new("53003","สินค้าที่ขายแยกตามร้านค้า",2,"school-food-items","inventory_2_outlined",["VIEW","EDIT"]),
        new("53004","กำหนดเปอร์เซ็นต์หักยอดขาย",2,"school-food-commission","percent",["VIEW","EDIT"]),
        new("53005","บัตรและลายนิ้วมือนักเรียน",1,"school-food-identifiers","badge_outlined",["VIEW","CREATE","EDIT","DELETE","MANAGE_DEVICE","MANAGE_CREDENTIAL"]),
        new("53006","โอนและรับสต๊อกร้านค้า",4,"school-food-transfers","swap_horiz",["VIEW","CREATE","EDIT","DELETE","TRANSFER","RECEIVE"]),
        new("53007","Wallet และการเติมเงิน",4,"school-food-wallet","account_balance_wallet_outlined",["VIEW","TOPUP","ADJUST"]),
        new("53008","ขายหน้าร้าน",4,"school-food-pos","point_of_sale",["VIEW","SALE"]),
        new("53009","ประวัติขายและคืนสินค้า",4,"school-food-sales","receipt_long_outlined",["VIEW","REFUND"]),
        new("53010","ประวัติการซื้อของนักเรียน",3,"school-food-students","history",["VIEW","EXPORT"]),
        new("53011","กระทบยอดร้านค้า",3,"school-food-settlements","fact_check_outlined",["VIEW","EXPORT"]),
        new("53012","Dashboard และรายงาน",3,"school-food-dashboard","dashboard_outlined",["VIEW","EXPORT"])
    ];
}
