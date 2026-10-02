param([string]$ApiUrl='http://localhost:5080',[Parameter(Mandatory=$true)][string]$Username,[Parameter(Mandatory=$true)][string]$Password)
$ErrorActionPreference='Stop';$base=$ApiUrl.TrimEnd('/');$run='KN-API-'+(Get-Date -Format 'yyyyMMdd-HHmmss')
function Send([string]$Method,[string]$Path,$Body=$null,[hashtable]$Headers=@{}){
 $p=@{Method=$Method;Uri=$base+$Path;Headers=$Headers;UseBasicParsing=$true;TimeoutSec=30}
 if($null-ne$Body){$p.ContentType='application/json; charset=utf-8';$p.Body=$Body|ConvertTo-Json -Depth 20 -Compress}
 try{$r=Invoke-WebRequest @p;$d=if([string]::IsNullOrWhiteSpace($r.Content)){$null}else{$r.Content|ConvertFrom-Json};return [pscustomobject]@{Status=[int]$r.StatusCode;Data=$d}}
 catch [System.Net.WebException]{if(-not $_.Exception.Response){throw};$r=$_.Exception.Response;$reader=New-Object IO.StreamReader($r.GetResponseStream());$content=$reader.ReadToEnd();$reader.Dispose();$d=if([string]::IsNullOrWhiteSpace($content)){$null}else{$content|ConvertFrom-Json};return [pscustomobject]@{Status=[int]$r.StatusCode;Data=$d}}
}
function Expect($Response,[int[]]$Statuses,[string]$Case){if($Statuses-notcontains$Response.Status){throw "FAIL $Case expected $($Statuses-join'/') got $($Response.Status): $($Response.Data|ConvertTo-Json -Depth 8 -Compress)"};Write-Output "PASS $Case=$($Response.Status)"}
$login=Send POST '/api/auth/login' @{username=$Username;password=$Password;projectCode='LAOO'};Expect $login @(200) 'center-login'
if(-not $login.Data.success-or[string]::IsNullOrWhiteSpace($login.Data.accessToken)){throw 'Login token missing'}
$h=@{Authorization='Bearer '+$login.Data.accessToken}
foreach($menu in 49001..49008){Expect (Send GET "/api/company/knowledge/actions/$menu" $null $h) @(200) "actions-$menu"}
Expect (Send GET '/api/company/knowledge/settings' $null $h) @(200) 'settings'
Expect (Send GET '/api/company/knowledge/options' $null $h) @(200) 'options'
$taxonomy=Send GET '/api/company/knowledge/taxonomy' $null $h;Expect $taxonomy @(200) 'taxonomy';$category=[long]($taxonomy.Data|Select-Object -First 1).id
$invalid=Send POST '/api/company/knowledge/articles' @{categoryId=$category;title='';contentType='ARTICLE';audienceMode='ALL'} $h;Expect $invalid @(400) 'article-validation'
$body=@{categoryId=$category;code=$run;title="ทดสอบ Flow $run";summary='ข้อมูลทดสอบ API';contentType='ARTICLE';body='เนื้อหาทดสอบครบ Flow';reviewerUserId=$null;audienceMode='ALL';departmentIds=@();userIds=@();nextReviewDate=(Get-Date).AddMonths(12).ToString('yyyy-MM-dd')}
$article=Send POST '/api/company/knowledge/articles' $body $h;Expect $article @(200) 'article-create';$articleId=[long]$article.Data.id
Expect (Send POST "/api/company/knowledge/articles/$articleId/submit" $null $h) @(204) 'article-submit'
$reviews=Send GET '/api/company/knowledge/reviews' $null $h;Expect $reviews @(200) 'review-inbox';if(-not($reviews.Data|Where-Object{[long]$_.id-eq$articleId})){throw 'Article missing from review inbox'}
Expect (Send POST "/api/company/knowledge/reviews/$articleId/publish" @{note='ตรวจทานผ่าน'} $h) @(204) 'article-publish'
$library=Send GET ("/api/company/knowledge/library?search="+[uri]::EscapeDataString($run)) $null $h;Expect $library @(200) 'library-search';$libraryItems=if($library.Data.items){@($library.Data.items)}else{@($library.Data)};if(-not($libraryItems|Where-Object{[long]$_.id-eq$articleId})){throw 'Published article missing from library'}
Expect (Send PUT "/api/company/knowledge/articles/$articleId/feedback" @{isHelpful=$true;comment='มีประโยชน์'} $h) @(204) 'feedback'
Expect (Send PUT "/api/company/knowledge/articles/$articleId/follow" @{follow=$true} $h) @(204) 'follow'
$q=Send POST '/api/company/knowledge/questions' @{categoryId=$category;title="คำถาม $run";question='ทดสอบถามผู้เชี่ยวชาญ'} $h;Expect $q @(200) 'question-create';$qid=[long]$q.Data.id
$a=Send POST "/api/company/knowledge/questions/$qid/answers" @{answer='คำตอบที่ตรวจสอบแล้ว'} $h;Expect $a @(200) 'answer-create';$aid=[long]$a.Data.id
Expect (Send POST "/api/company/knowledge/questions/$qid/accept/$aid" $null $h) @(204) 'answer-accept'
$converted=Send POST "/api/company/knowledge/questions/$qid/convert" @{title="บทความจากคำถาม $run"} $h;Expect $converted @(200) 'answer-convert-draft'
Expect (Send GET '/api/company/knowledge/questions' $null $h) @(200) 'questions-list'
Expect (Send GET '/api/company/knowledge/mine' $null $h) @(200) 'mine'
Expect (Send GET '/api/company/knowledge/reports' $null $h) @(200) 'reports'
Write-Output "KNOWLEDGE_FLOW_OK run=$run article=$articleId question=$qid converted=$($converted.Data.id)"
# End of script.
