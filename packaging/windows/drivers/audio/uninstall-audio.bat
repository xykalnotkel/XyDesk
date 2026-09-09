@echo off
setlocal EnableExtensions

REM ============================================================================
REM Pembersihan driver Virtual Audio & Virtual Mic
REM ============================================================================

set "DRV_DIR=%~dp0"
set "SETUP_X64=%DRV_DIR%VBCABLE_Setup_x64.exe"

echo [XyDesk] Membersihkan driver Virtual Audio ^& Mic...

if exist "%SETUP_X64%" (
  "%SETUP_X64%" -u -h
  exit /b 0
)

if exist "C:\Program Files\VB\CABLE\VBCABLE_Setup_x64.exe" (
  "C:\Program Files\VB\CABLE\VBCABLE_Setup_x64.exe" -u -h
  exit /b 0
)

exit /b 0
