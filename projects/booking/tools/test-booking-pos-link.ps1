param([Parameter(Mandatory=$true)][string]$Password)
$ErrorActionPreference='Stop'
$base='http://127.0.0.1:5080'
$run='BK_20261009_DEMO_POS'
$terminal='46004001-0000-4000-8000-000000000001'
$login=Invoke-RestMethod "$base/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{username='c111';password=$Password}|ConvertTo-Json)
if(-not $login.accessToken){throw 'DEMO login failed'}
$headers=@{Authorization="Bearer $($login.accessToken)"}
function Call([string]$method,[string]$path,$body=$null){
 $args=@{Uri="$base/$path";Method=$method;Headers=$headers;UseBasicParsing=$true;TimeoutSec=30}
 if($null -ne $body){$args.ContentType='application/json';$args.Body=$body|ConvertTo-Json -Depth 10 -Compress}
 try{$r=Invoke-WebRequest @args;return @{status=[int]$r.StatusCode;data=if($r.Content){$r.Content|ConvertFrom-Json}else{$null}}}
 catch [System.Net.WebException]{$response=$_.Exception.Response;if(-not $response){throw};$reader=[IO.StreamReader]::new($response.GetResponseStream());$content=$reader.ReadToEnd();$reader.Dispose();return @{status=[int]$response.StatusCode;data=if($content){try{$content|ConvertFrom-Json}catch{$content}}else{$null}}}
}
function Expect([string]$name,$result,[int]$status){
 if($result.status -ne $status){throw "$name expected $status got $($result.status): $($result.data|ConvertTo-Json -Compress -Depth 4)"}
 Write-Output "$name=$status"
}
$bookingActions=Call GET 'api/company/booking/actions/61008'
Expect 'booking-actions' $bookingActions 200
if($bookingActions.data.actions.sale -ne $true){throw 'Booking SALE permission missing'}
$posActions=Call GET 'api/company/pos/actions/46004'
Expect 'pos-actions' $posActions 200
if($posActions.data.create -ne $true -or $posActions.data.finalize -ne $true){throw 'POS sale permission missing'}
$bootstrap=Call GET "api/company/pos/bootstrap/$terminal"
Expect 'pos-terminal' $bootstrap 200
if([long]$bootstrap.data.branchID -ne 2){throw 'Fixture terminal branch changed'}
$openedShift=$null
if(-not $bootstrap.data.shiftId){
 $open=Call POST 'api/company/pos/shifts/open' @{activationID=$terminal;openingCash=0}
 Expect 'open-test-shift' $open 200
 $openedShift=[long]$open.data.id
}
$items=Call GET 'api/company/pos/outlet-items'
Expect 'pos-items' $items 200
$item=$items.data|Where-Object { $_.outletID -eq $bootstrap.data.outletID -and $_.sellable -and $_.price -gt 0 -and $_.stock -ge 1 }|Select-Object -First 1
if(-not $item){throw 'No in-stock POS item for Booking test'}
$settings=Call GET 'api/company/pos/settings'
Expect 'pos-settings' $settings 200
$net=[decimal]$item.price*(1+[decimal]$settings.data.taxPercent/100)
$received=[math]::Ceiling($net)
$sale=Call POST 'api/company/pos/sales/finalize' @{
 activationID=$terminal;idempotencyKey=[guid]::NewGuid().ToString();items=@(@{itemID=[long]$item.itemID;quantity=1});
 discountAmount=0;paymentCode='CASH';receivedAmount=$received;paymentReference=$run;customerID=$null
}
Expect 'pos-sale-created' $sale 200
$saleId=[long]$sale.data.id
$services=Call GET 'api/company/booking/services'
Expect 'booking-services' $services 200
$service=$services.data|Where-Object code -eq 'BK26_GROOM'|Select-Object -First 1
if(-not $service){throw 'Booking fixture service missing'}
$start=[datetime]::UtcNow.AddDays(6)
$booking=Call POST 'api/company/booking/bookings' @{
 memberId=$null;guestName="POS $run";guestPhone='0000000000';branchId=2;
 startsAt=$start.ToString('o');endsAt=$start.AddHours(1).ToString('o');note=$run;
 services=@(@{serviceId=[long]$service.id;providerId=$null;resourceId=$null})
}
Expect 'booking-created' $booking 201
$bookingId=[long]$booking.data.id
Expect 'reject-missing-sale' (Call POST "api/company/booking/bookings/$bookingId/sales" @{saleId=999999999}) 400
Expect 'link-pos-sale' (Call POST "api/company/booking/bookings/$bookingId/sales" @{saleId=$saleId}) 204
Expect 'reject-duplicate-link' (Call POST "api/company/booking/bookings/$bookingId/sales" @{saleId=$saleId}) 409
$detail=Call GET "api/company/booking/bookings/${bookingId}?menu=61008"
Expect 'booking-detail' $detail 200
if(-not @($detail.data.sales|Where-Object saleId -eq $saleId).Count){throw 'Linked POS sale missing from Booking detail'}
$posDetail=Call GET "api/company/pos/sales/$saleId"
Expect 'pos-sale-detail' $posDetail 200
if($posDetail.data.header[0].status -ne 'COMPLETED'){throw 'POS sale status changed unexpectedly'}
if($openedShift){
 $close=Call POST "api/company/pos/shifts/$openedShift/close" @{countedCash=$net;remark=$run}
 Expect 'close-test-shift' $close 204
}
Write-Output "BOOKING_POS_LINK=PASS RUN_ID=$run BOOKING_ID=$bookingId SALE_ID=$saleId"
