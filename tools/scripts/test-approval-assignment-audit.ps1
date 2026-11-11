$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$cfg = Get-Content (Join-Path $root 'laoo_api/local.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$db = New-Object System.Data.SqlClient.SqlConnection($cfg.ConnectionStrings.LaooDatabase)
$db.Open(); $tx = $db.BeginTransaction()
try {
    $q = $db.CreateCommand(); $q.Transaction = $tx
    $q.CommandText = @'
DECLARE @company bigint=(SELECT TOP(1) CompanyID FROM dbo.TDADEmployee WHERE CompanyID IS NOT NULL AND IsActive=1 GROUP BY CompanyID HAVING COUNT(*)>=2 ORDER BY CompanyID);
DECLARE @requester bigint=(SELECT MIN(EmployeeID) FROM dbo.TDADEmployee WHERE CompanyID=@company AND IsActive=1);
DECLARE @approver bigint=(SELECT MAX(EmployeeID) FROM dbo.TDADEmployee WHERE CompanyID=@company AND IsActive=1);
DECLARE @user bigint=(SELECT TOP(1) UserID FROM dbo.TDADUser WHERE CompanyID=@company AND IsActive=1 ORDER BY UserID);
IF @company IS NULL OR @user IS NULL THROW 54260,'Missing sample for audit test',1;
DELETE FROM dbo.TDSTPersonalApprovalStep WHERE CompanyID=@company AND MenuCode='66001';
DELETE FROM dbo.TDSTMenuApprovalAssignment WHERE CompanyID=@company AND MenuCode='66001';
INSERT dbo.TDSTApprovalPatternCatalog(CompanyID,PatternCode,PatternName,PatternType,LevelsUp,UpdateBy) VALUES(@company,N'__audit_test__',N'test','MANUAL',NULL,@user);
INSERT dbo.TDSTMenuApprovalAssignment(CompanyID,MenuCode,PatternCode,UpdateBy,UpdateDate) VALUES(@company,'66001',N'__audit_test__',@user,'2020-01-01');
INSERT dbo.TDSTPersonalApprovalStep(CompanyID,MenuCode,RequesterEmployeeID,StepNo,ApproverEmployeeID,UpdateBy,UpdateDate) VALUES(@company,'66001',@requester,1,@approver,@user,'2021-02-03T04:05:06');
SELECT @company;
'@
    $company = [long]$q.ExecuteScalar()
    $source = [IO.File]::ReadAllText((Join-Path $root 'laoo_api/Controllers/CompanyApprovalAssignmentController.cs'))
    $sql = [regex]::Match($source, '(?s)const string sql="""\s*(.*?)\s*""";').Groups[1].Value
    if (!$sql) { throw 'List query not found.' }
    $q.CommandText = $sql; [void]$q.Parameters.AddWithValue('@company',$company)
    $reader = $q.ExecuteReader(); $found = $false
    while ($reader.Read()) {
        if ($reader.GetString(0).Trim() -eq '66001') {
            $found = $true
            if ($reader.IsDBNull(10) -or $reader.GetDateTime(10) -ne [DateTime]'2021-02-03T04:05:06') { throw 'Latest personal update not selected.' }
            if ([string]::IsNullOrWhiteSpace($reader.GetString(6)) -and [string]::IsNullOrWhiteSpace($reader.GetString(7)) -and [string]::IsNullOrWhiteSpace($reader.GetString(9))) { throw 'Editor identity not available.' }
        }
    }
    $reader.Close()
    if (!$found) { throw 'Test menu not listed.' }
    Write-Output 'Latest approval editor/date query passed; all changes rolled back.'
} finally { $tx.Rollback(); $db.Close() }
