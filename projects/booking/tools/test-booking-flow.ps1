param([Parameter(Mandatory=$true)][string]$Password)
$ErrorActionPreference='Stop'
$apiBase='http://127.0.0.1:5080'
$run='BK_20261009_DEMO'
$login=Invoke-RestMethod "$apiBase/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{username='c111';password=$Password}|ConvertTo-Json)
if(-not $login.accessToken){throw 'DEMO login failed'}
$headers=@{Authorization="Bearer $($login.accessToken)"}
$checks=0
function Call-Booking([string]$method,[string]$path,$body=$null,[bool]$authorized=$true){
 $args=@{Uri="$apiBase/api/company/booking/$path";Method=$method;UseBasicParsing=$true;TimeoutSec=30}
 if($authorized){$args.Headers=$headers}
 if($null -ne $body){$args.ContentType='application/json';$args.Body=$body|ConvertTo-Json -Depth 12 -Compress}
 try{$r=Invoke-WebRequest @args;$data=if($r.Content){$r.Content|ConvertFrom-Json}else{$null};return @{status=[int]$r.StatusCode;data=$data}}
 catch [System.Net.WebException]{$res=$_.Exception.Response;if(-not $res){throw};$reader=New-Object IO.StreamReader($res.GetResponseStream());$content=$reader.ReadToEnd();$reader.Dispose();$data=if($content){try{$content|ConvertFrom-Json}catch{$content}}else{$null};return @{status=[int]$res.StatusCode;data=$data}}
}
function Check([string]$name,$result,[int[]]$expected){
 if($result.status -notin $expected){throw "$name expected $($expected -join '/') got $($result.status): $($result.data|ConvertTo-Json -Compress -Depth 4)"}
 $script:checks++
 Write-Output "$name=$($result.status)"
}
$now=[DateTime]::UtcNow
$from=[Uri]::EscapeDataString($now.AddDays(-3).ToString('o'))
$to=[Uri]::EscapeDataString($now.AddDays(10).ToString('o'))
foreach($menu in 61001..61010){Check "actions-$menu" (Call-Booking GET "actions/$menu") @(200)}
Check unauthenticated (Call-Booking GET services $null $false) @(401)
Check settings (Call-Booking GET settings) @(200)
Check update-settings (Call-Booking PUT settings @{advanceDays=90;cancelBeforeHours=2;noShowGraceMinutes=15}) @(204)
$services=Call-Booking GET services;Check services $services @(200)
$servicePage=Call-Booking GET 'services?page=1&pageSize=1';Check service-page $servicePage @(200)
if($servicePage.data.items.Count -ne 1 -or $servicePage.data.total -lt 3){throw 'Service pagination mismatch'}
Check invalid-service-page (Call-Booking GET 'services?page=0') @(400)
Check oversized-service-page (Call-Booking GET 'services?page=2147483647&pageSize=100') @(400)
$groom=($services.data|Where-Object code -eq 'BK26_GROOM'|Select-Object -First 1)
$pickup=($services.data|Where-Object code -eq 'BK26_PICKUP'|Select-Object -First 1)
$court=($services.data|Where-Object code -eq 'BK26_COURT'|Select-Object -First 1)
if(-not $groom -or -not $pickup -or -not $court){throw 'Fixture services not found'}
$members=Call-Booking GET 'members?page=1&pageSize=20';Check members $members @(200)
$member=($members.data.items|Where-Object code -eq 'BK26_MEMBER'|Select-Object -First 1)
if(-not $member){throw 'Fixture member not found'}
Check duplicate-member (Call-Booking POST members @{personId=$member.personId;memberCode='BK26_MEMBER';tierCode='GOLD';startsOn=$now.ToString('yyyy-MM-dd');expiresOn=$null}) @(409)
$providers=Call-Booking GET providers;Check providers $providers @(200)
Check provider-page (Call-Booking GET 'providers?page=1&pageSize=1') @(200)
$provider=($providers.data|Where-Object personId -eq 2|Select-Object -First 1)
if(-not $provider){throw 'Fixture provider not found'}
Check provider-schedule (Call-Booking GET "providers/$($provider.id)/schedule") @(200)
Check provider-schedule-save (Call-Booking PUT "providers/$($provider.id)/schedule" @{serviceIds=@($groom.id);slots=@(@{weekdayNumber=1;startsAt='09:00:00';endsAt='17:00:00'})}) @(204)
$resources=Call-Booking GET resources;Check resources $resources @(200)
Check resource-page (Call-Booking GET 'resources?page=1&pageSize=1') @(200)
$resource=($resources.data|Where-Object name -like "*$run*"|Select-Object -First 1)
if(-not $resource){throw 'Fixture resource not found'}
Check resource-services (Call-Booking GET "resources/$($resource.id)/services") @(200)
Check resource-services-save (Call-Booking PUT "resources/$($resource.id)/services" @{serviceIds=@($court.id)}) @(204)
Check promotions (Call-Booking GET promotions) @(200)
Check promotion-page (Call-Booking GET 'promotions?page=1&pageSize=1') @(200)
$future=$now.AddDays(2)
$end=$future.AddHours(1)
$guest=@{memberId=$null;guestName="Guest $run";guestPhone='0000000000';branchId=2;startsAt=$future.ToString('o');endsAt=$end.ToString('o');note=$run;services=@(@{serviceId=$groom.id;providerId=$null;resourceId=$null},@{serviceId=$pickup.id;providerId=$null;resourceId=$null})}
$wrongBranch=@{}+$guest;$wrongBranch.branchId=13
Check wrong-branch (Call-Booking POST bookings $wrongBranch) @(403)
Check missing-resource (Call-Booking POST bookings @{memberId=$null;guestName=$run;branchId=2;startsAt=$future.ToString('o');endsAt=$end.ToString('o');services=@(@{serviceId=$court.id;providerId=$null;resourceId=$null})}) @(400)
Check invalid-service (Call-Booking POST bookings @{memberId=$null;guestName=$run;branchId=2;startsAt=$future.ToString('o');endsAt=$end.ToString('o');services=@(@{serviceId=999999;providerId=$null;resourceId=$null})}) @(400)
$past=@{}+$guest;$past.startsAt=$now.AddDays(-1).ToString('o');$past.endsAt=$now.AddDays(-1).AddHours(1).ToString('o')
Check reject-past (Call-Booking POST bookings $past) @(400)
$created=Call-Booking POST bookings $guest;Check create-guest-two-services $created @(201)
if([decimal]$created.data.totalAmount -ne 450){throw 'Guest total must be 450'}
$guestId=[long]$created.data.id
 $detail=Call-Booking GET "bookings/${guestId}?menu=61008";Check booking-detail $detail @(200)
 if($detail.data.lines.Count -ne 2){throw 'Booking detail must have two service lines'}
 Check use-first-line (Call-Booking POST "bookings/$guestId/lines/$($detail.data.lines[0].id)/use") @(204)
