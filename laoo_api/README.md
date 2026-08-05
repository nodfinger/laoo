# laoo_api

ASP.NET Core Web API สำหรับ Project `laoo`

## First Endpoint

```http
GET /api/system/info
```

## Run

```powershell
dotnet restore
dotnet build
dotnet run
```

## Security

ห้าม Commit Connection String จริงลง Git

สำหรับ Development ให้แก้ค่าใน

```text
appsettings.Development.json
```

และก่อน Push ให้ตรวจว่าไม่มี Password จริงอยู่ในไฟล์
