@echo off
setlocal EnableExtensions

REM ============================================================================
REM Pembersihan driver display virtual ge9/IddSampleDriver
REM Effect: menghapus device, INF, dan (opsional) sertifikat dari store.
REM ============================================================================

set "DRV_DIR=%~dp0"
set "INF_FILE=%DRV_DIR%IddSampleDriver.inf"
set "CER_FILE=%DRV_DIR%ge9-driver.cer"

set "SILENT=0"
if /I "%~1"=="/silent" set "SILENT=1"

echo [XyDesk] Membersihkan driver display virtual...

REM 1. Hapus semua instance device yang terdaftar
echo [XyDesk] Langkah 1/2: Menghapus device...
pnputil /enum-devices /connected /disconnected /class Display 2>nul | findstr /I "IddSampleDriver" > "%TEMP%\idd_list.txt" 2>nul

REM Cara paling reliable: scan semua device dengan enum
for /f "tokens=*" %%I in ('pnputil /enum-devices /connected /disconnected /class Display 2^>nul ^| findstr /I "IddCx"') do (
  REM Ambil instance ID dari baris yang mengandung "Instance ID"
  for /f "tokens=2 delims=:" %%J in ("%%I") do (
    set "INSTANCE_ID=%%J"
    call :remove_device "%%J"
  )
)

REM 2. Hapus driver INF dari store
echo [XyDesk] Langkah 2/2: Menghapus INF dari driver store...
pnputil /delete-driver "%INF_FILE%" /uninstall /force >nul 2>&1

REM 3. (Opsional) Hapus sertifikat
if exist "%CER_FILE%" (
  certutil -delstore "Root" "ge9 IddSampleDriver" >nul 2>&1
)

echo [XyDesk] Selesai.
exit /b 0

:remove_device
REM %~1 = instance ID
set "DEV=%~1"
set "DEV=%DEV: =%"
if "%DEV%"=="" exit /b 0
if "%SILENT%"=="0" echo Menghapus device %DEV%...
pnputil /remove-device "%DEV%" /force >nul 2>&1
exit /b 0
