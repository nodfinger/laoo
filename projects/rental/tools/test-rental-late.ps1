param([Parameter(Mandatory = $true)][string]$Password,[long]$BookingId=8)
$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:5080/api/company/rental'
$run = 'RN_20261009_DEMO_LATE'
$login = Invoke-RestMethod 'http://127.0.0.1:5080/api/auth/login' -Method Post -ContentType 'application/json' -Body (@{username='c111';password=$Password}|ConvertTo-Json)
$headers = @{Authorization="Bearer $($login.accessToken)"}
Add-Type -AssemblyName System.Net.Http
$http = New-Object System.Net.Http.HttpClient
$http.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$login.accessToken)
$png = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9zVLkAAAAASUVORK5CYII=')
function Upload([long]$booking,[string]$kind,[long]$line=0) {
    $form=New-Object System.Net.Http.MultipartFormDataContent
    $form.Add([System.Net.Http.StringContent]::new($kind),'kind')
    if($line -gt 0){$form.Add([System.Net.Http.StringContent]::new([string]$line),'bookingLineId')}
    $file=[System.Net.Http.ByteArrayContent]::new($png)
    $file.Headers.ContentType=[System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('image/png')
    $form.Add($file,'file','late.png')
    $response=$http.PostAsync("$base/bookings/$booking/attachments",$form).Result
    $content=$response.Content.ReadAsStringAsync().Result
    $form.Dispose()
    if([int]$response.StatusCode -ne 201){throw "Upload $kind failed: $content"}
    return ($content|ConvertFrom-Json).id
}
try {
    if($BookingId -eq 0){
        $start=[DateTime]::UtcNow.AddSeconds(25)
        $end=$start.AddSeconds(20)
        $booking=Invoke-RestMethod "$base/bookings" -Method Post -Headers $headers -ContentType 'application/json' -Body (@{
            branchId=2;customerId=10;startAt=$start.ToString('o');endAt=$end.ToString('o')
            idempotencyKey="$run-$([guid]::NewGuid())";lines=@(@{rentalItemId=3;quantity=1})
        }|ConvertTo-Json -Depth 5)
        if($booking.totalRent -ne 40 -or $booking.totalDeposit -ne 0){throw 'Unexpected rent or deposit'}
        $id=[long]$booking.id
        Write-Output "BOOKING=$id RENT=40 DEPOSIT=0"
        $null=Invoke-RestMethod "$base/bookings/$id/payments" -Method Post -Headers $headers -ContentType 'application/json' -Body (@{
            kind='RENT';amount=40;method='CASH';idempotencyKey="$run-RENT-$id"
        }|ConvertTo-Json)
    } else {$id=$BookingId}
    $detail=Invoke-RestMethod "$base/bookings/${id}?menu=60006" -Headers $headers
    if($detail.header.StatusCode -eq 'CLOSED'){
        if($detail.returnLines[0].lateFee -ne 40){throw 'Persisted late fee is incorrect'}
        Write-Output "LATE_FLOW=PASS BOOKING_ID=$id RECHECK=TRUE"
        exit 0
    }
    if($detail.header.StatusCode -ne 'PAID'){throw "Expected PAID, got $($detail.header.StatusCode)"}
    $end=[DateTime]::SpecifyKind([DateTime]::Parse($detail.header.EndAt),[DateTimeKind]::Utc)
    $line=[long]$detail.lines[0].BookingLineID
    $staff=Upload $id HANDOVER_STAFF_SIGN
    $customer=Upload $id HANDOVER_CUSTOMER_SIGN
    $null=Upload $id HANDOVER_PHOTO $line
    $null=Invoke-RestMethod "$base/bookings/$id/handover" -Method Post -Headers $headers -ContentType 'application/json' -Body (@{
        staffSignAttachmentId=$staff;customerSignAttachmentId=$customer;serials=@()
    }|ConvertTo-Json -Depth 5)
    $delay=[Math]::Max(0,[int][Math]::Ceiling(($end.AddSeconds(3)-[DateTime]::UtcNow).TotalSeconds))
    if($delay -gt 0){Start-Sleep -Seconds $delay}
    $returnStaff=Upload $id RETURN_STAFF_SIGN
    $returnCustomer=Upload $id RETURN_CUSTOMER_SIGN
    $null=Upload $id RETURN_PHOTO $line
    $null=Invoke-RestMethod "$base/bookings/$id/returns" -Method Post -Headers $headers -ContentType 'application/json' -Body (@{
        staffSignAttachmentId=$returnStaff;customerSignAttachmentId=$returnCustomer
        lines=@(@{bookingLineId=$line;quantity=1;condition='OK';damageAmount=0;remark=$run;instanceIds=@()})
    }|ConvertTo-Json -Depth 6)
    $after=Invoke-RestMethod "$base/bookings/${id}?menu=60007" -Headers $headers
    $late=[decimal]$after.returnLines[0].lateFee
    if($late -ne 40){throw "Expected one hour late fee 40, got $late"}
    Write-Output "LATE_FEE=$late"
    $settlement=Invoke-RestMethod "$base/bookings/$id/settlement/approve" -Method Post -Headers $headers -ContentType 'application/json' -Body (@{
        approvedDeduction=$late;reason="$run actual clock late"
    }|ConvertTo-Json)
    if($settlement.additional -ne 40){throw 'Expected additional due 40'}
    $null=Invoke-RestMethod "$base/bookings/$id/payments" -Method Post -Headers $headers -ContentType 'application/json' -Body (@{
        kind='ADDITIONAL';amount=40;method='CASH';idempotencyKey="$run-ADDITIONAL"
    }|ConvertTo-Json)
    $refund=Invoke-RestMethod "$base/bookings/$id/settlement/refund" -Method Post -Headers $headers -ContentType 'application/json' -Body (@{
        method='CASH';idempotencyKey="$run-REFUND"
    }|ConvertTo-Json)
    if($refund.status -ne 'CLOSED'){throw 'Late booking did not close'}
    Write-Output "LATE_FLOW=PASS BOOKING_ID=$id"
} finally {$http.Dispose()}
