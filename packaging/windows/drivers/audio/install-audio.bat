@echo off
setlocal EnableExtensions

REM ============================================================================
REM Instalasi driver Virtual Audio & Virtual Mic (VB-CABLE / Virtual Cable)
REM Memungkinkan audio host ditangkap secara jernih dan microphone client (HP/Web)
REM terbaca sebagai perangkat microphone fisik Windows (CABLE Input -> CABLE Output).
REM
REM Dipanggil otomatis secara silent saat instalasi XyDesk.
REM
REM Return codes:
REM   0 = berhasil dipasang atau sudah terpasang
REM   1 = installer gagal
REM   2 = berkas biner installer tidak ditemukan
REM ============================================================================

set "DRV_DIR=%~dp0"
set "SETUP_X64=%DRV_DIR%VBCABLE_Setup_x64.exe"
set "SETUP_X86=%DRV_DIR%VBCABLE_Setup.exe"

echo [XyDesk] Memeriksa driver Virtual Audio ^& Mic...

REM 1. Cek apakah VB-CABLE sudah terpasang di sistem
if exist "C:\Program Files\VB\CABLE\VBCABLE_Setup_x64.exe" (
  echo [XyDesk] Driver Virtual Audio sudah terpasang, skip.
  exit /b 0
)

REM 2. Jalankan silent installation (-i = install, -h = hide/silent)
if exist "%SETUP_X64%" (
  echo [XyDesk] Memasang driver Virtual Audio x64...
  "%SETUP_X64%" -i -h
  if errorlevel 1 (
    echo [XyDesk] Peringatan: setup driver audio mengembalikan kode non-nol.
    exit /b 1
  )
  echo [XyDesk] Driver Virtual Audio x64 berhasil dipasang.
  exit /b 0
)

if exist "%SETUP_X86%" (
  echo [XyDesk] Memasang driver Virtual Audio x86...
  "%SETUP_X86%" -i -h
  if errorlevel 1 (
    echo [XyDesk] Peringatan: setup driver audio mengembalikan kode non-nol.
    exit /b 1
  )
  echo [XyDesk] Driver Virtual Audio x86 berhasil dipasang.
  exit /b 0
)

echo [XyDesk] Berkas installer audio tidak ditemukan di direktori lokal.
exit /b 2
