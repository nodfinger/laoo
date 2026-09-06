# LAOO Visitor

Business Project สำหรับระบบผู้มาติดต่อภายใน LAOO Monorepo

## Development ports

- Flutter Web: `8082`
- API: `5082`
- Project code: `LAOO_VISITOR`

## Run

```powershell
cd C:\laooplatform\laoo\projects\visitor\laoo_visitor_api
dotnet run
```

```powershell
cd C:\laooplatform\laoo\projects\visitor
flutter run -d web-server --web-port 8082 --dart-define=API_URL=http://localhost:5082 --dart-define=PROJECT_CODE=LAOO_VISITOR
```

Business menus remain inactive until their Route and API are implemented and tested.
Shared Branch, Employee, Organization, User, Permission, and Theme code must be consumed from `../../packages` instead of copied into this project.
