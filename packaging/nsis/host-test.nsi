Unicode True
!include "MUI2.nsh"
!include "x64.nsh"

!ifndef PAYLOAD
  !error "PAYLOAD wajib"
!endif
!ifndef GENERATED
  !error "GENERATED wajib"
!endif
!ifndef OUTPUT
  !error "OUTPUT wajib"
!endif
!define PRODUCT "XyDesk Host Test"
!define UNKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\XyDeskHostTest"
Name "${PRODUCT}"
OutFile "${OUTPUT}"
; Sentinel membedakan default dari /D, yang dihapus NSIS dari $CMDLINE.
InstallDir "$LOCALAPPDATA\Programs\XyDesk-NSIS-Default-50a751e8"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetCompressorDictSize 32
ShowInstDetails show
ShowUninstDetails show
ManifestDPIAware True
VIProductVersion "6.8.5.0"
VIAddVersionKey /LANG=1033 "ProductName" "XyDesk Host Test"
VIAddVersionKey /LANG=1033 "FileDescription" "Installer NSIS untuk paket uji engine Windows x64"
VIAddVersionKey /LANG=1033 "FileVersion" "6.8.5"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright 2026 XySpace Tech"

!define MUI_ICON "..\windows\xydesk.ico"
!define MUI_UNICON "..\windows\xydesk.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TEXT "Memasang paket uji engine Windows x64 yang terpisah dari XyDesk lama.$\r$\n$\r$\nDriver layar dibundel. Penyiapan opsional di halaman akhir meminta izin Administrator; driver yang sudah ada dipertahankan. Tidak membuka RDP. Host hanya dimulai lewat shortcut setelah Anda memilih menjalankannya.$\r$\n$\r$\nIdentitas uji disimpan terpisah dan tetap ada setelah uninstall."
!define MUI_FINISHPAGE_TEXT "Paket uji berhasil dipasang.$\r$\n$\r$\nJalankan XyDesk Host Test dari Desktop atau Start Menu. Biarkan RDP terbuka pada pengujian pertama.$\r$\n$\r$\nBaca Panduan Uji Manual sebelum menguji capture dan input."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${PAYLOAD}\LICENSE-XyDesk.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Siapkan layar virtual 720p (izin Administrator; tanpa restart otomatis)"
!define MUI_FINISHPAGE_RUN_FUNCTION SetupVirtualDisplay
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "Indonesian"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "Paket ini memerlukan Windows x64." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}
  SetShellVarContext current
  SetRegView 64
  StrCmp $INSTDIR "$LOCALAPPDATA\Programs\XyDesk-NSIS-Default-50a751e8" 0 init_done
  StrCpy $INSTDIR "$LOCALAPPDATA\Programs\XyDesk Host Test"
  ReadRegStr $0 HKCU "${UNKEY}" "InstallLocation"
  StrCmp $0 "" init_done
    StrCpy $INSTDIR $0
init_done:
FunctionEnd

; Tolak folder berisi berkas lain, kecuali instalasi produk ini yang tercatat.
; Pemeriksaan juga dijalankan oleh section agar /S tidak melewati pengaman.
Function CheckInstallDir
  ReadRegStr $2 HKCU "${UNKEY}" "InstallLocation"
  StrCmp $2 "" scan_dir
  StrCmp $2 $INSTDIR scan_dir reject
scan_dir:
  ClearErrors
  FindFirst $0 $1 "$INSTDIR\*"
  IfErrors empty
scan:
  StrCmp $1 "" close_empty
  StrCmp $1 "." next
  StrCmp $1 ".." next
  FindClose $0
  ReadRegStr $0 HKCU "${UNKEY}" "InstallLocation"
  StrCmp $0 $INSTDIR 0 reject
  IfFileExists "$INSTDIR\Uninstall-XyDesk-Host-Test.exe" empty reject
next:
  FindNext $0 $1
  IfErrors close_empty scan
close_empty:
  FindClose $0
empty:
  ClearErrors
  Return
reject:
  SetErrors
FunctionEnd

Function .onVerifyInstDir
  Call CheckInstallDir
  IfErrors 0 valid
    Abort
valid:
FunctionEnd

Section "Host uji"
  Call CheckInstallDir
  IfErrors 0 safe
    MessageBox MB_OK|MB_ICONSTOP "Pilih folder kosong. Installer tidak akan menimpa instalasi lain atau berkas pribadi." /SD IDOK
    SetErrorLevel 1
    Abort