Check use-all (Call-Booking POST "bookings/$guestId/use") @(204)
Check use-repeat-idempotent (Call-Booking POST "bookings/$guestId/use") @(204)
Check cancel-after-use (Call-Booking POST "bookings/$guestId/cancel") @(409)
$memberBooking=@{}+$guest;$memberBooking.memberId=[long]$member.id;$memberBooking.guestName=$null;$memberBooking.guestPhone=$null;$memberBooking.startsAt=$now.AddDays(3).ToString('o');$memberBooking.endsAt=$now.AddDays(3).AddHours(1).ToString('o')
$memberResult=Call-Booking POST bookings $memberBooking;Check member-discount $memberResult @(201)
if([decimal]$memberResult.data.totalAmount -ne 405){throw "Member discounted total should be 405, got $($memberResult.data.totalAmount)"}
Check member-history (Call-Booking GET "members/$($member.id)/history") @(200)
$cancelBooking=@{}+$guest;$cancelBooking.startsAt=$now.AddDays(4).ToString('o');$cancelBooking.endsAt=$now.AddDays(4).AddHours(1).ToString('o')
$cancelCreated=Call-Booking POST bookings $cancelBooking;Check create-to-cancel $cancelCreated @(201)
Check cancel (Call-Booking POST "bookings/$($cancelCreated.data.id)/cancel") @(204)
Check cancel-repeat (Call-Booking POST "bookings/$($cancelCreated.data.id)/cancel") @(409)
$courtBooking=@{}+$guest;$courtBooking.services=@(@{serviceId=$court.id;providerId=$null;resourceId=$resource.id});$courtBooking.startsAt=$now.AddDays(5).ToString('o');$courtBooking.endsAt=$now.AddDays(5).AddHours(2).ToString('o')
$courtCreated=Call-Booking POST bookings $courtBooking;Check court-booking $courtCreated @(201)
Check double-booked-court (Call-Booking POST bookings $courtBooking) @(409)
Check cancel-court-fixture (Call-Booking POST "bookings/$($courtCreated.data.id)/cancel") @(204)
$list=Call-Booking GET "bookings?from=$from&to=$to&menu=61008";Check usage-list $list @(200)
$noShow=($list.data|Where-Object number -eq 'BKSEED261009-NOSHOW'|Select-Object -First 1)
if(-not $noShow){throw 'No-show fixture not found'}
if($noShow.status -eq 'BOOKED'){Check no-show (Call-Booking POST "bookings/$($noShow.id)/no-show") @(204)}
Check no-show-repeat (Call-Booking POST "bookings/$($noShow.id)/no-show") @(409)
Check booking-list (Call-Booking GET "bookings?from=$from&to=$to&menu=61007") @(200)
$paged=Call-Booking GET "bookings?from=$from&to=$to&menu=61007&page=1&pageSize=2"
Check booking-page-1 $paged @(200)
if($paged.data.items.Count -ne 2 -or $paged.data.total -lt 2){throw 'Booking page 1 count mismatch'}
$next=Call-Booking GET "bookings?from=$from&to=$to&menu=61007&page=2&pageSize=2"
Check booking-page-2 $next @(200)
if($next.data.items.Count -ne 2 -or $next.data.items[0].id -eq $paged.data.items[0].id){throw 'Booking page 2 is not distinct'}
Check invalid-booking-page (Call-Booking GET "bookings?from=$from&to=$to&menu=61007&page=0") @(400)
Check dashboard (Call-Booking GET "dashboard?from=$from&to=$to") @(200)
foreach($menu in 61003,61004,61005,61006,61007,61008,61009,61010){Check "options-$menu" (Call-Booking GET "options/$menu") @(200)}
Write-Output "PASS_COUNT=$checks RUN_ID=$run GUEST_BOOKING_ID=$guestId"
