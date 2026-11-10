$ErrorActionPreference = 'Stop'
$workspace = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$runtime = Join-Path $workspace 'local-ai\ollama\ollama.exe'
$models = Join-Path $workspace 'local-ai\models'
if (-not (Test-Path -LiteralPath $runtime)) { throw 'Local Ollama runtime is not installed.' }
$env:OLLAMA_HOST = '127.0.0.1:11434'
$env:OLLAMA_NO_CLOUD = '1'
$env:OLLAMA_MODELS = $models
try {
    Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2 | Out-Null
    Write-Output 'A local service already responds on port 11434; its configuration was not changed.'
} catch {
    Start-Process -FilePath $runtime -ArgumentList 'serve' -WindowStyle Hidden
    Write-Output 'Started local Ollama on 127.0.0.1:11434 with cloud features disabled.'
}
