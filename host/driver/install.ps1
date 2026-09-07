# XyDesk Virtual Display Driver Installer
# Jalankan sebagai Administrator
# Download driver otomatis dari itsmikethetech/Virtual-Display-Driver

param(
    [string]$DriverUrl = "https://github.com/itsmikethetech/Virtual-Display-Driver/releases/latest/download/Virtual-Display-Driver-Setup-v24.12.24.exe",
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
    Write-Host "Uninstall Virtual Display Driver..." -ForegroundColor Yellow
    $uninstaller = "C:\Program Files\Virtual Display Driver\uninstall.exe"
    if (Test-Path $uninstaller) {
        Start-Process $uninstaller -Wait
        Write-Host "Uninstall selesai" -ForegroundColor Green
    } else {
        Write-Host "Uninstaller tidak ditemukan di $uninstaller" -ForegroundColor Red
    }
    exit 0
}

# Cek apakah driver sudah ada
$driverInf = "C:\Program Files\Virtual Display Driver\VirtualDisplayDriver.inf"
if (Test-Path $driverInf) {
    Write-Host "Virtual Display Driver sudah terinstal di $driverInf" -ForegroundColor Green
    Write-Host "Cek Device Manager -> Display adapters -> Virtual Display Driver" -ForegroundColor Cyan
    exit 0
}

# Download installer
$tempFile = "$env:TEMP\Virtual-Display-Driver-Setup.exe"
Write-Host "Download driver dari $DriverUrl ..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $DriverUrl -OutFile $tempFile -UseBasicParsing
    Write-Host "Download selesai: $tempFile" -ForegroundColor Green
} catch {
    Write-Host "Download gagal: $_" -ForegroundColor Red
    Write-Host "Download manual dari https://github.com/itsmikethetech/Virtual-Display-Driver/releases" -ForegroundColor Yellow
    exit 1
}

# Install
Write-Host "Install driver (butuh reboot mungkin)..." -ForegroundColor Cyan
Start-Process $tempFile -ArgumentList "/S" -Wait
Write-Host "Install selesai. Restart XyDesk Host." -ForegroundColor Green
Write-Host "Kalau masih hitam, jalankan: tscon %SESSIONNAME% /dest:console" -ForegroundColor Yellow
