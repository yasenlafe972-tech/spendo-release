# Spendo GitHub Auto-Sync Engine
param (
    [int]$IntervalSeconds = 10,
    [switch]$Once = $false
)

$ErrorActionPreference = "Continue"

# Locate Git
$gitBin = "git"
if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    if (Test-Path "D:\flutter\bin\mingit\cmd\git.exe") {
        $gitBin = "D:\flutter\bin\mingit\cmd\git.exe"
    }
}

$repoDir = "C:\Users\LAFE9\OneDrive\Desktop\my app"
Set-Location $repoDir

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Spendo GitHub Auto-Sync Service" -ForegroundColor Yellow
Write-Host "  Repository: $repoDir" -ForegroundColor Gray
Write-Host "  Git Binary: $gitBin" -ForegroundColor Gray
Write-Host "  Interval: Every $IntervalSeconds seconds" -ForegroundColor Gray
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Auto-sync is ACTIVE. Edit your code freely; changes will be auto-pushed to GitHub!" -ForegroundColor Green

function Sync-ToGitHub {
    try {
        $status = & $gitBin status --porcelain 2>&1
        $statusStr = ($status -join "`n").Trim()
        if ($statusStr.Length -gt 0) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Host "`n[$timestamp] Detected local changes. Auto-committing and pushing to GitHub..." -ForegroundColor Yellow
            
            & $gitBin add -A
            & $gitBin commit -m "auto-sync: update from PC ($timestamp)"
            
            $pushOut = & $gitBin push origin main 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[$timestamp] Successfully synced to GitHub!" -ForegroundColor Green
            } else {
                Write-Host "[$timestamp] Push warning: $pushOut" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Sync error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($Once) {
    Sync-ToGitHub
    exit 0
}

while ($true) {
    Sync-ToGitHub
    Start-Sleep -Seconds $IntervalSeconds
}
