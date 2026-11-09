# Soulbound Release Export Script (PowerShell)
# Builds Windows Desktop and Web distributions using Godot 4.7.2 Stable headless CLI.

param (
    [string]$GodotPath = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [switch]$SkipZip = $false
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $ProjectRoot

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   Soulbound Automated Release Exporter   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Locate Godot
if (-not (Test-Path $GodotPath)) {
    $GodotCommand = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($GodotCommand) {
        $GodotPath = $GodotCommand.Source
    } else {
        throw "Godot console executable not found at '$GodotPath' and not in system PATH."
    }
}

Write-Host "Using Godot executable: $GodotPath" -ForegroundColor Green

# Prepare directories
$WebDir = Join-Path $ProjectRoot "builds\web"
$WindowsDir = Join-Path $ProjectRoot "builds\windows"
$DistDir = Join-Path $ProjectRoot "dist"

foreach ($dir in @($WebDir, $WindowsDir, $DistDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $gdignore = Join-Path $dir ".gdignore"
    if (-not (Test-Path $gdignore)) {
        New-Item -ItemType File -Path $gdignore -Force | Out-Null
    }
}

# 1. Export Web Build
Write-Host "`n[1/3] Exporting Web Release (single-threaded, Compatibility)..." -ForegroundColor Yellow
$WebOutput = Join-Path $WebDir "index.html"
$WebArgs = @(
    "--headless",
    "--path", $ProjectRoot.Path,
    "--export-release", "Web",
    "builds/web/index.html"
)
& $GodotPath @WebArgs
if ($LASTEXITCODE -ne 0) {
    throw "Web export failed with exit code $LASTEXITCODE"
}
Write-Host "Web export successful." -ForegroundColor Green

# 2. Export Windows Desktop Build
Write-Host "`n[2/3] Exporting Windows Desktop Release..." -ForegroundColor Yellow
$WindowsOutput = Join-Path $WindowsDir "Soulbound.exe"
$WinArgs = @(
    "--headless",
    "--path", $ProjectRoot.Path,
    "--export-release", "Windows Desktop",
    "builds/windows/Soulbound.exe"
)
& $GodotPath @WinArgs
if ($LASTEXITCODE -ne 0) {
    throw "Windows Desktop export failed with exit code $LASTEXITCODE"
}
Write-Host "Windows Desktop export successful." -ForegroundColor Green

# 3. Create Distribution Archives
if (-not $SkipZip) {
    Write-Host "`n[3/4] Packaging distribution archives..." -ForegroundColor Yellow
    
    $WebZip = Join-Path $DistDir "Soulbound-Web.zip"
    $WinZip = Join-Path $DistDir "Soulbound-Windows-Portable.zip"
    
    if (Test-Path $WebZip) { Remove-Item $WebZip -Force }
    if (Test-Path $WinZip) { Remove-Item $WinZip -Force }
    
    # Remove any stray .import files in builds directory before archiving
    Get-ChildItem -Path $WebDir, $WindowsDir -Filter "*.import" -File -Recurse | Remove-Item -Force
    
    $webFiles = Get-ChildItem -Path $WebDir -File | Where-Object { $_.Name -ne ".gdignore" } | Select-Object -ExpandProperty FullName
    Compress-Archive -Path $webFiles -DestinationPath $WebZip -CompressionLevel Optimal
    Write-Host "Created Web package: $WebZip" -ForegroundColor Green
    
    $winFiles = Get-ChildItem -Path $WindowsDir -File | Where-Object { $_.Name -ne ".gdignore" } | Select-Object -ExpandProperty FullName
    Compress-Archive -Path $winFiles -DestinationPath $WinZip -CompressionLevel Optimal
    Write-Host "Created Windows package: $WinZip" -ForegroundColor Green
}

# 4. Validate Release Artifacts
if (-not $SkipZip) {
    Write-Host "`n[4/4] Validating release artifacts..." -ForegroundColor Yellow
    $ValidateScript = Join-Path $PSScriptRoot "validate_release.ps1"
    & $ValidateScript -DistDir $DistDir
    if ($LASTEXITCODE -ne 0) {
        throw "Release validation failed with exit code $LASTEXITCODE"
    }
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "            Artifact Summary            " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Get-ChildItem -Path $DistDir, $WebDir, $WindowsDir -File | Format-Table -Property Name, Length, LastWriteTime

Write-Host "`nExport build process completed successfully." -ForegroundColor Green
