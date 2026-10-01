param(
    [string]$ApiUrl = 'http://localhost:5080',
    [Parameter(Mandatory = $true)][string]$Username,
    [Parameter(Mandatory = $true)][string]$Password
)

$ErrorActionPreference = 'Stop'
$base = $ApiUrl.TrimEnd('/')
$run = 'SURVEY-' + (Get-Date -Format 'yyyyMMdd-HHmmss')

function Send([string]$Method, [string]$Path, $Body = $null, [hashtable]$Headers = @{}) {
    $parameters = @{ Method = $Method; Uri = $base + $Path; Headers = $Headers; UseBasicParsing = $true; TimeoutSec = 30 }
    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json; charset=utf-8'
        $parameters.Body = $Body | ConvertTo-Json -Depth 20 -Compress
    }
    try {
        $response = Invoke-WebRequest @parameters
        $data = if ([string]::IsNullOrWhiteSpace($response.Content)) { $null } else { $response.Content | ConvertFrom-Json }
        return [pscustomobject]@{ Status = [int]$response.StatusCode; Data = $data }
    }
    catch [System.Net.WebException] {
        if (-not $_.Exception.Response) { throw }
        $response = $_.Exception.Response
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $content = $reader.ReadToEnd()
        $reader.Dispose()
        $data = if ([string]::IsNullOrWhiteSpace($content)) { $null } else { $content | ConvertFrom-Json }
        return [pscustomobject]@{ Status = [int]$response.StatusCode; Data = $data }
    }
}

function Expect($Response, [int[]]$Statuses, [string]$Case) {
    if ($Statuses -notcontains $Response.Status) {
        throw "FAIL $Case expected $($Statuses -join '/') got $($Response.Status): $($Response.Data | ConvertTo-Json -Depth 8 -Compress)"
    }
    Write-Output "PASS $Case=$($Response.Status)"
}

$login = Send POST '/api/auth/login' @{ username = $Username; password = $Password; projectCode = 'LAOO_SURVEY' }
Expect $login @(200) 'login'
if (-not $login.Data.success -or [string]::IsNullOrWhiteSpace($login.Data.accessToken)) { throw 'Survey login did not return accessToken.' }
$headers = @{ Authorization = 'Bearer ' + $login.Data.accessToken }

Expect (Send GET '/api/company/surveys/settings' $null $headers) @(200) 'settings-view'
foreach ($menu in 40001..40007) { Expect (Send GET "/api/company/surveys/actions/$menu" $null $headers) @(200) "actions-$menu" }
$options = Send GET '/api/company/surveys/options' $null $headers
Expect $options @(200) 'options'
$employee = $options.Data.employees | Where-Object { $_.isCurrent -eq $true } | Select-Object -First 1
if (-not $employee) { throw 'No active employee is available for Survey target.' }

$open = (Get-Date).ToUniversalTime().AddMinutes(-5).ToString('o')
$close = (Get-Date).ToUniversalTime().AddDays(2).ToString('o')
$invalid = @{ code = "$run-INVALID"; name = 'ทดสอบ Validation'; openAt = $open; closeAt = $close; isAnonymous = $true; showResultAfterClose = $true; approverEmployeeID = [long]$employee.id; questions = @(@{ text = 'เลือก'; type = 'SINGLE'; required = $true; options = @('หนึ่ง') }) }
Expect (Send POST '/api/company/surveys' $invalid $headers) @(400) 'choice-minimum-two'

$document = @{
    code = $run; name = "แบบสอบถามทดสอบ Flow $run"; description = 'ข้อมูลทดสอบอัตโนมัติจากฐานข้อมูลจริง'
    openAt = $open; closeAt = $close; isAnonymous = $true; showResultAfterClose = $true
    approverEmployeeID = [long]$employee.id
    questions = @(
        @{ text = 'เลือกคำตอบเดียว'; type = 'SINGLE'; required = $true; options = @('ดี', 'ควรปรับปรุง') },
        @{ text = 'เลือกได้หลายคำตอบ'; type = 'MULTI'; required = $true; options = @('รวดเร็ว', 'ชัดเจน', 'ใช้งานง่าย') },
        @{ text = 'ให้คะแนน'; type = 'SCALE'; required = $true; minValue = 1; maxValue = 5; options = @() },
        @{ text = 'ข้อเสนอแนะ'; type = 'TEXT'; required = $true; options = @() },
        @{ text = 'ต้องการใช้งานต่อหรือไม่'; type = 'YES_NO'; required = $true; options = @() }
    )
}
$created = Send POST '/api/company/surveys' $document $headers
Expect $created @(200) 'create-header-detail'
$id = [long]$created.Data.id
Expect (Send POST "/api/company/surveys/$id/submit" $null $headers) @(204) 'submit-approval'
$inbox = Send GET '/api/company/surveys/approvals' $null $headers
Expect $inbox @(200) 'approval-inbox'
if (-not ($inbox.Data | Where-Object { [long]$_.id -eq $id })) { throw 'Created survey is missing from approval inbox.' }
Expect (Send POST "/api/company/surveys/approvals/$id" @{ action = 'APPROVE'; reason = $null } $headers) @(204) 'approve'
Expect (Send PUT "/api/company/surveys/$id/targets" @{ mode = 'CUSTOM'; departmentIDs = @(); employeeIDs = @() } $headers) @(400) 'empty-custom-target'
Expect (Send PUT "/api/company/surveys/$id/targets" @{ mode = 'CUSTOM'; departmentIDs = @(); employeeIDs = @([long]$employee.id, [long]$employee.id) } $headers) @(204) 'target-deduplicate'
$published = Send POST "/api/company/surveys/$id/publish" $null $headers
Expect $published @(200) 'publish-freeze'
if ([int]$published.Data.audienceCount -ne 1) { throw "Expected one deduplicated assignment, got $($published.Data.audienceCount)." }

