$ErrorActionPreference = "Stop"

if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] 'git' is not installed. Please install git." -ForegroundColor Red
    exit 1
}

$MerlinHome = Join-Path $env:USERPROFILE ".merlin"

if (Test-Path $MerlinHome) {
    Write-Host "[UPDATE] Updating existing Merlin installation in $MerlinHome..." -ForegroundColor Cyan
    Set-Location $MerlinHome
    git pull origin main
} else {
    Write-Host "[INSTALL] Cloning Merlin to $MerlinHome..." -ForegroundColor Cyan
    git clone https://github.com/yutila-org/merlin.git $MerlinHome
    Set-Location $MerlinHome
}

Write-Host "[BUILD] Compiling Merlin Engine..." -ForegroundColor Cyan

# Fallback compiler logic
$DC = ""
if (Get-Command "ldc2" -ErrorAction SilentlyContinue) { $DC = "ldc2" }
elseif (Test-Path "C:\D\dmd2\windows\bin\dmd.exe") { $DC = "C:\D\dmd2\windows\bin\dmd.exe" }
elseif (Get-Command "dmd" -ErrorAction SilentlyContinue) { $DC = "dmd" }
elseif (Get-Command "gdc" -ErrorAction SilentlyContinue) { $DC = "gdc" }

if ($DC -eq "") {
    Write-Host "[ERROR] No D compiler found. Please install ldc2 or dmd." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "bin")) { New-Item -ItemType Directory -Path "bin" | Out-Null }

if ($DC -match "gdc") {
    & $DC src\*.d -o bin\merlin.exe
} else {
    & $DC src\*.d -of=bin\merlin.exe
}

$UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$BinPath = Join-Path $MerlinHome "bin"

if ($UserPath -notmatch [regex]::Escape($BinPath)) {
    $NewPath = "$UserPath;$BinPath"
    [Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
    Write-Host "[SUCCESS] Added Merlin to Windows PATH." -ForegroundColor Green
}

Write-Host "[SUCCESS] Merlin Engine successfully initialized!" -ForegroundColor Green
Write-Host "Please restart your PowerShell terminal to wield 'merlin'." -ForegroundColor Cyan
