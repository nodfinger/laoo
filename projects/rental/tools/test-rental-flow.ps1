param([Parameter(Mandatory = $true)][string]$Password)
$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:5080'
$run = 'RN_20261009_DEMO'
$login = Invoke-RestMethod "$base/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{ username = 'c111'; password = $Password } | ConvertTo-Json)
if (-not $login.accessToken) { throw 'Login failed' }
$headers = @{ Authorization = "Bearer $($login.accessToken)" }
Add-Type -AssemblyName System.Net.Http
$http = New-Object System.Net.Http.HttpClient
$http.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $login.accessToken)
$png = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9zVLkAAAAASUVORK5CYII=')
$count = 0
function Call-Rental([string]$method, [string]$path, $body = $null) {
    $args = @{ Uri = "$base/api/company/rental/$path"; Method = $method; Headers = $headers; UseBasicParsing = $true }
    if ($null -ne $body) { $args.ContentType = 'application/json'; $args.Body = $body | ConvertTo-Json -Depth 10 -Compress }
    try {
        $response = Invoke-WebRequest @args
        $data = if ($response.Content) { $response.Content | ConvertFrom-Json } else { $null }
        return @{ status = [int]$response.StatusCode; data = $data }
    } catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if (-not $response) { throw }
        $reader = New-Object IO.StreamReader($response.GetResponseStream())
        $content = $reader.ReadToEnd()
        $reader.Dispose()
        $data = if ($content) { try { $content | ConvertFrom-Json } catch { $content } } else { $null }
        return @{ status = [int]$response.StatusCode; data = $data }
    }
}
function Check([string]$name, $result, [int[]]$expected) {
    if ($result.status -notin $expected) { throw "$name expected $($expected -join '/') got $($result.status): $($result.data | ConvertTo-Json -Compress -Depth 3)" }
    $script:count++
    Write-Output "$name=$($result.status)"
}
function Upload([string]$kind, [long]$line = 0) {
    $form = New-Object System.Net.Http.MultipartFormDataContent
    $form.Add([System.Net.Http.StringContent]::new($kind), 'kind')
    if ($line -gt 0) { $form.Add([System.Net.Http.StringContent]::new([string]$line), 'bookingLineId') }
    $file = [System.Net.Http.ByteArrayContent]::new($png)
    $file.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('image/png')
    $form.Add($file, 'file', 'flow.png')
    $response = $http.PostAsync("$base/api/company/rental/bookings/1/attachments", $form).Result
    $data = $response.Content.ReadAsStringAsync().Result
    $form.Dispose()
    if ([int]$response.StatusCode -ne 201) { throw "Upload $kind failed: $([int]$response.StatusCode) $data" }
    $script:count++
    Write-Host "upload-$kind=201"
    return ($data | ConvertFrom-Json).id
}
try {
    foreach ($menu in 60001..60010) { Check "actions-$menu" (Call-Rental GET "actions/$menu") @(200) }
    Check settings (Call-Rental GET settings) @(200)
    Check items (Call-Rental GET 'items?branchId=2') @(200)
    Check options (Call-Rental GET 'options/60002') @(200)
    Check forbidden-branch (Call-Rental GET 'items?branchId=13') @(403)
    $booking = Call-Rental GET 'bookings/1?menu=60006'
    Check fixture-booking $booking @(200)
    $line = [long]$booking.data.lines[0].BookingLineID
    Check payment-receipt (Call-Rental GET 'payments/1/receipt-data') @(200)
    if ($booking.data.header.StatusCode -eq 'PAID') {
    Check handover-no-proof (Call-Rental POST 'bookings/1/handover' @{ staffSignAttachmentId = 99999; customerSignAttachmentId = 99998; serials = @() }) @(400)
    $hs = Upload HANDOVER_STAFF_SIGN
    $hc = Upload HANDOVER_CUSTOMER_SIGN
    $null = Upload HANDOVER_PHOTO $line
    Check serial-before-handover (Call-Rental GET 'bookings/1/serial-lookup?stage=HANDOVER&serialNo=111') @(200)
    $handover = @{ staffSignAttachmentId = $hs; customerSignAttachmentId = $hc; serials = @(@{ bookingLineId = $line; instanceIds = @(12, 13) }) }
    Check handover (Call-Rental POST 'bookings/1/handover' $handover) @(200)
    Check handover-repeat (Call-Rental POST 'bookings/1/handover' $handover) @(409)
    Check settlement-too-early (Call-Rental POST 'bookings/1/settlement/approve' @{ approvedDeduction = 0; reason = $run }) @(409)
    Check serial-before-return (Call-Rental GET 'bookings/1/serial-lookup?stage=RETURN&serialNo=111') @(200)
    $rs = Upload RETURN_STAFF_SIGN
    $rc = Upload RETURN_CUSTOMER_SIGN
    $null = Upload RETURN_PHOTO $line
    $part = Call-Rental POST 'bookings/1/returns' @{ staffSignAttachmentId = $rs; customerSignAttachmentId = $rc; lines = @(@{ bookingLineId = $line; quantity = 1; condition = 'OK'; damageAmount = 0; remark = $run; instanceIds = @(12) }) }
    Check partial-return $part @(200)
    if ($part.data.outstanding -ne 1) { throw 'Partial return quantity mismatch' }
    $rs2 = Upload RETURN_STAFF_SIGN
    $rc2 = Upload RETURN_CUSTOMER_SIGN
    $null = Upload RETURN_PHOTO $line
    $finish = Call-Rental POST 'bookings/1/returns' @{ staffSignAttachmentId = $rs2; customerSignAttachmentId = $rc2; lines = @(@{ bookingLineId = $line; quantity = 1; condition = 'DAMAGED'; damageAmount = 120; remark = $run; instanceIds = @(13) }) }
    Check damaged-return $finish @(200)
    if ($finish.data.outstanding -ne 0) { throw 'Final return quantity mismatch' }
    Check over-return (Call-Rental POST 'bookings/1/returns' @{ staffSignAttachmentId = $rs2; customerSignAttachmentId = $rc2; lines = @(@{ bookingLineId = $line; quantity = 1; condition = 'OK'; damageAmount = 0; instanceIds = @(12) }) }) @(409)
    Check settlement-proposal (Call-Rental GET 'bookings/1/settlement') @(200)
    $settle = Call-Rental POST 'bookings/1/settlement/approve' @{ approvedDeduction = 120; reason = "$run damage approved" }
    Check settlement-approved $settle @(200)
    if ($settle.data.refund -ne 880) { throw 'Refund should be 880' }
    Check settlement-repeat (Call-Rental POST 'bookings/1/settlement/approve' @{ approvedDeduction = 120; reason = $run }) @(409)
    $refund = @{ method = 'CASH'; idempotencyKey = "$run-refund" }
    Check refund (Call-Rental POST 'bookings/1/settlement/refund' $refund) @(200)
    Check refund-repeat (Call-Rental POST 'bookings/1/settlement/refund' $refund) @(200)
    } elseif ($booking.data.header.StatusCode -eq 'CLOSED') {
        if ($booking.data.returns.Count -ne 2) { throw 'Expected two return rounds' }
        if ($booking.data.settlement.StatusCode -ne 'REFUNDED') { throw 'Expected refunded settlement' }
        $hs = [long]($booking.data.attachments | Where-Object Kind -eq 'HANDOVER_STAFF_SIGN' | Select-Object -First 1).AttachmentID
        Check handover-repeat (Call-Rental POST 'bookings/1/handover' @{
            staffSignAttachmentId = $hs
            customerSignAttachmentId = 999999
            serials = @()
        }) @(409)
        Check refund-repeat (Call-Rental POST 'bookings/1/settlement/refund' @{
            method = 'CASH'
            idempotencyKey = "$run-refund"
        }) @(200)
    } else { throw "Unexpected booking state: $($booking.data.header.StatusCode)" }
    Check history (Call-Rental GET 'history?page=1&pageSize=10') @(200)
    Check dashboard (Call-Rental GET dashboard) @(200)
    Check attachment-download (Call-Rental GET "attachments/$hs") @(200)
    Check unknown-booking (Call-Rental GET 'bookings/999999?menu=60009') @(404)
    Write-Output "PASS_COUNT=$count RUN_ID=$run BOOKING_ID=1"
} finally { $http.Dispose() }
