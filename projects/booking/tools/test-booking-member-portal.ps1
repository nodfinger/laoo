param([Parameter(Mandatory=$true)][string]$StaffPassword)
$ErrorActionPreference='Stop'
$base='http://127.0.0.1:5080'
$staff=Invoke-RestMethod "$base/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{username='c111';password=$StaffPassword}|ConvertTo-Json)
if(-not $staff.accessToken){throw 'Staff login failed'}
$staffHeaders=@{Authorization="Bearer $($staff.accessToken)"}
$members=Invoke-RestMethod "$base/api/company/booking/members?page=1&pageSize=20" -Headers $staffHeaders
$member=$members.items|Where-Object code -eq 'BK26_MEMBER'|Select-Object -First 1
if(-not $member){throw 'Booking fixture member missing'}
$password='B'+[guid]::NewGuid().ToString('N')+'a9!'
$nextPassword='C'+[guid]::NewGuid().ToString('N')+'a9!'
function Code([scriptblock]$call){
 try{& $call|Out-Null;return 200}catch{
  $response=$_.Exception.Response
  if(-not $response){throw}
  return [int]$response.StatusCode
 }
}
$set=Invoke-RestMethod "$base/api/company/booking/members/$($member.id)/credential" -Method Put -Headers $staffHeaders -ContentType 'application/json' -Body (@{newPassword=$password;isActive=$true}|ConvertTo-Json)
if(-not $set.saved){throw 'Credential setup failed'}
$bad=Code {Invoke-RestMethod "$base/api/booking/member/login" -Method Post -ContentType 'application/json' -Body (@{companyCode='DEMO';memberCode='BK26_MEMBER';password='wrong'}|ConvertTo-Json)}
if($bad -ne 401){throw "Wrong password status: $bad"}
$wrongCompany=Code {Invoke-RestMethod "$base/api/booking/member/login" -Method Post -ContentType 'application/json' -Body (@{companyCode='OTHER';memberCode='BK26_MEMBER';password=$password}|ConvertTo-Json)}
if($wrongCompany -ne 401){throw "Cross-company login status: $wrongCompany"}
$wrongMember=Code {Invoke-RestMethod "$base/api/company/booking/members/999999999/credential" -Method Put -Headers $staffHeaders -ContentType 'application/json' -Body (@{newPassword=$password;isActive=$true}|ConvertTo-Json)}
if($wrongMember -ne 404){throw "Cross-company credential status: $wrongMember"}
$login=Invoke-RestMethod "$base/api/booking/member/login" -Method Post -ContentType 'application/json' -Body (@{companyCode='DEMO';memberCode='BK26_MEMBER';password=$password}|ConvertTo-Json)
if(-not $login.accessToken -or -not $login.mustChangePassword){throw 'Member login missing token/change flag'}
$memberHeaders=@{Authorization="Bearer $($login.accessToken)"}
$me=Invoke-RestMethod "$base/api/booking/member/me" -Headers $memberHeaders
if($me.id -ne $member.id -or $me.code -ne 'BK26_MEMBER'){throw 'Member scope mismatch'}
$beforeChange=Code {Invoke-RestMethod "$base/api/booking/member/history?page=1&pageSize=20" -Headers $memberHeaders}
if($beforeChange -ne 403){throw "Initial password did not protect history: $beforeChange"}
$staffAsMember=Code {Invoke-RestMethod "$base/api/booking/member/me" -Headers $staffHeaders}
if($staffAsMember -ne 403){throw "Staff member portal isolation failed: $staffAsMember"}
$memberAsStaff=Code {Invoke-RestMethod "$base/api/company/booking/actions/61005" -Headers $memberHeaders}
if($memberAsStaff -ne 403){throw "Member staff access failed: $memberAsStaff"}
$anonymous=Code {Invoke-RestMethod "$base/api/booking/member/history"}
if($anonymous -ne 401){throw "Anonymous access failed: $anonymous"}
$changed=Invoke-RestMethod "$base/api/booking/member/change-password" -Method Post -Headers $memberHeaders -ContentType 'application/json' -Body (@{currentPassword=$password;newPassword=$nextPassword}|ConvertTo-Json)
if(-not $changed.reauthenticate){throw 'Password change failed'}
$old=Code {Invoke-RestMethod "$base/api/booking/member/me" -Headers $memberHeaders}
if($old -ne 403){throw "Old token not revoked: $old"}
$login2=Invoke-RestMethod "$base/api/booking/member/login" -Method Post -ContentType 'application/json' -Body (@{companyCode='DEMO';memberCode='BK26_MEMBER';password=$nextPassword}|ConvertTo-Json)
if(-not $login2.accessToken -or $login2.mustChangePassword){throw 'Updated password login failed'}
$memberHeaders2=@{Authorization="Bearer $($login2.accessToken)"}
$history=Invoke-RestMethod "$base/api/booking/member/history?page=1&pageSize=20" -Headers $memberHeaders2
if($history.total -lt 1){throw 'Member history missing'}
$invalidPage=Code {Invoke-RestMethod "$base/api/booking/member/history?page=0" -Headers $memberHeaders2}
if($invalidPage -ne 400){throw "Invalid pagination failed: $invalidPage"}
Write-Output "BOOKING_MEMBER_PASS login=200 me=200 history=$($history.total) initialHistory=403 wrong=401 crossCompany=401 missingMember=404 employee=403 memberStaff=403 anonymous=401 pagination=400 revoke=403"