$mine = Send GET '/api/company/surveys/mine' $null $headers
Expect $mine @(200) 'my-surveys'
if (-not ($mine.Data | Where-Object { [long]$_.id -eq $id })) { throw 'Published survey is missing from My Surveys.' }
Expect (Send GET "/api/company/surveys/results/$id" $null $headers) @(404) 'result-hidden-before-close'
$detail = Send GET "/api/company/surveys/mine/$id" $null $headers
Expect $detail @(200) 'my-survey-detail'
$answers = @()
foreach ($question in $detail.Data.questions) {
    $questionOptions = @($detail.Data.options | Where-Object { [long]$_.questionID -eq [long]$question.id })
    switch ($question.type) {
        'SINGLE' { $answers += @{ questionID = [long]$question.id; textValue = $null; numberValue = $null; optionIDs = @([long]$questionOptions[0].id) } }
        'MULTI' { $answers += @{ questionID = [long]$question.id; textValue = $null; numberValue = $null; optionIDs = @([long]$questionOptions[0].id, [long]$questionOptions[1].id) } }
        'SCALE' { $answers += @{ questionID = [long]$question.id; textValue = $null; numberValue = 4; optionIDs = @() } }
        'TEXT' { $answers += @{ questionID = [long]$question.id; textValue = 'ข้อเสนอแนะจาก c111'; numberValue = $null; optionIDs = @() } }
        'YES_NO' { $answers += @{ questionID = [long]$question.id; textValue = 'YES'; numberValue = $null; optionIDs = @() } }
    }
}
Expect (Send POST "/api/company/surveys/mine/$id/responses" @{ answers = $answers } $headers) @(200) 'respond-all-question-types'
Expect (Send POST "/api/company/surveys/mine/$id/responses" @{ answers = $answers } $headers) @(409) 'prevent-duplicate-response'
Expect (Send POST "/api/company/surveys/$id/resend" $null $headers) @(409) 'no-resend-after-all-responded'
Expect (Send POST "/api/company/surveys/$id/close" $null $headers) @(204) 'close'
$result = Send GET "/api/company/surveys/results/$id" $null $headers
Expect $result @(200) 'aggregate-result'
$resultText = $result.Data | ConvertTo-Json -Depth 12 -Compress
if ($resultText -match 'FullName|EmployeeName|Username|c111') { throw 'Anonymous result exposed an individual identity.' }
Expect (Send GET '/api/company/surveys/reports' $null $headers) @(200) 'dashboard-report'
Expect (Send PUT "/api/company/surveys/$id" $document $headers) @(409) 'protect-closed-structure'
Expect (Send DELETE "/api/company/surveys/$id" $null $headers) @(409) 'protect-closed-delete'
Expect (Send GET "/api/company/surveys/results/$id" $null $headers) @(200) 'closed-detail-preserved'

$draft = Send POST '/api/company/surveys' (@{ code = "$run-DELETE"; name = 'ร่างสำหรับทดสอบลบ'; openAt = $open; closeAt = $close; isAnonymous = $true; showResultAfterClose = $true; approverEmployeeID = [long]$employee.id; questions = @(@{ text = 'คำถาม'; type = 'TEXT'; required = $true; options = @() }) }) $headers
Expect $draft @(200) 'create-delete-draft'
Expect (Send DELETE "/api/company/surveys/$([long]$draft.Data.id)" $null $headers) @(204) 'delete-draft'
Expect (Send GET "/api/company/surveys/$([long]$draft.Data.id)" $null $headers) @(404) 'deleted-not-found'
Expect (Send GET '/api/company/surveys/settings') @(401) 'anonymous-denied'

$foreign = Send POST '/api/auth/login' @{ username = $Username; password = $Password; projectCode = 'LAOO' }
if ($foreign.Status -eq 200 -and $foreign.Data.accessToken) {
    Expect (Send GET '/api/company/surveys/settings' $null @{ Authorization = 'Bearer ' + $foreign.Data.accessToken }) @(403) 'active-project-guard'
}

Write-Output "SURVEY_FLOW_COMPLETE RunID=$run SurveyID=$id"
