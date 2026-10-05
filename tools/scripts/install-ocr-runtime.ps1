param(
    [string]$TargetDirectory = (Join-Path $PSScriptRoot '..\..\laoo_api\App_Data\tessdata')
)

$ErrorActionPreference = 'Stop'
$models = @(
    @{
        Name = 'tha.traineddata'
        Uri = 'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/tha.traineddata'
        Sha256 = '294227CC2D1292B0ACB28D61D4115C88252B96D466CA90B417CF4CF0C67BF07C'
    },
    @{
        Name = 'eng.traineddata'
        Uri = 'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/eng.traineddata'
        Sha256 = '7D4322BD2A7749724879683FC3912CB542F19906C83BCC1A52132556427170B2'
    }
)

$resolvedTarget = [System.IO.Path]::GetFullPath($TargetDirectory)
[System.IO.Directory]::CreateDirectory($resolvedTarget) | Out-Null

foreach ($model in $models) {
    $destination = Join-Path $resolvedTarget $model.Name
    $valid = (Test-Path -LiteralPath $destination) -and
        ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -eq $model.Sha256)
    if (-not $valid) {
        $temporary = Join-Path $resolvedTarget ($model.Name + '.download')
        Invoke-WebRequest -UseBasicParsing -Uri $model.Uri -OutFile $temporary
        $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash
        if ($actual -ne $model.Sha256) {
            Remove-Item -LiteralPath $temporary -Force
            throw "OCR model checksum mismatch: $($model.Name)"
        }
        Move-Item -LiteralPath $temporary -Destination $destination -Force
    }
    Write-Host "READY $($model.Name)"
}
