param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
)

$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path $RepositoryRoot 'laoo_api\Controllers\ServiceRequestController.cs'
$settingsPath = Join-Path $RepositoryRoot 'laoo_api\local.json'
$source = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
$match = [regex]::Match(
    $source,
    'new SqlCommand\("(?<sql>UPDATE dbo\.TDIVStockBalance[^"]+)", c, tx\)'
)
if (-not $match.Success) { throw 'Service repair stock SQL was not found.' }
$stockSql = $match.Groups['sql'].Value
if ([regex]::Matches($stockSql, 'IF @@ROWCOUNT=0 THROW 52331').Count -ne 2) {
    throw 'Both warehouse and item balance updates must check affected rows.'
}
$stockSql = $stockSql.Replace('dbo.TDIVStockBalance', '#StockBalance').Replace('dbo.TDIVItem', '#Item')

$config = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$connection = [System.Data.SqlClient.SqlConnection]::new($config.ConnectionStrings.LaooDatabase)
try {
    $connection.Open()
    $setup = $connection.CreateCommand()
    $setup.CommandText = @'
CREATE TABLE #StockBalance (
    CompanyID bigint NOT NULL, WarehouseID bigint NOT NULL, ItemID bigint NOT NULL,
    Quantity decimal(18,3) NOT NULL, UpdateDate datetime2 NULL
);
CREATE TABLE #Item (
    CompanyID bigint NOT NULL, ItemID bigint NOT NULL,
    StockBalance decimal(18,3) NOT NULL, UpdateDate datetime2 NULL
);
INSERT #StockBalance(CompanyID,WarehouseID,ItemID,Quantity) VALUES(1,1,1,5);
INSERT #Item(CompanyID,ItemID,StockBalance) VALUES(1,1,5);
'@
    [void]$setup.ExecuteNonQuery()

    function Invoke-StockCase([decimal]$quantity, [bool]$expectFailure) {
        $transaction = $connection.BeginTransaction()
        try {
            $command = $connection.CreateCommand()
            $command.Transaction = $transaction
            $command.CommandText = $stockSql
            foreach ($entry in @(
                @('@company', [long]1),
                @('@warehouse', [long]1),
                @('@item', [long]1),
                @('@qty', $quantity)
            )) {
                [void]$command.Parameters.AddWithValue($entry[0], $entry[1])
            }
            if ($expectFailure) {
                $command.CommandText = 'UPDATE #Item SET StockBalance=1 WHERE CompanyID=1 AND ItemID=1'
                [void]$command.ExecuteNonQuery()
                $command.CommandText = $stockSql
            }
            [void]$command.ExecuteNonQuery()
            if ($expectFailure) { throw 'Expected item-balance conflict was not raised.' }
            $check = $connection.CreateCommand()
            $check.Transaction = $transaction
            $check.CommandText = 'SELECT b.Quantity,i.StockBalance FROM #StockBalance b JOIN #Item i ON i.CompanyID=b.CompanyID AND i.ItemID=b.ItemID'
            $reader = $check.ExecuteReader()
            try {
                if (-not $reader.Read() -or $reader.GetDecimal(0) -ne 3 -or $reader.GetDecimal(1) -ne 3) {
                    throw 'Successful stock issue did not decrement both balances.'
                }
            } finally { $reader.Close() }
            Write-Output 'PASS: sufficient stock decreases warehouse and item balances together'
        } catch {
            $sqlError = $_.Exception
            while ($null -ne $sqlError -and $sqlError -isnot [System.Data.SqlClient.SqlException]) {
                $sqlError = $sqlError.InnerException
            }
            if (-not $expectFailure -or $null -eq $sqlError -or $sqlError.Number -ne 52331) { throw }
            Write-Output 'PASS: insufficient item balance raises 52331'
        } finally {
            $transaction.Rollback()
            $transaction.Dispose()
        }
        $verify = $connection.CreateCommand()
        $verify.CommandText = 'SELECT b.Quantity,i.StockBalance FROM #StockBalance b JOIN #Item i ON i.CompanyID=b.CompanyID AND i.ItemID=b.ItemID'
        $reader = $verify.ExecuteReader()
        try {
            if (-not $reader.Read() -or $reader.GetDecimal(0) -ne 5 -or $reader.GetDecimal(1) -ne 5) {
                throw 'Rollback did not restore both balances.'
            }
        } finally { $reader.Close() }
        Write-Output 'PASS: transaction rollback restores both balances'
    }

    Invoke-StockCase -quantity 2 -expectFailure $false
    Invoke-StockCase -quantity 2 -expectFailure $true
} finally {
    $connection.Dispose()
}
