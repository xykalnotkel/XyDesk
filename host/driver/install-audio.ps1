# XyDesk Virtual Mic & Audio Driver Installer (VB-CABLE)
# Biar mic client (HP → PC) kebaca sebagai mic input di Windows dan denyut di Control Panel
# Jalankan sebagai Administrator — memprioritaskan driver bawaan/offline

param(
    [string]$DriverUrl = "https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack45.zip",
    [switch]$Uninstall
)

function Test-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Harus jalan sebagai Administrator! Klik kanan PowerShell -> Run as Administrator" -ForegroundColor Red
    exit 1
}

if ($Uninstall) {
    Write-Host "Uninstall VB-CABLE..." -ForegroundColor Yellow
    $localUninstall = Join-Path $PSScriptRoot "..\..\packaging\windows\drivers\audio\uninstall-audio.bat"
    if (Test-Path $localUninstall) {
        & cmd.exe /c $localUninstall
        Write-Host "Uninstall selesai via batch script lokal" -ForegroundColor Green
        exit 0
    }
    $uninstaller = "C:\Program Files\VB\CABLE\VBCABLE_Setup_x64.exe"
    if (Test-Path $uninstaller) {
        Start-Process $uninstaller -ArgumentList "-u -h" -Wait
        Write-Host "Uninstall selesai, reboot disarankan" -ForegroundColor Green
    } else {
        Write-Host "Uninstaller tidak ditemukan, cek Device Manager -> Audio inputs and outputs" -ForegroundColor Red
    }
    exit 0
}

# Cek sudah ada
$hasCable = Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -like "*CABLE*" }
if ($hasCable) {
    Write-Host "VB-CABLE sudah terinstal:" -ForegroundColor Green
    $hasCable | Format-Table FriendlyName, InstanceId, Status
    Write-Host "Di XyDesk Host -> Beranda -> Virtual Mic akan installed=true" -ForegroundColor Cyan
    Write-Host "Render target akan otomatis CABLE Input → denyut di CABLE Output (Recording)" -ForegroundColor Cyan
    exit 0
}

# Cek apakah ada driver lokal bawaan (offline bundling)
$localBat = Join-Path $PSScriptRoot "..\..\packaging\windows\drivers\audio\install-audio.bat"
if (Test-Path $localBat) {
    Write-Host "Memasang driver audio bawaan lokal..." -ForegroundColor Cyan
    & cmd.exe /c $localBat
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Driver audio bawaan lokal berhasil dipasang." -ForegroundColor Green
        exit 0
    }
}

# Fallback download online
$tempZip = "$env:TEMP\VBCABLE_Driver_Pack45.zip"
$tempDir = "$env:TEMP\VBCABLE"
Write-Host "Download VB-CABLE dari $DriverUrl ..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $DriverUrl -OutFile $tempZip -UseBasicParsing
    Write-Host "Download selesai: $tempZip" -ForegroundColor Green
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
    Write-Host "Extract ke $tempDir" -ForegroundColor Green
    $setup = Get-ChildItem -Path $tempDir -Recurse -Filter "VBCABLE_Setup_x64.exe" | Select-Object -First 1
    if (-not $setup) { $setup = Get-ChildItem -Path $tempDir -Recurse -Filter "VBCABLE_Setup.exe" | Select-Object -First 1 }
    if ($setup) {
        Write-Host "Install $($setup.FullName) ..." -ForegroundColor Cyan
        Start-Process $setup.FullName -ArgumentList "-i -h" -Wait
        Write-Host "Install selesai. Reboot disarankan, lalu restart XyDesk." -ForegroundColor Green
        Write-Host "Setelah reboot: Control Panel -> Sound -> Recording -> CABLE Output akan denyut kalau ada suara" -ForegroundColor Yellow
        Write-Host "Di Discord/Zoom/Game: pilih mic = CABLE Output" -ForegroundColor Yellow
    } else {
        Write-Host "Setup exe tidak ditemukan di $tempDir" -ForegroundColor Red
        Get-ChildItem $tempDir -Recurse | Format-Table Name
    }
} catch {
    Write-Host "Gagal: $_" -ForegroundColor Red
    Write-Host "Download manual dari https://vb-audio.com/Cable/ lalu Run as Admin VBCABLE_Setup_x64.exe" -ForegroundColor Yellow
}
