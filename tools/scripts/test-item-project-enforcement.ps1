param([string]$Root = (Resolve-Path "$PSScriptRoot/../..").Path)
$ErrorActionPreference = 'Stop'
# Execute the actual production SQL, not a duplicate policy implementation.
function Read-SqlConstant([string]$path, [string]$name) {
    $source = Get-Content (Join-Path $Root $path) -Raw -Encoding UTF8
    $match = [regex]::Match($source, '(?s)public const string ' + $name + ' = """\s*(.*?)\s*""";')
    if (!$match.Success) { throw "Missing SQL constant: $name" }
    return $match.Groups[1].Value
}
$sessionSql = Read-SqlConstant 'laoo_api/Security/RequireItemCatalogProjectAttribute.cs' 'SessionSql'
$permissionSql = Read-SqlConstant 'laoo_api/Security/RequireItemCatalogProjectAttribute.cs' 'PermissionSql'
$predicate = Read-SqlConstant 'projects/service/packages/dotnet/Laoo.Service.Module/Infrastructure/ItemProjectAccess.cs' 'ItemAliasPredicate'
$cfg = Get-Content (Join-Path $Root 'laoo_api/local.json') -Raw | ConvertFrom-Json
$connection = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$connection.Open()
$transaction = $connection.BeginTransaction()
$script:checks = 0
try {
    function Scalar([string]$sql, [hashtable]$values = @{}) {
        $cmd = $connection.CreateCommand()
        $cmd.Transaction = $transaction
        $cmd.CommandText = $sql
        foreach ($key in $values.Keys) { [void]$cmd.Parameters.AddWithValue('@' + $key, $values[$key]) }
        try { return $cmd.ExecuteScalar() } finally { $cmd.Dispose() }
    }
    function Assert-Value([string]$label, [bool]$actual, [bool]$expected) {
        if ($actual -ne $expected) { throw "FAIL: $label" }
        $script:checks++
        Write-Output "PASS: $label"
    }
    $fixture = Scalar @'
SELECT TOP(1) CONCAT(U.UserID,',',U.CompanyID,',',C.PartnerID,',',P.ProjectID,',',S.ProjectID,',',I.ItemID)
FROM dbo.TDADUser U JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.IsActive=1
JOIN dbo.TDADPartner B ON B.PartnerID=C.PartnerID AND B.IsActive=1
JOIN dbo.TDADProject P ON P.ProjectCode='LAOO' AND P.IsActive=1
JOIN dbo.TDADProject S ON S.ProjectCode='LAOO_SERVICE' AND S.IsActive=1
JOIN dbo.TDIVItem I ON I.CompanyID=U.CompanyID AND I.IsActive=1
WHERE U.IsActive=1 AND U.IsCompanyAdmin=1
AND EXISTS(SELECT 1 FROM dbo.TDADCompanyProject CP WHERE CP.CompanyID=U.CompanyID AND CP.PartnerID=C.PartnerID AND CP.ProjectID=P.ProjectID AND CP.IsEnabled=1 AND (CP.StartDate IS NULL OR CP.StartDate<=GETUTCDATE()) AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,GETUTCDATE())))
AND EXISTS(SELECT 1 FROM dbo.TDADCompanyProject CP WHERE CP.CompanyID=U.CompanyID AND CP.PartnerID=C.PartnerID AND CP.ProjectID=S.ProjectID AND CP.IsEnabled=1 AND (CP.StartDate IS NULL OR CP.StartDate<=GETUTCDATE()) AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,GETUTCDATE())))
ORDER BY U.UserID,I.ItemID;
'@
    if (!$fixture) { throw 'Requires an active company admin, item and enabled Core/Service projects.' }
    $ids = $fixture.Split(',') | ForEach-Object { [long]$_ }
    $scope = @{user=$ids[0]; company=$ids[1]; partner=$ids[2]; project=$ids[3]; service=$ids[4]; item=$ids[5]; action='VIEW'}
    Assert-Value 'Core session' (Scalar $sessionSql $scope) $true
    foreach ($action in @('VIEW','CREATE','EDIT','DELETE')) {
        $scope.action=$action
        Assert-Value "Core admin $action" (Scalar $permissionSql $scope) $true
    }
    $scope.action='UNSUPPORTED'
    Assert-Value 'Unsupported action denied' (Scalar $permissionSql $scope) $false
    $scope.action='VIEW'
    $wrong=$scope.Clone(); $wrong.company=-1
    Assert-Value 'Cross-company session denied' (Scalar $sessionSql $wrong) $false
    $wrong=$scope.Clone(); $wrong.partner=-1
    Assert-Value 'Cross-partner session denied' (Scalar $sessionSql $wrong) $false
    [void](Scalar 'UPDATE dbo.TDADCompanyProject SET IsEnabled=0 WHERE CompanyID=@company AND ProjectID=@service' $scope)
    Assert-Value 'Core does not require Service entitlement' (Scalar $sessionSql $scope) $true
    Assert-Value 'Core menu remains permitted without Service' (Scalar $permissionSql $scope) $true
    $itemSql="SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.TDIVItem I WHERE I.CompanyID=@company AND I.ItemID=@item AND I.IsActive=1 AND $predicate) THEN 1 ELSE 0 END AS bit)"
    [void](Scalar 'DELETE FROM dbo.TDIVItemProject WHERE CompanyID=@company AND ItemID=@item; DELETE FROM dbo.TDIVItemProjectPolicy WHERE CompanyID=@company AND ItemID=@item;' $scope)
    Assert-Value 'Core sales work with Service disabled' (Scalar $itemSql $scope) $true
    [void](Scalar 'UPDATE dbo.TDADCompanyProject SET IsEnabled=1 WHERE CompanyID=@company AND ProjectID=@service' $scope)
    [void](Scalar 'DELETE FROM dbo.TDIVItemProject WHERE CompanyID=@company AND ItemID=@item; DELETE FROM dbo.TDIVItemProjectPolicy WHERE CompanyID=@company AND ItemID=@item;' $scope)
    Assert-Value 'Legacy item allowed without policy' (Scalar $itemSql $scope) $true
    [void](Scalar "INSERT dbo.TDIVItemProjectPolicy(CompanyID,ItemID,AccessModeCode,UpdatedBy) VALUES(@company,@item,'ALL',@user)" $scope)
    Assert-Value 'ALL item allowed' (Scalar $itemSql $scope) $true
    [void](Scalar "UPDATE dbo.TDIVItemProjectPolicy SET AccessModeCode='SELECTED' WHERE CompanyID=@company AND ItemID=@item; INSERT dbo.TDIVItemProject(CompanyID,ItemID,ProjectID) VALUES(@company,@item,@project);" $scope)
    Assert-Value 'Core-only item allowed for delivery and stock' (Scalar $itemSql $scope) $true
    [void](Scalar 'INSERT dbo.TDIVItemProject(CompanyID,ItemID,ProjectID) VALUES(@company,@item,@service)' $scope)
    Assert-Value 'Core and Service selection allowed for Core' (Scalar $itemSql $scope) $true
    [void](Scalar 'DELETE FROM dbo.TDIVItemProject WHERE CompanyID=@company AND ItemID=@item AND ProjectID=@project' $scope)
    Assert-Value 'Service-only item denied to Core sales' (Scalar $itemSql $scope) $false
    $wrong=$scope.Clone(); $wrong.company=-1
    Assert-Value 'Cross-company item denied' (Scalar $itemSql $wrong) $false
    [void](Scalar 'UPDATE dbo.TDIVItem SET IsActive=0 WHERE CompanyID=@company AND ItemID=@item' $scope)
    Assert-Value 'Inactive item denied immediately' (Scalar $itemSql $scope) $false
    [void](Scalar 'UPDATE dbo.TDADUser SET IsCompanyAdmin=0 WHERE CompanyID=@company AND UserID=@user; UPDATE dbo.TDADUserProject SET IsActive=0 WHERE CompanyID=@company AND UserID=@user;' $scope)
    Assert-Value 'Nonadmin without project membership denied' (Scalar $sessionSql $scope) $false
    Assert-Value 'Nonadmin cannot bypass menu membership' (Scalar $permissionSql $scope) $false
    [void](Scalar 'UPDATE dbo.TDADUser SET IsCompanyAdmin=1,IsActive=0 WHERE CompanyID=@company AND UserID=@user' $scope)
    Assert-Value 'Inactive admin denied' (Scalar $sessionSql $scope) $false
    Write-Output "$script:checks checks passed. All fixture changes will be rolled back."
}
finally {
    $transaction.Rollback()
    $transaction.Dispose()
    $connection.Dispose()
}
