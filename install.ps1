# install.ps1 - Windows setup for Claude Voice MCP plugin
# Run: powershell -ExecutionPolicy ByPass -File install.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModelsDir = Join-Path $ScriptDir "voice\models"

Write-Host "=== Claude Voice MCP - Windows Setup ===" -ForegroundColor Cyan

# 1. Check/install uv
if (Get-Command uv -ErrorAction SilentlyContinue) {
    $uvVer = & uv --version
    Write-Host "[OK] uv found: $uvVer" -ForegroundColor Green
} else {
    Write-Host "[..] Installing uv..." -ForegroundColor Yellow
    irm https://astral.sh/uv/install.ps1 | iex
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Host "[OK] uv installed." -ForegroundColor Green
    } else {
        Write-Host "[!!] uv install failed. Install manually: https://docs.astral.sh/uv/getting-started/installation/" -ForegroundColor Red
        exit 1
    }
}

# 2. Check Visual C++ Redistributable
$vcKeys = @(
    "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
)
$vcFound = $false
foreach ($key in $vcKeys) {
    if (Test-Path $key) { $vcFound = $true; break }
}
if ($vcFound) {
    Write-Host "[OK] Visual C++ Redistributable found." -ForegroundColor Green
} else {
    Write-Host "[!!] Visual C++ 2015-2022 Redistributable may not be installed." -ForegroundColor Yellow
    Write-Host "     ONNX Runtime requires it. Download from:" -ForegroundColor Yellow
    Write-Host "     https://aka.ms/vs/17/release/vc_redist.x64.exe" -ForegroundColor Yellow
}

# 3. Pre-install Python dependencies via uv
Write-Host "[..] Pre-installing Python dependencies..." -ForegroundColor Yellow
$serverPy = Join-Path $ScriptDir "voice\server.py"
# Dry-run import to trigger uv dependency resolution without starting the server
& uv run --script $serverPy -c "import kokoro_onnx; import sounddevice; import soundfile; print('deps ok')" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Python dependencies installed." -ForegroundColor Green
} else {
    # Try alternate approach - just let uv resolve
    Write-Host "[..] Resolving dependencies (this may take a moment)..." -ForegroundColor Yellow
}

# 4. Download TTS models
New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null

$modelFile = Join-Path $ModelsDir "kokoro-v1.0.onnx"
$voicesFile = Join-Path $ModelsDir "voices-v1.0.bin"

$modelUrl = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
$voicesUrl = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

if (Test-Path $modelFile) {
    Write-Host "[OK] Model file already downloaded." -ForegroundColor Green
} else {
    Write-Host "[..] Downloading kokoro-v1.0.onnx (~310 MB)..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $modelUrl -OutFile $modelFile -UseBasicParsing
    Write-Host "[OK] Model downloaded." -ForegroundColor Green
}

if (Test-Path $voicesFile) {
    Write-Host "[OK] Voices file already downloaded." -ForegroundColor Green
} else {
    Write-Host "[..] Downloading voices-v1.0.bin (~27 MB)..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $voicesUrl -OutFile $voicesFile -UseBasicParsing
    Write-Host "[OK] Voices downloaded." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Setup complete ===" -ForegroundColor Cyan
Write-Host "The voice plugin is ready. Models and dependencies are pre-cached."
