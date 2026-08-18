@echo off
setlocal EnableExtensions

REM ============================================================================
REM Instalasi driver display virtual ge9/IddSampleDriver (MIT)
REM https://github.com/ge9/IddSampleDriver
REM
REM Effect: setelah selesai, Windows melihat monitor virtual default
REM   1920x1080 @ 60Hz. Resolusi bisa diedit via option.txt.
REM
REM CATATAN NAMA BERKAS: rilis upstream 0.0.1.4 memaketkan berkas dengan nama
REM   huruf kecil (iddsampledriver.inf / .cer). Skrip ini memakai nama persis
REM   seperti di dalam zip. Sebelumnya skrip mencari "ge9-driver.cer" yang
REM   TIDAK PERNAH ADA, sehingga sertifikat tidak pernah terpasang dan
REM   pnputil selalu gagal memvalidasi tanda tangan.
REM
REM CATATAN ARSITEKTUR: INF upstream hanya mendeklarasikan [Standard.NTamd64].
REM   Pada Windows on Arm driver ini TIDAK didukung — installer sudah tidak
REM   menawarkannya, tapi cek di sini jadi jaring pengaman kalau dijalankan
REM   manual.
REM
REM Return codes:
REM   0 = berhasil
REM   1 = gagal install
REM   2 = driver sudah ada, skip
REM   3 = signing error
REM   4 = arsitektur tidak didukung
REM   5 = berkas driver tidak lengkap
REM ============================================================================

set "DRV_DIR=%~dp0"
set "INF_FILE=%DRV_DIR%iddsampledriver.inf"
set "CER_FILE=%DRV_DIR%iddsampledriver.cer"

set "SILENT=0"
if /I "%~1"=="/silent" set "SILENT=1"

echo [XyDesk] Memasang driver display virtual ge9/IddSampleDriver...

REM 0a. Driver ini x64-only (INF: Standard.NTamd64).
if /I not "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
  if /I not "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
    echo [XyDesk] Arsitektur %PROCESSOR_ARCHITECTURE% tidak didukung driver ini.
    exit /b 4
  )
)

REM 0b. Pastikan berkas benar-benar ada sebelum menyentuh certificate store.
if not exist "%INF_FILE%" (
  echo [XyDesk] GAGAL: %INF_FILE% tidak ditemukan.
  exit /b 5
)
if not exist "%CER_FILE%" (
  echo [XyDesk] GAGAL: %CER_FILE% tidak ditemukan.
  exit /b 5
)

REM 1. Pasang sertifikat penanda tangan driver.
REM    Butuh DUA store: Root (rantai kepercayaan) dan TrustedPublisher
REM    (agar Windows tidak menampilkan dialog konfirmasi driver).
REM    Ini mengikuti installCert.bat upstream.
echo [XyDesk] Langkah 1/3: Memasang sertifikat penanda tangan driver...
certutil -addstore -f "Root" "%CER_FILE%" >nul 2>&1
if errorlevel 1 (
  echo [XyDesk] GAGAL memasang sertifikat ke Root store.
  exit /b 3
)
certutil -addstore -f "TrustedPublisher" "%CER_FILE%" >nul 2>&1
if errorlevel 1 (
  echo [XyDesk] GAGAL memasang sertifikat ke TrustedPublisher store.
  exit /b 3
)

REM 2. Daftarkan driver ke driver store.
echo [XyDesk] Langkah 2/3: Mendaftarkan driver...
pnputil /add-driver "%INF_FILE%" /install
set "PNPUTIL_RC=%errorlevel%"

if "%PNPUTIL_RC%"=="0" goto :success
REM 259 (ERROR_NO_MORE_ITEMS) = tidak ada device baru, driver sudah ada.
if "%PNPUTIL_RC%"=="259" goto :already_installed
REM 3010 = sukses tapi perlu reboot.
if "%PNPUTIL_RC%"=="3010" goto :success

REM 3. Fallback sekali lagi. CATATAN: /force BUKAN opsi valid untuk
REM    /add-driver (itu milik /delete-driver), jadi kita ulang tanpa /install
REM    lalu biarkan Windows memasang saat device muncul.
echo [XyDesk] Langkah 3/3: Percobaan ulang pendaftaran driver...
pnputil /add-driver "%INF_FILE%"
if errorlevel 1 (
  echo [XyDesk] GAGAL total ^(kode %PNPUTIL_RC%^). Pasang manual via Device Manager.
  exit /b 1
)

:success
echo [XyDesk] Driver display virtual berhasil dipasang.
echo [XyDesk] Mulai berlaku setelah restart service atau reboot.
exit /b 0

:already_installed
echo [XyDesk] Driver sudah terpasang, skip.
exit /b 2
