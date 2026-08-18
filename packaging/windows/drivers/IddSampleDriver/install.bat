@echo off
setlocal EnableExtensions

REM ============================================================================
REM Instalasi driver display virtual ge9/IddSampleDriver (MIT)
REM https://github.com/ge9/IddSampleDriver
REM
REM Effect: setelah selesai, Windows melihat monitor virtual default
REM   1920x1080 @ 60Hz. Resolusi bisa diedit via option.txt.
REM
REM Prasyarat: installer Inno Setup sudah Elevate ke admin, jadi
REM   pnputil dan certutil dapat menulis ke system store.
REM
REM Return codes:
REM   0 = berhasil
REM   1 = gagal install
REM   2 = driver sudah ada, skip
REM   3 = signing error (coba unattended signing)
REM ============================================================================

set "DRV_DIR=%~dp0"
set "INF_FILE=%DRV_DIR%IddSampleDriver.inf"
set "CER_FILE=%DRV_DIR%ge9-driver.cer"

set "SILENT=0"
if /I "%~1"=="/silent" set "SILENT=1"

echo [XyDesk] Memasang driver display virtual ge9/IddSampleDriver...

REM 1. Pasang sertifikat ke Trusted Root hanya jika belum ada
echo [XyDesk] Langkah 1/3: Memasang sertifikat ke Trusted Root...
certutil -addstore -f "Root" "%CER_FILE%" >nul 2>&1
if errorlevel 1 (
  if "%SILENT%"=="0" (
    echo [XyDesk] Peringatan: sertifikat tidak bisa ditambahkan. Mungkin sudah ada.
  )
)

REM 2. Coba install driver
echo [XyDesk] Langkah 2/3: Mendaftarkan driver...
pnputil /add-driver "%INF_FILE%" /install
set "PNPUTIL_RC=%errorlevel%"

REM 0x00 = success, ada juga kasus "device already installed"
if "%PNPUTIL_RC%"=="0" goto :success
if "%PNPUTIL_RC%"=="259" goto :already_installed

REM 3. Fallback: jika code signing strict, pakai pnputil dengan flag unsigned
echo [XyDesk] Langkah 3/3: Fallback install (unsigned mode)...
pnputil /add-driver "%INF_FILE%" /install /force
if errorlevel 1 (
  echo [XyDesk] GAGAL total. Coba pasang manual di Device Manager.
  exit /b 3
)

:already_installed
echo [XyDesk] Driver sudah terpasang, skip.
exit /b 2

:success
echo [XyDesk] Driver display virtual berhasil dipasang.
echo [XyDesk] Mulai berlaku setelah restart service atau reboot.
exit /b 0