safe:
  SetShellVarContext current
  SetRegView 64
  SetOverwrite on
  ClearErrors
  !include "${GENERATED}\install-files.nsh"
  IfErrors failed
  WriteUninstaller "$INSTDIR\Uninstall-XyDesk-Host-Test.exe"
  IfErrors failed
  WriteRegStr HKCU "${UNKEY}" "DisplayName" "${PRODUCT}"
  WriteRegStr HKCU "${UNKEY}" "DisplayVersion" "6.8.5"
  WriteRegStr HKCU "${UNKEY}" "Publisher" "XySpace Tech"
  WriteRegStr HKCU "${UNKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNKEY}" "UninstallString" '$\"$INSTDIR\Uninstall-XyDesk-Host-Test.exe$\"'
  WriteRegStr HKCU "${UNKEY}" "QuietUninstallString" '$\"$INSTDIR\Uninstall-XyDesk-Host-Test.exe$\" /S'
  WriteRegStr HKCU "${UNKEY}" "DisplayIcon" "$INSTDIR\xydesk.ico"
  WriteRegDWORD HKCU "${UNKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNKEY}" "NoRepair" 1
  WriteRegDWORD HKCU "${UNKEY}" "EstimatedSize" ${ESTIMATED_KB}
  CreateDirectory "$SMPROGRAMS\${PRODUCT}"
  CreateShortcut "$DESKTOP\XyDesk Virtual720.lnk" "$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" '-NoLogo -NoProfile -NoExit -ExecutionPolicy RemoteSigned -File $\"$INSTDIR\Start-Virtual720.ps1$\"' "$INSTDIR\xydesk.ico"

  CreateShortcut "$SMPROGRAMS\${PRODUCT}\${PRODUCT}.lnk" "$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" '-NoLogo -NoProfile -NoExit -ExecutionPolicy RemoteSigned -File $\"$INSTDIR\Start-TestHost.ps1$\"' "$INSTDIR\xydesk.ico"
  CreateShortcut "$DESKTOP\${PRODUCT}.lnk" "$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" '-NoLogo -NoProfile -NoExit -ExecutionPolicy RemoteSigned -File $\"$INSTDIR\Start-TestHost.ps1$\"' "$INSTDIR\xydesk.ico"
  CreateShortcut "$SMPROGRAMS\${PRODUCT}\Panduan Uji Manual.lnk" "$WINDIR\System32\notepad.exe" '$\"$INSTDIR\README-INSTALLER.txt$\"' "$INSTDIR\xydesk.ico"
  CreateShortcut "$SMPROGRAMS\${PRODUCT}\Uninstall.lnk" "$INSTDIR\Uninstall-XyDesk-Host-Test.exe"
  IfErrors failed
  SetErrorLevel 0
  Goto done
failed:
  MessageBox MB_OK|MB_ICONSTOP "Instalasi gagal. Pastikan host uji tidak sedang berjalan dan folder dapat ditulis. Tidak ada proses yang dihentikan otomatis." /SD IDOK
  SetErrorLevel 1
  Abort
done:
SectionEnd

Function un.onInit
  SetShellVarContext current
  SetRegView 64
  ReadRegStr $0 HKCU "${UNKEY}" "InstallLocation"
  StrCmp $0 $INSTDIR valid
    MessageBox MB_OK|MB_ICONSTOP "Lokasi uninstall tidak cocok dengan instalasi yang tercatat." /SD IDOK
    SetErrorLevel 1
    Abort
valid:
FunctionEnd

Section "Uninstall"
  SetShellVarContext current
  SetRegView 64
  ; Hanya berkas yang dibundel. Tidak ada RMDir /r atau penghapusan identitas.
  ClearErrors
  !include "${GENERATED}\uninstall-files.nsh"
  IfFileExists "$INSTDIR\xydesk-host.exe" blocked
  Delete "$DESKTOP\${PRODUCT}.lnk"
  Delete "$DESKTOP\XyDesk Virtual720.lnk"
  Delete "$SMPROGRAMS\${PRODUCT}\${PRODUCT}.lnk"
  Delete "$SMPROGRAMS\${PRODUCT}\Panduan Uji Manual.lnk"
  Delete "$SMPROGRAMS\${PRODUCT}\Uninstall.lnk"
  RMDir "$SMPROGRAMS\${PRODUCT}"
  DeleteRegKey HKCU "${UNKEY}"
  Delete "$INSTDIR\Uninstall-XyDesk-Host-Test.exe"
  RMDir "$INSTDIR"
  SetErrorLevel 0
  Goto done
blocked:
  MessageBox MB_OK|MB_ICONSTOP "Engine belum dapat dihapus. Tutup host uji secara manual, lalu ulangi uninstall." /SD IDOK
  SetErrorLevel 1
  Abort
done:
SectionEnd

Function SetupVirtualDisplay
  ${DisableX64FSRedirection}
  ClearErrors
  ExecShell "runas" "$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" '-NoProfile -ExecutionPolicy RemoteSigned -File "$INSTDIR\Configure-Display.ps1"'
  IfErrors display_declined display_started
display_declined:
  ${EnableX64FSRedirection}
  MessageBox MB_OK "Penyiapan layar belum dimulai. Host tetap terpasang; jalankan Configure-Display.ps1 dengan izin Administrator bila diperlukan."
  Return
display_started:
  ${EnableX64FSRedirection}
FunctionEnd
