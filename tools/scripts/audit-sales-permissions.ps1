param([Parameter(Mandatory = $true)][string]$OutputPath)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$config = Get-Content -LiteralPath (Join-Path $root 'laoo_api\local.json') -Raw | ConvertFrom-Json
$source = Get-Content -LiteralPath (Join-Path $root 'packages\dotnet\Laoo.Shared.Contracts\CompanyMenuAccess.cs') -Raw
$match = [regex]::Match($source, '(?s)public const string Sql = """\s*(.*?)\s*""";')
if (-not $match.Success) { throw 'Cannot locate the shared authorization query.' }
$db = New-Object System.Data.SqlClient.SqlConnection($config.ConnectionStrings.LaooDatabase)
try {
    $db.Open()
    $usersCommand = $db.CreateCommand()
    $usersCommand.CommandText = "SELECT DISTINCT U.UserID,U.CompanyID,C.PartnerID FROM dbo.TDADUser U JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.IsActive=1 JOIN dbo.TDADUserProject UP ON UP.UserID=U.UserID AND UP.CompanyID=U.CompanyID AND UP.IsActive=1 JOIN dbo.TDADProject P ON P.ProjectID=UP.ProjectID AND P.ProjectCode=N'LAOO' WHERE U.IsActive=1 ORDER BY U.CompanyID,U.UserID"
    $reader = $usersCommand.ExecuteReader()
    $users = @()
    while ($reader.Read()) { $users += [pscustomobject]@{ User = $reader.GetInt64(0); Company = $reader.GetInt64(1); Partner = $reader.GetInt64(2) } }
    $reader.Close()
    $command = $db.CreateCommand()
    $command.CommandText = $match.Groups[1].Value
    [void]$command.Parameters.Add('@UserID', [System.Data.SqlDbType]::BigInt)
    [void]$command.Parameters.Add('@CompanyID', [System.Data.SqlDbType]::BigInt)
    [void]$command.Parameters.Add('@PartnerID', [System.Data.SqlDbType]::BigInt)
    [void]$command.Parameters.Add('@MenuCode', [System.Data.SqlDbType]::NVarChar, 20)
    [void]$command.Parameters.Add('@Action', [System.Data.SqlDbType]::NVarChar, 20)
    $results = [System.Collections.Generic.List[string]]::new()
    foreach ($user in $users) {
        $command.Parameters['@UserID'].Value = $user.User
        $command.Parameters['@CompanyID'].Value = $user.Company
        $command.Parameters['@PartnerID'].Value = $user.Partner
        foreach ($number in 1..27) {
            $menu = '090{0:D2}' -f $number
            $command.Parameters['@MenuCode'].Value = $menu
            foreach ($action in @('VIEW', 'CREATE', 'EDIT', 'DELETE', 'APPROVE', 'REJECT', 'ISSUE', 'RETURN', 'EXPORT', 'PREVIEW', 'DOWNLOAD', 'PRINT')) {
                $command.Parameters['@Action'].Value = $action
                if ([bool]$command.ExecuteScalar()) { $results.Add(('{0}|{1}|{2}|{3}' -f $user.Company, $user.User, $menu, $action)) }
            }
        }
    }
    $results | Sort-Object | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    "Audited $($users.Count) active users; $($results.Count) permitted actions."
} finally { $db.Dispose() }
