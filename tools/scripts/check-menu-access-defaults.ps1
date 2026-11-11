$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
try {
    $db.Open()
    $q = $db.CreateCommand()
    $q.CommandText = "SELECT U.CompanyID,ISNULL(G.ViewScope,'SELF'),ISNULL(G.EditMode,'HEAD'),ISNULL(G.DeleteMode,'HEAD') FROM dbo.TDADUser U LEFT JOIN dbo.TDSTTravelClaimAccess G ON G.CompanyID=U.CompanyID WHERE U.NormalizedUsername=N'IT#P' AND U.IsActive=1; SELECT M.MenuCode,M.MenuName,M.AllowDataAccessSettings,CASE WHEN P.MenuCode IS NULL THEN 'global' ELSE 'override' END FROM dbo.TDADMainMenu M LEFT JOIN dbo.TDSTMenuDataAccessPolicy P ON P.MenuCode=M.MenuCode AND P.CompanyID=(SELECT TOP 1 CompanyID FROM dbo.TDADUser WHERE NormalizedUsername=N'IT#P' AND IsActive=1) WHERE M.MenuCode IN ('66001','20001','21001') ORDER BY M.MenuCode"
    $r = $q.ExecuteReader()
    while ($r.Read()) { Write-Output ('Company {0}: view={1}, edit={2}, delete={3}' -f $r.GetValue(0),$r.GetValue(1),$r.GetValue(2),$r.GetValue(3)) }
    if ($r.NextResult()) { while ($r.Read()) { Write-Output ('Menu {0}: enabled={1}, source={2}' -f $r.GetValue(0),$r.GetValue(2),$r.GetValue(3)) } }
    $r.Close()
    $q.CommandText = "SELECT MenuCode,ViewScope,EditScope,DeleteScope FROM dbo.TDSTMenuDataAccessPolicy WHERE CompanyID=(SELECT TOP 1 CompanyID FROM dbo.TDADUser WHERE NormalizedUsername=N'IT#P' AND IsActive=1) AND MenuCode IN ('66001','20001','21001')"
    $r = $q.ExecuteReader()
    while ($r.Read()) { Write-Output ('Override {0}: view={1}, edit={2}, delete={3}' -f $r.GetValue(0),$r.GetValue(1),$r.GetValue(2),$r.GetValue(3)) }
    $r.Close()
} finally { $db.Dispose() }
