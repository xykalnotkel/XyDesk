@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================================
REM Pembersihan driver display virtual ge9/IddSampleDriver
REM Effect: menghapus device, INF dari driver store, dan sertifikat.
REM
REM Perbaikan dari versi sebelumnya:
REM   - nama berkas mengikuti zip upstream (huruf kecil)
REM   - `setlocal EnableDelayedExpansion` ditambahkan; loop lama menyetel
REM     INSTANCE_ID lalu membacanya di iterasi yang sama tanpa delayed
REM     expansion, jadi nilainya selalu kosong
REM   - sertifikat dihapus berdasarkan THUMBPRINT, bukan nama tebakan
REM     "ge9 IddSampleDriver" yang tidak cocok dengan subject asli
REM     (CN=WDKTestCert anonymous,132727330555318916)
REM   - hapus juga dari store TrustedPublisher
REM ============================================================================

set "DRV_DIR=%~dp0"
set "INF_FILE=%DRV_DIR%iddsampledriver.inf"

REM SHA-1 thumbprint sertifikat rilis 0.0.1.4. Dipakai untuk penghapusan yang
REM tepat sasaran; kalau upstream mengganti sertifikat, nilai ini ikut berubah.
set "CER_THUMB=26a26e11f7d812826aa9a862568c4d3dfb1da065"

set "SILENT=0"
if /I "%~1"=="/silent" set "SILENT=1"

echo [XyDesk] Membersihkan driver display virtual...

REM 1. Hapus device yang memakai hardware ID Root\IddSampleDriver.
echo [XyDesk] Langkah 1/3: Menghapus device...
for /f "tokens=2 delims=:" %%I in (
  'pnputil /enum-devices /class Display 2^>nul ^| findstr /I "Root\\IddSampleDriver"'
) do (
  set "DEV=%%I"
  set "DEV=!DEV: =!"
  if not "!DEV!"=="" (
    if "%SILENT%"=="0" echo   Menghapus device !DEV!...
    pnputil /remove-device "!DEV!" >nul 2>&1
  )
)

REM 2. Hapus INF dari driver store. Nama oem*.inf perlu dicari dulu karena
REM    /delete-driver memakai nama published, bukan path sumber.
echo [XyDesk] Langkah 2/3: Menghapus INF dari driver store...
for /f "tokens=2 delims=:" %%P in (
  'pnputil /enum-drivers 2^>nul ^| findstr /I /C:"iddsampledriver.inf" /C:"Published Name"'
) do (
  set "OEMINF=%%P"
  set "OEMINF=!OEMINF: =!"
)
if defined OEMINF (
  pnputil /delete-driver "!OEMINF!" /uninstall /force >nul 2>&1
) else (
  pnputil /delete-driver "%INF_FILE%" /uninstall /force >nul 2>&1
)

REM 3. Hapus sertifikat dari kedua store berdasarkan thumbprint.
echo [XyDesk] Langkah 3/3: Menghapus sertifikat...
certutil -delstore "Root" "%CER_THUMB%" >nul 2>&1
certutil -delstore "TrustedPublisher" "%CER_THUMB%" >nul 2>&1

echo [XyDesk] Selesai.
exit /b 0
