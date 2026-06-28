$ErrorActionPreference = "Stop"

param (
    [string]$Version = ""
)

if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] 'git' is not installed." -ForegroundColor Red
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
}

if (-not (Test-Path "$MerlinHome\bin")) { New-Item -ItemType Directory -Path "$MerlinHome\bin" | Out-Null }

if ($Version -ne "") {
    $tag = $Version
} else {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/yutila-org/merlin/releases/latest" -ErrorAction Stop
        $tag = $release.tag_name
    } catch {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/yutila-org/merlin/releases"
        if ($releases.Count -gt 0) {
            $tag = $releases[0].tag_name
        } else {
            Write-Host "[ERROR] Could not determine the latest Merlin release." -ForegroundColor Red
            exit 1
        }
    }
}


Write-Host "[DOWNLOAD] Fetching system-specific binary for Merlin (windows-amd64) from release $tag..." -ForegroundColor Cyan
$URL = "https://github.com/yutila-org/merlin/releases/download/$tag/merlin-windows-amd64.exe"
Invoke-WebRequest -Uri $URL -OutFile "$MerlinHome\bin\merlin.exe"

[Environment]::SetEnvironmentVariable("MERLIN_HOME", $MerlinHome, "User")
$UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$BinPath = Join-Path $MerlinHome "bin"

if ($UserPath -notmatch [regex]::Escape($BinPath)) {
    $NewPath = "$UserPath;$BinPath"
    [Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
}

Write-Host "[SUCCESS] Merlin Engine successfully installed to $MerlinHome!" -ForegroundColor Green
