param([Parameter(Mandatory=$true)][string]$StaffPassword)
$ErrorActionPreference='Stop'
$base='http://127.0.0.1:5080'
$run='BK_20261009_DEMO'
$config=Get-Content (Join-Path $PSScriptRoot '..\..\..\laoo_api\local.json') -Raw|ConvertFrom-Json
$db=New-Object System.Data.SqlClient.SqlConnection($config.ConnectionStrings.LaooDatabase)
function Sql([string]$statement,$values=@{}){
 $cmd=$db.CreateCommand();$cmd.CommandText=$statement
 foreach($key in $values.Keys){$p=$cmd.Parameters.AddWithValue("@$key",$values[$key]);if($null -eq $values[$key]){$p.Value=[DBNull]::Value}}
 return $cmd
}
function Status([scriptblock]$action){
 try{& $action|Out-Null;return 200}catch{
  $response=$_.Exception.Response
  if(-not $response){throw}
  return [int]$response.StatusCode
 }
}
function Expect([string]$name,[int]$actual,[int]$wanted){
 if($actual -ne $wanted){throw "$name expected $wanted got $actual"}
}
$original=$null
try{
 $db.Open()
 $find=Sql "SELECT S.SubscriptionID,S.StatusCode,S.ExpireDate FROM dbo.TDADCompanyProjectSubscription S JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=S.CompanyID JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID WHERE C.CompanyCode=N'DEMO' AND P.ProjectCode=N'LAOO_BOOKING' AND S.IsCurrent=1 AND S.ReasonText=@run" @{run=$run}
 $reader=$find.ExecuteReader()
 if(-not $reader.Read()){throw 'Exact DEMO Booking fixture subscription missing'}
 $original=@{id=$reader.GetInt64(0);status=$reader.GetString(1);expire=$reader.GetDateTime(2)}
 if($reader.Read()){throw 'More than one fixture subscription found'}
 $reader.Close();$find.Dispose()
 if($original.status -notin @('ACTIVE','TRIAL') -or $original.expire -lt [DateTime]::UtcNow.Date){throw 'Fixture is not an active trial; refusing to alter it'}
 $staff=Invoke-RestMethod "$base/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{username='c111';password=$StaffPassword}|ConvertTo-Json)
 $headers=@{Authorization="Bearer $($staff.accessToken)"}
 if(-not $staff.accessToken){throw 'Staff login failed'}
 $members=Invoke-RestMethod "$base/api/company/booking/members?page=1&pageSize=20" -Headers $headers
 $member=$members.items|Where-Object code -eq 'BK26_MEMBER'|Select-Object -First 1
 if(-not $member){throw 'Fixture member missing'}
 $password='B'+[guid]::NewGuid().ToString('N')+'a9!'
 Invoke-RestMethod "$base/api/company/booking/members/$($member.id)/credential" -Method Put -Headers $headers -ContentType 'application/json' -Body (@{newPassword=$password;isActive=$true}|ConvertTo-Json)|Out-Null
 $login=Invoke-RestMethod "$base/api/booking/member/login" -Method Post -ContentType 'application/json' -Body (@{companyCode='DEMO';memberCode='BK26_MEMBER';password=$password}|ConvertTo-Json)
 $memberHeaders=@{Authorization="Bearer $($login.accessToken)"}
 if(-not $login.accessToken){throw 'Member login failed'}
 $changedPassword='C'+[guid]::NewGuid().ToString('N')+'a9!'
 Invoke-RestMethod "$base/api/booking/member/change-password" -Method Post -Headers $memberHeaders -ContentType 'application/json' -Body (@{currentPassword=$password;newPassword=$changedPassword}|ConvertTo-Json)|Out-Null
 $changedLogin=Invoke-RestMethod "$base/api/booking/member/login" -Method Post -ContentType 'application/json' -Body (@{companyCode='DEMO';memberCode='BK26_MEMBER';password=$changedPassword}|ConvertTo-Json)
 $memberHeaders=@{Authorization="Bearer $($changedLogin.accessToken)"}
 if(-not $changedLogin.accessToken -or $changedLogin.mustChangePassword){throw 'Member password change failed'}
 $expire=Sql "UPDATE dbo.TDADCompanyProjectSubscription SET StatusCode=N'EXPIRED' WHERE SubscriptionID=@id AND ReasonText=@run AND IsCurrent=1" @{id=$original.id;run=$run}
 if($expire.ExecuteNonQuery() -ne 1){throw 'Could not set exact fixture to expired'}
 $expire.Dispose()
 $actions=Invoke-RestMethod "$base/api/company/booking/actions/61005" -Headers $headers
 if($actions.actions.view -ne $true -or $actions.actions.edit -ne $false){throw 'Expired menu action flags are wrong'}
 Expect 'expired staff read' (Status {Invoke-RestMethod "$base/api/company/booking/services?page=1" -Headers $headers}) 200
 Expect 'expired member read' (Status {Invoke-RestMethod "$base/api/booking/member/history" -Headers $memberHeaders}) 200
 Expect 'expired staff write' (Status {Invoke-RestMethod "$base/api/company/booking/settings" -Method Put -Headers $headers -ContentType 'application/json' -Body (@{advanceDays=90;cancelBeforeHours=2;noShowGraceMinutes=15}|ConvertTo-Json)}) 403
 Expect 'expired credential write' (Status {Invoke-RestMethod "$base/api/company/booking/members/$($member.id)/credential" -Method Put -Headers $headers -ContentType 'application/json' -Body (@{newPassword=$password;isActive=$true}|ConvertTo-Json)}) 403
 $suspend=Sql "UPDATE dbo.TDADCompanyProjectSubscription SET StatusCode=N'SUSPENDED' WHERE SubscriptionID=@id AND ReasonText=@run AND IsCurrent=1" @{id=$original.id;run=$run}
 if($suspend.ExecuteNonQuery() -ne 1){throw 'Could not suspend exact fixture'}
 $suspend.Dispose()
 Expect 'suspended staff read' (Status {Invoke-RestMethod "$base/api/company/booking/services?page=1" -Headers $headers}) 403
 Expect 'suspended member read' (Status {Invoke-RestMethod "$base/api/booking/member/history" -Headers $memberHeaders}) 403
 Write-Output "BOOKING_EXPIRED_PASS view=200 edit=403 memberHistory=200 suspended=403 run=$run"
}finally{
 if($db.State -eq [System.Data.ConnectionState]::Open -and $null -ne $original){
  $restore=Sql "UPDATE dbo.TDADCompanyProjectSubscription SET StatusCode=@status,ExpireDate=@expire WHERE SubscriptionID=@id AND ReasonText=@run AND IsCurrent=1" @{id=$original.id;run=$run;status=$original.status;expire=$original.expire}
  if($restore.ExecuteNonQuery() -ne 1){throw 'CRITICAL: exact fixture subscription could not be restored'}
  $restore.Dispose()
 }
 $db.Dispose()
}
