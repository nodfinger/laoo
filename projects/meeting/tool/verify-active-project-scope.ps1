param(
    [string]$ApiUrl = 'http://localhost:5080',
    [string]$ForeignProjectCode = 'LAOO_SERVICE'
)

$ErrorActionPreference = 'Stop'
$userName = $env:LAOO_MEETING_TEST_USERNAME
$password = $env:LAOO_MEETING_TEST_PASSWORD
if ([string]::IsNullOrWhiteSpace($userName) -or [string]::IsNullOrWhiteSpace($password)) {
    throw 'Set LAOO_MEETING_TEST_USERNAME and LAOO_MEETING_TEST_PASSWORD for a user assigned to Meeting and the foreign project.'
}

$baseUrl = $ApiUrl.TrimEnd('/')
$paths = @(
    '/api/company/meeting-foods',
    '/api/company/meeting-room-bookings'
)

function Get-HttpStatus([string]$url, [hashtable]$headers) {
    try {
        $response = Invoke-WebRequest -Method Get -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 10
        return [int]$response.StatusCode
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            return [int]$_.Exception.Response.StatusCode
        }
        throw
    }
}

function Get-ProjectHeaders([string]$projectCode) {
    $body = @{ username = $userName; password = $password; projectCode = $projectCode } |
        ConvertTo-Json -Compress
    $login = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/auth/login" -ContentType 'application/json' -Body $body -TimeoutSec 10
    if (-not $login.success -or [string]::IsNullOrWhiteSpace($login.accessToken)) {
        throw "Login failed for project $projectCode"
    }
    return @{ Authorization = 'Bearer ' + $login.accessToken }
}

$meetingHeaders = Get-ProjectHeaders 'LAOO_MEETING'
$foreignHeaders = Get-ProjectHeaders $ForeignProjectCode
foreach ($path in $paths) {
    $meetingStatus = Get-HttpStatus ($baseUrl + $path) $meetingHeaders
    $foreignStatus = Get-HttpStatus ($baseUrl + $path) $foreignHeaders
    if ($meetingStatus -ne 200 -or $foreignStatus -ne 403) {
        throw "$path expected Meeting=200 and $ForeignProjectCode=403; got $meetingStatus/$foreignStatus"
    }
    Write-Output "PASS $path Meeting=200 $ForeignProjectCode=403"
}

$guestStatus = Get-HttpStatus ($baseUrl + $paths[0]) @{}
if ($guestStatus -ne 401) {
    throw "Anonymous request expected 401; got $guestStatus"
}
Write-Output 'PASS anonymous=401'
